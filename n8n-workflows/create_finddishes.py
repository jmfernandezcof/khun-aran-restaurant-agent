#!/usr/bin/env python3
"""Create the Khun Aran-Tool-FindDishes sub-workflow from khun-aran-tool-finddishes.json. Run by the owner.

Aborts if a workflow with the same name already exists. Never prints the API key.
Rollback: DELETE /workflows/<id> (nothing references it until the agent tool is connected).
"""
import json, os, sys, urllib.request

BASE = "https://n8n.nomadprompters.es/api/v1"
HERE = os.path.dirname(os.path.abspath(__file__))
WF = json.load(open(os.path.join(HERE, "khun-aran-tool-finddishes.json")))
KEY = json.load(open(os.path.expanduser("~/.claude/.mcp.json")))["mcpServers"]["n8n"]["env"]["N8N_API_KEY"]


def call(method, path, body=None):
    req = urllib.request.Request(BASE + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"X-N8N-API-KEY": KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


existing = call("GET", "/workflows?limit=250")["data"]
if any(w["name"] == WF["name"] for w in existing):
    sys.exit(f"ABORT: a workflow named {WF['name']!r} already exists. Nothing changed.")

res = call("POST", "/workflows", WF)
live = call("GET", f"/workflows/{res['id']}")
pg = next(n for n in live["nodes"] if n["name"] == "Find Dishes")
checks = {
    "3 nodes": len(live["nodes"]) == 3,
    "2 connections": len(live["connections"]) == 2,
    "postgres credential": pg.get("credentials", {}).get("postgres", {}).get("id") == "epQtsywLYdQbHmj0",
    "query uses menu_items": "FROM menu_items" in pg["parameters"]["query"],
}
for k, v in checks.items():
    print(("OK   " if v else "FAIL ") + k)
print("workflow id:", res["id"], "versionId:", live.get("versionId"))
sys.exit(0 if all(checks.values()) else 1)
