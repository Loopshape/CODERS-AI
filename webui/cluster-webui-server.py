#!/usr/bin/env python3
# cluster-webui-server.py
# Minimal WebSocket server that tails agent logs and broadcasts lines to connected browsers.
# Requirements: pip install websockets aiohttp google-generativeai

import asyncio
import os
import json
import shutil
import signal
from aiohttp import web
import websockets
import google.generativeai as genai

# --- Configuration ---
LOGDIR = os.path.expanduser("~/.ai_prime_logs")
PORT_HTTP = 8080
WS_PATH = "/ws"
AGENTS = ["cube","core","loop","wave","line","coin","code","work"]
OLLAMA_BRIDGE_URL = "ws://localhost:3000"

# --- Gemini AI Configuration ---
try:
    GEMINI_API_KEY = os.environ.get("API_KEY")
    if not GEMINI_API_KEY:
        print("WARNING: API_KEY environment variable not set. Gemini features will be disabled.")
        genai.configure(api_key="DUMMY_KEY_NEVER_WORKS")
    else:
        genai.configure(api_key=GEMINI_API_KEY)
except ImportError:
    print("WARNING: google.generativeai library not found. Gemini features will be disabled.")
    genai = None


clients = set()

# --- Log Tailing ---
async def tail_file(path, agent):
    proc = await asyncio.create_subprocess_exec("tail", "-n", "0", "-F", path,
                                                stdout=asyncio.subprocess.PIPE,
                                                stderr=asyncio.subprocess.DEVNULL)
    try:
        while True:
            line = await proc.stdout.readline()
            if not line:
                await asyncio.sleep(0.1)
                continue
            text = line.decode(errors="ignore").rstrip()
            msg = json.dumps({"agent": agent, "text": text})
            await broadcast(msg)
    except asyncio.CancelledError:
        proc.kill()
        await proc.wait()
        raise

async def broadcast(message):
    if not clients: return
    # Use asyncio.gather for concurrent sends
    await asyncio.gather(*[ws.send_str(message) for ws in clients], return_exceptions=True)

# --- AI Bridge Handlers ---
async def handle_ollama_prompt(ws, prompt):
    AI_SCRIPT_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "ai.sh"))
    
    await ws.send_str(json.dumps({"type": "info", "message": f"Starting AI orchestration for prompt: {prompt}"}))
    
    process = None
    try:
        # Execute ai.sh with the prompt
        # Use os.getcwd() to set the working directory for ai.sh if it relies on current working dir
        # Or explicitly pass PROJECT_ROOT if ai.sh expects it.
        process = await asyncio.create_subprocess_exec(
            AI_SCRIPT_PATH, "prompt", prompt, # Assuming ai.sh expects "prompt" command followed by the actual prompt
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=os.path.join(os.path.dirname(__file__), "..") # Execute ai.sh from the project root
        )

        final_code_buffer = []
        is_code_block = False

        while True:
            stdout_line = await process.stdout.readline()
            stderr_line = await process.stderr.readline()

            if not stdout_line and not stderr_line and process.stdout.at_eof() and process.stderr.at_eof():
                break

            if stdout_line:
                line = stdout_line.decode(errors="ignore").strip()
                await ws.send_str(json.dumps({"type": "ollama_token", "token": line + "\n"})) # Send stdout as tokens

                # Detect final code block
                if "[*] Orchestration Closed. Final Answer Manifested by 'code'." in line:
                    is_code_block = True
                    final_code_buffer = [] # Clear buffer, ready for code
                elif is_code_block and line.startswith("# Final composed script by the 'code' agent"):
                    # This is the header, ignore or capture as needed
                    pass
                elif is_code_block and line.startswith("import") or is_code_block and line.startswith("async def") or is_code_block and line.startswith("class") or is_code_block and line.startswith("if __name__ == "): # Simple heuristic to capture python code
                    final_code_buffer.append(line)
                elif is_code_block and not line and final_code_buffer: # End of code block heuristic
                    is_code_block = False # Reset
                    await ws.send_str(json.dumps({"type": "ollama_final_code", "code": "\n".join(final_code_buffer)}))


            if stderr_line:
                error_line = stderr_line.decode(errors="ignore").strip()
                await ws.send_str(json.dumps({"type": "error", "message": error_line + "\n"})) # Send stderr as errors

        await process.wait() # Wait for the subprocess to finish

        if process.returncode != 0:
            await ws.send_str(json.dumps({"type": "error", "message": f"AI orchestration failed with exit code {process.returncode}"}))
        else:
            await ws.send_str(json.dumps({"type": "ollama_done"}))

    except Exception as e:
        await ws.send_str(json.dumps({"type": "error", "message": f"Server error during AI orchestration: {str(e)}"}))
    finally:
        if process and process.returncode is None:
            process.kill()


async def handle_gemini_review(ws, code, language):
    if not genai or not GEMINI_API_KEY:
        await ws.send_str(json.dumps({"type": "error", "message": "Gemini API not configured. Is API_KEY set?"}))
        return

    prompt = f"""
You are an expert senior software engineer and a world-class code reviewer.
Your task is to provide a comprehensive and constructive review of the following {language} code.

Analyze the code for the following aspects:
1.  **Bugs and Errors:** Identify any potential bugs, logical errors, or edge cases that are not handled.
2.  **Performance:** Suggest optimizations for performance bottlenecks or inefficient code.
3.  **Security:** Point out any potential security vulnerabilities.
4.  **Best Practices & Readability:** Check for adherence to language-specific best practices, code style, and overall readability. Suggest improvements for clarity and maintainability.
5.  **Architecture:** Comment on the overall structure and design, if applicable.

Provide your feedback in Markdown format. Structure your review with clear headings for each category (e.g., ### Bugs, ### Performance).
For each point, explain the issue and suggest a specific code change or improvement. Use code snippets where helpful.
If you find no issues in a category, state "No issues found."

Here is the code to review:
```{language}
{code}
```
"""
    try:
        model = genai.GenerativeModel('gemini-2.5-flash')
        response = await model.generate_content_async(prompt, stream=True)
        async for chunk in response:
            await ws.send_str(json.dumps({"type": "gemini_token", "token": chunk.text}))
        await ws.send_str(json.dumps({"type": "gemini_done"}))

    except Exception as e:
        await ws.send_str(json.dumps({"type": "error", "message": f"Gemini API error: {str(e)}"}))


# --- WebSocket and HTTP Server ---
async def websocket_handler(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    clients.add(ws)
    try:
        async for msg in ws:
            if msg.type == web.WSMsgType.TEXT:
                try:
                    data = json.loads(msg.data)
                    msg_type = data.get("type")
                    if msg_type == "ollama_prompt":
                        asyncio.create_task(handle_ollama_prompt(ws, data.get("prompt", "")))
                    elif msg_type == "gemini_review_prompt":
                         asyncio.create_task(handle_gemini_review(ws, data.get("code", ""), data.get("language", "")))
                except json.JSONDecodeError:
                    pass # Ignore non-json messages
    finally:
        clients.discard(ws)
    return ws

async def index(request):
    # Adjust root path to be relative to this script's location
    root = os.path.dirname(__file__)
    return web.FileResponse(os.path.join(root, "index.html"))

async def static_file(request):
    root = os.path.dirname(__file__)
    path = request.match_info.get('filename')
    filep = os.path.join(root, path)
    if not os.path.exists(filep):
        raise web.HTTPNotFound()
    return web.FileResponse(filep)

async def start_tail_tasks(app):
    app["tasks"] = []
    os.makedirs(LOGDIR, exist_ok=True)
    for a in AGENTS:
        logfile = os.path.join(LOGDIR, f"{a}.log")
        open(logfile, "a").close()
        t = asyncio.create_task(tail_file(logfile, a))
        app["tasks"].append(t)

async def cleanup(app):
    for t in app.get("tasks", []):
        t.cancel()
    await asyncio.gather(*app.get("tasks", []), return_exceptions=True)

def main():
    app = web.Application()
    app.router.add_get("/", index)
    app.router.add_get(WS_PATH, websocket_handler)
    # Be careful with exposing all files in a directory
    app.router.add_get("/{filename:.*}", static_file) 
    app.on_startup.append(start_tail_tasks)
    app.on_cleanup.append(cleanup)
    
    print(f"Starting server on http://localhost:{PORT_HTTP}")
    web.run_app(app, port=PORT_HTTP, host="0.0.0.0")

if __name__ == "__main__":
    main()

