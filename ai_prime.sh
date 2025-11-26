cat > ai.sh <<'EOF'
#!/usr/bin/env bash
# ai_prime.sh – orchestrator mit genesis-hash, rehash und parallelen Agenten

set -euo pipefail
OLLAMA_API="http://localhost:11434/api/generate"
STREAM=true
KEEP_ALIVE="5m"

declare -A MODELS=(
  ["cube"]="cube"
  ["core"]="core"
  ["loop"]="loop"
  ["wave"]="wave"
  ["line"]="line"
  ["coin"]="coin"
  ["code"]="code"
  ["work"]="work"
)

LOGDIR="${HOME}/.ai_prime_logs"
mkdir -p "$LOGDIR"

call_model() {
  local agent=$1 prompt=$2 model="${MODELS[$agent]}"
  jq -nc --arg m "$model" --arg p "$prompt" --arg ka "$KEEP_ALIVE" --argjson st "$STREAM" \
    '{model:$m,prompt:$p,keep_alive:$ka,stream:$st}' |
  curl -s "$OLLAMA_API" -H "Content-Type: application/json" -d @-
}

orchestrate() {
  local hash=$1 prompt=$2
  for agent in "${!MODELS[@]}"; do
    (
      local msg="GENESIS_HASH:$hash\nPROMPT:$prompt\nROLE:$agent"
      call_model "$agent" "$msg" | while read -r line; do
        echo "[$agent] $line"
        echo "$line" >> "$LOGDIR/$agent.log"
      done
    ) &
  done
  wait
}

compute_rehash() {
  local buf=""
  for a in "${!MODELS[@]}"; do
    buf+=$(tail -n1 "$LOGDIR/$a.log" 2>/dev/null)
  done
  echo -n "$buf" | sha256sum | awk '{print $1}'
}

main() {
  local hash
  hash=$(date +%s%N | sha256sum | awk '{print $1}')
  while true; do
    echo -n "Prompt: "
    read -r p
    [[ "$p" == quit ]] && break
    orchestrate "$hash" "$p"
    hash=$(compute_rehash)
    echo "REHASH: $hash"
  done
}

main
EOF

