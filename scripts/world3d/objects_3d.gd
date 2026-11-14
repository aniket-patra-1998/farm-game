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
const DRESSING := ^"dressing_round"   # the name of the grass and stones round an object (outside its footprint)
const TREE_SIZE_JITTER := 0.0   # each tree of a kind is this much bigger or smaller than the built look it copies
const GROUP := &"objects_3d"   # every Objects3D, for until_settled
const FULL_EVERY := 10        # a full look at everything every this many seconds (the rest only look at those)
# A sync builds models for at most this long a frame, then carries on the next frame: a farm with hundreds of
# things appears over a few frames instead of freezing (a phone says "not responding" after 5 s of that).
const BUILD_BUDGET_MS := 12
const SCENERY_Y := -Ground3D.SLAB
const SCENERY_CELL := 14.0    # woods are baked in squares this many tiles across
const GROVE_MASK := 0xff       # woods stand shoulder to shoulder: their trees are drawn crowded on every side

const PINE := Color("#2f6b3a")
const PINE_TIERS := 5        # skirts of needles on a pine
const PINE_TRUNK_R := 0.055


const STEP_LEVEL := 100       # see _step
const DROP_HEIGHT := 1.4      # tiles above the ground a new thing falls from
const YARD_HEIGHT := 0.3      # a building's yard and fence, for taps
const PART_HEIGHT := 1.0      # what stands beside a building (a silo, an annex), for taps
const ROOF_EXTRAS := 0.35     # chimneys, cupolas and vanes above the roof, for taps
const TREE_CROWN_AT := 0.6     # where a tree's crown is centred, of its height
const TREE_CROWN_FILL := 0.92  # how much of its box the pickable crown takes: the leafy outline is ragged
const TREE_TRUNK_HALF := 0.12  # half the width of the pickable trunk, in tiles
const TREE_CENTRE_BIAS := 0.6  # tiles of depth a tap at the crown's very edge is worth less than at its middle


static var _ghost_materials := {}   # tint name -> the shared see-through material

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
var _full := true        # the queued sync looks at everything (a change), not only what time changes
var _ticks := 0

var _scenery: Node3D
var _links: LinkLayer   # draws the fences, hedges, walls and paths, joined up
var _ghost_mask := -1
var _link_landed := -1   # the frame a joined piece last landed
var _woods: Array = []   # groups of the woods still going up: [holder, trees left]
var _carry_on := false  # a sync ran out of time: the rest comes next frame
var _left := 0           # objects a sync ran out of time for, still to build




static func handles(o: Dictionary) -> bool:
	return o.get("stray", false) or MODELLED.has(Game.kind_of(o))




func _ready() -> void:
	add_to_group(GROUP)
	_scenery = Node3D.new()
	add_child(_scenery)
	_links = LinkLayer.new()
	add_child(_links)
	_links.snapped.connect(func(at: Vector3, fresh: bool) -> void: snapped.emit(at, fresh))
	sync()
	Game.farm_expanded.connect(func(_n: int) -> void: _build_scenery())
	_build_scenery()
	var timer := Timer.new()
	timer.wait_time = 1.0  # trees ripen and buildings become ready over time
	timer.autostart = true
	timer.timeout.connect(_on_tick)
	add_child(timer)




## Each second: only what time changes (trees ripening, buildings filling, sites rising) is looked at again; every
## FULL_EVERY ticks everything is, in case a change was not announced.
func _on_tick() -> void:
	_ticks += 1
	if _ticks % FULL_EVERY == 0:
		queue_sync()
	elif not _queued:
		_queued = true
		sync.call_deferred()


## Whether the picture of `o` can change with time alone (not only when the player or a system changes it).
static func timed(o: Dictionary) -> bool:
	return TIMED_KINDS.has(Game.kind_of(o)) or Game.under_construction(o)


func queue_sync() -> void:
	_full = true
	if not _queued:
		_queued = true
		sync.call_deferred()




func sync() -> void:
	_queued = false
	var light := not _full   # a timer tick: only what time changes
	_full = false
	if not light:
		_links.sync(Game.objects)   # first: what's new there is already known when its stand-in drops in
	var seen := {}
	var began := Time.get_ticks_msec()
	var built := 0
	var left := 0
	for o in Game.objects:
		if not handles(o):
			continue
		var uid := int(o["uid"])
		seen[uid] = true
		if light and _views.has(uid) and not timed(o):
			continue
		var key := _key(o)
		var v: Dictionary = _views.get(uid, {})
		if v.get("key", "") == key:
			var fill := fill_of(uid)
			if fill != null:
				fill.refresh(o)  # who's in, how near ready: shown without rebuilding the building
			continue
		if Time.get_ticks_msec() - began > BUILD_BUDGET_MS:
			left += 1          # out of time this frame: built on the next
			continue
		built += 1
		if v.has("node"):
			(v["node"] as Node3D).queue_free()
		var node := _build(o)
		add_child(node)
		var fresh := not v.has("node")
		var step := _step(o)
		_views[uid] = {"node": node, "key": key, "box": _bounds(node, o), "parts": _parts(node, o), "step": step}
		if Game.catalog.get_def(str(o["id"])) is TreeDef:
			_views[uid]["crown"] = _crown_of(_views[uid]["box"])
		if not fresh and _synced_once and step > int(v.get("step", step)):
			grow_in(uid, int(v.get("step", step)) == 0)  # upgraded or finished: it swells in with a flourish
		if fresh and _synced_once:
			drop_in(uid)  # newly bought or placed: it drops onto the farm
	for uid in _views.keys():
		if not seen.has(uid):
			(_views[uid]["node"] as Node3D).queue_free()
			_views.erase(uid)
	if built > 0:
		LoadTrace.mark("objects: built %d in %d ms, %d to go" % [built, Time.get_ticks_msec() - began, left])  # not-ui
	_left = left
	if left > 0:
		_full = _full or not light
		_carry_on = true
	else:
		_synced_once = true   # (until the whole farm stands, nothing drops in: it is being laid out, not bought)
	if light and built == 0:
		return
	_animals.clear()
	for v in _views.values():
		if v["node"] is Animal3D:
			_animals.append(v["node"])


## Whether everything is built: every object, the woods, and every orchard's trees (the farm goes up over a few
## frames after it opens; screenshots and measurements wait for this).
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
		sync()
	if not _woods.is_empty():
		_grow_woods()
	_update_placing()
	var cam := get_viewport().get_camera_3d()
	for a in _animals:
		if not is_instance_valid(a):
			continue
		if a.behaviour == null:
			a.behaviour = _mind_of(a)
		a.animate(delta, cam)




func _mind_of(a: Animal3D) -> AnimalBehaviour:
	return life.mind(int(a.get_meta("uid", -1))) if life != null else null




## What a view shows: when this changes, it's rebuilt.
## How far along a building is in its life: a site counts for nothing, a finished building 100, plus 10 a level.
## (When it goes up, the building has been finished or upgraded: see grow_in.)
func _step(o: Dictionary) -> int:
	if not Game.kind_of(o) in ["building", "barn", "crafting"]:
		return 0
	return 0 if Game.under_construction(o) else STEP_LEVEL + 10 * int(o.get("level", 1))


func _key(o: Dictionary) -> String:
	if Game.links.group_of(str(o["id"])) != "":
		return "link|%s|%d|%d" % [o["id"], int(o["row"]), int(o["col"])]   # how it joins is the LinkLayer's business
	# A building site is rebuilt as each tenth of its materials goes in.
	var site := int(Game.land.construction_progress(o) * 10.0) if Game.under_construction(o) else -1
	return "%s|%d|%d|%d|%s|%d|%s|%d|%s" % [o["id"], int(o["row"]), int(o["col"]), int(o.get("level", 1)),
		o.get("flip", false), site, Game.kind_of(o) in ["tree", "bloom"] and Game.is_ready(o),
		Crowding.mask(o),
		str(o.get("crop", o.get("flower", ""))) + "|%d|%s|%s" % [int(o.get("fed", 0)), Game.is_withered(o), _at_work(o)]]




## Whether a building is at work right now: a crafting building with something in its ovens or vats. (Other
## buildings are always "at work": their chimneys, if any, smoke.)
func _at_work(o: Dictionary) -> bool:
	if not Game.crafting.is_crafting(o):
		return true
	return Game.crafting.crafts_done(o) < (o.get("slots", []) as Array).size()


func _build(o: Dictionary) -> Node3D:
	var it := Game.item_data(o["id"])
	var fp := Game.footprint(o["id"])
	var node: Node3D
	var turn := Basis.IDENTITY   # what a tree is turned and sized by, about its own base
	if Game.kind_of(o) == "animal" or o.get("stray", false):
		var a := Animal3D.create(it, null, Vector3(int(o["col"]) + fp.x / 2.0, 0, int(o["row"]) + fp.y / 2.0))
		a.set_meta("uid", int(o["uid"]))
		a.behaviour = _mind_of(a)
		a.update(0.0)
		return a
	match Game.kind_of(o):
		"tree":
			# One of a few built looks of this kind (Instancer), turned and sized a little for this one.
			var look := Instancer.variant(int(o["row"]), int(o["col"]))
			var grown := ScaleGuide.factor(str(o["id"]))
			var ready := Game.is_ready(o)
			var mask := Crowding.mask(o)
			node = Instancer.copy_of(Instancer.key_of(["tree", o["id"], grown, ready, mask, look]), func() -> Node3D:
				var tree := Node3D.new()
				TreeModel.build_at(tree, Vector3(fp.x / 2.0, 0, fp.y / 2.0), it, grown, ready, look, true,
					TreeModel.UNSET, mask)
				return ModelKit.bake(tree))
			var rng := RandomNumberGenerator.new()
			rng.seed = int(o["uid"])
			# (A tree with neighbours is neither turned nor resized: which of its sides they cover is part of its
			# look, and its crown must not reach into theirs.)
			if mask == 0:
				turn = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * (1.0 + rng.randf_range(
					-TREE_SIZE_JITTER, TREE_SIZE_JITTER)))
		"vehicle":
			node = SpaceFit.fit_model(VehicleModel.build(it, Game.under_construction(o)), fp)
		"decor":
			if Game.links.group_of(str(o["id"])) != "":
				node = Node3D.new()   # drawn by the LinkLayer, which joins it to its neighbours; this stands in for taps
			else:
				node = DecorModel.build(it, fp, o)
				if not str(o["id"]).ends_with("_tree"):   # (a tree's crown overhangs by design)
					node = SpaceFit.fit_model(node, fp)
		"young":
			node = SpaceFit.fit_model(DecorModel.build_young(it, o, Game.nurture.growth(o)), fp)
		"bloom":
			node = SpaceFit.fit_model(BloomModel.build(it, o, ScaleGuide.factor(str(o["id"]))), fp)
		_:
			if Game.under_construction(o):
				node = ModelKit.bake(BuildingModel.build_site(it, fp, Game.land.construction_progress(o)))
			else:
				var level := Game.level_of(o)
				var working := _at_work(o)
				node = Instancer.copy_of(Instancer.key_of(["building", o["id"], level, working]), func() -> Node3D:
					return ModelKit.bake(BuildingModel.build(it, fp, level, working)))
				if BuildingFill.shows(o):
					node.add_child(BuildingFill.create(o, node))
	var dressing := Dressing.make(Game.kind_of(o), fp, int(o["uid"]))
	if dressing != null:
		dressing.name = String(DRESSING)
		node.add_child(dressing)
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
	return holder




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
		_woods.append([Node3D.new(), cells[cell]])
	_grow_woods()


## Builds trees of the woods for at most BUILD_BUDGET_MS; a group finished is baked and stands.
func _grow_woods() -> void:
	var began := Time.get_ticks_msec()
	while not _woods.is_empty() and Time.get_ticks_msec() - began <= BUILD_BUDGET_MS:
		var group: Array = _woods[0]
		var trees: Array = group[1]
		if trees.is_empty():
			_scenery.add_child(ModelKit.bake(group[0]))
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
			TreeModel.build_at(holder, at, {"id": "willow"}, 1.15, false, int(r * 31 + c), false, TreeModel.UNSET,
				GROVE_MASK)
		_:
			TreeModel.build_at(holder, at, {"id": str(t[2])}, 1.2, false, int(r * 31 + c), false, TreeModel.UNSET,
				GROVE_MASK)




## A pine: a short trunk and five stacked, overlapping skirts of needles, widest and darkest at the bottom,
## each turned a little from the one below, so the outline is ragged like a real conifer's.
static func pine(parent: Node3D, base: Vector3, size: float) -> void:
	var root := Node3D.new()
	root.position = base
	parent.add_child(root)
	ModelKit.cylinder(root, Vector3.ZERO, PINE_TRUNK_R * size, 0.22 * size, ModelKit.paint(TreeModel.BARK), -1.0, 6)
	for k in PINE_TIERS:
		var up := float(k) / (PINE_TIERS - 1)
		var y := (0.14 + 0.2 * k) * size
		var r := lerpf(0.5, 0.14, up) * size
		var skirt := ModelKit.cylinder(root, Vector3(0, y, 0), r, lerpf(0.46, 0.34, up) * size,
			ModelKit.paint(PINE.darkened(0.16 * (1.0 - up)).lightened(0.06 * up)), 0.0, 8 + (k % 2))
		skirt.rotation.y = k * 0.7
	ModelKit.sway_all(root, TreeModel.SWAY)  # bends in the wind like every tree


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
			var box: AABB = v["box"]
			d = _ray_to(AABB(node.position + box.position, box.size), from, dir)
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
	if node is Animal3D or not Game.is_building(o) or Game.under_construction(o) or node.get_child_count() == 0:
		return [_bounds(node, o)]
	var model := node.get_child(0) as Node3D
	var fp := Game.footprint(o["id"])
	var spec := BuildingModel.spec(str(o["id"]), Game.level_of(o))
	var out: Array[AABB] = [node.transform * (model.transform * AABB(Vector3.ZERO, Vector3(fp.x, YARD_HEIGHT, fp.y)))]
	var taken := BuildingModel.taken(spec, fp)
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
	var node := _node(uid)
	if node == null:
		return
	var base := Vector3.ONE
	var tw := _tween(node)
	tw.tween_property(node, "scale", base * Vector3(1.12, 0.84, 1.12), 0.07).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base * Vector3(0.95, 1.08, 0.95), 0.09).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)




## Finished or upgraded: it swells up past its size and settles back, with sparkles at its feet.
func grow_in(uid: int, grand: bool) -> void:
	var node := _node(uid)
	if node == null:
		return
	node.scale = Vector3.ONE * 0.82
	var tw := _tween(node)
	tw.tween_property(node, "scale", Vector3.ONE * Vector3(1.1, 1.14, 1.1), 0.16).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	transformed.emit(node.position, grand)


## Newly on the farm: it falls in from above, lands with a squash and settles.
func drop_in(uid: int) -> void:
	if _links.has_piece(uid):
		if Engine.get_process_frames() != _link_landed:   # a line is one thud, not forty
			_link_landed = Engine.get_process_frames()
			landed.emit(_node(uid).position)
		return   # the layer drops the piece itself
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
	tw.tween_property(node, "scale", base, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
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
