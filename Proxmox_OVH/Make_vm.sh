#!/bin/bash
set -euo pipefail

VMID=203
VMNAME="peer-backend"
STORAGE=local
IMG="/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img"
DISK_SIZE=1000G
CIUSER="peer"
PUBKEY="/root/.ssh/id_rsa.pub"
PASSWORD="peer2025"

# Download cloud image if missing
if [[ ! -f "$IMG" ]]; then
  wget -q https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img -O "$IMG"
fi

# Clean old VM if it exists
qm destroy $VMID --purge || true

# Create shell
qm create $VMID --name "$VMNAME" --ostype l26 \
  --memory 2048 --cores 2 --sockets 1 \
  --cpu host --scsihw virtio-scsi-pci \
  --net0 virtio,bridge=vmbr0 \
  --agent enabled=1,fstrim_cloned_disks=1 \
  --serial0 socket --vga serial0

# Import cloud image into storage (force qcow2 for easy resize)
qm importdisk $VMID "$IMG" $STORAGE --format qcow2

# Attach imported disk as OS drive
VOLID=$(qm config $VMID | awk -F ': ' '/^unused[0-9]+:/ {print $2; exit}')
qm set $VMID --scsi0 "$VOLID",iothread=1,cache=writeback

# Resize disk to desired size
qm disk resize $VMID scsi0 $DISK_SIZE

# Add cloud-init drive
qm set $VMID --ide2 $STORAGE:cloudinit

# Set boot order
qm set $VMID --boot order=scsi0

# Cloud-init user setup
qm set $VMID --ciuser $CIUSER --sshkey $PUBKEY
qm set $VMID --cipassword $PASSWORD
qm set $VMID --ipconfig0 ip=dhcp

# (Optional) custom cloud-init snippet with extra packages
SNIPPET="/var/lib/vz/snippets/ubuntu-noble-runtime.yaml"
mkdir -p /var/lib/vz/snippets
cat >"$SNIPPET" <<EOF
#cloud-config
packages: [qemu-guest-agent, net-tools, curl, vim, parted, xfsprogs, e2fsprogs]
runcmd:
  - systemctl enable --now qemu-guest-agent
EOF
qm set $VMID --cicustom "user=local:snippets/ubuntu-noble-runtime.yaml"

# Start VM
qm start $VMID
