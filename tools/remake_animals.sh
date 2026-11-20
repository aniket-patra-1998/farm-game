#!/usr/bin/env bash
# Makes every animal's file again from the art tool and brings the game's lists in step
# (tools/remake_animals.sh path/to/godot): run after any change to tools/animal_art, or after adding an animal
# there (docs/LIMITED.md "Adding one", tools/animal_art/README.md). An animal whose builder did not change
# comes out byte for byte the same. Stops at the first failure.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:?usage: tools/remake_animals.sh path/to/godot}"
NAMES=$(cd tools/animal_art && python3 -c "from animal_art.registry import GAME; print(','.join(n for v in GAME.values() for n in v))")
(cd tools/animal_art && python3 -m animal_art export ../../art/models/animals "$NAMES" > /dev/null)
python3 tools/make_limited.py
"$GODOT" --headless --path . --import > /dev/null 2>&1
python3 tools/make_art_versions.py
python3 tools/make_art_manifest.py
python3 tools/make_catalog.py
"$GODOT" --headless --path . res://tools/animal_strides.tscn | tail -1
