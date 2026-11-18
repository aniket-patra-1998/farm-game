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
		if not g.is_home(o):
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


func test_421_the_showcase_shows_each_system_at_its_best_and_its_looks_can_be_walked() -> void:
	var g := _farm()
	g.open_showcase()
	# Every system dresses its own part (GameSystem.showcase), so the showcase keeps up with the game.
	var dressed: Array[String] = []
	for system in g.systems:
		var own: Array = (system.get_script() as Script).get_script_method_list()
		if own.any(func(m: Dictionary) -> bool: return m["name"] == "showcase"):   # not-ui
			dressed.append(str((system.get_script() as Script).get_global_name()))
	for name: String in ["VipSystem", "RustSystem", "CraftingSystem"]:   # not-ui
		_check(dressed.has(name), "%s says what the showcase shows of it" % name)
	# The Barn is the hero at its best: whole, at the top VIP level, and VIP active.
	var barns := g.objects.filter(func(o: Dictionary) -> bool: return str(o["id"]) == "barn")
	_eq(barns.size(), 1, "the showcase has its Barn")
	_check(not bool(barns[0].get("broken", false)), "whole, not broken")
	_check(g.vip.active() and g.vip.level() == g.vip.max_level(), "VIP is at its top level and active")
	_eq(g.look_level(barns[0]), g.look_levels("barn"), "so the Barn wears its grandest look")
	# Vehicles at every stage of rust between them, some in the Garage and some left out.
	var rusts: Array = g.vehicles.owned_vehicles().map(func(id: String) -> int: return g.rust.level(id))
	_check(rusts.has(0) and rusts.has(g.rust.max_level()), "vehicles from clean to seized %s" % [rusts])
	var out := g.vehicles.owned_vehicles().filter(func(id: String) -> bool: return g.rust.stands_outside(id))
	_check(out.size() > 0 and out.size() < rusts.size(), "some left out on the farm, some in the Garage")
	# Crafting buildings at work, finished and idle.
	var states := {}
	for o in g.objects:
		if g.kind_of(o) == "crafting" and not g.under_construction(o):
			var slots: Array = o["slots"]
			states["idle" if slots.is_empty() else ("done" if int(slots[0]["done"]) <= g.now() else "working")] = true
	_eq(states.size(), 3, "crafting buildings show all three of their looks %s" % [states.keys()])
	# What stands at one size at a time is walked by hand.
	var bakery := g.objects.filter(func(o: Dictionary) -> bool: return str(o["id"]) == "bakery")[0] as Dictionary
	var top := g.max_level("bakery")
	ShowcaseFarm.step_sizes(g, -1)
	_eq(g.level_of(bakery), top - 1, "a step down: every building a size smaller")
	for step in top + 2:
		ShowcaseFarm.step_sizes(g, -1)
	_eq(g.level_of(bakery), 1, "never under its first size")
	for step in top + 2:
		ShowcaseFarm.step_sizes(g, 1)
	_eq(g.level_of(bakery), top, "and back up to its biggest, never past it")
	ShowcaseFarm.step_vip(g, -1)
	_eq(g.vip.level(), g.vip.max_level() - 1, "a VIP level down: the Barn's look before")
	for step in g.vip.max_level() + 2:
		ShowcaseFarm.step_vip(g, -1)
	_eq(g.vip.level(), 0, "down to no VIP at all")
	ShowcaseFarm.step_vip(g, 1)
	_eq(g.vip.level(), 1, "and up again")
	ShowcaseFarm.toggle_vip(g)
	_check(not g.vip.active(), "VIP lapses (the badge grey and still)")
	ShowcaseFarm.toggle_vip(g)
	_check(g.vip.active(), "and starts again")
	_done(g)


func test_454_a_farm_opened_in_place_is_covered_and_built_at_full_speed() -> void:
	var g := GameState.new()
	add_child(g)
	g.saving_enabled = false
	g.reset_game()
	var told := [0]
	g.farm_opened.connect(func() -> void: told[0] += 1)
	g.open_showcase()
	_eq(told[0], 1, "opening the showcase says a farm was opened in place (Main covers it)")
	g.open_own_farm()
	_eq(told[0], 2, "and so does going back to your own")
	g.free()
	var objects := Objects3D.new()
	add_child(objects)
	_eq(objects.call("_budget_ms"), Objects3D.OPENING_BUDGET_MS, "a farm first opening builds more a frame")
	LoadingCover.covering += 1
	_eq(objects.call("_budget_ms"), Objects3D.COVERED_BUDGET_MS, "and under the loading cover, at full speed")
	LoadingCover.covering -= 1
	objects.free()
