class_name FindsSystem
extends GameSystem
## Things found while farming: gophers, and later every creature or item that turns up as you work (data in
## data/finds.json). One framework: a family is a set of kinds, found by one kind of work, rolled with a
## chance that mastery raises and a pity counter that keeps luck fair. What is owned feeds homes (a Gopher
## Garden needs one, and grows as you find more) and collections (finding every kind pays a reward).
## Reached as `Game.finds`.

const DATA := "res://data/finds.json"

var owned := {}           # kind id -> how many found
var pity := {}            # family -> dry rolls since the last find
var claimed := {}         # family -> true once its collection reward is paid
var families := {}        # family id -> its data


func load_data() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	families = (parsed as Dictionary).get("families", {}) if parsed is Dictionary else {}


func reset() -> void:
	owned = {}
	pity = {}
	claimed = {}


func save_to(data: Dictionary) -> void:
	data["finds_owned"] = owned
	data["finds_pity"] = pity
	data["finds_claimed"] = claimed


func load_from(data: Dictionary) -> void:
	owned = int_map(data.get("finds_owned", {}))
	pity = int_map(data.get("finds_pity", {}))
	claimed = {}
	var saved: Variant = data.get("finds_claimed", {})
	if saved is Dictionary:
		for k in saved:
			claimed[str(k)] = bool(saved[k])


## Rolls every family triggered by `work` ("harvest"); returns what was found: [{family, id, name, rarity}].
func roll(work: String, stars := 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not game.drops_enabled:
		return out
	for fid: String in families:
		var trig: Dictionary = families[fid].get("trigger", {})
		if str(trig.get("on", "")) != work:
			continue
		pity[fid] = int(pity.get(fid, 0)) + 1
		var chance := float(trig.get("chance", 0.0)) * (1.0 + float(trig.get("mastery_luck", 0.0)) * stars + help_for(fid))
		if int(pity[fid]) >= int(trig.get("pity", 1000000)) or game.rng.randf() < chance:
			pity[fid] = 0
			var kind := pick(fid)
			if not kind.is_empty():
				out.append(add(fid, kind))
	return out


## What the other families help this one with (our own touch): each find of a helping family adds its share to the
## find chance, up to that family's `help_cap`. Dogs sniff out gophers.
func help_for(target: String) -> float:
	var sum := 0.0
	for fid: String in families:
		var share := float(families[fid].get("helps", {}).get(target, 0.0))
		if share > 0.0:
			sum += minf(share * total(fid), float(families[fid].get("help_cap", 1.0)))
	return sum


## A kind of the family by weight (common ones turn up more).
func pick(family: String) -> Dictionary:
	var kinds: Array = families.get(family, {}).get("kinds", [])
	var total := 0
	for k: Dictionary in kinds:
		total += int(k.get("weight", 1))
	if total <= 0:
		return {}
	var r := game.rng.randi_range(1, total)
	for k: Dictionary in kinds:
		r -= int(k.get("weight", 1))
		if r <= 0:
			return k
	return kinds[-1]


## One more of `kind` found; pays the collection reward the first time the family is complete.
func add(family: String, kind: Dictionary) -> Dictionary:
	var id := str(kind["id"])
	owned[id] = int(owned.get(id, 0)) + 1
	game.ribbons.bump("finds", 1)
	game.collections_changed.emit()
	game.message.emit(tr("YOU_FOUND_A_FIND") % [kind["name"], families[family]["name"]])
	_claim_if_complete(family)
	grow_homes(family)
	return {"family": family, "id": id, "name": kind["name"], "rarity": kind.get("rarity", "common")}


func count(kind_id: String) -> int:
	return int(owned.get(kind_id, 0))


## How many are owned across the whole family.
func total(family: String) -> int:
	var n := 0
	for k: Dictionary in families.get(family, {}).get("kinds", []):
		n += count(str(k["id"]))
	return n


## How many different kinds of the family have been found.
func distinct(family: String) -> int:
	var n := 0
	for k: Dictionary in families.get(family, {}).get("kinds", []):
		if count(str(k["id"])) > 0:
			n += 1
	return n


## The level the family's home has reached: how many tiers the count owned has passed (0 with none).
func tier(family: String) -> int:
	var have := total(family)
	var level := 0
	for t in families.get(family, {}).get("tiers", []):
		if have >= int(t):
			level += 1
	return level


func is_complete(family: String) -> bool:
	var kinds: Array = families.get(family, {}).get("kinds", [])
	return not kinds.is_empty() and distinct(family) >= kinds.size()


func _claim_if_complete(family: String) -> void:
	if claimed.get(family, false) or not is_complete(family):
		return
	claimed[family] = true
	var reward: Dictionary = families[family].get("reward", {})
	game.add_coins(int(reward.get("coins", 0)))
	game.add_xp(int(reward.get("xp", 0)))
	game.message.emit(tr("FIND_COLLECTION_COMPLETE") % [families[family]["name"], int(reward.get("coins", 0))])


## Every home of the family is at the level the finds have reached (never lower, never past its biggest size).
func grow_homes(family: String) -> void:
	var level := maxi(tier(family), 1)
	for o in game.objects:
		if str(game.item_data(o["id"]).get("home_of", "")) != family or game.under_construction(o):
			continue
		var to := mini(level, game.max_level(str(o["id"])))
		if to > game.level_of(o):
			o["level"] = to
			game.message.emit(tr("HOME_GREW") % [game.item_data(o["id"])["name"], game.size_name(o)])
	game.objects_changed.emit()
