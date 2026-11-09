class_name Ground3D
extends Node3D
## The land: your farm as a raised slab of turf with earthy sides (so it has weight and an edge, as in
## FarmVille), the meadow around it a step lower, tufts of grass growing in clumps over both (thick in some
## places, thin in others) and wild flowers here and there, all swaying in the wind.
##
## The grass knows what stands on it, through a shade map (one texel per eighth of a tile): it darkens
## round the foot of buildings, under trees and vehicles, where they block the sky (ambient occlusion),
## and wears thin and straw-coloured where feet go (round buildings' doors, where animals graze). Nothing
## grows through buildings, paths or plots. Rebuilt when the farm grows, plots change or things move.

const SLAB := 0.22                 # how far the farm stands above the meadow
const MEADOW := 40.0               # tiles of countryside around the farm
const MEADOW_TUFTS_PER_TILE := 2
const TUFT_REACH := 6.0            # meadow tufts only this far out (further, they're too small to see)
const EARTH := Color("#7a5232")
const SHADE_RES := 6               # shade-map texels per tile
const SHADE_PAD := 2               # tiles of margin round the farm in the shade map
## What stands on a tile, by kind: [how much it shades the grass, how much it wears it].
const SHADE_BY_KIND := {
	"building": [0.75, 0.9], "vehicle": [0.55, 0.4], "tree": [0.5, 0.15], "decor": [0.2, 0.0],
	"animal": [0.0, 0.55]}
const SHADE_BLUR := 0.4            # shade fades out over this much past what casts it (tiles)
const WEAR_REACH := 0.9            # and wear over this much
## Kinds that nothing grows through (trees and animals stand among the grass).
const COVERS_GRASS := ["building", "vehicle", "decor"]
const CLUMP_MAX := 9               # tufts in the thickest clump on a tile
const FLOWER_CHANCE := 0.22        # of a meadow tile having a patch of wild flowers
const FLOWERS := [Color("#f5f1e6"), Color("#ffd84a"), Color("#c99be8"), Color("#ff8fa3"), Color("#8fc6ff")]

var wind := 0.6: set = _set_wind

var _slab: MeshInstance3D
var _meadow: MeshInstance3D
var _tufts: MultiMeshInstance3D
var _flowers: MultiMeshInstance3D
var _tuft_material: ShaderMaterial
var _flower_material: ShaderMaterial
var _grass: Array[ShaderMaterial] = []
var _shade: Image                  # R: shade, G: wear (see the class notes)
var _shade_texture: ImageTexture
var _shade_signature := 0
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
	_flowers = MultiMeshInstance3D.new()
	_flowers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flower_material = _tuft_material.duplicate() as ShaderMaterial
	_flower_material.set_shader_parameter("flower_heads", true)
	_flowers.material_override = _flower_material
	add_child(_flowers)
	_grass = [grass, meadow_grass]
	rebuild()


func _set_wind(v: float) -> void:
	wind = v
	if _tuft_material != null:
		_tuft_material.set_shader_parameter("wind", v)
		_flower_material.set_shader_parameter("wind", v)


func rebuild() -> void:
	var n := Game.farm_size
	if n != _size:
		_size = n
		_build_slab(n)
		var plane := _meadow.mesh as PlaneMesh
		plane.size = Vector2(n + MEADOW * 2.0, n + MEADOW * 2.0)
		_meadow.position = Vector3(n / 2.0, -SLAB, n / 2.0)
	_paint_shade(n)
	_scatter_tufts(n)
	_scatter_flowers(n)


## Things on the farm moved, came or went: the shade and wear under them, and where grass grows, follow
## (coalesced to once a frame).
func queue_rebuild() -> void:
	if not has_meta("queued"):
		set_meta("queued", true)
		(func() -> void:
			remove_meta("queued")
			# Collecting or upgrading changes nothing on the ground: only a change in what stands where does.
			if is_inside_tree() and hash([Game.farm_size, _kinds(Game.farm_size)]) != _shade_signature:
				rebuild()).call_deferred()


## The shade map: what stands on each tile, painted as blocks and blurred out (by shrinking the image
## and growing it back, which the engine does natively) so shade and wear fall off softly round it.
## Repainted only when what stands where has changed.
func _paint_shade(n: int) -> void:
	var kinds := _kinds(n)
	var signature := hash([n, kinds])
	if signature == _shade_signature and _shade != null:
		return
	_shade_signature = signature
	var side := (n + SHADE_PAD * 2) * SHADE_RES
	var shade := Image.create_empty(side, side, false, Image.FORMAT_L8)
	var wear := Image.create_empty(side, side, false, Image.FORMAT_L8)
	for r in n:
		for c in n:
			var kind: String = kinds[r * n + c]
			if not SHADE_BY_KIND.has(kind):
				continue
			var spec: Array = SHADE_BY_KIND[kind]
			var cell := Rect2i((c + SHADE_PAD) * SHADE_RES, (r + SHADE_PAD) * SHADE_RES, SHADE_RES, SHADE_RES)
			_raise(shade, cell, float(spec[0]))
			# An animal wanders round its spot, so it wears the tiles round it too.
			_raise(wear, cell.grow(SHADE_RES if kind == "animal" else 0), float(spec[1]))
	blur(shade, SHADE_BLUR)
	blur(wear, WEAR_REACH)
	var s_data := shade.get_data()
	var w_data := wear.get_data()
	var data := PackedByteArray()
	data.resize(side * side * 2)
	for i in side * side:
		data[i * 2] = s_data[i]
		data[i * 2 + 1] = w_data[i]
	_shade = Image.create_from_data(side, side, false, Image.FORMAT_RG8, data)
	if _shade_texture == null or Vector2i(_shade_texture.get_size()) != Vector2i(side, side):
		_shade_texture = ImageTexture.create_from_image(_shade)
	else:
		_shade_texture.update(_shade)
	var rect := Vector4(-SHADE_PAD, -SHADE_PAD, n + SHADE_PAD * 2, n + SHADE_PAD * 2)
	for m in _grass:
		m.set_shader_parameter("shade_map", _shade_texture)
		m.set_shader_parameter("shade_rect", rect)


## What stands on every tile of the farm, row by row ("" for nothing).
static func _kinds(n: int) -> Array[String]:
	var by_uid := {}
	for o in Game.objects:
		by_uid[int(o["uid"])] = "animal" if o.get("stray", false) else Game.kind_of(o)
	var out: Array[String] = []
	out.resize(n * n)
	for r in n:
		for c in n:
			var o := Game.object_at(Game.index_of(r, c))
			out[r * n + c] = "" if o.is_empty() else str(by_uid.get(int(o["uid"]), ""))
	return out


## Raises a block of the image to at least `v` (where things overlap, the stronger wins).
static func _raise(img: Image, cell: Rect2i, v: float) -> void:
	if v <= 0.0:
		return
	var inside := cell.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for y in range(inside.position.y, inside.end.y, SHADE_RES):
		for x in range(inside.position.x, inside.end.x, SHADE_RES):
			var block := Rect2i(x, y, SHADE_RES, SHADE_RES).intersection(inside)
			if img.get_pixel(x, y).r < v:
				img.fill_rect(block, Color(v, v, v))


## Softens an image by about `tiles` tiles: shrunk so a texel covers that much, then grown back smoothly.
static func blur(img: Image, tiles: float) -> void:
	var size := img.get_size()
	var small := maxi(2, int(size.x / maxf(tiles * SHADE_RES, 1.0)))
	img.resize(small, small, Image.INTERPOLATE_LANCZOS)  # averages, so nothing is skipped
	img.resize(size.x, size.y, Image.INTERPOLATE_CUBIC)


## How shaded (x) and worn (y) the grass is at a point on the farm, 0..1 each.
func shade_at(world_xz: Vector2) -> Vector2:
	if _shade == null:
		return Vector2.ZERO
	var px := ((world_xz + Vector2(SHADE_PAD, SHADE_PAD)) * SHADE_RES).floor()
	if px.x < 0 or px.y < 0 or px.x >= _shade.get_width() or px.y >= _shade.get_height():
		return Vector2.ZERO
	var c := _shade.get_pixel(int(px.x), int(px.y))
	return Vector2(c.r, c.g)


## The kind of thing standing on a tile ("" for none); a stray counts as an animal.
static func _kind_at(r: int, c: int) -> String:
	var o := Game.object_at(Game.index_of(r, c))
	if o.is_empty():
		return ""
	return "animal" if o.get("stray", false) else Game.kind_of(o)


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


## Tufts in clumps over the grass: how thick they grow follows a slow noise over the land (so there are
## lush patches and thin ones), thinning where the grass is worn, and none through anything that covers
## the ground. Seeded by position, so they don't move when rebuilt.
func _scatter_tufts(n: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true  # each clump's shade, multiplied into its blades' colours
	mm.mesh = _tuft_mesh()
	var spots: Array[Transform3D] = []
	var tints: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	var lush := FastNoiseLite.new()
	lush.seed = 7
	lush.frequency = 0.21
	var reach := int(TUFT_REACH)
	for r in range(-reach, n + reach):
		for c in range(-reach, n + reach):
			var on_farm := r >= 0 and c >= 0 and r < n and c < n
			if on_farm and (Game.plots[Game.index_of(r, c)].get("state", "grass") != "grass"
					or COVERS_GRASS.has(_kind_at(r, c))):
				continue
			rng.seed = hash(Vector2i(r, c))
			var thick := clampf(lush.get_noise_2d(c, r) * 0.5 + 0.5, 0.0, 1.0)
			var worn := shade_at(Vector2(c + 0.5, r + 0.5)).y
			var most := CLUMP_MAX if on_farm else MEADOW_TUFTS_PER_TILE * 2
			var count := int(round(lerpf(1.0, most, pow(thick, 1.6)) * (1.0 - worn * 0.85)))
			var y := 0.0 if on_farm else -SLAB
			var centre := Vector2(c + rng.randf_range(0.2, 0.8), r + rng.randf_range(0.2, 0.8))
			var hue := rng.randf_range(-1.0, 1.0)
			for k in count:
				# Most of a tile's tufts gather round one spot; a few stray.
				var spread := 0.16 if k < count * 0.7 else 0.45
				var p := centre + Vector2(rng.randfn(0.0, spread), rng.randfn(0.0, spread))
				p = p.clamp(Vector2(c, r), Vector2(c + 0.999, r + 0.999))
				var s := rng.randf_range(0.7, 1.25) * lerpf(0.85, 1.15, thick)
				spots.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
					Vector3(p.x, y, p.y)))
				# Lusher clumps are a deeper green; thin or worn ones paler and yellower.
				var b := rng.randf_range(0.9, 1.08)
				tints.append(Color(b * (1.0 + 0.06 * hue + worn * 0.15), b * (1.0 - worn * 0.05),
					b * (0.92 + 0.08 * thick - worn * 0.2), 1.0))
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
		mm.set_instance_color(i, tints[i])
	_tufts.multimesh = mm


## Patches of wild flowers in the meadow and along the farm's edge, a few colours to a patch.
func _scatter_flowers(n: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _flower_mesh()
	var spots: Array[Transform3D] = []
	var tints: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	var reach := int(TUFT_REACH)
	for r in range(-reach, n + reach):
		for c in range(-reach, n + reach):
			var on_farm := r >= 0 and c >= 0 and r < n and c < n
			if on_farm:
				continue
			rng.seed = hash(Vector3i(r, c, 31))
			if rng.randf() > FLOWER_CHANCE:
				continue
			var centre := Vector2(c + rng.randf(), r + rng.randf())
			var col: Color = FLOWERS[rng.randi() % FLOWERS.size()]
			for k in rng.randi_range(3, 7):
				var p := centre + Vector2(rng.randfn(0.0, 0.14), rng.randfn(0.0, 0.14))
				var s := rng.randf_range(0.8, 1.2)
				spots.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
					Vector3(p.x, -SLAB, p.y)))
				tints.append(col.lightened(rng.randf_range(0.0, 0.15)))
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
		mm.set_instance_custom_data(i, tints[i])
	_flowers.multimesh = mm


## A wild flower: a stalk with two leaves, and a head of four petals round a centre (the head's vertices
## have alpha 0: the shader colours them with the flower's own colour).
static func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalk := Color("#4c7d2a")
	var h := 0.16
	st.set_normal(Vector3.UP)
	for v: Vector3 in [Vector3(-0.008, 0, 0), Vector3(0.008, 0, 0), Vector3(0, h, 0)]:
		st.set_color(stalk)
		st.add_vertex(v)
	for side: float in [-1.0, 1.0]:
		for v: Vector3 in [Vector3(0, 0.03, 0), Vector3(0.045 * side, 0.07, 0.01), Vector3(0, 0.07, 0)]:
			st.set_color(stalk.lightened(0.15))
			st.add_vertex(v)
	for k in 4:
		var a := TAU * k / 4.0
		var out := Vector3(cos(a), 0, sin(a)) * 0.035
		var side := Vector3(-sin(a), 0, cos(a)) * 0.016
		st.set_color(Color(1, 1, 1, 0))
		for v: Vector3 in [Vector3(0, h, 0) - side, Vector3(0, h, 0) + side, Vector3(0, h + 0.012, 0) + out]:
			st.add_vertex(v)
	return st.commit()


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
