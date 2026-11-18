extends Node
## Balance simulator: plays the real game for days with a tidy bot (visits a few times a day, harvests everything,
## replants the crop that pays best until the next visit, plows as coins allow) and reports how fast the
## economy moves, what drops and how often, and what the weather does. Time is skipped, not waited for, so
## weeks take seconds. Change a number in data/balance.json (or pass `--set=section.name=value`) and run it again
## to see the effect before shipping it. Headless:
##   godot --headless --path . res://tools/balance_sim.tscn -- --days=14 --visits=3 --minutes=5 --seed=1 \
##     [--style=plain|goals|casual] [--away=3,7] [--first-hour] [--set=harvest.golden_chance=0.01]
## Styles (docs/PLAYER_EXPERIENCE.md Part 4): `plain` the field loop only; `goals` also does what the goal faces
## say (prefers the crops and things the open goals name, swaps a job it cannot do, collects every finished goal);
## `casual` follows goals at one visit a day and skips days 3 and 7 unless `--away` says which. `--away=3,7`: the
## days the bot does not come (1 is the first). `--first-hour`: one 60-minute first session from minute zero,
## played a minute at a time (with goals), then its numbers (first harvest, levels, coins, goals) and stop.
## Reads the real systems, so a rule change shows up here too. A test drives it on its own farm (`game`).

const SECONDS_PER_ACTION := 1.15   # the farmer works 0.75 s at each job and walks a little between them
const HOURS_DEFAULT := [8.0, 13.0, 20.0]     # local hours of the day the bot visits (with --visits=3)
const LOOKAHEAD_VISITS := 12   # how many visits ahead a crop may ripen in
const CASUAL_AWAY := [3, 7]    # the days a casual player skips when --away is not given
const FIRST_HOUR_MINUTES := 60
const FIRST_HOUR_MARKS := [10, 20, 30, 40, 60]   # minutes at which the first hour prints the level and coins

var game: GameState       # the farm it plays (the real one when run as a tool)
var style := "plain"      # plain, goals or casual
var away: Array = []      # days (1 = the first) the bot does not come
var goals_claimed := 0    # goals collected (chains, jobs, projects)
var chain_steps := 0      # story chain steps collected
var swaps := 0            # daily jobs swapped for one the bot can do
var _days := 14
var _visits := 3
var _seed := 1
var _drops := {}          # drop type -> count
var _harvests := 0
var _by_crop := {}        # crop id -> harvests
var _level_day := {}      # level -> day first reached
var _collected := 0
var _fed := 0
var _actions := 0         # what is left to do in this visit
var _minutes := 5.0       # how long a visit lasts
var _expansions := 0
var _bought := {}         # item id -> bought
var _cleared := 0         # plots cleared to make room for what a goal asks to buy or a vehicle
var _last_cleared := -1
var _spent := 0           # coins spent (every fall of the purse)
var _last_coins := 0
var _away_days := 0
var _keep := 0           # coins kept for what an open goal asks to buy (not spent on seeds)
var _want_plant := {}     # crops a goal asks to plant (planted even when no visit finds them ripe)
var _want := {}           # crop id -> plots a goal still wants planted with it (this visit)


func _ready() -> void:
	Season.active = false   # (the same in any month)
	var first_hour := false
	var away_given := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			_days = int(arg.get_slice("=", 1))
		elif arg.begins_with("--visits="):
			_visits = clampi(int(arg.get_slice("=", 1)), 1, 12)
		elif arg.begins_with("--minutes="):
			_minutes = float(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--style="):
			style = arg.get_slice("=", 1)
		elif arg.begins_with("--away="):
			away_given = true
			for d in arg.get_slice("=", 1).split(",", false):
				away.append(int(d))
		elif arg == "--first-hour":
			first_hour = true
		elif arg.begins_with("--set="):
			var kv := arg.get_slice("=", 1)
			var key := kv.get_slice("=", 0)
			var value := float(kv.get_slice("=", 1))
			Balance.override(key, int(value) if value == floorf(value) else value)
	if style == "casual":
		_visits = 1
		if not away_given:
			away = CASUAL_AWAY.duplicate()
	await get_tree().process_frame
	game = Game
	game.saving_enabled = false
	# The farm is made at the first visit's hour, as a player plays the moment they install: made earlier, the
	# clock then skipped to that hour (up to a day with one visit) and the starter's ripe plots withered unseen.
	game.debug_time_offset += _seconds_until(_visit_hours()[0], game.now())
	game.reset_game()
	game.rng.seed = _seed
	if first_hour:
		print("FIRST HOUR  seed=%d" % _seed)
		var r := play_first_hour()
		for line: String in r["lines"]:
			print(line)
		get_tree().quit()
		return
	print("BALANCE SIM  days=%d visits/day=%d minutes/visit=%.0f seed=%d style=%s away=%s" % [
		_days, _visits, _minutes, _seed, style, away])
	_play()
	_drop_table()
	_weather_table()
	get_tree().quit()


func _visit_hours() -> Array:
	if _visits == 3:
		return HOURS_DEFAULT
	var out := []
	for k in _visits:
		out.append(7.0 + 14.0 * k / maxf(_visits - 1, 1))
	return out


func follows_goals() -> bool:
	return style in ["goals", "casual"] and game.goals.active()


func _watch_coins() -> void:
	_last_coins = game.coins
	if not game.coins_changed.is_connected(_on_coins):
		game.coins_changed.connect(_on_coins)


func _on_coins(coins: int) -> void:
	if coins < _last_coins:
		_spent += _last_coins - coins
	_last_coins = coins


func _play() -> void:
	_watch_coins()
	var hours := _visit_hours()   # (the clock already stands at the first one: _ready)
	var start := game.now()
	print("day  level   coins  harvests  coins/h   spent  golden  collect  super  bonus  idle plots  goals  left  chain"
		+ "  fed")
	var coins_at_day_start := game.coins
	var harvests_at_day_start := 0
	for day in _days:
		var spent_at_day_start := _spent
		var goals_at_day_start := goals_claimed
		var fed_at_day_start := _fed
		var here := not away.has(day + 1)
		if not here:
			_away_days += 1
		for v in hours.size():
			if here:
				_visit(_visits_after(hours, v))
			game.debug_time_offset += int(_gap_after(hours, v) * 3600.0)
		var earned := game.coins - coins_at_day_start + _spent - spent_at_day_start
		print("%3d  %5d  %6d  %8d  %7.0f  %6d  %6d  %7d  %5d  %5d  %10d  %5d  %4d  %5d  %3d%s" % [
			day + 1, game.level(), game.coins, _harvests - harvests_at_day_start, earned / 24.0,
			_spent - spent_at_day_start, _drops.get("golden", 0), _drops.get("collectible", 0),
			_drops.get("super_harvest", 0), _drops.get("bonus_xp", 0), _idle_plots(),
			goals_claimed - goals_at_day_start, jobs_left(), chain_steps, _fed - fed_at_day_start, "" if here else "  (away)"])
		coins_at_day_start = game.coins
		harvests_at_day_start = _harvests
		for lvl in range(2, game.level() + 1):
			if not _level_day.has(lvl):
				_level_day[lvl] = day + 1
	print("elapsed game days: %.1f (away %d)" % [(game.now() - start) / 86400.0, _away_days])
	var marks := []
	for lvl: int in _level_day:
		if lvl % 5 == 0 or lvl == 2:
			marks.append("L%d on day %d" % [lvl, _level_day[lvl]])
	print("level pace: %s" % ", ".join(PackedStringArray(marks)))
	var crops := []
	for id: String in _by_crop:
		crops.append("%s x%d" % [id, _by_crop[id]])
	print("crops grown: %s" % ", ".join(PackedStringArray(crops)))
	var bought := []
	for id: String in _bought:
		bought.append("%s x%d" % [id, _bought[id]])
	print("bought: %s; land expanded %d times (farm %d x %d); collected %d; fed %d" % [
		", ".join(PackedStringArray(bought)), _expansions, game.farm_size, game.farm_size, _collected, _fed])
	print("goals collected %d (chain steps %d, jobs swapped %d); coins spent %d" % [
		goals_claimed, chain_steps, swaps, _spent])
	if follows_goals():
		var at := []
		for id: String in game.goals.chain_step:
			at.append("%s at step %d" % [id, int(game.goals.chain_step[id]) + 1])
		print("chains done: %s; open: %s; plots cleared for goals %d" % [", ".join(PackedStringArray(
			game.goals.chains_done)), ", ".join(PackedStringArray(at)), _cleared])


## Today's jobs still open (not collected) now: at a day's end, the jobs the day did not finish.
func jobs_left() -> int:
	var n := 0
	if follows_goals():
		for key in game.goals.open_keys():
			if key.begins_with("daily:"):
				n += 1
	return n


## The first session of a new farm, from minute zero: the bot plays a minute at a time for an hour (as a player
## who stays), following the goals, and notes when things first happen. Returns the numbers and printable lines:
## {first_harvest, first_buy, level_at (minute -> level), coins_at, minute_of_level (level -> minute), goals,
## stuck_minutes (minutes with an open goal and nothing done), chain_minutes (chain id -> the minute each of its
## steps was collected, in order: Part 2's minute-by-minute plan), lines}.
func play_first_hour() -> Dictionary:
	if style == "plain":
		style = "goals"
	_watch_coins()
	var out := {"first_harvest": -1, "first_buy": -1, "level_at": {}, "coins_at": {}, "minute_of_level": {},
		"goals": 0, "stuck_minutes": 0, "chain_minutes": {}, "lines": []}
	var per_minute := int(60.0 / SECONDS_PER_ACTION)
	var visit_minutes := _minutes   # (each minute is a short visit; later visits are the usual length)
	_minutes = per_minute * SECONDS_PER_ACTION / 60.0
	var later := []   # the real day's later visits after the first one (the session started at it)
	for t: float in _visits_after(_visit_hours(), 0):
		later.append(t)
	for m in FIRST_HOUR_MINUTES:
		var ahead := []
		for k in range(1, FIRST_HOUR_MINUTES - m):
			ahead.append(k * 60.0)
		for t: float in later:
			ahead.append(t - m * 60.0)   # the day's next visits, counted from this minute
		var harvests := _harvests
		var bought := _bought.duplicate()
		var level := game.level()
		var steps := game.goals.chain_step.duplicate()
		var done := game.goals.chains_done.duplicate()
		_visit(ahead)
		for id: String in steps:
			var now := int(game.goals.chain_step.get(id, -1))
			var gone := (game.goals.chain_of(id)["steps"] as Array).size() if (game.goals.chains_done.has(id)
				and not done.has(id)) else now
			for _s in range(int(steps[id]), gone):
				(out["chain_minutes"].get_or_add(id, []) as Array).append(m)
		if harvests == 0 and _harvests > 0 and out["first_harvest"] < 0:
			out["first_harvest"] = m
		if out["first_buy"] < 0 and bought != _bought:
			out["first_buy"] = m
		for l in range(level + 1, game.level() + 1):
			out["minute_of_level"][l] = m + 1
		if _actions >= int(_minutes * 60.0 / SECONDS_PER_ACTION) and not game.goals.open_keys().is_empty():
			out["stuck_minutes"] += 1   # nothing at all done this minute while goals wait
		game.debug_time_offset += 60
		if FIRST_HOUR_MARKS.has(m + 1):
			out["level_at"][m + 1] = game.level()
			out["coins_at"][m + 1] = game.coins
	_minutes = visit_minutes
	out["goals"] = goals_claimed
	var lines: Array = out["lines"]
	lines.append("first harvest at minute %d, first purchase at minute %d" % [out["first_harvest"], out["first_buy"]])
	var levels := []
	for l: int in out["minute_of_level"]:
		levels.append("L%d at %d" % [l, out["minute_of_level"][l]])
	lines.append("levels: %s" % ", ".join(PackedStringArray(levels)))
	for id: String in out["chain_minutes"]:
		lines.append("chain %s: steps collected at minutes %s" % [id, out["chain_minutes"][id]])
	var marks := []
	for at: int in FIRST_HOUR_MARKS:
		marks.append("%d min: L%d, %d coins" % [at, out["level_at"][at], out["coins_at"][at]])
	lines.append(" | ".join(PackedStringArray(marks)))
	lines.append("goals collected %d (chain steps %d, jobs swapped %d); idle minutes with goals open %d" % [
		goals_claimed, chain_steps, swaps, out["stuck_minutes"]])
	var crops := []
	for id: String in _by_crop:
		crops.append("%s x%d" % [id, _by_crop[id]])
	lines.append("harvested: %s; collected %d; bought: %s; open goals at the end: %s" % [
		", ".join(PackedStringArray(crops)), _collected,
		str(_bought), ", ".join(PackedStringArray(game.goals.open_keys()))])
	return out


## Seconds from `t` to the next time the local clock reads `hour` (0 when it reads it now).
static func _seconds_until(hour: float, t: int) -> int:
	return int(fposmod(hour - DayCycle.local_hour(t, DayCycle.device_bias_minutes()), 24.0) * 3600.0)


static func _gap_after(hours: Array, v: int) -> float:
	var next: float = hours[(v + 1) % hours.size()] + (24.0 if v + 1 >= hours.size() else 0.0)
	return next - float(hours[v])


## How long after visit `v` each of the next visits comes, in seconds (the real schedule: with two visits a
## day the gaps alternate, 14 and 10 hours, so the k-th visit is not k equal gaps on).
static func _visits_after(hours: Array, v: int) -> Array:
	var out := []
	var t := 0.0
	for k in LOOKAHEAD_VISITS:
		t += _gap_after(hours, (v + k) % hours.size())
		out.append(t * 3600.0)
	return out


## One visit: harvest what's ripe, plow what the coins reach, plant the best-paying crop for the time until
## a later visit finds it ripe.
func _visit(next_visits: Array) -> void:
	_actions = int(_minutes * 60.0 / SECONDS_PER_ACTION)
	if follows_goals():
		_claim_goals()   # yesterday's finished jobs first: the day's refresh replaces them
		game.goals.refresh()
		_swap_undoable()
	_place_gifts()
	_collect_ready()
	_feed_hungry()
	_claim_goals()
	_want_crops()
	for r in game.farm_size:
		for c in game.farm_size:
			var i := game.index_of(r, c)
			if game.is_occupied(i):
				continue
			match game.field.phase(i):
				GameState.Phase.RIPE:
					if _act():
						_record(game.field.harvest(i))
				GameState.Phase.WITHERED:
					if _act():
						game.field.plow(i)
	if follows_goals():
		_goal_buy()   # before replanting: an empty plot can still be cleared to make room for it
		_goal_vehicles()
	for r in game.farm_size:
		for c in game.farm_size:
			var i := game.index_of(r, c)
			if game.is_occupied(i):
				continue
			var ph := game.field.phase(i)
			var crop := _best_crop(next_visits)
			if crop == "":
				break   # nothing affordable that a later visit finds ripe: plowing now would only waste coins
			if ph == GameState.Phase.GRASS:
				if game.coins - _keep < Balance.i("economy.plow_cost") + int(game.crops[crop]["seed_cost"]) or not _act():
					continue
				game.field.plow(i)
				ph = game.field.phase(i)
			if ph == GameState.Phase.PLOWED:
				if _act() and not game.field.plant(i, crop):
					break   # out of coins: the rest wait for the next visit
				if _want.has(crop):
					_want[crop] = int(_want[crop]) - 1
					if int(_want[crop]) <= 0:
						_want_plant.erase(crop)
	_claim_goals()
	_spend()
	_claim_goals()


## Collects every finished goal (a claim can open the next step, which may be done already).
func _claim_goals() -> void:
	if not follows_goals():
		return
	var again := true
	while again:
		again = false
		for key in game.goals.open_keys():
			if game.goals.is_done(key):   # (a tap on a face: never left for want of time)
				game.goals.claim(key)
				goals_claimed += 1
				if key.begins_with("chain:"):
					chain_steps += 1
				again = true
				break


## The open goals' tasks not yet done: [{do, what, n}, ...].
func _open_tasks() -> Array:
	var out := []
	if not follows_goals():
		return out
	for key in game.goals.open_keys():
		var tasks := game.goals.tasks_of(key)
		var prog := game.goals.progress_of(key)
		for t in tasks.size():
			if t < prog.size() and prog[t][0] < prog[t][1]:
				out.append((tasks[t] as Dictionary).merged({"left": int(prog[t][1]) - int(prog[t][0])}, true))
	return out


## The crops the open goals name for planting or harvesting, and how many more plots each still needs.
func _want_crops() -> void:
	_want = {}
	_want_plant = {}
	_keep = 0
	var growing := {}   # crop id -> plots growing it (a harvest goal counts them already)
	for i in game.plots.size():
		var p: Dictionary = game.plots[i]
		if game.on_farm(i) and p.get("state") == "planted":
			growing[str(p["crop"])] = int(growing.get(str(p["crop"]), 0)) + 1
	for task: Dictionary in _open_tasks():
		var id := str(task.get("what", ""))
		if str(task["do"]) in ["buy", "own", "build"] and game.items.has(id):
			_keep += int(game.buildings.price_of(id).get("coins", 0))
		if not game.crops.has(id):
			continue
		var left := int(task["left"])
		match str(task["do"]):
			"plant":
				_want[id] = maxi(int(_want.get(id, 0)), left)
				_want_plant[id] = true
			"harvest":
				_want[id] = maxi(int(_want.get(id, 0)), left - int(growing.get(id, 0)))


## Swaps today's job the bot's farm cannot do (a recipe with no building to craft in, an animal it has not got).
func _swap_undoable() -> void:
	for i in game.goals.daily_jobs.size():
		if game.goals.daily_claimed[i] or game.goals.is_done("daily:%d" % i):
			continue
		var job: Dictionary = game.goals.daily_jobs[i]
		var what := str(job.get("what", ""))
		var cannot := false
		match str(job["do"]):
			"craft", "start_craft":
				cannot = not game.crafting.owns_crafting()
			"collect", "feed":
				cannot = what != "" and game.goals.own_count(what) == 0
		if cannot and game.goals.swap_daily(i):
			swaps += 1


## Buys what an open goal asks to buy or own, when the coins reach (before the bot's own spending): the thing
## itself, or for a kind ("own 6 trees") the cheapest of that kind on sale. When nothing fits, an empty plot is
## cleared to make room (as a player clears one with Sell).
func _goal_buy() -> void:
	for task: Dictionary in _open_tasks():
		if not str(task["do"]) in ["buy", "own", "build"]:
			continue
		var id := _goal_item(str(task.get("what", "")))
		if id == "" or not game.buildings.can_buy(id).ok():
			continue
		if not _buy_somewhere(id) and _clear_a_plot():
			_buy_somewhere(id)
		return


## Buys `id` on the first free spot from the back of the farm. False when nothing fits.
func _buy_somewhere(id: String) -> bool:
	for r in range(game.farm_size - 1, -1, -1):
		for c in range(game.farm_size - 1, -1, -1):
			if game.can_place(id, r, c):
				if _act() and game.buy_and_place(id, r, c):
					_bought[id] = int(_bought.get(id, 0)) + 1
				return true
	return false


## The item a goal's `what` asks for: itself, or the cheapest coin-bought one of a kind the farm can buy now.
func _goal_item(what: String) -> String:
	if game.items.has(what):
		return what
	var best := ""
	var best_cost := INF
	for id: String in game.items:
		var it: Dictionary = game.items[id]
		var cost := int(game.buildings.price_of(id).get("coins", 0))
		if str(it.get("kind", "")) == what and cost > 0 and cost < best_cost and game.buildings.can_buy(id).ok():
			best = id
			best_cost = cost
	return best


## Clears one plot that grows nothing (plowed or withered) at the back of the farm. True when one was cleared.
func _clear_a_plot() -> bool:
	for r in range(game.farm_size - 1, -1, -1):
		for c in range(game.farm_size - 1, -1, -1):
			var i := game.index_of(r, c)
			if game.is_occupied(i) or game.plots[i].get("state") == "planted":
				continue
			if game.field.phase(i) != GameState.Phase.GRASS and _act() and game.field.clear_plot(i):
				_cleared += 1
				_last_cleared = i
				return true
	return false


## Sends a vehicle on a goal's run ("plow 10 plots with the Tractor"): old plots that grow nothing are cleared
## first when the farm has no grass left (as a player clears them with Sell), then the run starts on the grass.
func _goal_vehicles() -> void:
	for task: Dictionary in _open_tasks():
		if str(task["do"]) != "vehicle_work":
			continue
		for id in game.vehicles.usable_vehicles():
			if not game.goals.matches(str(task.get("what", "")), id) or game.vehicles.is_running(id):
				continue
			var grass := []
			for i in game.plots.size():
				if game.on_farm(i) and not game.is_occupied(i) and game.field.phase(i) == GameState.Phase.GRASS:
					grass.append(i)
			while grass.size() < int(task["left"]) and _clear_a_plot():
				grass.append(_last_cleared)
			if not grass.is_empty() and _act():
				game.vehicles.use_vehicle(id, GameState.row_of(grass[0]), GameState.col_of(grass[0]))
			return


## Places the things waiting in the inbox that a goal gave (the Welcome chain's chicken), as a player taps Place.
func _place_gifts() -> void:
	if not follows_goals():
		return
	for item: Dictionary in game.social.inbox.duplicate():
		if str(item["give"].get("what", "")) != InboxItem.ITEM or not _act():
			continue
		var id := str(item["give"].get("id", ""))
		if not game.social.claim(int(item["id"]), true):
			continue
		var at := game.storage.stored.size() - 1
		for r in range(game.farm_size - 1, -1, -1):
			for c in game.farm_size:
				if game.can_place(id, r, c) and game.storage.place_from_storage(at, r, c):
					return


## One thing the farmer does (a harvest, a plow, a planting, a collection, a purchase); the visit has only so many.
func _act() -> bool:
	if _actions <= 0:
		return false
	_actions -= 1
	return true


func _collect_ready() -> void:
	for o in game.objects.duplicate():
		if game.kind_of(o) in ["tree", "animal", "bloom"] and game.is_ready(o):
			if not _act():
				return
			var got := game.collect(int(o["uid"]))
			if not got.is_empty():
				_collected += 1


## Feeds what is hungry with the best feed in stock (an action each, like a player's tap): without it every animal
## pays the hunger penalty and the simulated farm earns less than a played one.
func _feed_hungry() -> void:
	for o in game.objects.duplicate():
		if not game.feeds.is_hungry(o) or game.is_ready(o):
			continue
		var pick := game.feeds.best_feed_for(o)
		if pick.is_empty() or not _act():
			continue
		if not game.feeds.feed(int(o["uid"]), str(pick["feed"]), "produce", bool(pick["rich"])).is_empty():
			_fed += 1


## One building per visit at most: the dearest the farm can buy now (homes, cottages, the barn's neighbours), so
## the coin sinks of the real game show in the curve instead of coins piling up.
func _buy_building(reserve: int) -> void:
	var best := ""
	var best_cost := 0
	for id: String in game.items:
		var it: Dictionary = game.items[id]
		# Buildings only, and not those built from collected materials (the bot never finishes a frame).
		if game.building_def(id) == null or it.has("status") or it.has("build_materials") or id == "barn":
			continue
		var price := game.buildings.price_of(id)
		var cost := int(price.get("coins", 0))
		if price.has("gems"):
			continue
		if cost <= 0 or cost + reserve > game.coins or cost <= best_cost or not game.buildings.can_buy(id).ok():
			continue
		best = id
		best_cost = cost
	if best == "":
		return
	for r in range(game.farm_size - 1, -1, -1):
		for c in range(game.farm_size - 1, -1, -1):
			if game.can_place(best, r, c) and game.buy_and_place(best, r, c):   # a tap at the end of the visit
				_bought[best] = int(_bought.get(best, 0)) + 1
				return


## Spends what's above a reserve for replanting: land first when it can be bought, then whichever tree or
## animal pays back soonest, on free ground at the back of the farm (never more than a quarter of the farm).
func _spend() -> void:
	var reserve := 300
	_goal_buy()
	while game.land.can_expand_with_coins() and game.coins >= int(game.land.next_expansion()["coins"]) + reserve:
		if not game.land.expand(false):
			break
		_expansions += 1
	_buy_building(reserve)
	var held := 0
	for o in game.objects:
		if game.kind_of(o) in ["tree", "animal"]:
			held += 1
	if held >= game.farm_size * game.farm_size / 4:
		return
	var best := ""
	var best_payback := INF
	for id: String in game.items:
		var it: Dictionary = game.items[id]
		if not str(it.get("kind", "")) in ["tree", "animal"] or int(it.get("cost", 0)) <= 0:
			continue
		if it.get("stray_only", false):
			continue
		if game.level() < int(it.get("unlock_level", 1)) or int(it["cost"]) + reserve > game.coins:
			continue
		var days := float(it.get("cycle_seconds", 86400)) / 86400.0
		var payback := float(it["cost"]) / maxf(float(it.get("payout", 1)) / days, 0.01)
		if payback < best_payback:
			best_payback = payback
			best = id
	if best == "":
		return
	for r in range(game.farm_size - 1, -1, -1):
		for c in range(game.farm_size - 1, -1, -1):
			if game.can_place(best, r, c) and _act() and game.buy_and_place(best, r, c):
				_bought[best] = int(_bought.get(best, 0)) + 1
				return


func _record(h: Dictionary) -> void:
	if h.is_empty():
		return
	_harvests += 1
	var t := str(h.get("drop", ""))
	if t != "":
		_drops[t] = int(_drops.get(t, 0)) + 1
	var crop := str(h.get("crop", ""))
	_by_crop[crop] = int(_by_crop.get(crop, 0)) + 1


## The crop with the best profit per second it takes, counting the wait until the next visit as time spent,
## that will be ripe at the next visit and not yet withered (a crop withers as long after ripening as it took to
## grow, so a player who visits once a day can't use a 12-hour crop: it's gone by the next visit).
func _best_crop(next_visits: Array) -> String:
	var best := ""
	var best_rate := -INF
	for id: String in game.crops:
		var crop: Dictionary = game.crops[id]
		if not game.can_plant(id) or int(crop["seed_cost"]) > game.coins - _keep:
			continue
		var grow := float(crop["grow_seconds"])
		var window := float(game.field.ripe_window(crop))
		# The first visit that finds it ripe and not yet withered.
		var wait := 0.0
		for at: float in next_visits:
			if grow <= at and at < grow + window:
				wait = at
				break
		if wait == 0.0 and _want_plant.has(id):
			wait = grow   # a goal asks to plant it: planted, whatever comes of it
		if wait == 0.0:
			continue   # always ripens between visits and withers before the next
		var rate := (float(crop["sell_price"]) - float(crop["seed_cost"])) / wait
		if int(_want.get(id, 0)) > 0:
			rate += 1e9   # a goal's crop first, as many plots as the goal still needs
		if rate > best_rate:
			best_rate = rate
			best = id
	return best


func _idle_plots() -> int:
	var n := 0
	for r in game.farm_size:
		for c in game.farm_size:
			var i := game.index_of(r, c)
			if not game.is_occupied(i) and game.field.phase(i) in [GameState.Phase.GRASS, GameState.Phase.PLOWED]:
				n += 1
	return n


## What the drop rolls really give over many harvests, against what the numbers say.
func _drop_table() -> void:
	print("\nDROPS per 1000 harvests (100000 rolls each, the real rolls; golden and collectibles have pity counters)")
	print("stars  golden  collect  bird  super  bonus")
	var crop := ""
	for id: String in game.crops:
		if not game.crops[id].get("flower", false):
			crop = id
			break
	for stars in 4:
		var counts := {}
		for k in 100000:
			var d := game.drops.roll_drop(crop, stars, 1)
			var t := str(d.get("type", ""))
			counts[t] = int(counts.get(t, 0)) + 1
		var per := func(kind: String) -> float: return counts.get(kind, 0) / 100.0
		print("%5d  %6.1f  %7.1f  %4.1f  %5.1f  %5.1f" % [stars, per.call("golden"), per.call("collectible"),
			per.call("bird"), per.call("super_harvest"), per.call("bonus_xp")])


func _weather_table() -> void:
	print("\nWEATHER over 20000 blocks (share of time, mean spell in blocks, longest spell)")
	var t0 := 1_800_000_000 - 1_800_000_000 % Weather.block()
	var odds: Dictionary = Balance.d("weather.odds")
	for season: String in odds:
		var count := {}
		var runs := 0
		var longest := 0
		var run := 0
		var last := ""
		for b in 20000:
			var s := Weather.state_at(t0 + b * Weather.block(), season, fposmod(12.0 + b * 3.0, 24.0))
			count[s] = int(count.get(s, 0)) + 1
			if s == last:
				run += 1
			else:
				runs += 1
				run = 1
			longest = maxi(longest, run)
			last = s
		var parts := []
		for s: String in Weather.STATES:
			if count.has(s):
				parts.append("%s %.0f%%" % [s, count[s] / 200.0])
		print(
			"%-7s %s | spell %.1f, longest %d" % [season, ", ".join(PackedStringArray(parts)), 20000.0 / runs, longest]
		)
