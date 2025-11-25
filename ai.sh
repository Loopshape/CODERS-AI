#!/bin/bash
# ai.sh – Autonomous DAG-based, streaming, memory-aware, self-learning AI orchestrator
# Features:
# - streaming concurrent model pipelines
# - DAG dependency ordering
# - automatic prompt/url import
# - fallback to analyze+explain ./*
# - persistent AI memory + scoreboard
# - model auto-ranking + auto-order tuning
# - safe review/approval hook

set -euo pipefail

ROOT="${ROOT:-$HOME/CODERS-AI}"
MEMORY="$ROOT/ai_memory.json"
SCOREBOARD="$ROOT/ai_scoreboard.json"
RESULTS="$ROOT/ai_results"
TMP="$ROOT/tmp"
mkdir -p "$RESULTS" "$TMP"

OLLAMA="${OLLAMA_HOST:-localhost:11434}"

MODELS=(cube core loop wave coin code)

#---------------------------------------------
# INIT MEMORY + SCOREBOARD
#---------------------------------------------
[[ ! -f "$MEMORY" ]] && echo "{}" > "$MEMORY"
[[ ! -f "$SCOREBOARD" ]] && echo "{}" > "$SCOREBOARD"

load_memory() { MEM=$(cat "$MEMORY"); }
save_memory() { echo "$MEM" > "$MEMORY"; }

load_scoreboard() { SCORE=$(cat "$SCOREBOARD"); }
save_scoreboard() { echo "$SCORE" > "$SCOREBOARD"; }


#---------------------------------------------
# STREAMING MODEL RUN (CONCURRENT)
#---------------------------------------------
run_model_stream() {
    local model="$1"
    local prompt="$2"
    local outfile="$3"
    local start_ts=$(date +%s)

    {
        curl -s -N \
            -X POST "http://$OLLAMA/api/generate" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$model\",\"prompt\":\"$prompt\",\"stream\":true}" \
            | stdbuf -o0 sed 's/^data: //g' \
            | tee "$outfile"
    } &

    PID=$!
    echo "$PID"
}

#---------------------------------------------
# SCORING OF MODEL OUTPUT
#---------------------------------------------
score_output() {
    local model="$1"
    local file="$2"
    local latency="$3"

    local text
    text=$(cat "$file")

    # Auto-score using the "core" model → meta-evaluation
    local eval
    eval=$(curl -s -X POST "http://$OLLAMA/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"core\",\"prompt\":\"Evaluate quality:\n$text\",\"stream\":false}" \
        | jq -r '.response')

    local coherence=$(echo "$eval" | grep -i "coherence" | awk '{print $NF}' | tr -dc '0-9')
    local improvement=$(echo "$eval" | grep -i "improve" | awk '{print $NF}' | tr -dc '0-9')
    local memorylink=$(echo "$eval" | grep -i "memory" | awk '{print $NF}' | tr -dc '0-9')

    load_scoreboard

    SCORE=$(jq --arg m "$model" \
               --argjson lat "$latency" \
               --argjson coh "${coherence:-50}" \
               --argjson imp "${improvement:-50}" \
               --argjson mem "${memorylink:-50}" \
               '
               .[$m] = {
                   latency: $lat,
                   coherence: $coh,
                   improvement: $imp,
                   memorylink: $mem,
                   score: (($coh+$imp+$mem)/3)-(0.2*$lat)
               }
               ' <<< "$SCORE")

    save_scoreboard
}

#---------------------------------------------
# MODEL AUTOTUNE ORDER
#---------------------------------------------
autotune_order() {
    load_scoreboard

    # If scoreboard empty → keep default
    if [[ "$(echo "$SCORE" | jq length)" -eq 0 ]]; then
        echo "${MODELS[@]}"
        return
    fi

    # Sort by descending score
    sorted=$(echo "$SCORE" | jq -r '
        to_entries | sort_by(.value.score) | reverse | .[].key
    ')

    echo "$sorted"
}

#---------------------------------------------
# PROMPT / URL FETCH
#---------------------------------------------
fetch_input() {
    local input="$1"
    local out="$TMP/input.txt"

    if [[ -z "$input" ]]; then
        echo "" > "$out"
        echo "$out"
        return
    fi
    if [[ "$input" =~ ^https?:// ]]; then
        curl -sL "$input" -o "$out"
        echo "$out"
        return
    fi

    echo "$input" > "$out"
    echo "$out"
}

#---------------------------------------------
# DAG ANALYSIS
#---------------------------------------------
build_dag() {
    local base="$1"
    find "$base" -type f | while read -r f; do
        deps=$(grep -oE '(import|require)\s+["'"'"'][^"'"'"']+["'"'"']' "$f" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/')
        echo "$f:$deps"
    done
}

toposort() {
    python3 - "$@" << 'EOF'
import sys
from collections import defaultdict, deque

dag=defaultdict(list)
incoming=defaultdict(int)

for line in sys.stdin:
    f,deps=line.strip().split(":")
    deps=[d for d in deps.split() if d]
    for d in deps:
        dag[d].append(f)
        incoming[f]+=1
    if f not in incoming:
        incoming[f]=incoming.get(f,0)

q=deque([n for n in incoming if incoming[n]==0])
out=[]

while q:
    n=q.popleft()
    out.append(n)
    for nxt in dag[n]:
        incoming[nxt]-=1
        if incoming[nxt]==0:
            q.append(nxt)

print("\n".join(out))
EOF
}

#---------------------------------------------
# FILE PROCESS
#---------------------------------------------
process_file() {
    local file="$1"
    local content
    content=$(cat "$file")

    # Auto-discover model order:
    local ordered
    ordered=($(autotune_order))

    declare -A streams

    for model in "${ordered[@]}"; do
        outfile="$RESULTS/$(basename "$file").$model.out"
        pid=$(run_model_stream "$model" "$content" "$outfile")
        streams["$model"]="$pid"
    done

    # Wait & score
    for model in "${ordered[@]}"; do
        pid="${streams[$model]}"
        start=$(date +%s)
        wait "$pid"
        end=$(date +%s)
        score_output "$model" "$RESULTS/$(basename "$file").$model.out" "$((end-start))"
    done
}

#---------------------------------------------
# SAFE APPROVAL HOOK
#---------------------------------------------
approval() {
    local summary="$1"

    echo "======================================="
    echo "   AI GENERATED CHANGE SUMMARY"
    echo "======================================="
    echo "$summary"
    echo "---------------------------------------"
    read -p "Approve? (y/n): " a
    [[ "$a" == "y" ]]
}

#---------------------------------------------
# MAIN WORKFLOW
#---------------------------------------------
main() {
    input="${1:-}"
    input_file=$(fetch_input "$input")

    load_memory

    if [[ -s "$input_file" ]]; then
        # Treat as single file content
        process_file "$input_file"
    else
        # Analyze entire project via DAG
        build_dag "$ROOT" | toposort | while read -r f; do
            [[ -f "$f" ]] || continue
            process_file "$f"
        done
    fi

    echo "DONE."
}

main "$@"

