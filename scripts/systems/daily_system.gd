class_name DailySystem
extends GameSystem
## Building materials found while farming, and the daily gift with its 5-day streak.
## Part of the game state: reached as `Game.daily`; shared state is on `game`.


# FarmVille's daily bonus: come back on consecutive days for a bigger reward, up to day 5.
const DAILY_STREAK := [
	{"coins": 100}, {"coins": 250}, {"coins": 500, "fertilizer": 1},
	{"coins": 750, "unwither": 1}, {"coins": 1000, "gems": 1}]

var last_daily_day := 0            # day number of the last daily gift
var daily_streak := 0              # consecutive days the daily bonus was collected


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
	last_daily_day = game.day_number()
	daily_streak = 0


func save_to(data: Dictionary) -> void:
	data["last_daily_day"] = last_daily_day
	data["daily_streak"] = daily_streak


func load_from(data: Dictionary) -> void:
	last_daily_day = int(data.get("last_daily_day", game.day_number()))
	daily_streak = int(data.get("daily_streak", 0))


## A part for this harvest or collection, or "" for none. Fewer-held parts are likelier.
func roll_part() -> String:
	if not game.drops_enabled or game.rng.randf() >= Balance.f("daily.part_chance"):
		return ""
	var p := pick_part()
	add_part(p, 1)
	return p


## Which materials can drop: the basic three, plus the specific ones of buildings you own.
func wanted_parts() -> Array[String]:
	var out: Array[String] = []
	out.assign(GameState.basic_parts)
	for o in game.objects:
		var it := game.item_data(o["id"])
		var used: Array = (it.get("build_materials", {}) as Dictionary).keys() + it.get("uses_materials", [])
		var def := game.building_def(o["id"])
		if def != null:
			for k in range(2, def.max_level() + 1):
				used.append_array(def.size_materials(k).keys())
		for m in used:
			if not out.has(m):
				out.append(m)
	return out


func pick_part() -> String:
	var pool := wanted_parts()
	var weights: Array[float] = []
	var total := 0.0
	for p in pool:
		var w := 1.0 / (1.0 + int(game.parts.get(p, 0)))
		weights.append(w)
		total += w
	var pick := game.rng.randf() * total
	for k in pool.size():
		pick -= weights[k]
		if pick <= 0.0:
			return pool[k]
	return pool[-1]


func add_part(part: String, n: int) -> void:
	game.parts[part] = int(game.parts.get(part, 0)) + n
	game.ribbons.bump("parts_found", n)
	game.inventory_changed.emit()
	game.queue_save()


## Once per calendar day: a couple of free parts.
func check_daily_gift() -> void:
	var today := game.day_number()
	if today <= last_daily_day:
		return
	daily_streak = daily_streak + 1 if today == last_daily_day + 1 else 1
	last_daily_day = today
	var got: Array[String] = _give_daily_bonus(daily_streak)
	for k in Balance.i("daily.daily_parts"):
		var p := pick_part()
		add_part(p, 1)
		got.append(GameState.part_names[p])
	game.ribbons.bump("daily_bonuses", 1)
	game.message.emit(tr("DAY_BONUS") % [mini(daily_streak, DAILY_STREAK.size()), ", ".join(PackedStringArray(got))])
	game.queue_save()


## The reward for this day of the streak; day 5 and on repeat the biggest one.
func daily_reward(day: int) -> Dictionary:
	return DAILY_STREAK[clampi(day, 1, DAILY_STREAK.size()) - 1]


func _give_daily_bonus(day: int) -> Array[String]:
	var got: Array[String] = []
	var reward := daily_reward(day)
	if reward.has("coins"):
		game.add_coins(int(reward["coins"]), false)
		got.append("%d coins" % int(reward["coins"]))
	if reward.has("fertilizer"):
		game.fertilizer_bags += int(reward["fertilizer"])
		got.append(tr("FERTILIZER_2") % int(reward["fertilizer"]))
	if reward.has("unwither"):
		game.add_unwithers(int(reward["unwither"]))
		got.append(tr("UNWITHER") % int(reward["unwither"]))
	if reward.has("gems"):
		game.add_gems(int(reward["gems"]))
		got.append("%d gem" % int(reward["gems"]))
	return got
