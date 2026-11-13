# Alle Test-Suites in allen Varianten (Sprache × Fraktion) – Aufruf: python tests/all.py
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
RUNS = [
    ("scenario", "deDE", "Horde"), ("english", "enUS", "Horde"),
] + [(s, loc, "Horde") for s in ("games", "migrate", "comm", "layout") for loc in ("deDE", "enUS")] \
  + [("alliance", loc, "Alliance") for loc in ("deDE", "enUS")] \
  + [("screens", loc, fac) for loc in ("deDE", "enUS") for fac in ("Horde", "Alliance")]

bad = 0
for suite, loc, fac in RUNS:
    env = dict(os.environ, LOCALE=loc, FACTION=fac, PYTHONIOENCODING="utf-8")
    out = subprocess.run([sys.executable, os.path.join(HERE, "run.py"), ADDON, os.path.join(HERE, suite + ".lua")],
                         capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    text = out.stdout + out.stderr
    errors = [l for l in text.splitlines() if re.match(r"(FEHLER|FAIL)\b", l) or "Traceback" in l or "LuaError" in l]
    summary = next((l for l in reversed(text.splitlines()) if re.search(r"ok,|OK", l)), "?")
    ok = out.returncode == 0 and not errors
    bad += 0 if ok else 1
    print(("ok    " if ok else "FEHLER") + f" {suite:9} {loc} {fac:8} {summary.strip()}")
    for l in errors[:10]:
        print("       " + l)
print("Alles grün." if bad == 0 else f"{bad} Lauf/Läufe mit Fehlern.")
sys.exit(1 if bad else 0)
