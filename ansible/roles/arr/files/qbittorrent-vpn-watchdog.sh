#!/usr/bin/env bash
# Restart qBittorrent when it has lost its listen socket on the VPN tunnel.
#
# Gluetun recreates tun0 when its healthcheck fails, and qBittorrent does not
# always rebind afterwards. Peers then can't connect and every torrent stalls,
# even though gluetun reports healthy and egress from the container still works.
#
# Needs two consecutive misses so a tunnel restart in progress doesn't trigger it.

set -euo pipefail

state_file=/run/qbittorrent-vpn-watchdog.misses
max_misses=2

# No tunnel means gluetun is down or mid-restart. Restarting qBittorrent won't help.
tun_ip=$(docker exec gluetun ip -4 -o addr show dev tun0 2>/dev/null | awk '{split($4, a, "/"); print a[1]}') || true
if [[ -z "$tun_ip" ]]; then
    echo "tun0 not up in gluetun, skipping check"
    rm -f "$state_file"
    exit 0
fi

# qBittorrent not running is left alone, it may have been stopped on purpose.
if ! sockets=$(docker exec qbittorrent cat /proc/net/tcp 2>/dev/null); then
    echo "qbittorrent not running, skipping check"
    rm -f "$state_file"
    exit 0
fi

# /proc/net/tcp holds IPv4 addresses as little-endian hex.
IFS=. read -r a b c d <<< "$tun_ip"
tun_hex=$(printf '%02X%02X%02X%02X' "$d" "$c" "$b" "$a")

# State 0A is LISTEN.
if awk -v addr="$tun_hex" 'index($2, addr ":") == 1 && $4 == "0A" { found = 1 } END { exit !found }' <<< "$sockets"; then
    rm -f "$state_file"
    exit 0
fi

misses=$(( $(cat "$state_file" 2>/dev/null || echo 0) + 1 ))
echo "qbittorrent has no listen socket on tun0 ($tun_ip), miss $misses of $max_misses"

if (( misses < max_misses )); then
    echo "$misses" > "$state_file"
    exit 0
fi

echo "restarting qbittorrent"
rm -f "$state_file"
docker restart qbittorrent
