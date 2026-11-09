"""Fails if a Godot run printed an engine or script error (the kind the editor's Errors panel shows).

Godot keeps running after most errors, so a run can "pass" while the game is quietly broken; CI pipes each
run's output through this. Each error is reported with the "at:" line that follows it. A few errors come
from the CI machine itself (no sound card) and are allowed, by where they happen.

Usage: python3 tools/check_godot_log.py LOG...
"""
import re
import sys

# Errors that come from the CI machine, not the game: matched against the error and its "at:" line.
ALLOWED = [
    r"audio_driver_alsa",        # no sound card on the CI machine
    r"audio_driver_pulseaudio",
]


def errors(text):
    lines = [re.sub(r"^﻿?\d{4}-\d\d-\d\dT[\d:.]+Z ", "", l) for l in text.splitlines()]
    out = []
    for i, line in enumerate(lines):
        if re.match(r"\s*(ERROR|SCRIPT ERROR|USER ERROR):", line):
            where = lines[i + 1].strip() if i + 1 < len(lines) else ""
            block = line + " " + where
            if not any(re.search(a, block) for a in ALLOWED):
                out.append((line.strip(), where))
    return out


def main():
    found = []
    for path in sys.argv[1:]:
        found += [(path, e, w) for e, w in errors(open(path, errors="replace").read())]
    seen = {}
    for path, e, w in found:
        seen.setdefault((e, w), [path, 0])[1] += 1
    for (e, w), (path, n) in seen.items():
        print("%s: %s (x%d)\n    %s" % (path, e, n, w))
    print("godot log: %d errors" % len(found))
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
