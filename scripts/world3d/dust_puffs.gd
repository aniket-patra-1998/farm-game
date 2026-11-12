class_name DustPuffs
extends MultiMeshInstance3D
## Dust kicked up by wheels and smoke from exhausts: soft round puffs that drift, swell and thin out. One
## MultiMesh holds them all as a ring (the oldest is replaced by the newest), so any amount of dust is one draw,
## and nothing runs while there is none (the node sleeps until the first puff).

const CAPACITY := 96
const DRAG := 1.6              # how fast a puff's drift slows (per second)

var _pos: Array[Vector3] = []
var _vel: Array[Vector3] = []
var _age := PackedFloat32Array()    # seconds lived
var _life := PackedFloat32Array()   # seconds a puff lives (0: the slot is free)
var _size := PackedFloat32Array()   # size at birth, in tiles
var _grow := PackedFloat32Array()   # how many times larger it swells by the end
var _tint: Array[Color] = []
var _next := 0
var _live := 0


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(80.0, 6.0, 80.0))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = CAPACITY
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/dust3d.gdshader")
	material_override = mat
	_pos.resize(CAPACITY)
	_vel.resize(CAPACITY)
	_tint.resize(CAPACITY)
	for arr: PackedFloat32Array in [_age, _life, _size, _grow]:
		arr.resize(CAPACITY)
	for i in CAPACITY:
		_hide(i)
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


## One puff at `at`, drifting with `velocity` (tiles per second), `size` tiles across at first, living `life`
## seconds, swelling `grow` times; `tint`'s alpha is how thick it starts.
func emit(at: Vector3, velocity: Vector3, size: float, life: float, tint: Color, grow := 2.2) -> void:
	var i := _next
	_next = (_next + 1) % CAPACITY
	if _life[i] <= 0.0:
		_live += 1
	_pos[i] = at
	_vel[i] = velocity
	_age[i] = 0.0
	_life[i] = maxf(life, 0.05)
	_size[i] = size
	_grow[i] = grow
	_tint[i] = tint
	_draw(i)
	set_process(true)


## Time passes: puffs drift, swell and thin; one that has lived its life is gone.
func advance(delta: float) -> void:
	for i in CAPACITY:
		if _life[i] <= 0.0:
			continue
		_age[i] += delta
		if _age[i] >= _life[i]:
			_life[i] = 0.0
			_live -= 1
			_hide(i)
			continue
		_vel[i] *= exp(-DRAG * delta)
		_pos[i] += _vel[i] * delta
		_draw(i)
	if _live <= 0:
		set_process(false)


## How many puffs are in the air.
func live() -> int:
	return _live


func _draw(i: int) -> void:
	var t := _age[i] / _life[i]
	var s := _size[i] * lerpf(1.0, _grow[i], sqrt(t))
	multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), _pos[i]))
	multimesh.set_instance_color(i, _tint[i])
	multimesh.set_instance_custom_data(i, Color(t, 0, 0, 0))


func _hide(i: int) -> void:
	multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
