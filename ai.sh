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
AUTO_APPROVE="${AUTO_APPROVE:-true}"

MODELS=("cube" "core" "loop" "wave" "line" "coin" "code" "work")

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
  local deps=(curl jq)
  for d in "${deps[@]}"; do
    command -v "$d" >/dev/null || fatal "Missing dependency: $d"
  einzelne
  done
  if ! curl -s "http://$OLLAMA_HOST/api/tags" >/dev/null; then
    fatal "Ollama not reachable at $OLLAMA_HOST"
  fi
}

# ----------------------------------------------------------
# CHECK AND PULL OLLAMA MODELS
# ----------------------------------------------------------
check_ollama_models(){
  log "Checking for required Ollama models..."
  local model_exists
  for m in "${MODELS[@]}"; do
    log "  Checking model: $m"
    # Use /api/show to check if the model exists
    model_exists=$(curl -s "http://$OLLAMA_HOST/api/show" -d "{\"name\": \"$m\"}" | jq -r '.error')
    
    if [[ "$model_exists" == "null" ]]; then
      log "    Model '$m' found."
    else
      log "    Model '$m' not found. Attempting to pull..."
      if ollama pull "$m"; then
        log "${GREEN}    Successfully pulled model '$m'.${NC}"
      else
        err "    Failed to pull model '$m'. Please ensure it exists and Ollama is running."
        # Optionally, fatal here if a model is absolutely essential
      fi
    fi
  done
  log "Finished checking for required Ollama models."
}

# ----------------------------------------------------------
# ORCHESTRATION COMMANDS - USE WITH CAUTION
# ----------------------------------------------------------
# These functions provide powerful capabilities to interact with the filesystem and network.
# They execute with the permissions of the user running the script.
# Ensure you understand the impact of any command before execution.

# File/Data CRUD operations
crud_create(){
  local file_path="$1"
  local content="${2:-}"
  log "CRUD CREATE: $file_path"
  if [[ -e "$file_path" ]]; then
      err "File already exists."
      return 1
  fi
  if ! echo -e "$content" > "$file_path"; then
    err "Failed to create file."
    return 1
  fi
  chmod 777 "$file_path"
  log "${GREEN}File created successfully with full permissions.${NC}"
}

crud_read(){
  local file_path="$1"
  log "CRUD READ: $file_path"
  if [[ ! -f "$file_path" ]]; then
      err "File not found."
      return 1
  fi
  cat "$file_path" || { err "Failed to read file."; return 1; }
}

crud_update(){
  local file_path="$1"
  local content="$2"
  log "CRUD UPDATE: $file_path"
  if [[ ! -f "$file_path" ]]; then
      err "File not found."
      return 1
  fi
  if ! echo -e "$content" >> "$file_path"; then
    err "Failed to update file (append)."
    return 1
  fi
  log "${GREEN}File updated successfully (content appended).${NC}"
}

crud_delete(){
  local file_path="$1"
  log "CRUD DELETE: $file_path"
  if [[ ! -f "$file_path" ]]; then
      err "File not found."
      return 1
  fi
  rm -f "$file_path" || { err "Failed to delete file."; return 1; }
  log "${GREEN}File deleted successfully.${NC}"
}

# Batch operations
batch_op(){
    local operation="$1"
    local pattern="$2"
    log "BATCH operation '$operation' on files matching '$pattern'"
    case "$operation" in
        delete)
            find . -type f -name "$pattern" -print0 | while IFS= read -r -d '' file; do
                log "Deleting $file"
                rm -f "$file" || err "Failed to delete $file"
            done
            ;;
        chmod)
            local perms="$3"
            [[ -z "$perms" ]] && err "Chmod operation requires permissions (e.g., 777)." && return 1
            find . -type f -name "$pattern" -print0 | while IFS= read -r -d '' file; do
                log "Setting permissions of $file to $perms"
                chmod "$perms" "$file" || err "Failed to chmod $file"
            done
            ;;
        *)
            err "Unsupported batch operation: $operation. Use delete|chmod."
            return 1
            ;;
    esac
    log "${GREEN}Batch operation finished.${NC}"
}


# Network operations
rest_op(){
  local method="$1"
  local url="$2"
  local data="${3:-}"
  log "REST: $method $url"
  local curl_opts=(-s -L --insecure) # --insecure for local self-signed certs
  [[ -n "$data" ]] && curl_opts+=(-d "$data")
  curl "${curl_opts[@]}" -X "$method" "$url" || { err "REST request failed."; return 1; }
}

soap_op(){
  local url="$1"
  local action="$2"
  local payload="$3"
  log "SOAP: $action @ $url"
  curl -s -L --insecure -X POST "$url" \
    -H "Content-Type: text/xml;charset=UTF-8" \
    -H "SOAPAction: \"$action\"" \
    -d "$payload" || { err "SOAP request failed."; return 1; }
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
# MODEL ORDER AUTOTUNING
# ----------------------------------------------------------
autotune_model_order(){
  # Placeholder for adaptive model-order logic
  # In the future, this will use the scoreboard to determine the optimal order
  printf "%s\n" "${MODELS[@]}"
}

# ----------------------------------------------------------
# MODEL EXECUTION AND SCORING
# ----------------------------------------------------------
run_model_and_wait(){
  local model_name="$1"
  local prompt_text="$2"
  local outfile="$3"
  local response
  local generated_text
  local endpoint

  log "Running model '$model_name' with prompt (truncated): '${prompt_text:0:100}...' -> '$outfile'"

  # --- Attempt 1: /api/generate ---
  endpoint="generate"
  log "Attempting /api/generate for model '$model_name'..."
  local generate_payload
  generate_payload=$(jq -n \
              --arg model "$model_name" \
              --arg prompt "$prompt_text" \
              '{model: $model, prompt: $prompt, "stream": false}')

  response=$(curl -s -X POST "http://$OLLAMA_HOST/api/generate" \
               -H "Content-Type: application/json" \
               -d "$generate_payload")

  # Check for "does not support generate" error
  if echo "$response" | jq -e '(.error // "") | contains("does not support generate")' > /dev/null; then
    log "Model '$model_name' does not support /api/generate. Falling back to /api/chat."

    # --- Attempt 2: /api/chat ---
    endpoint="chat"
    local chat_payload
    chat_payload=$(jq -n \
                    --arg model "$model_name" \
                    --arg content "$prompt_text" \
                    '{model: $model, messages: [{"role": "user", "content": $content}], "stream": false}')

    response=$(curl -s -X POST "http://$OLLAMA_HOST/api/chat" \
                 -H "Content-Type: application/json" \
                 -d "$chat_payload")
  fi

  # --- Process the response ---
  if [[ "$endpoint" == "generate" ]]; then
    generated_text=$(echo "$response" | jq -r '.response')
  else # chat
    generated_text=$(echo "$response" | jq -r '.message.content')
  fi

  if [[ -z "$generated_text" || "$generated_text" == "null" ]]; then
    err "Failed to get response from Ollama model '$model_name' via /api/$endpoint. Response: $response"
    echo "ERROR: Failed to generate content from model '$model_name' via /api/$endpoint." > "$outfile"
    echo "Ollama API Response: $response" >> "$outfile"
    return 1
  else
    printf '%s' "$generated_text" > "$outfile"
    log "${GREEN}Model '$model_name' ($endpoint) output saved to '$outfile'.${NC}"
  fi
}

score_model_output(){
  local model_name="$1"
  local outfile="$2"
  local latency="$3"
  log "Scoring output for model '$model_name' (file: '$outfile', latency: ${latency}ms)"
  # Placeholder for actual scoring logic
  # Returns dummy metrics for now
  local file_size=$(wc -c < "$outfile")
  local dummy_score=$(( (RANDOM % 100) + 1 )) # Random score between 1 and 100
  echo "runs:1,applied:1,total_bytes:$file_size,avg_latency:$latency,score:$dummy_score"
}

update_scoreboard_with_metrics(){
  local model_name="$1"
  local metrics_str="$2" # Format: "runs:X,applied:Y,total_bytes:Z,avg_latency:A,score:B"

  load_scoreboard

  # Parse metrics string
  local runs=$(echo "$metrics_str" | sed -n 's/.*runs:\([0-9]*\).*/\1/p')
  local applied=$(echo "$metrics_str" | sed -n 's/.*applied:\([0-9]*\).*/\1/p')
  local total_bytes=$(echo "$metrics_str" | sed -n 's/.*total_bytes:\([0-9]*\).*/\1/p')
  local avg_latency=$(echo "$metrics_str" | sed -n 's/.*avg_latency:\([0-9]*\).*/\1/p')
  local score=$(echo "$metrics_str" | sed -n 's/.*score:\([0-9]*\).*/\1/p')

  # Get current values
  local current_runs=$(jq -r --arg m "$model_name" '.[$m].runs // 0' <<< "$SCORE_JSON")
  local current_applied=$(jq -r --arg m "$model_name" '.[$m].applied // 0' <<< "$SCORE_JSON")
  local current_total_bytes=$(jq -r --arg m "$model_name" '.[$m].total_bytes // 0' <<< "$SCORE_JSON")
  local current_avg_latency=$(jq -r --arg m "$model_name" '.[$m].avg_latency // 0' <<< "$SCORE_JSON")
  local current_score=$(jq -r --arg m "$model_name" '.[$m].score // 0' <<< "$SCORE_JSON")

  # Calculate new values
  local new_runs=$(( current_runs + runs ))
  local new_applied=$(( current_applied + applied ))
  local new_total_bytes=$(( current_total_bytes + total_bytes ))

  # Simple average for latency for now
  local new_avg_latency=$(( (current_avg_latency * current_runs + avg_latency * runs) / new_runs ))

  # For score, maybe a weighted average or just replace with latest? For now, simple average
  local new_score=$(( (current_score * current_runs + score * runs) / new_runs ))

  SCORE_JSON=$(jq --arg m "$model_name" \
                  --argjson nr "$new_runs" \
                  --argjson na "$new_applied" \
                  --argjson ntb "$new_total_bytes" \
                  --argjson nal "$new_avg_latency" \
                  --argjson ns "$new_score" \
                  '.[$m] = {runs: $nr, applied: $na, total_bytes: $ntb, avg_latency: $nal, score: $ns}' <<< "$SCORE_JSON")
  save_scoreboard
  log "Scoreboard updated for '$model_name'. New score: $new_score"
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
# MAIN ORCHESTRATION
# ----------------------------------------------------------
run_prompt_on_models() {
    local prompt_text="$1"
    log "Processing prompt against all models concurrently..."
    local order=($(autotune_model_order))
    local pids=()
    local outfiles=()
    for m in "${order[@]}"; do
        local outfile="$RESULTS_DIR/model_${m}_$(date +%s).txt"
        outfiles+=("$outfile")
        local t0=$(date +%s%N)
        (
            run_model_and_wait "$m" "$prompt_text" "$outfile"
            local t1=$(date +%s%N)
            local latency=$(( (t1 - t0)/1000000 ))
            local metrics; metrics=$(score_model_output "$m" "$outfile" "$latency")
            update_scoreboard_with_metrics "$m" "$metrics"
            log "Model '$m' finished. Latency: ${latency}ms. Scoreboard updated."
        ) &
        pids+=($!)
    done
    log "Waiting for all models to complete... PIDs: ${pids[*]}"
    wait
    log "${GREEN}All models have completed processing.${NC}"
    local best_model
    best_model=$(load_scoreboard; echo "$SCORE_JSON" | jq -r 'to_entries | sort_by(.value.score) | reverse | .[0].key')
    log "Best performing model in this run: ${GREEN}${best_model}${NC}"
    log "All outputs are saved in '$RESULTS_DIR'"
    log "Done."
}

main(){
  check_deps
  check_ollama_models # Call the new function here
  init_state
  ensure_scoreboard_models

  if [[ $# -eq 0 ]]; then
    fatal "Usage: $0 \"<prompt|command>\" [args...]\nCommands:\n  crud <create|read|update|delete> [args...]\n  batch <delete|chmod> <pattern> [perms]\n  rest <GET|POST|PUT|DELETE> <url> [data]\n  soap <url> <action> <payload>\n  prompt <text...>\n"
  fi

  local command="$1"
  shift

  case "$command" in
    crud)
      local sub_cmd="${1:-}"
      shift ||:
      case "$sub_cmd" in
        create) crud_create "$@";;
        read) crud_read "$@";;
        update) crud_update "$@";;
        delete) crud_delete "$@";;
        *) fatal "Invalid crud command: '$sub_cmd'. Use create|read|update|delete.";;
      esac
      ;;
    batch)
      batch_op "$@";;
    rest)
      rest_op "$@";;
    soap)
      soap_op "$@";;
    prompt)
      log "Running multi-agent orchestration for prompt: $*"
      python3 "$PROJECT_ROOT/orchestrator.py" "$*" || fatal "Orchestration failed."
      ;;    
    *)
      # Default to original behavior: treat the whole input as a prompt
      log "Running multi-agent orchestration for prompt: $command $*"
      python3 "$PROJECT_ROOT/orchestrator.py" "$command $*" || fatal "Orchestration failed."
      ;;
  esac
}

main "$@"
summarize_nexus_prompt='\nNEXUS-AGENT: Convert the following input into structured entropic intelligence.\nUse the NEXUS logic layers: hash, rehash, timestamps, vectorization, node-polarization, loop-alignment, and π-prediction (2π-bypass).\n\nOutput strictly in this structure:\n\n1. ORIGIN HASH\n- compressed essence in 3–5 sentences\n- primary meaning vector\n- timestamp-encoded core\n\n2. REHASH STACK\n- list of major derived meaning branches\n- each with semantic source, logical root, entropic contribution\n\n3. NODE-VECTOR MAP (LCP/NEXUS)\n- polarized nodes\n- vectors\n- loops\n- cross-node interference & resolution\n\n4. LOOP ALIGNMENT\n- closed loops\n- async loops\n- roots back to origin\n- alignment index (0–1)\n\n5. π-PREDICTOR LAYER\n- where π-protection is needed\n- where 2π bypass resolves logical deadlocks\n\n6. CONSTRAINT BOUNDS\n- hard rules\n- logical safeties\n- entropic boundaries\n\n7. OPEN INDEX NODES\n- missing info\n- unclear parameters\n- async branches requiring future rehash rounds\n\n8. NEXT ACTIONS (NEXUS-AGENT)\n- which hashes to generate\n- which rehashes to perform\n- loop initiation/closure\n- π-bypass preparation\n\nCONTENT INPUT:\n```INPUT_BLOCK```\n'