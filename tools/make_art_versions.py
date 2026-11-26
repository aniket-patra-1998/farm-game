"""Writes data/art_versions.json: a fingerprint of what every item's look is made from, so whatever is made
from the art (item pictures: ItemIcons, through ArtVersion) is made again by itself when the art changes.

    files   asset id -> fingerprint of its file's contents (data/assets.json: animals, trees, crop forms...)
    built   fingerprint of everything a code-built look is made from (the builders, their data, the shaders)
    studio  fingerprint of how a picture is taken (the icon studio and its developing)

It also keeps the art files tied to the builders they are exported from (data/art_sources.json): each exporter
records a fingerprint of its builders when it writes the files, and --check fails when a builder has changed
since, so a builder change never silently leaves the game drawing the old files.

    python3 tools/make_art_versions.py          # write it (after changing any art)
    python3 tools/make_art_versions.py --check  # exit 1 if anything is out of date (CI runs this)
    python3 tools/make_art_versions.py --exported plants|buildings|animals|sounds   # (the exporters run this
                                                                                   # when they finish)
"""
import glob
import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = "data/art_versions.json"
# What code-built looks are made from (a change to any of them redraws the pictures of every code-built item).
BUILT = ["scripts/world3d/*.gd", "scripts/world/animals/*.gd", "scripts/world/space_fit.gd", "scripts/season.gd",
         "shaders/*.gdshader*", "data/building_models.json", "data/tree_shapes.json", "data/crop_forms.json",
         "data/animal_rigs.json", "data/linking.json", "data/quality.json", "data/crowding.json", "data/dressing.json",
         "data/scale_guide.json", "data/seasons.json"]
# Where look code lives: every data file it reads must be in BUILT (--check finds them itself), so a new one can
# never shape a look without redrawing its pictures.
LOOK_CODE = ["scripts/world3d/*.gd", "scripts/world/animals/*.gd", "scripts/ui/ui_models.gd", "scripts/ui/item_icons.gd",
             "scripts/ui/icon_maker.gd", "scripts/season.gd"]
# (the fingerprints themselves, the files are fingerprinted; animal strides are measured from those files, each
# kept with its file's fingerprint, and move nothing in a picture; nor does where a sleeper's nose is: its z z z
# is drawn on the farm at night, never in a picture)
NOT_LOOKS = {"data/art_versions.json", "data/assets.json", "data/animal_strides.json", "data/animal_sleep.json"}
STUDIO = ["scripts/ui/item_icons.gd", "scripts/ui/icon_maker.gd", "scripts/ui/icon_develop.gd", "scripts/ui/ui_models.gd",
          "scripts/ui/icon_style.gd", "shaders/icon_flat.gdshader"]
SOURCES_OUT = "data/art_sources.json"
# What each kind of exported art file is made from, and the exporter to run when any of it changes.
SOURCES = {
    "plants": (["scripts/world3d/tree_model.gd", "scripts/world3d/tree_spec.gd", "scripts/world3d/bloom_model.gd",
                "scripts/world3d/crop_models.gd", "scripts/world3d/crop_forms.gd", "scripts/world3d/crop_form_spec.gd", "data/scale_guide.json",
                "data/catalog/blooms.json",
                "scripts/world3d/mesh_builder.gd", "scripts/world3d/model_kit.gd", "scripts/world3d/crowding.gd",
                "scripts/world3d/scale_guide.gd", "data/tree_shapes.json", "data/crop_forms.json",
                "shaders/crown3d.gdshader", "shaders/crop3d.gdshader",
                "shaders/fruit3d.gdshader", "shaders/bloom3d.gdshader",
                "scripts/world3d/frond_mesh.gd", "shaders/frond3d.gdshader", "shaders/leaf_touch.gdshaderinc",
                "tools/export_plants.gd"],
               "godot --headless --path . res://tools/export_plants.tscn"),
    "buildings": (["scripts/world3d/building_model.gd", "scripts/world3d/building_spec.gd",
                   "scripts/world3d/building_dress.gd",
                   "scripts/world3d/vip_badge.gd", "scripts/world3d/model_kit.gd", "scripts/world3d/decor_motion.gd",
                   "scripts/world/space_fit.gd", "data/building_models.json", "data/catalog/buildings.json",
                   "shaders/wall3d.gdshader", "shaders/paint3d.gdshader", "shaders/orbit3d.gdshader",
                   "shaders/spray3d.gdshader", "shaders/flame3d.gdshader", "shaders/glow3d.gdshader",
                   "shaders/frame3d.gdshader", "shaders/shine3d.gdshader",
                   "shaders/contact3d.gdshader", "tools/export_buildings.gd"],
                  "godot --headless --path . res://tools/export_buildings.tscn"),
    "sounds": (["tools/sound_cuts/*.py"],
               "python3 tools/sound_cuts/make_generated.py (and make_sounds.py <downloads> for the cut recordings)"),
    "animals": (["tools/animal_art/animal_art/**/*.py"],
                "cd tools/animal_art && python3 -m animal_art export ../../art/models/animals \"<every animal>\""),
}


def _digest(paths):
    h = hashlib.sha1()
    for p in paths:
        h.update(p.encode())
        with open(os.path.join(ROOT, p), "rb") as f:
            h.update(f.read())
    return h.hexdigest()[:16]


def _expand(patterns):
    out = []
    for pat in patterns:
        out += sorted(os.path.relpath(p, ROOT) for p in glob.glob(os.path.join(ROOT, pat), recursive=True))
    return sorted(set(p for p in out if not p.endswith(".uid")))


def make():
    with open(os.path.join(ROOT, "data/assets.json")) as f:
        assets = json.load(f)["assets"]
    files = {}
    for aid, e in sorted(assets.items()):
        # (a path with {level} in it is a file for each level: all of them make the item's look)
        paths = _expand([e[k].replace("res://", "").replace("{level}", "*").replace("{stage}", "*")
                         for k in ("model", "site", "broken") if e.get(k)])
        if paths:
            files[aid] = _digest(paths)
    out = {"about": "Generated by tools/make_art_versions.py: what each item's look is made from (ArtVersion).",
           "built": _digest(_expand(BUILT)), "studio": _digest(_expand(STUDIO)), "files": files}
    return json.dumps(out, indent=2) + "\n"


def _read_by_looks():
    import re
    found = set()
    for path in _expand(LOOK_CODE):
        with open(os.path.join(ROOT, path)) as f:
            found |= {m.replace("res://", "") for m in re.findall(r"res://data/[a-z_/]+\.json", f.read())}
    return found


def _sources():
    return {kind: _digest(_expand(files)) for kind, (files, _run) in SOURCES.items()}


def _stamps():
    path = os.path.join(ROOT, SOURCES_OUT)
    return json.load(open(path)) if os.path.exists(path) else {}


def main():
    if "--exported" in sys.argv:
        kind = sys.argv[sys.argv.index("--exported") + 1]
        stamps = _stamps()
        stamps[kind] = _sources()[kind]
        with open(os.path.join(ROOT, SOURCES_OUT), "w") as f:
            f.write(json.dumps(dict(sorted(stamps.items())), indent=2) + "\n")
    text = make()
    path = os.path.join(ROOT, OUT)
    if "--check" in sys.argv:
        stamps = _stamps()
        stale = False
        for data in _read_by_looks() - set(_expand(BUILT)) - NOT_LOOKS:
            print("%s shapes a look but is not in BUILT (tools/make_art_versions.py): add it" % data)
            stale = True
        for kind, now in _sources().items():
            if stamps.get(kind) != now:
                print("the %s builders changed since their files were exported: run %s" % (kind, SOURCES[kind][1]))
                stale = True
        if stale:
            sys.exit(1)
        old = open(path).read() if os.path.exists(path) else ""
        if old != text:
            print("%s is out of date: run python3 tools/make_art_versions.py" % OUT)
            sys.exit(1)
        print("%s is up to date" % OUT)
        return
    with open(path, "w") as f:
        f.write(text)
    print("wrote %s (%d files)" % (OUT, len(json.loads(text)["files"])))


if __name__ == "__main__":
    main()
