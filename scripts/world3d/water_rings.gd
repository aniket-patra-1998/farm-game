class_name WaterRings
extends MultiMeshInstance3D
## The rings that spread on water (our own touch): a swimmer's wake, a splash where the water is tapped, a
## fish's leap. Each is a quad lying on the surface in one MultiMesh held as a ring buffer
## (shaders/ring3d.gdshader), so any number of them is one draw, and nothing runs while the water is still (the
## node sleeps), as the dust (DustPuffs).

const CAPACITY := 96
const SPLASH := [[0.0, 0.5], [0.12, 0.38], [0.26, 0.26]]   # a splash's rings: [seconds before it starts, tiles wide]
const SPLASH_LIFE := 0.9

var _pos: Array[Vector3] = []
var _age := PackedFloat32Array()    # seconds lived (under 0: it has not started yet)
var _life := PackedFloat32Array()   # seconds a ring lives (0: the slot is free)
var _from := PackedFloat32Array()   # how wide it starts, in tiles
var _to := PackedFloat32Array()     # ..and ends
var _next := 0
var _live := 0


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(80.0, 6.0, 80.0))
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true   # (the compatibility renderer reads an unset instance colour as black)
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = CAPACITY
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ring3d.gdshader")
	mat.render_priority = 1   # (after the water it lies on)
	material_override = mat
	_pos.resize(CAPACITY)
	for arr: PackedFloat32Array in [_age, _life, _from, _to]:
		arr.resize(CAPACITY)
	for i in CAPACITY:
		_hide(i)
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


## One ring at `at` (on the water's surface), widening from `from` to `to` tiles across over `life` seconds,
## starting after `wait`.
func ring(at: Vector3, from: float, to: float, life: float, wait := 0.0) -> void:
	var i := _next
	_next = (_next + 1) % CAPACITY
	if _life[i] <= 0.0:
		_live += 1
	_pos[i] = at
	_age[i] = -wait
	_life[i] = maxf(life, 0.05)
	_from[i] = from
	_to[i] = to
	_draw(i)
	set_process(true)


## A splash at `at`: a few rings one inside another, `size` times the usual.
func splash(at: Vector3, size := 1.0) -> void:
	for one: Array in SPLASH:
		ring(at, 0.06 * size, float(one[1]) * size, SPLASH_LIFE, float(one[0]))


## Time passes: rings widen and fade; one that has lived its life is gone.
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
		_draw(i)
	if _live <= 0:
		set_process(false)


## How many rings are on the water.
func live() -> int:
	return _live


func _draw(i: int) -> void:
	var t := _age[i] / _life[i]
	var wide := lerpf(_from[i], _to[i], sqrt(maxf(t, 0.0)))
	multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(wide, 1.0, wide)), _pos[i]))
	multimesh.set_instance_color(i, Color.WHITE)
	multimesh.set_instance_custom_data(i, Color(t, 0, 0, 0))


func _hide(i: int) -> void:
	multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
