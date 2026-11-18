class_name GoalSystem
extends GameSystem
## Goals (docs/PLAYER_EXPERIENCE.md Part 1): the neighbours' story chains, today's three jobs and the long farm
## projects, all written in data/goals.json. Reached as `Game.goals`. A goal counts what is done after it is taken
## (it listens to `Game.did`, the one event stream), except the state verbs (`level`, `own`), which are true or
## not now. A finished goal waits to be collected with one tap (`claim_*`); its reward goes through the paths
## that exist (coins, XP, gems, the Barn or inbox for things, `unlock_chain` for the next chain). Saves only the
## goals' own state. Off when the release switches `goals` off.

const DATA_PATH := "res://data/goals.json"
const STATE_VERBS := ["level", "own"]   # true or not now, read from the farm rather than counted
const PICK := "@"                         # a `what` starting with it is a pick for daily jobs (@crop_unlocked...)
const ANY := ""                           # a `what` that matches anything done with the verb

var chains: Array = []          # data: [{id, giver, after, level, steps: [{say, tasks, reward}]}]
var daily_data := {}            # data: {count, swap, bonus, templates}
var projects: Array = []        # data: [{id, name, level, stages: [{tasks}], reward}]
var show_data := {}             # data: verb -> where a task's Show me goes (HudGoals.show_of)

var chain_step := {}            # open chain id -> the step it is on
var chains_done: Array[String] = []
var unlocked: Array[String] = []    # chains a reward opened (`unlock_chain`), still waiting for their level
var project_stage := {}         # open project id -> the stage it is on
var projects_done: Array[String] = []
var progress := {}              # goal key ("chain:<id>", "project:<id>", "daily:<i>") -> counts, one per task
var daily_day := 0              # the day today's jobs were made for (0: never)
var daily_jobs: Array = []      # today's jobs: [{do, what, n}]
var daily_claimed: Array = []   # which of them were collected
var daily_swaps := 0            # swaps used today
var daily_bonus_given := false

var _chain_by_id := {}
var _project_by_id := {}


func load_data() -> void:
	use_data(DataFile.read(DATA_PATH))
	if not game.did.is_connected(_on_did):
		game.did.connect(_on_did)
	if not game.xp_changed.is_connected(_on_xp):
		game.xp_changed.connect(_on_xp)


## Sets the goals' data (load_data reads data/goals.json; tests hand in their own).
func use_data(d: Dictionary) -> void:
	chains = d.get("chains", [])
	daily_data = d.get("daily", {})
	projects = d.get("projects", [])
	show_data = d.get("show", {})
	_chain_by_id.clear()
	for c: Dictionary in chains:
		_chain_by_id[str(c["id"])] = c
	_project_by_id.clear()
	for p: Dictionary in projects:
		_project_by_id[str(p["id"])] = p


func reset() -> void:
	chain_step = {}
	chains_done = []
	unlocked = []
	project_stage = {}
	projects_done = []
	progress = {}
	daily_day = 0
	daily_jobs = []
	daily_claimed = []
	daily_swaps = 0
	daily_bonus_given = false


func save_to(data: Dictionary) -> void:
	data["goal_chain_step"] = chain_step.duplicate()
	data["goal_chains_done"] = chains_done.duplicate()
	data["goal_unlocked"] = unlocked.duplicate()
	data["goal_project_stage"] = project_stage.duplicate()
	data["goal_projects_done"] = projects_done.duplicate()
	data["goal_progress"] = progress.duplicate(true)
	data["goal_daily"] = {"day": daily_day, "jobs": daily_jobs.duplicate(true), "claimed": daily_claimed.duplicate(),
		"swaps": daily_swaps, "bonus": daily_bonus_given}


func load_from(data: Dictionary) -> void:
	reset()
	chain_step = _known(int_map(data.get("goal_chain_step", {})), _chain_by_id, "steps")
	project_stage = _known(int_map(data.get("goal_project_stage", {})), _project_by_id, "stages")
	chains_done = _strings(data.get("goal_chains_done", []))
	unlocked = _strings(data.get("goal_unlocked", []))
	projects_done = _strings(data.get("goal_projects_done", []))
	var p: Variant = data.get("goal_progress", {})
	if typeof(p) == TYPE_DICTIONARY:
		for k: String in p:
			if typeof(p[k]) == TYPE_ARRAY:
				progress[k] = (p[k] as Array).map(func(v: Variant) -> int: return maxi(0, int(v)) if (
					typeof(v) in [TYPE_INT, TYPE_FLOAT]) else 0)
	var dd: Variant = data.get("goal_daily", {})
	if typeof(dd) == TYPE_DICTIONARY:
		daily_day = maxi(0, int(dd.get("day", 0)))
		for j: Variant in dd.get("jobs", []):
			if typeof(j) == TYPE_DICTIONARY and (j as Dictionary).has("do"):
				daily_jobs.append({"do": str(j["do"]), "what": str(j.get("what", ANY)), "n": maxi(1, int(j.get("n", 1)))})
		var claimed: Variant = dd.get("claimed", [])
		for i in daily_jobs.size():
			daily_claimed.append(typeof(claimed) == TYPE_ARRAY and i < (claimed as Array).size() and bool(claimed[i]))
		daily_swaps = maxi(0, int(dd.get("swaps", 0)))
		daily_bonus_given = bool(dd.get("bonus", false))


## A new farm's showcase: today's jobs with one done and waiting, and the first chain open, half way.
func showcase() -> void:
	if not active():
		return
	refresh()
	if not daily_jobs.is_empty():
		var need := int(daily_jobs[0]["n"])
		progress["daily:0"] = [need]
	for id: String in chain_step:
		var tasks := tasks_of("chain:" + id)
		if not tasks.is_empty():
			progress["chain:" + id] = tasks.map(func(t: Dictionary) -> int: return int(t.get("n", 1)) / 2)
		break
	game.goals_changed.emit()


static func _strings(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(v) == TYPE_ARRAY:
		for s: Variant in v:
			out.append(str(s))
	return out


## The entries of `m` (id -> step) whose id is in `by_id` and whose step is one of its `parts` (a damaged save's
## step past the end is dropped, not a crash).
static func _known(m: Dictionary, by_id: Dictionary, parts: String) -> Dictionary:
	var out := {}
	for k: String in m:
		if by_id.has(k) and int(m[k]) < (by_id[k].get(parts, []) as Array).size():
			out[k] = m[k]
	return out


func active() -> bool:
	return Release.on("goals")


# ---------------------------------------------------------------- what is open


## Opens every chain and project whose time has come, and makes today's jobs when the day turned.
func refresh() -> void:
	if not active():
		return
	var changed := false
	for c: Dictionary in chains:
		var id := str(c["id"])
		if not chain_step.has(id) and not chains_done.has(id) and _chain_ready(c):
			chain_step[id] = 0
			_take("chain:" + id)
			changed = true
	for p: Dictionary in projects:
		var id := str(p["id"])
		if not project_stage.has(id) and not projects_done.has(id) and game.level() >= int(p.get("level", 1)):
			project_stage[id] = 0
			_take("project:" + id)
			changed = true
	if game.day_turned(daily_day):
		make_daily_jobs()
		changed = true
	if changed:
		game.goals_changed.emit()


func _chain_ready(c: Dictionary) -> bool:
	if game.level() < int(c.get("level", 1)):
		return false
	if unlocked.has(str(c["id"])):
		return true
	if c.get("locked", false):
		return false
	for a: Variant in c.get("after", []):
		if not chains_done.has(str(a)):
			return false
	return true


## A chain's data by id ({} when there is none).
func chain_of(id: String) -> Dictionary:
	return _chain_by_id.get(id, {})


## A project's data by id ({} when there is none).
func project_of(id: String) -> Dictionary:
	return _project_by_id.get(id, {})


## The open goals, in the order the faces show them: chains, then today's jobs, then projects.
func open_keys() -> Array[String]:
	var out: Array[String] = []
	for c: Dictionary in chains:
		if chain_step.has(str(c["id"])):
			out.append("chain:" + str(c["id"]))
	for i in daily_jobs.size():
		if not daily_claimed[i]:
			out.append("daily:%d" % i)
	for p: Dictionary in projects:
		if project_stage.has(str(p["id"])):
			out.append("project:" + str(p["id"]))
	return out


## The tasks of a goal now (its step or stage; a daily job is one task).
func tasks_of(key: String) -> Array:
	var part := key.split(":", true, 1)
	if part.size() < 2:
		return []
	match part[0]:
		"chain":
			var c: Dictionary = _chain_by_id.get(part[1], {})
			if c.is_empty() or not chain_step.has(part[1]):
				return []
			return c["steps"][int(chain_step[part[1]])].get("tasks", [])
		"project":
			var p: Dictionary = _project_by_id.get(part[1], {})
			if p.is_empty() or not project_stage.has(part[1]):
				return []
			return p["stages"][int(project_stage[part[1]])].get("tasks", [])
		"daily":
			var i := int(part[1])
			return [daily_jobs[i]] if i >= 0 and i < daily_jobs.size() else []
	return []


## How far each task of a goal is: [[have, need], ...]. State verbs read the farm now.
func progress_of(key: String) -> Array:
	var out := []
	var counts: Array = progress.get(key, [])
	var tasks := tasks_of(key)
	for t in tasks.size():
		var task: Dictionary = tasks[t]
		var need := int(task.get("n", 1))
		var have := 0
		match str(task["do"]):
			"level":
				have = game.level()
			"own":
				have = own_count(str(task.get("what", ANY)))
			_:
				have = int(counts[t]) if t < counts.size() else 0
		out.append([mini(have, need), need])
	return out


func is_done(key: String) -> bool:
	if key.begins_with("daily:"):
		var i := int(key.get_slice(":", 1))
		if i < 0 or i >= daily_claimed.size() or daily_claimed[i]:
			return false
	var p := progress_of(key)
	if p.is_empty():
		return false
	for pair: Array in p:
		if pair[0] < pair[1]:
			return false
	return true


## How many things standing on the farm `what` names (an id or a kind).
func own_count(what: String) -> int:
	var n := 0
	for o: Dictionary in game.objects:
		if matches(what, str(o["id"])):
			n += 1
	return n


## Whether a task's `what` covers `subject`: anything, the same id, or the subject's catalog kind.
func matches(what: String, subject: String) -> bool:
	if what == ANY or what == subject:
		return true
	if subject == "" or what.begins_with(PICK):
		return false
	return str(game.item_data(subject).get("kind", "")) == what if game.items.has(subject) else (
		what == "crop" and game.crops.has(subject))


func _take(key: String) -> void:
	progress[key] = []
	progress[key].resize(tasks_of(key).size())
	progress[key].fill(0)


func _on_did(verb: String, subject: String, n: int) -> void:
	if not active():
		return
	var changed := false
	for key in open_keys():
		var tasks := tasks_of(key)
		if not progress.has(key) or (progress[key] as Array).size() != tasks.size():
			_take(key)
		for t in tasks.size():
			var task: Dictionary = tasks[t]
			if str(task["do"]) == verb and matches(str(task.get("what", ANY)), subject):
				progress[key][t] = mini(int(progress[key][t]) + n, int(task.get("n", 1)))
				changed = true
	if verb in ["expand", "build", "buy"] or changed:
		refresh()
	if changed:
		game.goals_changed.emit()


func _on_xp(_xp: int, _level: int) -> void:
	refresh()


# ---------------------------------------------------------------- collecting


## Collects a finished goal: its reward once, then the next step, stage or nothing. Returns the reward given.
func claim(key: String) -> Dictionary:
	if not active() or not is_done(key):
		return {}
	var part := key.split(":", true, 1)
	var reward := {}
	match part[0]:
		"chain":
			reward = _claim_chain(part[1])
		"project":
			reward = _claim_project(part[1])
		"daily":
			reward = _claim_daily(int(part[1]))
	give(reward)
	refresh()
	game.goals_changed.emit()
	game.queue_save()
	return reward


func _claim_chain(id: String) -> Dictionary:
	var c: Dictionary = _chain_by_id[id]
	var step := int(chain_step[id])
	var reward: Dictionary = c["steps"][step].get("reward", {})
	if step + 1 < (c["steps"] as Array).size():
		chain_step[id] = step + 1
		_take("chain:" + id)
	else:
		chain_step.erase(id)
		progress.erase("chain:" + id)
		chains_done.append(id)
	return reward


func _claim_project(id: String) -> Dictionary:
	var p: Dictionary = _project_by_id[id]
	var stage := int(project_stage[id])
	if stage + 1 < (p["stages"] as Array).size():
		project_stage[id] = stage + 1
		_take("project:" + id)
		return p["stages"][stage].get("reward", {})
	project_stage.erase(id)
	progress.erase("project:" + id)
	projects_done.append(id)
	return p.get("reward", {})


func _claim_daily(i: int) -> Dictionary:
	daily_claimed[i] = true
	var task: Dictionary = daily_jobs[i]
	var reward := {"coins": Balance.i("goals.daily_coins_per") * int(task["n"]), "xp": Balance.i("goals.daily_xp")}
	if not daily_bonus_given and not daily_claimed.has(false):
		daily_bonus_given = true
		var bonus: Dictionary = daily_data.get("bonus", {})
		if bonus.has("box"):
			reward["box"] = str(bonus["box"])
		var every := int(bonus.get("gems_every", 0))
		if every > 0 and daily_day % every == 0:
			reward["gems"] = 1
	return reward


## Gives a reward through the paths that exist.
func give(reward: Dictionary) -> void:
	if reward.has("coins"):
		game.add_coins(int(reward["coins"]))
	if reward.has("xp"):
		game.add_xp(int(reward["xp"]))
	if reward.has("gems"):
		game.add_gems(int(reward["gems"]))
	for f in ["item", "place"]:
		if reward.has(f):
			game.storage.welcome(str(reward[f]))
	if reward.has("box"):
		game.mystery.gift_box()
	if reward.has("unlock_chain") and not unlocked.has(str(reward["unlock_chain"])):
		unlocked.append(str(reward["unlock_chain"]))


# ---------------------------------------------------------------- today's jobs


## Makes today's jobs: picked from the templates for what this farm can do now, the same for the same day and
## farm, sized by level.
func make_daily_jobs() -> void:
	daily_day = game.day_number()
	daily_jobs = []
	daily_swaps = 0
	daily_bonus_given = false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([daily_day, game.level()])
	for i in int(daily_data.get("count", 3)):
		var job := _pick_job(rng, daily_jobs)
		if job.is_empty():
			break
		daily_jobs.append(job)
	daily_claimed = []
	daily_claimed.resize(daily_jobs.size())
	daily_claimed.fill(false)
	for i in daily_jobs.size():
		_take("daily:%d" % i)


## Swaps today's job `i` for another, once a day (daily.swap). Returns whether it was swapped.
func swap_daily(i: int) -> bool:
	if i < 0 or i >= daily_jobs.size() or daily_claimed[i] or daily_swaps >= int(daily_data.get("swap", 1)):
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([daily_day, game.level(), "swap", i])
	var job := _pick_job(rng, daily_jobs)
	if job.is_empty():
		return false
	daily_jobs[i] = job
	daily_swaps += 1
	_take("daily:%d" % i)
	game.goals_changed.emit()
	game.queue_save()
	return true


func _pick_job(rng: RandomNumberGenerator, taken: Array) -> Dictionary:
	var options := []
	var weights := PackedFloat32Array()
	for t: Dictionary in daily_data.get("templates", []):
		if game.level() < int(t.get("level", 1)):
			continue
		for what in pick_candidates(str(t.get("what", ANY))):
			if taken.any(func(j: Dictionary) -> bool: return j["do"] == t["do"] and j["what"] == what):
				continue
			options.append([t, what])
			weights.append(float(t.get("weight", 1)))
	if options.is_empty():
		return {}
	var o: Array = options[rng.rand_weighted(weights)]
	var t: Dictionary = o[0]
	var n: Variant = t.get("n", 1)
	var size := int(n) if typeof(n) != TYPE_ARRAY else 1
	if typeof(n) == TYPE_ARRAY:
		var share := clampf(float(game.level()) / maxf(1.0, Balance.f("goals.daily_full_level")), 0.0, 1.0)
		size = roundi(lerpf(float(n[0]), float(n[1]), share))
	return {"do": str(t["do"]), "what": o[1], "n": maxi(1, size)}


## What a daily template's `what` can be on this farm now: a pick (@crop_unlocked, @animal_owned, @recipe_known,
## @building_owned) gives the choices, anything else is itself.
func pick_candidates(what: String) -> Array:
	match what:
		"@crop_unlocked":
			return game.crops.keys().filter(func(id: String) -> bool: return game.is_unlocked(id) and Release.has(id))
		"@animal_owned":
			return _owned_of_kind("animal")
		"@building_owned":
			return _owned_of_kind("building")
		"@recipe_known":
			var out := []
			for o: Dictionary in game.objects:
				for r: RecipeDef in game.crafting.recipes_of(str(o["id"])):
					if not out.has(r.id) and game.level() >= r.unlock_level:
						out.append(r.id)
			return out
	return [] if what.begins_with(PICK) else [what]


func _owned_of_kind(kind: String) -> Array:
	var out := []
	for o: Dictionary in game.objects:
		var id := str(o["id"])
		if not out.has(id) and str(game.item_data(id).get("kind", "")) == kind:
			out.append(id)
	return out
