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

var rig: AnimalRig
var behaviour: AnimalBehaviour   # shared with the 2D piece; ObjectLayer updates it each frame
var heading := 0.0               # radians around +y; 0 faces +x
var home := Vector3.ZERO         # the tile centre it wanders around

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


static func create(it: Dictionary, mind: AnimalBehaviour, at: Vector3) -> Animal3D:
	var a := Animal3D.new()
	a.rig = AnimalRig.of(it)
	a.behaviour = mind
	a.home = at
	a.position = at
	a._last = at
	a.heading = PI * 0.75 if mind == null or mind.facing < 0.0 else -PI * 0.25
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
	rotation.y = heading


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
		_legs.append({"hip": hip, "upper": upper, "lower": lower, "hoof": hoof, "phase": LEG_PHASES[k], "fore": fore})
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
		ModelKit.ball(_head, Vector3(hl * 0.05, hh * 0.15, side * hh * 0.4), eye_r, ModelKit.paint(EYE, 0.8))
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
		ModelKit.ball(_head, Vector3(hr * 0.4, hr * 0.25, side * hr * 0.75), hr * 0.16 * rig.num("eye_scale", 1.0),
			ModelKit.paint(EYE, 0.8))


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


# ---------------------------------------------------------------- moving


## Poses the animal for this frame from its behaviour (call every frame it's on screen).
func update(delta: float) -> void:
	var p: AnimalPose = behaviour.pose if behaviour != null else AnimalPose.rest()
	if behaviour != null:
		position = home + IsoProjection.ground_of(behaviour.offset)
	# Face where it's going: turn smoothly toward its direction of travel.
	var moved := position - _last
	_last = position
	if Vector2(moved.x, moved.z).length() > 0.0005:
		var want := atan2(-moved.z, moved.x)
		heading = rotate_toward(heading, want, TURN_RATE * delta)
	rotation.y = heading
	match rig.type:
		"bird":
			_pose_bird(p)
		"bug":
			_pose_bee(p)
		"shell":
			_pose_turtle(p)
		_:
			_pose_quad(p)


func _pose_quad(p: AnimalPose) -> void:
	var rise := pow(sin(p.gait * TAU * 2.0), 2.0) * _leg * 0.06 * p.stride
	var air := p.hop * _leg * 0.55
	_body.position = Vector3(0, _leg + _r.y * 0.62 + rise + air + p.breath * _r.y * 0.01, 0)
	var reach := AnimalArt.STRIDE * _leg
	for leg in _legs:
		var hip: Vector3 = leg["hip"]
		var u := fposmod(p.gait + float(leg["phase"]), 1.0)
		var off := AnimalArt.foot_offset(u, reach, AnimalArt.LIFT * _leg) * p.stride
		# Feet on the ground, below the hip (in body space the ground is at -_body.y).
		var ground := -_body.position.y + p.hop * _leg * 0.4
		var foot := Vector3(hip.x + off.x, ground - off.y, hip.z)
		var knee := _knee(hip, foot, bool(leg["fore"]))
		_place(leg["upper"], hip, knee)
		_place(leg["lower"], knee, foot)
		(leg["hoof"] as Node3D).position = foot
	# Neck and head: up and looking about, or down to graze, chewing.
	var down := smoothstep(0.0, 1.0, p.head)
	var neck_len := _px(rig.pair("neck", Vector2(14, 9)).x)
	var chest := Vector3(_r.x * 0.72, _r.y * 0.3, 0)
	var up_at := chest + Vector3(cos(-rig.num("neck_up", -0.6)), sin(-rig.num("neck_up", -0.6)), 0) * neck_len
	var graze_at := Vector3(chest.x + neck_len * 0.8, -_body.position.y + _r.y * 0.35, 0)
	var head_at := up_at.lerp(graze_at, down) + Vector3(0, p.look * _r.y * 0.1 * (1.0 - down), 0)
	_place(_neck, chest, head_at)
	_head.position = head_at + Vector3(0, p.jaw * _px(0.4), 0)
	_head.rotation = Vector3(0, p.look * 0.35 * (1.0 - down), -lerpf(rig.num("head_tilt", 0.3), 1.2, down))
	for k in _ears.size():
		_ears[k].rotation.x = (1.0 if k % 2 else -1.0) * p.ear * 0.6
	_tail.rotation = Vector3(p.tail * 0.8, 0, 0.35)


## The knee (or hock) of a two-bone leg from hip to foot, bending forward for forelegs, back for hind.
func _knee(hip: Vector3, foot: Vector3, fore: bool) -> Vector3:
	var bone := absf(foot.y - hip.y) * 0.56
	var j := AnimalArt.joint(Vector2(hip.x, -hip.y), Vector2(foot.x, -foot.y), bone, bone, -1.0 if fore else 1.0)
	return Vector3(j.x, -j.y, hip.z)


func _pose_bird(p: AnimalPose) -> void:
	var waddle := sin(p.gait * TAU) * 0.13 * p.stride if rig.flag("waddle") else 0.0
	var air := p.hop * _leg * 0.8
	_body.position = Vector3(0, _leg + _r.y * 0.8 + absf(sin(p.gait * TAU)) * _leg * 0.08 * p.stride + air, 0)
	_body.rotation = Vector3(waddle, 0, 0.22 - 0.12 * p.head)
	for leg in _legs:
		var hip: Vector3 = leg["hip"]
		var u := fposmod(p.gait + float(leg["phase"]), 1.0)
		var off := AnimalArt.foot_offset(u, 0.9 * _leg, 0.45 * _leg) * p.stride
		var foot := Vector3(hip.x + off.x, -_body.position.y - off.y, hip.z)
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
	_head.rotation = Vector3(0, p.look * 0.4, -down * 0.9)
	for k in _wings.size():
		var side := -1.0 if k == 0 else 1.0
		_wings[k].rotation = Vector3(side * (p.wing * 1.2 + sin(p.time * 26.0) * 0.5 * p.wing), 0, 0)
	_tail.rotation = Vector3(p.tail * 0.5, 0, 0.6 + p.display * 0.9)
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
