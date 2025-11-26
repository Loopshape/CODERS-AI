#!/usr/bin/env bash
# work.sh – Worker-Knoten für ai.sh Cluster

PORT="${1:-5544}"
AI="./ai.sh"

echo "[WORKER] Listening on port $PORT ..."
while true; do
  nc -l -p "$PORT" -q 1 | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "[WORKER] Prompt erhalten: $line"
    echo "$line" | $AI
  done
done

