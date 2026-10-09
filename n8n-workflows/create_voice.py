#!/usr/bin/env python3
"""Create and activate Khun Aran-Web-Voice (webhook khun-aran-voice) from khun-aran-web-voice.json. Run by the owner.

The webhook only transcribes (OpenAI gpt-4o-mini-transcribe) and returns {"text"}; the web then sends that text
through /chat as usual. The access token is copied from the agent's "Auth Gate" at runtime and never printed.
Executions are not saved (the audio would be stored with them).
Aborts if a workflow with the same name already exists. Never prints the API key.
Rollback: deactivate or DELETE /workflows/<id> (only nginx /voice points to it).
"""
import json, os, sys, urllib.request

BASE = "https://n8n.nomadprompters.es/api/v1"
AGENT = "TNMHHaKWEoO0rLhf"
HERE = os.path.dirname(os.path.abspath(__file__))
WF = json.load(open(os.path.join(HERE, "khun-aran-web-voice.json")))
KEY = json.load(open(os.path.expanduser("~/.claude/.mcp.json")))["mcpServers"]["n8n"]["env"]["N8N_API_KEY"]


def call(method, path, body=None):
    req = urllib.request.Request(BASE + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"X-N8N-API-KEY": KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def gate_token(wf):
    return next(n for n in wf["nodes"] if n["name"] == "Auth Gate")["parameters"]["conditions"]["conditions"][0]


existing = call("GET", "/workflows?limit=250")["data"]
if any(w["name"] == WF["name"] for w in existing):
    sys.exit(f"ABORT: a workflow named {WF['name']!r} already exists. Nothing changed.")

token = gate_token(call("GET", f"/workflows/{AGENT}"))["rightValue"]
if not token or len(token) < 32:
    sys.exit("ABORT: could not read the agent token. Nothing changed.")
gate_token(WF)["rightValue"] = token

created = call("POST", "/workflows", WF)
wid = created["id"]
print("created:", wid)
call("POST", f"/workflows/{wid}/activate")

after = call("GET", f"/workflows/{wid}")
checks = {
    "active": after.get("active") is True,
    "nodes": len(after["nodes"]) == len(WF["nodes"]),
    "no_saved_data": after["settings"].get("saveDataSuccessExecution") == "none"
                     and after["settings"].get("saveDataErrorExecution") == "none",
    "token_set": gate_token(after)["rightValue"] == token,
}
print(checks)
print("OK" if all(checks.values()) else "CHECK FAILED")
