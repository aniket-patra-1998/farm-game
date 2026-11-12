class_name LinkModels
extends RefCounted
## The pieces of fences, hedges, walls and paths that join up, as meshes shared by every piece of their kind:
## one mesh per (item, shape, variant), built once and cached, drawn by LinkLayer. A piece is built from a
## post at its tile's centre and an arm towards each side it joins (a short stub on a free side): the arm
## reaches the tile's edge, where the neighbour's arm begins, so rails, rows of pickets and courses of stones run
## on unbroken, and the post at a corner, an end or a junction is a different post. Paths have no arms: the
## slab runs to the edge on joined sides and keeps a worn edge on free ones.
## Built in the tile's own frame, origin at its centre, an arm pointing north (-z) before it's turned.

const VARIANTS := 3          # different hand-built looks of every shape, picked by where the piece stands
const HEIGHT := 0.32         # a fence's posts
const POST := 0.035          # half the width of a post
const WALL_TOP := 0.33

static var _cache := {}      # "item|kind|variant" -> Array of {"mesh": ArrayMesh, "shadow": bool}


## Which of the hand-built looks a piece on tile (row, col) has, so a piece and its preview agree.
static func variant_at(row: int, col: int) -> int:
	return (row * 7 + col * 13 + row * col) % VARIANTS


## The parts (one mesh and whether it casts a shadow each) of a piece, built on first use.
static func parts(it: Dictionary, kind: int, variant: int) -> Array:
	var id := str(it.get("id", ""))
	var key := "%s|%d|%d" % [id, kind, variant % VARIANTS]
	if _cache.has(key):
		return _cache[key]
	var root := Node3D.new()
	var group := Linking.group_of_shape(str(it.get("shape", "")))
	build(root, it, group, LinkShape.canon(kind), kind, variant % VARIANTS)
	var out := []
	var baked := ModelKit.bake(root)
	for c in baked.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var mesh := mi.mesh as ArrayMesh
		for s in mesh.get_surface_count():
			mesh.surface_set_material(s, mi.get_surface_override_material(s))
		out.append({"mesh": mesh, "shadow": mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF})
	baked.free()
	_cache[key] = out
	return out


## A piece as a node (for what's being placed): the shared meshes, not turned.
static func node(it: Dictionary, kind: int, variant: int) -> Node3D:
	var holder := Node3D.new()
	for p: Dictionary in parts(it, kind, variant):
		var mi := MeshInstance3D.new()
		mi.mesh = p["mesh"]
		if not p["shadow"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	return holder


## Builds one piece's parts into `root`, for the sides in `mask`.
static func build(root: Node3D, it: Dictionary, group: String, mask: int, kind: int, variant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 7919 + hash(str(it.get("id", ""))) + kind * 31
	var col := Color.html(str(it.get("color", "#a8743f")))
	var arm := Linking.setting(group, "arm", 0.5)
	var stub := Linking.setting(group, "stub", 0.3)
	if group == "path":
		_path(root, str(it.get("id", "")), col, mask, rng)
		return
	# A lone piece and a run's end stand on stubs, so they read as a short fence, not a bare post.
	var reach: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for d in 4:
		if (mask >> d) & 1 == 1:
			reach[d] = arm
	if mask == 0:
		reach[0] = stub
		reach[2] = stub
	elif kind == LinkShape.Kind.END:
		reach[2] = stub   # the free side, opposite the arm (an end is built pointing north)
	match group:
		"fence":
			_fence(root, col, str(it.get("id", "")) == "white_picket_fence", kind, reach, rng)
		"hedge":
			_hedge(root, kind, reach, rng)
		"wall":
			_wall(root, col, kind, reach, rng)


## An arm node pointing at side `d`, to build along its -z.
static func _arm(root: Node3D, d: int) -> Node3D:
	var a := Node3D.new()
	a.rotation.y = LinkShape.yaw(d)
	root.add_child(a)
	return a


static func _fence(root: Node3D, col: Color, picket: bool, kind: int, reach: Array[float],
		rng: RandomNumberGenerator) -> void:
	var mat := ModelKit.paint(col)
	var worn := ModelKit.paint(col.darkened(0.12))
	var boards := ModelKit.surface(col, "boards", 0.0)
	# The post: stouter where arms meet, with a cap that sheds the rain.
	var half := POST * (1.25 if kind >= LinkShape.Kind.TEE else 1.0)
	var h := HEIGHT + rng.randf_range(-0.01, 0.02) + (0.025 if kind >= LinkShape.Kind.TEE else 0.0)
	ModelKit.box(root, Vector3(-half, 0, -half), Vector3(half, h, half), worn if not picket else mat)
	ModelKit.cylinder(root, Vector3(0, h, 0), half * 1.45, 0.035, mat, 0.012, 4)
	for d in 4:
		var len := reach[d]
		if len <= 0.0:
			continue
		var a := _arm(root, d)
		if picket:
			for y: float in [0.09, 0.2]:
				ModelKit.box(a, Vector3(-0.025, y, -len), Vector3(0.025, y + 0.03, -half), mat)
			var z := 0.07
			while z < len - 0.02:
				var ph := 0.28 + rng.randf_range(-0.025, 0.02)
				ModelKit.box(a, Vector3(-0.015, 0, -z - 0.02), Vector3(0.015, ph, -z + 0.02), mat)
				ModelKit.cylinder(a, Vector3(0, ph, -z), 0.02, 0.04, mat, 0.0, 4)
				z += 0.125
		else:
			for y: float in [0.1, 0.24]:
				var yy := y + rng.randf_range(-0.004, 0.004)
				ModelKit.box(a, Vector3(-0.02, yy, -len), Vector3(0.02, yy + 0.045, -half), boards)


static func _hedge(root: Node3D, kind: int, reach: Array[float], rng: RandomNumberGenerator) -> void:
	var leaf := DecorModel.LEAF
	var bump := 1.25 if kind >= LinkShape.Kind.TEE else 1.0
	ModelKit.ball(root, Vector3(0, 0.17, 0), 0.2 * bump, ModelKit.paint(leaf.darkened(rng.randf() * 0.15)),
		Vector3(1.15, 0.95, 1.15))
	ModelKit.ball(root, Vector3(0, 0.3, 0), 0.15 * bump, ModelKit.paint(leaf.lightened(0.08)), Vector3(1.15, 0.55, 1.15))
	for d in 4:
		if reach[d] <= 0.0:
			continue
		var a := _arm(root, d)
		var z := 0.2
		while z < reach[d] + 0.01:
			var shade := leaf.darkened(rng.randf() * 0.15)
			ModelKit.ball(a, Vector3(rng.randf_range(-0.02, 0.02), 0.17, -z), 0.2, ModelKit.paint(shade),
				Vector3(1.15, 0.95, 1.05))
			ModelKit.ball(a, Vector3(0, 0.3 + rng.randf_range(-0.01, 0.02), -z), 0.15,
				ModelKit.paint(shade.lightened(0.08)), Vector3(1.15, 0.55, 1.1))
			z += 0.2
		for k in 2:
			ModelKit.ball(a, Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(0.18, 0.34),
				-0.08 - k * 0.16 - rng.randf_range(0.0, 0.06)), 0.03,
				ModelKit.paint(Color("#e8d86a") if k % 2 else Color("#d8506a")))


static func _wall(root: Node3D, col: Color, kind: int, reach: Array[float], rng: RandomNumberGenerator) -> void:
	var stone := col
	# The centre: a pillar of heavier stones where the walls meet.
	ModelKit.box(root, Vector3(-0.11, 0, -0.11), Vector3(0.11, WALL_TOP, 0.11), ModelKit.paint(stone.darkened(0.15)))
	ModelKit.box(root, Vector3(-0.13, WALL_TOP, -0.13), Vector3(0.13, WALL_TOP + 0.035, 0.13),
		ModelKit.paint(stone.lightened(0.1)))
	for d in 4:
		var len := reach[d]
		if len <= 0.0:
			continue
		var a := _arm(root, d)
		ModelKit.box(a, Vector3(-0.1, 0, -len), Vector3(0.1, 0.04, -0.1), ModelKit.paint(stone.darkened(0.4)), false)
		for row in 3:
			var n := maxi(1, roundi((len - 0.1) / 0.1 * (0.9 if row % 2 else 1.0)))
			for k in n:
				var z := 0.1 + (len - 0.1) * (k + 0.5) / n
				var size := rng.randf_range(0.085, 0.115) * (1.0 - row * 0.06)
				var st := ModelKit.facet_ball(a, Vector3(rng.randf_range(-0.012, 0.012), 0.07 + row * 0.095, -z), size,
					ModelKit.paint(stone.darkened(rng.randf() * 0.28)), Vector3(1.05, 0.72, 1.35))
				st.rotation.y = rng.randf_range(-0.2, 0.2)
		ModelKit.box(a, Vector3(-0.07, 0.3, -len), Vector3(0.07, 0.335, -0.12),
			ModelKit.paint(stone.lightened(0.08).darkened(rng.randf() * 0.12)))


## A path tile: the slab runs to the tile's edge on the sides it joins (no seam of grass between tiles) and
## keeps a worn edge on the free ones; the surface (earth, bricks, stones) is the same across the whole tile.
static func _path(root: Node3D, id: String, col: Color, mask: int, rng: RandomNumberGenerator) -> void:
	var tile := Node3D.new()
	tile.position = Vector3(-0.5, 0, -0.5)
	root.add_child(tile)
	var lo := Vector3(0.0 if mask & LinkShape.W else 0.02, 0, 0.0 if mask & LinkShape.N else 0.02)
	var hi := Vector3(1.0 if mask & LinkShape.E else 0.98, 0, 1.0 if mask & LinkShape.S else 0.98)
	match id:
		"dirt_path":
			ModelKit.box(tile, lo, hi + Vector3(0, 0.012, 0), ModelKit.surface(col.darkened(0.12), "plaster", 0.0), false)
			for i in 2:
				var worn := ModelKit.cylinder(tile, Vector3(rng.randf_range(0.3, 0.7), 0.012, rng.randf_range(0.3, 0.7)),
					rng.randf_range(0.22, 0.34), 0.006, ModelKit.paint(col.lerp(Color("#e2bd86"), rng.randf_range(0.2, 0.4))),
					-1.0, 9)
				worn.scale = Vector3(rng.randf_range(1.1, 1.5), 1.0, 1.0)
				worn.rotation.y = rng.randf() * PI
			for i in rng.randi_range(3, 6):
				ModelKit.facet_ball(tile, Vector3(rng.randf_range(0.08, 0.92), 0.012, rng.randf_range(0.08, 0.92)),
					rng.randf_range(0.015, 0.035), ModelKit.paint(Color("#9a948a").darkened(rng.randf() * 0.2)),
					Vector3(1.2, 0.6, 1.0))
		"brick_path":
			ModelKit.box(tile, lo, hi + Vector3(0, 0.008, 0), ModelKit.paint(col.darkened(0.35)), false)
			for i in 4:
				for j in 4:
					var shade := ModelKit.paint(col.lightened(0.05).darkened(rng.randi_range(0, 2) * 0.1))
					var at := Vector3(0.03 + i * 0.235, 0.0, 0.03 + j * 0.235)
					ModelKit.box(tile, at, at + Vector3(0.21, 0.016, 0.21), shade, false)
		_:
			for i in 3:
				for j in 3:
					var p := Vector3(0.18 + 0.32 * i + rng.randf_range(-0.05, 0.05), 0.008,
						0.18 + 0.32 * j + rng.randf_range(-0.05, 0.05))
					var r := rng.randf_range(0.11, 0.16)
					var stone := ModelKit.cylinder(tile, p - Vector3(0, 0.008, 0), r, 0.03,
						ModelKit.paint(col.lightened(0.1).darkened(rng.randf() * 0.25)), r * 0.82, 7)
					stone.scale = Vector3(1.0, 1.0, rng.randf_range(0.8, 1.2))
					stone.rotation.y = rng.randf() * PI
