class_name DecorMotion
extends RefCounted
## Things on the farm that move by themselves (a fountain's water, a fire's flames and embers), built so the
## GPU moves them: each is one mesh whose vertex shader animates it from the time, so motion costs no script,
## no extra nodes per drop and one draw per effect (shaders/spray3d, flame3d, water3d). Moving parts are kept
## out of the bake (ModelKit.KEEP) and cast no shadow.
##
## Effects are described by data (`spray` takes the shader's settings), so decorations and buildings share
## them: a jet, a cascade off a rim, embers rising, a flame.

const DROP_RADIUS := 0.02           # a drop at full size (the shader scales it)
const PUFF_SIDES := 8               # a smoke puff's roundness
const PUFF_RINGS := 4
const SPRAY_SHADER := "res://shaders/spray3d.gdshader"
const FLAME_SHADER := "res://shaders/flame3d.gdshader"
const WATER_SHADER := "res://shaders/water3d.gdshader"
const ORBIT_SHADER := "res://shaders/orbit3d.gdshader"

## A bird circling its house, fluttering. A duck paddling round a pond. A bucket bobbing in a well. A
## weathervane swinging with the wind.
const CIRCLING := {"speed": 1.6, "radius": 0.3, "bob": 0.035, "bob_rate": 1.4}
const PADDLING := {"speed": 0.35, "radius": 0.22, "bob": 0.006, "bob_rate": 0.6}
const BOBBING := {"speed": 0.0, "bob": 0.025, "bob_rate": 0.25}
const VANE := {"speed": 0.45, "swing": 0.7}
## A pennant streaming from its pole: swings quickly and a little, harder in wind.
const FLUTTER := {"speed": 2.4, "swing": 0.28}

## A fountain's jet: arcs of water up from the spout and falling back round it (streams of drops one
## behind another along the same arc read as running water, not specks).
const JET := {"streams": 8, "per_stream": 9, "life": 0.9, "rise": 1.5, "gravity": 3.4, "reach": 0.17,
	"size": 1.35}
## Water spilling over a basin's rim into the one below, in short falling ribbons.
const CASCADE := {"streams": 18, "per_stream": 4, "life": 0.62, "rise": 0.05, "gravity": 2.6,
	"reach": 0.07, "size": 1.1}
## Embers floating up from a fire, glowing (one each: they drift alone).
const EMBERS := {"streams": 10, "per_stream": 1, "life": 1.8, "rise": 0.25, "gravity": -0.05,
	"reach": 0.08, "size": 0.45, "colour": Color("#ffb347"), "glow": 3.0}

## Smoke curling up from a chimney: soft grey puffs drifting up and spreading as they rise.
const SMOKE := {"streams": 7, "per_stream": 1, "life": 3.2, "rise": 0.22, "gravity": -0.02, "reach": 0.18,
	"size": 2.2, "end_size": 2.6, "colour": Color("#d9d6d0"), "sheen": 0.15, "round": true}

static var _materials := {}         # settings -> ShaderMaterial (shared by every effect alike)


## Streams of drops thrown from `at` (in the parent's space) as `settings` say (JET, CASCADE, EMBERS or the
## like: `streams` headings round the circle, `per_stream` drops along each; `start_radius` makes them leave
## from a ring). One mesh, one draw.
static func spray(parent: Node3D, at: Vector3, settings: Dictionary) -> MeshInstance3D:
	var streams := int(settings.get("streams", 8))
	var per := int(settings.get("per_stream", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([at, streams, per])
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for k in streams:
		# Each stream on its own heading round the circle and its own offset in time; its drops follow
		# one another along it, evenly spaced, so the stream is never empty or bunched.
		var angle := (k + rng.randf_range(-0.2, 0.2)) / streams
		var offset := rng.randf()
		var reach := rng.randf_range(0.7, 1.0)
		for j in per:
			var data := Vector2(fposmod(offset + float(j) / per, 1.0), angle)
			if settings.get("round", false):
				_puff(verts, normals, uv, uv2, data, Vector2(reach, rng.randf()))
			else:
				_drop(verts, normals, uv, uv2, data, Vector2(reach, rng.randf()))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(SPRAY_SHADER, settings)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The drops fly well outside the mesh as built: tell culling where they can reach.
	var span := float(settings.get("start_radius", 0.0)) + float(settings.get("reach", 0.3)) + 0.05
	var rise := float(settings.get("rise", 1.0))
	var life := float(settings.get("life", 1.0))
	var g := float(settings.get("gravity", 3.0))
	var top := maxf(rise * rise / maxf(2.0 * g, 0.01) if g > 0.0 else rise * life - 0.5 * g * life * life, 0.05)
	var bottom := minf(rise * life - 0.5 * g * life * life, 0.0)
	mi.custom_aabb = AABB(Vector3(-span, bottom - 0.05, -span), Vector3(span * 2.0, top - bottom + 0.1, span * 2.0))
	mi.position = at
	mi.set_meta(ModelKit.KEEP, true)
	parent.add_child(mi)
	return mi


## A flame standing on `at`: a tongue `r` wide and `h` tall that flickers and licks upward.
static func flame(parent: Node3D, at: Vector3, r: float, h: float, col: Color, tip: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r
	mesh.top_radius = r * 0.15
	mesh.height = h
	mesh.radial_segments = 8
	mesh.rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(FLAME_SHADER, {"colour": col, "tip": tip, "height": h})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The cylinder is centred on its middle; the shader measures height from the foot.
	mi.position = at + Vector3(0, h / 2.0, 0)
	mi.extra_cull_margin = h * 0.3
	mi.set_meta(ModelKit.KEEP, true)
	parent.add_child(mi)
	return mi


## Moves `part` (built facing -z at its origin) as `settings` say: round a circle, bobbing, or swinging
## (CIRCLING, PADDLING, BOBBING, VANE; "phase" sets it apart from another like it). Baked to a draw per
## material and moved by orbit3d; returns the part's node, placed at `at` in the parent.
static func orbit(parent: Node3D, at: Vector3, part: Node3D, settings: Dictionary) -> Node3D:
	var baked := ModelKit.bake(part)
	# (bake frees `part`)
	var mat := _material(ORBIT_SHADER, settings)
	var reach := float(settings.get("radius", 0.0)) + 0.25
	for c in baked.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			mi.material_override = mat  # its colours are in its vertices
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.custom_aabb = AABB(Vector3(-reach, -0.1, -reach), Vector3(reach * 2.0, 0.5, reach * 2.0))
	baked.position = at
	baked.set_meta(ModelKit.KEEP, true)
	parent.add_child(baked)
	return baked


## A little bird facing -z: body, head, beak and tail.
static func bird(col: Color) -> Node3D:
	var b := Node3D.new()
	ModelKit.ball(b, Vector3.ZERO, 0.035, ModelKit.paint(col), Vector3(0.8, 0.8, 1.2))
	ModelKit.ball(b, Vector3(0, 0.03, -0.04), 0.022, ModelKit.paint(col.lightened(0.1)))
	ModelKit.ball(b, Vector3(0, 0.028, -0.065), 0.008, ModelKit.paint(Color("#e8a23a")), Vector3(0.8, 0.6, 1.6))
	ModelKit.ball(b, Vector3(0, 0.01, 0.045), 0.018, ModelKit.paint(col.darkened(0.2)), Vector3(0.6, 0.3, 1.2))
	return b


## A duck facing -z, sitting on the water: body, head and bill.
static func duck(col: Color) -> Node3D:
	var d := Node3D.new()
	ModelKit.ball(d, Vector3(0, 0.025, 0), 0.05, ModelKit.paint(col), Vector3(0.75, 0.6, 1.1))
	ModelKit.ball(d, Vector3(0, 0.075, -0.045), 0.026, ModelKit.paint(col.darkened(0.05)))
	ModelKit.ball(d, Vector3(0, 0.07, -0.072), 0.011, ModelKit.paint(Color("#f0a030")), Vector3(1.1, 0.5, 1.4))
	return d


## The shared rippling water (one material for every pond, trough, well and basin).
static func water() -> ShaderMaterial:
	return _material(WATER_SHADER, {})


## One small drop (an octahedron: 8 triangles) at the origin, carrying its data in both UV channels.
static func _drop(verts: PackedVector3Array, normals: PackedVector3Array, uv: PackedVector2Array,
		uv2: PackedVector2Array, data: Vector2, data2: Vector2) -> void:
	var r := DROP_RADIUS
	var tips := [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(0, 0, -r)]
	for k in 4:
		var a: Vector3 = tips[k]
		var b: Vector3 = tips[(k + 1) % 4]
		for pole: Vector3 in [Vector3(0, r * 1.3, 0), Vector3(0, -r * 1.3, 0)]:
			# Clockwise seen from outside (Godot's front faces: the cross product points inward).
			var tri := [pole, a, b] if pole.y > 0.0 else [pole, b, a]
			for v: Vector3 in tri:
				verts.append(v)
				normals.append(v.normalized())
				uv.append(data)
				uv2.append(data2)


## A round puff (a low sphere: PUFF_SIDES around, PUFF_RINGS up) at the origin, for smoke.
static func _puff(verts: PackedVector3Array, normals: PackedVector3Array, uv: PackedVector2Array,
		uv2: PackedVector2Array, data: Vector2, data2: Vector2) -> void:
	var r := DROP_RADIUS
	for i in PUFF_RINGS:
		var t0 := PI * i / PUFF_RINGS
		var t1 := PI * (i + 1) / PUFF_RINGS
		for j in PUFF_SIDES:
			var p0 := TAU * j / PUFF_SIDES
			var p1 := TAU * (j + 1) / PUFF_SIDES
			var a := _on_sphere(t0, p0)
			var b := _on_sphere(t0, p1)
			var c := _on_sphere(t1, p0)
			var d := _on_sphere(t1, p1)
			# Two triangles per patch, clockwise seen from outside.
			for v: Vector3 in [a, c, b, b, c, d]:
				verts.append(v * r)
				normals.append(v)
				uv.append(data)
				uv2.append(data2)


static func _on_sphere(theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))


static func _material(shader_path: String, settings: Dictionary) -> ShaderMaterial:
	var key := shader_path + str(settings)
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(shader_path)
		for k in settings:
			if not k in ["streams", "per_stream", "round"]:
				m.set_shader_parameter(k, settings[k])
		_materials[key] = m
	return _materials[key]
