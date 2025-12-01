#!/bin/bash

# ProPrompt.sh - A Concurrent Parallel Accelerated Orchestration
# This script simulates a multi-agent AI system based on a circular,
# asynchronous communication model. It uses embedded Node.js for data
# ingestion and Python for agent reasoning, all orchestrated by Bash.

# --- Configuration ---
AGENT_NAMES=("Cube" "Core" "Loop" "Wave" "Line" "Coin" "Code" "Work")
NUM_AGENTS=${#AGENT_NAMES[@]}
PI=3.14159265359
STEP_ANGLE=$(echo "2 * $PI / $NUM_AGENTS" | bc -l)
STEP_DELAY=0.05 # A small delay to simulate the 2Pi/8 offset

# --- ANSI Color Codes ---
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_MAGENTA='\033[0;35m'
C_CYAN='\033[0;36m'
C_WHITE='\033[1;37m'
C_NC='\033[0m' # No Color

# --- Dependency Check ---
command -v node >/dev/null 2>&1 || { echo -e "${C_RED}Error: 'node' is not installed. Aborting.${C_NC}"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo -e "${C_RED}Error: 'python3' is not installed. Aborting.${C_NC}"; exit 1; }
command -v bc >/dev/null 2>&1 || { echo -e "${C_RED}Error: 'bc' is not installed. Aborting.${C_NC}"; exit 1; }

# --- Input Validation ---
if [ -z "$1" ]; then
    echo -e "${C_RED}Usage: $0 \"<prompt or url>\"${C_NC}"
    exit 1
fi
INPUT_PROMPT="$1"

# --- 1. Genesis Phase: Setup and Hashing ---
echo -e "${C_WHITE}--- GENESIS PHASE ---${C_NC}"
# Create a temporary, isolated global memory space for this run
GLOBAL_MEMORY_DIR=$(mktemp -d -t proprompt.XXXXXX)
echo -e "${C_CYAN}Global Memory Index created at: ${GLOBAL_MEMORY_DIR}${C_NC}"

# Calculate the Genesis Hash from the initial input
GENESIS_HASH=$(echo -n "$INPUT_PROMPT" | sha256sum | awk '{print $1}')
echo -e "${C_CYAN}Genesis Hash (SHA256 of input): ${GENESIS_HASH}${C_NC}"
echo "{\"genesis_hash\": \"${GENESIS_HASH}\", \"input\": \"$INPUT_PROMPT\", \"status\": \"initiated\"}" > "${GLOBAL_MEMORY_DIR}/manifest.json"

# --- 2. Embedded Agents Logic ---

# Node.js Agent: Handles URL fetching and initial data processing (Wave's primary role)
# We use a heredoc to embed the ES Module script.
cat > "${GLOBAL_MEMORY_DIR}/data_ingestor.mjs" <<'EOF'
import { promises as fs } from 'fs';

async function ingest(input) {
    let content;
    try {
        // Check if input is a valid URL
        const url = new URL(input);
        console.log(`[Node Ingestor] Detected URL. Fetching content from: ${url}`);
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        // For simplicity, we'll process as text. A real system would handle content types.
        content = `Content fetched from URL ${url}:\n\n${await response.text()}`;
    } catch (_) {
        // If it's not a URL, treat it as a raw prompt
        console.log('[Node Ingestor] Detected raw prompt.');
        content = input;
    }
    return content;
}

const inputFile = process.argv[2];
const outputFile = process.argv[3];

if (!inputFile || !outputFile) {
    console.error('Usage: node data_ingestor.mjs <path_to_input_manifest> <path_to_output_file>');
    process.exit(1);
}

(async () => {
    try {
        const manifest = JSON.parse(await fs.readFile(inputFile, 'utf-8'));
        const processedContent = await ingest(manifest.input);
        await fs.writeFile(outputFile, processedContent);
        console.log(`[Node Ingestor] Initial data processed and written to ${outputFile}`);
    } catch (error) {
        console.error(`[Node Ingestor] Error: ${error.message}`);
        await fs.writeFile(outputFile, `Error processing input: ${error.message}`);
    }
})();
EOF


# Python Agent: Simulates the reasoning for all 8 agents
# This single Python file contains the logic for every agent role.
cat > "${GLOBAL_MEMORY_DIR}/agent_reasoner.py" <<'EOF'
import sys
import time
import hashlib

def think(agent_name, prompt):
    """Simulates the reasoning process for a given agent."""
    
    # Simulate cognitive load
    time.sleep(0.1) 
    
    reasoning = ""
    if agent_name == "Cube":
        reasoning = f"""
### Perspective by Cube ###
1.  **Structural View:** The request can be broken down into components: Orchestration, Parallelism, and Validation.
2.  **Functional View:** The goal is to achieve faster, more robust results by combining specialized agent outputs.
3.  **Implementation View:** A hybrid script (Bash, Node, Python) can model this, using file-based shared memory for communication.
"""
    elif agent_name == "Core":
        reasoning = f"""
### Foundational Algorithms by Core ###
-   **Concurrency Model:** Fork-Join Parallelism.
-   **Communication:** Asynchronous broadcast via a shared file system (publish-subscribe pattern).
-   **Validation:** Cryptographic Hashing (SHA-256) for data integrity checks (Genesis and Final hashes).
-   **Topology:** Simulated Ring Topology with stepped execution delays.
"""
    elif agent_name == "Loop":
        reasoning = f"""
### Predictive Analysis by Loop ###
-   **Pattern Detected:** The query implies a need for emergent intelligence from collaborative simple agents.
-   **Prediction:** The final assembled output will likely be more comprehensive than a single-agent response.
-   **Trend:** The 'crosslined path' suggests that all agents should have access to all other agents' data, predicting a need for a final aggregation step.
"""
    elif agent_name == "Wave":
        # Wave's role is primarily data ingestion, but it also processes it.
        line_count = len(prompt.splitlines())
        word_count = len(prompt.split())
        reasoning = f"""
### Data Processing by Wave ###
-   **Input Type:** Analyzed as {'URL content' if prompt.startswith('Content fetched') else 'Raw Text'}.
-   **Metrics:** Input contains approximately {line_count} lines and {word_count} words.
-   **Initial Token Stream:** The data is now ready for deep processing by other agents.
"""
    elif agent_name == "Line":
        reasoning = f"""
### Alignment & Assignment by Line ###
-   **Task Breakdown (Plan):**
    1.  [Genesis] Create secure workspace and initial hash.
    2.  [Wave/Ingest] Fetch and clean the input data.
    3.  [Cube, Core, Loop, etc.] All agents analyze data in parallel from their unique perspectives.
    4.  [Work] Assemble all parallel streams into a final, coherent response.
    5.  [Validation] Re-hash the final output to ensure integrity.
-   **Alignment:** All outputs must be text-based and stored in the global memory index.
"""
    elif agent_name == "Coin":
        reasoning = f"""
### Functionality Implementation by Coin ###
-   **System Functionality:**
    -   `parse_prompt_or_url()`: Implemented via Node.js fetch API.
    -   `orchestrate_in_parallel()`: Implemented via Bash background processes (`&`).
    -   `share_tokenize_stream()`: Implemented via agent-specific output files.
    -   `rehash_and_validate()`: Implemented via `sha256sum`.
"""
    elif agent_name == "Code":
        reasoning = f"""
### Programming Logic by Code ###
-   **Orchestrator (Bash):**
    ```bash
    for i in {{0..7}}; do
        python3 agent.py $AGENTS[$i] &
    done
    wait
    ```
-   **Reasoner (Python):**
    ```python
    if agent == 'Cube':
        # Generate 3 perspectives
    elif agent == 'Core':
        # Extract algorithms
    ...
    ```
-   **Data Ingestor (Node.js):**
    ```javascript
    const response = await fetch(url);
    const text = await response.text();
    ```
"""
    elif agent_name == "Work":
        # 'Work' has a special role: assembly. It gets all other agent data.
        reasoning = f"\n### Final Assembly by Work ###\nThis is the reorchestrational chunk-assembly of all agent outputs, synchronized and validated for a final coherent answer.\n"
        reasoning += prompt # In this case, prompt is the concatenated data
    else:
        reasoning = f"Agent {agent_name} reporting: No specific logic defined."

    return reasoning.strip()

if __name__ == "__main__":
    agent_name = sys.argv[1]
    input_file_path = sys.argv[2]
    output_file_path = sys.argv[3]

    with open(input_file_path, 'r', encoding='utf-8') as f:
        prompt_data = f.read()

    result = think(agent_name, prompt_data)

    with open(output_file_path, 'w', encoding='utf-8') as f:
        f.write(result)
EOF

# --- 3. Orchestration Phase: Concurrent Execution ---
echo -e "\n${C_WHITE}--- ORCHESTRATION PHASE ---${C_NC}"
echo -e "${C_MAGENTA}Posing agents on a circled position with a 2*Pi/8 stepped offset...${C_NC}"

# Step 3.1: Wave's primary function - Data Ingestion
echo -e "[${C_YELLOW}WAVE${C_NC}] Performing initial data ingestion..."
node "${GLOBAL_MEMORY_DIR}/data_ingestor.mjs" "${GLOBAL_MEMORY_DIR}/manifest.json" "${GLOBAL_MEMORY_DIR}/initial_data.txt"
if [ $? -ne 0 ]; then
    echo -e "${C_RED}Data ingestion failed. Aborting.${C_NC}"
    rm -rf "${GLOBAL_MEMORY_DIR}"
    exit 1
fi
echo -e "[${C_YELLOW}WAVE${C_NC}] Ingestion complete. Data is now in global memory."

# Step 3.2: Launch all reasoning agents in parallel
pids=()
for i in $(seq 0 $(($NUM_AGENTS - 1))); do
    AGENT_NAME=${AGENT_NAMES[$i]}
    
    # Skip 'Work' agent for now, it runs last.
    if [ "$AGENT_NAME" == "Work" ]; then
        continue
    fi
    
    # Calculate offset and position
    OFFSET_DELAY=$(echo "$i * $STEP_DELAY" | bc -l)
    POSITION_RADIANS=$(echo "$i * $STEP_ANGLE" | bc -l)

    echo -e "[${C_YELLOW}${AGENT_NAME}${C_NC}] Commencing thought process at position ${POSITION_RADIANS:.2f} rad, offset ${OFFSET_DELAY}s"
    
    # Each agent works on the initial data and writes to its own file
    # The `sleep` simulates the "stepped offset"
    ( sleep $OFFSET_DELAY && \
      python3 "${GLOBAL_MEMORY_DIR}/agent_reasoner.py" "$AGENT_NAME" "${GLOBAL_MEMORY_DIR}/initial_data.txt" "${GLOBAL_MEMORY_DIR}/token_stream_${AGENT_NAME}.txt"
    ) &
    pids+=($!)
done

# Wait for all parallel agents to complete their reasoning
echo -e "${C_MAGENTA}Waiting for all crosslined paths to commute...${C_NC}"
for pid in "${pids[@]}"; do
    wait $pid
done
echo -e "${C_GREEN}All agents have completed their individual reasoning.${C_NC}"

# --- 4. Assembly Phase: Reorchestration and Validation ---
echo -e "\n${C_WHITE}--- ASSEMBLY & VALIDATION PHASE ---${C_NC}"
echo -e "[${C_YELLOW}Work${C_NC}] Initiating reorchestrational chunk-assembly..."

# Concatenate all token streams for the 'Work' agent
ASSEMBLY_INPUT_FILE="${GLOBAL_MEMORY_DIR}/assembly_input.txt"
for AGENT_NAME in "${AGENT_NAMES[@]}"; do
    if [ "$AGENT_NAME" != "Work" ]; then
        cat "${GLOBAL_MEMORY_DIR}/token_stream_${AGENT_NAME}.txt" >> "$ASSEMBLY_INPUT_FILE"
        echo -e "\n\n" >> "$ASSEMBLY_INPUT_FILE"
    fi
done

# 'Work' agent assembles the final result
FINAL_ANSWER_FILE="${GLOBAL_MEMORY_DIR}/final_answer.txt"
python3 "${GLOBAL_MEMORY_DIR}/agent_reasoner.py" "Work" "$ASSEMBLY_INPUT_FILE" "$FINAL_ANSWER_FILE"

# Calculate the final hash for entropic validation
FINAL_HASH=$(cat "$FINAL_ANSWER_FILE" | sha256sum | awk '{print $1}')
echo -e "${C_CYAN}Final Rehash for Entropic Validation: ${FINAL_HASH}${C_NC}"

# --- 5. Final Output ---
echo -e "\n${C_GREEN}--- FINAL ORCHESTRATED RESPONSE ---${C_NC}"
cat "$FINAL_ANSWER_FILE"

# --- 6. Cleanup ---
rm -rf "${GLOBAL_MEMORY_DIR}"
echo -e "\n${C_BLUE}Global Memory Index destroyed. Orchestration complete.${C_NC}"
