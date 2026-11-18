class_name HarvestDrops
extends GameSystem
## Surprise drops rolled on every harvest: golden and super harvests, bonus XP, with pity counters.
## Part of the game state: reached as `Game.drops`; shared state is on `game`.

# Surprise drops, rolled on every harvest. Chances are per harvest.

var pity := {"golden": 0, "collectible": 0}


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
	pity = {"golden": 0, "collectible": 0}


func save_to(data: Dictionary) -> void:
	data["pity"] = pity


func load_from(data: Dictionary) -> void:
	var saved: Dictionary = data.get("pity", {})
	pity = {"golden": int(saved.get("golden", 0)), "collectible": int(saved.get("collectible", 0))}


## What a harvest turns up, decided and given in one go (animals and trees, which have no plot to hold it).
func roll_drop(crop_id: String, stars: int, super_mult := 1) -> Dictionary:
	return give_drop(decide_drop(crop_id, stars, super_mult))


## Decides what a harvest will turn up, without giving it: {} or {type} ("golden", "super_harvest", "bonus_xp"),
## and for a "bird" or a "collectible" which `item` (and the `crop` whose set it is from). The luck is spent here
## (the pity counters move); a crop's is decided when it is planted and kept with its plot, so a plot holding
## something can glint before it is harvested (FieldSystem).
func decide_drop(crop_id: String, stars: int, super_mult := 1) -> Dictionary:
	if not game.drops_enabled:
		return {}
	pity["golden"] = int(pity["golden"]) + 1
	if crop_id != "":
		pity["collectible"] = int(pity["collectible"]) + 1   # animals and trees (no crop) can never discharge it
	var luck := 1.0 + Balance.f("harvest.mastery_luck_bonus") * stars + game.boosts.total("golden_luck")

	var golden := Balance.f("harvest.golden_chance") * luck
	if int(pity["golden"]) >= Balance.i("harvest.golden_pity") or game.rolls.roll("golden", golden):
		pity["golden"] = 0
		return {"type": "golden"}

	# A due collectible (pity) always wins over a bird visit.
	var collectible_due := int(pity["collectible"]) >= Balance.i("harvest.collectible_pity")
	var bird := Balance.f("harvest.bird_chance")
	if not game.collectibles.bird_collection.is_empty() and not collectible_due and game.rolls.roll("bird", bird):
		return {"type": "bird", "item": game.collectibles.pick_item(game.collectibles.bird_collection)}

	var coll: Dictionary = game.collectibles.collection_of_crop.get(crop_id, {})
	if not coll.is_empty() and (
		int(pity["collectible"]) >= Balance.i("harvest.collectible_pity")
		or game.rolls.roll("collectible", Balance.f("harvest.collectible_chance") * luck)
	):
		pity["collectible"] = 0
		return {"type": "collectible", "item": game.collectibles.pick_item(coll), "crop": crop_id}

	var r := game.rng.randf()
	var super_chance := Balance.f("harvest.super_harvest_chance") * super_mult
	if r < super_chance:
		return {"type": "super_harvest"}
	if r < super_chance + Balance.f("harvest.bonus_xp_chance"):
		return {"type": "bonus_xp"}
	return {}


## Gives a decided drop (a bird or a collectible joins its set) and returns it with its words: {type, text,
## rarity}, and {name, collection} for a bird or a collectible. {} for none.
func give_drop(drop: Dictionary) -> Dictionary:
	var out := drop.duplicate()
	match str(drop.get("type", "")):
		"":
			return {}
		"golden":
			out["text"] = tr("GOLDEN_HARVEST")
		"super_harvest":
			out["text"] = tr("SUPER_HARVEST_X_COINS") % Balance.i("economy.super_harvest_multiplier")
		"bonus_xp":
			out["text"] = tr("BONUS_XP")
		"bird", "collectible":
			var item := str(drop["item"])
			var is_bird := str(drop["type"]) == "bird"
			var coll: Dictionary = game.collectibles.bird_collection if is_bird \
				else game.collectibles.collection_of_crop.get(str(drop.get("crop", "")), {})
			game.collectibles.owned[item] = int(game.collectibles.owned.get(item, 0)) + 1
			if is_bird:
				game.ribbons.bump("birds_seen", 1)
			game.collections_changed.emit()
			var item_name := str(game.collectibles.item_names.get(item, item))
			out["name"] = item_name
			out["collection"] = str(coll.get("name", ""))
			out["text"] = tr("A_VISITED") % item_name.to_lower() if is_bird else tr("FOUND") + item_name
	out["rarity"] = rarity_of(drop)
	return out


## How rare a decided drop is, for its glint in the field and its burst when found: a golden harvest is
## legendary, a bird rare, a collectible as rare as its item; the small bonuses are common (and do not glint).
func rarity_of(drop: Dictionary) -> String:
	match str(drop.get("type", "")):
		"golden":
			return "legendary"
		"bird":
			return "rare"
		"collectible":
			return game.collectibles.rarity_of(str(drop.get("item", "")))
	return "common"


## Whether a decided drop is a find worth a glint before the harvest (the small bonuses stay a surprise).
static func glints(drop: Dictionary) -> bool:
	return str(drop.get("type", "")) in ["golden", "bird", "collectible"]
