extends TestSuite
## A new farm's first hour (docs/PLAYER_EXPERIENCE.md Part 2, docs/FIRST_HOUR_RUN.md step 4): the Welcome chain
## opens on a brand-new farm in place of the old tutorial, a farm saved before it skips it, Starter Seeds are given
## once and never sold, Barley's chicken and the first Apple Tree come ready, today's jobs wait for level 3, and
## the goal-following bot finishes the Welcome chain within the first hour.

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
	sim.free()
	_done(g)


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
