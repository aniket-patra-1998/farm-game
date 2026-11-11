class_name TreeModel
extends RefCounted
## A tree in 3D, grown to its kind's shape (data/tree_shapes.json): an apple's round dome, a lemon's tight
## glossy ball on a short trunk, a cherry's tall oval in blossom, an olive's wide silvery crown on a thick
## trunk, a willow's hanging strands, a palm's ringed trunk and fronds, a banana's paddle leaves, a
## pomegranate's many stems. Fruit hangs in its own way too: round, oval, in long bunches, huge on the
## trunk, or as many small nuts. While a tree grows its fruit is small and green; ready, it's full-coloured.
##
## No two trees are the same: each is varied by its own seed (height, lean, where its clumps sit, their
## shade), so an orchard of one kind still reads as trees and not copies.

const SWAY := 0.035                # how far a tree bends in the wind (paint3d sway, by height)
const PATH := "res://data/tree_shapes.json"
const BARK := Color("#7a4f2c")
const LEAF := Color("#4f9a3a")
const LEAF_TOP := Color("#7cc04e")
const UNSET := Color(0, 0, 0, 0)
const FRUIT_READY := 12     # fruit on a ready tree (fewer, small and green, while it grows)
const FRUIT_R := 0.052      # a round fruit's radius (a small one's: FRUIT_SMALL_R), for a full-size tree
const FRUIT_SMALL_R := 0.02
const FRUIT_OUT := 0.92     # how far out through a leafy clump fruit hangs (1: on its surface)
const FRUIT_GROWING := 3
const TILE_FILL := 1.65     # a tree at `size` 1 fills about four fifths of a tile (FarmVille's trees were full, not dainty)

static var _data := {}


## The shape for a tree: its form's sizes with its family's own laid over them.
static func shape_of(it: Dictionary) -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"forms": {}, "families": {}}
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error(PATH + " is missing or not valid JSON")
	var families: Dictionary = _data.get("families", {})
	var own: Dictionary = families.get(str(it.get("family", "")), families.get(str(it.get("id", "")), {}))
	var form := str(own.get("form", "round"))
	var out: Dictionary = ((_data.get("forms", {}) as Dictionary).get(form, {}) as Dictionary).duplicate()
	out.merge(own, true)
	out["form"] = form
	return out


## Every form the data describes (tests build each one).
static func forms() -> Array:
	shape_of({})
	return (_data.get("forms", {}) as Dictionary).keys()


## A tree standing on `base` under `parent`; `size` 1 is a full tree on its own tile (crown nearly as wide as it). `leaf` overrides the
## kind's leaf colour when given.
static func build_at(parent: Node3D, base: Vector3, it: Dictionary, size := 1.0, ready := false,
		seed_value := 0, fruit := true, leaf := UNSET) -> Node3D:
	var root := Node3D.new()
	root.position = base
	parent.add_child(root)
	var sh := shape_of(it)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + hash(str(it.get("id", "")))
	# This tree's own variation: a little taller or shorter, leaning a little, turned its own way.
	var k := size * TILE_FILL * rng.randf_range(0.9, 1.1)
	root.rotation.y = rng.randf() * TAU
	var leaf_col := leaf if leaf.a > 0.0 else Color.html(str(sh.get("leaf", LEAF.to_html())))
	leaf_col = Color.from_hsv(leaf_col.h + rng.randf_range(-0.015, 0.015), leaf_col.s * rng.randf_range(0.92, 1.05),
		leaf_col.v * rng.randf_range(0.94, 1.04))
	var t := {"root": root, "rng": rng, "k": k, "sh": sh, "leaf": leaf_col, "shine": float(sh.get("shine", 0.0)),
		"lean": Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))}
	var crown: Vector3
	match str(sh["form"]):
		"palm":
			crown = _palm(t)
		"banana":
			crown = _banana(t)
		"bushy":
			crown = _stems(t)
			_crown(t, crown)
		"weeping":
			crown = _trunk(t)
			_crown(t, crown)
			_strands(t, crown)
		_:
			crown = _trunk(t)
			_crown(t, crown)
	if sh.has("blossom"):
		_blossom(t, crown, Color.html(str(sh["blossom"])))
	if fruit:
		_fruit(t, crown, Color.html(str(it.get("color", "#d93b30"))), ready)
	ModelKit.sway_all(root, SWAY)
	return root


# ---------------------------------------------------------------- trunks


## A tapering trunk, leaning a little, with a limb forking off; returns where the crown sits.
static func _trunk(t: Dictionary) -> Vector3:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var h := float(sh["trunk_h"]) * k
	var r := float(sh["trunk_r"]) * k
	var lean: Vector3 = t["lean"]
	var trunk := ModelKit.cylinder(root, Vector3.ZERO, r, h, ModelKit.surface(BARK, "logs", 0.3), r * 0.65, 8)
	trunk.rotation = Vector3(lean.z, 0, -lean.x)
	var top := Vector3(lean.x * h, h, lean.z * h)
	# Limbs into the crown: one for a small tree, three spreading ones for a wide one.
	var limbs := 3 if str(sh["form"]) == "spreading" else 1
	var rng: RandomNumberGenerator = t["rng"]
	for i in limbs:
		var a := TAU * i / limbs + rng.randf() * 0.8
		var limb := ModelKit.cylinder(root, Vector3.ZERO, r * 0.5, h * 0.55, ModelKit.paint(BARK), r * 0.25, 6)
		limb.position = top * 0.7 + Vector3(cos(a), 0, sin(a)) * r * 0.5 + Vector3(0, h * 0.2, 0)
		limb.rotation = Vector3(sin(a) * 0.7, 0, -cos(a) * 0.7)
	return top + Vector3(0, float(sh["crown_h"]) * k * 0.6, 0)


## Several thin stems from the ground (a shrubby tree); returns the crown's centre.
static func _stems(t: Dictionary) -> Vector3:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var h := float(sh["trunk_h"]) * k
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf() * 0.5
		var stem := ModelKit.cylinder(root, Vector3.ZERO, float(sh["trunk_r"]) * k, h * 1.6, ModelKit.paint(BARK),
			float(sh["trunk_r"]) * k * 0.6, 5)
		stem.position = Vector3(cos(a) * 0.04 * k, h * 0.8, sin(a) * 0.04 * k)
		stem.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35)
	return Vector3(0, h + float(sh["crown_h"]) * k * 0.5, 0)


# ---------------------------------------------------------------- crowns


## The leafy crown: clumps over an ellipsoid of the form's width and height, lighter where the sun
## catches the top, darker underneath, with a filler clump in the middle so it never looks hollow.
static func _crown(t: Dictionary, centre: Vector3) -> void:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var leaf: Color = t["leaf"]
	var shine: float = t["shine"]
	var cr := float(sh["crown_r"]) * k
	var ch := maxf(float(sh["crown_h"]) * k, cr * 0.5)
	var n := int(sh["clumps"])
	var clump_r := cr * (0.62 if str(sh["form"]) == "dense" else 0.75)
	ModelKit.ball(root, centre, 1.0, ModelKit.paint(leaf.darkened(0.12), shine), Vector3(cr * 0.85, ch * 0.75, cr * 0.85))
	for i in n:
		# Spread round the crown in a spiral, from low to high.
		var u := (i + 0.5) / n
		var a := i * 2.399963 + rng.randf() * 0.3
		var y := lerpf(-0.45, 0.55, u)
		var ring := sqrt(maxf(1.0 - y * y, 0.15))
		var p := centre + Vector3(cos(a) * cr * 0.62 * ring, y * ch * 0.8, sin(a) * cr * 0.62 * ring)
		var light := clampf(0.5 + y * 0.6, 0.0, 1.0)
		var col := leaf.darkened(0.14).lerp(leaf.lightened(0.2), light).darkened(rng.randf_range(0.0, 0.07))
		var s := rng.randf_range(0.78, 1.0) * clump_r
		ModelKit.ball(root, p, s, ModelKit.paint(col, shine), Vector3(1, rng.randf_range(0.78, 0.92), 1))


## A willow's curtain: strands of leaves hanging from the crown's rim nearly to the ground.
static func _strands(t: Dictionary, centre: Vector3) -> void:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var leaf: Color = t["leaf"]
	var cr := float(sh["crown_r"]) * k
	for i in 16:
		var a := TAU * i / 16.0 + rng.randf() * 0.2
		var top := centre + Vector3(cos(a) * cr * 0.85, 0.02 * k, sin(a) * cr * 0.85)
		var length := top.y * rng.randf_range(0.55, 0.8)
		ModelKit.box(root, top + Vector3(-0.025, -length, -0.012) * Vector3(k, 1, k),
			top + Vector3(0.025, 0, 0.012) * Vector3(k, 1, k), ModelKit.paint(leaf.lerp(LEAF_TOP, rng.randf() * 0.3)), false)


## A palm: a tall trunk curving up in rings, and fronds drooping from the top in a star.
static func _palm(t: Dictionary) -> Vector3:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var leaf: Color = t["leaf"]
	var h := float(sh["trunk_h"]) * k
	var r := float(sh["trunk_r"]) * k
	var bend := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	var rings := 9
	var top := Vector3.ZERO
	for i in rings:
		var u := float(i) / rings
		var at := bend * (u * u) * h * 2.0 + Vector3(0, u * h, 0)
		ModelKit.cylinder(root, at, r * lerpf(1.0, 0.75, u), h / rings * 1.02,
			ModelKit.paint(BARK.lightened(0.12 if i % 2 == 0 else 0.0)), r * lerpf(0.95, 0.72, u), 8)
		top = at + Vector3(0, h / rings, 0)
	var fronds := int(sh["clumps"])
	var reach := float(sh["crown_r"]) * k
	for i in fronds:
		var a := TAU * i / fronds + rng.randf() * 0.25
		_frond(root, top, Vector3(cos(a), 0, sin(a)), reach * rng.randf_range(0.85, 1.1), leaf, rng)
	return top


## A frond: a spine arching out and down, with a leaf blade along it in a few bent segments.
static func _frond(root: Node3D, from: Vector3, dir: Vector3, reach: float, leaf: Color,
		rng: RandomNumberGenerator) -> void:
	var mat := ModelKit.paint(leaf.darkened(rng.randf_range(0.0, 0.12)))
	var side := Vector3(-dir.z, 0, dir.x)
	var prev := from
	var segments := 4
	for s in segments:
		var u := (s + 1.0) / segments
		var p := from + dir * reach * u + Vector3(0, 0.12 * reach * sin(u * PI * 0.9) - 0.35 * reach * u * u, 0)
		var w := 0.09 * reach * (1.0 - u * 0.7)
		var mid := (prev + p) / 2.0
		var length := prev.distance_to(p)
		var blade := ModelKit.box(root, Vector3(-length / 2.0, -0.004, -w), Vector3(length / 2.0, 0.004, w), mat, false)
		# The blade lies along the spine (x), flat across it (z), facing up (y).
		var along := (p - prev).normalized()
		var up := side.cross(along).normalized()
		blade.transform = Transform3D(Basis(along, up, along.cross(up)), mid)
		prev = p


## A banana: a soft green stem, and a fan of huge paddle leaves arching out of its top.
static func _banana(t: Dictionary) -> Vector3:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var leaf: Color = t["leaf"]
	var h := float(sh["trunk_h"]) * k
	ModelKit.cylinder(root, Vector3.ZERO, float(sh["trunk_r"]) * k, h, ModelKit.paint(Color("#8aa548")),
		float(sh["trunk_r"]) * k * 0.75, 8)
	var top := Vector3(0, h, 0)
	var n := int(sh["clumps"])
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		var length := float(sh["crown_r"]) * k * rng.randf_range(0.8, 1.1)
		var paddle := ModelKit.ball(root, Vector3.ZERO, 1.0, ModelKit.paint(leaf.darkened(rng.randf_range(0.0, 0.1))),
			Vector3(length * 0.55, 0.012, length * 0.16))
		paddle.position = top + dir * length * 0.5 + Vector3(0, 0.1 * k, 0)
		paddle.rotation = Vector3(0, -a, -0.5 + rng.randf_range(-0.2, 0.25))
	return top + Vector3(0, 0.05 * k, 0)


# ---------------------------------------------------------------- blossom and fruit


## Blossom through the crown: little five-petal flowers on the outside of the clumps.
static func _blossom(t: Dictionary, centre: Vector3, col: Color) -> void:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var cr := float(sh["crown_r"]) * k
	var ch := maxf(float(sh["crown_h"]) * k, cr * 0.5)
	for i in 14:
		var a := rng.randf() * TAU
		var y := rng.randf_range(-0.2, 0.9)
		var p := centre + Vector3(cos(a) * cr * 0.95 * sqrt(1.0 - y * y * 0.6), y * ch * 0.85,
			sin(a) * cr * 0.95 * sqrt(1.0 - y * y * 0.6))
		ModelKit.ball(root, p, 0.022 * k, ModelKit.paint(col.lightened(rng.randf_range(0.0, 0.15))), Vector3(1, 0.6, 1))


## Fruit, hung the kind's way. Small and green while the tree grows, its full colour once it's ready.
static func _fruit(t: Dictionary, centre: Vector3, col: Color, ready: bool) -> void:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var shape := str(sh.get("fruit_shape", "round"))
	var size := float(sh.get("fruit_size", 1.0)) * (1.0 if ready else 0.65)
	var c := col if ready else col.lerp(LEAF, 0.6)
	var mat := ModelKit.paint(c, 0.4)
	var cr := float(sh["crown_r"]) * k
	var count := FRUIT_READY if ready else FRUIT_GROWING
	match shape:
		"long", "cluster":
			# Hanging bunches under the crown: bananas point up in hands, dates hang in strings.
			for b in (1 if shape == "long" else 3):
				var a := TAU * b / 3.0 + rng.randf()
				var at := centre + Vector3(cos(a) * cr * 0.3, -0.08 * k, sin(a) * cr * 0.3)
				ModelKit.box(root, at + Vector3(-0.006, -0.05, -0.006) * k, at + Vector3(0.006, 0.02, 0.006) * k,
					ModelKit.paint(Color("#6a5a2a")))
				for i in (8 if shape == "long" else 6):
					var ring := TAU * i / 6.0
					var p := at + Vector3(cos(ring) * 0.035, -0.06 - 0.025 * int(i / 3.0), sin(ring) * 0.035) * k * size
					if shape == "long":
						ModelKit.ball(root, p, 0.018 * k * size, mat, Vector3(1, 3.0, 1))
					else:
						ModelKit.ball(root, p, 0.016 * k * size, mat)
		"big":
			# Huge fruit growing straight off the trunk and the lowest limbs.
			for i in (4 if ready else 2):
				var a := TAU * i / 4.0 + rng.randf() * 0.4
				var p := Vector3(cos(a) * 0.09 * k, centre.y * rng.randf_range(0.35, 0.7), sin(a) * 0.09 * k)
				ModelKit.ball(root, p, 0.06 * k * size, mat, Vector3(0.85, 1.25, 0.85))
		_:
			var n := count * (3 if shape == "small" else 1)
			var r := (FRUIT_SMALL_R if shape == "small" else FRUIT_R) * k * size
			# The leafy clumps (_crown) sit 0.62 crown radii out and are ~0.75 wide, so the canopy's skin is
			# ~1.37 radii out: fruit goes just inside it, over the upper half the camera sees, so a ready tree
			# reads as ready at a glance, as in FarmVille (on a ring at 1 radius it was buried in the leaves).
			var ch := maxf(float(sh.get("crown_h", 0.2)) * k, cr * 0.5)
			var clump := cr * (0.62 if str(sh["form"]) == "dense" else 0.75)
			var across := cr * 0.62 + clump * FRUIT_OUT
			var high := ch * 0.8 * 0.55 + clump * FRUIT_OUT
			for i in n:
				var a := TAU * i / n + rng.randf() * 0.5
				var up := rng.randf_range(-0.15, 0.8)
				var p := centre + Vector3(cos(a) * cos(up) * across, sin(up) * high, sin(a) * cos(up) * across)
				if str(sh["form"]) == "palm":
					# Coconuts cluster under the fronds, against the trunk.
					p = centre + Vector3(cos(a) * 0.06 * k, -0.06 * k, sin(a) * 0.06 * k)
				ModelKit.ball(root, p, r, mat, Vector3(1, 1.3, 1) if shape == "oval" else Vector3.ONE)
