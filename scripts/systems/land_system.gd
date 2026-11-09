class_name LandSystem
extends GameSystem
## Construction with building materials, building upgrades, and land expansion.
## Part of the game state: reached as `Game.land`; shared state is on `game`.

var expansion_steps: Array = []    # from data/expansions.json


func _init(owner: GameState) -> void:
	super(owner)


func load_data() -> void:
	expansion_steps = game.read_json("res://data/expansions.json").get("steps", [])


## Materials still needed to finish a frame: {material: count}. Empty when done.
func construction_needs(b: Dictionary) -> Dictionary:
	if not game.under_construction(b):
		return {}
	var need: Dictionary = game.item_data(b["id"]).get("build_materials", {})
	var have: Dictionary = b["construction"]
	var left := {}
	for m in need:
		var short := int(need[m]) - int(have.get(m, 0))
		if short > 0:
			left[m] = short
	return left


## Puts held materials into a frame. Finishes the building when nothing is missing.
func add_materials(uid: int) -> int:
	var b := game.object_by_uid(uid)
	if b.is_empty() or not game.under_construction(b):
		return 0
	var left := construction_needs(b)
	var added := 0
	var have: Dictionary = b["construction"]
	for m in left:
		var give := mini(int(left[m]), int(game.parts.get(m, 0)))
		if give > 0:
			game.parts[m] = int(game.parts[m]) - give
			have[m] = int(have.get(m, 0)) + give
			added += give
	if added == 0:
		game.message.emit("No materials to add yet. They turn up while harvesting and as daily gifts.")
		return 0
	if construction_needs(b).is_empty():
		b.erase("construction")
		b["t"] = game.now()
		var done_it := game.item_data(b["id"])
		if done_it["kind"] == "vehicle":
			game.message.emit("%s built! Pick it in the toolbar, then tap the field." % done_it["name"])
		elif done_it.get("special", "") == "garage":
			game.message.emit("Garage finished! Park vehicles inside and upgrade them with Vehicle Parts.")
		else:
			game.message.emit("%s finished! Open it to move animals in." % done_it["name"])
		if done_it.has("build_xp"):
			game.add_xp(int(done_it["build_xp"]))
		game.ribbons.bump("buildings_built", 1)
		game.building_upgraded.emit(uid, 1)
	else:
		game.message.emit("Added %d materials to the %s" % [added, game.item_data(b["id"])["name"]])
	game.inventory_changed.emit()
	game.objects_updated()
	return added


## Materials for the next expansion, or {} at full size.
func expansion_needs(b: Dictionary) -> Dictionary:
	if game.level_of(b) >= game.max_level(b["id"]):
		return {}
	return game.item_data(b["id"]).get("expand_materials", {})


func can_expand(b: Dictionary) -> bool:
	var need := expansion_needs(b)
	if need.is_empty() or game.under_construction(b):
		return false
	for m in need:
		if int(game.parts.get(m, 0)) < int(need[m]):
			return false
	return true


## Expands a building one size, paying its materials (FarmVille's Big and Huge sizes).
func upgrade_building(uid: int) -> bool:
	var b := game.object_by_uid(uid)
	if b.is_empty() or not game.is_building(b) or not can_expand(b):
		return false
	var need := expansion_needs(b)
	for m in need:
		game.parts[m] = int(game.parts[m]) - int(need[m])
	b["level"] = game.level_of(b) + 1
	game.message.emit("%s now holds %d!" % [game.size_name(b), game.capacity(b)])
	game.ribbons.bump("upgrades", 1)
	game.building_upgraded.emit(uid, game.level_of(b))
	game.inventory_changed.emit()
	game.objects_updated()
	return true


## The next expansion step, or {} when the farm is at full size.
func next_expansion() -> Dictionary:
	for step in expansion_steps:
		if int(step["size"]) > game.farm_size:
			return step
	return {}


func can_expand_with_coins() -> bool:
	var step := next_expansion()
	return not step.is_empty() and game.level() >= int(step["level"]) and game.coins >= int(step["coins"])


## Coins need the step's level; gems skip the level requirement.
func expand(use_gems: bool) -> bool:
	var step := next_expansion()
	if step.is_empty():
		return false
	if use_gems:
		if not game.spend_gems(int(step["gems"])):
			game.message.emit("Not enough gems to expand")
			return false
	else:
		if game.level() < int(step["level"]):
			game.message.emit("Reach level %d to expand with coins" % int(step["level"]))
			return false
		if not game.spend(int(step["coins"])):
			game.message.emit("Not enough coins to expand")
			return false
	game.farm_size = int(step["size"])
	game.message.emit("Your farm grew to %d x %d!" % [game.farm_size, game.farm_size])
	game.ribbons.bump("expansions", 1)
	game.farm_expanded.emit(game.farm_size)
	game.plot_changed.emit(-1)
	game.queue_save()
	return true
