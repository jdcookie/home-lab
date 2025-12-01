# Homelab Setup Guide

Complete step-by-step guide to deploy your homelab infrastructure.

## Prerequisites

- New homelab machine with Proxmox VE installed
- Control machine (laptop/workstation) with SSH access
- Network configuration:
  - Static IP for Proxmox host
  - Available IP addresses for services
  - Access to router for DNS configuration

## Phase 1: Initial Preparation (Day 0)

### 1. Install Proxmox VE

1. Download Proxmox VE ISO from https://www.proxmox.com/en/downloads
2. Create bootable USB with Etcher or Rufus
3. Boot new machine from USB
4. Follow installation wizard:
   - Set hostname (e.g., `pve.home.lab`)
   - Configure network (static IP)
   - Set root password
   - Complete installation and reboot

5. Access Proxmox web UI: `https://<PROXMOX_IP>:8006`
6. Update Proxmox:
   ```bash
   apt update && apt upgrade -y
   ```

### 2. Prepare Control Machine

1. Clone this repository:
   ```bash
   git clone <your-repo-url> ~/homelab
   cd ~/homelab
   ```

2. Configure environment:
   ```bash
   cp .env.example .env
   # Edit .env with your IP addresses and domain
   ```

3. Run bootstrap script:
   ```bash
   ./scripts/bootstrap.sh
   ```

   This will:
   - Install Ansible
   - Install required Ansible collections
   - Create encrypted vault file with generated passwords
   - Prepare environment

4. **IMPORTANT**: Save your vault password securely (password manager)

### 3. Configure Environment

Edit `.env` with your network configuration:

```bash
# Network
NETWORK_CIDR=192.168.1.0/24
GATEWAY_IP=192.168.1.1

# Host IPs
PROXMOX_IP=192.168.1.2
PIHOLE_IP=192.168.1.10
CADDY_IP=192.168.1.11
DOCKER_HOST_IP=192.168.1.50

# Domain
BASE_DOMAIN=example.com
HOMELAB_DOMAIN=lab.example.com
ADMIN_EMAIL=admin@example.com
```

## Phase 2: Create LXC Containers & VMs (Day 1)

### Option A: Manual Creation (Recommended for First Time)

#### Create PiHole LXC Container

1. In Proxmox web UI, click "Create CT"
2. Configuration:
   - CT ID: 100
   - Hostname: pihole
   - Template: debian-12-standard
   - Root password: (set securely)
   - CPU: 1 core
   - Memory: 512 MB
   - Network: Static IP (from your .env PIHOLE_IP)
   - Storage: 8 GB

3. Start container and install PiHole:
   ```bash
   pct enter 100
   curl -sSL https://install.pi-hole.net | bash
   ```

4. Follow PiHole installer, set admin password

#### Create Caddy LXC Container

1. Create CT with ID 101, hostname "caddy"
2. Configuration:
   - CPU: 1 core
   - Memory: 512 MB
   - Network: Static IP (from your .env CADDY_IP)
   - Storage: 4 GB

3. Container will be configured by Ansible later

#### Create Docker VM

1. Download Ubuntu 22.04 Server ISO to Proxmox
2. Create VM:
   - VM ID: 200
   - Name: docker-services
   - CPU: 4 cores
   - Memory: 8192 MB
   - Disk: 50 GB
   - Network: Static IP (from your .env DOCKER_HOST_IP)

3. Install Ubuntu Server (minimal installation)
4. Set up SSH access with your SSH key

### Option B: Automated Creation with Proxmox API (Advanced)

*To be implemented - manual creation recommended for now*

## Phase 3: Deploy Infrastructure (Day 2)

### Test Ansible Connectivity

```bash
cd ansible
ansible all -m ping --ask-vault-pass
```

You should see "pong" responses from all hosts.

### Deploy Everything

Run the main playbook:

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

This will:
1. Configure all hosts with common settings
2. Deploy and configure PiHole DNS
3. Deploy and configure Caddy reverse proxy
4. Install Docker on services VM
5. Deploy all services (Jellyfin, N8N, Portainer, Uptime Kuma)

**Duration**: ~30-45 minutes

### Verify Deployment

Check that all services are running:

```bash
# SSH to docker host
ssh root@<DOCKER_HOST_IP>

# Check running containers
docker ps

# You should see:
# - jellyfin
# - n8n
# - portainer
# - uptime-kuma
```

## Phase 4: Configure Services (Day 3)

### 1. Update Router DNS Settings

Configure your router to use PiHole as primary DNS:
- Primary DNS: <PIHOLE_IP>
- Secondary DNS: 1.1.1.1 (fallback)

**OR** manually configure DNS on each device.

### 2. Test DNS Resolution

```bash
nslookup jellyfin.<HOMELAB_DOMAIN> <PIHOLE_IP>
# Should resolve to <DOCKER_HOST_IP>
```

### 3. Configure Jellyfin

1. Access Jellyfin: `https://jellyfin.<HOMELAB_DOMAIN>`
2. Complete initial setup wizard
3. Create admin account
4. Add your media libraries

### 4. Configure N8N

1. Access N8N: `https://n8n.<HOMELAB_DOMAIN>`
2. Create admin account on first access
3. N8N is ready for workflow automation

### 5. Configure Portainer

1. Access Portainer: `https://portainer.<HOMELAB_DOMAIN>`
2. Create admin account
3. Connect to Docker endpoint (should be auto-detected)

### 6. Set Up Uptime Kuma Monitoring

1. Access Uptime Kuma: `https://status.<HOMELAB_DOMAIN>`
2. Create admin account
3. Add monitors for each service:
   - Jellyfin: https://jellyfin.<HOMELAB_DOMAIN>
   - N8N: https://n8n.<HOMELAB_DOMAIN>
   - Portainer: https://portainer.<HOMELAB_DOMAIN>
   - PiHole: https://pihole.<HOMELAB_DOMAIN>/admin
4. Configure notifications (email, Discord, etc.)

## Phase 5: Add Media to Jellyfin (Day 4)

### Mount Media Storage

If you have existing media on external drive or NAS:

```bash
# SSH to docker host
ssh root@<DOCKER_HOST_IP>

# Create mount point
mkdir -p /mnt/media

# Mount NFS share (example)
mount -t nfs 192.168.1.200:/mnt/media /mnt/media

# Or mount external drive
mount /dev/sdb1 /mnt/media

# Make permanent in /etc/fstab
echo "192.168.1.200:/mnt/media /mnt/media nfs defaults 0 0" >> /etc/fstab
```

### Add Library in Jellyfin

1. Access Jellyfin: `https://jellyfin.<HOMELAB_DOMAIN>`
2. Dashboard → Libraries → Add Library
3. Select content type (Movies, TV Shows, Music)
4. Add folder: `/media/Movies` (or your path)
5. Scan library

## Phase 6: Testing & Validation (Day 5)

### Test Checklist

- [ ] DNS resolution works for all services
- [ ] All services accessible via HTTPS
- [ ] Jellyfin can scan and play media
- [ ] N8N workflows execute correctly
- [ ] Uptime Kuma shows all services as UP
- [ ] Portainer shows all containers running

### Performance Testing

```bash
# Test DNS response time
dig @<PIHOLE_IP> jellyfin.<HOMELAB_DOMAIN>

# Test HTTPS connection
curl -I https://jellyfin.<HOMELAB_DOMAIN>

# Check Docker resource usage
docker stats
```

## Phase 7: Backups & Maintenance (Day 6)

### Set Up Automated Backups

SSH to docker host and set up cron job:

```bash
crontab -e

# Add daily backup at 2 AM
0 2 * * * /opt/homelab/scripts/backup.sh >> /var/log/homelab-backup.log 2>&1
```

### Test Backup

```bash
/opt/homelab/scripts/backup.sh
```

Check `/opt/backups/` for backup files.

### Create Proxmox Backup Schedule

1. In Proxmox web UI, go to Datacenter → Backup
2. Create backup job:
   - Schedule: Daily at 3 AM
   - Selection mode: All
   - Target: Local storage
   - Retention: Keep last 7 backups

### Maintenance Tasks

Weekly:
- Check Uptime Kuma for any service issues
- Review Portainer logs for errors
- Update Docker images: `./scripts/update-services.sh`

Monthly:
- Update Proxmox: `apt update && apt upgrade`
- Test backup restoration
- Review and rotate secrets in Ansible vault

## Troubleshooting

### Service Won't Start

```bash
# Check logs
docker compose logs -f <service>

# Check if port is already in use
netstat -tulpn | grep <port>

# Restart service
docker compose restart <service>
```

### DNS Not Resolving

```bash
# Check PiHole is running
pct status 100

# Test DNS directly
dig @<PIHOLE_IP> test.<HOMELAB_DOMAIN>

# Check PiHole logs
pct enter 100
pihole -t
```

### Can't Access Services via Domain Names

1. Check DNS is set to PiHole (<PIHOLE_IP>)
2. Verify Caddy is running: `pct status 101`
3. Check Caddy logs: `pct enter 101 && journalctl -u caddy -f`
4. Verify custom DNS records: `cat /etc/pihole/custom.list`

## Advanced Topics

### Adding New Services

1. Create `compose/<service-name>/docker-compose.yml`
2. Create Ansible role in `ansible/roles/<service-name>/`
3. Add service to `ansible/playbooks/deploy-docker-services.yml`
4. Add DNS entry to `ansible/templates/pihole-custom.list.j2`
5. Add reverse proxy config to `ansible/templates/Caddyfile.j2`
6. Run playbook: `ansible-playbook playbooks/site.yml --ask-vault-pass`

### Scaling Up

To add more Docker hosts:
1. Create new VM in Proxmox
2. Add to inventory under `docker_hosts`
3. Run playbook to configure

### Migrating to TrueNAS

When ready to set up TrueNAS for storage:
1. Create TrueNAS VM (8GB RAM, 4 cores)
2. Install TrueNAS Scale
3. Create ZFS pools
4. Export NFS shares
5. Mount in Docker host and update Jellyfin/Immich volumes

## DNS Configuration Options

You have **3 options** for DNS setup. Choose based on your needs:

### Option 1: Internal-Only Access (Easiest)

**Best for**: Testing, local network only

PiHole already handles internal DNS - no additional setup needed. Services accessible only on your home network with self-signed SSL certificates.

### Option 2: External Access via Port Forward

**Best for**: Accessing from anywhere without VPN

1. Add DNS record to your domain:
   ```
   Type: A
   Name: *.lab
   Value: YOUR_PUBLIC_IP
   ```

2. Forward ports on your router:
   ```
   80 (HTTP)  → <CADDY_IP>:80
   443 (HTTPS) → <CADDY_IP>:443
   ```

3. Caddy automatically gets Let's Encrypt certificates

**Security**: Use strong passwords, keep services updated.

### Option 3: VPN Access (Tailscale) - Recommended

**Best for**: Secure remote access without exposing services

1. Install Tailscale on Caddy LXC:
   ```bash
   pct enter 101
   curl -fsSL https://tailscale.com/install.sh | sh
   tailscale up
   ```

2. Install Tailscale on your devices
3. Access services via Tailscale IP - no port forwarding needed

### Testing DNS

```bash
# Test internal DNS
dig @<PIHOLE_IP> jellyfin.<HOMELAB_DOMAIN>

# Test HTTPS access
curl -I https://jellyfin.<HOMELAB_DOMAIN>
```

## Next Steps

- Set up off-site backups
- Configure VPN access (Tailscale/WireGuard)
- Add more services (Radarr, Sonarr, etc.)
- Implement monitoring with Prometheus/Grafana
- Set up automated certificate management

---

**Questions or issues?** Review the `docs/architecture.md` design document or check container logs for troubleshooting.
