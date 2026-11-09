class_name BuildingSpecials
extends GameSystem
## What buildings do when collected: babies, helpers, fertilizer, rare saplings, grow-ups.
## Part of the game state: reached as `Game.specials`; shared state is on `game`.

const LAMB_CHANCE := 0.25          # Sheep Pen harvest with a ram inside
const PIGLET_CHANCE := 0.25        # Pig Pen harvest with a boar inside

# Building specials, the FarmVille way.
const CALF_CHANCE := 0.25          # Dairy Farm harvest with a bull inside
const FERTILIZER_CHANCE := 0.10    # Dairy Farm harvest drops a bag of fertilizer
const FOAL_CHANCE := 0.25          # Horse Stable harvest with a stallion inside
const STABLE_HELPER_CHANCE := 0.15 # Stable harvest: a farmhand, and separately an arborist
const STABLE_XP_CHANCE := 0.10     # Stable harvest with a stallion: 100 XP
const STABLE_XP := 100
const NURSERY_SPARE_XP := 25       # stands in for FarmVille's spare baby to gift a friend
const FERTILIZE_ALL_CHANCE := 0.10 # per hive collection

# Orchard: rare sapling varieties of the trees inside.
const SAPLING_CHANCE := 0.10


func _init(owner: GameState) -> void:
	super(owner)


## FarmVille's Baby Turkey and Ugly Duckling grow up after their first collection.
func grows_into(item_id: String) -> String:
	var d := game.catalog.get_def(item_id)
	return (d as AnimalDef).grows_into() if d is AnimalDef else ""


func grow_up_inside(b: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var inside: Dictionary = b.get("inside", {})
	for id in inside.keys():
		var adult := grows_into(id)
		if adult == "" or int(inside[id]) <= 0:
			continue
		inside[adult] = int(inside.get(adult, 0)) + int(inside[id])
		out.append("%d %s grew up!" % [int(inside[id]), game.item_data(id)["name"]])
		inside.erase(id)
	return out


## Which baby a Dairy Farm or Horse Stable brings: a breed's own baby, likelier for the breeds it holds more of.
func _pick_baby(b: Dictionary, plain: String) -> String:
	var inside: Dictionary = b.get("inside", {})
	var total := 0
	for id in inside:
		var d := game.catalog.get_def(id)
		if d is AnimalDef and not (d as AnimalDef).is_stray_only() and not (d as AnimalDef).is_young():
			total += int(inside[id])
	if total == 0:
		return plain
	var pick := game.rng.randi_range(1, total)
	for id in inside:
		var d := game.catalog.get_def(id)
		if d is AnimalDef and not (d as AnimalDef).is_stray_only() and not (d as AnimalDef).is_young():
			pick -= int(inside[id])
			if pick <= 0:
				var baby := (d as AnimalDef).baby()
				return baby if baby != "" else plain
	return plain


## Extra results of collecting a building, as short popup texts.
func building_specials(b: Dictionary) -> Array[String]:
	var out: Array[String] = []
	match game.item_data(b["id"]).get("special", ""):
		"mystery_eggs":
			var colour := game.mystery.roll_mystery_egg(b)
			if colour != "":
				game.mystery.mystery_eggs[colour] = int(game.mystery.mystery_eggs.get(colour, 0)) + 1
				var egg_name: String = game.mystery.egg_data["colours"][colour]["name"]
				game.message.emit("You found a %s! Open it from the coop." % egg_name)
				out.append(egg_name + "!")
		"calves":
			if game.drops_enabled and game.rng.randf() < FERTILIZER_CHANCE:
				game.fertilizer_bags += 1
				out.append("+1 Fertilizer")
			if game.has_inside(b, "bull") and game.drops_enabled and game.rng.randf() < CALF_CHANCE:
				var calf := _pick_baby(b, "calf")
				if game.place_somewhere(calf):
					game.message.emit(
						"A %s was born! Raise it in a Nursery Barn." % game.item_data(calf)["name"].to_lower()
					)
					out.append("A %s!" % game.item_data(calf)["name"].to_lower())
		"foals":
			var with_stallion := game.has_inside(b, "stallion")
			if game.drops_enabled and with_stallion and game.rng.randf() < FOAL_CHANCE:
				var foal := _pick_baby(b, "foal")
				if game.place_somewhere(foal):
					game.message.emit(
						"A %s was born! Raise it in a Nursery Barn." % game.item_data(foal)["name"].to_lower()
					)
					out.append("A %s!" % game.item_data(foal)["name"].to_lower())
			if game.drops_enabled and game.rng.randf() < STABLE_HELPER_CHANCE:
				game.farmhands += 1
				out.append("+1 Farmhand")
			if game.drops_enabled and game.rng.randf() < STABLE_HELPER_CHANCE:
				game.arborists += 1
				out.append("+1 Arborist")
			if game.drops_enabled and with_stallion and game.rng.randf() < STABLE_XP_CHANCE:
				game.add_xp(STABLE_XP)
				out.append("+%d XP" % STABLE_XP)
		"nursery":
			out.append_array(_grow_babies(b))
		"lambs":
			if game.has_inside(b, "ram") and game.drops_enabled and game.rng.randf() < LAMB_CHANCE:
				if game.place_somewhere("lamb"):
					game.message.emit("A lamb was born! Raise it in a Nursery Barn.")
					out.append("A lamb!")
		"truffles":
			if game.has_inside(b, "boar") and game.drops_enabled and game.rng.randf() < PIGLET_CHANCE:
				if game.place_somewhere("piglet"):
					game.message.emit("A piglet was born! Raise it in a Nursery Barn.")
					out.append("A piglet!")
		"beehive":
			if game.drops_enabled and game.rng.randf() < FERTILIZE_ALL_CHANCE:
				game.fertilize_alls += 1
				game.message.emit("The bees left a Fertilize All!")
				out.append("+1 Fertilize All")
		"saplings":
			var sapling := _roll_sapling(b)
			if sapling != "" and game.place_somewhere(sapling):
				game.message.emit("A rare sapling sprouted: %s!" % game.item_data(sapling)["name"])
				out.append("Rare sapling!")
	if not out.is_empty():
		game.inventory_changed.emit()
	return out


## Nursery Barn: each baby grows a day per collection; grown ones move out as adults.
func _grow_babies(nursery: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var it := game.item_data(nursery["id"])
	var grow_days := int(it.get("grow_days", 4))
	var into: Dictionary = it.get("grows_into", {})
	var still: Array = []
	var inside: Dictionary = nursery["inside"]
	for baby in nursery.get("growing", []):
		baby[1] = int(baby[1]) + 1
		if int(baby[1]) >= grow_days and game.place_somewhere(into.get(baby[0], baby[0])):
			inside[baby[0]] = int(inside.get(baby[0], 0)) - 1
			if int(inside[baby[0]]) <= 0:
				inside.erase(baby[0])
			game.add_xp(NURSERY_SPARE_XP)
			game.ribbons.bump("babies_raised", 1)
			var adult_name: String = game.item_data(into.get(baby[0], baby[0]))["name"]
			game.message.emit(
				"Your %s grew up into a %s!" % [game.item_data(baby[0])["name"].to_lower(), adult_name.to_lower()]
			)
			out.append("A %s grew up!" % adult_name.to_lower())
		else:
			still.append(baby)
	nursery["growing"] = still
	return out


## A rare sapling of one of the trees inside, likelier for the trees you have more of.
func _roll_sapling(orchard: Dictionary) -> String:
	if not game.drops_enabled or game.rng.randf() >= SAPLING_CHANCE:
		return ""
	var inside: Dictionary = orchard["inside"]
	var pool: Array[String] = []
	var weights: Array[int] = []
	var total := 0
	for id in inside:
		if game.item_data(id).has("rare_sapling") and int(inside[id]) > 0:
			pool.append(id)
			weights.append(int(inside[id]))
			total += int(inside[id])
	if total == 0:
		return ""
	var pick := game.rng.randi_range(1, total)
	for k in pool.size():
		pick -= weights[k]
		if pick <= 0:
			return game.item_data(pool[k])["rare_sapling"]
	return ""
