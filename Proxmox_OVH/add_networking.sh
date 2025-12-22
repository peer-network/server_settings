#!/bin/bash

# Proxmox Host Firewall Configuration
# Port forwarding for SSH (bastion) and HTTP/HTTPS (website)

set -e

if [ "$EUID" -ne 0 ]; then 
  echo "ERROR: Please run as root"
  exit 1
fi

# Configuration
PUBLIC_IP="162.19.169.215"
BASTION_PRIVATE_IP="192.168.1.2"
WEBSITE_PRIVATE_IP="192.168.1.10"

echo "Setting up firewall rules..."

# Enable IP forwarding (if not already enabled)
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

# Clear existing NAT rules (optional - be careful!)
# iptables -t nat -F

# Port forward SSH (22) to Bastion
echo "Forwarding SSH (22) to Bastion ($BASTION_PRIVATE_IP)..."
iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 22 -j DNAT --to-destination ${BASTION_PRIVATE_IP}:22
iptables -A FORWARD -p tcp -d ${BASTION_PRIVATE_IP} --dport 22 -j ACCEPT

# Port forward HTTP (80) to Website
echo "Forwarding HTTP (80) to Website ($WEBSITE_PRIVATE_IP)..."
iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 80 -j DNAT --to-destination ${WEBSITE_PRIVATE_IP}:80
iptables -A FORWARD -p tcp -d ${WEBSITE_PRIVATE_IP} --dport 80 -j ACCEPT

# Port forward HTTPS (443) to Website
echo "Forwarding HTTPS (443) to Website ($WEBSITE_PRIVATE_IP)..."
iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 443 -j DNAT --to-destination ${WEBSITE_PRIVATE_IP}:443
iptables -A FORWARD -p tcp -d ${WEBSITE_PRIVATE_IP} --dport 443 -j ACCEPT

# Save iptables rules
echo "Saving iptables rules..."
apt-get install -y iptables-persistent
netfilter-persistent save

echo ""
echo "=========================================="
echo "Firewall rules configured successfully!"
echo "=========================================="
echo ""
echo "Port forwarding active:"
echo "  ${PUBLIC_IP}:22   → ${BASTION_PRIVATE_IP}:22   (SSH - Bastion)"
echo "  ${PUBLIC_IP}:80   → ${WEBSITE_PRIVATE_IP}:80   (HTTP - Website)"
echo "  ${PUBLIC_IP}:443  → ${WEBSITE_PRIVATE_IP}:443  (HTTPS - Website)"
echo ""
echo "To view rules:"
echo "  iptables -t nat -L -n -v"
echo "  iptables -L FORWARD -n -v"
echo ""
echo "=========================================="