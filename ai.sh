#!/bin/bash
# ai.sh - Fully merged autonomous AI orchestrator
# Features: prompt/URL fetch, verbose streaming, DAG-aware ordering, memory, backup, tools, merge

set -euo pipefail

# ----------------------------
# CONFIGURATION
# ----------------------------
PROJECT_ROOT="${PROJECT_ROOT:-$HOME/CODERS-AI}"
OLLAMA_HOST="${OLLAMA_HOST:-localhost:11434}"
BACKUP_DIR="$PROJECT_ROOT/backup_$(date +%Y%m%d_%H%M%S)"
RESULTS_DIR="$PROJECT_ROOT/ai_results"
TOOLS_DIR="$PROJECT_ROOT/ai_tools"
MEMORY_FILE="$PROJECT_ROOT/ai_memory.json"
TMP_DIR="$PROJECT_ROOT/tmp"
MAX_PARALLEL_JOBS=6
CHUNK_SIZE=5000
MODELS=("cube" "core" "loop" "wave" "line" "coin" "code" "deepseek-v3.1:671b-cloud")

mkdir -p "$BACKUP_DIR" "$RESULTS_DIR" "$TOOLS_DIR" "$TMP_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

# ----------------------------
# LOGGING
# ----------------------------
log() { echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
log_verbose() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] VERBOSE: $1${NC}"; }
error_exit() { echo -e "${RED}ERROR: $1${NC}"; exit 1; }

# ----------------------------
# DEPENDENCY CHECK
# ----------------------------
check_dependencies() {
    local deps=("curl" "jq" "find" "file" "md5sum" "stat" "diff" "patch" "python3" "awk" "sed" "grep" "tee")
    for dep in "${deps[@]}"; do
        command -v "$dep" &> /dev/null || error_exit "Required dependency '$dep' not found"
    done

    # quick Ollama connectivity check
    if ! curl -s "http://$OLLAMA_HOST/api/tags" >/dev/null 2>&1; then
        error_exit "Ollama not reachable at $OLLAMA_HOST"
    fi
}

# ----------------------------
# MEMORY MANAGEMENT
# ----------------------------
init_ai_memory() { [[ ! -f "$MEMORY_FILE" ]] && echo "{}" > "$MEMORY_FILE"; }
load_ai_memory() { MEMORY=$(cat "$MEMORY_FILE"); }
update_ai_memory() {
    local file="$1"; local summary="$2"; local meta="$3"; local ts
    ts=$(date +%s)
    MEMORY=$(jq --arg f "$file" --arg t "$ts" --arg s "$summary" --arg m "$meta" \
        '.[$f]={last_update:$t,summary:$s,meta_prompt:$m}' <<< "$MEMORY")
    echo "$MEMORY" > "$MEMORY_FILE"
}

# ----------------------------
# BACKUP FILES
# ----------------------------
backup_files() {
    log "Creating backup snapshot in $BACKUP_DIR"
    find "$PROJECT_ROOT" -type f \
        -not -path "$BACKUP_DIR/*" \
        -not -path "$RESULTS_DIR/*" \
        -not -name "*.log" \
        -exec cp --parents {} "$BACKUP_DIR/" \;
}

# ----------------------------
# TOOL GENERATION
# ----------------------------
generate_ai_tools() {
    mkdir -p "$TOOLS_DIR"
    cat > "$TOOLS_DIR/analyze_file.sh" <<'EOF'
#!/bin/bash
FILE="$1"
[[ -z "$FILE" || ! -f "$FILE" ]] && echo "Usage: $0 <file>" && exit 1
echo "AI File Analysis Tool"
echo "File: $FILE"
echo "Type: $(file -b "$FILE")"
echo "Size: $(stat -c%s "$FILE") bytes"
EOF

    cat > "$TOOLS_DIR/enhance_code.sh" <<'EOF'
#!/bin/bash
FILE="$1"
OLLAMA_HOST="${OLLAMA_HOST:-localhost:11434}"
[[ -z "$FILE" || ! -f "$FILE" ]] && echo "Usage: $0 <file>" && exit 1
CONTENT=$(cat "$FILE")
curl -s -X POST "http://$OLLAMA_HOST/api/generate" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"code\",\"prompt\":\"Enhance this code:\\n$CONTENT\",\"stream\":false}" | jq -r '.response'
EOF

    chmod +x "$TOOLS_DIR"/*.sh
    log "AI helper tools generated at $TOOLS_DIR"
}

# ----------------------------
# FETCH PROMPT / URL OR DEFAULT
# ----------------------------
fetch_input() {
    local input="$1"
    local out="$TMP_DIR/tmp_input_file"
    mkdir -p "$TMP_DIR"
    if [[ -z "$input" ]]; then
        # empty file indicates default behavior
        : > "$out"
    elif [[ "$input" =~ ^https?:// ]]; then
        log "Fetching external URL: $input"
        curl -sL "$input" -o "$out"
    else
        log "Using provided prompt text"
        printf '%s' "$input" > "$out"
    fi
    echo "$out"
}

# ----------------------------
# CALL OLLAMA WITH STREAMING
# Writes streaming output to a temp file and logfile.
# Returns path of temp file (stdout) so caller can read it.
# ----------------------------
call_ollama_stream() {
    local model="$1"; local prompt="$2"; local logfile="$3"
    local tmpout
    tmpout=$(mktemp "$TMP_DIR/ollama_stream.XXXXXX")
    log_verbose "Streaming call to model '$model' (output -> $tmpout)."

    # use stream:true - capture response blocks (assumes each chunk has .response)
    # pipe jq to extract .response lines, append to tmpout and logfile
    curl -s -X POST "http://$OLLAMA_HOST/api/generate" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg model "$model" --arg prompt "$prompt" '{model:$model,prompt:$prompt,stream:true}')" \
    | jq -c -r '.response // empty' 2>/dev/null | tee -a "$logfile" >> "$tmpout"

    # ensure tmpout exists and is readable
    if [[ ! -s "$tmpout" ]]; then
        # fallback to non-streaming call if streaming produced nothing
        log_verbose "Streaming returned nothing; falling back to non-streamed call for '$model'."
        local resp
        resp=$(curl -s -X POST "http://$OLLAMA_HOST/api/generate" \
            -H "Content-Type: application/json" \
            -d "$(jq -n --arg model "$model" --arg prompt "$prompt" '{model:$model,prompt:$prompt,stream:false}')" \
            | jq -r '.response // ""')
        printf '%s\n' "$resp" | tee -a "$logfile" > "$tmpout"
    fi

    echo "$tmpout"
}

# ----------------------------
# DEPENDENCY GRAPH & TOPOLOGICAL SORT
# ----------------------------
build_dependency_graph_file() {
    local graph_json="$RESULTS_DIR/dependency_graph.json"
    declare -A depsmap
    : > "$graph_json"

    # heuristic: capture imports/requires/source lines and normalize
    mapfile -t allfiles < <(find "$PROJECT_ROOT" -type f -not -path "$BACKUP_DIR/*" -not -path "$RESULTS_DIR/*" -not -name "*.log")
    for f in "${allfiles[@]}"; do
        local rel
        rel=$(realpath --relative-to="$PROJECT_ROOT" "$f")
        local matches
        matches=$(grep -Eo "import[[:space:]]+.*from[[:space:]]+['\"][^'\"]+['\"]|require\(['\"]([^'\")]+)['\"]\)|source[[:space:]]+['\"][^'\"]+['\"]" "$f" 2>/dev/null || true)
        # normalize to relative file names where possible
        local dep_list=""
        if [[ -n "$matches" ]]; then
            while IFS= read -r line; do
                # extract quoted path
                local path
                path=$(echo "$line" | grep -Eo "['\"][^'\"]+['\"]" | sed -E "s/^['\"]|['\"]$//g" | head -1 || true)
                if [[ -n "$path" ]]; then
                    # if it's a relative path, resolve
                    if [[ "$path" == ./* || "$path" == ../* || "$path" == /* ]]; then
                        # try to resolve to project relative path
                        if [[ -f "$PROJECT_ROOT/$path" ]]; then
                            dep_list+="$path "
                        else
                            # try join with dir of f
                            local cand
                            cand=$(realpath -m "$(dirname "$f")/$path" 2>/dev/null || true)
                            if [[ -n "$cand" && -f "$cand" ]]; then
                                dep_list+="$(realpath --relative-to="$PROJECT_ROOT" "$cand") "
                            fi
                        fi
                    else
                        # non-relative (module name) — leave as-is (not mapped to file)
                        :
                    fi
                fi
            done <<< "$matches"
        fi
        # write to JSON
        jq -n --arg f "$rel" --arg deps "$dep_list" '{"file":$f,"deps":$deps}' >> "$graph_json.tmp" || true
    done

    # Convert temp entries into a JSON map: { "file": ["dep1","dep2"] ... }
    jq -s 'reduce .[] as $item ({}; .[$item.file] = ( ($item.deps | split(" ") | map(select(length>0))) ))' "$graph_json.tmp" > "$graph_json" 2>/dev/null || echo "{}" > "$graph_json"
    rm -f "$graph_json.tmp" || true
    echo "$graph_json"
}

topological_sort_file() {
    local graph_json="$1"
    local order_file="$RESULTS_DIR/execution_order.txt"

    # Use python for Kahn's algorithm
    python3 - "$graph_json" "$order_file" <<'PY'
import sys, json
gfile = sys.argv[1]
outfile = sys.argv[2]
with open(gfile) as f:
    graph = json.load(f)
# build incoming edges
nodes = set(graph.keys())
for v in graph.values():
    for d in v:
        nodes.add(d)
incoming = {n:set() for n in nodes}
outgoing = {n:set() for n in nodes}
for n, deps in graph.items():
    for d in deps:
        # only consider deps that are files in the graph (ignore external module names)
        incoming[n].add(d)
        outgoing.setdefault(d,set()).add(n)
# Kahn
L = []
S = [n for n in nodes if not incoming.get(n)]
# convert incoming to workable map: nodes with incoming edges
incoming2 = {n:set(incoming[n]) for n in incoming}
while S:
    n = S.pop(0)
    L.append(n)
    for m in list(outgoing.get(n, [])):
        incoming2[m].discard(n)
        if not incoming2[m]:
            S.append(m)
            incoming2.pop(m, None)
            outgoing[n].discard(m)
# If incoming2 still has edges -> cycle
if any(incoming2.values()):
    # fallback: just list files as found in graph keys
    with open(outfile, 'w') as f:
        for k in graph.keys():
            f.write(k + "\n")
else:
    with open(outfile, 'w') as f:
        for n in L:
            f.write(n + "\n")
PY

    echo "$order_file"
}

# ----------------------------
# PROCESS SINGLE FILE (streaming + merge + memory)
# ----------------------------
process_file() {
    local file="$1"
    local rel_path
    rel_path=$(realpath --relative-to="$PROJECT_ROOT" "$file")
    local fdir="$RESULTS_DIR/$rel_path"
    mkdir -p "$fdir"
    local verbose_log="$fdir/verbose_log.txt"
    : > "$verbose_log"

    log "Processing (hierarchical) $file"

    # basic metadata
    local ftype fsize fmd5
    ftype=$(file -b "$file")
    fsize=$(stat -c%s "$file")
    fmd5=$(md5sum "$file" | cut -d' ' -f1)
    printf 'File: %s\nType: %s\nSize: %s bytes\nMD5: %s\n---\n' "$file" "$ftype" "$fsize" "$fmd5" > "$fdir/basic_analysis.txt"

    # streaming passes: each model reads previous result (initially original)
    local input_text
    input_text=$(cat "$file")

    for model in "${MODELS[@]}"; do
        log_verbose "Starting model '$model' for $rel_path"
        local prompt="Analyze, explain, and enhance this file (task-aware and project-aware). Provide the full rewritten/enhanced content as output.\n\n$input_text"
        # get tmp file containing model output
        local tmpout
        tmpout=$(call_ollama_stream "$model" "$prompt" "$verbose_log")
        # read the latest output into input_text for next pass
        if [[ -s "$tmpout" ]]; then
            input_text=$(cat "$tmpout")
        else
            log_verbose "Model $model produced no output; keeping previous content."
        fi
        rm -f "$tmpout" 2>/dev/null || true
    done

    # final enhanced content
    echo "$input_text" > "$fdir/enhanced_file"

    # intelligent merge: backup original and patch with diff
    local orig="$PROJECT_ROOT/$rel_path"
    if [[ -f "$orig" ]]; then
        cp -p "$orig" "$orig.bak"
        # produce unified diff and apply with patch (forward only)
        diff -u "$orig" "$fdir/enhanced_file" > "$fdir/merge.diff" || true
        if [[ -s "$fdir/merge.diff" ]]; then
            # try to apply patch; if fails, do safe replace
            if patch -p0 --forward < "$fdir/merge.diff" 2>/dev/null; then
                log "Patched $orig with AI changes (backup: $orig.bak). Diff saved to $fdir/merge.diff"
            else
                # fallback: replace file atomically
                mv "$fdir/enhanced_file" "$orig"
                log "Patch failed — replaced original with enhanced content (backup: $orig.bak)"
                # recreate enhanced_file from new orig
                cat "$orig" > "$fdir/enhanced_file"
            fi
        else
            log "No differences between original and enhanced for $orig"
        fi
    else
        # new file: just write enhanced into project
        mkdir -p "$(dirname "$orig")"
        mv "$fdir/enhanced_file" "$orig"
        log "Created new file from enhanced output: $orig"
    fi

    # update memory with short summary and meta_prompt placeholder
    local summary
    summary=$(printf '%s' "$input_text" | head -n 20)
    update_ai_memory "$rel_path" "$summary" "hierarchical-enhance"

    log_verbose "Completed processing $file"
}

# ----------------------------
# AUTONOMOUS LOOP (DAG-aware hierarchical processing)
# ----------------------------
autonomous_loop() {
    local input_file="$1"
    log "Starting DAG-aware hierarchical orchestrator..."

    if [[ -s "$input_file" ]]; then
        # treat fetched input as a single file content to analyze
        # write to a temp file and process it (won't merge into project)
        local tmpf
        tmpf=$(mktemp "$TMP_DIR/fetched.XXXXXX")
        cat "$input_file" > "$tmpf"
        process_file "$tmpf"
        rm -f "$tmpf"
        return
    fi

    # Build dependency graph and topologically sort
    local graph_json order_file
    graph_json=$(build_dependency_graph_file)
    order_file=$(topological_sort_file "$graph_json")

    # Process files in topological order sequentially (hierarchical streaming)
    if [[ -f "$order_file" ]]; then
        mapfile -t ordered_files < "$order_file"
        for rel in "${ordered_files[@]}"; do
            # only process files that exist
            local full="$PROJECT_ROOT/$rel"
            if [[ -f "$full" ]]; then
                process_file "$full"
            fi
        done
    else
        # fallback: process all files found
        mapfile -t allfiles < <(find "$PROJECT_ROOT" -type f -not -path "$BACKUP_DIR/*" -not -path "$RESULTS_DIR/*" -not -name "*.log")
        for f in "${allfiles[@]}"; do
            process_file "$f"
        done
    fi
}

# ----------------------------
# MAIN
# ----------------------------
main() {
    local input="${1:-}"
    check_dependencies
    init_ai_memory
    load_ai_memory
    backup_files
    generate_ai_tools
    local fetched
    fetched=$(fetch_input "$input")
    autonomous_loop "$fetched"
}

main "$@"

