#!/usr/bin/env bash
# ai.sh - Final autonomous AI orchestrator
# Fully autonomous parallel orchestrator for multi-model Ollama pipelines.
# Features:
#  - prompt/URL fetch (or analyze project files)
#  - dependency graph builder (import/require/source detection)
#  - DAG level generation with parallel execution per level
#  - concurrent streaming generation from all models
#  - automatic scoring (meta-eval via 'core' model)
#  - adaptive model-order via scoreboard
#  - patch/diff-based merges with safe approval layer
#  - fallback full-file overwrite if patching fails
#  - persistent memory & scoreboard
#  - auto tools folder injection support

set -euo pipefail
IFS=$'\n\t'

# ----------------------------------------------------------
# CONFIG
# ----------------------------------------------------------
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
OLLAMA_HOST="${OLLAMA_HOST:-localhost:11434}"
MAX_PARALLEL_JOBS="${MAX_PARALLEL_JOBS:-6}"
TMP_DIR="${TMP_DIR:-$PROJECT_ROOT/.ai_tmp}"
RESULTS_DIR="${RESULTS_DIR:-$PROJECT_ROOT/ai_results}"
TOOLS_DIR="${TOOLS_DIR:-$PROJECT_ROOT/ai_tools}"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backup_$(date +%Y%m%d_%H%M%S)}"
MEMORY_FILE="${MEMORY_FILE:-$PROJECT_ROOT/ai_memory.json}"
SCOREBOARD_FILE="${SCOREBOARD_FILE:-$PROJECT_ROOT/ai_scoreboard.json}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

MODELS=("deepseek-v3.1:671b-cloud" "cube" "core" "loop" "wave" "line" "coin" "code" "work")

mkdir -p "$TMP_DIR" "$RESULTS_DIR" "$TOOLS_DIR" "$BACKUP_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log(){ printf "%b[%s] %s%b\n" "$CYAN" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$NC"; }
err(){ printf "%b%s%b\n" "$RED" "$1" "$NC"; }
fatal(){ err "$1"; exit 1; }

# ----------------------------------------------------------
# CHECK DEPENDENCIES
# ----------------------------------------------------------
check_deps(){
  local deps=(curl jq find file md5sum stat diff patch python3 sed grep awk tee)
  for d in "${deps[@]}"; do
    command -v "$d" >/dev/null || fatal "Missing dependency: $d"
  done
  if ! curl -s "http://$OLLAMA_HOST/api/tags" >/dev/null; then
    fatal "Ollama not reachable at $OLLAMA_HOST"
  fi
}

# ----------------------------------------------------------
# MEMORY + SCOREBOARD INIT
# ----------------------------------------------------------
init_state(){
  [[ -f "$MEMORY_FILE" ]] || echo "{}" > "$MEMORY_FILE"
  [[ -f "$SCOREBOARD_FILE" ]] || echo "{}" > "$SCOREBOARD_FILE"
}

load_memory(){ MEM_JSON=$(cat "$MEMORY_FILE"); }
save_memory(){ printf '%s' "$MEM_JSON" > "$MEMORY_FILE"; }

load_scoreboard(){ SCORE_JSON=$(cat "$SCOREBOARD_FILE"); }
save_scoreboard(){ printf '%s' "$SCORE_JSON" > "$SCOREBOARD_FILE"; }

ensure_scoreboard_models(){
  load_scoreboard
  for m in "${MODELS[@]}"; do
    if ! echo "$SCORE_JSON" | jq -e --arg m "$m" '.[$m]' >/dev/null; then
      SCORE_JSON=$(jq --arg m "$m" '.[$m]={runs:0,applied:0,total_bytes:0,avg_latency:0,score:0}' <<< "$SCORE_JSON")
    fi
  done
  save_scoreboard
}

# ----------------------------------------------------------
# FETCH INPUT
# ----------------------------------------------------------
fetch_input(){
  local in="${1:-}"
  local out="$TMP_DIR/fetched_input.txt"
  [[ -z "$in" ]] && : > "$out" && echo "$out" && return
  if [[ "$in" =~ ^https?:// ]]; then
    curl -sL "$in" -o "$out"
  else
    printf '%s' "$in" > "$out"
  fi
  echo "$out"
}

# ----------------------------------------------------------
# BUILD DEPENDENCY GRAPH
# ----------------------------------------------------------
build_dependency_graph_file(){
  local graph_json="$RESULTS_DIR/dependency_graph.json"
  local tmp_entries="$TMP_DIR/graph_entries.jsonl"
  : > "$tmp_entries"

  mapfile -t files < <(find "$PROJECT_ROOT" -type f \
    -not -path "$BACKUP_DIR/*" \
    -not -path "$RESULTS_DIR/*" \
    -not -name "*.log")

  for f in "${files[@]}"; do
    local rel; rel=$(realpath --relative-to="$PROJECT_ROOT" "$f")
    local matches
    matches=$(grep -Eo "import .* from ['\"][^'\"]+['\"]|require\(['\"][^'\"]+['\"]\)|source ['\"][^'\"]+['\"]" "$f" 2>/dev/null || true)
    local deps=()
    if [[ -n "$matches" ]]; then
      while read -r line; do
        local p; p=$(echo "$line" | sed -nE "s/.*['\"]([^'\"]+)['\"].*/\1/p")
        [[ -z "$p" ]] && continue
        if [[ "$p" == .* || "$p" == /* ]]; then
          local cand; cand=$(realpath -m "$(dirname "$f")/$p" 2>/dev/null || true)
          [[ -f "$cand" ]] && deps+=("$(realpath --relative-to="$PROJECT_ROOT" "$cand")")
        fi
      done <<< "$matches"
    fi

    jq -n --arg f "$rel" --argjson d "$(printf '%s\n' "${deps[@]}" | jq -R . | jq -s .)" \
      '{file:$f,deps:$d}' >> "$tmp_entries"
  done

  jq -s 'reduce .[] as $i ({}; .[$i.file]=$i.deps)' "$tmp_entries" \
    > "$graph_json" 2>/dev/null || echo "{}" > "$graph_json"

  rm -f "$tmp_entries"
  echo "$graph_json"
}

# ----------------------------------------------------------
# DAG LEVELS
# ----------------------------------------------------------
produce_dag_levels(){
  local graph_json="$1"
  local out="$RESULTS_DIR/dag_levels.json"

python3 - "$graph_json" "$out" << 'PY'
import sys,json
gfile, ofile = sys.argv[1], sys.argv[2]
graph=json.load(open(gfile))
nodes=set(graph.keys())
for dlist in graph.values():
    nodes.update(dlist)

incoming={n:set() for n in nodes}
outgoing={n:set() for n in nodes}

for n,deps in graph.items():
    for d in deps:
        if d in nodes:
            incoming[n].add(d)
            outgoing[d].add(n)

levels=[]
while True:
    ready=[n for n in incoming if not incoming[n]]
    if not ready:
        break
    ready=sorted(ready)
    levels.append(ready)
    for r in ready:
        incoming.pop(r,None)
        for o in list(outgoing.get(r,[])):
            incoming[o].discard(r)
        outgoing.pop(r,None)

if incoming:
    levels.append(sorted(incoming.keys()))

json.dump(levels, open(ofile,"w"), indent=2)
PY

  echo "$out"
}

# ----------------------------------------------------------
# MODEL INVOCATION
# ----------------------------------------------------------
call_ollama_stream_to_file(){
  local model="$1" prompt="$2" outfile="$3"
  : > "$outfile"
  curl -s -X POST "http://$OLLAMA_HOST/api/generate" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg model "$model" --arg prompt "$prompt" \
        '{model:$model,prompt:$prompt,stream:true}')" \
    | jq -r '.response // empty' >> "$outfile" &
  echo $!
}

call_ollama_sync_to_file(){
  local model="$1" prompt="$2" outfile="$3"
  curl -s -X POST "http://$OLLAMA_HOST/api/generate" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg model "$model" --arg prompt "$prompt" \
        '{model:$model,prompt:$prompt,stream:false}')" \
    | jq -r '.response // ""' > "$outfile"
}

run_model_and_wait(){
  local model="$1" prompt="$2" out="$3"
  local pid; pid=$(call_ollama_stream_to_file "$model" "$prompt" "$out")
  local timeout=${MODEL_TIMEOUT:-300}
  for ((i=0;i<timeout;i++)); do
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 1
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    call_ollama_sync_to_file "$model" "$prompt" "$out"
  elif [[ ! -s "$out" ]]; then
    call_ollama_sync_to_file "$model" "$prompt" "$out"
  fi
}

# ----------------------------------------------------------
# SCORING (meta-eval via core)
# ----------------------------------------------------------
score_model_output(){
  local model="$1" outfile="$2" latency="$3"
  local text; text=$(sed 's/"/\\"/g' "$outfile")

  local eval_prompt="Evaluate this model output. Return JSON: {coherence:0-100, improvement:0-100, memorylink:0-100}.\n$text"

  local resp; resp=$(curl -s -X POST "http://$OLLAMA_HOST/api/generate" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg model "core" --arg prompt "$eval_prompt" \
      '{model:$model,prompt:$prompt,stream:false}')" \
      | jq -r '.response // ""')

  if echo "$resp" | jq -e . >/dev/null 2>&1; then
    jq --argjson lat "$latency" '. + {latency:$lat}' <<< "$resp"
  else
    jq -n --argjson c 50 --argjson i 50 --argjson m 50 --argjson lat "$latency" \
      '{coherence:$c, improvement:$i, memorylink:$m, latency:$lat}'
  fi
}

update_scoreboard_with_metrics(){
  local model="$1" metrics="$2"
  load_scoreboard
  SCORE_JSON=$(jq -n --arg m "$model" --argjson cur "$(echo "$SCORE_JSON" | jq -r '.[$m]')" --argjson met "$metrics" '
    ($cur.runs // 0) as $runs |
    ($cur.avg_latency // 0) as $al |
    ($met.latency) as $lat |
    {
      runs: ($runs + 1),
      applied: ($cur.applied // 0),
      total_bytes: ($cur.total_bytes // 0),
      avg_latency: (($al * $runs + $lat) / ($runs + 1)),
      score: (($met.coherence + $met.improvement + $met.memorylink)/3) - (0.1 * ($lat/100))
    }
  ' | jq --arg m "$model" '. as $new | {($m):$new} + input' <<< "$SCORE_JSON")
  save_scoreboard
}

mark_models_applied_for_file(){
  local fdir="$1" rel="$2"
  local orig="$PROJECT_ROOT/$rel"
  for m in "${MODELS[@]}"; do
    local mout="$fdir/model_${m}.txt"
    [[ ! -f "$mout" ]] && continue
    if [[ -f "$orig" ]]; then
      if ! diff -u "$orig" "$mout" >/dev/null; then
        load_scoreboard
        SCORE_JSON=$(echo "$SCORE_JSON" | jq --arg m "$m" '.[$m].applied += 1')
        save_scoreboard
      fi
    else
      load_scoreboard
      SCORE_JSON=$(echo "$SCORE_JSON" | jq --arg m "$m" '.[$m].applied += 1')
      save_scoreboard
    fi
  done
}

# ----------------------------------------------------------
# MODEL ORDER AUTOTUNE
# ----------------------------------------------------------
autotune_model_order(){
  load_scoreboard
  local ordered
  ordered=$(echo "$SCORE_JSON" | jq -r '
      to_entries | sort_by(.value.score) | reverse | .[].key
  ')

  local final=()
  for m in $ordered; do
    for base in "${MODELS[@]}"; do
      [[ "$m" == "$base" ]] && final+=("$m")
    done
  done
  for base in "${MODELS[@]}"; do
    if ! printf '%s\n' "${final[@]}" | grep -qx "$base"; then
      final+=("$base")
    fi
  done
  echo "${final[@]}"
}

# ----------------------------------------------------------
# SAFE PATCH
# ----------------------------------------------------------
safe_apply_patch(){
  local difffile="$1" orig="$2" fdir="$3"

  if [[ ! -s "$difffile" ]]; then
    echo "nochange"; return
  fi

  if [[ "$AUTO_APPROVE" == "true" ]]; then
    if patch -p0 --forward < "$difffile" 2>/dev/null; then
      echo "applied"
    else
      mv "$fdir/enhanced_file" "$orig"
      echo "replaced"
    fi
    return
  fi

  if [[ -t 0 && -t 1 ]]; then
    echo "Diff for $orig"
    echo "Apply patch? [y/N]"
    read -r ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      if patch -p0 --forward < "$difffile"; then
        echo "applied"
      else
        mv "$fdir/enhanced_file" "$orig"
        echo "replaced"
      fi
    else
      echo "skipped"
    fi
  else
    echo "skipped"
  fi
}

# ----------------------------------------------------------
# MAIN
# ----------------------------------------------------------
main(){
  check_deps
  init_state
  ensure_scoreboard_models

  local input; input=$(fetch_input "${1:-}")
  log "Fetched input at $input"

  cp -a "$PROJECT_ROOT" "$BACKUP_DIR"

  local graph; graph=$(build_dependency_graph_file)
  local levels; levels=$(produce_dag_levels "$graph")

  log "DAG ready: $levels"

  readarray -t LEVELS < <(jq -r '.[] | @sh' "$levels")

  for lvl in "${LEVELS[@]}"; do
    eval "files=($lvl)"
    for f in "${files[@]}"; do
      (
        local rel="$f"
        local abs="$PROJECT_ROOT/$rel"
        local fdir="$TMP_DIR/$(echo "$rel" | sed 's/\//_/g')"
        mkdir -p "$fdir"

        local prompt
        prompt=$(printf "Enhance the following file:\n\n%s\n\nUser input:\n%s" \
          "$(sed 's/"/\\"/g' "$abs" 2>/dev/null || echo)" \
          "$(cat "$input")")

        local order; order=($(autotune_model_order))

        for m in "${order[@]}"; do
          local outfile="$fdir/model_${m}.txt"
          local t0=$(date +%s%N)
          run_model_and_wait "$m" "$prompt" "$outfile"
          local t1=$(date +%s%N)
          local latency=$(( (t1 - t0)/1000000 ))
          local metrics; metrics=$(score_model_output "$m" "$outfile" "$latency")
          update_scoreboard_with_metrics "$m" "$metrics"
        done

        local best_model
        best_model=$(load_scoreboard; echo "$SCORE_JSON" | jq -r 'to_entries | sort_by(.value.score) | reverse | .[0].key')

        cp "$fdir/model_${best_model}.txt" "$fdir/enhanced_file"

        if [[ -f "$abs" ]]; then
          diff -u "$abs" "$fdir/enhanced_file" > "$fdir/patch.diff" || true
          act=$(safe_apply_patch "$fdir/patch.diff" "$abs" "$fdir")
        else
          cp "$fdir/enhanced_file" "$abs"
        fi

        mark_models_applied_for_file "$fdir" "$rel"
      ) &
      while (( $(jobs | wc -l) >= MAX_PARALLEL_JOBS )); do sleep 0.3; done
    done
    wait
  done

  log "All files processed."
  log "Done."
}

main "$@"

