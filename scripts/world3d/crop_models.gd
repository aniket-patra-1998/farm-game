class_name CropModels
extends RefCounted
## The 3D crop plants: one mesh per plant shape (grain, stalk, berry, fruit, gourd, root, leafy, flower,
## spike, fluff) and growth stage (seeds, sprout, young, ripe, withered), built once and shared by every
## plot through MultiMeshes. Leaves are coloured in the mesh; produce is marked (vertex alpha 0) and
## takes each crop's own colour from its instance, so seventy crops need only fifty meshes.

const HARVEST := "harvest"   # the stage a crop's picture is drawn at: its produce gathered (CropForms.harvest)
const STAGES := ["seeds", "sprout", "young", "ripe", "withered"]
const LEAF := Color("#4f9a36")
const LEAF_DARK := Color("#2f6b24")
const LEAF_TIP := Color("#8fcf55")
const DRY := Color("#9a7a42")
const DRY_DARK := Color("#6e5530")
const SEED := Color("#4a3322")
const STEM := Color("#5c8a2e")
const SPAN_MOST := 0.85    # produce may take this share of the height crops are kept to; the rest is stem and top
const PRODUCE_REACH := 1.2  # produce may spread this much further than leaves (it is what the field shows)
const ON_SOIL := 0.03      # produce beginning lower than this lies on the soil
const GREEN_SHARP := 4.0   # how quickly a colour counts as leaf green (its green over its red and blue, times this)

static var _cache := {}
static var _files := {}   # form|stage -> its mesh from the form's file (null: it has none)


## A crop form's mesh at `stage`: from its file (art/models/crops, AssetRegistry `crop:<form>`, made by
## tools/export_plants), else built here (`from_file` false: the export itself).

static func mesh(shape: String, stage: String, from_file := true) -> ArrayMesh:
	var key := shape + "|" + stage
	if from_file:
		if not _files.has(key):
			_files[key] = null
			if AssetRegistry.has_model(AssetRegistry.CROP + shape):
				var model := AssetRegistry.instance(AssetRegistry.CROP + shape)
				var part := model.get_node_or_null(stage) as MeshInstance3D
				if part != null and part.mesh is ArrayMesh:
					_files[key] = part.mesh
				model.free()
		if _files[key] != null:
			return _files[key]
	if not _cache.has(key) and stage == HARVEST:
		_cache[key] = _build(shape, stage)   # (a picture's: the camera frames it, no plot to fit)
	if not _cache.has(key):
		var ripe := stage == "ripe"
		var cap := CropFormSpec.look("height", 0.0) * (1.0 if ripe else CropFormSpec.look("young", 1.0))
		_cache[key] = _fit(_build(shape, stage), cap, CropFormSpec.look("leaf_ripe", 1.0) if ripe else 1.0,
			bool(CropFormSpec.spec(shape).get("squash", false)),
			0.0 if CropFormSpec.is_plot(shape) else CropFormSpec.look("reach", 0.0))
		if CropFormSpec.is_plot(shape) and stage in ["seeds", "sprout", "withered"]:
			_cache[key] = _rows(_cache[key])
	return _cache[key]


## Every crop stands about as tall as the next and shows its harvest (data/crop_forms.json "look": a field reads
## best level, its produce on top). A plant taller than `cap` keeps its produce as it is and has the rest
## shortened: the stem under it and whatever stands above it (a tassel, a stake). Produce that alone is taller
## than the cap makes the whole plant smaller; a plant with no produce, or one that is `squash`ed (canes, which
## are produce from foot to tip), is drawn shorter instead. `dim` darkens the green of a ripe plant's leaves,
## so the harvest stands out against them. `reach` is how far from its middle a plant may spread, so a plot's
## plants stay inside it and each plot is its own patch: leaves beyond it are drawn in, and produce beyond it
## (a little more is allowed) is made smaller, in proportion.
static func _fit(mesh: ArrayMesh, cap: float, dim := 1.0, squash := false, reach := 0.0) -> ArrayMesh:
	if (cap <= 0.0 and reach <= 0.0 and is_equal_approx(dim, 1.0)) or mesh.get_surface_count() == 0:
		return mesh
	var arrays := mesh.surface_get_arrays(0)
	var pts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var top := 0.0
	var head := INF       # where the produce begins..
	var head_top := -INF  # ..and ends
	for i in pts.size():
		top = maxf(top, pts[i].y)
		if cols[i].a < 0.5:
			head = minf(head, pts[i].y)
			head_top = maxf(head_top, pts[i].y)
		elif dim < 1.0:
			var c := cols[i]
			var green := clampf((c.g - maxf(c.r, c.b)) * GREEN_SHARP, 0.0, 1.0)   # (straw and petals are left as they are)
			var k := lerpf(1.0, dim, green)
			cols[i] = Color(c.r * k, c.g * k, c.b * k, c.a)
	if cap > 0.0 and top > cap:
		if head > top or squash:
			for i in pts.size():
				pts[i].y *= cap / top
		else:
			var whole := minf(1.0, cap * SPAN_MOST / maxf(head_top - maxf(head, 0.0), 0.0001))   # (produce taller than the cap)
			var under := maxf(head, 0.0)   # (produce lying on the soil may dip a little below it)
			var free := cap / whole - (head_top - under)
			var above := top - head_top
			var stem := free * under / maxf(under + above, 0.0001)
			for i in pts.size():
				var y := pts[i].y
				if y <= under:
					y *= stem / under if under > 0.0001 else 1.0
				elif y <= head_top:
					y += stem - under
				else:
					y = stem + head_top - under + (y - head_top) * (free - stem) / maxf(above, 0.0001)
				pts[i] = Vector3(pts[i].x, y, pts[i].z) * whole
	if reach > 0.0:
		_draw_in(pts, cols, reach)
	arrays[Mesh.ARRAY_VERTEX] = pts
	arrays[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Three rows of three of a plant as one mesh: the stages every crop shares (seeds, a sprout, withered), for a
## crop drawn a plot at a time.
static func _rows(mesh: ArrayMesh) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var pts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	for spot: Vector2 in Crops3D.SPOTS:
		for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			pts.append(p + Vector3(spot.x, 0.0, spot.y) / Crops3D.PLANT_SCALE)
		normals.append_array(arrays[Mesh.ARRAY_NORMAL])
		cols.append_array(arrays[Mesh.ARRAY_COLOR])
	var all := []
	all.resize(Mesh.ARRAY_MAX)
	all[Mesh.ARRAY_VERTEX] = pts
	all[Mesh.ARRAY_NORMAL] = normals
	all[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, all)
	return out


## Keeps a plant within `reach` of its middle (see `_fit`).
static func _draw_in(pts: PackedVector3Array, cols: PackedColorArray, reach: float) -> void:
	var leaf_far := 0.0001
	var produce_far := 0.0001
	var low := INF      # the produce's lowest point..
	var middle := 0.0   # ..and its middle height
	var n := 0
	for i in pts.size():
		var far := Vector2(pts[i].x, pts[i].z).length()
		if cols[i].a < 0.5:
			produce_far = maxf(produce_far, far)
			low = minf(low, pts[i].y)
			middle += pts[i].y
			n += 1
		else:
			leaf_far = maxf(leaf_far, far)
	var leaf_k := minf(1.0, reach / leaf_far)
	var produce_k := minf(1.0, reach * PRODUCE_REACH / produce_far)
	# Produce shrinks about where it sits: its foot when it lies on the soil, else its own middle (a head on a stem).
	var about := low if low < ON_SOIL else middle / maxi(n, 1)
	for i in pts.size():
		if cols[i].a < 0.5:
			pts[i] = Vector3(pts[i].x * produce_k, about + (pts[i].y - about) * produce_k, pts[i].z * produce_k)
		else:
			pts[i] = Vector3(pts[i].x * leaf_k, pts[i].y, pts[i].z * leaf_k)


## Produce colour in the vertex: `shade` 0..1 (how lit), alpha 0 marks it as produce (every other
## colour here is opaque).
static func _p(shade: float) -> Color:
	return Color(shade, shade, shade, 0.0)


static func _build(shape: String, stage: String) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(shape + stage)
	match stage:
		"harvest":
			if CropFormSpec.builder().harvest(mb, shape, rng):
				return mb.commit()
			CropFormSpec.builder().build(mb, shape, rng, 1.0, true)   # (a form that isn't a plot: one ripe plant)
			return mb.commit()
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
			if CropFormSpec.builder().build(mb, shape, rng, k, ripe):
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
