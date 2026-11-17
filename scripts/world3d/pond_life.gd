class_name PondLife
extends Node3D
## What lives at a pond (our own touch; the small pond and the Duck Pond): a frog on a lily pad that bobs,
## dragonflies over the water by day, fireflies by night, and a fish that leaps now and then. Objects3D gives
## one to every pond standing on the farm (never to a picture of one). Its creatures move by themselves
## (DecorMotion.orbit, shaders/firefly3d.gdshader); only the fish's leap runs here, and only while it is in
## the air. A frozen pond has no fish leaping and no dragonflies.

const PAD := Color("#4f9a3a")
const FROG := Color("#5fae3c")
const FISH := Color("#f08a3c")
const WING := Color("#d8eef5")
const DRAGONFLIES := 2
const FIREFLIES := 6
const FIREFLY_SIZE := 0.07        # a firefly's light, in tiles across
const OVER := 0.22                # how far over the water the dragonflies and fireflies fly, in tiles
const LEAP_EVERY := Vector2(7.0, 18.0)   # seconds between a fish's leaps
const LEAP_TIME := 0.7            # seconds a leap lasts..
const LEAP_LONG := 0.3            # ..how far it goes, in tiles..
const LEAP_HIGH := 0.2            # ..and how high
const LOOK_EVERY := 1.5           # seconds between looks at the hour and the weather
const HOVER := {"speed": 1.3, "bob": 0.03, "bob_rate": 0.7, "flap": 0.5, "flap_rate": 38.0, "shoulder": 0.008}
const BOB := {"speed": 0.0, "bob": 0.004, "bob_rate": 0.35}

var rings: WaterRings             # where its fish's rings go (Objects3D's)
var _centre := Vector3.ZERO       # the middle of the water's surface, here
var _reach := Vector2.ONE         # the water's half sizes
var _by_day: Array[Node3D] = []
var _by_night: Node3D
var _fish: Node3D
var _leap := -1.0                 # seconds into a leap (under 0: none)
var _leap_from := Vector3.ZERO
var _leap_way := Vector3.RIGHT
var _rng := RandomNumberGenerator.new()


## The life of a pond whose water's middle is at `centre` (in the parent's space), `reach` its half sizes.
static func create(centre: Vector3, reach: Vector2, seed_value: int, to_rings: WaterRings) -> PondLife:
	var life := PondLife.new()
	life.rings = to_rings
	life._centre = centre
	life._reach = reach
	life._rng.seed = seed_value * 977 + 5
	life._build()
	return life


func _build() -> void:
	# A frog on its own lily pad, near the bank.
	var seat := Node3D.new()
	var pad := ModelKit.cylinder(seat, Vector3.ZERO, 0.07, 0.006, ModelKit.paint(PAD), -1.0, 9)
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ModelKit.ball(seat, Vector3(0, 0.03, 0), 0.032, ModelKit.paint(FROG), Vector3(1.0, 0.75, 1.25))
	for side: float in [-1.0, 1.0]:
		ModelKit.ball(seat, Vector3(side * 0.016, 0.052, -0.022), 0.011, ModelKit.paint(FROG.lightened(0.2)))
		ModelKit.ball(seat, Vector3(side * 0.03, 0.014, 0.018), 0.016, ModelKit.paint(FROG.darkened(0.1)),
			Vector3(1.0, 0.6, 1.5))
	DecorMotion.orbit(self, _spot(0.62) + Vector3(0, 0.004, 0), seat, BOB)
	for k in DRAGONFLIES:
		var hover: Dictionary = HOVER.duplicate()
		hover["radius"] = minf(_reach.x, _reach.y) * (0.35 + 0.25 * k)
		hover["phase"] = k * 2.7
		_by_day.append(DecorMotion.orbit(self, _centre + Vector3(0, OVER + 0.05 * k, 0), _dragonfly(), hover))
	var lights := MultiMeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * FIREFLY_SIZE
	lights.multimesh = MultiMesh.new()
	lights.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	lights.multimesh.use_colors = true   # (the compatibility renderer reads an unset instance colour as black)
	lights.multimesh.use_custom_data = true
	lights.multimesh.mesh = quad
	lights.multimesh.instance_count = FIREFLIES
	for k in FIREFLIES:
		lights.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY,
			_spot(_rng.randf_range(0.1, 0.95)) + Vector3(0, OVER * _rng.randf_range(0.6, 1.8), 0)))
		lights.multimesh.set_instance_color(k, Color.WHITE)
		lights.multimesh.set_instance_custom_data(k, Color(_rng.randf(), 0, 0, 0))
	var light := ShaderMaterial.new()
	light.shader = load("res://shaders/firefly3d.gdshader")
	lights.material_override = light
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lights)
	_by_night = lights
	_fish = Node3D.new()
	ModelKit.ball(_fish, Vector3.ZERO, 0.035, ModelKit.paint(FISH, 0.6), Vector3(1.7, 0.8, 0.5))
	ModelKit.ball(_fish, Vector3(-0.06, 0, 0), 0.022, ModelKit.paint(FISH.darkened(0.15), 0.6), Vector3(0.6, 1.2, 0.3))
	_fish.visible = false
	add_child(_fish)
	set_process(false)
	var clock := Timer.new()
	clock.wait_time = LOOK_EVERY
	clock.autostart = true
	clock.timeout.connect(_look)
	add_child(clock)
	var leaper := Timer.new()
	leaper.one_shot = true
	leaper.timeout.connect(_start_leap.bind(leaper))
	add_child(leaper)
	leaper.autostart = true
	leaper.wait_time = _rng.randf_range(LEAP_EVERY.x, LEAP_EVERY.y)
	_look()


func _process(delta: float) -> void:
	_leap += delta
	var u := _leap / LEAP_TIME
	if u >= 1.0:
		_fish.visible = false
		_leap = -1.0
		set_process(false)
		_ring(_leap_from + _leap_way * LEAP_LONG)
		return
	_fish.position = _leap_from + _leap_way * (LEAP_LONG * u) + Vector3(0, LEAP_HIGH * sin(u * PI), 0)
	_fish.rotation = Vector3(0, atan2(-_leap_way.z, _leap_way.x), cos(u * PI) * 0.9)


## Whether the pond is frozen over (snow lies: the water's shader shows ice).
static func frozen() -> bool:
	return float(ShaderGlobals.value(&"snow_cover", 0.0)) > 0.5


## Who is out now: dragonflies by day, fireflies by night, neither over ice.
func _look() -> void:
	var night := float(ShaderGlobals.value(&"dark", 0.0)) > 0.35
	for fly in _by_day:
		fly.visible = not night and not frozen()
	_by_night.visible = night


func _start_leap(leaper: Timer) -> void:
	leaper.start(_rng.randf_range(LEAP_EVERY.x, LEAP_EVERY.y))
	if frozen() or not is_visible_in_tree():
		return
	var way := _rng.randf() * TAU
	_leap_way = Vector3(cos(way), 0, sin(way))
	_leap_from = _spot(_rng.randf_range(0.0, 0.4)) - _leap_way * (LEAP_LONG / 2.0)
	_leap = 0.0
	_fish.visible = true
	_ring(_leap_from)
	set_process(true)


## A point on the water, `out` of the way from its middle to its shore, any way round.
func _spot(out: float) -> Vector3:
	var way := _rng.randf() * TAU
	return _centre + Vector3(cos(way) * _reach.x, 0, sin(way) * _reach.y) * out


func _ring(at: Vector3) -> void:
	if rings != null:
		rings.splash(to_global(at) + Vector3(0, 0.004, 0), 0.6)


## A dragonfly facing -z: a thin body and two pairs of wings, spread (DecorMotion.orbit beats them).
static func _dragonfly() -> Node3D:
	var fly := Node3D.new()
	ModelKit.ball(fly, Vector3.ZERO, 0.012, ModelKit.paint(Color("#2f8fb8"), 0.7), Vector3(0.6, 0.6, 4.0))
	ModelKit.ball(fly, Vector3(0, 0, -0.045), 0.012, ModelKit.paint(Color("#2a6f96"), 0.7))
	for side: float in [-1.0, 1.0]:
		for pair in 2:
			ModelKit.ball(fly, Vector3(side * 0.04, 0.004, -0.02 + 0.03 * pair), 0.03, ModelKit.paint(WING, 0.8),
				Vector3(1.3, 0.08, 0.35))
	return fly
