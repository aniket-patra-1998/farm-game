class_name ModelKit
extends RefCounted
## The building blocks of the farm's 3D models: boxes, prisms, cylinders, cones, spheres and roofs, each a
## mesh with its normals facing out, placed under a parent node; and the shared materials they're made of
## (made once and reused, so a farm of buildings needs a handful of materials, not hundreds).

const PAINT_SHADER := "res://shaders/paint3d.gdshader"
const CANOPY_SHADER := "res://shaders/canopy3d.gdshader"
const FOLIAGE_SHADER := "res://shaders/foliage3d.gdshader"
const SPRIG_SIZE := 64         # the leaf-cluster texture, in pixels a side
const RAKE_COLOUR := Color("#f3eee2")   # barge boards up a roof's sloped ends
const RAKE_WIDTH := 0.035
const SPRIG_LEAVES := 9        # leaves on a sprig
const KEEP := &"keep_unbaked"  # meta on a part that moves on its own: bake leaves it whole

## Tessellation: enough to read round at farm zoom on a phone, no more (each ball is ~170 triangles,
## each cylinder ~48, before the shadow pass draws them again).
const GLASS_GLOW := 3.4      # how bright lit windows are at night (emission energy at full dark)
const GLOW_LIFT := 0.02      # a pool of light lies this far above the ground
const FACET_SEGMENTS := 8     # a faceted ball: around
const FACET_RINGS := 4        # and up
const MIN_DETAIL := 0.35
const BALL_SEGMENTS := 8
const BALL_RINGS := 5
const SMOOTH_SEGMENTS := 12   # the balls that make up an animal's body and head: round, not faceted
const SMOOTH_RINGS := 7
const CANOPY_SEGMENTS := 16   # a canopy's grid: around
const CANOPY_BANDS := 4.0     # steps of light on a canopy,
const CANOPY_BANDING := 0.55  # how firmly it keeps to them (0: smooth)
const CANOPY_MOTTLE := 0.1    # and how much leaf-sized patches vary it
const CANOPY_RINGS := 8       # and up

const CYLINDER_SIDES := 12


## Shaders that tint by vertex colour, and the colour parameter each one's materials set.
const TINT_PARAMS := {"res://shaders/paint3d.gdshader": "albedo", "res://shaders/wall3d.gdshader": "base_color",
	"res://shaders/canopy3d.gdshader": "albedo"}

const WHITE_TWIN := &"white_twin"  # meta on a white twin
const LOD_LEVELS := &"lod_levels"   # meta on a baked mesh: how many simpler levels it carries
const LOD_MIN_TRIANGLES := 600     # a baked mesh this big or bigger gets simpler versions for when it is drawn small
const LOD_NORMAL_MERGE := 25.0     # degrees: faces this close in angle may merge when a level is made simpler
const LOD_NORMAL_SPLIT := 60.0     # and faces this far apart keep a hard edge
const WALL_SHADER := "res://shaders/wall3d.gdshader"
const WALL_STYLES := 6             # boards, logs, stone, plaster, shingles, metal
const WALL_AO_STEP := 0.02         # the ground shade packed for a wall is a whole number of these



static var _facet_mesh: ArrayMesh
static var _facet_low: ArrayMesh   # the same ball with fewer facets, for crowds
## How much detail the parts built now get, 1 full .. MIN_DETAIL: orchards and gardens build dozens of the
## same model, so BuildingFill lowers it while it builds them (fewer sides, rings, clumps and petals).
static var detail := 1.0
## Set while an animal is built: its balls are round (SMOOTH_*), not the coarse ones trees and rocks use.
static var round_balls := false
static var _materials := {}  # key -> Material

static var _sprig: ImageTexture
static var _meshes := {}     # key -> Mesh (shared unit shapes)


static var _white := {}   # material id -> [white twin, colour]
## Whether `bake` gives big meshes simpler levels of detail (off for one-off close-ups such as item pictures).
static var lods := true
## The last value each global shader value was set to through `set_global` (the engine can't be asked cheaply).
static var globals := {}


# ---------------------------------------------------------------- materials


## A plain coloured material (matte unless `shine`), darkening where it meets the ground (paint3d).
static func paint(col: Color, shine := 0.0, sway := 0.0) -> ShaderMaterial:
	var key := "paint:%s:%.2f:%.3f" % [col.to_html(), shine, sway]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/paint3d.gdshader")
		m.set_shader_parameter("albedo", col)
		m.set_shader_parameter("roughness", 1.0 - shine * 0.6)
		m.set_shader_parameter("specular", 0.1 + shine * 0.4)
		if sway > 0.0:
			m.set_shader_parameter("sway", sway)
		_materials[key] = m
	return _materials[key]


## One white painted material that reads each part's shine from its vertex alpha (see `shine_arrays`), so parts of
## every finish can share a surface: a skinned animal is one draw instead of one per finish.
static func coat() -> ShaderMaterial:
	if not _materials.has("coat"):
		var m := ShaderMaterial.new()
		m.shader = load(PAINT_SHADER)
		m.set_shader_parameter("albedo", Color.WHITE)
		m.set_shader_parameter("shine_in_alpha", true)
		m.set_meta(WHITE_TWIN, true)
		_materials["coat"] = m
	return _materials["coat"]


## The one white wall material that reads each part's pattern and ground shade from its vertex alpha (`wall_pack`).
static func wall_coat() -> ShaderMaterial:
	if not _materials.has("wall_coat"):
		var m := ShaderMaterial.new()
		m.shader = load(WALL_SHADER)
		m.set_shader_parameter("base_color", Color.WHITE)
		m.set_shader_parameter("packed_in_alpha", true)
		m.set_meta(WHITE_TWIN, true)
		_materials["wall_coat"] = m
	return _materials["wall_coat"]


## A wall's pattern (0..WALL_STYLES-1) and ground shade packed into one vertex alpha: 32 steps of each
## WALL_AO_STEP of shade per pattern (shaders/wall3d.gdshader unpacks it the same way).
static func wall_pack(style: int, ao: float) -> float:
	var shade := clampi(roundi(ao / WALL_AO_STEP), 0, 31)
	return float(clampi(style, 0, WALL_STYLES - 1) * 32 + shade) / 255.0


## The shine (0..1) a painted material was made with (the inverse of `paint`'s roughness curve).
static func shine_of(mat: Material) -> float:
	return clampf((1.0 - float((mat as ShaderMaterial).get_shader_parameter("roughness"))) / 0.6, 0.0, 1.0)


## Whether a material is a plain painted one that can join the shared `coat` (not swaying in the wind).
static func is_coatable(mat: Material) -> bool:
	var sm := mat as ShaderMaterial
	return sm != null and sm.shader != null and sm.shader.resource_path == PAINT_SHADER \
		and float(sm.get_shader_parameter("sway") if sm.get_shader_parameter("sway") != null else 0.0) <= 0.0


## Arrays whose vertex colours (made by `tint_arrays`) carry `shine` in their alpha, for the `coat` material.
static func shine_arrays(arrays: Array, shine: float) -> Array:
	var out := arrays.duplicate()
	var colours: PackedColorArray = (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate()
	for i in colours.size():
		colours[i].a = shine
	out[Mesh.ARRAY_COLOR] = colours
	return out


## The leaf-pattern material of a canopy (white: the colour is in the vertices); `sway` bends it in the wind.
static func leaves(shine := 0.0, sway := 0.0) -> ShaderMaterial:
	var key := "leaves:%.2f:%.3f" % [shine, sway]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(CANOPY_SHADER)
		m.set_shader_parameter("albedo", Color.WHITE)
		m.set_shader_parameter("roughness", 1.0 - shine * 0.6)
		m.set_shader_parameter("specular", 0.1 + shine * 0.4)
		if sway > 0.0:
			m.set_shader_parameter("sway", sway)
		_materials[key] = m
	return _materials[key]


## The material of foliage cards (white: the colour is in the vertices), with the leaf-cluster texture.
static func foliage(shine := 0.0, sway := 0.0) -> ShaderMaterial:
	var key := "foliage:%.2f:%.3f" % [shine, sway]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(FOLIAGE_SHADER)
		m.set_shader_parameter("sprig", leaf_texture())
		m.set_shader_parameter("roughness", 1.0 - shine * 0.6)
		m.set_shader_parameter("specular", 0.1 + shine * 0.4)
		if sway > 0.0:
			m.set_shader_parameter("sway", sway)
		_materials[key] = m
	return _materials[key]


## A sprig of leaves, drawn once: red is where there is leaf (the rest is cut away), green how light it is (leaf
## tips catch the light, bases and veins are darker). The stem is at the bottom middle, the tip at the top.
static func leaf_texture() -> ImageTexture:
	if _sprig != null:
		return _sprig
	var n := SPRIG_SIZE
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	# Leaves along a stem: a pair every so often, the longest in the middle, and one at the tip.
	var leaves: Array = []   # [base (0..1, y up), angle from straight up, length, half width]
	leaves.append([Vector2(0.5, 0.52), 0.0, 0.46, 0.085])
	for k in (SPRIG_LEAVES - 1) / 2:
		var h := 0.08 + 0.17 * k
		var len := 0.34 - 0.03 * k
		leaves.append([Vector2(0.5, h), -1.0 + 0.12 * k, len, 0.075])
		leaves.append([Vector2(0.5, h + 0.04), 1.0 - 0.12 * k, len, 0.075])
	for y in n:
		for x in n:
			var p := Vector2((x + 0.5) / n, 1.0 - (y + 0.5) / n)
			var cover := 0.0
			var light := 0.0
			# The stem.
			if absf(p.x - 0.5) < 0.012 and p.y < 0.6:
				cover = 1.0
				light = 0.5
			for l: Array in leaves:
				var base: Vector2 = l[0]
				var a: float = l[1]
				var dir := Vector2(sin(a), cos(a))
				var side := Vector2(dir.y, -dir.x)
				var d := p - base
				var along: float = d.dot(dir) / float(l[2])
				if along < 0.0 or along > 1.0:
					continue
				var across := absf(d.dot(side))
				var width: float = float(l[3]) * pow(sin(PI * pow(along, 0.8)), 0.85)
				if across < width:
					cover = 1.0
					var vein := 1.0 - smoothstep(0.0, 0.012, across)
					light = maxf(light, 0.62 + 0.38 * along - 0.18 * vein - 0.12 * (across / maxf(width, 0.001)))
			img.set_pixel(x, y, Color(cover, clampf(light, 0.0, 1.0), 0.0, 1.0))
	img.generate_mipmaps()
	_sprig = ImageTexture.create_from_image(img)
	return _sprig


## Leafy foliage over an ellipsoid: `count` cards, each a sprig of leaves, spread over its upper and outer side and
## facing outward, so the crown has a ragged leafy outline. `shade` turns how lit a card is (0 shade .. 1 sun) into its
## colour; `sun` is the light in the mesh's own space. One mesh, one draw.
static func foliage_cards(parent: Node3D, centre: Vector3, radii: Vector3, rng: RandomNumberGenerator,
		shade: Callable, sun: Vector3, count: int, card: float, shine := 0.0) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in count:
		# A direction over the sphere, more of them up and out than underneath; the card sits on the surface or a
		# little inside it, so the cards make shells of foliage.
		var y := rng.randf_range(-0.55, 1.0)
		var a := rng.randf() * TAU
		var r := sqrt(maxf(1.0 - y * y, 0.0))
		var dir := Vector3(cos(a) * r, y, sin(a) * r)
		var depth := rng.randf_range(0.8, 1.02)
		var at := dir * radii * depth
		var out := (dir / radii).normalized()          # an ellipsoid's own outward normal
		var along := Vector3.UP.cross(out)
		if along.length_squared() < 0.01:
			along = Vector3.RIGHT
		along = along.normalized()
		var rise := out.cross(along).normalized()      # up the card, in its plane
		var roll := rng.randf_range(-0.8, 0.8)
		var right := (along * cos(roll) + rise * sin(roll)).normalized()
		var up := (rise * cos(roll) - along * sin(roll)).normalized()
		if up.y < 0.0:                                 # sprigs reach upward and outward, they do not point at the ground
			up = -up
			right = -right
		var size := card * rng.randf_range(0.8, 1.25)
		var base := at - up * size * 0.15
		var light := clampf(0.55 + 0.3 * out.y + 0.3 * out.dot(sun) + rng.randf_range(-0.1, 0.1), 0.25, 0.85)
		var colour: Color = shade.call(light)
		var flip := rng.randf() < 0.5
		var start := verts.size()
		for c in 4:
			var cx := -0.5 if c == 0 or c == 3 else 0.5
			var cy := 0.0 if c < 2 else 1.0
			verts.append(base + right * cx * size + up * cy * size)
			norms.append(out)
			var u := cx + 0.5
			uvs.append(Vector2(1.0 - u if flip else u, 1.0 - cy))
			cols.append(colour)
		idx.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = centre
	mi.material_override = foliage(shine)
	parent.add_child(mi)
	return mi


## Makes every painted part under `root` bend in the wind by `amount` (paint3d's sway, by height above
## the model's foot), keeping each part's colour and shine. Applied before baking, the parts still merge
## into one draw (they share the swaying white twin).
static func sway_all(root: Node, amount: float) -> void:
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		var m := mi.material_override as ShaderMaterial
		if m != null and m.shader != null and m.shader.resource_path == CANOPY_SHADER:
			var lr := float(m.get_shader_parameter("roughness"))
			mi.material_override = leaves((1.0 - lr) / 0.6, amount)
		elif m != null and m.shader != null and m.shader.resource_path == FOLIAGE_SHADER:
			var fr := float(m.get_shader_parameter("roughness"))
			mi.material_override = foliage((1.0 - fr) / 0.6, amount)
		elif m != null and m.shader != null and m.shader.resource_path == PAINT_SHADER:
			var rough := float(m.get_shader_parameter("roughness"))
			var col = m.get_shader_parameter("albedo")
			mi.material_override = paint(col if col is Color else Color(col.x, col.y, col.z),
				(1.0 - rough) / 0.6, amount)
	for c in root.get_children():
		sway_all(c, amount)


## A wall or roof surface with a pattern (see shaders/wall3d.gdshader): boards, logs, stone, plaster,
## shingles or metal.
static func surface(col: Color, style: String, ao := 0.45) -> ShaderMaterial:
	var key := "surface:%s:%s:%.2f" % [col.to_html(), style, ao]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/wall3d.gdshader")
		m.set_shader_parameter("base_color", col)
		m.set_shader_parameter("style", ["boards", "logs", "stone", "plaster", "shingles", "metal"].find(style))
		m.set_shader_parameter("ground_ao", ao)
		_materials[key] = m
	return _materials[key]


## Glass that catches the sky, and glows warm at night (`glow` 0..1, shared by every window).
static func glass() -> StandardMaterial3D:
	if not _materials.has("glass"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#9cc7da")
		m.roughness = 0.15
		m.metallic_specular = 0.9
		m.emission_enabled = true
		m.emission = Color(1.0, 0.78, 0.42)
		m.emission_energy_multiplier = 0.0
		_materials["glass"] = m
	return _materials["glass"]


static func set_window_glow(glow: float) -> void:
	glass().emission_energy_multiplier = glow * GLASS_GLOW
	glow_material().set_shader_parameter("strength", glow)
	set_global(&"dark", glow)  # butterflies and fireflies read it too


## Sets a global shader value and remembers it in `globals` (for code that must know it, as item pictures do).
static func set_global(name: StringName, value: Variant) -> void:
	globals[name] = value
	RenderingServer.global_shader_parameter_set(name, value)


## The shared material of every pool of light a lit window or door throws on the ground (shaders/glow3d).
static func glow_material() -> ShaderMaterial:
	if not _materials.has("glow"):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/glow3d.gdshader")
		_materials["glow"] = m
	return _materials["glow"]


## A pool of warm light on the ground, `size` across, centred on `at` (x, z). Left out of the bake (it
## is drawn blended and shares nothing), casts no shadow.
static func glow_pool(parent: Node3D, at: Vector3, size: Vector2) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = glow_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(at.x, GLOW_LIFT, at.z)
	mi.set_meta(KEEP, true)
	parent.add_child(mi)
	return mi


## Still water: shared and rippling (DecorMotion.water: shaders/water3d), one material for all of it.
static func water() -> ShaderMaterial:
	return DecorMotion.water()


# ---------------------------------------------------------------- shapes


## A box from `lo` to `hi` (axis aligned in the parent's space).
static func box(parent: Node3D, lo: Vector3, hi: Vector3, mat: Material, shadow := true) -> MeshInstance3D:
	var size := (hi - lo).abs()
	if size.x <= 0.0001 or size.y <= 0.0001 or size.z <= 0.0001:
		return null
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = (lo + hi) / 2.0
	mi.material_override = mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi




## An open tub (a trough, a planter) from `lo` to `hi`: a floor and four walls `wall` thick, filled with
## `fill` (water) to `fill_to` of its height. Hollow, so what's in it shows: a solid box with water inside it
## hides the water.
static func tub(parent: Node3D, lo: Vector3, hi: Vector3, wall: float, mat: Material, fill: Material = null,
		fill_to := 0.8) -> void:
	box(parent, lo, Vector3(hi.x, lo.y + wall, hi.z), mat)
	box(parent, Vector3(lo.x, lo.y, lo.z), Vector3(lo.x + wall, hi.y, hi.z), mat)
	box(parent, Vector3(hi.x - wall, lo.y, lo.z), Vector3(hi.x, hi.y, hi.z), mat)
	box(parent, Vector3(lo.x + wall, lo.y, lo.z), Vector3(hi.x - wall, hi.y, lo.z + wall), mat)
	box(parent, Vector3(lo.x + wall, lo.y, hi.z - wall), Vector3(hi.x - wall, hi.y, hi.z), mat)
	if fill != null:
		var top := lerpf(lo.y + wall, hi.y, fill_to)
		box(parent, Vector3(lo.x + wall, lo.y + wall, lo.z + wall), Vector3(hi.x - wall, top, hi.z - wall), fill, false)


## An upright cylinder (or a cone, with `top_r` 0) standing on `base`.
static func cylinder(parent: Node3D, base: Vector3, r: float, h: float, mat: Material, top_r := -1.0,
		sides := CYLINDER_SIDES) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r
	mesh.top_radius = r if top_r < 0.0 else top_r
	mesh.height = h
	mesh.radial_segments = scaled(sides, 5)
	mesh.rings = 1
	mi.mesh = mesh
	mi.position = base + Vector3(0, h / 2.0, 0)
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A count cut down by the current detail, never below `least`.
static func scaled(count: int, least: int) -> int:
	return maxi(roundi(count * detail), mini(least, count))


## A sphere (or a squashed one, with `scale`).
static func ball(parent: Node3D, centre: Vector3, r: float, mat: Material, scale := Vector3.ONE,
		smooth := false) -> MeshInstance3D:
	smooth = smooth or round_balls
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = scaled(SMOOTH_SEGMENTS if smooth else BALL_SEGMENTS, 6)
	mesh.rings = scaled(SMOOTH_RINGS if smooth else BALL_RINGS, 3)
	mi.mesh = mesh
	mi.position = centre
	mi.scale = scale
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A faceted ball: a low-poly sphere with each face lit flat, so its facets catch the light separately (leafy
## clumps, rocks, bushes read as many planes, not one smooth blob). The mesh is made once and shared.
static func facet_ball(parent: Node3D, centre: Vector3, r: float, mat: Material,
		scale := Vector3.ONE) -> MeshInstance3D:
	var low := detail < 0.7
	if _facet_mesh == null or (low and _facet_low == null):
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = FACET_SEGMENTS - (2 if low else 0)
		sphere.rings = FACET_RINGS - (1 if low else 0)
		var st := SurfaceTool.new()
		st.create_from(sphere, 0)
		st.deindex()
		st.generate_normals()
		if low:
			_facet_low = st.commit()
		else:
			_facet_mesh = st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _facet_low if low else _facet_mesh
	mi.position = centre
	mi.scale = scale * r
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A leafy canopy: one smooth, lumpy mass (an ellipsoid of `radii`, pushed out in `lobes` rounded bulges, like
## the scalloped crown of a painted tree), shaded by vertex colour from `shade` (a Callable from how lit a point
## is, 0 deep shade .. 1 full sun, to a colour). `sun` is the direction of the light in the mesh's own space.
## One mesh and one draw, soft inside and rough only along its outline; the paint material is white because
## the colour is in the vertices.
static func canopy(parent: Node3D, centre: Vector3, radii: Vector3, rng: RandomNumberGenerator, shade: Callable,
		sun: Vector3, lobes := 7, bump := 0.2, shine := 0.0) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = scaled(CANOPY_SEGMENTS, 8)
	sphere.rings = scaled(CANOPY_RINGS, 4)
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var dirs: Array[Vector3] = []
	var tones: Array[float] = []
	for i in lobes:
		# Bulges spread over the upper and side of the mass, a little more of them up where the light is.
		var y := rng.randf_range(-0.35, 1.0)
		var a := rng.randf() * TAU
		var r := sqrt(maxf(1.0 - y * y, 0.0))
		dirs.append(Vector3(cos(a) * r, y, sin(a) * r))
		tones.append(rng.randf_range(-0.09, 0.09))   # each bulge a touch lighter or darker: leaves in clusters
	var colours := PackedColorArray()
	colours.resize(verts.size())
	for i in verts.size():
		var d := verts[i].normalized()
		var push := 0.0
		var tone := 0.0
		for k in lobes:
			var w := smoothstep(0.45, 1.0, d.dot(dirs[k]))
			push += w
			tone += w * tones[k]
		verts[i] = d * radii * (1.0 + bump * (push - 0.35))
		var light := clampf(0.45 + 0.4 * d.y + 0.42 * d.dot(sun) + tone + 0.08 * push, 0.0, 1.0)
		# Painted, not smooth: light falls in a few soft bands, with a mottle of leaf-sized lighter and darker patches.
		light = lerpf(light, roundf(light * CANOPY_BANDS) / CANOPY_BANDS, CANOPY_BANDING)
		light = clampf(light + CANOPY_MOTTLE * sin(d.x * 11.0 + d.z * 5.0) * sin(d.y * 13.0 + d.x * 4.0)
			* sin(d.z * 12.0 - d.y * 6.0), 0.0, 1.0)
		colours[i] = shade.call(light)
	# Smooth normals: the same point is one vertex (the seam of the sphere's grid is a pair) so no crease shows.
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var acc := {}
	for t in range(0, idx.size(), 3):
		var fn := (verts[idx[t + 1]] - verts[idx[t]]).cross(verts[idx[t + 2]] - verts[idx[t]])
		for j in 3:
			var key := Vector3i((verts[idx[t + j]] * 1000.0).round())
			acc[key] = (acc.get(key, Vector3.ZERO) as Vector3) + fn
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in verts.size():
		normals[i] = (acc.get(Vector3i((verts[i] * 1000.0).round()), Vector3.UP) as Vector3).normalized()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = centre
	mi.material_override = leaves(shine)
	parent.add_child(mi)
	return mi


## A mesh from flat faces (each a list of 3 or 4 points), with each face's normal facing away from
## `inside`, so lighting is right whichever way round the points were listed.
static func faces(parent: Node3D, list: Array, inside: Vector3, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Array in list:
		var a: Vector3 = f[0]
		var b: Vector3 = f[1]
		var c: Vector3 = f[2]
		var n := (b - a).cross(c - a).normalized()
		var centre := Vector3.ZERO
		for v: Vector3 in f:
			centre += v
		centre /= f.size()
		if n.dot(centre - inside) < 0.0:
			n = -n
		# Godot draws a triangle's front when its corners run clockwise seen from outside, i.e. when
		# (b - a) x (c - a) points into the surface; list the corners the other way round if not.
		var order := [0, 1, 2] if f.size() == 3 else [0, 1, 2, 0, 2, 3]
		if (b - a).cross(c - a).dot(n) > 0.0:
			order = [0, 2, 1] if f.size() == 3 else [0, 2, 1, 0, 3, 2]
		for i: int in order:
			st.set_normal(n)
			st.add_vertex(f[i])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A roof over the block from `lo` to `hi` (its walls' top corners), overhanging by `over`. Kinds:
## gable (ridge along the longer side), gambrel (a barn's two-pitch roof), hip, shed (one slope down to
## the front), flat, dome. `rise` is how high the ridge stands over the walls. Returns the ridge's top.
static func roof(parent: Node3D, kind: String, lo: Vector3, hi: Vector3, rise: float, over: float,
		mat: Material, gable_mat: Material) -> float:
	var y := hi.y
	var x0 := lo.x - over
	var x1 := hi.x + over
	var z0 := lo.z - over
	var z1 := hi.z + over
	var top := y + rise
	var inside := Vector3((lo.x + hi.x) / 2.0, y + rise * 0.3, (lo.z + hi.z) / 2.0)
	var along_x := (hi.x - lo.x) >= (hi.z - lo.z)
	match kind:
		"gable", "gambrel":
			# Work in "ridge" coordinates: u along the ridge, v across it; then map back.
			var map := func(u: float, v: float, h: float) -> Vector3:
				return Vector3(u, h, v) if along_x else Vector3(v, h, u)
			var u0 := x0 if along_x else z0
			var u1 := x1 if along_x else z1
			var v0 := z0 if along_x else x0
			var v1 := z1 if along_x else x1
			var vm := (v0 + v1) / 2.0
			var wall_v0 := (lo.z if along_x else lo.x)
			var wall_v1 := (hi.z if along_x else hi.x)
			var eave := y - over * rise / maxf(vm - v0, 0.01)
			var slopes: Array = []
			var ends: Array = []
			if kind == "gable":
				slopes = [[
					map.call(u0, v0, eave),
					map.call(u1, v0, eave),
					map.call(u1, vm, top),
					map.call(u0, vm, top)
				],
					[map.call(u0, v1, eave), map.call(u1, v1, eave), map.call(u1, vm, top), map.call(u0, vm, top)]]
				for u: float in [lo.x if along_x else lo.z, hi.x if along_x else hi.z]:
					ends.append([map.call(u, wall_v0, y), map.call(u, wall_v1, y), map.call(u, vm, top)])
			else:
				var knee := y + rise * 0.62
				var kv0 := v0 + (vm - v0) * 0.32
				var kv1 := v1 - (v1 - vm) * 0.32
				slopes = [[
					map.call(u0, v0, eave),
					map.call(u1, v0, eave),
					map.call(u1, kv0, knee),
					map.call(u0, kv0, knee)
				],
					[map.call(u0, kv0, knee), map.call(u1, kv0, knee), map.call(u1, vm, top), map.call(u0, vm, top)],
					[map.call(u0, v1, eave), map.call(u1, v1, eave), map.call(u1, kv1, knee), map.call(u0, kv1, knee)],
					[map.call(u0, kv1, knee), map.call(u1, kv1, knee), map.call(u1, vm, top), map.call(u0, vm, top)]]
				var wk0 := wall_v0 + (vm - wall_v0) * 0.3
				var wk1 := wall_v1 - (wall_v1 - vm) * 0.3
				for u: float in [lo.x if along_x else lo.z, hi.x if along_x else hi.z]:
					ends.append([map.call(u, wall_v0, y), map.call(u, wall_v1, y), map.call(u, wk1, knee),
						map.call(u, wk0, knee)])
					ends.append([map.call(u, wk0, knee), map.call(u, wk1, knee), map.call(u, vm, top)])
			faces(parent, slopes, inside, mat)
			faces(parent, ends, inside, gable_mat)
			_roof_edges(parent, slopes, mat)
			_rake_boards(parent, slopes)
		"hip":
			var cx := (x0 + x1) / 2.0
			var cz := (z0 + z1) / 2.0
			var half := minf(x1 - x0, z1 - z0) / 2.0
			var r0 := Vector3(x0 + half, top, cz) if along_x else Vector3(cx, top, z0 + half)
			var r1 := Vector3(x1 - half, top, cz) if along_x else Vector3(cx, top, z1 - half)
			var e := y - over * 0.5
			var c00 := Vector3(x0, e, z0)
			var c10 := Vector3(x1, e, z0)
			var c11 := Vector3(x1, e, z1)
			var c01 := Vector3(x0, e, z1)
			if along_x:
				faces(parent, [[c00, c10, r1, r0], [c01, c11, r1, r0], [c00, c01, r0], [c10, c11, r1]], inside, mat)
			else:
				faces(parent, [[c00, c01, r1, r0], [c10, c11, r1, r0], [c00, c10, r0], [c01, c11, r1]], inside, mat)
		"shed":
			# One slope, high at the back (low z and x) and low over the front the camera sees.
			var back_h := top
			var front_h := y
			var pts := [Vector3(x0, back_h, z0), Vector3(x1, lerpf(back_h, front_h, 0.5), z0),
				Vector3(x1, front_h, z1), Vector3(x0, lerpf(back_h, front_h, 0.5), z1)]
			faces(parent, [pts], inside - Vector3(0, 1, 0), mat)
			box(parent, Vector3(x0, front_h - 0.03, z1 - 0.02), Vector3(x1, front_h, z1 + 0.01), mat)
			# Side walls up to the slope.
			faces(parent, [[Vector3(lo.x, y, hi.z), Vector3(lo.x, y, lo.z), Vector3(lo.x, back_h, lo.z)],
				[Vector3(hi.x, y, lo.z), Vector3(hi.x, y, hi.z), Vector3(hi.x, lerpf(back_h, front_h, 0.5), lo.z)]],
				inside, gable_mat)
		"flat":
			box(parent, Vector3(x0, y, z0), Vector3(x1, y + 0.06, z1), mat)
			top = y + 0.06
		"dome":
			var r := minf(hi.x - lo.x, hi.z - lo.z) / 2.0
			ball(parent, Vector3(inside.x, y, inside.z), r, mat, Vector3(1, rise / maxf(r, 0.01), 1))
	return top


## A darker strip along a roof's lower edge (the eave), so the roof reads as having thickness.
## The white boards that run up the sloped ends of a gable or gambrel roof (a farm building's barge boards):
## one along each slope's two end edges, a little proud of the roof.
static func _rake_boards(parent: Node3D, slopes: Array) -> void:
	var white := paint(RAKE_COLOUR)
	for s: Array in slopes:
		for pair: Array in [[s[0], s[3]], [s[1], s[2]]]:
			var a: Vector3 = pair[0]
			var b: Vector3 = pair[1]
			var length := a.distance_to(b)
			if length < 0.01:
				continue
			var mi := box(parent, Vector3(-RAKE_WIDTH / 2.0, -RAKE_WIDTH / 2.0, -length / 2.0),
				Vector3(RAKE_WIDTH / 2.0, RAKE_WIDTH / 2.0, length / 2.0), white)
			var dir := (b - a) / length
			mi.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), (a + b) / 2.0 + Vector3(0, RAKE_WIDTH * 0.4, 0))


static func _roof_edges(parent: Node3D, slopes: Array, mat: Material) -> void:
	var edge := mat
	if mat is ShaderMaterial:
		# A patterned surface keeps its colour in base_color, a painted one in albedo.
		var sm := mat as ShaderMaterial
		var v: Variant = sm.get_shader_parameter("base_color")
		var col: Color = v if v != null else sm.get_shader_parameter("albedo")
		edge = paint(col.darkened(0.2))
	for s: Array in [slopes[0], slopes[slopes.size() / 2]]:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var lo := Vector3(minf(a.x, b.x), a.y - 0.05, minf(a.z, b.z)) - Vector3(0.01, 0, 0.01)
		var hi := Vector3(maxf(a.x, b.x), a.y + 0.005, maxf(a.z, b.z)) + Vector3(0.01, 0, 0.01)
		box(parent, lo, hi, edge)


# ---------------------------------------------------------------- merging


## Merges every mesh under `root` into as few as possible: one MeshInstance3D for the parts that cast
## shadows and one for those that don't, each with one surface per material. A building authored from a
## hundred boxes is then drawn in a handful of draws. The parts' own transforms are kept; `root` is freed.
## A part marked to move on its own (meta KEEP: a door on its hinge) is left whole and carried over, with
## its place, so it can still swing.
static func bake(root: Node3D) -> Node3D:
	var groups := {}   # "shadow|material id|format" -> {"st": SurfaceTool, "mat": Material, "shadow": bool}
	var kept: Array = []  # [node, its transform in root's space]
	_collect(root, Transform3D.IDENTITY, groups, kept)
	var out := Node3D.new()
	out.transform = root.transform
	for k: Array in kept:
		var n: Node3D = k[0]
		n.get_parent().remove_child(n)
		n.transform = k[1]
		out.add_child(n)
		# What hangs on it is baked too: a door is one or two draws, not a dozen boxes. A child that's already
		# a finished mesh (no parts under it: a moving effect, a part baked before) is left as it is;
		# re-baking it would bake nothing and lose it.
		for part in n.get_children():
			if part is Node3D and part.get_child_count() > 0:
				n.remove_child(part)
				n.add_child(bake(part))
	for shadow: bool in [true, false]:
		var mesh := ArrayMesh.new()
		var mats: Array[Material] = []
		for key in groups:
			var g: Dictionary = groups[key]
			if g["shadow"] != shadow:
				continue
			(g["st"] as SurfaceTool).commit(mesh)
			mats.append(g["mat"])
		if mesh.get_surface_count() == 0:
			continue
		if lods:
			mesh = with_lods(mesh)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		for k in mats.size():
			mi.set_surface_override_material(k, mats[k])
		if not shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.add_child(mi)
	root.free()
	return out


static func _collect(node: Node, xf: Transform3D, groups: Dictionary, kept: Array) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		var c := child as Node3D
		var cxf := xf * c.transform
		if c.has_meta(KEEP):
			kept.append([c, cxf])
			continue
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var mi := c as MeshInstance3D
			var shadow := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for s in mi.mesh.get_surface_count():
				var mat := mi.material_override if mi.material_override != null else mi.get_active_material(s)
				var arrays := mi.mesh.surface_get_arrays(s)
				# A painted or patterned part's colour moves into its vertices and the part takes its shader's
				# one white material, so every part painted with that shader merges into one draw, whatever
				# its colour (the shaders tint by vertex colour).
				var tint := tinted(mat)
				if not tint.is_empty():
					mat = tint[0]
					arrays = tint_arrays(arrays, tint[1])
				# Surfaces only merge with the same vertex layout (a box has UVs, a hand-made face doesn't).
				var fmt := 0
				for k: int in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR, Mesh.ARRAY_TANGENT]:
					if arrays[k] != null:
						fmt |= 1 << k
				var key := "%s|%d|%d" % [shadow, mat.get_instance_id() if mat != null else 0, fmt]
				if not groups.has(key):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					groups[key] = {"st": st, "mat": mat, "shadow": shadow}
				if tint.is_empty():
					(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, s, cxf)
				else:
					var one := ArrayMesh.new()
					one.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
					(groups[key]["st"] as SurfaceTool).append_from(one, 0, cxf)
		_collect(c, cxf, groups, kept)




## Merges a node's own plain parts (MeshInstance3D children with nothing under them, not in `skip`) into
## one mesh, a draw per shader instead of one per part: for models whose other parts move (animals).
static func merge_leaves(parent: Node3D, skip: Array) -> void:
	var tmp := Node3D.new()
	for c in parent.get_children():
		if c is MeshInstance3D and c.get_child_count() == 0 and not skip.has(c) and not c.has_meta(KEEP):
			parent.remove_child(c)
			tmp.add_child(c)
	if tmp.get_child_count() < 2:
		for c in tmp.get_children():
			tmp.remove_child(c)
			parent.add_child(c)
		tmp.free()
		return
	parent.add_child(bake(tmp))




## For a material whose shader tints by vertex colour: [its white twin, its colour]; otherwise [].
static func tinted(mat: Material) -> Array:
	if not mat is ShaderMaterial or (mat as ShaderMaterial).shader == null:
		return []
	var id := mat.get_instance_id()
	if _white.has(id):
		return _white[id]
	var sm := mat as ShaderMaterial
	var param: String = TINT_PARAMS.get(sm.shader.resource_path, "")
	# A white twin's surfaces already carry their colours in their vertices (merged once, then skinned).
	if param == "" or sm.has_meta(WHITE_TWIN):
		_white[id] = []
		return []
	var col = sm.get_shader_parameter(param)
	var colour: Color = col if col is Color else Color(col.x, col.y, col.z) if col is Vector3 else Color.WHITE
	# Painted parts of every finish, and walls of every pattern, share one material each: what set them apart
	# rides in the vertex alpha (shine; pattern and ground shade), so a building is a few draws, not one a finish.
	if is_coatable(sm):
		_white[id] = [coat(), Color(colour.r, colour.g, colour.b, shine_of(sm))]
		return _white[id]
	if sm.shader.resource_path == WALL_SHADER:
		_white[id] = [wall_coat(), Color(colour.r, colour.g, colour.b,
			wall_pack(int(sm.get_shader_parameter("style")), float(sm.get_shader_parameter("ground_ao"))))]
		return _white[id]
	# Twins are shared by everything with the same shader and other settings.
	var sig := sm.shader.resource_path
	for u in sm.shader.get_shader_uniform_list():
		if u["name"] != param:
			sig += "|%s=%s" % [u["name"], sm.get_shader_parameter(u["name"])]
	var key := "white:" + sig
	if not _materials.has(key):
		var w := sm.duplicate() as ShaderMaterial
		w.set_shader_parameter(param, Color.WHITE)
		w.set_meta(WHITE_TWIN, true)
		_materials[key] = w
	_white[id] = [_materials[key], colour]
	return _white[id]




## A surface's arrays with every vertex coloured `col` and indexed (no UVs or tangents: the tinting shaders
## use neither, and dropping them lets every shape share one vertex layout).
static func tint_arrays(arrays: Array, col: Color) -> Array:
	var out := arrays.duplicate()
	var n := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var colours := PackedColorArray()
	colours.resize(n)
	colours.fill(col)
	if arrays[Mesh.ARRAY_COLOR] != null:  # a mesh with its own vertex colours (a canopy): the paint tints them
		var own: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in n:
			colours[i] = own[i] * col
	out[Mesh.ARRAY_COLOR] = colours
	# Everything merged into one surface must be indexed alike: a SurfaceTool mixing indexed shapes with
	# unindexed hand-made faces drops the faces.
	if arrays[Mesh.ARRAY_INDEX] == null:
		var idx := PackedInt32Array()
		idx.resize(n)
		for k in n:
			idx[k] = k
		out[Mesh.ARRAY_INDEX] = idx
	out[Mesh.ARRAY_TEX_UV] = null
	out[Mesh.ARRAY_TANGENT] = null
	return out



## The mesh with simpler versions of itself (levels of detail) that the renderer switches to on its own when the
## mesh is drawn small on screen (zoomed out): each about half the triangles of the one before (meshoptimizer,
## through ImporterMesh). Small meshes are returned as they are: they would gain nothing.
static func with_lods(mesh: ArrayMesh) -> ArrayMesh:
	var triangles := 0
	for k in mesh.get_surface_count():
		var indices := mesh.surface_get_array_index_len(k)
		triangles += (indices if indices > 0 else mesh.surface_get_array_len(k)) / 3
	if triangles < LOD_MIN_TRIANGLES:
		return mesh
	var im := ImporterMesh.new()
	for k in mesh.get_surface_count():
		im.add_surface(mesh.surface_get_primitive_type(k), mesh.surface_get_arrays(k), [], {},
			mesh.surface_get_material(k))
	im.generate_lods(LOD_NORMAL_MERGE, LOD_NORMAL_SPLIT, [])
	var levels := 0
	for k in im.get_surface_count():
		levels = maxi(levels, im.get_surface_lod_count(k))
	var out := im.get_mesh()
	out.set_meta(LOD_LEVELS, levels)
	return out
