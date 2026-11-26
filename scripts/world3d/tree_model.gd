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
const FORK_STEMS := 2         # a shrubby tree's trunk forks into this many more stems..
const FORK_LOW := 0.1         # ..between this share of its height..
const FORK_HIGH := 0.25       # ..and this
const FORK_SPREAD := 0.45     # each reaching out this far under the crown, of its radius
const FORK_THIN := 0.9       # and this much thinner than the trunk
const FORK_TURN_VARY := 0.6   # radians each is turned off its even spacing
const TRUNK_TAPER := 0.85     # a trunk is a thin straight pole: its top is this much of its foot
const TRUNK_LEAN := 0.03      # and it leans no more than this (radians)
const META_SHARE := &"trunk_share"   # on a built tree: the share of its height that is bare trunk
const META_REACH := &"crown_reach"   # and how far its crown reaches from the trunk, of the tree's size
const META_FAR := TreeSpec.META_FAR   # and what its far look needs (TreeSpec)
const FAR_LUMPS := 3            # a tree seen from far: its crown is this many soft lumps round the main one
const LEAF_HUE_VARY := 0.04   # how far a tree's leaf colour may drift round its kind's, in hue
const SEEN_FROM := Vector3(0.7071, 0, 0.7071)   # the side of a tree the farm's camera sees
const FRUIT_BEHIND := -0.35   # a crown's fruit facing further from the camera than this (a cosine) is hidden by it..
const FRUIT_TOP := 0.45       # ..unless it sits this high on its clump (the camera looks down on the crown's top)
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
const FROND_DEEP := 0.5    # how much of a variety's darkening its fronds take (a flat leaf has no lit side)
const LEAFLETS_FEWEST := 6   # pairs of leaflets on a frond in the thickest crowd
const STARS := 22            # stars on a Galaxy tree's crown..
const STARS_FEWEST := 8      # ..in the thickest crowd
const STAR_R := Vector2(0.026, 0.046)   # a star's radius, of the tree's size
const STAR_REACH := 0.3      # how far round a palm's head its stars stand, of the tree's size
const FRUIT_READY := 14     # fruit on a full tree (they come one at a time as it ripens: _fruit): few and big, so
const FRUIT_R := 0.093      # ..each reads as a fruit (owner, 19 Nov). A round one's radius on a full-size tree..
const FRUIT_SMALL_R := 0.029  # ..and a small one's (cherries, olives: three times as many)
const PALM_NUT := 0.6       # a palm's nuts, of a round fruit's size, in a ring..
const PALM_RING := 0.075    # ..this far out from the trunk (of the tree's size)
const FRUIT_OUT := 1.04     # how far out through a leafy clump one sits (1: on its skin). Just inside, so the leaves
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
const MIN_LEAF_SATURATION := 0.5   # no tree washes out to pale grey-green
const WILLOW_SPRAYS_FEWEST := 16   # ..in the thickest crowd
const SPRAYS := 300           # leaf sprays over a whole crown (those the camera never sees are not made)
const SPRAYS_FEWEST := 150    # ..in the thickest crowd
const SPRAY_FAN := 5          # pointed leaves in one spray
const SPRAY_LEAF := 0.19      # a leaf's length, of its crown's radius..
const SPRAY_LEAF_VARY := Vector2(0.85, 1.25)   # ..each its own
const SPRAY_SPREAD := 1.9     # a spray fans this far (radians) to each side of straight up the crown
const SPRAY_TILT := 0.38      # how far its leaves lift off the crown (0: flat on it)
const SPRAY_DOWN := 1.72      # how far down a crown the sprays go (2: to its very underside)
const SPRAY_SKIN := 0.97      # where a spray is rooted, of the way out to the crown's skin..
const SPRAY_INSIDE := 0.9     # ..and where the plain shape under the sprays is
const SPRAY_UNSEEN := 0.08    # a spray facing the camera less than this (a cosine) is not made: round the back it
							# showed past the outline as a loose ring of leaves (owner, 26 Nov)
const SPRAY_COVERED := 0.1    # on a side a neighbour stands by, sprays lower than this (of the crown's height) are
							# not made: its crown hides them
const SPRAY_WIDE := 1.2       # a crown's radius, of its kind's `crown_r`..
const SPRAY_SQUAT := 0.744    # ..and its half height, of that radius, on a round tree
const SPRAY_ASPECT := 0.52    # the height to width a round tree's numbers come to (a taller kind: a taller crown)..
const SPRAY_TALL := Vector2(0.72, 1.06)   # ..within this much squatter or taller than the round tree's
const GROVE_SHADE := 0.4      # how much of a grove's shade a crown's paint takes (all of it painted it near black)
const CROWN_SEAT := 0.78      # a crown's middle is this much of its half height above the trunk's top
const SWELL := Vector3(0.1, 0.07, 0.06)   # a crown's own swells: broad ones round it, finer ones, and up it
const SWELL_MOST := 1.2       # the furthest any of them pushes its skin out
const HANG_BELOW := 0.35      # a willow's sprays lower than this (of the crown's height) hang down..
const HANG_LONGER := 1.5      # ..and are this much longer
const WILLOW_SPRAYS := 40     # sprays on one of a willow's hanging masses
const HUE_PATCHES := 3.0      # a variety's leaf colours lie over its crown in about this many patches round it
const CROWN_FRUIT := 0.62     # fruit on a leafy crown is this much of FRUIT_R: small and many, as painted on it
const FRUIT_SIDES := 5        # a crown's fruit is dealt out over this many sides of it
# A crown's paint: five flat tones of its leaf colour, deepest shade first (each a share of the colour's value and
# saturation and a drift of its hue: shade leans blue-green, sun yellow-green), and the light that picks one.
const TONE_VALUE: Array[float] = [0.74, 0.87, 1.0, 1.2, 1.44]
const TONE_SATURATION: Array[float] = [1.05, 1.03, 1.0, 0.95, 0.85]
const TONE_HUE: Array[float] = [0.02, 0.01, 0.0, -0.015, -0.03]
const TONE_EDGE := Vector2(0.43, 0.57)   # where between two tones one gives way to the next: nearly a hard step
const LEAF_SEEN := 0.86                  # a crown's middle tone, of its kind's leaf colour in value..
const LEAF_VALUE := Vector2(0.6, 0.8)    # ..kept within this (none near black: its edge read as black lines)..
const DEEP_SHARE := 0.4                  # how much of a variety's `darken` its crown's paint takes (all of it: black)
const LEAF_SATURATION_MAX := 0.82        # ..and no more saturated than this
const SPRAY_LIGHT := 0.6      # how lit a spray is: this..
const SPRAY_UP := 0.26        # ..more facing up..
const SPRAY_SUN := 0.36       # ..more facing the sun..
const SPRAY_VARY := 0.12      # ..each a little its own..
const SPRAY_UNDER := 0.06     # ..a little less low on the crown..
const SPRAY_DARKEST := 0.3    # ..and never less than this
const SPRAY_STEM := -0.07     # within a leaf: its stem is darker by this, its shoulders lighter by..
const SPRAY_EDGE := 0.02
const SPRAY_TIP := 0.2        # ..and its tip lighter by this
const INSIDE_SEGMENTS := 14   # the plain shape under the sprays: its grid round..
const INSIDE_RINGS := 8       # ..and up
const INSIDE_LIGHT := Vector2(0.42, 0.08)   # how lit it is painted (seen only in the gaps), and how much more up top
const GOLDEN_TURN := 2.399963 # each spray is this far round from the one before: evenly over the crown, in no rows
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


## The colours tree `it` of look `seed_value` is painted in, of its kind's own (`sh`: its shape): [its leaves'
## before they are toned, its fruit's]. Chosen on a stream of their own, so choosing colours never moves the
## tree's shape, and so what falls from a tree can be drawn in its colours without building it (TreeLife).
static func picks(it: Dictionary, sh: Dictionary, seed_value: int) -> Array[Color]:
	var colours := RandomNumberGenerator.new()
	colours.seed = seed_value * 7919 + hash(str(it.get("id", ""))) + COLOUR_SEED
	var leaf_col := _pick(sh, "leaf", "leaf_alts", LEAF.to_html(), colours)
	return [leaf_col, _pick(sh, "", "fruit_alts", "#d93b30", colours, str(it.get("color", "")))]


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
	var picked := picks(it, sh, seed_value)
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
	var leaf_col := leaf if leaf.a > 0.0 else picked[0]
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
	var t := {"root": root, "rng": rng, "k": k, "sh": sh, "crowd": crowd, "mask": mask, "leaf": leaf_col, "tall": tall,
		"hues": hues, "hue": 0, "deep": float(variety.get("darken", 0.0)),
		"pale": float(variety.get("pale", MIN_LEAF_SATURATION)),
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
		_fruit(t, crown, picked[1])
	if variety.has("stars"):
		_stars(t, crown, Color.html(str(variety["stars"])))
	ModelKit.sway_all(root, SWAY)
	ModelKit.touch_all(root, str(it.get("touch", "")))
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
	ModelKit.ball(out, mid, 1.0, ModelKit.paint(as_paint(tones(leaf)[2])), Vector3(reach * 0.8, half, reach * 0.8), true)
	for i in FAR_LUMPS:
		var a := TAU * i / FAR_LUMPS
		var at := mid + Vector3(cos(a) * reach * 0.38, half * (0.25 if i == 0 else -0.1), sin(a) * reach * 0.38)
		ModelKit.ball(out, at, 1.0, ModelKit.paint(as_paint(tones(leaf)[3 if i == 0 else 1])),
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
	var centre := _crown(t, Vector3.ZERO)
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
	_stems(t)
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


## How far out a crown's skin is along `d` (1: its plain ellipsoid): a few broad swells of this tree's own (`ph`:
## where they fall) and its kind's shape. One crown with an uneven outline, never separate balls (owner, 26 Nov).
static func _swell(d: Vector3, ph: Vector3, sh: Dictionary) -> float:
	var around := atan2(d.z, d.x)
	var r := 1.0 + SWELL.x * sin(3.0 * around + ph.x) * (1.0 - d.y * d.y) \
		+ SWELL.y * sin(5.0 * around + ph.y + d.y * 3.0) + SWELL.z * sin(d.y * 5.0 + ph.z)
	match str(sh.get("shape", "round")):
		"teardrop":
			r *= 1.08 - 0.4 * smoothstep(-0.2, 1.0, d.y)
		"layers":
			r *= 1.0 + 0.1 * sin(d.y * 8.0 + 1.0)
	match str(sh.get("form", "round")):
		"weeping":
			r *= 1.0 + 0.22 * smoothstep(0.1, -0.8, d.y)
		"spreading":
			r *= 1.0 - 0.25 * smoothstep(0.0, -1.0, d.y)
	return r


## The flat tones a crown of leaf colour `leaf` is painted in, deepest shade first (TONE_VALUE). `deep` darkens
## them all (a variety's `darken`); `pale`: the least saturation it is painted with (a pastel variety asks for less).
static func tones(leaf: Color, deep := 0.0, pale := MIN_LEAF_SATURATION) -> Array[Color]:
	var s := minf(maxf(leaf.s, pale), LEAF_SATURATION_MAX)
	var v := clampf(leaf.v * LEAF_SEEN, LEAF_VALUE.x, LEAF_VALUE.y)
	var out: Array[Color] = []
	for i in TONE_VALUE.size():
		out.append(Color.from_hsv(fposmod(leaf.h + TONE_HUE[i], 1.0), minf(s * TONE_SATURATION[i], 1.0),
			minf(v * TONE_VALUE[i], 1.0)).darkened(deep * DEEP_SHARE))
	return out


## The tone of `set` for how lit a point is (0 deep shade .. 1 full sun): flat steps with a short blend between.
static func _tone_at(set: Array, light: float) -> Color:
	var x := clampf(light, 0.0, 0.999) * (set.size() - 1)
	var i := int(x)
	return (set[i] as Color).lerp(set[i + 1], smoothstep(TONE_EDGE.x, TONE_EDGE.y, x - i))


## A crown tone as a plain paint must be given it to look the same (the crown's own shader deepens what it is
## given: ModelKit.SPRAY_DEPTH): for the same tree seen from far, which is plain shapes.
static func as_paint(c: Color) -> Color:
	var k := pow(ModelKit.SPRAY_DEPTH, 1.0 / ModelKit.SPRAY_CURVE)
	return Color(c.r * k, c.g * k, c.b * k)


## The leafy crown: one rounded mass of its kind's width and height, shingled all over in leaf sprays (`_sprayed`),
## as the classic farm games paint a tree. Returns its middle (over a trunk top at the origin).
static func _crown(t: Dictionary, centre: Vector3) -> Vector3:
	var k: float = t["k"]
	var sh: Dictionary = t["sh"]
	var cr := float(sh["crown_r"]) * k
	# (its kind's shape, not this tree's own tallness: one tree stands taller than the next by its trunk)
	var slim := sqrt(maxf(float(sh["crown_h"]) * k / float(t["tall"]) / cr, 0.01) / SPRAY_ASPECT)
	var wide := cr * SPRAY_WIDE * clampf(SPRAY_TALL.y / slim, SPRAY_TALL.x, 1.0)
	var high := cr * SPRAY_WIDE * SPRAY_SQUAT * clampf(slim, SPRAY_TALL.x, SPRAY_TALL.y)
	var radii := Vector3(wide, high, wide)
	var mid := Vector3(centre.x, high * CROWN_SEAT, centre.z)
	# In a grove the crown is in its neighbours' shade.
	var shaded := float(t["crowd"]) * Crowding.setting("tree", "shade")
	t["swell"] = _sprayed(t, mid, radii, ModelKit.scaled(SPRAYS, SPRAYS_FEWEST), wide * SPRAY_LEAF, -shaded * GROVE_SHADE,
		str(sh["form"]) == "weeping")
	# (its swells push its sides out; its top may sit a little under its plain shape's, and is counted so)
	_measure(t, mid, Vector3(wide * SWELL_MOST, high * SPRAY_SKIN * (1.0 - SWELL.z), wide * SWELL_MOST))
	for i in FRUIT_SIDES:
		(t["blobs"] as Array).append([mid, wide, TAU * i / FRUIT_SIDES, high / wide])
	return mid


## Counts one leafy mass (centre and half-sizes) into the crown's real extent: its lowest and highest leaves and
## how far it reaches from the trunk's line.
static func _measure(t: Dictionary, at: Vector3, radii: Vector3) -> void:
	t["low"] = minf(float(t["low"]), at.y - radii.y)
	t["high"] = maxf(float(t["high"]), at.y + radii.y)
	t["reach"] = maxf(float(t["reach"]), Vector2(at.x, at.z).length() + maxf(radii.x, radii.z))


## One leafy mass painted the farm's way: a plain shape underneath, seen only in the gaps, shingled all over in
## leaf sprays, each a fan of pointed leaves (stem, two shoulders, tip) lapping over the spray below, lighter where
## the sun falls and at every tip. One mesh and one draw, with no see-through cards. `leaf_len`: a leaf's length;
## `lift` brightens it all; `hang`: its lower sprays hang down (a willow). Sprays round the back, which the farm's
## camera never sees, and low on a side a neighbour hides are not made. Returns where its swells fall (`_swell`).
static func _sprayed(t: Dictionary, at: Vector3, radii: Vector3, count: int, leaf_len: float, lift: float,
		hang := false) -> Vector3:
	var root: Node3D = t["root"]
	var rng: RandomNumberGenerator = t["rng"]
	var sh: Dictionary = t["sh"]
	var turn := float(root.rotation.y)   # (the tree is turned at random, the sun and the camera are not)
	var sun := Vector3(-0.45, 0.75, 0.5).normalized().rotated(Vector3.UP, -turn)
	var seen := (SEEN_FROM * cos(IsoProjection.PITCH) + Vector3.UP * sin(IsoProjection.PITCH)).rotated(Vector3.UP, -turn)
	var ph := Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU
	var paints: Array = []
	for hue: Color in t["hues"]:
		paints.append(tones(hue, float(t["deep"]), float(t["pale"])))
	if paints.is_empty():
		paints.append(tones(t["leaf"], float(t["deep"]), float(t["pale"])))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var seg := ModelKit.scaled(INSIDE_SEGMENTS, 8)
	var rings := ModelKit.scaled(INSIDE_RINGS, 5)
	for j in rings + 1:
		var phi := PI * float(j) / rings
		for i in seg + 1:
			var th := TAU * float(i) / seg
			var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			verts.append(d * radii * _swell(d, ph, sh) * SPRAY_INSIDE)
			norms.append((d / radii).normalized())
			cols.append(_tone_at(paints[0], INSIDE_LIGHT.x + INSIDE_LIGHT.y * d.y + lift))
	for j in rings:
		for i in seg:
			var a := j * (seg + 1) + i
			var b := a + seg + 1
			idx.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	for k in count:
		var y := 1.0 - SPRAY_DOWN * (k + 0.5) / count
		var r := sqrt(1.0 - y * y)
		var ang := k * GOLDEN_TURN + rng.randf() * 0.3
		var d := Vector3(cos(ang) * r, y, sin(ang) * r)
		var n := (d / radii).normalized()
		if n.dot(seen) < SPRAY_UNSEEN or (y < SPRAY_COVERED and Crowding.covered(int(t["mask"]), ang - turn)):
			continue
		var p := d * radii * _swell(d, ph, sh) * SPRAY_SKIN
		var up := Vector3.UP - n * n.y
		up = (Vector3(cos(ang), 0, sin(ang)) if up.length_squared() < 0.03 else up).normalized()
		var hanging := hang and y < HANG_BELOW
		if hanging:
			up = -up
		var side := n.cross(up).normalized()
		var paint: Array = paints[posmod(floori(ang / TAU * HUE_PATCHES + y * 1.5 + ph.x), paints.size())]
		var lit := maxf(SPRAY_LIGHT + SPRAY_UP * n.y + SPRAY_SUN * n.dot(sun) + rng.randf_range(-SPRAY_VARY, SPRAY_VARY)
			- SPRAY_UNDER * smoothstep(0.3, -0.5, y) + lift, SPRAY_DARKEST)
		for f in SPRAY_FAN:
			# (a spray on the very top fans all the way round; one on the side fans up and out)
			var a := TAU * f / SPRAY_FAN if n.y >= 0.9 \
				else lerpf(-SPRAY_SPREAD, SPRAY_SPREAD, (f + rng.randf_range(0.2, 0.8)) / SPRAY_FAN)
			var along := (up * cos(a) + side * sin(a) + n * SPRAY_TILT).normalized()
			var across := along.cross(n).normalized()
			var size := leaf_len * rng.randf_range(SPRAY_LEAF_VARY.x, SPRAY_LEAF_VARY.y) * (HANG_LONGER if hanging else 1.0)
			var first := verts.size()
			verts.append(p)
			verts.append(p + along * size * 0.48 - across * size * 0.36 + n * size * 0.15)
			verts.append(p + along * size * 0.48 + across * size * 0.36 + n * size * 0.15)
			verts.append(p + along * size * 0.92 + n * size * 0.25)
			for own: float in [SPRAY_STEM, SPRAY_EDGE, SPRAY_EDGE, SPRAY_TIP]:
				norms.append(n)
				cols.append(_tone_at(paint, lit + own))
			idx.append_array(PackedInt32Array([first, first + 1, first + 2, first + 1, first + 3, first + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.material_override = ModelKit.sprays()   # (painted: a glossy kind's shine washed its tones out)
	root.add_child(mi)
	return ph


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
	var shaded := float(t["crowd"]) * Crowding.setting("tree", "shade")
	var n := ModelKit.scaled(WILLOW_FALLS, 5)
	for i in n:
		var a := TAU * i / n + rng.randf_range(-WILLOW_TURN_VARY, WILLOW_TURN_VARY)
		if Crowding.covered(int(t["mask"]), a - root.rotation.y):
			continue
		var long := cr * WILLOW_FALL * rng.randf_range(WILLOW_FALL_VARY_MIN, WILLOW_FALL_VARY_MAX)
		var at := centre + Vector3(cos(a) * cr * WILLOW_RIM, -long * 0.5, sin(a) * cr * WILLOW_RIM)
		var radii := Vector3(cr * WILLOW_FALL_W, long * 0.5, cr * WILLOW_FALL_W)
		_sprayed(t, at, radii, ModelKit.scaled(WILLOW_SPRAYS, WILLOW_SPRAYS_FEWEST), cr * SPRAY_WIDE * SPRAY_LEAF,
			WILLOW_LIFT - shaded * GROVE_SHADE, true)
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
			reach * float(sh["leaflet"]), pairs,
			_leaf_of(t).darkened(float(t["deep"]) * FROND_DEEP + rng.randf_range(0.0, FROND_SHADE)),
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
			_leaf_of(t).darkened(float(t["deep"]) * FROND_DEEP + rng.randf_range(0.0, FROND_SHADE)), rng.randf())
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
					fruit_r = r * rng.randf_range(0.8, 1.15) * (1.0 if shape == "small" else CROWN_FRUIT)
					var dir := Vector3(cos(face), rng.randf_range(-0.1, 0.9), sin(face)).normalized()
					var out := FRUIT_OUT * (_swell(dir, t["swell"], sh) if t.has("swell") else 1.0)
					dir.y *= float(blob[3])   # (a crown is flatter than it is wide: the fruit sits in its skin)
					p = (blob[0] as Vector3) + dir * float(blob[1]) * out
					fruit_mat = shades[0 if dir.y > 0.55 else (1 if dir.y > 0.12 else 2)]
					# A fruit round the back of the crown is never seen (the farm's camera does not turn) and a
					# tree's fruit is never made simpler with distance, so it is not made at all.
					var seen := SEEN_FROM.rotated(Vector3.UP, -root.rotation.y)
					if dir.y < FRUIT_TOP and Vector2(dir.x, dir.z).normalized().dot(Vector2(seen.x, seen.z)) < FRUIT_BEHIND:
						continue
				if str(sh["form"]) == "palm":
					# Coconuts cluster under the fronds, against the trunk: smaller than a crown's fruit, or the
					# cluster is one ball.
					fruit_r = r * PALM_NUT
					p = centre + Vector3(cos(a) * PALM_RING * k, -0.06 * k, sin(a) * PALM_RING * k)
				ModelKit.fruit_ball(root, p, fruit_r, fruit_mat, Vector3(1, 1.3, 1) if shape == "oval" else Vector3.ONE,
					shape == "small", fposmod(i * TURN_STEP, 1.0))
