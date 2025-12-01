# Homelab 2.0 - Infrastructure as Code Design

## Executive Summary

This document outlines a modern, maintainable homelab infrastructure using **Infrastructure as Code (IaC)** principles. The design leverages Proxmox as the hypervisor with automated provisioning via Ansible, and containerized services using Docker Compose.

**Key Design Principles:**
- **Infrastructure as Code**: All configurations stored in Git, reproducible deployments
- **Automated Provisioning**: Ansible-driven setup and configuration management
- **Container-First**: Docker Compose for service orchestration (familiar, mature, well-documented)
- **Local DNS Resolution**: PiHole + Caddy for internal service discovery
- **Maintainability**: Simple, documented, version-controlled infrastructure

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Proxmox Hypervisor                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Infrastructure Services (LXC/VM)                         │  │
│  │  ├─ PiHole (LXC) - DNS + Ad Blocking                     │  │
│  │  └─ Caddy (LXC) - Reverse Proxy                          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Media & Application Services                             │  │
│  │  ├─ Jellyfin (Docker) - Media Server                     │  │
│  │  ├─ N8N (Docker) - Workflow Automation                   │  │
│  │  ├─ Immich (Docker) - Photo Management [Future]          │  │
│  │  └─ TrueNAS (VM) - Storage Management [Future]           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Management & Monitoring                                   │  │
│  │  ├─ Portainer (Docker) - Container Management            │  │
│  │  ├─ Uptime Kuma (Docker) - Service Monitoring            │  │
│  │  └─ Ansible Control (Optional) - Automation              │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack Decisions

### Container Platform: Docker Compose (Not Podman - Yet)

**Recommendation: Stick with Docker Compose**

**Reasoning:**
- ✅ **Mature Ecosystem**: Extensive community support, proven in production
- ✅ **Familiar**: You already know Docker well
- ✅ **Comprehensive Documentation**: Better service documentation and examples
- ✅ **Authentik Support**: Better tested with Docker
- ✅ **Compose Files**: Declarative, version-controlled service definitions
- ✅ **Portainer Integration**: Excellent Docker management UI

**Podman Considerations:**
- ⚠️ **Rootless by Default**: Security benefit but compatibility challenges
- ⚠️ **Systemd Integration**: Different service management paradigm
- ⚠️ **Docker Compose Support**: Improving but not 100% compatible
- ⚠️ **Service Discovery**: Networking behaves differently than Docker
- 💡 **Future Migration**: Can migrate later once Podman ecosystem matures

**Verdict**: Use Docker Compose now, consider Podman in 1-2 years when ecosystem stabilizes.

---

### Infrastructure as Code: Ansible

**Why Ansible over Terraform/Other Options:**

| Tool | Pros | Cons | Verdict |
|------|------|------|---------|
| **Ansible** | ✅ Agentless, idempotent, excellent for configuration management, YAML-based, great Proxmox modules | ⚠️ Not ideal for cloud infrastructure | **RECOMMENDED** |
| Terraform | ✅ Great for cloud resources, state management | ❌ Requires Proxmox provider, less suited for config management | Not ideal for homelab |
| Pulumi | ✅ Real programming languages | ❌ Overkill for homelab, steeper learning curve | Overkill |
| Shell Scripts | ✅ Simple, direct | ❌ Not idempotent, error-prone, hard to maintain | Avoid |

**Ansible Strategy:**
1. **Proxmox VM/LXC Provisioning**: Create and configure containers/VMs
2. **Service Configuration**: Install Docker, configure networking, deploy services
3. **Docker Compose Deployment**: Template and deploy compose files
4. **DNS Updates**: Automatically update PiHole DNS records
5. **Backup Configuration**: Automated backup schedules

---

## Service Architecture

### Core Infrastructure Services

#### 1. PiHole - DNS & Ad Blocking
```yaml
Type: LXC Container (lightweight, efficient for DNS)
Resources: 512MB RAM, 1 CPU core, 8GB storage
DNS: 192.168.1.10 (example)
Domain: pihole.<HOMELAB_DOMAIN>
```

**Features:**
- Local DNS resolution for `.<HOMELAB_DOMAIN>` domain
- Ad blocking and tracker blocking
- DHCP server (optional, can replace router DHCP)
- DNS record management via API (for automation)

**Integration:**
- Ansible updates DNS records automatically
- Custom DNS entries for all services
- Fallback to public DNS (1.1.1.1, 8.8.8.8)

---

#### 2. Caddy - Reverse Proxy
```yaml
Type: LXC Container
Resources: 512MB RAM, 1 CPU core, 4GB storage
URL: proxy.<HOMELAB_DOMAIN>
Ports: 80, 443
```

**Features:**
- Automatic HTTPS with internal CA
- Reverse proxy for all web services
- Easy configuration via Caddyfile
- Automatic service discovery (optional)

**Configuration Strategy:**
- Template-based Caddyfile (Jinja2 in Ansible)
- Git-tracked configuration
- Automatic reload on changes

**Example Caddyfile:**
```caddy
{
    auto_https internal
    email admin@example.com
}

jellyfin.<HOMELAB_DOMAIN> {
    reverse_proxy 192.168.1.100:8096
}

immich.<HOMELAB_DOMAIN> {
    reverse_proxy 192.168.1.101:2283
}

```

---

### Media & Application Services

#### 4. Jellyfin - Media Server
```yaml
Type: Docker Compose
Resources: 4GB RAM, 2-4 CPU cores (for transcoding), 20GB storage (+ media mount)
URL: jellyfin.<HOMELAB_DOMAIN>
Ports: 8096
GPU: Optional hardware acceleration (Intel QuickSync, NVIDIA)
```

**Features:**
- Media streaming (movies, TV shows, music)
- Hardware transcoding support
- Multiple user profiles
- Mobile apps available

**Docker Compose:**
```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    environment:
      - TZ=America/New_York
    volumes:
      - ./config:/config
      - ./cache:/cache
      - /mnt/media:/media:ro
    ports:
      - 8096:8096
    devices:
      - /dev/dri:/dev/dri  # Hardware acceleration (Intel)
    restart: unless-stopped
```

---

#### 5. N8N - Workflow Automation
```yaml
Type: Docker Compose
Resources: 1GB RAM, 1-2 CPU cores, 5GB storage
URL: n8n.<HOMELAB_DOMAIN>
Ports: 5678
```

**Features:**
- Visual workflow automation
- 400+ integrations
- Self-hosted alternative to Zapier
- Webhook support for external triggers

**Docker Compose:**
```yaml
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    environment:
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=${WEBHOOK_URL}
      - GENERIC_TIMEZONE=${TZ}
    volumes:
      - n8n_data:/home/node/.n8n
    ports:
      - 5678:5678
    restart: unless-stopped
```

---

#### 6. Immich - Photo Management [Future]

**Note**: Requires additional storage drives. Will be deployed after TrueNAS setup.

```yaml
Type: Docker Compose
Resources: 2GB RAM, 2 CPU cores, 20GB storage (+ photo storage)
URL: immich.<HOMELAB_DOMAIN>
Ports: 2283
Database: PostgreSQL (dedicated)
ML: Optional machine learning for face detection
```

**Features:**
- Google Photos alternative
- Mobile auto-backup
- Face recognition (optional)
- Timeline and album organization

---

#### 7. TrueNAS Scale (Future)
```yaml
Type: VM
Resources: 8GB RAM minimum, 4 CPU cores, 50GB boot disk
URL: truenas.<HOMELAB_DOMAIN>
Purpose: ZFS storage management, SMB/NFS shares
```

**Integration:**
- NFS exports for media storage
- SMB shares for general storage
- Integration with Proxmox backup
- TrueNAS provides storage datasets for:
  - Jellyfin media library
  - Immich photo storage
  - General file shares
  - Backup targets

**Note**: Set up after acquiring storage drives.

---

### Management Services

#### 7. Portainer - Container Management
```yaml
Type: Docker Compose
Resources: 512MB RAM, 1 CPU core
URL: portainer.<HOMELAB_DOMAIN>
Ports: 9000
```

**Features:**
- Web UI for Docker management
- Stack deployment (compose files)
- Container logs and stats

---

#### 8. Uptime Kuma - Service Monitoring
```yaml
Type: Docker Compose
Resources: 512MB RAM, 1 CPU core
URL: status.<HOMELAB_DOMAIN>
Ports: 3001
```

**Features:**
- Service uptime monitoring
- Status page
- Notifications (email, Discord, etc.)
- Beautiful UI

---

## Infrastructure as Code Structure

### Repository Layout

```
home-lab/
├── README.md
├── homelab2.md                    # This document
├── ansible/
│   ├── ansible.cfg                # Ansible configuration
│   ├── inventory/
│   │   ├── hosts.yml              # Inventory of hosts
│   │   └── group_vars/
│   │       ├── all.yml            # Global variables
│   │       └── proxmox.yml        # Proxmox-specific vars
│   ├── playbooks/
│   │   ├── site.yml               # Main orchestration playbook
│   │   ├── provision-infrastructure.yml
│   │   ├── deploy-pihole.yml
│   │   ├── deploy-caddy.yml
│   │   ├── deploy-authentik.yml
│   │   ├── deploy-jellyfin.yml
│   │   ├── deploy-immich.yml
│   │   └── update-dns.yml
│   ├── roles/
│   │   ├── common/                # Base system configuration
│   │   ├── docker/                # Docker installation
│   │   ├── pihole/                # PiHole setup
│   │   ├── caddy/                 # Caddy reverse proxy
│   │   ├── jellyfin/              # Jellyfin media server
│   │   └── immich/                # Immich photo management
│   └── templates/
│       ├── Caddyfile.j2           # Templated Caddyfile
│       ├── docker-compose.*.j2    # Templated compose files
│       └── pihole-custom.list.j2  # DNS records template
├── compose/
│   ├── jellyfin/
│   │   ├── docker-compose.yml
│   │   └── .env.example
│   ├── immich/
│   │   ├── docker-compose.yml
│   │   └── .env.example
│   └── monitoring/
│       ├── docker-compose.yml     # Portainer, Uptime Kuma
│       └── .env.example
├── scripts/
│   ├── bootstrap.sh               # Initial setup script
│   ├── backup.sh                  # Backup automation
│   └── update-dns.sh              # DNS record updates
└── docs/
    ├── setup-guide.md             # Step-by-step setup
    ├── service-configuration.md   # Service-specific docs
    └── troubleshooting.md         # Common issues
```

---

## Provisioning Workflow

### Initial Setup Flow

```
1. Install Proxmox on bare metal
   └─> Configure network, storage pools, updates

2. Bootstrap Ansible controller
   └─> Install Ansible on laptop/workstation
   └─> Clone home-lab repository
   └─> Configure inventory with Proxmox credentials

3. Run infrastructure provisioning
   └─> ansible-playbook playbooks/provision-infrastructure.yml
   └─> Creates LXC containers for PiHole, Caddy
   └─> Creates VMs for Docker hosts

4. Deploy core services
   └─> ansible-playbook playbooks/deploy-pihole.yml
   └─> ansible-playbook playbooks/deploy-caddy.yml
5. Configure DNS and reverse proxy
   └─> Update PiHole DNS records
   └─> Configure Caddyfile with service entries
   └─> Test DNS resolution

6. Deploy application services
   └─> ansible-playbook playbooks/deploy-jellyfin.yml
   └─> ansible-playbook playbooks/deploy-immich.yml

7. Configure SSO integrations
   └─> Set up Authentik applications
   └─> Configure OIDC/LDAP in each service
   └─> Test authentication flow

8. Set up monitoring and backups
   └─> Deploy Uptime Kuma, Portainer
   └─> Configure backup schedules
   └─> Test restore procedures
```

---

## Network Architecture

### IP Address Scheme

```
Network: 192.168.1.0/24 (example - adjust to your network)

Infrastructure:
├─ 192.168.1.1       Router/Gateway
├─ 192.168.1.2       Proxmox Host
├─ 192.168.1.10      PiHole (LXC)
├─ 192.168.1.11      Caddy (LXC)

Services:
├─ 192.168.1.100     Jellyfin (Docker/VM)
├─ 192.168.1.105     N8N (Docker/VM)
├─ 192.168.1.110     Portainer (Docker/VM)
├─ 192.168.1.111     Uptime Kuma (Docker/VM)

Future:
├─ 192.168.1.101     Immich (Docker/VM)
└─ 192.168.1.200     TrueNAS (VM)
```

### DNS Records (PiHole)

```
# Core Infrastructure
192.168.1.2    proxmox.<HOMELAB_DOMAIN>
192.168.1.10   pihole.<HOMELAB_DOMAIN>
192.168.1.11   proxy.<HOMELAB_DOMAIN>

# Services
192.168.1.100  jellyfin.<HOMELAB_DOMAIN>
192.168.1.105  n8n.<HOMELAB_DOMAIN>
192.168.1.110  portainer.<HOMELAB_DOMAIN>
192.168.1.111  status.<HOMELAB_DOMAIN>

# Future
192.168.1.101  immich.<HOMELAB_DOMAIN>
192.168.1.200  truenas.<HOMELAB_DOMAIN>
```

### Port Mapping

| Service | Internal Port | External Access | Protocol |
|---------|---------------|-----------------|----------|
| Proxmox | 8006 | Direct IP | HTTPS |
| PiHole Admin | 80/443 | pihole.<HOMELAB_DOMAIN> | HTTP/HTTPS |
| Caddy | 80/443 | proxy.<HOMELAB_DOMAIN> | HTTP/HTTPS |
| Jellyfin | 8096 | jellyfin.<HOMELAB_DOMAIN> | HTTP (proxied) |
| N8N | 5678 | n8n.<HOMELAB_DOMAIN> | HTTP (proxied) |
| Portainer | 9000 | portainer.<HOMELAB_DOMAIN> | HTTP (proxied) |

**All external access goes through Caddy reverse proxy.**

---

## Making Changes: GitOps Workflow

### Philosophy: Everything in Git

**Rule**: If it's not in Git, it doesn't exist.

### Change Workflow

```
1. Make changes locally
   └─> Edit Ansible playbook, role, or template
   └─> Update compose files or configurations
   └─> Commit changes to Git

2. Test changes
   └─> Run ansible-playbook with --check (dry-run)
   └─> Review planned changes
   └─> Optionally test in isolated VM

3. Apply changes
   └─> Run ansible-playbook playbooks/site.yml
   └─> Ansible applies changes idempotently
   └─> Services automatically updated

4. Verify and document
   └─> Test service functionality
   └─> Update documentation if needed
   └─> Push changes to remote Git repository
```

### Example: Adding a New Service

```bash
# 1. Create compose file
vim compose/radarr/docker-compose.yml

# 2. Create Ansible role
mkdir -p ansible/roles/radarr
vim ansible/roles/radarr/tasks/main.yml

# 3. Update playbook
vim ansible/playbooks/deploy-radarr.yml

# 4. Add DNS entry
vim ansible/templates/pihole-custom.list.j2
# Add: 192.168.1.105  radarr.<HOMELAB_DOMAIN>

# 5. Update Caddyfile
vim ansible/templates/Caddyfile.j2
# Add reverse proxy block

# 6. Commit changes
git add .
git commit -m "Add Radarr service"

# 7. Deploy
ansible-playbook ansible/playbooks/site.yml --tags radarr
```

---

## Security Considerations

### Authentication & Authorization
- ✅ Strong password policies
- ✅ Optional 2FA/MFA support per service

### Network Security
- ✅ Internal-only access (no external exposure)
- ✅ Firewall rules on Proxmox host
- ✅ Separate VLANs for sensitive services (optional)
- ✅ Regular security updates via Ansible

### Secrets Management
- ✅ `.env` files for compose secrets (Git-ignored)
- ✅ Ansible Vault for sensitive variables
- ✅ Template-based secret injection
- ✅ Regular secret rotation

**Example Ansible Vault Usage:**
```bash
# Create encrypted vault
ansible-vault create ansible/inventory/group_vars/vault.yml

# Edit vault
ansible-vault edit ansible/inventory/group_vars/vault.yml

# Run playbook with vault
ansible-playbook playbooks/site.yml --ask-vault-pass
```

### Backup Strategy
- ✅ Automated daily backups via Ansible cron
- ✅ Proxmox backup and replication
- ✅ Configuration stored in Git
- ✅ Off-site backup to external drive or cloud

---

## Migration & Deployment Plan

### Day 1: Proxmox Installation
```
1. Install Proxmox VE on new hardware
2. Configure networking and storage
3. Update system packages
4. Create storage pools (local, backup)
5. Configure Proxmox backup schedules
```

### Day 2: Core Infrastructure
```
1. Clone home-lab repository
2. Configure Ansible inventory
3. Run provision-infrastructure.yml
   └─> Creates PiHole LXC
   └─> Creates Caddy LXC
4. Deploy PiHole and Caddy
5. Update router DHCP to use PiHole DNS
6. Test DNS resolution
```

### Day 3-4: Application Services
```
1. Deploy Jellyfin
   └─> Add media libraries
2. Deploy N8N
   └─> Configure workflows
3. Deploy Portainer
```

### Day 5: Monitoring & Hardening
```
1. Deploy Uptime Kuma
2. Configure service health checks
3. Set up backup automation
4. Test restore procedures
5. Document everything
```

### Future: TrueNAS Integration
```
1. Acquire storage drives
2. Create TrueNAS VM
3. Configure ZFS pools
4. Set up NFS/SMB exports
5. Migrate media storage to TrueNAS
6. Configure backup targets
```

---

## Maintenance & Operations

### Regular Maintenance Tasks

**Weekly:**
- Review Uptime Kuma status
- Check for service updates
- Review logs for errors

**Monthly:**
- Run Ansible playbooks to ensure configuration drift is corrected
- Update Docker images (`docker compose pull`)
- Test backup restoration
- Review and rotate secrets

**Quarterly:**
- Update Proxmox VE
- Review and update Ansible roles
- Performance tuning and capacity planning
- Security audit

### Ansible Maintenance Commands

```bash
# Check configuration drift
ansible-playbook playbooks/site.yml --check

# Apply all configurations (idempotent)
ansible-playbook playbooks/site.yml

# Update specific service
ansible-playbook playbooks/deploy-jellyfin.yml

# Update DNS records
ansible-playbook playbooks/update-dns.yml

# Backup all services
ansible-playbook playbooks/backup.yml
```

---

## Cost Analysis

### Time Investment
- **Initial Setup**: 20-30 hours (spread over 1-2 weeks)
- **Learning Ansible**: 5-10 hours (if new to Ansible)
- **Ongoing Maintenance**: 2-4 hours/month

### Financial Cost
- **Homelab Hardware**: Sunk cost (already purchased)
- **Domain Name**: $0 (using `.<HOMELAB_DOMAIN>` local domain)
- **Software**: $0 (all open source)
- **Storage**: Variable (TrueNAS drives)

### Value Delivered
- ✅ Reproducible infrastructure (rebuild in hours, not days)
- ✅ Version-controlled configuration
- ✅ Unified authentication (password management simplified)
- ✅ Professional homelab setup
- ✅ Learning opportunity (Ansible, Docker, networking)

---

## Comparison: This Design vs Alternatives

| Approach | Pros | Cons |
|----------|------|------|
| **Ansible + Docker Compose** | ✅ Declarative, version-controlled, idempotent, mature tooling | ⚠️ Learning curve for Ansible |
| Kubernetes (K3s) | ✅ Industry standard, powerful orchestration | ❌ Overkill for homelab, complex, high resource usage |
| Portainer Stacks | ✅ Easy UI, quick setup | ❌ Not version-controlled, manual changes, no IaC |
| Pure Docker CLI | ✅ Simple, direct | ❌ Not reproducible, error-prone, manual |
| Proxmox VM per Service | ✅ Complete isolation | ❌ High resource usage, slow provisioning |
| LXC per Service | ✅ Lightweight | ❌ No Docker benefits, manual configuration |

**Verdict**: Ansible + Docker Compose strikes the best balance for a homelab.

---

## Next Steps

### Immediate Actions (This Week)
1. ✅ Read this document thoroughly
2. ⬜ Set up Git repository structure
3. ⬜ Install Proxmox on new hardware
4. ⬜ Install Ansible on control machine (laptop)
5. ⬜ Create basic inventory and variables

### Short-Term (Next 2 Weeks)
6. ⬜ Provision PiHole and Caddy LXC containers
7. ⬜ Deploy Jellyfin
8. ⬜ Set up monitoring and backups

### Long-Term (1-3 Months)
11. ⬜ Acquire storage drives for TrueNAS
12. ⬜ Deploy TrueNAS VM
13. ⬜ Migrate media storage to ZFS
14. ⬜ Deploy Immich for photo management
15. ⬜ Add additional services (Radarr, Sonarr, etc.)
16. ⬜ Refine automation and monitoring

---

## Resources & References

### Documentation
- [Ansible Docs](https://docs.ansible.com/)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [PiHole Documentation](https://docs.pi-hole.net/)

### Community Resources
- [r/selfhosted](https://reddit.com/r/selfhosted)
- [r/homelab](https://reddit.com/r/homelab)
- [Awesome Selfhosted List](https://github.com/awesome-selfhosted/awesome-selfhosted)

### Example Ansible Roles
- [geerlingguy/ansible-role-docker](https://github.com/geerlingguy/ansible-role-docker)
- [geerlingguy/ansible-role-pip](https://github.com/geerlingguy/ansible-role-pip)

---

## Questions & Decisions Needed

Before proceeding, please decide:

1. **Network Configuration**:
   - What is your current network subnet? (e.g., 192.168.1.0/24)
   - Do you want static IPs or DHCP reservations?
   - Will PiHole handle DHCP or just DNS?

2. **Storage**:
   - Where will media files be stored initially? (Local disk, NAS, external?)
   - What size storage do you have for Docker volumes?

3. **Backup**:
   - Do you have external storage for backups?
   - How often do you want automated backups?

4. **Ansible Control Node**:
   - Will you run Ansible from your laptop/workstation?
   - Or do you want a dedicated Ansible VM?

---

## Conclusion

This design provides a **modern, maintainable, and professional homelab infrastructure** using industry-standard tools and practices. By leveraging Infrastructure as Code with Ansible and Docker Compose, you ensure that your homelab is:

- **Reproducible**: Rebuild entire infrastructure from scratch in hours
- **Version-Controlled**: All changes tracked in Git
- **Maintainable**: Clear structure and documentation
- **Scalable**: Easy to add new services
- **Secure**: HTTPS everywhere via Caddy
- **Professional**: Follows DevOps and SRE best practices

The investment in learning Ansible and setting up this infrastructure will pay dividends in reduced maintenance burden, faster service deployment, and increased reliability.

**Good luck with your new homelab! 🎉**

---

## Appendix A: Quick Reference Commands

```bash
# Ansible Commands
ansible-playbook playbooks/site.yml                    # Deploy everything
ansible-playbook playbooks/site.yml --check            # Dry-run
ansible-playbook playbooks/site.yml --tags pihole      # Deploy specific service
ansible-playbook playbooks/backup.yml                  # Run backups

# Docker Commands
docker compose up -d                                    # Start services
docker compose down                                     # Stop services
docker compose pull                                     # Update images
docker compose logs -f [service]                        # View logs

# Proxmox Commands
pct list                                                # List containers
qm list                                                 # List VMs
pct start 100                                           # Start container
pct stop 100                                            # Stop container

# Git Commands
git status                                              # Check status
git add .                                               # Stage changes
git commit -m "message"                                 # Commit
git push                                                # Push to remote
```

---

**Document Version**: 1.0
**Last Updated**: 2025-01-19
**Author**: Home Lab Infrastructure Design
**Status**: Ready for Implementation
