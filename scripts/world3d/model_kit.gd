class_name ModelKit
extends RefCounted
## The building blocks of the farm's 3D models: boxes, prisms, cylinders, cones, spheres and roofs, each a
## mesh with its normals facing out, placed under a parent node; and the shared materials they're made of
## (made once and reused, so a farm of buildings needs a handful of materials, not hundreds).

const KEEP := &"keep_unbaked"  # meta on a part that moves on its own: bake leaves it whole

## Tessellation: enough to read round at farm zoom on a phone, no more (each ball is ~170 triangles,
## each cylinder ~48, before the shadow pass draws them again).
const BALL_SEGMENTS := 12
const BALL_RINGS := 7

const CYLINDER_SIDES := 12


## Shaders that tint by vertex colour, and the colour parameter each one's materials set.
const TINT_PARAMS := {"res://shaders/paint3d.gdshader": "albedo", "res://shaders/wall3d.gdshader": "base_color"}

const WHITE_TWIN := &"white_twin"  # meta on a white twin



static var _materials := {}  # key -> Material

static var _meshes := {}     # key -> Mesh (shared unit shapes)


static var _white := {}   # material id -> [white twin, colour]


# ---------------------------------------------------------------- materials


## A plain coloured material (matte unless `shine`), darkening where it meets the ground (paint3d).
static func paint(col: Color, shine := 0.0) -> ShaderMaterial:
	var key := "paint:%s:%.2f" % [col.to_html(), shine]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/paint3d.gdshader")
		m.set_shader_parameter("albedo", col)
		m.set_shader_parameter("roughness", 1.0 - shine * 0.6)
		m.set_shader_parameter("specular", 0.1 + shine * 0.4)
		_materials[key] = m
	return _materials[key]


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
	glass().emission_energy_multiplier = glow * 2.2


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




## An upright cylinder (or a cone, with `top_r` 0) standing on `base`.
static func cylinder(parent: Node3D, base: Vector3, r: float, h: float, mat: Material, top_r := -1.0,
		sides := CYLINDER_SIDES) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r
	mesh.top_radius = r if top_r < 0.0 else top_r
	mesh.height = h
	mesh.radial_segments = sides
	mesh.rings = 1
	mi.mesh = mesh
	mi.position = base + Vector3(0, h / 2.0, 0)
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A sphere (or a squashed one, with `scale`).
static func ball(parent: Node3D, centre: Vector3, r: float, mat: Material, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = BALL_SEGMENTS
	mesh.rings = BALL_RINGS
	mi.mesh = mesh
	mi.position = centre
	mi.scale = scale
	mi.material_override = mat
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
		# What hangs on it is baked too: a door is one or two draws, not a dozen boxes.
		for part in n.get_children():
			if part is Node3D:
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
