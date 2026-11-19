extends TestSuite
## Goals (GoalSystem, data/goals.json; docs/PLAYER_EXPERIENCE.md Part 1): the data is sound, doing a goal's tasks
## completes it, its reward arrives once, saved goals load where they were, and today's jobs are the same for the
## same day, only what the farm can do, swapped once.

const SHOP_ID := "strawberries"
const BOT := "res://tools/balance_sim.gd"   # the balance bot (step 6), driven on a test farm

## A small set of goals of the data's own shape, for the rules (the real chains are content: steps 4 and 7).
const FIXTURE := {
	"chains": [
		{"id": "first", "giver": "barley", "after": [], "level": 1, "steps": [
			{"say": "GOAL_TEST", "tasks": [{"do": "harvest", "what": "strawberries", "n": 3}],
				"reward": {"coins": 50, "xp": 5}},
			{"say": "GOAL_TEST", "tasks": [{"do": "plow", "what": "", "n": 2}, {"do": "level", "n": 1}],
				"reward": {"gems": 1, "unlock_chain": "later"}}]},
		{"id": "second", "giver": "maple", "after": ["first"], "level": 1, "steps": [
			{"say": "GOAL_TEST", "tasks": [{"do": "plant", "what": "crop", "n": 1}], "reward": {"coins": 10}}]},
		{"id": "later", "giver": "rusty", "locked": true, "level": 1, "steps": [
			{"say": "GOAL_TEST", "tasks": [{"do": "own", "what": "animal", "n": 1}], "reward": {"xp": 1}}]}],
	"daily": {"count": 3, "swap": 1, "bonus": {"box": "mystery_box", "gems_every": 3}, "templates": [
		{"do": "harvest", "what": "@crop_unlocked", "n": [6, 20], "weight": 3},
		{"do": "plow", "what": "", "n": [6, 20], "weight": 1},
		{"do": "collect", "what": "@animal_owned", "n": [2, 8], "weight": 2},
		{"do": "craft", "what": "@recipe_known", "n": [1, 2], "weight": 1, "level": 99}]},
	"projects": [
		{"id": "proj", "level": 1, "stages": [{"tasks": [{"do": "harvest", "what": "", "n": 1}]},
			{"tasks": [{"do": "plow", "what": "", "n": 1}]}], "reward": {"place": "hay_bale"}}],
}


func _goal_farm() -> GameState:
	var g := _farm()
	g.goals.use_data(FIXTURE)
	g.goals.reset()
	g.goals.refresh()
	return g


func test_458_the_goals_data_is_sound() -> void:
	var g := _farm()
	var d := DataFile.read(GoalSystem.DATA_PATH)
	_check(d.has("daily") and d.has("chains") and d.has("projects"), "data/goals.json has chains, daily and projects")
	var verbs: Dictionary = g.ribbons.event_verbs
	var roster := g.social.roster().map(func(n: String) -> String: return n.to_lower())
	var chain_ids := (d.get("chains", []) as Array).map(func(c: Dictionary) -> String: return str(c["id"]))
	var tasks := []
	for c: Dictionary in d.get("chains", []):
		_check(roster.has(str(c.get("giver", "")).to_lower()) or c.get("giver", "") == "guide",
			"chain %s's giver is a neighbour" % c["id"])
		for a: Variant in c.get("after", []):
			_check(chain_ids.has(str(a)), "chain %s comes after a chain that exists (%s)" % [c["id"], a])
		for s: Dictionary in c.get("steps", []):
			_check(tr(str(s.get("say", ""))) != str(s.get("say", "")), "chain %s's words are in locale" % c["id"])
			tasks.append_array(s.get("tasks", []))
			_check(not (s.get("reward", {}) as Dictionary).has("cost"), "a step never asks for gems")
	for p: Dictionary in d.get("projects", []):
		for s: Dictionary in p.get("stages", []):
			tasks.append_array(s.get("tasks", []))
	tasks.append_array(d["daily"].get("templates", []))
	for t: Dictionary in tasks:
		var v := str(t["do"])
		_check(verbs.has(v) or GoalSystem.STATE_VERBS.has(v), "the verb '%s' is an event or a state" % v)
		var what := str(t.get("what", ""))
		if what != "" and not what.begins_with("@"):
			var kinds := ["crop", "animal", "tree", "building", "decor", "vehicle", "bloom", "recipe", "bee"]
			_check(g.items.has(what) or g.crops.has(what) or kinds.has(what), "'%s' is an id or a kind" % what)
			_check(Release.has(what), "'%s' is in the release" % what)
	_done(g)


func test_459_doing_a_chains_tasks_completes_it_and_the_reward_arrives_once() -> void:
	var g := _goal_farm()
	_check(g.goals.open_keys().has("chain:first"), "the first chain opens by itself")
	_check(not g.goals.open_keys().has("chain:second"), "the second waits for the first")
	g.record("harvest", "wheat", 5)
	_eq(g.goals.progress_of("chain:first")[0][0], 0, "another crop does not count")
	g.record("harvest", SHOP_ID, 2)
	_check(not g.goals.is_done("chain:first"), "two of three is not done")
	_check(g.goals.claim("chain:first").is_empty(), "an unfinished goal gives nothing")
	g.record("harvest", SHOP_ID, 5)
	_eq(g.goals.progress_of("chain:first")[0], [3, 3], "progress stops at what is asked")
	var coins := g.coins
	_eq(g.goals.claim("chain:first").get("coins", 0), 50, "the step's reward")
	_eq(g.coins, coins + 50, "the coins arrive")
	_check(g.goals.claim("chain:first").is_empty(), "the reward arrives once (the next step is not done yet)")
	g.record("plow", "", 2)
	_check(g.goals.is_done("chain:first"), "plow anything twice and be at level 1 (a state)")
	var gems := g.gems
	g.goals.claim("chain:first")
	_eq(g.gems, gems + 1, "the last step's gem")
	_check(g.goals.chains_done.has("first"), "the chain is done")
	_check(g.goals.open_keys().has("chain:second"), "the chain after it opens")
	_check(g.goals.open_keys().has("chain:later"), "unlock_chain opens a locked chain")
	g.record("plant", "wheat")
	_check(g.goals.is_done("chain:second"), "a kind (crop) covers any crop")
	_done(g)


func test_460_counting_starts_when_a_goal_is_taken_and_state_verbs_read_the_farm() -> void:
	var g := _goal_farm()
	g.record("plow", "", 9)
	g.goals.claim("chain:first")
	_eq(g.goals.progress_of("chain:first")[0][0], 0, "plowing done before the step was taken does not count")
	g.goals.use_data({"chains": [FIXTURE["chains"][2]], "daily": {}, "projects": []})
	g.goals.reset()
	g.goals.unlocked.append("later")
	g.goals.refresh()
	var animals := g.goals.own_count("animal")
	_eq(g.goals.is_done("chain:later"), animals >= 1, "own: true when an animal stands on the farm now")
	_done(g)


func test_461_saved_goals_load_where_they_were() -> void:
	var g := _goal_farm()
	g.record("harvest", SHOP_ID, 2)
	g.record("harvest", "", 1)
	var data := {}
	g.goals.save_to(data)
	var h := _goal_farm()
	h.goals.load_from(JSON.parse_string(JSON.stringify(data)))
	_eq(h.goals.progress_of("chain:first"), g.goals.progress_of("chain:first"), "the chain's progress")
	_eq(h.goals.progress_of("project:proj"), [[1, 1]], "the project's progress")
	_eq(h.goals.daily_jobs, g.goals.daily_jobs, "today's jobs")
	h.goals.load_from({"goal_chain_step": {"gone": 1, "first": -3}, "goal_progress": {"chain:first": ["x", -1]},
		"goal_daily": "broken"})
	_check(h.goals.chain_step.is_empty(), "a chain no longer in the data, or a negative step, is dropped")
	_eq(h.goals.progress_of("chain:first"), [], "a dropped chain has no tasks")
	_done(h)
	_done(g)


func test_462_todays_jobs_are_the_days_own_and_only_what_the_farm_can_do() -> void:
	var g := _goal_farm()
	var jobs := g.goals.daily_jobs.duplicate(true)
	_eq(jobs.size(), 3, "three jobs")
	g.goals.make_daily_jobs()
	_eq(g.goals.daily_jobs, jobs, "the same day gives the same jobs")
	for j: Dictionary in jobs:
		_check(j["do"] != "craft", "never a job above the farm's level")
		if j["do"] == "harvest":
			_check(g.is_unlocked(str(j["what"])), "a crop the farm can grow")
		if j["do"] == "collect":
			_check(g.goals.own_count(str(j["what"])) > 0, "an animal the farm has")
		_check(int(j["n"]) >= 6 or j["do"] == "collect" or (g.crops.has(str(j["what"]))
			and int(j["n"]) == maxi(1, g.goals.affordable_plots(str(j["what"])))), "sized from the template's range")
	# A job to plant or harvest a named crop asks no more plots than the coins plow and sow today.
	g.coins = 55
	g.goals.daily_day = -1
	g.goals.make_daily_jobs()
	for j: Dictionary in g.goals.daily_jobs:
		if j["do"] in ["plant", "harvest"] and g.crops.has(str(j["what"])):
			_check(int(j["n"]) <= maxi(1, g.goals.affordable_plots(str(j["what"]))), "an affordable job: %s" % j)
	var seen := {}
	for j: Dictionary in jobs:
		seen["%s %s" % [j["do"], j["what"]]] = true
	_eq(seen.size(), 3, "three different jobs")
	_check(g.goals.swap_daily(1), "a job swaps")
	_check(g.goals.daily_jobs[1] != jobs[1], "for another")
	_check(not g.goals.swap_daily(2), "once a day")
	_done(g)


func test_463_all_three_jobs_collected_give_the_bonus_once() -> void:
	var g := _goal_farm()
	for i in g.goals.daily_jobs.size():
		var j: Dictionary = g.goals.daily_jobs[i]
		g.record(str(j["do"]), str(j["what"]), int(j["n"]))
	_check(g.goals.is_done("daily:0"), "a job done")
	var r0 := g.goals.claim("daily:0")
	_check(r0.get("coins", 0) > 0 and not r0.has("box"), "one job pays coins, not the bonus")
	g.goals.claim("daily:1")
	var r2 := g.goals.claim("daily:2")
	_eq(r2.get("box", ""), "mystery_box", "the third gives the Mystery Box")
	_eq(r2.has("gems"), g.goals.daily_day % 3 == 0, "and a gem every third day")
	_check(g.goals.claim("daily:2").is_empty(), "collected once")
	_check(not g.goals.open_keys().any(func(k: String) -> bool: return k.begins_with("daily")), "none left today")
	_done(g)


func test_464_a_project_goes_stage_by_stage_and_its_reward_stands_on_the_farm() -> void:
	var g := _goal_farm()
	g.record("harvest", SHOP_ID)
	g.goals.claim("project:proj")
	_eq(g.goals.project_stage.get("proj", -1), 1, "the next stage")
	g.record("plow", "")
	var before := g.storage.stored.size() + g.social.inbox.size()
	g.goals.claim("project:proj")
	_check(g.goals.projects_done.has("proj"), "the project is done")
	_eq(g.storage.stored.size() + g.social.inbox.size(), before + 1, "its reward arrives in the Barn or inbox")
	_done(g)


func test_483_a_clock_set_back_a_day_brings_no_day_round_again() -> void:
	# Setting the clock back to yesterday and forward again made a new day each time: today's jobs (coins, XP, a
	# Mystery Box, a gem), the neighbours' helps and gifts, the fuel find and the market stall came round anew.
	var g := _goal_farm()
	var jobs := g.goals.daily_jobs.duplicate(true)
	var j: Dictionary = jobs[0]
	g.record(str(j["do"]), str(j["what"]), int(j["n"]))
	g.goals.claim("daily:0")
	g.social.help_day = g.day_number()
	g.social.helps_today = Balance.i("social.helps_per_day")
	g.social.gift_day = g.day_number()
	g.social.gifts_today = {"0": Balance.i("social.gifts_per_neighbour_per_day")}
	g.vehicles.fuel_found_day = g.day_number()
	var today := g.day_number()
	g.persistence.watch_clock()
	g.debug_time_offset -= 86400
	g.persistence.watch_clock()   # (a day back is seen, and moves the timers, not the day markers)
	g.goals.refresh()
	_eq(g.goals.daily_day, today, "yesterday's clock keeps today's jobs")
	_eq(g.goals.daily_jobs, jobs, "the same jobs")
	_check(g.goals.daily_claimed[0], "the collected one stays collected")
	_eq(g.social.helps_left(), 0, "no helps come back")
	_check(g.social.gifted_today(0), "no gift comes back")
	_check(not g.day_turned(g.vehicles.fuel_found_day), "no second fuel find")
	g.debug_time_offset += 86400
	g.goals.refresh()
	_check(g.goals.daily_claimed[0], "back to today: still collected")
	g.debug_time_offset += 86400
	_check(g.day_turned(today), "a real new day still turns")
	g.goals.refresh()
	_eq(g.goals.daily_day, today + 1, "and brings new jobs")
	# A clock that ran a month ahead and is put right: the day markers go back with it, so today's jobs, helps
	# and the daily gift come round today, not in a month.
	g.debug_time_offset += 30 * 86400
	g.persistence.watch_clock()
	g.goals.refresh()
	g.social._count_help()
	g.daily.last_daily_day = g.day_number()
	g.debug_time_offset -= 30 * 86400
	g.persistence.watch_clock()
	_check(not g.day_turned(g.goals.daily_day) and g.goals.daily_day >= g.day_number() - 1, "the jobs' day came back")
	_check(not g.day_turned(g.social.help_day) and g.social.help_day <= g.day_number(), "the helps' day came back")
	_check(g.daily.last_daily_day <= g.day_number(), "the daily gift's day came back")
	g.debug_time_offset += 86400
	_check(g.day_turned(g.goals.daily_day) and g.day_turned(g.social.help_day), "and the next day turns tomorrow")
	_done(g)


func test_484_a_damaged_goal_save_loads_without_a_crash() -> void:
	var g := _goal_farm()
	g.goals.load_from({"goal_chain_step": {"first": 99}, "goal_project_stage": {"proj": 5},
		"goal_daily": {"day": g.day_number(), "jobs": [{"do": "plow"}, {"do": "plow"}], "claimed": [true]}})
	_check(g.goals.chain_step.is_empty() and g.goals.project_stage.is_empty(), "a step past the end is dropped")
	_eq(g.goals.daily_claimed, [true, false], "a short claimed list is filled with not collected")
	_check(not g.goals.daily_bonus_given and g.goals.open_keys().has("daily:1"), "the second job is open")
	_done(g)


## The balance bot as a goal follower (tools/balance_sim, step 6): on a new farm from minute zero it harvests the
## starter's ripe plots at once, reaches level 2 in the first minutes and collects goals; over three days of
## visits it finishes every one of today's jobs on each day it comes, and nothing on a day it is away. (The faces
## are kept full by the story chains, which come in steps 4 and 7.)
func test_483_the_goal_follower_plays_a_new_farm_without_getting_stuck() -> void:
	var g := _farm()
	var sim: Node = load(BOT).new()
	sim.set("game", g)
	sim.set("style", "goals")
	var hours: Array = sim.call("_visit_hours")
	sim.call("new_farm")   # a farm made at the first visit's hour
	_check(absf(DayCycle.local_hour(g.now(), DayCycle.device_bias_minutes()) - float(hours[0])) < 0.01,
		"the new farm's clock reads the first visit's hour, whatever the hour the test runs")
	var hour: Dictionary = sim.call("play_first_hour")
	_eq(hour["first_harvest"], 0, "the starter's ripe plots are harvested in the first minute")
	_check(int(hour["level_at"][10]) >= 2, "level 2 within ten minutes")
	_check(int(hour["goals"]) >= 1, "a goal is collected in the first hour")
	sim.set("away", [2])
	var got := {1: int(hour["goals"])}   # day -> goals collected (day 1 is the first, with its first hour)
	for day in range(1, 4):
		for v in hours.size():
			if day == 1 and v == 0:
				continue   # the first hour was this visit
			g.debug_time_offset += int(sim.call("_seconds_until", hours[v], g.now()))
			var before := int(sim.get("goals_claimed"))
			if day != 2:
				sim.call("_visit", sim.call("_visits_after", hours, v))
			got[day] = int(got.get(day, 0)) + int(sim.get("goals_claimed")) - before
		_check(day == 2 or sim.call("jobs_left") == 0, "day %d: every job done by its last visit; open %s" % [day,
			g.goals.open_keys().map(func(k: String) -> Array: return [g.goals.tasks_of(k), g.goals.progress_of(k)])])
	_check(int(got[1]) > 0 and int(got[3]) > 0, "goals collected every day it comes: %s" % got)
	_eq(got[2], 0, "nothing on the day it is away")
	sim.free()
	_done(g)


## Today's jobs can be done today (found by the goal-following bot, step 6): a harvest job names only a crop that
## ripens within goals.daily_crop_hours, and a job to collect from or feed animals asks no more than the farm's
## own animals give in goals.daily_play_hours.
func test_484_todays_jobs_can_be_done_today() -> void:
	var g := _farm()
	g.goals.load_data()
	g.goals.reset()
	g.add_xp(g.xp_for_level(12))
	for o in 3:
		_check(g.place_somewhere("chicken"), "a chicken on the farm")
	var hours := Balance.f("goals.daily_crop_hours") * 3600.0
	for id: String in g.goals.pick_candidates("@crop_quick"):
		_check(float(g.crops[id]["grow_seconds"]) <= hours, "%s ripens within a day's play" % id)
	_check(g.goals.pick_candidates("@crop_quick").has(SHOP_ID), "strawberries are a quick crop")
	for day in 30:
		g.debug_time_offset += 86400
		g.goals.refresh()
		for job: Dictionary in g.goals.daily_jobs:
			var what := str(job["what"])
			match str(job["do"]):
				"harvest":
					_check(what == "" or float(g.crops[what]["grow_seconds"]) <= hours,
						"day %d: harvest %s can be done" % [day, what])
				"collect", "feed":
					_check(int(job["n"]) <= g.goals.per_day_of(what), "day %d: %s %d from %s, no more than they give"
						% [day, job["do"], job["n"], what])
	_done(g)


## Step 7's chains: each of the six neighbours tells one, each 3 to 6 steps of 1 to 3 tasks, opening from level 2
## to 12, never before the chains it follows; along the level path no more than two neighbour chains are open
## at once (the faces keep a place for today's jobs).
func test_513_the_six_neighbours_chains_follow_the_level_path() -> void:
	var g := _farm()
	var d := DataFile.read(GoalSystem.DATA_PATH)
	var by_id := {}
	var givers := []
	for c: Dictionary in d["chains"]:
		by_id[str(c["id"])] = c
		if c.get("new_farm", false):
			continue
		givers.append(str(c["giver"]).to_lower())
		var steps: Array = c["steps"]
		_check(steps.size() >= 3 and steps.size() <= 6, "%s has 3 to 6 steps" % c["id"])
		for s: Dictionary in steps:
			_check((s["tasks"] as Array).size() in [1, 2, 3], "%s: a step is 1 to 3 tasks" % c["id"])
			_check(not (s.get("reward", {}) as Dictionary).is_empty(), "%s: every step gives something" % c["id"])
		_check(int(c.get("level", 1)) >= 2 and int(c.get("level", 1)) <= 12, "%s opens from level 2 to 12" % c["id"])
		for a: Variant in c.get("after", []):
			_check(int(by_id.get(str(a), {}).get("level", 1)) <= int(c["level"]), "%s opens after %s" % [c["id"], a])
	givers.sort()
	var roster := g.social.roster().map(func(n: String) -> String: return n.to_lower())
	roster.sort()
	_eq(givers, roster, "each of the six neighbours tells one chain")
	# Walk the level path finishing each open chain at once: count the neighbour chains open together.
	var done := {"welcome": true}
	var most := 0
	for level in range(1, 31):
		var open := []
		for c: Dictionary in d["chains"]:
			var ready: bool = not done.has(str(c["id"])) and level >= int(c.get("level", 1)) \
				and (c.get("after", []) as Array).all(func(a: Variant) -> bool: return done.has(str(a)))
			if ready:
				open.append(str(c["id"]))
		most = maxi(most, open.size())
		for id: String in open:
			done[id] = true
	_check(most <= 2, "at most two neighbour chains open at once (%d)" % most)
	for p: Dictionary in d["projects"]:
		_check(tr(str(p.get("name", ""))) != str(p.get("name", "")), "project %s's name is in locale" % p["id"])
		var rewards: Array = [p.get("reward", {})]
		for s: Dictionary in p["stages"]:
			rewards.append(s.get("reward", {}))
		for c: Dictionary in d["chains"]:
			for s: Dictionary in c["steps"]:
				rewards.append(s.get("reward", {}))
		for r: Dictionary in rewards:
			for f in ["item", "place"]:
				if r.has(f):
					_check(g.items.has(str(r[f])) and Release.has(str(r[f])), "reward %s is in the release" % r[f])
	_eq(done.size(), (d["chains"] as Array).size(), "every chain opens on the level path")
	_done(g)


## A daily template's `needs` keeps it until the farm has one (no pollinate job without a beehive), and
## @tree_owned picks the farm's own trees.
func test_514_a_job_waits_for_what_it_needs() -> void:
	var g := _farm()
	g.goals.load_data()
	g.goals.reset()
	g.add_xp(g.xp_for_level(12))
	_eq(g.goals.pick_candidates("@tree_owned"), [], "no tree, no tree to pick")
	_check(g.place_somewhere("apple_tree"), "an apple tree on the farm")
	_eq(g.goals.pick_candidates("@tree_owned"), ["apple_tree"], "the farm's own tree")
	var seen := {}
	for day in 60:
		g.debug_time_offset += 86400
		g.goals.refresh()
		for job: Dictionary in g.goals.daily_jobs:
			seen[str(job["do"])] = true
	_check(not seen.has("pollinate"), "no pollinate job without a beehive")
	_check(not seen.has("vehicle_work"), "no vehicle job without a vehicle")
	_check(seen.has("collect"), "collect jobs come (the apple tree)")
	_done(g)


## Step 7's done-when (docs/FIRST_HOUR_RUN.md): the goal-following bot, three visits a day on a brand-new farm,
## finishes every story chain (the Welcome chain and the six neighbours') within three weeks.
func test_515_the_goal_bot_completes_every_chain() -> void:
	var g := _farm()
	var sim: Node = load(BOT).new()
	sim.set("game", g)
	sim.set("style", "goals")
	sim.set("_days", 21)
	var hours: Array = sim.call("_visit_hours")
	sim.call("new_farm")   # a farm made at the first visit's hour
	g.rng.seed = 1
	sim.call("_play")
	var left := []
	for c: Dictionary in g.goals.chains:
		if not g.goals.chains_done.has(str(c["id"])):
			left.append("%s at step %d" % [c["id"], int(g.goals.chain_step.get(str(c["id"]), -1)) + 1])
	_eq(left, [], "every chain done in 21 days")
	sim.free()
	_done(g)


## Part 4's Market measure in the balance bot (step 8): a progress buy counts as "something to buy" when it costs
## 1 to 3 visits of income (too cheap or too dear does not), decorations never count, the next land counts when
## its level is met; the builder style buys what it can afford of them, cheapest first.
func test_525_the_bot_measures_the_market_against_part_4() -> void:
	var g := _farm()
	g.xp = g.xp_for_level(15)
	var sim: Node = load(BOT).new()
	sim.set("game", g)
	var tree := float(g.buildings.price_of("apple_tree")["coins"])
	_check((sim.call("market_wants", tree / 2.0) as Array).has("apple_tree"), "a tree costing two visits is wanted")
	_check(not (sim.call("market_wants", tree * 4.0) as Array).has("apple_tree"), "nor one costing a quarter visit")
	_check(not (sim.call("market_wants", tree / 6.0) as Array).has("apple_tree"), "nor one costing six visits")
	for id: String in sim.call("market_wants", 1.0e9 / 3.0) + sim.call("market_wants", 100.0):
		_check(id == "land" or str(g.items[id]["kind"]) != "decor", "a decoration is never a progress buy: " + id)
	var step: Dictionary = g.land.next_expansion()
	if not step.is_empty() and g.level() >= int(step["level"]):
		_check((sim.call("market_wants", float(step["coins"]) / 2.0) as Array).has("land"), "the next land is wanted")
	g.coins = int(tree * 3.0)
	sim.set("_per_visit", tree / 2.0)
	sim.set("_actions", 0)
	sim.call("_buy_wants")
	_check((sim.get("_bought") as Dictionary).size() >= 1, "the builder buys what it wants and can afford")
	_check(g.coins < int(tree * 3.0), "and pays for it")
	_check(str(sim.call("market_line")).begins_with("market:"), "the summary line prints")
	sim.free()
	_done(g)


## Part 4's feeding targets in the balance bot (step 8): a never-feeder loses at most FEED_LOSS_MAX of what a feeder
## earns from animals (feeds.hunger_penalty is tuned for it) and nothing else, and a week away loses nothing: no
## animal, tree or building is gone when the bot comes back (FarmVille: nothing dies).
func test_529_never_feeding_costs_under_30_percent_and_a_week_away_loses_nothing() -> void:
	var shares := []
	for never: bool in [false, true]:
		var g := _farm(true)
		g.feeds.active = true   # (the test farm turns feeding off for exact payouts)
		var sim: Node = load(BOT).new()
		sim.set("game", g)
		sim.set("style", "goals")
		sim.set("_days", 12)
		sim.set("no_feed", never)
		if not never:
			sim.set("away", [3, 4, 5, 6, 7, 8, 9])
		var hours: Array = sim.call("_visit_hours")
		sim.call("new_farm")   # a farm made at the first visit's hour
		g.rng.seed = 1
		sim.call("_play")
		_check(int(sim.get("animal_collects")) > 0, "the bot collects from animals")
		_eq(int(sim.get("away_lost")), 0, "nothing lost while away")
		shares.append(float(sim.call("animal_share")))
		if never:
			_eq(int(sim.get("_fed")), 0, "--no-feed never feeds")
		sim.free()
		_done(g)
	_check(absf(float(shares[1]) - (1.0 - Balance.f("feeds.hunger_penalty"))) < 0.01,
		"a never-feeder's collects pay the hungry price: %.2f" % shares[1])
	_check(float(shares[0]) > 1.0, "feeding pays more than the plain price: %.2f" % shares[0])
	var loss := 1.0 - float(shares[1]) / float(shares[0])
	_check(loss <= float((load(BOT) as GDScript).get_script_constant_map()["FEED_LOSS_MAX"]),
		"never feeding loses %.0f%% of animal income (Part 4: at most 30%%)" % (loss * 100.0))



## Part 4's crafter style (step 8): at level 25 it builds the Bakery with coins (clearing harvested plots to make
## room), starts the best-paying recipe it has the bushels for, sells what is done at the next visit and counts it
## against the building's cost (craft_line: days of crafting to pay it back).
func test_531_the_crafter_builds_the_bakery_and_crafts() -> void:
	var g := _farm()
	g.xp = g.xp_for_level(25)
	var sim: Node = load(BOT).new()
	sim.set("game", g)
	sim.set("style", "crafter")
	g.coins = 200000
	sim.set("_actions", 100)
	sim.call("_craft")
	_check(g.crafting.owns_crafting(), "the crafter builds the Bakery")
	_eq(int(sim.get("craft_cost")), 100000, "with coins")
	_eq(int(sim.get("craft_built_day")), 1, "on the day it could")
	var home: Dictionary = sim.call("_crafting_home")
	var r := g.crafting.recipes_of("bakery")[0]
	for c: String in r.inputs():
		g.crafting.add_bushels(c, int(r.inputs()[c]))
	sim.set("_actions", 100)
	sim.call("_craft")
	_eq((home["slots"] as Array).size(), 1, "it starts a recipe with the bushels it holds")
	g.debug_time_offset += g.crafting.craft_seconds(r.id) + 1
	sim.set("_actions", 100)
	sim.call("_craft")
	_eq(int(sim.get("craft_made")), 1, "the next visit collects the good")
	_check(int(sim.get("craft_coins")) > int(sim.get("craft_worth")), "and sells it for more than its ingredients")
	_check(float(sim.call("craft_payback_days")) < INF, "crafting counts against the building's cost")
	_check(str(sim.call("craft_line")).begins_with("crafting: bakery built day 1"), "the summary line prints")
	sim.free()
	_done(g)
