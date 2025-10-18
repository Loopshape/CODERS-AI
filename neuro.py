#!/usr/bin/env python3
import sqlite3
import json
import sys
from datetime import datetime

DB_FILE = "state.db"

class Neuro:
    def __init__(self, db_file=DB_FILE):
        self.conn = sqlite3.connect(db_file)
        self._init_db()

    def _init_db(self):
        c = self.conn.cursor()
        c.execute("""
        CREATE TABLE IF NOT EXISTS guidance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            topic TEXT,
            suggestion TEXT
        )
        """)
        self.conn.commit()

    def log_suggestion(self, topic, suggestion):
        c = self.conn.cursor()
        c.execute("INSERT INTO guidance (timestamp, topic, suggestion) VALUES (?, ?, ?)",
                  (datetime.utcnow().isoformat(), topic, suggestion))
        self.conn.commit()

    def get_recent(self, limit=5):
        c = self.conn.cursor()
        c.execute("SELECT timestamp, topic, suggestion FROM guidance ORDER BY id DESC LIMIT ?", (limit,))
        return c.fetchall()

    def process_input(self, input_json):
        # Lightweight NLP placeholder for Phase 1
        data = json.loads(input_json)
        topic = data.get("topic", "general")
        prompt = data.get("prompt", "")
        suggestion = f"Neuro thinks about '{topic}': {prompt[:50]}..."
        self.log_suggestion(topic, suggestion)
        return {"topic": topic, "suggestion": suggestion}

if __name__ == "__main__":
    neuro = Neuro()
    if len(sys.argv) > 1:
        input_json = sys.argv[1]
        result = neuro.process_input(input_json)
        print(json.dumps(result, indent=2))
    else:
        recent = neuro.get_recent()
        print(json.dumps([{"timestamp": t, "topic": top, "suggestion": s} for t, top, s in recent], indent=2))
