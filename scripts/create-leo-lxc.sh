#!/bin/bash
# Create Leo LXC Container on Proxmox
# Run this script on the Proxmox host to create the control node container
#
# Usage:
#   scp scripts/create-leo-lxc.sh root@proxmox:/tmp/
#   ssh root@proxmox 'bash /tmp/create-leo-lxc.sh'

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

CTID=103
HOSTNAME="leo"
TEMPLATE="debian-12-standard_12.7-1_amd64.tar.zst"
STORAGE="local-lvm"
MEMORY=1024
SWAP=512
CORES=2
DISK_SIZE=20
IP_ADDRESS="${LEO_IP:-192.168.1.13}"
GATEWAY="${GATEWAY_IP:-192.168.1.1}"
BRIDGE="vmbr0"
NAMESERVER="${PIHOLE_IP:-192.168.1.10}"
SSH_PUBKEY="${SSH_PUBKEY:-}"
USERNAME="jcook"

# =============================================================================
# Pre-flight checks
# =============================================================================

echo "=== Creating Leo Control Node LXC ==="
echo "CTID: $CTID"
echo "Hostname: $HOSTNAME"
echo "IP: $IP_ADDRESS"
echo "Memory: ${MEMORY}MB"
echo "Disk: ${DISK_SIZE}GB"
echo ""

# Check if container already exists
if pct status $CTID &>/dev/null; then
    echo "ERROR: Container $CTID already exists!"
    echo "To recreate, first destroy it: pct destroy $CTID --purge"
    exit 1
fi

# Check if template exists
TEMPLATE_PATH="/var/lib/vz/template/cache/$TEMPLATE"
if [[ ! -f "$TEMPLATE_PATH" ]]; then
    echo "Template not found. Downloading..."
    pveam update
    pveam download local $TEMPLATE
fi

# =============================================================================
# Create Container
# =============================================================================

echo "Creating container..."
pct create $CTID "$TEMPLATE_PATH" \
    --hostname "$HOSTNAME" \
    --storage "$STORAGE" \
    --rootfs "${STORAGE}:${DISK_SIZE}" \
    --memory "$MEMORY" \
    --swap "$SWAP" \
    --cores "$CORES" \
    --net0 "name=eth0,bridge=${BRIDGE},ip=${IP_ADDRESS}/24,gw=${GATEWAY}" \
    --nameserver "$NAMESERVER" \
    --unprivileged 1 \
    --features nesting=1 \
    --onboot 1 \
    --start 0

echo "Container created successfully."

# =============================================================================
# Configure Container
# =============================================================================

echo "Starting container..."
pct start $CTID
sleep 5  # Wait for container to boot

echo "Configuring container..."

# Update and install prerequisites
pct exec $CTID -- bash -c "apt-get update && apt-get install -y sudo openssh-server curl"

# Create user
pct exec $CTID -- bash -c "useradd -m -s /bin/bash -G sudo $USERNAME || true"

# Set up passwordless sudo
pct exec $CTID -- bash -c "echo '$USERNAME ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$USERNAME"

# Configure SSH
pct exec $CTID -- bash -c "mkdir -p /home/$USERNAME/.ssh && chmod 700 /home/$USERNAME/.ssh"

# Add SSH key if provided
if [[ -n "$SSH_PUBKEY" ]]; then
    pct exec $CTID -- bash -c "echo '$SSH_PUBKEY' >> /home/$USERNAME/.ssh/authorized_keys"
    pct exec $CTID -- bash -c "chmod 600 /home/$USERNAME/.ssh/authorized_keys"
fi

# Fix ownership
pct exec $CTID -- bash -c "chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh"

# Enable SSH service
pct exec $CTID -- bash -c "systemctl enable ssh && systemctl start ssh"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "============================================================"
echo "LEO LXC CONTAINER CREATED SUCCESSFULLY!"
echo ""
echo "Container ID: $CTID"
echo "Hostname: $HOSTNAME"
echo "IP Address: $IP_ADDRESS"
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Add your SSH key to leo (if not done above):"
echo "   ssh-copy-id $USERNAME@$IP_ADDRESS"
echo ""
echo "2. Update your .env file:"
echo "   LEO_IP=$IP_ADDRESS"
echo ""
echo "3. Run the Ansible playbook to complete setup:"
echo "   cd ~/Code/home-lab/ansible"
echo "   ansible-playbook playbooks/deploy-leo.yml"
echo ""
echo "4. SSH into leo and start using Claude:"
echo "   ssh $USERNAME@$IP_ADDRESS"
echo "   claude"
echo "============================================================"
