#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
DIST="${DIST:-$ROOT/dist}"
MAIN_TEMPLATE="${MAIN_TEMPLATE:-$ROOT/templates/main.html}"

log() { echo "[${1:-INFO}] $2"; }

# Recursively assemble a file
assemble_file() {
    local file="$1"
    local depth="${2:-0}"

    # prevent infinite recursion
    if [ "$depth" -gt 10 ]; then
        echo "<!-- MAX INCLUDE DEPTH REACHED: $file -->"
        return
    fi

    # resolve relative paths
    if [[ "$file" != /* ]]; then
        file="$ROOT/$file"
    fi

    if [ ! -f "$file" ]; then
        echo "<!-- INCLUDE NOT FOUND: $file -->"
        log "[WARN] Include file not found: $file"
        return
    fi

    local content
    content=$(cat "$file" 2>/dev/null || echo "")
    if [ -z "$content" ]; then
        log "[WARN] Include file not found: $file"
        echo "<!-- MISSING: $file -->"
        return
    fi


    # Substitute environment variables {{VAR}}
    while [[ "$content" =~ \{\{([A-Z0-9_]+)\}\} ]]; do
        local var="${BASH_REMATCH[1]}"
        content="${content//\{\{$var\}\}/${!var-}}"
    done

    # Recursive includes {{include:path/to/file}}
    while [[ "$content" =~ \{\{include:([^\}]+)\}\} ]]; do
        local inc="${BASH_REMATCH[1]}"
        local inc_content
        inc_content=$(assemble_file "$inc" $((depth+1)) || echo "<!-- FAILED INCLUDE: $inc -->")
        # Escape slashes for safe sed replacement
        inc_content=$(echo "$inc_content" | sed 's/[\/&]/\\&/g')
        content=$(echo "$content" | sed "0,/{{include:$inc}}/s//${inc_content}/")
    done

    echo "$content"
}

mkdir -p "$DIST"
log INFO "Building templates into $DIST ..."

OUTPUT_FILE="$DIST/index.html"
assemble_file "$MAIN_TEMPLATE" > "$OUTPUT_FILE"

log INFO "Assembled $OUTPUT_FILE"
log INFO "Build complete."
