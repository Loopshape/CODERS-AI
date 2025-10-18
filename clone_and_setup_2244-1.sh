#!/bin/bash
# clone_and_setup_2244-1.sh
# One-step setup: clone repo, protect Neuro, ready to run

REPO_URL="git@github.com:Loopshape/CODERS-AI.git"
TARGET_DIR="2244-1"

# === Clone repo if folder doesn't exist ===
if [ ! -d "$TARGET_DIR" ]; then
    echo "[INFO] Cloning repository into $TARGET_DIR..."
    git clone "$REPO_URL" "$TARGET_DIR" || { echo "[ERROR] Clone failed"; exit 1; }
else
    echo "[INFO] Folder $TARGET_DIR already exists. Pulling latest changes..."
    cd "$TARGET_DIR" || exit 1
    git pull origin main || echo "[WARNING] Pull failed, continuing..."
    cd ..
fi

cd "$TARGET_DIR" || { echo "[ERROR] Cannot enter $TARGET_DIR"; exit 1; }

# === Watermark creation ===
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

# === Setup core runner ===
CORE_RUNNER="./core/ai_runner.sh"
if [ -f "$CORE_RUNNER" ]; then
    chmod +x "$CORE_RUNNER"
    echo "[INFO] Core AI runner ready"
else
    echo "[WARNING] Core AI runner missing!"
fi

echo "[SETUP COMPLETE] $TARGET_DIR is ready. Run './neuro_runner.sh' or './core/ai_runner.sh'."
