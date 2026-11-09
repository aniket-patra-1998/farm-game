class_name VehicleModel
extends RefCounted
## FarmVille's four vehicles in 3D, facing down the farm toward the camera's right (+x): the Tractor (a
## bonnet, an open cab with a canopy, big ridged back wheels, small front ones, an exhaust stack), the
## Harvester (a reel at the front, a grain tank), the Seeder (a tractor towing a row of seed hoppers) and
## the Combine (a big body, a wide header with a turning reel, an unloading pipe, a glazed cab). The
## Combine still being built is a bare chassis on blocks. The node's origin is its tile's back corner.

const TYRE := Color("#2a2a2a")
const RIM := Color("#e8d27a")
const METAL := Color("#b9c0c4")
const SEAT := Color("#3a3a3a")


static func build(it: Dictionary, chassis := false) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.position = Vector3(0.5, 0, 0.5)
	root.add_child(body)
	var col := Color.html(str(it.get("color", "#c0392b")))
	if chassis:
		_chassis(body, col)
		return ModelKit.bake(root)
	match str(it.get("id", "")):
		"harvester":
			_harvester(body, col)
		"seeder":
			_tractor(body, Color("#c0392b"), 0.12)
			_hoppers(body, col)
		"combine":
			_combine(body, col)
		_:
			_tractor(body, col, 0.0)
	return ModelKit.bake(root)


## A wheel standing on the ground at `at` (its centre's x and z), facing sideways (along z).
static func _wheel(parent: Node3D, at: Vector3, r: float, w: float) -> void:
	var tyre := ModelKit.cylinder(parent, Vector3.ZERO, r, w, ModelKit.paint(TYRE), -1.0, 16)
	tyre.rotation.x = PI / 2.0
	tyre.position = Vector3(at.x, r, at.z)
	var rim := ModelKit.cylinder(parent, Vector3.ZERO, r * 0.55, w + 0.01, ModelKit.paint(RIM, 0.4), -1.0, 12)
	rim.rotation.x = PI / 2.0
	rim.position = Vector3(at.x, r, at.z)
	# Tread blocks around the tyre, so it reads as a tractor tyre and not a disc.
	for k in 10:
		var a := TAU * k / 10.0
		var lug := ModelKit.box(
			parent,
			Vector3(-0.012, -0.01, -w / 2.0),
			Vector3(0.012, 0.012, w / 2.0),
			ModelKit.paint(TYRE)
		)
		lug.position = Vector3(at.x + cos(a) * r, r + sin(a) * r, at.z)
		lug.rotation.z = a


static func _tractor(b: Node3D, col: Color, shift: float) -> void:
	var o := Vector3(shift, 0, 0)
	var dark := col.darkened(0.25)
	# Chassis, engine bonnet with a grille, and the rear body over the big wheels.
	ModelKit.box(b, o + Vector3(-0.2, 0.1, -0.08), o + Vector3(0.22, 0.17, 0.08), ModelKit.paint(dark))
	ModelKit.box(b, o + Vector3(0.0, 0.14, -0.07), o + Vector3(0.24, 0.27, 0.07), ModelKit.paint(col, 0.5))
	ModelKit.box(b, o + Vector3(0.24, 0.15, -0.06), o + Vector3(0.25, 0.26, 0.06), ModelKit.paint(Color("#444444")))
	ModelKit.box(b, o + Vector3(-0.2, 0.15, -0.1), o + Vector3(0.02, 0.27, 0.1), ModelKit.paint(col, 0.5))
	# Seat and steering wheel, under a canopy on four posts.
	ModelKit.box(b, o + Vector3(-0.15, 0.27, -0.05), o + Vector3(-0.06, 0.3, 0.05), ModelKit.paint(SEAT))
	ModelKit.box(b, o + Vector3(-0.16, 0.3, -0.05), o + Vector3(-0.14, 0.38, 0.05), ModelKit.paint(SEAT))
	var steer := ModelKit.cylinder(b, Vector3.ZERO, 0.035, 0.01, ModelKit.paint(SEAT), -1.0, 10)
	steer.position = o + Vector3(-0.02, 0.36, 0)
	steer.rotation.z = -0.6
	for x: float in [-0.17, 0.0]:
		for z: float in [-0.09, 0.09]:
			ModelKit.box(
				b,
				o + Vector3(x - 0.008, 0.27, z - 0.008),
				o + Vector3(x + 0.008, 0.48, z + 0.008),
				ModelKit.paint(METAL)
			)
	ModelKit.box(b, o + Vector3(-0.2, 0.48, -0.12), o + Vector3(0.03, 0.5, 0.12), ModelKit.paint(col.lightened(0.15)))
	# Exhaust stack with a cap.
	ModelKit.cylinder(b, o + Vector3(0.17, 0.27, -0.04), 0.012, 0.13, ModelKit.paint(Color("#555555"), 0.6))
	ModelKit.cylinder(b, o + Vector3(0.17, 0.4, -0.04), 0.017, 0.012, ModelKit.paint(Color("#333333")))
	# Mudguards over the rear wheels.
	for z: float in [-0.12, 0.12]:
		ModelKit.box(b, o + Vector3(-0.2, 0.26, z - 0.035), o + Vector3(-0.02, 0.28, z + 0.035), ModelKit.paint(col))
	_wheel(b, o + Vector3(-0.11, 0, -0.13), 0.13, 0.07)
	_wheel(b, o + Vector3(-0.11, 0, 0.13), 0.13, 0.07)
	_wheel(b, o + Vector3(0.17, 0, -0.1), 0.075, 0.05)
	_wheel(b, o + Vector3(0.17, 0, 0.1), 0.075, 0.05)
	# Headlights.
	for z: float in [-0.04, 0.04]:
		ModelKit.ball(b, o + Vector3(0.245, 0.24, z), 0.014, ModelKit.paint(Color("#fff3c4"), 0.8))


static func _harvester(b: Node3D, col: Color) -> void:
	_tractor(b, col, -0.06)
	# The reel at the front: a drum with bats, on side arms.
	var reel := ModelKit.cylinder(b, Vector3.ZERO, 0.06, 0.36, ModelKit.paint(col.darkened(0.15)), -1.0, 8)
	reel.rotation.x = PI / 2.0
	reel.position = Vector3(0.3, 0.12, 0)
	for k in 6:
		var a := TAU * k / 6.0
		var bat := ModelKit.box(b, Vector3(-0.006, -0.03, -0.18), Vector3(0.006, 0.03, 0.18), ModelKit.paint(METAL))
		bat.position = Vector3(0.3 + cos(a) * 0.07, 0.12 + sin(a) * 0.07, 0)
		bat.rotation.z = a
	for z: float in [-0.19, 0.19]:
		ModelKit.box(b, Vector3(0.18, 0.1, z - 0.008), Vector3(0.32, 0.14, z + 0.008), ModelKit.paint(col))
	# The grain tank behind the cab.
	ModelKit.box(b, Vector3(-0.3, 0.27, -0.09), Vector3(-0.18, 0.42, 0.09), ModelKit.paint(col.lightened(0.1), 0.4))


static func _hoppers(b: Node3D, col: Color) -> void:
	# A tow bar and a frame with three seed hoppers on two little wheels.
	ModelKit.box(b, Vector3(-0.22, 0.09, -0.015), Vector3(-0.06, 0.11, 0.015), ModelKit.paint(METAL))
	ModelKit.box(b, Vector3(-0.42, 0.1, -0.2), Vector3(-0.22, 0.13, 0.2), ModelKit.paint(col.darkened(0.2)))
	for k in 3:
		var z := -0.13 + 0.13 * k
		ModelKit.cylinder(b, Vector3(-0.32, 0.13, z), 0.05, 0.12, ModelKit.paint(col, 0.4), 0.035, 10)
		ModelKit.cylinder(b, Vector3(-0.32, 0.25, z), 0.052, 0.012, ModelKit.paint(col.lightened(0.2)), -1.0, 10)
	_wheel(b, Vector3(-0.32, 0, -0.22), 0.06, 0.03)
	_wheel(b, Vector3(-0.32, 0, 0.22), 0.06, 0.03)


static func _combine(b: Node3D, col: Color) -> void:
	var dark := col.darkened(0.25)
	ModelKit.box(b, Vector3(-0.32, 0.12, -0.17), Vector3(0.14, 0.42, 0.17), ModelKit.paint(col, 0.4))
	ModelKit.box(b, Vector3(-0.32, 0.42, -0.12), Vector3(-0.05, 0.5, 0.12), ModelKit.paint(col.lightened(0.1), 0.4))
	# Glazed cab up front.
	ModelKit.box(b, Vector3(0.0, 0.42, -0.08), Vector3(0.14, 0.58, 0.08), ModelKit.glass())
	ModelKit.box(b, Vector3(-0.01, 0.58, -0.09), Vector3(0.15, 0.6, 0.09), ModelKit.paint(col))
	# The header: a wide trough with a reel, on the front.
	ModelKit.box(b, Vector3(0.14, 0.05, -0.36), Vector3(0.36, 0.12, 0.36), ModelKit.paint(dark))
	var reel := ModelKit.cylinder(b, Vector3.ZERO, 0.055, 0.7, ModelKit.paint(METAL), -1.0, 8)
	reel.rotation.x = PI / 2.0
	reel.position = Vector3(0.3, 0.17, 0)
	for k in 5:
		ModelKit.box(b, Vector3(0.36, 0.05, -0.34 + 0.17 * k - 0.01), Vector3(0.42, 0.07, -0.34 + 0.17 * k + 0.01),
			ModelKit.paint(METAL))
	# The unloading pipe, folded back along the side.
	var pipe := ModelKit.cylinder(b, Vector3.ZERO, 0.025, 0.42, ModelKit.paint(col.lightened(0.1)), -1.0, 8)
	pipe.rotation.z = PI / 2.0 - 0.15
	pipe.position = Vector3(-0.15, 0.48, -0.19)
	_wheel(b, Vector3(0.0, 0, -0.18), 0.14, 0.08)
	_wheel(b, Vector3(0.0, 0, 0.18), 0.14, 0.08)
	_wheel(b, Vector3(-0.27, 0, -0.16), 0.08, 0.05)
	_wheel(b, Vector3(-0.27, 0, 0.16), 0.08, 0.05)


## A vehicle being built: its frame and axles on wooden blocks, a toolbox beside it.
static func _chassis(b: Node3D, col: Color) -> void:
	var frame := ModelKit.paint(col.darkened(0.3))
	for z: float in [-0.12, 0.12]:
		ModelKit.box(b, Vector3(-0.3, 0.14, z - 0.02), Vector3(0.25, 0.18, z + 0.02), frame)
	for x: float in [-0.2, 0.15]:
		ModelKit.box(b, Vector3(x - 0.015, 0.12, -0.2), Vector3(x + 0.015, 0.15, 0.2), ModelKit.paint(METAL))
		for z: float in [-0.14, 0.14]:
			ModelKit.box(b, Vector3(x - 0.05, 0, z - 0.04), Vector3(x + 0.05, 0.12, z + 0.04),
				ModelKit.surface(Color("#b07a4c"), "boards", 0.0))
	ModelKit.box(b, Vector3(0.28, 0, 0.15), Vector3(0.4, 0.07, 0.22), ModelKit.paint(Color("#c0392b"), 0.4))
