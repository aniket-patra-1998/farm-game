class_name ScaleGuide
extends RefCounted
## How big things are against each other. Every model is built on its own, so nothing else stops a flower
## standing as tall as a tree. This builds an item's model, measures how tall it really stands (in tiles),
## and compares it with the range its class should have (data/scale_guide.json), the same way for everything.


## An item's real height in tiles: its model built as the farm builds it and measured (0 if it has no model).
static func height_of(id: String) -> float:
	var node := model_of(id)
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
