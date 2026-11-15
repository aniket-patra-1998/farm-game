class_name Instancer
extends RefCounted
## Repeated things are built once and shared (game-wide; build anything that repeats through here, not from
## scratch each time). Two ways, by what the thing has to do:
##
## - `copy_of`: a thing that has to be its own node (it is tapped, bounces, has doors that swing): built once per
##   key, then each one is a copy that shares the first's meshes and materials. Saves the build time (a tree is
##   ~15 ms) and the memory, not the draws.
## - `parts_of` + `place`: a crowd that is never touched one by one (the trees of an orchard): built once per
##   key, then drawn as MultiMeshes, a batch per part of each kind however many there are.
##
## The key is whatever the look depends on (`key_of` joins the pieces); different looks must have different
## keys, and a thing that varies from one copy to the next gets `variant`s: a few built looks to pick from.

const VARIANTS := 8      # different looks built of a kind that should not look cloned
const KEPT := 128        # templates kept; past that the oldest are let go (they are rebuilt if needed again)

static var _templates := {}   # key -> a baked Node3D, never in the tree
static var _pieces := {}      # key -> what pieces_of made
static var _parts := {}       # key -> [{mesh, shadow}]


## A joined key from the pieces a look depends on.
static func key_of(pieces: Array) -> String:
	var out := PackedStringArray()
	for p in pieces:
		out.append(str(p) if typeof(p) != TYPE_FLOAT else "%.2f" % p)
	return "|".join(out)


## Which variant (0..count-1) a thing standing on this tile is: the same one every time, and neighbours (beside
## or in front) are never the same one, so copies do not stand in clumps of clones.
static func variant(row: int, col: int, count := VARIANTS) -> int:
	return posmod(col + 3 * row, maxi(count, 1))


## A copy of what `build` makes (a baked Node3D), built once per `key`. The copy has its own nodes and shares
## the template's meshes, materials and metadata.
static func copy_of(key: String, build: Callable) -> Node3D:
	if not _templates.has(key):
		if _templates.size() >= KEPT:
			_forget(_templates)
		_templates[key] = ModelStore.cached(key, build)   # (from disk when kept: no build at all)
	return (_templates[key] as Node3D).duplicate()


## The drawn parts of what `build` makes (a baked Node3D, freed after), as [{mesh, shadow}], built once per key.
static func parts_of(key: String, build: Callable) -> Array:
	if _parts.has(key):
		return _parts[key]
	if _parts.size() >= KEPT:
		_forget(_parts)
	var baked: Node3D = ModelStore.cached(key, build)
	var parts: Array = []
	for mi in baked.get_children():
		if mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null:
			var mesh := (mi as MeshInstance3D).mesh
			for k in mesh.get_surface_count():
				mesh.surface_set_material(k, (mi as MeshInstance3D).get_surface_override_material(k))
			parts.append({"mesh": mesh, "shadow": (mi as MeshInstance3D).cast_shadow
				!= GeometryInstance3D.SHADOW_CASTING_SETTING_OFF})
	baked.free()
	_parts[key] = parts
	return parts


## What `build` makes (a baked Node3D, freed after), taken apart to be drawn in batches (DecorLayer), built once
## per key: {"pieces": [{mesh, shadow, material (an override, or null), xf (its place in the model)}],
## "root" (the model's own transform, e.g. how it was fitted to its tile), "box" (around it, in its own space)}.
## Unlike `parts_of` it goes all the way down the model (a part that moves on its own keeps its place).
static func pieces_of(key: String, build: Callable) -> Dictionary:
	if _pieces.has(key):
		return _pieces[key]
	if _pieces.size() >= KEPT:
		_pieces.erase(_pieces.keys()[0])
	var baked: Node3D = ModelStore.cached(key, build)
	var out := {"pieces": [], "root": Transform3D.IDENTITY, "box": AABB()}
	if baked != null:
		out["root"] = baked.transform
		_take_apart(baked, Transform3D.IDENTITY, out)
		baked.free()
	_pieces[key] = out
	return out


static func _take_apart(node: Node, xf: Transform3D, out: Dictionary) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		var at := xf * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var mi := child as MeshInstance3D
			for k in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(k) != null:
					mi.mesh.surface_set_material(k, mi.get_surface_override_material(k))
			(out["pieces"] as Array).append({"mesh": mi.mesh, "xf": at, "material": mi.material_override,
				"shadow": mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF})
			var box := at * mi.mesh.get_aabb()
			out["box"] = box if (out["pieces"] as Array).size() == 1 else (out["box"] as AABB).merge(box)
		_take_apart(child, at, out)


## Draws `parts` (from `parts_of`) once for every transform, as one batch per part, under `parent`. Returns
## the batches.
static func place(parent: Node3D, parts: Array, at: Array[Transform3D]) -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	if at.is_empty():
		return out
	for part: Dictionary in parts:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = part["mesh"]
		multi.instance_count = at.size()
		for k in at.size():
			multi.set_instance_transform(k, at[k])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if part["shadow"]
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		parent.add_child(node)
		out.append(node)
	return out


## Lets go of everything kept (tests, or a rebuild of the data the looks came from).
static func clear() -> void:
	for t: Node in _templates.values():
		t.free()
	_templates.clear()
	_parts.clear()
	Animal3D.clear_templates()
	_pieces.clear()


static func _forget(store: Dictionary) -> void:
	var oldest = store.keys()[0]
	if store[oldest] is Node:
		(store[oldest] as Node).free()
	store.erase(oldest)
