#!/bin/bash
# Homelab Bootstrap Script
# Run this script on your control machine (laptop/workstation) to prepare for deployment

set -e

echo "================================================"
echo "Homelab Bootstrap Script"
echo "================================================"
echo ""

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    echo "❌ Ansible not found. Installing Ansible..."

    # Detect OS and install Ansible
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install ansible
        else
            echo "Please install Homebrew first: https://brew.sh"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux - use sudo if available and not root
        SUDO=""
        if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
            SUDO="sudo"
        fi

        if command -v apt-get &> /dev/null; then
            $SUDO apt-get update
            $SUDO apt-get install -y ansible
        elif command -v dnf &> /dev/null; then
            $SUDO dnf install -y ansible
        elif command -v yum &> /dev/null; then
            $SUDO yum install -y ansible
        else
            echo "Please install Ansible manually for your distribution"
            exit 1
        fi
    else
        echo "Unsupported operating system"
        exit 1
    fi
fi

echo "✅ Ansible $(ansible --version | head -n1)"
echo ""

# Install Ansible collections
echo "📦 Installing required Ansible collections..."
ansible-galaxy collection install community.general community.docker

# Create vault file if it doesn't exist
if [ ! -f ansible/inventory/group_vars/vault.yml ]; then
    echo ""
    echo "🔐 Creating encrypted vault file..."
    echo "You will be prompted to enter a vault password (save this securely!)"
    cp ansible/inventory/group_vars/vault.yml.example ansible/inventory/group_vars/vault.yml

    # Generate secure passwords
    PG_PASS=$(openssl rand -base64 32)
    SECRET_KEY=$(openssl rand -base64 50 | tr -d '=' | tr '+/' '-_')
    IMMICH_PASS=$(openssl rand -base64 32)
    PIHOLE_PASS=$(openssl rand -base64 16)

    # Update vault file with generated passwords
    sed -i.bak "s/CHANGE-ME-RANDOM-50-CHARS/$SECRET_KEY/" ansible/inventory/group_vars/vault.yml
    sed -i.bak "s/CHANGE-ME-SECURE-PASSWORD/$PG_PASS/" ansible/inventory/group_vars/vault.yml
    sed -i.bak "s/CHANGE-ME-CLIENT-SECRET/$(openssl rand -base64 32)/" ansible/inventory/group_vars/vault.yml

    # Encrypt the vault
    ansible-vault encrypt ansible/inventory/group_vars/vault.yml

    echo "✅ Vault file created and encrypted"
    rm ansible/inventory/group_vars/vault.yml.bak
fi

echo ""
echo "================================================"
echo "Bootstrap Complete! 🎉"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Update ansible/inventory/hosts.yml with your actual IP addresses"
echo "2. Ensure Proxmox is installed and accessible"
echo "3. Create LXC containers for PiHole and Caddy (or let Ansible do it)"
echo "4. Run: cd ansible && ansible-playbook playbooks/site.yml --ask-vault-pass"
echo ""
echo "For detailed instructions, see docs/setup-guide.md"
echo ""
