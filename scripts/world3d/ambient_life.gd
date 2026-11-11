class_name AmbientLife
extends Node3D
## The small life that makes a farm feel lived in even when nothing is being tapped: butterflies wandering over
## the grass by day, fireflies blinking over it at night, and a flock of birds crossing high above now and
## then. Each kind is one mesh whose vertex shader moves every creature along its own path from the time
## (shaders/flutter3d, firefly3d), so a hundred of them cost two draws and no script. They fade with the time
## of day (the shared `dark`). How many follows how much land there is.

const WEATHER_CHECK_SECONDS := 2.0
const BUTTERFLIES_PER_ROW := 1.6      # butterflies per row of land (farm_size)
const FIREFLIES_PER_ROW := 2.4
const FLOCKS := 2
const BIRDS_PER_FLOCK := 3
const MIN_COUNT := 10
const WING := 0.09                    # a butterfly's wing, in tiles
const BIRD_WING := 0.2
const FLY_SHADER := "res://shaders/flutter3d.gdshader"
const FIREFLY_SHADER := "res://shaders/firefly3d.gdshader"
const COLOURS: Array[Color] = [Color("#f6c445"), Color("#f2f0e8"), Color("#e7743a"), Color("#8fb8e8"),
	Color("#d96aa7")]
const BIRD_COLOUR := Color("#4b4a52")
const SKY_HEIGHT := 6.0

var _built_for := -1
var _since_check := 0.0
var _butterflies: MeshInstance3D
var _birds: MeshInstance3D


func _ready() -> void:
	rebuild()
	_follow_weather()


func _process(delta: float) -> void:
	_since_check += delta
	if _since_check >= WEATHER_CHECK_SECONDS:
		_since_check = 0.0
		_follow_weather()
	Game.farm_expanded.connect(func(_n: int) -> void: rebuild())


## Butterflies and birds keep out of rain, snow, storms and thick fog (fireflies are for the dark and need no
## such rule: the night shader shows them).
func _follow_weather() -> void:
	var w := Game.weather()
	var foul := float(w.get("rain", 0.0)) > 0.05 or float(w.get("snow", 0.0)) > 0.05 or float(w.get("fog", 0.0)) > 0.5
	if _butterflies != null:
		_butterflies.visible = not foul
	if _birds != null:
		_birds.visible = not foul


## (Re)makes the creatures for the farm's present size.
func rebuild() -> void:
	if _built_for == Game.farm_size:
		return
	_built_for = Game.farm_size
	for c in get_children():
		c.queue_free()
	var n := Game.farm_size
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var butterflies := maxi(MIN_COUNT, int(n * BUTTERFLIES_PER_ROW))
	_butterflies = _add(_wings(rng, butterflies, n, WING, true), _material(FLY_SHADER, 0.0), n)
	_add(_dots(rng, maxi(MIN_COUNT, int(n * FIREFLIES_PER_ROW)), n), _material(FIREFLY_SHADER, 0.0), n)
	_birds = _add(_flocks(rng, n), _material(FLY_SHADER, 1.0), n)


func _add(mesh: ArrayMesh, mat: ShaderMaterial, n: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# They wander far from where the mesh is built: tell culling the whole farm and the sky above it.
	mi.custom_aabb = AABB(Vector3(-8, -1, -8), Vector3(n + 16, SKY_HEIGHT + 2, n + 16))
	add_child(mi)
	return mi


static func _material(path: String, kind: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	if path == FLY_SHADER:
		m.set_shader_parameter("kind", kind)
	return m


## A pair of wings (four triangles) for each creature: UV = (phase), UV2 = (home), COLOR = its colour.
static func _wings(rng: RandomNumberGenerator, count: int, land: int, size: float, coloured: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var phase := rng.randf()
		var home := Vector2(rng.randf_range(0.5, land - 0.5), rng.randf_range(0.5, land - 0.5))
		var col := COLOURS[rng.randi() % COLOURS.size()] if coloured else BIRD_COLOUR
		_pair(st, phase, home, col, size)
	return st.commit()


static func _pair(st: SurfaceTool, phase: float, home: Vector2, col: Color, size: float) -> void:
	for side: float in [-1.0, 1.0]:
		var pts := [Vector3(0, 0, -0.5 * size), Vector3(side * size, 0, -0.8 * size), Vector3(side * size, 0, 0.45 * size),
			Vector3(0, 0, 0.5 * size)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_uv(Vector2(phase, 0))
			st.set_uv2(home)
			st.add_vertex(pts[k])


## Flocks: birds sharing a start and flying together, each a little apart.
static func _flocks(rng: RandomNumberGenerator, land: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in FLOCKS:
		var lane := rng.randf_range(2.0, maxf(land - 2.0, 3.0))
		var base := rng.randf()
		for b in BIRDS_PER_FLOCK:
			_pair(st, fposmod(base + b * 0.004, 1.0), Vector2(0.0, lane + b * 0.4), BIRD_COLOUR, BIRD_WING)
	return st.commit()


## Fireflies: a tiny cross of two quads each (seen from any side), additive.
static func _dots(rng: RandomNumberGenerator, count: int, land: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 0.034
	for i in count:
		var phase := rng.randf()
		var home := Vector2(rng.randf_range(0.5, land - 0.5), rng.randf_range(0.5, land - 0.5))
		for quad: Array in [[Vector3(-r, -r, 0), Vector3(r, -r, 0), Vector3(r, r, 0), Vector3(-r, r, 0)],
				[Vector3(0, -r, -r), Vector3(0, -r, r), Vector3(0, r, r), Vector3(0, r, -r)]]:
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2(phase, 0))
				st.set_uv2(home)
				st.add_vertex(quad[k])
	return st.commit()
