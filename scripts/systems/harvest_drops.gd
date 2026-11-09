class_name HarvestDrops
extends GameSystem
## Surprise drops rolled on every harvest: golden and super harvests, bonus XP, with pity counters.
## Part of the game state: reached as `Game.drops`; shared state is on `game`.

# Surprise drops, rolled on every harvest. Chances are per harvest.
const GOLDEN_CHANCE := 0.004      # golden harvest: 5x coins, +10 XP
const GOLDEN_PITY := 250          # guaranteed after this many harvests without one
const COLLECTIBLE_CHANCE := 0.05  # one item from the crop's collection
const COLLECTIBLE_PITY := 30
const SUPER_HARVEST_CHANCE := 0.06  # super harvest: double coins
const BIRD_CHANCE := 0.03          # a bird visits: one item from the bird collection
const BONUS_XP_CHANCE := 0.05     # +2 XP
const MASTERY_LUCK_BONUS := 0.15  # per mastery star, multiplies golden and collectible chances

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


## One roll per harvest. Rarest outcomes are checked first; pity counters
## guarantee a golden harvest or a collectible after a long dry spell.
func roll_drop(crop_id: String, stars: int, super_mult := 1) -> Dictionary:
	if not game.drops_enabled:
		return {}
	pity["golden"] = int(pity["golden"]) + 1
	pity["collectible"] = int(pity["collectible"]) + 1
	var luck := 1.0 + MASTERY_LUCK_BONUS * stars

	if int(pity["golden"]) >= GOLDEN_PITY or game.rng.randf() < GOLDEN_CHANCE * luck:
		pity["golden"] = 0
		return {"type": "golden", "text": tr("GOLDEN_HARVEST")}

	# A due collectible (pity) always wins over a bird visit.
	var collectible_due := int(pity["collectible"]) >= COLLECTIBLE_PITY
	if not game.collectibles.bird_collection.is_empty() and not collectible_due and game.rng.randf() < BIRD_CHANCE:
		var bird_id := game.collectibles.pick_item(game.collectibles.bird_collection)
		game.collectibles.owned[bird_id] = int(game.collectibles.owned.get(bird_id, 0)) + 1
		game.ribbons.bump("birds_seen", 1)
		game.collections_changed.emit()
		return {"type": "bird", "text": tr("A_VISITED") % game.collectibles.item_names[bird_id].to_lower(),
			"name": game.collectibles.item_names[bird_id], "collection": game.collectibles.bird_collection["name"]}

	var coll: Dictionary = game.collectibles.collection_of_crop.get(crop_id, {})
	if not coll.is_empty() and (
		int(pity["collectible"]) >= COLLECTIBLE_PITY or game.rng.randf() < COLLECTIBLE_CHANCE * luck
	):
		pity["collectible"] = 0
		var item_id := game.collectibles.pick_item(coll)
		game.collectibles.owned[item_id] = int(game.collectibles.owned.get(item_id, 0)) + 1
		game.collections_changed.emit()
		return {"type": "collectible", "text": tr("FOUND") + game.collectibles.item_names[item_id],
			"name": game.collectibles.item_names[item_id], "collection": coll["name"]}

	var r := game.rng.randf()
	var super_chance := SUPER_HARVEST_CHANCE * super_mult
	if r < super_chance:
		return {"type": "super_harvest", "text": tr("SUPER_HARVEST_X_COINS")}
	if r < super_chance + BONUS_XP_CHANCE:
		return {"type": "bonus_xp", "text": tr("BONUS_XP")}
	return {}
