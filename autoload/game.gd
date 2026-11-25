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
signal away_recap(rows: Array, notes: Array)   # what happened while away, as rows that go to their things
signal tutorial_changed(step: int)
signal collections_changed
signal ribbons_changed
signal did(verb: String, subject: String, n: int)   # one thing done on the farm (record): goals listen
signal objects_changed
signal farm_opened   # another farm was laid out in place of this one (the showcase, or back to your own)
## One thing changed where it stands (fed, collected, upgraded, filled): only it needs looking at again, not the
## whole farm (scaling report: a change costs one object, not all of them). A move, a turn, a purchase or a sale is
## still `objects_changed`.
signal object_changed(uid: int)
# A find, said where it was made in its rarity's colours ("common", "uncommon", "rare", "legendary"): on a plot
# (fuel, a collectible, a gopher, a golden harvest...) or on a thing (a bird at a tree, a calf born, a stray).
signal found(index: int, text: String, rarity: String)
signal found_on(uid: int, text: String, rarity: String)
signal building_upgraded(uid: int, level: int)
signal vip_level_reached(level: int)   # a new VIP level (VipSystem): the Barn has a new look
signal farm_expanded(size: int)
signal inventory_changed
signal goals_changed             # a goal opened, moved on or was collected (GoalSystem)
signal inbox_changed             # the neighbours' mail changed (arrived, claimed, answered)

enum Phase { GRASS, PLOWED, GROWING, RIPE, WITHERED }
enum Tutorial { HARVEST, PLOW, PLANT, DONE }

const DAY_MARKER_SHIFT := 2 * 86400   # a clock step back from which day markers move with it (day_moved_back)
const WET: Array[String] = ["rain", "storm"]               # the weather that waters the fields
const FALLING: Array[String] = ["rain", "storm", "snow"]   # the weather the forecast speaks of
const STATES_KEPT := 512     # weather blocks kept (two months of them) before the keeping starts again
const RAIN_LOOK_MOST := 64   # weather blocks one look for rain covers at most (8 days of growing)
# More tiles changed at once than this, and the whole field is laid again instead of each plot.
const WHOLE_FIELD_TILES := 96
const CLOSE_FRAMES := 2      # frames for a hidden window to leave the screen before the game quits
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
const SHOWCASE_SAVE_PATH := "user://showcase.json"   # the showcase farm's own save (ShowcaseFarm)
## The debug tools, loaded by path when used, so the start never compiles them (docs/PERF_RUN.md, the start).
const SHOWCASE_SCRIPT := "res://scripts/debug/showcase_farm.gd"
const LOAD_TRACE_SCRIPT := "res://scripts/debug/load_trace.gd"
const SAVE_DELAY_MSEC := 1500    # changes are written together, at most this often (a save is the whole farm)
const BACKUP_SUFFIX := ".bak"     # the save before the last one: used if the newest is unreadable
const TEMP_SUFFIX := ".tmp"
## Kinds that never have anything to collect (is_ready; the 3D ready sign skips them without asking).
const NEVER_READY: Array[String] = ["decor", "barn", "vehicle"]
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
var rescued := false   # a rescue was given and no harvest since: the next waits for one (no free-coins loop)
var keep_clock := false   # a new game keeps debug_time_offset (the play bot starts every farm on one date)
var born_day := -1     # the day this farm began (a young farm's daily help counts from it)
var helped_day := -1   # the last day a young farm was helped to plant (once a day)
var fertilize_alls := 0            # fertilize every growing crop at once
var absence_items: Array[Dictionary] = []   # the same as rows, [{kind, count}] (AbsenceReport.items): the away card's
var absence_head := ""             # the line of absence_note those rows already say
var absence_note := ""             # what happened while the player was away, shown on start
var parts := {}                    # building material -> count (see part_ids)
var farmhands := 0                 # collect every animal at once
var arborists := 0                 # collect every tree at once
var gardeners := 0                 # collect every bloom at once
var fertilizer_bags := 0           # free fertilizer, used before coins
var clear_until := 0               # unix time until which the weather is clear (a new farm)
var weather_override := ""         # force a weather state (screenshots, testing); "" = the real weather
var debug_time_offset := 0         # seconds; only changed by the debug skip button
var skipped := 0                   # seconds of the offset from Skip 1 hour: timers move, the sky doesn't
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
var limited: LimitedSystem
var mystery: MysterySystem
var daily: DailySystem
var storage: BarnStorage
var bees: BeehiveSystem
var links: LinksSystem
var mastery: MasterySystem
var nurture: NurtureSystem
var raising: RaisingSystem
var social: SocialSystem
var finds: FindsSystem
var feeds: FeedSystem
var adjacency: AdjacencySystem
var boosts: HomeBoostSystem
var player: PlayerSystem
var pigpen: PigPenSystem
var vehicles: VehicleSystem
var vip: VipSystem
var rolls: RollSystem
var rust: RustSystem
var wear: WearSystem                # building wear (docs/WEAR.md)
var field: FieldSystem
var strays: StraySystem
var crafting: CraftingSystem
var homes: HousingSystem
var buildings: BuildingSystem
var collecting: CollectSystem   # collecting what is ready (Game.collect)
var shop: ShopSystem               # buying and selling what stands on the farm
var helpers: HelperSystem          # using a farmhand, arborist or gardener
var goals: GoalSystem              # story chains, today's jobs, farm projects (data/goals.json)
var persistence: Persistence          # saving and loading (not in `systems`: it has no state of its own)

var systems: Array[GameSystem] = []   # all of the above, for load_data/reset/save_to/load_from


var objects_revision := 0          # goes up whenever anything on the farm may have changed (derived totals key on it)
var tiles_revision := 0            # goes up only when which tile holds what has really changed (unlike the next)
## While objects_changed is being told: the things that came, went or moved in this change, when the change knows
## them (`objects_updated(uid)`: that one thing, and whatever joined or left with it); empty: anything may have
## changed, and a listener looks at everything. Placing one thing then costs one thing, not the whole farm.
var changed_uids: Array[int] = []
var layout_revision := 0           # goes up whenever which tiles are covered may have changed (walking grid, etc.)
var _closing := false   # a computer's close button was pressed: going (_close)
var _touched := {}                 # uid -> true: joined, left or moved since the farm was last told
var _touched_all := false          # the whole list was replaced (set_objects): nothing narrower is known
var _level := 1                    # level() remembered for this XP (and this version of the Balance numbers)
var _level_xp := -1
var _level_rev := -1
var _tiles_changed := {}           # tiles whose occupant changed since the farm was last told (objects_updated)
var _occupied := {}                # tile index -> uid of the object covering it
var _uid_index := {}               # uid -> its position in objects (see object_by_uid)

var _weather := {}                # the last answer of weather(), and when and for what it was made
var _states := {}                 # weather block index -> its state (weather_state_at), and what they were made for
var _states_for := "?"
var _forecast := {}               # the last answer of forecast(), and the weather block it was made in
var _forecast_block := -1
var _weather_at := -1
var _weather_for := "?"
var _holding := 0          # hold_updates depth
var _held_update := false  # an objects_updated came while held
var _held_uids := {}       # ..or only these things changed in place while held
var _load_trace: Script = null   # LoadTrace, once a trace was begun (trace_begin)
var _said_packs: Array[String] = []   # what the player has been told of packs (each once a session)


func _init() -> void:
	StartMarks.mark("scripts")   # not-ui (every script compiled: the start's first measure)
	drops = HarvestDrops.new(self)
	collectibles = CollectiblesSystem.new(self)
	shed = GardenShedSystem.new(self)
	ribbons = RibbonsSystem.new(self)
	land = LandSystem.new(self)
	specials = BuildingSpecials.new(self)
	limited = LimitedSystem.new(self)
	mystery = MysterySystem.new(self)
	daily = DailySystem.new(self)
	storage = BarnStorage.new(self)
	bees = BeehiveSystem.new(self)
	links = LinksSystem.new(self)
	mastery = MasterySystem.new(self)
	pigpen = PigPenSystem.new(self)
	vehicles = VehicleSystem.new(self)
	vip = VipSystem.new(self)
	rolls = RollSystem.new(self)
	rust = RustSystem.new(self)
	wear = WearSystem.new(self)
	field = FieldSystem.new(self)
	player = PlayerSystem.new(self)
	nurture = NurtureSystem.new(self)
	raising = RaisingSystem.new(self)
	social = SocialSystem.new(self)
	finds = FindsSystem.new(self)
	feeds = FeedSystem.new(self)
	adjacency = AdjacencySystem.new(self)
	boosts = HomeBoostSystem.new(self)
	strays = StraySystem.new(self)
	crafting = CraftingSystem.new(self)
	homes = HousingSystem.new(self)
	buildings = BuildingSystem.new(self)
	collecting = CollectSystem.new(self)
	shop = ShopSystem.new(self)
	helpers = HelperSystem.new(self)
	goals = GoalSystem.new(self)
	persistence = Persistence.new(self)
	systems = [field, drops, collectibles, shed, ribbons, land, specials, mystery, daily, storage, bees, links, pigpen,
		vehicles, strays, crafting, homes, buildings, mastery, player, nurture, raising, finds, feeds, adjacency, boosts,
		social, collecting, shop, helpers, vip, rust, wear, rolls, goals, limited]
	StartMarks.mark("made")   # not-ui (the systems made)


func _ready() -> void:
	StartMarks.mark("ready")   # not-ui (the other autoloads made: Sound, Feedback)
	rng.randomize()
	if not OS.has_feature("mobile"):
		get_tree().set_auto_accept_quit(false)   # (closing is ours: _close, so the window goes before the teardown)
	_load_crops()
	_load_items()
	StartMarks.mark("catalog")   # not-ui (crops and items read)
	for system in systems:
		system.load_data()
	StartMarks.mark("data")   # not-ui (every system's data read)
	if AssetPacks.shared == null and self == get_node_or_null(^"/root/Game"):   # not-ui (the game's own, not a test's)
		# Files left out of the app (docs/PACKS.md): the kept ones are loaded now, the rest fetched when first drawn.
		var packs := AssetPacks.begin(self)
		packs.waiting.connect(_packs_said.bind("PACK_WAITING"))
		packs.no_room.connect(_packs_said.bind("PACK_NO_ROOM"))
		packs.update_needed.connect(_packs_said.bind("PACK_UPDATE"))
	if not saving_enabled or not load_game():
		_new_game()
	if OS.is_debug_build() and OS.get_cmdline_user_args().has(SHOWCASE_ARG):
		open_showcase.call_deferred()  # straight into the farm with everything on it, for testing
	# Deferred so the HUD is connected and can show the message.
	check_rescue.call_deferred()
	strays.check_strays.call_deferred()
	daily.check_daily_gift.call_deferred()
	wear.spoil.call_deferred()
	_show_absence.call_deferred()
	var stray_timer := Timer.new()
	stray_timer.wait_time = 30.0
	stray_timer.autostart = true
	stray_timer.timeout.connect(strays.check_strays)
	stray_timer.timeout.connect(daily.check_daily_gift)
	stray_timer.timeout.connect(rust.finish_repairs)   # (a mended vehicle comes back: RustSystem)
	stray_timer.timeout.connect(wear.finish_repairs)   # (..and a repaired building is like new: WearSystem)
	add_child(stray_timer)
	StartMarks.mark("game")   # not-ui (data and the save loaded)


## What happened while the player was away, said once as the farm opens: as a card of rows that each go to their
## thing when something shows cards (the HUD: `away_recap`), and as one line otherwise.
func _show_absence() -> void:
	var rows := absence_items.duplicate()
	if not rows.is_empty() and objects.any(func(o: Dictionary) -> bool: return o.get("stray", false)):
		rows.append({"kind": "stray", "count": 1})
	if not rows.is_empty() and not away_recap.get_connections().is_empty():
		var notes: Array[String] = []
		for text: String in absence_note.split("\n", false):
			if text != absence_head:
				notes.append(text)
		away_recap.emit(rows, notes)
	elif absence_note != "":
		message.emit(absence_note)
	absence_note = ""
	absence_head = ""
	absence_items = []


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		PhoneNotices.schedule(self)   # (the phone tells the player while the game is closed)
	if what == NOTIFICATION_APPLICATION_RESUMED:
		PhoneNotices.cancel_all()
		wear.spoil()   # (worn storage spoiled a little while the game was away)
		check_rescue()   # (back to a farm that can't plant: helped now, not only at a cold start or a harvest)
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not OS.has_feature("mobile"):
		_close()


## A computer's close button: saved (above), the window is hidden and given frames to really go, and only then
## does the game quit, so the engine taking the 3D world down happens out of sight, never as a frozen window.
func _close() -> void:
	if _closing:
		return
	_closing = true
	get_window().hide()
	Sound.silence()   # let go while frames remain for the audio thread to drop what played
	for k in CLOSE_FRAMES:
		await get_tree().process_frame
	get_tree().quit()


func _exit_tree() -> void:
	Instancer.clear()   # the shared looks live in statics: let them go before the engine reports leaks
	if self != Game:   # (a test's own GameState leaving: the shared caches stay for the next test)
		return
	ItemIcons.release_statics()
	UiSvg.release_statics()
	UiKit.release_statics()
	CardFace.release_statics()
	BuildingFill.release_statics()
	LinkModels.release_statics()
	# (the art builders' own caches, cleared from here so their files, fingerprinted for the exported art, stay as
	# they are: a change to them means re-exporting every plant and building)
	for cache: Variant in [ModelKit._materials, ModelKit._meshes, ModelKit._white, ModelKit.paint_like,
			CropModels._cache, CropModels._files, DecorMotion._materials]:
		cache.clear()
	ModelKit._facet_mesh = null
	ModelKit._facet_low = null
	ModelKit._sprig = null
	PondModel.release_statics()
	WorldFx.release_statics()


# ---------------------------------------------------------------- time


## The farmer works through their queue as time passes (PlayerSystem).
func _process(delta: float) -> void:
	player.advance(delta)
	vehicles.advance(delta)
	persistence.tick()


func now() -> int:
	return int(Time.get_unix_time_from_system()) + debug_time_offset


## The time the farm LOOKS like (its sky, light, clock, the animals' day): now() less what Skip 1 hour added, so a
## test skip hurries every timer but never moves the day away from the player's real time (owner, 19 Nov).
func look_now() -> int:
	return now() - skipped


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
	skipped += seconds
	strays.check_strays()
	daily.check_daily_gift()
	wear.spoil()
	plot_changed.emit(-1)
	_tiles_changed.clear()   # (the whole field has just been told)
	check_rescue()
	queue_save()


## The player's calendar day (their local midnight, not UTC's): the daily gift, fuel find and crafting daily turn there.
func day_number() -> int:
	return floori((now() + DayCycle.device_bias_minutes() * 60) / 86400.0)


## Has a new day come since `day`? Only forward: a clock set back to yesterday is still today for every daily
## limit and daily pick (else setting it back and forward again gives each day's helps, gifts, jobs anew).
func day_turned(day: int) -> bool:
	return day_number() > day


## A day marker (day_turned's `day`) once the clock was set back `seconds`: a clock that ran days ahead and is put
## right (DAY_MARKER_SHIFT or more) takes its days back with it, so today's limits come round today, not when the
## clock catches up; a smaller step leaves the marker, so no day comes round twice.
func day_moved_back(day: int, seconds: int) -> int:
	return day - floori(seconds / 86400.0) if day > 0 and seconds >= DAY_MARKER_SHIFT else day


# ---------------------------------------------------------------- plots


func index_of(row: int, col: int) -> int:
	return row * MAX_SIZE + col


## The row of plot index `i` (the other half of `index_of`).
static func row_of(i: int) -> int:
	return int(i / float(MAX_SIZE))


## The column of plot index `i`.
static func col_of(i: int) -> int:
	return i % MAX_SIZE


## Whether plot index `i` lies on the farm as it is now (a plot past the edge keeps its data in `plots`, so a
## smaller farm, after a reset or load, must not draw or work it).
func on_farm(i: int) -> bool:
	return i >= 0 and in_farm(row_of(i), col_of(i))


func in_farm(row: int, col: int) -> bool:
	return row >= 0 and col >= 0 and row < farm_size and col < farm_size


# ---------------------------------------------------------------- placed objects
# Trees, animals and buildings sit on grass tiles. Each object is a dictionary:
# {"uid", "id", "row", "col", "t"} where t is when its current cycle started.
# Buildings also have "level" and "inside" (item id -> count).


func item_data(item_id: String) -> Dictionary:
	return items.get(item_id, {})


## The name of anything in the catalog (an item, a crop, a building part...), or "" for an unknown id.
func name_of(id: String) -> String:
	var d := catalog.get_def(id)
	return d.name if d != null else ""


func footprint(item_id: String) -> Vector2i:
	var d := catalog.get_def(item_id)
	return (d as PlaceableDef).footprint() if d is PlaceableDef else Vector2i.ONE


func object_at(i: int) -> Dictionary:
	return object_by_uid(int(_occupied.get(i, -1)))


## The uid of what covers tile `i`, or -1.
func holder_at(i: int) -> int:
	return int(_occupied.get(i, -1))




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
	objects_revision += 1
	_touched[int(o.get("uid", -1))] = true
	if o.has("row") and o.has("col"):
		_occupy(o)
		tiles_revision += 1
		var fp := footprint(o["id"])
		for r in range(int(o["row"]), int(o["row"]) + fp.y):
			for c in range(int(o["col"]), int(o["col"]) + fp.x):
				_tiles_changed[index_of(r, c)] = true


func remove_object(o: Dictionary) -> void:
	_touched[int(o.get("uid", -1))] = true
	objects.erase(o)
	objects_revision += 1
	rebuild_occupancy()


## Replaces the whole list (a sweep that drops several at once).
func set_objects(list: Array) -> void:
	_touched_all = true
	objects = list
	objects_revision += 1
	rebuild_occupancy()


## Whether the tiles already say where `uid` and everything touched with it stand (a thing placed or sold keeps
## them true itself); not for a thing moved, whose new tiles do not name it yet.
func _occupancy_holds(uid: int) -> bool:
	var uids := _touched.keys()
	uids.append(uid)
	for u: int in uids:
		var o := object_by_uid(u)
		if o.is_empty() or not (o.has("row") and o.has("col")):
			continue
		var fp := footprint(o["id"])
		for r in range(int(o["row"]), int(o["row"]) + fp.y):
			for c in range(int(o["col"]), int(o["col"]) + fp.x):
				if int(_occupied.get(index_of(r, c), -1)) != u:
					return false
	return true


func is_occupied(i: int) -> bool:
	return _occupied.has(i)


func rebuild_occupancy() -> void:
	var before := _occupied
	_occupied = {}
	layout_revision += 1
	for o in objects:
		_occupy(o)
	# Which tiles hold something else now than they did (for most changes: none) is kept until the farm is told
	# (objects_updated), so only those plots are laid again and nothing that follows the ground looks again.
	var moved := false
	for i: int in _occupied:
		if int(before.get(i, -1)) != int(_occupied[i]):
			_tiles_changed[i] = true
			moved = true
	for i: int in before:
		if not _occupied.has(i):
			_tiles_changed[i] = true
			moved = true
	if moved:
		tiles_revision += 1


## Whether `item_id` can stand at row, col (the rule and its reasons: BuildingSystem.can_place).
func can_place(item_id: String, row: int, col: int, ignore_uid := -1, strict := true) -> bool:
	return buildings.place_why(item_id, row, col, ignore_uid, strict) == BuildingSystem.Why.OK


func grass_over(item_id: String, row: int, col: int) -> void:
	var fp := footprint(item_id)
	for r in range(row, row + fp.y):
		for c in range(col, col + fp.x):
			plots[index_of(r, c)] = {"state": "grass"}


## A pack could not be fetched (AssetPacks: no network, no room, or the app needs an update): each said once a
## session; the animal keeps its stand-in till it comes.
func _packs_said(key: String) -> void:
	if not _said_packs.has(key):
		_said_packs.append(key)
		message.emit(tr(key))


func can_afford_item(item_id: String) -> bool:
	return buildings.can_buy(item_id).ok()


## Buys one of an item, wherever it's going (onto the farm or straight into a home): checks its level,
## takes its price (coins, gems, or a crafting building's rising price), and applies what buying it does
## (its XP, the decorating ribbon, a first vehicle filling the fuel tank). False, with a message, if it
## can't be bought.
func buy_item(item_id: String) -> bool:
	return shop.buy_item(item_id)


func buy_and_place(item_id: String, row: int, col: int) -> bool:
	var pt := PerfReadout.start()
	var done := shop.buy_and_place(item_id, row, col)
	PerfReadout.stop("buy_and_place", pt)
	return done


func move_object(uid: int, row: int, col: int) -> bool:
	var obj := object_by_uid(uid)
	if obj.is_empty() or not can_place(obj["id"], row, col, uid):
		return false
	obj["row"] = row
	obj["col"] = col
	grass_over(obj["id"], row, col)
	objects_updated(uid)   # (only it moved: only it, and what stood or stands beside it, is looked at again)
	return true


## A building's own cycle (the Stable's 1 day beats a loose horse's 3) or the item's.
func cycle_of(obj: Dictionary) -> int:
	var cycle := int(item_data(obj["id"]).get("cycle_seconds", 86400))
	var cut := feeds.speed_cut(obj)   # a speed feed shortens the cycle it was given for
	return maxi(1, roundi(cycle * (1.0 - cut))) if cut > 0.0 else cycle


func level_of(obj: Dictionary) -> int:
	return int(obj.get("level", 1))


## The look a building wears now (BuildingDef.look_level: its size, or for the Barn the VIP level), and how
## many looks it has.
func look_level(obj: Dictionary) -> int:
	var d := catalog.get_def(str(obj["id"]))
	return (d as BuildingDef).look_level(obj, self) if d is BuildingDef else level_of(obj)


func look_levels(building_id: String) -> int:
	var d := catalog.get_def(building_id)
	return (d as BuildingDef).look_levels() if d is BuildingDef else 1


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
## A building's special role from the catalog ("" for none): "beehive", "garage", "nursery", "truffles",
## "finds_home"... Code asks for the role, never for a building by its id, so a second building with the
## same role behaves the same with no code changed.
func special_of(obj: Dictionary) -> String:
	return "" if obj.is_empty() else str(item_data(str(obj.get("id", ""))).get("special", ""))


func is_home(obj: Dictionary) -> bool:
	return item_data(obj["id"]).get("kind", "") == "building"


## Which of the four types of building `building_id` is: "decor", "crafting", "harvesting" (animals, bees, trees
## or blooms live in it and it is collected from) or "storing"; "" for anything else. Each type has its rules
## for levels and looks (CLAUDE.md).
func building_type(building_id: String) -> String:
	var d := catalog.get_def(building_id)
	return (d as BuildingDef).type() if d is BuildingDef else ""


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


## How rare a thing is to come by, for the colours of its reveal when a mystery young one grows into it: a tree's
## rare variety and a lost animal (never sold, only found) are rare, something only gems buy is uncommon.
func rarity_of_item(item_id: String) -> String:
	var it := item_data(item_id)
	if it.get("lost", false) or it.get("stray_only", false):
		return "rare"
	for k: String in item_order:
		if str(items[k].get("rare_sapling", "")) == item_id:
			return "rare"
	return "uncommon" if it.has("gem_cost") else "common"


## Whether a thing has something to take now, so wears a ready sign: its produce (`is_ready`), or a crafting
## building's finished crafts. The one place that says so (the signs, the Next ready button, the away card).
func has_ready(obj: Dictionary) -> bool:
	return is_ready(obj) or (crafting.is_crafting(obj) and crafting.crafts_done(obj) > 0)


func is_ready(obj: Dictionary) -> bool:
	if obj.get("stray", false):
		return false
	var it := item_data(obj["id"])   # one lookup: this runs for every object, every frame
	var kind: String = it.get("kind", "")
	if NEVER_READY.has(kind):
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
	return collecting.collect(uid)


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


## A random free spot on grass where `item_id` fits, or (-1, -1). `strict` as can_place: a tree keeps off a
## building's ring and a building off a tree's.
func free_spot_for(item_id: String, strict := true) -> Vector2i:
	var spots: Array[Vector2i] = []
	for r in farm_size:
		for c in farm_size:
			if plots[index_of(r, c)].get("state", "grass") == "grass" and can_place(item_id, r, c, -1, strict):
				spots.append(Vector2i(r, c))
	return spots[rng.randi_range(0, spots.size() - 1)] if not spots.is_empty() else Vector2i(-1, -1)


## Puts a new thing on a random open grass tile where placing it by hand would be allowed (BuildingSystem's
## rule); a tree from a sold Orchard with only crowded spots left still lands, beside a building, rather than
## being lost. False if the farm is full.
func place_somewhere(item_id: String) -> bool:
	if buildings.owned(item_id) >= buildings.limit_of(item_id):
		return false
	var spot := free_spot_for(item_id)
	if spot.x < 0:
		spot = free_spot_for(item_id, false)
	if spot.x < 0:
		return false
	add_object({"uid": next_uid, "id": item_id, "row": spot.x, "col": spot.y, "t": now()})
	next_uid += 1
	return true


# ---------------------------------------------------------------- farmhands and arborists




func helpers_held(kind: String) -> int:
	return int(get(HELPERS[kind]["field"]))


## A helper does everything the action registry (data/actions.json) gives its kind: collects what is ready, then
## feeds what is hungry for the cycle ahead. One helper is used up whatever it did.
func use_helper(kind: String) -> int:
	return helpers.use_helper(kind)


# ---------------------------------------------------------------- buying XP, selling and turning


## FarmVille gave XP for what you bought: 1 per 100 coins, and at least 5 for a decoration.
func buy_xp(item_id: String) -> int:
	var d := catalog.get_def(item_id)
	return d.buy_xp() if d else 0


## What selling an object returns: 5% of its price, as in FarmVille.
func sell_value(obj: Dictionary) -> int:
	return shop.sell_value(obj)


func can_sell(obj: Dictionary) -> bool:
	return buildings.can_sell(obj).ok()


## Sells an object. Animals, trees or vehicles inside a building move back onto the farm first.
func sell_object(uid: int) -> bool:
	return shop.sell_object(uid)


## Turns an object to face the other way. Only square ones turn, so nothing changes size.
func can_rotate(obj: Dictionary) -> bool:
	if obj.is_empty():
		return false
	var d := catalog.get_def(obj["id"])
	return d is PlaceableDef and (d as PlaceableDef).can_rotate()


func rotate_object(uid: int) -> bool:
	var o := object_by_uid(uid)
	var verdict := buildings.can_rotate(o)
	if not verdict.ok():
		message.emit(verdict.text)
		return false
	o["flip"] = not o.get("flip", false)
	objects_updated(uid)
	return true


# ---------------------------------------------------------------- object changes


## Holds the farm's "objects changed" news while many changes are made at once (Accept all bringing ten young
## animals): the farm, the ground and an open panel rebuild once at `release_updates`, not once per change.
func hold_updates() -> void:
	_holding += 1


func release_updates() -> void:
	_holding = maxi(_holding - 1, 0)
	if _holding > 0:
		return
	if _held_update:
		_held_update = false
		_held_uids.clear()
		objects_updated()
	elif not _held_uids.is_empty():
		var uids := _held_uids.keys()
		_held_uids.clear()
		for uid: int in uids:
			object_changed.emit(uid)
		queue_save()


## Tells the farm its things changed. Given `uid` (the one thing a rule just changed), and that thing still standing
## on the tiles it held, only it is looked at again (`object_changed`); otherwise (moved, turned, gone, or not
## said) the whole farm is (`objects_changed`).
func objects_updated(uid := -1) -> void:
	objects_revision += 1
	if uid >= 0 and _in_place(uid):
		if _holding > 0:
			_held_uids[uid] = true
		else:
			object_changed.emit(uid)
			queue_save()
		return
	if uid < 0 or _touched_all or not _occupancy_holds(uid):
		rebuild_occupancy()   # (a placing or a sale already keeps the tiles true: add_object, remove_object)
	if _holding > 0:
		_held_update = true   # (told once, when the batch ends: release_updates)
		return
	changed_uids.clear()
	if uid >= 0 and not _touched_all:   # (`uid` vouches that nothing else changed in place: only what came or went)
		_touched[uid] = true
		for k: int in _touched:
			changed_uids.append(k)
	_touched.clear()
	_touched_all = false
	var pt := PerfReadout.start()
	objects_changed.emit()
	PerfReadout.stop("objects_changed_told", pt)
	changed_uids.clear()
	# Only the plots whose tile holds something else now are laid again: none, for a turn, a feed or an upgrade
	# (the whole field was laid again after every change, though nothing on it had moved).
	var tiles: Array = _tiles_changed.keys()
	_tiles_changed.clear()
	if tiles.size() > WHOLE_FIELD_TILES:
		plot_changed.emit(-1)
	else:
		for i: int in tiles:
			plot_changed.emit(i)
	queue_save()


## The farmhouse's stage, 1 up: it gains a part at each of Balance `feel.farmhouse_levels` the farmer reaches
## (dormers, a wing, a balcony and flag), so the farm's years show on the house and not only in a number.
func farmhouse_stage() -> int:
	var stage := 1
	for need: float in Balance.a("feel.farmhouse_levels"):
		if level() >= int(need):
			stage += 1
	return stage


# ---------------------------------------------------------------- seasons and weather


## The season now, where the player lives (Season: the real calendar by region; summer when seasons are off).
func season() -> String:
	return Season.at(now(), DayCycle.device_bias_minutes())


## Whether a crop planted now would be off-season (it sells for more and withers sooner). Never on a young farm
## (Balance `seasons.from_level`): plain farming is learnt first.
func off_season(crop_id: String) -> bool:
	return level() >= Balance.i("seasons.from_level") and Season.is_off(crop_id, season())


## The weather's state ("rain", "clear"...) in the block holding a time, by the season of that day.
func weather_state_at(unix_time: int) -> String:
	# Kept by block (a harvest asks about every block its crop grew through, a field of them the same ones over
	# and over: 0.6 ms a harvest for a four-day crop before). Made again when the region or the switch changes.
	var made_for := Season.region() if Season.enabled() else ""
	if made_for != _states_for or _states.size() > STATES_KEPT:
		_states_for = made_for
		_states.clear()
	var index := int(floor(unix_time / float(Weather.block())))
	var state: Variant = _states.get(index)
	if state == null:
		var bias := DayCycle.device_bias_minutes()
		state = Weather.state_at(unix_time, Season.odds_key(Season.at(unix_time, bias)),
			DayCycle.local_hour(unix_time, bias))
		_states[index] = state
	return str(state)


## Whether it rained at any time between two moments (a crop's growing): the weather is a pure function of the
## date, so this is known for any stretch, past or to come. Not during a fresh farm's clear spell, and never when
## seasons are off.
func rained_between(from_t: int, to_t: int) -> bool:
	if not Season.enabled():
		return false
	var length := Weather.block()
	var t := maxi(from_t, clear_until)
	t -= posmod(t, length)
	var looked := 0
	while t < to_t and looked < RAIN_LOOK_MOST:
		# (the first block is asked the full way, which also checks the kept blocks are for this region; the rest
		# are read straight from what is kept when it is there)
		var kept: Variant = _states.get(int(t / float(length))) if looked > 0 else null
		if WET.has(str(kept) if kept != null else weather_state_at(t)):
			return true
		t += length
		looked += 1
	return false


## What the sky will do next, for the forecast under the clock: {name, at, starts}: rain (or snow) `starts` at `at`
## (unix seconds), or the rain falling now ends then. {} when nothing changes within a day (Balance
## `seasons.forecast_blocks`). Worked out once per weather block.
func forecast() -> Dictionary:
	var length := Weather.block()
	var t := now()
	var index := int(floor(t / float(length)))
	if index == _forecast_block:
		return _forecast
	_forecast_block = index
	_forecast = {}
	var wet_now := FALLING.has(weather_state_at(t))
	var falling := weather_state_at(t)
	for k in range(1, Balance.i("seasons.forecast_blocks") + 1):
		var at := (index + k) * length
		var state := weather_state_at(at)
		if FALLING.has(state) != wet_now:
			_forecast = {"name": Weather.NAMES[state if not wet_now else falling], "at": at, "starts": not wet_now}
			break
	return _forecast




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
			Season.odds_key(season()),
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
	_tiles_changed.clear()   # (the whole field has just been told)
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


## Quiet backstop: a player who can't plant (seeds, and the plow too when no plot is plowed) and has nothing
## growing or ripe gets enough coins to plant again, so the farm can never get stuck.
func check_rescue() -> void:
	_help_young_farm()
	if coins >= coins_to_plant():
		return
	if any_plot_in(Phase.GROWING) or any_plot_in(Phase.RIPE):
		return
	if rescued:
		return   # rescued already and spent it on something else: the next one waits for a harvest
	var gift := Balance.i("economy.rescue_coins") - coins
	if gift <= 0:
		return
	rescued = true
	add_coins(gift, false)
	message.emit(tr("YOU_FOUND_COINS_IN_THE_BARN") % gift)


## A young farm (its first `economy.young_farm_days` days) that cannot afford to plow and plant
## `economy.young_farm_plots` plots, with empty land to plant, is topped up to that once a day (owner, 19 Nov: a
## player who comes once a day was broke for four days, on level 2 with 70 to 95 plots bare).
func _help_young_farm() -> void:
	var today := day_number()
	if born_day < 0 or today - born_day >= Balance.i("economy.young_farm_days") or helped_day == today:
		return
	var plots_n := Balance.i("economy.young_farm_plots")
	var need := plots_n * (cheapest_seed_cost() + Balance.i("economy.plow_cost"))
	if coins >= need or not (any_plot_in(Phase.GRASS) or any_plot_in(Phase.PLOWED)):
		return
	helped_day = today
	var gift := need - coins
	add_coins(gift, false)
	message.emit(tr("YOUNG_FARM_HELP") % gift)


## The coins the next planting needs: the cheapest seed, and the plow when no plot is plowed and waiting.
func coins_to_plant() -> int:
	var need := cheapest_seed_cost()
	if not any_plot_in(Phase.PLOWED):
		need += Balance.i("economy.plow_cost")
	return need


func any_plot_in(wanted: Phase) -> bool:
	for i in plots.size():
		if field.phase(i) == wanted:
			return true
	return false


# ---------------------------------------------------------------- tutorial


## The next step in floating words: the old tutorial's (farms from before goals), else the open Welcome
## chain's line (GoalSystem.welcome_say).
func tutorial_text() -> String:
	_fit_tutorial()
	return tr(TUTORIAL_TEXT[tutorial_step]) if TUTORIAL_TEXT.has(tutorial_step) else goals.welcome_say()


## The old tutorial's step never asks for what the farm doesn't have (owner, 19 Nov: "Tap your ripe crops to
## harvest!" over a field of empty plowed plots): a harvest step with nothing ripe moves on to plowing.
func _fit_tutorial() -> void:
	if tutorial_step == Tutorial.HARVEST and not any_plot_in(Phase.RIPE):
		tutorial_step = Tutorial.PLOW


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
		record("earn", "coins", amount)
	queue_save()


## Everything done on the farm is one event (data/events.json): it keeps the ribbon counters and is told as `did`,
## which goals (and anything later) listen to. `subject` is what it was done to (a crop, an animal, a recipe...).
func record(verb: String, subject: String, n := 1) -> void:
	if n <= 0:
		return
	if not ribbons.event_verbs.has(verb):
		push_error("Game.record: verb '%s' is not in data/events.json" % verb)
		return
	ribbons.count(verb, subject, n)
	did.emit(verb, subject, n)


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
	var n := lvl - table.size()   # levels past the table: each needs a little more than the one before
	return int(table[-1]) + n * Balance.i("economy.xp_per_level_after_table") \
		+ Balance.i("economy.xp_growth_after_table") * n * (n - 1) / 2


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


## Whether this crop can be planted now: unlocked, or gift seeds of it are held (Starter Seeds).
func can_plant(crop_id: String) -> bool:
	return is_unlocked(crop_id) or goals.seeds_of(crop_id) > 0


## Coins paid on reaching a level: grows with level so later levels still feel big.
func level_reward(lvl: int) -> int:
	return Balance.i("economy.coins_per_level") * lvl


## Ids of the crops, trees, animals and buildings that unlock at exactly this level (in this release).
func unlock_ids_at(lvl: int) -> Array[String]:
	var ids: Array[String] = []
	for id in crop_order:
		if int(crops[id]["unlock_level"]) == lvl and Release.has(id):
			ids.append(id)
	for id in item_order:
		if int(items[id]["unlock_level"]) == lvl and Release.has(id):
			ids.append(id)
	return ids


## Names of crops, trees, animals and buildings that unlock at exactly this level.
func unlocks_at(lvl: int) -> Array[String]:
	var names: Array[String] = []
	for id in unlock_ids_at(lvl):
		names.append(crops[id]["name"] + tr("SEEDS") if crops.has(id) else items[id]["name"])
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
	return DataFile.read(path)


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
		if d.kind in ["crop", "material", "recipe", "ingredient"]:
			continue   # (not things that stand on the farm)
		items[id] = d.data
		item_order.append(id)


func _new_game() -> void:
	coins = Balance.i("economy.start_coins")
	gems = Balance.i("economy.start_gems")
	xp = 0
	if not keep_clock:
		debug_time_offset = 0
	skipped = 0
	born_day = day_number()
	helped_day = born_day   # (the first day is the starting coins' and the Welcome chain's)
	clear_until = now() + Balance.i("economy.fresh_farm_clear_seconds")
	# The Welcome chain teaches a new farm (GoalSystem); the three-step tutorial stays for farms without goals.
	tutorial_step = Tutorial.DONE if goals.active() and not goals.new_farm_chains().is_empty() else Tutorial.HARVEST
	objects = []
	next_uid = 1
	_occupied.clear()
	layout_revision += 1
	tiles_revision += 1
	_tiles_changed.clear()
	plots.clear()
	farm_size = START_SIZE
	unwithers = Balance.i("economy.start_unwithers")
	rescued = false
	fertilize_alls = 0
	absence_items = []
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
	# The animals have their first collect waiting, so the first session also teaches collecting (a starter
	# animal placed with a fresh timer stood a whole cycle, a day or more, before its first tap).
	_add_starter_object("chicken", 9, 2, ready_now("chicken"))
	_add_starter_object("chicken", 9, 3, ready_now("chicken"))
	_add_starter_object("cow", 10, 6, ready_now("cow"))
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
	obj.merge(extra, true)   # (an extra "t" replaces the fresh timer)
	add_object(obj)
	next_uid += 1


## A starter thing's timer set one cycle back: ready to collect from the first minute.
func ready_now(item_id: String) -> Dictionary:
	return {"t": now() - int(item_data(item_id).get("cycle_seconds", 86400))}


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
	trace_begin("showcase")
	save_game()
	trace("own farm saved")  # not-ui
	save_path = SHOWCASE_SAVE_PATH
	var left_out: Array[String] = load(SHOWCASE_SCRIPT).build(self)
	trace("showcase laid out: %d objects" % objects.size())  # not-ui
	save_game()
	trace("showcase saved")  # not-ui
	message.emit(tr("SHOWCASE_OPENED"))
	farm_opened.emit()
	return left_out


## Back from the showcase to the player's own farm, as it was left.
func open_own_farm() -> void:
	trace_begin("own farm")  # not-ui
	weather_override = ""   # (the showcase's tried weather stays in the showcase)
	save_game()
	save_path = SAVE_PATH
	if not saving_enabled or not load_game():
		_new_game()
	rebuild_occupancy()
	load(SHOWCASE_SCRIPT).announce(self)
	farm_opened.emit()


## Debug builds: a timed trace of opening a farm begins (LoadTrace, loaded only then).
func trace_begin(what: String) -> void:
	if not OS.is_debug_build():
		return
	_load_trace = load(LOAD_TRACE_SCRIPT)
	_load_trace.begin(what, get_tree())


## One line in the trace of opening a farm, if one was begun (LoadTrace.mark).
func trace(what: String) -> void:
	if _load_trace != null:
		_load_trace.mark(what)


func in_showcase() -> bool:
	return save_path == SHOWCASE_SAVE_PATH


## Lays every object back on the farm; one that no longer fits where it stood (its footprint changed, or the
## farm's rules did) moves to the nearest free spot, and one above its top level comes down to it. Returns how
## many moved. Leaves the occupancy rebuilt.
func settle_objects() -> int:
	_occupied.clear()
	layout_revision += 1
	tiles_revision += 1
	var misfits: Array = []
	for o in objects:
		# (a building saved above what is now its top level comes down to the top)
		if is_building_item(str(o["id"])) and int(o.get("level", 1)) > max_level(str(o["id"])):
			o["level"] = max_level(str(o["id"]))
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


## Whether thing `uid` is on the farm and on exactly the tiles it was (nothing moved since the tiles were known).
func _in_place(uid: int) -> bool:
	if not _tiles_changed.is_empty():
		return false
	var o := object_by_uid(uid)
	if o.is_empty():
		return false
	if not (o.has("row") and o.has("col")):
		return true
	var fp := footprint(o["id"])
	for r in range(int(o["row"]), int(o["row"]) + fp.y):
		for c in range(int(o["col"]), int(o["col"]) + fp.x):
			if int(_occupied.get(index_of(r, c), -1)) != uid:
				return false
	return true


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
	_tiles_changed.clear()   # (the whole field has just been told)


func plot_updated(i: int) -> void:
	plot_changed.emit(i)
	queue_save()
