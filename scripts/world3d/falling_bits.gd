class_name FallingBits
extends MultiMeshInstance3D
## What falls from a tree: leaves that flutter down, lie a moment and fade, or fruit that drops, bounces, rolls
## and fades (`fruit`). One MultiMesh holds every piece of one sort as a ring (the oldest gives way to the
## newest), so any number of them is one draw, and nothing runs while none is falling. For show only: nothing
## here is picked up, and nothing here changes the game (TreeLife decides what falls and when).

const CAPACITY := 96
const LEAF_FALL := 0.42       # a leaf's steady fall, tiles a second..
const LEAF_FLUTTER := 0.16    # ..quicker and slower by this as it rocks..
const LEAF_SWAY := 0.28       # ..while it slips side to side this fast
const LEAF_PACE := 3.1        # the rock's pace (radians a second)
const LEAF_DRAG := 1.5        # how fast the push it left with dies away (per second)
const LEAF_FLAT := Vector3(1.0, 0.12, 0.6)   # a leaf's shape, of a ball
const LEAF_LIES := 1.2        # seconds a leaf lies on the grass before it fades..
const FRUIT_LIES := 1.6       # ..and a fruit
const FADE := 0.5             # seconds either takes to shrink away
const GRAVITY := 7.5          # a fruit's fall (tiles a second, each second)
const BOUNCE := 0.38          # the speed a fruit keeps when it bounces..
const BOUNCES := 2            # ..how many times it does, before it rolls..
const ROLL_DRAG := 3.0        # ..and how fast the roll dies away (per second)
const SLIP := Vector3(0.7071, 0, -0.7071)   # the way a leaf slips as it rocks: across the screen

var fruit := false            # these are fruit (false: leaves)

var _pos: Array[Vector3] = []
var _vel: Array[Vector3] = []
var _tint: Array[Color] = []
var _age := PackedFloat32Array()     # seconds since it left the tree
var _down := PackedFloat32Array()    # seconds since it came to rest (-1: still falling)
var _size := PackedFloat32Array()    # its radius, in tiles (0: the slot is free)
var _beat := PackedFloat32Array()    # its own beat (radians), so no two rock together
var _hits := PackedInt32Array()      # times it has hit the ground
var _next := 0
var _live := 0


func _init(of_fruit := false) -> void:
	fruit = of_fruit
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(80.0, 8.0, 80.0))
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 10 if fruit else 6
	ball.rings = 5 if fruit else 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = ball
	mm.instance_count = CAPACITY
	multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	if not fruit:
		# A leaf falls in its crown's colours. The crown's shader shows its painted tones as screen colours, and a
		# share of them in full sun (ModelKit.SPRAY_CURVE, SPRAY_DEPTH): so does a leaf, or it falls pale.
		mat.vertex_color_is_srgb = true
		var share := pow(ModelKit.SPRAY_DEPTH, 1.0 / ModelKit.SPRAY_CURVE)
		mat.albedo_color = Color(share, share, share)
	material_override = mat
	_pos.resize(CAPACITY)
	_vel.resize(CAPACITY)
	_tint.resize(CAPACITY)
	for arr: PackedFloat32Array in [_age, _down, _size, _beat]:
		arr.resize(CAPACITY)
	_hits.resize(CAPACITY)
	for i in CAPACITY:
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	set_process(false)


## How many pieces are in the air or on the grass.
func live() -> int:
	return _live


## One piece leaves a tree at `at`, moving at `push`, `size` across (its radius, in tiles), in `col`.
func drop(at: Vector3, push: Vector3, col: Color, size: float, beat := 0.0) -> void:
	var i := _next
	_next = (_next + 1) % CAPACITY
	if _size[i] <= 0.0:
		_live += 1
	_pos[i] = at
	_vel[i] = push
	_tint[i] = col
	_age[i] = 0.0
	_down[i] = -1.0
	_size[i] = size
	_beat[i] = beat
	_hits[i] = 0
	multimesh.set_instance_color(i, col)
	set_process(true)


func _process(delta: float) -> void:
	tick(delta)


## Moves every piece on by `delta` seconds (the frame's own; tests step it).
func tick(delta: float) -> void:
	for i in CAPACITY:
		if _size[i] <= 0.0:
			continue
		_age[i] += delta
		if fruit:
			_move_fruit(i, delta)
		else:
			_move_leaf(i, delta)
		var left := 1.0
		if _down[i] >= 0.0:
			_down[i] += delta
			left = clampf(1.0 - (_down[i] - (FRUIT_LIES if fruit else LEAF_LIES)) / FADE, 0.0, 1.0)
		if left <= 0.0:
			_size[i] = 0.0
			_live -= 1
			multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		multimesh.set_instance_transform(i, Transform3D(_turn(i) * Basis.from_scale(
			(Vector3.ONE if fruit else LEAF_FLAT) * _size[i] * left), _pos[i]))
	if _live <= 0:
		set_process(false)


func _move_leaf(i: int, delta: float) -> void:
	if _down[i] >= 0.0:
		return
	var rock := sin(_age[i] * LEAF_PACE + _beat[i])
	_vel[i] = _vel[i].lerp(Vector3.ZERO, clampf(delta * LEAF_DRAG, 0.0, 1.0))
	_pos[i] += (_vel[i] + Vector3(0, -(LEAF_FALL + LEAF_FLUTTER * rock), 0) + SLIP * rock * LEAF_SWAY) * delta
	if _pos[i].y <= _size[i] * LEAF_FLAT.y:
		_pos[i].y = _size[i] * LEAF_FLAT.y
		_down[i] = 0.0


func _move_fruit(i: int, delta: float) -> void:
	if _hits[i] <= BOUNCES:
		_vel[i].y -= GRAVITY * delta
	_pos[i] += _vel[i] * delta
	if _pos[i].y <= _size[i] and _hits[i] <= BOUNCES:
		_pos[i].y = _size[i]
		_hits[i] += 1
		_vel[i] = Vector3(_vel[i].x * 0.6, -_vel[i].y * BOUNCE if _hits[i] <= BOUNCES else 0.0, _vel[i].z * 0.6)
		if _hits[i] > BOUNCES:
			_down[i] = 0.0
	if _hits[i] > BOUNCES:
		_vel[i] = _vel[i].lerp(Vector3.ZERO, clampf(delta * ROLL_DRAG, 0.0, 1.0))


## How a piece is turned this moment: a leaf spins and rocks as it falls and lies flat once down.
func _turn(i: int) -> Basis:
	if fruit:
		return Basis.IDENTITY
	if _down[i] >= 0.0:
		return Basis(Vector3.UP, _beat[i])
	var rock := sin(_age[i] * LEAF_PACE + _beat[i])
	return Basis(Vector3.UP, _age[i] * (2.0 + _beat[i] * 0.5)) * Basis(Vector3.RIGHT, 0.3 + 0.5 * rock)
