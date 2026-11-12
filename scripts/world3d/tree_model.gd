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
const BARK := Color("#5a4630")
const LEAF := Color("#4f9a3a")
const LEAF_TOP := Color("#7cc04e")
const UNSET := Color(0, 0, 0, 0)
const FRUIT_READY := 22     # fruit on a ready tree (fewer, small and green, while it grows)
const FRUIT_R := 0.045      # a round fruit's radius (a small one's: FRUIT_SMALL_R), for a full-size tree
const FRUIT_SMALL_R := 0.02
const FRUIT_OUT := 1.12     # how far out through a leafy clump sits (1: on its surface; less: sunk in the leaves)
const HANG_OUT := 0.95      # where a hanging fruit's stem joins a leafy mass (1: its skin)
const STEM := Color("#5a4a2a")
const FRUIT_GROWING := 3
const FLOWERS: Array[Color] = [Color("#f6e04a"), Color("#f7f2e8"), Color("#e98bb0"), Color("#9b7be0")]
const TRUNK_BULK := 0.7     # trunks are drawn a little slimmer than the data says
const TRUNK_TALL := 1.0     # a trunk shows under the crown, the crown is the tree
const CROWN_GROW := 1.55    # and the crown is big, well over a tile across, the way FarmVille's were
const TRUNK_VARY_MIN := 0.85   # each tree's trunk is its own length, apart from its crown's size
const TRUNK_VARY_MAX := 1.25
const TALL_MIN := 0.85      # each tree is its own height, this much of its kind's..
const TALL_MAX := 1.2       # ..to this much
const MIN_LEAF_SATURATION := 0.5   # no tree washes out to pale grey-green
const CROWN_LOBES := 13      # rounded bulges on each leafy mass (data can set "lobes")
const CROWN_BUMP := 0.13     # how far they push out ("bump")
const FOLIAGE_CARDS := 90       # leaf cards on a crown mass (the cards' size follows the mass, so the cover does not)
const FOLIAGE_CARD := 0.85      # a card's size, of its mass's radius
const FOLIAGE_CORE := 0.66      # the solid mass inside the cards, of the full size: the cards make the outline
const FOLIAGE_MIN := 8          # at least this many cards on any mass
const TILE_FILL := 1.15     # a tree is one tile on the farm and its crown a little wider, so neighbours overlap

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


## A tree standing on `base` under `parent`; `size` 1 is a full tree on its own tile (crown nearly as wide
## as it). `leaf` overrides the kind's leaf colour when given. `mask` (see Crowding) is which tiles round it hold
## trees: more shade underneath, a taller trunk, a crown that swells to meet its neighbours', and no parts on the
## sides they cover.
static func build_at(parent: Node3D, base: Vector3, it: Dictionary, size := 1.0, ready := false,
		seed_value := 0, fruit := true, leaf := UNSET, mask := 0) -> Node3D:
	var crowd := Crowding.share_of(mask)
	var root := Node3D.new()
	root.position = base
	parent.add_child(root)
	var sh := shape_of(it)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + hash(str(it.get("id", "")))
	# Its height: its kind's (oaks low and broad, cherries tall), and this tree's own within that.
	var tall := float(sh.get("tall", 1.0)) * rng.randf_range(TALL_MIN, TALL_MAX)
	var upright := str(sh["form"]) not in ["palm", "banana"]
	var lift := 1.0 + Crowding.setting("tree", "lift") * crowd
	sh["trunk_h"] = float(sh["trunk_h"]) * tall * (TRUNK_TALL if upright else 1.0) * lift \
		* (rng.randf_range(TRUNK_VARY_MIN, TRUNK_VARY_MAX) if upright else 1.0)
	sh["crown_h"] = float(sh["crown_h"]) * tall
	# This tree's own variation: a little taller or shorter, leaning a little, turned its own way.
	var k := size * TILE_FILL * rng.randf_range(0.9, 1.1)
	root.rotation.y = rng.randf() * TAU
	var leaf_col := leaf if leaf.a > 0.0 else Color.html(str(sh.get("leaf", LEAF.to_html())))
	leaf_col = Color.from_hsv(leaf_col.h + rng.randf_range(-0.025, 0.025), leaf_col.s * rng.randf_range(0.92, 1.05),
		leaf_col.v * rng.randf_range(0.94, 1.04))
	sh["crown_r"] = float(sh["crown_r"]) * (1.0 + Crowding.setting("tree", "swell") * crowd) \
		* (CROWN_GROW if upright else 1.0)
	var t := {"root": root, "rng": rng, "k": k, "sh": sh, "crowd": crowd, "mask": mask, "leaf": leaf_col,
		"shine": float(sh.get("shine", 0.0)),
		"lean": Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06)), "blobs": []}
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
	_base(t)
	if sh.has("blossom"):
		_blossom(t, crown, Color.html(str(sh["blossom"])))
	if fruit:
		_fruit(t, crown, Color.html(str(it.get("color", "#d93b30"))), ready)
	ModelKit.sway_all(root, SWAY)
	return root


# ---------------------------------------------------------------- the ground under it


## What a tree stands among: a patch of bare earth round the trunk, a few stones, and wildflowers, so it
## is planted there and not set down on the grass. Different round each tree (its own seed).
static func _base(t: Dictionary) -> void:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var rng: RandomNumberGenerator = t["rng"]
	var r := float(t["sh"]["trunk_r"]) * k
	ModelKit.cylinder(root, Vector3(0, 0.002, 0), r * 2.6, 0.006, ModelKit.paint(Color("#7d5c3b")), -1.0, 10)
	for i in 3:
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(3.0, 4.6)
		ModelKit.facet_ball(root, Vector3(cos(a) * d, 0.0, sin(a) * d), r * rng.randf_range(0.5, 0.9),
			ModelKit.paint(Color("#9a9a94").darkened(rng.randf_range(0.0, 0.15))), Vector3(1, 0.6, 1))
	for i in 4:
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(3.6, 6.0)
		var col: Color = FLOWERS[rng.randi() % FLOWERS.size()]
		var at := Vector3(cos(a) * d, 0.0, sin(a) * d)
		ModelKit.cylinder(root, at, 0.004, 0.05 * k, ModelKit.paint(Color("#4f8a3a")), -1.0, 4)
		ModelKit.ball(root, at + Vector3(0, 0.055 * k, 0), 0.014 * k, ModelKit.paint(col))


# ---------------------------------------------------------------- trunks


## A tapering trunk, leaning a little, with a limb forking off; returns where the crown sits.
static func _trunk(t: Dictionary) -> Vector3:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var h := float(sh["trunk_h"]) * k
	var r := float(sh["trunk_r"]) * k * TRUNK_BULK
	var lean: Vector3 = t["lean"]
	var trunk := ModelKit.cylinder(root, Vector3.ZERO, r, h,
		ModelKit.paint(BARK.darkened(Crowding.setting("tree", "shade") * float(t["crowd"]))), r * 0.6, 8)
	trunk.rotation = Vector3(lean.z, 0, -lean.x)
	# The trunk flares at the foot into roots that grip the ground.
	ModelKit.cylinder(root, Vector3.ZERO, r * 1.9, r * 1.4, ModelKit.paint(BARK), r * 1.0, 8)
	for i in 3:
		var ra := TAU * i / 3.0 + float(t["lean"].x) * 20.0
		var rt := ModelKit.ball(root, Vector3(cos(ra) * r * 1.5, r * 0.25, sin(ra) * r * 1.5), r * 0.6,
			ModelKit.paint(BARK.darkened(0.1)), Vector3(1.5, 0.5, 1.0))
		rt.rotation.y = -ra
	var top := Vector3(lean.x * h, h, lean.z * h)
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


## The leafy crown: many faceted clumps over an ellipsoid of the form's width and height, so the outline is
## rough and every plane takes the light on its own. Sunlit tops lean yellow-green and bright, the shaded
## underside leans blue-green and dark, each clump a little different, with a dark core so it never looks hollow.
static func _crown(t: Dictionary, centre: Vector3) -> void:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var leaf: Color = t["leaf"]
	var shine: float = t["shine"]
	var cr := float(sh["crown_r"]) * k
	var ch := maxf(float(sh["crown_h"]) * k, cr * 0.5)
	var masses := int(sh.get("masses", 5))
	var reach := float(sh.get("reach", 0.55))
	var flat := float(sh.get("flat", 0.8))
	var mass := float(sh.get("mass", 0.52))
	# A crown is a few big leafy masses on limbs, each with small clumps along its outer edge: an uneven outline
	# with gaps where the branches show, not a ball. Its centre is off the trunk a little, so no two sides match.
	var mid := centre + Vector3(rng.randf_range(-0.1, 0.1) * cr, 0.0, rng.randf_range(-0.1, 0.1) * cr)
	# The trunk's top, where the limbs fork.
	var foot := Vector3(centre.x, centre.y - float(sh["crown_h"]) * k * 0.6, centre.z)
	# The light in the tree's own space (the tree is turned at random, the sun is not).
	var sun := Vector3(-0.45, 0.75, 0.5).normalized().rotated(Vector3.UP, -float(t["root"].rotation.y))
	# In a grove the lower crown is in its neighbours' shade.
	var shaded := float(t["crowd"]) * Crowding.setting("tree", "shade")
	var lobes := int(sh.get("lobes", CROWN_LOBES))
	var bump := float(sh.get("bump", CROWN_BUMP))
	# The core, a soft mass of the whole crown's width, then the masses around it: each one smooth and lumpy,
	# overlapping, so the crown reads as one canopy with a scalloped outline and a few deep folds.
	_canopy(root, mid, Vector3(cr * 0.72, maxf(ch * 0.5, cr * 0.4), cr * 0.72), rng, leaf, sun, -shaded, lobes, bump,
		shine)
	var shape := str(sh.get("shape", "round"))
	for i in masses:
		var a := i * 2.399963 + rng.randf() * 0.4
		var lay := _layout(shape, i, masses, rng)   # (height, reach, size), each a share of the plain round tree's
		var y := lay.x
		var d := cr * reach * lay.y * rng.randf_range(0.85, 1.15) * sqrt(maxf(1.0 - y * y * 0.6, 0.2))
		var p := mid + Vector3(cos(a) * d, y * ch * 0.7, sin(a) * d)
		var size := cr * mass * lay.z * rng.randf_range(0.85, 1.1)
		var squash := Vector3(rng.randf_range(1.0, 1.2), flat * rng.randf_range(0.85, 1.05), rng.randf_range(0.95, 1.15))
		# A mass on a side a neighbour covers is hidden anyway: every other one is left out, with its limb.
		if i % 2 == 1 and Crowding.covered(int(t["mask"]), a - root.rotation.y):
			continue
		_canopy(root, p, squash * size, rng, leaf, sun, 0.1 + 0.2 * (y + 0.3) - shaded, lobes, bump, shine)
		(t["blobs"] as Array).append([p, size, a])
		_limb(root, foot, p - Vector3(0, size * 0.45, 0), float(sh["trunk_r"]) * k * float(sh.get("limb", 0.6)))


## Where mass `i` of `n` sits for a kind of crown: (height, how far out, how big), as shares of the plain round
## tree's. Round is the ordinary dome; teardrop is wide at the bottom and narrows to a top (pear); umbrella is
## one wide flat layer (cherry, fig, olive); columnar is a tall narrow stack (pecan, avocado); layers are tiers
## that narrow as they climb (oak, walnut).
static func _layout(shape: String, i: int, n: int, rng: RandomNumberGenerator) -> Vector3:
	var u := float(i) / maxf(n - 1.0, 1.0)
	match shape:
		"teardrop":
			return Vector3(lerpf(-0.35, 0.65, u), lerpf(1.25, 0.4, u), lerpf(1.15, 0.65, u))
		"umbrella":
			return Vector3(rng.randf_range(-0.12, 0.12), 1.4, 1.1)
		"columnar":
			return Vector3(lerpf(-0.45, 1.1, u), 0.35, lerpf(1.0, 0.7, u))
		"layers":
			var tier := float(i % 3) / 2.0
			return Vector3(lerpf(-0.4, 0.8, tier), lerpf(1.3, 0.5, tier), lerpf(1.1, 0.75, tier))
	return Vector3(lerpf(-0.3, 0.5, fposmod(i * 0.618 + rng.randf() * 0.15, 1.0)), 1.0, 1.0)


## One canopy mass: smooth, lumpy and shaded in its vertices (ModelKit.canopy); `lift` brightens it (masses up
## in the crown catch more light than the ones low down).
static func _canopy(root: Node3D, at: Vector3, radii: Vector3, rng: RandomNumberGenerator, leaf: Color, sun: Vector3,
		lift: float, lobes: int, bump: float, shine: float) -> void:
	var shade := func(light: float) -> Color: return _shade(leaf, clampf(light * 1.1 + lift * 0.4 - 0.12, 0.0, 1.0))
	ModelKit.canopy(root, at, radii * FOLIAGE_CORE, rng, shade, sun, lobes, bump, shine)
	var mean := (radii.x + radii.y + radii.z) / 3.0
	var cards := ModelKit.scaled(FOLIAGE_CARDS, FOLIAGE_MIN)
	ModelKit.foliage_cards(root, at, radii, rng, shade, sun, cards, mean * FOLIAGE_CARD, shine)


## A branch from one point to another: a thin tapering cylinder tipped to lie along the line.
static func _limb(root: Node3D, from: Vector3, to: Vector3, r: float) -> void:
	var line := to - from
	var length := line.length()
	if length < 0.02:
		return
	var limb := ModelKit.cylinder(root, Vector3.ZERO, r, length, ModelKit.paint(BARK), r * 0.4, 5)
	var dir := line / length
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.001:
		limb.basis = Basis(axis.normalized(), acos(clampf(Vector3.UP.dot(dir), -1.0, 1.0)))
	limb.position = from + line * 0.5


## The leaf colour for how lit a clump is (0 deep shade .. 1 full sun): shade drifts blue-green and dark,
## sun drifts yellow-green and bright, and the colour is richer than a flat darker/lighter of one green.
static func _shade(leaf: Color, light: float) -> Color:
	var h := leaf.h + lerpf(0.025, -0.03, light)
	var s := clampf(maxf(leaf.s, MIN_LEAF_SATURATION) * lerpf(1.12, 0.88, light), 0.0, 1.0)
	var v := clampf(leaf.v * lerpf(0.42, 1.5, light), 0.0, 1.0)
	return Color.from_hsv(h, s, v)


## A fruit's colour in the sun: brighter and a little warmer, never washed toward pink or white
## (lightening a red fruit made it salmon).
static func _sunlit(c: Color) -> Color:
	return Color.from_hsv(c.h, clampf(c.s * 0.95, 0.0, 1.0), clampf(c.v * 1.12 + 0.04, 0.0, 1.0))


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
	var mat := ModelKit.paint(leaf.darkened(rng.randf_range(0.2, 0.32)))  # (flat fronds catch the sun full on)
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
	# Three shades, so a tree's fruit isn't a row of identical balls: sunny side, middle, shaded underside.
	var shades := [ModelKit.paint(_sunlit(c), 0.5), mat, ModelKit.paint(c.darkened(0.2), 0.3)]
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
				var fruit_mat: Material = mat
				var fruit_r := r
				var blobs: Array = t["blobs"]
				if not blobs.is_empty() and str(sh["form"]) != "palm":
					# Fruit grows in twos and threes on one mass, each its own size. Most hang from the canopy's rim and
					# underside on a short stem (as FarmVille's did); a few sit on its sunlit top.
					var blob: Array = blobs[i % blobs.size()]
					var face := float(blob[2]) + (i / 3) * 0.7 + rng.randf_range(-0.35, 0.35)
					fruit_r = r * rng.randf_range(0.8, 1.15)
					var low := (blob[0] as Vector3).y - float(blob[1]) < 0.16 * k  # a low crown: nothing hangs to the grass
					if i % 3 != 2 and not low:
						var rim := Vector3(cos(face), rng.randf_range(-0.55, 0.05), sin(face)).normalized()
						var anchor := (blob[0] as Vector3) + rim * float(blob[1]) * HANG_OUT
						var drop := fruit_r * rng.randf_range(1.2, 1.9)
						ModelKit.box(root, anchor + Vector3(-0.004, -drop, -0.004) * k,
							anchor + Vector3(0.004, 0.0, 0.004) * k, ModelKit.paint(STEM), false)
						p = anchor - Vector3(0, drop + fruit_r * 0.85, 0)
						fruit_mat = shades[1 if rim.y > -0.3 else 2]
					else:
						var dir := Vector3(cos(face), rng.randf_range(0.25, 0.9), sin(face)).normalized()
						p = (blob[0] as Vector3) + dir * float(blob[1]) * FRUIT_OUT
						fruit_mat = shades[0 if dir.y > 0.55 else 1]
				if str(sh["form"]) == "palm":
					# Coconuts cluster under the fronds, against the trunk.
					p = centre + Vector3(cos(a) * 0.06 * k, -0.06 * k, sin(a) * 0.06 * k)
				ModelKit.ball(root, p, fruit_r, fruit_mat, Vector3(1, 1.3, 1) if shape == "oval" else Vector3.ONE)
