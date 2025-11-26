#!/usr/bin/env bash
# auto-discovery.sh – findet alle Worker im LAN automatisch

PORT="${1:-5544}"

echo "[DISCOVERY] Scanning LAN for workers on port $PORT ..."

# Lokale Netzmaske ermitteln
SUBNET=$(ip -4 addr show | grep -oP '(?<=inet ).*(?=/)' | head -n1)
BASE=$(echo "$SUBNET" | cut -d. -f1-3)

FOUND=()

for i in {1..254}; do
  IP="$BASE.$i"
  (echo "" | nc -w 1 "$IP" "$PORT" >/dev/null 2>&1) && {
     echo "[FOUND] Worker: $IP:$PORT"
     FOUND+=("$IP:$PORT")
  }
done

echo
echo "[DISCOVERY] Gefundene Worker:"
printf '%s\n' "${FOUND[@]}"

