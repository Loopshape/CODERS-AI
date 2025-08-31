#!/usr/bin/env bash
# Author: Aris Arjuna Noorsanto <exe.opcode@gmail.com>
# AI / AGI / AIM Unified Processing Tool with Ollama Integration
# Modes: ai - file, ai + script, ai * regex batch, ai . env, ai : pipeline
# AGI: watch files, batch, screenshots, web scraping
# AIM: monitoring
# Ollama: automatic model serving & prompt processing
set -euo pipefail
IFS=$'\n\t'

# -----------------------
# CONFIG
# -----------------------
BACKUP_DIR="$HOME/.ai_backups"
mkdir -p "$BACKUP_DIR"

OLLAMA_MODEL="gemma3:1b"

UNIVERSAL_LAW=$(cat <<'EOF'
:bof:
redo complete layout and design an advanced symetrics to proximity accordance for dedicated info-quota alignments, which grant a better adjustment for leading besides subliminal range compliance promisings, that affair any competing content relations into a cognitive intuitition guidance comparison between space and gap implies, that are suggesting the viewer a subcoordinated experience alongside repetitive tasks and stoic context sortings, all cooperational aligned to timed subjects of importance accordingly to random capacity within builds of data statements, that prognose the grid reliability of a mockup as given optically acknowledged for a more robust but also as attractive rulership into golden-ratio item handling
:eof:
EOF
)

# -----------------------
# HELPER FUNCTIONS
# -----------------------
log() { echo "[AI] $*"; }

backup_file() {
    local file="$1"
    local timestamp
    timestamp=$(date +%Y%m%d%H%M%S)
    cp "$file" "$BACKUP_DIR/$(basename "$file").$timestamp.bak"
}

fetch_url() {
    local url="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -sL "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$url"
    else
        log "Error: curl or wget required to fetch URLs."
    fi
}

get_prompt() {
    local input="$1"
    if [[ "$input" =~ ^https?:// ]]; then
        fetch_url "$input"
    elif [ -f "$input" ]; then
        cat "$input"
    else
        echo "$input"
    fi
}

# -----------------------
# OLLAMA INTEGRATION
# -----------------------
ollama_init() {
    log "Stopping any running Ollama server..."
    pkill ollama || true
    log "Starting Ollama server in background..."
    ollama serve &>/dev/null &
    sleep 2
    log "Ollama server ready."
}

ollama_prompt() {
    local prompt="$1"
    if ! command -v ollama &>/dev/null; then
        log "Ollama not installed. Install via Homebrew."
        return 1
    fi
    ollama_init
    log "Sending prompt to Ollama model: $OLLAMA_MODEL"
    ollama run "$OLLAMA_MODEL" --prompt "$prompt"
}

# -----------------------
# AI MODES
# -----------------------
mode_file() {
    for f in "$@"; do
        [ -f "$f" ] || continue
        backup_file "$f"
        log "Processing file: $f"
        echo "$UNIVERSAL_LAW" > "$f.processed"
        ollama_prompt "$UNIVERSAL_LAW" > "$f.ollama"
    done
}

mode_script() {
    log "Processing script content..."
}

mode_batch() {
    local pattern="$1"
    shift
    for f in $pattern; do
        [ -f "$f" ] || continue
        backup_file "$f"
        log "Batch processing $f"
    done
}

mode_env() {
    log "Scanning environment..."
    env | sort
    df -h
    ls -la "$HOME"
    ls -la /etc
}

mode_pipeline() {
    local files=("$@")
    for f in "${files[@]}"; do
        log "Pipeline processing: $f"
        backup_file "$f"
    done
}

# -----------------------
# AGI MODES
# -----------------------
agi_watch() {
    local folder="$1"
    local pattern="${2:-*}"
    log "Watching $folder for pattern $pattern"
    command -v inotifywait >/dev/null 2>&1 || { log "Install inotify-tools"; return; }
    inotifywait -m -r -e modify --format '%w%f' "$folder" | while read file; do
        [[ "$file" == $pattern ]] || continue
        log "Detected change in $file, refreshing..."
        mode_file "$file"
    done
}

agi_screenshot() {
    local ratio="${1:-portrait}"
    log "Generating virtual screenshot ($ratio)..."
}

agi_webscrape() {
    local url="$1"
    local folder="${2:-$BACKUP_DIR/webscrape}"
    mkdir -p "$folder"
    local html_file="$folder/$(basename "$url").html"
    fetch_url "$url" > "$html_file"
    log "Fetched $url -> $html_file"
}

# -----------------------
# AIM MODE
# -----------------------
aim_monitor() {
    log "AIM activated: MIME-aware monitoring (Placeholder)"
    sleep 1
}

# -----------------------
# ARGUMENT PARSING
# -----------------------
if [ $# -eq 0 ]; then
    log "No arguments provided. Usage: ai <mode> [files/patterns/prompt]"
    exit 1
fi

case "$1" in
    -) shift; mode_file "$@" ;;
    +) shift; mode_script "$@" ;;
    \*) shift; mode_batch "$@" ;;
    .) shift; mode_env "$@" ;;
    :) shift; mode_pipeline "$@" ;;
    agi)
        shift
        case "$1" in
            +) shift; agi_watch "$@" ;;
            -) shift; agi_screenshot "$@" ;;
            ~) shift; agi_watch "$@" ;;
            web) shift; agi_webscrape "$@" ;;
            *) shift; agi_watch "$@" ;;
        esac
        ;;
    aim) shift; aim_monitor "$@" ;;
    *)
        PROMPT=$(get_prompt "$*")
        log "Processing prompt..."
        ollama_prompt "$PROMPT"
        ;;
esac