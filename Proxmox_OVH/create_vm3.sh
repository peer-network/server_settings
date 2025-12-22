#!/bin/bash

# Proxmox VM Creation Script with Cloud-Init
# Creates VMs from Ubuntu Noble base image

set -e

# --- CONFIGURATION ---
UBUNTU_IMAGE="/home/peer/noble-server-cloudimg-amd64.img"  # Adjust path to your image
STORAGE_POOL="local-zfs"  # Your ZFS pool name
TEMPLATE_ID=9000  # Template VM ID
BRIDGE="vmbr0"  # Network bridge

# SSH key for cloud-init (replace with your public key)
SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDHr7r2lnUkxuUdAbYeNMfRe2ddGoMrcf5v5QT7Caoba peer@peer-omen"

# --- COLORS FOR OUTPUT ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "Proxmox VM Creation Script"
echo -e "==========================================${NC}"

# --- FUNCTION: CREATE TEMPLATE ---
create_template() {
    echo -e "\n${GREEN}[1/3] Creating Ubuntu Noble Template (ID: $TEMPLATE_ID)${NC}"
    
    # Check if template already exists
    if qm status $TEMPLATE_ID &>/dev/null; then
        echo "Template $TEMPLATE_ID already exists. Destroying it..."
        qm destroy $TEMPLATE_ID
    fi
    
    # Create VM
    qm create $TEMPLATE_ID \
        --name ubuntu-noble-template \
        --memory 2048 \
        --cores 2 \
        --net0 virtio,bridge=$BRIDGE \
        --serial0 socket \
        --vga serial0
    
    # Import disk
    echo "Importing Ubuntu Noble image..."
    qm importdisk $TEMPLATE_ID $UBUNTU_IMAGE $STORAGE_POOL
    
    # Attach disk
    qm set $TEMPLATE_ID \
        --scsihw virtio-scsi-pci \
        --scsi0 ${STORAGE_POOL}:vm-${TEMPLATE_ID}-disk-0
    
    # Add cloud-init drive
    qm set $TEMPLATE_ID --ide2 ${STORAGE_POOL}:cloudinit
    
    # Set boot disk
    qm set $TEMPLATE_ID --boot c --bootdisk scsi0
    
    # Add serial console
    qm set $TEMPLATE_ID --serial0 socket --vga serial0
    
    # Enable QEMU agent
    qm set $TEMPLATE_ID --agent enabled=1
    
    # Convert to template
    qm template $TEMPLATE_ID
    
    echo -e "${GREEN}Template created successfully!${NC}"
}

# --- FUNCTION: CREATE VM FROM TEMPLATE ---
create_vm() {
    local VM_ID=$1
    local VM_NAME=$2
    local CORES=$3
    local MEMORY=$4  # in GB
    local DISK_SIZE=$5  # in GB
    local CIUSER=${6:-"ubuntu"}
    local CIPASSWORD=${7:-""}
    
    echo -e "\n${GREEN}Creating VM: $VM_NAME (ID: $VM_ID)${NC}"
    echo "  Cores: $CORES | RAM: ${MEMORY}GB | Disk: ${DISK_SIZE}GB"
    
    # Check if VM already exists
    if qm status $VM_ID &>/dev/null; then
        echo "VM $VM_ID already exists. Skipping..."
        return
    fi
    
    # Clone from template
    qm clone $TEMPLATE_ID $VM_ID --name $VM_NAME --full
    
    # Set resources
    qm set $VM_ID --cores $CORES
    qm set $VM_ID --memory $((MEMORY * 1024))  # Convert GB to MB
    
    # Resize disk
    qm resize $VM_ID scsi0 ${DISK_SIZE}G
    
    # Configure cloud-init
    qm set $VM_ID --ciuser $CIUSER
    qm set $VM_ID --sshkeys <(echo "$SSH_KEY")
    qm set $VM_ID --ipconfig0 ip=dhcp
    
    # Set password if provided
    if [ -n "$CIPASSWORD" ]; then
        qm set $VM_ID --cipassword "$CIPASSWORD"
    fi
    
    echo -e "${GREEN}VM $VM_NAME created successfully!${NC}"
}

# --- MAIN EXECUTION ---

# Step 1: Create template
create_template

# Step 2: Create all VMs
echo -e "\n${BLUE}[2/3] Creating VMs from template${NC}"

# VM_ID  NAME                    CORES  RAM(GB)  DISK(GB)
create_vm 101 "peer-prod-frontend"   1      1        20
create_vm 102 "peer-prod-admin"      1      1        20
create_vm 103 "peer-prod-backend"    5      32       1000
create_vm 104 "peer-prod-bastion"    1      1        20
create_vm 105 "peer-prod-website"    1      1        20
create_vm 106 "peer-prod-database"   3      16       1000

# Step 3: Summary
echo -e "\n${BLUE}[3/3] Summary${NC}"
echo -e "${GREEN}All VMs created successfully!${NC}"
echo ""
echo "VM List:"
echo "  101 - peer-prod-frontend  (1c/1GB/20GB)"
echo "  102 - peer-prod-admin     (1c/1GB/20GB)"
echo "  103 - peer-prod-backend   (5c/32GB/1000GB)"
echo "  104 - peer-prod-bastion   (1c/1GB/20GB)"
echo "  105 - peer-prod-website   (1c/1GB/20GB)"
echo "  106 - peer-prod-database  (3c/16GB/1000GB)"
echo ""
echo "To start a VM: qm start <VM_ID>"
echo "To start all VMs: for i in {101..106}; do qm start \$i; done"
echo ""
echo "Cloud-init will configure the VMs on first boot with:"
echo "  - Username: ubuntu"
echo "  - SSH key authentication"
echo "  - DHCP networking"
echo ""
echo -e "${BLUE}==========================================${NC}"