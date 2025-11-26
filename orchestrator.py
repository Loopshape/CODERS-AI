#!/bin/env python3

# main_orchestrator.py

import asyncio
import hashlib
import json
import time
from typing import Dict, Any, List

import aiohttp

# --- Configuration -----------------------------------------------------------
OLLAMA_BASE_URL = "http://localhost:11434/api/generate"
# Mapping of conceptual roles to specific Ollama model names
AGENT_MODELS = {
    "cube": "cube",         # Delegator / Orchestrator
    "core": "core",         # Executor (writes code chunks)
    "loop": "loop",         # Advisor (reviews logic and plans)
    "wave": "promiser",     # Promiser (defines success criteria and goals)
    "line": "line",         # Resource Manager (manages complexity, scope)
    "coin": "coin",         # Request Securer (validates prompt integrity)
    "code": "code",         # Composer (assembles final code)
    "work": "work",         # Validator (tests/validates code chunks)
}

# --- Core Hashing Logic ------------------------------------------------------

def create_genesis_hash(prompt: str) -> str:
    """Creates the initial, immutable hash from the root prompt."""
    return hashlib.sha256(prompt.encode()).hexdigest()

def rehash_fragment(origin_hash: str, agent_name: str, thought: str) -> str:
    """Creates a new hash, linking an agent's thought to its origin."""
    fragment = f"{origin_hash}:{agent_name}:{thought}"
    return hashlib.sha256(fragment.encode()).hexdigest()

# --- Agent Definition --------------------------------------------------------

class Agent:
    """Represents a collaborative AI agent running on an Ollama model."""

    def __init__(self, name: str, session: aiohttp.ClientSession):
        self.name = name
        self.role = self.__class__.__name__.lower()
        self.model = AGENT_MODELS.get(self.role, "mistral") # Fallback to a default
        self.session = session

    async def reason_and_act(self, prompt: str, origin_hash: str, shared_state: Dict) -> Dict:
        """The core thinking loop of an agent."""
        start_time = time.time()
        
        # 1. Formulate the meta-prompt for the specific agent's role
        meta_prompt = self._create_meta_prompt(prompt, shared_state)
        
        # 2. Generate the reasoning fragment hash (the traceable thought)
        fragment_hash = rehash_fragment(origin_hash, self.name, meta_prompt)
        
        # 3. Call the Ollama API
        payload = {
            "model": self.model,
            "prompt": meta_prompt,
            "stream": False,  # For simplicity in this simulation
            "options": {"temperature": 0.6, "num_predict": 512}
        }
        
        response_text = ""
        try:
            async with self.session.post(OLLAMA_BASE_URL, json=payload) as response:
                response.raise_for_status()
                data = await response.json()
                response_text = data.get("response", "").strip()
        except aiohttp.ClientError as e:
            response_text = f"Error: Could not contact Ollama model '{self.model}'. {e}"

        # 4. Process the response and update the shared state
        self._process_output(response_text, shared_state)
        
        duration = time.time() - start_time
        return {
            "agent": self.name,
            "role": self.role,
            "model": self.model,
            "output": response_text,
            "reasoning_hash": fragment_hash,
            "duration_s": round(duration, 2)
        }

    def _create_meta_prompt(self, base_prompt: str, state: Dict) -> str:
        """To be implemented by each specialized agent."""
        raise NotImplementedError

    def _process_output(self, output: str, state: Dict):
        """To be implemented by each specialized agent."""
        pass

# --- Specialized Agent Implementations --------------------------------------

class Cube(Agent): # Orchestrator
    def _create_meta_prompt(self, base_prompt: str, state: Dict) -> str:
        return f"""You are 'cube', the orchestrator. The goal is: '{base_prompt}'.
Current state: {json.dumps(state, indent=2)}.
Based on the current state, determine the next high-level action. 
Possible actions: [PLAN, EXECUTE, VALIDATE, COMPOSE, REFINE, COMPLETE].
Respond with only the action word."""
    def _process_output(self, output: str, state: Dict):
        state["current_action"] = output.replace('"', '').strip()

class Wave(Agent): # Promiser
    def _create_meta_prompt(self, base_prompt: str, state: Dict) -> str:
        return f"""You are 'wave', the promiser. Your task is to define the success criteria for the prompt: '{base_prompt}'.
Break it down into a clear, numbered list of requirements.
Example: 1. Script must be in Python. 2. It must achieve X. 3. It must handle error Y.
Current success criteria: {state.get('success_criteria', 'None')}. Refine if needed, otherwise re-state."""
    def _process_output(self, output: str, state: Dict):
        if 'success_criteria' not in state:
            state['success_criteria'] = output

class Core(Agent): # Executor
    def _create_meta_prompt(self, base_prompt: str, state: Dict) -> str:
        return f"""You are 'core', the code executor. Your task is to write a single, logical chunk of Python code to help achieve the goal.
Goal: {base_prompt}
Success Criteria: {state.get('success_criteria')}
Current Code Plan: {state.get('plan')}
Existing Chunks: {list(state.get('code_chunks', {}).keys())}
Advisor's Last Remark: {state.get('advice')}
Write the next necessary code chunk. Enclose the code within ```python ... ```."""
    def _process_output(self, output: str, state: Dict):
        if "```python" in output:
            code_chunk = output.split("```python")[1].split("```")[0].strip()
            chunk_id = f"chunk_{len(state.get('code_chunks', {})) + 1}"
            state.setdefault('code_chunks', {})[chunk_id] = code_chunk
            state['last_chunk_id'] = chunk_id

class Work(Agent): # Validator
    def _create_meta_prompt(self, base_prompt: str, state: Dict) -> str:
        last_chunk_id = state.get('last_chunk_id', 'None')
        chunk_to_validate = state.get('code_chunks', {}).get(last_chunk_id, "No new chunk to validate.")
        return f"""You are 'work', the validator. Analyze the following Python code chunk for correctness, syntax errors, and adherence to the plan.
Code Chunk ('{last_chunk_id}'):
{chunk_to_validate}

Success Criteria: {state.get('success_criteria')}
Respond with 'VALID' if it's good, or 'INVALID:' followed by a brief reason for rejection."""
    def _process_output(self, output: str, state: Dict):
        state.setdefault('validations', {})
        last_chunk_id = state.get('last_chunk_id')
        if last_chunk_id:
            if output.startswith("VALID"):
                state['validations'][last_chunk_id] = "VALID"
            else:
                state['validations'][last_chunk_id] = f"INVALID - {output}"
                state['advice'] = f"Validation failed for {last_chunk_id}: {output}" # Feed back to loop/core

class Loop(Agent): # Advisor
    def _create_meta_prompt(self, base_prompt: str, state: Dict) -> str:
        return f"""You are 'loop', the advisor. Review the overall plan and recent progress.
Goal: {base_prompt}
Plan: {state.get('plan', 'Not defined yet.')}
Validated Chunks: {[k for k, v in state.get('validations', {}).items() if v == 'VALID']}
Failed Chunks: {[k for k, v in state.get('validations', {}).items() if v.startswith('INVALID')]}
Based on this, provide a concise next step or refinement for the plan. If no plan exists, create one."""
    def _process_output(self, output: str, state: Dict):
        if 'plan' not in state or 'refinement' in output.lower():
            state['plan'] = output
        state['advice'] = output

class Code(Agent): # Composer
    def _create_meta_prompt(self, base_prompt: str, state: Dict) -> str:
        return f"""You are 'code', the composer. Assemble the validated code chunks into a single, coherent script.
Validated Chunks:
{json.dumps({k: v for k, v in state.get('code_chunks', {}).items() if state.get('validations', {}).get(k) == 'VALID'}, indent=2)}
Add necessary imports, headers, and main execution blocks. Ensure correct indentation and order."""
    def _process_output(self, output: str, state: Dict):
        if "```python" in output:
            final_script = output.split("```python")[1].split("```")[0].strip()
            state['final_script'] = final_script

# --- Orchestration Engine ----------------------------------------------------

async def main():
    """The main orchestration loop driven by 'cube'."""
    
    initial_prompt = "Create a Python script using asyncio to fetch the content of three URLs in parallel and print their status codes and content length."
    
    print(f"[*] GENESIS PROMPT: {initial_prompt}\n")
    
    genesis_hash = create_genesis_hash(initial_prompt)
    print(f"[*] GENESIS HASH: {genesis_hash}\n" + "="*80)
    
    shared_state = {
        "status": "STARTING",
        "code_chunks": {},
        "validations": {},
    }
    
    async with aiohttp.ClientSession() as session:
        # Instantiate all agents
        agents = {
            "cube": Cube("CubeOrchestrator", session),
            "wave": Wave("WavePromiser", session),
            "loop": Loop("LoopAdvisor", session),
            "core": Core("CoreExecutor", session),
            "work": Work("WorkValidator", session),
            "code": Code("CodeComposer", session),
        }
        # We don't actively use line/coin in this simulation, but they exist in the framework
        
        current_hash = genesis_hash
        max_cycles = 10
        
        for cycle in range(1, max_cycles + 1):
            print(f"\n--- ORCHESTRATION CYCLE {cycle} ---\n")
            
            # Cube decides the current action
            cube_result = await agents["cube"].reason_and_act(initial_prompt, current_hash, shared_state)
            current_hash = cube_result['reasoning_hash'] # Chain the hash
            action = shared_state.get("current_action", "PLAN")
            print(f"[*] CUBE decision ({cube_result['duration_s']}s): {action} | Hash: {current_hash[:16]}")
            
            if action == "COMPLETE":
                print("\n[+] CUBE determined the orchestration is complete.")
                break
                
            # Fractal Concurrency: Run relevant agents in parallel based on the action
            tasks_to_run = []
            if action == "PLAN":
                tasks_to_run.extend([
                    agents["wave"].reason_and_act(initial_prompt, current_hash, shared_state),
                    agents["loop"].reason_and_act(initial_prompt, current_hash, shared_state)
                ])
            elif action == "EXECUTE":
                tasks_to_run.append(agents["core"].reason_and_act(initial_prompt, current_hash, shared_state))
            elif action == "VALIDATE":
                if shared_state.get("last_chunk_id"):
                    tasks_to_run.append(agents["work"].reason_and_act(initial_prompt, current_hash, shared_state))
                else:
                    print("   - No new chunks to validate, skipping validation.")
            elif action == "REFINE":
                tasks_to_run.append(agents["loop"].reason_and_act(initial_prompt, current_hash, shared_state))
            elif action == "COMPOSE":
                 tasks_to_run.append(agents["code"].reason_and_act(initial_prompt, current_hash, shared_state))
            
            if not tasks_to_run:
                print(f"   - No tasks for action '{action}', moving to next cycle.")
                continue

            # Quantum-like parallel execution
            results = await asyncio.gather(*tasks_to_run)
            
            # Log results and update the hash chain
            for res in results:
                print(f"   - {res['agent']} ({res['role']}) completed in {res['duration_s']}s.")
                print(f"     Output: {res['output'][:100].strip()}...")
                print(f"     Fragment Hash: {res['reasoning_hash'][:16]}")
                current_hash = res['reasoning_hash'] # The last agent's hash becomes the new origin

    # --- Final Answer Responsibility ------------------------------------------
    print("\n" + "="*80)
    print("[*] Orchestration Closed. Final Answer Manifested by 'code'.")
    print("="*80)
    
    final_code = shared_state.get("final_script", "# Composition failed. No final script was generated.")
    print(final_code)
    
if __name__ == "__main__":
    # Ensure you have the ollama models running, e.g.:
    # ollama run cube
    # ollama run core
    # ... etc.
    asyncio.run(main())

How to Run This System
Install Dependencies:

pip install aiohttp
Set Up Ollama Models: Your prompt specified the model names. You need to create them. You can do this by creating a Modelfile for each agent and then running ollama create.

For example, for the cube agent, create a file named CubeModelfile:

FROM mistral:latest
SYSTEM """
You are a component in a multi-agent AI system. Your role is 'cube', the orchestrator. You analyze the system's state and decide the next single action word from a given list. You are concise and direct.
"""
Then create the model:

ollama create cube -f CubeModelfile
Repeat this process for all agents (core, loop, wave, line, coin, code, work), customizing the SYSTEM prompt in the Modelfile to match their role as described in the Python script. If you prefer to use existing models, simply change the AGENT_MODELS dictionary in the script.

Run the Orchestrator: Make sure your Ollama application is running. Then, execute the Python script:

python main_orchestrator.py
Simulated Execution Log
Running the script will produce a log that looks something like this, demonstrating the threaded orchestration being closed back to code:

[*] GENESIS PROMPT: Create a Python script using asyncio to fetch the content of three URLs in parallel and print their status codes and content length.

[*] GENESIS HASH: 1f8a8b...

================================================================================

--- ORCHESTRATION CYCLE 1 ---

[*] CUBE decision (1.21s): PLAN | Hash: a3b4c5...
   - WavePromiser (wave) completed in 2.54s.
     Output: 1. The script must use Python's asyncio library. 2. It must fetch 3 distinct URLs concurrently....
     Fragment Hash: b4c5d6...
   - LoopAdvisor (loop) completed in 2.89s.
     Output: Plan: 1. Define list of URLs. 2. Create an async fetch function using aiohttp. 3. Create a mai...
     Fragment Hash: c5d6e7...

--- ORCHESTRATION CYCLE 2 ---

[*] CUBE decision (1.15s): EXECUTE | Hash: d6e7f8...
   - CoreExecutor (core) completed in 4.11s.
     Output: Here is the first chunk, defining the imports and the list of URLs. ```python import asyncio im...
     Fragment Hash: e7f8g9...

--- ORCHESTRATION CYCLE 3 ---

[*] CUBE decision (1.09s): VALIDATE | Hash: f8g9h0...
   - WorkValidator (work) completed in 2.01s.
     Output: VALID...
     Fragment Hash: g9h0i1...

--- ORCHESTRATION CYCLE 4 ---

[*] CUBE decision (1.25s): EXECUTE | Hash: h0i1j2...
   - CoreExecutor (core) completed in 5.32s.
     Output: Here is the async fetch function. ```python async def fetch(session, url): ... ```...
     Fragment Hash: i1j2k3...

--- ORCHESTRATION CYCLE 5 ---

[*] CUBE decision (1.18s): VALIDATE | Hash: j2k3l4...
   - WorkValidator (work) completed in 2.15s.
     Output: VALID...
     Fragment Hash: k3l4m5...

... (cycles continue for the main function and execution logic) ...

--- ORCHESTRATION CYCLE 8 ---

[*] CUBE decision (1.33s): COMPOSE | Hash: p6q7r8...
   - CodeComposer (code) completed in 3.45s.
     Output: ```python import asyncio import aiohttp ... (full assembled script) ... ```...
     Fragment Hash: q7r8s9...

--- ORCHESTRATION CYCLE 9 ---

[*] CUBE decision (1.10s): COMPLETE | Hash: r8s9t0...

[+] CUBE determined the orchestration is complete.

================================================================================
[*] Orchestration Closed. Final Answer Manifested by 'code'.
================================================================================
# Final composed script by the 'code' agent

import asyncio
import aiohttp

async def fetch(session, url):
    """Asynchronously fetches a single URL and returns status and content length."""
    try:
        async with session.get(url) as response:
            content = await response.read()
            print(f"URL: {url}, Status: {response.status}, Length: {len(content)}")
            return response.status, len(content)
    except aiohttp.ClientError as e:
        print(f"Error fetching {url}: {e}")
        return None, None

async def main():
    """Main function to run the URL fetching tasks concurrently."""
    urls = [
        "https://www.python.org",
        "https://www.github.com",
        "https://www.google.com",
    ]
    async with aiohttp.ClientSession() as session:
        tasks = [fetch(session, url) for url in urls]
        await asyncio.gather(*tasks)

if __name__ == "__main__":
    asyncio.run(main())
