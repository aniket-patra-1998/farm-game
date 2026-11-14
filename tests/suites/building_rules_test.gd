extends TestSuite
## The rules every building answers to (Game.buildings): buying, limits, growing, selling, and buying
## missing materials with gems. Each refusal comes with its reason and a message.


func test_108_buying_a_building_says_yes_or_why_not() -> void:
	var g := _farm()
	g.coins = 1000000
	g.gems = 1000
	g.xp = g.xp_for_level(50)
	_clear(g)
	# Too early: its level.
	var low := _farm()
	_eq(low.buildings.can_buy("horse_stable").why, BuildingSystem.Why.LEVEL, "a level 1 farmer can't buy a Stable")
	_check(low.buildings.can_buy("horse_stable").text != "", "and is told why")
	# Too poor: coins.
	var poor := _farm()
	poor.xp = poor.xp_for_level(50)
	poor.coins = 10
	_eq(poor.buildings.can_buy("chicken_coop").why, BuildingSystem.Why.COINS, "not enough coins says so")
	# Two of a building per farm for now: a third is refused, with the limit on the button.
	_check(g.buildings.can_buy("chicken_coop").ok(), "the first Coop can be bought")
	_check(g.buy_and_place("chicken_coop", 0, 0), "and placed")
	_check(g.buy_and_place("chicken_coop", 0, 6), "a second too")
	var again := g.buildings.can_buy("chicken_coop")
	_eq(again.why, BuildingSystem.Why.LIMIT, "a third Coop is over the limit")
	_check(again.short.contains("2"), "the button says the limit (%s)" % again.short)
	var coins_before := g.coins
	_check(not g.buy_and_place("chicken_coop", 0, 12), "buying one anyway is refused")
	_eq(g.coins, coins_before, "and costs nothing")
	for k in 2:
		_check(g.buy_and_place("cow_shed", 4 + 4 * int(k / 3.0), 4 * (k % 3)), "Dairy Farm %d of 2" % (k + 1))
	_eq(g.buildings.owned("cow_shed"), 2, "two Dairy Farms")
	_eq(g.buildings.can_buy("cow_shed").why, BuildingSystem.Why.LIMIT, "a third is over the limit")
	# Other kinds have their own limits: one of each vehicle (on the farm or in a Garage), 99 living things.
	_eq(g.buildings.limit_of("tractor"), 1, "one of each vehicle")
	_eq(g.buildings.limit_of("hedge"), 999, "decorations")
	_eq(g.buildings.limit_of("chicken"), 99, "animals")
	_eq(g.buildings.limit_of("apple_tree"), 99, "trees")
	# Crafting buildings share a limit of three.
	for id in ["bakery", "winery", "spa"]:
		g.objects.append({"uid": g.next_uid, "id": id, "row": 20, "col": 0, "t": 0, "level": 1, "slots": []})
		g.next_uid += 1
	_eq(g.buildings.group_owned("crafting"), 3, "three crafting buildings")
	_check(not g.buildings.can_buy("bakery").ok(), "and no more")
	_done(low)
	_done(poor)
	_done(g)


func test_109_growing_a_building_and_buying_materials_with_gems() -> void:
	var g := _farm()
	g.xp = g.xp_for_level(50)
	g.coins = 1000000
	_clear(g)
	_check(g.buy_and_place("horse_stable", 0, 0), "a Stable frame is placed")
	var st: Dictionary = g.objects.back()
	_eq(g.buildings.can_expand(st).why, BuildingSystem.Why.FRAME, "a frame can't grow before it's built")
	# Finish it with materials bought with gems: exactly what's missing, a gem each.
	var need := g.land.construction_needs(st)
	var missing := 0
	for m in need:
		missing += int(need[m])
	g.gems = missing - 1
	_check(not g.buildings.buy_missing(need), "one gem short buys nothing")
	g.gems = missing
	_eq(g.buildings.gems_for(need), missing * Balance.i("buildings.material_gems"), "a gem a material")
	_check(g.buildings.buy_missing(need), "the missing materials are bought")
	_eq(g.gems, 0, "for exactly their price")
	_check(g.buildings.missing(need).is_empty(), "now nothing is missing")
	g.land.add_materials(int(st["uid"]))
	_check(not g.under_construction(st), "and the Stable is finished")
	# The next size: materials short, then bought, then grown; and at the biggest, no more.
	var short := g.buildings.can_expand(st)
	_eq(short.why, BuildingSystem.Why.MATERIALS, "growing needs its materials")
	_check(short.text != "", "and says which")
	while g.level_of(st) < g.max_level("horse_stable"):
		g.gems = 1000
		_check(g.buildings.buy_missing(g.land.expansion_needs(st)), "materials for size %d" % (g.level_of(st) + 1))
		_check(g.land.upgrade_building(int(st["uid"])), "grown to size %d" % (g.level_of(st) + 1))
	_eq(g.capacity(st), 40, "the biggest Stable holds 40")
	_eq(g.buildings.can_expand(st).why, BuildingSystem.Why.BIGGEST, "and grows no more")
	# FarmVille's Stable took 50 materials a size.
	var size_cost := 0
	var per_size := g.building_def("horse_stable").size_materials(2)
	for m in per_size:
		size_cost += int(per_size[m])
	_eq(size_cost, 50, "a Stable size takes 50 materials")
	_done(g)


func test_110_what_can_be_sold() -> void:
	var g := _farm()
	var barn := g.storage.barn()
	_eq(g.buildings.can_sell(barn).why, BuildingSystem.Why.KEPT, "the Barn stays")
	_check(not g.can_sell(barn), "so it can't be sold")
	g.xp = g.xp_for_level(50)
	g.coins = 100000
	g.farm_size = GameState.MAX_SIZE
	g.buy_and_place("chicken_coop", 14, 14)
	_check(g.can_sell(g.objects.back()), "a Coop can be sold")
	_done(g)


## A big, empty farm (no starter buildings or plots in the way).
func _clear(g: GameState) -> void:
	g.farm_size = GameState.MAX_SIZE
	g.objects.clear()
	for i in g.plots.size():
		g.plots[i] = {"state": "grass"}
	g.rebuild_occupancy()


func test_125_objects_join_and_leave_the_farm_only_through_game() -> void:
	var offenders: Array[String] = []
	for dir in ["res://scripts", "res://autoload"]:
		for path in _gd_files(dir):
			if path.ends_with("autoload/game.gd"):
				continue
			var text := FileAccess.get_file_as_string(path)
			for needle in ["objects.append(", "objects.erase(", "objects = "]:
				if text.contains("game." + needle) or text.contains("g." + needle):
					offenders.append("%s (%s)" % [path, needle])
	_eq(offenders, [] as Array[String], "add_object, remove_object or set_objects instead")


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(sub)))
	return out


func test_139_a_vehicle_is_on_the_farm_or_in_the_garage_never_both() -> void:
	var g := _farm()
	g.coins = 10000000
	g.xp = g.xp_for_level(60)
	g.farm_size = 24
	_clear(g)
	_check(g.buy_and_place("garage", 8, 8), "a Garage")
	var garage := g.object_at(g.index_of(8, 8))
	_all_materials(g, 100)
	if g.under_construction(garage):
		g.land.add_materials(int(garage["uid"]))
	_check(g.buy_and_place("tractor", 2, 2), "a tractor standing on the farm")
	_eq(g.buildings.owned("tractor"), 1, "is the one tractor")
	_check(not g.homes.put_in_home(int(garage["uid"]), "tractor", {"buy": true}),
		"a second can't be bought into the Garage")
	_eq(g.buildings.can_buy("tractor").why, BuildingSystem.Why.LIMIT, "and the Market says it is at its limit")
	# Parking the one on the farm moves it: still one.
	var loose := g.object_at(g.index_of(2, 2))
	_check(g.homes.put_in_home(int(garage["uid"]), "tractor", {"uid": int(loose["uid"])}), "parked in the Garage")
	_eq(g.buildings.owned("tractor"), 1, "still one tractor")
	# An old save with both: one is kept, and its price comes back.
	g.add_object({"uid": g.next_uid, "id": "tractor", "row": 2, "col": 2, "t": 0})
	g.next_uid += 1
	_eq(g.buildings.owned("tractor"), 2, "an old save held two")
	var coins := g.coins
	_eq(g.buildings.trim_extra_vehicles(), 1, "one is taken away")
	_eq(g.buildings.owned("tractor"), 1, "leaving one")
	_check(int((garage["inside"] as Dictionary).get("tractor", 0)) == 1, "the one in the Garage is the one kept")
	_check(g.coins > coins, "the price is given back")


func test_140_every_kind_has_its_limit_and_it_counts_what_is_inside_and_put_away() -> void:
	var g := _farm()
	g.coins = 100000000
	g.xp = g.xp_for_level(60)
	g.farm_size = 24
	_clear(g)
	# Animals: 99. Some standing on the farm, some inside a home, some in the Barn all count.
	_check(g.buy_and_place("chicken_coop", 0, 0), "a Coop")
	var coop := g.object_at(g.index_of(0, 0))
	g.objects.append({"uid": g.next_uid, "id": "chicken", "row": 10, "col": 10, "t": 0})
	g.next_uid += 1
	(coop.get_or_add("inside", {}) as Dictionary)["chicken"] = 40
	for k in 58:
		g.storage.stored.append({"uid": 8000 + k, "id": "chicken", "t": 0})
	_eq(g.buildings.owned("chicken"), 99, "1 standing + 40 inside + 58 put away")
	_eq(g.buildings.can_buy("chicken").why, BuildingSystem.Why.LIMIT, "the 100th chicken is refused")
	_check(g.buildings.can_buy("chicken").short.contains("99"), "with the limit shown")
	_check(not g.place_somewhere("chicken"), "and a gift or drop can't add one either")
	g.storage.stored.pop_back()
	_check(g.buildings.can_buy("chicken").ok(), "one fewer and it can be bought again")
	# Trees and blooms are living things too.
	_eq(g.buildings.limit_of("apple_tree"), 99, "trees")
	# Decorations: 999.
	_eq(g.buildings.limit_of("hedge"), 999, "decorations")
	for k in 998:
		g.objects.append({"uid": g.next_uid, "id": "hedge", "row": 0, "col": 0, "t": 0})
		g.next_uid += 1
	_check(g.buildings.can_buy("hedge").ok(), "the 999th hedge can be bought")
	g.objects.append({"uid": g.next_uid, "id": "hedge", "row": 0, "col": 0, "t": 0})
	g.next_uid += 1
	_eq(g.buildings.can_buy("hedge").why, BuildingSystem.Why.LIMIT, "the 1000th is refused")
	# A vehicle put away in the Barn is still the one vehicle.
	g.storage.stored.append({"uid": 8500, "id": "tractor", "t": 0})
	_eq(g.buildings.can_buy("tractor").why, BuildingSystem.Why.LIMIT, "a stored tractor means no second one")
	# Buildings: two, and frames count.
	_check(g.buy_and_place("cow_shed", 4, 0), "a first Dairy Farm")
	_check(g.buy_and_place("cow_shed", 4, 6), "a second")
	_eq(g.buildings.can_buy("cow_shed").why, BuildingSystem.Why.LIMIT, "a third is refused")
	_check(not g.buy_and_place("cow_shed", 4, 12), "and not placed")


## Placing, moving in, storing and finishing answer through Game.buildings too: yes, or no with its reason
## and a message, one test per reason.
func test_319_place_move_in_store_and_finish_say_yes_or_why_not() -> void:
	var g := _farm()
	g.coins = 10000000
	g.gems = 1000
	g.xp = g.xp_for_level(60)
	_clear(g)
	var B := BuildingSystem.Why
	# Placing.
	_check(g.buildings.can_place("chicken_coop", 2, 2).ok(), "an empty grassy spot takes a Coop")
	_eq(g.buildings.can_place("chicken_coop", -1, 0).why, B.OFF_FARM, "off the edge")
	_eq(g.buildings.can_place("chicken_coop", g.farm_size - 1, 0).why, B.OFF_FARM, "hanging past the edge")
	_check(g.buy_and_place("chicken_coop", 2, 2), "a Coop goes down")
	var taken := g.buildings.can_place("cow_shed", 2, 2)
	_eq(taken.why, B.TAKEN, "a spot with something on it")
	_check(taken.text.contains(str(g.item_data("chicken_coop")["name"])), "names what is there: %s" % taken.text)
	g.plots[g.index_of(16, 2)] = {"state": "planted", "crop": "strawberries", "t": g.now()}
	_eq(g.buildings.can_place("hay_bale", 16, 2).why, B.PLANTED, "on crops")
	_eq(g.buildings.can_place("apple_tree", 2, 2 + g.footprint("chicken_coop").x).why, B.CROWDED,
		"a tree hard against a building")
	_check(g.buildings.can_place("apple_tree", 2, 2 + g.footprint("chicken_coop").x, -1, false).ok(),
		"not strict (laying a saved farm back down) lets it be")
	_check(g.can_place("chicken_coop", 14, 2) == g.buildings.can_place("chicken_coop", 14, 2).ok(),
		"Game.can_place asks the same rule")
	# Moving in.
	var coop := g.object_at(g.index_of(2, 2))
	_check(g.buildings.can_move_in(coop, "chicken").ok(), "a chicken can move into the Coop")
	var wrong := g.buildings.can_move_in(coop, "cow")
	_eq(wrong.why, B.WRONG_KIND, "a cow can't")
	_check(wrong.text != "", "and is told why")
	coop["inside"] = {"chicken": g.capacity(coop)}
	_eq(g.buildings.can_move_in(coop, "chicken").why, B.FULL, "a full Coop")
	_check(g.buy_and_place("pig_pen", 10, 10), "a Pig Pen frame goes down")
	var pen := g.object_at(g.index_of(10, 10))
	_eq(g.buildings.can_move_in(pen, "pig").why, B.NOT_BUILT, "a frame takes no one")
	# Finishing.
	_eq(g.buildings.can_finish(coop).why, B.NOT_A_FRAME, "a finished building is no frame")
	var short := g.buildings.can_finish(pen)
	_eq(short.why, B.MATERIALS, "a frame without its materials")
	_check(short.text != "", "says what is still needed: %s" % short.text)
	for m in g.land.construction_needs(pen):
		g.parts[m] = int(g.land.construction_needs(pen)[m])
	_check(g.buildings.can_finish(pen).ok(), "with every material in hand it can be finished")
	# Storing.
	_check(g.buy_and_place("hay_bale", 18, 18), "a hay bale")
	var bale := g.object_at(g.index_of(18, 18))
	_eq(g.buildings.can_store(coop).why, B.CANT_STORE, "a building can't go in the Barn")
	g.add_object({"uid": g.next_uid, "id": "barn", "row": 14, "col": 14, "t": g.now(), "broken": true,
		"level": 1, "inside": {}})
	g.next_uid += 1
	var barn := g.storage.barn()
	_check(not barn.is_empty(), "the starter Barn, broken")
	_eq(g.buildings.can_store(bale).why, B.BARN_BROKEN, "a broken Barn stores nothing")
	barn.erase("broken")
	_check(g.buildings.can_store(bale).ok(), "a repaired Barn takes the bale")
	for k in g.storage.total_limit():
		g.storage.stored.append({"id": "hay_bale", "uid": 90000 + k})
	_eq(g.buildings.can_store(bale).why, B.FULL, "a full Barn")
	_check(not g.storage.store_object(int(bale["uid"])), "and storing anyway is refused")
	g.queue_free()
