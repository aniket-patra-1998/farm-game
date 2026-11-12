extends Node
## Balance simulator: plays the real game for days with a tidy bot (visits a few times a day, harvests everything,
## replants the crop that pays best until the next visit, plows as coins allow) and reports how fast the
## economy moves, what drops and how often, and what the weather does. Time is skipped, not waited for, so
## weeks take seconds. Change a number in data/balance.json (or pass `--set=section.name=value`) and run it again
## to see the effect before shipping it. Headless:
##   godot --headless --path . res://tools/balance_sim.tscn -- --days=14 --visits=3 --seed=1 [--set=harvest.golden_chance=0.01]
## Reads the real systems, so a rule change shows up here too. The bot is deliberately plain: it measures the
## farm-field loop (plant, harvest, drops, levels), not every building.

const HOURS_DEFAULT := [8.0, 13.0, 20.0]     # local hours of the day the bot visits (with --visits=3)

var _days := 14
var _visits := 3
var _seed := 1
var _drops := {}          # drop type -> count
var _harvests := 0
var _by_crop := {}        # crop id -> harvests
var _level_day := {}      # level -> day first reached


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			_days = int(arg.get_slice("=", 1))
		elif arg.begins_with("--visits="):
			_visits = clampi(int(arg.get_slice("=", 1)), 1, 12)
		elif arg.begins_with("--seed="):
			_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--set="):
			var kv := arg.get_slice("=", 1)
			var key := kv.get_slice("=", 0)
			var value := float(kv.get_slice("=", 1))
			Balance.override(key, int(value) if value == floorf(value) else value)
	await get_tree().process_frame
	Game.saving_enabled = false
	Game.reset_game()
	Game.rng.seed = _seed
	print("BALANCE SIM  days=%d visits/day=%d seed=%d" % [_days, _visits, _seed])
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


func _play() -> void:
	var hours := _visit_hours()
	var t0 := Game.now()
	# Start a morning, so the visits fall on the hours above.
	Game.debug_time_offset += int(
		fposmod(hours[0] - DayCycle.local_hour(t0, DayCycle.device_bias_minutes()), 24.0) * 3600.0
	)
	var start := Game.now()
	print("day  level   coins  harvests  coins/h  golden  collect  super  bonus  idle plots")
	var coins_at_day_start := Game.coins
	var harvests_at_day_start := 0
	for day in _days:
		for v in hours.size():
			_visit(_gap_after(hours, v))
			Game.debug_time_offset += int(_gap_after(hours, v) * 3600.0)
		var earned := Game.coins - coins_at_day_start
		print("%3d  %5d  %6d  %8d  %7.0f  %6d  %7d  %5d  %5d  %5d" % [
			day + 1, Game.level(), Game.coins, _harvests - harvests_at_day_start, earned / 24.0,
			_drops.get("golden", 0), _drops.get("collectible", 0), _drops.get("super_harvest", 0),
			_drops.get("bonus_xp", 0), _idle_plots()])
		coins_at_day_start = Game.coins
		harvests_at_day_start = _harvests
		for lvl in range(2, Game.level() + 1):
			if not _level_day.has(lvl):
				_level_day[lvl] = day + 1
	print("elapsed game days: %.1f" % ((Game.now() - start) / 86400.0))
	var marks := []
	for lvl: int in _level_day:
		if lvl % 5 == 0 or lvl == 2:
			marks.append("L%d on day %d" % [lvl, _level_day[lvl]])
	print("level pace: %s" % ", ".join(PackedStringArray(marks)))
	var crops := []
	for id: String in _by_crop:
		crops.append("%s x%d" % [id, _by_crop[id]])
	print("crops grown: %s" % ", ".join(PackedStringArray(crops)))


func _gap_after(hours: Array, v: int) -> float:
	var next: float = hours[(v + 1) % hours.size()] + (24.0 if v + 1 >= hours.size() else 0.0)
	return next - float(hours[v])


## One visit: harvest what's ripe, plow what the coins reach, plant the best-paying crop for the time until the next visit.
func _visit(gap_hours: float) -> void:
	for r in Game.farm_size:
		for c in Game.farm_size:
			var i := Game.index_of(r, c)
			if Game.is_occupied(i):
				continue
			match Game.field.phase(i):
				GameState.Phase.RIPE:
					_record(Game.field.harvest(i))
				GameState.Phase.WITHERED:
					Game.field.plow(i)
	for r in Game.farm_size:
		for c in Game.farm_size:
			var i := Game.index_of(r, c)
			if Game.is_occupied(i):
				continue
			var ph := Game.field.phase(i)
			if ph == GameState.Phase.GRASS:
				if Game.coins < Balance.i("economy.plow_cost") + _cheapest_seed():
					continue
				Game.field.plow(i)
				ph = Game.field.phase(i)
			if ph == GameState.Phase.PLOWED:
				var crop := _best_crop(gap_hours * 3600.0)
				if OS.get_cmdline_user_args().has("--trace"):
					print("  plant %s (coins %d, gap %.0fh)" % [crop, Game.coins, gap_hours])
				if crop != "" and not Game.field.plant(i, crop):
					return   # out of coins: the rest wait for the next visit


func _record(h: Dictionary) -> void:
	if h.is_empty():
		return
	_harvests += 1
	var t := str(h.get("drop", ""))
	if t != "":
		_drops[t] = int(_drops.get(t, 0)) + 1
	var crop := str(h.get("crop", ""))
	_by_crop[crop] = int(_by_crop.get(crop, 0)) + 1


func _cheapest_seed() -> int:
	return Game.cheapest_seed_cost()


## The crop with the best profit per second it takes, counting the wait until the next visit as time spent,
## that will be ripe at the next visit and not yet withered (a crop withers as long after ripening as it took to
## grow, so a player who visits once a day can't use a 12-hour crop: it's gone by the next visit).
func _best_crop(gap_seconds: float) -> String:
	var best := ""
	var best_rate := -INF
	for id: String in Game.crops:
		var crop: Dictionary = Game.crops[id]
		if Game.level() < int(crop["unlock_level"]) or int(crop["seed_cost"]) > Game.coins:
			continue
		var grow := float(crop["grow_seconds"])
		var window := float(Game.field.ripe_window(crop))
		# The first visit that finds it ripe and not yet withered (visits come every gap, so the k-th is k gaps on).
		var wait := 0.0
		for k in range(1, 13):
			if grow <= k * gap_seconds and k * gap_seconds < grow + window:
				wait = k * gap_seconds
				break
		if wait == 0.0:
			continue   # always ripens between visits and withers before the next
		var rate := (float(crop["sell_price"]) - float(crop["seed_cost"])) / wait
		if rate > best_rate:
			best_rate = rate
			best = id
	return best


func _idle_plots() -> int:
	var n := 0
	for r in Game.farm_size:
		for c in Game.farm_size:
			var i := Game.index_of(r, c)
			if not Game.is_occupied(i) and Game.field.phase(i) in [GameState.Phase.GRASS, GameState.Phase.PLOWED]:
				n += 1
	return n


## What the drop rolls really give over many harvests, against what the numbers say.
func _drop_table() -> void:
	print("\nDROPS per 1000 harvests (100000 rolls each, the real rolls; golden and collectibles have pity counters)")
	print("stars  golden  collect  bird  super  bonus")
	var crop := ""
	for id: String in Game.crops:
		if not Game.crops[id].get("flower", false):
			crop = id
			break
	for stars in 4:
		var counts := {}
		for k in 100000:
			var d := Game.drops.roll_drop(crop, stars, 1)
			var t := str(d.get("type", ""))
			counts[t] = int(counts.get(t, 0)) + 1
		print("%5d  %6.1f  %7.1f  %4.1f  %5.1f  %5.1f" % [stars, counts.get("golden", 0) / 100.0, counts.get("collectible", 0) / 100.0,
			counts.get("bird", 0) / 100.0, counts.get("super_harvest", 0) / 100.0, counts.get("bonus_xp", 0) / 100.0])


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
