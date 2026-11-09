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
MANIFEST_VERSION = 4
STYLE_REFS = ["style/farmhouse.png", "style/cow.png", "style/apple_tree.png"]
ICON = ("A single game icon for a cozy farming game's menus: one object, centered, front three-quarter view, slightly from above, "
        "complete and uncropped, a bold readable silhouette that reads at small size, isolated on a plain flat light grey (#e8e8e8) "
        "background with nothing else: no text, no letters, no numbers, no border, no frame, no watermark. All the images given are "
        "style references only: match their painting style, brushwork, palette and lighting exactly, but don't copy their subjects.")
AVATAR = ("A single full-body character for a cozy isometric farming game, seen from 30 degrees above like the rest of the game, "
          "standing on flat ground, centered, complete from hat to boots and uncropped, isolated on a plain flat light grey (#e8e8e8) "
          "background with nothing else: no shadow on the background, no text, no border, no watermark. If the first image shows this "
          "same farmer, keep exactly the same person: face, hair, body, clothes and colours, changing only the pose and direction. "
          "The last three images are style references only: match their painting style, brushwork, palette and lighting exactly.")
CROP = ("Four farm plants of one kind for a cozy isometric farming game, seen from 30 degrees above, standing in a diamond "
        "(one at the back, one left, one right, one at the front) as if growing on a square plot. Only the plants: leaves, stems, "
        "flowers and fruit, with their stems ending where they meet the ground. Absolutely no soil, no dirt, no plot, no tile, "
        "no base, no ground, no shadow; isolated on a plain flat light grey (#e8e8e8) background with nothing else, no text, "
        "no border, no watermark. The first image is a layout sketch showing where the four plants stand and how big they are. "
        "The last three images are style references only: match their painting style, brushwork, palette and lighting exactly.")
COMMONS = {"Icon": ICON, "Material": ICON, "Recipe": ICON, "Avatar": AVATAR, "Crop": CROP}
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
            return {"planted": f"tiny {thing} seedlings just sprouting, a few small leaves each; no flowers yet",
                    "growing": f"half-grown leafy {thing} plants with closed buds, not in bloom yet",
                    "ripe": f"{thing} plants in full colourful bloom, ready to pick",
                    "withered": f"wilted, dried-out brown {thing} plants drooping over"}[stage]
        return {"planted": f"tiny {thing} seedlings just sprouting, a few small leaves each; no fruit, no flowers, nothing ripe yet",
                "growing": f"half-grown leafy {thing} plants, healthy and green but not ripe yet",
                "ripe": f"lush {thing} plants full of ripe {thing}, ready to harvest",
                "withered": f"wilted, dried-out brown {thing} plants drooping over"}[stage]
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
    if cls == "Crafting":
        n = int(stage)
        return (f"{look}. Star level {n} of {n_sizes}: " + ["a modest cottage", "a little bigger, with more trim and a second window",
                "bigger again, with a porch and more decoration", "a grand version with an extra wing and flower boxes",
                "the grandest, most charming version, with golden details and a little tower"][min(n - 1, 4)])
    if cls in ("Building", "Barn"):
        if n_sizes <= 1:
            return look
        n = int(stage)
        size = ["the small starter size", "a bigger, grander version with more detail",
                "the biggest, grandest version, with extra decoration and flourishes",
                "an even larger deluxe version", "the largest, most luxurious version"][min(n - 1, 4)]
        return f"{look}. Size {n} of {n_sizes}: {size}"
    if cls == "Recipe":
        return f"{name}, a homemade {e.get('product', 'good').lower().rstrip('s')} from a country farm, made from {', '.join(c.replace('_', ' ') for c in e['inputs'])}; appetising and charming"
    if cls == "Material":
        return f"a game icon of {name.lower()}, a building material, simple, bold and readable at small size"
    if cls == "Decoration" and not e.get("look"):
        return f"a {name.lower()}, a farm decoration"
    return look


def icon(id, subject, item=""):
    return {"id": "icon_" + id, "item": item, "class": "Icon", "stage": "icon", "tiles": 1, "fill": 0.5, "refs": [], "subject": subject}


def extra_art():
    """The farmer's poses and the menu icons (data/ui_art.json, collections, eggs, box and ribbons)."""
    ui = json.load(open(os.path.join(ROOT, "data", "ui_art.json")))
    out = []
    av = ui["avatar"]
    for who, look in av["farmers"].items():
        base = f"avatar_{who}_idle_front"
        for pose, doing in av["poses"].items():
            for facing, way in av["facings"].items():
                aid = f"avatar_{who}_{pose}_{facing}"
                out.append({"id": aid, "item": who, "class": "Avatar", "stage": f"{pose}_{facing}", "tiles": 1, "fill": 0.42,
                            "refs": [], "chain": "" if aid == base else base,
                            "subject": f"{look}, {doing}, {way}"})
    for id, subject in ui["icons"].items():
        out.append(icon(id, subject))
    eggs = json.load(open(os.path.join(ROOT, "data", "mystery_eggs.json")))
    for colour in eggs["colours"]:
        look = {"golden": "shining gold", "grey": "soft grey", "cornish": "chestnut brown with black speckles"}.get(colour, colour)
        out.append(icon("egg_" + colour, f"a large {look} egg with a swirly golden pattern and a little sparkle, a mystery egg"))
    out.append(icon("mystery_box", "a cardboard mystery gift box with a big red ribbon, the lid slightly open with a glow coming out"))
    cols = json.load(open(os.path.join(ROOT, "data", "collections.json")))
    for c in cols["collections"]:
        for it in c["items"]:
            bird = c["id"] == "farm_birds"
            out.append(icon("collect_" + it["id"], f"a cute {it['name'].lower()} bird perched" if bird else
                            f"a {it['name'].lower()}, a little collectible keepsake from a country farm"))
    rib = json.load(open(os.path.join(ROOT, "data", "ribbons.json")))
    for r in rib["ribbons"]:
        out.append(icon("ribbon_" + r["id"], f"a white prize rosette ribbon with a small emblem in the middle that shows {r['what']}"))
    return out


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
                    refs = [] if cls in ("Material", "Recipe") else [f"refs/{art}.png"]
                    if os.path.exists(os.path.join(ROOT, "art", "refs3d", e["id"] + ".png")):
                        refs.append(f"refs3d/{e['id']}.png")
                    items.append({"id": art, "item": e["id"], "class": cls, "stage": stage,
                                  "tiles": int(e.get("w", 1)), "fill": float(e.get("art_fill", lc.get("fill", 0.7))),
                                  "refs": refs, "subject": subject(cls, e, stage, len(stages))})
    items += extra_art()
    # Ground (grass, soil) is drawn by the game so plots always line up; no ground tiles here.
    return {"_note": "Generated by tools/make_art_manifest.py from data/catalog/. Don't edit by hand: change the catalog "
                     "(look, art_fill) or the generator.",
            "version": MANIFEST_VERSION, "common": COMMON, "commons": COMMONS, "styles": STYLES, "style_refs": STYLE_REFS, "items": items}


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
