#!/usr/bin/env python3
"""Replay a guest conversation through the public chat to compare tone after a prompt change. Costs ~5 cents/message.

Usage: replay_tone.py   (messages below: the owner's 2026-10-03 conversation, with a test phone, stopping before the
booking is created so nothing is stored). Prints each guest message and Khun Aran's reply.
"""
import json, time, urllib.request, uuid

URL = "https://demo-talay.nomadprompters.es/chat"
PACE = 6.0
_last = [0.0]


# same as run_regression.say (copied: importing that script would run the battery)
def say(sid, msg):
    wait = PACE - (time.time() - _last[0])
    if wait > 0:
        time.sleep(wait)
    _last[0] = time.time()
    body = json.dumps({"session_id": sid, "message": msg, "lang": "multi"}).encode()
    req = urllib.request.Request(URL, data=body, method="POST",
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 khun-aran-regression"})
    for attempt in (1, 2):   # one retry: a reply lost between Cloudflare and us is a network blip, not an agent failure
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.load(r).get("reply", "")
        except Exception as e:
            err = e
            if "timed out" not in str(e) or attempt == 2:
                break
            print(f"   (reintento tras tiempo agotado: {e})")
    return f"__ERROR__ {err}"


MESSAGES = [
    "Quiero reservar, para 5 personas, dentro de tres jueves, hay espectaculo de fuego?",
    "a pues el domingo, si a las 19:45",
    "Test Regresion +447700900099, si dos personas son veganas, es un cumpleaños, haceis menus de cumpleaños? o que me aconsejas?",
    "no ninguna alergia",
    "si el mensaje que querais",
]
sid = str(uuid.uuid4())
for m in MESSAGES:
    print(f"\nHUÉSPED: {m}\nKHUN ARAN: {say(sid, m)}")
