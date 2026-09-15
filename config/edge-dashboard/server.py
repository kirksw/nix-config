#!/usr/bin/env python3
"""Read-only loopback dashboard. Never expose terminal contents or session paths."""
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import threading

ROOT = Path(__file__).resolve().parent
PORT = 8767


class UnreadTracker:
    def __init__(self):
        self.states = {}

    def update(self, agents):
        current = {}
        for agent in agents:
            identity = (agent["pane_id"], json.dumps(agent.get("agent_session"), sort_keys=True))
            status = agent.get("agent_status", "unknown")
            previous, unread = self.states.get(identity, (None, False))
            if (previous == "working" and status == "idle") or (status == "done" and previous != "done"):
                unread = True
            if agent.get("focused", False):
                unread = False
            current[identity] = (status, unread)
            agent["unread"] = unread
        self.states = current


unread_tracker = UnreadTracker()
agent_lock = threading.Lock()


def agent_snapshot():
    # Serialize fetches as well as transitions so concurrent clients cannot reorder state.
    with agent_lock:
        return read_agent_snapshot()


def read_agent_snapshot():
    result = subprocess.run(["herdr", "api", "snapshot"], capture_output=True,
                            text=True, timeout=4, check=True)
    snapshot = json.loads(result.stdout)["result"]["snapshot"]
    workspaces = {w["workspace_id"]: w["label"] for w in snapshot["workspaces"]}
    unread_tracker.update(snapshot["agents"])
    agents = []
    for agent in snapshot["agents"]:
        agents.append({
            "id": agent["pane_id"],
            "unread": agent["unread"],
            "agent": agent.get("agent", "unknown"),
            "status": agent.get("agent_status", "unknown"),
            "workspace": workspaces.get(agent["workspace_id"], "Unknown workspace"),
        })
    return {"status": "connected", "updatedAt": datetime.now(timezone.utc).isoformat(),
            "agents": agents}


def calendar_snapshot():
    path = Path.home() / "Library/Caches/edge-dashboard/calendar.json"
    try:
        data = json.loads(path.read_text())
        updated = datetime.fromisoformat(data["updatedAt"].replace("Z", "+00:00"))
        if (datetime.now(timezone.utc) - updated).total_seconds() > 90:
            return {"status": "stale", "events": [], "message": "Calendar helper stopped updating."}
        return data
    except (OSError, ValueError, KeyError, TypeError):
        return {"status": "disconnected", "events": [], "message": "Start EDGE Calendar to connect."}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        # Reject DNS rebinding and cross-origin reads of local session metadata.
        if self.headers.get("Host") != f"127.0.0.1:{PORT}":
            self.send_error(403)
            return
        origin = self.headers.get("Origin")
        if origin and origin != f"http://127.0.0.1:{PORT}":
            self.send_error(403)
            return
        if self.headers.get("Sec-Fetch-Site") == "cross-site":
            self.send_error(403)
            return
        if self.path == "/api/calendar":
            body = json.dumps(calendar_snapshot()).encode()
            content_type = "application/json"
        elif self.path == "/api/agents":
            try:
                data = agent_snapshot()
            except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError):
                data = {"status": "disconnected", "agents": [],
                        "message": "Herdr is unavailable. Retrying automatically."}
            body = json.dumps(data).encode()
            content_type = "application/json"
        else:
            files = {"/": ("index.html", "text/html"),
                     "/style.css": ("style.css", "text/css"),
                     "/app.js": ("app.js", "text/javascript")}
            if self.path not in files:
                self.send_error(404)
                return
            filename, content_type = files[self.path]
            body = (ROOT / filename).read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type + "; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'self'; style-src 'self'; "
                         "frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    print(f"EDGE dashboard: http://127.0.0.1:{PORT}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
