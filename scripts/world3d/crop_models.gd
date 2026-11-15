class_name CropModels
extends RefCounted
## The 3D crop plants: one mesh per plant shape (grain, stalk, berry, fruit, gourd, root, leafy, flower,
## spike, fluff) and growth stage (seeds, sprout, young, ripe, withered), built once and shared by every
## plot through MultiMeshes. Leaves are coloured in the mesh; produce is marked (vertex alpha 0) and
## takes each crop's own colour from its instance, so seventy crops need only fifty meshes.

const STAGES := ["seeds", "sprout", "young", "ripe", "withered"]
const LEAF := Color("#4f9a36")
const LEAF_DARK := Color("#2f6b24")
const LEAF_TIP := Color("#8fcf55")
const DRY := Color("#9a7a42")
const DRY_DARK := Color("#6e5530")
const SEED := Color("#4a3322")
const STEM := Color("#5c8a2e")

static var _cache := {}


static func mesh(shape: String, stage: String) -> ArrayMesh:
	var key := shape + "|" + stage
	if not _cache.has(key):
		_cache[key] = _build(shape, stage)
	return _cache[key]


## Produce colour in the vertex: `shade` 0..1 (how lit), alpha 0 marks it as produce (every other
## colour here is opaque).
static func _p(shade: float) -> Color:
	return Color(shade, shade, shade, 0.0)


static func _build(shape: String, stage: String) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(shape + stage)
	match stage:
		"seeds":
			for k in 4:
				var a := TAU * k / 4.0 + 0.4
				mb.ellipsoid(Vector3(cos(a) * 0.04, 0.008, sin(a) * 0.04), Vector3(0.014, 0.008, 0.01), SEED, 6, 3)
		"sprout":
			for k in 2:
				var a := PI * k + 0.6
				mb.blade(Vector3.ZERO, Vector3(cos(a) * 0.05, 0.07, sin(a) * 0.05), 0.04, LEAF, LEAF_TIP)
			mb.cone(Vector3.ZERO, 0.006, 0.004, 0.05, STEM, 4)
		"withered":
			for k in 5:
				var a := TAU * k / 5.0 + rng.randf() * 0.4
				mb.blade(Vector3.ZERO, Vector3(cos(a) * 0.12, 0.05, sin(a) * 0.12), 0.05, DRY_DARK, DRY,
					Vector3(0, -0.02, 0))
		_:
			var ripe := stage == "ripe"
			var k := 1.0 if ripe else 0.7
			if CropForms.build(mb, shape, rng, k, ripe):
				return mb.commit()
			match shape:
				"grain":
					_grain(mb, rng, k, ripe)
				"stalk":
					_stalk(mb, rng, k, ripe)
				"berry", "fruit", "fluff":
					_bush(mb, rng, k, ripe, shape)
				"gourd":
					_gourd(mb, rng, k, ripe)
				"root":
					_root(mb, rng, k, ripe)
				"leafy":
					_leafy(mb, rng, k, ripe)
				"flower", "spike":
					_flower(mb, rng, k, ripe, shape == "spike")
				_:
					_bush(mb, rng, k, ripe, "berry")
	return mb.commit()


static func _grain(mb: MeshBuilder, rng: RandomNumberGenerator, k: float, ripe: bool) -> void:
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.5
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.02, 0.05) * k
		var h := rng.randf_range(0.22, 0.3) * k
		var tip := lean + Vector3(0, h, 0)
		mb.blade(Vector3(cos(a), 0, sin(a)) * 0.015, tip, 0.012, LEAF_DARK if not ripe else DRY_DARK.lerp(LEAF, 0.3),
			LEAF_TIP if not ripe else Color(0.85, 0.75, 0.4))
		if ripe:
			mb.ellipsoid(tip + Vector3(0, 0.03, 0), Vector3(0.012, 0.035, 0.012), _p(0.85), 5, 4)


static func _stalk(mb: MeshBuilder, rng: RandomNumberGenerator, k: float, ripe: bool) -> void:
	var h := 0.55 * k
	mb.cone(Vector3.ZERO, 0.018, 0.008, h, STEM, 6)
	for i in 6:
		var a := TAU * i / 3.0 + i * 0.4
		var y := h * (0.2 + 0.12 * i)
		mb.blade(Vector3(0, y, 0), Vector3(cos(a) * 0.17, y + 0.06, sin(a) * 0.17) * Vector3(k, 1, k), 0.05, LEAF_DARK,
			LEAF_TIP, Vector3(0, -0.04, 0))
	if ripe:
		for i in 2:
			var a := PI * i + 0.8
			mb.ellipsoid(Vector3(cos(a) * 0.035, h * 0.55, sin(a) * 0.035), Vector3(0.025, 0.07, 0.025), _p(0.85), 6, 4)


static func _bush(mb: MeshBuilder, rng: RandomNumberGenerator, k: float, ripe: bool, kind: String) -> void:
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.4
		var c := Vector3(cos(a) * 0.07, 0.06 + rng.randf() * 0.05, sin(a) * 0.07) * Vector3(k, k, k)
		mb.ellipsoid(c, Vector3(0.06, 0.045, 0.06) * k, LEAF.darkened(rng.randf() * 0.2), 7, 4)
	mb.ellipsoid(Vector3(0, 0.12 * k, 0), Vector3(0.06, 0.05, 0.06) * k, LEAF.lightened(0.1), 7, 4)
	if not ripe:
		return
	var count := 7 if kind == "berry" else 5
	var r := 0.022 if kind == "berry" else (0.035 if kind == "fruit" else 0.032)
	for i in count:
		var a := TAU * i / count + rng.randf() * 0.5
		var p := Vector3(cos(a) * 0.1, 0.06 + rng.randf() * 0.08, sin(a) * 0.1)
		var size := Vector3(r, r * (1.5 if kind == "fruit" else 1.0), r)
		mb.ellipsoid(p, size, _p(0.9), 6, 4)


static func _gourd(mb: MeshBuilder, rng: RandomNumberGenerator, k: float, ripe: bool) -> void:
	for i in 5:
		var a := TAU * i / 5.0 + rng.randf() * 0.5
		mb.blade(Vector3(0, 0.01, 0), Vector3(cos(a) * 0.16, 0.08, sin(a) * 0.16) * Vector3(k, 1, k), 0.09, LEAF_DARK,
			LEAF, Vector3(0, 0.03, 0))
	if ripe:
		mb.ellipsoid(Vector3(0.03, 0.06, 0.02), Vector3(0.1, 0.07, 0.09), _p(0.9), 10, 6)
		mb.cone(Vector3(0.03, 0.12, 0.02), 0.01, 0.006, 0.04, Color("#6b4a26"), 4)


static func _root(mb: MeshBuilder, rng: RandomNumberGenerator, k: float, ripe: bool) -> void:
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.4
		mb.blade(Vector3.ZERO, Vector3(cos(a) * 0.06, 0.16 * k, sin(a) * 0.06), 0.035, LEAF_DARK, LEAF_TIP)
	if ripe:
		# The top of the root showing at the soil.
		mb.ellipsoid(Vector3(0, 0.01, 0), Vector3(0.035, 0.025, 0.035), _p(0.85), 7, 4)


static func _leafy(mb: MeshBuilder, rng: RandomNumberGenerator, k: float, ripe: bool) -> void:
	# A rosette: the leaves themselves are the produce, so they take the crop's colour when grown.
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.3
		var shade := 0.65 + 0.35 * (i % 3) / 2.0
		var col := _p(shade) if ripe else LEAF.lerp(LEAF_TIP, (i % 3) / 2.0)
		mb.blade(Vector3.ZERO, Vector3(cos(a) * 0.12 * k, 0.09 * k, sin(a) * 0.12 * k), 0.08 * k, col, col,
			Vector3(0, 0.025, 0))
	if ripe:
		mb.ellipsoid(Vector3(0, 0.06, 0), Vector3(0.05, 0.05, 0.05), _p(0.95), 8, 5)


static func _flower(mb: MeshBuilder, rng: RandomNumberGenerator, k: float, ripe: bool, spike: bool) -> void:
	for i in 3:
		var a := TAU * i / 3.0 + rng.randf()
		var top := Vector3(cos(a) * 0.04, rng.randf_range(0.22, 0.3) * k, sin(a) * 0.04)
		mb.cone(Vector3(cos(a) * 0.01, 0, sin(a) * 0.01), 0.006, 0.004, top.y, STEM, 4)
		mb.blade(Vector3(0, top.y * 0.3, 0), Vector3(cos(a + 1.2) * 0.07, top.y * 0.45, sin(a + 1.2) * 0.07), 0.035,
			LEAF_DARK, LEAF)
		if not ripe:
			mb.ellipsoid(top, Vector3(0.015, 0.025, 0.015), LEAF, 5, 3)
		elif spike:
			for j in 5:
				mb.ellipsoid(top - Vector3(0, j * 0.022, 0), Vector3(0.014, 0.014, 0.014), _p(0.95 - j * 0.08), 5, 3)
		else:
			for j in 6:
				var b := TAU * j / 6.0
				mb.ellipsoid(
					top + Vector3(cos(b) * 0.025, 0, sin(b) * 0.025),
					Vector3(0.02, 0.008, 0.02),
					_p(0.95),
					5,
					3
				)
			mb.ellipsoid(top + Vector3(0, 0.006, 0), Vector3(0.013, 0.01, 0.013), Color("#f2c230"), 5, 3)
