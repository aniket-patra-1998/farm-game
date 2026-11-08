class_name GameState
extends Node
## Global game state: economy, plots, mastery, save/load.
## Autoloaded as `Game`. All rules live here; scenes only display and call in.

signal coins_changed(coins: int)
signal gems_changed(gems: int)
signal xp_changed(xp: int, level: int)
signal leveled_up(level: int)
signal plot_changed(index: int) # -1 means "everything changed"
signal message(text: String)
signal tutorial_changed(step: int)
signal collections_changed
signal ribbons_changed
signal objects_changed
signal building_upgraded(uid: int, level: int)
signal farm_expanded(size: int)
signal inventory_changed

enum Phase { GRASS, PLOWED, GROWING, RIPE, WITHERED }
enum Tutorial { HARVEST, PLOW, PLANT, DONE }

const TUTORIAL_TEXT := {
	Tutorial.HARVEST: "Your first crops are ready! Tap them to harvest.",
	Tutorial.PLOW: "Choose Plow, then tap a grassy or empty spot to plow a plot.",
	Tutorial.PLANT: "Choose Strawberries, then tap a plowed plot to plant.",
}

# Building parts: found while harvesting and collecting, plus a daily gift.
const PARTS := ["bricks", "nails", "boards"]
const PART_NAMES := {"bricks": "Bricks", "nails": "Nails", "boards": "Wooden Boards"}
const PART_CHANCE := 0.08          # per harvest or collection
const DAILY_PARTS := 2

# Building upgrades: each level above 1 earns more and finds better drops; the top level also works faster.
const UPGRADE_EARNINGS_BONUS := 0.10   # +10% per level above 1
const TOP_LEVEL_SPEEDUP := 0.85        # level 3 and up: cycles take 85% as long
const TOP_LEVEL := 3
const UPGRADE_XP_PER_LEVEL := 50       # one-time XP for reaching a level: 50 x the new level

# Rescue: if a player can't afford seeds and has nothing growing, top them up to this.
const RESCUE_COINS := 50

# Surprise drops, rolled on every harvest. Chances are per harvest.
const GOLDEN_CHANCE := 0.004      # golden harvest: 5x coins, +10 XP
const GOLDEN_PITY := 250          # guaranteed after this many harvests without one
const GOLDEN_COIN_MULTIPLIER := 5
const GOLDEN_XP := 10
const COLLECTIBLE_CHANCE := 0.05  # one item from the crop's collection
const COLLECTIBLE_PITY := 30
const SUPER_HARVEST_CHANCE := 0.06  # super harvest: double coins
const BIRD_CHANCE := 0.03          # a bird visits: one item from the bird collection
const FERTILIZER_COST := 10
const FERTILIZER_BONUS := 0.2      # +20% coins on a fertilized plot
const BONUS_XP_CHANCE := 0.05     # +2 XP
const BONUS_XP := 2
const MASTERY_LUCK_BONUS := 0.15  # per mastery star, multiplies golden and collectible chances

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const MAX_SIZE := 30   # plots are stored for the largest farm; farm_size says how much is usable
const START_SIZE := 12
const OLD_GRID_SIZE := 12 # saves from before land expansion stored a 12x12 grid
const START_UNWITHERS := 2
const BEE_CHANCE := 0.12           # per flower harvest
const MAX_WAITING_BEES := 10       # bees that wait for hive space
const STRAY_MIN_GAP := 3 * 3600    # a new stray turns up 3 to 6 hours after the last
const STRAY_MAX_GAP := 6 * 3600
const STRAY_STAYS := 86400         # a stray nobody adopts wanders off after a day
const STRAY_ADOPT_XP := 5
const UNWITHER_GEM_COST := 3
const START_COINS := 200
const START_GEMS := 5
const GEMS_PER_LEVEL := 1
const PLOW_COST := 15
const PLOW_XP := 1

# A ripe crop stays ripe as long as it took to grow, clamped to this window.
const MIN_RIPE_WINDOW := 4 * 3600
const MAX_RIPE_WINDOW := 2 * 86400

# Total XP needed to reach level n is LEVEL_XP[n - 1]. Past the table, +250 per level.
# Tuned so level 20 takes about two weeks of regular play (the beta test window).
const LEVEL_XP := [0, 15, 40, 75, 120, 175, 240, 320, 410, 510,
	620, 740, 870, 1010, 1160, 1320, 1490, 1670, 1860, 2060]
const XP_PER_LEVEL_AFTER_TABLE := 250

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
var gems := START_GEMS           # premium currency
var xp := 0
var plots: Array[Dictionary] = []  # MAX_SIZE * MAX_SIZE entries, row-major
var farm_size := START_SIZE        # usable width and depth in tiles
var expansion_steps: Array = []    # from data/expansions.json
var unwithers := START_UNWITHERS   # Unwither items held
var waiting_bees := 0              # bees found with no hive space
var next_stray_at := 0             # when the next stray may turn up
var parts := {"bricks": 0, "nails": 0, "boards": 0}
var last_daily_day := 0            # day number of the last daily gift
var stored: Array = []             # objects put away in the barn (no row or col)
var mastery := {}                  # crop id -> lifetime harvest count
var debug_time_offset := 0         # seconds; only changed by the debug skip button
var tutorial_step: int = Tutorial.HARVEST

var collections: Array = []        # from data/collections.json
var collection_of_crop := {}       # crop id -> collection dictionary
var bird_collection := {}          # the collection whose items are birds
var item_names := {}               # item id -> display name
var ribbon_data := {}              # data/ribbons.json
var owned := {}                    # item id -> count held
var stats := {}                    # lifetime counters for ribbons
var ribbon_tiers := {}             # ribbon id -> tiers earned (0..4)
var pity := {"golden": 0, "collectible": 0}
var items := {}                    # placeable objects from data/items.json
var item_order: Array[String] = []
var objects: Array = []            # placed trees, animals and buildings
var next_uid := 1
var _occupied := {}                # tile index -> uid of the object covering it
var modal_open := false            # true while a menu covers the farm

var rng := RandomNumberGenerator.new()
# Test hooks: tests turn saving off (or point it at a scratch file) and can switch off random drops.
var saving_enabled := true
var save_path := SAVE_PATH
var drops_enabled := true
var _save_queued := false


func _ready() -> void:
	rng.randomize()
	_load_crops()
	_load_collections()
	_load_ribbons()
	_load_items()
	expansion_steps = _read_json("res://data/expansions.json").get("steps", [])
	if not saving_enabled or not load_game():
		_new_game()
	# Deferred so the HUD is connected and can show the message.
	call_deferred("check_rescue")
	call_deferred("check_strays")
	call_deferred("check_daily_gift")
	var stray_timer := Timer.new()
	stray_timer.wait_time = 30.0
	stray_timer.autostart = true
	stray_timer.timeout.connect(check_strays)
	stray_timer.timeout.connect(check_daily_gift)
	add_child(stray_timer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# ---------------------------------------------------------------- time

func now() -> int:
	return int(Time.get_unix_time_from_system()) + debug_time_offset


func add_gems(amount: int) -> void:
	gems += amount
	gems_changed.emit(gems)
	queue_save()


func spend_gems(amount: int) -> bool:
	if gems < amount:
		return false
	gems -= amount
	gems_changed.emit(gems)
	queue_save()
	return true


## Test helpers. They do nothing in release builds.
func debug_add_coins(amount: int) -> void:
	if OS.is_debug_build():
		add_coins(amount, false)
		add_gems(int(amount / 1000.0))


func debug_level_up() -> void:
	if OS.is_debug_build():
		add_xp(xp_for_level(level() + 1) - xp)


func debug_skip(seconds: int) -> void:
	if not OS.is_debug_build():
		return
	debug_time_offset += seconds
	check_strays()
	check_daily_gift()
	plot_changed.emit(-1)
	check_rescue()
	queue_save()


# ---------------------------------------------------------------- plots

func index_of(row: int, col: int) -> int:
	return row * MAX_SIZE + col


func in_farm(row: int, col: int) -> bool:
	return row >= 0 and col >= 0 and row < farm_size and col < farm_size


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
	if is_occupied(i):
		return false
	if not spend(PLOW_COST):
		message.emit("Not enough coins to plow")
		return false
	plots[i] = {"state": "plowed"}
	add_xp(PLOW_XP)
	_bump("plowed", 1)
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


func is_fertilized(i: int) -> bool:
	return plots[i].get("fert", false)


## Fertilizer goes on a planted crop that isn't ripe or withered yet.
func fertilize(i: int) -> bool:
	if phase(i) != Phase.GROWING or is_fertilized(i):
		return false
	if not spend(FERTILIZER_COST):
		message.emit("Not enough coins for fertilizer")
		return false
	plots[i]["fert"] = true
	_bump("fertilized", 1)
	_plot_updated(i)
	return true


## Returns {"coins", "xp", "crop", "drop", "drop_text"} or {} if nothing was harvested.
## "drop" is "", "golden", "bird", "collectible", "super_harvest" or "bonus_xp".
func harvest(i: int) -> Dictionary:
	if phase(i) != Phase.RIPE:
		return {}
	var crop_id: String = plots[i]["crop"]
	var crop: Dictionary = crops[crop_id]
	var stars_before := mastery_stars(crop_id)
	var fertilized: bool = plots[i].get("fert", false)
	var bonus := MASTERY_PRICE_BONUS * stars_before + (FERTILIZER_BONUS if fertilized else 0.0)
	var earned := int(round(float(crop["sell_price"]) * (1.0 + bonus)))
	var gained := int(crop["xp"])

	var drop := _roll_drop(crop_id, stars_before)
	match drop.get("type", ""):
		"golden":
			earned *= GOLDEN_COIN_MULTIPLIER
			gained += GOLDEN_XP
		"super_harvest":
			earned *= 2
		"bonus_xp":
			gained += BONUS_XP

	plots[i] = {"state": "plowed"}
	# A fertilized harvest counts double toward mastery.
	mastery[crop_id] = int(mastery.get(crop_id, 0)) + (2 if fertilized else 1)
	add_coins(earned)
	add_xp(gained)
	_bump("harvests", 1)
	if drop.get("type", "") == "golden":
		_bump("golden_finds", 1)
		message.emit("Golden harvest! %s paid %dx coins" % [crop["name"], GOLDEN_COIN_MULTIPLIER])
	elif drop.get("type", "") == "collectible":
		message.emit("You found a %s! (%s collection)" % [drop["name"], drop["collection"]])
	elif drop.get("type", "") == "bird":
		message.emit("A %s landed on your farm! (%s collection)" % [drop["name"].to_lower(), drop["collection"]])
	var part := _roll_part()
	var found_bee: bool = crop.get("flower", false) and rng.randf() < BEE_CHANCE
	if found_bee:
		_add_bee()
	var stars_after := mastery_stars(crop_id)
	if stars_after > stars_before:
		_award_mastery_star(crop_id, stars_after)
	if tutorial_step == Tutorial.HARVEST and not _any_plot_in(Phase.RIPE):
		_advance_tutorial(Tutorial.HARVEST)
	_plot_updated(i)
	return {"coins": earned, "xp": gained, "crop": crop_id, "bee": found_bee,
		"drop": drop.get("type", ""), "drop_text": drop.get("text", ""), "part": part}


# ---------------------------------------------------------------- surprise drops

## One roll per harvest. Rarest outcomes are checked first; pity counters
## guarantee a golden harvest or a collectible after a long dry spell.
func _roll_drop(crop_id: String, stars: int) -> Dictionary:
	if not drops_enabled:
		return {}
	pity["golden"] = int(pity["golden"]) + 1
	pity["collectible"] = int(pity["collectible"]) + 1
	var luck := 1.0 + MASTERY_LUCK_BONUS * stars

	if int(pity["golden"]) >= GOLDEN_PITY or rng.randf() < GOLDEN_CHANCE * luck:
		pity["golden"] = 0
		return {"type": "golden", "text": "Golden harvest!"}

	# A due collectible (pity) always wins over a bird visit.
	var collectible_due := int(pity["collectible"]) >= COLLECTIBLE_PITY
	if not bird_collection.is_empty() and not collectible_due and rng.randf() < BIRD_CHANCE:
		var bird_id := _pick_item(bird_collection)
		owned[bird_id] = int(owned.get(bird_id, 0)) + 1
		collections_changed.emit()
		return {"type": "bird", "text": "A %s visited!" % item_names[bird_id].to_lower(),
			"name": item_names[bird_id], "collection": bird_collection["name"]}

	var coll: Dictionary = collection_of_crop.get(crop_id, {})
	if not coll.is_empty() and (int(pity["collectible"]) >= COLLECTIBLE_PITY or rng.randf() < COLLECTIBLE_CHANCE * luck):
		pity["collectible"] = 0
		var item_id := _pick_item(coll)
		owned[item_id] = int(owned.get(item_id, 0)) + 1
		collections_changed.emit()
		return {"type": "collectible", "text": "Found: " + item_names[item_id],
			"name": item_names[item_id], "collection": coll["name"]}

	var r := rng.randf()
	if r < SUPER_HARVEST_CHANCE:
		return {"type": "super_harvest", "text": "Super harvest! 2x coins"}
	if r < SUPER_HARVEST_CHANCE + BONUS_XP_CHANCE:
		return {"type": "bonus_xp", "text": "Bonus XP!"}
	return {}


## Items you hold fewer of are more likely, so sets fill up instead of piling duplicates.
func _pick_item(coll: Dictionary) -> String:
	var weights: Array[float] = []
	var total := 0.0
	for item in coll["items"]:
		var w := 1.0 / (1.0 + 2.0 * int(owned.get(item["id"], 0)))
		weights.append(w)
		total += w
	var pick := rng.randf() * total
	for k in weights.size():
		pick -= weights[k]
		if pick <= 0.0:
			return coll["items"][k]["id"]
	return coll["items"][-1]["id"]


# ---------------------------------------------------------------- collections

func can_trade_in(coll: Dictionary) -> bool:
	for item in coll["items"]:
		if int(owned.get(item["id"], 0)) < 1:
			return false
	return true


func trade_in(coll_id: String) -> bool:
	for coll in collections:
		if coll["id"] != coll_id:
			continue
		if not can_trade_in(coll):
			return false
		for item in coll["items"]:
			owned[item["id"]] = int(owned[item["id"]]) - 1
		add_coins(int(coll["reward_coins"]))
		add_xp(int(coll["reward_xp"]))
		message.emit("%s collection traded in: +%d coins, +%d XP" % [
			coll["name"], int(coll["reward_coins"]), int(coll["reward_xp"])])
		_bump("collections_traded", 1)
		add_unwithers(1)
		collections_changed.emit()
		queue_save()
		return true
	return false


# ---------------------------------------------------------------- ribbons

func stat(stat_name: String) -> int:
	return int(stats.get(stat_name, 0))


func _bump(stat_name: String, amount: int) -> void:
	stats[stat_name] = stat(stat_name) + amount
	_check_ribbons(stat_name)


func _check_ribbons(stat_name: String) -> void:
	if ribbon_data.is_empty():
		return
	var tier_names: Array = ribbon_data["tiers"]
	for r in ribbon_data["ribbons"]:
		if r["stat"] != stat_name:
			continue
		var earned := int(ribbon_tiers.get(r["id"], 0))
		var thresholds: Array = r["thresholds"]
		while earned < thresholds.size() and stat(stat_name) >= int(thresholds[earned]):
			earned += 1
			ribbon_tiers[r["id"]] = earned
			# Rewards are paid without counting toward "coins earned", so ribbons can't chain.
			coins += int(ribbon_data["tier_reward_coins"][earned - 1])
			coins_changed.emit(coins)
			add_xp(int(ribbon_data["tier_reward_xp"][earned - 1]))
			message.emit("%s ribbon: %s! +%d coins" % [
				tier_names[earned - 1], r["name"], int(ribbon_data["tier_reward_coins"][earned - 1])])
			ribbons_changed.emit()
	queue_save()


# ---------------------------------------------------------------- placed objects
# Trees, animals and buildings sit on grass tiles. Each object is a dictionary:
# {"uid", "id", "row", "col", "t"} where t is when its current cycle started.
# Buildings also have "level" and "inside" (item id -> count).

func item_data(item_id: String) -> Dictionary:
	return items.get(item_id, {})


func footprint(item_id: String) -> Vector2i:
	var it := item_data(item_id)
	return Vector2i(int(it.get("w", 1)), int(it.get("h", 1)))


func object_at(i: int) -> Dictionary:
	return object_by_uid(int(_occupied.get(i, -1)))


func object_by_uid(uid: int) -> Dictionary:
	for o in objects:
		if int(o["uid"]) == uid:
			return o
	return {}


func is_occupied(i: int) -> bool:
	return _occupied.has(i)


func _rebuild_occupancy() -> void:
	_occupied.clear()
	for o in objects:
		var fp := footprint(o["id"])
		for r in range(int(o["row"]), int(o["row"]) + fp.y):
			for c in range(int(o["col"]), int(o["col"]) + fp.x):
				_occupied[index_of(r, c)] = int(o["uid"])


## Objects go on grass or empty plowed plots, never on planted crops or other objects.
func can_place(item_id: String, row: int, col: int, ignore_uid := -1) -> bool:
	var fp := footprint(item_id)
	if row < 0 or col < 0 or row + fp.y > farm_size or col + fp.x > farm_size:
		return false
	for r in range(row, row + fp.y):
		for c in range(col, col + fp.x):
			var i := index_of(r, c)
			var holder := int(_occupied.get(i, -1))
			if holder != -1 and holder != ignore_uid:
				return false
			if plots[i].get("state", "grass") == "planted":
				return false
	return true


func _grass_over(item_id: String, row: int, col: int) -> void:
	var fp := footprint(item_id)
	for r in range(row, row + fp.y):
		for c in range(col, col + fp.x):
			plots[index_of(r, c)] = {"state": "grass"}


func can_afford_item(item_id: String) -> bool:
	return coins >= int(item_data(item_id).get("cost", 0))


func buy_and_place(item_id: String, row: int, col: int) -> bool:
	var it := item_data(item_id)
	if it.is_empty():
		return false
	if level() < int(it["unlock_level"]):
		message.emit("%s unlocks at level %d" % [it["name"], int(it["unlock_level"])])
		return false
	if not can_place(item_id, row, col):
		return false
	if not spend(int(it["cost"])):
		message.emit("Not enough coins for a %s" % it["name"])
		return false
	var obj := {"uid": next_uid, "id": item_id, "row": row, "col": col, "t": now()}
	if it["kind"] == "building":
		obj["level"] = 1
		obj["inside"] = {}
		message.emit("%s built! Open it to move animals in." % it["name"])
	next_uid += 1
	_grass_over(item_id, row, col)
	objects.append(obj)
	_house_waiting_bees()
	_objects_updated()
	return true


func move_object(uid: int, row: int, col: int) -> bool:
	var obj := object_by_uid(uid)
	if obj.is_empty() or not can_place(obj["id"], row, col, uid):
		return false
	obj["row"] = row
	obj["col"] = col
	_grass_over(obj["id"], row, col)
	_objects_updated()
	return true


func cycle_of(obj: Dictionary) -> int:
	var base := int(item_data(obj["id"]).get("cycle_seconds", 86400))
	if is_building(obj) and level_of(obj) >= TOP_LEVEL:
		return int(base * TOP_LEVEL_SPEEDUP)
	return base


func level_of(obj: Dictionary) -> int:
	return int(obj.get("level", 1))


## What a building gets at a given level: capacity, earnings bonus %, speed-up %, extra luck.
func perks_at(building_id: String, lvl: int) -> Dictionary:
	var levels: Array = item_data(building_id).get("levels", [0])
	return {
		"capacity": int(levels[clampi(lvl - 1, 0, levels.size() - 1)]),
		"earnings_pct": int(round(UPGRADE_EARNINGS_BONUS * (lvl - 1) * 100.0)),
		"faster_pct": int(round((1.0 - TOP_LEVEL_SPEEDUP) * 100.0)) if lvl >= TOP_LEVEL else 0,
		"luck": lvl - 1,
	}


func kind_of(obj: Dictionary) -> String:
	return item_data(obj["id"]).get("kind", "")


func is_building(obj: Dictionary) -> bool:
	return item_data(obj["id"]).get("kind", "") == "building"


func is_ready(obj: Dictionary) -> bool:
	if obj.get("stray", false):
		return false
	if kind_of(obj) == "decor" or kind_of(obj) == "barn":
		return false # scenery and the barn never produce
	if is_building(obj) and inside_total(obj) == 0:
		return false
	return now() - int(obj["t"]) >= cycle_of(obj)


func seconds_until_ready(obj: Dictionary) -> int:
	return maxi(0, int(obj["t"]) + cycle_of(obj) - now())


## Coins and XP one collection pays.
func object_payout(obj: Dictionary) -> Vector2i:
	if not is_building(obj):
		var it := item_data(obj["id"])
		return Vector2i(int(it["payout"]), int(it["xp"]))
	var total := Vector2i.ZERO
	var inside: Dictionary = obj["inside"]
	for id in inside:
		var it2 := item_data(id)
		total += Vector2i(int(it2["payout"]), int(it2["xp"])) * int(inside[id])
	# Upgraded buildings earn more coins per collection.
	total.x = int(round(total.x * (1.0 + UPGRADE_EARNINGS_BONUS * (level_of(obj) - 1))))
	return total


## Returns {"coins", "xp", "drop", "drop_text", "name"} or {} if nothing was ready.
func collect(uid: int) -> Dictionary:
	var obj := object_by_uid(uid)
	if obj.is_empty() or not is_ready(obj):
		return {}
	var pay := object_payout(obj)
	var earned := pay.x
	var gained := pay.y
	# Upgrades count like mastery stars for luck: better odds of rare finds.
	var drop := _roll_drop("", level_of(obj) - 1 if is_building(obj) else 0)
	match drop.get("type", ""):
		"golden":
			earned *= GOLDEN_COIN_MULTIPLIER
			gained += GOLDEN_XP
		"super_harvest":
			earned *= 2
		"bonus_xp":
			gained += BONUS_XP
	obj["t"] = now()
	add_coins(earned)
	add_xp(gained)
	_bump("collected", 1)
	var part := _roll_part()
	if drop.get("type", "") == "golden":
		_bump("golden_finds", 1)
		message.emit("Golden collection! %dx coins" % GOLDEN_COIN_MULTIPLIER)
	elif drop.get("type", "") == "bird":
		message.emit("A %s landed on your farm! (%s collection)" % [drop["name"].to_lower(), drop["collection"]])
	_objects_updated()
	return {"coins": earned, "xp": gained, "drop": drop.get("type", ""),
		"drop_text": drop.get("text", ""), "name": item_data(obj["id"])["name"], "part": part}


# ---------------------------------------------------------------- buildings

func building_accepts(building: Dictionary, item_id: String) -> bool:
	var b := item_data(building["id"])
	if b.has("holds_kind"):
		return item_data(item_id).get("kind", "") == b["holds_kind"]
	return (b.get("holds", []) as Array).has(item_id)


func capacity(building: Dictionary) -> int:
	var levels: Array = item_data(building["id"])["levels"]
	return int(levels[clampi(int(building["level"]) - 1, 0, levels.size() - 1)])


func inside_total(building: Dictionary) -> int:
	var total := 0
	var inside: Dictionary = building.get("inside", {})
	for id in inside:
		total += int(inside[id])
	return total


func loose_matching(building: Dictionary) -> int:
	var n := 0
	for o in objects:
		if not is_building(o) and not o.get("stray", false) and building_accepts(building, o["id"]):
			n += 1
	return n


## Moves loose animals or trees of the right type into the building, up to its capacity.
func fill_building(uid: int) -> int:
	var b := object_by_uid(uid)
	if b.is_empty() or not is_building(b):
		return 0
	var was_empty := inside_total(b) == 0
	var room := capacity(b) - inside_total(b)
	var moved := 0
	var keep: Array = []
	for o in objects:
		if moved < room and not is_building(o) and not o.get("stray", false) and building_accepts(b, o["id"]):
			var inside: Dictionary = b["inside"]
			inside[o["id"]] = int(inside.get(o["id"], 0)) + 1
			moved += 1
		else:
			keep.append(o)
	if moved == 0:
		return 0
	objects = keep
	if was_empty:
		b["t"] = now() # the first cycle starts when something moves in
	message.emit("Moved %d into the %s" % [moved, item_data(b["id"])["name"]])
	_objects_updated()
	return moved


## Coins to reach the next level, or -1 at the top level.
func upgrade_cost(building: Dictionary) -> int:
	var costs: Array = item_data(building["id"]).get("upgrade_costs", [])
	var idx := int(building["level"]) - 1
	return int(costs[idx]) if idx < costs.size() else -1


func upgrade_building(uid: int) -> bool:
	var b := object_by_uid(uid)
	if b.is_empty() or not is_building(b):
		return false
	var cost := upgrade_cost(b)
	if cost < 0:
		return false
	if not spend(cost):
		message.emit("Not enough coins to upgrade")
		return false
	b["level"] = int(b["level"]) + 1
	var lvl := int(b["level"])
	var perks := perks_at(b["id"], lvl)
	var parts_of_msg: Array[String] = ["holds %d" % capacity(b), "+%d%% earnings" % int(perks["earnings_pct"])]
	if int(perks["faster_pct"]) > 0:
		parts_of_msg.append("%d%% faster" % int(perks["faster_pct"]))
	message.emit("%s is now level %d: %s" % [item_data(b["id"])["name"], lvl, ", ".join(PackedStringArray(parts_of_msg))])
	add_xp(UPGRADE_XP_PER_LEVEL * lvl)
	_bump("upgrades", 1)
	building_upgraded.emit(uid, lvl)
	_house_waiting_bees()
	_objects_updated()
	return true


# ---------------------------------------------------------------- parts and the daily gift

func day_number() -> int:
	return int(now() / 86400.0)


## A part for this harvest or collection, or "" for none. Fewer-held parts are likelier.
func _roll_part() -> String:
	if not drops_enabled or rng.randf() >= PART_CHANCE:
		return ""
	var p := _pick_part()
	add_part(p, 1)
	return p


func _pick_part() -> String:
	var weights: Array[float] = []
	var total := 0.0
	for p in PARTS:
		var w := 1.0 / (1.0 + int(parts.get(p, 0)))
		weights.append(w)
		total += w
	var pick := rng.randf() * total
	for k in PARTS.size():
		pick -= weights[k]
		if pick <= 0.0:
			return PARTS[k]
	return PARTS[-1]


func add_part(part: String, n: int) -> void:
	parts[part] = int(parts.get(part, 0)) + n
	_bump("parts_found", n)
	inventory_changed.emit()
	queue_save()


## Once per calendar day: a couple of free parts.
func check_daily_gift() -> void:
	var today := day_number()
	if today <= last_daily_day:
		return
	last_daily_day = today
	var got: Array[String] = []
	for k in DAILY_PARTS:
		var p := _pick_part()
		add_part(p, 1)
		got.append(PART_NAMES[p])
	message.emit("Daily gift: " + ", ".join(PackedStringArray(got)))
	queue_save()


# ---------------------------------------------------------------- barn

func barn() -> Dictionary:
	for o in objects:
		if o["id"] == "barn":
			return o
	return {}


func barn_repaired() -> bool:
	var b := barn()
	return not b.is_empty() and not b.get("broken", false)


func repair_needs() -> Dictionary:
	return item_data("barn").get("repair_parts", {})


func can_repair_barn() -> bool:
	var b := barn()
	if b.is_empty() or not b.get("broken", false):
		return false
	var need := repair_needs()
	for p in need:
		if int(parts.get(p, 0)) < int(need[p]):
			return false
	return true


func repair_barn() -> bool:
	if not can_repair_barn():
		return false
	var need := repair_needs()
	for p in need:
		parts[p] = int(parts[p]) - int(need[p])
	var b := barn()
	b.erase("broken")
	var it := item_data("barn")
	add_coins(int(it.get("repair_coins", 0)))
	add_xp(int(it.get("repair_xp", 0)))
	message.emit("The Barn is fixed! Use the Store tool to put things away in it.")
	_bump("buildings_repaired", 1)
	inventory_changed.emit()
	_objects_updated()
	return true


func barn_capacity() -> int:
	var levels: Array = item_data("barn").get("levels", [0])
	return int(levels[0])


## Trees, animals and scenery can be stored; shelters, the barn and strays can't.
func can_store(obj: Dictionary) -> bool:
	if obj.is_empty() or obj.get("stray", false):
		return false
	var k := kind_of(obj)
	return k == "tree" or k == "animal" or k == "decor"


func store_object(uid: int) -> bool:
	var o := object_by_uid(uid)
	if not barn_repaired():
		message.emit("Fix the Barn first to store things")
		return false
	if not can_store(o):
		message.emit("That can't go in the barn")
		return false
	if stored.size() >= barn_capacity():
		message.emit("The barn is full")
		return false
	objects.erase(o)
	o.erase("row")
	o.erase("col")
	stored.append(o)
	message.emit("%s stored in the barn" % item_data(o["id"])["name"])
	inventory_changed.emit()
	_objects_updated()
	return true


func place_from_storage(index: int, row: int, col: int) -> bool:
	if index < 0 or index >= stored.size():
		return false
	var o: Dictionary = stored[index]
	if not can_place(o["id"], row, col):
		return false
	stored.remove_at(index)
	o["row"] = row
	o["col"] = col
	o["t"] = now() # production restarts when it comes back out
	_grass_over(o["id"], row, col)
	objects.append(o)
	inventory_changed.emit()
	_objects_updated()
	return true


# ---------------------------------------------------------------- bees

func _hive_with_room() -> Dictionary:
	for o in objects:
		if o["id"] == "beehive" and inside_total(o) < capacity(o):
			return o
	return {}


func _add_bee() -> void:
	_bump("bees_found", 1)
	var hive := _hive_with_room()
	if not hive.is_empty():
		_put_bee_in(hive)
		message.emit("A bee followed you home to the hive!")
	elif waiting_bees < MAX_WAITING_BEES:
		waiting_bees += 1
		message.emit("A bee is buzzing around. Build a Beehive to keep it (%d waiting)" % waiting_bees)
	else:
		message.emit("A bee flew off: build or upgrade a Beehive to keep more")
	inventory_changed.emit()
	_objects_updated()


func _put_bee_in(hive: Dictionary) -> void:
	var inside: Dictionary = hive["inside"]
	if inside_total(hive) == 0:
		hive["t"] = now() # honey starts once the first bee moves in
	inside["bee"] = int(inside.get("bee", 0)) + 1


func _house_waiting_bees() -> void:
	var moved := 0
	while waiting_bees > 0:
		var hive := _hive_with_room()
		if hive.is_empty():
			break
		_put_bee_in(hive)
		waiting_bees -= 1
		moved += 1
	if moved > 0:
		message.emit("%d waiting bees moved into the hive" % moved)
		inventory_changed.emit()


# ---------------------------------------------------------------- strays

## Called on start, every 30 seconds, and after a debug time skip.
func check_strays() -> void:
	var t := now()
	var changed := false
	var keep: Array = []
	for o in objects:
		if o.get("stray", false) and t - int(o["t"]) > STRAY_STAYS:
			message.emit("The lonely %s wandered off." % item_data(o["id"])["name"].to_lower())
			changed = true
		else:
			keep.append(o)
	objects = keep
	if t >= next_stray_at and not _has_stray():
		if _spawn_stray():
			changed = true
		next_stray_at = t + rng.randi_range(STRAY_MIN_GAP, STRAY_MAX_GAP)
		queue_save()
	if changed:
		_objects_updated()


func _has_stray() -> bool:
	for o in objects:
		if o.get("stray", false):
			return true
	return false


## Picks an animal near the player's level (cheaper ones more often) and an open grass tile.
func _spawn_stray() -> bool:
	var choices: Array[String] = []
	var weights: Array[float] = []
	var total := 0.0
	for id in item_order:
		var it: Dictionary = items[id]
		if it["kind"] == "animal" and int(it["unlock_level"]) <= level() + 2:
			var w := 1.0 / maxf(1.0, float(it["cost"]) / 100.0)
			choices.append(id)
			weights.append(w)
			total += w
	if choices.is_empty():
		return false
	var pick := rng.randf() * total
	var animal_id := choices[-1]
	for k in choices.size():
		pick -= weights[k]
		if pick <= 0.0:
			animal_id = choices[k]
			break
	var spots: Array[Vector2i] = []
	for r in farm_size:
		for c in farm_size:
			var i := index_of(r, c)
			if plots[i].get("state", "grass") == "grass" and not is_occupied(i):
				spots.append(Vector2i(r, c))
	if spots.is_empty():
		return false
	var spot := spots[rng.randi_range(0, spots.size() - 1)]
	objects.append({"uid": next_uid, "id": animal_id, "row": spot.x, "col": spot.y, "t": now(), "stray": true})
	next_uid += 1
	message.emit("A lonely %s wandered onto your farm! Tap it to adopt." % item_data(animal_id)["name"].to_lower())
	return true


func adopt_stray(uid: int) -> bool:
	var o := object_by_uid(uid)
	if o.is_empty() or not o.get("stray", false):
		return false
	o.erase("stray")
	o["t"] = now() # starts producing from today
	add_xp(STRAY_ADOPT_XP)
	_bump("strays_adopted", 1)
	message.emit("You adopted the %s! It's part of your farm now." % item_data(o["id"])["name"].to_lower())
	_objects_updated()
	return true


func _objects_updated() -> void:
	_rebuild_occupancy()
	objects_changed.emit()
	plot_changed.emit(-1)
	queue_save()


# ---------------------------------------------------------------- land expansion

## The next expansion step, or {} when the farm is at full size.
func next_expansion() -> Dictionary:
	for step in expansion_steps:
		if int(step["size"]) > farm_size:
			return step
	return {}


func can_expand_with_coins() -> bool:
	var step := next_expansion()
	return not step.is_empty() and level() >= int(step["level"]) and coins >= int(step["coins"])


## Coins need the step's level; gems skip the level requirement.
func expand(use_gems: bool) -> bool:
	var step := next_expansion()
	if step.is_empty():
		return false
	if use_gems:
		if not spend_gems(int(step["gems"])):
			message.emit("Not enough gems to expand")
			return false
	else:
		if level() < int(step["level"]):
			message.emit("Reach level %d to expand with coins" % int(step["level"]))
			return false
		if not spend(int(step["coins"])):
			message.emit("Not enough coins to expand")
			return false
	farm_size = int(step["size"])
	message.emit("Your farm grew to %d x %d!" % [farm_size, farm_size])
	_bump("expansions", 1)
	farm_expanded.emit(farm_size)
	plot_changed.emit(-1)
	queue_save()
	return true


## Old saves: copy the 12x12 grid into the top-left of the full-size grid.
func _widen_old_grid(old: Array) -> Array:
	var wide: Array = []
	for i in MAX_SIZE * MAX_SIZE:
		wide.append({"state": "grass"})
	for r in OLD_GRID_SIZE:
		for c in OLD_GRID_SIZE:
			wide[r * MAX_SIZE + c] = old[r * OLD_GRID_SIZE + c]
	return wide


# ---------------------------------------------------------------- unwither

func withered_count() -> int:
	var n := 0
	for r in farm_size:
		for c in farm_size:
			if phase(index_of(r, c)) == Phase.WITHERED:
				n += 1
	return n


## Brings every withered crop back to ripe. Uses an Unwither item, or gems if none are left.
func use_unwither() -> bool:
	var count := withered_count()
	if count == 0:
		message.emit("Nothing has withered. Save it for when crops go bad.")
		return false
	if unwithers > 0:
		unwithers -= 1
	elif not spend_gems(UNWITHER_GEM_COST):
		message.emit("No Unwither left, and not enough gems for one")
		return false
	var t := now()
	for r in farm_size:
		for c in farm_size:
			var i := index_of(r, c)
			if phase(i) == Phase.WITHERED:
				plots[i]["planted_at"] = t - int(crops[plots[i]["crop"]]["grow_seconds"])
	message.emit("Unwithered %d plots! They're ready to harvest." % count)
	inventory_changed.emit()
	plot_changed.emit(-1)
	queue_save()
	return true


func add_unwithers(n: int) -> void:
	unwithers += n
	inventory_changed.emit()
	queue_save()


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
	add_coins(gift, false)
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
	_bump("mastery_stars", 1)


# ---------------------------------------------------------------- economy

func spend(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	queue_save()
	return true


## counts_as_earned: false for gifts like the barn rescue, so they don't advance ribbons.
func add_coins(amount: int, counts_as_earned := true) -> void:
	coins += amount
	coins_changed.emit(coins)
	if counts_as_earned:
		_bump("coins_earned", amount)
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


## Coins paid on reaching a level: grows with level so later levels still feel big.
func level_reward(lvl: int) -> int:
	return 100 * lvl


## Names of crops, trees, animals and buildings that unlock at exactly this level.
func unlocks_at(lvl: int) -> Array[String]:
	var names: Array[String] = []
	for id in crop_order:
		if int(crops[id]["unlock_level"]) == lvl:
			names.append(crops[id]["name"] + " seeds")
	for id in item_order:
		if int(items[id]["unlock_level"]) == lvl:
			names.append(items[id]["name"])
	return names


func _on_level_reached(lvl: int) -> void:
	# The reward is a gift, so it doesn't count toward the coins-earned ribbon.
	add_coins(level_reward(lvl), false)
	add_gems(GEMS_PER_LEVEL)
	if lvl % 5 == 0:
		add_unwithers(1)
	leveled_up.emit(lvl) # the HUD shows the celebration popup


# ---------------------------------------------------------------- data

func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(path + " is not valid JSON")
		return {}
	return parsed


func _load_crops() -> void:
	var parsed := _read_json("res://data/crops.json")
	for c in parsed.get("crops", []):
		crops[c["id"]] = c
		crop_order.append(c["id"])


func _load_collections() -> void:
	var parsed := _read_json("res://data/collections.json")
	collections = parsed.get("collections", [])
	for coll in collections:
		if coll.get("birds", false):
			bird_collection = coll
		for crop_id in coll.get("crops", []):
			collection_of_crop[crop_id] = coll
		for item in coll["items"]:
			item_names[item["id"]] = item["name"]


func _load_ribbons() -> void:
	ribbon_data = _read_json("res://data/ribbons.json")


func _load_items() -> void:
	var parsed := _read_json("res://data/items.json")
	for it in parsed.get("items", []):
		items[it["id"]] = it
		item_order.append(it["id"])


func _new_game() -> void:
	coins = START_COINS
	gems = START_GEMS
	xp = 0
	mastery = {}
	debug_time_offset = 0
	tutorial_step = Tutorial.HARVEST
	owned = {}
	stats = {}
	ribbon_tiers = {}
	pity = {"golden": 0, "collectible": 0}
	objects = []
	next_uid = 1
	_occupied.clear()
	plots.clear()
	farm_size = START_SIZE
	unwithers = START_UNWITHERS
	waiting_bees = 0
	next_stray_at = now() + STRAY_MIN_GAP
	for i in MAX_SIZE * MAX_SIZE:
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
	# Scenery, a few animals and a run-down barn, so the farm feels lived in from the start.
	_add_starter_object("farmhouse", 0, 0)
	_add_starter_object("barn", 0, 8, {"broken": true})
	_add_starter_object("mailbox", 4, 0)
	_add_starter_object("farm_stand", 4, 1)
	_add_starter_object("chicken", 9, 2)
	_add_starter_object("chicken", 9, 3)
	_add_starter_object("cow", 10, 6)
	parts = {"bricks": 0, "nails": 0, "boards": 0}
	stored = []
	last_daily_day = day_number()
	_rebuild_occupancy()
	save_game()


func _add_starter_object(item_id: String, row: int, col: int, extra := {}) -> void:
	var obj := {"uid": next_uid, "id": item_id, "row": row, "col": col, "t": now()}
	obj.merge(extra)
	objects.append(obj)
	next_uid += 1


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
	if not saving_enabled:
		return
	var data := {
		"version": SAVE_VERSION,
		"saved_at": now(),
		"coins": coins,
		"gems": gems,
		"xp": xp,
		"mastery": mastery,
		"plots": plots,
		"debug_time_offset": debug_time_offset,
		"tutorial_step": tutorial_step,
		"owned": owned,
		"stats": stats,
		"ribbon_tiers": ribbon_tiers,
		"pity": pity,
		"objects": objects,
		"farm_size": farm_size,
		"unwithers": unwithers,
		"waiting_bees": waiting_bees,
		"parts": parts,
		"last_daily_day": last_daily_day,
		"stored": stored,
		"next_stray_at": next_stray_at,
		"next_uid": next_uid,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SAVE_VERSION:
		return false
	var saved_plots: Array = data.get("plots", [])
	if saved_plots.size() == OLD_GRID_SIZE * OLD_GRID_SIZE:
		saved_plots = _widen_old_grid(saved_plots)
	if saved_plots.size() != MAX_SIZE * MAX_SIZE:
		return false
	farm_size = clampi(int(data.get("farm_size", START_SIZE)), START_SIZE, MAX_SIZE)
	unwithers = int(data.get("unwithers", START_UNWITHERS))
	waiting_bees = int(data.get("waiting_bees", 0))
	var saved_parts: Dictionary = data.get("parts", {})
	parts = {}
	for p in PARTS:
		parts[p] = int(saved_parts.get(p, 0))
	last_daily_day = int(data.get("last_daily_day", day_number()))
	stored = []
	for o in data.get("stored", []):
		if items.has(o.get("id", "")):
			o["uid"] = int(o["uid"])
			o["t"] = int(o.get("t", 0))
			stored.append(o)
	next_stray_at = int(data.get("next_stray_at", 0))
	coins = int(data.get("coins", START_COINS))
	gems = int(data.get("gems", START_GEMS))
	xp = int(data.get("xp", 0))
	mastery = data.get("mastery", {})
	debug_time_offset = int(data.get("debug_time_offset", 0)) if OS.is_debug_build() else 0
	# Saves from before the tutorial existed belong to players who already know the basics.
	tutorial_step = int(data.get("tutorial_step", Tutorial.DONE))
	# Fields added in milestone 2 default to empty for older saves.
	owned = data.get("owned", {})
	stats = data.get("stats", {})
	ribbon_tiers = data.get("ribbon_tiers", {})
	var saved_pity: Dictionary = data.get("pity", {})
	pity = {"golden": int(saved_pity.get("golden", 0)), "collectible": int(saved_pity.get("collectible", 0))}
	objects = []
	for o in data.get("objects", []):
		var obj: Dictionary = o
		if not items.has(obj.get("id", "")):
			continue # item removed from the data file
		obj["uid"] = int(obj["uid"])
		obj["row"] = int(obj["row"])
		obj["col"] = int(obj["col"])
		obj["t"] = int(obj["t"])
		if obj.has("level"):
			obj["level"] = int(obj["level"])
		objects.append(obj)
	next_uid = int(data.get("next_uid", 1))
	plots.clear()
	for p in saved_plots:
		var plot: Dictionary = p
		# Drop plots whose crop no longer exists in the data file.
		if plot.get("state") == "planted" and not crops.has(plot.get("crop", "")):
			plot = {"state": "plowed"}
		plots.append(plot)
	_rebuild_occupancy()
	return true


func reset_game() -> void:
	_new_game()
	coins_changed.emit(coins)
	gems_changed.emit(gems)
	xp_changed.emit(xp, level())
	tutorial_changed.emit(tutorial_step)
	collections_changed.emit()
	ribbons_changed.emit()
	objects_changed.emit()
	inventory_changed.emit()
	farm_expanded.emit(farm_size)
	plot_changed.emit(-1)


func _plot_updated(i: int) -> void:
	plot_changed.emit(i)
	queue_save()
