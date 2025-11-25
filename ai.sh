#!/bin/bash
# ai_orchestrator.sh - Full enhanced autonomous Ollama AI orchestration
# Features: full resource access, parallel AI pipelines, persistent memory, automatic tool generation

set -euo pipefail

# ----------------------------
# CONFIGURATION
# ----------------------------
PROJECT_ROOT="${PROJECT_ROOT:-$HOME/CODERS-AI}"
OLLAMA_HOST="${OLLAMA_HOST:-localhost:11434}"
BACKUP_DIR="$PROJECT_ROOT/backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$PROJECT_ROOT/ai_orchestrator.log"
TMP_DIR="$PROJECT_ROOT/tmp"
RESULTS_DIR="$PROJECT_ROOT/ai_results"
TOOLS_DIR="$PROJECT_ROOT/ai_tools"
MEMORY_FILE="$PROJECT_ROOT/ai_memory.json"
MAX_PARALLEL_JOBS=6
CHUNK_SIZE=5000  # characters per AI prompt chunk
MODELS=("deepseek-v3.1:671b-cloud" "cube" "core" "loop" "line" "wave" "coin" "code")

# Ensure directories exist
mkdir -p "$BACKUP_DIR" "$TMP_DIR" "$RESULTS_DIR" "$TOOLS_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# ----------------------------
# LOGGING
# ----------------------------
log() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error_exit() {
    echo -e "${RED}ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

# ----------------------------
# DEPENDENCY CHECK
# ----------------------------
check_dependencies() {
    local deps=("curl" "jq" "find" "file" "md5sum" "stat" "fold")
    for dep in "${deps[@]}"; do
        command -v "$dep" &> /dev/null || error_exit "Required dependency '$dep' not found"
    done

    curl -s "http://$OLLAMA_HOST/api/tags" &> /dev/null || error_exit "Ollama not accessible at $OLLAMA_HOST"
}

# ----------------------------
# AI MEMORY MANAGEMENT
# ----------------------------
init_ai_memory() {
    if [[ ! -f "$MEMORY_FILE" ]]; then
        echo "{}" > "$MEMORY_FILE"
    fi
}

load_ai_memory() {
    MEMORY=$(cat "$MEMORY_FILE")
}

update_ai_memory() {
    local file="$1"
    local summary="$2"
    local ts
    ts=$(date +%s)
    MEMORY=$(jq --arg f "$file" --arg t "$ts" --arg s "$summary" \
        '.[$f] = {last_update: $t, summary: $s}' <<< "$MEMORY")
    echo "$MEMORY" > "$MEMORY_FILE"
}

# ----------------------------
# BACKUP
# ----------------------------
backup_files() {
    log "Creating backup in $BACKUP_DIR"
    find "$PROJECT_ROOT" -type f \
        -not -path "$BACKUP_DIR/*" \
        -not -path "$RESULTS_DIR/*" \
        -not -name "*.log" \
        -exec cp --parents {} "$BACKUP_DIR/" \;
}

# ----------------------------
# AI CALL
# ----------------------------
call_ollama() {
    local model="$1"
    local prompt="$2"

    local response
    response=$(curl -s -X POST "http://$OLLAMA_HOST/api/generate" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg model "$model" --arg prompt "$prompt" '{model: $model, prompt: $prompt, stream: false}')")

    if echo "$response" | jq -e '.error' &> /dev/null; then
        echo "ERROR: $(echo "$response" | jq -r '.error')" >&2
        return 1
    fi
    echo "$response" | jq -r '.response'
}

# ----------------------------
# FILE ANALYSIS
# ----------------------------
analyze_file_basic() {
    local file="$1"
    local type size md5
    type=$(file -b "$file")
    size=$(stat -c%s "$file")
    md5=$(md5sum "$file" | cut -d' ' -f1)
    echo -e "File: $file\nType: $type\nSize: $size bytes\nMD5: $md5\n---"
}

ai_analyze_file_parallel() {
    local file="$1"
    local results_dir="$2"
    mkdir -p "$results_dir"

    local content chunked
    content=$(cat "$file")

    # Chunk large files
    chunked=""
    while read -r -d '' piece; do
        chunked+="$piece"$'\n---CHUNK---\n'
    done < <(fold -w "$CHUNK_SIZE" < <(echo "$content") -s -z)

    declare -A pids
    for model in "${MODELS[@]}"; do
        (
            local prompt="Analyze file with model '$model':\n$chunked"
            if result=$(call_ollama "$model" "$prompt"); then
                echo -e "=== $model Analysis ===\n$result" > "$results_dir/${model}.txt"
            else
                echo "Failed $model analysis" > "$results_dir/${model}_error.txt"
            fi
        ) &
        pids[$model]=$!
    done

    # Wait for all parallel jobs
    for pid in "${pids[@]}"; do wait "$pid"; done
}

# ----------------------------
# FILE ENHANCEMENT
# ----------------------------
create_enhanced_file() {
    local file="$1"
    local results_dir="$2"
    mkdir -p "$results_dir"

    local enhanced
    enhanced=$(cat "$file")

    # Sequential AI passes for enhancement
    if new=$(call_ollama "cube" "Improve structure:\n$enhanced"); then enhanced="$new"; fi
    if new=$(call_ollama "code" "Enhance readability, best practices, optimizations:\n$enhanced"); then enhanced="$new"; fi
    if new=$(call_ollama "coin" "Optimize performance and efficiency:\n$enhanced"); then enhanced="$new"; fi

    echo "$enhanced" > "$results_dir/enhanced_file"
}

# ----------------------------
# PROCESS SINGLE FILE
# ----------------------------
process_file() {
    local file="$1"
    local rel_path
    rel_path=$(realpath --relative-to="$PROJECT_ROOT" "$file")
    local fdir="$RESULTS_DIR/$rel_path"
    mkdir -p "$fdir"

    log "Processing $file"

    analyze_file_basic "$file" > "$fdir/basic_analysis.txt"
    ai_analyze_file_parallel "$file" "$fdir"
    create_enhanced_file "$file" "$fdir"

    # Update AI memory
    local summary
    summary=$(head -n 20 "$fdir/enhanced_file" 2>/dev/null || echo "Enhanced")
    update_ai_memory "$rel_path" "$summary"

    log "Completed $file (memory updated)"
}

# ----------------------------
# AUTOMATIC TOOL GENERATION
# ----------------------------
generate_ai_tools() {
    mkdir -p "$TOOLS_DIR"

    # analyze_file.sh
    cat > "$TOOLS_DIR/analyze_file.sh" << 'EOF'
#!/bin/bash
FILE="$1"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
    echo "Usage: $0 <file>"
    exit 1
fi
echo "AI File Analysis Tool"
echo "File: $FILE"
echo "Type: $(file -b "$FILE")"
echo "Size: $(stat -c%s "$FILE") bytes"
EOF

    # enhance_code.sh
    cat > "$TOOLS_DIR/enhance_code.sh" << 'EOF'
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
EOF

    chmod +x "$TOOLS_DIR"/*.sh
    log "AI tools generated in $TOOLS_DIR"
}

# ----------------------------
# AUTONOMOUS WORKFLOW
# ----------------------------
autonomous_loop() {
    log "Starting autonomous AI workflow..."
    while true; do
        # Detect new or recently modified files
        mapfile -t files < <(find "$PROJECT_ROOT" -type f \
            -not -path "$BACKUP_DIR/*" \
            -not -path "$RESULTS_DIR/*" \
            -not -name "*.log" \
            -mmin -1)

        for f in "${files[@]}"; do
            process_file "$f" &
            # Respect parallel job limit
            while (( $(jobs -r | wc -l) >= MAX_PARALLEL_JOBS )); do sleep 0.2; done
        done

        sleep 30
    done
}

# ----------------------------
# MAIN
# ----------------------------
main() {
    check_dependencies
    init_ai_memory
    load_ai_memory
    backup_files
    generate_ai_tools
    autonomous_loop
}

main "$@"

