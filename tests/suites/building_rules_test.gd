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
	# One Chicken Coop per farm, as in FarmVille: a second is refused, with the limit on the button.
	_check(g.buildings.can_buy("chicken_coop").ok(), "the first Coop can be bought")
	_check(g.buy_and_place("chicken_coop", 0, 0), "and placed")
	var again := g.buildings.can_buy("chicken_coop")
	_eq(again.why, BuildingSystem.Why.LIMIT, "a second Coop is over the limit")
	_check(again.short.contains("1"), "the button says the limit (%s)" % again.short)
	var coins_before := g.coins
	_check(not g.buy_and_place("chicken_coop", 0, 6), "buying one anyway is refused")
	_eq(g.coins, coins_before, "and costs nothing")
	# Up to five Dairy Farms.
	for k in 5:
		_check(g.buy_and_place("cow_shed", 4 + 4 * int(k / 3.0), 4 * (k % 3)), "Dairy Farm %d of 5" % (k + 1))
	_eq(g.buildings.owned("cow_shed"), 5, "five Dairy Farms")
	_eq(g.buildings.can_buy("cow_shed").why, BuildingSystem.Why.LIMIT, "a sixth is over the limit")
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
	_eq(g.buildings.gems_for(need), missing * BuildingSystem.MATERIAL_GEMS, "a gem a material")
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
