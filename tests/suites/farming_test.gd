extends TestSuite
## Plowing, planting, growing, harvesting, withering, and levelling up.


func test_01_new_farm_starts_like_the_classic_opening() -> void:
	var g := _farm()
	_eq(g.coins, Balance.i("economy.start_coins"), "starting coins")
	_eq(g.gems, Balance.i("economy.start_gems"), "starting gems")
	_eq(g.farm_size, GameState.START_SIZE, "starting size")
	_eq(g.field.phase(g.index_of(5, 4)), GameState.Phase.RIPE, "starter strawberries ripe")
	_eq(g.field.phase(g.index_of(5, 5)), GameState.Phase.RIPE, "starter wheat ripe")
	_eq(g.field.phase(g.index_of(6, 4)), GameState.Phase.GROWING, "half-grown plot growing")
	_eq(g.field.phase(g.index_of(7, 4)), GameState.Phase.PLOWED, "plowed starter plot")
	# The Welcome chain teaches a new farm (welcome_test 500); the three-step tutorial stays for farms without goals.
	_eq(g.tutorial_step, GameState.Tutorial.DONE, "the old tutorial gives way to the Welcome chain")
	_check(g.goals.chain_step.has("welcome"), "a new farm is on the Welcome chain")
	var ids: Array = g.objects.map(func(o): return o["id"])
	for want in ["farmhouse", "barn", "mailbox", "farm_stand", "cow"]:
		_check(ids.has(want), "starter farm has a %s" % want)
	_eq(ids.count("chicken"), 2, "two starter chickens")
	for o in g.objects:
		if o["id"] in ["chicken", "cow"]:
			_check(g.is_ready(o), "starter %s has its first collect waiting" % o["id"])
	_check(g.storage.barn().get("broken", false), "the barn starts broken")
	_check(not g.is_occupied(g.index_of(5, 4)), "no object on the starter crops")
	_done(g)






## The first visit closes on a level-up: harvesting the ripe plots, collecting the animals and plowing a field of
## ten (about half the coins in hand) reaches level 2 (data/balance.json level_xp; it took 55 XP, three visits).
func test_01b_first_visit_reaches_level_2() -> void:
	var g := _farm()
	g.field.harvest(g.index_of(5, 4))
	g.field.harvest(g.index_of(5, 5))
	for o in g.objects.duplicate():
		if g.is_ready(o):
			g.collect(int(o["uid"]))
	var plowed := 0
	for i in g.plots.size():
		if plowed == 10:
			break
		if g.on_farm(i) and not g.is_occupied(i) and g.plots[i]["state"] == "grass" and g.field.plow(i):
			g.field.plant(i, "strawberries")
			plowed += 1
	_eq(plowed, 10, "ten plots plowed and planted")
	_check(g.coins > 0, "with coins left over")
	_eq(g.level(), 2, "level 2 in the first visit")
	_done(g)






func test_02_plow_plant_grow_wither() -> void:
	var g := _farm()
	var i := _free(g)
	_check(g.field.plow(i), "plow grass")
	_eq(g.coins, Balance.i("economy.start_coins") - Balance.i("economy.plow_cost"), "plow cost")
	_check(not g.field.plow(i), "can't plow twice")
	_check(not g.field.plant(i, "cotton"), "locked crop refused at level 1")
	_check(g.field.plant(i, "strawberries"), "plant strawberries")
	_eq(g.field.phase(i), GameState.Phase.GROWING, "growing after planting")
	_skip(g, 4 * 3600)
	_eq(g.field.phase(i), GameState.Phase.RIPE, "ripe after 4 h")
	_skip(g, 4 * 3600)
	_eq(g.field.phase(i), GameState.Phase.WITHERED, "withered after the ripe window")
	_check(g.field.harvest(i).is_empty(), "withered crops can't be harvested")
	_done(g)






func test_03_harvest_pays_and_counts_mastery() -> void:
	var g := _farm()
	var i := _free(g)
	var before := g.coins
	var result := _grow_and_harvest(g, i, "strawberries")
	_eq(result["coins"], 35, "strawberry harvest coins")
	_eq(g.coins, before - Balance.i("economy.plow_cost") - 10 + 35, "coin balance after the cycle")
	_eq(g.field.phase(i), GameState.Phase.PLOWED, "plot is plowed again after harvest")
	_eq(g.mastery.points_of("strawberries"), 1, "mastery count")
	_done(g)






func test_04_fertilizer_adds_twenty_percent_and_double_mastery() -> void:
	var g := _farm()
	var i := _free(g)
	g.field.plow(i)
	_check(not g.field.fertilize(i), "can't fertilize an empty plot")
	g.field.plant(i, "strawberries")
	_check(g.field.fertilize(i), "fertilize a growing crop")
	_check(not g.field.fertilize(i), "can't fertilize twice")
	_skip(g, 4 * 3600)
	var result := g.field.harvest(i)
	_eq(result["coins"], 42, "35 coins + 20%")
	_eq(g.mastery.points_of("strawberries"), 2, "fertilized harvest counts double")
	_done(g)






func test_05_unwither_revives_withered_crops() -> void:
	var g := _farm()
	var i := _free(g)
	g.field.plow(i)
	g.field.plant(i, "strawberries")
	_skip(g, 9 * 3600)
	_eq(g.field.phase(i), GameState.Phase.WITHERED, "withered")
	var held := g.unwithers
	_check(g.use_unwither(), "use unwither")
	_eq(g.field.phase(i), GameState.Phase.RIPE, "ripe again")
	_eq(g.unwithers, held - 1, "one unwither used")
	_done(g)






func test_06_level_up_pays_coins_and_a_gem() -> void:
	var g := _farm()
	var coins := g.coins
	var gems := g.gems
	g.add_xp(g.xp_for_level(2))
	_eq(g.level(), 2, "reached level 2")
	_eq(g.coins, coins + g.level_reward(2), "level reward coins")
	_eq(g.gems, gems + Balance.i("economy.gems_per_level"), "level reward gem")
	_done(g)






func test_07_ribbons_award_tiers() -> void:
	var g := _farm()
	g.coins = 10000
	for r in range(8, 12):
		for c in range(7, 12):
			g.field.plow(g.index_of(r, c))
	_eq(g.ribbons.stat("plowed"), 20, "plowed counter")
	_eq(int(g.ribbons.ribbon_tiers.get("plow_pro", 0)), 1, "Plow Pro yellow ribbon at 20 plots")
	_done(g)


func test_114_the_sell_tool_clears_plots_back_to_grass() -> void:
	# FarmVille's delete: a plot put down by mistake goes back to grass, free; a crop on it is lost.
	var g := _farm()
	var i := g.index_of(10, 10)
	_check(not g.field.can_clear_plot(i), "grass is already grass")
	_check(g.field.plow(i), "plowed")
	var coins := g.coins
	_check(g.field.clear_plot(i), "a plowed plot clears")
	_eq(g.field.phase(i), GameState.Phase.GRASS, "back to grass")
	_eq(g.coins, coins, "for free")
	g.field.plow(i)
	g.field.plant(i, g.crops.keys()[0])
	_check(g.field.clear_plot(i), "a growing crop clears too (the tool asks first)")
	_eq(g.field.crop_at(i), "", "and the crop is gone")
	var j := g.index_of(6, 6)
	g.buy_and_place("hay_bale", 6, 6)
	_check(g.is_occupied(j) and not g.field.can_clear_plot(j), "nothing is cleared from under an object")
	_check(not g.field.clear_plot(j), "and clearing there does nothing")
	_done(g)


## Every crop, at its exact edges: one second before ripe it grows and can't be picked; at ripe it can; one
## second before its ripe window closes it still can; at the close it has withered.
func test_40_every_crop_ripens_and_withers_exactly_on_its_edges() -> void:
	var g := _farm()
	g.coins = 100000000
	g.xp = g.xp_for_level(120)
	var i := _free(g)
	for id: String in g.crops:
		var crop: Dictionary = g.crops[id]
		var grow := int(crop["grow_seconds"])
		var window := g.field.ripe_window(crop)
		g.field.clear_plot(i)
		g.field.plow(i)
		_check(g.field.plant(i, id), "%s is planted" % id)
		_skip(g, grow - 1)
		_eq(g.field.phase(i), GameState.Phase.GROWING, "%s: a second before ripe it grows" % id)
		_check(g.field.harvest(i).is_empty(), "%s: and can't be picked" % id)
		_skip(g, 1)
		_eq(g.field.phase(i), GameState.Phase.RIPE, "%s: ripe on the second" % id)
		_skip(g, window - 1)
		_eq(g.field.phase(i), GameState.Phase.RIPE, "%s: still ripe a second before the window closes" % id)
		_skip(g, 1)
		_eq(g.field.phase(i), GameState.Phase.WITHERED, "%s: withered as it closes" % id)
	_done(g)


func test_41_nothing_changes_when_a_step_is_refused() -> void:
	var g := _farm()
	var i := _free(g)
	g.field.plow(i)
	g.coins = 0
	_check(not g.field.plant(i, "strawberries"), "no seeds without coins")
	_eq(g.plots[i], {"state": "plowed"}, "the plot is untouched")
	_eq(g.coins, 0, "and no coins went")
	g.coins = 1000
	g.field.plant(i, "strawberries")
	_check(g.field.fertilize(i), "fertilized")
	var coins := g.coins
	_check(not g.field.fertilize(i), "a second fertilizer is refused")
	_eq(g.coins, coins, "without charging for it")
	g.coins = 0
	var j := g.index_of(11, 12)
	_check(not g.field.plow(j), "no plowing without coins")
	_eq(g.field.phase(j), GameState.Phase.GRASS, "the grass is untouched")
	_done(g)


func test_42_the_clock_going_back_and_a_long_absence_are_both_handled() -> void:
	var g := _farm()
	var i := _free(g)
	g.field.plow(i)
	g.field.plant(i, "strawberries")
	_skip(g, -86400)
	_eq(g.field.phase(i), GameState.Phase.GROWING, "planted 'in the future' it is still growing, not ripe")
	_check(g.field.harvest(i).is_empty(), "and can't be picked")
	_skip(g, 86400 + 4 * 3600)
	_eq(g.field.phase(i), GameState.Phase.RIPE, "with the clock right again it ripens on time")
	_skip(g, 30 * 86400)
	_eq(g.field.phase(i), GameState.Phase.WITHERED, "a month away, it has withered")
	_done(g)


func test_43_a_pollinated_crop_stays_ripe_longer_and_pays_once() -> void:
	var g := _farm()
	var i := _free(g)
	g.field.plow(i)
	g.field.plant(i, "strawberries")
	g.plots[i]["pol"] = true
	var window := g.field.ripe_window(g.crops["strawberries"])
	_skip(g, 4 * 3600 + window)
	_eq(g.field.phase(i), GameState.Phase.RIPE, "still ripe past the plain window")
	_skip(g, window * (Balance.i("economy.pollinated_ripe_mult") - 1))
	_eq(g.field.phase(i), GameState.Phase.WITHERED, "withered at the end of the longer one")
	var j := g.index_of(11, 12)
	g.field.plow(j)
	g.field.plant(j, "strawberries")
	_skip(g, 4 * 3600)
	var coins := g.coins
	_check(not g.field.harvest(j).is_empty(), "picked")
	var paid := g.coins - coins
	_check(g.field.harvest(j).is_empty(), "a second pick of the same crop (a job queued twice) gets nothing")
	_eq(g.coins - coins, paid, "so it is paid once")
	_done(g)


func test_44_fertilizer_doubles_mastery_for_every_crop() -> void:
	var g := _farm()
	g.coins = 100000000
	g.xp = g.xp_for_level(120)
	var i := _free(g)
	for id: String in g.crops:
		var before := g.mastery.points_of(id)
		g.field.plow(i)
		g.field.plant(i, id)
		g.field.fertilize(i)
		_skip(g, int(g.crops[id]["grow_seconds"]))
		_check(not g.field.harvest(i).is_empty(), "%s picked" % id)
		_eq(g.mastery.points_of(id) - before, 2, "%s: a fertilized crop counts twice" % id)
	_done(g)


func test_576_the_old_tutorial_never_asks_for_what_is_not_there() -> void:
	# Owner, 19 Nov: "Tap your ripe crops to harvest!" floated over a field of empty plowed plots. A harvest step
	# with nothing ripe moves on to plowing.
	var g := _farm()
	g.tutorial_step = GameState.Tutorial.HARVEST
	_eq(g.tutorial_text(), tr("YOUR_FIRST_CROPS_ARE_READY_TAP"), "ripe starter crops: harvest them")
	g.field.harvest(g.index_of(5, 4))
	g.field.harvest(g.index_of(5, 5))
	_check(not g.any_plot_in(GameState.Phase.RIPE), "nothing ripe now")
	g.tutorial_step = GameState.Tutorial.HARVEST   # (an older save stuck on the step)
	_eq(g.tutorial_text(), tr("CHOOSE_PLOW_THEN_TAP_A_GRASSY"), "nothing ripe: plow next")
	_done(g)


func test_582_phone_notifications_are_few_true_and_never_at_night() -> void:
	# Owner, 19 Nov: phone notifications. Planned from the farm's own timers: the next crop ready (named), the
	# animals, the next day's gift; at most notify.most, notify.gap apart, none in the quiet hours (moved to 8 am).
	var g := _farm()
	var plan := PhoneNotices.plan(g)
	_check(not plan.is_empty() and plan.size() <= Balance.i("notify.most"), "a few: %d" % plan.size())
	var bias := DayCycle.device_bias_minutes() * 60
	var quiet: Array = Balance.a("notify.quiet")
	for k in plan.size():
		var at := int(plan[k]["at"])
		_check(at > g.now(), "in the future")
		var hour := float(posmod(at + bias, 86400)) / 3600.0
		_check(hour >= float(quiet[1]) and hour < float(quiet[0]), "never in the quiet hours (%.2f)" % hour)
		if k > 0:
			_check(at - int(plan[k - 1]["at"]) >= Balance.i("notify.gap"), "an hour apart at least")
	var texts := plan.map(func(r: Dictionary) -> String: return str(r["text"]))
	_check(texts.any(func(t: String) -> bool: return t.contains("ready to harvest") or t.contains("daily gift")),
		"it says what is waiting %s" % str(texts))
	# A moment at 11 pm is moved to the end of the quiet hours, the next morning.
	var day := floori((g.now() + bias) / 86400.0) * 86400
	var late := day + 23 * 3600 - bias
	_eq(PhoneNotices._out_of_quiet(late, bias), day + 86400 + int(float(quiet[1]) * 3600) - bias, "11 pm -> 8 am")
	_done(g)


func test_585_a_young_farm_is_helped_to_plant_once_a_day() -> void:
	# Owner, 19 Nov ("a gentler start"): for its first week a farm short of seed money for a few plots is topped up
	# once a day; the first day is the starting coins' and Welcome's, and a grown farm is never helped.
	var g := _farm()
	var need := Balance.i("economy.young_farm_plots") * (g.cheapest_seed_cost() + Balance.i("economy.plow_cost"))
	_check(g.any_plot_in(GameState.Phase.GRASS) or g.any_plot_in(GameState.Phase.PLOWED), "room to plant")
	g.coins = 0
	g.check_rescue()
	_eq(g.coins < need, true, "not on the first day")
	g.born_day = g.day_number() - 1
	g.helped_day = g.born_day
	g.coins = 0
	g.check_rescue()
	_check(g.coins >= need, "the second day: enough for a few plots (%d)" % g.coins)
	g.coins = 0
	g.check_rescue()
	_check(g.coins < need, "once a day")
	g.born_day = g.day_number() - Balance.i("economy.young_farm_days")
	g.helped_day = -1
	g.check_rescue()
	_check(g.coins < need, "a grown farm is not helped")
	_done(g)


func test_586_the_rare_coop_gives_the_eggs_it_asks_to_open() -> void:
	# Owner, 19 Nov: the rare coop project could never finish (Mystery Eggs too rare); its middle step now gives
	# the eggs its last step asks to open, through the goal reward "eggs".
	var g := _farm()
	var before := int(g.mystery.mystery_eggs.get("white", 0))
	g.goals.give({"eggs": {"white": 2}})
	_eq(int(g.mystery.mystery_eggs.get("white", 0)) - before, 2, "two white Mystery Eggs given")
	var chain := g.goals.project_of("rare_coop")
	_check(not chain.is_empty(), "the rare coop project exists")
	var given := 0
	var asked := 0
	for s: Dictionary in chain.get("stages", []):
		given += int((s.get("reward", {}) as Dictionary).get("eggs", {}).get("white", 0))
		for t: Dictionary in s.get("tasks", []):
			if str(t.get("do")) == "open_egg":
				asked += int(t.get("n", 0))
	_check(given >= asked and asked > 0, "gives %d, asks %d" % [given, asked])
	_done(g)
