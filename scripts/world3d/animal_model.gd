class_name AnimalModel
extends RefCounted
## Ready-made, animated animal models (Quaternius, CC0) for the families in data/animal_models.json. One skinned
## mesh each, with its own Idle (and Walk) from the file; the family's colours repaint its surfaces.

const DIR := "res://art/models/quaternius/%s.fbx"
const DATA := "res://data/animal_models.json"
const UNIT := 100.0       # the files are modelled at 1/100 and their armature scales them up
const IDLE := "Armature|Idle"  # not-ui
const WALK := "Armature|Walk"  # not-ui
const BLEND := 0.25       # seconds to ease from one animation to the next

static var _data: Dictionary = {}
static var _boxes: Dictionary = {}   # file -> its true bounds (the mesh's own box is padded for skinning)


## The model's spec for a family, or {} when it has none (or the file isn't there).
static func of(family: String) -> Dictionary:
	if _data.is_empty():
		_data = (JSON.parse_string(FileAccess.get_file_as_string(DATA)) as Dictionary).get("families", {})
	var spec: Dictionary = _data.get(family, {})
	if spec.is_empty() or not ResourceLoader.exists(DIR % spec["file"]):
		return {}
	return spec


static func families() -> Array:
	of("")
	return _data.keys()


## Puts the model in `parent`, standing on the ground at the origin facing +x, `length` long, painted from the rig.
## Returns {"player", "height", "length", "width"}.
static func build(parent: Node3D, spec: Dictionary, rig: AnimalRig, length: float) -> Dictionary:
	var inst := (load(DIR % spec["file"]) as PackedScene).instantiate() as Node3D
	var mesh := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D  # not-ui
	var skeleton := mesh.get_parent() as Node3D
	var armature := skeleton.get_parent() as Node3D
	var box := _bounds(str(spec["file"]), mesh, armature)
	var longest := maxf(box.size.x, box.size.z)
	var s := length / longest
	var c := box.get_center()
	var floor_y := _floor(skeleton as Skeleton3D, armature, box.position.y)
	var pivot := Node3D.new()
	pivot.rotation.y = deg_to_rad(float(spec.get("yaw", 0.0)))
	parent.add_child(pivot)
	pivot.add_child(inst)
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(-c.x, -floor_y, -c.z) * s
	var roles: Array = spec.get("roles", [])
	for i in mesh.mesh.get_surface_count():
		var base := (mesh.mesh.surface_get_material(i) as BaseMaterial3D).albedo_color
		var role := str(roles[i]) if i < roles.size() else "keep"
		var col := rig.body_color if role == "coat" else rig.accent_color if role == "accent" else base
		mesh.set_surface_override_material(i, ModelKit.paint(col))
	var player := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer  # not-ui
	var lib := player.get_animation_library(&"")
	if spec.has("walk_from"):
		var other := (load(DIR % spec["walk_from"]) as PackedScene).instantiate()
		var from := other.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer  # not-ui
		if not lib.has_animation(WALK):
			lib.add_animation(WALK, from.get_animation(WALK).duplicate())
		other.free()
	for a: String in [IDLE, WALK]:
		if lib.has_animation(a):
			lib.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return {"player": player, "height": (box.end.y - floor_y) * s, "length": longest * s,
		"width": minf(box.size.x, box.size.z) * s}


## The bounds of what is really drawn, from the vertices, in the model's own space (after its armature).
static func _bounds(file: String, mesh: MeshInstance3D, armature: Node3D) -> AABB:
	if not _boxes.has(file):
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for i in mesh.mesh.get_surface_count():
			for v: Vector3 in mesh.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
				var w := armature.transform * v
				lo = lo.min(w)
				hi = hi.max(w)
		_boxes[file] = AABB(lo, hi - lo)
	return _boxes[file]


## Where the ground is: the tips of the feet in the rest pose (some meshes have a stray vertex far below them).
static func _floor(skeleton: Skeleton3D, armature: Node3D, fallback: float) -> float:
	var low := INF
	for b in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(b)
		if n.contains("Foot") and n.ends_with("_end"):  # not-ui
			low = minf(low, (armature.transform * skeleton.get_bone_global_rest(b).origin).y)
	return fallback if low == INF else low
