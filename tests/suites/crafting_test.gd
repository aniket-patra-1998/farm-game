extends TestSuite
## Crafting: bushels, recipes, mastery, goods and the Farmers Market.


func test_79_crafting_recipes_match_farmville() -> void:
	var g := _farm()
	for b in ["bakery", "winery", "spa"]:
		var rs := g.crafting.recipes_of(b)
		_eq(rs.size(), 15, "%s has 15 recipes" % b)
		for star in range(1, 6):
			_eq(rs.filter(func(r): return r.star() == star).size(), 3, "%s: 3 recipes at %d stars" % [b, star])
	_eq(
		_ints((g.catalog.get_def("pumpkin_bread") as RecipeDef).inputs()),
		{"pumpkins": 4, "wheat": 4},
		"Pumpkin Bread: 4 pumpkins, 4 wheat"
	)
	_eq(
		_ints((g.catalog.get_def("red_table_wine") as RecipeDef).inputs()),
		{"grapes": 2, "white_grapes": 5},
		"Red Table Wine: 2 grapes, 5 white grapes"
	)
	_eq(
		_ints((g.catalog.get_def("floral_perfume") as RecipeDef).inputs()),
		{"blueberries": 4, "morning_glory": 4},
		"Floral Perfume: 4 blueberries, 4 morning glory"
	)
	_check(
		g.crops.has("aloe_vera") and g.crops.has("pattypan_squash") and g.crops.has("pink_roses"),
		"the crops recipes need are in the game"
	)
	var bakery := g.catalog.get_def("bakery") as CraftingDef
	_eq(bakery.unlock_level, 25, "crafting unlocks at level 25, as in FarmVille")
	_eq(
		bakery.star_cost(1),
		{"coins": 50000, "recipe_stars": 6, "gems": 15},
		"2 stars: 50,000 coins and 6 recipe stars, or 15 gems"
	)
	_eq(
		bakery.star_cost(4),
		{"coins": 1000000, "recipe_stars": 36, "gems": 60},
		"5 stars: 1,000,000 coins and 36 recipe stars, or 60 gems"
	)
	_eq(bakery.star_cost(5), {}, "5 stars is the top")
	_check(not g.items.has("pumpkin_bread"), "recipes aren't placeable items")
	_done(g)






func test_80_first_crafting_building_is_coins_the_rest_gems() -> void:
	var g := _farm()
	_eq(g.crafting.crafting_price("bakery"), {"coins": 100000}, "the first costs coins")
	var uid := _crafting_building(g)
	_check(g.crafting.is_crafting(g.object_by_uid(uid)), "it's a crafting building")
	_eq(g.crafting.free_slots(g.object_by_uid(uid)), 1, "one slot at 1 star")
	_eq(g.crafting.crafting_price("winery"), {"gems": 80}, "the next costs 80 gems")
	g.gems = 10
	_check(not g.can_afford_item("winery"), "can't afford it without the gems")
	_done(g)






func _ints(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(d[k])
	return out






func test_81_bushels_craft_goods_sell_and_fuel() -> void:
	var g := _farm(true)
	g.coins = 100000
	g.objects = g.objects.filter(func(o): return g.kind_of(o) != "animal")
	g.rebuild_occupancy()
	# No crafting building: no bushels.
	for k in 30:
		var r := _grow_and_harvest(g, _open_plot(g), "strawberries")
		_eq(r.get("bushel", ""), "", "no bushels before crafting")
		if r.get("bushel", "") != "":
			break
	var uid := _crafting_building(g)
	var got := 0
	for k in 60:
		if _grow_and_harvest(g, _open_plot(g), "wheat").get("bushel", "") == "wheat":
			got += 1
	_check(got > 0, "harvests drop bushels of their crop (%d in 60)" % got)
	_eq(int(g.crafting.bushels.get("wheat", 0)), got, "bushels are kept")
	# Craft Pumpkin Bread.
	g.crafting.bushels = {"pumpkins": 4, "wheat": 5}
	_eq(g.crafting.craft_problem(uid, "pumpkin_bread"), "", "ready to bake")
	_eq(g.crafting.craft_problem(uid, "pattypan_tart"), "Unlocks at 2 stars", "2-star recipes are locked")
	_check(g.crafting.start_craft(uid, "pumpkin_bread"), "baking")
	_eq(g.crafting.bushels, {"wheat": 1}, "bushels used")
	_eq(g.crafting.craft_problem(uid, "strawberry_shortcake"), "Every slot is busy", "one slot at 1 star")
	_eq(g.crafting.finish_crafts(uid), 0, "not done yet")
	_skip(g, 6 * 3600)
	_eq(g.crafting.finish_crafts(uid), 1, "done after 6 hours")
	_eq(int(g.crafting.goods["pumpkin_bread"]), 1, "a loaf of pumpkin bread")
	_eq(g.ribbons.stat("crafted"), 1, "counted for the Crafty ribbon")
	var price := g.crafting.good_price("pumpkin_bread")
	_check(
		price > 4 * int(g.crops["pumpkins"]["sell_price"]) + 4 * int(g.crops["wheat"]["sell_price"]),
		"goods sell for more than their bushels (%d)" % price
	)
	var coins := g.coins
	_eq(g.crafting.sell_good("pumpkin_bread"), price, "sold")
	_eq(g.coins, coins + price, "for coins")
	_check(not g.crafting.goods.has("pumpkin_bread"), "gone once sold")
	# Use a good for fuel.
	g.crafting.goods["pumpkin_bread"] = 1
	g.vehicles.fuel_unlocked = true
	g.vehicles.fuel = VehicleSystem.FUEL_TANK - 5
	g.vehicles.fuel_tanks = 0
	_eq(g.crafting.use_good("pumpkin_bread"), RecipeDef.FUEL_BASE, "a good gives fuel")
	_eq(g.vehicles.fuel_tanks, 1, "fuel past a full tank fills a spare tank")
	# Buy the missing bushels with gems.
	g.crafting.bushels = {}
	g.gems = 100
	_check(g.crafting.buy_missing_and_craft(uid, "strawberry_shortcake"), "bought 8 bushels and started")
	_eq(g.gems, 100 - 8 * CraftingSystem.BUSHEL_GEM_COST, "1 gem a bushel")
	_done(g)






func test_82_stars_mastery_and_the_farmers_market() -> void:
	var g := _farm()
	var uid := _crafting_building(g, "winery")
	var o := g.object_by_uid(uid)
	_check(not g.crafting.can_add_star(uid, false), "no recipe stars yet")
	g.crafting.crafted = {"red_table_wine": 15, "sweet_saki": 15, "white_sangria": 5}
	_eq(g.crafting.recipe_stars("red_table_wine"), 2, "15 crafts: 2 mastery stars")
	_eq(g.crafting.building_recipe_stars("winery"), 5, "5 stars across the Winery's recipes")
	_check(not g.crafting.can_add_star(uid, false), "6 are needed")
	g.crafting.crafted["white_sangria"] = 15
	_check(g.crafting.can_add_star(uid, false), "now there are 6")
	var coins := g.coins
	_check(g.crafting.add_star(uid, false), "2 stars")
	_eq(g.coins, coins - 50000, "for 50,000 coins")
	_eq(g.crafting.free_slots(o), 2, "2 slots")
	_check(g.crafting.recipe_unlocked(o, "dry_saki"), "2-star recipes unlocked")
	g.gems = 25
	_check(g.crafting.add_star(uid, true), "3 stars for gems")
	_eq(g.gems, 0, "25 gems")
	# The Farmers Market sells this building's crops, 3 bushels each, new every day.
	var stall := g.crafting.market_stall()
	_eq(stall.size(), CraftingSystem.STALL_CROPS, "%d crops on offer" % CraftingSystem.STALL_CROPS)
	var winery_crops := {}
	for r in g.crafting.recipes_of("winery"):
		for c in r.inputs():
			winery_crops[c] = true
	for c in stall:
		_check(winery_crops.has(c), "%s is used by the Winery" % c)
		_eq(int(stall[c]), CraftingSystem.STALL_EACH, "3 of each")
	var crop: String = stall.keys()[0]
	for k in 3:
		_check(g.crafting.buy_bushel(crop), "bought a %s bushel" % crop)
	_check(not g.crafting.buy_bushel(crop), "sold out for today")
	_eq(int(g.crafting.bushels[crop]), 3, "3 bushels")
	_skip(g, 86400)
	_eq(
		int(g.crafting.market_stall().values().reduce(func(a, b): return a + b, 0)),
		CraftingSystem.STALL_CROPS * CraftingSystem.STALL_EACH,
		"restocked the next day"
	)
	# Bushels are capped.
	g.crafting.bushels = {"rice": CraftingSystem.BUSHEL_CAP}
	_eq(g.crafting.add_bushels("wheat", 1), 0, "no room past %d bushels" % CraftingSystem.BUSHEL_CAP)
	_done(g)
