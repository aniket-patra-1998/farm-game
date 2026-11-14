class_name ScaleGuide
extends RefCounted
## How big things are against each other. Every model is built on its own, so nothing else stops a flower
## standing as tall as a tree. This builds an item's model, measures how tall it really stands (in tiles),
## and compares it with the range its class should have (data/scale_guide.json), the same way for everything.


const DATA := "res://data/scale_guide.json"

static var _ranges := {}
static var _factors := {}
static var _decor := {}


## What to multiply an item's size by so it stands within its kind's range (1.0 when it already does, or its
## kind has no range). Measured once per item and kept.
static func factor(id: String) -> float:
	if _factors.has(id):
		return _factors[id]
	var f := 1.0
	var range_of: Array = _heights().get(str(Game.item_data(id).get("kind", "")), [])
	if range_of.size() == 2:
		var h := height_of(id)
		if h > 0.0:
			f = clampf(h, float(range_of[0]), float(range_of[1])) / h
	_factors[id] = f
	return f


## The lowest a kind should stand, in tiles (0 when it has no range): trees reach it with their trunks.
static func lowest(kind: String) -> float:
	var range_of: Array = _heights().get(kind, [])
	return float(range_of[0]) if range_of.size() == 2 else 0.0


## How much bigger a decoration is drawn than it is modelled (1.0 for anything with no entry and no default).
static func decor_scale(id: String) -> float:
	if _decor.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_decor = (parsed as Dictionary).get("decor", {}) if parsed is Dictionary else {}
		if _decor.is_empty():
			_decor = {"default": 1.0}
	return float((_decor.get("ids", {}) as Dictionary).get(id, _decor.get("default", 1.0)))


static func _heights() -> Dictionary:
	if _ranges.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_ranges = (parsed as Dictionary).get("heights", {}) if parsed is Dictionary else {"": []}
	return _ranges


## An item's real height in tiles: its model built as the farm builds it and measured (0 if it has no model).
static func height_of(id: String) -> float:
	# Always measured at full detail, so a crowd being built (which lowers it) never changes what an item measures.
	var detail := ModelKit.detail
	ModelKit.detail = 1.0
	var node := model_of(id)
	ModelKit.detail = detail
	if node == null:
		return 0.0
	var h := _top(node, Transform3D.IDENTITY)
	node.free()
	return maxf(h, 0.0)


static func model_of(id: String) -> Node3D:
	var it := Game.item_data(id)
	var fp := Game.footprint(id)
	var mid := Vector3(fp.x / 2.0, 0, fp.y / 2.0)
	match str(it.get("kind", "")):
		"animal":
			var a := Animal3D.create(it, null, mid)
			a.update(0.016)
			return a
		"tree":
			var t := Node3D.new()
			TreeModel.build_at(t, mid, it, 1.0, true, 7)
			return ModelKit.bake(t)
		"vehicle":
			return VehicleModel.build(it, false)
		"decor":
			return DecorModel.build(it, fp, {"id": id, "uid": 7})
		"bloom":
			return BloomModel.build(it, {"id": id, "uid": 7, "t": Game.now() - int(it.get("cycle_seconds", 86400)) - 1})
		"young":
			return DecorModel.build_young(it, {"id": id, "uid": 7, "fed": 4}, 0.5)
		"building", "barn", "crafting":
			return ModelKit.bake(BuildingModel.build(it, fp, Game.max_level(id)))
	return null


## The highest point of everything under `node`, in its parent's space.
static func _top(node: Node3D, to_parent: Transform3D) -> float:
	var t := to_parent * node.transform
	var top := -INF
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var b := t * (node as MeshInstance3D).get_aabb()
		top = b.position.y + b.size.y
	for c in node.get_children():
		if c is Node3D:
			top = maxf(top, _top(c, t))
	return top
