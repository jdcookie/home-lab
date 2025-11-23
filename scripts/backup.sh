#!/bin/bash
# Homelab Backup Script
# Backs up all Docker volumes and configurations

set -e

BACKUP_DIR="/opt/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"

echo "🔄 Starting homelab backup..."
echo "Backup location: ${BACKUP_PATH}"

mkdir -p "${BACKUP_PATH}"

# Backup Docker volumes
echo "📦 Backing up Docker volumes..."
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${BACKUP_PATH}":/backup \
    alpine sh -c "docker ps --format '{{.Names}}' | xargs -I {} docker run --rm --volumes-from {} -v ${BACKUP_PATH}:/backup alpine tar czf /backup/{}.tar.gz -C / \$(docker inspect --format '{{range .Mounts}}{{if eq .Type \"volume\"}}{{.Destination}} {{end}}{{end}}' {})"

# Backup compose files
echo "📄 Backing up compose files..."
tar czf "${BACKUP_PATH}/compose.tar.gz" -C /opt/homelab compose/

# Backup Ansible configurations (if running on Proxmox host)
if [ -d "/opt/homelab/ansible" ]; then
    echo "📄 Backing up Ansible configurations..."
    tar czf "${BACKUP_PATH}/ansible.tar.gz" -C /opt/homelab ansible/
fi

# Clean up old backups (keep last 30 days)
echo "🧹 Cleaning up old backups..."
find "${BACKUP_DIR}" -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \;

echo "✅ Backup complete: ${BACKUP_PATH}"
echo "Total size: $(du -sh ${BACKUP_PATH} | cut -f1)"
