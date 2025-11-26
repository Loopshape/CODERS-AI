#!/usr/bin/env bash
# load-balancer.sh – verteilt Prompts über Worker anhand hash/rehash

WORKERS=("$@")

phi="1.6180339887"

hash_prompt() {
  echo -n "$1" | sha256sum | awk '{print $1}'
}

pick_worker() {
  local h="$1"
  local n="${#WORKERS[@]}"

  # hash nach Zahl umwandeln
  local num=$(( 0x${h:0:12} ))

  # golden ratio mapping
  local slot=$(echo "$num * $phi" | awk '{printf("%d",$1)}')
  slot=$(( slot % n ))

  echo "${WORKERS[$slot]}"
}

main() {
  [[ ${#WORKERS[@]} -eq 0 ]] && { echo "No workers"; exit 1; }

  while true; do
    echo -n "Prompt: "
    read -r p
    [[ "$p" == "quit" ]] && break

    h=$(hash_prompt "$p")
    w=$(pick_worker "$h")

    echo "[LB] Hash: $h"
    echo "[LB] Worker selected: $w"

    echo "$p" | nc "$(echo "$w" | cut -d: -f1)" "$(echo "$w" | cut -d: -f2)"
  done
}

main

