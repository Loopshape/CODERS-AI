#!/usr/bin/env bash
# token-bridge.sh
# Bidirektionales Token Streaming zwischen zwei Ollama-Instanzen

REMOTE="${1?Usage: ./token-bridge.sh <REMOTE_IP:PORT>}"
MODEL="${2:-core}"

while true; do
  echo -n "prompt> "
  read -r PROMPT

  curl -N -X POST "http://$REMOTE/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"$MODEL\", \"prompt\": \"$PROMPT\", \"stream\": true}" |
  while IFS= read -r line; do
      printf "%s" "$line"
  done

  echo ""
done

