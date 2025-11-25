#!/bin/bash
FILE="$1"
OLLAMA_HOST="${OLLAMA_HOST:-localhost:11434}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
    echo "Usage: $0 <file>"
    exit 1
fi
CONTENT=$(cat "$FILE")
curl -s -X POST "http://$OLLAMA_HOST/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"code\",\"prompt\":\"Enhance this code:\\n$CONTENT\",\"stream\":false}" | jq -r '.response'
