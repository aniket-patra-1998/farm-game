#!/usr/bin/env bash
# What CI checks, run here before a push (tools/precheck.sh [path/to/godot]): the line and file limits gdlint
# enforces (gdlint itself when installed), the generated documents, player-facing text, then every test with
# the engine log gate. Stops at the first failure.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-godot}"
if command -v gdlint >/dev/null; then
	gdlint autoload scripts tests tools
else
	python3 - <<'PY'
import pathlib, re, sys
limits = dict(re.findall(r"^(max-line-length|max-file-lines):\s*(\d+)", open(".gdlintrc").read(), re.M))
bad = []
for f in sorted(p for d in ("autoload", "scripts", "tests", "tools") for p in pathlib.Path(d).rglob("*.gd")):
    lines = f.read_text().split("\n")
    if len(lines) > int(limits["max-file-lines"]):
        bad.append(f"{f}: {len(lines)} lines")
    bad += [f"{f}:{n}: {len(l)} characters" for n, l in enumerate(lines, 1) if len(l) > int(limits["max-line-length"])]
print("\n".join(bad) or "gdlint limits: ok (gdlint itself isn't installed)")
sys.exit(1 if bad else 0)
PY
fi
python3 tools/make_catalog.py --check
python3 tools/make_art_manifest.py --check
python3 tools/make_notebook.py --check
python3 tools/strings_lint.py
log="$(mktemp)"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . res://tests/run_tests.tscn >"$log" 2>&1 || true
if grep -E "Parse Error|Compile Error|Failed to load script" "$log"; then echo "A script didn't load"; exit 1; fi
grep -E "checks, 0 failed" "$log" || { grep -E "^FAIL|^  - " "$log"; echo "Tests didn't all pass"; exit 1; }
python3 tools/check_godot_log.py "$log"
