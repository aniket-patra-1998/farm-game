class_name Objects3D
extends Node3D
## Everything standing on the farm that has a 3D model, one node per object, rebuilt only when what it
## shows changes (its id, size, ready state, a frame becoming a building). Also the countryside trees
## around the farm. Kinds without a 3D model yet keep their 2D piece (ObjectLayer asks handles()).

signal landed(at: Vector3)  # something dropped onto the farm: a puff of dust there


const MODELLED := ["building", "barn", "crafting", "tree", "animal", "vehicle", "decor", "young", "bloom"]
const SCENERY_Y := -Ground3D.SLAB

const PINE := Color("#2f6b3a")


const DROP_HEIGHT := 1.4      # tiles above the ground a new thing falls from
const YARD_HEIGHT := 0.3      # a building's yard and fence, for taps
const PART_HEIGHT := 1.0      # what stands beside a building (a silo, an annex), for taps
const ROOF_EXTRAS := 0.35     # chimneys, cupolas and vanes above the roof, for taps


var life: FarmLife  # the animals' minds (shared with the 2D world)

var grid: FarmGrid  # for what's being placed: its ghost follows the finger, and the thing being moved hides


var _views := {}   # uid -> {"node": Node3D, "key": String}
var _animals: Array[Animal3D] = []
var _synced_once := false   # the farm's first sync places everything quietly; later ones drop new things in
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
			var fill := fill_of(uid)
			if fill != null:
				fill.refresh(o)  # who's in, how near ready: shown without rebuilding the building
			continue
		if v.has("node"):
			(v["node"] as Node3D).queue_free()
		var node := _build(o)
		add_child(node)
		var fresh := not v.has("node")
		_views[uid] = {"node": node, "key": key, "box": _bounds(node, o), "parts": _parts(node, o)}
		if fresh and _synced_once:
			drop_in(uid)  # newly bought or placed: it drops onto the farm
	for uid in _views.keys():
		if not seen.has(uid):
			(_views[uid]["node"] as Node3D).queue_free()
			_views.erase(uid)
	_synced_once = true
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
		a.animate(delta, cam)




func _mind_of(a: Animal3D) -> AnimalBehaviour:
	return life.mind(int(a.get_meta("uid", -1))) if life != null else null




## What a view shows: when this changes, it's rebuilt.
func _key(o: Dictionary) -> String:
	# A building site is rebuilt as each tenth of its materials goes in.
	var site := int(Game.land.construction_progress(o) * 10.0) if Game.under_construction(o) else -1
	return "%s|%d|%d|%d|%s|%d|%s|%s" % [o["id"], int(o["row"]), int(o["col"]), int(o.get("level", 1)),
		o.get("flip", false), site, Game.kind_of(o) in ["tree", "bloom"] and Game.is_ready(o),
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
		"young":
			node = DecorModel.build_young(it, o, Game.nurture.growth(o))
		"bloom":
			node = BloomModel.build(it, o)
		_:
			if Game.under_construction(o):
				node = ModelKit.bake(BuildingModel.build_site(it, fp, Game.land.construction_progress(o)))
			else:
				node = ModelKit.bake(BuildingModel.build(it, fp, Game.level_of(o), _at_work(o)))
				if BuildingFill.shows(o):
					node.add_child(BuildingFill.create(o, node))
	# The view stands at the footprint's centre on the ground, so it squashes, bounces and lands about
	# its base; the model hangs under it, shifted back to the footprint's corner.
	var holder := Node3D.new()
	holder.position = Vector3(int(o["col"]) + fp.x / 2.0, 0, int(o["row"]) + fp.y / 2.0)
	var centre := Vector3(fp.x / 2.0, 0, fp.y / 2.0)
	var basis := Basis.IDENTITY
	if o.get("flip", false):
		# Turned: mirrored across the footprint's diagonal (square things only turn), as the 2D art flips
		# left to right on screen.
		basis = Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0))
	node.transform = Transform3D(basis, -(basis * centre))
	holder.add_child(node)
	return holder




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
		_ghost.position = Vector3(col + fp.x / 2.0, lift, row + fp.y / 2.0)




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
		if node is Animal3D:
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




## Newly on the farm: it falls in from above, lands with a squash and settles.
func drop_in(uid: int) -> void:
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
