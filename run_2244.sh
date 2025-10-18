#!/bin/bash
# run_2244.sh — Auto-launch 2244-1 AI environment

# 1️⃣ Activate Python virtual environment
if [ -d "venv" ]; then
    echo "[INFO] Activating Python environment..."
    source venv/bin/activate
else
    echo "[WARN] Python venv not found. Please run build_2244.sh first."
    exit 1
fi

# 2️⃣ Choose mode (CLI or Web)
MODE=$1
if [ -z "$MODE" ]; then
    echo "[INFO] No mode specified. Defaulting to CLI."
    MODE="cli"
fi

# 3️⃣ Run CLI mode
if [ "$MODE" == "cli" ]; then
    echo "[INFO] Launching CLI AI..."
    ./ai.sh "$2"
    exit 0
fi

# 4️⃣ Run Web mode
if [ "$MODE" == "web" ]; then
    echo "[INFO] Launching Web AI interface..."
    npm run dev
    exit 0
fi

# 5️⃣ Invalid mode
echo "[ERROR] Unknown mode: $MODE"
echo "Usage: ./run_2244.sh [cli|web] [optional CLI args]"
exit 1
