#!/usr/bin/env python3
"""Tasa de acierto por escenario: ejecuta run_regression.py N veces y suma los resultados. Run by the owner.

Usage: repeat_regression.py N [--only 4,5,6]
The agent's model is probabilistic: the same scenario can pass one run and fail the next, so a single PASS/FAIL says
little. This reports e.g. "4. gala: 3/3". Each run cleans up after itself (see run_regression.py).
Report: scripts/regression/repeat_last.json
"""
import json, os, subprocess, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
N = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 3
extra = sys.argv[2:] if len(sys.argv) > 2 else []
tally, runs = defaultdict(lambda: [0, 0]), []
for i in range(1, N + 1):
    print(f"== ejecución {i}/{N}", flush=True)
    subprocess.run([sys.executable, "-u", os.path.join(HERE, "run_regression.py"), *extra])
    res = json.load(open(os.path.join(HERE, "last_run.json")))["results"]
    runs.append(res)
    for r in res:
        if r["n"] == 90:      # cleanup cancellations, counted together
            key = "90. cancelar por el chat (limpieza)"
        else:
            key = f"{r['n']:>2}. {r['scenario']}"
        tally[key][0] += r["ok"]; tally[key][1] += 1
print("\nTASA DE ACIERTO")
for k in sorted(tally):
    ok, tot = tally[k]
    print(f"  {k:55} {ok}/{tot}{'' if ok == tot else '   <-'}")
json.dump({"runs": runs, "tally": {k: v for k, v in tally.items()}}, open(os.path.join(HERE, "repeat_last.json"), "w"),
          ensure_ascii=False, indent=1)
