class_name CollectiblesSystem
extends GameSystem
## Collections, the FarmVille way: items found while farming, rarity, and 3-level trade-ins.
## Part of the game state: reached as `Game.collectibles`; shared state is on `game`.

var coll_levels := {}              # collection id -> trade-in levels done (3 levels, then it repeats)
var tree_collection := {}          # the collection found while harvesting trees
var animal_collection := {}        # the collection found while collecting animals
var collections: Array = []        # from data/collections.json
var collections_data := {}         # the whole file: levels, rarity weights
var collection_of_crop := {}       # crop id -> collection dictionary
var bird_collection := {}          # the collection whose items are birds
var item_names := {}               # item id -> display name
var owned := {}                    # item id -> count held


func _init(owner: GameState) -> void:
	super(owner)


func load_data() -> void:
	var parsed := game.read_json("res://data/collections.json")
	collections_data = parsed
	collections = parsed.get("collections", [])
	for coll in collections:
		if coll.get("birds", false):
			bird_collection = coll
		match str(coll.get("source", "")):
			"trees": tree_collection = coll
			"animals": animal_collection = coll
		for crop_id in coll.get("crops", []):
			collection_of_crop[crop_id] = coll
		for item in coll["items"]:
			item_names[item["id"]] = item["name"]


func reset() -> void:
	owned = {}
	coll_levels = {}


func save_to(data: Dictionary) -> void:
	data["owned"] = owned
	data["coll_levels"] = coll_levels


func load_from(data: Dictionary) -> void:
	owned = int_map(data.get("owned", {}))
	coll_levels = int_map(data.get("coll_levels", {}))


## Items you hold fewer of are more likely, so sets fill up instead of piling duplicates.
func pick_item(coll: Dictionary) -> String:
	var weights: Array[float] = []
	var total := 0.0
	var rarity: Dictionary = collections_data.get("rarity_weight", {})
	for item in coll["items"]:
		var w := 1.0 / (1.0 + 2.0 * int(owned.get(item["id"], 0)))
		w *= float(rarity.get(item.get("rarity", "common"), 1))
		weights.append(w)
		total += w
	var pick := game.rng.randf() * total
	for k in weights.size():
		pick -= weights[k]
		if pick <= 0.0:
			return coll["items"][k]["id"]
	return coll["items"][-1]["id"]


## The trade-in level this set is on next: 0, 1 or 2 (after level 3 it repeats from level 1).
func coll_level(coll: Dictionary) -> int:
	return int(coll_levels.get(coll["id"], 0)) % 3


## Item id -> how many the next trade-in takes (FarmVille: 3/2/1, then 6/4/2, then 12/8/4).
func coll_need(coll: Dictionary) -> Dictionary:
	var need: Dictionary = collections_data["levels"][coll_level(coll)]["need"]
	var out := {}
	for item in coll["items"]:
		out[item["id"]] = int(need.get(item.get("rarity", "common"), 1))
	return out


## {"coins", "xp", "prize"} for the next trade-in.
func coll_reward(coll: Dictionary) -> Dictionary:
	var lvl: Dictionary = collections_data["levels"][coll_level(coll)]
	return {"coins": int(lvl["coins"]), "xp": int(lvl["xp"]), "prize": coll["rewards"][coll_level(coll)]}


func can_trade_in(coll: Dictionary) -> bool:
	var need := coll_need(coll)
	for id in need:
		if int(owned.get(id, 0)) < int(need[id]):
			return false
	return true


func trade_in(coll_id: String) -> bool:
	for coll in collections:
		if coll["id"] != coll_id:
			continue
		if not can_trade_in(coll):
			return false
		var need := coll_need(coll)
		var reward := coll_reward(coll)
		var lvl := coll_level(coll) + 1
		for id in need:
			owned[id] = int(owned[id]) - int(need[id])
		game.add_coins(int(reward["coins"]))
		game.add_xp(int(reward["xp"]))
		var prize := game.mystery.give_prize(reward["prize"])
		coll_levels[coll_id] = int(coll_levels.get(coll_id, 0)) + 1
		game.message.emit(
			tr("LEVEL_COINS_XP_AND") % [
				coll["name"],
				lvl,
				int(reward["coins"]),
				int(reward["xp"]),
				prize
			]
		)
		game.ribbons.bump("collections_traded", 1)
		game.collections_changed.emit()
		game.queue_save()
		return true
	return false


## One roll for a collectible from a set, outside harvests (no pity). Returns the item name or "".
func roll_collectible(coll: Dictionary, chance: float, index := -1) -> String:
	if coll.is_empty() or not game.drops_enabled or game.rng.randf() >= chance:
		return ""
	var item_id := pick_item(coll)
	owned[item_id] = int(owned.get(item_id, 0)) + 1
	game.collections_changed.emit()
	var text: String = tr("FOUND") + str(item_names[item_id])
	if index >= 0:
		game.found.emit(index, text)
	else:
		game.message.emit(tr("COLLECTION") % [text, coll["name"]])
	return item_names[item_id]


## A collection to roll on a plow: the set of the crop that was there, or one for a crop you can grow.
func plow_collection(old_crop: String) -> Dictionary:
	if collection_of_crop.has(old_crop):
		return collection_of_crop[old_crop]
	var pool: Array = []
	for coll in collections:
		for c in coll.get("crops", []):
			if game.crops.has(c) and int(game.crops[c]["unlock_level"]) <= game.level():
				pool.append(coll)
				break
	return pool[game.rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else {}
