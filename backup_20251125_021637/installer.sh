#!/usr/bin/env bash
# installer.sh - Full NEXUS Orchestrator Installer
# -----------------------------------------------
# Usage: ./installer.sh
# Installs dependencies, prepares environment, bundles templates, and sets up NEXUS base.

set -euo pipefail

ROOT="$(pwd)"
DIST_DIR="$ROOT/dist"
SNIPPETS_DIR="$ROOT/snippets"
TEMPLATES_DIR="$ROOT/templates"
MANIFEST_DIR="$ROOT/orchestrator/manifest"
MAIN_TEMPLATE="$TEMPLATES_DIR/main.html"

log() {
    echo "[${1:-INFO}] $2"
}

# ----------------------------
# Step 1: Environment check
# ----------------------------
log INFO "Checking environment..."
if ! command -v bash >/dev/null 2>&1; then
    log ERROR "Bash not found. Aborting."
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    log WARN "Docker not found. You can install it to enable container builds."
fi

mkdir -p "$DIST_DIR" "$MANIFEST_DIR"

# ----------------------------
# Step 2: Dependency install
# ----------------------------
log INFO "Installing required packages..."
PKGS=(git curl wget coreutils)

for pkg in "${PKGS[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        log INFO "Installing $pkg..."
        sudo apt-get update && sudo apt-get install -y "$pkg"
    fi
done

# ----------------------------
# Step 3: Scan snippets/templates
# ----------------------------
log INFO "Scanning snippets and templates..."
MANIFEST_FILE="$MANIFEST_DIR/manifest.json"
mkdir -p "$(dirname "$MANIFEST_FILE")"

jq -n --argjson snippets "$(ls -1 "$SNIPPETS_DIR" | jq -R -s -c 'split("\n")[:-1]')" \
      --argjson templates "$(ls -1 "$TEMPLATES_DIR" | jq -R -s -c 'split("\n")[:-1]')" \
      '{snippets: $snippets, templates: $templates}' > "$MANIFEST_FILE"

log INFO "Manifest generated at $MANIFEST_FILE"

# ----------------------------
# Step 4: Bundler function
# ----------------------------
assemble_file() {
    local file="$1"
    local content=""
    
    if [[ ! -f "$file" ]]; then
        log WARN "File not found: $file"
        echo "<!-- MISSING: $file -->"
        return
    fi

    content=$(<"$file")

    # Replace {{include:PATH}} with file contents
    while [[ "$content" =~ \{\{include:([^\}]+)\}\} ]]; do
        local inc="${BASH_REMATCH[1]}"
        local inc_path="$ROOT/$inc"

        if [[ ! -f "$inc_path" ]]; then
            log WARN "Include file not found: $inc_path"
            inc_content="<!-- MISSING: $inc_path -->"
        else
            inc_content=$(assemble_file "$inc_path")
        fi

        content="${content//\{\{include:$inc\}\}/$inc_content}"
    done

    echo "$content"
}

# ----------------------------
# Step 5: Bundle templates
# ----------------------------
log INFO "Bundling templates into $DIST_DIR/index.html..."
if [[ ! -f "$MAIN_TEMPLATE" ]]; then
    log ERROR "Main template not found: $MAIN_TEMPLATE"
    exit 1
fi

assemble_file "$MAIN_TEMPLATE" > "$DIST_DIR/index.html"

log INFO "Bundling complete."

# ----------------------------
# Step 6: Genesis hash
# ----------------------------
GENESIS_HASH=$(sha256sum "$DIST_DIR/index.html" | awk '{print $1}')
echo "$GENESIS_HASH" > "$DIST_DIR/genesis.hash"
log INFO "Current genesis hash: $GENESIS_HASH"

# ----------------------------
# Step 7: Docker base image
# ----------------------------
if command -v docker >/dev/null 2>&1; then
    DOCKER_IMAGE="nexus/base:latest"
    log INFO "Building Docker base image $DOCKER_IMAGE..."
    docker build -t "$DOCKER_IMAGE" .
    log INFO "Docker image built successfully."
else
    log WARN "Docker not installed, skipping Docker build."
fi

# ----------------------------
# Done
# ----------------------------
log INFO "NEXUS Orchestrator installation complete!"

