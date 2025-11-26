#!/usr/bin/env python3
# cluster-webui-server.py
# Full WebUI backend: HTTP Server + WebSocket + Log Tailer + /push endpoint
#
# Requirements:
#   pip install aiohttp websockets

import asyncio
import os
import json
from aiohttp import web

# --- CONFIG --------------------------------------------------------------

LOGDIR = os.path.expanduser("~/.ai_prime_logs")
PORT_HTTP = 8080

AGENTS = [
    "cube", "core", "loop", "wave",
    "line", "coin", "code", "work"
]

# --- GLOBALS --------------------------------------------------------------

clients = set()

# --- BROADCAST -------------------------------------------------------------

async def broadcast(message: str):
    if not clients:
        return
    dead = []
    for ws in clients:
        try:
            await ws.send_str(message)
        except:
            dead.append(ws)
    for d in dead:
        clients.remove(d)

# --- LOG TAILING -----------------------------------------------------------

async def tail_file(path, agent):
    """Tail -F <file> and send new lines to all WebSocket clients."""
    proc = await asyncio.create_subprocess_exec(
        "tail", "-n", "0", "-F", path,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.DEVNULL
    )

    try:
        while True:
            line = await proc.stdout.readline()
            if not line:
                await asyncio.sleep(0.05)
                continue

            text = line.decode(errors="ignore").rstrip()
            msg = json.dumps({"agent": agent, "text": text})
            await broadcast(msg)

    except asyncio.CancelledError:
        proc.kill()
        await proc.wait()
        raise

# --- HANDLERS --------------------------------------------------------------

async def websocket_handler(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)

    clients.add(ws)
    print("WS connected:", request.remote)

    try:
        async for msg in ws:
            pass  # incoming messages not used
    finally:
        clients.discard(ws)
        print("WS disconnected:", request.remote)

    return ws

async def push_handler(request):
    """
    HTTP POST /push
    JSON: { "agent": "...", "text": "..." }
    """
    data = await request.json()

    agent = data.get("agent", "unknown")
    text = data.get("text", "")

    msg = json.dumps({"agent": agent, "text": text})
    await broadcast(msg)

    return web.Response(text="OK")

async def index_handler(request):
    root = os.path.join(os.path.dirname(__file__), "webui")
    return web.FileResponse(os.path.join(root, "index.html"))

async def static_handler(request):
    root = os.path.join(os.path.dirname(__file__), "webui")
    name = request.match_info.get("filename")
    path = os.path.join(root, name)

    if not os.path.exists(path):
        raise web.HTTPNotFound()

    return web.FileResponse(path)

# --- STARTUP / CLEANUP -----------------------------------------------------

async def start_tail_tasks(app):
    os.makedirs(LOGDIR, exist_ok=True)

    app["tasks"] = []
    for agent in AGENTS:
        logfile = os.path.join(LOGDIR, f"{agent}.log")
        open(logfile, "a").close()

        t = asyncio.create_task(tail_file(logfile, agent))
        app["tasks"].append(t)

async def cleanup(app):
    for t in app.get("tasks", []):
        t.cancel()
    await asyncio.gather(*app["tasks"], return_exceptions=True)

# --- MAIN ------------------------------------------------------------------

def main():
    app = web.Application()

    # routes
    app.router.add_get("/", index_handler)
    app.router.add_get("/ws", websocket_handler)
    app.router.add_post("/push", push_handler)
    app.router.add_get("/static/{filename}", static_handler)

    # boot / shutdown
    app.on_startup.append(start_tail_tasks)
    app.on_cleanup.append(cleanup)

    print(f"WebUI running on http://0.0.0.0:{PORT_HTTP}")
    web.run_app(app, port=PORT_HTTP, host="0.0.0.0")

if __name__ == "__main__":
    main()

