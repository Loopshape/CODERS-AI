#!/usr/bin/env bash
# visualizer.sh – terminal live UI für 8 Agenten

LOGDIR="${HOME}/.ai_prime_logs"

clear
echo "=== Agent Visualizer ==="
echo "Watching logs in: $LOGDIR"
echo

while true; do
  clear
  echo "=== LIVE AGENT STREAM ==="
  echo

  for agent in cube core loop wave line coin code work; do
    echo "[$agent]"
    tail -n 3 "$LOGDIR/$agent.log" 2>/dev/null | sed 's/^/  /'
    echo
  done

  sleep 0.8
done

