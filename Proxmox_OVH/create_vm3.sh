#!/usr/bin/env bash
set -euo pipefail

# ====== SETTINGS ======
IMG="/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img"
STOR="local"
BR0="vmbr0"
# Updated to match your actual network
GATEWAY="162.19.169.1"  # Your actual gateway
CIUSER="peer"
PUBKEY="/root/.ssh/id_rsa.pub"   # Fixed typo from id_rda.pub
SNIPPET="/var/lib/vz/snippets/cloudinit-userdata.yaml"
# ======================

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
    passwd: SSH_PASSWORD_HASH_PLACEHOLDER
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

  # Generate password hash for 'peer' user (change 'changeme' to your desired password)
  local PEER_PASSWORD="peer2025"
  local PASSWORD_HASH
  PASSWORD_HASH=$(openssl passwd -6 "$PEER_PASSWORD")

  # Replace placeholders
  sed -i "s|SSH_PASSWORD_HASH_PLACEHOLDER|${PASSWORD_HASH}|" "$SNIPPET"

  if [[ -f "$PUBKEY" ]]; then
    # Read and sanitize the SSH key (remove any trailing whitespace)
    local SSH_KEY_CONTENT
    SSH_KEY_CONTENT=$(cat "$PUBKEY" | tr -d '\n\r')
    sed -i "s|SSH_KEY_PLACEHOLDER|${SSH_KEY_CONTENT}|" "$SNIPPET"
    echo "✓ SSH key loaded from $PUBKEY (hidden from output)"
  else
    echo "WARNING: SSH public key not found at $PUBKEY"
    sed -i "s|SSH_KEY_PLACEHOLDER|# NO SSH KEY FOUND|" "$SNIPPET"
  fi

  echo "✓ Cloud-init configured with user 'peer' and password authentication"
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

  VOLID="local:${VMID}/vm-${VMID}-disk-0.raw"

  if ! qm importdisk "$VMID" /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img local; then
    VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="import disk failed"; return
  fi

  if ! qm set "$VMID" --scsi0 local:${VOLID},iothread=1,cache=writeback; then
    VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="qm failed to set ${VOLID} OS drive"; return
  fi

  if ! qm resize "$VMID" scsi0 ${OSDISK_GB}G; then
    VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="os disk resize failed"; return    
  fi


#   # Cloud-init drive, serial console, and resize OS disk
#   if ! qm set "$VMID" --ide2 "${STOR}:cloudinit" --serial0 socket --vga serial0; then
#     VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="cloudinit/serial setup failed"; return
#   fi

  # Enable Proxmox firewall for this VM (no need for iptables inside VM)
  # qm set "$VMID" --firewall 1 || true

  # Resize may be a no-op if image already >= requested size
  # qm resize "$VMID" scsi0 "${OSDISK_GB}G" >/dev/null 2>&1 || true

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

  # Optional data disk - properly allocate from storage
#   if [[ -n "${DATADISK_GB}" && "${DATADISK_GB}" != "0" ]]; then
#     echo "    Creating ${DATADISK_GB}GB data disk..."
#     if ! pvesm alloc "$STOR" "$VMID" "vm-${VMID}-disk-1" "${DATADISK_GB}G" >/dev/null 2>&1; then
#       VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="data disk allocation failed"; return
#     fi
#     if ! qm set "$VMID" --scsi1 "${STOR}:vm-${VMID}-disk-1"; then
#       VM_STATUS["$VMID"]="FAILED"; VM_REASON["$VMID"]="attach data disk failed"; return
#     fi
#   fi

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

# ------------------ DEFINE YOUR VMs HERE ------------------
# Updated to match your network topology
# Format: VMID NAME CORES RAM(GB) OSDISK(GB) DATADISK(GB) IP BRIDGE VLAN

# First, set up the internal bridge
setup_internal_bridge

echo "Creating VMs with updated network configuration..."

# Option 1: All VMs on external bridge (vmbr0) - Simpler but less secure
# create_vm 200 "peer-gateway-router"  2  2  20   0     "162.19.169.220" "vmbr0" "0"
create_vm 201 "peer-prod-frontend"   1  1  20        "162.19.169.221" "vmbr0" "0"
create_vm 202 "peer-prod-admin"      1  1  20        "162.19.169.222" "vmbr0" "0"
create_vm 203 "peer-prod-backend"    5 32  1000        "162.19.169.223" "vmbr0" "0"
create_vm 204 "peer-prod-bastion"    1  1  20        "162.19.169.224" "vmbr0" "0"
create_vm 205 "peer-prod-website"    1  1  20        "162.19.169.225" "vmbr0" "0"
create_vm 206 "peer-prod-database"   3 16  100        "162.19.169.226" "vmbr0" "0"

# ----------------------------------------------------------

# Summary table
printf "\n%-6s %-24s %-10s %-s\n" "VMID" "NAME" "STATUS" "REASON/INFO"
printf "%-6s %-24s %-10s %-s\n" "-----" "------------------------" "--------" "------------------------------"
for vmid in 201 ; do  #202 203 204 205 206
  name="$(qm config "$vmid" 2>/dev/null | awk -F': ' '/^name:/{print $2}' || echo 'N/A')"
  status="${VM_STATUS[$vmid]:-UNKNOWN}"
  reason="${VM_REASON[$vmid]:-}"
  printf "%-6s %-24s %-10s %-s\n" "$vmid" "${name:-N/A}" "$status" "$reason"
  if qm status "$vmid" >/dev/null 2>&1; then
    qm status --verbose "$vmid" 2>/dev/null || echo "Status check failed"
  fi
done

echo ""
echo "=========================================="
echo "VM ACCESS CREDENTIALS"
echo "=========================================="
echo "User: peer"
echo "Password: peer2025"
echo "SSH Key: (configured from $PUBKEY)"
echo ""
echo "IMPORTANT: Change the default password after first login!"
echo "On each VM run: sudo passwd peer"
echo ""
echo "=========================================="
echo ""
echo "Data Disk Management:"
echo "  List disks:      ./manage_data_disks.sh list"
echo "  Add 1TB to 203:  ./manage_data_disks.sh add 203 1000"
echo "  Format disk:     ./manage_data_disks.sh format 203"
echo ""
echo "Tip: check live state with 'qm list' or 'qm status <vmid>'."
echo ""
echo "Post-creation steps:"
echo "1. Change default password on all VMs"
echo "2. Add data disks to VMs that need them (203, 206)"
echo "3. Format and mount data disks"
echo "4. Run firewall setup script: ./setup_firewall.sh"
echo "5. Test connectivity and services"
