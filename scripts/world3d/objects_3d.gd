class_name Objects3D
extends Node3D
## Everything standing on the farm that has a 3D model, one node per object, rebuilt only when what it
## shows changes (its id, size, ready state, a frame becoming a building). Also the countryside trees
## around the farm. Kinds without a 3D model yet keep their 2D piece (ObjectLayer asks handles()).

const MODELLED := ["building", "barn", "crafting", "tree", "animal", "vehicle", "decor"]
const SCENERY_Y := -Ground3D.SLAB
const PINE := Color("#2f6b3a")

var life: FarmLife  # the animals' minds (shared with the 2D world)
var grid: FarmGrid  # for what's being placed: its ghost follows the finger, and the thing being moved hides

var _views := {}   # uid -> {"node": Node3D, "key": String}
var _animals: Array[Animal3D] = []
var _ghost: Node3D
var _ghost_key := ""
var _lifted := -1
var _queued := false
var _scenery: Node3D


static func handles(o: Dictionary) -> bool:
	return o.get("stray", false) or MODELLED.has(Game.kind_of(o))


func _ready() -> void:
	_scenery = Node3D.new()
	add_child(_scenery)
	sync()
	Game.farm_expanded.connect(func(_n: int) -> void: _build_scenery())
	_build_scenery()
	var timer := Timer.new()
	timer.wait_time = 1.0  # trees ripen and buildings become ready over time
	timer.autostart = true
	timer.timeout.connect(queue_sync)
	add_child(timer)


func queue_sync() -> void:
	if not _queued:
		_queued = true
		sync.call_deferred()


func sync() -> void:
	_queued = false
	var seen := {}
	for o in Game.objects:
		if not handles(o):
			continue
		var uid := int(o["uid"])
		seen[uid] = true
		var key := _key(o)
		var v: Dictionary = _views.get(uid, {})
		if v.get("key", "") == key:
			continue
		if v.has("node"):
			(v["node"] as Node3D).queue_free()
		var node := _build(o)
		add_child(node)
		_views[uid] = {"node": node, "key": key}
	for uid in _views.keys():
		if not seen.has(uid):
			(_views[uid]["node"] as Node3D).queue_free()
			_views.erase(uid)
	_animals.clear()
	for v in _views.values():
		if v["node"] is Animal3D:
			_animals.append(v["node"])


## Animals move every frame, with their 2D twin's mind; those off screen keep their place but aren't posed.
func _process(delta: float) -> void:
	_update_placing()
	var cam := get_viewport().get_camera_3d()
	for a in _animals:
		if not is_instance_valid(a):
			continue
		if a.behaviour == null:
			a.behaviour = _mind_of(a)
		if cam == null or cam.is_position_in_frustum(a.global_position):
			a.update(delta)


func _mind_of(a: Animal3D) -> AnimalBehaviour:
	return life.mind(int(a.get_meta("uid", -1))) if life != null else null


## What a view shows: when this changes, it's rebuilt.
func _key(o: Dictionary) -> String:
	return "%s|%d|%d|%d|%s|%s|%s|%s" % [o["id"], int(o["row"]), int(o["col"]), int(o.get("level", 1)),
		o.get("flip", false), Game.under_construction(o), Game.kind_of(o) == "tree" and Game.is_ready(o),
		o.get("crop", o.get("flower", ""))]


func _build(o: Dictionary) -> Node3D:
	var it := Game.item_data(o["id"])
	var fp := Game.footprint(o["id"])
	var node: Node3D
	if Game.kind_of(o) == "animal" or o.get("stray", false):
		var a := Animal3D.create(it, null, Vector3(int(o["col"]) + fp.x / 2.0, 0, int(o["row"]) + fp.y / 2.0))
		a.set_meta("uid", int(o["uid"]))
		a.behaviour = _mind_of(a)
		a.update(0.0)
		return a
	match Game.kind_of(o):
		"tree":
			node = Node3D.new()
			TreeModel.build_at(node, Vector3(fp.x / 2.0, 0, fp.y / 2.0), it, 1.0, Game.is_ready(o), int(o["uid"]))
			node = ModelKit.bake(node)
		"vehicle":
			node = VehicleModel.build(it, Game.under_construction(o))
		"decor":
			node = DecorModel.build(it, fp, o)
		_:
			if Game.under_construction(o):
				node = ModelKit.bake(BuildingModel.build_frame(it, fp))
			else:
				node = ModelKit.bake(BuildingModel.build(it, fp))
	node.position = Vector3(int(o["col"]), 0, int(o["row"]))
	if o.get("flip", false):
		# Turned: mirrored across the footprint's diagonal, as the 2D art flips left to right on screen.
		node.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)), node.position)
	return node


## Woods along the back two sides of the farm (FarmGrid.scenery(), the same spots as the 2D world).
func _build_scenery() -> void:
	for c in _scenery.get_children():
		c.queue_free()
	var n := Game.farm_size
	for t in FarmGrid.scenery():
		var r: float = t[0]
		var c: float = t[1]
		if (r >= -1.0 and c >= -1.0) or r > n + 4 or c > n + 4:
			continue
		var at := Vector3(c + 0.5, SCENERY_Y, r + 0.5)
		match str(t[2]):
			"pine_tree":
				pine(_scenery, at, 1.0 + fposmod(r * 7.0 + c * 3.0, 0.5))
			"willow_tree":
				TreeModel.build_at(_scenery, at, {"id": "willow"}, 1.15, false, int(r * 31 + c), false)
			_:
				TreeModel.build_at(_scenery, at, {"id": str(t[2])}, 1.2, false, int(r * 31 + c), false)


## A pine: a short trunk and three stacked cones of dark needles.
static func pine(parent: Node3D, base: Vector3, size: float) -> void:
	var root := Node3D.new()
	root.position = base
	parent.add_child(root)
	ModelKit.cylinder(root, Vector3.ZERO, 0.05 * size, 0.2 * size, ModelKit.paint(TreeModel.BARK), -1.0, 6)
	for k in 3:
		var y := (0.15 + 0.28 * k) * size
		var r := (0.42 - 0.1 * k) * size
		ModelKit.cylinder(root, Vector3(0, y, 0), r, 0.5 * size, ModelKit.paint(PINE.lightened(0.07 * k)), 0.0, 9)


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
	var row := int(placing["row"])
	var col := int(placing["col"])
	var home := int(placing.get("home", -1)) != -1
	var ok := home or Game.can_place(item, row, col, lifted)
	var key := "%s|%s|%s" % [item, ok, home]
	if key != _ghost_key:
		_clear_ghost()
		_ghost_key = key
		var fake := {"uid": -1, "id": item, "row": 0, "col": 0, "level": 1}
		if lifted != -1:
			fake = Game.object_by_uid(lifted).duplicate()
			fake["row"] = 0
			fake["col"] = 0
		_ghost = _build(fake)
		if _ghost is Animal3D:
			_ghost.set_meta("uid", -1)  # a ghost has no mind: it stands still
		_tint(_ghost, Color(1, 1, 1, 0.5) if home else (Color(0.5, 1.0, 0.5, 0.6) if ok else Color(1.0, 0.4, 0.35, 0.6)))
		add_child(_ghost)
	var fp := Game.footprint(item)
	var lift := 0.25 if home else 0.0  # hovering over a home, it floats just above it
	if _ghost is Animal3D:
		(_ghost as Animal3D).home = Vector3(col + fp.x / 2.0, lift, row + fp.y / 2.0)
		_ghost.position = (_ghost as Animal3D).home
	else:
		_ghost.position = Vector3(col, lift, row)


func _clear_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_ghost_key = ""


func _show(uid: int, on: bool) -> void:
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
