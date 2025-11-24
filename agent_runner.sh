#!/usr/bin/env bash
source "$(dirname "$0")/core.sh"

MODEL="gemma3:1b"
INDEX_HTML="$HOME/.ai/index.html"
STATE_DIR="$HOME/.ai/state"
HASH_FILE="$STATE_DIR/hashes.json"

run_agent() {
  if [[ ! -f "$INDEX_HTML" ]]; then
    log_error "index.html not found, bitte zuerst build_html ausführen."
    exit 1
  fi
  if [[ ! -f "$HASH_FILE" ]]; then
    log_error "Hash state nicht gefunden – bitte bauen Sie zuerst."
    exit 1
  fi

  local root_hash
  root_hash=$(jq -r '.root' "$HASH_FILE")

  local html_content
  html_content=$(< "$INDEX_HTML")

  local prompt=$(cat <<EOF
[UNIVERSAL_LAW]
RootHash: $root_hash

<<HTML-CONTENT-BEGIN>>
$html_content
<<HTML-CONTENT-END>>

You are in **NEXUS** mode. Your task:
1. Analyse the HTML content.
2. Decompose it into modular components aligned with a hash:rehash hierarchical tree.
3. For each component propose a child hash value timestamped.
4. Output a JSON structure with:
   - root: the root hash  
   - components: array of { "hash": "...", "filename": "...", "parent": root }  
   - optionally instructions for reorganizing snippets.

Then output an updated HTML skeleton, optimized for modular snippet usage. Use asynchronous loop semantics in your description.

Respond strictly in JSON and HTML, separated by a marker "---END---".
EOF
)

  log_info "Running agent with prompt..."
  echo "$prompt" | ollama run "$MODEL"
}

run_agent

