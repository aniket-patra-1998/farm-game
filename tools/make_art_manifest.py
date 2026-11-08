#!/usr/bin/env python3
"""Builds art/manifest.json from the catalog: one entry per lifecycle stage of every in-game item
(see "lifecycle" in data/catalog/schema.json), each with what to draw, how wide, and its references.

    python3 tools/make_art_manifest.py          # rewrite art/manifest.json
    python3 tools/make_art_manifest.py --check  # exit 1 if it's out of date (CI runs this)

Add or change an item in data/catalog/ and its art entries follow automatically.
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data", "catalog")
OUT = os.path.join(ROOT, "art", "manifest.json")
schema = json.load(open(os.path.join(DATA, "schema.json")))
classes = schema["classes"]

COMMON = ("A single isometric game asset for a cozy farming game, seen from 30 degrees above and turned 45 degrees, "
          "matching the reference image's camera angle, outline, proportions and footprint exactly. Centered, complete and "
          "uncropped, isolated on a plain flat light grey (#e8e8e8) background with nothing else in the scene: no ground beyond "
          "its own footprint, no cast shadow on the background, no text, no numbers, no badges, no border, no watermark. "
          "The first image is the layout reference for this item; the last three images are style references only: "
          "match their painting style, brushwork, palette and lighting exactly, but don't copy their subjects.")
# Bump when items are added, so the Colab notebook asks for the new references zip.
MANIFEST_VERSION = 2
STYLE_REFS = ["style/farmhouse.png", "style/cow.png", "style/apple_tree.png"]
STYLES = {"painterly": "Style: hand-painted cozy cartoon game art, soft painterly brushwork, warm golden-hour sunlight from the "
                       "upper left, gentle ambient occlusion, rich but natural colors, crisp readable silhouette with a soft dark "
                       "outline, premium mobile game quality."}


def chain(cls):
    out = []
    while cls:
        out.insert(0, cls)
        cls = classes[cls].get("extends")
    return out


def defaults(cls):
    out = {}
    for c in chain(cls):
        for k, v in classes[c]["fields"].items():
            if "default" in v:
                out[k] = v["default"]
    return out


def lifecycle(cls):
    for c in reversed(chain(cls)):
        if "lifecycle" in classes[c]:
            return classes[c]["lifecycle"]
    return {"stages": ["placed"], "pattern": "{id}", "fill": 0.7}


def subject(cls, e, stage, n_sizes):
    name = e["name"]
    look = e.get("look") or name.lower()
    if cls == "Crop":
        thing = name.lower()
        if e.get("flower"):
            return {"planted": f"one square plot of freshly tilled dark brown soil in neat furrows with tiny {thing} seedlings just sprouting; no flowers yet",
                    "growing": f"one square plot of tilled brown soil with half-grown leafy {thing} plants with closed buds, not in bloom yet",
                    "ripe": f"one square plot of tilled brown soil with {thing} plants in full colourful bloom, ready to pick",
                    "withered": f"one square plot of dry cracked soil with wilted, dried-out brown {thing} plants drooping over"}[stage]
        return {"planted": f"one square plot of freshly tilled dark brown soil in neat furrows with tiny {thing} seedlings just sprouting; no fruit, no flowers, nothing ripe yet",
                "growing": f"one square plot of tilled brown soil with half-grown leafy {thing} plants, healthy and green but not ripe yet",
                "ripe": f"one square plot of tilled brown soil with lush {thing} plants full of ripe {thing}, ready to harvest",
                "withered": f"one square plot of dry cracked soil with wilted, dried-out brown {thing} plants drooping over"}[stage]
    if cls == "Tree":
        fruit = name.replace(" Tree", "").lower()
        base = e["look"] if e.get("look") else f"a lush {name.lower()} with a sturdy trunk and a full green canopy"
        return {"harvested": base + ", with no fruit on it (just picked)",
                "fruiting": base + f", with small unripe green {fruit} fruit among the leaves",
                "ready": base + f", laden with plenty of ripe {fruit} fruit, ready to pick"}[stage]
    if cls == "Animal":
        if e.get("kind") == "bee":
            return "a single cute honey bee hovering"
        if e.get("young"):
            return f"a cute baby farm animal: {look if e.get('look') else 'a ' + name.lower()}, small and young, full body, standing"
        article = "" if look.startswith(("a ", "an ")) else "a "
        return f"{article}{look}, a farm animal, full body, standing calmly"
    if cls in ("Building", "Barn"):
        if n_sizes <= 1:
            return look
        n = int(stage)
        size = ["the small starter size", "a bigger, grander version with more detail",
                "the biggest, grandest version, with extra decoration and flourishes",
                "an even larger deluxe version", "the largest, most luxurious version"][min(n - 1, 4)]
        return f"{look}. Size {n} of {n_sizes}: {size}"
    if cls == "Material":
        return f"a game icon of {name.lower()}, a building material, simple, bold and readable at small size"
    if cls == "Decoration" and not e.get("look"):
        return f"a {name.lower()}, a farm decoration"
    return look


def build():
    items = []
    for category, file_cls in schema["files"].items():
        d = json.load(open(os.path.join(DATA, category + ".json")))
        for fam in d["families"]:
            for v in fam["variants"]:
                if v.get("status") == "planned":
                    continue
                cls = schema.get("kind_classes", {}).get(v.get("kind", ""), file_cls)
                e = defaults(cls)
                e.update(d.get("defaults", {})); e.update(fam.get("defaults", {})); e.update(v)
                lc = lifecycle(cls)
                stages = [str(n) for n in range(1, len(e.get("levels", [1])) + 1)] if lc["stages"] == "sizes" else lc["stages"]
                for stage in stages:
                    art = lc["pattern"].replace("{id}", e["id"]).replace("{stage}", stage).replace("{n}", stage)
                    refs = [] if cls == "Material" else [f"refs/{art}.png"]
                    if os.path.exists(os.path.join(ROOT, "art", "refs3d", e["id"] + ".png")):
                        refs.append(f"refs3d/{e['id']}.png")
                    items.append({"id": art, "item": e["id"], "class": cls, "stage": stage,
                                  "tiles": int(e.get("w", 1)), "fill": float(e.get("art_fill", lc.get("fill", 0.7))),
                                  "refs": refs, "subject": subject(cls, e, stage, len(stages))})
    # Ground tiles under everything.
    items.append({"id": "ground_grass", "item": "", "class": "Ground", "stage": "grass", "tiles": 1, "fill": 1.0,
                  "refs": ["refs/ground_grass.png"], "subject": "one flat square tile of lush, short, sunlit green grass filling the whole tile edge to edge, nothing on it"})
    items.append({"id": "ground_plowed", "item": "", "class": "Ground", "stage": "plowed", "tiles": 1, "fill": 1.0,
                  "refs": ["refs/ground_plowed.png"], "subject": "one flat square plot of freshly plowed dark brown soil in neat furrows, filling the whole tile, nothing growing"})
    return {"_note": "Generated by tools/make_art_manifest.py from data/catalog/. Don't edit by hand: change the catalog "
                     "(look, art_fill) or the generator.",
            "version": MANIFEST_VERSION, "common": COMMON, "styles": STYLES, "style_refs": STYLE_REFS, "items": items}


if __name__ == "__main__":
    text = json.dumps(build(), indent=1) + "\n"
    if "--check" in sys.argv:
        if not os.path.exists(OUT) or open(OUT).read() != text:
            print("art/manifest.json is out of date: run python3 tools/make_art_manifest.py")
            sys.exit(1)
        print("art/manifest.json is up to date")
    else:
        open(OUT, "w").write(text)
        m = json.loads(text)
        from collections import Counter
        print(len(m["items"]), "art pieces:", dict(Counter(i["class"] for i in m["items"])))
