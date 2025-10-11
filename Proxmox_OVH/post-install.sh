#!/bin/bash

# --- config ---
USERNAME="peer"
PASSWORD_HASH='$6$vZ/wjbnP7yQ7jV1v$yQeXzmK17PbiOnsG5Z8F0AbCKo1MLCk0UTMVnLteXdkcmA78mNH5fwKdP/e2Ni5tb28By8rUuEkl4zb/UG1Pt1'  # passwd hash
# ovh-host
PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDHr7r2lnUkxuUdAbYeNMfRe2ddGoMrcf5v5QT7Caoba peer@peer-omen'  # OPTION A: put key here
#PUBKEY_FILE="/root/.ssh/id_rsa.pub"  # OPTION B: use a file instead (uncomment and set)

# Apps to Install Script
# System Update
sudo apt-get update

# Apps
sudo apt install software-properties-common apt-transport-https wget gpg -y
sudo apt install -y htop
sudo apt install -y curl
sudo apt install -y git
sudo apt install -y tree
sudo apt install -y python3
sudo apt install -y ansible
sudo apt install -y python3-venv

# Grafana Alloy install
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get install alloy

# Openstack
sudo apt install git python3-dev libffi-dev gcc libssl-dev libdbus-glib-1-dev

#user
# --- create user & set password (safe if user exists) ---
if ! id -u "$USERNAME" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -p "$PASSWORD_HASH" -U "$USERNAME"
else
  echo "User $USERNAME already exists"
fi

# --- put user in sudoers (NOPASSWD) ---
usermod -aG sudo "$USERNAME"

SUDO_FILE="/etc/sudoers.d/90-$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDO_FILE"
chmod 440 "$SUDO_FILE"
# optional sanity check:
visudo -cf "$SUDO_FILE" >/dev/null

# --- install SSH public key ---
HOME_DIR="$(getent passwd "$USERNAME" | cut -d: -f6)"
SSH_DIR="$HOME_DIR/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTH_KEYS"
echo "$PUBKEY" >> "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

# ENDE