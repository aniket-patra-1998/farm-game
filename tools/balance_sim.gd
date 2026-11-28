extends Node
## Balance simulator: plays the real game for days with a tidy bot (visits a few times a day, harvests everything,
## replants the crop that pays best until the next visit, plows as coins allow) and reports how fast the
## economy moves, what drops and how often, and what the weather does. Time is skipped, not waited for, so
## weeks take seconds. Change a number in data/balance.json (or pass `--set=section.name=value`) and run it again
## to see the effect before shipping it. Headless:
##   godot --headless --path . res://tools/balance_sim.tscn -- --days=14 --visits=3 --minutes=5 --seed=1 \
##     [--style=plain|goals|casual|builder|crafter] [--away=3,7] [--no-feed] [--first-hour] \
##     [--set=harvest.golden_chance=0.01]
## Styles (docs/PLAYER_EXPERIENCE.md Part 4): `plain` the field loop only; `goals` also does what the goal faces
## say (prefers the crops and things the open goals name, swaps a job it cannot do, collects every finished goal);
## `casual` follows goals at one visit a day and skips days 3 and 7 unless `--away` says which. `--away=3,7`: the
## days the bot does not come (1 is the first). `builder` follows goals and, at each visit's end, also buys the
## Market's progress buys it can afford (market_wants: cheapest first, at most BUILDER_BUYS a visit; frames that
## need materials are left, the bot never finishes one): does a player who buys keep idle coins down?
## `crafter` follows goals, builds the Bakery (the first crafting building, coins) as soon as it unlocks and crafts
## at every visit: finishes what is done, sells the goods, starts the best-paying recipe it has the bushels for
## (buying the few missing ones at the Farmers Market stall); its `crafting:` line says what the building cost and
## how many days of crafting paid it back (Part 4: about CRAFT_PAYBACK_DAYS).
## `--no-feed`: the bot never feeds (Part 4: a never-feeder loses at most FEED_LOSS_MAX of animal income and nothing
## else; compare its `animals:` line with a feeding run's). Every run reports what a stretch of away days lost
## (animals, trees and buildings gone; Part 4: a week away loses nothing).
## `--first-hour`: one 60-minute first session from minute zero, played a minute at a time (with goals), then
## its numbers (first harvest, levels, coins, goals) and stop.
## Reads the real systems, so a rule change shows up here too. A test drives it on its own farm (`game`).

const SECONDS_PER_ACTION := 1.15   # the farmer works 0.75 s at each job and walks a little between them
const HOURS_DEFAULT := [8.0, 13.0, 20.0]     # local hours of the day the bot visits (with --visits=3)
const LOOKAHEAD_VISITS := 12   # how many visits ahead a crop may ripen in
const CASUAL_AWAY := [3, 7]    # the days a casual player skips when --away is not given
const FIRST_HOUR_MINUTES := 60
const BUILD_ROWS := 5        # the back rows a grown farm keeps for buildings (BalanceSim._kept_for_building)
const BUILD_FROM_SIZE := 16   # the farm size from which it does
const SIM_START := 1793491200   # 1 Nov 2026, 00:00 UTC (the tests' season): every run's first day (new_farm)
const UPGRADE_SPARE := 3   # the bot grows a building only with this many times its price to spare (jobs first)
const REPAIR_AT := 2   # the wear level the bot repairs at (a careful player: before it costs much)
const NEVER := 999        # a level or moment the run never reached (a target's "at most" then misses)
const FIRST_HOUR_MARKS := [10, 20, 30, 40, 60]   # minutes at which the first hour prints the level and coins
const WANT_VISITS := [1.0, 3.0]   # Part 4's "something to buy": a thing costing 1 to 3 visits of income
const IDLE_VISITS_MAX := 5.0      # Part 4: idle coins stay under about 5 visits of income
const BUILDER_BUYS := 3          # purchases a builder makes at a visit's end (a tap or two each)
const FEED_LOSS_MAX := 0.3        # Part 4: a never-feeder loses at most this share of animal income
const CRAFTER_BUILDING := "bakery"   # Part 4: "the crafter builds the Bakery early and crafts"
const CRAFT_PAYBACK_DAYS := 7.0   # Part 4: a crafting building pays back in about a week of normal crafting
const STALL_BUY_MOST := 4         # bushels a crafter buys at the stall to finish one recipe (more: wait for harvests)
const WANT_SKIP_KINDS := ["decor", "crop", "material", "ingredient", "recipe", "young"]   # not progress buys

var game: GameState       # the farm it plays (the real one when run as a tool)
var style := "plain"      # plain, goals, casual, builder or crafter
var away: Array = []      # days (1 = the first) the bot does not come
var goals_claimed := 0    # goals collected (chains, jobs, projects)
var chain_steps := 0      # story chain steps collected
var swaps := 0            # daily jobs swapped for one the bot can do
var no_feed := false      # --no-feed: never feeds
var animal_coins := 0     # coins from collecting animals and their homes (the feeding target's measure)
var animal_collects := 0
var animal_base := 0.0    # what those collects pay unfed-and-unboosted (coins / the feed multiplier)
var away_from := -1       # what lasted (_lasting) when the current away stretch began; -1: here
var away_lost := 0        # animals, trees and buildings gone across away stretches (Part 4: none)
var craft_built_day := -1   # the day (1 = the first) the crafter's building went up; -1: not yet
var craft_cost := 0         # what it cost
var craft_made := 0         # goods finished
var craft_coins := 0        # coins from selling them
var craft_worth := 0        # what their ingredients would have sold for at the Market
var craft_stall_spent := 0  # coins spent on bushels at the stall
var _day := 0               # the day being played (0 = the first)
var _craft_crops := {}      # once the crafter's building stands: the crops its unlocked recipes use (all it plants)
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
var _repairs := 0           # building repairs (docs/WEAR.md) and what they cost
var _repair_coins := 0
var _upgrades := 0          # building sizes grown and what they cost
var _upgrade_coins := 0
var _earned := 0            # coins earned in all (upkeep's share of it)
var _late_earned := 0       # the same in the run's last third (the farm grown: upkeep's steady share)
var _late_repairs := 0
var _bought := {}         # item id -> bought
var _cleared := 0         # plots cleared to make room for what a goal asks to buy or a vehicle
var _last_cleared := -1
var _spent := 0           # coins spent (every fall of the purse)
var _last_coins := 0
var _gems_earned := 0     # gems gained (every rise; Part 4: a free player earns a few a week)
var _last_gems := 0
var _away_days := 0
var _keep := 0           # coins kept for what an open goal asks to buy (not spent on seeds)
var _want_plant := {}     # crops a goal asks to plant (planted even when no visit finds them ripe)
var _want := {}           # crop id -> plots a goal still wants planted with it (this visit)
var _market_days := 0     # days measured against Part 4's Market targets (a day the bot came and earned)
var _want_days := 0       # of those, days the Market held 1 to 3 things costing 1 to 3 visits of income
var _per_visit := 0.0     # yesterday's income per visit (the builder's sense of what a thing costs)
var _last_wants := []    # what the Market held on the last day measured (market_wants)
var _stuck_days := 0      # days that ended unable to plant: too few coins for seeds and nothing growing
var _strays_week := 0     # most strays that came in any week (StraySystem.this_week)
var _idle_days := 0       # of those, days that ended with idle coins over IDLE_VISITS_MAX visits of income


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
		elif arg == "--no-feed":
			no_feed = true
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
	new_farm()
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


## A new farm made at the first visit's hour, as a player plays the moment they install: made earlier, the clock
## then skipped to that hour (up to a day with one visit) and the starter's ripe plots withered unseen. The farm is
## made now and the clock set back to the last time it read that hour; the game moves every timer with it, as for a
## device clock set back (Persistence.watch_clock). (Moving the clock on before Game.reset_game did nothing: the
## reset sets the clock back to the device's, so the first visit fell at whatever hour the run started.)
func new_farm() -> void:
	# Every run starts on the same date (SIM_START) whenever it runs: seasons, weather and day turns follow the
	# calendar, so a run started on another day played another game (the audit gave 31% and 4% upkeep for one seed).
	# The farm is made on that date, not moved there.
	game.debug_time_offset += SIM_START - game.now()
	game.keep_clock = true
	game.reset_game()
	game.keep_clock = false
	game.persistence.forget_clock()   # (the jump to SIM_START is not a clock set back: nothing is moved for it)
	game.persistence.watch_clock()
	var hour := DayCycle.local_hour(game.now(), DayCycle.device_bias_minutes())
	var back := int(fposmod(hour - float(_visit_hours()[0]), 24.0) * 3600.0)
	game.persistence.watch_clock()   # (it knows the new farm's time first)
	game.debug_time_offset -= back
	game.persistence.watch_clock()


## Whether the day being played is in the run's last third: wear has had time to build up (14 days' grace, then
## a level every 10), so upkeep is measured there, not over a start that has none.
func _late() -> bool:
	return _day >= _days * 2 / 3


func follows_goals() -> bool:
	return style in ["goals", "casual", "builder", "crafter"] and game.goals.active()


func _watch_coins() -> void:
	_last_coins = game.coins
	if not game.coins_changed.is_connected(_on_coins):
		game.coins_changed.connect(_on_coins)
	_last_gems = game.gems
	if not game.gems_changed.is_connected(_on_gems):
		game.gems_changed.connect(_on_gems)


func _on_coins(coins: int) -> void:
	if coins < _last_coins:
		_spent += _last_coins - coins
	_last_coins = coins


func _on_gems(gems: int) -> void:
	if gems > _last_gems:
		_gems_earned += gems - _last_gems
	_last_gems = gems


func _play() -> void:
	_watch_coins()
	var hours := _visit_hours()   # (the clock already stands at the first one: _ready)
	var start := game.now()
	print("day  level   coins  harvests  coins/h   spent  golden  collect  super  bonus  idle plots  goals  left  chain"
		+ "  fed  idle_v  want")
	var coins_at_day_start := game.coins
	var harvests_at_day_start := 0
	for day in _days:
		_day = day
		var spent_at_day_start := _spent
		var goals_at_day_start := goals_claimed
		var fed_at_day_start := _fed
		var here := not away.has(day + 1)
		if not here:
			_away_days += 1
			if away_from < 0:
				away_from = _lasting()
		elif away_from >= 0:
			away_lost += maxi(0, away_from - _lasting())
			away_from = -1
		for v in hours.size():
			if here:
				_visit(_visits_after(hours, v))
			game.debug_time_offset += int(_gap_after(hours, v) * 3600.0)
		var earned := game.coins - coins_at_day_start + _spent - spent_at_day_start
		_earned += maxi(0, earned)
		if _late():
			_late_earned += maxi(0, earned)
		var per_visit := float(earned) / float(hours.size())
		# Idle: coins left over after everything worth having that is on offer now, once each (owner, 19 Nov: the
		# late game too easy). Coins held for things on offer are being saved, not idle; the bot's own thrift is
		# not the game's fault.
		var idle_v := float(maxi(0, game.coins - spendable())) / per_visit if per_visit > 0.0 else 0.0
		if per_visit > 0.0:
			_per_visit = per_visit
		var wants := market_wants(per_visit) if per_visit > 0.0 else []
		if here and per_visit > 0.0:
			_market_days += 1
			_last_wants = wants
			if wants.size() >= 1:
				_want_days += 1
			if idle_v > IDLE_VISITS_MAX:
				_idle_days += 1
		print("%3d  %5d  %6d  %8d  %7.0f  %6d  %6d  %7d  %5d  %5d  %10d  %5d  %4d  %5d  %3d  %6.1f  %4d%s" % [
			day + 1, game.level(), game.coins, _harvests - harvests_at_day_start, earned / 24.0,
			_spent - spent_at_day_start, _drops.get("golden", 0), _drops.get("collectible", 0),
			_drops.get("super_harvest", 0), _drops.get("bonus_xp", 0), _idle_plots(),
			goals_claimed - goals_at_day_start, jobs_left(), chain_steps, _fed - fed_at_day_start, idle_v, wants.size(),
			"" if here else "  (away)"])
		coins_at_day_start = game.coins
		harvests_at_day_start = _harvests
		if here and game.coins < game.coins_to_plant() and not (game.any_plot_in(GameState.Phase.GROWING)
				or game.any_plot_in(GameState.Phase.RIPE)):
			_stuck_days += 1
		_strays_week = maxi(_strays_week, game.strays.this_week())
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
	print("upkeep: %d repairs, %d coins; %d upgrades, %d coins; repairs %.0f%% of coins earned (%.0f%% in the last third)"
		% [_repairs, _repair_coins, _upgrades, _upgrade_coins, 100.0 * _repair_coins / maxf(1.0, _earned),
		100.0 * _late_repairs / maxf(1.0, _late_earned)])
	print(market_line())
	print(targets_line(_days, metrics()))
	print(feed_line())
	if style == "crafter":
		print(craft_line())
	print("gems earned %d (%.1f a week), held %d" % [_gems_earned, _gems_earned * 7.0 / maxf(_days, 1), game.gems])
	if follows_goals():
		var at := []
		for id: String in game.goals.chain_step:
			at.append("%s at step %d" % [id, int(game.goals.chain_step[id]) + 1])
		print("chains done: %s; open: %s; plots cleared for goals %d" % [", ".join(PackedStringArray(
			game.goals.chains_done)), ", ".join(PackedStringArray(at)), _cleared])
		print("projects done: %s; open: %s" % [", ".join(PackedStringArray(game.goals.projects_done)),
			game.goals.project_stage])


## What lasts on a farm: animals, trees and buildings (a week away must not lose one).
func _lasting() -> int:
	var n := 0
	for o in game.objects:
		if game.kind_of(o) in ["animal", "tree", "building"]:
			n += 1
	return n


## Part 4's feeding and away targets: animal coins (compare a --no-feed run's with a feeding run's: at most
## FEED_LOSS_MAX less), what was fed, and what away stretches lost.
func feed_line() -> String:
	return "animals: coins %d from %d collects (x%.2f of the plain price), fed %d%s; lost while away %d" % [
		animal_coins, animal_collects, animal_share(), _fed, " (never feeds)" if no_feed else "", away_lost]


## Animal coins as a share of what the same collects pay at the plain price (1: neither fed nor hungry): a
## never-feeder's is 1 - hunger_penalty; a feeder's says how much feeding adds.
func animal_share() -> float:
	return animal_coins / animal_base if animal_base > 0.0 else 1.0


## Part 4's Market targets over the days measured: the share of days with something to buy (1 to 3 visits of
## income) and of days ending with idle coins over IDLE_VISITS_MAX visits of income.
## What the run measured, by the names data/sim_targets.json checks (an audit's view of the economy).
func metrics() -> Dictionary:
	var n := maxi(_market_days, 1)
	var m := {"idle_days_pct": 100.0 * _idle_days / n, "want_days_pct": 100.0 * _want_days / n,
		"upkeep_pct": 100.0 * _late_repairs / maxf(1.0, _late_earned), "stuck_days": _stuck_days, "away_lost": away_lost,
		"strays_week_most": _strays_week, "gems_per_week": _gems_earned * 7.0 / maxf(_days, 1)}
	for lvl: int in [3, 10, 20]:
		m["level%d_day" % lvl] = int(_level_day.get(lvl, NEVER))
	if follows_goals():
		m["projects_open"] = game.goals.project_stage.size()
	if style == "crafter" and not _crafting_home().is_empty():
		m["craft_payback_days"] = craft_payback_days()
	return m


## The run against data/sim_targets.json: "targets: all met" or every one missed, so an audit can't read past a
## broken economy as a figure (owner, 19 Nov: "nothing should get missed by the audit bot").
func targets_line(days: int, measured: Dictionary, first_hour := false) -> String:
	var missed: Array[String] = []
	var checked := 0
	for rule: Dictionary in (game.read_json("res://data/sim_targets.json").get("targets", []) as Array):
		var key := str(rule["metric"])
		if bool(rule.get("first_hour", false)) != first_hour or not measured.has(key):
			continue
		if days < int(rule.get("min_days", 0)) or (rule.has("styles") and not (rule["styles"] as Array).has(style)):
			continue
		checked += 1
		var v := float(measured[key])
		if (rule.has("most") and v > float(rule["most"])) or (rule.has("least") and v < float(rule["least"])):
			missed.append("%s %s (target %s%s)" % [key, str(snappedf(v, 0.1)), "at most " if rule.has("most")
				else "at least ", str(rule.get("most", rule.get("least")))])
	if missed.is_empty():
		return "targets: all %d met" % checked
	return "TARGETS MISSED (%d of %d): %s" % [missed.size(), checked, "; ".join(PackedStringArray(missed))]


func market_line() -> String:
	var n := maxi(_market_days, 1)
	return ("market: something to buy on %d%% of days, idle coins over %.0f visits on %d%% (of %d days measured);"
		+ " the last day's: %s") % [100 * _want_days / n, IDLE_VISITS_MAX, 100 * _idle_days / n, _market_days,
		", ".join(PackedStringArray(_last_wants))]


## The coins everything worth having that is on offer now would take, each once: what the Market sells for
## progress (as market_wants, any price the purse covers), the next land, every building's next size and every
## crafting star (an audit's measure of whether coins have anything left to go to).
func spendable() -> int:
	var total := 0
	for id: String in game.items:
		var it: Dictionary = game.items[id]
		if str(it.get("kind", "")) in WANT_SKIP_KINDS or int(it.get("unlock_level", 1)) >= 99 or not Release.has(id) \
				or it.get("stray_only", false):
			continue
		var price := game.buildings.price_of(id)
		if not price.has("gems") and game.buildings.can_buy(id).why in [BuildingSystem.Why.OK, BuildingSystem.Why.COINS]:
			total += int(price.get("coins", 0))
	var step := game.land.next_expansion()
	if not step.is_empty() and game.level() >= int(step["level"]) and not step.has("gems_only"):
		total += int(step.get("coins", 0))
	for o in game.objects:
		if game.is_building_item(str(o["id"])) and not game.under_construction(o):
			total += game.land.expansion_coins(o)
			if game.crafting.is_crafting(o):
				total += int(game.crafting.star_cost(o).get("coins", 0))
	return total


## What the Market holds now that a player would buy for progress (homes, buildings, trees, animals, vehicles,
## the next land; not decorations, seeds or materials) costing WANT_VISITS of `per_visit` income: ids (land is
## "land"). Level, limit and requirements must be met; only the coins may be short.
func market_wants(per_visit: float) -> Array:
	var out := []
	var low := WANT_VISITS[0] * per_visit
	var high := WANT_VISITS[1] * per_visit
	for id: String in game.items:
		var it: Dictionary = game.items[id]
		if str(it.get("kind", "")) in WANT_SKIP_KINDS or int(it.get("unlock_level", 1)) >= 99 or not Release.has(id):
			continue
		if it.get("stray_only", false):
			continue
		var price := game.buildings.price_of(id)
		if price.has("gems"):
			continue
		var cost := float(price.get("coins", 0))
		if cost < low or cost > high:
			continue
		var why := game.buildings.can_buy(id).why
		if why == BuildingSystem.Why.OK or why == BuildingSystem.Why.COINS:
			out.append(id)
	var step := game.land.next_expansion()
	if not step.is_empty() and game.level() >= int(step["level"]) and not step.has("gems_only"):
		var land := float(step.get("coins", 0))
		if land >= low and land <= high:
			out.append("land")
	# Part 4's wants include upgrades ("the next home, an upgrade, a tree"): a building's next size and a crafting
	# star count as things to buy (they were left out, so a farm that owned every building read as wanting nothing).
	for o in game.objects:
		if not game.is_building_item(str(o["id"])) or game.under_construction(o):
			continue
		var size := float(game.land.expansion_coins(o))
		if size >= low and size <= high:
			out.append("size:" + str(o["id"]))
		if game.crafting.is_crafting(o):
			var star := float(game.crafting.star_cost(o).get("coins", 0))
			if star >= low and star <= high:
				out.append("star:" + str(o["id"]))
	return out


## The builder's shopping: the Market's progress buys it can afford now, cheapest first (land through expanding),
## skipping frames built from materials; at most BUILDER_BUYS a visit.
func _buy_wants() -> void:
	if _per_visit <= 0.0:
		return
	var wants := market_wants(_per_visit)
	wants.sort_custom(func(a: String, b: String) -> bool: return _want_cost(a) < _want_cost(b))
	var bought := 0
	for id: String in wants:
		if bought >= BUILDER_BUYS or _want_cost(id) > game.coins:
			break
		if id.contains(":"):
			continue   # (a size or a star: _upkeep grows buildings)
		if id == "land":
			if game.land.expand(false):
				_expansions += 1
				bought += 1
			continue
		if game.items[id].has("build_materials"):
			continue
		_actions += 1   # (a purchase is a tap of its own, after the visit's field work)
		if _buy_somewhere(id):
			bought += 1


func _want_cost(id: String) -> int:
	if id == "land":
		return int(game.land.next_expansion().get("coins", 0))
	return int(game.buildings.price_of(id).get("coins", 0))


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
## steps was collected, in order: Part 2's minute-by-minute plan), first_find (the minute of the first find),
## project_open (project id -> the minute it opened), lines}.
func play_first_hour() -> Dictionary:
	if style == "plain":
		style = "goals"
	_watch_coins()
	var out := {"first_harvest": -1, "first_buy": -1, "first_find": -1, "project_open": {}, "level_at": {},
		"coins_at": {}, "minute_of_level": {}, "goals": 0, "stuck_minutes": 0, "chain_minutes": {}, "lines": []}
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
		if out["first_find"] < 0 and not game.finds.owned.is_empty():
			out["first_find"] = m
		for id: String in game.goals.project_stage:
			if not out["project_open"].has(id):
				out["project_open"][id] = m
		if out["first_buy"] < 0 and bought != _bought:
			out["first_buy"] = m
		for l in range(level + 1, game.level() + 1):
			out["minute_of_level"][l] = m + 1
		if _actions >= int(_minutes * 60.0 / SECONDS_PER_ACTION) and not game.goals.open_keys().is_empty() \
				and not game.any_plot_in(GameState.Phase.GROWING):
			out["stuck_minutes"] += 1   # nothing done this minute while goals wait, and nothing growing to wait for
		game.debug_time_offset += 60
		if FIRST_HOUR_MARKS.has(m + 1):
			out["level_at"][m + 1] = game.level()
			out["coins_at"][m + 1] = game.coins
	_minutes = visit_minutes
	out["goals"] = goals_claimed
	var lines: Array = out["lines"]
	lines.append("first harvest at minute %d, first purchase at minute %d, first find at minute %d, projects open %s"
		% [out["first_harvest"], out["first_buy"], out["first_find"], out["project_open"]])
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
	var first := {"stuck_minutes": out["stuck_minutes"], "coins_at_10": out["coins_at"].get(10, 0),
		"level3_minute": int(out["minute_of_level"].get(3, NEVER))}
	lines.append(targets_line(1, first, true))
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
	game.check_rescue()   # (the game opened: a stuck or young farm is helped, as on a phone)
	if follows_goals():
		_claim_goals()   # yesterday's finished jobs first: the day's refresh replaces them
		game.goals.refresh()
		_swap_undoable()
	_place_gifts()
	_place_named()
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
		_goal_eggs()
	if style == "crafter":
		_craft()   # before replanting: harvested plots can still be cleared to make room for the building
	if style != "casual":
		_upkeep(300)   # (repairs first: a player keeps what they have working before buying more)
		if not follows_goals() or jobs_left() == 0:
			_buy_building(300)   # (before replanting: harvested plots make room; after the goals' own buys)
	for r in game.farm_size:
		for c in game.farm_size:
			var i := game.index_of(r, c)
			if game.is_occupied(i) or _kept_for_building(r):
				continue
			var ph := game.field.phase(i)
			# On grass the plowing is paid too: the best crop is the best one the coins cover with it (a goal's
			# Eggplant at 25 with 30 coins on grass left every plot bare all through a new farm's first hour).
			var crop := _best_crop(next_visits, Balance.i("economy.plow_cost") if ph == GameState.Phase.GRASS else 0)
			if crop == "":
				break   # nothing affordable that a later visit finds ripe: plowing now would only waste coins
			if ph == GameState.Phase.GRASS:
				if game.coins - _kept() < Balance.i("economy.plow_cost") + int(game.crops[crop]["seed_cost"]) or not _act():
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
	if style == "builder":
		_buy_wants()
	_claim_goals()


## The coins kept back from seeds for what an open goal asks to buy: only once the purse holds them. Short of
## that, keeping would stop the planting that earns them (a new farm with 55 coins kept them all for Barley's
## chicken and stood still through its first hour).
func _kept() -> int:
	return _keep if game.coins >= _keep else 0


## The crafter's visit at its building: built first if it can be (it waits for that: the bot keeps the coins),
## then finished crafts collected, goods sold, and the free slots filled with the best-paying recipe.
func _craft() -> void:
	var cr := game.crafting
	var home := _crafting_home()
	if home.is_empty():
		_build_crafting()
		return
	var uid := int(home["uid"])
	if cr.crafts_done(home) > 0 and _act():
		var goods_before := _goods_held()
		cr.finish_crafts(uid)
		craft_made += _goods_held() - goods_before
	for rid: String in cr.goods.keys():
		while int(cr.goods.get(rid, 0)) > 0 and _act():
			craft_worth += (game.catalog.get_def(rid) as RecipeDef).worth(game.catalog)
			craft_coins += cr.sell_good(rid)
	while cr.free_slots(home) > 0:
		var rid := _best_recipe(home)
		if rid == "" or not _act():
			return
		for c: String in cr.missing_bushels(rid):
			for k in int(cr.missing_bushels(rid)[c]):
				var price := cr.bushel_price(c)
				if cr.buy_bushel(c):
					craft_stall_spent += price
		if not cr.start_craft(uid, rid):
			return


## The crafter's building, finished ({} for none yet).
func _crafting_home() -> Dictionary:
	for o in game.objects:
		if game.crafting.is_crafting(o) and not game.under_construction(o):
			return o
	return {}


func _goods_held() -> int:
	var n := 0
	for rid: String in game.crafting.goods:
		n += int(game.crafting.goods[rid])
	return n


## The unlocked recipe (goods, not feed) paying most over its ingredients that the bushels held, plus at most
## STALL_BUY_MOST bought at today's stall and affordable, can make now; "" for none.
func _best_recipe(home: Dictionary) -> String:
	var cr := game.crafting
	var best := ""
	var best_gain := 0
	var stall := cr.market_stall()
	for r in cr.recipes_of(str(home["id"])):
		if not cr.recipe_unlocked(home, r.id) or r.makes_feed():
			continue
		var missing := cr.missing_bushels(r.id)
		var buy := 0
		var cost := 0
		var short := false
		for c: String in missing:
			buy += int(missing[c])
			cost += cr.bushel_price(c) * int(missing[c])
			short = short or int(stall.get(c, 0)) < int(missing[c])
		if short or buy > STALL_BUY_MOST or cost > game.coins:
			continue
		var gain := cr.good_price(r.id) - cost
		if gain > best_gain:
			best_gain = gain
			best = r.id
	return best


## Buys and places the crafter's building once it unlocks and the coins are there.
func _build_crafting() -> void:
	if not game.buildings.can_buy(CRAFTER_BUILDING).ok():
		return
	var cost := int(game.buildings.price_of(CRAFTER_BUILDING).get("coins", 0))
	if cost <= 0 or game.coins < cost:
		return
	if (_buy_somewhere(CRAFTER_BUILDING) or (_clear_area(CRAFTER_BUILDING) and _buy_somewhere(CRAFTER_BUILDING))) \
			and game.crafting.owns_crafting():
		craft_built_day = _day + 1
		craft_cost = cost


## Clears a spot of plots that grow nothing (as a player clears them with Sell) where `id` then fits, from the back
## of the farm. True when one was cleared.
func _clear_area(id: String) -> bool:
	var it: Dictionary = game.items[id]
	var w := int(it.get("w", 1))
	var h := int(it.get("h", 1))
	for r in range(game.farm_size - h, -1, -1):
		for c in range(game.farm_size - w, -1, -1):
			var tiles := []
			for dr in h:
				for dc in w:
					var i := game.index_of(r + dr, c + dc)
					if game.is_occupied(i) or game.plots[i].get("state") == "planted":
						tiles = []
						break
					tiles.append(i)
				if tiles.size() < (dr + 1) * w:
					break
			if tiles.size() < w * h:
				continue
			for i: int in tiles:
				if game.field.phase(i) != GameState.Phase.GRASS and game.field.clear_plot(i):
					_cleared += 1
			return true
	return false


## Part 4's crafting target: what the building cost, what crafting earned since (goods sold less bushels bought
## at the stall; harvest bushels come free beside the crop), and in how many days that pays the building back.
func craft_line() -> String:
	if craft_built_day < 0:
		return "crafting: %s not built (level %d)" % [CRAFTER_BUILDING, game.level()]
	return ("crafting: %s built day %d for %d; %d goods sold for %d (ingredients worth %d), stall bushels %d; "
		+ "pays back in %.1f days (target about %.0f); bushels held %s") % [
		CRAFTER_BUILDING, craft_built_day, craft_cost, craft_made, craft_coins, craft_worth, craft_stall_spent,
		craft_payback_days(), CRAFT_PAYBACK_DAYS, game.crafting.bushels]


## Days of crafting the building took to pay back at the rate since it was built (INF: it earns nothing).
func craft_payback_days() -> float:
	var days := maxf(1.0, float(_day + 1 - craft_built_day + 1))
	var per_day := float(craft_coins - craft_stall_spent) / days
	return float(craft_cost) / per_day if per_day > 0.0 else INF


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
	if style == "crafter":
		_want_craft_crops(growing)


## The crafter plants for its next recipe: enough plots of each crop it is short of to find those bushels (a
## harvest finds one at crafting.bushel_chance), and grows only the crops its building's recipes use.
func _want_craft_crops(growing: Dictionary) -> void:
	_craft_crops = {}
	var home := _crafting_home()
	if home.is_empty():
		# A level before it unlocks the crafter already grows its crops: what ripens after it is built must not
		# fill the stall with bushels nothing there uses.
		if game.level() < int(game.items[CRAFTER_BUILDING].get("unlock_level", 1)) - 1:
			return
		home = {"id": CRAFTER_BUILDING, "level": 1}
	var cr := game.crafting
	var best: RecipeDef = null
	for r in cr.recipes_of(str(home["id"])):
		if not cr.recipe_unlocked(home, r.id) or r.makes_feed():
			continue
		var plantable := true   # every crop it needs can be planted, and its produce is held or at the stall
		var short := cr.missing_bushels(r.id)
		for c: String in r.inputs():
			if game.crops.has(c):
				plantable = plantable and game.can_plant(c)
			elif short.has(c):
				plantable = plantable and int(cr.market_stall().get(c, 0)) >= int(short[c])
		if plantable and (best == null or cr.good_price(r.id) - r.worth(game.catalog)
				> cr.good_price(best.id) - best.worth(game.catalog)):
			best = r
	if best == null:
		return
	var missing := cr.missing_bushels(best.id)
	for c: String in missing:
		if game.crops.has(c):
			_craft_crops[c] = true   # only the crops this recipe still lacks: any other's bushels fill the stall
	if _craft_crops.is_empty():
		for c: String in best.inputs():
			if game.crops.has(c):
				_craft_crops[c] = true
	for c: String in missing:
		if game.crops.has(c):
			var plots := ceili(float(missing[c]) / Balance.f("crafting.bushel_chance")) - int(growing.get(c, 0))
			_want[c] = maxi(int(_want.get(c, 0)), plots)


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
		# (Never the seed money: a player keeps enough to sow the fields again before buying for a goal, or the
		# farm stalls with nothing growing; goals credited with the day's work came faster and spent it, 28 Nov.)
		if game.coins - int(game.buildings.price_of(id).get("coins", 0)) < _seed_money():
			continue
		if not _buy_somewhere(id) and _clear_a_plot():
			_buy_somewhere(id)
		return


## The coins to sow every field plot once with the cheapest seed (what a goal buy leaves: _goal_buy).
func _seed_money() -> int:
	if not game.goals.past_welcome():
		return 0   # (the Welcome chain's buys are the tutorial's own: its gifts pay for them)
	var cheapest := INF
	for id: String in game.crops:
		if game.can_plant(id):
			cheapest = minf(cheapest, float(game.crops[id]["seed_cost"]))
	if cheapest == INF:
		return 0
	var fields := 0
	for i in game.plots.size():
		if game.on_farm(i) and game.field.phase(i) != GameState.Phase.GRASS:
			fields += 1
	return int(cheapest) * fields


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


## Opens the Mystery Eggs held when a goal asks to open some (a tap on the egg in the Barn).
func _goal_eggs() -> void:
	for task: Dictionary in _open_tasks():
		if str(task["do"]) != "open_egg":
			continue
		for colour: String in game.mystery.mystery_eggs.keys():
			while int(game.mystery.mystery_eggs[colour]) > 0 and _act():
				game.mystery.open_mystery_egg(colour)
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


## Takes out of the Barn a thing an open goal's task names (the rebuilt Tractor Rusty wants driving), clearing a
## plot when nothing fits.
func _place_named() -> void:
	if not follows_goals():
		return
	var named := {}
	for key: String in game.goals.open_keys():
		for t: Dictionary in game.goals.tasks_of(key):
			named[str(t.get("what", ""))] = true
	for at in range(game.storage.stored.size() - 1, -1, -1):
		var id := str(game.storage.stored[at]["id"])
		if not named.has(id):
			continue
		for _try in 2:
			for r in range(game.farm_size - 1, -1, -1):
				for c in game.farm_size:
					if game.can_place(id, r, c) and _act() and game.storage.place_from_storage(at, r, c):
						return
			if not _clear_a_plot():
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
			var before := game.coins
			var mult := game.feeds.coin_multiplier(o)
			var got := game.collect(int(o["uid"]))
			if not got.is_empty():
				_collected += 1
				if game.feeds.is_feedable(o):
					animal_coins += game.coins - before
					animal_base += (game.coins - before) / maxf(mult, 0.01)
					animal_collects += 1


## Feeds what is hungry with the best feed in stock (an action each, like a player's tap): without it every animal
## pays the hunger penalty and the simulated farm earns less than a played one.
func _feed_hungry() -> void:
	if no_feed:
		return
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
		# Buildings only (a frame too: _upkeep puts in the materials the farm finds, as a player does).
		# (every item has a status, "in_game" or "planned": the bot never bought a building here, it skipped them all)
		if game.building_def(id) == null or str(it.get("status", "")) == "planned" or id == "barn":
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
	# No room: as a player does, clear plots that grow nothing now at the back of the farm to make it (the bot
	# used to fill its farm with plots and then sit on its coins with nothing it could place).
	var fp := game.footprint(best)
	for r in range(game.farm_size - fp.x, -1, -1):
		for c in range(game.farm_size - fp.y, -1, -1):
			if not _clearable(r, c, fp):
				continue
			for dr in fp.x:
				for dc in fp.y:
					var i := game.index_of(r + dr, c + dc)
					if game.field.phase(i) != GameState.Phase.GRASS and game.field.clear_plot(i):
						_cleared += 1
			if game.can_place(best, r, c) and game.buy_and_place(best, r, c):
				_bought[best] = int(_bought.get(best, 0)) + 1
			return


## Whether row `r` is kept clear of fields for buildings: a farm grown past its start keeps its back BUILD_ROWS
## rows for them, as a player lays a farm out (all but the casual bot, which never builds).
func _kept_for_building(r: int) -> bool:
	return style != "casual" and game.farm_size >= BUILD_FROM_SIZE and r >= game.farm_size - BUILD_ROWS


## Whether every tile of a `fp` footprint at row, col holds no object and nothing planted (plots can be cleared).
func _clearable(r: int, c: int, fp: Vector2i) -> bool:
	for dr in fp.x:
		for dc in fp.y:
			var i := game.index_of(r + dr, c + dc)
			if i < 0 or game.is_occupied(i) or game.plots[i].get("state") == "planted":
				return false
	return true


## Wear (docs/WEAR.md) and growing, as a player does: spoiling worked out, materials put into frames, crafting
## stars bought, every building worn to level 3 or more repaired, then every building that can grow a size grown,
## while coins stay above the reserve.
func _upkeep(reserve: int) -> void:
	game.wear.spoil()
	for o in game.objects:
		if game.under_construction(o):
			game.land.add_materials(int(o["uid"]))   # (the materials found go into a frame standing)
		elif game.crafting.is_crafting(o) and not game.crafting.star_cost(o).is_empty():
			var star := int(game.crafting.star_cost(o).get("coins", 0))
			if game.coins >= star + reserve and game.crafting.can_add_star(int(o["uid"]), false):
				game.crafting.add_star(int(o["uid"]), false)
				_upgrades += 1
				_upgrade_coins += star
	for o in game.objects:
		var uid := int(o["uid"])
		if game.wear.needs_repair(o) and game.wear.level_of(o) >= REPAIR_AT:
			var cost := game.wear.repair_cost(uid)
			if game.coins >= int(cost["coins"]) + reserve and game.wear.repair(uid):
				_repairs += 1
				_repair_coins += int(cost["coins"])
				if _late():
					_late_repairs += int(cost["coins"])
	for o in game.objects:
		if game.is_building_item(str(o["id"])) and game.buildings.can_expand(o).ok():
			var coins := game.land.expansion_coins(o)
			if game.coins >= UPGRADE_SPARE * coins + reserve and game.land.upgrade_building(int(o["uid"])):
				_upgrades += 1
				_upgrade_coins += coins


## Spends what's above a reserve for replanting: land first when it can be bought, then whichever tree or
## animal pays back soonest, on free ground at the back of the farm (never more than a quarter of the farm).
func _spend() -> void:
	var reserve := 300
	_goal_buy()
	_upkeep(reserve)
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
func _best_crop(next_visits: Array, also_pay := 0) -> String:
	var best := ""
	var best_rate := -INF
	for id: String in game.crops:
		var crop: Dictionary = game.crops[id]
		if not game.can_plant(id) or int(crop["seed_cost"]) + also_pay > game.coins - _kept():
			continue
		if not _craft_crops.is_empty() and not _craft_crops.has(id):
			continue   # the crafter grows what it crafts with: other crops' bushels would fill the stall
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
