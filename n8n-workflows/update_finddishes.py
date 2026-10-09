#!/usr/bin/env python3
"""Update Khun Aran-Tool-FindDishes (bDhUJdIGhnpZGpxk) nodes from khun-aran-tool-finddishes.json. Run by the owner.

Current change: text search mode (param text, 8th query parameter); price_thb returned only in
lookup mode (see data/menu/find_dishes.sql).
Aborts unless the live versionId is EXPECTED. Keeps the workflow active. Never prints the API key.
Rollback: git checkout the previous khun-aran-tool-finddishes.json and rerun with the new EXPECTED.
"""
import json, os, sys, time, urllib.request

WF = "bDhUJdIGhnpZGpxk"
EXPECTED = sys.argv[1] if len(sys.argv) > 1 else "db927bc8-324b-496b-9d63-13c3292e2bb3"
BASE = "https://n8n.nomadprompters.es/api/v1"
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = json.load(open(os.path.join(HERE, "khun-aran-tool-finddishes.json")))
KEY = json.load(open(os.path.expanduser("~/.claude/.mcp.json")))["mcpServers"]["n8n"]["env"]["N8N_API_KEY"]


def call(method, path, body=None):
    req = urllib.request.Request(BASE + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"X-N8N-API-KEY": KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


live = call("GET", f"/workflows/{WF}?_={int(time.time())}")
if live.get("versionId") != EXPECTED:
    sys.exit(f"ABORT: versionId is {live.get('versionId')}, expected {EXPECTED}. Nothing changed.")
by_name = {n["name"]: n for n in SRC["nodes"]}
for n in live["nodes"]:
    n["parameters"] = by_name[n["name"]]["parameters"]
res = call("PUT", f"/workflows/{WF}", {k: live[k] for k in ("name", "nodes", "connections", "settings")})
after = call("GET", f"/workflows/{WF}?_={int(time.time())}")
code = next(n for n in after["nodes"] if n["name"] == "Build Result")["parameters"]["jsCode"]
q = next(n for n in after["nodes"] if n["name"] == "Find Dishes")["parameters"]
checks = {"active": after.get("active") is True, "price only in lookup": "price_thb: r.price_thb" in code,
          "dish lookup in code": "suits_guest" in code, "8 query params": "$json.text" in q["options"]["queryReplacement"],
          "3 nodes": len(after["nodes"]) == 3}
for k, v in checks.items():
    print(("OK   " if v else "FAIL ") + k)
print("versionId now:", after.get("versionId"))
sys.exit(0 if all(checks.values()) else 1)
