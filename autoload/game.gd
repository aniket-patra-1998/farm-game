class_name GameState
extends Node
## Global game state: economy, plots, mastery, save/load.
## Autoloaded as `Game`. All rules live here; scenes only display and call in.

signal coins_changed(coins: int)
signal xp_changed(xp: int, level: int)
signal leveled_up(level: int)
signal plot_changed(index: int) # -1 means "everything changed"
signal message(text: String)
signal tutorial_changed(step: int)

enum Phase { GRASS, PLOWED, GROWING, RIPE, WITHERED }
enum Tutorial { HARVEST, PLOW, PLANT, DONE }

const TUTORIAL_TEXT := {
	Tutorial.HARVEST: "Your first crops are ready! Tap them to harvest.",
	Tutorial.PLOW: "Choose Plow, then tap a grassy or empty spot to plow a plot.",
	Tutorial.PLANT: "Choose Strawberries, then tap a plowed plot to plant.",
}

# Rescue: if a player can't afford seeds and has nothing growing, top them up to this.
const RESCUE_COINS := 50

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const GRID_SIZE := 12
const START_COINS := 200
const PLOW_COST := 15
const PLOW_XP := 1

# A ripe crop stays ripe as long as it took to grow, clamped to this window.
const MIN_RIPE_WINDOW := 4 * 3600
const MAX_RIPE_WINDOW := 2 * 86400

# Total XP needed to reach level n is LEVEL_XP[n - 1]. Past the table, +700 per level.
const LEVEL_XP := [0, 15, 40, 80, 140, 220, 320, 450, 600, 780,
	1000, 1250, 1550, 1900, 2300, 2750, 3250, 3800, 4400, 5050]
const XP_PER_LEVEL_AFTER_TABLE := 700

# Mastery: harvests needed for stars 1, 2, 3, by crop speed.
const MASTERY_FAST := [150, 450, 900]   # grows in 6 h or less
const MASTERY_MEDIUM := [80, 240, 480]  # 8 to 16 h
const MASTERY_SLOW := [40, 120, 240]    # 1 day or more
const MASTERY_PRICE_BONUS := 0.05       # per star
const MASTERY_STAR_COINS := [100, 300, 1000]
const MASTERY_STAR_XP := [10, 30, 100]

var crops := {}                    # id -> crop dictionary from data/crops.json
var crop_order: Array[String] = [] # display order
var coins := START_COINS
var xp := 0
var plots: Array[Dictionary] = []  # GRID_SIZE * GRID_SIZE entries
var mastery := {}                  # crop id -> lifetime harvest count
var debug_time_offset := 0         # seconds; only changed by the debug skip button
var tutorial_step: int = Tutorial.HARVEST

var _save_queued := false


func _ready() -> void:
	_load_crops()
	if not load_game():
		_new_game()
	# Deferred so the HUD is connected and can show the message.
	call_deferred("check_rescue")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# ---------------------------------------------------------------- time

func now() -> int:
	return int(Time.get_unix_time_from_system()) + debug_time_offset


func debug_skip(seconds: int) -> void:
	if not OS.is_debug_build():
		return
	debug_time_offset += seconds
	plot_changed.emit(-1)
	check_rescue()
	queue_save()


# ---------------------------------------------------------------- plots

func index_of(row: int, col: int) -> int:
	return row * GRID_SIZE + col


func phase(i: int) -> Phase:
	var p: Dictionary = plots[i]
	match p.get("state", "grass"):
		"plowed":
			return Phase.PLOWED
		"planted":
			var crop: Dictionary = crops[p["crop"]]
			var age := now() - int(p["planted_at"])
			var grow := int(crop["grow_seconds"])
			if age < grow:
				return Phase.GROWING
			if age < grow + ripe_window(crop):
				return Phase.RIPE
			return Phase.WITHERED
	return Phase.GRASS


func ripe_window(crop: Dictionary) -> int:
	return clampi(int(crop["grow_seconds"]), MIN_RIPE_WINDOW, MAX_RIPE_WINDOW)


## 0.0 just planted .. 1.0 ripe.
func growth(i: int) -> float:
	var p: Dictionary = plots[i]
	if p.get("state") != "planted":
		return 0.0
	var grow := float(crops[p["crop"]]["grow_seconds"])
	return clampf(float(now() - int(p["planted_at"])) / grow, 0.0, 1.0)


func seconds_until_ripe(i: int) -> int:
	var p: Dictionary = plots[i]
	if p.get("state") != "planted":
		return 0
	var grow := int(crops[p["crop"]]["grow_seconds"])
	return maxi(0, int(p["planted_at"]) + grow - now())


func crop_at(i: int) -> String:
	return plots[i].get("crop", "")


func plow(i: int) -> bool:
	var ph := phase(i)
	if ph != Phase.GRASS and ph != Phase.WITHERED:
		return false
	if not spend(PLOW_COST):
		message.emit("Not enough coins to plow")
		return false
	plots[i] = {"state": "plowed"}
	add_xp(PLOW_XP)
	if coins < cheapest_seed_cost():
		message.emit("Careful: keep some coins for seeds!")
	_advance_tutorial(Tutorial.PLOW)
	_plot_updated(i)
	check_rescue()
	return true


func plant(i: int, crop_id: String) -> bool:
	if phase(i) != Phase.PLOWED or not crops.has(crop_id):
		return false
	var crop: Dictionary = crops[crop_id]
	if level() < int(crop["unlock_level"]):
		message.emit("%s unlocks at level %d" % [crop["name"], int(crop["unlock_level"])])
		return false
	if not spend(int(crop["seed_cost"])):
		message.emit("Not enough coins for %s seeds" % crop["name"])
		return false
	plots[i] = {"state": "planted", "crop": crop_id, "planted_at": now()}
	_advance_tutorial(Tutorial.PLANT)
	_plot_updated(i)
	return true


## Returns {"coins": int, "xp": int, "crop": String} or {} if nothing was harvested.
func harvest(i: int) -> Dictionary:
	if phase(i) != Phase.RIPE:
		return {}
	var crop_id: String = plots[i]["crop"]
	var crop: Dictionary = crops[crop_id]
	var stars_before := mastery_stars(crop_id)
	var earned := int(round(float(crop["sell_price"]) * (1.0 + MASTERY_PRICE_BONUS * stars_before)))
	var gained := int(crop["xp"])
	plots[i] = {"state": "plowed"}
	mastery[crop_id] = int(mastery.get(crop_id, 0)) + 1
	add_coins(earned)
	add_xp(gained)
	var stars_after := mastery_stars(crop_id)
	if stars_after > stars_before:
		_award_mastery_star(crop_id, stars_after)
	if tutorial_step == Tutorial.HARVEST and not _any_plot_in(Phase.RIPE):
		_advance_tutorial(Tutorial.HARVEST)
	_plot_updated(i)
	return {"coins": earned, "xp": gained, "crop": crop_id}


# ---------------------------------------------------------------- safety net

func cheapest_seed_cost() -> int:
	var cheapest := 1 << 30
	for id in crop_order:
		if is_unlocked(id):
			cheapest = mini(cheapest, int(crops[id]["seed_cost"]))
	return cheapest


## Quiet backstop: a player who can't buy seeds and has nothing growing or ripe
## gets enough coins to plant again, so the farm can never get stuck.
func check_rescue() -> void:
	if coins >= cheapest_seed_cost():
		return
	if _any_plot_in(Phase.GROWING) or _any_plot_in(Phase.RIPE):
		return
	var gift := RESCUE_COINS - coins
	add_coins(gift)
	message.emit("You found %d coins in the barn. Plant some seeds!" % gift)


func _any_plot_in(wanted: Phase) -> bool:
	for i in plots.size():
		if phase(i) == wanted:
			return true
	return false


# ---------------------------------------------------------------- tutorial

func tutorial_text() -> String:
	return TUTORIAL_TEXT.get(tutorial_step, "")


## Moves to the next step only when the finished step is the current one.
func _advance_tutorial(finished: Tutorial) -> void:
	if tutorial_step != finished:
		return
	tutorial_step += 1
	tutorial_changed.emit(tutorial_step)
	if tutorial_step == Tutorial.DONE:
		message.emit("Nice! Crops grow in real time. Come back when they're ready.")
	queue_save()


# ---------------------------------------------------------------- mastery

func mastery_thresholds(crop_id: String) -> Array:
	var grow := int(crops[crop_id]["grow_seconds"])
	if grow <= 6 * 3600:
		return MASTERY_FAST
	if grow < 86400:
		return MASTERY_MEDIUM
	return MASTERY_SLOW


func mastery_stars(crop_id: String) -> int:
	var count := int(mastery.get(crop_id, 0))
	var stars := 0
	for need in mastery_thresholds(crop_id):
		if count >= int(need):
			stars += 1
	return stars


func _award_mastery_star(crop_id: String, star: int) -> void:
	add_coins(MASTERY_STAR_COINS[star - 1])
	add_xp(MASTERY_STAR_XP[star - 1])
	message.emit("%s mastery: star %d!" % [crops[crop_id]["name"], star])


# ---------------------------------------------------------------- economy

func spend(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	queue_save()
	return true


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)
	queue_save()


func add_xp(amount: int) -> void:
	var before := level()
	xp += amount
	var after := level()
	xp_changed.emit(xp, after)
	for lvl in range(before + 1, after + 1):
		_on_level_reached(lvl)
	queue_save()


func xp_for_level(lvl: int) -> int:
	if lvl <= 1:
		return 0
	if lvl - 1 < LEVEL_XP.size():
		return LEVEL_XP[lvl - 1]
	return LEVEL_XP[-1] + (lvl - LEVEL_XP.size()) * XP_PER_LEVEL_AFTER_TABLE


func level() -> int:
	var lvl := 1
	while xp >= xp_for_level(lvl + 1):
		lvl += 1
	return lvl


func is_unlocked(crop_id: String) -> bool:
	return level() >= int(crops[crop_id]["unlock_level"])


func _on_level_reached(lvl: int) -> void:
	var unlocked: Array[String] = []
	for id in crop_order:
		if int(crops[id]["unlock_level"]) == lvl:
			unlocked.append(crops[id]["name"])
	var text := "Level %d!" % lvl
	if not unlocked.is_empty():
		text += " Unlocked: " + ", ".join(PackedStringArray(unlocked))
	leveled_up.emit(lvl)
	message.emit(text)


# ---------------------------------------------------------------- data

func _load_crops() -> void:
	var f := FileAccess.open("res://data/crops.json", FileAccess.READ)
	if f == null:
		push_error("Missing data/crops.json")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("data/crops.json is not valid JSON")
		return
	for c in parsed["crops"]:
		crops[c["id"]] = c
		crop_order.append(c["id"])


func _new_game() -> void:
	coins = START_COINS
	xp = 0
	mastery = {}
	debug_time_offset = 0
	tutorial_step = Tutorial.HARVEST
	plots.clear()
	for i in GRID_SIZE * GRID_SIZE:
		plots.append({"state": "grass"})
	# Starter farm, modelled on the classic opening: 2 plots ripe to harvest,
	# 2 half-grown (a first-day safety net), 2 plowed and ready for seeds.
	var t := now()
	var berry_grow := int(crops["strawberries"]["grow_seconds"])
	var wheat_grow := int(crops["wheat"]["grow_seconds"])
	_set_starter(5, 4, "strawberries", t - berry_grow)
	_set_starter(5, 5, "wheat", t - wheat_grow)
	_set_starter(6, 4, "strawberries", t - int(berry_grow / 2.0))
	_set_starter(6, 5, "wheat", t - int(wheat_grow / 2.0))
	plots[index_of(7, 4)] = {"state": "plowed"}
	plots[index_of(7, 5)] = {"state": "plowed"}
	save_game()


func _set_starter(row: int, col: int, crop_id: String, planted_at: int) -> void:
	plots[index_of(row, col)] = {"state": "planted", "crop": crop_id, "planted_at": planted_at}


# ---------------------------------------------------------------- save/load

func queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	call_deferred("_flush_save")


func _flush_save() -> void:
	_save_queued = false
	save_game()


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": now(),
		"coins": coins,
		"xp": xp,
		"mastery": mastery,
		"plots": plots,
		"debug_time_offset": debug_time_offset,
		"tutorial_step": tutorial_step,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SAVE_VERSION:
		return false
	var saved_plots: Array = data.get("plots", [])
	if saved_plots.size() != GRID_SIZE * GRID_SIZE:
		return false
	coins = int(data.get("coins", START_COINS))
	xp = int(data.get("xp", 0))
	mastery = data.get("mastery", {})
	debug_time_offset = int(data.get("debug_time_offset", 0)) if OS.is_debug_build() else 0
	# Saves from before the tutorial existed belong to players who already know the basics.
	tutorial_step = int(data.get("tutorial_step", Tutorial.DONE))
	plots.clear()
	for p in saved_plots:
		var plot: Dictionary = p
		# Drop plots whose crop no longer exists in the data file.
		if plot.get("state") == "planted" and not crops.has(plot.get("crop", "")):
			plot = {"state": "plowed"}
		plots.append(plot)
	return true


func reset_game() -> void:
	_new_game()
	coins_changed.emit(coins)
	xp_changed.emit(xp, level())
	tutorial_changed.emit(tutorial_step)
	plot_changed.emit(-1)


func _plot_updated(i: int) -> void:
	plot_changed.emit(i)
	queue_save()
