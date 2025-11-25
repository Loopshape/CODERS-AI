#!/usr/bin/env bash
source "$(dirname "$0")/core.sh"

SNIPPET_DIR="$HOME/.ai/snippets"
STATE_DIR="$HOME/.ai/state"
HASH_FILE="$STATE_DIR/hashes.json"
BUILD_FILE="$HOME/.ai/index.html"

build_html() {
  log_info "Building HTML from snippets..."
  # Konkateniere Teile in definierter Reihenfolge
  {
    [[ -f "$SNIPPET_DIR/__header.html" ]] && cat "$SNIPPET_DIR/__header.html"
    find "$SNIPPET_DIR" -type f -name '*.html' ! -name "__header.html" ! -name "__footer.html" | sort | while read -r f; do
      cat "$f"
    done
    [[ -f "$SNIPPET_DIR/__footer.html" ]] && cat "$SNIPPET_DIR/__footer.html"
  } > "$BUILD_FILE"

  log_info "HTML built at $BUILD_FILE"

  # Neuen Root-Hash berechnen
  local root_hash
  root_hash=$(new_root_hash)
  log_info "Generated new root hash: $root_hash"

  # Gesamten Snippet-Ordner hashen
  local dir_hash
  dir_hash=$(sha256sum_dir "$SNIPPET_DIR")
  log_info "Directory content hash: $dir_hash"

  # In state speichern
  jq -n --arg root "$root_hash" --arg content "$dir_hash" '{root: $root, content: $content}' > "$HASH_FILE"

  log_success "State written to $HASH_FILE"

  echo "$root_hash"
}

build_html

