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
	_stretch(skeleton as Skeleton3D, spec.get("stretch", []))
	_parts(mesh, skeleton as Skeleton3D, spec.get("parts", []), rig)
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


## Reshapes a model by scaling bones: [{"bone": "Neck", "scale": 0.7, "keep": ["Head"]}] shortens the neck and
## leaves the head at its size (a goat from a llama).
static func _stretch(skeleton: Skeleton3D, list: Array) -> void:
	for e: Dictionary in list:
		var b := skeleton.find_bone(str(e["bone"]))
		if b < 0:
			continue
		var k := float(e["scale"])
		# (in the rest pose, so the animation, which only turns the bones, leaves it be)
		skeleton.set_bone_rest(b, skeleton.get_bone_rest(b).scaled_local(Vector3.ONE * k))
		for name: String in e.get("keep", []):
			var kept := skeleton.find_bone(name)
			if kept >= 0:
				skeleton.set_bone_rest(kept, skeleton.get_bone_rest(kept).scaled_local(Vector3.ONE / k))
	skeleton.reset_bone_poses()


## Extras on the head: [{"shape": "horn", "at": [forward, up, side], "dir": [forward, up, side], "len": 0.5,
## "r": 0.07, "colour": "accent" (or "coat", or a "#hex")}], a cone from `at` (shares of the head's length,
## height and half width, from its back, bottom and middle) toward `dir`, `len` and `r` in head heights. A pair is made if `at` has a side.
## The head is found from the vertices the skin gives its bone; all the parts are baked into one mesh.
static func _parts(mesh: MeshInstance3D, skeleton: Skeleton3D, list: Array, rig: AnimalRig) -> void:
	if list.is_empty():
		return
	var head := skeleton.find_bone("Head")  # not-ui
	var skin := mesh.skin
	if head < 0 or skin == null:
		return
	var mine := PackedInt32Array()
	for j in skin.get_bind_count():
		if skin.get_bind_bone(j) == head or skin.get_bind_name(j) == "Head":  # not-ui
			mine.append(j)
	if mine.is_empty():
		return
	var pts := PackedVector3Array()
	var body := Vector3.ZERO
	var count := 0
	for i in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if bones.is_empty() or verts.is_empty():
			continue
		var per := bones.size() / verts.size()
		for v in verts.size():
			body += verts[v]
			count += 1
			for k in per:
				if mine.has(bones[v * per + k]) and weights[v * per + k] > 0.5:
					pts.append(verts[v])
					break
	if pts.size() < 8:
		return
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var mid := Vector3.ZERO
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
		mid += p
	mid /= pts.size()
	body /= count
	# The mesh is Z up with its length along Y: the nose is the way from the body to the head.
	var nose := signf(mid.y - body.y)
	var back_y := lo.y if nose > 0.0 else hi.y
	var height := hi.z - lo.z
	var half := (hi.x - lo.x) * 0.5
	var to_bone := skin.get_bind_pose(mine[0])   # (not the rest pose: some meshes sit off their skeleton)
	var holder := Node3D.new()
	for part: Dictionary in list:
		var at: Array = part["at"]
		var dir: Array = part["dir"]
		var named := str(part.get("colour", "accent"))
		var col := Color.html(named) if named.begins_with("#") else rig.accent_color if named == "accent" else rig.body_color
		var mat := ModelKit.paint(col)
		for side: float in ([-1.0, 1.0] if float(at[2]) != 0.0 else [1.0]):
			var base := Vector3(mid.x + side * float(at[2]) * half, back_y + nose * float(at[0]) * (hi.y - lo.y),
				lo.z + float(at[1]) * height)
			var way := Vector3(side * float(dir[2]), nose * float(dir[0]), float(dir[1])).normalized()
			var len := float(part["len"]) * height
			var r := float(part["r"]) * height
			var cone := ModelKit.cylinder(holder, Vector3.ZERO, r, len, mat, 0.0)
			cone.transform = Transform3D(Basis(Quaternion(Vector3.UP, to_bone.basis * way)),
				to_bone * base + to_bone.basis * way * len * 0.5)
	var attach := BoneAttachment3D.new()
	attach.bone_name = "Head"  # not-ui
	skeleton.add_child(attach)
	var baked := ModelKit.bake(holder)
	for g in baked.find_children("*", "GeometryInstance3D", true, false):  # not-ui
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attach.add_child(baked)
