#!/usr/bin/env python3
"""Writes docs/CATALOG.md from data/catalog/: every item, by category -> family -> variant,
plus the class tree and field reference from schema.json. Run after changing the data:

    python3 tools/make_catalog.py          # rewrite docs/CATALOG.md
    python3 tools/make_catalog.py --check  # exit 1 if it's out of date (CI runs this)
"""
import json, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data", "catalog")
OUT = os.path.join(ROOT, "docs", "CATALOG.md")
schema = json.load(open(os.path.join(DATA, "schema.json")))
classes = schema["classes"]


def fields_of(cls):
    chain = []
    while cls:
        chain.insert(0, cls)
        cls = classes[cls].get("extends")
    out = {}
    for c in chain:
        for k, v in classes[c]["fields"].items():
            out[k] = (v, c)
    return out


def dur(sec):
    if not sec:
        return ""
    sec = int(sec)
    if sec % 86400 == 0:
        d = sec // 86400
        return f"{d} day" + ("s" if d > 1 else "")
    return f"{sec // 3600} h" if sec % 3600 == 0 else f"{sec // 60} min"


def money(e):
    if e.get("gem_cost"):
        return f"{e['gem_cost']} gems"
    c = e.get("cost", 0)
    return f"{c:,}" if c else "free"


def unlock(e):
    lvl = e.get("unlock_level", 1)
    return "never sold" if lvl >= 99 else str(lvl)


COLUMNS = {
    "Crop": [("Unlock", unlock), ("Seed", lambda e: e.get("seed_cost", "")), ("Grows", lambda e: dur(e.get("grow_seconds"))),
             ("Sells", lambda e: e.get("sell_price", "")), ("XP", lambda e: e.get("xp", ""))],
    "Tree": [("Unlock", unlock), ("Cost", money), ("Every", lambda e: dur(e.get("cycle_seconds"))), ("Pays", lambda e: e.get("payout", "")),
             ("Notes", lambda e: ("rare variety of " + e["rare_of"].replace("_", " ")) if e.get("rare_of") else "")],
    "Animal": [("Unlock", unlock), ("Cost", money), ("Gives", lambda e: e.get("product", "")), ("Every", lambda e: dur(e.get("cycle_seconds"))),
               ("Pays", lambda e: e.get("payout", "")),
               ("Notes", lambda e: "; ".join(x for x in [("stray, needs a " + e["home"].replace("_", " ")) if e.get("stray_only") else "",
                                                          ("breed: " + e["breed"]) if e.get("breed") else "",
                                                          "traded for truffles" if e.get("rare_pig") else ""] if x))],
    "Building": [("Unlock", unlock), ("Cost", money), ("Size", lambda e: f"{e.get('w', 1)}x{e.get('h', 1)}"),
                 ("Holds", lambda e: " / ".join(str(s["capacity"]) for s in e.get("sizes", []))),
                 ("Tab", lambda e: e.get("tab", "")), ("Limit", lambda e: (f"{e.get('group_limit')} {e['limit_group']}" if e.get("limit_group") else str(e.get("limit", 1)))),
                 ("Built from", lambda e: "frame" if e.get("build_materials") else ""),
                 ("Special", lambda e: e.get("special", ""))],
    "Vehicle": [("Unlock", unlock), ("Cost", money), ("Job", lambda e: e.get("job", "")), ("Fuel a plot", lambda e: e.get("fuel_per_plot", "")),
                ("Upgrade parts", lambda e: ", ".join(str(x) for x in e.get("upgrade_parts", [])))],
    "Decoration": [("Unlock", unlock), ("Cost", money), ("Size", lambda e: f"{e.get('w', 1)}x{e.get('h', 1)}"), ("Shape", lambda e: e.get("shape", ""))],
    "Material": [("Basic", lambda e: "yes" if e.get("basic") else "")],
}
TITLES = {"crops": "Crops", "trees": "Trees", "animals": "Animals", "buildings": "Buildings", "vehicles": "Vehicles",
          "decorations": "Decorations", "materials": "Materials"}


def stack(cls, file_defaults, fam_defaults, entry):
    out = {k: v["default"] for k, (v, _) in fields_of(cls).items() if "default" in v}
    out.update(file_defaults); out.update(fam_defaults); out.update(entry)
    return out


def build():
    L = ["# Catalog", "",
         "Every item in the game, generated from `data/catalog/` by `tools/make_catalog.py`. Don't edit this file by hand.", "",
         "**Layout:** category (one data file) → family (variants that share defaults) → variant (one item).",
         "**Status:** ✅ in the game · 🕓 planned (catalogued from FarmVille, not built yet).", ""]
    totals = []
    body = []
    for cat, cls in schema["files"].items():
        d = json.load(open(os.path.join(DATA, cat + ".json")))
        n_in = n_pl = 0
        body += [f"## {TITLES.get(cat, cat)}", "", d.get("_note", ""), ""]
        for fam in d["families"]:
            vs = [stack(schema.get("kind_classes", {}).get(v.get("kind", ""), cls), d.get("defaults", {}), fam.get("defaults", {}), v) for v in fam["variants"]]
            ins = sum(1 for v in vs if v.get("status") != "planned")
            n_in += ins; n_pl += len(vs) - ins
            body += [f"### {fam['name']}", ""]
            if fam.get("doc"):
                body += [fam["doc"], ""]
            if fam.get("defaults"):
                body += ["Shared: " + ", ".join(f"`{k}` = {json.dumps(v)}" for k, v in fam["defaults"].items()), ""]
            if not vs:
                body += ["_Nothing yet._", ""]
                continue
            cols = COLUMNS.get(cls, [])
            body.append("| | Item | id | " + " | ".join(c for c, _ in cols) + " |")
            body.append("|---|---|---|" + "---|" * len(cols))
            for v in vs:
                mark = "🕓" if v.get("status") == "planned" else "✅"
                cells = ["" if v.get("status") == "planned" and c not in ("Unlock", "Grows", "Every") else str(fn(v)) for c, fn in cols]
                name = v["name"] + (f" ({v['note']})" if v.get("note") else "")
                body.append(f"| {mark} | {name} | `{v['id']}` | " + " | ".join(cells) + " |")
            body.append("")
        totals.append((TITLES.get(cat, cat), len(d["families"]), n_in, n_pl))
    L += ["| Category | Families | In game | Planned |", "|---|---|---|---|"]
    for t in totals:
        L.append(f"| {t[0]} | {t[1]} | {t[2]} | {t[3]} |")
    L.append(f"| **All** | **{sum(t[1] for t in totals)}** | **{sum(t[2] for t in totals)}** | **{sum(t[3] for t in totals)}** |")
    L += ["", "## Adding an item", "",
          "1. Find its category file in `data/catalog/` and the family it belongs to (or add a family).",
          "2. Add a variant with `id` and `name`, plus only what differs from the family's and file's defaults.",
          "3. Give it art: a `shape` for its placeholder drawing now, and an entry in `art/manifest.json` for final art.",
          "4. Run the tests (Godot, F6 on `tests/run_tests.tscn`) and `python3 tools/make_catalog.py`. The catalog loader names any missing or mistyped field, and any reference to something that doesn't exist.",
          "",
          "A new **kind** of thing needs a class: add it to `schema.json` (with `extends` and its fields) and a matching `scripts/catalog/<kind>_def.gd` that extends its parent and overrides only what's different.",
          ""]
    # Collectibles: drops gathered into sets (data/collections.json).
    colls = json.load(open(os.path.join(ROOT, "data", "collections.json")))["collections"]
    body += ["## Collectibles", "", "Drops found while harvesting, gathered into sets and traded in for rewards (`data/collections.json`).", ""]
    for c in colls:
        where = ("from " + ", ".join(x.replace("_", " ") for x in c["crops"])) if c.get("crops") else "spotted while farming"
        reward = ", ".join(x for x in [f"{c['reward_coins']:,} coins" if c.get("reward_coins") else "", f"{c['reward_xp']} XP" if c.get("reward_xp") else ""] if x)
        body += [f"### {c['name']}", "", f"Found {where}." + (f" Trade-in reward: {reward}." if reward else ""), "",
                 ", ".join(i["name"] for i in c["items"]), ""]
    totals.append(("Collectibles", len(colls), sum(len(c["items"]) for c in colls), 0))
    L[L.index("| **All** | **%d** | **%d** | **%d** |" % (sum(t[1] for t in totals[:-1]), sum(t[2] for t in totals[:-1]), sum(t[3] for t in totals[:-1])))] = \
        "| Collectibles | %d sets | %d | 0 |\n| **All** | **%d** | **%d** | **%d** |" % (len(colls), totals[-1][2], sum(t[1] for t in totals), sum(t[2] for t in totals), sum(t[3] for t in totals))
    L += ["## Classes", "", "Each class inherits its parent's fields and rules. The code for each is in `scripts/catalog/`.", "", "```"]

    def tree(cls, depth):
        kids = [c for c, v in classes.items() if v.get("extends") == cls]
        abstract = " (abstract)" if classes[cls].get("abstract") else ""
        L.append("  " * depth + cls + abstract + " - " + classes[cls]["doc"])
        for k in kids:
            tree(k, depth + 1)
    tree("Item", 0)
    L += ["```", ""]
    for cls, spec in classes.items():
        L += [f"### {cls}" + (f" (extends {spec['extends']})" if spec.get("extends") else ""), "", spec["doc"], "",
              "| Field | Type | Default | Required | Meaning |", "|---|---|---|---|---|"]
        for k, v in spec["fields"].items():
            t = v["type"] + (" of " + ", ".join(v["values"]) if v.get("values") else "") + (f" → {v['ref']}" if v.get("ref") else "")
            dflt = json.dumps(v["default"]) if "default" in v else ""
            L.append(f"| `{k}` | {t} | {dflt} | {'yes' if v.get('required') else ''} | {v.get('doc', '')} |")
        L.append("")
    L += body
    return "\n".join(L).rstrip() + "\n"


if __name__ == "__main__":
    text = build()
    if "--check" in sys.argv:
        current = open(OUT).read() if os.path.exists(OUT) else ""
        if current != text:
            print("docs/CATALOG.md is out of date: run python3 tools/make_catalog.py")
            sys.exit(1)
        print("docs/CATALOG.md is up to date")
    else:
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        open(OUT, "w").write(text)
        print("wrote", OUT)
