class_name ModelKit
extends RefCounted
## The building blocks of the farm's 3D models: boxes, prisms, cylinders, cones, spheres and roofs, each a
## mesh with its normals facing out, placed under a parent node; and the shared materials they're made of
## (made once and reused, so a farm of buildings needs a handful of materials, not hundreds).

static var _materials := {}  # key -> Material
static var _meshes := {}     # key -> Mesh (shared unit shapes)


# ---------------------------------------------------------------- materials


## A plain coloured material (matte unless `shine`).
static func paint(col: Color, shine := 0.0) -> StandardMaterial3D:
	var key := "paint:%s:%.2f" % [col.to_html(), shine]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 1.0 - shine * 0.7
		m.metallic_specular = 0.2 + shine * 0.4
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


static func water() -> StandardMaterial3D:
	if not _materials.has("water"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.32, 0.6, 0.78, 0.92)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.08
		m.metallic_specular = 1.0
		_materials["water"] = m
	return _materials["water"]


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
		sides := 16) -> MeshInstance3D:
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
	mesh.radial_segments = 14
	mesh.rings = 8
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
		var tris := [0, 1, 2] if f.size() == 3 else [0, 1, 2, 0, 2, 3]
		for i: int in tris:
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
		var col: Color = (mat as ShaderMaterial).get_shader_parameter("base_color")
		edge = paint(col.darkened(0.35))
	for s: Array in [slopes[0], slopes[slopes.size() / 2]]:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var lo := Vector3(minf(a.x, b.x), a.y - 0.05, minf(a.z, b.z)) - Vector3(0.01, 0, 0.01)
		var hi := Vector3(maxf(a.x, b.x), a.y + 0.005, maxf(a.z, b.z)) + Vector3(0.01, 0, 0.01)
		box(parent, lo, hi, edge)
