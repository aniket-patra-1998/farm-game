extends TestSuite
## A new farm's first hour (docs/PLAYER_EXPERIENCE.md Part 2, docs/FIRST_HOUR_RUN.md step 4): the Welcome chain
## opens on a brand-new farm in place of the old tutorial, a farm saved before it skips it, Starter Seeds are given
## once and never sold, Barley's chicken and the first Apple Tree come ready, today's jobs wait for level 3, and
## the goal-following bot finishes the Welcome chain within the first hour; the tools and menu buttons appear as
## goals need them (data/reveal.json, HudReveal).

const WELCOME := "welcome"


func test_500_a_new_farm_opens_on_the_welcome_chain_and_an_older_farm_skips_it() -> void:
	var g := _farm()
	_check(g.goals.chain_step.has(WELCOME), "a new farm is on the Welcome chain")
	_eq(int(g.goals.chain_step[WELCOME]), 0, "at its first step")
	_eq(g.tutorial_step, GameState.Tutorial.DONE, "the old three-step tutorial is not shown beside it")
	_eq(g.tutorial_text(), tr("GOAL_SAY_WELCOME_1"), "the floating words are Maple's first line")
	_eq(g.goals.open_keys()[0], "chain:" + WELCOME, "its face is the first")
	g.goals.refresh()
	_check(g.goals.daily_jobs.is_empty(), "today's jobs wait for level 3")
	# A farm saved before the Welcome chain existed (no goal state at all) knows the basics.
	var data := {}
	g.goals.save_to(data)
	data.erase("goal_chain_step")
	g.goals.load_from(data)
	_check(not g.goals.chain_step.has(WELCOME) and g.goals.chains_done.has(WELCOME), "an older farm skips Welcome")
	_eq(g.goals.welcome_say(), "", "and has no Welcome words")
	# A farm saved on the chain loads on its step.
	var mid := {}
	g.goals.chain_step = {WELCOME: 3}
	g.goals.chains_done = []
	g.goals.save_to(mid)
	g.goals.load_from(mid)
	_eq(int(g.goals.chain_step.get(WELCOME, -1)), 3, "a farm saved on the chain loads on its step")
	_done(g)


func test_501_starter_seeds_are_a_gift_once_never_sold_and_ripen_in_minutes() -> void:
	var g := _farm()
	var crop: Dictionary = g.crops["starter_seeds"]
	_check(crop.get("starter", false) and int(crop["grow_seconds"]) <= 300, "Starter Seeds ripen within minutes")
	_check(not g.can_plant("starter_seeds"), "they cannot be planted before they are given")
	_check(not g.goals.pick_candidates("@crop_unlocked").has("starter_seeds")
		and not g.goals.pick_candidates("@crop_quick").has("starter_seeds"), "today's jobs never name them")
	var i := _plowed(g)
	_check(not g.field.plant(i, "starter_seeds"), "nor planted by hand")
	g.goals.give({"seeds": "starter_seeds"})
	_eq(g.goals.seeds_of("starter_seeds"), 1, "a reward gives one plot's worth")
	var coins := g.coins
	_check(g.field.plant(i, "starter_seeds"), "planted while held")
	_eq(g.coins, coins, "free")
	_eq(g.goals.seeds_of("starter_seeds"), 0, "used up")
	_check(not g.field.plant(_plowed(g), "starter_seeds"), "one plot only")
	g.debug_time_offset += int(crop["grow_seconds"])
	_eq(g.field.phase(i), GameState.Phase.RIPE, "ripe after its minutes")
	var saved := {}
	g.goals.give({"seeds": "starter_seeds"})
	g.goals.save_to(saved)
	g.goals.load_from(saved)
	_eq(g.goals.seeds_of("starter_seeds"), 1, "held seeds are saved")
	_done(g)


func test_502_barleys_chicken_and_the_first_apple_tree_come_ready() -> void:
	var g := _farm()
	g.goals.give({"place": "chicken", "ready": true})
	var post: Dictionary = g.social.inbox[g.social.inbox.size() - 1]
	_check(g.social.claim(int(post["id"]), true), "the chicken is taken from the Gift Box")
	var spot := _free_spot(g, "chicken")
	_check(g.storage.place_from_storage(g.storage.stored.size() - 1, spot.x, spot.y), "and placed")
	var placed: Dictionary = g.objects[g.objects.size() - 1]
	_check(g.is_ready(placed), "its first egg is ready at once")
	# The Welcome step that buys the first tree marks it ready.
	g.goals.chain_step = {WELCOME: _step_with(g, "apple_tree")}
	g.goals.progress.erase("chain:" + WELCOME)
	g.add_coins(1000)
	g.xp = 200
	var at := _free_spot(g, "apple_tree")
	_check(g.buy_and_place("apple_tree", at.x, at.y), "the Apple Tree is bought")
	_check(g.is_ready(g.objects[g.objects.size() - 1]), "its first fruit is ready at once")
	_check(g.buy_and_place("apple_tree", _free_spot(g, "apple_tree").x, _free_spot(g, "apple_tree").y), "a second")
	_check(not g.is_ready(g.objects[g.objects.size() - 1]), "a later tree grows as usual")
	_done(g)


func test_503_the_bot_finishes_the_welcome_chain_in_the_first_hour() -> void:
	var g := _farm()
	var sim: Node = load("res://tools/balance_sim.gd").new()
	sim.set("game", g)
	sim.set("style", "goals")
	g.debug_time_offset += int(sim.call("_seconds_until", sim.call("_visit_hours")[0], g.now()))
	g.reset_game()
	var hour: Dictionary = sim.call("play_first_hour")
	_check(g.goals.chains_done.has(WELCOME), "the Welcome chain is done within the hour (%s)" % [hour["lines"]])
	_check(int(hour["level_at"][60]) >= 3, "level 3 by minute 60")
	_check(not g.goals.daily_jobs.is_empty(), "today's jobs arrived with level 3")
	_check(g.goals.chains_done.has(WELCOME) and not g.goals.open_keys().is_empty(), "and a goal is open after it")
	# Part 2's minute-by-minute plan, in its order: harvest, Starter Seeds, the chicken, the Apple Tree from the
	# Market, level 3 and today's jobs, a crop ready when you wake. (The Tractor project and Barley's coop chain
	# are step 7's content.)
	var at: Array = hour["chain_minutes"].get(WELCOME, [])
	_eq(at.size(), (g.goals.chain_of(WELCOME)["steps"] as Array).size(), "every Welcome step collected (%s)" % [at])
	var sorted := at.duplicate()
	sorted.sort()
	_check(at == sorted, "one after another")
	_check(int(hour["first_harvest"]) >= 0 and int(hour["first_harvest"]) <= 2, "the first harvest in minutes 0-2")
	_check(int(hour["first_buy"]) >= 0 and at.size() > 4 and int(hour["first_buy"]) <= int(at[4]),
		"the first purchase is the Apple Tree step's (minute %d)" % hour["first_buy"])
	_check(int(hour["minute_of_level"].get(3, 99)) <= 60, "level 3 within the hour")
	sim.free()
	_done(g)


func test_504_a_new_farm_sees_the_buttons_as_goals_need_them() -> void:
	var g := _farm()
	var rules: Dictionary = g.goals.reveal_data.get("buttons", {})
	_check(rules.has("menu:MARKET") and rules.has("tool:plow"), "data/reveal.json lists the Market and the tools")
	_check(g.goals.shows("tool:hand") and g.goals.shows("tool:harvest"), "Select and Harvest show from the start")
	for b: String in rules:
		_check(not g.goals.shows(b), "%s waits on a new farm" % b)
	_check(g.goals.reveal_now().is_empty(), "nothing shines at minute zero")
	# Maple's second step asks to plow and plant: those tools appear, once, and stay.
	g.goals.chain_step = {WELCOME: 1}
	var fresh := g.goals.reveal_now()
	_check(fresh.has("tool:plow") and fresh.has("tool:plant") and not fresh.has("menu:MARKET"), "%s appear" % [fresh])
	g.goals.chain_step = {WELCOME: _step_with(g, "apple_tree")}
	_check(Array(g.goals.reveal_now()) == ["menu:MARKET"], "the Market appears with the Apple Tree step")
	g.goals.chain_step = {WELCOME: 0}
	_check(g.goals.shows("tool:plow") and g.goals.shows("menu:MARKET"), "a shown button stays")
	var saved := {}
	g.goals.save_to(saved)
	g.goals.load_from(saved)
	_check(g.goals.shows("menu:MARKET") and not g.goals.shows("menu:RIBBONS"), "what was shown is saved")
	# Something in the inbox (Barley's chicken) shows the inbox; a level shows the rest.
	g.goals.give({"place": "chicken", "ready": true})
	_check(g.goals.shows("menu:INBOX"), "the inbox shows while a gift waits in it")
	g.xp = 100000
	for b: String in rules:
		_check(g.goals.shows(b), "%s shows by its level at the latest" % b)
	# A farm past Welcome (an older save) sees everything.
	g.goals.reset()
	g.goals.chain_step = {}
	g.goals.chains_done = [WELCOME]
	g.xp = 0
	for b: String in rules:
		_check(g.goals.shows(b), "%s shows on a farm past Welcome" % b)
	_done(g)


func test_505_the_hud_hides_what_waits_and_shines_what_appears() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	_check(Game.goals.chain_step.has(WELCOME), "a new farm on the Welcome chain")
	var market: Button = hud.side.buttons["MARKET"]
	var plow: Button = hud.tools.buttons["plow"]
	_check(not market.visible and not plow.visible, "the Market and the hoe wait")
	_check((hud.tools.buttons["harvest"] as Button).visible, "Harvest is there for Maple's first step")
	Game.goals.chain_step = {WELCOME: 1}
	Game.goals_changed.emit()
	_check(plow.visible and not market.visible, "the hoe appears with the step that plows")
	await get_tree().process_frame
	_check(plow.modulate.r > 1.0, "with a shine")
	Game.goals.chain_step = {}
	Game.goals.chains_done = [WELCOME]
	Game.goals_changed.emit()
	for b: String in hud.reveals.buttons:
		_check((hud.reveals.buttons[b] as Button).visible, "%s shows past Welcome" % b)
	main.queue_free()
	await get_tree().process_frame
	Game.reset_game()


func _plowed(g: GameState) -> int:
	for i in g.plots.size():
		if g.on_farm(i) and g.field.phase(i) == GameState.Phase.PLOWED:
			return i
	for i in g.plots.size():
		if g.on_farm(i) and g.field.phase(i) == GameState.Phase.GRASS and not g.is_occupied(i):
			g.add_coins(100)
			g.field.plow(i)
			return i
	return -1


func _free_spot(g: GameState, id: String) -> Vector2i:
	for r in range(g.farm_size - 1, -1, -1):
		for c in g.farm_size:
			if g.can_place(id, r, c):
				return Vector2i(r, c)
	return Vector2i(-1, -1)


func _step_with(g: GameState, what: String) -> int:
	var steps: Array = g.goals.chain_of(WELCOME)["steps"]
	for s in steps.size():
		for t: Dictionary in steps[s]["tasks"]:
			if str(t.get("what", "")) == what:
				return s
	return -1
