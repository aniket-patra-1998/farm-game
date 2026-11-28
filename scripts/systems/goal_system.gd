class_name GoalSystem
extends GameSystem
## Goals (docs/PLAYER_EXPERIENCE.md Part 1): the neighbours' story chains, today's three jobs and the long farm
## projects, all written in data/goals.json. Reached as `Game.goals`. A goal counts what is done after it is taken
## (it listens to `Game.did`, the one event stream), except the state verbs (`level`, `own`), which are true or
## not now. A finished goal waits to be collected with one tap (`claim_*`); its reward goes through the paths
## that exist (coins, XP, gems, the Barn or inbox for things, `unlock_chain` for the next chain). Saves only the
## goals' own state. Off when the release switches `goals` off.

const DATA_PATH := "res://data/goals.json"
const REVEAL_PATH := "res://data/reveal.json"   # which buttons a new farm waits to see (shows, reveal_now)
const STATE_VERBS := ["level", "own"]   # true or not now, read from the farm rather than counted
const PICK := "@"                         # a `what` starting with it is a pick for daily jobs (@crop_unlocked...)
const ANY := ""                           # a `what` that matches anything done with the verb
const PER_WHAT := "?"                      # a key in _gives_by_id: a `what` already added up (not an id)

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
var seeds := {}                 # seeds a goal gave (Starter Seeds): crop id -> how many plots' worth are held
var reveal_data := {}           # data/reveal.json: {after, buttons: {button -> {verbs, level, inbox}}}
var revealed: Array[String] = []   # listed buttons this farm has been shown (they stay)
var sure_spent: Array[String] = []  # goal keys whose `sure` find was handed to a harvest (take_sure_find)
var recent := {}                # today's work not yet spent on a collected goal: "verb|subject" -> how many
var recent_day := 0             # the day `recent` is for

var _chain_by_id := {}
var _gives_by_id := {}   # what each id gives today, while the day's jobs are picked (_gives_today)
var _ready_next := ""           # a thing just bought that a `ready` task counted (take_ready)
var _project_by_id := {}


func load_data() -> void:
	use_data(DataFile.read(DATA_PATH))
	reveal_data = DataFile.read(REVEAL_PATH)
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
	chain_step = new_farm_chains()
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
	seeds = {}
	revealed = []
	sure_spent = []
	recent = {}
	recent_day = 0


## The chains a brand-new farm starts on (`new_farm`: the Welcome chain), at their first step. A farm saved
## before it had them never sees them (load_from).
func new_farm_chains() -> Dictionary:
	var out := {}
	for c: Dictionary in chains:
		if c.get("new_farm", false):
			out[str(c["id"])] = 0
	return out


func shift_clock(seconds: int) -> void:
	daily_day = game.day_moved_back(daily_day, seconds)


func save_to(data: Dictionary) -> void:
	data["goal_chain_step"] = chain_step.duplicate()
	data["goal_chains_done"] = chains_done.duplicate()
	data["goal_unlocked"] = unlocked.duplicate()
	data["goal_project_stage"] = project_stage.duplicate()
	data["goal_projects_done"] = projects_done.duplicate()
	data["goal_progress"] = progress.duplicate(true)
	data["goal_daily"] = {"day": daily_day, "jobs": daily_jobs.duplicate(true), "claimed": daily_claimed.duplicate(),
		"swaps": daily_swaps, "bonus": daily_bonus_given}
	data["goal_seeds"] = seeds.duplicate()
	data["goal_revealed"] = revealed.duplicate()
	data["goal_sure_spent"] = sure_spent.duplicate()
	data["goal_recent"] = {"day": recent_day, "done": recent.duplicate()}


func load_from(data: Dictionary) -> void:
	reset()
	chain_step = _known(int_map(data.get("goal_chain_step", {})), _chain_by_id, "steps")
	project_stage = _known(int_map(data.get("goal_project_stage", {})), _project_by_id, "stages")
	chains_done = _strings(data.get("goal_chains_done", []))
	unlocked = _strings(data.get("goal_unlocked", []))
	projects_done = _strings(data.get("goal_projects_done", []))
	# A farm saved before the Welcome chain existed knows the basics: it is done.
	for id: String in new_farm_chains():
		if not chain_step.has(id) and not chains_done.has(id):
			chains_done.append(id)
	revealed = _strings(data.get("goal_revealed", []))
	sure_spent = _strings(data.get("goal_sure_spent", []))
	var rd: Variant = data.get("goal_recent", {})
	var done: Variant = (rd as Dictionary).get("done", {}) if typeof(rd) == TYPE_DICTIONARY else {}
	if typeof(done) == TYPE_DICTIONARY:
		recent_day = maxi(0, int((rd as Dictionary).get("day", 0)))
		for k: Variant in done:
			if typeof(done[k]) in [TYPE_INT, TYPE_FLOAT] and int(done[k]) > 0:
				recent[str(k)] = int(done[k])
	var held := int_map(data.get("goal_seeds", {}))
	for id: String in held:
		if game.crops.has(id) and int(held[id]) > 0:
			seeds[id] = int(held[id])
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
	for b: String in reveal_data.get("buttons", {}):   # (the showcase shows every button)
		if not revealed.has(b):
			revealed.append(b)
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
	if game.level() >= int(daily_data.get("level", 1)) and game.day_turned(daily_day):
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


## Whether an open goal asks the player to buy `id` (the first-hour coin floor never holds such a buy back).
func asks_to_buy(id: String) -> bool:
	for key in open_keys():
		for t: Dictionary in tasks_of(key):
			if str(t.get("do", "")) == "buy" and str(t.get("what", "")) == id:
				return true
	return false


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


## A goal opening: its counts start from what was already done today (owner, 28 Nov: a hen collected just before
## its goal opened had to wait a day; games credit work already done). Not today's jobs (they are today's work
## by design), not a task that makes its thing come `ready`, not the state verbs (read from the farm anyway).
func _take(key: String) -> void:
	var tasks := tasks_of(key)
	progress[key] = []
	progress[key].resize(tasks.size())
	progress[key].fill(0)
	if key.begins_with("daily:"):
		return
	_age_recent()
	for t in tasks.size():
		var task: Dictionary = tasks[t]
		if STATE_VERBS.has(str(task["do"])) or task.get("ready", false):
			continue
		progress[key][t] = mini(_recent_of(task), int(task.get("n", 1)))


## How much of today's unspent work `task` covers.
func _recent_of(task: Dictionary) -> int:
	var n := 0
	for k: String in recent:
		var part := k.split("|", true, 1)
		if part[0] == str(task["do"]) and matches(str(task.get("what", ANY)), part[1] if part.size() > 1 else ""):
			n += int(recent[k])
	return n


## Today's work, kept to credit goals that open later today.
func _note_recent(verb: String, subject: String, n: int) -> void:
	_age_recent()
	var k := verb + "|" + subject
	recent[k] = int(recent.get(k, 0)) + n


## A collected goal spends the work its tasks needed, so the next goal is not paid by the same harvests twice.
func _spend_recent(key: String) -> void:
	_age_recent()
	for task: Dictionary in tasks_of(key):
		if STATE_VERBS.has(str(task["do"])):
			continue
		var need := int(task.get("n", 1))
		for k: String in recent.keys():
			if need <= 0:
				break
			var part := k.split("|", true, 1)
			if part[0] == str(task["do"]) and matches(str(task.get("what", ANY)), part[1] if part.size() > 1 else ""):
				var used := mini(need, int(recent[k]))
				recent[k] = int(recent[k]) - used
				need -= used
				if int(recent[k]) <= 0:
					recent.erase(k)


func _age_recent() -> void:
	if recent_day != game.day_number():
		recent = {}
		recent_day = game.day_number()


func _on_did(verb: String, subject: String, n: int) -> void:
	if not active():
		return
	_note_recent(verb, subject, n)
	var changed := false
	for key in open_keys():
		var tasks := tasks_of(key)
		if not progress.has(key) or (progress[key] as Array).size() != tasks.size():
			_take(key)
		for t in tasks.size():
			var task: Dictionary = tasks[t]
			if str(task["do"]) == verb and matches(str(task.get("what", ANY)), subject):
				if task.get("ready", false) and int(progress[key][t]) < int(task.get("n", 1)):
					_ready_next = subject
				progress[key][t] = mini(int(progress[key][t]) + n, int(task.get("n", 1)))
				changed = true
	if verb in ["expand", "build", "buy"] or changed:
		refresh()
	if changed:
		game.goals_changed.emit()


func _on_xp(_xp: int, _level: int) -> void:
	refresh()


# ---------------------------------------------------------------- collecting


## A harvest about to be decided asks whether an open goal guarantees its find: a `find` task marked `sure`,
## not yet done, whose sure find was not handed out yet (the broken Tractor project's first find, so a new
## player meets Collections; PLAYER_EXPERIENCE Part 2). Yes spends it: one sure find per goal, ever.
func take_sure_find() -> bool:
	if not active():
		return false
	for key: String in open_keys():
		if sure_spent.has(key):
			continue
		var tasks := tasks_of(key)
		var have := progress_of(key)
		for i in tasks.size():
			var t: Dictionary = tasks[i]
			if str(t.get("do", "")) == "find" and t.get("sure", false) and int(have[i][0]) < int(have[i][1]):
				sure_spent.append(key)
				return true
	return false


## Collects a finished goal: its reward once, then the next step, stage or nothing. Returns the reward given.
func claim(key: String) -> Dictionary:
	if not active() or not is_done(key):
		return {}
	var part := key.split(":", true, 1)
	var reward := {}
	if part[0] != "daily":
		_spend_recent(key)
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


## What collecting goal `key` will give (shown on its card before it is done); the daily bonus is not counted.
func reward_of(key: String) -> Dictionary:
	var part := key.split(":", true, 1)
	match part[0]:
		"chain":
			if not _chain_by_id.has(part[1]):
				return {}
			var steps: Array = _chain_by_id[part[1]]["steps"]
			var step := int(chain_step.get(part[1], 0))
			return (steps[step] as Dictionary).get("reward", {}) if step < steps.size() else {}
		"project":
			if not _project_by_id.has(part[1]):
				return {}
			var p: Dictionary = _project_by_id[part[1]]
			var stage := int(project_stage.get(part[1], 0))
			if stage + 1 < (p["stages"] as Array).size():
				return (p["stages"][stage] as Dictionary).get("reward", {})
			return p.get("reward", {})
		"daily":
			var i := int(part[1])
			if i < 0 or i >= daily_jobs.size():
				return {}
			return {"coins": Balance.i("goals.daily_coins_per") * int(daily_jobs[i]["n"]),
				"xp": Balance.i("goals.daily_xp")}
	return {}


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
			game.storage.welcome(str(reward[f]), {"ready": true} if reward.get("ready", false) else {})
	var parts: Variant = reward.get("parts", {})
	if typeof(parts) == TYPE_DICTIONARY:
		for m: String in parts:
			if int(parts[m]) > 0:
				game.daily.add_part(m, int(parts[m]))
	if reward.has("box"):
		game.mystery.gift_box()
	var eggs: Variant = reward.get("eggs", {})   # Mystery Eggs by colour (the rare coop's: owner, 19 Nov)
	if typeof(eggs) == TYPE_DICTIONARY:
		for colour: String in eggs:
			game.mystery.mystery_eggs[colour] = int(game.mystery.mystery_eggs.get(colour, 0)) + int(eggs[colour])
		if not (eggs as Dictionary).is_empty():
			game.inventory_changed.emit()
	if reward.has("seeds") and game.crops.has(str(reward["seeds"])):
		seeds[str(reward["seeds"])] = int(seeds.get(str(reward["seeds"]), 0)) + 1
	if reward.has("unlock_chain") and not unlocked.has(str(reward["unlock_chain"])):
		unlocked.append(str(reward["unlock_chain"]))


# ---------------------------------------------------------------- today's jobs


## Makes today's jobs: picked from the templates for what this farm can do now, the same for the same day and
## farm, sized by level.
func make_daily_jobs() -> void:
	_gives_by_id = _gives_today()   # (looked at once for all of today's picks)
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
	_gives_by_id = {}


## Swaps today's job `i` for another, once a day (daily.swap). Returns whether it was swapped.
func swap_daily(i: int) -> bool:
	if i < 0 or i >= daily_jobs.size() or daily_claimed[i] or daily_swaps >= int(daily_data.get("swap", 1)):
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([daily_day, game.level(), "swap", i])
	_gives_by_id = _gives_today()
	var job := _pick_job(rng, daily_jobs)
	_gives_by_id = {}
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
		if t.has("needs") and own_count(str(t["needs"])) == 0:   # a job for bees waits for a beehive
			continue
		for what in pick_candidates(str(t.get("what", ANY))):
			if taken.any(func(j: Dictionary) -> bool: return j["do"] == t["do"] and j["what"] == what):
				continue
			if t.get("per_owned", false) and per_day_of(str(what)) <= 0:
				continue   # (nothing of it will be ready in today's play: a job it can't be done today)
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
	if t.get("per_owned", false):
		size = mini(size, per_day_of(str(o[1])))
	if str(t["do"]) in ["plant", "harvest"] and game.crops.has(str(o[1])):
		size = mini(size, affordable_plots(str(o[1])))
	return {"do": str(t["do"]), "what": o[1], "n": maxi(1, size)}


## How many plots of crop `id` the farm's coins plow and sow now: a job to plant or harvest a named crop asks no
## more, so today's job can be done today (a new farm with 55 coins was asked to plant 8 Eggplant, 320 coins).
func affordable_plots(id: String) -> int:
	var each := int(game.crops[id].get("seed_cost", 0)) + Balance.i("economy.plow_cost")
	return game.coins / maxi(1, each)


## How many times the things standing on the farm that `what` names give in a day's play from now (a job to
## collect from them asks no more): each one when it is next ready, then once a cycle, within
## goals.daily_play_hours. A chicken just collected gives nothing more today (the bot was asked for 3 chickens'
## eggs the morning it had collected them all: a job that could not be done that day).
func per_day_of(what: String) -> int:
	if _gives_by_id.has(PER_WHAT + what):
		return int(_gives_by_id[PER_WHAT + what])
	var by_id := _gives_by_id if not _gives_by_id.is_empty() else _gives_today()
	var n := 0
	for id: String in by_id:
		if not id.begins_with(PER_WHAT) and matches(what, id):
			n += int(by_id[id])
	if not _gives_by_id.is_empty():
		_gives_by_id[PER_WHAT + what] = n   # (asked again for the next pick: known)
	return n


## What each kind of thing on the farm gives in a day's play from now, by item id (per_day_of adds up the ids a
## job names): the farm looked at once, not once for each job's candidate (a full farm's day turning took 8 s
## on a PC, every item asked of all 614 things).
func _gives_today() -> Dictionary:
	var out := {}
	var window := Balance.f("goals.daily_play_hours") * 3600.0
	for o: Dictionary in game.objects:
		var id := str(o["id"])
		var cycle := maxf(float(game.item_data(id).get("cycle_seconds", 86400)), 1.0)
		var wait := float(game.seconds_until_ready(o)) if o.has("t") else 0.0
		if wait <= window:
			out[id] = int(out.get(id, 0)) + 1 + floori((window - wait) / cycle)
	return out


## What a daily template's `what` can be on this farm now: a pick (@crop_unlocked, @crop_quick, @animal_owned,
## @tree_owned, @recipe_known, @building_owned) gives the choices, anything else is itself.
func pick_candidates(what: String) -> Array:
	match what:
		"@crop_unlocked":
			return _unlocked_crops()
		"@crop_quick":   # one that ripens within a day's play (a job to harvest it can be done today)
			var hours := Balance.f("goals.daily_crop_hours") * 3600.0
			return _unlocked_crops().filter(
				func(id: String) -> bool: return float(game.crops[id]["grow_seconds"]) <= hours)
		"@animal_owned":
			return _owned_of_kind("animal")
		"@tree_owned":
			return _owned_of_kind("tree")
		"@building_owned":
			return _owned_of_kind("building")
		"@recipe_known":
			var out := []
			var ids := {}
			for o: Dictionary in game.objects:
				ids[str(o["id"])] = true   # (each kind of building asked once, not each one on the farm)
			for id: String in ids:
				for r: RecipeDef in game.crafting.recipes_of(id):
					if not out.has(r.id) and game.level() >= r.unlock_level:
						out.append(r.id)
			return out
	return [] if what.begins_with(PICK) else [what]


## The open new-farm chain's line for the floating words ("" when none is open).
func welcome_say() -> String:
	if not active():
		return ""
	for id: String in new_farm_chains():
		if chain_step.has(id):
			var say := str(_chain_by_id[id]["steps"][int(chain_step[id])].get("say", ""))
			return tr(say) if say != "" else ""
	return ""


## Whether the `item_id` just bought comes ready to harvest at once: a task marked `ready` counted its buy
## (the Welcome chain's first tree). Asked once, as it is placed (ShopSystem.buy_and_place).
func take_ready(item_id: String) -> bool:
	var yes := _ready_next == item_id
	_ready_next = ""
	return yes


## How many plots' worth of a goal's gift seeds are held.
func seeds_of(crop_id: String) -> int:
	return int(seeds.get(crop_id, 0))


## Uses one plot's worth of gift seeds, if any are held. Returns whether one was used.
func take_seed(crop_id: String) -> bool:
	if seeds_of(crop_id) <= 0:
		return false
	seeds[crop_id] = seeds_of(crop_id) - 1
	if seeds[crop_id] == 0:
		seeds.erase(crop_id)
	return true


func _unlocked_crops() -> Array:
	return game.crops.keys().filter(func(id: String) -> bool: return game.is_unlocked(id) and Release.has(id))


func _owned_of_kind(kind: String) -> Array:
	var out := []
	for o: Dictionary in game.objects:
		var id := str(o["id"])
		if not out.has(id) and str(game.item_data(id).get("kind", "")) == kind:
			out.append(id)
	return out


# ---------------------------------------------------------------- showing the interface as it is needed


## Whether HUD button `button` ("tool:plow", "menu:MARKET") shows on this farm now (data/reveal.json): a button
## not listed, a farm without goals and a farm past the `after` chains see it; else once a goal needs it (an open
## task's verb), at its level, or (`inbox`) while something waits in the inbox, and from then on.
func shows(button: String) -> bool:
	var rule: Variant = reveal_data.get("buttons", {}).get(button)
	if not active() or typeof(rule) != TYPE_DICTIONARY or revealed.has(button) or past_welcome():
		return true
	if game.level() >= int(rule.get("level", 1)):
		return true
	if rule.get("inbox", false) and not game.social.inbox.is_empty():
		return true
	var verbs: Array = rule.get("verbs", [])
	for key: String in open_keys():
		for task: Dictionary in tasks_of(key):
			if verbs.has(str(task.get("do", ""))):
				return true
	return false


## Whether the farm is past the chains that teach it (reveal.json `after`): then every button shows.
func past_welcome() -> bool:
	for id: Variant in reveal_data.get("after", []):
		if not chains_done.has(str(id)):
			return false
	return true


## The listed buttons that show now for the first time (kept as shown; the HUD gives each its shine).
func reveal_now() -> Array[String]:
	var out: Array[String] = []
	for b: String in reveal_data.get("buttons", {}):
		if not revealed.has(b) and shows(b):
			revealed.append(b)
			out.append(b)
	return out
