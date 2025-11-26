#!/usr/bin/env python3
# cluster-webui-server.py
# Minimal WebSocket server that tails agent logs and broadcasts lines to connected browsers.
# Requirements: pip install websockets aiohttp

import asyncio
import os
from aiohttp import web
import websockets
import json
import shutil
import signal

LOGDIR = os.path.expanduser("~/.ai_prime_logs")
PORT_HTTP = 8080
WS_PATH = "/ws"

AGENTS = ["cube","core","loop","wave","line","coin","code","work"]

clients = set()

async def tail_file(path, agent):
    # Use tail -F for robust follow
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
    if not clients:
        return
    to_remove = []
    for ws in clients:
        try:
            await ws.send(message)
        except Exception:
            to_remove.append(ws)
    for r in to_remove:
        clients.remove(r)

async def ws_handler(websocket, path):
    # Keep this for websockets (if you use websockets lib)
    pass

# aiohttp route to serve static index.html and handle WS upgrade
async def websocket_handler(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    clients.add(ws)
    try:
        async for msg in ws:
            # ignore inbound messages for now
            pass
    finally:
        clients.discard(ws)
    return ws

async def index(request):
    root = os.path.join(os.path.dirname(__file__), "webui")
    return web.FileResponse(os.path.join(root, "index.html"))

async def static_file(request):
    root = os.path.join(os.path.dirname(__file__), "webui")
    path = request.match_info.get('filename')
    filep = os.path.join(root, path)
    if not os.path.exists(filep):
        raise web.HTTPNotFound()
    return web.FileResponse(filep)

async def start_tail_tasks(app):
    app["tasks"] = []
    # ensure logs exist
    os.makedirs(LOGDIR, exist_ok=True)
    for a in AGENTS:
        logfile = os.path.join(LOGDIR, f"{a}.log")
        # create empty if missing
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
    app.router.add_get("/ws", websocket_handler)
    app.router.add_get("/static/{filename}", static_file)
    app.on_startup.append(start_tail_tasks)
    app.on_cleanup.append(cleanup)
    web.run_app(app, port=PORT_HTTP, host="0.0.0.0")

if __name__ == "__main__":
    main()

