class_name GameState
extends Node
## Global game state, autoloaded as `Game`: the shared core (coins, gems, XP and levels, time, plots and
## crops, placed objects, mastery, the tutorial, saving) plus one instance of each subsystem in
## scripts/systems/ (Game.crafting, Game.vehicles, Game.bees...). All rules live here and in the systems;
## scenes only display and call in.

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
signal inbox_changed             # the neighbours' mail changed (arrived, claimed, answered)

enum Phase { GRASS, PLOWED, GROWING, RIPE, WITHERED }
enum Tutorial { HARVEST, PLOW, PLANT, DONE }

# Each step's hint, as keys in locale/strings.csv (tutorial_text() translates it).
const TUTORIAL_TEXT := {
	Tutorial.HARVEST: "YOUR_FIRST_CROPS_ARE_READY_TAP",
	Tutorial.PLOW: "CHOOSE_PLOW_THEN_TAP_A_GRASSY",
	Tutorial.PLANT: "CHOOSE_STRAWBERRIES_THEN_TAP_A_PLOWED",
}


# Rescue: if a player can't afford seeds and has nothing growing, top them up to this.
## Farmhand: collects every ready animal on the farm. Arborist: every ready tree.
## FarmVille's helpers: each collects everything of its kind that's ready, at once. kind -> the field
## counting them, what they're called, and what's said after.
const HELPERS := {
	"animal": {"field": "farmhands", "name": "FARMHANDS", "done": "COLLECTED_ANIMALS_FOR_COINS"},
	"tree": {"field": "arborists", "name": "ARBORISTS", "done": "COLLECTED_TREES_FOR_COINS"},
	"bloom": {"field": "gardeners", "name": "GARDENERS", "done": "COLLECTED_BLOOMS_FOR_COINS"},
}
const SAVE_PATH := "user://save.json"
const SAVE_DELAY_MSEC := 1500    # changes are written together, at most this often (a save is the whole farm)
const BACKUP_SUFFIX := ".bak"     # the save before the last one: used if the newest is unreadable
const TEMP_SUFFIX := ".tmp"
const SAVE_VERSION := 2         # 2: FarmVille footprints (older saves are settled on load)
const OLDEST_SAVE_VERSION := 1
const SHOWCASE_ARG := "--showcase"  # debug builds: start on the showcase farm (godot ... -- --showcase)
const MAX_SIZE := 30   # plots are stored for the largest farm; farm_size says how much is usable
const START_SIZE := 12
const OLD_GRID_SIZE := 12 # saves from before land expansion stored a 12x12 grid

# A vehicle's working area at each upgrade: 2x2, growing with Vehicle Parts in the Garage up to 4x4.
const VEHICLE_SIZES := VehicleDef.SIZES
# FarmVille: any action can drop a collectible (plow, plant, fertilize); harvests are likelier.


# Mastery: harvests needed for stars 1, 2, 3, by crop speed.

# Building parts: found while harvesting and collecting, plus a daily gift.
# Building materials, the FarmVille set: three basic ones every building uses,
# plus two specific to some buildings (they only drop once you own that building).
# Materials come from data/catalog/materials.json (filled in when the catalog loads).
static var basic_parts: Array[String] = []
static var part_ids: Array[String] = []
static var part_names := {}

var crops := {}                    # id -> crop dictionary from data/catalog/crops.json
var crop_order: Array[String] = [] # display order
var coins := Balance.i("economy.start_coins")
var gems := Balance.i("economy.start_gems")           # premium currency
var xp := 0
var plots: Array[Dictionary] = []  # MAX_SIZE * MAX_SIZE entries, row-major
var farm_size := START_SIZE        # usable width and depth in tiles
var unwithers := Balance.i("economy.start_unwithers")   # Unwither items held
var fertilize_alls := 0            # fertilize every growing crop at once
var absence_note := ""             # what happened while the player was away, shown on start
var parts := {}                    # building material -> count (see part_ids)
var farmhands := 0                 # collect every animal at once
var arborists := 0                 # collect every tree at once
var gardeners := 0                 # collect every bloom at once
var fertilizer_bags := 0           # free fertilizer, used before coins
var clear_until := 0               # unix time until which the weather is clear (a new farm)
var weather_override := ""         # force a weather state (screenshots, testing); "" = the real weather
var debug_time_offset := 0         # seconds; only changed by the debug skip button
var tutorial_step: int = Tutorial.HARVEST
var catalog: Catalog               # every item, as typed definitions (scripts/catalog/)
var items := {}                    # placeable objects from data/catalog/, as dictionaries
var item_order: Array[String] = []
var objects: Array = []            # placed trees, animals and buildings
var next_uid := 1
var modal_open := false            # true while a menu covers the farm
var rng := RandomNumberGenerator.new()

# Test hooks: tests turn saving off (or point it at a scratch file) and can switch off random drops.
var saving_enabled := true
var save_path := SAVE_PATH
var drops_enabled := true

# The subsystems (scripts/systems/): each owns its own state and rules, and reaches shared state
# through `game`. Built in _init so a bare GameState.new() (as in tests) is complete.
var drops: HarvestDrops
var collectibles: CollectiblesSystem
var shed: GardenShedSystem
var ribbons: RibbonsSystem
var land: LandSystem
var specials: BuildingSpecials
var mystery: MysterySystem
var daily: DailySystem
var storage: BarnStorage
var bees: BeehiveSystem
var links: LinksSystem
var mastery: MasterySystem
var nurture: NurtureSystem
var social: SocialSystem
var finds: FindsSystem
var feeds: FeedSystem
var adjacency: AdjacencySystem
var boosts: HomeBoostSystem
var player: PlayerSystem
var pigpen: PigPenSystem
var vehicles: VehicleSystem
var field: FieldSystem
var strays: StraySystem
var crafting: CraftingSystem
var homes: HousingSystem
var buildings: BuildingSystem
var persistence: Persistence          # saving and loading (not in `systems`: it has no state of its own)

var systems: Array[GameSystem] = []   # all of the above, for load_data/reset/save_to/load_from


var layout_revision := 0           # goes up whenever which tiles are covered may have changed (walking grid, etc.)
var _level := 1                    # level() remembered for this XP (and this version of the Balance numbers)
var _level_xp := -1
var _level_rev := -1
var _occupied := {}                # tile index -> uid of the object covering it
var _uid_index := {}               # uid -> its position in objects (see object_by_uid)

var _weather := {}                # the last answer of weather(), and when and for what it was made
var _weather_at := -1
var _weather_for := "?"


func _init() -> void:
	drops = HarvestDrops.new(self)
	collectibles = CollectiblesSystem.new(self)
	shed = GardenShedSystem.new(self)
	ribbons = RibbonsSystem.new(self)
	land = LandSystem.new(self)
	specials = BuildingSpecials.new(self)
	mystery = MysterySystem.new(self)
	daily = DailySystem.new(self)
	storage = BarnStorage.new(self)
	bees = BeehiveSystem.new(self)
	links = LinksSystem.new(self)
	mastery = MasterySystem.new(self)
	pigpen = PigPenSystem.new(self)
	vehicles = VehicleSystem.new(self)
	field = FieldSystem.new(self)
	player = PlayerSystem.new(self)
	nurture = NurtureSystem.new(self)
	social = SocialSystem.new(self)
	finds = FindsSystem.new(self)
	feeds = FeedSystem.new(self)
	adjacency = AdjacencySystem.new(self)
	boosts = HomeBoostSystem.new(self)
	strays = StraySystem.new(self)
	crafting = CraftingSystem.new(self)
	homes = HousingSystem.new(self)
	buildings = BuildingSystem.new(self)
	persistence = Persistence.new(self)
	systems = [field, drops, collectibles, shed, ribbons, land, specials, mystery, daily, storage, bees, links, pigpen,
		vehicles, strays, crafting, homes, buildings, mastery, player, nurture, finds, feeds, adjacency, boosts, social]


func _ready() -> void:
	rng.randomize()
	_load_crops()
	_load_items()
	for system in systems:
		system.load_data()
	if not saving_enabled or not load_game():
		_new_game()
	if OS.is_debug_build() and OS.get_cmdline_user_args().has(SHOWCASE_ARG):
		open_showcase.call_deferred()  # straight into the farm with everything on it, for testing
	# Deferred so the HUD is connected and can show the message.
	check_rescue.call_deferred()
	strays.check_strays.call_deferred()
	daily.check_daily_gift.call_deferred()
	_show_absence.call_deferred()
	var stray_timer := Timer.new()
	stray_timer.wait_time = 30.0
	stray_timer.autostart = true
	stray_timer.timeout.connect(strays.check_strays)
	stray_timer.timeout.connect(daily.check_daily_gift)
	add_child(stray_timer)


func _show_absence() -> void:
	if absence_note != "":
		message.emit(absence_note)
		absence_note = ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _exit_tree() -> void:
	Instancer.clear()   # the shared looks live in statics: let them go before the engine reports leaks


# ---------------------------------------------------------------- time


## The farmer works through their queue as time passes (PlayerSystem).
func _process(delta: float) -> void:
	player.advance(delta)
	vehicles.advance(delta)
	persistence.tick()


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
		for m in part_ids:
			parts[m] = int(parts.get(m, 0)) + n
		inventory_changed.emit()
		queue_save()


## Adds bees to finished hives (with a queen, so the hive works). Test helper.
func debug_add_bees(n: int) -> void:
	if not OS.is_debug_build():
		return
	var all := bees.hives()
	if all.is_empty():
		message.emit(tr("BUILD_A_BEEHIVE_FIRST"))
		return
	for h in all:
		h["queen"] = true
		var room := capacity(h) - inside_total(h)
		for k in mini(n, room):
			bees.put_bee_in(h)
		n -= mini(n, room)
	objects_updated()


func debug_level_up() -> void:
	if OS.is_debug_build():
		add_xp(xp_for_level(level() + 1) - xp)


func debug_skip(seconds: int) -> void:
	if not OS.is_debug_build():
		return
	debug_time_offset += seconds
	strays.check_strays()
	daily.check_daily_gift()
	plot_changed.emit(-1)
	check_rescue()
	queue_save()


## The player's calendar day (their local midnight, not UTC's): the daily gift, fuel find and crafting daily turn there.
func day_number() -> int:
	return floori((now() + DayCycle.device_bias_minutes() * 60) / 86400.0)


# ---------------------------------------------------------------- plots


func index_of(row: int, col: int) -> int:
	return row * MAX_SIZE + col


func in_farm(row: int, col: int) -> bool:
	return row >= 0 and col >= 0 and row < farm_size and col < farm_size


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




## O(1): a uid -> position index that checks itself on every use. Code anywhere may add, remove or replace
## objects without telling it: a stale position no longer holds that uid, and the index is rebuilt then.
func object_by_uid(uid: int) -> Dictionary:
	if uid < 0:
		return {}
	var i: int = _uid_index.get(uid, -1)
	if i < 0 or i >= objects.size() or int(objects[i]["uid"]) != uid:
		_uid_index.clear()
		for k in objects.size():
			_uid_index[int(objects[k]["uid"])] = k
		i = _uid_index.get(uid, -1)
		if i < 0:
			return {}
	return objects[i]




## The only ways objects join or leave the farm: each keeps the tiles they stand on (and the uid index) true.
func add_object(o: Dictionary) -> void:
	if o.has("uid") and not object_by_uid(int(o["uid"])).is_empty():
		push_warning("add_object: uid %d is already on the farm" % int(o["uid"]))
		return  # two things never share a uid: taps, saves and the uid index all depend on it
	objects.append(o)
	if o.has("row") and o.has("col"):
		_occupy(o)


func remove_object(o: Dictionary) -> void:
	objects.erase(o)
	rebuild_occupancy()


## Replaces the whole list (a sweep that drops several at once).
func set_objects(list: Array) -> void:
	objects = list
	rebuild_occupancy()


func is_occupied(i: int) -> bool:
	return _occupied.has(i)


func rebuild_occupancy() -> void:
	_occupied.clear()
	layout_revision += 1
	for o in objects:
		_occupy(o)


## Objects go on grass or empty plowed plots, never on planted crops or other objects.
## `strict` also keeps a tree and a building off each other's edges (a tree's crown overhangs its tile, so it is
## never planted hard against a wall); laying the farm back down after loading is not strict, so no save moves.
func can_place(item_id: String, row: int, col: int, ignore_uid := -1, strict := true) -> bool:
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
	return not (strict and _crowds_neighbour(item_id, row, col, fp, ignore_uid))


## Whether a tree here would touch a building, or a building here a tree: something of the other kind on the ring
## of tiles around the footprint (diagonals too).
func _crowds_neighbour(item_id: String, row: int, col: int, fp: Vector2i, ignore_uid: int) -> bool:
	var kind: String = item_data(item_id).get("kind", "")
	if kind != "tree" and kind != "building":
		return false
	var other := "building" if kind == "tree" else "tree"
	for r in range(row - 1, row + fp.y + 1):
		for c in range(col - 1, col + fp.x + 1):
			if r < 0 or c < 0 or r >= farm_size or c >= farm_size:
				continue
			if r >= row and r < row + fp.y and c >= col and c < col + fp.x:
				continue
			var uid := int(_occupied.get(index_of(r, c), -1))
			if uid == -1 or uid == ignore_uid:
				continue
			if str(item_data(object_by_uid(uid).get("id", "")).get("kind", "")) == other:
				return true
	return false


func grass_over(item_id: String, row: int, col: int) -> void:
	var fp := footprint(item_id)
	for r in range(row, row + fp.y):
		for c in range(col, col + fp.x):
			plots[index_of(r, c)] = {"state": "grass"}


func can_afford_item(item_id: String) -> bool:
	return buildings.can_buy(item_id).ok()


## Buys one of an item, wherever it's going (onto the farm or straight into a home): checks its level,
## takes its price (coins, gems, or a crafting building's rising price), and applies what buying it does
## (its XP, the decorating ribbon, a first vehicle filling the fuel tank). False, with a message, if it
## can't be bought.
func buy_item(item_id: String) -> bool:
	var it := item_data(item_id)
	var verdict := buildings.can_buy(item_id)  # its level, the farm's limit, its price
	if not verdict.ok():
		if verdict.text != "":
			message.emit(verdict.text)
		return false
	var price := buildings.price_of(item_id)
	if not (spend_gems(int(price["gems"])) if price.has("gems") else spend(int(price.get("coins", 0)))):
		return false
	var bought_xp := buy_xp(item_id)
	if bought_xp > 0:
		add_xp(bought_xp)
	if it["kind"] == "decor":
		ribbons.bump("decor_bought", 1)
	if it["kind"] == "vehicle":
		vehicles.on_vehicle_bought()
	return true


func buy_and_place(item_id: String, row: int, col: int) -> bool:
	var it := item_data(item_id)
	if it.is_empty() or not can_place(item_id, row, col) or not buy_item(item_id):
		return false
	var obj := {"uid": next_uid, "id": item_id, "row": row, "col": col, "t": now()}
	if it.get("special", "") == "garden_shed":
		shed.on_shed_built()
	if it["kind"] == "crafting":
		crafting.on_crafting_built(obj)
	if it["kind"] == "building":
		obj["level"] = maxi(1, finds.tier(str(it.get("home_of", ""))))
		obj["inside"] = {}
		if it.has("build_materials"):
			obj["construction"] = {} # a frame: finished with materials, like FarmVille
			message.emit(tr("FRAME_PLACED_TAP_IT_TO_ADD") % it["name"])
		else:
			message.emit(tr("BUILT_OPEN_IT_TO_MOVE_ANIMALS") % it["name"])
	elif it["kind"] == "vehicle":
		if it.has("build_materials"):
			obj["construction"] = {} # the Combine's chassis, finished with Vehicle Parts
			message.emit(tr("CHASSIS_PLACED_TAP_IT_TO_ADD") % it["name"])
		else:
			message.emit(tr("BOUGHT_PICK_IT_IN_THE_TOOLBAR") % it["name"])
	next_uid += 1
	grass_over(item_id, row, col)
	add_object(obj)
	objects_updated()
	return true


func move_object(uid: int, row: int, col: int) -> bool:
	var obj := object_by_uid(uid)
	if obj.is_empty() or not can_place(obj["id"], row, col, uid):
		return false
	obj["row"] = row
	obj["col"] = col
	grass_over(obj["id"], row, col)
	objects_updated()
	return true


## A building's own cycle (the Stable's 1 day beats a loose horse's 3) or the item's.
func cycle_of(obj: Dictionary) -> int:
	var cycle := int(item_data(obj["id"]).get("cycle_seconds", 86400))
	var cut := feeds.speed_cut(obj)   # a speed feed shortens the cycle it was given for
	return maxi(1, roundi(cycle * (1.0 - cut))) if cut > 0.0 else cycle


func level_of(obj: Dictionary) -> int:
	return int(obj.get("level", 1))


func max_level(building_id: String) -> int:
	var d := catalog.get_def(building_id)
	return (d as BuildingDef).max_level() if d is BuildingDef else 1


## The building's name at its size: Big Chicken Coop, Huge Dairy Farm...
func size_name(obj: Dictionary) -> String:
	var it := item_data(obj["id"])
	var def := building_def(obj["id"])
	var lvl := level_of(obj)
	if def != null and def.size(lvl).has("name"):
		return str(def.size(lvl)["name"])
	return it["name"] if lvl == 1 else tr("SIZE") % [it["name"], lvl]


## A building's definition (null for anything else).
func building_def(id: String) -> BuildingDef:
	return catalog.get_def(id) as BuildingDef


## Whether an item is a building (its catalog class is BuildingDef or one of its kinds: BarnDef, CraftingDef...).
## The one test of it: the Market, the limits and the showcase all ask here (`is_home` asks something
## narrower, of a placed object).
func is_building_item(id: String) -> bool:
	return building_def(id) != null


func under_construction(obj: Dictionary) -> bool:
	return obj.has("construction")


func kind_of(obj: Dictionary) -> String:
	return item_data(obj["id"]).get("kind", "")


## Whether a placed object is a home: a building of kind "building", holding animals, trees, bees or vehicles
## (not the Barn or a crafting building; for "any building" ask `is_building_item`).
func is_home(obj: Dictionary) -> bool:
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
	var ph := field.phase(i)
	var stage := "growing"
	match ph:
		Phase.RIPE:
			stage = "ripe"
		Phase.WITHERED:
			stage = "withered"
		Phase.GROWING:
			stage = "planted" if field.growth(i) < 0.5 else "growing"
	var art := "crop_%s_%s" % [field.crop_at(i), stage]
	return art if SpriteBank.has(art) else ""


func is_ready(obj: Dictionary) -> bool:
	if obj.get("stray", false):
		return false
	var it := item_data(obj["id"])   # one lookup: this runs for every object, every frame
	var kind: String = it.get("kind", "")
	if kind == "decor" or kind == "barn" or kind == "vehicle":
		return false # scenery, the barn and vehicles never produce
	if not it.get("produces", true):
		return false # the garage only stores
	if under_construction(obj):
		return false
	if kind == "building" and inside_total(obj) == 0:
		return false
	return now() - int(obj["t"]) >= cycle_of(obj) and not is_withered(obj)


## A Single Bloom on the farm left ready for 7 days has withered: no harvest until Flower Food regrows it.
## (In a Bloom Garden blooms are counts, not objects, so they never wither there.)
func is_withered(obj: Dictionary) -> bool:
	var d := catalog.get_def(str(obj.get("id", "")))
	if not d is BloomDef or not (d as BloomDef).withers():
		return false
	return now() - int(obj["t"]) >= cycle_of(obj) + Balance.i("blooms.wither_after")


func seconds_until_ready(obj: Dictionary) -> int:
	return maxi(0, int(obj["t"]) + cycle_of(obj) - now())


## Coins and XP one collection pays.
func object_payout(obj: Dictionary) -> Vector2i:
	if not is_home(obj):
		var it := item_data(obj["id"])
		return Vector2i(int(it.get("payout", 0)), int(it.get("xp", 0)))
	var total := Vector2i.ZERO
	var inside: Dictionary = obj["inside"]
	for id in inside:
		var it2 := item_data(id)
		# Vehicles and other things parked in a building pay nothing.
		total += Vector2i(int(it2.get("payout", 0)), int(it2.get("xp", 0))) * int(inside[id])
	return total


## Returns {"coins", "xp", "drop", "drop_text", "name"} or {} if nothing was ready.
func collect(uid: int) -> Dictionary:
	var obj := object_by_uid(uid)
	if obj.is_empty() or not is_ready(obj):
		return {}
	# FarmVille: collecting pays coins and mastery, never XP (an animal or tree gave its XP once, when bought);
	# only a bonus drop adds XP.
	# Fed or hungry, and touching its own kind.
	var earned := roundi(object_payout(obj).x * feeds.coin_multiplier(obj) * adjacency.coin_multiplier(obj))
	feeds.rare_boost = feeds.rare_multiplier(obj)
	var gained := 0
	var drop := drops.roll_drop("", 0)
	match drop.get("type", ""):
		"golden":
			earned *= Balance.i("economy.golden_coin_multiplier")
			gained += Balance.i("economy.golden_xp")
		"super_harvest":
			earned *= 2
		"bonus_xp":
			gained += Balance.i("economy.bonus_xp")
	obj["t"] = now()
	add_coins(earned)
	add_xp(gained)
	ribbons.bump("collected", 1)
	var part := daily.roll_part()
	var extras: Array[String] = []
	var name_before: String = item_data(obj["id"])["name"]
	# Every animal, tree or bloom harvested earns its own mastery, loose or living in a home.
	if is_home(obj):
		var inside: Dictionary = obj.get("inside", {})
		for id in inside:
			mastery.add_harvest(id, int(inside[id]))
	else:
		mastery.add_harvest(obj["id"], 1)
	if kind_of(obj) == "bloom":
		extras.append_array(nurture.from_bloom(obj))
	if is_home(obj):
		extras.append_array(specials.building_specials(obj))
		extras.append_array(specials.grow_up_inside(obj))
	else:
		var adult := specials.grows_into(obj["id"])
		if adult != "":
			obj["id"] = adult
			message.emit(tr("YOUR_GREW_UP_INTO_A") % [name_before.to_lower(), item_data(adult)["name"].to_lower()])
			extras.append(tr("GREW_UP"))
	obj.erase(FeedSystem.FED)   # what it was fed was for this cycle
	feeds.rare_boost = 1.0
	var coll_find := ""
	if kind_of(obj) == "tree":
		var fruit := feeds.roll_tree()
		if fruit != "":
			extras.append(tr("FOUND_FEED") % feeds.feed_name(fruit))
		coll_find = collectibles.roll_collectible(
			collectibles.tree_collection,
			Balance.f("economy.animal_collectible_chance")
		)
	elif kind_of(obj) == "animal" or is_home(obj):
		coll_find = collectibles.roll_collectible(
			collectibles.animal_collection,
			Balance.f("economy.animal_collectible_chance")
		)
	if coll_find != "":
		extras.append(tr("FOUND") + coll_find)
	if drop.get("type", "") == "golden":
		ribbons.bump("golden_finds", 1)
		message.emit(tr("GOLDEN_COLLECTION_X_COINS") % Balance.i("economy.golden_coin_multiplier"))
	elif drop.get("type", "") == "bird":
		message.emit(tr("A_LANDED_ON_YOUR_FARM_COLLECTION") % [drop["name"].to_lower(), drop["collection"]])
	objects_updated()
	return {"coins": earned, "xp": gained, "drop": drop.get("type", ""),
		"drop_text": drop.get("text", ""), "name": name_before, "part": part, "extras": extras}


# ---------------------------------------------------------------- buildings


## Can this be bought straight into a home? Not if it's finished with materials on the farm (a frame or
## the Combine's chassis): that happens where it stands.
func can_buy_into_home(item_id: String) -> bool:
	var d := catalog.get_def(item_id)
	return d is PlaceableDef and not (d as PlaceableDef).built_in_place()


func building_accepts(building: Dictionary, item_id: String) -> bool:
	var b := catalog.get_def(building["id"])
	return b is BuildingDef and (b as BuildingDef).accepts(item_id, item_data(item_id).get("kind", ""))


## A bull or stallion: one lives inside, alongside the animals, without taking a space.
func is_one_each(building: Dictionary, item_id: String) -> bool:
	return (item_data(building["id"]).get("one_each", []) as Array).has(item_id)


func has_inside(building: Dictionary, item_id: String) -> bool:
	return int((building.get("inside", {}) as Dictionary).get(item_id, 0)) > 0


func capacity(building: Dictionary) -> int:
	return (catalog.get_def(building["id"]) as BuildingDef).capacity(level_of(building))


## Animals taking up spaces (a bull or stallion doesn't count).
func inside_total(building: Dictionary) -> int:
	var total := 0
	var inside: Dictionary = building.get("inside", {})
	for id in inside:
		if not is_one_each(building, id):
			total += int(inside[id])
	return total


# ---------------------------------------------------------------- placing new animals


## Puts a new animal on an open grass tile. False if the farm is full.
## A random free spot on grass where `item_id` fits, or (-1, -1).
func free_spot_for(item_id: String) -> Vector2i:
	var spots: Array[Vector2i] = []
	for r in farm_size:
		for c in farm_size:
			if plots[index_of(r, c)].get("state", "grass") == "grass" and can_place(item_id, r, c):
				spots.append(Vector2i(r, c))
	return spots[rng.randi_range(0, spots.size() - 1)] if not spots.is_empty() else Vector2i(-1, -1)


func place_somewhere(item_id: String) -> bool:
	if buildings.owned(item_id) >= buildings.limit_of(item_id):
		return false
	var spots: Array[Vector2i] = []
	for r in farm_size:
		for c in farm_size:
			var i := index_of(r, c)
			if plots[i].get("state", "grass") == "grass" and not is_occupied(i):
				spots.append(Vector2i(r, c))
	if spots.is_empty():
		return false
	var spot := spots[rng.randi_range(0, spots.size() - 1)]
	add_object({"uid": next_uid, "id": item_id, "row": spot.x, "col": spot.y, "t": now()})
	next_uid += 1
	return true


# ---------------------------------------------------------------- farmhands and arborists




func helpers_held(kind: String) -> int:
	return int(get(HELPERS[kind]["field"]))


## A helper does everything the action registry (data/actions.json) gives its kind: collects what is ready, then
## feeds what is hungry for the cycle ahead. One helper is used up whatever it did.
func use_helper(kind: String) -> int:
	var helper: Dictionary = HELPERS[kind]
	if helpers_held(kind) <= 0:
		message.emit(tr("NO_LEFT") % tr(helper["name"]))
		return 0
	var actions := Actions.for_helper(kind)
	var ready: Array = []
	if "collect" in actions:
		for o in objects:
			if kind_of(o) == kind and is_ready(o):
				ready.append(int(o["uid"]))
	var coins_total := 0
	for uid in ready:
		coins_total += int(collect(uid).get("coins", 0))
	var fed := feeds.feed_all(kind) if "feed" in actions else 0
	if ready.is_empty() and fed == 0:
		message.emit(tr("NOTHING_IS_READY_TO_COLLECT_YET"))
		return 0
	set(helper["field"], helpers_held(kind) - 1)
	if not ready.is_empty():
		message.emit(tr(helper["done"]) % [ready.size(), coins_total])
	if fed > 0:
		message.emit(tr("FED_ANIMALS") % fed)
	inventory_changed.emit()
	return ready.size() + fed


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
	return buildings.can_sell(obj).ok()


## Sells an object. Animals, trees or vehicles inside a building move back onto the farm first.
func sell_object(uid: int) -> bool:
	var o := object_by_uid(uid)
	if not can_sell(o):
		message.emit(tr("THAT_CAN_T_BE_SOLD"))
		return false
	var held: Array[String] = []
	for id in o.get("inside", {}):
		for k in int(o["inside"][id]):
			held.append(id)
	remove_object(o)
	if held.size() > 0:
		# Room check: the building's own tiles are free now that it's gone.
		var free := 0
		for r in farm_size:
			for c in farm_size:
				var i := index_of(r, c)
				if plots[i].get("state", "grass") == "grass" and not is_occupied(i):
					free += 1
		if free < held.size():
			add_object(o)
			message.emit(tr("NOT_ENOUGH_OPEN_GRASS_FOR_THE") % held.size())
			return false
		for id in held:
			place_somewhere(id)
	var value := sell_value(o)
	add_coins(value)
	ribbons.bump("items_sold", 1)
	var moved := (tr("MOVED_OUT_ONTO_THE_FARM") % held.size()) if held.size() > 0 else ""
	message.emit(tr("SOLD_THE_FOR_COINS") % [item_data(o["id"])["name"], value, moved])
	inventory_changed.emit()
	objects_updated()
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
		message.emit(tr("BUILDINGS_AND_BIG_PIECES_CAN_T"))
		return false
	o["flip"] = not o.get("flip", false)
	objects_updated()
	return true


# ---------------------------------------------------------------- object changes


func objects_updated() -> void:
	rebuild_occupancy()
	objects_changed.emit()
	plot_changed.emit(-1)
	queue_save()


# ---------------------------------------------------------------- weather


## The weather right now (see Weather.current): looks only, FarmVille had none. It changes by the second at
## most, so a frame asking again gets the same answer without the work.
func weather() -> Dictionary:
	var t := now()
	var forced := weather_override if weather_override != "" else ("clear" if t < clear_until else "")
	if t != _weather_at or forced != _weather_for:
		_weather_at = t
		_weather_for = forced
		_weather = Weather.current(
			t,
			DayCycle.SEASON,
			DayCycle.local_hour(t, DayCycle.device_bias_minutes()),
			forced
		)
	return _weather


# ---------------------------------------------------------------- unwither


func withered_count() -> int:
	var n := 0
	for r in farm_size:
		for c in farm_size:
			if field.phase(index_of(r, c)) == Phase.WITHERED:
				n += 1
	return n


## Brings every withered crop back to ripe. Uses an Unwither item, or gems if none are left.
func use_unwither() -> bool:
	var count := withered_count()
	if count == 0:
		message.emit(tr("NOTHING_HAS_WITHERED_SAVE_IT_FOR"))
		return false
	if unwithers > 0:
		unwithers -= 1
	elif not spend_gems(Balance.i("economy.unwither_gem_cost")):
		message.emit(tr("NO_UNWITHER_LEFT_AND_NOT_ENOUGH"))
		return false
	var t := now()
	for r in farm_size:
		for c in farm_size:
			var i := index_of(r, c)
			if field.phase(i) == Phase.WITHERED:
				plots[i]["planted_at"] = t - int(crops[plots[i]["crop"]]["grow_seconds"])
	message.emit(tr("UNWITHERED_PLOTS_THEY_RE_READY_TO") % count)
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
	if any_plot_in(Phase.GROWING) or any_plot_in(Phase.RIPE):
		return
	var gift := Balance.i("economy.rescue_coins") - coins
	add_coins(gift, false)
	message.emit(tr("YOU_FOUND_COINS_IN_THE_BARN") % gift)


func any_plot_in(wanted: Phase) -> bool:
	for i in plots.size():
		if field.phase(i) == wanted:
			return true
	return false


# ---------------------------------------------------------------- tutorial


func tutorial_text() -> String:
	return tr(TUTORIAL_TEXT[tutorial_step]) if TUTORIAL_TEXT.has(tutorial_step) else ""


## Moves to the next step only when the finished step is the current one.
func advance_tutorial(finished: Tutorial) -> void:
	if tutorial_step != finished:
		return
	tutorial_step += 1
	tutorial_changed.emit(tutorial_step)
	if tutorial_step == Tutorial.DONE:
		message.emit(tr("NICE_CROPS_GROW_IN_REAL_TIME"))
	queue_save()


# ---------------------------------------------------------------- mastery


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
		ribbons.bump("coins_earned", amount)
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
	var table := Balance.a("economy.level_xp")
	if lvl - 1 < table.size():
		return int(table[lvl - 1])
	return int(table[-1]) + (lvl - table.size()) * Balance.i("economy.xp_per_level_after_table")


func level() -> int:
	# Asked many times a frame (what is unlocked, what shows): worked out again only when the XP or the numbers change.
	if xp == _level_xp and Balance.revision == _level_rev:
		return _level
	var lvl := 1
	while xp >= xp_for_level(lvl + 1):
		lvl += 1
	_level = lvl
	_level_xp = xp
	_level_rev = Balance.revision
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
			names.append(crops[id]["name"] + tr("SEEDS"))
	for id in item_order:
		if int(items[id]["unlock_level"]) == lvl:
			names.append(items[id]["name"])
	return names


func _on_level_reached(lvl: int) -> void:
	# The reward is a gift, so it doesn't count toward the coins-earned ribbon.
	add_coins(level_reward(lvl), false)
	add_gems(Balance.i("economy.gems_per_level"))
	if lvl % 5 == 0:
		add_unwithers(1)
	leveled_up.emit(lvl) # the HUD shows the celebration popup


# ---------------------------------------------------------------- data


func read_json(path: String) -> Dictionary:
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
	if part_ids.is_empty():
		for d in catalog.of_kind("material"):
			part_ids.append(d.id)
			part_names[d.id] = d.name
			if (d as MaterialDef).is_basic():
				basic_parts.append(d.id)


func _load_crops() -> void:
	_load_catalog()
	for d in catalog.of_kind("crop"):
		crops[d.id] = d.data
		crop_order.append(d.id)


func _load_items() -> void:
	_load_catalog()
	for id in catalog.order:
		var d := catalog.get_def(id)
		if d.kind == "crop" or d.kind == "material" or d.kind == "recipe":
			continue
		items[id] = d.data
		item_order.append(id)


func _new_game() -> void:
	coins = Balance.i("economy.start_coins")
	gems = Balance.i("economy.start_gems")
	xp = 0
	debug_time_offset = 0
	clear_until = now() + Balance.i("economy.fresh_farm_clear_seconds")
	tutorial_step = Tutorial.HARVEST
	objects = []
	next_uid = 1
	_occupied.clear()
	layout_revision += 1
	plots.clear()
	farm_size = START_SIZE
	unwithers = Balance.i("economy.start_unwithers")
	fertilize_alls = 0
	absence_note = ""
	for system in systems:
		system.reset()
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
	for p in part_ids:
		parts[p] = 0
	farmhands = 0
	arborists = 0
	gardeners = 0
	fertilizer_bags = 0
	rebuild_occupancy()
	save_game()


func _add_starter_object(item_id: String, row: int, col: int, extra := {}) -> void:
	var obj := {"uid": next_uid, "id": item_id, "row": row, "col": col, "t": now()}
	obj.merge(extra)
	add_object(obj)
	next_uid += 1


func _set_starter(row: int, col: int, crop_id: String, planted_at: int) -> void:
	plots[index_of(row, col)] = {"state": "planted", "crop": crop_id, "planted_at": planted_at}


# ---------------------------------------------------------------- save/load


## A change to save soon (see Persistence).
func queue_save() -> void:
	persistence.queue()


## Writes the farm; `in_background` copies it and writes on a thread (see Persistence).
func save_game(in_background := false) -> void:
	persistence.save(in_background)


## Waits for a background save still being written.
func finish_saving() -> void:
	persistence.finish()


## Puts the last save back; false if there is none to use.
func load_game() -> bool:
	return persistence.load_save()


## Debug builds: the farm with everything on it, for testing (ShowcaseFarm), built fresh in its own save.
## The player's own farm is saved first and never touched; open_own_farm brings it back. Returns what
## didn't fit (nothing, normally).
func open_showcase() -> Array[String]:
	LoadTrace.begin("showcase", get_tree())
	save_game()
	LoadTrace.mark("own farm saved")  # not-ui
	save_path = ShowcaseFarm.SAVE_PATH
	var left_out := ShowcaseFarm.build(self)
	LoadTrace.mark("showcase laid out: %d objects" % objects.size())  # not-ui
	save_game()
	LoadTrace.mark("showcase saved")  # not-ui
	message.emit(tr("SHOWCASE_OPENED"))
	return left_out


## Back from the showcase to the player's own farm, as it was left.
func open_own_farm() -> void:
	LoadTrace.begin("own farm", get_tree())  # not-ui
	save_game()
	save_path = SAVE_PATH
	if not saving_enabled or not load_game():
		_new_game()
	rebuild_occupancy()
	ShowcaseFarm.announce(self)


func in_showcase() -> bool:
	return save_path == ShowcaseFarm.SAVE_PATH


## Lays every object back on the farm; one that no longer fits where it stood (its footprint changed, or the
## farm's rules did) moves to the nearest free spot. Returns how many moved. Leaves the occupancy rebuilt.
func settle_objects() -> int:
	_occupied.clear()
	layout_revision += 1
	var misfits: Array = []
	for o in objects:
		if can_place(o["id"], int(o["row"]), int(o["col"]), -1, false):
			_occupy(o)
		else:
			misfits.append(o)
	var moved := 0
	for o in misfits:
		var spot := nearest_free_spot(o["id"], int(o["row"]), int(o["col"]))
		if spot.x >= 0:
			o["row"] = spot.x
			o["col"] = spot.y
			moved += 1
		_occupy(o) # nowhere free at all: it stays put, overlapping, until the player moves something
	return moved


## The free spot for an item closest to (row, col), or (-1, -1) if there's none.
func nearest_free_spot(item_id: String, row: int, col: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := -1
	for r in farm_size:
		for c in farm_size:
			var dist := (r - row) * (r - row) + (c - col) * (c - col)
			if (best_d < 0 or dist < best_d) and can_place(item_id, r, c):
				best = Vector2i(r, c)
				best_d = dist
	return best


func _occupy(o: Dictionary) -> void:
	layout_revision += 1
	var fp := footprint(o["id"])
	for r in range(int(o["row"]), int(o["row"]) + fp.y):
		for c in range(int(o["col"]), int(o["col"]) + fp.x):
			_occupied[index_of(r, c)] = int(o["uid"])


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


func plot_updated(i: int) -> void:
	plot_changed.emit(i)
	queue_save()
