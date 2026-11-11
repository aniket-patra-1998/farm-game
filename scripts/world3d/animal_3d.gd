class_name Animal3D
extends Node3D
## An animal in 3D, built from its rig (data/animal_rigs.json, through AnimalRig) and moved every frame by
## the same AnimalBehaviour that drives the 2D animal: one mind, two bodies. A four-legged animal has a
## body, a neck and head that lower to graze, four legs with knees that walk a planted-foot gait, ears,
## eyes, a tail that swishes; a bird has two legs, a bobbing head, wings that open; rabbits hop, turtles
## paddle, bees hover. Proportions (and so babies' big heads and long legs) all come from the rig.
##
## Local space: the animal faces +x, up is +y, its left side is -z. Sizes are the rig's pixels (made for a
## 128-pixel tile) times PX, so a cow is a little over half a tile long.

const PX := 1.6 / IsoProjection.PX_PER_UNIT    # rig pixels to world units (larger than 2D: a cow fills most of a tile)
const TURN_RATE := 6.0                          # how fast it turns to face where it's going (radians/s)
const EYE := Color("#1b140f")
const HOOF := Color("#3a2c22")
const PINK := Color("#eba9a3")
const BEAK := Color("#f2a33a")
const COMB := Color("#d8382f")
const LEG_NAMES := ["hind_far", "fore_far", "hind_near", "fore_near"]

const LEG_PHASES := [0.5, 0.75, 0.0, 0.25]      # the four-beat walk, as in QuadrupedArt
const CONTACT_SPREAD := 1.25                    # the contact shade reaches this far past the body

const CONTACT_LIFT := 0.012                     # just above the grass, so it never flickers into it


## The animation budget: this many animals on screen are posed every frame; past it, each is posed every
## 2nd, 3rd or 4th frame in turn (round-robin, so the work is spread evenly), holding its pose between.
## The usual mobile budget is 10-20 fully animated characters; the minds still think every frame.
const FULL_RATE := 16
const MAX_STRIDE := 4

static var _contact_material: ShaderMaterial    # one for every animal

static var _frame := -1          # the frame _seen counts
static var _seen := 0            # animals on screen so far this frame

static var _seen_last := 0       # and last frame, which sets this frame's stride



var rig: AnimalRig
var behaviour: AnimalBehaviour   # its mind, owned and updated by FarmLife
var motion: AnimalMotion         # its body's weight: leaning, swaying, lagging, settling (3D only)
var heading := 0.0               # radians around +y; 0 faces +x

var home := Vector3.ZERO         # the tile centre it wanders around

var drop := 0.0                  # height above the ground while dropping in (tweened by land())

var _body: Node3D
var _head: Node3D
var _neck: MeshInstance3D
var _tail: Node3D
var _legs: Array[Dictionary] = []   # {"hip": Vector3, "upper": MeshInstance3D, "lower": MeshInstance3D, ...}
var _wings: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _last := Vector3.ZERO
var _r := Vector3.ONE            # body half-sizes (length, height, width)

var _leg := 0.2
var _contact: MeshInstance3D     # the soft shade on the grass right under it
var _eyes: Array[Node3D] = []    # (they blink)
var _walk_speed := 1.0           # its walking speed, in units a second
var _skeleton: Skeleton3D        # the whole animal is one skinned mesh on this (see _skin)
var _bones: Array[Node3D] = []   # the part nodes the pose code moves, by bone index; copied to the bones
var _slot := 0                   # its turn in the round-robin when posed less than every frame

var _pending := 0.0              # time not yet posed (while waiting its turn)






static func create(it: Dictionary, mind: AnimalBehaviour, at: Vector3) -> Animal3D:
	var a := Animal3D.new()
	a.rig = AnimalRig.of(it)
	a.behaviour = mind
	a.home = at
	a.position = at
	a._last = at
	a.heading = PI * 0.75 if mind == null or mind.facing < 0.0 else -PI * 0.25
	a.motion = AnimalMotion.new(hash(str(it.get("id", ""))) + int(at.x * 97.0 + at.z * 31.0))
	a._walk_speed = maxf(IsoProjection.ground_of(Vector2(a.rig.num("speed", 10.0) * a.rig.scale, 0)).length(), 0.001)
	a._build()
	return a




# ---------------------------------------------------------------- building


func _build() -> void:
	_body = Node3D.new()
	add_child(_body)
	match rig.type:
		"bird":
			_build_bird()
		"bug":
			_build_bee()
		"shell":
			_build_turtle()
		_:
			_build_quad()
	_build_contact()
	_merge_parts()
	_skin()
	_slot = get_instance_id() % MAX_STRIDE
	rotation.y = heading




## Draws: the parts that never move against each other (body and its coat, head and its face) become one
## mesh each, and only the body and head cast shadows; the thin moving parts (legs, ears, eyes, tail,
## wings) cast none, which at this size the sun's shadow wouldn't show anyway, and the contact shade under
## the animal grounds it. A cow goes from ~24 draws and ~24 shadow draws to ~12 and 2.
func _merge_parts() -> void:
	var moving: Array = [_neck, _head, _tail, _contact]
	moving.append_array(_wings)
	moving.append_array(_ears)
	moving.append_array(_eyes)
	for leg in _legs:
		for k in leg:
			if leg[k] is Node3D:
				moving.append(leg[k])
	ModelKit.merge_leaves(_body, moving)
	if _head != null:
		ModelKit.merge_leaves(_head, moving)
	for n: Node3D in moving:
		if n != null and n != _head:
			_no_shadow(n)




## One draw for the whole animal (two with its shadow-casting body and head): every part's mesh is baked,
## at rest, into one skinned mesh, each part bound wholly to its own bone. The part nodes stay, emptied, as
## the pose: the pose code moves them as before, and _pose_bones copies their transforms to the bones.
func _skin() -> void:
	var parts: Array[MeshInstance3D] = []
	_gather(self, parts)
	if parts.is_empty():
		return
	_skeleton = Skeleton3D.new()
	var bone_of := {}   # node -> bone index
	var groups := {}    # "shadow|material|format" -> {"st", "mat", "shadow"}
	for mi in parts:
		var chain: Array[Node3D] = []
		var n: Node = mi
		while n != self:
			chain.push_front(n as Node3D)
			n = n.get_parent()
		var rest := Transform3D.IDENTITY
		for link in chain:
			rest = rest * link.transform
			if not bone_of.has(link):
				var b := _skeleton.get_bone_count()
				_skeleton.add_bone(str(b))
				_skeleton.set_bone_parent(b, bone_of.get(link.get_parent(), -1))
				_skeleton.set_bone_rest(b, link.transform)
				bone_of[link] = b
				_bones.append(link)
		var bone: int = bone_of[mi]
		var shadow := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var mat := mi.material_override if mi.material_override != null else mi.get_active_material(s)
			var arrays := mi.mesh.surface_get_arrays(s)
			var tint := ModelKit.tinted(mat)
			if not tint.is_empty():
				mat = tint[0]
				arrays = ModelKit.tint_arrays(arrays, tint[1])
			var count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var bones := PackedInt32Array()
			bones.resize(count * 4)
			var weights := PackedFloat32Array()
			weights.resize(count * 4)
			for v in count:
				bones[v * 4] = bone
				weights[v * 4] = 1.0
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			var fmt := 0
			for k: int in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR, Mesh.ARRAY_TANGENT]:
				if arrays[k] != null:
					fmt |= 1 << k
			var key := "%s|%d|%d" % [shadow, mat.get_instance_id() if mat != null else 0, fmt]
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"st": st, "mat": mat, "shadow": shadow}
			var one := ArrayMesh.new()
			one.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			(groups[key]["st"] as SurfaceTool).append_from(one, 0, rest)
		mi.mesh = null  # it's drawn by the skinned mesh now; the node stays as its bone's pose
	add_child(_skeleton)
	var skin := _skeleton.create_skin_from_rest_transforms()
	for shadow: bool in [true, false]:
		var mesh := ArrayMesh.new()
		var mats: Array[Material] = []
		for key in groups:
			if groups[key]["shadow"] == shadow:
				(groups[key]["st"] as SurfaceTool).commit(mesh)
				mats.append(groups[key]["mat"])
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.skin = skin
		for k in mats.size():
			mi.set_surface_override_material(k, mats[k])
		if not shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
	_pose_bones()




func _gather(n: Node, out: Array[MeshInstance3D]) -> void:
	for c in n.get_children():
		if c == _contact or c == _skeleton:
			continue
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			out.append(c)
		_gather(c, out)




func _pose_bones() -> void:
	if _skeleton == null:
		return
	for b in _bones.size():
		_skeleton.set_bone_pose(b, _bones[b].transform)




## Poses it this frame if it's on screen and its turn has come (the animation budget, FULL_RATE): owners
## call this every frame instead of update().
func animate(delta: float, cam: Camera3D) -> void:
	if cam != null and not cam.is_position_in_frustum(global_position):
		_pending = 0.0
		return
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_seen_last = _seen
		_seen = 0
	_seen += 1
	_pending += delta
	var stride := clampi(ceili(float(_seen_last) / FULL_RATE), 1, MAX_STRIDE)
	if (f + _slot) % stride != 0:
		return
	update(_pending)
	_pending = 0.0




static func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)




## A soft dark patch on the grass under the body, a little longer than it, so the animal stands on the
## farm (ambient occlusion; the sun's shadow falls separately, and moves with the time of day).
func _build_contact() -> void:
	if _contact_material == null:
		_contact_material = ShaderMaterial.new()
		_contact_material.shader = load("res://shaders/contact3d.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2(_r.x * 2.0 * CONTACT_SPREAD, maxf(_r.z, _r.x * 0.45) * 2.0 * CONTACT_SPREAD)
	_contact = MeshInstance3D.new()
	_contact.mesh = plane
	_contact.material_override = _contact_material
	_contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contact.position.y = CONTACT_LIFT
	add_child(_contact)




func _px(v: float) -> float:
	return v * PX




func _build_quad() -> void:
	var b := rig.pair("body", Vector2(26, 14))
	_r = Vector3(_px(b.x), _px(b.y), _px(b.y) * 0.85)
	_leg = _px(rig.size("leg", 15.0))
	var coat := rig.body_color
	var accent := rig.accent_color
	var mat := ModelKit.paint(coat)
	# The body: a rounded barrel, with wool, spots or patches on it.
	if rig.flag("wool"):
		for k in 9:
			var a := TAU * k / 9.0
			ModelKit.ball(_body, Vector3(cos(a) * _r.x * 0.62, sin(a) * _r.y * 0.4, 0), _r.y * 0.62,
				ModelKit.paint(coat.lightened(0.06)))
		ModelKit.ball(_body, Vector3.ZERO, 1.0, ModelKit.paint(coat.lightened(0.06)), _r * Vector3(0.95, 0.95, 1.05))
	else:
		ModelKit.ball(_body, Vector3.ZERO, 1.0, mat, _r)
	_markings(rig.text("markings", "none"), accent)
	if rig.flag("udder"):
		ModelKit.ball(_body, Vector3(-_r.x * 0.3, -_r.y * 0.85, 0), _r.y * 0.3, ModelKit.paint(PINK))
	# Legs: upper and lower segments, re-posed every frame.
	var thick := _px(rig.num("leg_width", 1.0) * (1.35 if rig.family == "pig" else 1.0) * 3.4)
	var leg_col := coat.darkened(0.08)
	var lower_col := leg_col
	if rig.family == "horse":
		lower_col = accent.lerp(coat, 0.35)
	if rig.flag("socks"):
		lower_col = Color("#f4f1ea")
	for k in 4:
		var near: bool = k >= 2
		var fore: bool = k % 2 == 1
		var hip := Vector3((0.58 if fore else -0.58) * _r.x, -_r.y * 0.35, (0.55 if near else -0.55) * _r.z)
		var upper := _segment(ModelKit.paint(leg_col), thick)
		var lower := _segment(ModelKit.paint(lower_col), thick * 0.75)
		var hoof_col := HOOF if rig.family != "pig" else coat.darkened(0.45)
		var hoof := ModelKit.box(_body, Vector3(-thick * 0.6, 0, -thick * 0.5),
			Vector3(thick * 0.6, thick * 0.6, thick * 0.5), ModelKit.paint(hoof_col))
		_legs.append({"hip": hip, "upper": upper, "lower": lower, "hoof": hoof, "phase": LEG_PHASES[k], "fore": fore,
			"k": k})
	# Neck and head.
	_neck = _segment(mat, _px(rig.pair("neck", Vector2(14, 9)).y) * 1.6)
	_head = Node3D.new()
	_body.add_child(_head)
	var h := rig.pair("head", Vector2(14, 10)) * rig.head_scale
	var hl := _px(h.x)
	var hh := _px(h.y)
	var head_col := coat
	if rig.text("markings") == "white_face":
		head_col = Color("#f4f1ea")
	elif rig.text("head_color") == "accent":
		head_col = accent
	ModelKit.ball(
		_head,
		Vector3(-hl * 0.1, 0, 0),
		1.0,
		ModelKit.paint(head_col),
		Vector3(hl * 0.48, hh * 0.5, hh * 0.45)
	)
	var muzzle := _muzzle_colour(rig.text("muzzle", "light"), head_col)
	if rig.text("muzzle") == "snout":
		var snout := ModelKit.cylinder(
			_head,
			Vector3(hl * 0.3, 0, 0),
			hh * 0.3,
			hl * 0.25,
			ModelKit.paint(muzzle),
			-1.0,
			12
		)
		snout.rotation.z = -PI / 2.0
		snout.position = Vector3(hl * 0.42, 0, 0)
	else:
		ModelKit.ball(
			_head,
			Vector3(hl * 0.32, -hh * 0.08, 0),
			1.0,
			ModelKit.paint(muzzle),
			Vector3(hl * 0.28, hh * 0.36, hh * 0.38)
		)
	var eye_r := hh * 0.09 * rig.num("eye_scale", 1.0)
	for side: float in [-1.0, 1.0]:
		_eyes.append(ModelKit.ball(_head, Vector3(hl * 0.05, hh * 0.15, side * hh * 0.4), eye_r, ModelKit.paint(EYE, 0.8)))
		var ear := Node3D.new()
		ear.position = Vector3(-hl * 0.3, hh * 0.3, side * hh * 0.35)
		_head.add_child(ear)
		var long_ears := rig.text("ears") == "long"
		var up := rig.text("ears") in ["up", "long"]
		var ear_at := Vector3(0, hh * (0.35 if up else 0.05), side * hh * (0.05 if up else 0.3))
		var ear_size := Vector3(
			hh * 0.12,
			hh * (0.45 if long_ears else (0.3 if up else 0.12)),
			hh * (0.12 if up else 0.28)
		)
		ModelKit.ball(ear, ear_at, 1.0, ModelKit.paint(head_col), ear_size)
		_ears.append(ear)
		match rig.text("horns", "none"):
			"nubs", "short":
				var horn_h := hh * (0.25 if rig.text("horns") == "nubs" else 0.45)
				ModelKit.cylinder(_head, Vector3(-hl * 0.15, hh * 0.4, side * hh * 0.22), hh * 0.08, horn_h,
					ModelKit.paint(Color("#ece3cf")), 0.0, 8)
			"long", "curl", "back", "long_back":
				var horn := ModelKit.cylinder(
					_head,
					Vector3.ZERO,
					hh * 0.09,
					hh * 0.9,
					ModelKit.paint(Color("#ece3cf")),
					0.0,
					8
				)
				horn.position = Vector3(-hl * 0.2, hh * 0.45, side * hh * 0.35)
				horn.rotation = Vector3(side * 1.1, 0, -0.6)
	if rig.text("mane", "") != "":
		ModelKit.box(
			_head,
			Vector3(-hl * 0.55, hh * 0.25, -hh * 0.08),
			Vector3(-hl * 0.2, hh * 0.55, hh * 0.08),
			ModelKit.paint(accent)
		)
	# Tail.
	_tail = Node3D.new()
	_tail.position = Vector3(-_r.x * 0.95, _r.y * 0.35, 0)
	_body.add_child(_tail)
	var tail_len := _px(rig.size("tail_len", 14.0))
	var tail_kind := rig.text("tail", "tuft")
	if tail_kind == "curl":
		ModelKit.ball(_tail, Vector3(-_px(2.0), 0, 0), _px(2.2), ModelKit.paint(coat.darkened(0.12)))
	else:
		var t := ModelKit.cylinder(
			_tail,
			Vector3(0, -tail_len, 0),
			_px(1.2),
			tail_len,
			ModelKit.paint(coat.darkened(0.1)),
			_px(1.0),
			6
		)
		t.position = Vector3(0, -tail_len / 2.0, 0)
		if tail_kind in ["tuft", "hair"]:
			ModelKit.ball(_tail, Vector3(0, -tail_len, 0), _px(2.6 if tail_kind == "tuft" else 3.4), ModelKit.paint(accent),
				Vector3(1, 1.6, 1))




func _markings(kind: String, accent: Color) -> void:
	var white := Color("#f4f1ea")
	match kind:
		"spots", "patches":
			var spots := [Vector3(-0.4, 0.3, 1), Vector3(0.1, 0.5, 1), Vector3(0.45, 0.1, 1), Vector3(-0.15, -0.1, 1),
				Vector3(-0.3, 0.4, -1), Vector3(0.3, 0.3, -1)]
			var big := 0.24 if kind == "patches" else 0.17
			var col := accent if kind == "spots" else (white if rig.body_color.get_luminance() < 0.5 else accent)
			for s: Vector3 in spots:
				# A flattened blob pressed onto the body's surface.
				var p := Vector3(s.x * _r.x, s.y * _r.y, s.z * _r.z * sqrt(maxf(0.0, 1.0 - s.x * s.x - s.y * s.y)))
				ModelKit.ball(_body, p, 1.0, ModelKit.paint(col), Vector3(_r.x * big, _r.y * big * 1.1, _r.z * 0.12))
		"belt", "saddle":
			var x0 := -0.22 if kind == "belt" else 0.22
			ModelKit.ball(_body, Vector3((x0 + 0.18) * _r.x, 0, 0), 1.0, ModelKit.paint(white),
				Vector3(_r.x * 0.2, _r.y * 1.02, _r.z * 1.02))
		"pale_belly", "white_face":
			ModelKit.ball(_body, Vector3(0, -_r.y * 0.35, 0), 1.0, ModelKit.paint(rig.body_color.lightened(0.45)),
				Vector3(_r.x * 0.85, _r.y * 0.7, _r.z * 1.01))




static func _muzzle_colour(kind: String, head_col: Color) -> Color:
	match kind:
		"pink":
			return head_col.lerp(PINK, 0.65)
		"dark":
			return head_col.darkened(0.35)
		"snout":
			return head_col.lerp(PINK, 0.35).darkened(0.08)
	return head_col.lightened(0.25)




func _build_bird() -> void:
	var b := rig.pair("body", Vector2(13, 11))
	_r = Vector3(_px(b.x), _px(b.y), _px(b.y) * 0.85)
	_leg = _px(rig.size("leg", 9.0))
	var coat := rig.body_color
	var accent := rig.accent_color
	ModelKit.ball(_body, Vector3.ZERO, 1.0, ModelKit.paint(coat), _r)
	# Wings: flattened ovals on each side, hinged at the shoulder.
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(_r.x * 0.2, _r.y * 0.25, side * _r.z * 0.85)
		_body.add_child(wing)
		ModelKit.ball(wing, Vector3(-_r.x * 0.45, 0, 0), 1.0, ModelKit.paint(coat.darkened(0.1)),
			Vector3(_r.x * 0.6, _r.y * 0.55, _r.z * 0.18))
		_wings.append(wing)
	# Tail.
	_tail = Node3D.new()
	_tail.position = Vector3(-_r.x * 0.85, _r.y * 0.3, 0)
	_body.add_child(_tail)
	match rig.text("tail", "fan"):
		"fan", "turkey":
			var n := 7 if rig.text("tail") == "turkey" else 4
			for k in n:
				var feather := Node3D.new()
				feather.rotation.x = (k / maxf(n - 1.0, 1.0) - 0.5) * 1.6
				_tail.add_child(feather)
				ModelKit.ball(feather, Vector3(0, _r.y * 0.6, 0), 1.0, ModelKit.paint(accent.lerp(coat, 0.2 * (k % 2))),
					Vector3(_r.x * 0.12, _r.y * 0.65, _r.z * 0.15))
		_:
			ModelKit.ball(_tail, Vector3(-_r.x * 0.1, _r.y * 0.1, 0), 1.0, ModelKit.paint(coat.darkened(0.06)),
				Vector3(_r.x * 0.3, _r.y * 0.2, _r.z * 0.4))
	# Two legs.
	for k in 2:
		var hip := Vector3(0, -_r.y * 0.5, (0.35 if k == 1 else -0.35) * _r.z)
		var col := BEAK if rig.flag("webbed") else Color("#e8a634")
		var upper := _segment(ModelKit.paint(col), _px(1.6))
		var lower := _segment(ModelKit.paint(col), _px(1.4))
		var foot := ModelKit.box(
			_body,
			Vector3(-_px(1.5), 0, -_px(2.0)),
			Vector3(_px(4.5), _px(0.8), _px(2.0)),
			ModelKit.paint(col)
		)
		_legs.append({"hip": hip, "upper": upper, "lower": lower, "hoof": foot, "phase": 0.5 * k, "fore": false})
	# Neck and head.
	_neck = _segment(ModelKit.paint(coat), _px(rig.pair("neck", Vector2(7, 7)).y) * 1.4)
	_head = Node3D.new()
	_body.add_child(_head)
	var h := rig.pair("head", Vector2(6.5, 6.5)) * rig.head_scale
	var hr := _px(h.x)
	var head_col := Color("#c9a7a0") if rig.family == "turkey" else coat
	ModelKit.ball(_head, Vector3.ZERO, hr, ModelKit.paint(head_col))
	if rig.text("beak") == "bill":
		ModelKit.ball(
			_head,
			Vector3(hr * 1.1, -hr * 0.15, 0),
			1.0,
			ModelKit.paint(BEAK),
			Vector3(hr * 0.7, hr * 0.22, hr * 0.45)
		)
	else:
		var beak := ModelKit.cylinder(_head, Vector3.ZERO, hr * 0.3, hr * 0.7, ModelKit.paint(BEAK), 0.0, 8)
		beak.rotation.z = -PI / 2.0
		beak.position = Vector3(hr * 1.2, -hr * 0.05, 0)
	if rig.flag("comb"):
		for k in 3:
			ModelKit.ball(_head, Vector3((-0.3 + 0.3 * k) * hr, hr * 0.95, 0), hr * 0.28, ModelKit.paint(COMB))
	if rig.flag("wattle"):
		ModelKit.ball(_head, Vector3(hr * 0.7, -hr * 0.8, 0), hr * 0.22, ModelKit.paint(COMB), Vector3(1, 1.5, 1))
	for side: float in [-1.0, 1.0]:
		_eyes.append(ModelKit.ball(_head, Vector3(hr * 0.4, hr * 0.25, side * hr * 0.75),
			hr * 0.16 * rig.num("eye_scale", 1.0), ModelKit.paint(EYE, 0.8)))




func _build_turtle() -> void:
	var b := rig.pair("body", Vector2(16, 10))
	_r = Vector3(_px(b.x), _px(b.y) * 0.8, _px(b.x) * 0.8)
	_leg = _px(4.0)
	var skin := rig.accent_color.lerp(Color("#8a9a5b"), 0.6)
	ModelKit.ball(_body, Vector3.ZERO, 1.0, ModelKit.paint(rig.body_color), Vector3(_r.x, _r.y, _r.z))
	for k in 4:
		var hip := Vector3((0.6 if k % 2 else -0.6) * _r.x, -_r.y * 0.2, (0.7 if k >= 2 else -0.7) * _r.z)
		var leg := ModelKit.ball(_body, hip, _px(3.0), ModelKit.paint(skin), Vector3(1.3, 0.7, 1))
		_legs.append({"stub": leg, "hip": hip, "phase": k * 0.25})
	_head = Node3D.new()
	_body.add_child(_head)
	ModelKit.ball(_head, Vector3.ZERO, _px(4.0), ModelKit.paint(skin), Vector3(1.3, 1, 1))
	for side: float in [-1.0, 1.0]:
		ModelKit.ball(_head, Vector3(_px(2.5), _px(1.5), side * _px(2.6)), _px(0.8), ModelKit.paint(EYE))




func _build_bee() -> void:
	var b := rig.pair("body", Vector2(6, 4))
	_r = Vector3(_px(b.x), _px(b.y), _px(b.y))
	ModelKit.ball(_body, Vector3.ZERO, 1.0, ModelKit.paint(rig.body_color), _r)
	for k in 2:
		ModelKit.ball(_body, Vector3((-0.3 + 0.4 * k) * _r.x, 0, 0), 1.0, ModelKit.paint(Color("#2a2118")),
			Vector3(_r.x * 0.12, _r.y * 1.02, _r.z * 1.02))
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(0, _r.y * 0.8, side * _r.z * 0.5)
		_body.add_child(wing)
		var glass := ModelKit.paint(Color(0.92, 0.97, 1.0))
		ModelKit.ball(wing, Vector3(0, 0, side * _r.z * 0.8), 1.0, glass, Vector3(_r.x * 0.5, _r.y * 0.1, _r.z * 0.9))
		_wings.append(wing)




## A limb segment: a unit cylinder, stretched between two points each frame by _place().
func _segment(mat: Material, width: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = width / 2.0
	mesh.bottom_radius = width / 2.0
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat
	_body.add_child(mi)
	return mi




## Stretches a segment from a to b (in the body's space).
static func _place(seg: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := maxf(d.length(), 0.0001)
	var up := d / length
	var side := up.cross(Vector3.BACK)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var fwd := side.cross(up).normalized()
	seg.transform = Transform3D(Basis(side, up * length, fwd), (a + b) / 2.0)




## How far it reaches from its feet (radius) and how tall it stands: its box for taps.
func reach() -> Vector2:
	var r := maxf(_r.x, _r.z) * 1.6
	return Vector2(maxf(r, 0.12), _leg + _r.y * 2.6 + 0.05)




## Dropped onto the farm (just bought): falls in and lands with a little hop.
func land() -> void:
	drop = Objects3D.DROP_HEIGHT
	var tw := create_tween()
	tw.tween_property(self, "drop", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if behaviour != null:
		tw.tween_callback(behaviour.poke)




# ---------------------------------------------------------------- moving


## Poses the animal for this frame from its behaviour (call every frame it's on screen).
func update(delta: float) -> void:
	var p: AnimalPose = behaviour.pose if behaviour != null else AnimalPose.rest()
	if behaviour != null:
		position = home + IsoProjection.ground_of(behaviour.offset) + Vector3(0, drop, 0)
	# Face where it's going: turn smoothly toward its direction of travel.
	var moved := position - _last
	_last = position
	if Vector2(moved.x, moved.z).length() > 0.0005:
		var want := atan2(-moved.z, moved.x)
		heading = rotate_toward(heading, want, TURN_RATE * delta)
	rotation.y = heading
	# The body's weight: how fast it's going (in walks), turning, hopping, and whether it's been tapped and
	# should look round at you.
	var speed := Vector2(moved.x, moved.z).length() / maxf(delta, 0.0001) / _walk_speed if delta > 0.0 else 0.0
	var keen := clampf(behaviour.noticed / 0.4, 0.0, 1.0) if behaviour != null else 0.0
	motion.step(delta, speed, heading, p.hop, p.stride, _yaw_to_camera() if keen > 0.0 else 0.0, keen)
	for e in _eyes:
		e.scale = Vector3(1.0, maxf(1.0 - p.blink, 0.1), 1.0)
	match rig.type:
		"bird":
			_pose_bird(p)
		"bug":
			_pose_bee(p)
		"shell":
			_pose_turtle(p)
		_:
			_pose_quad(p)
	_settle_contact(p)
	_pose_bones()




## Which way to turn the head to look at the camera, from straight ahead (radians, + to its left).
func _yaw_to_camera() -> float:
	if not is_inside_tree():
		return 0.0
	var local := global_transform.basis.inverse() * -IsoProjection.forward()
	return atan2(-local.z, local.x)


## The contact shade stays on the ground and fades as the animal leaves it (a hop, dropping in, a bee).
func _settle_contact(p: AnimalPose) -> void:
	var air := drop + p.hop * _leg * 0.55
	if rig.type == "bug":
		air += _body.position.y  # a bee hovers: only a faint patch under it
	_contact.position.y = CONTACT_LIFT - drop
	var fade := clampf(air / maxf(_r.y * 3.0, 0.05), 0.0, 0.85)
	_contact.transparency = fade
	_contact.scale = Vector3.ONE * (1.0 - fade * 0.3)




func _pose_quad(p: AnimalPose) -> void:
	var m := motion
	var rise := pow(sin(p.gait * TAU * 2.0), 2.0) * _leg * 0.06 * p.stride
	var air := p.hop * _leg * 0.55
	_body.position = Vector3(0, _leg + _r.y * 0.62 + rise + air + p.breath * _r.y * 0.01, 0)
	# Weight: leaning into turns and speed, the hips rolling with each step and dropping on a rested leg; a
	# squash on landing; a slow breath.
	var sway := sin(p.gait * TAU) * AnimalMotion.SWAY * p.stride * (1.0 - m.trot * 0.6)
	_body.rotation = Vector3(m.roll + sway + m.rest * 0.05, 0, m.pitch - m.rest * 0.03)
	var breathe := 1.0 + p.breath * 0.012
	_body.scale = Vector3(1.0 + m.squash * 0.6, (1.0 - m.squash) * breathe, (1.0 + m.squash * 0.6) * breathe)
	# Legs: the feet stay planted on the ground whatever the body does above them (worked out on the
	# ground, then into the body's space for the leg's two bones).
	var reach := AnimalArt.STRIDE * _leg * (1.0 + m.trot * 0.25)
	var lift := AnimalArt.LIFT * _leg * (1.0 + m.trot * 0.5)
	var to_body := _body.transform.affine_inverse()
	for leg in _legs:
		var hip: Vector3 = leg["hip"]
		var k: int = leg["k"]
		var u := fposmod(p.gait + m.leg_phase(k), 1.0)
		var off := AnimalArt.foot_offset(u, reach, lift) * p.stride
		var hip_on_ground := _body.transform * hip
		var foot_on_ground := Vector3(hip_on_ground.x + off.x, p.hop * _leg * 0.4 - off.y, hip_on_ground.z)
		if k == 2:
			# The near hind leg is the one it rests: toe down, a little forward, the hock bent.
			foot_on_ground += Vector3(_leg * 0.12, _leg * 0.07, 0) * m.rest
		var foot := to_body * foot_on_ground
		var knee := _knee(hip, foot, bool(leg["fore"]))
		_place(leg["upper"], hip, knee)
		_place(leg["lower"], knee, foot)
		(leg["hoof"] as Node3D).position = foot
	# Neck and head: up and looking about, or down to graze, chewing. The head lags the body's turns,
	# rides out its bob, stays level when it leans, and turns to you when you tap.
	var down := smoothstep(0.0, 1.0, p.head)
	var neck_len := _px(rig.pair("neck", Vector2(14, 9)).x)
	var chest := Vector3(_r.x * 0.72, _r.y * 0.3, 0)
	var up_at := chest + Vector3(cos(-rig.num("neck_up", -0.6)), sin(-rig.num("neck_up", -0.6)), 0) * neck_len
	var graze_at := Vector3(chest.x + neck_len * 0.8, -_body.position.y + _r.y * 0.35, 0)
	var head_at := up_at.lerp(graze_at, down) + Vector3(0, p.look * _r.y * 0.1 * (1.0 - down), 0)
	head_at.y -= rise * m.head_steady
	var yaw := (p.look * 0.35 + m.head_yaw) * (1.0 - down * 0.7)
	head_at.z -= sin(yaw) * neck_len * 0.35
	_place(_neck, chest, head_at)
	_head.position = head_at + Vector3(0, p.jaw * _px(0.4), 0)
	_head.rotation = Vector3(-m.roll * 0.7, yaw, -lerpf(rig.num("head_tilt", 0.3), 1.2, down) - m.pitch * 0.7)
	for k in _ears.size():
		_ears[k].rotation = Vector3((1.0 if k % 2 else -1.0) * p.ear * 0.6, 0, m.ears)
	# The tail swings on after the body, and lifts when it trots.
	_tail.rotation = Vector3(p.tail * 0.8 + m.tail, 0, 0.35 - m.pitch * 0.8 + m.trot * 0.35)




## The knee (or hock) of a two-bone leg from hip to foot, bending forward for forelegs, back for hind.
func _knee(hip: Vector3, foot: Vector3, fore: bool) -> Vector3:
	var bone := absf(foot.y - hip.y) * 0.56
	var j := AnimalArt.joint(Vector2(hip.x, -hip.y), Vector2(foot.x, -foot.y), bone, bone, -1.0 if fore else 1.0)
	return Vector3(j.x, -j.y, hip.z)




func _pose_bird(p: AnimalPose) -> void:
	var waddle := sin(p.gait * TAU) * 0.13 * p.stride if rig.flag("waddle") else 0.0
	var air := p.hop * _leg * 0.8
	_body.position = Vector3(0, _leg + _r.y * 0.8 + absf(sin(p.gait * TAU)) * _leg * 0.08 * p.stride + air, 0)
	_body.rotation = Vector3(waddle + motion.roll, 0, 0.22 - 0.12 * p.head + motion.pitch)
	_body.scale = Vector3(1.0 + motion.squash * 0.6, 1.0 - motion.squash, 1.0 + motion.squash * 0.6)
	for leg in _legs:
		var hip: Vector3 = leg["hip"]
		var u := fposmod(p.gait + float(leg["phase"]), 1.0)
		var off := AnimalArt.foot_offset(u, 0.9 * _leg, 0.45 * _leg) * p.stride
		# Feet planted on the ground, whatever the body's lean (worked out on the ground, then into its space).
		var on_ground := _body.transform * hip
		var foot := _body.transform.affine_inverse() * Vector3(on_ground.x + off.x, -off.y, on_ground.z)
		var knee := _knee(hip, foot, false)
		_place(leg["upper"], hip, knee)
		_place(leg["lower"], knee, foot)
		(leg["hoof"] as Node3D).position = foot
	var down := smoothstep(0.0, 1.0, p.head)
	var neck_len := _px(rig.pair("neck", Vector2(7, 7)).x)
	var shoulder := Vector3(_r.x * 0.7, _r.y * 0.35, 0)
	var thrust := (fposmod(p.gait * 2.0, 1.0) - 0.5) * _px(3.0) * p.stride
	var up_at := shoulder + Vector3(0.25, 1.0, 0).normalized() * neck_len + Vector3(-thrust, 0, 0)
	var peck_at := Vector3(shoulder.x + neck_len, -_body.position.y + _r.y * 0.3, 0)
	var head_at := up_at.lerp(peck_at, down)
	_place(_neck, shoulder, head_at)
	_head.position = head_at
	_head.rotation = Vector3(0, p.look * 0.4 + motion.head_yaw * (1.0 - down * 0.7), -down * 0.9 - motion.pitch * 0.6)
	for k in _wings.size():
		var side := -1.0 if k == 0 else 1.0
		_wings[k].rotation = Vector3(side * (p.wing * 1.2 + sin(p.time * 26.0) * 0.5 * p.wing), 0, 0)
	_tail.rotation = Vector3(p.tail * 0.5 + motion.tail * 0.6, 0, 0.6 + p.display * 0.9 - motion.pitch)
	for f in _tail.get_children():
		var n := _tail.get_child_count()
		var i := f.get_index()
		(f as Node3D).rotation.x = (i / maxf(n - 1.0, 1.0) - 0.5) * lerpf(1.0, 2.6, p.display)




func _pose_turtle(p: AnimalPose) -> void:
	_body.position = Vector3(0, _r.y * 0.6, 0)
	for leg in _legs:
		var hip: Vector3 = leg["hip"]
		(leg["stub"] as Node3D).position = hip + Vector3(
			sin(p.gait * TAU + float(leg["phase"]) * TAU) * _px(2.0) * p.stride,
			0,
			0
		)
	var out := clampf(0.55 + 0.45 * maxf(p.stride, absf(p.look)), 0.0, 1.0)
	_head.position = Vector3(_r.x * (0.75 + 0.35 * out), _r.y * 0.1 - p.head * _px(2.0), 0)
	_head.rotation.y = p.look * 0.5




func _pose_bee(p: AnimalPose) -> void:
	_body.position = Vector3(0, _px(rig.size("hover", 18.0)) + sin(p.time * 3.3) * _px(2.0), 0)
	for k in _wings.size():
		_wings[k].rotation.x = (1.0 if k else -1.0) * (0.3 + sin(p.time * 60.0) * 0.5)
