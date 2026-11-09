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
signal found(index: int, text: String) # a find on a plot (fuel, a collectible...): floats up from it
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
# Building materials, the FarmVille set: three basic ones every building uses,
# plus two specific to some buildings (they only drop once you own that building).
# Materials come from data/catalog/materials.json (filled in when the catalog loads).
static var BASIC_PARTS: Array[String] = []
static var PARTS: Array[String] = []
static var PART_NAMES := {}
const PART_CHANCE := 0.08          # per harvest or collection
const DAILY_PARTS := 2
# FarmVille's daily bonus: come back on consecutive days for a bigger reward, up to day 5.
const DAILY_STREAK := [
	{"coins": 100}, {"coins": 250}, {"coins": 500, "fertilizer": 1},
	{"coins": 750, "unwither": 1}, {"coins": 1000, "gems": 1}]
const SELL_SHARE := PlaceableDef.SELL_SHARE
const SELL_COINS_PER_GEM := PlaceableDef.SELL_COINS_PER_GEM
const DECOR_MIN_XP := DecorationDef.MIN_XP
const LAMB_CHANCE := 0.25          # Sheep Pen harvest with a ram inside
const PIGLET_CHANCE := 0.25        # Pig Pen harvest with a boar inside

# Building specials, the FarmVille way.
const CALF_CHANCE := 0.25          # Dairy Farm harvest with a bull inside
const FERTILIZER_CHANCE := 0.10    # Dairy Farm harvest drops a bag of fertilizer
const FOAL_CHANCE := 0.25          # Horse Stable harvest with a stallion inside
const STABLE_HELPER_CHANCE := 0.15 # Stable harvest: a farmhand, and separately an arborist
const STABLE_XP_CHANCE := 0.10     # Stable harvest with a stallion: 100 XP
const STABLE_XP := 100
const NURSERY_SPARE_XP := 25       # stands in for FarmVille's spare baby to gift a friend

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
# Beehive, as in FarmVille: a Queen Bee makes the hive work, worker bees join it,
# and the bees pollinate fertilized crops nearby.
const QUEEN_CHANCE := 0.008        # a Queen Bee found on a flower harvest
const QUEEN_GEM_COST := 10
const BEE_CHANCE := 0.25           # per flower harvest, only into a hive with a queen
const POLLINATION_PER_BEE := 1.0 / 400.0
const MAX_POLLINATION := 0.5
const POLLINATED_SEEDS := 5        # given per pollination
const POLLINATED_LIFETIME := 2 * 86400
const POLLINATED_RIPE_MULT := 2    # pollinated crops stay ripe twice as long
const POLLINATED_SUPER_MULT := 3   # and triple the super-harvest chance
const FERTILIZE_ALL_CHANCE := 0.10 # per hive collection
const BEES_STAY_DAYS := 3          # away longer than this, bees start to leave
const BEES_LEAVE_PER_DAY := 0.15
const QUEEN_STAYS_DAYS := 14
# Pig Pen: feed slop, the pigs forage, and truffles trade for rare breeds.
const SLOP_COST := 150
const FORAGE_SECONDS := 8 * 3600
const PIGS_PER_TRUFFLE := 5
const TRUFFLES_PER_PIG := 10
# Orchard: rare sapling varieties of the trees inside.
const SAPLING_CHANCE := 0.10
# Vehicles, as in FarmVille: one shared fuel tank of 150, 1 fuel a plot (the Combine 3),
# a 2x2 area that grows with Vehicle Parts in the Garage, up to 4x4.
const VEHICLE_SIZES := VehicleDef.SIZES
const FUEL_TANK := 150
const FUEL_REGEN_SECONDS := 600    # the tank slowly refills: 1 fuel every 10 minutes
const FUEL_TANK_GEM_COST := 3
const TRACTOR_COIN_CHANCE := 0.05  # coins pop out of the ground while a vehicle plows
const TRACTOR_COINS := 10
const STRAY_MIN_GAP := 3 * 3600    # a new stray turns up 3 to 6 hours after the last
const STRAY_MAX_GAP := 6 * 3600
const STRAY_STAYS := 86400         # a stray nobody adopts wanders off after a day
const STRAY_ADOPT_XP := 5
const LOST_WEIGHT := 0.25           # each lost animal's share of the stray pool (a 100-coin animal is 1.0)
const MYSTERY_BOX_GEM_COST := 12
const COLLECTIBLE_ACTION_CHANCE := 0.02  # FarmVille: any action can drop one (plow, plant, fertilize); harvests are likelier
const ANIMAL_COLLECTIBLE_CHANCE := 0.05  # collecting animals, trees and buildings (barnyard and orchard sets)
const FUEL_LEVEL := 12               # FarmVille: fuel finds from level 12
const FUEL_FIND_CHANCE := 0.08      # FarmVille: plowing your own farm can turn up fuel, once a day
const FUEL_FIND_SHARE := 0.25       # of a full tank
const PERFECT_BUNCH_CHANCE := 0.04  # FarmVille: a flower harvest can give a Perfect Bunch
const BUNCH_DAYS := 14              # a placed Perfect Bunch lasts 14 days
const BUNCH_CAP_NO_SHED := 10       # bunches kept without a Garden Shed
const SHED_FREE_BUNCHES := 10       # FarmVille gave 10 bunches with the shed
const BUSHEL_CHANCE := 0.2          # a harvest drops a bushel of its crop, once you own a crafting building
const BUSHEL_CAP := 100             # bushels held at once (FarmVille's stall held 100)
const STALL_CROPS := 6              # the Farmers Market offers this many crops a day
const STALL_EACH := 3               # 3 bushels of each, like 3 a day from each neighbour in FarmVille
const BUSHEL_GEM_COST := 1          # "Buy all ingredients" with premium currency
const CRAFT_XP_PER_STAR := 5
const UNWITHER_GEM_COST := 3
const START_COINS := 200
const START_GEMS := 5
const GEMS_PER_LEVEL := 1
const PLOW_COST := 15
const PLOW_XP := 1

# A ripe crop stays ripe as long as it took to grow, clamped to this window.
const MIN_RIPE_WINDOW := CropDef.MIN_RIPE_WINDOW
const MAX_RIPE_WINDOW := CropDef.MAX_RIPE_WINDOW

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

var crops := {}                    # id -> crop dictionary from data/catalog/crops.json
var crop_order: Array[String] = [] # display order
var coins := START_COINS
var gems := START_GEMS           # premium currency
var xp := 0
var plots: Array[Dictionary] = []  # MAX_SIZE * MAX_SIZE entries, row-major
var farm_size := START_SIZE        # usable width and depth in tiles
var expansion_steps: Array = []    # from data/expansions.json
var unwithers := START_UNWITHERS   # Unwither items held
var queen_bees := 0                # Queen Bees held, waiting for a hive
var fertilize_alls := 0            # fertilize every growing crop at once
var pollinated := {}               # crop id -> [seed count, expires at]
var truffles := 0
var fuel := 0                      # in the shared tank
var fuel_t := 0                    # when fuel last refilled itself
var fuel_tanks := 0                # spare full tanks, opened when the tank runs dry
var fuel_unlocked := false         # true once the first vehicle is bought
var vehicle_levels := {}           # vehicle id -> upgrades bought (0..4)
var absence_note := ""             # what happened while the player was away, shown on start
var next_stray_at := 0             # when the next stray may turn up
var parts := {}                    # building material -> count (see PARTS)
var mystery_eggs := {}             # egg colour -> count
var farmhands := 0                 # collect every animal at once
var arborists := 0                 # collect every tree at once
var fertilizer_bags := 0           # free fertilizer, used before coins
var egg_data := {}                 # data/mystery_eggs.json
var box_data := {}                 # data/mystery_box.json
var weather_override := ""         # force a weather state (screenshots, testing); "" = the real weather
var bushels := {}                  # crop id -> bushels held, for crafting
var coll_levels := {}              # collection id -> trade-in levels done (3 levels, then it repeats)
var fuel_found_day := 0            # the day fuel was last found while plowing
var bunches: Array = []            # Perfect Bunches held: flower crop ids
var tree_collection := {}          # the collection found while harvesting trees
var animal_collection := {}        # the collection found while collecting animals
var goods := {}                    # recipe id -> crafted goods held
var crafted := {}                  # recipe id -> lifetime crafts (recipe mastery)
var stall := {}                    # crop id -> bushels for sale at the Farmers Market today
var stall_day := 0
var last_daily_day := 0            # day number of the last daily gift
var daily_streak := 0              # consecutive days the daily bonus was collected
var stored: Array = []             # objects put away in the barn (no row or col)
var mastery := {}                  # crop id -> lifetime harvest count
var debug_time_offset := 0         # seconds; only changed by the debug skip button
var tutorial_step: int = Tutorial.HARVEST

var collections: Array = []        # from data/collections.json
var collections_data := {}         # the whole file: levels, rarity weights
var collection_of_crop := {}       # crop id -> collection dictionary
var bird_collection := {}          # the collection whose items are birds
var item_names := {}               # item id -> display name
var ribbon_data := {}              # data/ribbons.json
var owned := {}                    # item id -> count held
var stats := {}                    # lifetime counters for ribbons
var ribbon_tiers := {}             # ribbon id -> tiers earned (0..4)
var pity := {"golden": 0, "collectible": 0}
var catalog: Catalog               # every item, as typed definitions (scripts/catalog/)
var items := {}                    # placeable objects from data/catalog/, as dictionaries
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
	egg_data = _read_json("res://data/mystery_eggs.json")
	box_data = _read_json("res://data/mystery_box.json")
	if not saving_enabled or not load_game():
		_new_game()
	# Deferred so the HUD is connected and can show the message.
	call_deferred("check_rescue")
	call_deferred("check_strays")
	call_deferred("check_daily_gift")
	call_deferred("_show_absence")
	var stray_timer := Timer.new()
	stray_timer.wait_time = 30.0
	stray_timer.autostart = true
	stray_timer.timeout.connect(check_strays)
	stray_timer.timeout.connect(check_daily_gift)
	add_child(stray_timer)


func _show_absence() -> void:
	if absence_note != "":
		message.emit(absence_note)
		absence_note = ""


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


func debug_add_materials(n: int) -> void:
	if OS.is_debug_build():
		for m in PARTS:
			parts[m] = int(parts.get(m, 0)) + n
		inventory_changed.emit()
		queue_save()


## Adds bees to finished hives (with a queen, so the hive works). Test helper.
func debug_add_bees(n: int) -> void:
	if not OS.is_debug_build():
		return
	var all := hives()
	if all.is_empty():
		message.emit("Build a Beehive first")
		return
	for h in all:
		h["queen"] = true
		var room := capacity(h) - inside_total(h)
		for k in mini(n, room):
			_put_bee_in(h)
		n -= mini(n, room)
	_objects_updated()


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
			var window := ripe_window(crop) * (POLLINATED_RIPE_MULT if p.get("pol", false) else 1)
			if age < grow + window:
				return Phase.RIPE
			return Phase.WITHERED
	return Phase.GRASS


func ripe_window(crop: Dictionary) -> int:
	return (catalog.get_def(crop["id"]) as CropDef).ripe_window()


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
	var old_crop := str(plots[i].get("crop", ""))
	plots[i] = {"state": "plowed"}
	add_xp(PLOW_XP)
	_bump("plowed", 1)
	_roll_fuel_find(i)
	_roll_collectible(_plow_collection(old_crop), COLLECTIBLE_ACTION_CHANCE, i)
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
	# Pollinated seeds are planted first, for free.
	var use_pollinated := pollinated_seeds(crop_id) > 0
	if use_pollinated:
		var entry: Array = pollinated[crop_id]
		entry[0] = int(entry[0]) - 1
		if int(entry[0]) <= 0:
			pollinated.erase(crop_id)
		inventory_changed.emit()
	elif not spend(int(crop["seed_cost"])):
		message.emit("Not enough coins for %s seeds" % crop["name"])
		return false
	plots[i] = {"state": "planted", "crop": crop_id, "planted_at": now()}
	if use_pollinated:
		plots[i]["pol"] = true
	_roll_collectible(collection_of_crop.get(crop_id, {}), COLLECTIBLE_ACTION_CHANCE, i)
	_advance_tutorial(Tutorial.PLANT)
	_plot_updated(i)
	return true


func is_fertilized(i: int) -> bool:
	return plots[i].get("fert", false)


## Fertilizer goes on a planted crop that isn't ripe or withered yet.
func fertilize(i: int) -> bool:
	if phase(i) != Phase.GROWING or is_fertilized(i):
		return false
	if fertilizer_bags > 0:
		fertilizer_bags -= 1
		inventory_changed.emit()
	elif not spend(FERTILIZER_COST):
		message.emit("Not enough coins for fertilizer")
		return false
	plots[i]["fert"] = true
	_bump("fertilized", 1)
	_roll_collectible(collection_of_crop.get(str(plots[i]["crop"]), {}), COLLECTIBLE_ACTION_CHANCE, i)
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

	var was_pollinated: bool = plots[i].get("pol", false)
	var drop := _roll_drop(crop_id, stars_before, POLLINATED_SUPER_MULT if was_pollinated else 1)
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
	var bushel := _roll_bushel(crop_id)
	var bunch := _roll_bunch(crop_id, i)
	var bee_news := ""
	if crop.get("flower", false):
		bee_news = _flower_harvest_bees()
	var seeds := _pollinate(crop_id) if fertilized else 0
	var stars_after := mastery_stars(crop_id)
	if stars_after > stars_before:
		_award_mastery_star(crop_id, stars_after)
	if tutorial_step == Tutorial.HARVEST and not _any_plot_in(Phase.RIPE):
		_advance_tutorial(Tutorial.HARVEST)
	_plot_updated(i)
	return {"coins": earned, "xp": gained, "crop": crop_id, "bee": bee_news,
		"pollinated": seeds, "drop": drop.get("type", ""), "drop_text": drop.get("text", ""), "part": part, "bushel": bushel,
		"bushels": (1 + mastery_stars(crop_id)) if bushel != "" else 0, "bunch": bunch}


# ---------------------------------------------------------------- surprise drops

## One roll per harvest. Rarest outcomes are checked first; pity counters
## guarantee a golden harvest or a collectible after a long dry spell.
func _roll_drop(crop_id: String, stars: int, super_mult := 1) -> Dictionary:
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
		_bump("birds_seen", 1)
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
	var super_chance := SUPER_HARVEST_CHANCE * super_mult
	if r < super_chance:
		return {"type": "super_harvest", "text": "Super harvest! 2x coins"}
	if r < super_chance + BONUS_XP_CHANCE:
		return {"type": "bonus_xp", "text": "Bonus XP!"}
	return {}


## Items you hold fewer of are more likely, so sets fill up instead of piling duplicates.
func _pick_item(coll: Dictionary) -> String:
	var weights: Array[float] = []
	var total := 0.0
	var rarity: Dictionary = collections_data.get("rarity_weight", {})
	for item in coll["items"]:
		var w := 1.0 / (1.0 + 2.0 * int(owned.get(item["id"], 0)))
		w *= float(rarity.get(item.get("rarity", "common"), 1))
		weights.append(w)
		total += w
	var pick := rng.randf() * total
	for k in weights.size():
		pick -= weights[k]
		if pick <= 0.0:
			return coll["items"][k]["id"]
	return coll["items"][-1]["id"]


# ---------------------------------------------------------------- collections

## The trade-in level this set is on next: 0, 1 or 2 (after level 3 it repeats from level 1).
func coll_level(coll: Dictionary) -> int:
	return int(coll_levels.get(coll["id"], 0)) % 3


## Item id -> how many the next trade-in takes (FarmVille: 3/2/1, then 6/4/2, then 12/8/4).
func coll_need(coll: Dictionary) -> Dictionary:
	var need: Dictionary = collections_data["levels"][coll_level(coll)]["need"]
	var out := {}
	for item in coll["items"]:
		out[item["id"]] = int(need.get(item.get("rarity", "common"), 1))
	return out


## {"coins", "xp", "prize"} for the next trade-in.
func coll_reward(coll: Dictionary) -> Dictionary:
	var lvl: Dictionary = collections_data["levels"][coll_level(coll)]
	return {"coins": int(lvl["coins"]), "xp": int(lvl["xp"]), "prize": coll["rewards"][coll_level(coll)]}


func can_trade_in(coll: Dictionary) -> bool:
	var need := coll_need(coll)
	for id in need:
		if int(owned.get(id, 0)) < int(need[id]):
			return false
	return true


func trade_in(coll_id: String) -> bool:
	for coll in collections:
		if coll["id"] != coll_id:
			continue
		if not can_trade_in(coll):
			return false
		var need := coll_need(coll)
		var reward := coll_reward(coll)
		var lvl := coll_level(coll) + 1
		for id in need:
			owned[id] = int(owned[id]) - int(need[id])
		add_coins(int(reward["coins"]))
		add_xp(int(reward["xp"]))
		var prize := _give_prize(reward["prize"])
		coll_levels[coll_id] = int(coll_levels.get(coll_id, 0)) + 1
		message.emit("%s level %d! +%d coins, +%d XP and %s" % [coll["name"], lvl, int(reward["coins"]), int(reward["xp"]), prize])
		_bump("collections_traded", 1)
		collections_changed.emit()
		queue_save()
		return true
	return false


## One roll for a collectible from a set, outside harvests (no pity). Returns the item name or "".
func _roll_collectible(coll: Dictionary, chance: float, index := -1) -> String:
	if coll.is_empty() or not drops_enabled or rng.randf() >= chance:
		return ""
	var item_id := _pick_item(coll)
	owned[item_id] = int(owned.get(item_id, 0)) + 1
	collections_changed.emit()
	var text := "Found: " + item_names[item_id]
	if index >= 0:
		found.emit(index, text)
	else:
		message.emit("%s (%s collection)" % [text, coll["name"]])
	return item_names[item_id]


## A collection to roll on a plow: the set of the crop that was there, or one for a crop you can grow.
func _plow_collection(old_crop: String) -> Dictionary:
	if collection_of_crop.has(old_crop):
		return collection_of_crop[old_crop]
	var pool: Array = []
	for coll in collections:
		for c in coll.get("crops", []):
			if crops.has(c) and int(crops[c]["unlock_level"]) <= level():
				pool.append(coll)
				break
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else {}


## Adds fuel; past a full tank it fills spare tanks.
func _add_fuel(n: int) -> void:
	if not fuel_unlocked:
		fuel_unlocked = true
		fuel_t = now()
	fuel = fuel_now() + n
	while fuel > FUEL_TANK:
		fuel -= FUEL_TANK
		fuel_tanks += 1
	if fuel >= FUEL_TANK:
		fuel_t = now()
	inventory_changed.emit()


## FarmVille: plowing your own farm can turn up fuel, at most once a day.
func _roll_fuel_find(i: int) -> int:
	if not drops_enabled or level() < FUEL_LEVEL or fuel_found_day == day_number() or rng.randf() >= FUEL_FIND_CHANCE:
		return 0
	fuel_found_day = day_number()
	var n := int(FUEL_TANK * FUEL_FIND_SHARE)
	_add_fuel(n)
	found.emit(i, "Found fuel! +%d" % n)
	return n


# ---------------------------------------------------------------- Perfect Bunches and the Garden Shed

func bunch_cap() -> int:
	for o in objects:
		if o["id"] == "garden_shed":
			return int(item_data("garden_shed")["levels"][0])
	return BUNCH_CAP_NO_SHED


func add_bunch(flower: String) -> bool:
	if bunches.size() >= bunch_cap():
		return false
	bunches.append(flower)
	inventory_changed.emit()
	return true


func _roll_bunch(crop_id: String, i: int) -> String:
	if not drops_enabled or not crops[crop_id].get("flower", false) or rng.randf() >= PERFECT_BUNCH_CHANCE:
		return ""
	if not add_bunch(crop_id):
		return ""
	_bump("perfect_bunches", 1)
	found.emit(i, "Perfect Bunch of %s!" % crops[crop_id]["name"])
	return crop_id


## Takes a bunch out of the shed, ready to place: it goes to the end of the storage list. Returns its index.
func unpack_bunch(k: int) -> int:
	if k < 0 or k >= bunches.size():
		return -1
	var flower: String = bunches[k]
	bunches.remove_at(k)
	stored.append({"uid": next_uid, "id": "perfect_bunch", "flower": flower, "t": now(), "bunch": true})
	next_uid += 1
	inventory_changed.emit()
	return stored.size() - 1


## Placed bunches wilt away after BUNCH_DAYS days.
func _expire_bunches() -> void:
	var before := objects.size()
	objects = objects.filter(func(o): return not (o["id"] == "perfect_bunch" and now() >= int(o.get("expires", now() + 1))))
	if objects.size() != before:
		_rebuild_occupancy()
		message.emit("A Perfect Bunch has wilted away")
		_objects_updated()


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
	var d := catalog.get_def(item_id)
	return (d as PlaceableDef).footprint() if d is PlaceableDef else Vector2i.ONE


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
	var it := item_data(item_id)
	if it.get("kind", "") == "crafting":
		var price := crafting_price(item_id)
		return gems >= int(price["gems"]) if price.has("gems") else coins >= int(price["coins"])
	if it.has("gem_cost"):
		return gems >= int(it["gem_cost"])
	return coins >= int(it.get("cost", 0))


func buy_and_place(item_id: String, row: int, col: int) -> bool:
	var it := item_data(item_id)
	if it.is_empty():
		return false
	if level() < int(it["unlock_level"]):
		message.emit("%s unlocks at level %d" % [it["name"], int(it["unlock_level"])])
		return false
	if not can_place(item_id, row, col):
		return false
	if it["kind"] == "crafting":
		var price := crafting_price(item_id)
		var paid := spend_gems(int(price["gems"])) if price.has("gems") else spend(int(price["coins"]))
		if not paid:
			message.emit("Not enough %s for a %s" % ["gems" if price.has("gems") else "coins", it["name"]])
			return false
	elif it.has("gem_cost"):
		if not spend_gems(int(it["gem_cost"])):
			message.emit("Not enough gems for a %s" % it["name"])
			return false
	elif not spend(int(it["cost"])):
		message.emit("Not enough coins for a %s" % it["name"])
		return false
	var obj := {"uid": next_uid, "id": item_id, "row": row, "col": col, "t": now()}
	var bought_xp := buy_xp(item_id)
	if bought_xp > 0:
		add_xp(bought_xp)
	if it["kind"] == "decor":
		_bump("decor_bought", 1)
	if it.get("special", "") == "garden_shed":
		var flowers: Array[String] = []
		for c in crop_order:
			if crops[c].get("flower", false) and int(crops[c]["unlock_level"]) <= level():
				flowers.append(c)
		for k in SHED_FREE_BUNCHES:
			if not flowers.is_empty():
				bunches.append(flowers[rng.randi_range(0, flowers.size() - 1)])
		message.emit("Garden Shed built! It holds 100 Perfect Bunches, and here are %d to start." % SHED_FREE_BUNCHES)
	if it["kind"] == "crafting":
		obj["level"] = 1
		obj["slots"] = []
		stall_day = 0 # restock the Farmers Market with this building's crops
		message.emit("%s built! Harvests now drop bushels. Tap it to craft." % it["name"])
	if it["kind"] == "building":
		obj["level"] = 1
		obj["inside"] = {}
		if it.has("build_materials"):
			obj["construction"] = {} # a frame: finished with materials, like FarmVille
			message.emit("%s frame placed! Tap it to add building materials." % it["name"])
		else:
			message.emit("%s built! Open it to move animals in." % it["name"])
	elif it["kind"] == "vehicle":
		if it.has("build_materials"):
			obj["construction"] = {} # the Combine's chassis, finished with Vehicle Parts
			message.emit("%s chassis placed! Tap it to add Vehicle Parts." % it["name"])
		else:
			message.emit("%s bought! Pick it in the toolbar, then tap the field." % it["name"])
		if not fuel_unlocked:
			fuel_unlocked = true
			fuel = FUEL_TANK
			fuel_t = now()
	next_uid += 1
	_grass_over(item_id, row, col)
	objects.append(obj)
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


## A building's own cycle (the Stable's 1 day beats a loose horse's 3) or the item's.
func cycle_of(obj: Dictionary) -> int:
	return int(item_data(obj["id"]).get("cycle_seconds", 86400))


func level_of(obj: Dictionary) -> int:
	return int(obj.get("level", 1))


func max_level(building_id: String) -> int:
	var d := catalog.get_def(building_id)
	return (d as BuildingDef).max_level() if d is BuildingDef else 1


## The building's name at its size: Big Chicken Coop, Huge Dairy Farm...
func size_name(obj: Dictionary) -> String:
	var it := item_data(obj["id"])
	var names: Array = it.get("level_names", [])
	var lvl := level_of(obj)
	if lvl - 1 < names.size():
		return names[lvl - 1]
	return it["name"] if lvl == 1 else "%s (size %d)" % [it["name"], lvl]


func under_construction(obj: Dictionary) -> bool:
	return obj.has("construction")


func kind_of(obj: Dictionary) -> String:
	return item_data(obj["id"]).get("kind", "")


func is_building(obj: Dictionary) -> bool:
	return item_data(obj["id"]).get("kind", "") == "building"


## Art id to draw for a placed object right now, by its lifecycle stage (see data/catalog/schema.json).
## Returns "" when there's no art for that stage yet, so the code drawing is used.
func art_for(obj: Dictionary) -> String:
	var id: String = obj["id"]
	var candidates: Array[String] = []
	match kind_of(obj):
		"tree":
			var stage := "ready"
			if not is_ready(obj):
				var age := float(now() - int(obj.get("t", now())))
				stage = "fruiting" if age >= cycle_of(obj) * 0.5 else "harvested"
			candidates = [id + "_" + stage, id]
		"building", "barn", "crafting":
			candidates = ["%s_size%d" % [id, level_of(obj)], id + "_size1", id]
		_:
			candidates = [id]
	for c in candidates:
		if SpriteBank.has(c):
			return c
	return ""


## Art id for a planted plot's stage: planted until half grown, growing, ripe, withered.
func crop_art_for(i: int) -> String:
	var ph := phase(i)
	var stage := "growing"
	match ph:
		Phase.RIPE:
			stage = "ripe"
		Phase.WITHERED:
			stage = "withered"
		Phase.GROWING:
			stage = "planted" if growth(i) < 0.5 else "growing"
	var art := "crop_%s_%s" % [crop_at(i), stage]
	return art if SpriteBank.has(art) else ""


func is_ready(obj: Dictionary) -> bool:
	if obj.get("stray", false):
		return false
	if kind_of(obj) == "decor" or kind_of(obj) == "barn" or kind_of(obj) == "vehicle":
		return false # scenery, the barn and vehicles never produce
	if not item_data(obj["id"]).get("produces", true):
		return false # the garage only stores
	if under_construction(obj):
		return false
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
	return total


## Returns {"coins", "xp", "drop", "drop_text", "name"} or {} if nothing was ready.
func collect(uid: int) -> Dictionary:
	var obj := object_by_uid(uid)
	if obj.is_empty() or not is_ready(obj):
		return {}
	var pay := object_payout(obj)
	var earned := pay.x
	var gained := pay.y
	var drop := _roll_drop("", 0)
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
	var extras: Array[String] = []
	var name_before: String = item_data(obj["id"])["name"]
	if is_building(obj):
		extras = _building_specials(obj)
		extras.append_array(_grow_up_inside(obj))
	else:
		var adult := _grows_into(obj["id"])
		if adult != "":
			obj["id"] = adult
			message.emit("Your %s grew up into a %s!" % [name_before.to_lower(), item_data(adult)["name"].to_lower()])
			extras.append("Grew up!")
	var coll_find := ""
	if kind_of(obj) == "tree":
		coll_find = _roll_collectible(tree_collection, ANIMAL_COLLECTIBLE_CHANCE)
	elif kind_of(obj) == "animal" or is_building(obj):
		coll_find = _roll_collectible(animal_collection, ANIMAL_COLLECTIBLE_CHANCE)
	if coll_find != "":
		extras.append("Found: " + coll_find)
	if drop.get("type", "") == "golden":
		_bump("golden_finds", 1)
		message.emit("Golden collection! %dx coins" % GOLDEN_COIN_MULTIPLIER)
	elif drop.get("type", "") == "bird":
		message.emit("A %s landed on your farm! (%s collection)" % [drop["name"].to_lower(), drop["collection"]])
	_objects_updated()
	return {"coins": earned, "xp": gained, "drop": drop.get("type", ""),
		"drop_text": drop.get("text", ""), "name": name_before, "part": part, "extras": extras}


## FarmVille's Baby Turkey and Ugly Duckling grow up after their first collection.
func _grows_into(item_id: String) -> String:
	var d := catalog.get_def(item_id)
	return (d as AnimalDef).grows_into() if d is AnimalDef else ""


func _grow_up_inside(b: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var inside: Dictionary = b.get("inside", {})
	for id in inside.keys():
		var adult := _grows_into(id)
		if adult == "" or int(inside[id]) <= 0:
			continue
		inside[adult] = int(inside.get(adult, 0)) + int(inside[id])
		out.append("%d %s grew up!" % [int(inside[id]), item_data(id)["name"]])
		inside.erase(id)
	return out


## Which baby a Dairy Farm or Horse Stable brings: a breed's own baby, likelier for the breeds it holds more of.
func _pick_baby(b: Dictionary, plain: String) -> String:
	var inside: Dictionary = b.get("inside", {})
	var total := 0
	for id in inside:
		var d := catalog.get_def(id)
		if d is AnimalDef and not (d as AnimalDef).is_stray_only() and not (d as AnimalDef).is_young():
			total += int(inside[id])
	if total == 0:
		return plain
	var pick := rng.randi_range(1, total)
	for id in inside:
		var d := catalog.get_def(id)
		if d is AnimalDef and not (d as AnimalDef).is_stray_only() and not (d as AnimalDef).is_young():
			pick -= int(inside[id])
			if pick <= 0:
				var baby := (d as AnimalDef).baby()
				return baby if baby != "" else plain
	return plain


# ---------------------------------------------------------------- buildings

func building_accepts(building: Dictionary, item_id: String) -> bool:
	var b := catalog.get_def(building["id"])
	return b is BuildingDef and (b as BuildingDef).accepts(item_id, item_data(item_id).get("kind", ""))


## A bull or stallion: one lives inside, alongside the animals, without taking a space.
func is_one_each(building: Dictionary, item_id: String) -> bool:
	return (item_data(building["id"]).get("one_each", []) as Array).has(item_id)


func has_inside(building: Dictionary, item_id: String) -> bool:
	return int((building.get("inside", {}) as Dictionary).get(item_id, 0)) > 0


func capacity(building: Dictionary) -> int:
	return (catalog.get_def(building["id"]) as BuildingDef).capacity(int(building["level"]))


## Animals taking up spaces (a bull or stallion doesn't count).
func inside_total(building: Dictionary) -> int:
	var total := 0
	var inside: Dictionary = building.get("inside", {})
	for id in inside:
		if not is_one_each(building, id):
			total += int(inside[id])
	return total


func loose_matching(building: Dictionary) -> int:
	var n := 0
	for o in objects:
		if not is_building(o) and not o.get("stray", false) and not under_construction(o) and building_accepts(building, o["id"]):
			n += 1
	return n


## Moves loose animals or trees of the right type into the building, up to its capacity.
func fill_building(uid: int) -> int:
	var b := object_by_uid(uid)
	if b.is_empty() or not is_building(b) or under_construction(b):
		return 0
	var was_empty := inside_total(b) == 0
	var room := capacity(b) - inside_total(b)
	var moved := 0
	var regular := 0 # moves that take a space (the bull or stallion doesn't)
	var keep: Array = []
	for o in objects:
		var movable: bool = not is_building(o) and not o.get("stray", false) and not under_construction(o) and building_accepts(b, o["id"])
		var inside: Dictionary = b["inside"]
		if movable and is_one_each(b, o["id"]) and not has_inside(b, o["id"]):
			inside[o["id"]] = 1 # the one bull or stallion
			moved += 1
		elif movable and not is_one_each(b, o["id"]) and regular < room:
			regular += 1
			inside[o["id"]] = int(inside.get(o["id"], 0)) + 1
			if b["id"] == "nursery_barn":
				(b.get_or_add("growing", []) as Array).append([o["id"], 0])
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


# ---------------------------------------------------------------- construction and expansion

## Materials still needed to finish a frame: {material: count}. Empty when done.
func construction_needs(b: Dictionary) -> Dictionary:
	if not under_construction(b):
		return {}
	var need: Dictionary = item_data(b["id"]).get("build_materials", {})
	var have: Dictionary = b["construction"]
	var left := {}
	for m in need:
		var short := int(need[m]) - int(have.get(m, 0))
		if short > 0:
			left[m] = short
	return left


## Puts held materials into a frame. Finishes the building when nothing is missing.
func add_materials(uid: int) -> int:
	var b := object_by_uid(uid)
	if b.is_empty() or not under_construction(b):
		return 0
	var left := construction_needs(b)
	var added := 0
	var have: Dictionary = b["construction"]
	for m in left:
		var give := mini(int(left[m]), int(parts.get(m, 0)))
		if give > 0:
			parts[m] = int(parts[m]) - give
			have[m] = int(have.get(m, 0)) + give
			added += give
	if added == 0:
		message.emit("No materials to add yet. They turn up while harvesting and as daily gifts.")
		return 0
	if construction_needs(b).is_empty():
		b.erase("construction")
		b["t"] = now()
		var done_it := item_data(b["id"])
		if done_it["kind"] == "vehicle":
			message.emit("%s built! Pick it in the toolbar, then tap the field." % done_it["name"])
		elif done_it.get("special", "") == "garage":
			message.emit("Garage finished! Park vehicles inside and upgrade them with Vehicle Parts.")
		else:
			message.emit("%s finished! Open it to move animals in." % done_it["name"])
		if done_it.has("build_xp"):
			add_xp(int(done_it["build_xp"]))
		_bump("buildings_built", 1)
		building_upgraded.emit(uid, 1)
	else:
		message.emit("Added %d materials to the %s" % [added, item_data(b["id"])["name"]])
	inventory_changed.emit()
	_objects_updated()
	return added


## Materials for the next expansion, or {} at full size.
func expansion_needs(b: Dictionary) -> Dictionary:
	if level_of(b) >= max_level(b["id"]):
		return {}
	return item_data(b["id"]).get("expand_materials", {})


func can_expand(b: Dictionary) -> bool:
	var need := expansion_needs(b)
	if need.is_empty() or under_construction(b):
		return false
	for m in need:
		if int(parts.get(m, 0)) < int(need[m]):
			return false
	return true


## Expands a building one size, paying its materials (FarmVille's Big and Huge sizes).
func upgrade_building(uid: int) -> bool:
	var b := object_by_uid(uid)
	if b.is_empty() or not is_building(b) or not can_expand(b):
		return false
	var need := expansion_needs(b)
	for m in need:
		parts[m] = int(parts[m]) - int(need[m])
	b["level"] = level_of(b) + 1
	message.emit("%s now holds %d!" % [size_name(b), capacity(b)])
	_bump("upgrades", 1)
	building_upgraded.emit(uid, level_of(b))
	inventory_changed.emit()
	_objects_updated()
	return true


# ---------------------------------------------------------------- building specials

## Extra results of collecting a building, as short popup texts.
func _building_specials(b: Dictionary) -> Array[String]:
	var out: Array[String] = []
	match item_data(b["id"]).get("special", ""):
		"mystery_eggs":
			var colour := _roll_mystery_egg(b)
			if colour != "":
				mystery_eggs[colour] = int(mystery_eggs.get(colour, 0)) + 1
				var egg_name: String = egg_data["colours"][colour]["name"]
				message.emit("You found a %s! Open it from the coop." % egg_name)
				out.append(egg_name + "!")
		"calves":
			if drops_enabled and rng.randf() < FERTILIZER_CHANCE:
				fertilizer_bags += 1
				out.append("+1 Fertilizer")
			if has_inside(b, "bull") and drops_enabled and rng.randf() < CALF_CHANCE:
				var calf := _pick_baby(b, "calf")
				if place_somewhere(calf):
					message.emit("A %s was born! Raise it in a Nursery Barn." % item_data(calf)["name"].to_lower())
					out.append("A %s!" % item_data(calf)["name"].to_lower())
		"foals":
			var with_stallion := has_inside(b, "stallion")
			if drops_enabled and with_stallion and rng.randf() < FOAL_CHANCE:
				var foal := _pick_baby(b, "foal")
				if place_somewhere(foal):
					message.emit("A %s was born! Raise it in a Nursery Barn." % item_data(foal)["name"].to_lower())
					out.append("A %s!" % item_data(foal)["name"].to_lower())
			if drops_enabled and rng.randf() < STABLE_HELPER_CHANCE:
				farmhands += 1
				out.append("+1 Farmhand")
			if drops_enabled and rng.randf() < STABLE_HELPER_CHANCE:
				arborists += 1
				out.append("+1 Arborist")
			if drops_enabled and with_stallion and rng.randf() < STABLE_XP_CHANCE:
				add_xp(STABLE_XP)
				out.append("+%d XP" % STABLE_XP)
		"nursery":
			out.append_array(_grow_babies(b))
		"lambs":
			if has_inside(b, "ram") and drops_enabled and rng.randf() < LAMB_CHANCE:
				if place_somewhere("lamb"):
					message.emit("A lamb was born! Raise it in a Nursery Barn.")
					out.append("A lamb!")
		"truffles":
			if has_inside(b, "boar") and drops_enabled and rng.randf() < PIGLET_CHANCE:
				if place_somewhere("piglet"):
					message.emit("A piglet was born! Raise it in a Nursery Barn.")
					out.append("A piglet!")
		"beehive":
			if drops_enabled and rng.randf() < FERTILIZE_ALL_CHANCE:
				fertilize_alls += 1
				message.emit("The bees left a Fertilize All!")
				out.append("+1 Fertilize All")
		"saplings":
			var sapling := _roll_sapling(b)
			if sapling != "" and place_somewhere(sapling):
				message.emit("A rare sapling sprouted: %s!" % item_data(sapling)["name"])
				out.append("Rare sapling!")
	if not out.is_empty():
		inventory_changed.emit()
	return out


## Mystery Egg chance grows with the chickens inside; colour follows the breeds there.
func _roll_mystery_egg(coop: Dictionary) -> String:
	if not drops_enabled or egg_data.is_empty():
		return ""
	var chickens := inside_total(coop)
	var chance := minf(float(egg_data.get("max_chance", 0.4)), chickens * float(egg_data.get("chance_per_chicken", 0.005)))
	if rng.randf() >= chance:
		return ""
	var pick := rng.randi_range(1, chickens)
	var inside: Dictionary = coop["inside"]
	for id in inside:
		pick -= int(inside[id])
		if pick <= 0:
			return item_data(id).get("breed", "white")
	return "white"


## Opens one Mystery Egg of a colour. Returns the prize text, or "" if none held.
func open_mystery_egg(colour: String) -> String:
	if int(mystery_eggs.get(colour, 0)) <= 0:
		return ""
	mystery_eggs[colour] = int(mystery_eggs[colour]) - 1
	var text := _give_prize(_weighted_prize(egg_data["colours"][colour]["prizes"]))
	_bump("eggs_opened", 1)
	message.emit("%s: %s" % [egg_data["colours"][colour]["name"], text])
	inventory_changed.emit()
	queue_save()
	return text


func _give_prize(prize: Array) -> String:
	var kind: String = prize[0]
	match kind:
		"coins":
			add_coins(int(prize[1]))
			return "%d coins" % int(prize[1])
		"xp":
			add_xp(int(prize[1]))
			return "%d XP" % int(prize[1])
		"gems":
			add_gems(int(prize[1]))
			return "%d gems" % int(prize[1])
		"chicken", "item":
			if place_somewhere(prize[1]):
				return "a %s" % item_data(prize[1])["name"]
			add_coins(200)
			return "200 coins (no room for a %s)" % item_data(prize[1])["name"]
		"materials":
			var got: Array[String] = []
			for k in int(prize[1]):
				var m := _pick_part()
				add_part(m, 1)
				got.append(PART_NAMES[m])
			return ", ".join(PackedStringArray(got))
		"unwither":
			add_unwithers(int(prize[1]))
			return "%d Unwither" % int(prize[1])
		"farmhand":
			farmhands += int(prize[1])
			return "%d Farmhand" % int(prize[1])
		"arborist":
			arborists += int(prize[1])
			return "%d Arborist" % int(prize[1])
		"fuel":
			_add_fuel(int(prize[1]))
			return "%d fuel" % int(prize[1])
		"fertilize_all":
			fertilize_alls += int(prize[1])
			return "%d Fertilize All" % int(prize[1])
	return ""


## Picks one prize from a weighted list: [kind, amount or item, weight].
func _weighted_prize(prizes: Array) -> Array:
	var total := 0
	for p in prizes:
		total += int(p[2])
	var roll := rng.randi_range(1, total)
	for p in prizes:
		roll -= int(p[2])
		if roll <= 0:
			return p
	return prizes[-1]


## FarmVille's Mystery Box: bought with premium currency, opens into one random prize.
## Some things (the Donkey) come only from here.
func buy_mystery_box() -> String:
	if box_data.is_empty() or not spend_gems(int(box_data.get("gem_cost", MYSTERY_BOX_GEM_COST))):
		return ""
	return _open_box()


func _open_box() -> String:
	var text := _give_prize(_weighted_prize(box_data["prizes"]))
	_bump("boxes_opened", 1)
	message.emit("Mystery Box: %s" % text)
	inventory_changed.emit()
	_objects_updated()
	queue_save()
	return text


## Nursery Barn: each baby grows a day per collection; grown ones move out as adults.
func _grow_babies(nursery: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var it := item_data(nursery["id"])
	var grow_days := int(it.get("grow_days", 4))
	var into: Dictionary = it.get("grows_into", {})
	var still: Array = []
	var inside: Dictionary = nursery["inside"]
	for baby in nursery.get("growing", []):
		baby[1] = int(baby[1]) + 1
		if int(baby[1]) >= grow_days and place_somewhere(into.get(baby[0], baby[0])):
			inside[baby[0]] = int(inside.get(baby[0], 0)) - 1
			if int(inside[baby[0]]) <= 0:
				inside.erase(baby[0])
			add_xp(NURSERY_SPARE_XP)
			_bump("babies_raised", 1)
			var adult_name: String = item_data(into.get(baby[0], baby[0]))["name"]
			message.emit("Your %s grew up into a %s!" % [item_data(baby[0])["name"].to_lower(), adult_name.to_lower()])
			out.append("A %s grew up!" % adult_name.to_lower())
		else:
			still.append(baby)
	nursery["growing"] = still
	return out


## Puts a new animal on an open grass tile. False if the farm is full.
func place_somewhere(item_id: String) -> bool:
	var spots: Array[Vector2i] = []
	for r in farm_size:
		for c in farm_size:
			var i := index_of(r, c)
			if plots[i].get("state", "grass") == "grass" and not is_occupied(i):
				spots.append(Vector2i(r, c))
	if spots.is_empty():
		return false
	var spot := spots[rng.randi_range(0, spots.size() - 1)]
	objects.append({"uid": next_uid, "id": item_id, "row": spot.x, "col": spot.y, "t": now()})
	next_uid += 1
	_rebuild_occupancy()
	return true


# ---------------------------------------------------------------- farmhands and arborists

## Farmhand: collects every ready animal on the farm. Arborist: every ready tree.
func use_helper(kind: String) -> int:
	var held := farmhands if kind == "animal" else arborists
	if held <= 0:
		message.emit("No %s left" % ("Farmhands" if kind == "animal" else "Arborists"))
		return 0
	var ready: Array = []
	for o in objects:
		if kind_of(o) == kind and is_ready(o):
			ready.append(int(o["uid"]))
	if ready.is_empty():
		message.emit("Nothing is ready to collect yet")
		return 0
	if kind == "animal":
		farmhands -= 1
	else:
		arborists -= 1
	var coins_total := 0
	for uid in ready:
		coins_total += int(collect(uid).get("coins", 0))
	message.emit("Collected %d %s for %d coins" % [ready.size(), "animals" if kind == "animal" else "trees", coins_total])
	inventory_changed.emit()
	return ready.size()


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


## Which materials can drop: the basic three, plus the specific ones of buildings you own.
func wanted_parts() -> Array[String]:
	var out: Array[String] = []
	out.assign(BASIC_PARTS)
	for o in objects:
		var it := item_data(o["id"])
		for key in ["build_materials", "expand_materials", "uses_materials"]:
			for m in it.get(key, {}):
				if not out.has(m):
					out.append(m)
	return out


func _pick_part() -> String:
	var pool := wanted_parts()
	var weights: Array[float] = []
	var total := 0.0
	for p in pool:
		var w := 1.0 / (1.0 + int(parts.get(p, 0)))
		weights.append(w)
		total += w
	var pick := rng.randf() * total
	for k in pool.size():
		pick -= weights[k]
		if pick <= 0.0:
			return pool[k]
	return pool[-1]


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
	daily_streak = daily_streak + 1 if today == last_daily_day + 1 else 1
	last_daily_day = today
	var got: Array[String] = _give_daily_bonus(daily_streak)
	for k in DAILY_PARTS:
		var p := _pick_part()
		add_part(p, 1)
		got.append(PART_NAMES[p])
	_bump("daily_bonuses", 1)
	message.emit("Day %d bonus: %s" % [mini(daily_streak, DAILY_STREAK.size()), ", ".join(PackedStringArray(got))])
	queue_save()


## The reward for this day of the streak; day 5 and on repeat the biggest one.
func daily_reward(day: int) -> Dictionary:
	return DAILY_STREAK[clampi(day, 1, DAILY_STREAK.size()) - 1]


func _give_daily_bonus(day: int) -> Array[String]:
	var got: Array[String] = []
	var reward := daily_reward(day)
	if reward.has("coins"):
		add_coins(int(reward["coins"]), false)
		got.append("%d coins" % int(reward["coins"]))
	if reward.has("fertilizer"):
		fertilizer_bags += int(reward["fertilizer"])
		got.append("%d Fertilizer" % int(reward["fertilizer"]))
	if reward.has("unwither"):
		add_unwithers(int(reward["unwither"]))
		got.append("%d Unwither" % int(reward["unwither"]))
	if reward.has("gems"):
		add_gems(int(reward["gems"]))
		got.append("%d gem" % int(reward["gems"]))
	return got


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
	if o.get("bunch", false) and not o.has("expires"):
		o["expires"] = now() + BUNCH_DAYS * 86400
	_grass_over(o["id"], row, col)
	objects.append(o)
	inventory_changed.emit()
	_objects_updated()
	return true


# ---------------------------------------------------------------- beehive

func hives() -> Array:
	var out: Array = []
	for o in objects:
		if o["id"] == "beehive" and not under_construction(o):
			out.append(o)
	return out


func bee_count() -> int:
	var n := 0
	for h in hives():
		n += inside_total(h)
	return n


func has_queen(hive: Dictionary) -> bool:
	return hive.get("queen", false)


## Chance that harvesting a fertilized crop gives pollinated seeds.
func pollination_chance() -> float:
	return minf(MAX_POLLINATION, bee_count() * POLLINATION_PER_BEE)


## Puts a Queen Bee in a finished hive: one you hold, or one bought for gems.
func add_queen(uid: int, buy := false) -> bool:
	var hive := object_by_uid(uid)
	if hive.is_empty() or hive["id"] != "beehive" or under_construction(hive) or has_queen(hive):
		return false
	if not buy and queen_bees > 0:
		queen_bees -= 1
	elif buy:
		if not spend_gems(QUEEN_GEM_COST):
			message.emit("Not enough gems for a Queen Bee")
			return false
	else:
		message.emit("No Queen Bee yet. One may turn up while harvesting flowers.")
		return false
	hive["queen"] = true
	message.emit("The Queen Bee moved in! Worker bees will now join while you harvest flowers.")
	inventory_changed.emit()
	_objects_updated()
	return true


## Flower harvests: a rare Queen Bee, or a worker bee joining a hive that has a queen.
func _flower_harvest_bees() -> String:
	if not drops_enabled:
		return ""
	var all := hives()
	var queenless := all.filter(func(h: Dictionary) -> bool: return not has_queen(h))
	if (all.is_empty() or not queenless.is_empty()) and queen_bees == 0 and rng.randf() < QUEEN_CHANCE:
		queen_bees += 1
		_bump("queens_found", 1)
		message.emit("You found a Queen Bee! Put her in a Beehive.")
		inventory_changed.emit()
		return "A Queen Bee!"
	for h in all:
		if has_queen(h) and inside_total(h) < capacity(h):
			if rng.randf() >= BEE_CHANCE:
				return ""
			_put_bee_in(h)
			_bump("bees_found", 1)
			_objects_updated()
			return "A bee joined!"
	return ""


func _put_bee_in(hive: Dictionary) -> void:
	var inside: Dictionary = hive["inside"]
	if inside_total(hive) == 0:
		hive["t"] = now() # honey starts once the first bee moves in
	inside["bee"] = int(inside.get("bee", 0)) + 1


## Bees pollinate a fertilized crop as it's harvested: pollinated seeds of that crop.
func _pollinate(crop_id: String) -> int:
	if not drops_enabled or rng.randf() >= pollination_chance():
		return 0
	var n := pollinated_seeds(crop_id) + POLLINATED_SEEDS
	pollinated[crop_id] = [n, now() + POLLINATED_LIFETIME]
	_bump("pollinated", 1)
	message.emit("Your bees pollinated the %s! %d pollinated seeds for 2 days." % [crops[crop_id]["name"].to_lower(), n])
	inventory_changed.emit()
	return POLLINATED_SEEDS


## Pollinated seeds held for a crop, dropping any that expired.
func pollinated_seeds(crop_id: String) -> int:
	if not pollinated.has(crop_id):
		return 0
	var entry: Array = pollinated[crop_id]
	if now() >= int(entry[1]):
		pollinated.erase(crop_id)
		return 0
	return int(entry[0])


## Fertilizes every growing crop for free.
func use_fertilize_all() -> int:
	if fertilize_alls <= 0:
		message.emit("No Fertilize All left")
		return 0
	var done := 0
	for r in farm_size:
		for c in farm_size:
			var i := index_of(r, c)
			if phase(i) == Phase.GROWING and not is_fertilized(i):
				plots[i]["fert"] = true
				done += 1
	if done == 0:
		message.emit("Nothing growing to fertilize")
		return 0
	fertilize_alls -= 1
	_bump("fertilized", done)
	message.emit("Fertilized %d crops" % done)
	inventory_changed.emit()
	plot_changed.emit(-1)
	queue_save()
	return done


## FarmVille's bees left when nobody came for days, and the queen after weeks.
## Returns a note for the player, or "".
func apply_absence(seconds_away: int) -> String:
	var days := seconds_away / 86400.0
	if days <= BEES_STAY_DAYS:
		return ""
	var notes: Array[String] = []
	var share := minf(1.0, (days - BEES_STAY_DAYS) * BEES_LEAVE_PER_DAY)
	for h in hives():
		var bees := inside_total(h)
		var gone := mini(bees, int(ceil(bees * share)))
		if gone > 0:
			var inside: Dictionary = h["inside"]
			inside["bee"] = bees - gone
			if int(inside["bee"]) <= 0:
				inside.erase("bee")
			notes.append("%d bees left the hive while you were away" % gone)
		if days > QUEEN_STAYS_DAYS and has_queen(h):
			h.erase("queen")
			notes.append("the Queen Bee flew off")
	return "; ".join(PackedStringArray(notes))


# ---------------------------------------------------------------- pig pen

func is_foraging(pen: Dictionary) -> bool:
	return int(pen.get("forage_until", 0)) > 0


func forage_seconds_left(pen: Dictionary) -> int:
	return maxi(0, int(pen.get("forage_until", 0)) - now())


## Feeds slop to the pigs inside; they forage for truffles for 8 hours.
func feed_slop(uid: int) -> bool:
	var pen := object_by_uid(uid)
	if pen.is_empty() or pen["id"] != "pig_pen" or under_construction(pen) or is_foraging(pen):
		return false
	if inside_total(pen) == 0:
		message.emit("Move some pigs in first")
		return false
	if not spend(SLOP_COST):
		message.emit("Not enough coins for slop")
		return false
	pen["forage_until"] = now() + FORAGE_SECONDS
	message.emit("The pigs are out looking for truffles")
	_objects_updated()
	return true


## Truffles found by the pigs once foraging is over: one per 5 pigs, at least one.
func collect_truffles(uid: int) -> int:
	var pen := object_by_uid(uid)
	if pen.is_empty() or not is_foraging(pen) or forage_seconds_left(pen) > 0:
		return 0
	var found := maxi(1, int(inside_total(pen) / float(PIGS_PER_TRUFFLE)))
	pen.erase("forage_until")
	truffles += found
	_bump("truffles", found)
	message.emit("Your pigs found %d truffles!" % found)
	inventory_changed.emit()
	_objects_updated()
	return found


func rare_pigs() -> Array[String]:
	var out: Array[String] = []
	for id in item_order:
		if items[id].get("rare_pig", false):
			out.append(id)
	return out


## Trades 10 truffles for a rare pig breed, placed on the farm.
func trade_truffles(breed: String) -> bool:
	if not item_data(breed).get("rare_pig", false) or truffles < TRUFFLES_PER_PIG:
		return false
	if not place_somewhere(breed):
		message.emit("No room on the farm for a new pig")
		return false
	truffles -= TRUFFLES_PER_PIG
	message.emit("A %s joined your farm!" % item_data(breed)["name"])
	inventory_changed.emit()
	_objects_updated()
	return true


# ---------------------------------------------------------------- orchard

## A rare sapling of one of the trees inside, likelier for the trees you have more of.
func _roll_sapling(orchard: Dictionary) -> String:
	if not drops_enabled or rng.randf() >= SAPLING_CHANCE:
		return ""
	var inside: Dictionary = orchard["inside"]
	var pool: Array[String] = []
	var weights: Array[int] = []
	var total := 0
	for id in inside:
		if item_data(id).has("rare_sapling") and int(inside[id]) > 0:
			pool.append(id)
			weights.append(int(inside[id]))
			total += int(inside[id])
	if total == 0:
		return ""
	var pick := rng.randi_range(1, total)
	for k in pool.size():
		pick -= weights[k]
		if pick <= 0:
			return item_data(pool[k])["rare_sapling"]
	return ""


# ---------------------------------------------------------------- buying XP, selling and turning

## FarmVille gave XP for what you bought: 1 per 100 coins, and at least 5 for a decoration.
func buy_xp(item_id: String) -> int:
	var d := catalog.get_def(item_id)
	return d.buy_xp() if d else 0


## What selling an object returns: 5% of its price, as in FarmVille.
func sell_value(obj: Dictionary) -> int:
	var d := catalog.get_def(obj["id"])
	return (d as PlaceableDef).sell_value() if d is PlaceableDef else 0


func can_sell(obj: Dictionary) -> bool:
	if obj.is_empty() or obj.get("stray", false):
		return false
	return obj["id"] != "barn" and obj["id"] != "farmhouse"


## Sells an object. Animals, trees or vehicles inside a building move back onto the farm first.
func sell_object(uid: int) -> bool:
	var o := object_by_uid(uid)
	if not can_sell(o):
		message.emit("That can't be sold")
		return false
	var held: Array[String] = []
	for id in o.get("inside", {}):
		for k in int(o["inside"][id]):
			held.append(id)
	objects.erase(o)
	_rebuild_occupancy()
	if held.size() > 0:
		# Room check: the building's own tiles are free now that it's gone.
		var free := 0
		for r in farm_size:
			for c in farm_size:
				var i := index_of(r, c)
				if plots[i].get("state", "grass") == "grass" and not is_occupied(i):
					free += 1
		if free < held.size():
			objects.append(o)
			_rebuild_occupancy()
			message.emit("Not enough open grass for the %d inside. Make room first." % held.size())
			return false
		for id in held:
			place_somewhere(id)
	var value := sell_value(o)
	add_coins(value)
	_bump("items_sold", 1)
	var moved := (" · %d moved out onto the farm" % held.size()) if held.size() > 0 else ""
	message.emit("Sold the %s for %d coins%s" % [item_data(o["id"])["name"], value, moved])
	inventory_changed.emit()
	_objects_updated()
	return true


## Turns an object to face the other way. Only square ones turn, so nothing changes size.
func can_rotate(obj: Dictionary) -> bool:
	if obj.is_empty():
		return false
	var d := catalog.get_def(obj["id"])
	return d is PlaceableDef and (d as PlaceableDef).can_rotate()


func rotate_object(uid: int) -> bool:
	var o := object_by_uid(uid)
	if not can_rotate(o):
		message.emit("Buildings and big pieces can't turn")
		return false
	o["flip"] = not o.get("flip", false)
	_objects_updated()
	return true


# ---------------------------------------------------------------- vehicles and fuel

## Vehicle types you can drive: finished ones on the farm or parked in a garage.
func owned_vehicles() -> Array[String]:
	var out: Array[String] = []
	for o in objects:
		if kind_of(o) == "vehicle" and not under_construction(o) and not out.has(o["id"]):
			out.append(o["id"])
		elif o["id"] == "garage":
			for id in o.get("inside", {}):
				if int(o["inside"][id]) > 0 and not out.has(id):
					out.append(id)
	var ordered: Array[String] = []
	for id in item_order:
		if out.has(id):
			ordered.append(id)
	return ordered


func vehicle_level(id: String) -> int:
	return int(vehicle_levels.get(id, 0))


## Plots a vehicle works in one tap: columns x rows.
func vehicle_area(id: String) -> Vector2i:
	return VehicleDef.SIZES[clampi(vehicle_level(id), 0, VehicleDef.SIZES.size() - 1)]


## Fuel in the tank now, after its slow refill.
func fuel_now() -> int:
	if not fuel_unlocked:
		return 0
	var t := now()
	if fuel >= FUEL_TANK:
		fuel_t = t
		return fuel
	var gained := int((t - fuel_t) / float(FUEL_REGEN_SECONDS))
	if gained > 0:
		fuel = mini(FUEL_TANK, fuel + gained)
		fuel_t = t if fuel >= FUEL_TANK else fuel_t + gained * FUEL_REGEN_SECONDS
	return fuel


## Takes fuel for one plot, opening a spare tank when the tank runs dry.
func _burn_fuel(n: int) -> bool:
	fuel_now()
	if fuel < n and fuel_tanks > 0:
		fuel_tanks -= 1
		fuel = mini(FUEL_TANK, fuel + FUEL_TANK)
		message.emit("Opened a spare fuel tank")
	if fuel < n:
		return false
	if fuel >= FUEL_TANK:
		fuel_t = now() # the refill clock starts once the tank is below full
	fuel -= n
	return true


func buy_fuel_tank() -> bool:
	if not spend_gems(FUEL_TANK_GEM_COST):
		message.emit("Not enough gems for a fuel tank")
		return false
	fuel_tanks += 1
	message.emit("Bought a full fuel tank")
	inventory_changed.emit()
	return true


## Drives a vehicle over the area whose back corner is row, col.
## Tractor plows, Seeder plants crop_id, Harvester harvests, Combine does all three.
## Returns {"plots", "coins", "xp", "fuel", "drops":[texts]}, or {} if it couldn't run.
func use_vehicle(id: String, row: int, col: int, crop_id := "") -> Dictionary:
	if not owned_vehicles().has(id):
		return {}
	var it := item_data(id)
	var job: String = it["job"]
	if job == "plant" and crop_id == "":
		message.emit("Pick a seed first, then the Seeder")
		return {}
	if fuel_now() + fuel_tanks * FUEL_TANK <= 0:
		message.emit("Out of fuel. It refills slowly, or buy a tank.")
		return {}
	var per := int(it.get("fuel_per_plot", 1))
	var area := vehicle_area(id)
	var out := {"plots": 0, "coins": 0, "xp": 0, "fuel": 0, "drops": []}
	var coins_before := coins
	var xp_before := xp
	var out_of_fuel := false
	for r in range(row, row + area.y):
		for c in range(col, col + area.x):
			if not in_farm(r, c):
				continue
			var i := index_of(r, c)
			if is_occupied(i) or not _vehicle_has_work(job, i, crop_id):
				continue
			if not _burn_fuel(per):
				out_of_fuel = true
				break
			out["fuel"] = int(out["fuel"]) + per
			if _vehicle_work(job, i, crop_id, out):
				out["plots"] = int(out["plots"]) + 1
		if out_of_fuel:
			break
	out["coins"] = coins - coins_before
	out["xp"] = xp - xp_before
	if int(out["plots"]) > 0:
		_bump("vehicle_plots", int(out["plots"]))
	if out_of_fuel:
		message.emit("Out of fuel. It refills slowly, or buy a tank.")
	inventory_changed.emit()
	queue_save()
	return out


func _vehicle_has_work(job: String, i: int, crop_id: String) -> bool:
	var ph := phase(i)
	match job:
		"plow":
			return ph == Phase.GRASS or ph == Phase.WITHERED
		"plant":
			return ph == Phase.PLOWED
		"harvest":
			return ph == Phase.RIPE
		"all":
			return ph == Phase.RIPE or ph == Phase.GRASS or ph == Phase.WITHERED or (ph == Phase.PLOWED and crop_id != "")
	return false


func _vehicle_work(job: String, i: int, crop_id: String, out: Dictionary) -> bool:
	var did := false
	if (job == "harvest" or job == "all") and phase(i) == Phase.RIPE:
		var r := harvest(i)
		if not r.is_empty():
			did = true
			if r.get("drop_text", "") != "":
				(out["drops"] as Array).append(r["drop_text"])
	if (job == "plow" or job == "all") and (phase(i) == Phase.GRASS or phase(i) == Phase.WITHERED):
		if plow(i):
			did = true
			if drops_enabled and rng.randf() < TRACTOR_COIN_CHANCE:
				add_coins(TRACTOR_COINS)
	if (job == "plant" or job == "all") and crop_id != "" and phase(i) == Phase.PLOWED:
		if plant(i, crop_id):
			did = true
	return did


## FarmVille's Garage upgrades: Vehicle Parts make a vehicle cover more plots, up to 4x4.
func vehicle_upgrade_cost(id: String) -> int:
	var d := catalog.get_def(id)
	return (d as VehicleDef).upgrade_cost(vehicle_level(id)) if d is VehicleDef else -1


func vehicle_upgrade_level_needed(id: String) -> int:
	var d := catalog.get_def(id)
	return (d as VehicleDef).upgrade_level_needed(vehicle_level(id)) if d is VehicleDef else 0


func has_garage() -> bool:
	for o in objects:
		if o["id"] == "garage" and not under_construction(o):
			return true
	return false


func can_upgrade_vehicle(id: String) -> bool:
	var cost := vehicle_upgrade_cost(id)
	return has_garage() and owned_vehicles().has(id) and cost > 0 \
		and level() >= vehicle_upgrade_level_needed(id) and int(parts.get("vehicle_parts", 0)) >= cost


func upgrade_vehicle(id: String) -> bool:
	if not can_upgrade_vehicle(id):
		if not has_garage():
			message.emit("Build a Garage to upgrade vehicles")
		elif vehicle_upgrade_cost(id) < 0:
			message.emit("Your %s is fully upgraded" % item_data(id)["name"])
		elif level() < vehicle_upgrade_level_needed(id):
			message.emit("This upgrade unlocks at level %d" % vehicle_upgrade_level_needed(id))
		else:
			message.emit("Not enough Vehicle Parts yet")
		return false
	parts["vehicle_parts"] = int(parts["vehicle_parts"]) - vehicle_upgrade_cost(id)
	vehicle_levels[id] = vehicle_level(id) + 1
	var area := vehicle_area(id)
	_bump("vehicle_upgrades", 1)
	message.emit("%s upgraded! It now works %dx%d plots." % [item_data(id)["name"], area.x, area.y])
	inventory_changed.emit()
	_objects_updated()
	return true


# ---------------------------------------------------------------- strays

## Called on start, every 30 seconds, and after a debug time skip.
func check_strays() -> void:
	_expire_bunches()
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
		if it["kind"] != "animal":
			continue
		var w := 0.0
		if it.get("stray_only", false):
			# FarmVille's lonely bull, wandering stallion, ram and boar: only once you have their home.
			if _owns(str(it.get("home", ""))):
				w = 0.6
		elif it.get("lost", false):
			# FarmVille's lost animals (Pink Cow, Black Sheep, Ugly Duckling...): never sold, only adopted.
			w = LOST_WEIGHT
		elif int(it["unlock_level"]) <= level() + 2 and not it.has("gem_cost"):
			w = 1.0 / maxf(1.0, float(it["cost"]) / 100.0)
		if w > 0.0:
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


func _owns(item_id: String) -> bool:
	for o in objects:
		if o["id"] == item_id:
			return true
	return false


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


# ---------------------------------------------------------------- weather

## The weather right now (see Weather.current): looks only, FarmVille had none.
func weather() -> Dictionary:
	return Weather.current(now(), DayCycle.SEASON, DayCycle.local_hour(now(), DayCycle.device_bias_minutes()), weather_override)


# ---------------------------------------------------------------- crafting (FarmVille's Bakery, Winery and Spa)

func _int_map(d) -> Dictionary:
	var out := {}
	if typeof(d) == TYPE_DICTIONARY:
		for k in d:
			out[str(k)] = int(d[k])
	return out


func is_crafting(obj: Dictionary) -> bool:
	return kind_of(obj) == "crafting"


func owns_crafting() -> bool:
	for o in objects:
		if is_crafting(o):
			return true
	return false


## FarmVille: your first crafting building costs coins; every one after that, premium currency.
func crafting_price(item_id: String) -> Dictionary:
	var it := item_data(item_id)
	if owns_crafting():
		return {"gems": int(it.get("extra_gem_cost", 80))}
	return {"coins": int(it.get("cost", 0))}


func _crafting_def(obj: Dictionary) -> CraftingDef:
	return catalog.get_def(obj["id"]) as CraftingDef


func _recipe(rid: String) -> RecipeDef:
	return catalog.get_def(rid) as RecipeDef


## Every recipe the building knows, unlocked or not, by star.
func recipes_of(building_id: String) -> Array[RecipeDef]:
	return catalog.recipes_of(building_id)


func recipe_unlocked(obj: Dictionary, rid: String) -> bool:
	var r := _recipe(rid)
	return r != null and r.building() == obj["id"] and r.star() <= level_of(obj)


func recipe_stars(rid: String) -> int:
	return CraftingDef.recipe_stars(int(crafted.get(rid, 0)))


## Recipe mastery stars across one building's recipes; going up a star needs enough of them.
func building_recipe_stars(building_id: String) -> int:
	var n := 0
	for r in recipes_of(building_id):
		n += recipe_stars(r.id)
	return n


func total_bushels() -> int:
	var n := 0
	for c in bushels:
		n += int(bushels[c])
	return n


func add_bushels(crop_id: String, n: int) -> int:
	var room := maxi(0, BUSHEL_CAP - total_bushels())
	var got := mini(n, room)
	if got > 0:
		bushels[crop_id] = int(bushels.get(crop_id, 0)) + got
		inventory_changed.emit()
	return got


func _roll_bushel(crop_id: String) -> String:
	if not drops_enabled or not owns_crafting() or rng.randf() >= BUSHEL_CHANCE:
		return ""
	# FarmVille: each bushel found comes with one extra per mastery star on that crop.
	return crop_id if add_bushels(crop_id, 1 + mastery_stars(crop_id)) > 0 else ""


## Bushels still needed for one craft: crop id -> how many more.
func missing_bushels(rid: String) -> Dictionary:
	var out := {}
	var ins := _recipe(rid).inputs()
	for c in ins:
		var short := int(ins[c]) - int(bushels.get(c, 0))
		if short > 0:
			out[c] = short
	return out


func free_slots(obj: Dictionary) -> int:
	return _crafting_def(obj).slots(level_of(obj)) - (obj.get("slots", []) as Array).size()


## Why a craft can't start right now, or "" if it can.
func craft_problem(uid: int, rid: String) -> String:
	var obj := object_by_uid(uid)
	if obj.is_empty() or not is_crafting(obj):
		return "That isn't a crafting building"
	if not recipe_unlocked(obj, rid):
		return "Unlocks at %d stars" % _recipe(rid).star() if _recipe(rid) else "Unknown recipe"
	if free_slots(obj) <= 0:
		return "Every slot is busy"
	if not missing_bushels(rid).is_empty():
		return "Not enough bushels"
	return ""


func start_craft(uid: int, rid: String) -> bool:
	if craft_problem(uid, rid) != "":
		return false
	var obj := object_by_uid(uid)
	var ins := _recipe(rid).inputs()
	for c in ins:
		bushels[c] = int(bushels[c]) - int(ins[c])
		if int(bushels[c]) <= 0:
			bushels.erase(c)
	(obj["slots"] as Array).append({"r": rid, "done": now() + _crafting_def(obj).craft_seconds()})
	_bump("crafts_started", 1)
	inventory_changed.emit()
	_objects_updated()
	return true


## FarmVille's "Buy all ingredients": the missing bushels for gems, then start crafting.
func buy_missing_and_craft(uid: int, rid: String) -> bool:
	var missing := missing_bushels(rid)
	var n := 0
	for c in missing:
		n += int(missing[c])
	var obj := object_by_uid(uid)
	if obj.is_empty() or not recipe_unlocked(obj, rid) or free_slots(obj) <= 0:
		return false
	if n > 0 and not spend_gems(n * BUSHEL_GEM_COST):
		message.emit("Not enough gems")
		return false
	for c in missing:
		bushels[c] = int(bushels.get(c, 0)) + int(missing[c]) # may go past the cap: used straight away
	return start_craft(uid, rid)


func crafts_done(obj: Dictionary) -> int:
	var n := 0
	for slot in obj.get("slots", []):
		if now() >= int(slot["done"]):
			n += 1
	return n


## Moves finished crafts into goods. Returns how many finished.
func finish_crafts(uid: int) -> int:
	var obj := object_by_uid(uid)
	if obj.is_empty() or not is_crafting(obj):
		return 0
	var still: Array = []
	var n := 0
	for slot in obj.get("slots", []):
		if now() >= int(slot["done"]):
			var rid: String = slot["r"]
			var before := recipe_stars(rid)
			goods[rid] = int(goods.get(rid, 0)) + 1
			crafted[rid] = int(crafted.get(rid, 0)) + 1
			add_xp(CRAFT_XP_PER_STAR * _recipe(rid).star())
			_bump("crafted", 1)
			if recipe_stars(rid) > before:
				message.emit("%s mastery: %d stars!" % [_recipe(rid).name, recipe_stars(rid)])
			n += 1
		else:
			still.append(slot)
	obj["slots"] = still
	if n > 0:
		message.emit("Finished %d %s" % [n, "good" if n == 1 else "goods"])
		inventory_changed.emit()
		_objects_updated()
	return n


func good_price(rid: String) -> int:
	return _recipe(rid).sell_price(crops, recipe_stars(rid))


func good_fuel(rid: String) -> int:
	return _recipe(rid).fuel(recipe_stars(rid))


func sell_good(rid: String) -> int:
	if int(goods.get(rid, 0)) <= 0:
		return 0
	var price := good_price(rid)
	_take_good(rid)
	add_coins(price)
	_bump("goods_sold", 1)
	return price


## FarmVille's "Use": a good becomes fuel. Fuel past a full tank fills spare tanks.
func use_good(rid: String) -> int:
	if int(goods.get(rid, 0)) <= 0:
		return 0
	var f := good_fuel(rid)
	_take_good(rid)
	_add_fuel(f)
	return f


func _take_good(rid: String) -> void:
	goods[rid] = int(goods[rid]) - 1
	if int(goods[rid]) <= 0:
		goods.erase(rid)
	inventory_changed.emit()
	queue_save()


func star_cost(obj: Dictionary) -> Dictionary:
	return _crafting_def(obj).star_cost(level_of(obj))


func can_add_star(uid: int, with_gems: bool) -> bool:
	var obj := object_by_uid(uid)
	if obj.is_empty() or not is_crafting(obj):
		return false
	var cost := star_cost(obj)
	if cost.is_empty():
		return false
	if with_gems:
		return gems >= int(cost["gems"])
	return coins >= int(cost["coins"]) and building_recipe_stars(obj["id"]) >= int(cost["recipe_stars"])


func add_star(uid: int, with_gems: bool) -> bool:
	if not can_add_star(uid, with_gems):
		return false
	var obj := object_by_uid(uid)
	var cost := star_cost(obj)
	if with_gems:
		spend_gems(int(cost["gems"]))
	else:
		spend(int(cost["coins"]))
	obj["level"] = level_of(obj) + 1
	message.emit("Your %s now has %d stars: a new slot and 3 new recipes!" % [item_data(obj["id"])["name"], level_of(obj)])
	_objects_updated()
	return true


## The Farmers Market: a few crops' bushels for coins, new each day (standing in for neighbours' stalls).
func _refresh_stall() -> void:
	var today := day_number()
	if stall_day == today:
		return
	stall_day = today
	stall = {}
	var pool: Array[String] = []
	for b in objects:
		if is_crafting(b):
			for r in recipes_of(b["id"]):
				for c in r.inputs():
					if not pool.has(str(c)):
						pool.append(str(c))
	for k in mini(STALL_CROPS, pool.size()):
		var c := pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(c)
		stall[c] = STALL_EACH


func market_stall() -> Dictionary:
	_refresh_stall()
	return stall


func bushel_price(crop_id: String) -> int:
	return int(crops[crop_id]["sell_price"])


func buy_bushel(crop_id: String) -> bool:
	_refresh_stall()
	if int(stall.get(crop_id, 0)) <= 0 or total_bushels() >= BUSHEL_CAP:
		return false
	if not spend(bushel_price(crop_id)):
		return false
	stall[crop_id] = int(stall[crop_id]) - 1
	add_bushels(crop_id, 1)
	queue_save()
	return true


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
	if star == 3 and place_somewhere("mastery_sign"):
		objects[-1]["crop"] = crop_id # FarmVille's mastery sign, to show off on the farm
		message.emit("%s mastered! A mastery sign was put on your farm." % crops[crop_id]["name"])
		_objects_updated()


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


## Loads the catalog once; crops, items and materials all come from it.
func _load_catalog() -> void:
	if catalog != null:
		return
	catalog = Catalog.load_default()
	for e in catalog.errors:
		push_error("Catalog: " + e)
	if PARTS.is_empty():
		for d in catalog.of_kind("material"):
			PARTS.append(d.id)
			PART_NAMES[d.id] = d.name
			if (d as MaterialDef).is_basic():
				BASIC_PARTS.append(d.id)


func _load_crops() -> void:
	_load_catalog()
	for d in catalog.of_kind("crop"):
		crops[d.id] = d.data
		crop_order.append(d.id)


func _load_collections() -> void:
	var parsed := _read_json("res://data/collections.json")
	collections_data = parsed
	collections = parsed.get("collections", [])
	for coll in collections:
		if coll.get("birds", false):
			bird_collection = coll
		match str(coll.get("source", "")):
			"trees": tree_collection = coll
			"animals": animal_collection = coll
		for crop_id in coll.get("crops", []):
			collection_of_crop[crop_id] = coll
		for item in coll["items"]:
			item_names[item["id"]] = item["name"]


func _load_ribbons() -> void:
	ribbon_data = _read_json("res://data/ribbons.json")


func _load_items() -> void:
	_load_catalog()
	for id in catalog.order:
		var d := catalog.get_def(id)
		if d.kind == "crop" or d.kind == "material" or d.kind == "recipe":
			continue
		items[id] = d.data
		item_order.append(id)


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
	queen_bees = 0
	fertilize_alls = 0
	pollinated = {}
	truffles = 0
	fuel = 0
	fuel_t = 0
	fuel_tanks = 0
	fuel_unlocked = false
	vehicle_levels = {}
	absence_note = ""
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
	parts = {}
	for p in PARTS:
		parts[p] = 0
	coll_levels = {}
	fuel_found_day = 0
	bunches = []
	bushels = {}
	goods = {}
	crafted = {}
	stall = {}
	stall_day = 0
	mystery_eggs = {}
	farmhands = 0
	arborists = 0
	fertilizer_bags = 0
	stored = []
	last_daily_day = day_number()
	daily_streak = 0
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
		"queen_bees": queen_bees,
		"fertilize_alls": fertilize_alls,
		"pollinated": pollinated,
		"truffles": truffles,
		"fuel": fuel,
		"fuel_t": fuel_t,
		"fuel_tanks": fuel_tanks,
		"fuel_unlocked": fuel_unlocked,
		"vehicle_levels": vehicle_levels,
		"parts": parts,
		"mystery_eggs": mystery_eggs,
		"farmhands": farmhands,
		"arborists": arborists,
		"fertilizer_bags": fertilizer_bags,
		"last_daily_day": last_daily_day,
		"daily_streak": daily_streak,
		"stored": stored,
		"next_stray_at": next_stray_at,
		"next_uid": next_uid,
		"bushels": bushels,
		"coll_levels": coll_levels,
		"fuel_found_day": fuel_found_day,
		"bunches": bunches,
		"goods": goods,
		"crafted": crafted,
		"stall": stall,
		"stall_day": stall_day,
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
	queen_bees = int(data.get("queen_bees", 0))
	fertilize_alls = int(data.get("fertilize_alls", 0))
	truffles = int(data.get("truffles", 0))
	fuel = int(data.get("fuel", 0))
	fuel_t = int(data.get("fuel_t", 0))
	fuel_tanks = int(data.get("fuel_tanks", 0))
	fuel_unlocked = bool(data.get("fuel_unlocked", false))
	vehicle_levels = {}
	var saved_levels: Dictionary = data.get("vehicle_levels", {})
	for v in saved_levels:
		vehicle_levels[v] = int(saved_levels[v])
	pollinated = {}
	var saved_pol: Dictionary = data.get("pollinated", {})
	for c in saved_pol:
		var e: Array = saved_pol[c]
		if crops.has(c) and e.size() == 2:
			pollinated[c] = [int(e[0]), int(e[1])]
	var saved_parts: Dictionary = data.get("parts", {})
	parts = {}
	for p in PARTS:
		parts[p] = int(saved_parts.get(p, 0))
	last_daily_day = int(data.get("last_daily_day", day_number()))
	daily_streak = int(data.get("daily_streak", 0))
	bushels = _int_map(data.get("bushels", {}))
	coll_levels = _int_map(data.get("coll_levels", {}))
	fuel_found_day = int(data.get("fuel_found_day", 0))
	bunches = (data.get("bunches", []) as Array).duplicate()
	goods = _int_map(data.get("goods", {}))
	crafted = _int_map(data.get("crafted", {}))
	stall = _int_map(data.get("stall", {}))
	stall_day = int(data.get("stall_day", 0))
	mystery_eggs = {}
	var saved_eggs: Dictionary = data.get("mystery_eggs", {})
	for colour in saved_eggs:
		mystery_eggs[colour] = int(saved_eggs[colour])
	farmhands = int(data.get("farmhands", 0))
	arborists = int(data.get("arborists", 0))
	fertilizer_bags = int(data.get("fertilizer_bags", 0))
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
		if obj.has("forage_until"):
			obj["forage_until"] = int(obj["forage_until"])
		objects.append(obj)
	next_uid = int(data.get("next_uid", 1))
	absence_note = apply_absence(now() - int(data.get("saved_at", now())))
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
