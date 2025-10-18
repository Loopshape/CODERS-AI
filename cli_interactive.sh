#!/bin/bash
# cli_interactive.sh — Fully interactive AI CLI with Pygments syntax highlighting

# Activate Python environment
if [ -d "venv" ]; then
    source venv/bin/activate
else
    echo "[WARN] Virtual environment not found. Creating one..."
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install Pygments
fi

# Ensure Pygments is installed
pip install -q Pygments

echo "==============================="
echo "2244-1 AI CLI (interactive mode)"
echo "Type 'exit' to quit"
echo "==============================="

while true; do
    read -p "AI> " query
    [[ "$query" == "exit" ]] && break
    curl -s "http://127.0.0.1:5000/api/run?query=$(echo $query | jq -sRr @uri)"

    # Exit condition
    if [[ "$query" == "exit" ]]; then
        echo "[INFO] Exiting CLI..."
        break
    fi

    # Highlight query using Pygments
    python3 - <<EOF
from pygments import highlight
from pygments.lexers import PythonLexer
from pygments.formatters import TerminalFormatter

query = """$query"""
print(highlight(query, PythonLexer(), TerminalFormatter()))
EOF

    # Call your AI runner (replace ./ai.sh with your CLI AI script)
    ./ai.sh "$query"
done
