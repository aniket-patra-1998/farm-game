extends TestSuite
## The showcase farm (debug builds): everything on one farm, laid out tidily, for testing.

const ZONE_KINDS := ["building", "crafting", "barn", "vehicle", "tree", "animal", "decor"]


func test_106_the_showcase_farm_has_everything_laid_out() -> void:
	var g := _farm()
	var left_out := g.open_showcase()
	_eq(left_out.size(), 0, "everything fits on the farm %s" % [left_out])
	_check(g.in_showcase(), "it's the showcase, in its own save")
	_eq(g.farm_size, GameState.MAX_SIZE, "the farm is at its biggest")
	_eq(g.level(), ShowcaseFarm.top_level(g), "the player is past every unlock")
	for id in g.items:
		_check(int(g.items[id].get("unlock_level", 1)) <= g.level(), "%s is unlocked" % id)
	# One of everything that stands on a farm.
	var placed := {}
	for o in g.objects:
		placed[o["id"]] = int(placed.get(o["id"], 0)) + 1
	for id in g.items:
		if ZONE_KINDS.has(str(g.items[id].get("kind", ""))):
			# (A vehicle is on the farm or parked in the Garage, never both.)
			_check(placed.has(id) or g.buildings.owned(id) > 0, "%s is on the farm" % id)
			if id != ShowcaseFarm.SITE:  # (the showcase builds one building at three stages of construction)
				_check(g.buildings.owned(id) <= g.buildings.limit_of(id), "%s is within its limit" % id)
	# Nothing overlaps, and everything is on the farm.
	var covered := {}
	var overlaps := 0
	for o in g.objects:
		var fp := g.footprint(o["id"])
		for r in range(int(o["row"]), int(o["row"]) + fp.y):
			for c in range(int(o["col"]), int(o["col"]) + fp.x):
				_check(r < g.farm_size and c < g.farm_size, "%s stands on the farm" % o["id"])
				if covered.has(Vector2i(r, c)):
					overlaps += 1
				covered[Vector2i(r, c)] = true
	_eq(overlaps, 0, "nothing stands on anything else")
	# Buildings at their biggest, homes full; building sites part-built, at different stages.
	var sites: Array[float] = []
	var ready := 0
	for o in g.objects:
		if not g.is_building(o):
			continue
		if g.under_construction(o):
			sites.append(g.land.construction_progress(o))
			continue
		_eq(g.level_of(o), g.max_level(o["id"]), "%s is at its biggest" % o["id"])
		var def := g.catalog.get_def(o["id"]) as BuildingDef
		if not def.holds().is_empty() and not def.stores_anything():
			_check(g.inside_total(o) >= g.capacity(o) or o["id"] == "garage" or o["id"] == "beehive",
				"%s is full (%d of %d)" % [o["id"], g.inside_total(o), g.capacity(o)])
			if g.is_ready(o):
				ready += 1
	_eq(sites.size(), ShowcaseFarm.SITE_STAGES.size(), "a building is shown at each stage of construction")
	_check(sites.size() == 3 and sites[0] < sites[1] and sites[1] < sites[2], "further along each time %s" % [sites])
	_check(ready > 0, "homes are ready to collect from (%d)" % ready)
	# Every crop in the field, most ripe; a few withered and a few plowed.
	var phases := {}
	var crops_planted := {}
	for i in g.plots.size():
		phases[g.field.phase(i)] = int(phases.get(g.field.phase(i), 0)) + 1
		if g.field.crop_at(i) != "":
			crops_planted[g.field.crop_at(i)] = true
	_eq(crops_planted.size(), g.crops.size(), "every crop is planted")
	_check(int(phases.get(GameState.Phase.RIPE, 0)) > g.crops.size() / 2.0, "most are ripe to harvest")
	_check(int(phases.get(GameState.Phase.GROWING, 0)) > 0, "some are growing")
	_eq(int(phases.get(GameState.Phase.WITHERED, 0)), ShowcaseFarm.WITHERED_PLOTS, "a few have withered")
	_eq(int(phases.get(GameState.Phase.PLOWED, 0)), ShowcaseFarm.PLOWED_PLOTS, "a few are plowed for seed")
	# Back to your own farm, as it was.
	g.open_own_farm()
	_check(not g.in_showcase(), "and back to your own farm")
	_check(g.farm_size < GameState.MAX_SIZE, "which is the farm you had")
	_done(g)
