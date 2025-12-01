# Home Lab Infrastructure

Modern homelab infrastructure managed with Infrastructure as Code using Ansible and Docker Compose.

## Architecture

- **Hypervisor**: Proxmox VE
- **Automation**: Ansible
- **DNS**: PiHole
- **Reverse Proxy**: Caddy

## Services

**Core**: PiHole, Caddy
**Applications**: Jellyfin, N8N, Portainer, Uptime Kuma
**Future**: Immich (requires additional storage)

## Quick Start

```bash
# 1. Clone and configure
git clone <your-repo-url> ~/homelab
cd ~/homelab
cp .env.example .env
# Edit .env with your IPs and domain

# 2. Bootstrap
./scripts/bootstrap.sh

# 3. Create containers in Proxmox (see docs/setup-guide.md)

# 4. Deploy
cd ansible
ansible-playbook playbooks/site.yml --ask-vault-pass
```

## Configuration

All settings are in `.env`. Key variables:

```bash
PROXMOX_IP=192.168.1.2
PIHOLE_IP=192.168.1.10
CADDY_IP=192.168.1.11
DOCKER_HOST_IP=192.168.1.50
HOMELAB_DOMAIN=lab.example.com
ADMIN_EMAIL=admin@example.com
```

## Repository Structure

```
├── ansible/           # Playbooks, roles, inventory
├── compose/           # Docker Compose files
├── scripts/           # Bootstrap, backup, update
├── docs/              # Detailed documentation
└── .env.example       # Configuration template
```

## Common Operations

```bash
# Deploy all services
ansible-playbook playbooks/site.yml --ask-vault-pass

# Update services
ssh root@<DOCKER_HOST_IP> /opt/homelab/scripts/update-services.sh

# Backup
ssh root@<DOCKER_HOST_IP> /opt/homelab/scripts/backup.sh

# Check status
ssh root@<DOCKER_HOST_IP> docker ps
```

## Service URLs

Replace with your domain:
- **Jellyfin**: https://jellyfin.lab.example.com
- **N8N**: https://n8n.lab.example.com
- **Portainer**: https://portainer.lab.example.com
- **Uptime Kuma**: https://status.lab.example.com
- **PiHole**: https://pihole.lab.example.com/admin

## Documentation

- **[docs/setup-guide.md](docs/setup-guide.md)** - Complete deployment guide with DNS configuration
- **[docs/architecture.md](docs/architecture.md)** - Design decisions and technical architecture

## Security

- Secrets in Ansible Vault (`ansible/inventory/group_vars/vault.yml`)
- Automatic HTTPS via Caddy

```bash
# Edit vault
ansible-vault edit ansible/inventory/group_vars/vault.yml
```

## Troubleshooting

```bash
# DNS not resolving
dig @<PIHOLE_IP> jellyfin.<HOMELAB_DOMAIN>

# Service won't start
docker compose -f /opt/homelab/compose/<service>/docker-compose.yml logs

# Check Caddy
pct status 101
```

## License

MIT License

---

**Built for learning and self-hosting**
