#!/bin/bash
# AI Runner - Core 2244-1
# Fast, safe, integrated with Neuro and JSON-NLP mesh

# === Check folder & watermark ===
if [ ! -f ".origin" ]; then
    echo "[WARNING] Origin watermark missing. Some features may be disabled."
fi

CURRENT_DIR=$(basename "$PWD")
if [ "$CURRENT_DIR" != "2244-1" ]; then
    echo "[ERROR] Must run inside '2244-1'. Aborting."
    exit 1
fi

# === Timing for performance ===
START_MS=$(date +%s%3N)

# === Parse JSON input if given ===
INPUT_JSON="$1"
if [ -n "$INPUT_JSON" ]; then
    # Simple parse example, extendable with jq
    TOPIC=$(echo "$INPUT_JSON" | jq -r '.topic // empty')
    PROMPT=$(echo "$INPUT_JSON" | jq -r '.prompt // empty')
    echo "[INFO] Input topic: $TOPIC | prompt: $PROMPT"
fi

# === SQLite persistent memory setup ===
DB_FILE="./core/ai_state.db"
if [ ! -f "$DB_FILE" ]; then
    echo "[INFO] Creating new AI state DB..."
    sqlite3 "$DB_FILE" "CREATE TABLE IF NOT EXISTS memory(key TEXT PRIMARY KEY, value TEXT);"
fi

# === JSON-NLP mesh simulation (lightweight vibing) ===
# For now, we just echo, but can expand to neuron-like connections
echo "[INFO] JSON-NLP mesh vibing..."
sleep 0.01  # simulate processing delay

# === Main AI loop (placeholder for actual AI call) ===
echo "[INFO] Running AI logic..."
# Example: log the prompt in DB
if [ -n "$PROMPT" ]; then
    sqlite3 "$DB_FILE" "INSERT OR REPLACE INTO memory(key, value) VALUES('last_prompt', '$PROMPT');"
fi

# === Timing end ===
END_MS=$(date +%s%3N)
ELAPSED_MS=$((END_MS - START_MS))
echo "[INFO] AI Runner finished in ${ELAPSED_MS} ms"

exit 0
