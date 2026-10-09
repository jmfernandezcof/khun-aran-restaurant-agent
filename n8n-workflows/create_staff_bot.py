#!/usr/bin/env python3
"""Create and activate a staff workflow from its JSON (default khun-aran-staff-bot.json). Run by the owner.

Usage: create_staff_bot.py [khun-aran-staff-reminders.json]. HITL step 2 (staff bot) and step 3 (reminders).

Telegram Trigger on the staff bot (callback_query, only chat -1001234567890) → "Lo atiendo" claims the case in
human_requests (data/hitl/claim_case.sql, atomic), edits the group message ("✅ Lo atiende <name> · HH:MM", button
removed) and answers the click. Aborts if a workflow with that name exists. Never prints the API key.
Rollback: deactivate or DELETE /workflows/<id> (the staff bot then stops reacting to the button).
"""
import json, os, sys, urllib.request

BASE = "https://n8n.nomadprompters.es/api/v1"
HERE = os.path.dirname(os.path.abspath(__file__))
WF = json.load(open(os.path.join(HERE, sys.argv[1] if len(sys.argv) > 1 else "khun-aran-staff-bot.json")))
KEY = json.load(open(os.path.expanduser("~/.claude/.mcp.json")))["mcpServers"]["n8n"]["env"]["N8N_API_KEY"]


def call(method, path, body=None):
    req = urllib.request.Request(BASE + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"X-N8N-API-KEY": KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


if any(w["name"] == WF["name"] for w in call("GET", "/workflows?limit=250")["data"]):
    sys.exit(f"ABORT: a workflow named {WF['name']!r} already exists. Nothing changed.")
wid = call("POST", "/workflows", WF)["id"]
print("created:", wid)
call("POST", f"/workflows/{wid}/activate")
after = call("GET", f"/workflows/{wid}")
checks = {"active": after.get("active") is True, "nodes": len(after["nodes"]) == len(WF["nodes"])}
for k, v in checks.items():
    print(("OK   " if v else "FAIL ") + k)
sys.exit(0 if all(checks.values()) else 1)
