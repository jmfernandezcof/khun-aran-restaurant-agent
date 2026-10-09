#!/usr/bin/env python3
"""Tokens and response time of Khun Aran between two moments (to compare models). Read-only.

Usage: measure_usage.py START END [input_price output_price]   (UTC ISO, e.g. 2026-10-03T13:42:00; prices $/MTok)
Sums the "Anthropic Chat Model" tokenUsage of every agent execution in the window. n8n reports promptTokens without
the cache split, so the cost shown is an upper bound (as if nothing were cached); use it to compare models, and the
Anthropic console for the real bill.
"""
import json, os, sys, urllib.request
from datetime import datetime

AG = "TNMHHaKWEoO0rLhf"
BASE = "https://n8n.nomadprompters.es/api/v1"
KEY = json.load(open(os.path.expanduser("~/.claude/.mcp.json")))["mcpServers"]["n8n"]["env"]["N8N_API_KEY"]
start, end = sys.argv[1], sys.argv[2]
pin, pout = (float(sys.argv[3]), float(sys.argv[4])) if len(sys.argv) > 4 else (None, None)


def get(path):
    with urllib.request.urlopen(urllib.request.Request(BASE + path, headers={"X-N8N-API-KEY": KEY}), timeout=60) as r:
        return json.load(r)


ids, cursor = [], ""
while True:
    page = get(f"/executions?workflowId={AG}&limit=100" + (f"&cursor={cursor}" if cursor else ""))
    for e in page["data"]:
        if start <= e["startedAt"][:19] <= end:
            ids.append(e["id"])
    cursor = page.get("nextCursor")
    if not cursor or page["data"][-1]["startedAt"][:19] < start:
        break

tin = tout = calls = 0
secs = []
for i in ids:
    d = get(f"/executions/{i}?includeData=true")
    t0, t1 = (datetime.fromisoformat(d[k].replace("Z", "+00:00")) for k in ("startedAt", "stoppedAt"))
    secs.append((t1 - t0).total_seconds())
    for run in d["data"]["resultData"]["runData"].get("Anthropic Chat Model", []):
        u = run["data"]["ai_languageModel"][0][0]["json"].get("tokenUsage", {})
        tin += u.get("promptTokens", 0); tout += u.get("completionTokens", 0); calls += 1

n = len(ids)
print(f"mensajes del huésped: {n} · llamadas al modelo: {calls}")
if n:
    secs.sort()
    print(f"tokens entrada: {tin} ({tin // n}/mensaje) · salida: {tout} ({tout // n}/mensaje)")
    print(f"tiempo de respuesta: mediana {secs[n // 2]:.1f} s · máx {secs[-1]:.1f} s")
    if pin is not None:
        cost = tin / 1e6 * pin + tout / 1e6 * pout
        print(f"coste sin caché (cota superior): ${cost:.2f} · ${cost / n:.3f}/mensaje")
