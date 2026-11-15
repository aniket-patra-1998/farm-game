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
const BIRDS_PER_FLOCK := 5            # a leader and two behind on each side (a V)
const V_BACK := 0.45                  # each rank of the V flies this far behind the one ahead, in tiles..
const V_OUT := 0.42                   # ..and this far out to its side
const BIRD_SPAN := 24.0               # tiles a flock crosses (the shader's `span`)
const BIRD_CROSSING := 0.35           # the share of its period a flock spends crossing (the shader's)
const BODY_SIDES := 6
const BODY_DARK := Color("#2b2622")   # a butterfly's body
const BEAK := Color("#e8a23a")
const MIN_COUNT := 10
const WING := 0.09                    # a butterfly's wing, in tiles
const BIRD_WING := 0.24               # a bird's wing, body to tip, in tiles
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
	Game.farm_expanded.connect(_on_farm_expanded)


func _process(delta: float) -> void:
	_since_check += delta
	if _since_check >= WEATHER_CHECK_SECONDS:
		_since_check = 0.0
		_follow_weather()


func _on_farm_expanded(_n: int) -> void:
	rebuild()


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


## Butterflies: a body with a fore and a hind wing each side, darker toward the edge.
## Per vertex: UV = (phase, how far out along the wing: 0 for a butterfly), UV2 = (home), COLOR = its colour
## (alpha: where in its wingbeat a bird is).
static func _wings(rng: RandomNumberGenerator, count: int, land: int, size: float, _coloured: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var phase := rng.randf()
		var home := Vector2(rng.randf_range(0.5, land - 0.5), rng.randf_range(0.5, land - 0.5))
		_butterfly(st, phase, home, COLOURS[rng.randi() % COLOURS.size()], size)
	return st.commit()


static func _butterfly(st: SurfaceTool, phase: float, home: Vector2, col: Color, size: float) -> void:
	var edge := col.darkened(0.3)
	for side: float in [-1.0, 1.0]:
		# Each wing as a fan from where it joins the body: [x, z, at the edge].
		var fore := [[0.05, 0.12, false], [0.5, 0.8, true], [1.0, 0.62, true], [0.92, 0.12, true], [0.05, -0.02, false]]
		var hind := [[0.05, -0.02, false], [0.8, -0.04, true], [0.68, -0.6, true], [0.25, -0.72, true],
			[0.05, -0.4, false]]
		for wing: Array in [fore, hind]:
			for k in range(1, wing.size() - 1):
				for point: Array in [wing[0], wing[k], wing[k + 1]]:
					_point(st, Vector3(side * float(point[0]), 0, float(point[1])) * size, edge if point[2] else col,
						phase, 0.0, home)
	for point: Vector3 in [Vector3(-0.05, 0, -0.45), Vector3(0.05, 0, -0.45), Vector3(0.05, 0, 0.5),
			Vector3(-0.05, 0, -0.45), Vector3(0.05, 0, 0.5), Vector3(-0.05, 0, 0.5)]:
		_point(st, point * size, BODY_DARK, phase, 0.0, home)


static func _point(st: SurfaceTool, at: Vector3, col: Color, phase: float, along: float, home: Vector2) -> void:
	st.set_color(col)
	st.set_uv(Vector2(phase, along))
	st.set_uv2(home)
	st.add_vertex(at)


## Flocks: birds flying together in a V, a leader and the rest behind it to each side, each beating its wings
## on its own time.
static func _flocks(rng: RandomNumberGenerator, land: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in FLOCKS:
		var lane := rng.randf_range(3.0, maxf(land - 3.0, 4.0))
		var base := rng.randf()
		for b in BIRDS_PER_FLOCK:
			var rank := (b + 1) / 2   # (0, then 1 and 1, then 2 and 2)
			var side := -1.0 if b % 2 == 1 else 1.0
			# Flying `V_BACK` behind is being that much earlier on the way: a little less far through the crossing.
			var phase := fposmod(base - rank * V_BACK * BIRD_CROSSING / BIRD_SPAN, 1.0)
			_bird(st, phase, Vector2(0.0, lane + side * rank * V_OUT), BIRD_WING, rng.randf())
	return st.commit()


## One bird, flying toward +z: a body with a head and beak, a tail fan, and two wings swept back to a point,
## each in an inner and an outer part so the shader can bend it as it beats.
static func _bird(st: SurfaceTool, phase: float, home: Vector2, size: float, beat: float) -> void:
	var back := Color(BIRD_COLOUR, beat)
	var pale := Color(BIRD_COLOUR.lightened(0.22), beat)
	var deep := Color(BIRD_COLOUR.darkened(0.3), beat)
	var beak := Color(BEAK, beat)
	# The body: rings along it, [z, radius, colour], closed to a point at the beak.
	var rings := [[-0.42, 0.02, deep], [-0.15, 0.085, back], [0.18, 0.095, back], [0.4, 0.065, deep],
		[0.52, 0.03, beak], [0.66, 0.0, beak]]
	for k in rings.size() - 1:
		for i in BODY_SIDES:
			var quad: Array = []
			for pair: Array in [[k, i], [k + 1, i], [k + 1, i + 1], [k, i + 1]]:
				var ring: Array = rings[pair[0]]
				var ang := TAU * float(pair[1]) / BODY_SIDES
				var r := float(ring[1])
				# (lighter above than below: these are drawn unlit, so the body's roundness is painted on)
				var shade: Color = (ring[2] as Color).lightened(0.18 * sin(ang))
				shade.a = beat
				quad.append([Vector3(cos(ang) * r, sin(ang) * r * 0.8, float(ring[0])) * size, shade])
			for v: int in [0, 1, 2, 0, 2, 3]:
				_point(st, quad[v][0], quad[v][1], phase, 0.0, home)
	for side: float in [-1.0, 1.0]:
		var root_lead := [Vector3(side * 0.07, 0, 0.26), pale, 0.07]
		var root_trail := [Vector3(side * 0.07, 0, -0.14), back, 0.07]
		var wrist_lead := [Vector3(side * 0.5, 0, 0.3), pale, 0.5]
		var wrist_trail := [Vector3(side * 0.5, 0, -0.1), back, 0.5]
		var tip := [Vector3(side * 1.0, 0, -0.2), deep, 1.0]
		var feather := [Vector3(side * 0.78, 0, -0.27), deep, 0.78]
		for point: Array in [root_lead, wrist_lead, wrist_trail, root_lead, wrist_trail, root_trail,
				wrist_lead, tip, feather, wrist_lead, feather, wrist_trail]:
			_point(st, (point[0] as Vector3) * size, point[1], phase, float(point[2]), home)
	var tail_root := [Vector3(-0.035, 0, -0.38), Vector3(0.035, 0, -0.38)]
	var tail_end := [Vector3(-0.15, 0, -0.76), Vector3(0.15, 0, -0.76)]
	var notch := Vector3(0, 0, -0.66)
	for point: Vector3 in [tail_root[0], tail_root[1], notch, tail_root[0], notch, tail_end[0],
			tail_root[1], tail_end[1], notch]:
		_point(st, point * size, deep, phase, 0.0, home)


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
