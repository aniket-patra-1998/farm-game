class_name Ground3D
extends Node3D
## The land: your farm as a raised slab of turf with earthy sides (so it has weight and an edge, as in
## FarmVille), the meadow around it a step lower, and tufts of grass scattered over both, swaying in the
## wind. Plowed plots don't grow tufts. Rebuilt when the farm grows or plots change.

const SLAB := 0.22                 # how far the farm stands above the meadow
const MEADOW := 40.0               # tiles of countryside around the farm
const TUFTS_PER_TILE := 5
const MEADOW_TUFTS_PER_TILE := 2
const TUFT_REACH := 6.0            # meadow tufts only this far out (further, they're too small to see)
const EARTH := Color("#7a5232")

var wind := 0.6: set = _set_wind

var _slab: MeshInstance3D
var _meadow: MeshInstance3D
var _tufts: MultiMeshInstance3D
var _tuft_material: ShaderMaterial
var _size := -1


func _ready() -> void:
	var grass := ShaderMaterial.new()
	grass.shader = load("res://shaders/ground3d.gdshader")
	var meadow_grass := grass.duplicate() as ShaderMaterial
	meadow_grass.set_shader_parameter("checker", 0.0)
	meadow_grass.set_shader_parameter("dryness", 0.32)
	meadow_grass.set_shader_parameter("grass_light", Color(0.52, 0.72, 0.30))
	_meadow = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	_meadow.mesh = plane
	_meadow.material_override = meadow_grass
	add_child(_meadow)
	_slab = MeshInstance3D.new()
	add_child(_slab)
	_slab.set_meta("grass", grass)
	_tufts = MultiMeshInstance3D.new()
	_tufts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tuft_material = ShaderMaterial.new()
	_tuft_material.shader = load("res://shaders/tuft3d.gdshader")
	_tufts.material_override = _tuft_material
	add_child(_tufts)
	rebuild()


func _set_wind(v: float) -> void:
	wind = v
	if _tuft_material != null:
		_tuft_material.set_shader_parameter("wind", v)


func rebuild() -> void:
	var n := Game.farm_size
	if n != _size:
		_size = n
		_build_slab(n)
		var plane := _meadow.mesh as PlaneMesh
		plane.size = Vector2(n + MEADOW * 2.0, n + MEADOW * 2.0)
		_meadow.position = Vector3(n / 2.0, -SLAB, n / 2.0)
	_scatter_tufts(n)


## The farm: a box whose top is turf and whose sides are earth, with a darker lip under the turf.
func _build_slab(n: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := 0.0
	var bottom := -SLAB - 0.02
	# Top (turf) in surface 0.
	_quad(st, Vector3(0, top, 0), Vector3(n, top, 0), Vector3(n, top, n), Vector3(0, top, n), Vector3.UP)
	var turf := st.commit()
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The two sides the camera sees (+x and +z), and the hidden two for shadows.
	var sides := [
		[Vector3(n, top, 0), Vector3(n, top, n), Vector3.RIGHT], [Vector3(n, top, n), Vector3(0, top, n), Vector3.BACK],
		[
			Vector3(0, top, n),
			Vector3(0, top, 0),
			Vector3.LEFT
		], [Vector3(0, top, 0), Vector3(n, top, 0), Vector3.FORWARD]]
	for side in sides:
		var a: Vector3 = side[0]
		var b: Vector3 = side[1]
		_quad(st, a, b, Vector3(b.x, bottom, b.z), Vector3(a.x, bottom, a.z), side[2], EARTH, EARTH.darkened(0.35))
	st.commit(turf)
	_slab.mesh = turf
	_slab.set_surface_override_material(0, _slab.get_meta("grass"))
	var earth := StandardMaterial3D.new()
	earth.vertex_color_use_as_albedo = true
	earth.roughness = 1.0
	earth.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slab.set_surface_override_material(1, earth)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3,
		top_col := Color.WHITE, bottom_col := Color.WHITE) -> void:
	st.set_normal(normal)
	for v: Vector3 in [a, b, c, a, c, d]:
		st.set_color(top_col if v.y >= 0.0 else bottom_col)
		st.add_vertex(v)


## Tufts on every grass tile of the farm and a ring of the meadow, seeded by position so they don't move
## when rebuilt.
func _scatter_tufts(n: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _tuft_mesh()
	var spots: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	var reach := int(TUFT_REACH)
	for r in range(-reach, n + reach):
		for c in range(-reach, n + reach):
			var on_farm := r >= 0 and c >= 0 and r < n and c < n
			if on_farm and Game.plots[Game.index_of(r, c)].get("state", "grass") != "grass":
				continue
			rng.seed = hash(Vector2i(r, c))
			var count := TUFTS_PER_TILE if on_farm else MEADOW_TUFTS_PER_TILE
			var y := 0.0 if on_farm else -SLAB
			for k in count:
				var at := Vector3(c + rng.randf(), y, r + rng.randf())
				var s := rng.randf_range(0.7, 1.25)
				spots.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), at))
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
	_tufts.multimesh = mm


## One tuft: five blades fanning out, dark green at the root, light at the tip.
static func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root := Color("#3f6b22")
	var tip := Color("#9ccc4f")
	for i in 5:
		var a := TAU * i / 5.0
		var lean := Vector3(cos(a), 0, sin(a)) * 0.05
		var side := Vector3(-sin(a), 0, cos(a)) * 0.022
		var h := 0.13 + 0.03 * float(i % 2)
		st.set_normal(Vector3.UP)
		st.set_color(root)
		st.add_vertex(-side)
		st.add_vertex(side)
		st.set_color(tip)
		st.add_vertex(lean + Vector3(0, h, 0))
	st.index()
	return st.commit()
