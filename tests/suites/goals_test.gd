extends TestSuite
## Goals (GoalSystem, data/goals.json; docs/PLAYER_EXPERIENCE.md Part 1): the data is sound, doing a goal's tasks
## completes it, its reward arrives once, saved goals load where they were, and today's jobs are the same for the
## same day, only what the farm can do, swapped once.

const SHOP_ID := "strawberries"

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
		_check(roster.has(str(c.get("giver", ""))) or c.get("giver", "") == "guide",
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
		_check(int(j["n"]) >= 6 or j["do"] == "collect", "sized from the template's range")
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
