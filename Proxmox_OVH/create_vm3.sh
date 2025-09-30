#!/usr/bin/env bash
set -euo pipefail

# ====== SETTINGS ======

# IMG="/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img"
IMG="/var/lib/vz/template/iso/noble-server-cloudimg-amd64.qcow2"
STOR="local"
BR0="vmbr0"
# Updated to match your actual network
GATEWAY="162.19.169.1"  # Your actual gateway
CIUSER="peer"
PUBKEY="/root/.ssh/id_rsa.pub"   # Fixed typo from id_rda.pub
SNIPPET="/var/lib/vz/snippets/cloudinit-userdata.yaml"
# ======================

  # Generate password hash for 'peer' user (change 'changeme' to your desired password)
  local PEER_PASSWORD="peer2025"
  local PASSWORD_HASH
  PASSWORD_HASH=$(openssl passwd -6 "$PEER_PASSWORD")

mkdir -p /var/lib/vz/snippets
# Enhanced cloud-init snippet - No iptables needed, using Proxmox firewall
if [[ ! -f "$SNIPPET" ]]; then
  cat >"$SNIPPET" <<'YAML'
    #cloud-config
    packages:
    - qemu-guest-agent
    - net-tools
    - curl
    - wget
    - vim
    - parted
    - xfsprogs
    - e2fsprogs

    users:
    - name: peer
        groups: [sudo]
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        lock_passwd: false
        passwd: PASSWORD_HASH
        ssh_authorized_keys:
        - SSH_KEY_PLACEHOLDER

    # Auto-format and mount data disk if it exists
    runcmd:
    - systemctl enable --now qemu-guest-agent
    - echo "VM configured - firewall managed by Proxmox" > /etc/motd
    # Check for and format data disk (scsi1 = /dev/sdb)
    - |
        if [ -b /dev/sdb ]; then
        echo "Found data disk /dev/sdb, formatting..."
        parted -s /dev/sdb mklabel gpt
        parted -s /dev/sdb mkpart primary xfs 0% 100%
        mkfs.xfs -f /dev/sdb1
        mkdir -p /data
        echo '/dev/sdb1 /data xfs defaults,noatime 0 2' >> /etc/fstab
        mount /data
        chmod 755 /data
        echo "Data disk mounted at /data"
        fi

    write_files:
    - path: /etc/issue
        content: |

        Welcome to \n
        Login: peer / <password set during creation>

YAML

  # Replace placeholders
  sed -i "s|PASSWORD_HASH_PLACEHOLDER|${PASSWORD_HASH}|" "$SNIPPET"
  
  if [[ -f "$PUBKEY" ]]; then
    SSH_KEY_CONTENT=$(cat "$PUBKEY" | tr -d '\n\r')
    sed -i "s|SSH_KEY_PLACEHOLDER|${SSH_KEY_CONTENT}|" "$SNIPPET"
    echo "  SSH key loaded (hidden from output)"
  else
    echo "  WARNING: SSH public key not found at $PUBKEY"
    sed -i "s|SSH_KEY_PLACEHOLDER|# NO SSH KEY FOUND|" "$SNIPPET"
  fi
  
  echo "  Cloud-init configured for user 'peer'"
fi

# Track statuses
declare -A VM_STATUS VM_REASON

die() { echo "ERROR: $*" >&2; exit 1; }

has_qm() { command -v qm >/dev/null 2>&1; }
has_qm || die "Proxmox 'qm' not found. Run on a Proxmox node."

require_img() { [[ -f "$IMG" ]] || die "Cloud image not found: $IMG"; }
require_img

# Small helper to wait for a VM to report "running"
wait_running() {
  local vmid="$1" tries=30
  while (( tries-- > 0 )); do
    local st
    st="$(qm status "$vmid" 2>/dev/null | awk '{print $2}')"
    [[ "$st" == "running" ]] && return 0
    sleep 2
  done
  return 1
}

# Helper to wait for VM to be running
wait_running() {
  local vmid="$1" tries=60  # Increased from 30 to 60
  echo -n "    Waiting for VM to start."
  while (( tries-- > 0 )); do
    local st
    st="$(qm status "$vmid" 2>/dev/null | awk '{print $2}')"
    if [[ "$st" == "running" ]]; then
      echo " OK"
      return 0
    fi
    echo -n "."
    sleep 2
  done
  echo " TIMEOUT"
  return 1
}

# Helper to wait for disk operation
wait_for_disk_op() {
  local message="$1"
  echo -n "    $message"
  for i in {1..5}; do
    echo -n "."
    sleep 1
  done
  echo " done"
}

# Create a VM and record status
create_vm () {
  local VMID="$1" NAME="$2" CORES="$3" RAM_GB="$4" OSDISK_GB="$5" IP="$6" BRIDGE="$7" VLAN="$8"
  VM_STATUS["$VMID"]="INIT"
  VM_REASON["$VMID"]=""

  echo "==> [$VMID] Creating $NAME…"

  # Determine network configuration
  local NET_CONFIG="virtio,bridge=${BRIDGE}"
  if [[ -n "$VLAN" && "$VLAN" != "0" ]]; then
    NET_CONFIG="${NET_CONFIG},tag=${VLAN}"
  fi

  # Create shell for the VM
  if ! qm create "$VMID" --name "$NAME" \
      --memory "$((RAM_GB*1024))" --cores "$CORES" --sockets 1 \
      --net0 "$NET_CONFIG" \
      --ostype l26 --scsihw virtio-scsi-pci; then
    VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="qm create failed"; return
  fi

  #qm set 203 --scsi0 local:203/vm-203-disk-0.raw

  VOLID=${VMID}/vm-${VMID}-disk-0.raw
echo text volid "${VOLID}", "${OSDISK_GB}"

  # Import disk - this can take time
  echo "    Importing disk image (this may take 30-60 seconds)..."
  if ! timeout 120 qm importdisk "$VMID" "$IMG" "$STOR" 2>&1 | grep -v "^$"; then
    VM_STATUS["$VMID"]="FAILED"
    VM_REASON["$VMID"]="disk import failed or timed out"
    return
  fi
  wait_for_disk_op "Processing disk import"

#   if ! qm importdisk "$VMID" /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img local; then
#     VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="import disk failed"; return
#   fi

 # Find imported disk
  local DISK_SPEC
  DISK_SPEC=$(qm config "$VMID" | awk -F': ' '/^unused[0-9]+:/ {print $2; exit}')
  if [[ -z "$DISK_SPEC" ]]; then
    VM_STATUS["$VMID"]="FAILED"
    VM_REASON["$VMID"]="no imported disk found"
    return
  fi

 # Setup cloud-init
  echo "    Configuring cloud-init..."
  if ! qm set "$VMID" --ide2 "${STOR}:cloudinit" --serial0 socket --vga serial0 2>/dev/null; then
    VM_STATUS["$VMID"]="FAILED"
    VM_REASON["$VMID"]="cloudinit setup failed"
    return
  fi

#   # Enable firewall
#   qm set "$VMID" --firewall 1 2>/dev/null || true

  # Resize disk - this can also take time
  if [[ "$OSDISK_GB" -gt 20 ]]; then
    echo "    Resizing disk to ${OSDISK_GB}GB (this may take time)..."
    if ! timeout 180 qm resize "$VMID" scsi0 "${OSDISK_GB}G" 2>&1 | grep -v "^$"; then
      echo "    WARNING: Disk resize timed out, but may complete in background"
    fi
    wait_for_disk_op "Finalizing disk resize"
  fi


    # Attach disk
#   echo "    Attaching disk as boot device..."
#   if ! qm set "$VMID" --scsi0 "$DISK_SPEC" --boot order=scsi0 2>/dev/null; then
#     VM_STATUS["$VMID"]="FAILED"
#     VM_REASON["$VMID"]="attach scsi0 failed"
#     return
#   fi


#   if ! qm set "$VMID" --scsi0 local:"${VOLID}", iothread=1, cache=writeback; then
#     VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="qm failed to set ${VOLID} OS drive"; return
#   fi

#   if ! qm resize "$VMID" scsi0 ${OSDISK_GB}; then
#     VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="os disk resize failed"; return    
#   fi

  # Determine IP configuration based on network
  local IP_CONFIG
  if [[ "$BRIDGE" == "vmbr0" ]]; then
    # External network - use your actual gateway
    IP_CONFIG="ip=${IP}/24,gw=${GATEWAY}"
  else
    # Internal network - would need different gateway (like 192.168.1.1 from gateway VM)
    IP_CONFIG="ip=${IP}/24,gw=192.168.1.1"
  fi

  # Cloud-init user, key, IP
  if ! qm set "$VMID" --ciuser "$CIUSER" --sshkey "$PUBKEY" \
      --ipconfig0 "$IP_CONFIG" \
      --cicustom "user=local:snippets/$(basename "$SNIPPET")" >/dev/null 2>&1; then
    VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="cloud-init settings failed"; return
  fi
  echo "    Network: $IP_CONFIG (credentials hidden)"

  # Minimal existence check
  if [[ ! -f "/etc/pve/qemu-server/${VMID}.conf" ]]; then
    VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="config file missing"; return
  fi
  VM_STATUS["$VMID"]="CREATED"

  # Start & verify boot
  if ! qm start "$VMID" >/dev/null 2>&1; then
    VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="start failed"; return
  fi
  VM_STATUS["$VMID"]="BOOTING"

  if wait_running "$VMID"; then
    VM_STATUS["$VMID"]="RUNNING"
  else
    VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="did not reach running state"
  fi
}

# Function to create internal bridge (vmbr1) for private networks
setup_internal_bridge() {
  echo "==> Setting up internal bridge (vmbr1)..."

  # Check if vmbr1 exists in network config
  if ! grep -q "auto vmbr1" /etc/network/interfaces; then
    echo "Adding vmbr1 to network configuration..."
    cat >> /etc/network/interfaces << 'EOF'

# Internal bridge for private networks
auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
#Internal Bridge for Private Networks
EOF
    echo "NOTE: You'll need to reboot or run 'ifreload -a' to activate vmbr1"
  fi
}

# Main execution
echo "======================================"
echo "Proxmox VM Creation Script"
echo "======================================"
echo "Image: $IMG"
echo "Storage: $STOR"
echo "Bridge: $BR0"
echo "Gateway: $GATEWAY"
echo ""

setup_internal_bridge

echo ""
echo "Creating VMs..."
echo "Note: Disk operations may take 1-3 minutes per VM"
echo ""

# Create VMs - removed DATADISK parameter, disks will be 20GB or resized
#create_vm 201 "peer-prod-frontend"  1  1  20    "162.19.169.221" "vmbr0" "0"
#create_vm 202 "peer-prod-admin"     1  1  20    "162.19.169.222" "vmbr0" "0"
create_vm 203 "peer-prod-backend"   5  32 1000  "162.19.169.223" "vmbr0" "0"
#create_vm 204 "peer-prod-bastion"   1  1  20    "162.19.169.224" "vmbr0" "0"
#create_vm 205 "peer-prod-website"   1  1  20    "162.19.169.225" "vmbr0" "0"
#create_vm 206 "peer-prod-database"  3  16 1000  "162.19.169.226" "vmbr0" "0"

# Summary
echo ""
echo "======================================"
echo "CREATION SUMMARY"
echo "======================================"
printf "%-6s %-24s %-10s %s\n" "VMID" "NAME" "STATUS" "NOTES"
printf "%-6s %-24s %-10s %s\n" "----" "----------------------" "--------" "-------------------------"

for vmid in 201 202 203 204 205 206; do
  name="$(qm config "$vmid" 2>/dev/null | awk -F': ' '/^name:/{print $2}' || echo 'N/A')"
  status="${VM_STATUS[$vmid]:-UNKNOWN}"
  reason="${VM_REASON[$vmid]:-}"
  printf "%-6s %-24s %-10s %s\n" "$vmid" "${name:-N/A}" "$status" "$reason"
done

echo ""
echo "======================================"
echo "VM ACCESS CREDENTIALS"
echo "======================================"
echo "Username: peer"
echo "Password: $PEER_PASSWORD"
echo "SSH Key:  Configured from $PUBKEY"
echo ""
echo "SECURITY: Change passwords immediately!"
echo "  ssh peer@<VM_IP>"
echo "  sudo passwd peer"
echo ""
echo "======================================"
echo ""
echo "Next Steps:"
echo "1. Verify VMs are accessible:"
echo "   qm list"
echo "2. Test SSH access:"
echo "   ssh peer@162.19.169.221"
echo "3. For VMs with large disks (203, 206):"
echo "   - Wait for disk resize to complete (check 'qm status <vmid>')"
echo "   - SSH in and verify with: df -h"
echo "4. Add additional data disks if needed:"
echo "   ./manage_data_disks.sh add 203 500  # Add 500GB"
echo "5. Setup firewall rules:"
echo "   ./setup_firewall.sh"
echo ""
echo "Troubleshooting:"
echo "- If VM won't start: qm status <vmid>"
echo "- Check logs: journalctl -u qemu-server@<vmid>"
echo "- View console: qm terminal <vmid>"
echo ""