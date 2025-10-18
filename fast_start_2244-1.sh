#!/bin/bash
# Fast start for 2244-1: clones, protects, and launches Neuro + AI runner

REPO_URL="git@github.com:Loopshape/CODERS-AI.git"
TARGET_DIR="2244-1"

# === Clone or update repo ===
if [ ! -d "$TARGET_DIR" ]; then
    echo "[INFO] Cloning repository into $TARGET_DIR..."
    git clone "$REPO_URL" "$TARGET_DIR" || { echo "[ERROR] Clone failed"; exit 1; }
else
    echo "[INFO] Folder $TARGET_DIR exists. Pulling latest changes..."
    cd "$TARGET_DIR" || exit 1
    git pull origin main || echo "[WARNING] Pull failed, continuing..."
    cd ..
fi

cd "$TARGET_DIR" || { echo "[ERROR] Cannot enter $TARGET_DIR"; exit 1; }

# === Watermark file ===
if [ ! -f ".origin" ]; then
    echo "2244-1 root origin" > .origin
    echo "[INFO] Watermark '.origin' created"
fi

# === Protect Neuro ===
NEURO_FILE="./neuro_runner.sh"
if [ -f "$NEURO_FILE" ]; then
    chmod 700 "$NEURO_FILE"
    echo "[INFO] Neuro protection enabled (700)"
else
    echo "[WARNING] Neuro runner missing!"
fi

# === Prepare core AI runner ===
CORE_RUNNER="./core/ai_runner.sh"
if [ -f "$CORE_RUNNER" ]; then
    chmod +x "$CORE_RUNNER"
    echo "[INFO] Core AI runner ready"
else
    echo "[WARNING] Core AI runner missing!"
fi

# === Enforce correct folder ===
CURRENT_DIR=$(basename "$PWD")
if [ "$CURRENT_DIR" != "2244-1" ]; then
    echo "[ERROR] Must run inside folder '2244-1'. Aborting."
    exit 1
fi

# === Launch Neuro + AI runner safely ===
echo "[INFO] Starting Neuro and AI runner loop..."
while true; do
    ./neuro_runner.sh "$@" &
    NEURO_PID=$!
    ./core/ai_runner.sh "$@" &
    AI_PID=$!
    
    wait $NEURO_PID
    wait $AI_PID

    echo "[INFO] Neuro + AI loop finished, restarting in 2 seconds..."
    sleep 2
done
