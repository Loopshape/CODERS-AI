#!/bin/bash

# === Step 1: Neuro guidance (protected) ===
if [ -n "$1" ]; then
    INPUT_JSON="{\"topic\":\"system optimization\",\"prompt\":\"$*\"}"
    # Neuro is protected inside its own folder
    ./neuro/neuro_runner.sh "$INPUT_JSON"
fi

# === Step 2: Watermark check ===
if [ ! -f ".origin" ]; then
    echo "[WARNING] Origin file missing. Some features may be disabled."
fi

# === Step 3: Enforce correct folder ===
CURRENT_DIR=$(basename "$PWD")
if [ "$CURRENT_DIR" != "2244-1" ]; then
    echo "[ERROR] This AI system only runs inside a folder named '2244-1'."
    exit 1
fi

# === Step 4: Pass arguments to core AI runner ===
./core/ai_runner.sh "$@"
