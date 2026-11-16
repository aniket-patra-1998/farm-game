extends TestSuite
## Crafting: bushels, recipes, mastery, goods and the Farmers Market.


func test_79_every_building_has_three_recipes_a_star_made_of_what_the_farm_gives() -> void:
	var g := _farm()
	for b in ["bakery", "winery", "spa"]:
		var rs := g.crafting.recipes_of(b)
		_eq(rs.size(), 15, "%s has 15 recipes" % b)
		var dearest := 0   # what the dearest good of the star below sells for
		for star in range(1, 6):
			var of_star := rs.filter(func(r): return r.star() == star)
			_eq(of_star.size(), 3, "%s: 3 recipes at %d stars" % [b, star])
			var cheapest := 1 << 30
			var top := 0
			for r: RecipeDef in of_star:
				cheapest = mini(cheapest, r.sell_price(g.catalog, 0))
				top = maxi(top, r.sell_price(g.catalog, 0))
				for c: String in r.inputs():
					_check(g.crops.has(c) or g.catalog.get_def(c) is IngredientDef, "%s: %s is a crop or produce" % [r.id, c])
			_check(cheapest > dearest, "%s: every %d-star good sells for more than any below (%d > %d)" % [b, star,
				cheapest, dearest])
			dearest = top
	_eq(
		_ints((g.catalog.get_def("pumpkin_bread") as RecipeDef).inputs()),
		{"pumpkins": 4, "wheat": 4},
		"Pumpkin Bread is FarmVille's own: 4 pumpkins, 4 wheat"
	)
	_check(g.catalog.planned.has("red_table_wine") and g.catalog.get_def("red_table_wine") == null,
		"FarmVille's recipes for crops outside the first release are kept, planned")
	# The first release shows every one of them: nothing needs a crop or an animal it leaves out.
	var whole := Release.whole
	Release.whole = false
	for b in ["bakery", "winery", "spa"]:
		_eq(g.crafting.recipes_of(b).size(), 15, "%s: all 15 recipes in the first release" % b)
	_eq(g.crafting.recipes_of("feed_mill").size(), g.catalog.recipes_of("feed_mill").size(),
		"the Feed Mill: every recipe in the first release")
	Release.whole = whole
	# A recipe's star sets its time, fuel and XP.
	var bread := g.catalog.get_def("pumpkin_bread") as RecipeDef
	var pie := g.catalog.get_def("truffle_pie") as RecipeDef
	_eq(bread.craft_seconds(), 3600, "a 1-star recipe takes an hour")
	_eq(pie.craft_seconds(), 8 * 3600, "a 5-star one takes eight")
	_check(pie.fuel(0) > bread.fuel(0) and pie.xp() > bread.xp(), "a higher star gives more fuel and XP")
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
	_eq(g.crafting.craft_problem(uid, "three_berry_pie"), "Unlocks at 2 stars", "2-star recipes are locked")
	_check(g.crafting.start_craft(uid, "pumpkin_bread"), "baking")
	_eq(g.crafting.bushels, {"wheat": 1}, "bushels used")
	_eq(g.crafting.craft_problem(uid, "strawberry_shortcake"), "Every slot is busy", "one slot at 1 star")
	_eq(g.crafting.finish_crafts(uid), 0, "not done yet")
	_skip(g, 1800)
	_eq(g.crafting.finish_crafts(uid), 0, "nor after half an hour")
	_skip(g, 1800)
	_eq(g.crafting.finish_crafts(uid), 1, "done after an hour: a 1-star recipe's time")
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
	g.vehicles.fuel = Balance.i("vehicles.fuel_tank") - 5
	g.vehicles.fuel_tanks = 0
	_eq(g.crafting.use_good("pumpkin_bread"), Balance.i("recipes.fuel_base"), "a good gives fuel")
	_eq(g.vehicles.fuel_tanks, 1, "fuel past a full tank fills a spare tank")
	# Buy the missing bushels with gems.
	g.crafting.bushels = {}
	g.gems = 100
	_check(g.crafting.buy_missing_and_craft(uid, "strawberry_shortcake"), "bought 8 bushels and started")
	_eq(g.gems, 100 - 8 * Balance.i("crafting.bushel_gem_cost"), "1 gem a bushel")
	_done(g)






func test_82_stars_mastery_and_the_farmers_market() -> void:
	var g := _farm()
	var uid := _crafting_building(g, "winery")
	var o := g.object_by_uid(uid)
	_check(not g.crafting.can_add_star(uid, false), "no recipe stars yet")
	g.crafting.crafted = {"apple_cider": 15, "sweet_saki": 15, "strawberry_cranberry_juice": 5}
	_eq(g.crafting.recipe_stars("apple_cider"), 2, "15 crafts: 2 mastery stars")
	_eq(g.crafting.building_recipe_stars("winery"), 5, "5 stars across the Winery's recipes")
	_check(not g.crafting.can_add_star(uid, false), "6 are needed")
	g.crafting.crafted["strawberry_cranberry_juice"] = 15
	_check(g.crafting.can_add_star(uid, false), "now there are 6")
	var coins := g.coins
	_check(g.crafting.add_star(uid, false), "2 stars")
	_eq(g.coins, coins - 50000, "for 50,000 coins")
	_eq(g.crafting.free_slots(o), 2, "2 slots")
	_check(g.crafting.recipe_unlocked(o, "berry_wine"), "2-star recipes unlocked")
	g.gems = 25
	_check(g.crafting.add_star(uid, true), "3 stars for gems")
	_eq(g.gems, 0, "25 gems")
	# The Farmers Market sells this building's crops, 3 bushels each, new every day.
	var stall := g.crafting.market_stall()
	_eq(stall.size(), Balance.i("crafting.stall_crops"), "%d crops on offer" % Balance.i("crafting.stall_crops"))
	var winery_crops := {}
	for r in g.crafting.recipes_of("winery"):
		for c in r.inputs():
			winery_crops[c] = true
	for c in stall:
		_check(winery_crops.has(c), "%s is used by the Winery" % c)
		_eq(int(stall[c]), Balance.i("crafting.stall_each"), "3 of each")
	var crop: String = stall.keys()[0]
	for k in 3:
		_check(g.crafting.buy_bushel(crop), "bought a %s bushel" % crop)
	_check(not g.crafting.buy_bushel(crop), "sold out for today")
	_eq(int(g.crafting.bushels[crop]), 3, "3 bushels")
	_skip(g, 86400)
	_eq(
		int(g.crafting.market_stall().values().reduce(func(a, b): return a + b, 0)),
		Balance.i("crafting.stall_crops") * Balance.i("crafting.stall_each"),
		"restocked the next day"
	)
	# Bushels are capped.
	g.crafting.bushels = {"rice": Balance.i("crafting.bushel_cap")}
	_eq(g.crafting.add_bushels("wheat", 1), 0, "no room past %d bushels" % Balance.i("crafting.bushel_cap"))
	_done(g)


func test_371_collecting_gives_produce_and_recipes_use_it() -> void:
	var g := _farm(true)
	g.coins = 10000000
	g.xp = g.xp_for_level(30)
	_eq(g.crafting.produce_of("cow"), "milk", "a cow gives milk")
	_eq(g.crafting.produce_of("brown_chicken"), "eggs", "any chicken gives eggs")
	_eq(g.crafting.produce_of("apple_tree"), "apples", "an apple tree gives apples")
	_eq(g.crafting.produce_of("rose_full_bloom"), "cut_roses", "a rose bloom gives cut roses")
	_eq(g.crafting.produce_of("beehive"), "honey", "the beehive gives honey")
	_eq(g.crafting.produce_of("bull"), "", "a bull gives nothing")
	_eq(g.crafting.produce_of("bakery"), "", "nor does a building that isn't a hive")
	_check(g.buy_and_place("cow", 3, 3), "a cow")
	var cow := int(g.object_at(g.index_of(3, 3))["uid"])
	for k in 20:
		_skip(g, 2 * 86400)
		g.collect(cow)
	_check(g.crafting.bushels.is_empty(), "no produce before there is a crafting building")
	var uid := _crafting_building(g)
	_check(g.buy_and_place("cow", 3, 3), "a cow again (the helper clears the animals)")
	cow = int(g.object_at(g.index_of(3, 3))["uid"])
	var said := 0
	for k in 60:
		_skip(g, 2 * 86400)
		for extra: String in g.collect(cow).get("extras", []):
			if extra.contains(g.name_of("milk")):
				said += 1
	var milk := int(g.crafting.bushels.get("milk", 0))
	_check(milk > 5 and milk < 45, "about a third of collections give milk (%d of 60)" % milk)
	_eq(said, milk, "each one is said with the collection")
	# A home's animals each have their chance.
	g.crafting.bushels = {}
	var given := g.crafting.roll_produce({"id": "cow_shed", "uid": -5, "inside": {"cow": 20}})
	_check(int(given.get("milk", 0)) > 1, "a shed of 20 cows gives several (%s)" % given)
	# Produce is held with the bushels and used like one.
	g.crafting.bushels = {"carrots": 3, "wheat": 3, "eggs": 1}
	_eq(g.crafting.missing_bushels("carrot_muffins"), {"eggs": 1}, "Carrot Muffins need two eggs")
	g.crafting.bushels["eggs"] = 2
	_check(g.crafting.start_craft(uid, "carrot_muffins"), "baking with eggs")
	_check(g.crafting.bushels.is_empty(), "the eggs are used")
	_eq(g.crafting.value_of("milk"), (g.catalog.get_def("milk") as IngredientDef).value(), "produce has its own worth")
	_eq(g.crafting.value_of("wheat"), int(g.crops["wheat"]["sell_price"]), "a bushel is worth what its crop sells for")
	g.crafting.bushels = {"rice": Balance.i("crafting.bushel_cap")}
	_check(g.crafting.roll_produce({"id": "cow_shed", "uid": -5, "inside": {"cow": 40}}).is_empty(),
		"no room for produce past the bushels' cap")
	_done(g)


func test_372_every_good_and_every_produce_has_its_own_picture() -> void:
	var g := _farm()
	var looks := {}
	for kind: String in ["recipe", "ingredient"]:
		for d in g.catalog.of_kind(kind):
			var shape := (d as RecipeDef).shape() if d is RecipeDef else (d as IngredientDef).shape()
			_check((GoodsModel.GOODS if d is RecipeDef else GoodsModel.PRODUCE).has(shape),
				"%s: %s is a shape the pictures know" % [d.id, shape])
			var model := GoodsModel.build(d.id)
			_check(model != null, "%s has a model" % d.id)
			if model == null:
				continue
			var points := 0
			var colours := []
			for part in model.find_children("*", "MeshInstance3D", true, false):
				var mesh := (part as MeshInstance3D).mesh
				for s in mesh.get_surface_count():
					points += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			_check(points > 60, "%s is a thing, not a blob (%d points)" % [d.id, points])
			if d is RecipeDef:
				colours = GoodsModel.flavours(d as RecipeDef)
				_eq(colours.size() >= 3, true, "%s takes its colours from what goes into it" % d.id)
				looks["%s %s" % [shape, (colours[0] as Color).to_html(false)]] = true
			model.free()
	_check(looks.size() >= 40, "the goods are told apart by shape and colour (%d looks)" % looks.size())
	_check(GoodsModel.build("wheat") == null and GoodsModel.build("nails") == null and GoodsModel.build("nope") == null,
		"a crop, a building part or nothing is not a good")
	var loaf := GoodsModel.flavours(g.catalog.get_def("pumpkin_bread") as RecipeDef)
	_eq(loaf[0].to_html(false), GoodsModel.colour_of("pumpkins").to_html(false), "Pumpkin Bread is pumpkin coloured first")
	_done(g)

