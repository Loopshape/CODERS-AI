#!/bin/bash
# Neuro – Gatekeeper & Spiritual Guidance

AGENT="Neuro"

while true; do
    # Example: Send heartbeat
    python3 ./core/mesh.py send "$AGENT" '{"status":"alive","time":"'"$(date)"'"}'
    
    # Receive messages from other agents
    messages=$(python3 ./core/mesh.py receive)
    if [ ! -z "$messages" ]; then
        echo "[NEURO] Received mesh messages: $messages"
    fi

    sleep 1  # adjust for real-time responsiveness
done
