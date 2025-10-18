#!/bin/bash
# setup_2244-1.sh
# Self-contained setup for 2244-1 repo with Neuro protection

TARGET_DIR="2244-1"

# === Enforce correct folder name ===
CURRENT_DIR=$(basename "$PWD")
if [ "$CURRENT_DIR" != "$TARGET_DIR" ]; then
    echo "[INFO] Moving/creating folder: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
    cp -r ./* "$TARGET_DIR/"
    cd "$TARGET_DIR" || { echo "[ERROR] Failed to enter $TARGET_DIR"; exit 1; }
fi

# === Create watermark file ===
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

# === Success message ===
echo "[SETUP COMPLETE] Folder '$TARGET_DIR' ready with Neuro protection."
