# Home Lab Architecture

Quick reference for what's running where.

---

## Machines Overview

```
┌─────────────────────────────────────────────────────────────┐
│  leo (Proxmox)                                              │
│  ├── caddy (LXC) ─────────── Reverse Proxy                  │
│  ├── tailscale (LXC) ─────── VPN Subnet Router              │
│  ├── docker-services (VM) ── See services below             │
│  ├── truenas (VM) ────────── ZFS NAS, NFS exports           │
│  └── game-server (VM) ────── Satisfactory (off by default)  │
├─────────────────────────────────────────────────────────────┤
│  raph (Dell OptiPlex)                                       │
│  └── Docker ──────────────── Jellyfin, Arr Stack            │
├─────────────────────────────────────────────────────────────┤
│  dona (Dell OptiPlex)                                       │
│  └── Docker ──────────────── n8n, Uptime Kuma, Home         │
│                              Assistant, Netdata, Homepage   │
├─────────────────────────────────────────────────────────────┤
│  pi (Raspberry Pi 3B)                                       │
│  └── PiHole ──────────────── DNS + Ad Blocking              │
└─────────────────────────────────────────────────────────────┘
```

---

## leo → docker-services

| Service | Purpose |
|---------|---------|
| Immich | Photo management |
| ImmichFrame | Digital photo frame display |

---

## raph

| Service | Purpose |
|---------|---------|
| Jellyfin | Media streaming |
| Jellyseerr | Media requests |
| Sonarr | TV show management |
| Radarr | Movie management |
| Prowlarr | Indexer manager |
| qBittorrent | Downloads (via VPN) |
| Gluetun | VPN container (Mullvad) |

---

## dona

| Service | Purpose |
|---------|---------|
| N8N | Workflow automation |
| Uptime Kuma | Service monitoring |
| Home Assistant | Home automation |
| Netdata | System metrics |
| Homepage | Dashboard |

---

## pi

| Service | Purpose |
|---------|---------|
| PiHole | DNS + ad blocking |

---

## Infrastructure Services

| Service | Host | Purpose |
|---------|------|---------|
| Caddy | leo (LXC) | HTTPS reverse proxy, Let's Encrypt |
| Tailscale | leo (LXC) | VPN subnet router for remote access |
| TrueNAS | leo (VM) | ZFS storage, NFS exports |

---

## Storage (TrueNAS)

NFS exports mounted on docker-services:
- `/mnt/video` → Video library
- `/mnt/photos` → Photo library
- `/mnt/media` → Media library (arr stack)
