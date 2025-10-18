#!/bin/bash
# setup_and_run.sh — Full build & launch for 2244-1 AI system
# Includes CLI Pygments & Web Prism.js syntax highlighting

# 1️⃣ Set up Python virtual environment
if [ ! -d "venv" ]; then
    echo "[INFO] Creating Python virtual environment..."
    python3 -m venv venv
fi

echo "[INFO] Activating Python environment..."
source venv/bin/activate

# 2️⃣ Install Python requirements including Pygments
if [ -f "requirements.txt" ]; then
    echo "[INFO] Installing Python dependencies..."
    pip install --upgrade pip
    pip install -r requirements.txt
    pip install Pygments
else
    echo "[WARN] requirements.txt not found. Installing only Pygments..."
    pip install --upgrade pip
    pip install Pygments
fi

# 3️⃣ Initialize database
if [ -f "core_db.sh" ]; then
    echo "[INFO] Initializing core database..."
    bash core_db.sh
elif [ -f "ai_db-init.sh" ]; then
    echo "[INFO] Initializing AI database..."
    bash ai_db-init.sh
else
    echo "[WARN] No database init script found. Skipping."
fi

# 4️⃣ Build front-end (Prism.js included automatically)
if [ -f "package.json" ]; then
    echo "[INFO] Installing npm dependencies..."
    npm install
    # Ensure Prism.js is available
    if ! grep -q "prism.js" package.json; then
        echo "[INFO] Adding Prism.js to dependencies..."
        npm install prismjs
    fi
fi

# 5️⃣ Choose mode
MODE=$1
if [ -z "$MODE" ]; then
    echo "[INFO] No mode specified. Defaulting to CLI."
    MODE="cli"
fi

# 6️⃣ Run CLI mode (with Pygments highlighting)
if [ "$MODE" == "cli" ]; then
    echo "[INFO] Launching CLI AI with syntax highlighting..."
    if [ -z "$2" ]; then
        echo "[INFO] No query provided. Launching interactive CLI."
        python3 -m pygments -g
    else
        python3 - <<EOF
from pygments import highlight
from pygments.lexers import PythonLexer
from pygments.formatters import TerminalFormatter

query = """$2"""
print(highlight(query, PythonLexer(), TerminalFormatter()))
EOF
        ./ai.sh "$2"
    fi
    exit 0
fi

# 7️⃣ Run Web mode (Prism.js)
if [ "$MODE" == "web" ]; then
    echo "[INFO] Launching Web AI interface..."
    # Add Prism.js link to HTML if missing
    if ! grep -q "prism.css" index.html; then
        sed -i 's#</head>#<link rel="stylesheet" href="node_modules/prismjs/themes/prism.css"></head>#' index.html
        sed -i 's#</body>#<script src="node_modules/prismjs/prism.js"></script></body>#' index.html
        echo "[INFO] Prism.js injected into index.html"
    fi
    npm run dev
    exit 0
fi

# 8️⃣ Invalid mode
echo "[ERROR] Unknown mode: $MODE"
echo "Usage: ./setup_and_run.sh [cli|web] [optional CLI args]"
exit 1
