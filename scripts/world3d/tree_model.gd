class_name TreeModel
extends RefCounted
## A tree in 3D, grown to its kind's shape (data/tree_shapes.json): an apple's round dome, a lemon's tight
## glossy ball on a short trunk, a cherry's tall oval in blossom, an olive's wide silvery crown on a thick
## trunk, a willow's drooping curtain, a palm's ringed trunk and fronds, a banana's paddle leaves, a
## pomegranate's many stems. Fruit hangs in its own way too: round, oval, in long bunches, huge on the
## trunk, or as many small nuts. Its fruit comes one piece at a
## time as it ripens, each small and green, then full-coloured.
##
## No two trees are the same: each is varied by its own seed (height, lean, where its clumps sit, their
## shade), so an orchard of one kind still reads as trees and not copies.

const SWAY := TreeSpec.SWAY        # (what the farm names is in TreeSpec: this file loads by path, TreeSpec.builder())
const PATH := TreeSpec.PATH
const BARK := TreeSpec.BARK
const LEAF := Color("#4f9a3a")
const LEAF_TOP := Color("#7cc04e")
const UNSET := TreeSpec.UNSET
const COLOUR_SEED := 4177   # offsets the colour stream from the shape stream
const CROWN_TRIM := 1.0       # every crown is drawn this share of its data's width (0.92 of that in height): lighter
const CROWN_REACH_MAX := 0.68  # no crown reaches further from its trunk than this (of the tree's size): never a blob
const TRUNK_SHARE := 0.27     # bare trunk shows for at least this share of a tree's height, under the lowest leaves
const TRUNK_LENGTH := 0.9     # every trunk is drawn this much of the length the rules above give it
const WILLOW_FALLS := 8       # the hanging masses round a willow's rim
const WILLOW_FALL := 1.0      # how far one hangs below the crown's middle, of the crown's radius
const WILLOW_FALL_VARY_MIN := 0.8   # and each its own length within this..
const WILLOW_FALL_VARY_MAX := 1.1   # ..to this
const WILLOW_RIM := 0.7       # where they hang from, of the crown's radius out from the trunk
const WILLOW_FALL_W := 0.26   # how wide each is, of the crown's radius
const WILLOW_TURN_VARY := 0.2 # radians each is turned off its even spacing
const WILLOW_LIFT := -0.05    # a little darker than the crown above (they hang in its shade)
const WILLOW_CARDS := 24      # leaf cards on a hanging mass (narrow: far fewer than a crown mass needs)
const FORK_STEMS := 2         # a shrubby tree's trunk forks into this many more stems..
const FORK_LOW := 0.3         # ..between this share of its height..
const FORK_HIGH := 0.45       # ..and this
const FORK_SPREAD := 0.45     # each reaching out this far under the crown, of its radius
const FORK_THIN := 0.75       # and this much thinner than the trunk
const FORK_TURN_VARY := 0.6   # radians each is turned off its even spacing
const TRUNK_TAPER := 0.85     # a trunk is a thin straight pole: its top is this much of its foot
const TRUNK_LEAN := 0.03      # and it leans no more than this (radians)
const META_SHARE := &"trunk_share"   # on a built tree: the share of its height that is bare trunk
const META_REACH := &"crown_reach"   # and how far its crown reaches from the trunk, of the tree's size
const META_FAR := TreeSpec.META_FAR   # and what its far look needs (TreeSpec)
const FAR_LUMPS := 3            # a tree seen from far: its crown is this many soft lumps round the main one
const LEAF_HUE_VARY := 0.04   # how far a tree's leaf colour may drift round its kind's, in hue
const SEEN_FROM := Vector3(0.7071, 0, 0.7071)   # the side of a tree the farm's camera sees
const BUNCH_OUT := 0.13      # how far out from the stem a banana's bunch hangs, of the tree's size..
const BUNCH_WIDE := 0.045    # ..how wide a hand of it is..
const BANANA_R := 0.027      # ..and how thick each banana
const PALM_RINGS := 11       # rings up a palm's trunk..
const BANANA_RINGS := 6      # ..and sheaths up a banana's stem
const TRUNK_NARROW := 0.64   # a ringed trunk's top, of its foot's width
const TRUNK_FOOT := 1.7      # the swell where it meets the ground, of its width
const RING_LIGHT := 0.13     # every other ring, lighter by this
const BANANA_STEM := Color("#8fb84e")
const FROND_TURN := 0.12     # how far a frond strays from its even place round the crown (radians)
const FROND_SHADE := 0.1     # how much darker one frond may be than the next
const LEAFLETS_FEWEST := 6   # pairs of leaflets on a frond in the thickest crowd
const FRUIT_READY := 14     # fruit on a full tree (they come one at a time as it ripens: _fruit): few and big, so
const FRUIT_R := 0.093      # ..each reads as a fruit (owner, 19 Nov). A round one's radius on a full-size tree..
const FRUIT_SMALL_R := 0.029  # ..and a small one's (cherries, olives: three times as many)
const PALM_NUT := 0.6       # a palm's nuts, of a round fruit's size, in a ring..
const PALM_RING := 0.075    # ..this far out from the trunk (of the tree's size)
const FRUIT_OUT := 0.97     # how far out through a leafy clump one sits (1: on its skin). Just inside, so the leaves
							# lap over its edge and it grows there; standing proud of them it looked stuck on
const TURN_STEP := 0.618    # each fruit's turn to grow is this much on from the one before (wrapping at 1): spread out
const TRUNK_BULK := 0.7     # trunks are drawn a little slimmer than the data says
const TRUNK_TALL := 0.85    # trunks are short: a big full crown on a slim trunk, FarmVille's way
const CROWN_GROW := 1.55    # the crown is well over a tile across: most of the tree
const TRUNK_VARY_MIN := 0.85   # each tree's trunk is its own length, apart from its crown's size
const TRUNK_VARY_MAX := 1.25
const TALL_MIN := 0.85      # each tree is its own height, this much of its kind's..
const TALL_MAX := 1.2       # ..to this much
const STAND_TALL_MAX := 1.1    # a tree stands at least its kind's lowest height times its own tallness, up to this
const MIN_LEAF_VALUE := 0.56   # and none is so dark its crown reads as a black mass (an orange's deep teal)
const CROWN_CORE := 0.56       # the soft mass in a crown's middle, of the crown's radius: the clumps stand clear of it
const CLUMP_OUT := 1.22        # a crown's clumps sit this much further out than its kind's numbers say..
const CLUMP_SIZE := 0.9        # ..and are this much of their size: clumps of their own, not one ball
const MIN_LEAF_SATURATION := 0.5   # no tree washes out to pale grey-green
const CROWN_LOBES := 13      # rounded bulges on each leafy mass (data can set "lobes")
const CROWN_BUMP := 0.13     # how far they push out ("bump")
const FOLIAGE_CARDS := 90       # leaf cards on a crown mass (the cards' size follows the mass, so the cover does not)
const FOLIAGE_CARD := 0.7       # a card's size, of its mass's radius
const FOLIAGE_CORE := 0.66      # the solid mass inside the cards, of the full size: the cards make the outline
const FOLIAGE_MIN := 8          # at least this many cards on any mass
const TILE_FILL := 1.15     # a tree is one tile on the farm and its crown a little wider, so neighbours overlap

## Whether a tree of this kind stands within the tree height range by itself (TreeSpec, kept here for the tools).
static func stands_by_itself(it: Dictionary) -> bool:
	return TreeSpec.stands_by_itself(it)


## The shape for a tree (TreeSpec).
static func shape_of(it: Dictionary) -> Dictionary:
	return TreeSpec.shape_of(it)


## One of a kind's colours, chosen for this tree: the main one (`key` in the shape, or `main` when it has none)
## or one of its alternatives (an array of colours under `alts`), so a row of one kind is not one colour.
static func _pick(sh: Dictionary, key: String, alts: String, fallback: String, rng: RandomNumberGenerator,
		main := "") -> Color:
	var options: Array = [str(sh.get(key, fallback)) if key != "" else (main if main != "" else fallback)]
	options.append_array(sh.get(alts, []))
	return Color.html(str(options[rng.randi() % options.size()]))


## A leaf colour in the farm's one family (data/tree_shapes.json `leaf_tone`): each kind keeps its own hue, but
## all are mixed a little towards one shared warm green and softened, so a row of pink, teal and orange crowns
## reads as painted from the same palette as the animals and the lawn beside them, not as candy. The hue is always
## the kind's own (the mix only softens and darkens it): a pink crown stays pink, never salmon or grey (owner, 18 Nov).
static func tone(col: Color) -> Color:
	var tn: Dictionary = TreeSpec.data().get("leaf_tone", {})
	if tn.is_empty():
		return col
	var c := col.lerp(Color.html(str(tn.get("tint", "#8c9a52"))), float(tn.get("mix", 0.0)))
	return Color.from_hsv(col.h, clampf(c.s * float(tn.get("saturation", 1.0)), 0.0, 1.0), c.v, col.a)


## Every form the data describes (tests build each one).
static func forms() -> Array:
	return (TreeSpec.data().get("forms", {}) as Dictionary).keys()


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
	var colours := RandomNumberGenerator.new()   # its own stream: choosing colours must not move the tree's shape
	colours.seed = rng.seed + COLOUR_SEED
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
	var leaf_col := leaf if leaf.a > 0.0 else _pick(sh, "leaf", "leaf_alts", LEAF.to_html(), colours)
	leaf_col = Color.from_hsv(leaf_col.h + rng.randf_range(-LEAF_HUE_VARY, LEAF_HUE_VARY),
		leaf_col.s * rng.randf_range(0.92, 1.05),
		leaf_col.v * rng.randf_range(0.94, 1.04))
	leaf_col = tone(leaf_col)
	sh["crown_r"] = float(sh["crown_r"]) * (1.0 + Crowding.setting("tree", "swell") * crowd) \
		* (CROWN_GROW if upright else 1.0) * CROWN_TRIM
	sh["crown_h"] = float(sh["crown_h"]) * (CROWN_TRIM + 0.04)
	# A limited variety (data/varieties.json): its own colours through the crown, deeper if it says so.
	var variety := Varieties.of(str(it.get("variety", "")))
	var hues := Varieties.leaves(str(it.get("variety", "")))
	if not hues.is_empty() and leaf.a <= 0.0:
		leaf_col = hues[0]
	var t := {"root": root, "rng": rng, "k": k, "sh": sh, "crowd": crowd, "mask": mask, "leaf": leaf_col,
		"hues": hues, "hue": 0, "deep": float(variety.get("darken", 0.0)),
		"shine": float(sh.get("shine", 0.0)),
		"lean": Vector3(rng.randf_range(-TRUNK_LEAN, TRUNK_LEAN), 0, rng.randf_range(-TRUNK_LEAN, TRUNK_LEAN)),
		"blobs": [], "low": INF, "high": -INF, "reach": 0.0,
		"stand": ScaleGuide.lowest("tree") * size * clampf(tall, 1.0, STAND_TALL_MAX) * lift}
	var crown: Vector3
	match str(sh["form"]):
		"palm":
			crown = _palm(t)
		"banana":
			crown = _banana(t)
		_:
			crown = _crown_on_trunk(t)
	if sh.has("blossom"):
		_blossom(t, crown, Color.html(str(sh["blossom"])))
	if fruit:
		var fruit_col := _pick(sh, "", "fruit_alts", "#d93b30", colours, str(it.get("color", "")))
		_fruit(t, crown, fruit_col)
	ModelKit.sway_all(root, SWAY)
	return root


# ---------------------------------------------------------------- far away


## The same tree seen from far away (an orchard zoomed out): its own trunk, as long and as thin, and its crown
## as a few smooth lumps of its own size and colours, lit and shaded like the real one, in a few hundred
## triangles instead of thousands. Palms and bananas, which have no leafy crown, are their own tree at low detail.
static func far_model(it: Dictionary, size: float, seed_value: int) -> Node3D:
	var whole := Node3D.new()
	var tree := build_at(whole, Vector3.ZERO, it, size, false, seed_value, false)
	var far: Array = tree.get_meta(META_FAR, [])
	whole.free()
	return far_from(far, it, size, seed_value)


## The far look from a built tree's own measurements (its META_FAR), without building the tree again; with none
## (a palm or a banana, which have no leafy crown) the tree itself at low detail.
static func far_from(far: Array, it: Dictionary, size: float, seed_value: int) -> Node3D:
	var out := Node3D.new()
	if far.size() < 6:
		var detail := ModelKit.detail
		ModelKit.detail = 0.4
		build_at(out, Vector3.ZERO, it, size, false, seed_value, false)
		ModelKit.detail = detail
		return ModelKit.bake(out)
	var trunk_h := float(far[0])
	var low := float(far[1])
	var high := float(far[2])
	var reach := float(far[3])
	var leaf: Color = far[5]
	ModelKit.cylinder(out, Vector3.ZERO, float(far[4]), trunk_h, ModelKit.paint(BARK), float(far[4]) * TRUNK_TAPER, 5)
	var mid := Vector3(0, (low + high) * 0.5, 0)
	var half := (high - low) * 0.5
	ModelKit.ball(out, mid, 1.0, ModelKit.paint(_shade(leaf, 0.55)), Vector3(reach * 0.8, half, reach * 0.8), true)
	for i in FAR_LUMPS:
		var a := TAU * i / FAR_LUMPS
		var at := mid + Vector3(cos(a) * reach * 0.38, half * (0.25 if i == 0 else -0.1), sin(a) * reach * 0.38)
		ModelKit.ball(out, at, 1.0, ModelKit.paint(_shade(leaf, 0.85 if i == 0 else 0.4)),
			Vector3(reach * 0.55, half * 0.7, reach * 0.55), true)
	return ModelKit.bake(out)


# ---------------------------------------------------------------- trunks


## The crown, then the trunk that carries it. The crown is built first, over a trunk top at the origin, and
## measured as it really is (every mass, not a formula): it is brought in if it reaches past CROWN_REACH_MAX (and
## grown towards it when the tree would stand too short), and the trunk is then made long enough that TRUNK_SHARE of
## the whole height is bare trunk under the lowest leaves,
## and that the tree stands at least the lowest height of a tree (ScaleGuide), so nothing scales a crown up.
## Everything of the crown is then lifted onto the trunk's top. Returns the crown's centre.
static func _crown_on_trunk(t: Dictionary) -> Vector3:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var first := root.get_child_count()
	var centre := Vector3(0, float(sh["crown_h"]) * k * 0.6, 0)
	_crown(t, centre)
	if str(sh["form"]) == "weeping":
		_droop(t, centre)   # (measured with the crown, so the reach cap and the trunk rules take it in)
	# The crown is drawn bigger or smaller about the trunk's top, never reaching past the cap: smaller when too
	# wide; bigger when the tree would stand too short, up to the cap, the trunk making up whatever is left.
	var cap := CROWN_REACH_MAX * k / maxf(float(t["reach"]), 0.001)
	var shrink := minf(1.0, cap)
	var total := _trunk_for(sh, k, t, shrink) + float(t["high"]) * shrink
	if total < float(t["stand"]):
		shrink = minf(cap, shrink * float(t["stand"]) / maxf(total, 0.001))
	var low: float = float(t["low"]) * shrink
	var high: float = float(t["high"]) * shrink
	var h := maxf(_trunk_for(sh, k, t, shrink), float(t["stand"]) - high)
	# A little shorter, never under the share.
	h = maxf(h * TRUNK_LENGTH, (TRUNK_SHARE * high - low) / (1.0 - TRUNK_SHARE))
	var lean: Vector3 = t["lean"]
	var top := Vector3(lean.x * h, h, lean.z * h)
	for i in range(first, root.get_child_count()):
		var part := root.get_child(i) as Node3D
		part.position = part.position * shrink + top
		part.scale *= shrink
	for blob: Array in t["blobs"]:
		blob[0] = (blob[0] as Vector3) * shrink + top
		blob[1] = float(blob[1]) * shrink
	sh["crown_r"] = float(sh["crown_r"]) * shrink
	sh["crown_h"] = float(sh["crown_h"]) * shrink
	sh["trunk_h"] = h / k
	if str(sh["form"]) == "bushy":
		_stems(t)
	else:
		_trunk(t)
	root.set_meta(META_SHARE, (h + low) / (h + high))
	root.set_meta(META_REACH, float(t["reach"]) * shrink / k)
	root.set_meta(META_FAR, [h, h + low, h + high, float(t["reach"]) * shrink, float(sh["trunk_r"]) * k * TRUNK_BULK,
		t["leaf"]])
	return centre * shrink + top


## The trunk a crown drawn `shrink` times its size needs: its kind's own length, or longer so that TRUNK_SHARE of
## the height is bare trunk under the lowest leaves.
static func _trunk_for(sh: Dictionary, k: float, t: Dictionary, shrink: float) -> float:
	var low := float(t["low"]) * shrink
	var high := float(t["high"]) * shrink
	return maxf(float(sh["trunk_h"]) * k, (TRUNK_SHARE * high - low) / (1.0 - TRUNK_SHARE))


## A thin straight trunk, leaning very little, with small roots where it goes into the ground.
static func _trunk(t: Dictionary) -> void:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var h := float(sh["trunk_h"]) * k
	var r := float(sh["trunk_r"]) * k * TRUNK_BULK
	var lean: Vector3 = t["lean"]
	var trunk := ModelKit.cylinder(root, Vector3.ZERO, r, h,
		ModelKit.paint(BARK.darkened(Crowding.setting("tree", "shade") * float(t["crowd"]))), r * TRUNK_TAPER, 8)
	trunk.rotation = Vector3(lean.z, 0, -lean.x)
	# Three small roots where it enters the ground, so it grows out of it and is not set down on it.
	for i in 3:
		var ra := TAU * i / 3.0 + float(t["lean"].x) * 20.0
		var rt := ModelKit.ball(root, Vector3(cos(ra) * r * 1.1, r * 0.15, sin(ra) * r * 1.1), r * 0.45,
			ModelKit.paint(BARK.darkened(0.1)), Vector3(1.5, 0.5, 1.0))
		rt.rotation.y = -ra


## A shrubby tree: a short main trunk that forks low into two more stems, each leaning out under the crown (one
## clear trunk to read, not a tangle of sticks from the ground).
static func _stems(t: Dictionary) -> void:
	_trunk(t)
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var h := float(sh["trunk_h"]) * k
	var r := float(sh["trunk_r"]) * k * TRUNK_BULK
	var cr := float(sh["crown_r"]) * k
	for i in FORK_STEMS:
		var a := TAU * i / FORK_STEMS + rng.randf_range(-FORK_TURN_VARY, FORK_TURN_VARY)
		var fork := Vector3(0, h * rng.randf_range(FORK_LOW, FORK_HIGH), 0)
		_limb(root, fork, Vector3(cos(a) * cr * FORK_SPREAD, h, sin(a) * cr * FORK_SPREAD), r * FORK_THIN)


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
	var masses := ModelKit.scaled(int(sh.get("masses", 5)), 3)   # fewer in a crowd (ModelKit.detail)
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
	var lobes := ModelKit.scaled(int(sh.get("lobes", CROWN_LOBES)), 5)
	var bump := float(sh.get("bump", CROWN_BUMP))
	# The core, a soft mass in the crown's middle, then the masses around it standing clear of it: each one a
	# clump of its own, lit on top and dark underneath, so the crown is a cluster of clumps with a scalloped outline.
	var core := Vector3(cr * CROWN_CORE, maxf(ch * 0.5, cr * 0.4), cr * CROWN_CORE)
	_canopy(root, mid, core, rng, _leaf_of(t), sun, -shaded, lobes, bump, shine, FOLIAGE_CARDS, float(t["deep"]))
	_measure(t, mid, core)
	var shape := str(sh.get("shape", "round"))
	for i in masses:
		var a := i * 2.399963 + rng.randf() * 0.4
		var lay := _layout(shape, i, masses, rng)   # (height, reach, size), each a share of the plain round tree's
		var y := lay.x
		var d := cr * reach * CLUMP_OUT * lay.y * rng.randf_range(0.85, 1.15)
		d *= sqrt(maxf(1.0 - y * y * 0.6, 0.2))
		var p := mid + Vector3(cos(a) * d, y * ch * 0.7, sin(a) * d)
		var size := cr * mass * CLUMP_SIZE * lay.z * rng.randf_range(0.85, 1.1)
		var squash := Vector3(rng.randf_range(1.0, 1.2), flat * rng.randf_range(0.85, 1.05), rng.randf_range(0.95, 1.15))
		# A mass on a side a neighbour covers is hidden anyway: every other one is left out, with its limb.
		if i % 2 == 1 and Crowding.covered(int(t["mask"]), a - root.rotation.y):
			continue
		_canopy(root, p, squash * size, rng, _leaf_of(t), sun, 0.1 + 0.2 * (y + 0.3) - shaded, lobes, bump, shine,
			FOLIAGE_CARDS, float(t["deep"]))
		_measure(t, p, squash * size)
		(t["blobs"] as Array).append([p, size, a, squash.y])
		_limb(root, foot, p - Vector3(0, size * 0.45, 0), float(sh["trunk_r"]) * k * float(sh.get("limb", 0.6)))


## Counts one leafy mass (centre and half-sizes) into the crown's real extent: its lowest and highest leaves and
## how far it reaches from the trunk's line.
static func _measure(t: Dictionary, at: Vector3, radii: Vector3) -> void:
	t["low"] = minf(float(t["low"]), at.y - radii.y)
	t["high"] = maxf(float(t["high"]), at.y + radii.y)
	t["reach"] = maxf(float(t["reach"]), Vector2(at.x, at.z).length() + maxf(radii.x, radii.z))


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
		lift: float, lobes: int, bump: float, shine: float, cards_most := FOLIAGE_CARDS, deep := 0.0) -> void:
	var shade := func(light: float) -> Color:
		return _shade(leaf, clampf(light * 1.1 + lift * 0.4 - 0.12, 0.0, 1.0)).darkened(deep)
	ModelKit.canopy(root, at, radii * FOLIAGE_CORE, rng, shade, sun, lobes, bump, shine)
	var mean := (radii.x + radii.y + radii.z) / 3.0
	var cards := ModelKit.scaled(cards_most, FOLIAGE_MIN)
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


## The colour of the next mass of leaves (or frond) of tree `t`: its one leaf colour, or for a limited variety
## the variety's colours in turn (data/varieties.json `leaves`), so a Rainbow crown is many colours.
static func _leaf_of(t: Dictionary) -> Color:
	var hues: Array[Color] = t["hues"]
	if hues.is_empty():
		return t["leaf"]
	t["hue"] = int(t["hue"]) + 1
	return hues[(int(t["hue"]) - 1) % hues.size()]


## A Galaxy tree's stars: small pale lights dotted over the upper faces of its crown (or round a palm's head),
## each blinking on its own beat (star3d.gdshader).
static func _stars(t: Dictionary, centre: Vector3, col: Color) -> void:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var rng: RandomNumberGenerator = t["rng"]
	var blobs: Array = t["blobs"]
	var mat := ModelKit.star_paint(col)
	for i in ModelKit.scaled(STARS, STARS_FEWEST):
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.1, 1), rng.randf_range(-1, 1)).normalized()
		var p := centre + dir * STAR_REACH * k
		if not blobs.is_empty():
			var blob: Array = blobs[i % blobs.size()]
			dir.y *= float(blob[3])   # (a clump is flatter than it is wide)
			p = (blob[0] as Vector3) + dir * float(blob[1])
		var star := ModelKit.ball(root, p, rng.randf_range(STAR_R.x, STAR_R.y) * k, mat)
		ModelKit.mark_fruit(star, rng.randf())


## The leaf colour for how lit a clump is (0 deep shade .. 1 full sun): shade drifts blue-green and dark,
## sun drifts yellow-green and bright, and the colour is richer than a flat darker/lighter of one green.
static func _shade(leaf: Color, light: float) -> Color:
	var h := leaf.h + lerpf(0.025, -0.03, light)
	var s := clampf(maxf(leaf.s, MIN_LEAF_SATURATION) * lerpf(1.12, 0.88, light), 0.0, 1.0)
	# (shade is the leaf's colour deeper, never near black)
	var v := clampf(maxf(leaf.v, MIN_LEAF_VALUE) * lerpf(0.62, 1.4, light), 0.0, 1.0)
	return Color.from_hsv(h, s, v)


## A fruit's colour in the sun: brighter and a little warmer, never washed toward pink or white
## (lightening a red fruit made it salmon).
static func _sunlit(c: Color) -> Color:
	return Color.from_hsv(c.h, clampf(c.s * 0.95, 0.0, 1.0), clampf(c.v * 1.12 + 0.04, 0.0, 1.0))


## A willow's droop: soft leafy masses hanging round the crown's rim, longer than wide, so the crown falls in a
## curtain over the trunk without any stick-like strands. Built in the crown's own space, before it is fitted onto
## its trunk; in a grove the sides a neighbour covers get none, and their shade is the crown's.
static func _droop(t: Dictionary, centre: Vector3) -> void:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var cr := float(sh["crown_r"]) * k
	var sun := Vector3(-0.45, 0.75, 0.5).normalized().rotated(Vector3.UP, -root.rotation.y)
	var shaded := float(t["crowd"]) * Crowding.setting("tree", "shade")
	var lobes := ModelKit.scaled(CROWN_LOBES, 5)
	var n := ModelKit.scaled(WILLOW_FALLS, 5)
	for i in n:
		var a := TAU * i / n + rng.randf_range(-WILLOW_TURN_VARY, WILLOW_TURN_VARY)
		if Crowding.covered(int(t["mask"]), a - root.rotation.y):
			continue
		var long := cr * WILLOW_FALL * rng.randf_range(WILLOW_FALL_VARY_MIN, WILLOW_FALL_VARY_MAX)
		var at := centre + Vector3(cos(a) * cr * WILLOW_RIM, -long * 0.5, sin(a) * cr * WILLOW_RIM)
		var radii := Vector3(cr * WILLOW_FALL_W, long * 0.5, cr * WILLOW_FALL_W)
		_canopy(root, at, radii, rng, _leaf_of(t), sun, WILLOW_LIFT - shaded, lobes, CROWN_BUMP, float(t["shine"]),
			WILLOW_CARDS, float(t["deep"]))
		_measure(t, at, radii)


## A palm: a trunk curving up in rings from a swollen foot, narrowing as it goes, and a crown of feather fronds
## in tiers, the top ones reaching up and the lowest hanging (its form's `tiers`, `leaflets` and `lean`: a date
## palm's stand stiffer and more upright than a coconut palm's).
static func _palm(t: Dictionary) -> Vector3:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var top := _ringed_trunk(t, BARK, float(sh.get("lean", 0.0)), PALM_RINGS)
	var tiers: Array = sh["tiers"]
	var reach := float(sh["crown_r"]) * k
	var pairs := ModelKit.scaled(int(sh["leaflets"]), LEAFLETS_FEWEST)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fronds := int(sh["clumps"])
	for i in fronds:
		var tier: Array = tiers[i % tiers.size()]
		var at := Transform3D(Basis(Vector3.UP, -(TAU * i / fronds + rng.randf_range(-FROND_TURN, FROND_TURN))), top)
		FrondMesh.feather(st, at, reach * rng.randf_range(0.9, 1.08), float(tier[0]), float(tier[1]),
			reach * float(sh["leaflet"]), pairs, _leaf_of(t).darkened(float(t["deep"]) + rng.randf_range(0.0, FROND_SHADE)),
			rng.randf())
	_leaves_of(root, st)
	return top


## A banana: a soft green stem in sheaths, and a fan of broad paddle leaves arching out of its top.
static func _banana(t: Dictionary) -> Vector3:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var top := _ringed_trunk(t, BANANA_STEM, float(sh.get("lean", 0.0)), BANANA_RINGS)
	var tiers: Array = sh["tiers"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(sh["clumps"])
	for i in n:
		var tier: Array = tiers[i % tiers.size()]
		var length := float(sh["crown_r"]) * k * rng.randf_range(0.88, 1.08)
		var at := Transform3D(Basis(Vector3.UP, -(TAU * i / n + rng.randf_range(-FROND_TURN, FROND_TURN))), top)
		FrondMesh.paddle(st, at, length, float(tier[0]), float(tier[1]), length * float(sh["leaflet"]),
			_leaf_of(t).darkened(float(t["deep"]) + rng.randf_range(0.0, FROND_SHADE)), rng.randf())
	_leaves_of(root, st)
	return top + Vector3(0, 0.05 * k, 0)


## A palm's or a banana's trunk: `rings` rings from a swollen foot up to its form's `trunk_h`, narrowing to
## TRUNK_NARROW of its foot's width and leaning `lean` of its height off its foot, further the higher it goes
## (a curve). Returns its top.
static func _ringed_trunk(t: Dictionary, col: Color, lean: float, rings: int) -> Vector3:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var h := float(sh["trunk_h"]) * k
	var r := float(sh["trunk_r"]) * k
	var way := rng.randf() * TAU
	var off := Vector3(cos(way), 0, sin(way)) * lean * h
	ModelKit.ball(root, Vector3(0, r * 0.3, 0), r * TRUNK_FOOT, ModelKit.paint(col.darkened(0.12)), Vector3(1, 0.5, 1))
	for i in rings:
		var u := float(i) / rings
		var wide := r * lerpf(1.0, TRUNK_NARROW, u)
		ModelKit.cylinder(root, off * (u * u) + Vector3(0, u * h, 0), wide * 1.1, h / rings * 1.04,
			ModelKit.paint(col.lightened(RING_LIGHT if i % 2 == 0 else 0.0)), wide * 0.9, 8)
	return off + Vector3(0, h, 0)


## The leaves FrondMesh laid into `st`, as one part of the tree.
static func _leaves_of(root: Node3D, st: SurfaceTool) -> void:
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = ModelKit.fronds()
	root.add_child(mi)


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


## Fruit, hung the kind's way: every fruit of a full tree, each marked with its turn to grow (ModelKit.mark_fruit).
## The model always holds them all; the fruit's shader shows each one come in its turn, small and green, swell
## and take its colour as the tree's cycle goes (shaders/fruit3d.gdshader), so a tree ripens piece by piece
## instead of changing picture when it comes ready.
static func _fruit(t: Dictionary, centre: Vector3, col: Color) -> void:
	var root: Node3D = t["root"]
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var rng: RandomNumberGenerator = t["rng"]
	var shape := str(sh.get("fruit_shape", "round"))
	var size := float(sh.get("fruit_size", 1.0))
	var c := col
	var mat := ModelKit.fruit_paint(c)
	# Three shades, so a tree's fruit isn't a row of identical balls: sunny side, middle, shaded underside.
	var shades := [ModelKit.fruit_paint(_sunlit(c)), mat, ModelKit.fruit_paint(c.darkened(0.2))]
	var cr := float(sh["crown_r"]) * k
	var count := FRUIT_READY
	match shape:
		"long", "cluster":
			# Hanging bunches under the crown: bananas point up in hands, dates hang in strings.
			for b in (1 if shape == "long" else 3):
				var a := TAU * b / 3.0 + rng.randf()
				var at := centre + Vector3(cos(a) * cr * 0.3, -0.08 * k, sin(a) * cr * 0.3)
				if shape == "long":   # (a banana's one bunch hangs on the side the farm is seen from)
					at = centre + SEEN_FROM.rotated(Vector3.UP, -root.rotation.y) * BUNCH_OUT * k + Vector3(0, -0.08 * k, 0)
				ModelKit.box(root, at + Vector3(-0.006, -0.05, -0.006) * k, at + Vector3(0.006, 0.02, 0.006) * k,
					ModelKit.paint(Color("#6a5a2a")))
				for i in (8 if shape == "long" else 6):
					var ring := TAU * i / 6.0
					var wide := BUNCH_WIDE if shape == "long" else 0.035
					var p := at + Vector3(cos(ring) * wide, -0.06 - 0.025 * int(i / 3.0), sin(ring) * wide) * k * size
					var turn := fposmod((b * 8 + i) * TURN_STEP, 1.0)
					if shape == "long":
						ModelKit.mark_fruit(ModelKit.ball(root, p, BANANA_R * k * size, mat, Vector3(1, 2.6, 1)), turn)
					else:
						ModelKit.mark_fruit(ModelKit.ball(root, p, 0.016 * k * size, mat), turn)
		"big":
			# Huge fruit growing straight off the trunk and the lowest limbs.
			for i in 4:
				var a := TAU * i / 4.0 + rng.randf() * 0.4
				var p := Vector3(cos(a) * 0.09 * k, centre.y * rng.randf_range(0.35, 0.7), sin(a) * 0.09 * k)
				ModelKit.mark_fruit(ModelKit.ball(root, p, 0.06 * k * size, mat, Vector3(0.85, 1.25, 0.85)), i / 4.0)
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
					# Fruit is dotted all over the crown's face, each its own size, where it shows (as FarmVille's was),
					# in the leaves: none hangs under the crown on a stem (owner, 19 Nov).
					var blob: Array = blobs[i % blobs.size()]
					var face := float(blob[2]) + (i / 3) * 0.7 + rng.randf_range(-0.35, 0.35)
					fruit_r = r * rng.randf_range(0.8, 1.15)
					var dir := Vector3(cos(face), rng.randf_range(-0.1, 0.9), sin(face)).normalized()
					dir.y *= float(blob[3])   # (a clump is flatter than it is wide: the fruit sits in its skin)
					p = (blob[0] as Vector3) + dir * float(blob[1]) * FRUIT_OUT
					fruit_mat = shades[0 if dir.y > 0.55 else (1 if dir.y > 0.12 else 2)]
				if str(sh["form"]) == "palm":
					# Coconuts cluster under the fronds, against the trunk: smaller than a crown's fruit, or the
					# cluster is one ball.
					fruit_r = r * PALM_NUT
					p = centre + Vector3(cos(a) * PALM_RING * k, -0.06 * k, sin(a) * PALM_RING * k)
				ModelKit.fruit_ball(root, p, fruit_r, fruit_mat, Vector3(1, 1.3, 1) if shape == "oval" else Vector3.ONE,
					shape == "small", fposmod(i * TURN_STEP, 1.0))
