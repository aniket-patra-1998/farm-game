class_name Objects3D
extends Node3D
## Everything standing on the farm that has a 3D model, one node per object, rebuilt only when what it
## shows changes (its id, size, ready state, a frame becoming a building). Also the countryside trees
## around the farm. Kinds without a 3D model yet keep their 2D piece (ObjectLayer asks handles()).

const MODELLED := ["building", "barn", "crafting", "tree", "animal", "vehicle", "decor"]
const SCENERY_Y := -Ground3D.SLAB
const PINE := Color("#2f6b3a")

var pieces: ObjectLayer  # the 2D layer, whose animals' minds (AnimalBehaviour) the 3D animals share

var _views := {}   # uid -> {"node": Node3D, "key": String}
var _animals: Array[Animal3D] = []
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
	var cam := get_viewport().get_camera_3d()
	for a in _animals:
		if not is_instance_valid(a):
			continue
		if a.behaviour == null:
			a.behaviour = _mind_of(a)
		if cam == null or cam.is_position_in_frustum(a.global_position):
			a.update(delta)


func _mind_of(a: Animal3D) -> AnimalBehaviour:
	if pieces == null:
		return null
	var p: FarmPiece = pieces.pieces.get("o%d" % int(a.get_meta("uid", -1)))
	return p.animal if p != null else null


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
