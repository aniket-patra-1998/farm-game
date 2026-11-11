extends TestSuite
## Plowing, planting, growing, harvesting, withering, and levelling up.


func test_01_new_farm_starts_like_the_classic_opening() -> void:
	var g := _farm()
	_eq(g.coins, GameState.START_COINS, "starting coins")
	_eq(g.gems, GameState.START_GEMS, "starting gems")
	_eq(g.farm_size, GameState.START_SIZE, "starting size")
	_eq(g.phase(g.index_of(5, 4)), GameState.Phase.RIPE, "starter strawberries ripe")
	_eq(g.phase(g.index_of(5, 5)), GameState.Phase.RIPE, "starter wheat ripe")
	_eq(g.phase(g.index_of(6, 4)), GameState.Phase.GROWING, "half-grown plot growing")
	_eq(g.phase(g.index_of(7, 4)), GameState.Phase.PLOWED, "plowed starter plot")
	_eq(g.tutorial_step, GameState.Tutorial.HARVEST, "tutorial starts at harvest")
	var ids: Array = g.objects.map(func(o): return o["id"])
	for want in ["farmhouse", "barn", "mailbox", "farm_stand", "cow"]:
		_check(ids.has(want), "starter farm has a %s" % want)
	_eq(ids.count("chicken"), 2, "two starter chickens")
	_check(g.storage.barn().get("broken", false), "the barn starts broken")
	_check(not g.is_occupied(g.index_of(5, 4)), "no object on the starter crops")
	_done(g)






func test_02_plow_plant_grow_wither() -> void:
	var g := _farm()
	var i := _free(g)
	_check(g.plow(i), "plow grass")
	_eq(g.coins, GameState.START_COINS - GameState.PLOW_COST, "plow cost")
	_check(not g.plow(i), "can't plow twice")
	_check(not g.plant(i, "cotton"), "locked crop refused at level 1")
	_check(g.plant(i, "strawberries"), "plant strawberries")
	_eq(g.phase(i), GameState.Phase.GROWING, "growing after planting")
	_skip(g, 4 * 3600)
	_eq(g.phase(i), GameState.Phase.RIPE, "ripe after 4 h")
	_skip(g, 4 * 3600)
	_eq(g.phase(i), GameState.Phase.WITHERED, "withered after the ripe window")
	_check(g.harvest(i).is_empty(), "withered crops can't be harvested")
	_done(g)






func test_03_harvest_pays_and_counts_mastery() -> void:
	var g := _farm()
	var i := _free(g)
	var before := g.coins
	var result := _grow_and_harvest(g, i, "strawberries")
	_eq(result["coins"], 35, "strawberry harvest coins")
	_eq(g.coins, before - GameState.PLOW_COST - 10 + 35, "coin balance after the cycle")
	_eq(g.phase(i), GameState.Phase.PLOWED, "plot is plowed again after harvest")
	_eq(g.mastery.points_of("strawberries"), 1, "mastery count")
	_done(g)






func test_04_fertilizer_adds_twenty_percent_and_double_mastery() -> void:
	var g := _farm()
	var i := _free(g)
	g.plow(i)
	_check(not g.fertilize(i), "can't fertilize an empty plot")
	g.plant(i, "strawberries")
	_check(g.fertilize(i), "fertilize a growing crop")
	_check(not g.fertilize(i), "can't fertilize twice")
	_skip(g, 4 * 3600)
	var result := g.harvest(i)
	_eq(result["coins"], 42, "35 coins + 20%")
	_eq(g.mastery.points_of("strawberries"), 2, "fertilized harvest counts double")
	_done(g)






func test_05_unwither_revives_withered_crops() -> void:
	var g := _farm()
	var i := _free(g)
	g.plow(i)
	g.plant(i, "strawberries")
	_skip(g, 9 * 3600)
	_eq(g.phase(i), GameState.Phase.WITHERED, "withered")
	var held := g.unwithers
	_check(g.use_unwither(), "use unwither")
	_eq(g.phase(i), GameState.Phase.RIPE, "ripe again")
	_eq(g.unwithers, held - 1, "one unwither used")
	_done(g)






func test_06_level_up_pays_coins_and_a_gem() -> void:
	var g := _farm()
	var coins := g.coins
	var gems := g.gems
	g.add_xp(g.xp_for_level(2))
	_eq(g.level(), 2, "reached level 2")
	_eq(g.coins, coins + g.level_reward(2), "level reward coins")
	_eq(g.gems, gems + GameState.GEMS_PER_LEVEL, "level reward gem")
	_done(g)






func test_07_ribbons_award_tiers() -> void:
	var g := _farm()
	g.coins = 10000
	for r in range(8, 12):
		for c in range(7, 12):
			g.plow(g.index_of(r, c))
	_eq(g.ribbons.stat("plowed"), 20, "plowed counter")
	_eq(int(g.ribbons.ribbon_tiers.get("plow_pro", 0)), 1, "Plow Pro yellow ribbon at 20 plots")
	_done(g)


func test_114_the_sell_tool_clears_plots_back_to_grass() -> void:
	# FarmVille's delete: a plot put down by mistake goes back to grass, free; a crop on it is lost.
	var g := _farm()
	var i := g.index_of(10, 10)
	_check(not g.can_clear_plot(i), "grass is already grass")
	_check(g.plow(i), "plowed")
	var coins := g.coins
	_check(g.clear_plot(i), "a plowed plot clears")
	_eq(g.phase(i), GameState.Phase.GRASS, "back to grass")
	_eq(g.coins, coins, "for free")
	g.plow(i)
	g.plant(i, g.crops.keys()[0])
	_check(g.clear_plot(i), "a growing crop clears too (the tool asks first)")
	_eq(g.crop_at(i), "", "and the crop is gone")
	var j := g.index_of(6, 6)
	g.buy_and_place("hay_bale", 6, 6)
	_check(g.is_occupied(j) and not g.can_clear_plot(j), "nothing is cleared from under an object")
	_check(not g.clear_plot(j), "and clearing there does nothing")
	_done(g)
