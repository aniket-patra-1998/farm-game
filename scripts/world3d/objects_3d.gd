class_name Objects3D
extends Node3D
## Everything standing on the farm that has a 3D model, one node per object, rebuilt only when what it
## shows changes (its id, size, ready state, a frame becoming a building). Also the countryside trees
## around the farm. Kinds without a 3D model yet keep their 2D piece (ObjectLayer asks handles()).

signal transformed(at: Vector3, grand: bool)  # a building grew or was finished: sparkles there (grand: the big sound)
signal snapped(at: Vector3, fresh: bool)  # fence pieces joined up: a click there
signal landed(at: Vector3)  # something dropped onto the farm: a puff of dust there


const MODELLED := ["building", "barn", "crafting", "tree", "animal", "vehicle", "decor", "young", "bloom"]
const TIMED_KINDS := ["tree", "bloom", "building", "barn", "crafting", "young"]   # what time alone can change
const DECOR_MODEL := "res://scripts/world3d/decor_model.gd"
const CLOCKED := &"clocked"  # on a part: surface -> its own material that ripens by the clock (`_clocked`)
const TIMES: Array[StringName] = [&"ripe_from", &"ripe_len"]   # what `timed_material` sets
const TIMED_KEPT := 256      # timed materials kept before the ones nothing is drawn with are dropped
const HATCH_SHAKES := 3      # a mystery shakes this many times before it opens, each harder..
const HATCH_REACH := 0.035   # ..by this much more, in tiles, to either side
const HATCH_REST := 0.1      # seconds between shakes
const RUST := "rust"             # not-ui: how a vehicle's rust is written in its look ("rust2")
const REPAIRING := "fix"         # not-ui: written after a vehicle's rust while it is in for repair
const FARMHOUSE := "farmhouse"   # not-ui
const STAGE := "stage"           # not-ui: how the farmhouse's stage is written in its look ("stage3")
const PIECES := &"pieces"       # meta on a batched decoration's stand-in: the pieces the DecorLayer draws it from
const BOX := &"box"               # on a batched thing's stand-in: the box round its model, in the model's space
const DRESSINGS := 2              # looks of the grass and stones round a thing of a kind and size (shared, by its uid)
const TREE_SIZE_JITTER := 0.0   # each tree of a kind is this much bigger or smaller than the built look it copies
const GROUP := &"objects_3d"   # every Objects3D, for until_settled
const LIGHT_BUDGET_USEC := 800   # a timer's look works for this long a frame, then carries on the next (no hitch)
const FULL_EVERY := 10        # a full look at everything every this many seconds (the rest only look at those)
# A sync builds models for at most this long a frame, then carries on the next frame: a farm with hundreds of
# things appears over a few frames instead of freezing (a phone says "not responding" after 5 s of that).
# Decorations built a little differently by where they stand (the rest have one look).
const VARIED_DECOR := ["wooden_bridge", "pine_tree", "oak_tree", "maple_tree", "willow_tree"]
const BUILD_BUDGET_MS := 12
const OPENING_BUDGET_MS := 40   # ..and while a farm opens (nothing stands yet, the player waits for it): more a frame
const COVERED_BUDGET_MS := 150  # ..and under the loading cover (nothing is seen, so a frame may build for long)
## The kinds `uses_file` draws from files (a tree comes from its by look: tree_look).
const FILE_KINDS := ["building", "barn", "crafting", "decor"]
const TREE_LOOKS := 4     # looks of each tree kept in its file (tree_look; tools/export_plants)
const SHAKE_LEANS := [0.11, -0.08, 0.05, -0.025]   # how far a harvested tree rocks, one way then the other (radians)
const SHAKE_BEAT := 0.09  # seconds each rock takes
# The share of its slots holding something finished at which a crafting building's storage parts show a quarter,
# half and full.
const FILL_FROM: Array[float] = [0.25, 0.5, 1.0]
const ROLL := "_roll_"   # not-ui (in a part's name: a door that rolls up, mark_parts)
const HARVESTING := "harvesting"   # not-ui (a building type: Game.building_type)
const WINDOW_SIZE := 0.22       # a `window_*` part's size at scale 1 (how big a head looking out of it is)
const BUILD_STAGES := 10       # a construction site made as files has this many stages, a file each, as it goes up
const SCENERY_Y := -Ground3D.SLAB
const SCENERY_CELL := 14.0    # woods are baked in squares this many tiles across
const GROVE_MASK := 0xff       # woods stand shoulder to shoulder: their trees are drawn crowded on every side

const PINE := Color("#2f6b3a")
const PINE_TIERS := 5        # skirts of needles on a pine
const PINE_TRUNK_R := 0.055


const STEP_LEVEL := 100       # see _step
const MEND_LEAST := 0.02      # a repair just begun is already told from none (its sign's gear turns)
const DROP_HEIGHT := 1.4      # tiles above the ground a new thing falls from
const YARD_HEIGHT := 0.3      # a building's yard and fence, for taps
const PART_HEIGHT := 1.0      # what stands beside a building (a silo, an annex), for taps
const ROOF_EXTRAS := 0.35     # chimneys, cupolas and vanes above the roof, for taps
const TREE_CROWN_AT := 0.6     # where a tree's crown is centred, of its height
const TREE_CROWN_FILL := 0.92  # how much of its box the pickable crown takes: the leafy outline is ragged
const TREE_TRUNK_HALF := 0.12  # half the width of the pickable trunk, in tiles
const TREE_CENTRE_BIAS := 0.6  # tiles of depth a tap at the crown's very edge is worth less than at its middle


static var _ghost_materials := {}   # tint name -> the shared see-through material
static var _timed := {}             # material and times -> the material's copy that ripens then (`timed_material`)

var decor: DecorLayer   # draws the standalone decorations in batches
var ready_shown := 0    # how many things wear a ready sign now (the Next ready button's count asks nothing twice)
var life: FarmLife  # the animals' minds (shared with the 2D world)

var grid: FarmGrid  # for what's being placed: its ghost follows the finger, and the thing being moved hides



var _views := {}   # uid -> {"node": Node3D, "key": String}
var _animals: Array[Animal3D] = []
var _synced_once := false   # the farm's first sync places everything quietly; later ones drop new things in
var _ghost: Node3D
var _ghost_tint := ""
var _ghost_key := ""
var _lifted := -1
var _queued := false
var _one_due := {}       # uid -> true: things changed in place, looked at alone at the end of the frame
var _ready_of := {}      # uid -> whether it shows the ready sign, as last worked out (the signs of one thing redone)
var _full := true        # the queued sync looks at everything (a change), not only what time changes
var _sweep_all := false  # the timer's look this time looks at everything, not only what time changes (FULL_EVERY)
var _sweep_seen := 0     # things the timer's look has been past (one gone without a word shows as a shortfall)
var _rust_watch := {}    # uid -> true: the vehicles, Garages and buildings that wear (signs: _mark_rust)
var _changed := {}       # uid -> true: what a change said it touched (Game.changed_uids); looked at with its neighbours
var _ticks := 0

var _scenery: Node3D
var _hatching := {}     # young uid -> {into, then}: a mystery about to open (hatch), kept for its shaking
var _unopened := {}     # the uid it opens into -> true: built hidden until it opens
var _links_at := -1     # Game.tiles_revision, and how many things there were, when the fences were last joined
var _links_count := -1
var _plain := {}   # item id -> whether it is a plain decoration (code-built, standing alone): see _key
var _links: LinkLayer   # draws the fences, hedges, walls and paths, joined up
var _ghost_mask := -1
var _link_landed := -1   # the frame a joined piece last landed
var _woods: Array = []   # groups of the woods still going up: [holder, trees left]
var _sweep := -1         # how far the timer's look has got through Game.objects (-1: none under way)
var _sweep_ready := {}   # uid -> ready, as that look found it (its ready signs are made from these)
var _masks_at := Vector2i(-1, -1)   # the farm's layout (its revision, how many things) the masks were made for
var _masks := {}         # uid -> its Crowding.mask: neighbours only change with the farm, so kept between changes
var _carry_on := false  # a sync ran out of time: the rest comes next frame
var _left := 0           # objects a sync ran out of time for, still to build
var _most_left := 0   # the most there was left to build since the farm last stood whole (progress_in)
var _todo: Array[int] = []   # their uids: the next frame builds only these, without looking the farm over again
var _resuming := false   # this sync carries on from one that ran out of time, with no change since
var _ready_marks: ReadyMarks   # the one ready sign, over everything with something to collect
var _crown_stars: CrownStars   # the gold star over every building at its biggest size
var _rust_marks: RustMarks     # the rust sign, over every rusty vehicle (or the Garage it stands in)
var _fireworks: Fireworks3D    # the fireworks over a building that has just grown
var _rings: WaterRings         # the rings on water: swimmers' wakes, splashes, a fish's leap
var _links_due := true          # the farm changed since the fences and hedges were last joined up




static func handles(o: Dictionary) -> bool:
	return o.get("stray", false) or MODELLED.has(Game.kind_of(o))




func _ready() -> void:
	add_to_group(GROUP)
	_scenery = Node3D.new()
	add_child(_scenery)
	_links = LinkLayer.new()
	add_child(_links)
	_links.snapped.connect(func(at: Vector3, fresh: bool) -> void: snapped.emit(at, fresh))
	decor = DecorLayer.new()
	add_child(decor)
	_ready_marks = ReadyMarks.new()
	add_child(_ready_marks)
	_rust_marks = RustMarks.new()
	add_child(_rust_marks)
	_crown_stars = CrownStars.new()
	add_child(_crown_stars)
	_fireworks = Fireworks3D.new()
	add_child(_fireworks)
	_rings = WaterRings.new()
	add_child(_rings)
	sync()
	Game.farm_expanded.connect(func(_n: int) -> void: _build_scenery())
	# A vehicle standing on the farm is out of sight while it is drawn at work (VehicleRuns), and back after.
	Game.vehicles.run_started.connect(func(run: VehicleWork) -> void: _show_standing(run.id, false))
	Game.vehicles.run_finished.connect(func(run: VehicleWork) -> void: _show_standing(run.id, true))
	_build_scenery()
	var timer := Timer.new()
	timer.wait_time = 1.0  # trees ripen and buildings become ready over time
	timer.autostart = true
	timer.timeout.connect(_on_tick)
	add_child(timer)




## Shows or hides the vehicle `id` where it stands on the farm.
func _show_standing(id: String, shown: bool) -> void:
	for o in Game.objects:
		if str(o["id"]) == id and Game.kind_of(o) == "vehicle" and _views.has(int(o["uid"])):
			(_views[int(o["uid"])]["node"] as Node3D).visible = shown


## Each second: only what time changes (trees ripening, buildings filling, sites rising) is looked at again; every
## FULL_EVERY ticks everything is, in case a change was not announced.
func _on_tick() -> void:
	_ticks += 1
	if _ticks % FULL_EVERY == 0 and _synced_once:
		# Everything is looked at again, in case a change was not announced: a few things a frame like the timer's
		# look (one look at the whole of a full farm in a single frame cost 27 ms, every ten seconds).
		_masks_at = Vector2i(-1, -1)   # (who stands beside whom, and the fences, worked out again)
		_links_at = Game.tiles_revision
		_links_count = Game.objects.size()
		_links.sync(Game.objects)
		_sweep_all = true
	if not _queued and _sweep < 0:
		_sweep = 0   # (a few things a frame from here: see _light_some)
		_sweep_ready.clear()
		_sweep_seen = 0


## Whether the picture of `o` can change with time alone (not only when the player or a system changes it).
static func timed(o: Dictionary) -> bool:
	return TIMED_KINDS.has(Game.kind_of(o)) or Game.under_construction(o)


func queue_sync() -> void:
	if not Game.changed_uids.is_empty() and not (_queued and _full and _changed.is_empty()) and _synced_once:
		# The change says what it touched (one thing placed, moved or sold): only that, and what stands beside it,
		# is looked at (on a full farm looking at everything cost 25 ms a placing, a freeze on a phone).
		for uid: int in Game.changed_uids:
			_changed[uid] = true
		_links_due = true
		if not _queued:
			_queued = true
			_full = true
			sync.call_deferred()
		return
	_changed.clear()
	_full = true
	_resuming = false   # (a change: the whole farm is looked at again)
	_links_due = true
	if not _queued:
		_queued = true
		sync.call_deferred()




## One thing changed where it stands (Game.object_changed): only it is looked at, at the end of the frame.
func queue_one(uid: int) -> void:
	if _one_due.is_empty():
		_sync_some.call_deferred()
	_one_due[uid] = true


func _sync_some() -> void:
	var uids := _one_due.keys()
	_one_due.clear()
	if _queued and _full:
		return   # (the whole farm is being looked at this frame anyway)
	var built := false
	for uid: int in uids:
		var o := Game.object_by_uid(uid)
		if o.is_empty() or not handles(o):
			continue
		_ready_of.erase(uid)
		if not _shown_in_place(o):
			_rebuild(o)
			built = true
	_mark_ready(_ready_of)
	if built:
		_animals.clear()
		for v in _views.values():
			if v["node"] is Animal3D:
				_animals.append(v["node"])


## When `o` still looks as it is drawn (its key), shows what changed in place (ready, at work, who's in) and says
## so; false when it must be built again.
func _shown_in_place(o: Dictionary) -> bool:
	var v: Dictionary = _views.get(int(o["uid"]), {})
	if v.get("key", "") != _key(o):
		return false
	if v.has("crown") or v.has("blooms"):
		_ripen_view(v, o)   # (a tree just harvested: its fruit starts over; nothing when its cycle is as it was)
	if v.get("file", false) or v.get("states", false):
		AssetRegistry.apply_state(v["node"], state_of(o))   # (ready, at work... shown in place)
	var fill := v.get("fill") as BuildingFill   # (kept with the view: finding it took a look through the node)
	if fill != null and is_instance_valid(fill):
		fill.refresh(o)  # who's in, how near ready: shown without rebuilding the building
	return true


## Builds `o`'s look again (or for the first time), and plays it dropping in or swelling up.
## Files that were not in the app have arrived (AssetPacks.arrived): everything drawn from them, standing on the
## farm or living in a home, is made again from its own file.
func remake(paths: Array[String]) -> void:
	var ids := {}
	for id: String in Game.item_order:
		if paths.has(str(AssetRegistry.entry(id).get("model", ""))):
			ids[id] = true
	Animal3D.clear_templates()   # (the stand-ins built so far are not what these animals are any more)
	for o: Dictionary in Game.objects:
		var here := ids.has(str(o["id"]))
		for inside: String in (o.get("inside", {}) as Dictionary):
			here = here or ids.has(inside)
		if here:
			_rebuild(o)


func _rebuild(o: Dictionary) -> void:
	var uid := int(o["uid"])
	var v: Dictionary = _views.get(uid, {})
	if v.has("node"):
		(v["node"] as Node3D).queue_free()
	var node := _build(o)
	add_child(node)
	if _unopened.has(uid):
		node.visible = false   # (what a mystery is opening into: shown when it opens, _shake_open)
	var fresh := not v.has("node")
	var step := _step(o)
	_views[uid] = {"node": node, "key": _key(o), "box": _bounds(node, o), "parts": _parts(node, o), "step": step,
		"file": uses_file(o), "states": Game.is_building_item(str(o["id"]))}
	_views[uid]["never_ready"] = GameState.NEVER_READY.has(Game.kind_of(o))
	_views[uid]["kind"] = Game.kind_of(o)
	_views[uid]["garage"] = Game.special_of(o) == "garage"
	_views[uid]["wears"] = Game.wear.wears(o)
	if _views[uid]["kind"] == "vehicle" or _views[uid]["garage"] or _views[uid]["wears"]:
		_rust_watch[uid] = true   # (only these can wear a rust or wear sign: the rest of the farm is not asked)
	else:
		_rust_watch.erase(uid)
	if o.has("row"):   # (where it stands: a change that moves or takes it away looks at its old neighbours too)
		var fp := Game.footprint(str(o["id"]))
		_views[uid]["rect"] = Rect2i(int(o["col"]), int(o["row"]), fp.x, fp.y)
	_views[uid]["fill"] = fill_of(uid)
	_ground(node, o, _views[uid]["box"])
	_dress_water(uid, o)
	if Game.catalog.get_def(str(o["id"])) is TreeDef:
		_views[uid]["crown"] = _crown_of(_views[uid]["box"])
		_ripen_view(_views[uid], o)
	elif Game.catalog.get_def(str(o["id"])) is BloomDef:
		_views[uid]["blooms"] = true
		_ripen_view(_views[uid], o)
	if not fresh and _synced_once and step > int(v.get("step", step)):
		grow_in(uid, int(v.get("step", step)) == 0)  # upgraded or finished: it swells in with a flourish
	if fresh and _synced_once and not _unopened.has(uid):
		drop_in(uid)  # newly bought or placed: it drops onto the farm


func sync() -> void:
	var pt := PerfReadout.start()
	sync_timed()
	PerfReadout.stop("objects_3d_sync", pt)


func sync_timed() -> void:
	_queued = false
	var light := not _full   # a timer tick: only what time changes
	_full = false
	_sweep = -1              # (this look is at least what a timer's look under way would have been)
	if not light and _links_due:
		_links_due = false   # (once per change: not again on each frame the building carries on over)
		if Game.tiles_revision != _links_at or Game.objects.size() != _links_count:
			# (fences join by where things stand: a change that moved nothing changes none of it)
			_links_at = Game.tiles_revision
			_links_count = Game.objects.size()
			_links.sync(Game.objects)   # first: what's new there is already known when its stand-in drops in
	if not light and not _changed.is_empty():
		_sync_changed()
		return
	if _resuming and not light:
		_resuming = false
		_build_todo()
		return
	_resuming = false
	_todo.clear()
	var seen := {}
	var began := Time.get_ticks_msec()
	var built := 0
	var left := 0
	# The budget is for building. Looking at every thing (its key) must not eat it: on a farm of many hundreds
	# that alone took the whole budget, and the things at the end of the list were never built at all.
	var spent := 0
	for o in Game.objects:
		if not handles(o):
			continue
		var uid := int(o["uid"])
		seen[uid] = true
		if light and _views.has(uid) and not timed(o):
			continue
		if _shown_in_place(o):
			continue
		if spent > _budget_ms() * 1000:
			left += 1          # out of time this frame: built on the next
			_todo.append(uid)
			continue
		built += 1
		var build_began := Time.get_ticks_usec()
		_rebuild(o)
		spent += Time.get_ticks_usec() - build_began
	for uid in _views.keys():
		if not seen.has(uid):
			if _hatching.has(uid):
				_shake_open(uid)   # (a mystery opening: it shakes where it stood before it goes)
			else:
				(_views[uid]["node"] as Node3D).queue_free()
			_views.erase(uid)
			_rust_watch.erase(uid)
	_mark_ready()
	if built > 0:
		Game.trace("objects: built %d in %d ms, %d to go" % [built, Time.get_ticks_msec() - began, left])  # not-ui
	_left = left
	if left > 0:
		_full = _full or not light
		_carry_on = true
		_preload_todo()
	else:
		_synced_once = true   # (until the whole farm stands, nothing drops in: it is being laid out, not bought)
	if light and built == 0:
		return
	_animals.clear()
	for v in _views.values():
		if v["node"] is Animal3D:
			_animals.append(v["node"])


## Looks only at what a change touched (`_changed`) and at what stands, or stood, beside it (its neighbours'
## looks may join with it: Crowding): each is built, made again or taken away as needed; ready signs keep what is
## known of everything else.
func _sync_changed() -> void:
	var look := {}
	for uid: int in _changed:
		look[uid] = true
		var o := Game.object_by_uid(uid)
		if not o.is_empty() and o.has("row"):
			var fp := Game.footprint(str(o["id"]))
			_add_neighbours(look, Rect2i(int(o["col"]), int(o["row"]), fp.x, fp.y))
		if _views.has(uid) and _views[uid].has("rect"):
			_add_neighbours(look, _views[uid]["rect"])   # (where it stood: those beside it lost a neighbour)
	_changed.clear()
	var built := false
	for uid: int in look:
		_ready_of.erase(uid)
		var o := Game.object_by_uid(uid)
		if o.is_empty() or not handles(o):
			if _views.has(uid):
				if _hatching.has(uid):
					_shake_open(uid)
				else:
					(_views[uid]["node"] as Node3D).queue_free()
				_views.erase(uid)
				_rust_watch.erase(uid)
				built = true
			continue
		if not _shown_in_place(o):
			_rebuild(o)
			built = true
	_mark_ready(_ready_of)
	if built:
		_animals.clear()
		for v in _views.values():
			if v["node"] is Animal3D:
				_animals.append(v["node"])


## Adds the uids of what stands on the ring of tiles round `rect` (columns x, rows y) to `into`.
static func _add_neighbours(into: Dictionary, rect: Rect2i) -> void:
	for r in range(rect.position.y - 1, rect.end.y + 1):
		for c in range(rect.position.x - 1, rect.end.x + 1):
			if r < 0 or c < 0 or r >= Game.farm_size or c >= Game.farm_size:
				continue
			var n := Game.object_at(Game.index_of(r, c))
			if not n.is_empty():
				into[int(n["uid"])] = true


## Whether a look not built yet may be built now: while a farm opens (under its cover) yes; in play a tree's or
## bloom's crowded look waits (built and kept, it took 160 ms on a PC when a placing needed one: a freeze on a
## phone), shown meanwhile as it stands alone, and is built the next time the farm opens. One built or kept
## before (Instancer, ModelStore) is used at once.
func may_build() -> bool:
	return not _synced_once or LoadingCover.covering > 0


## How long a frame may build for: longer while a farm opens (nothing stands yet and the player is waiting for it),
## the usual BUILD_BUDGET_MS once it stands (so later changes never cost a hitch).
func _budget_ms() -> int:
	if LoadingCover.covering > 0:
		return COVERED_BUDGET_MS
	return BUILD_BUDGET_MS if _synced_once else OPENING_BUDGET_MS


## What the coming frames will build is loaded from its files on worker threads now, side by side
## (AssetRegistry.preload_files), so each frame only puts together what is already read.
func _preload_todo() -> void:
	var paths: Array[String] = []
	for uid in _todo:
		var o := Game.object_by_uid(uid)
		if not o.is_empty() and uses_file(o):
			var e := AssetRegistry.entry(str(o["id"]))
			paths.append(AssetRegistry.file_of(e, state_of(o)))
	AssetRegistry.preload_files(paths)


## Carries on a sync that ran out of time: builds only what it left (`_todo`), within the budget, instead of
## looking every thing on the farm over again each frame (on a full farm that alone cost more than the building).
func _build_todo() -> void:
	var began := Time.get_ticks_usec()
	var built := 0
	while not _todo.is_empty() and Time.get_ticks_usec() - began <= _budget_ms() * 1000:
		var o: Dictionary = Game.object_by_uid(_todo.pop_front())
		if o.is_empty() or not handles(o) or _shown_in_place(o):
			continue   # (gone, or already drawn as it is)
		_rebuild(o)
		built += 1
	_left = _todo.size()
	if _left > 0:
		_full = true
		_carry_on = true
	else:
		_synced_once = true
	if built > 0:
		_mark_ready()
		_animals.clear()
		for v in _views.values():
			if v["node"] is Animal3D:
				_animals.append(v["node"])


## FarmVille's one ready sign over everything that has something to collect: a building or its finished
## crafts, a tree, a bloom, an animal (whose sign walks with it). Over the top of what is drawn.
func _mark_ready(known := {}) -> void:
	var pt := PerfReadout.start()
	_mark_ready_timed(known)
	PerfReadout.stop("ready_marks", pt)


func _mark_ready_timed(known: Dictionary) -> void:
	var tops: Array[Vector3] = []
	var minor: Array[bool] = []
	var animals: Array[Animal3D] = []
	for uid: int in _views:
		var v: Dictionary = _views[uid]
		if v.get("never_ready", false):
			continue   # (scenery, the Barn, vehicles: known when it was built, not asked on every look)
		# (`known`: what a timer's look has just found, thing by thing, so nothing is asked twice)
		var ready: bool
		if known.has(uid):
			ready = known[uid]
		else:
			var o := Game.object_by_uid(uid)
			if o.is_empty():
				continue
			ready = Game.has_ready(o)
		_ready_of[uid] = ready
		if ready:
			var node: Node3D = v["node"]
			if node is Animal3D:
				animals.append(node as Animal3D)
			else:
				var box: AABB = v["box"]
				tops.append(Vector3(box.get_center().x, box.end.y, box.get_center().z))
				minor.append(not v.get("states", false))   # (trees and blooms: small, fade far out)
	ready_shown = tops.size() + animals.size()
	_ready_marks.show_at(tops, animals, minor)
	var pt := PerfReadout.start()
	_mark_rust()
	PerfReadout.stop("rust_marks", pt)
	_mark_stars()


## The gold star (CrownStars) over every finished building at its biggest size: where its model marks it
## (CrownStars.mark_of), at the size the mark names.
func _mark_stars() -> void:
	var tops: Array[Vector3] = []
	var radii: Array[float] = []
	for uid: int in _views:
		var v: Dictionary = _views[uid]
		if not v.get("states", false) or not (v["node"] as Node3D).is_visible_in_tree():
			continue   # (only buildings have sizes)
		if not v.has("star"):
			v["star"] = CrownStars.mark_of(v["node"])   # (looked for once a view)
		var star: Array = v["star"]
		if star.is_empty() or not is_instance_valid(star[0]) or not (star[0] as Node3D).is_inside_tree():
			continue
		tops.append(to_local((star[0] as Node3D).global_position))
		radii.append(float(star[1]))
	_crown_stars.show_at(tops, radii)


## The star layer (tests and tools).
func crown_stars_node() -> CrownStars:
	return _crown_stars


## The rust sign (RustMarks; docs/RUST.md) over every vehicle that needs a repair: over the vehicle where it
## stands outside, or over its Garage, which wears the sign of the rustiest vehicle in it.
func _mark_rust() -> void:
	var tops: Array[Vector3] = []
	var ids: Array[String] = []
	var shares: Array[float] = []
	var mends: Array[float] = []
	var rust := Game.rust
	var wear := Game.wear
	var rusting := rust.is_on() and not rust.vehicles.is_empty()
	if rusting or (wear.is_on() and not wear.buildings.is_empty()):
		for uid: int in _rust_watch:
			var v: Dictionary = _views.get(uid, {})
			if v.is_empty():
				continue
			var id := ""
			var share := 0.0
			var mend := 0.0
			var kind: String = v.get("kind", "")
			var o := Game.object_by_uid(uid)
			if o.is_empty() or Game.under_construction(o):
				continue
			if rusting and kind == "vehicle":
				id = str(o["id"]) if (_views[uid]["node"] as Node3D).visible and rust.needs_repair(str(o["id"])) else ""
			elif rusting and v.get("garage", false):
				id = rust.rustiest(o.get("inside", {}))
			if id != "":
				share = float(rust.level(id)) / rust.max_level()
			elif wear.needs_repair(o) or wear.repairing(uid):
				# (A worn building wears the same sign, and keeps it while it is repaired, its gear turning and its
				# pips filling as the repair goes: docs/WEAR.md.)
				id = WearSystem.key_of(uid)
				share = float(wear.level_of(o)) / wear.max_level()
				mend = maxf(wear.repair_share(uid), MEND_LEAST) if wear.repairing(uid) else 0.0
			if id == "":
				continue
			var box: AABB = _views[uid]["box"]
			tops.append(Vector3(box.get_center().x, box.end.y, box.get_center().z))
			ids.append(id)
			shares.append(share)
			mends.append(mend)
	_rust_marks.show_at(tops, ids, shares, mends)


## What drawing everything under `root` costs, counted as the renderer would (for the budget test and tools):
## x the draws (each visible mesh or batch with something in it, again for the sun's shadow when it casts one),
## y the triangles (a batch's mesh times its instances).
static func draw_cost(root: Node) -> Vector2i:
	var draws := 0
	var tris := 0
	for n in root.find_children("*", "GeometryInstance3D", true, false):  # not-ui
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		var copies := 1
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			var mm := (g as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			copies = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		if mesh == null or copies <= 0:
			continue
		var passes := 2 if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 1
		for k in mesh.get_surface_count():
			draws += passes
			var arrays := mesh.surface_get_arrays(k)
			var idx: Variant = arrays[Mesh.ARRAY_INDEX]
			var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
			var n_tris := (idx as PackedInt32Array).size() / 3 if idx != null else (verts as Array).size() / 3 \
				if verts != null else 0
			tris += n_tris * copies * passes
	return Vector2i(draws, tris)


## The ready signs' layer (for tests and tools).
func ready_marks_node() -> ReadyMarks:
	return _ready_marks


## The view of object `uid` (its holder, or the animal itself), or null.
func view_of(uid: int) -> Node3D:
	return _views.get(uid, {}).get("node")


## How many things show the ready sign.
func ready_marks() -> int:
	return _ready_marks.count()


## The rust signs (for tests and tools).
func rust_marks_node() -> RustMarks:
	return _rust_marks


## Whether everything is built: every object, the woods, and every orchard's trees (the farm goes up over a few
## frames after it opens; screenshots and measurements wait for this).
## How much of the farms on the screen is built, 0..1, against the most there was left to build since they were
## last whole (for the loading cover's count).
static func progress_in(tree: SceneTree) -> float:
	var left := 0
	var most := 0
	for o: Objects3D in tree.get_nodes_in_group(GROUP):
		left += o._left
		o._most_left = maxi(o._most_left, o._left) if o._left > 0 else 0
		most += o._most_left
	return 1.0 if left == 0 else 1.0 - float(left) / float(maxi(most, left))


func settled() -> bool:
	return _left == 0 and _woods.is_empty() and BuildingFill.planting == 0


## Waits until every farm on the screen is fully built (or `most` frames have passed): for screenshots and
## measurements, which must not catch a farm half up.
static func until_settled(tree: SceneTree, most := 3000) -> void:
	for n in most:
		var all := true
		for o: Objects3D in tree.get_nodes_in_group(GROUP):
			all = all and o.settled()
		if all:
			return
		await tree.process_frame







## Animals move every frame, with their 2D twin's mind; those off screen keep their place but aren't posed.
func _process(delta: float) -> void:
	if _carry_on and not _queued:   # the rest of a sync that ran out of time
		_carry_on = false
		_resuming = true
		sync()
	var pt := PerfReadout.start()
	if _sweep >= 0:
		_light_some()
	PerfReadout.stop("objects_light", pt)
	if not _woods.is_empty():
		pt = PerfReadout.start()
		_grow_woods()
		PerfReadout.stop("woods", pt)
	pt = PerfReadout.start()
	_update_placing()
	PerfReadout.stop("placing_ghost", pt)
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_ready_marks.follow(cam.size)
		_rust_marks.follow(cam.size)
	_ready_marks.follow_animals()
	pt = PerfReadout.start()
	var n := _animals.size()
	var first := Engine.get_process_frames() % maxi(n, 1)   # (a new first each frame: a crowded frame's waiters go
	for k in n:                                              # early in a coming one: Animal3D.POSES_MOST)
		var a := _animals[(first + k) % n]
		if not is_instance_valid(a):
			continue
		if a.behaviour == null:
			a.behaviour = _mind_of(a)
		a.animate(delta, cam)
	PerfReadout.stop("animals_pose", pt)




func _mind_of(a: Animal3D) -> AnimalBehaviour:
	return life.mind(int(a.get_meta("uid", -1))) if life != null else null




## What a view shows: when this changes, it's rebuilt.
## How far along a building is in its life: a site, or the starter Barn standing broken, counts for nothing, a
## finished building 100, plus 10 a level. (When it goes up, the building has been finished, repaired or
## upgraded: see grow_in.) A vehicle in for repair counts for nothing too, so it swells back in mended.
func _step(o: Dictionary) -> int:
	if Game.kind_of(o) == "vehicle":
		return 0 if Game.rust.repairing(str(o["id"])) else STEP_LEVEL
	if not Game.kind_of(o) in ["building", "barn", "crafting"]:
		return 0
	if Game.under_construction(o) or bool(o.get("broken", false)):
		return 0
	return STEP_LEVEL + 10 * int(o.get("level", 1))


## Whether decoration `id` is drawn as a model of its own, not in a batch with its like: a landmark, whose parts
## move by script (a clock's hands, a balloon riding the air) and of which a farm has one or two.
static func stands_alone(id: String) -> bool:
	var d := Game.catalog.get_def(id) as DecorationDef
	return d != null and d.is_landmark()


func _key(o: Dictionary) -> String:
	# A plain decoration (most of a decorated farm) shows nothing but what it is and where it stands: its key is
	# made without asking about ripeness, neighbours, withering or work, which it has none of.
	var id := str(o["id"])
	if not _plain.has(id):
		_plain[id] = Game.kind_of(o) == "decor" and Game.links.group_of(id) == "" and not AssetRegistry.has_model(id)
	if _plain[id] and not o.get("stray", false):
		return "decor|%s|%d|%d|%s|%s" % [id, int(o["row"]), int(o["col"]), o.get("flip", false),
			STAGE + str(Game.farmhouse_stage()) if id == FARMHOUSE else o.get("crop", o.get("flower", ""))]
	if Game.links.group_of(str(o["id"])) != "":
		return "link|%s|%d|%d" % [o["id"], int(o["row"]), int(o["col"])]   # how it joins is the LinkLayer's business
	if uses_file(o):
		# Made as a file: rebuilt only when it becomes another model (its level, broken or mended, withered); the
		# states that come and go (ready, at work) are shown in place (`sync`), so a collect's door swing and the
		# yard's animals carry on.
		return "file|%s|%d|%d|%s|%d|%s|%s|%d" % [o["id"], int(o["row"]), int(o["col"]), o.get("flip", false),
			Game.look_level(o), o.get("broken", false), Game.is_withered(o), int(state_of(o).get("stage", -1))]
	# A building site is rebuilt as each tenth of its materials goes in.
	var site := int(Game.land.construction_progress(o) * 10.0) if Game.under_construction(o) else -1
	return "%s|%d|%d|%d|%s|%d|%s|%d|%s" % [o["id"], int(o["row"]), int(o["col"]), Game.look_level(o),
		o.get("flip", false), site, false,
		_mask(o),
		str(o.get("broken", false)) + shows_of(o) + "|%d|%s|%s" % [int(o.get("fed", 0)),
			false, false]]   # (withering, work and fill are shown in place: no new model)




## Who stands beside `o` (Crowding.mask), kept until things come, go or move: looking around it costs more than
## the rest of its key together, and neither time nor a collect moves a neighbour.
func _mask(o: Dictionary) -> int:
	var layout := Vector2i(Game.tiles_revision, Game.objects.size())   # (which tiles hold what: not every change)
	if layout != _masks_at:
		_masks.clear()       # things have come, gone or moved: who stands beside whom is worked out again
		_masks_at = layout   # (a collect or a feed moves nothing: the masks stand)
	var uid := int(o.get("uid", -1))
	if not _masks.has(uid):
		_masks[uid] = Crowding.mask(o)
	return _masks[uid]


## The timer's look at what time alone changes, a few things a frame: what a thing shows in place (ready, at
## work, how full its yard, how near its produce) is set here; one that has become another picture (a tree
## ripened, a site risen) gets the full look, which builds it. Its ready signs go up when it has been round.
func _light_some() -> void:
	if _queued and _changed.is_empty():   # a change is about to be looked at in full
		_sweep = -1
		return
	var began := Time.get_ticks_usec()
	var end := Game.objects.size()
	for i in range(_sweep, end):
		if Time.get_ticks_usec() - began > LIGHT_BUDGET_USEC:
			end = i   # (out of time this frame: from here on the next)
			break
		var o: Dictionary = Game.objects[i]
		if not handles(o):
			continue
		var uid := int(o["uid"])
		_sweep_seen += 1
		var v: Dictionary = _views.get(uid, {})
		if v.is_empty():
			_queue_changed(uid)   # (something not announced: built where it stands)
			continue
		if not timed(o):
			if not GameState.NEVER_READY.has(Game.kind_of(o)):
				_sweep_ready[uid] = Game.is_ready(o)   # (an animal: only its sign changes with time)
			if _sweep_all and v["key"] != _key(o):
				_queue_changed(uid)   # (changed without a word: made again, with its neighbours)
			continue
		if v["key"] != _key(o):
			_queue_changed(uid)
			continue
		_sweep_ready[uid] = Game.has_ready(o)
		if v.get("file", false) or v.get("states", false):
			AssetRegistry.apply_state(v["node"], state_of(o))
		var fill := v.get("fill") as BuildingFill   # (kept with the view: no search through the node each second)
		if fill != null and is_instance_valid(fill):
			fill.refresh(o)
	_sweep = end
	if end >= Game.objects.size():
		_sweep = -1
		_mark_ready(_sweep_ready)
		if _sweep_all and _sweep_seen != _views.size():
			for uid: int in _views.keys():
				if Game.object_by_uid(uid).is_empty() and not _hatching.has(uid):
					_queue_changed(uid)   # (gone without a word: its picture is taken away)
		_sweep_all = false


## Looks again at `uid` alone (and its neighbours) at the end of the frame: found changed by the timer's look.
func _queue_changed(uid: int) -> void:
	_changed[uid] = true
	if not _queued:
		_queued = true
		_full = true
		sync.call_deferred()


## Whether a building is at work right now: a crafting building with something in its ovens or vats. (Other
## buildings are always "at work": their chimneys, if any, smoke.)
func _at_work(o: Dictionary) -> bool:
	if not Game.crafting.is_crafting(o):
		return true
	return Game.crafting.crafts_done(o) < (o.get("slots", []) as Array).size()


## How full a crafting building is of finished things waiting to be collected, as the look its storage parts
## show: 0 empty, 1 from a quarter of its slots, 2 from half, 3 (BuildingDress.FULL) when every slot holds one.
static func store_fill(o: Dictionary) -> int:
	if Game.building_type(str(o["id"])) == HARVESTING:
		# A harvesting building's ready part fills as its collect timer runs: full when it is ready to collect.
		return FILL_FROM.size() if Game.is_ready(o) else fill_for_share(BuildingFill.ready_share(o))
	if not Game.crafting.is_crafting(o):
		return 0
	return store_fill_for(Game.crafting.crafts_done(o), Game.crafting.slot_count(o))


## The storage look for `done` finished things in `slots` slots: 0 empty, 1 from a quarter, 2 from half, 3 full.
static func store_fill_for(done: int, slots: int) -> int:
	return fill_for_share(float(done) / maxi(slots, 1))


## The look for a part that is `share` full (0..1): 0 empty, 1 from a quarter, 2 from half, 3 full (FILL_FROM).
static func fill_for_share(share: float) -> int:
	var fill := 0
	for step: float in FILL_FROM:
		fill += 1 if share >= step else 0
	return fill


## Whether `o` is drawn from its file (AssetRegistry): only the kinds whose whole pipeline the file path keeps
## (buildings and their yards, plain decorations; trees and blooms by their look). Animals, vehicles (their
## implements and runs), young ones and joining fences and hedges (the LinkLayer draws those) stay code-built
## until their own file path is made (docs/ASSETS.md "Order of work").
func uses_file(o: Dictionary) -> bool:
	if not str(Game.kind_of(o)) in FILE_KINDS or o.get("stray", false):
		return false
	if Game.links.group_of(str(o["id"])) != "":
		return false
	if Game.under_construction(o):
		return AssetRegistry.has_site(str(o["id"]))   # (going up: its site's files, a stage each)
	return AssetRegistry.has_model(str(o["id"]))


## A lone tree's own size (the same for the same tree every time). It is never turned: its crown's leaves are
## made for the side the farm's camera sees and painted for where the sun is (TreeModel._sprayed), and each of
## its looks already stands its own way round.
static func _tree_turn(o: Dictionary) -> Basis:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(o["uid"])
	return Basis.IDENTITY.scaled(Vector3.ONE * (1.0 + rng.randf_range(-TREE_SIZE_JITTER, TREE_SIZE_JITTER)))


## Gives a building made as a file what its yard and doors need, from its parts' names (docs/ASSETS.md §1):
## `door*` parts swing open on collect (BuildingSpec.DOOR; `door_left` the other way), and `window_*` parts are
## where animals look out (BuildingSpec.WINDOWS, sized by the part's own scale).
static func mark_parts(model: Node3D) -> void:
	var windows: Array = []
	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not n is Node3D or n == model:
			continue
		var part := String(n.name)
		if part.begins_with("door") and part.contains(ROLL):
			n.set_meta(BuildingSpec.DOOR, 0.0)   # (a shutter: it rolls up by the height its name ends with)
			n.set_meta(BuildingSpec.SLIDE, part.get_slice(ROLL, 1).to_float() / 100.0)
		elif part.begins_with("door"):
			n.set_meta(BuildingSpec.DOOR, -1.0 if part.ends_with("left") else 1.0)
		elif part.begins_with("window"):
			windows.append({"at": _local_to(model, n as Node3D).origin, "size": WINDOW_SIZE * (n as Node3D).scale.x})
	if not windows.is_empty():
		var marker := Node3D.new()
		marker.set_meta(BuildingSpec.WINDOWS, windows)
		model.add_child(marker)


## `n`'s transform in `root`'s own space.
static func _local_to(root: Node3D, n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != root and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## What an asset made as a file is shown in (AssetRegistry.apply_state): its level, ready or not, withered,
## at work, broken, its building stage (0..BUILD_STAGES-1).
func state_of(o: Dictionary) -> Dictionary:
	var state := {"ready": Game.is_ready(o), "withered": Game.is_withered(o), "broken": bool(o.get("broken", false))}
	if Game.is_building_item(str(o["id"])):
		state["level"] = Game.look_level(o)
		state["working"] = _at_work(o)
		state["fill"] = store_fill(o)
		state[BuildingSpec.PLAN] = Release.on("plans") and not state["broken"]   # (what its next size adds, framed)
		if Game.vip.level() > 0 and not state["broken"] and Game.building_def(str(o["id"])).shows_vip():
			state["vip"] = Game.vip.active()   # (its badge: gold and turning, or grey metal; none before VIP 1)
		if Game.under_construction(o):
			state["stage"] = mini(int(Game.land.construction_progress(o) * BUILD_STAGES), BUILD_STAGES - 1)
	return state


## A tree's look (one of Instancer.VARIANTS, `look`), shared. A lone tree comes from its file (one of its
## TREE_LOOKS, ready or not: art/models/trees, made by tools/export_plants); one standing among others
## (`mask`: Crowding) and a tree with no file are built once, or loaded when kept (ModelStore).
static func tree_look(id: String, mask: int, look: int, from_file := true, build_now := true) -> Node3D:
	if from_file and mask == 0 and AssetRegistry.has_model(id):
		return AssetRegistry.instance(id, {"look": look % TREE_LOOKS})
	var it := Game.item_data(id)
	var fp := Game.footprint(id)
	var grown := ScaleGuide.factor(id)
	var key := Instancer.key_of(["tree", id, grown, mask, look])
	if not build_now and mask != 0 and not Instancer.has_ready(key):
		return tree_look(id, 0, look, from_file)   # (see `may_build`: its crowded look comes when the farm opens)
	return Instancer.copy_of(key, func() -> Node3D:
		var tree := Node3D.new()
		TreeSpec.builder().build_at(tree, Vector3(fp.x / 2.0, 0, fp.y / 2.0), it, grown, true, look, true, TreeSpec.UNSET,
			mask)
		return ModelKit.bake(tree))


## Starts a tree's fruit growing, or a bloom opening, for the cycle it is in, when that is not the one its model
## was last told. A bloom that withers is told too when its wilting starts (the last part of the time it may
## stand ready, `WILT_SHARE`) so it withers little by little; one that never withers is told nothing of it.
func _ripen_view(v: Dictionary, o: Dictionary) -> void:
	var cycle := [float(o.get("t", 0)), float(Game.cycle_of(o))]
	if v.get("ripe") == cycle:
		return
	v["ripe"] = cycle
	if v["node"] is PaintedBloom:
		var d := Game.catalog.get_def(str(o["id"])) as BloomDef
		var opens := float(cycle[0]) + float(cycle[1])
		var withers := d != null and d.withers()
		(v["node"] as PaintedBloom).set_cycle(opens,
			opens + float(Balance.i("blooms.wither_after")) if withers else PaintedBloom.NEVER)
	else:
		ripen(v["node"], cycle[0], cycle[1])


## Tells a tree's model when its cycle began and how long it lasts, so its fruit grows on it by the farm's clock
## (shaders/fruit3d.gdshader): each fruit comes in its turn, swells and colours, and the tree is full exactly
## when it is ready. Set when the tree is built and again when it is harvested (its cycle starts over); between
## the two the shader does the growing, and nothing is asked of the tree. A bloom is told the same, and when it
## starts to wilt and how long that takes (`wilt_unix`, below 0 for what never withers).
##
## The times are the material's own: each part that ripens by the clock is drawn with a copy of its material that
## holds them (`timed_material`), shared by everything with the same material and the same times (an orchard's
## trees, everything collected in one sweep). Not per-instance shader values: a renderer holds only so many of
## those (4,096 things on the phones' renderer), and a full farm of trees and blooms has more.
static func ripen(node: Node, from_unix: float, cycle: float) -> void:
	_time_parts(node, [from_unix - CropClock.clock_base, maxf(cycle, 1.0)])


static func _time_parts(node: Node, times: Array) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		for s in range(-1, mi.mesh.get_surface_count()):   # (-1: the material the whole part is drawn with)
			var base := _clocked(mi, s)
			if base == null:
				continue
			if s < 0:
				mi.material_override = timed_material(base, times)
			else:
				mi.set_surface_override_material(s, timed_material(base, times))
	for c in node.get_children():
		_time_parts(c, times)


## The material surface `s` of `mi` (-1: its material_override) is drawn with when that one ripens by the clock
## (a tree's fruit, a bloom), else null: its own material, kept on the part before any timed copy takes its place.
static func _clocked(mi: MeshInstance3D, s: int) -> ShaderMaterial:
	var kept: Dictionary = mi.get_meta(CLOCKED, {})
	if not kept.has(s):
		var m := (mi.material_override if s < 0 else (mi.mesh.surface_get_material(s) if mi.get_surface_override_material(s)
			== null else mi.get_surface_override_material(s))) as ShaderMaterial
		kept[s] = m if m != null and m.shader != null and m.shader.resource_path == ModelKit.FRUIT_SHADER else null
		mi.set_meta(CLOCKED, kept)
	return kept[s]


## `base`, as a copy that ripens at `times` ([ripe from, ripe length], in seconds on the farm's clock): one copy
## for each material and times, kept while anything is drawn with it.
static func timed_material(base: ShaderMaterial, times: Array) -> ShaderMaterial:
	var key := "%d|%.0f|%.0f" % [base.get_instance_id(), times[0], times[1]]
	if not _timed.has(key):
		if _timed.size() >= TIMED_KEPT:
			drop_unused_timed()
		var m := base.duplicate() as ShaderMaterial
		for k in TIMES.size():
			m.set_shader_parameter(TIMES[k], float(times[k]))
		_timed[key] = m
	return _timed[key]


## Forgets the timed materials nothing is drawn with any more (each harvest starts a new one). Returns how
## many are still kept.
static func drop_unused_timed() -> int:
	for key: String in _timed.keys():
		var m: ShaderMaterial = _timed[key]
		_timed.erase(key)
		if m.get_reference_count() > 1:   # (something else holds it: a part is drawn with it)
			_timed[key] = m
	return _timed.size()


## A decoration's look: its kind, one of a few variants by where it stands (`look`), and the mastered crop or
## flower a sign or bunch shows (`shows`).
static func decor_look(id: String, look: int, shows: String) -> Node3D:
	return Instancer.copy_of(decor_key(id, look, shows), func() -> Node3D: return _decor_built(id, look, shows))


## What a thing shows of the farm's own story, as part of its look: the mastered crop on a sign, a bunch's flower,
## and the farmhouse's stage (it grows as the farmer's level does: Game.farmhouse_stage).
static func shows_of(o: Dictionary) -> String:
	if str(o["id"]) == FARMHOUSE:
		return STAGE + str(Game.farmhouse_stage())
	if Game.kind_of(o) == "vehicle":
		var id := str(o["id"])   # (its rust shows in its paint, VehicleModel.build; in for repair, it is built again)
		return RUST + str(Game.rust.level(id)) + (REPAIRING if Game.rust.repairing(id) else "")
	return str(o.get("crop", o.get("flower", "")))


## What a decoration's look is kept under (its kind, which of its looks, and what a sign or bunch shows).
static func decor_key(id: String, look: int, shows: String) -> String:
	return Instancer.key_of(["decor", id, look, shows, Game.mastery.colour_of(shows)])


## The decorations' builders (DecorModel), loaded by path when a look must be built: a look ModelStore keeps never
## needs them, so the start does not compile them (docs/PERF_RUN.md, the start).
static func decor_model() -> GDScript:
	return load(DECOR_MODEL)


static func _decor_built(id: String, look: int, shows: String) -> Node3D:
	var fp := Game.footprint(id)
	var built: Node3D = decor_model().build(Game.item_data(id), fp, {"uid": look, "crop": shows})
	if not id.ends_with("_tree"):   # (a tree's crown overhangs by design)
		built = SpaceFit.fit_model(built, fp)
	return built


## A building's look at `level`, broken or not: one model with every state in it (at work or not, how full:
## BuildingModel.show_state, or AssetRegistry.apply_state with `state_of`).
static func building_look(id: String, level: int, broken := false) -> Node3D:
	var it := Game.item_data(id)
	var fp := Game.footprint(id)
	return Instancer.copy_of(Instancer.key_of(["building", id, level, broken]),
		func() -> Node3D: return ModelKit.bake(BuildingSpec.model().build(it, fp, level, true, broken)))


## Every look a farm may show that is worth having ready before it is asked for (CI keeps them in the game,
## ModelStore): every building at every level (at work and idle; the Barn broken too), every decoration's
## variants, every tree's variants, ripe and not, standing alone. Returns how many. Each is built (or loaded)
## once, through the same calls the farm makes, so the keys always match.
static func make_every_look() -> int:
	var made := 0
	for id: String in Game.item_order:
		if AssetRegistry.has_model(id):
			continue   # (made as a file: nothing to build)
		var kind := Game.kind_of({"id": id})
		var looks: Array[Node3D] = []
		match kind:
			"tree":
				for look in Instancer.VARIANTS:
					looks.append(tree_look(id, 0, look))
			"decor":
				if Game.links.group_of(id) == "":
					for look in (Instancer.VARIANTS if VARIED_DECOR.has(id) else 1):
						looks.append(decor_look(id, look, ""))
			"building", "barn", "crafting":
				for level in range(1, maxi(Game.max_level(id), 1) + 1):
					looks.append(building_look(id, level))
				if kind == "barn":
					looks.append(building_look(id, 1, true))
		for n in looks:
			n.free()
		made += looks.size()
	return made


func _build(o: Dictionary) -> Node3D:
	var it := Game.item_data(o["id"])
	var fp := Game.footprint(o["id"])
	var node: Node3D
	var batch := {}        # a thing drawn in a batch: what Instancer.pieces_of made of its model..
	var batch_look := ""   # ..and the look it shares its batches by
	var turn := Basis.IDENTITY   # what a tree is turned and sized by, about its own base
	if Game.kind_of(o) == "animal" or o.get("stray", false):
		var a := Animal3D.create(it, null, Vector3(int(o["col"]) + fp.x / 2.0, 0, int(o["row"]) + fp.y / 2.0))
		a.set_meta("uid", int(o["uid"]))
		a.behaviour = _mind_of(a)
		a.update(0.0)
		return a
	# Made as a file (AssetRegistry), in this thing's state; else its code-built stand-in.
	node = AssetRegistry.instance(str(o["id"]), state_of(o)) if uses_file(o) else null
	if node != null:
		if Game.kind_of(o) == "tree" and Crowding.mask(o) == 0:
			turn = _tree_turn(o)   # (as a built tree: turned and sized a little, each its own)
		if Game.is_building_item(str(o["id"])):
			mark_parts(node)
			GateSign.hang(node)
			if BuildingFill.shows(o):
				node.add_child(BuildingFill.create(o, node))
	else:
		match Game.kind_of(o):
			"tree":
				# One of a few built looks of this kind (Instancer), turned and sized a little for this one.
				var look := Instancer.variant(int(o["row"]), int(o["col"]))
				var grown := ScaleGuide.factor(str(o["id"]))
				var mask := Crowding.mask(o)
				node = tree_look(str(o["id"]), mask, look, true, may_build())   # (ready or not: its fruit grows, `ripen`)
				# (A tree with neighbours is neither turned nor resized: which of its sides they cover is part of
				# its look, and its crown must not reach into theirs.)
				if mask == 0:
					turn = _tree_turn(o)
			"vehicle":
				node = SpaceFit.fit_model(VehicleModel.build(it, Game.under_construction(o), false,
					Game.rust.level(str(o["id"]))), fp)
				node.visible = not Game.vehicles.is_running(str(o["id"]))   # (out at work: it is drawn driving)
			"decor":
				if Game.links.group_of(str(o["id"])) != "":
					node = Node3D.new()   # drawn by the LinkLayer, which joins it to its neighbours; this stands in for taps
				else:
					# Built once per look and shared (Instancer): what a piece's look depends on is its kind, one of a
					# few variants by where it stands (for the ones drawn a little differently each time), and the
					# mastered crop or flower a sign or bunch shows.
					# (Only the kinds built a little differently each time have looks: the rest were being built
					# eight times over, the same each time, and so many looks overflowed what the Instancer keeps.)
					var look := Instancer.variant(int(o["row"]), int(o["col"])) if VARIED_DECOR.has(str(o["id"])) else 0
					var shows := shows_of(o)
					if VARIED_DECOR.has(str(o["id"])) or stands_alone(str(o["id"])):
						node = decor_look(str(o["id"]), look, shows)
					else:
						# Drawn in a batch with every other of its look (DecorLayer): here it is only a stand-in,
						# standing where its model would, with the box round it for taps.
						batch = Instancer.pieces_of(decor_key(str(o["id"]), look, shows),
							func() -> Node3D: return _decor_built(str(o["id"]), look, shows))
						batch_look = decor_key(str(o["id"]), look, shows)
						node = Node3D.new()
						node.transform = batch["root"]
						node.set_meta(BOX, batch["box"])
						node.set_meta(PIECES, batch["pieces"])
			"young":
				node = SpaceFit.fit_model(YoungModel.build(it, o, Game.nurture.growth(o)), fp)
			"bloom":
				# One of a few looks (Instancer), as for trees: from its file when it stands on its own.
				# (one look whether in bud, in bloom or withered: its shader shows its life by the clock, `ripen`)
				node = PaintedBloom.create(str(o["id"]), fp)   # (flowers are painted pictures, as crops are)
			_:
				if Game.under_construction(o):
					node = ModelKit.bake(BuildingSpec.model().build_site(it, fp, Game.land.construction_progress(o)))
				else:
					node = building_look(str(o["id"]), Game.look_level(o), bool(o.get("broken", false)))
					GateSign.hang(node)
					AssetRegistry.apply_state(node, state_of(o))
					if BuildingFill.shows(o):
						node.add_child(BuildingFill.create(o, node))
	# The view stands at the footprint's centre on the ground, so it squashes, bounces and lands about
	# its base; the model hangs under it, shifted back to the footprint's corner.
	var holder := Node3D.new()
	holder.position = Vector3(int(o["col"]) + fp.x / 2.0, 0, int(o["row"]) + fp.y / 2.0)
	var centre := Vector3(fp.x / 2.0, 0, fp.y / 2.0)
	var basis := turn
	if o.get("flip", false):
		# Turned: mirrored across the footprint's diagonal (square things only turn), as the 2D art flips
		# left to right on screen.
		basis = Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)) * turn
	# (What the model was already moved and shrunk by to sit inside its tile border, SpaceFit.fit_model, stays.)
	node.transform = Transform3D(basis, -(basis * centre)) * node.transform
	holder.add_child(node)
	if not batch.is_empty():
		_batch(holder, node, o, batch, batch_look)
	_dress(holder, node, o, fp)
	return holder


## Hands a batched decoration's model to the DecorLayer, where the stand-in `node` under `holder` stands, and
## takes it back out when the stand-in goes.
func _batch(holder: Node3D, node: Node3D, o: Dictionary, batch: Dictionary, look: String) -> void:
	var uid := int(o["uid"])
	var layer := _decor_layer()
	var serial := layer.put(uid, look, batch["pieces"], holder.transform * node.transform, holder.position)
	holder.tree_exiting.connect(func() -> void:
		if is_instance_valid(layer):
			layer.remove(uid, serial))


## The grass, flowers and stones round anything that has them (Dressing, data/dressing.json: buildings, vehicles,
## decorations): one of a few shared looks per kind and footprint (by its uid), drawn in batches by the
## DecorLayer with every other alike, not a draw of its own per thing; where the model `node` under `holder`
## stands (turned with it), hidden with it (`_show`), and taken out when it goes.
func _dress(holder: Node3D, node: Node3D, o: Dictionary, fp: Vector2i) -> void:
	var kind := Game.kind_of(o)
	if not Dressing.has_kind(kind):
		return
	var uid := int(o["uid"])
	var round_it := posmod(uid, DRESSINGS)
	var key := Instancer.key_of(["dressing", kind, fp.x, fp.y, round_it])
	var dress := Instancer.pieces_of(key, func() -> Node3D: return Dressing.make(kind, fp, round_it))
	if (dress["pieces"] as Array).is_empty():
		return
	var layer := _decor_layer()
	var serial := layer.put(dressing_id(uid), key, dress["pieces"], holder.transform * node.transform, holder.position)
	holder.tree_exiting.connect(func() -> void:
		if is_instance_valid(layer):
			layer.remove(dressing_id(uid), serial))


## A standing decoration's contact shade on the grass (GroundShade), as animals have; `box` is round it in this
## node's space. Joined pieces (fences, paths), flat and large things get none.
func _ground(holder: Node3D, o: Dictionary, box: AABB) -> void:
	if Game.kind_of(o) != "decor" or Game.links.group_of(str(o["id"])) != "":
		return
	var local := holder.transform.affine_inverse() * box
	if GroundShade.fits(local):
		holder.add_child(GroundShade.under(local))


## The layer that draws things in batches (made here when asked before this was in the tree: tests).
func _decor_layer() -> DecorLayer:
	if decor == null:
		decor = DecorLayer.new()
		add_child(decor)
	return decor


## The DecorLayer's number for the grass and stones round decoration `uid` (its model's is the uid itself).
static func dressing_id(uid: int) -> int:
	return -(uid + 1)




## Woods along the back two sides of the farm (FarmGrid.scenery(), the same spots as the 2D world).
func _build_scenery() -> void:
	for c in _scenery.get_children():
		c.queue_free()
	_drop_woods()
	var n := Game.farm_size
	# The trees are built in groups by area and each group baked into a few draws, so the woods cost tens of draws
	# and not thousands, while a group off screen is still culled whole. They go up over a few frames (at most
	# BUILD_BUDGET_MS of building a frame, `_grow_woods`), so opening a farm never waits for its woods.
	var cells := {}   # cell -> [[r, c, kind]]
	for t in FarmGrid.scenery():
		var r: float = t[0]
		var c: float = t[1]
		if (r >= -1.0 and c >= -1.0) or r > n + 4 or c > n + 4:
			continue
		var cell := Vector2i(int(floor(c / SCENERY_CELL)), int(floor(r / SCENERY_CELL)))
		if not cells.has(cell):
			cells[cell] = []
		(cells[cell] as Array).append(t)
	for cell in cells:
		# A group kept on disk (ModelStore) stands at once; the others are built over the next frames.
		var key := Instancer.key_of(["woods", n, cell, cells[cell]])
		var kept := ModelStore.fetch(key)
		if kept != null:
			_scenery.add_child(kept)
		else:
			_woods.append([Node3D.new(), cells[cell], key])
	_grow_woods()


## Builds trees of the woods for at most BUILD_BUDGET_MS; a group finished is baked and stands.
func _grow_woods() -> void:
	var began := Time.get_ticks_msec()
	while not _woods.is_empty() and Time.get_ticks_msec() - began <= BUILD_BUDGET_MS:
		var group: Array = _woods[0]
		var trees: Array = group[1]
		if trees.is_empty():
			var baked := ModelKit.bake(group[0])
			ModelStore.keep(str(group[2]), baked)
			_scenery.add_child(baked)
			_woods.pop_front()
			continue
		_scenery_tree(group[0], trees.pop_back())


## Woods not yet up are dropped (and their half-built groups freed): the farm grew, or the layer is going.
func _drop_woods() -> void:
	for group: Array in _woods:
		(group[0] as Node3D).free()
	_woods.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_drop_woods()


## One tree of the woods round the farm, under `holder`.
func _scenery_tree(holder: Node3D, t: Array) -> void:
	var r: float = t[0]
	var c: float = t[1]
	var at := Vector3(c + 0.5, SCENERY_Y, r + 0.5)
	match str(t[2]):
		"pine_tree":
			pine(holder, at, 1.0 + fposmod(r * 7.0 + c * 3.0, 0.5))
		"willow_tree":
			TreeSpec.builder().build_at(holder, at, {"id": "willow"}, 1.15, false, int(r * 31 + c), false, TreeSpec.UNSET,
				GROVE_MASK)
		_:
			TreeSpec.builder().build_at(holder, at, {"id": str(t[2])}, 1.2, false, int(r * 31 + c), false, TreeSpec.UNSET,
				GROVE_MASK)




## A pine: a short trunk and five stacked, overlapping skirts of needles, widest and darkest at the bottom,
## each turned a little from the one below, so the outline is ragged like a real conifer's.
static func pine(parent: Node3D, base: Vector3, size: float) -> void:
	var root := Node3D.new()
	root.position = base
	parent.add_child(root)
	ModelKit.cylinder(root, Vector3.ZERO, PINE_TRUNK_R * size, 0.22 * size, ModelKit.paint(TreeSpec.BARK), -1.0, 6)
	for k in PINE_TIERS:
		var up := float(k) / (PINE_TIERS - 1)
		var y := (0.14 + 0.2 * k) * size
		var r := lerpf(0.5, 0.14, up) * size
		var skirt := ModelKit.cylinder(root, Vector3(0, y, 0), r, lerpf(0.46, 0.34, up) * size,
			ModelKit.paint(PINE.darkened(0.16 * (1.0 - up)).lightened(0.06 * up)), 0.0, 8 + (k % 2))
		skirt.rotation.y = k * 0.7
	ModelKit.sway_all(root, TreeSpec.SWAY)  # bends in the wind like every tree


# ---------------------------------------------------------------- placing


## While something is being placed: a see-through copy of it follows the finger, green where it fits and
## red where it doesn't (or soft white over a home it would move into), and the thing being moved hides.
func _update_placing() -> void:
	var placing: Dictionary = grid.placing if grid != null else {}
	var lifted := int(placing.get("uid", -1))
	if lifted != _lifted:
		_show(_lifted, true)
		_show(lifted, false)
		_lifted = lifted
	if placing.is_empty() or int(placing.get("row", -1)) < 0:
		_clear_ghost()
		return
	var item := str(placing["item"])
	if placing.has("line"):
		_update_line_ghost(placing)
		return
	var row := int(placing["row"])
	var col := int(placing["col"])
	var home := int(placing.get("home", -1)) != -1
	var ok := home or Game.can_place(item, row, col, lifted)
	# The model is built once per thing being carried; whether it fits changes only its tint (rebuilding a
	# building's model every time the finger crosses an edge made carrying it stutter).
	var group := Game.links.group_of(item)
	var mask := Game.links.mask_at(group, row, col, lifted) if group != "" else 0
	var shape := LinkShape.of(mask)
	var variant := LinkModels.variant_at(row, col)
	var key := "%s|%d|%d|%d" % [item, lifted, mask, variant] if group != "" else "%s|%d" % [item, lifted]
	if key != _ghost_key:
		var snapping := group != "" and _ghost != null and _ghost_mask != mask
		_clear_ghost()
		_ghost_key = key
		_ghost_mask = mask
		var fake := {"uid": -1, "id": item, "row": 0, "col": 0, "level": 1}
		if lifted != -1:
			fake = Game.object_by_uid(lifted).duplicate()
			fake["row"] = 0
			fake["col"] = 0
		if group != "":
			# A piece in hand shows the shape it will take where it's held, and settles into it as the shape changes.
			_ghost = Node3D.new()
			_ghost.add_child(LinkModels.node(Game.item_data(item), shape.x, variant))
			_ghost.rotation.y = LinkShape.yaw(shape.y)
			if snapping:
				_ghost.scale = Vector3(1.1, 0.88, 1.1)
				var tw := create_tween()
				tw.tween_property(_ghost, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_ghost = _build(fake)
		if _ghost is Animal3D:
			_ghost.set_meta("uid", -1)  # a ghost has no mind: it stands still
		_ghost_tint = ""
		add_child(_ghost)
	var tint := "home" if home else ("ok" if ok else "bad")
	if tint != _ghost_tint:
		_ghost_tint = tint
		_tint_with(_ghost, _ghost_material(tint))
	var fp := Game.footprint(item)
	var lift := 0.25 if home else 0.0  # hovering over a home, it floats just above it
	if _ghost is Animal3D:
		(_ghost as Animal3D).home = Vector3(col + fp.x / 2.0, lift, row + fp.y / 2.0)
		_ghost.position = (_ghost as Animal3D).home
	else:
		_ghost.position = Vector3(col + fp.x / 2.0, lift, row + fp.y / 2.0)




## A line of fence (or hedge, wall, path) being laid: each piece shows the shape it will take once the whole
## line stands, joined to itself and to what's beside it, green where it will be laid and red where it won't
## (taken, or more than the coins reach). Rebuilt only when something in it changes; the meshes are shared.
func _update_line_ghost(placing: Dictionary) -> void:
	var item := str(placing["item"])
	var group := Game.links.group_of(item)
	var line: Array = placing["line"]
	var oks: Array = placing.get("line_ok", [])
	var planned := {}
	for t: Vector2i in line:
		planned[Game.index_of(t.x, t.y)] = group
	var key := item
	var cells: Array = []
	for i in line.size():
		var t: Vector2i = line[i]
		var mask := Game.links.mask_at(group, t.x, t.y, -1, planned)
		var good: bool = i < oks.size() and oks[i]
		cells.append([t, mask, good])
		key += "|%d,%d,%d,%d" % [t.x, t.y, mask, 1 if good else 0]
	if key == _ghost_key:
		return
	_clear_ghost()
	_ghost_key = key
	_ghost = Node3D.new()
	add_child(_ghost)
	for cell: Array in cells:
		var t: Vector2i = cell[0]
		var shape := LinkShape.of(int(cell[1]))
		var piece := Node3D.new()
		piece.position = Vector3(t.y + 0.5, 0, t.x + 0.5)
		piece.rotation.y = LinkShape.yaw(shape.y)
		piece.add_child(LinkModels.node(Game.item_data(item), shape.x, LinkModels.variant_at(t.x, t.y)))
		_tint_with(piece, _ghost_material("ok" if cell[2] else "bad"))
		_ghost.add_child(piece)


func _clear_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_ghost_key = ""
	_ghost_tint = ""


## The see-through material a carried thing is drawn in: green where it fits, red where it doesn't, white over
## a home that takes it. Made once and shared.
static func _ghost_material(tint: String) -> Material:
	if not _ghost_materials.has(tint):
		var col := Color(1, 1, 1, 0.5)
		if tint == "ok":
			col = Color(0.5, 1.0, 0.5, 0.6)
		elif tint == "bad":
			col = Color(1.0, 0.4, 0.35, 0.6)
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost_materials[tint] = m
	return _ghost_materials[tint]




func _show(uid: int, on: bool) -> void:
	_links.set_hidden(uid, not on)
	decor.set_hidden(uid, not on)
	decor.set_hidden(dressing_id(uid), not on)
	var v: Dictionary = _views.get(uid, {})
	if v.has("node"):
		(v["node"] as Node3D).visible = on




static func _tint(node: Node, col: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tint_with(node, m)




static func _tint_with(node: Node, m: Material) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).material_override = m
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_tint_with(c, m)




# ---------------------------------------------------------------- touch and reactions


## The object drawn under a screen point: the nearest one along the ray from the camera, tested against
## each object's box (an animal's box goes where the animal is now). -1 if none.
func pick(camera: Camera3D, screen_pos: Vector2) -> int:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var best := -1
	var best_d := INF
	for uid in _views:
		var v: Dictionary = _views[uid]
		var node := v["node"] as Node3D
		if not node.visible:
			continue
		var d := INF
		if v.has("crown"):
			d = _tree_hit(v["crown"], from, dir)
		elif node is Animal3D:
			d = (node as Animal3D).hit(from, dir)
		else:
			for part: AABB in v["parts"]:
				d = minf(d, _ray_to(part, from, dir))
		if d == INF:
			continue
		# Animals sit in front of what they stand by: they win close calls with buildings behind them.
		if node is Animal3D:
			d -= 0.5
		if d < best_d:
			best_d = d
			best = int(uid)
	return best




## The water in what is drawn at a view: its biggest sheet of the kit's water, as {"at": the middle of its
## surface, "reach": its half sizes, "pond": whether it is a pond, with a shore}, all in `holder`'s own space;
## {} when it has none. A batched decoration's meshes are the DecorLayer's (meta PIECES on its stand-in).
static func water_in(holder: Node3D) -> Dictionary:
	var sheets: Array = []   # [mesh, where it is in the holder, its instance or null, the material over it all]
	var stand := holder.get_child(0) as Node3D if holder.get_child_count() > 0 else null
	if stand != null and stand.has_meta(PIECES):
		for piece: Dictionary in stand.get_meta(PIECES):
			sheets.append([piece["mesh"], stand.transform * (piece["xf"] as Transform3D), null, piece["material"]])
	else:
		for mi: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):  # not-ui
			if mi.mesh != null:
				sheets.append([mi.mesh, _local_to(holder, mi), mi, null])
	var best := {}
	var most := 0.0
	for sheet: Array in sheets:
		var mesh: Mesh = sheet[0]
		var mi := sheet[2] as MeshInstance3D
		for k in mesh.get_surface_count():
			var mat: Material = sheet[3]
			if mat == null:
				mat = mi.get_active_material(k) if mi != null else mesh.surface_get_material(k)
			if mat != ModelKit.pond_water() and mat != ModelKit.water():
				continue
			# (that surface's own reach: a file's mesh holds the whole building, the water one surface of it)
			var points: PackedVector3Array = mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX]
			if points.is_empty():
				continue
			var to_here: Transform3D = sheet[1]
			var box := AABB(to_here * points[0], Vector3.ZERO)
			for point in points:
				box = box.expand(to_here * point)
			if box.size.x * box.size.z > most:
				most = box.size.x * box.size.z
				best = {"at": Vector3(box.get_center().x, box.end.y, box.get_center().z),
					"reach": Vector2(box.size.x, box.size.z) / 2.0, "pond": mat == ModelKit.pond_water()}
	return best


## Notes the water a building or a decoration has, and brings a pond to life: its own PondLife, and its animals
## swim on it (BuildingFill.set_water).
func _dress_water(uid: int, o: Dictionary) -> void:
	var v: Dictionary = _views[uid]
	var def := Game.catalog.get_def(str(o["id"]))
	if not (def is BuildingDef or def is DecorationDef) or Game.under_construction(o):
		return
	var node: Node3D = v["node"]
	var water := water_in(node)
	v["water"] = water
	if water.is_empty() or not water["pond"]:
		return
	node.add_child(PondLife.create(water["at"], water["reach"], uid, _rings))
	var fill := v.get("fill") as BuildingFill
	if fill != null:
		var here := fill.global_transform.affine_inverse() * node.global_transform
		fill.set_water(here * (water["at"] as Vector3), (water["reach"] as Vector2) * here.basis.get_scale().x, _rings)


## The water of thing `uid` was tapped, at `at` on the ground: a splash there, or in its middle when the tap fell
## beside it (a basin stands above the ground). Nothing on ice.
func splash(uid: int, at: Vector3) -> void:
	var v: Dictionary = _views.get(uid, {})
	var water: Dictionary = v.get("water", {})
	if water.is_empty() or PondLife.frozen():
		return
	var node: Node3D = v["node"]
	var centre: Vector3 = water["at"]
	var reach: Vector2 = water["reach"]
	var tap := node.to_local(at)
	var off := Vector2((tap.x - centre.x) / reach.x, (tap.z - centre.z) / reach.y)
	var where := Vector3(tap.x, centre.y, tap.z) if water["pond"] and off.length() < 0.85 else centre
	_rings.splash(node.to_global(where) + Vector3(0, 0.004, 0), clampf(minf(reach.x, reach.y) / 0.6, 0.3, 1.0))


## The rings on water (for tests and tools).
func rings_node() -> WaterRings:
	return _rings


## Fireworks over building `uid`, which has just grown (Fireworks3D): a small burst, or a show for the Barn.
func fireworks_over(uid: int) -> void:
	var o := Game.object_by_uid(uid)
	if o.is_empty() or not _views.has(uid):
		return
	var box: AABB = _views[uid]["box"]
	_fireworks.launch(Vector3(box.get_center().x, box.end.y, box.get_center().z),
		Game.building_def(str(o["id"])).grand())


## The fireworks (for tests and tools).
func fireworks_node() -> Fireworks3D:
	return _fireworks


## The rusty vehicle whose sign is under a screen point ("" if none).
func pick_rust(camera: Camera3D, screen_pos: Vector2) -> String:
	return _rust_marks.pick(camera, screen_pos)


## The outline of a thing on screen, in the farm grid's space: the hull of its parts' boxes as the camera sees
## them (built once per view, since the parts don't change until it is rebuilt). Empty if it has no view.
func outline_of(uid: int) -> PackedVector2Array:
	var v: Dictionary = _views.get(uid, {})
	if v.is_empty():
		return PackedVector2Array()
	if not v.has("outline"):
		var points := PackedVector2Array()
		for part: AABB in v["parts"]:
			for corner in 8:
				points.append(IsoProjection.grid_of(part.get_endpoint(corner)))
		v["outline"] = Geometry2D.convex_hull(points)
	return v["outline"]


## What a tap on a tree lands on: its crown as an ellipsoid and its trunk, not the box round them all (whose empty
## corners would catch taps meant for the neighbour behind or beside it).
func _crown_of(box: AABB) -> Dictionary:
	var top := box.end.y
	var centre := Vector3(box.get_center().x, lerpf(box.position.y, top, TREE_CROWN_AT), box.get_center().z)
	var radii := Vector3(box.size.x * 0.5 * TREE_CROWN_FILL, (top - centre.y) * TREE_CROWN_FILL,
		box.size.z * 0.5 * TREE_CROWN_FILL)
	var trunk := AABB(Vector3(centre.x - TREE_TRUNK_HALF, box.position.y, centre.z - TREE_TRUNK_HALF),
		Vector3(TREE_TRUNK_HALF * 2.0, centre.y - box.position.y, TREE_TRUNK_HALF * 2.0))
	return {"centre": centre, "radii": radii, "trunk": trunk}


## How far along the ray a tree is met, or INF. Among crowns that overlap on screen the one tapped nearer its
## middle wins (the depth is nudged by how far off-centre the ray is), so a grove is easy to pick tree by tree.
static func _tree_hit(crown: Dictionary, from: Vector3, dir: Vector3) -> float:
	var radii: Vector3 = crown["radii"]
	var centre: Vector3 = crown["centre"]
	var o := (from - centre) / radii      # the ray in the space where the crown is a unit ball
	var dv := dir / radii
	var a := dv.dot(dv)
	var b := o.dot(dv)
	var closest := b / a
	var miss := (o - dv * closest).length()
	var best := INF
	if miss < 1.0:
		var half := sqrt(maxf(1.0 - miss * miss, 0.0) / a)
		best = maxf(-closest - half, 0.0) * dir.length()
		best += miss * TREE_CENTRE_BIAS
	var trunk := _ray_to(crown["trunk"], from, dir)
	# (A tap that lands on the thin trunk is plainly meant for it, so it beats any crown beside or in front.)
	return minf(best, trunk - TREE_CENTRE_BIAS * 2.0) if trunk != INF else best


## How far along the ray it meets the box (INF if it misses).
static func _ray_to(box: AABB, from: Vector3, dir: Vector3) -> float:
	var hit: Variant = box.intersects_ray(from, dir)
	return from.distance_to(hit) if hit != null else INF


## What a tap can land on, as boxes in the farm's space. A finished building is its walls and roof, its
## low yard and fence, and each thing standing beside it (a silo, an annex): not one box round it all,
## whose empty corners would catch taps meant for the animal standing behind its yard.
func _parts(node: Node3D, o: Dictionary) -> Array[AABB]:
	if node is Animal3D or not Game.is_home(o) or Game.under_construction(o) or node.get_child_count() == 0:
		return [_bounds(node, o)]
	var model := node.get_child(0) as Node3D
	var fp := Game.footprint(o["id"])
	var spec := BuildingSpec.spec(str(o["id"]), Game.look_level(o))
	var out: Array[AABB] = [node.transform * (model.transform * AABB(Vector3.ZERO, Vector3(fp.x, YARD_HEIGHT, fp.y)))]
	var taken := BuildingSpec.taken(spec, fp)
	var body: Dictionary = spec["body"]
	var roof: Dictionary = spec["roof"]
	for k in taken.size():
		var r: Rect2 = taken[k]
		var top := PART_HEIGHT
		if k == 0 and float(body.get("w", 0.0)) > 0.0:
			# The main block: its walls, its roof, and what stands on the roof.
			top = float(body.get("h", 0.85)) + float(roof.get("pitch", 0.75)) * minf(r.size.x, r.size.y) / 2.0 \
				+ ROOF_EXTRAS
		out.append(node.transform * (model.transform * AABB(Vector3(r.position.x, 0, r.position.y),
			Vector3(r.size.x, top, r.size.y))))
	return out


## The box around a model, in the farm's space (for an animal, around its feet, to move with it).
func _bounds(node: Node3D, o: Dictionary) -> AABB:
	var group := Game.links.group_of(str(o["id"]))
	if group != "":
		# A joined piece's stand-in: its tile, as tall as the piece (a path is flat, so taps pass through to what's behind).
		return node.transform * AABB(Vector3(-0.5, 0, -0.5), Vector3(1, Linking.setting(group, "tall", 0.3), 1))
	if node is Animal3D:
		var r := (node as Animal3D).reach()
		return AABB(Vector3(-r.x, 0, -r.x), Vector3(r.x * 2.0, r.y, r.x * 2.0))
	var box := AABB()
	var first := true
	for model in node.get_children():
		if model.has_meta(BOX):   # a batched thing's stand-in: the box round its model, kept when it was taken apart
			return node.transform * ((model as Node3D).transform * (model.get_meta(BOX) as AABB))
		for c in model.get_children():
			if c is MeshInstance3D:
				var b := (model as Node3D).transform * ((c as MeshInstance3D).transform * (c as MeshInstance3D).get_aabb())
				box = b if first else box.merge(b)
				first = false
	if first:
		var fp := Game.footprint(o["id"])
		box = AABB(Vector3(-fp.x / 2.0, 0, -fp.y / 2.0), Vector3(fp.x, 0.3, fp.y))
	return node.transform * box




## Tapped: it squashes down and springs back (from its base, so it stays on the ground).
func bounce(uid: int) -> void:
	if _links.has_piece(uid):
		_links.pulse(uid)
		return
	if decor.has_piece(uid):
		decor.pulse(uid)
		return
	var node := _node(uid)
	if node == null:
		return
	var base := Vector3.ONE
	var tw := _tween(node)
	tw.tween_property(node, "scale", base * Vector3(1.12, 0.84, 1.12), 0.07).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base * Vector3(0.95, 1.08, 0.95), 0.09).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	UiFx.settle(tw, node, "scale", base)




## Finished or upgraded: it swells up past its size and settles back, with sparkles at its feet.
func grow_in(uid: int, grand: bool) -> void:
	var node := _node(uid)
	if node == null:
		return
	node.scale = Vector3.ONE * 0.82
	var tw := _tween(node)
	tw.tween_property(node, "scale", Vector3.ONE * Vector3(1.1, 1.14, 1.1), 0.16).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	UiFx.settle(tw, node, "scale", Vector3.ONE, UiFx.SETTLE_TIME * 1.25)   # (a grown building, a touch slower)
	transformed.emit(node.position, grand)


## A mystery young one opens (the reveal): where it stood it shakes three times, each harder, swells and is gone,
## and what it grew into (`grown_uid`, -1 when that went to the Barn) swells up in its place; `then` is called at
## the opening, for its words and sparks. Called right after it grew, before the look that finds it gone: that
## look keeps its model for the shaking instead of removing it, and builds the grown one hidden until then.
func hatch(young_uid: int, grown_uid: int, then: Callable) -> void:
	if not _views.has(young_uid):
		then.call()
		return
	_hatching[young_uid] = {"into": grown_uid, "then": then}
	if grown_uid >= 0:
		_unopened[grown_uid] = true


func _shake_open(young_uid: int) -> void:
	var h: Dictionary = _hatching[young_uid]
	_hatching.erase(young_uid)
	var node: Node3D = _views[young_uid]["node"]
	var home := node.position
	var tw := _tween(node)
	for k in HATCH_SHAKES:
		var reach := HATCH_REACH * (k + 1)
		tw.tween_callback(func() -> void: Feedback.moment("reveal_shake"))
		tw.tween_property(node, "position:x", home.x + reach, 0.05)
		tw.parallel().tween_property(node, "scale", Vector3(1.06, 0.94, 1.06), 0.05)
		tw.tween_property(node, "position:x", home.x - reach, 0.1)
		tw.tween_property(node, "position:x", home.x, 0.05)
		tw.parallel().tween_property(node, "scale", Vector3.ONE, 0.05)
		tw.tween_interval(HATCH_REST)
	tw.tween_property(node, "scale", Vector3.ONE * 1.3, 0.09).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		node.queue_free()
		var into := int(h["into"])
		_unopened.erase(into)
		var grown := _node(into)
		if grown != null:
			grown.visible = true
			grow_in(into, true)
		(h["then"] as Callable).call())


## Newly on the farm: it falls in from above, lands with a squash and settles.
func drop_in(uid: int) -> void:
	if _links.has_piece(uid):
		if Engine.get_process_frames() != _link_landed:   # a line is one thud, not forty
			_link_landed = Engine.get_process_frames()
			landed.emit(_node(uid).position)
		return   # the layer drops the piece itself
	if decor.has_piece(uid):
		decor.pulse(uid, true)   # (the layer drops it: its batch's instance falls and settles)
		landed.emit(_node(uid).position)
		return
	var node := _node(uid)
	if node == null or node is Animal3D:
		if node is Animal3D:
			(node as Animal3D).land()
		return
	var base := Vector3.ONE
	var ground := node.position
	node.position = ground + Vector3(0, DROP_HEIGHT, 0)
	node.scale = base * Vector3(0.88, 1.15, 0.88)
	var tw := _tween(node)
	tw.tween_property(node, "position", ground, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "scale", base * Vector3(1.14, 0.82, 1.14), 0.07).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	UiFx.settle(tw, node, "scale", base)
	landed.emit(ground)




## What shows how full building `uid` is (null for things that show nothing of what's inside).
func fill_of(uid: int) -> BuildingFill:
	var node := _node(uid)
	if node == null or node.get_child_count() == 0:
		return null
	for c in node.get_child(0).get_children():
		if c is BuildingFill:
			return c
	return null


## Collected: the building's doors open and what it made pops off (BuildingFill.celebrate).
## A harvested tree shakes: it rocks to and fro about its foot and comes to rest (TreeLife).
## How tall object `uid` stands on the farm (the top of its view's box, kept since it was shown: nothing is built
## or measured), or 0 if it is not shown.
func height_of(uid: int) -> float:
	var v: Dictionary = _views.get(uid, {})
	return (v["box"] as AABB).end.y if v.has("box") else 0.0


func shake(uid: int) -> void:
	var node := _node(uid)
	if node == null:
		return
	var tw := _tween(node)
	for lean: float in SHAKE_LEANS:
		tw.tween_property(node, "rotation:z", lean, SHAKE_BEAT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "rotation:z", 0.0, SHAKE_BEAT)


func celebrate(uid: int) -> void:
	var fill := fill_of(uid)
	if fill != null:
		fill.celebrate()


func _node(uid: int) -> Node3D:
	var v: Dictionary = _views.get(uid, {})
	return v.get("node") as Node3D




func _tween(node: Node3D) -> Tween:
	if node.has_meta("tween"):
		var old: Tween = node.get_meta("tween")
		if old != null and old.is_valid():
			old.kill()
	var tw := node.create_tween()
	node.set_meta("tween", tw)
	return tw
