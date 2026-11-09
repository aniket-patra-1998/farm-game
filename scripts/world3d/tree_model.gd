class_name TreeModel
extends RefCounted
## A fruit tree in 3D: a tapering trunk with a fork, a canopy of overlapping leafy clumps (lighter on top,
## where the sun catches it), and fruit hung around the canopy: a few small green ones while it grows,
## full-coloured once it's ready to harvest. Each tree is shaped a little differently (seeded by `seed`).

const BARK := Color("#7a4f2c")
const LEAF := Color("#4f9a3a")
const LEAF_TOP := Color("#7cc04e")


## A tree standing on `base` under `parent`; `size` 1 is a full tree on its own tile.
static func build_at(parent: Node3D, base: Vector3, it: Dictionary, size := 1.0, ready := false,
		seed_value := 0, fruit := true, leaf := LEAF) -> Node3D:
	var root := Node3D.new()
	root.position = base
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + hash(str(it.get("id", "")))
	var k := size
	var trunk_h := 0.42 * k
	ModelKit.cylinder(root, Vector3.ZERO, 0.06 * k, trunk_h, ModelKit.surface(BARK, "logs", 0.3), 0.04 * k, 8)
	var fork := ModelKit.cylinder(
		root,
		Vector3(0, trunk_h * 0.6, 0),
		0.03 * k,
		0.22 * k,
		ModelKit.paint(BARK),
		0.015 * k,
		6
	)
	fork.rotation.z = -0.6
	fork.position += Vector3(0.05 * k, 0, 0)
	var crown := Vector3(0, trunk_h + 0.22 * k, 0)
	var clumps: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.4
		clumps.append(crown + Vector3(cos(a) * 0.2 * k, rng.randf_range(-0.06, 0.08) * k, sin(a) * 0.2 * k))
	clumps.append(crown + Vector3(0, 0.15 * k, 0))
	for i in clumps.size():
		var col := leaf.lerp(leaf.lightened(0.3), clampf((clumps[i].y - crown.y) / (0.15 * k) * 0.5 + 0.4, 0.0, 1.0))
		col = col.darkened(rng.randf_range(0.0, 0.08))
		ModelKit.ball(root, clumps[i], rng.randf_range(0.17, 0.22) * k, ModelKit.paint(col), Vector3(1, 0.85, 1))
	var fruit_col := Color.html(str(it.get("color", "#d93b30")))
	var count := (8 if ready else 3) if fruit else 0
	for i in count:
		var a := TAU * i / count + rng.randf() * 0.5
		var p := crown + Vector3(cos(a) * 0.3 * k, rng.randf_range(-0.1, 0.12) * k, sin(a) * 0.3 * k)
		var col := fruit_col if ready else fruit_col.lerp(LEAF, 0.6)
		ModelKit.ball(root, p, (0.045 if ready else 0.03) * k, ModelKit.paint(col, 0.4))
	return root
