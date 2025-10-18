#!/usr/bin/env python3
import sqlite3
import json
from datetime import datetime

DB_PATH = "./core/mesh.db"

def init_db():
    conn = sqlite3.connect(DB_PATH)
    with conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS mesh (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                agent TEXT NOT NULL,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                message TEXT NOT NULL,
                processed INTEGER DEFAULT 0
            )
        """)
    conn.close()

def send(agent, msg_dict):
    """Send a message to the mesh."""
    conn = sqlite3.connect(DB_PATH)
    with conn:
        conn.execute(
            "INSERT INTO mesh(agent, message) VALUES (?, ?)",
            (agent, json.dumps(msg_dict))
        )
    conn.close()

def receive(agent=None, unprocessed_only=True):
    """Receive messages from the mesh."""
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    query = "SELECT id, agent, message, timestamp FROM mesh WHERE 1=1"
    params = []
    if agent:
        query += " AND agent=?"
        params.append(agent)
    if unprocessed_only:
        query += " AND processed=0"
    cur.execute(query, params)
    rows = cur.fetchall()
    messages = []
    for row in rows:
        msg_id, agent_name, msg_json, timestamp = row
        messages.append({
            "id": msg_id,
            "agent": agent_name,
            "message": json.loads(msg_json),
            "timestamp": timestamp
        })
        # Mark as processed
        conn.execute("UPDATE mesh SET processed=1 WHERE id=?", (msg_id,))
    conn.commit()
    conn.close()
    return messages

if __name__ == "__main__":
    init_db()
    print("[INFO] Mesh database initialized at", DB_PATH)
