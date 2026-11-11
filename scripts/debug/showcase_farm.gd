class_name ShowcaseFarm
extends RefCounted
## A farm with everything in it, for testing and checking the art (debug builds only; see GameState
## open_showcase). The farm at its biggest, the player at a level past every unlock, plenty of coins,
## gems, materials and tools, and laid out in tidy zones, each starting on a new row with a lane before it:
##
##   buildings     every building at its biggest size, homes full of the animals they take (most of them
##                 ready to collect, some part-way), an orchard of trees, a beehive of bees, a garage of
##                 vehicles; and building sites of one building at three stages of construction
##   vehicles      one of each
##   trees         one of each kind, fruiting
##   animals       one of each, in rows by kind
##   decorations   one of each
##   crops         across the bottom rows: every crop, most ripe, some growing, with a few plots withered
##                 and a few plowed and waiting for seed
##
## It's built in its own save (SAVE_PATH), so the player's own farm is never touched.

const SAVE_PATH := "user://showcase.json"
const CROP_ROWS := 3             # rows of plots across the bottom of the farm
const LANE := 1                  # rows left empty between zones
const LEVEL_PAST_UNLOCKS := 5    # the player's level, past the highest unlock level
const COINS := 5000000
const GEMS := 50000
const STOCK := 99                # of each building material, and of each tool
const SITE := "pig_pen"          # the building shown under construction
const SITE_STAGES: Array[float] = [0.15, 0.5, 0.85]
const READY_EVERY := 3           # of homes and trees and animals, all but every third are ready to collect
const PART_WAY := 0.6            # and those are this far through their cycle
const WITHERED_PLOTS := 4
const PLOWED_PLOTS := 6
## Kinds that stand on the farm, in the order their zones are laid out (buildings first, decorations last).
const ZONES: Array[String] = ["building", "vehicle", "tree", "animal", "decor"]
const BUILDING_KINDS: Array[String] = ["building", "crafting", "barn"]


## Builds the showcase into `g` (which is reset first). Returns what was left out for want of room (ids;
## empty when everything fits, which a test checks).
static func build(g: GameState) -> Array[String]:
	g.reset_game()
	var now := g.now()
	g.objects.clear()
	for i in g.plots.size():
		g.plots[i] = {"state": "grass"}
	g.rebuild_occupancy()
	g.farm_size = GameState.MAX_SIZE
	g.xp = g.xp_for_level(top_level(g))
	g.coins = COINS
	g.gems = GEMS
	g.tutorial_step = GameState.Tutorial.DONE
	for p in g.part_ids:
		g.parts[p] = STOCK
	g.unwithers = STOCK
	g.fertilize_alls = STOCK
	g.farmhands = STOCK
	g.arborists = STOCK
	g.fertilizer_bags = STOCK
	var left_out: Array[String] = []
	var cursor := Vector2i.ZERO   # (row, col) where the next thing goes
	var shelf := 0                # how deep the row being filled is
	var last_row := GameState.MAX_SIZE - CROP_ROWS - LANE  # objects stay above the crop field
	for zone in ZONES:
		if cursor.y > 0:
			cursor = Vector2i(cursor.x + shelf + LANE, 0)
			shelf = 0
		for id in _zone_items(g, zone):
			var fp := g.footprint(id)
			if cursor.y + fp.x > g.farm_size:
				cursor = Vector2i(cursor.x + shelf, 0)
				shelf = 0
			if cursor.x + fp.y > last_row or not g.can_place(id, cursor.x, cursor.y):
				left_out.append(id)
				continue
			_place(g, id, cursor.x, cursor.y, now)
			cursor.y += fp.x
			shelf = maxi(shelf, fp.y)
	_fill_homes(g, now)
	_raise_young(g)
	_plant_field(g, now)
	g.rebuild_occupancy()
	announce(g)
	return left_out


## Every mystery young half grown, set to grow into its kind's first item, with supplies to finish it.
static func _raise_young(g: GameState) -> void:
	for s in NurtureSystem.SUPPLIES:
		g.nurture.supplies[s] = STOCK
	for o in g.objects:
		if g.nurture.is_young(o):
			o["fed"] = g.nurture.needs(o) / 2
			o["becomes"] = g.nurture.first_of(g.nurture.def_of(o).grows())


## A level past every unlock, so nothing in the Market is locked.
static func top_level(g: GameState) -> int:
	var most := 1
	for id in g.items:
		most = maxi(most, int(g.items[id].get("unlock_level", 1)))
	for id in g.crops:
		most = maxi(most, int(g.crops[id].get("unlock_level", 1)))
	return most + LEVEL_PAST_UNLOCKS


## What goes in a zone, in the order it's laid out: buildings biggest first (then the building sites),
## animals and trees by family so kinds stand together, decorations biggest first.
static func _zone_items(g: GameState, zone: String) -> Array[String]:
	var out: Array[String] = []
	for id in g.item_order:
		var kind := str(g.items[id].get("kind", ""))
		# Mystery young are small: they stand with the decorations.
		if kind == zone or zone == "building" and BUILDING_KINDS.has(kind) or zone == "decor" and kind == "young":
			out.append(id)
	if zone == "building" or zone == "decor":
		out.sort_custom(func(a: String, b: String) -> bool:
			var fa := g.footprint(a)
			var fb := g.footprint(b)
			return fa.y > fb.y or fa.y == fb.y and fa.x > fb.x)
	if zone == "building":
		for k in SITE_STAGES.size():
			out.append(SITE)
	if zone == "animal" or zone == "tree":
		out.sort_custom(func(a: String, b: String) -> bool:
			var fa := str(g.items[a].get("family", ""))
			var fb := str(g.items[b].get("family", ""))
			return fa < fb or fa == fb and a < b)
	return out


## One thing, finished and at its biggest; a building site for each extra SITE.
static func _place(g: GameState, id: String, row: int, col: int, now: int) -> void:
	var it := g.item_data(id)
	var kind := str(it.get("kind", ""))
	var obj := {"uid": g.next_uid, "id": id, "row": row, "col": col, "t": now}
	g.next_uid += 1
	if kind == "crafting":
		obj["slots"] = []
	if BUILDING_KINDS.has(kind):
		obj["level"] = g.max_level(id)
		obj["inside"] = {}
		var sites := g.objects.filter(func(o: Dictionary) -> bool: return o["id"] == SITE).size()
		if id == SITE and sites > 0 and sites <= SITE_STAGES.size():
			obj["level"] = 1
			obj["construction"] = _materials_for(it, SITE_STAGES[sites - 1])
	g.objects.append(obj)
	g.rebuild_occupancy()


## The share `share` of a building's materials, as if they'd been put in.
static func _materials_for(it: Dictionary, share: float) -> Dictionary:
	var need: Dictionary = it.get("build_materials", {})
	var have := {}
	for m in need:
		have[m] = int(floor(int(need[m]) * share))
	return have


## Every home filled with what it takes (round the kinds in turn, so a home of many kinds holds some of
## each); then the clocks set so most things are ready to collect and the rest are part-way.
static func _fill_homes(g: GameState, now: int) -> void:
	var k := 0
	for b in g.objects:
		if g.is_building(b) and not g.under_construction(b):
			var def := g.catalog.get_def(str(b["id"])) as BuildingDef
			if def != null and not def.stores_anything():
				var takes: Array[String] = []
				for id in g.item_order:
					if g.building_accepts(b, id):
						takes.append(id)
				var added := true
				while added:
					added = false
					for id in takes:
						if g.homes.fit(b, id) == HousingSystem.Fit.FITS:
							g.homes.house(b, id)
							added = true
		var cycle := g.cycle_of(b)
		if cycle > 0 and not g.under_construction(b):
			b["t"] = now - (cycle + 1 if k % READY_EVERY != READY_EVERY - 1 else int(cycle * PART_WAY))
		k += 1


## The crop field across the bottom: every crop in a row, most ripe and a few at each stage of growing;
## then a few withered plots (to try Unwither on) and a few plowed ones (to plant).
static func _plant_field(g: GameState, now: int) -> void:
	var first_row := GameState.MAX_SIZE - CROP_ROWS
	var spots: Array[int] = []
	for r in range(first_row, GameState.MAX_SIZE):
		for c in GameState.MAX_SIZE:
			spots.append(g.index_of(r, c))
	var k := 0
	for crop_id in g.crop_order:
		if k >= spots.size():
			break
		var grow := int(g.crops[crop_id]["grow_seconds"])
		# Every fifth is still growing (at a different stage each time round); the rest are ripe.
		var age := grow + 1 if k % 5 != 4 else int(grow * (0.15 + 0.2 * (int(k / 5.0) % 4)))
		g.plots[spots[k]] = {"state": "planted", "crop": crop_id, "planted_at": now - age}
		k += 1
	for w in WITHERED_PLOTS:
		if k >= spots.size():
			break
		var crop_id := g.crop_order[w]
		var crop: Dictionary = g.crops[crop_id]
		var long_ago := int(crop["grow_seconds"]) + g.ripe_window(crop) + 60
		g.plots[spots[k]] = {"state": "planted", "crop": crop_id, "planted_at": now - long_ago}
		k += 1
	for p in PLOWED_PLOTS:
		if k >= spots.size():
			break
		g.plots[spots[k]] = {"state": "plowed"}
		k += 1


## Tells everything showing the farm that it's a different farm now.
static func announce(g: GameState) -> void:
	g.coins_changed.emit(g.coins)
	g.gems_changed.emit(g.gems)
	g.xp_changed.emit(g.xp, g.level())
	g.tutorial_changed.emit(g.tutorial_step)
	g.collections_changed.emit()
	g.ribbons_changed.emit()
	g.inventory_changed.emit()
	g.farm_expanded.emit(g.farm_size)
	g.objects_changed.emit()
	g.plot_changed.emit(-1)
