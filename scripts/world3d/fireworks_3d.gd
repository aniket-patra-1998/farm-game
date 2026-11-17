class_name Fireworks3D
extends MultiMeshInstance3D
## Fireworks in the sky over a building that has just grown (our own touch): for most a small golden burst
## over the roof, for the Barn a show, three rockets that climb and burst in gold, red and blue one after
## another (`launch`). Every spark is a quad in one MultiMesh held as a ring (shaders/spark3d.gdshader), so
## any amount of them is one draw, and nothing runs while the sky is empty (the node sleeps), as the dust
## (DustPuffs).

const CAPACITY := 192
const GRAVITY := 1.3           # how fast a spark falls, in tiles a second each second
const DRAG := 2.4              # how fast its flight slows (per second)
const SMALL_ABOVE := 0.5       # how far over the roof a small burst goes off, in tiles
const ROCKET_FROM := 1.8       # how far under its burst a rocket starts, in tiles..
const ROCKET_RISE := 0.4       # ..the seconds it climbs..
const TRAIL := Vector2(0.16, 0.28)   # ..and the sparks it leaves behind: their size in tiles, the seconds they last
## A burst: how many sparks, how fast they fly out (tiles a second), their size in tiles and the seconds they last.
const SMALL := {"sparks": 16, "speed": 2.0, "size": 0.28, "life": 0.8}
const BIG := {"sparks": 28, "speed": 3.6, "size": 0.38, "life": 1.1}
const GOLD: Array[Color] = [Color("#ffc21a"), Color("#ff8a1a"), Color("#fff1a8")]
const RED: Array[Color] = [Color("#ff3d4a"), Color("#ff8fa0")]
const BLUE: Array[Color] = [Color("#35b8ff"), Color("#a8e4ff")]
## The Barn's show: where each rocket bursts (tiles from the top of the roof; the camera looks along the
## diagonal, so left and right on screen are both x and z), its colours, and the seconds before it goes up.
const SHOW := [[Vector3(0, 1.3, 0), GOLD, 0.0], [Vector3(-1.1, 0.8, 0.9), RED, 0.3],
	[Vector3(1.0, 0.6, -0.9), BLUE, 0.6]]

var _pos: Array[Vector3] = []
var _vel: Array[Vector3] = []
var _age := PackedFloat32Array()    # seconds lived
var _life := PackedFloat32Array()   # seconds a spark lives (0: the slot is free)
var _size := PackedFloat32Array()   # size at birth, in tiles
var _tint: Array[Color] = []
var _next := 0
var _live := 0
var _rockets: Array = []            # rockets waiting or climbing: {"wait", "age", "to", "colours"}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(80.0, 12.0, 80.0))
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
	mat.shader = load("res://shaders/spark3d.gdshader")
	mat.render_priority = 2   # (after the farm: it draws over what stands in front)
	material_override = mat
	_pos.resize(CAPACITY)
	_vel.resize(CAPACITY)
	_tint.resize(CAPACITY)
	for arr: PackedFloat32Array in [_age, _life, _size]:
		arr.resize(CAPACITY)
	for i in CAPACITY:
		_hide(i)
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


## Fireworks over a building whose roof's top is at `top`: a small burst, or the Barn's show (`grand`).
func launch(top: Vector3, grand := false) -> void:
	if not grand:
		burst(top + Vector3(0, SMALL_ABOVE, 0), GOLD, SMALL)
		return
	for shot: Array in SHOW:
		_rockets.append({"wait": float(shot[2]), "age": 0.0, "to": top + (shot[0] as Vector3), "colours": shot[1]})
	set_process(true)


## One burst at `at`: sparks of `colours` flying out every way, as `kind` says (SMALL or BIG).
func burst(at: Vector3, colours: Array[Color], kind: Dictionary) -> void:
	for k in int(kind["sparks"]):
		var up := _rng.randf_range(-1.0, 1.0)
		var round := _rng.randf() * TAU
		var out := Vector3(cos(round) * sqrt(1.0 - up * up), up, sin(round) * sqrt(1.0 - up * up))
		_spark(at, out * float(kind["speed"]) * _rng.randf_range(0.7, 1.0), float(kind["size"]) * _rng.randf_range(0.7, 1.0),
			float(kind["life"]) * _rng.randf_range(0.75, 1.0), colours[k % colours.size()])


## Time passes: rockets go up and burst, sparks fly, fall and die.
func advance(delta: float) -> void:
	for rocket: Dictionary in _rockets.duplicate():
		if float(rocket["wait"]) > 0.0:
			rocket["wait"] = float(rocket["wait"]) - delta
			continue
		rocket["age"] = float(rocket["age"]) + delta
		var u := minf(float(rocket["age"]) / ROCKET_RISE, 1.0)
		var to: Vector3 = rocket["to"]
		var colours: Array[Color] = rocket["colours"]
		_spark((to - Vector3(0, ROCKET_FROM, 0)).lerp(to, 1.0 - (1.0 - u) * (1.0 - u)), Vector3.ZERO, TRAIL.x, TRAIL.y,
			colours[-1])
		if u >= 1.0:
			_rockets.erase(rocket)
			burst(to, colours, BIG)
	for i in CAPACITY:
		if _life[i] <= 0.0:
			continue
		_age[i] += delta
		if _age[i] >= _life[i]:
			_life[i] = 0.0
			_live -= 1
			_hide(i)
			continue
		_vel[i] = (_vel[i] + Vector3(0, -GRAVITY * delta, 0)) * exp(-DRAG * delta)
		_pos[i] += _vel[i] * delta
		_draw(i)
	if _live <= 0 and _rockets.is_empty():
		set_process(false)


## How many sparks are in the air, and how many rockets are waiting or on their way up.
func live() -> int:
	return _live


func rockets() -> int:
	return _rockets.size()


func _spark(at: Vector3, velocity: Vector3, size: float, life: float, tint: Color) -> void:
	var i := _next
	_next = (_next + 1) % CAPACITY
	if _life[i] <= 0.0:
		_live += 1
	_pos[i] = at
	_vel[i] = velocity
	_age[i] = 0.0
	_life[i] = maxf(life, 0.05)
	_size[i] = size
	_tint[i] = tint
	_draw(i)
	set_process(true)


func _draw(i: int) -> void:
	multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, _pos[i]))
	multimesh.set_instance_color(i, _tint[i])
	multimesh.set_instance_custom_data(i, Color(_age[i] / _life[i], _size[i], 0, 0))


func _hide(i: int) -> void:
	multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	multimesh.set_instance_custom_data(i, Color(1, 0, 0, 0))
