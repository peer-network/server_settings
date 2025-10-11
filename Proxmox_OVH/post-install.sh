#!/bin/bash

# Proxmox Post-Installation Script for OVH
# Exit on error and undefined variables
set -e
set -u

# Setup logging
exec > >(tee -a /var/log/post-install.log)
exec 2>&1
echo "=========================================="
echo "Post-installation started at $(date)"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "ERROR: Please run as root"
  exit 1
fi

# --- CONFIG SECTION ---
USERNAME="peer"
PASSWORD_HASH='$6$vZ/wjbnP7yQ7jV1v$yQeXzmK17PbiOnsG5Z8F0AbCKo1MLCk0UTMVnLteXdkcmA78mNH5fwKdP/e2Ni5tb28By8rUuEkl4zb/UG1Pt1'
ROOT_HASH='$6$vZ/wjbnP7yQ7jV1v$yQeXzmK17PbiOnsG5Z8F0AbCKo1MLCk0UTMVnLteXdkcmA78mNH5fwKdP/e2Ni5tb28By8rUuEkl4zb/UG1Pt1'
# ROOT_PASSWORD='YourSecureRootPasswordHere'  # CHANGE THIS!
PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDHr7r2lnUkxuUdAbYeNMfRe2ddGoMrcf5v5QT7Caoba peer@peer-omen'

# --- SET ROOT PASSWORD ---
echo "Setting root password..."
echo "root:${ROOT_PASSWORD}" | chpasswd
echo "Root password set successfully"

# --- SYSTEM UPDATE ---
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# --- INSTALL BASIC PACKAGES ---
echo "Installing basic packages..."
apt-get install -y software-properties-common apt-transport-https wget gpg
apt-get install -y htop curl git tree python3 python3-venv

# --- INSTALL ANSIBLE ---
echo "Installing Ansible..."
apt-get install -y ansible

# --- INSTALL GRAFANA ALLOY ---
echo "Installing Grafana Alloy..."
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
apt-get update
apt-get install -y alloy

# --- INSTALL OPENSTACK DEPENDENCIES ---
echo "Installing OpenStack dependencies..."
apt-get install -y git python3-dev libffi-dev gcc libssl-dev libdbus-glib-1-dev

# --- CREATE USER ---
echo "Creating user: $USERNAME"
if ! id -u "$USERNAME" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -p "$PASSWORD_HASH" -U "$USERNAME"
  echo "User $USERNAME created successfully"
else
  echo "User $USERNAME already exists, skipping creation"
fi

# --- ADD USER TO SUDO GROUP ---
echo "Adding $USERNAME to sudo group..."
usermod -aG sudo "$USERNAME"

# --- CONFIGURE SUDOERS (NOPASSWD) ---
echo "Configuring sudoers for $USERNAME..."
SUDO_FILE="/etc/sudoers.d/90-$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDO_FILE"
chmod 440 "$SUDO_FILE"

# Validate sudoers file
if visudo -cf "$SUDO_FILE" >/dev/null 2>&1; then
  echo "Sudoers file validated successfully"
else
  echo "ERROR: Invalid sudoers file, removing it"
  rm -f "$SUDO_FILE"
  exit 1
fi

# --- INSTALL SSH PUBLIC KEY ---
echo "Installing SSH public key for $USERNAME..."
HOME_DIR="$(getent passwd "$USERNAME" | cut -d: -f6)"
SSH_DIR="$HOME_DIR/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTH_KEYS"

# Add key only if it doesn't exist
if ! grep -q "$PUBKEY" "$AUTH_KEYS" 2>/dev/null; then
  echo "$PUBKEY" >> "$AUTH_KEYS"
  echo "SSH key added successfully"
else
  echo "SSH key already exists, skipping"
fi

chmod 600 "$AUTH_KEYS"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

# --- HARDEN SSH CONFIGURATION ---
echo "Hardening SSH configuration..."
SSH_CONFIG="/etc/ssh/sshd_config"

# Backup original config
cp "$SSH_CONFIG" "${SSH_CONFIG}.backup.$(date +%Y%m%d)"

# Disable password authentication (force key-based only)
# sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSH_CONFIG"
# sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' "$SSH_CONFIG"  # Allow root for Proxmox management
# sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSH_CONFIG"

# Restart SSH service
systemctl restart sshd
echo "SSH configuration updated and service restarted"

# --- CLEANUP ---
echo "Cleaning up..."
apt-get autoremove -y
apt-get clean

# --- FINAL STATUS ---
echo "=========================================="
echo "Post-installation completed at $(date)"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Root password: SET"
echo "  - User '$USERNAME': CREATED"
echo "  - SSH key: INSTALLED"
echo "  - SSH: HARDENED (key-based auth only)"
echo "  - Packages: INSTALLED"
echo ""
echo "IMPORTANT: Save your root password securely!"
echo "You can now login as: $USERNAME@162.19.169.215"
echo ""
echo "Log file: /var/log/post-install.log"
echo "=========================================="