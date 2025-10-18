#!/bin/bash

# Ensure correct folder
CURRENT_DIR=$(basename "$PWD")
if [ "$CURRENT_DIR" != "2244-1" ]; then
    echo "[ERROR] Neuro AI only runs inside '2244-1'."
    exit 1
fi

# Pass JSON input to Neuro
if [ -z "$1" ]; then
    echo "[INFO] No input JSON provided. Showing recent suggestions..."
    python3 neuro.py
else
    INPUT_JSON="$1"
    python3 neuro.py "$INPUT_JSON"
fi
