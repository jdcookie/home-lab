#!/bin/bash
# Update all Docker services to latest images

set -e

COMPOSE_DIR="/opt/homelab/compose"

echo "🔄 Updating all homelab services..."
echo ""

for service_dir in "${COMPOSE_DIR}"/*; do
    if [ -d "$service_dir" ] && [ -f "$service_dir/docker-compose.yml" ]; then
        service_name=$(basename "$service_dir")
        echo "📦 Updating $service_name..."

        cd "$service_dir"
        docker compose pull
        docker compose up -d
        echo "✅ $service_name updated"
        echo ""
    fi
done

echo "🧹 Cleaning up unused images..."
docker image prune -f

echo ""
echo "✅ All services updated!"
