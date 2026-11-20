#!/usr/bin/env python3
"""Puts the limited animals and trees into the game's data, so a new one is one row to write (docs/LIMITED.md,
"Adding one").
Animals: for every row of tools/animal_art/animal_art/limited.py that has no entry yet it writes its catalog entry
(data/catalog/animals.json: limited, sold for gems, its variety, its baby, its touch), its place in its family's
home and its baby's in the Nursery (data/catalog/buildings.json), and its file (data/assets.json).
Trees: for every plain tree and every variety trees come in (data/varieties.json `trees`) it writes the limited
tree (data/catalog/trees.json: a variety of that tree, sold for gems). A tree's look is drawn by the game from
its variety, so it has no file.
An entry that is there is never changed, but for a missing `variety`: its price and payout are the owner's to tune.

  python3 tools/make_limited.py            adds what is missing
  python3 tools/make_limited.py --check    fails when a row has no entry, or a limited entry no row (precheck, CI)
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools" / "animal_art"))
from animal_art import limited as art  # noqa: E402  (the art tool is found by the line above)

ANIMALS = ROOT / "data" / "catalog" / "animals.json"
TREES = ROOT / "data" / "catalog" / "trees.json"
VARIETIES = ROOT / "data" / "varieties.json"
BUILDINGS = ROOT / "data" / "catalog" / "buildings.json"
ASSETS = ROOT / "data" / "assets.json"
MODEL = "res://art/models/limited/%s.glb"
NURSERY = "nursery_barn"
# What a new limited animal of each family starts with: the plain animal it is a coat of (its produce, level and
# timing), its home, its price in gems (the owner's: about double an ordinary gem animal, by kind) and, where
# the family has births in the game, the plain baby its own baby copies.
FAMILIES = {
    "cow": dict(plain="cow", home="cow_shed", gems=50, baby="calf"),
    "horse": dict(plain="horse", home="horse_stable", gems=50, baby="foal"),
    "pig": dict(plain="pig", home="pig_pen", gems=35, baby="piglet"),
    "sheep": dict(plain="sheep", home="sheep_pen", gems=35, baby="lamb"),
    "goat": dict(plain="goat", home="goat_pen", gems=35),
    "camelid": dict(plain="alpaca", home="sheep_pen", gems=50),
    "chicken": dict(plain="chicken", home="chicken_coop", gems=20),
    "turkey": dict(plain="turkey", home="chicken_coop", gems=20),
    "duck": dict(plain="duck", home="duck_pond", gems=20),
    "goose": dict(plain="goose", home="duck_pond", gems=20),
    "rabbit": dict(plain="rabbit", home="rabbit_hutch", gems=20),
}
PAY = 1.5        # a limited animal pays this many times its family's plain animal..
PAY_STEP = 5     # ..rounded to this many coins
TREE_OWN = ["cycle_seconds"]   # a plain tree's own fields that its limited varieties keep
BABY_LEVEL = 99  # a baby is never sold: it is born or found
NOTE = "a limited coat: values estimated in FarmVille's style"
TREE_NOTE = "a limited variety: values estimated in FarmVille's style"
ACCENTS = ("coat2", "wing", "points", "pale")   # a row's second colour, by the first of these it has


def item_id(name):
    return name.replace(" ", "_")


def title(name):
    return " ".join(word.capitalize() for word in name.split())


def colours(row):
    """A row's coat and accent as the catalog writes them (the accent tints its sparkles and touch)."""
    coat = row["coat"]
    accent = (row.get("paint") or {}).get("c2") or next((row[k] for k in ACCENTS if row.get(k)), coat)
    return "#" + coat, "#" + accent


def variety_of(name):
    """An animal's variety: its name without its kind (the last word): "cotton candy sheep" is cotton_candy."""
    return item_id(name.rsplit(" ", 1)[0])


def tree_entries(trees, varieties):
    """Every limited tree the varieties ask for, as (the family it joins, its entry)."""
    out = []
    for family in trees["families"]:
        plain = next((v for v in family["variants"] if not v.get("rare_of") and not v.get("limited")), None)
        if plain is None:
            continue
        level = plain.get("unlock_level", trees.get("defaults", {}).get("unlock_level", 1))
        gems = next(g for most, g in varieties["tree_gems"] if level <= most)
        for vid in varieties["trees"]:
            v = varieties["varieties"][vid]
            entry = {"id": "%s_%s" % (vid, plain["id"]), "name": "%s %s" % (v["name"], plain["name"]),
                     "unlock_level": level, "cost": 0, "gem_cost": gems,
                     "payout": int(round(plain["payout"] * varieties["tree_pay"] / PAY_STEP)) * PAY_STEP,
                     "xp": plain.get("xp", 1), "color": plain["color"], "limited": True, "variety": vid,
                     "limited_of": plain["id"], "note": TREE_NOTE}
            if v.get("touch"):
                entry["touch"] = v["touch"]
            for own in TREE_OWN:   # (what a tree sets apart from its family, its variety keeps: it ripens as it does)
                if own in plain:
                    entry[own] = plain[own]
            out.append((family, entry))
    return out


def entries(family, name, row, by_id):
    """The catalog entries a row asks for: [its own, its baby's (if its family has births)]."""
    rule = FAMILIES[family]
    plain = by_id["llama" if "llama" in name else rule["plain"]]
    coat, accent = colours(row)
    own = {"id": item_id(name), "name": title(name)}
    if plain.get("product"):
        own["product"] = plain["product"]
    own.update(unlock_level=plain.get("unlock_level", 1), cost=0, gem_cost=rule["gems"],
               payout=int(round(plain["payout"] * PAY / PAY_STEP)) * PAY_STEP)
    for key in ("xp", "cycle_seconds"):
        if key in plain:
            own[key] = plain[key]
    own.update(color=coat, accent=accent, limited=True, variety=variety_of(name))
    out = [own]
    if family in art.IN_GAME_BABIES:
        young = art.baby_name(name, art.BABY_WORDS[family])
        own["baby"] = item_id(young)
        plain_baby = by_id[rule["baby"]]
        out.append({"id": item_id(young), "name": title(young), "product": plain_baby["product"],
                    "unlock_level": BABY_LEVEL, "cost": 0, "payout": plain_baby["payout"],
                    "xp": plain_baby.get("xp", 1), "color": coat, "accent": accent, "young": True, "limited": True,
                    "variety": variety_of(name)})
    own["note"] = NOTE
    if row.get("touch"):
        for entry in out:
            entry["touch"] = row["touch"]
    return out


def read(path):
    return json.loads(path.read_text())


def write(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def main(argv):
    check = "--check" in argv
    animals, buildings, assets = read(ANIMALS), read(BUILDINGS), read(ASSETS)
    trees, varieties = read(TREES), read(VARIETIES)
    filled = []
    families = {f["id"]: f for f in animals["families"]}
    by_id = {v["id"]: v for f in animals["families"] for v in f["variants"]}
    homes = {v["id"]: v for f in buildings["families"] for v in f["variants"] if "holds" in v}
    wanted, added = set(), []
    for family, rows in art.ROWS.items():
        home = homes[FAMILIES[family]["home"]]
        for name, row in rows.items():
            made = entries(family, name, row, by_id)
            for k, entry in enumerate(made):
                wanted.add(entry["id"])
                house = homes[NURSERY] if k == 1 else home
                if entry["id"] in by_id and "variety" not in by_id[entry["id"]]:
                    by_id[entry["id"]]["variety"] = entry["variety"]
                    filled.append(entry["id"])
                if entry["variety"] not in varieties["varieties"]:
                    varieties["varieties"][entry["variety"]] = {"name": title(entry["variety"].replace("_", " "))}
                    filled.append("variety " + entry["variety"])
                if entry["id"] in by_id and entry["id"] in house["holds"] and entry["id"] in assets["assets"]:
                    continue
                added.append(entry["id"])
                if entry["id"] not in by_id:
                    families[family]["variants"].append(entry)
                if entry["id"] not in house["holds"]:
                    house["holds"].append(entry["id"])
                if k == 1:
                    house["grows_into"][entry["id"]] = made[0]["id"]
                assets["assets"].setdefault(entry["id"], {"model": MODEL % entry["id"], "budget": "animal"})
    by_tree = {v["id"]: v for f in trees["families"] for v in f["variants"]}
    tree_ids = set(by_tree)
    taken = []   # (a kind may already have a tree of a variety's name: a Golden Plum is the Orchard's rare plum)
    for family, entry in tree_entries(trees, varieties):
        if entry["id"] in tree_ids and not by_tree[entry["id"]].get("limited"):
            taken.append(entry["id"])
            continue
        wanted.add(entry["id"])
        if entry["id"] not in tree_ids:
            family["variants"].append(entry)
            added.append(entry["id"])
        elif by_tree[entry["id"]] != entry:
            # (A limited tree is wholly its plain tree's and its variety's: it follows a change to either.)
            by_tree[entry["id"]].clear()
            by_tree[entry["id"]].update(entry)
            filled.append(entry["id"])
    by_id.update({v["id"]: v for f in trees["families"] for v in f["variants"]})
    added += filled
    strays = sorted(i for i, v in by_id.items() if v.get("limited") and i not in wanted)
    if check:
        for i in added:
            print("limited %s is not (or not wholly) in the game's data: run tools/make_limited.py" % i)
        for i in strays:
            print("limited %s is in the catalog, and neither limited.py nor varieties.json asks for it" % i)
        if not added and not strays:
            print("the limited animals' and trees' data is up to date (%d)" % len(wanted))
        return 1 if added or strays else 0
    if added:
        write(ANIMALS, animals)
        write(BUILDINGS, buildings)
        write(ASSETS, assets)
        write(TREES, trees)
        VARIETIES.write_text(json.dumps(varieties, indent=1, ensure_ascii=False) + "\n")
    print("limited animals and trees: %d in the data, %d added or filled in" % (len(wanted), len(added)))
    for i in strays:
        print("note: %s is limited in the catalog and has no row in limited.py" % i)
    for i in taken:
        print("note: no limited %s: a tree of that name is there already (its kind has one variety fewer)" % i)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
