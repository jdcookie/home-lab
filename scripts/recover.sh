#!/bin/bash
# Post-power-outage recovery script
# Run from the control node (leo) after all machines have powered on
# Usage: ./recover.sh

set -euo pipefail

SSH_KEY="$HOME/.ssh/homelab"
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -i $SSH_KEY"

# Host definitions
TRUENAS_IP="192.168.1.60"
RAPH_IP="192.168.1.136"
DONA_IP="192.168.1.137"
DOCKER_SERVICES_IP="192.168.1.50"
PIHOLE_IP="192.168.1.10"
CADDY_IP="192.168.1.11"

RAPH_USER="jcook"
DONA_USER="jcook"
DOCKER_USER="root"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}[OK]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[WAIT]${NC} $1"; }
step() { echo -e "\n${GREEN}==>${NC} $1"; }

# Wait for a host to be reachable via SSH
wait_for_host() {
    local user=$1 host=$2 name=$3
    local attempts=0 max_attempts=30

    while [ $attempts -lt $max_attempts ]; do
        if ssh $SSH_OPTS -o BatchMode=yes "${user}@${host}" 'true' 2>/dev/null; then
            ok "$name ($host) is reachable"
            return 0
        fi
        attempts=$((attempts + 1))
        warn "$name not ready yet... ($attempts/$max_attempts)"
        sleep 5
    done

    fail "$name ($host) unreachable after ${max_attempts} attempts"
    return 1
}

# Remount NFS on a host (if fstab has NFS entries)
remount_nfs() {
    local user=$1 host=$2 name=$3

    local has_nfs
    has_nfs=$(ssh $SSH_OPTS "${user}@${host}" 'grep -c nfs /etc/fstab 2>/dev/null || echo 0')

    if [ "$has_nfs" -gt 0 ]; then
        local mounted
        mounted=$(ssh $SSH_OPTS "${user}@${host}" 'mount | grep -c nfs || echo 0')

        if [ "$mounted" -lt "$has_nfs" ]; then
            warn "$name: $mounted/$has_nfs NFS mounts active, remounting..."
            ssh $SSH_OPTS "${user}@${host}" 'sudo mount -a' 2>&1
            mounted=$(ssh $SSH_OPTS "${user}@${host}" 'mount | grep -c nfs || echo 0')
        fi

        if [ "$mounted" -ge "$has_nfs" ]; then
            ok "$name: $mounted NFS mounts active"
        else
            fail "$name: only $mounted/$has_nfs NFS mounts came up"
            return 1
        fi
    else
        ok "$name: no NFS mounts configured"
    fi
}

# Restart docker containers on a host
restart_docker() {
    local user=$1 host=$2 name=$3

    local containers
    containers=$(ssh $SSH_OPTS "${user}@${host}" 'sudo docker ps -q' 2>/dev/null | wc -l)

    if [ "$containers" -gt 0 ]; then
        echo "  Restarting $containers containers on $name..."
        ssh $SSH_OPTS "${user}@${host}" 'sudo docker restart $(sudo docker ps -q)' 2>&1 | while read -r c; do
            echo "    restarted $c"
        done
        ok "$name: all containers restarted"
    else
        warn "$name: no running containers found"
    fi
}

# Verify a service is responding
check_service() {
    local url=$1 name=$2
    local code
    code=$(curl -sk --connect-timeout 5 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

    if [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; then
        ok "$name: HTTP $code"
    else
        fail "$name: HTTP $code"
    fi
}

# ============================================
# RECOVERY SEQUENCE
# ============================================

echo "========================================="
echo "  Homelab Post-Outage Recovery"
echo "========================================="

# Step 1: Wait for all hosts
step "Step 1: Checking host connectivity"
wait_for_host "admin" "$TRUENAS_IP" "TrueNAS" || true
wait_for_host "$RAPH_USER" "$RAPH_IP" "raph"
wait_for_host "$DONA_USER" "$DONA_IP" "dona"
wait_for_host "$DOCKER_USER" "$DOCKER_SERVICES_IP" "docker-services"

# Step 2: Verify PiHole DNS
step "Step 2: Checking PiHole DNS"
if ssh $SSH_OPTS "${RAPH_USER}@${PIHOLE_IP}" 'pihole status' 2>/dev/null | grep -q "blocking is enabled"; then
    ok "PiHole DNS active"
else
    fail "PiHole DNS not responding"
fi

# Step 3: Remount NFS (TrueNAS must be up first)
step "Step 3: Remounting NFS shares"
remount_nfs "$RAPH_USER" "$RAPH_IP" "raph"
remount_nfs "$DONA_USER" "$DONA_IP" "dona"
remount_nfs "$DOCKER_USER" "$DOCKER_SERVICES_IP" "docker-services"

# Step 4: Restart Docker containers so they pick up mounts
step "Step 4: Restarting Docker containers"
restart_docker "$RAPH_USER" "$RAPH_IP" "raph"
restart_docker "$DONA_USER" "$DONA_IP" "dona"
restart_docker "$DOCKER_USER" "$DOCKER_SERVICES_IP" "docker-services"

# Step 5: Wait for services to come up
step "Step 5: Waiting 15s for services to initialize..."
sleep 15

# Step 6: Verify key services
step "Step 6: Verifying services"
check_service "http://${PIHOLE_IP}/admin" "PiHole"
check_service "http://${CADDY_IP}" "Caddy"
check_service "http://${RAPH_IP}:8096" "Jellyfin"
check_service "http://${RAPH_IP}:5055" "Jellyseerr"
check_service "http://${RAPH_IP}:8989" "Sonarr"
check_service "http://${RAPH_IP}:7878" "Radarr"
check_service "http://${DONA_IP}:3000" "Homepage"
check_service "http://${DONA_IP}:8123" "Home Assistant"
check_service "http://${DONA_IP}:3001" "Uptime Kuma"
check_service "http://${DOCKER_SERVICES_IP}:2283" "Immich"

echo ""
echo "========================================="
echo "  Recovery complete!"
echo "========================================="
