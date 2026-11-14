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
const FOREST_RECT := Rect2(-16.0, -16.0, 66.0, 66.0)  # tiles the forest floor map covers
const FOREST_RES := 3              # its texels per tile
const FOREST_REACH := 2.6          # how far the woods' floor spreads from a tree (tiles)
const SHADE_BLUR := 0.4            # shade fades out over this much past what casts it (tiles)
const WEAR_REACH := 0.9            # and wear over this much

## Kinds that nothing grows through (trees and animals stand among the grass).
const COVERS_GRASS := ["building", "vehicle", "decor"]
const BAKE_SHADER := "res://shaders/ground_bake.gdshader"   # (unshaded, seen straight down)
const BAKE_FARM_RES := 24          # baked ground texels per tile on the farm (it's seen close up)
const BAKE_MEADOW_RES := 8         # and on the meadow round it (always further away)
## The ground shader's uniforms the bake paints from (the still look: ground_common.gdshaderinc).
const BAKE_PARAMS: Array[String] = ["grass_light", "grass_dark", "dry", "checker", "dryness", "farm_n", "verge",
	"mow", "patchy", "bare_amount", "bare", "cool", "forest_amount", "forest_map", "forest_rect", "forest_dark",
	"forest_moss", "litter", "edge_n"]
const TUFT_FLOATS := 16           # a tuft in the MultiMesh buffer: transform (12) and colour (4)
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
var _meadow_tufts := PackedFloat32Array()   # the meadow's tufts (MultiMesh buffer), kept: they never change
var _shade_texture: ImageTexture
var _baked_size := -1              # the farm size the ground's still look was painted for
var _bakes_waiting: Array = []     # [material, its viewport (weak), rect]: painted this frame, read from the next
var _farm_tufts := {}              # farm tile index -> its tufts (MultiMesh buffer data), kept per tile
var _lush := _make_lush()          # how thick the grass grows, a slow noise over the land
var _shade_signature := 0
var _forest_map: ImageTexture      # where the woods are: R, 1 under the trees fading out

var _size := -1


func _ready() -> void:
	var grass := ShaderMaterial.new()
	grass.shader = load("res://shaders/ground3d.gdshader")
	var meadow_grass := grass.duplicate() as ShaderMaterial
	meadow_grass.set_shader_parameter("checker", 0.0)
	meadow_grass.set_shader_parameter("dryness", 0.32)
	meadow_grass.set_shader_parameter("patchy", 0.5)
	meadow_grass.set_shader_parameter("bare_amount", 0.6)
	meadow_grass.set_shader_parameter("grass_light", Color(0.38, 0.56, 0.25))
	meadow_grass.set_shader_parameter("grass_dark", Color(0.19, 0.35, 0.15))
	meadow_grass.set_shader_parameter("forest_amount", 0.9)
	meadow_grass.set_shader_parameter("forest_map", forest_map())
	meadow_grass.set_shader_parameter("forest_rect", Vector4(FOREST_RECT.position.x, FOREST_RECT.position.y,
		FOREST_RECT.size.x, FOREST_RECT.size.y))
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


## Paints `grass`'s still look over `rect` (in tiles) into a texture once, at `res` texels a tile, and has the
## ground read it from then on (a phone does one lookup a pixel instead of some forty noise samples). Painted in an
## off-screen viewport the frame after; until then (and with no screen at all) the ground works its look out live.
func bake(grass: ShaderMaterial, rect: Rect2, res: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if grass.has_meta(&"bake"):
		var old: Object = (grass.get_meta(&"bake") as WeakRef).get_ref()
		if old != null:
			(old as Node).queue_free()
	var vp := SubViewport.new()
	vp.size = Vector2i(ceili(rect.size.x * res), ceili(rect.size.y * res))
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var m := ShaderMaterial.new()
	m.shader = load(BAKE_SHADER)
	for name in BAKE_PARAMS:
		var v: Variant = grass.get_shader_parameter(name)
		if v != null:
			m.set_shader_parameter(name, v)   # (the same values: both shaders treat them alike)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = rect.size
	plane.mesh = mesh
	plane.material_override = m
	plane.position = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	vp.add_child(plane)
	# Straight down, north (-z) at the top of the picture, so its rows run along z and its columns along x.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = rect.size.y
	cam.near = 0.1
	cam.far = 10.0
	vp.add_child(cam)
	cam.look_at_from_position(plane.position + Vector3.UP * 5.0, plane.position, Vector3.FORWARD)
	var r4 := Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	add_child(vp)
	var ref: WeakRef = weakref(vp)
	grass.set_meta(&"bake", ref)
	grass.set_shader_parameter("use_bake", false)
	_bakes_waiting.append([grass, ref, r4])
	if not RenderingServer.frame_post_draw.is_connected(_baked):
		RenderingServer.frame_post_draw.connect(_baked, CONNECT_ONE_SHOT)


## The bakes have been painted: the ground reads them from now on (each unless a newer one has taken its place).
func _baked() -> void:
	for w: Array in _bakes_waiting:
		var grass: ShaderMaterial = w[0]
		var vp := (w[1] as WeakRef).get_ref() as SubViewport
		if vp == null or grass.get_meta(&"bake") != w[1]:
			continue
		grass.set_shader_parameter("baked", vp.get_texture())
		grass.set_shader_parameter("bake_rect", w[2])
		grass.set_shader_parameter("use_bake", true)
	_bakes_waiting.clear()


static func _make_lush() -> FastNoiseLite:
	var lush := FastNoiseLite.new()
	lush.seed = 7
	lush.frequency = 0.21
	return lush


## Where the woods are, painted once from the scenery trees (FarmGrid.scenery(): they never move): 1 under
## each tree, fading out over FOREST_REACH tiles. The meadow's shader makes the forest floor of it.
func forest_map() -> ImageTexture:
	if _forest_map == null:
		_forest_map = ImageTexture.create_from_image(paint_forest(FarmGrid.scenery()))
	return _forest_map


static func paint_forest(trees: Array) -> Image:
	var side := int(FOREST_RECT.size.x * FOREST_RES)
	var img := Image.create_empty(side, side, false, Image.FORMAT_L8)
	var reach := FOREST_REACH * FOREST_RES
	for t in trees:
		# A scenery tree is [row, col, id]; the map is x = col, y = row.
		var cx := (float(t[1]) + 0.5 - FOREST_RECT.position.x) * FOREST_RES
		var cy := (float(t[0]) + 0.5 - FOREST_RECT.position.y) * FOREST_RES
		for y in range(maxi(int(cy - reach), 0), mini(int(cy + reach) + 1, side)):
			for x in range(maxi(int(cx - reach), 0), mini(int(cx + reach) + 1, side)):
				var v := 1.0 - Vector2(x - cx, y - cy).length() / reach
				if v > img.get_pixel(x, y).r:
					img.set_pixel(x, y, Color(v, v, v))
	return img


func _set_wind(v: float) -> void:
	wind = v
	# Every swaying shader (grass, flowers, crops, trees, scarecrows) reads the one global wind.
	ShaderGlobals.set_value(&"wind", v)


func rebuild() -> void:
	var n := Game.farm_size
	if n != _size:
		_size = n
		_build_slab(n)
		var plane := _meadow.mesh as PlaneMesh
		plane.size = Vector2(n + MEADOW * 2.0, n + MEADOW * 2.0)
		_meadow.position = Vector3(n / 2.0, -SLAB, n / 2.0)
		_meadow_tufts = PackedFloat32Array()
		_scatter_flowers(n)  # flowers grow only off the farm, so only its size moves them
	_grass[0].set_shader_parameter("farm_n", float(n))
	_grass[1].set_shader_parameter("edge_n", float(n))
	if n != _baked_size:
		_baked_size = n
		bake(_grass[0], Rect2(0, 0, n, n), BAKE_FARM_RES)
		bake(_grass[1], Rect2(-MEADOW, -MEADOW, n + MEADOW * 2.0, n + MEADOW * 2.0), BAKE_MEADOW_RES)
	_paint_shade(n)
	_scatter_tufts(n)




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
## the ground. Seeded by position, so they don't move when rebuilt. Each farm tile's tufts are kept, so a
## plot plowed or cleared changes only its own (`update_tiles`).
func _scatter_tufts(n: int) -> void:
	# The meadow's tufts never change (only the farm's size moves them): worked out once and kept.
	if _meadow_tufts.is_empty():
		_meadow_tufts = PackedFloat32Array()
		for r in range(-int(TUFT_REACH), n + int(TUFT_REACH)):
			for c in range(-int(TUFT_REACH), n + int(TUFT_REACH)):
				if r < 0 or c < 0 or r >= n or c >= n:
					_meadow_tufts.append_array(_tile_tufts(r, c, false))
	_farm_tufts.clear()
	for r in n:
		for c in n:
			_farm_tufts[Game.index_of(r, c)] = _tile_tufts(r, c, true)
	_lay_tufts()


## The tufts of farm plots `indices` follow their ground (grass, or a bed with none), and only theirs.
func update_tiles(indices: Array) -> void:
	if indices.is_empty() or _farm_tufts.is_empty():
		_scatter_tufts(Game.farm_size)
		return
	for i: int in indices:
		_farm_tufts[i] = _tile_tufts(int(i / float(GameState.MAX_SIZE)), i % GameState.MAX_SIZE, true)
	_lay_tufts()


func _lay_tufts() -> void:
	var buffer := PackedFloat32Array()
	for i: int in _farm_tufts:
		buffer.append_array(_farm_tufts[i])
	buffer.append_array(_meadow_tufts)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true  # each clump's shade, multiplied into its blades' colours
	mm.mesh = _tuft_mesh()
	mm.instance_count = buffer.size() / TUFT_FLOATS
	mm.buffer = buffer  # one copy into the engine, not two calls per tuft
	_tufts.multimesh = mm


## The tufts on tile (r, c), on the farm (`on_farm`) or in the meadow round it, as MultiMesh buffer data: for
## each, its transform as 3 rows of 4 floats, then its colour.
func _tile_tufts(r: int, c: int, on_farm: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if on_farm and (Game.plots[Game.index_of(r, c)].get("state", "grass") != "grass"
			or COVERS_GRASS.has(_kind_at(r, c))):
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(r, c))
	var thick := clampf(_lush.get_noise_2d(c, r) * 0.5 + 0.5, 0.0, 1.0)
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
		var sc := rng.randf_range(0.7, 1.25) * lerpf(0.85, 1.15, thick)
		var turn := rng.randf() * TAU
		var cs := cos(turn) * sc
		var sn := sin(turn) * sc
		# Lusher clumps are a deeper green; thin or worn ones paler and yellower.
		var b := rng.randf_range(0.9, 1.08)
		# A turn about up, scaled: rows (cs, 0, sn, x), (0, sc, 0, y), (-sn, 0, cs, z).
		out.append_array([cs, 0.0, sn, p.x, 0.0, sc, 0.0, y, -sn, 0.0, cs, p.y,
			b * (1.0 + 0.06 * hue + worn * 0.15), b * (1.0 - worn * 0.05),
			b * (0.92 + 0.08 * thick - worn * 0.2), 1.0])
	return out




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
