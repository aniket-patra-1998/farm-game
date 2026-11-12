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
const SCALE := 1.45  # modelled at a little over half a tile; on the farm a vehicle nearly fills its tile
# Meta on the pivot of a wheel (its radius in model units) or of a reel (its radius, negative).
const SPIN := &"vehicle_spin"
# Meta on the pivot of an implement: the angle (radians about the across axis) it is lifted by when not working.
const LIFT := &"vehicle_lift"
const LIFTED := 0.5
const EXHAUST := {"tractor": Vector3(0.17, 0.42, -0.04), "seeder": Vector3(0.29, 0.42, -0.04),
	"harvester": Vector3(0.11, 0.42, -0.04), "combine": Vector3(-0.25, 0.6, 0.1)}   # where the smoke leaves

const WIDTH := {"tractor": 0.34, "seeder": 0.46, "harvester": 0.4, "combine": 0.74}  # across, in model units

static var _rig := false  # while a rig is being built, wheels and reels are pivots that can turn


## How big the whole model stands on the farm: the common SCALE times the vehicle's own size (a Combine is
## clearly larger than a Tractor).
static func scale_of(it: Dictionary) -> float:
	return SCALE * float(it.get("size", 1.0))


## How wide the vehicle stands across its direction of travel, in tiles.
static func width_of(it: Dictionary) -> float:
	return float(WIDTH.get(str(it.get("id", "")), 0.34)) * scale_of(it)


## The model of vehicle `it`. A `rig` keeps each wheel and reel as a pivot of its own (VehicleRun turns them);
## otherwise everything is merged into a few draws.
static func build(it: Dictionary, chassis := false, rig := false) -> Node3D:
	_rig = rig and not chassis
	var root := Node3D.new()
	var body := Node3D.new()
	body.position = Vector3(0.5, 0, 0.5)
	body.scale = Vector3.ONE * scale_of(it)
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
			_drill(body, col)
		"combine":
			_combine(body, col)
		_:
			_tractor(body, col, 0.0)
			_plough(body, col)
	return ModelKit.bake(root)


## A wheel standing on the ground at `at` (its centre's x and z), facing sideways (along z). Its parts hang on a
## pivot at its centre, which a rig keeps whole so it can turn.
static func _wheel(parent: Node3D, at: Vector3, r: float, w: float) -> void:
	var hub := Node3D.new()
	hub.position = Vector3(at.x, r, at.z)
	parent.add_child(hub)
	var tyre := ModelKit.cylinder(hub, Vector3.ZERO, r, w, ModelKit.paint(TYRE), -1.0, 16)
	tyre.rotation.x = PI / 2.0
	tyre.position = Vector3.ZERO
	var rim := ModelKit.cylinder(hub, Vector3.ZERO, r * 0.55, w + 0.01, ModelKit.paint(RIM, 0.4), -1.0, 12)
	rim.rotation.x = PI / 2.0
	rim.position = Vector3.ZERO
	# Tread blocks around the tyre, so it reads as a tractor tyre and not a disc.
	for k in 10:
		var a := TAU * k / 10.0
		var lug := ModelKit.box(
			hub,
			Vector3(-0.012, -0.01, -w / 2.0),
			Vector3(0.012, 0.012, w / 2.0),
			ModelKit.paint(TYRE)
		)
		lug.position = Vector3(cos(a) * r, sin(a) * r, 0)
		lug.rotation.z = a
	_pivot(hub, r)


## In a rig, a pivot is left whole (not merged) and marked with its radius, so it can turn.
static func _pivot(node: Node3D, radius: float) -> void:
	if _rig:
		node.set_meta(ModelKit.KEEP, true)
		node.set_meta(SPIN, radius)


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
	# Headlights, with a grille of slats between them and a bumper under.
	for z: float in [-0.04, 0.04]:
		ModelKit.ball(b, o + Vector3(0.245, 0.24, z), 0.014, ModelKit.paint(Color("#fff3c4"), 0.8))
	for k in 3:
		ModelKit.box(b, o + Vector3(0.246, 0.17 + 0.02 * k, -0.026), o + Vector3(0.256, 0.18 + 0.02 * k, 0.026),
			ModelKit.paint(Color("#2e2e2e")))
	ModelKit.box(b, o + Vector3(0.235, 0.09, -0.075), o + Vector3(0.265, 0.12, 0.075), ModelKit.paint(METAL))
	# Hubcaps, a stripe along the bonnet and a wing mirror, so it reads as a made machine.
	ModelKit.box(
		b,
		o + Vector3(0.0, 0.215, -0.0715),
		o + Vector3(0.24, 0.225, -0.0705),
		ModelKit.paint(Color("#f2f2f2"))
	)
	ModelKit.box(b, o + Vector3(0.0, 0.215, 0.0705), o + Vector3(0.24, 0.225, 0.0715), ModelKit.paint(Color("#f2f2f2")))
	ModelKit.box(b, o + Vector3(0.01, 0.38, 0.1), o + Vector3(0.025, 0.43, 0.108), ModelKit.paint(METAL))
	ModelKit.box(b, o + Vector3(0.008, 0.4, 0.108), o + Vector3(0.028, 0.43, 0.124), ModelKit.paint(Color("#2e2e2e")))
	# The farmer at the wheel: body, head and a straw hat, under the canopy.
	_driver(b, o + Vector3(-0.1, 0.3, 0))
	# A windscreen between the front posts.
	ModelKit.box(b, o + Vector3(0.0, 0.3, -0.088), o + Vector3(0.004, 0.46, 0.088), ModelKit.glass())


## A little farmer sitting in a cab: shirt, a round head and a straw hat with a brim.
static func _driver(b: Node3D, at: Vector3) -> void:
	ModelKit.box(b, at + Vector3(-0.025, 0.0, -0.04), at + Vector3(0.025, 0.09, 0.04), ModelKit.paint(Color("#3f6fb5")))
	ModelKit.ball(b, at + Vector3(0.0, 0.12, 0.0), 0.032, ModelKit.paint(Color("#e8b48a")))
	ModelKit.cylinder(b, at + Vector3(0.0, 0.14, 0.0), 0.05, 0.006, ModelKit.paint(Color("#d8b85a")), -1.0, 10)
	ModelKit.cylinder(b, at + Vector3(0.0, 0.145, 0.0), 0.03, 0.025, ModelKit.paint(Color("#d8b85a")), 0.026, 10)


static func _harvester(b: Node3D, col: Color) -> void:
	_tractor(b, col, -0.06)
	# The reel at the front: a drum with bats, on side arms.
	var reel := Node3D.new()
	reel.position = Vector3(0.3, 0.12, 0)
	b.add_child(reel)
	var drum := ModelKit.cylinder(reel, Vector3.ZERO, 0.06, 0.36, ModelKit.paint(col.darkened(0.15)), -1.0, 8)
	drum.rotation.x = PI / 2.0
	drum.position = Vector3.ZERO
	for k in 6:
		var a := TAU * k / 6.0
		var bat := ModelKit.box(reel, Vector3(-0.006, -0.03, -0.18), Vector3(0.006, 0.03, 0.18), ModelKit.paint(METAL))
		bat.position = Vector3(cos(a) * 0.07, sin(a) * 0.07, 0)
		bat.rotation.z = a
	_pivot(reel, -0.07)
	for z: float in [-0.19, 0.19]:
		ModelKit.box(b, Vector3(0.18, 0.1, z - 0.008), Vector3(0.32, 0.14, z + 0.008), ModelKit.paint(col))
	# The grain tank behind the cab.
	ModelKit.box(b, Vector3(-0.3, 0.27, -0.09), Vector3(-0.18, 0.42, 0.09), ModelKit.paint(col.lightened(0.1), 0.4))


## In a rig, an implement hangs on a pivot that VehicleRun lifts when the vehicle isn't working.
static func _hang_implement(parent: Node3D, at: Vector3) -> Node3D:
	var hitch := Node3D.new()
	hitch.position = at
	parent.add_child(hitch)
	if _rig:
		hitch.set_meta(ModelKit.KEEP, true)
		hitch.set_meta(LIFT, LIFTED)
	return hitch


## A three-furrow plough behind the tractor: a beam on the hitch and three angled blades that bite the ground.
static func _plough(b: Node3D, col: Color) -> void:
	var hitch := _hang_implement(b, Vector3(-0.22, 0.15, 0))
	ModelKit.box(hitch, Vector3(-0.2, -0.015, -0.015), Vector3(0.0, 0.015, 0.015), ModelKit.paint(METAL))
	ModelKit.box(hitch, Vector3(-0.22, -0.02, -0.17), Vector3(-0.19, 0.01, 0.17), ModelKit.paint(col.darkened(0.3)))
	for k in 3:
		var z := -0.12 + 0.12 * k
		ModelKit.box(hitch, Vector3(-0.215, -0.1, z - 0.004), Vector3(-0.205, -0.02, z + 0.004), ModelKit.paint(METAL))
		var share := ModelKit.box(hitch, Vector3(-0.07, -0.014, -0.045), Vector3(0.07, 0.0, 0.045),
			ModelKit.paint(Color("#6c7479"), 0.7))
		share.position = Vector3(-0.28, -0.13, z)
		share.rotation = Vector3(0.0, 0.0, -0.35)


## A seed drill behind the seeder's hoppers: a bar with a row of discs that cut the furrows.
static func _drill(b: Node3D, col: Color) -> void:
	var hitch := _hang_implement(b, Vector3(-0.42, 0.12, 0))
	ModelKit.box(hitch, Vector3(-0.02, -0.012, -0.19), Vector3(0.0, 0.012, 0.19), ModelKit.paint(METAL))
	for k in 5:
		var z := -0.16 + 0.08 * k
		var disc := ModelKit.cylinder(hitch, Vector3.ZERO, 0.045, 0.006, ModelKit.paint(Color("#6c7479"), 0.7), -1.0, 12)
		disc.position = Vector3(-0.03, -0.065, z)
		disc.rotation.x = PI / 2.0 - 0.12
		var arm := ModelKit.paint(col.darkened(0.2))
		ModelKit.box(hitch, Vector3(-0.03, -0.06, z - 0.002), Vector3(-0.02, 0.0, z + 0.002), arm)


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
	var reel := Node3D.new()
	reel.position = Vector3(0.3, 0.17, 0)
	b.add_child(reel)
	var drum := ModelKit.cylinder(reel, Vector3.ZERO, 0.055, 0.7, ModelKit.paint(METAL), -1.0, 8)
	drum.rotation.x = PI / 2.0
	drum.position = Vector3.ZERO
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		var bat := ModelKit.box(
			reel,
			Vector3(-0.007, -0.035, -0.35),
			Vector3(0.007, 0.035, 0.35),
			ModelKit.paint(METAL)
		)
		bat.position = Vector3(cos(a) * 0.075, sin(a) * 0.075, 0)
		bat.rotation.z = a
	_pivot(reel, -0.075)
	for k in 5:
		ModelKit.box(b, Vector3(0.36, 0.05, -0.34 + 0.17 * k - 0.01), Vector3(0.42, 0.07, -0.34 + 0.17 * k + 0.01),
			ModelKit.paint(METAL))
	# The unloading pipe, folded back along the side.
	var pipe := ModelKit.cylinder(b, Vector3.ZERO, 0.025, 0.42, ModelKit.paint(col.lightened(0.1)), -1.0, 8)
	pipe.rotation.z = PI / 2.0 - 0.15
	pipe.position = Vector3(-0.15, 0.48, -0.19)
	_driver(b, Vector3(0.05, 0.43, 0.0))
	# A ladder up the side to the cab, an exhaust, the grain tank's rim and a lamp on the cab roof.
	for k in 5:
		ModelKit.box(
			b,
			Vector3(0.0, 0.14 + 0.06 * k, 0.17),
			Vector3(0.05, 0.155 + 0.06 * k, 0.185),
			ModelKit.paint(METAL)
		)
	for x: float in [0.0, 0.05]:
		ModelKit.box(b, Vector3(x - 0.004, 0.13, 0.17), Vector3(x + 0.004, 0.42, 0.185), ModelKit.paint(METAL))
	ModelKit.cylinder(b, Vector3(-0.25, 0.5, 0.1), 0.014, 0.1, ModelKit.paint(Color("#555555"), 0.6))
	ModelKit.box(b, Vector3(-0.33, 0.495, -0.125), Vector3(-0.04, 0.515, 0.125), ModelKit.paint(col.darkened(0.15)))
	ModelKit.ball(b, Vector3(0.14, 0.6, 0.0), 0.02, ModelKit.paint(Color("#fff3c4"), 0.8))
	for z: float in [-0.12, 0.12]:
		ModelKit.ball(b, Vector3(0.145, 0.14, z), 0.02, ModelKit.paint(Color("#fff3c4"), 0.8))
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
