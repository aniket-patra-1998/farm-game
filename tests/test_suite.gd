class_name TestSuite
extends Node
## A group of rule tests. Each test_ method builds its own throwaway farm with saving turned off;
## the helpers below check results and record failures for tests/test_runner.gd to report.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var checks := 0
var failures: Array[String] = []
var current := ""


func _check(condition: bool, what: String) -> void:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [current, what])






func _eq(actual: Variant, expected: Variant, what: String) -> void:
	_check(actual == expected, "%s (expected %s, got %s)" % [what, str(expected), str(actual)])






## A fresh farm: saving off, drops off, fixed random seed.
func _farm(drops := false) -> GameState:
	var g := GameState.new()
	g.saving_enabled = false
	add_child(g)
	g.drops_enabled = drops
	g.rng.seed = 12345
	g.feeds.active = false   # exact payouts: feeding tests turn it on
	return g






func _done(g: GameState) -> void:
	g.queue_free()






## A tile that is open grass on a new farm (the farmhouse and barn sit along the back edge).
func _free(g: GameState) -> int:
	return g.index_of(11, 11)






func _skip(g: GameState, seconds: int) -> void:
	g.debug_time_offset += seconds






## Plows (if needed), plants and fast-forwards one crop to ripe, then harvests it.
func _grow_and_harvest(g: GameState, i: int, crop_id: String) -> Dictionary:
	if g.field.phase(i) != GameState.Phase.PLOWED:
		g.field.plow(i)
	g.field.plant(i, crop_id)
	_skip(g, int(g.crops[crop_id]["grow_seconds"]))
	return g.field.harvest(i)






func _all_materials(g: GameState, n: int) -> void:
	for m in GameState.part_ids:
		g.parts[m] = n






func _count(g: GameState, item_id: String) -> int:
	var n := 0
	for o in g.objects:
		if o["id"] == item_id and not o.get("stray", false):
			n += 1
	return n


## How many of `item_id` have arrived new (born, won, traded): in the Barn or waiting in the inbox.
func _arrived(g: GameState, item_id: String) -> int:
	var n := 0
	for kept: Dictionary in g.storage.stored:
		if str(kept["id"]) == item_id:
			n += 1
	for m: Dictionary in g.social.inbox:
		if str((m["give"] as Dictionary).get("id", "")) == item_id:
			n += int((m["give"] as Dictionary).get("n", 1))
	return n


## Every Mystery young `young_id` that has arrived, wherever it is (the farm, the Barn, the inbox), each as a
## dictionary with its own fields ("becomes", "fed").
func _young_all(g: GameState, young_id: String) -> Array:
	var out: Array = []
	for o: Dictionary in g.objects + g.storage.stored:
		if str(o["id"]) == young_id:
			out.append(o)
	for m: Dictionary in g.social.inbox:
		var give: Dictionary = m["give"]
		if str(give.get("id", "")) == young_id and give.has("keep"):
			out.append(give["keep"])
	return out


## A found Mystery young, placed from the Barn the way the player would (it arrives there: BarnStorage.welcome).
func _find_young(g: GameState, young_id: String, becomes: String) -> bool:
	if not g.nurture._found(young_id, becomes):
		return false
	if not g.storage.barn_repaired():   # (the Barn broken: it waited in the inbox; claimed into the Barn)
		g.social.claim(int(g.social.inbox.back()["id"]))
	var at := g.storage.stored.size() - 1
	var spot := g.free_spot_for(young_id)
	return spot.x >= 0 and g.storage.place_from_storage(at, spot.x, spot.y)






## A Bakery (or another crafting building) bought and placed at 8,8; returns its uid.
func _crafting_building(g: GameState, id := "bakery") -> int:
	g.coins = 10000000
	g.xp = g.xp_for_level(25)
	g.objects = g.objects.filter(func(o): return g.kind_of(o) != "animal") # starter animals wander anywhere
	g.rebuild_occupancy()
	_check(g.buy_and_place(id, 8, 8), "%s placed" % id)
	return int(g.object_at(g.index_of(8, 8))["uid"])






## A plot away from the crafting building at 8,8.
func _open_plot(g: GameState) -> int:
	for r in range(2, 8):
		for c in range(1, 8):
			var i := g.index_of(r, c)
			if not g.is_occupied(i):
				return i
	return g.index_of(7, 7)




