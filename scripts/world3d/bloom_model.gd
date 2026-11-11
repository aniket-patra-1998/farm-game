class_name BloomModel
extends RefCounted
## A Bloom in 3D: a Single Bloom is one tall flower on its leafy stem; a Full Bloom a bunch of them. Growing,
## the heads are closed buds; ready, open in the flower's colour round its centre; withered, the stems droop
## and everything browns. Built from the catalog's colour and accent; swaying in the wind like every plant.

const SWAY := 0.5
const STEM := Color("#4f8a34")
const DEAD := Color("#8a6d3b")
const PETALS := 6


## Builds the bloom standing on `at` in `parent`.
static func build_at(parent: Node3D, at: Vector3, it: Dictionary, size: float, ready: bool, withered: bool,
		full: bool, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var col := Color.html(str(it.get("color", "#d6304a")))
	var centre := Color.html(str(it.get("accent", "#f2c94c")))
	var stem := STEM
	if withered:
		col = col.lerp(DEAD, 0.75)
		centre = centre.lerp(DEAD, 0.6)
		stem = STEM.lerp(DEAD, 0.8)
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)
	var stems := ModelKit.scaled(5, 2) if full else 1
	for k in stems:
		var a := TAU * k / stems + rng.randf() * 0.5
		var off := Vector3(cos(a), 0, sin(a)) * (0.09 if full and k > 0 else 0.0) * size
		var h := (0.42 + rng.randf_range(-0.06, 0.06)) * size * (1.0 if k == 0 else 0.85)
		var lean := 0.9 if withered else 0.12
		var flower := Node3D.new()
		flower.position = off
		flower.rotation = Vector3(sin(a) * lean, 0, -cos(a) * lean) if (k > 0 or withered) else Vector3.ZERO
		root.add_child(flower)
		ModelKit.cylinder(flower, Vector3.ZERO, 0.012 * size, h, ModelKit.paint(stem), 0.009 * size, 6)
		for side: float in [-1.0, 1.0]:
			ModelKit.ball(flower, Vector3(side * 0.035, h * 0.35, 0) * Vector3(size, 1, size), 0.04 * size,
				ModelKit.paint(stem), Vector3(1.4, 0.3, 0.7))
		var top := Vector3(0, h, 0)
		if not ready and not withered:
			ModelKit.ball(flower, top, 0.035 * size, ModelKit.paint(col.lerp(STEM, 0.4)), Vector3(0.8, 1.3, 0.8))
			continue
		var open := 0.6 if withered else 1.0
		var petals := ModelKit.scaled(PETALS, 4)
		for pk in petals:
			var pa := TAU * pk / petals
			ModelKit.ball(flower, top + Vector3(cos(pa), 0.1, sin(pa)) * 0.045 * size * open, 0.035 * size,
				ModelKit.paint(col), Vector3(1.3, 0.45, 1.3))
		ModelKit.ball(flower, top + Vector3(0, 0.012 * size, 0), 0.024 * size, ModelKit.paint(centre))
	if not withered:
		ModelKit.sway_all(root, SWAY / maxf(size, 0.3))


## A bloom on the farm, as its own baked model.
static func build(it: Dictionary, o: Dictionary, scale := 1.0) -> Node3D:
	var holder := Node3D.new()
	var d := Game.catalog.get_def(str(it.get("id", ""))) as BloomDef
	build_at(holder, Vector3(0.5, 0, 0.5), it, 1.6 * scale, Game.is_ready(o), Game.is_withered(o),
		d != null and d.is_full(), int(o.get("uid", 0)))
	return ModelKit.bake(holder)
