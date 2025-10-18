#!/bin/bash
# build_2244.sh — Setup & build 2244-1 AI environment

set -e  # Exit on any error
echo "[INFO] Starting build_2244.sh for 2244-1 AI..."

# 1️⃣ Ensure git repo is initialized
if [ ! -d ".git" ]; then
    echo "[INFO] Initializing git repository..."
    git init
    git remote add origin git@github.com:Loopshape/CODERS-AI.git
else
    echo "[INFO] Git repo already initialized."
fi

# 2️⃣ Update submodules (if any)
git submodule update --init --recursive

# 3️⃣ Setup Python environment
echo "[INFO] Setting up Python environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt

# 4️⃣ Build front-end (assuming Vite/React)
echo "[INFO] Building web interface..."
npm install
npm run build

# 5️⃣ Prepare CLI scripts
echo "[INFO] Preparing CLI scripts..."
chmod +x ai.sh cli_main.py cli_mem.py
ln -sf 2244.sh ai  # Symlink for easy CLI access

# 6️⃣ Optional: Initialize database
if [ -f "core.db" ]; then
    echo "[INFO] Database already exists."
else
    echo "[INFO] Initializing SQLite database..."
    sqlite3 core.db < db_init.sql
fi

# 7️⃣ Self-check AI scripts
echo "[INFO] Checking AI runner scripts..."
./ai.sh --check || echo "[WARN] Some scripts may need manual review."

# ✅ Done
echo "[INFO] 2244-1 AI build complete!"
echo "[INFO] Activate environment: source venv/bin/activate"
echo "[INFO] Run CLI: ./ai.sh"
echo "[INFO] Run Web: npm run dev"
