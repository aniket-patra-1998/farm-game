class_name PondModel
extends RefCounted
## A pond that sits in the ground (our own look, beyond FarmVille's flat blue ovals): an uneven shoreline, a
## muddy bank sloping down from a grassy lip into a bowl, water standing a little below the ground that is
## clear and pale over the shallows and deep green-blue in the middle (shaders/water3d `shore_fade`, so the
## sloping bed shows through at the edge), pebbles in the shallows, clusters of stones, cattails and lily pads.
## Shared by the small pond decoration and the Duck Pond; `seed_value` makes each one its own.

const SHORE_POINTS := 36
const WOBBLE := [[3.0, 0.07], [5.0, 0.045], [8.0, 0.02]]   # the shoreline's bumps: [how many round, how big]
const LIP := 1.1             # the grassy lip, out from the shore (of the shore's radius)
# Every height stands above the farm's ground (y 0): the ground is one solid sheet that would hide anything
# below it, so the pond is a low raised bank round a shallow bowl, and the water shows its depth by colour.
const LIP_EDGE := 0.003      # the lip's outer edge, just above the lawn (no flicker against it)
const LIP_HEIGHT := 0.045    # the bank's top
const SHORE_HEIGHT := 0.035  # where it meets the water
const BED_IN := 0.88         # where the bank reaches the bed underwater (of the shore's radius)
const BED_HEIGHT := 0.012    # the bed there
const DEEP := 0.55           # where the bowl's floor begins (of the shore's radius)
const DEEP_HEIGHT := 0.005   # and its height: the lowest point, still above the ground
const WATER_LEVEL := 0.03    # the water stands a little under the bank's top
const GRASS := Color("#4f7a30")   # (close to the lawn, so the lip blends into it)
const MUD := Color("#6e5634")
const BED := Color("#3e3424")
const STONE := Color("#9a9588")
const REED := Color("#6f9a3c")
const CATTAIL := Color("#6b4423")
const PAD := Color("#4f9a3a")
const BLOOM := Color("#f4a6c8")
const BLOOM_HEART := Color("#f2c230")

static var _earth_material: StandardMaterial3D


## Builds a pond under `root`, centred at `c`, `rx` by `rz` at its shore. `still`: its reeds do not sway (a
## building made as a file moves only by its named parts).
static func build(root: Node3D, c: Vector3, rx: float, rz: float, seed_value: int, lilies := 4,
		still := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var phase := rng.randf() * TAU
	var shore := PackedFloat32Array()   # the shore's reach at each point round, as a share of the ellipse
	for k in SHORE_POINTS:
		var a := TAU * k / SHORE_POINTS
		var r := 1.0
		for w: Array in WOBBLE:
			r += float(w[1]) * sin(float(w[0]) * a + phase * float(w[0]))
		shore.append(r)
	root.add_child(_ground(c, rx, rz, shore))
	var water := MeshInstance3D.new()
	water.mesh = _surface(c, rx, rz, shore)
	water.material_override = ModelKit.pond_water()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(water)
	_shallows(root, c, rx, rz, shore, rng)
	_stones(root, c, rx, rz, shore, rng)
	_cattails(root, c, rx, rz, shore, rng, still)
	_lilies(root, c, rx, rz, rng, lilies)


## Where the shore is at point `k` round (on the ground), times `out`.
static func _at(c: Vector3, rx: float, rz: float, shore: PackedFloat32Array, k: int, out: float, y: float) -> Vector3:
	var a := TAU * (k % SHORE_POINTS) / SHORE_POINTS
	var r := shore[k % SHORE_POINTS] * out
	return c + Vector3(cos(a) * rx * r, y, sin(a) * rz * r)


## The bank and the bed: rings from the grassy lip down past the shore into a bowl, coloured grass to mud to
## the dark bed, in one mesh (its own colours, so it is one draw).
static func _ground(c: Vector3, rx: float, rz: float, shore: PackedFloat32Array) -> MeshInstance3D:
	# Each ring: [out, height, colour].
	var rings := [[LIP, LIP_EDGE, GRASS], [1.04, LIP_HEIGHT, GRASS.lerp(MUD, 0.5)], [1.0, SHORE_HEIGHT, MUD],
		[BED_IN, BED_HEIGHT, MUD.lerp(BED, 0.5)], [DEEP, DEEP_HEIGHT, BED]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in rings.size() - 1:
		var a: Array = rings[ring]
		var b: Array = rings[ring + 1]
		for k in SHORE_POINTS:
			var p0 := _at(c, rx, rz, shore, k, a[0], a[1])
			var p1 := _at(c, rx, rz, shore, k + 1, a[0], a[1])
			var q0 := _at(c, rx, rz, shore, k, b[0], b[1])
			var q1 := _at(c, rx, rz, shore, k + 1, b[0], b[1])
			for v: Array in [[p0, a[2]], [q1, b[2]], [q0, b[2]], [p0, a[2]], [p1, a[2]], [q1, b[2]]]:
				st.set_color(Color(v[1], 0.0))   # (alpha 0: matte, when a file draws it with the master shader)
				st.add_vertex(v[0])
	# The bowl's floor.
	var floor_y := DEEP_HEIGHT
	for k in SHORE_POINTS:
		for v: Vector3 in [c + Vector3(0, floor_y, 0), _at(c, rx, rz, shore, k, DEEP, floor_y),
				_at(c, rx, rz, shore, k + 1, DEEP, floor_y)]:
			st.set_color(Color(BED.darkened(0.15), 0.0))
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _earth()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The water's surface: a fan just under the ground, its UV.x the way out from the middle (0) to the shore (1)
## for the shader's shallows.
static func _surface(c: Vector3, rx: float, rz: float, shore: PackedFloat32Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in SHORE_POINTS:
		for v: Array in [[c + Vector3(0, WATER_LEVEL, 0), 0.0], [_at(c, rx, rz, shore, k, 1.01, WATER_LEVEL), 1.0],
				[_at(c, rx, rz, shore, k + 1, 1.01, WATER_LEVEL), 1.0]]:
			st.set_uv(Vector2(float(v[1]), 0.0))
			st.add_vertex(v[0])
	return st.commit()


## Pebbles on the bed in the shallows, seen through the clear edge of the water.
static func _shallows(root: Node3D, c: Vector3, rx: float, rz: float, shore: PackedFloat32Array,
		rng: RandomNumberGenerator) -> void:
	for k in 10:
		var i := rng.randi_range(0, SHORE_POINTS - 1)
		var out := rng.randf_range(0.82, 0.95)
		var p := _at(c, rx, rz, shore, i, out, lerpf(BED_HEIGHT, SHORE_HEIGHT, (out - BED_IN) / (1.0 - BED_IN)))
		ModelKit.facet_ball(root, p, rng.randf_range(0.015, 0.03), ModelKit.paint(STONE.darkened(rng.randf() * 0.3)),
			Vector3(1.3, 0.6, 1.0))


## Stones in a few clusters on the bank (not an even ring): a big one and smaller ones leaning on it.
static func _stones(root: Node3D, c: Vector3, rx: float, rz: float, shore: PackedFloat32Array,
		rng: RandomNumberGenerator) -> void:
	for cluster in 4:
		var i := int(SHORE_POINTS * (cluster + rng.randf() * 0.5) / 4.0)
		for k in rng.randi_range(3, 5):
			var p := _at(c, rx, rz, shore, i + k - 1, rng.randf_range(1.0, 1.12), LIP_HEIGHT * 0.6)
			var size := rng.randf_range(0.05, 0.1) if k == 0 else rng.randf_range(0.025, 0.055)
			var stone := ModelKit.facet_ball(root, p + Vector3(0, size * 0.25, 0), size,
				ModelKit.paint(STONE.darkened(rng.randf() * 0.25).lerp(Color("#8a8a6a"), rng.randf() * 0.3)),
				Vector3(1.25, 0.7, 1.0))
			stone.rotation.y = rng.randf() * TAU


## Cattails and reeds in clumps at the water's edge: thin leaves and stalks with brown heads.
static func _cattails(root: Node3D, c: Vector3, rx: float, rz: float, shore: PackedFloat32Array,
		rng: RandomNumberGenerator, still := false) -> void:
	for clump in 3:
		var i := int(SHORE_POINTS * (clump + 0.6 + rng.randf() * 0.3) / 3.0)
		var at := _at(c, rx, rz, shore, i, rng.randf_range(0.93, 1.02), WATER_LEVEL - 0.01)
		for k in 7:
			var h := rng.randf_range(0.16, 0.32)
			var foot := at + Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05))
			var lean := Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
			var leaf := ModelKit.cylinder(root, foot, 0.008, h, ModelKit.paint(REED.darkened(rng.randf() * 0.2), 0.0,
				0.0 if still else 0.5),
				0.002, 4)
			leaf.rotation = lean
			if k % 3 == 0:   # a cattail's brown head near the top of its stalk
				var head := ModelKit.cylinder(root, foot + Vector3(0, h * 0.72, 0), 0.016, h * 0.18,
					ModelKit.paint(CATTAIL), 0.016, 6)
				head.rotation = lean


## Lily pads floating on the water (a disc with a notch), one or two with a pink bloom.
static func _lilies(root: Node3D, c: Vector3, rx: float, rz: float, rng: RandomNumberGenerator, n: int) -> void:
	for k in n:
		var a := TAU * k / maxf(n, 1.0) + rng.randf_range(-0.4, 0.4)
		var out := rng.randf_range(0.35, 0.7)
		var p := c + Vector3(cos(a) * rx * out, WATER_LEVEL + 0.004, sin(a) * rz * out)
		var r := rng.randf_range(0.08, 0.12)
		var pad := MeshInstance3D.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		for j in 12:
			if j == 0:
				continue   # the notch
			var b0 := TAU * j / 12.0
			var b1 := TAU * (j + 1) / 12.0
			for v: Vector3 in [Vector3.ZERO, Vector3(cos(b0) * r, 0, sin(b0) * r), Vector3(cos(b1) * r, 0, sin(b1) * r)]:
				st.add_vertex(v)
		pad.mesh = st.commit()
		pad.material_override = ModelKit.paint(PAD.lightened(rng.randf() * 0.15))
		pad.position = p
		pad.rotation.y = rng.randf() * TAU
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pad)
		if k % 2 == 0:
			for j in 6:
				var b := TAU * j / 6.0
				ModelKit.ball(root, p + Vector3(cos(b) * 0.02, 0.012, sin(b) * 0.02), 0.024, ModelKit.paint(BLOOM),
					Vector3(0.7, 1.3, 0.7))
			ModelKit.ball(root, p + Vector3(0, 0.014, 0), 0.012, ModelKit.paint(BLOOM_HEART))


## The bank's material: its colours from the mesh, matte.
static func _earth() -> StandardMaterial3D:
	if _earth_material == null:
		_earth_material = StandardMaterial3D.new()
		_earth_material.vertex_color_use_as_albedo = true
		_earth_material.roughness = 1.0
		ModelKit.paint_like.append(_earth_material)   # (a file carries it as plain paint: its colours are the mesh's)
	return _earth_material
