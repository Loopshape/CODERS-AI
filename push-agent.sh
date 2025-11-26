#!/usr/bin/env bash
# push-agent.sh
# Usage: ./push-agent.sh <agent> <line>

AGENT="$1"
shift
TEXT="$*"

WEBUI="http://localhost:8080/push"

curl -s -X POST "$WEBUI" \
  -H "Content-Type: application/json" \
  -d "{\"agent\":\"$AGENT\",\"text\":\"$TEXT\"}" >/dev/null 2>&1

