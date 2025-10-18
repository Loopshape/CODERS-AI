#!/bin/bash
# run_2244.sh – Central orchestration CLI

# === Enforce folder & watermark ===
if [ ! -f ".origin" ]; then
    echo "[WARNING] Origin file missing. Some features may be disabled."
fi

CURRENT_DIR=$(basename "$PWD")
if [ "$CURRENT_DIR" != "2244-1" ]; then
    echo "[ERROR] This system only runs inside a folder named '2244-1'."
    exit 1
fi

# === Launch Neuro (Gatekeeper / Peacemaker) ===
echo "[INFO] Launching Neuro – spiritual guidance & gatekeeping..."
./neuro_runner.sh "$@" &
NEURO_PID=$!

# === Launch Core (Headmaster / Central Logic) ===
echo "[INFO] Launching Core..."
./core/ai_runner.sh "$@" &
CORE_PID=$!

# === Launch Loop (Grandmaster / Orchestrator) ===
echo "[INFO] Launching Loop..."
./loop.sh "$@" &
LOOP_PID=$!

# === Launch Code (Freedomfighter / Executor) ===
echo "[INFO] Launching Code..."
./code.sh "$@" &
CODE_PID=$!

# === Launch Coin (Mediator / Ethical Token) ===
echo "[INFO] Launching Coin..."
./coin.sh "$@" &
COIN_PID=$!

# === Launch 2244 (Mythbuster / Reality-checker) ===
echo "[INFO] Launching 2244 – Mythbuster..."
./mythbuster.sh "$@" &
MYTH_PID=$!

# === Wait for all agents to finish ===
wait $NEURO_PID $CORE_PID $LOOP_PID $CODE_PID $COIN_PID $MYTH_PID

echo "[INFO] All agents finished. System orchestration complete."

exit

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
