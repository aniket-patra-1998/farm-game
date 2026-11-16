class_name BloomModel
extends RefCounted
## A Bloom in 3D, each kind its own flower: a rose is a cup of layered petals, a tulip an egg of six, a daisy a
## ring of white rays round a yellow button, a sunflower a dark disc in two rows of rays, a lily six long petals
## curling back round its stamens, an iris three standards up and three falls down. A Single Bloom is one tall
## flower on its leafy stem; a Full Bloom a bunch of five that fills its tile. Each kind has its own leaves too
## (a tulip's straps, a sunflower's hearts, an iris's swords). Built from the catalog's colour and accent.
##
## One model holds a bloom's whole life: its heads are built open, and the bloom's shader (bloom3d) shows each
## one as a closed green bud that opens at its turn in the cycle, and wilts the whole plant little by little
## when it is left too long (ModelKit.mark_bloom says which head each part belongs to). So a bloom is never
## rebuilt when it comes ready or withers; Objects3D tells it its cycle (`ripen`).
## Petals and leaves are small cupped blades (a dozen triangles each, made once and shared), not balls.

const STEM := Color("#4f8a34")
const LEAF := Color("#2f6e24")            # a leaf at its foot..
const LEAF_TIP := Color("#5fa83a")        # ..and at its tip
const BLUE_LEAF := Color("#3f8253")       # a tulip's and an iris's leaves: a bluer green
const BLUE_LEAF_TIP := Color("#74b77a")
const ANTHER := Color("#a84a14")          # the pollen on a lily's stamens
const STEMS_FULL := 7                     # flowers in a Full Bloom: one in the middle, the rest round it
const STEMS_SINGLE := 2                   # flowers in a Single Bloom: its own, and a smaller one beside it
const FULL_SPREAD := 0.1                  # how far from the middle a Full Bloom's outer stems stand, in tiles
const FULL_LEAN := 0.2                    # and how far they lean outward, in radians
const FULL_TALL := 1.25                   # a Full Bloom's stems against a Single's: a tall bunch, not a wide one..
const FULL_HEAD := 0.75                   # ..of heads this much of a Single's, so seven stand inside one tile
const FULL_LEAF := 0.7                    # and its outer stems' leaves, against a Single's
const SIDE_OUT := 0.1                     # a Single Bloom's second stem stands this far from the main one..
const SIDE_LEAN := 0.55                   # ..leaning out this much (radians), to one side as the camera sees it..
const SIDE_TALL := 0.5                    # ..this tall against it..
const SIDE_SIZE := 0.55                   # ..and its flower is this much of the main one
const RIM := 0.0                          # a blade's `reach` when only its rim takes the tip's colour (a rose's)
const SIDEWAYS := Vector3(0.7, 0.0, -0.7)   # across the camera's view
const TOWARDS := Vector3(0.7, 0.0, 0.7)   # the side a flower turns its face to: the camera's
const NOT_A_HEAD := -1.0                  # the turn a stem or a leaf is marked with (ModelKit.mark_bloom)
const FIRST_TURN := 0.35                  # a Full Bloom's first head opens at this turn, its last at 1
const VEIN := 1.18                        # a leaf's midrib, against the leaf (lighter)
const CREASE := 0.82                      # a petal's midrib, against the petal (darker)

# Each kind's measures for a bloom of size 1, in tiles: its head's radius, its stem's height and thickness, and
# how far its face tilts from straight up (radians). Heads are big: a bloom is its flower.
const FORMS := {
	"rose": {"head": 0.2, "height": 0.5, "stem": 0.02, "tilt": 0.45},
	"tulip": {"head": 0.13, "height": 0.48, "stem": 0.022, "tilt": 0.1},
	"daisy": {"head": 0.21, "height": 0.46, "stem": 0.016, "tilt": 0.65},
	"sunflower": {"head": 0.27, "height": 0.62, "stem": 0.03, "tilt": 0.85},
	"lily": {"head": 0.24, "height": 0.54, "stem": 0.02, "tilt": 0.6},
	"iris": {"head": 0.19, "height": 0.52, "stem": 0.02, "tilt": 0.2},
}

# The blades: [where along it is widest, how pointed its end (0 round, 1 a point), how cupped across, how much
# it curls along its length (up, or down when negative), how many rows of two quads it is made of].
const BLADES := {
	"round": [0.6, 0.0, 0.55, 0.3, 4],        # a rose's petal, an iris's standard, a sunflower's leaf
	"pointed": [0.45, 0.8, 0.6, 0.1, 4],      # a tulip's petal
	"ray": [0.6, 0.3, 0.2, 0.06, 2],          # a daisy's and a sunflower's rays, a stamen (many, so lighter)
	"recurved": [0.4, 0.9, 0.35, -0.55, 4],   # a lily's petal, curling back
	"fall": [0.62, 0.15, 0.3, -0.45, 4],      # an iris's fall, hanging
	"leaf": [0.42, 1.0, 0.3, -0.3, 3],
	"strap": [0.35, 0.8, 0.55, -0.15, 3],     # a tulip's and an iris's long leaves
}

static var _blades := {}   # blade name and colours -> its mesh (made once)


## Builds the bloom standing on `at` in `parent`: `full` a Full Bloom's bunch, else one flower. `seed_value`
## gives its small differences; `mask` says which sides have neighbours (Crowding: fewer, taller stems).
static func build_at(parent: Node3D, at: Vector3, it: Dictionary, size: float, full: bool, seed_value: int,
		mask := 0) -> void:
	var crowd := Crowding.share_of(mask)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kind := kind_of(it)
	var form: Dictionary = FORMS[kind]
	var col := Color.html(str(it.get("color", "#d6304a")))
	var accent := Color.html(str(it.get("accent", "#f2c94c")))
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)
	var stems := maxi(3, roundi(ModelKit.scaled(STEMS_FULL, 4) * (1.0 - 0.4 * crowd))) if full else 1
	var turn_around := rng.randf() * TAU
	for k in stems:
		var a := turn_around + TAU * k / maxi(stems - 1, 1)
		var out := Vector3(cos(a), 0, sin(a)) if (full and k > 0) else Vector3.ZERO
		var h := float(form["height"]) * (1.0 + rng.randf_range(-0.05, 0.05)) * size \
			* (1.0 + Crowding.setting("bloom", "lift") * crowd)
		if full:
			h *= FULL_TALL * (1.1 if k == 0 else (0.74 if k % 2 == 0 else 0.92))
		var flower := Node3D.new()
		flower.position = out * FULL_SPREAD * size
		if k > 0:
			flower.rotation = Vector3(out.z, 0, -out.x) * FULL_LEAN   # (leaning out from the middle, like a bunch)
		root.add_child(flower)
		var turn := 1.0 if stems == 1 else lerpf(FIRST_TURN, 1.0, float(k) / (stems - 1))
		if full:
			_stem(kind, flower, h, size * FULL_HEAD, col, accent, turn, out, form, rng, 1.0 if k == 0 else 0.6,
				1.0 if k == 0 else FULL_LEAF, true)
		else:
			_stem(kind, flower, h, size, col, accent, turn, out, form, rng, 1.0)
			# A Single Bloom's second, smaller flower on a shorter stem beside it: it opens before the main one.
			var to := (SIDEWAYS * (1.0 if rng.randf() < 0.5 else -1.0) + TOWARDS * 0.35).normalized()
			var side := Node3D.new()
			side.position = to * SIDE_OUT * size
			side.rotation = Vector3(to.z, 0, -to.x) * SIDE_LEAN
			flower.add_child(side)
			_stem(kind, side, h * SIDE_TALL, size * SIDE_SIZE, col, accent, 0.6, to * 0.5, form, rng, 0.0, 1.0, true)
	if full:
		# A Full Bloom stands in a rosette of big leaves, so it is a mass of green under its flowers.
		for k in ModelKit.scaled(8, 4):
			var la := turn_around + TAU * k / 8.0 + 0.3
			_blade_at(root, _leaf_blade(kind), Vector3.ZERO, Vector3(cos(la) * sin(1.05), cos(1.05), sin(la) * sin(1.05)),
				0.34 * size, 0.15 * size, _leaf_col(kind), _leaf_tip(kind), VEIN, NOT_A_HEAD)


## One stem `h` tall standing in `flower`, with its leaves (`leafy`: how many of its usual leaves, 0..1) and its
## head on top, facing the camera and, for a stem that leans `out`, outward too. `leaf_size`: its leaves' size
## against the kind's own. `light`: its head is one of a bunch, or a small one (see `_head`).
static func _stem(kind: String, flower: Node3D, h: float, size: float, col: Color, accent: Color, turn: float,
		out: Vector3, form: Dictionary, rng: RandomNumberGenerator, leafy: float, leaf_size := 1.0,
		light := false) -> void:
	var r := float(form["stem"]) * size
	ModelKit.mark_bloom(ModelKit.cylinder(flower, Vector3.ZERO, r, h, ModelKit.bloom_paint(STEM), r * 0.7, 6),
		NOT_A_HEAD)
	if leafy > 0.0:
		_leaves(kind, flower, h, size * leaf_size, rng, leafy)
	var head := Node3D.new()
	head.position = Vector3(0, h, 0)
	var face := (TOWARDS + out * 0.7).normalized()
	head.rotation = Vector3(face.z, 0, -face.x) * float(form["tilt"])
	head.rotate_object_local(Vector3.UP, rng.randf() * TAU)
	flower.add_child(head)
	_head(kind, head, float(form["head"]) * size, col, accent, turn, light)


## A bloom on the farm, as its own baked model (`look`: the variant its small differences come from, or its uid).
static func build(it: Dictionary, o: Dictionary, scale := 1.0, look := -1) -> Node3D:
	var holder := Node3D.new()
	var d := Game.catalog.get_def(str(it.get("id", ""))) as BloomDef
	build_at(holder, Vector3(0.5, 0, 0.5), it, 1.6 * scale, d != null and d.is_full(),
		look if look >= 0 else int(o.get("uid", 0)), Crowding.mask(o))
	return ModelKit.bake(holder)


## Which flower an item is: the first word of its id ("rose_full_bloom" -> "rose"); a rose when unknown.
static func kind_of(it: Dictionary) -> String:
	var kind := str(it.get("id", "")).get_slice("_", 0)
	return kind if FORMS.has(kind) else "rose"


## The flower head of a kind, built open about `head`'s origin, facing up its y: radius `r`. Petals shade from
## their foot to their tip and carry a darker crease, so a head has depth and is not one flat colour. A `light`
## head (one of a Full Bloom's seven, a Single's small second flower) leaves out what a bunch hides or a small
## head doesn't show: the second row of rays, the sepals behind, half the stamens.
static func _head(kind: String, head: Node3D, r: float, col: Color, accent: Color, turn: float, light: bool) -> void:
	match kind:
		"rose":   # a cup of layered petals: a tight heart, then rings opening outward, on green sepals
			# (Each petal is dark but for its rim, so one shows against the next and the layers read.)
			var deep := col.darkened(0.5)
			var heart := col.darkened(0.3)   # (the heart is lighter than the petals' feet, so it is not a dark hole)
			_ball(head, Vector3(0, r * 0.32, 0), r * (0.36 if light else 0.3), heart, turn, Vector3(1, 1.15, 1))
			if not light:
				_ring(head, "round", 5, 0.22, r * 0.8, r * 0.82, heart, col, turn, 0.0, r * 0.1, 0.0, 1.0, RIM)
			_ring(head, "round", 5, 0.62, r * 0.95, r * 1.0, heart, col.lightened(0.1), turn, 0.5, r * 0.1, 0.0, 1.0, RIM)
			_ring(head, "round", 6, 1.0, r * 1.05, r * 1.05, deep, col.lightened(0.2), turn, 0.2, r * 0.1, 0.0, 1.0, RIM)
			_ring(head, "round", 7, 1.34, r * 1.1, r * 1.1, col.darkened(0.4), col.lightened(0.32), turn, 0.6, r * 0.08, 0.0,
				1.0, RIM)
			if not light:
				_ring(head, "leaf", 5, 2.0, r * 0.6, r * 0.22, LEAF, LEAF_TIP, turn, 0.3, r * 0.05)
		"tulip":   # an egg of six pointed petals, three inside three, warm at the foot
			var foot := accent.lerp(col, 0.25)
			_ring(head, "pointed", 3, 0.13, r * 2.3, r * 1.55, foot, col.lightened(0.14), turn, 0.0, r * 0.2)
			_ring(head, "pointed", 3, 0.26, r * 2.2, r * 1.6, foot, col.darkened(0.05), turn, PI / 3.0, r * 0.22)
		"daisy":   # white rays (two rows of them) round a domed yellow button
			var shade := col.lerp(accent, 0.18).darkened(0.12)
			_ring(head, "ray", 15, 1.4, r * 1.0, r * 0.33, shade, col, turn, 0.0, r * 0.22)
			_ball(head, Vector3(0, r * 0.06, 0), r * 0.36, accent, turn, Vector3(1, 0.6, 1))
			if not light:
				_ring(head, "ray", 15, 1.5, r * 0.92, r * 0.3, shade, col.darkened(0.06), turn, PI / 15.0, r * 0.2)
				_ball(head, Vector3(0, r * 0.16, 0), r * 0.18, accent.darkened(0.2), turn, Vector3(1, 0.6, 1))
		"sunflower":   # a dark seed disc in rays that start orange (two rows of them), green bracts behind
			var ember := col.lerp(Color("#d9620f"), 0.7)
			_ring(head, "ray", 16, 1.36, r * 0.82, r * 0.28, ember, col, turn, 0.0, r * 0.46)
			_ball(head, Vector3(0, r * 0.03, 0), r * 0.54, accent, turn, Vector3(1, 0.36, 1))
			_ball(head, Vector3(0, r * 0.1, 0), r * 0.3, accent.darkened(0.45), turn, Vector3(1, 0.4, 1))
			if not light:
				_ring(head, "ray", 16, 1.48, r * 0.72, r * 0.28, ember, col.lerp(Color("#f0a020"), 0.4), turn, PI / 16.0,
					r * 0.43)
				_ring(head, "leaf", 8, 1.78, r * 0.62, r * 0.3, LEAF, LEAF_TIP, turn, 0.2, r * 0.3)
		"lily":   # six long petals curling back, pale in the throat with a dark stripe, round long stamens
			var throat := col.lerp(Color.WHITE, 0.55).lerp(accent, 0.25)
			_ring(head, "recurved", 3, 0.9, r * 1.6, r * 0.62, throat, col.darkened(0.05), turn, 0.0, r * 0.08, 0.0, 0.7)
			_ring(head, "recurved", 3, 1.0, r * 1.55, r * 0.56, throat, col.lightened(0.1), turn, PI / 3.0, r * 0.08, 0.0,
				0.7)
			var stamens := 3 if light else ModelKit.scaled(6, 3)
			for k in stamens:
				var a := TAU * k / stamens
				var dir := Vector3(sin(0.42) * cos(a), cos(0.42), sin(0.42) * sin(a))
				_blade_at(head, "ray", Vector3.ZERO, dir, r * 1.0, r * 0.07, accent, accent.lightened(0.2), 1.0, turn)
				_blade_at(head, "leaf", dir * r * 0.95, dir, r * 0.32, r * 0.17, ANTHER, ANTHER.lightened(0.15), 1.0, turn)
		"iris":   # three ruffled standards up, three falls down with a yellow signal at the foot of each
			_ring(head, "round", 3, 0.26, r * 1.5, r * 1.0, col, col.lightened(0.3), turn, 0.0, r * 0.08)
			_ring(head, "fall", 3, 1.9, r * 1.65, r * 1.15, accent, col.darkened(0.12), turn, PI / 3.0, r * 0.12, 0.0, 0.9,
				0.34)
			if not light:
				_ring(head, "leaf", 3, 1.2, r * 0.7, r * 0.3, col.lightened(0.35), col.lightened(0.5), turn, PI / 3.0,
					r * 0.05)


static func _leaf_blade(kind: String) -> String:
	return "strap" if kind in ["tulip", "iris"] else ("round" if kind == "sunflower" else "leaf")


static func _leaf_col(kind: String) -> Color:
	return BLUE_LEAF if kind in ["tulip", "iris"] else LEAF


static func _leaf_tip(kind: String) -> Color:
	return BLUE_LEAF_TIP if kind in ["tulip", "iris"] else LEAF_TIP


## A kind's leaves on a stem `h` tall, standing in `flower`: big, a mass of green (`leafy`: the share of them a
## short side stem carries).
static func _leaves(kind: String, flower: Node3D, h: float, size: float, rng: RandomNumberGenerator,
		leafy: float) -> void:
	var start := rng.randf() * TAU
	match kind:
		"rose":   # oval leaves up the stem, side to side
			for k in maxi(1, roundi(ModelKit.scaled(5, 3) * leafy)):
				_leaf(flower, kind, h * (0.18 + 0.14 * k), start + PI * k + 0.5, 1.05, 0.26 * size, 0.14 * size)
		"tulip":   # broad straps rising from the foot
			for k in maxi(1, roundi(ModelKit.scaled(4, 2) * leafy)):
				_leaf(flower, kind, 0.0, start + TAU * k / 4.0, 0.42, h * 0.85, 0.16 * size)
		"daisy":   # a low tuft, and a few up the stem
			for k in maxi(1, roundi(ModelKit.scaled(6, 3) * leafy)):
				_leaf(flower, kind, h * 0.09 * k, start + 2.4 * k, 1.1, 0.22 * size, 0.09 * size)
		"sunflower":   # big heart-shaped leaves
			for k in maxi(1, roundi(ModelKit.scaled(5, 3) * leafy)):
				_leaf(flower, kind, h * (0.16 + 0.15 * k), start + 2.2 * k, 1.15, 0.34 * size, 0.27 * size)
		"lily":   # many narrow leaves spiralling up
			for k in maxi(2, roundi(ModelKit.scaled(9, 4) * leafy)):
				_leaf(flower, kind, h * (0.08 + 0.09 * k), start + 2.4 * k, 0.95, 0.27 * size, 0.07 * size)
		"iris":   # a fan of swords from the foot
			for k in maxi(1, roundi(ModelKit.scaled(5, 3) * leafy)):
				_leaf(flower, kind, 0.0, start + TAU * k / 5.0, 0.22, h * (0.8 + 0.07 * k), 0.1 * size)


## One leaf on the stem at `height`, pointing out at angle `around` and `tilt` from straight up.
static func _leaf(flower: Node3D, kind: String, height: float, around: float, tilt: float, length: float,
		width: float) -> void:
	var dir := Vector3(sin(tilt) * cos(around), cos(tilt), sin(tilt) * sin(around))
	_blade_at(flower, _leaf_blade(kind), Vector3(0, height, 0), dir, length, width, _leaf_col(kind), _leaf_tip(kind),
		VEIN, NOT_A_HEAD)


## A ring of `count` blades round a head's middle: each `tilt` from straight up (0 upright, a quarter turn flat,
## more hanging down), starting `out` from the middle and `lift` up, the first at angle `start`. Each shades from
## `foot` to `tip` (the foot's colour reaching `reach` of the way along) with its midrib `rib` times as bright.
static func _ring(head: Node3D, blade: String, count: int, tilt: float, length: float, width: float, foot: Color,
		tip: Color, turn: float, start: float, out: float, lift := 0.0, rib := CREASE, reach := 0.7) -> void:
	var n := ModelKit.scaled(count, mini(count, 3))
	for k in n:
		var a := start + TAU * k / n
		var radial := Vector3(cos(a), 0, sin(a))
		_blade_at(head, blade, radial * out + Vector3(0, lift, 0), radial * sin(tilt) + Vector3(0, cos(tilt), 0),
			length, width, foot, tip, rib, turn, reach)


## A blade from `base` along `dir`, `length` long and `width` across, its cupped face turned up and inward,
## shading from `foot` to `tip`. `turn`: the head it belongs to opens at (its middle is the parent's origin), or
## NOT_A_HEAD for a leaf.
static func _blade_at(parent: Node3D, blade: String, base: Vector3, dir: Vector3, length: float, width: float,
		foot: Color, tip: Color, rib: float, turn: float, reach := 0.7) -> void:
	var z := dir.normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var mi := MeshInstance3D.new()
	mi.mesh = blade_mesh(blade, foot, tip, rib, reach)
	mi.transform = Transform3D(Basis(x * width, z.cross(x) * width, z * length), base)
	mi.material_override = ModelKit.bloom_paint(Color.WHITE)   # (its colours are in its points)
	parent.add_child(mi)
	ModelKit.mark_bloom(mi, turn)


## A ball of a head (its heart, its button), opening with it.
static func _ball(head: Node3D, at: Vector3, r: float, col: Color, turn: float, scale := Vector3.ONE) -> void:
	ModelKit.mark_bloom(ModelKit.ball(head, at, r, ModelKit.bloom_paint(col), scale), turn)


## A blade's mesh, made once per shape and colours: lying along +z from its base at the origin, 1 long and 1
## across at its widest, a midrib with an edge either side (rows of two quads), its points shared so it is lit
## as one smooth curved surface. Its shape is BLADES[name]; its points shade from `foot` (as far as `reach` of the
## way along, or only at the rim when `reach` is RIM) to `tip`, the midrib `rib` times as bright (a petal's dark
## crease, a leaf's light vein).
static func blade_mesh(name: String, foot: Color, tip: Color, rib: float, reach := 0.7) -> ArrayMesh:
	var key := "%s|%s|%s|%.2f|%.2f" % [name, foot.to_html(false), tip.to_html(false), rib, reach]
	if _blades.has(key):
		return _blades[key]
	var shape: Array = BLADES[name]
	var waist := float(shape[0])
	var count := int(shape[4])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in count + 1:
		var t := 1.0 - pow(1.0 - float(row) / count, 1.6)   # (rows closer towards the tip: a round end is round)
		var w := lerpf(0.16, 0.5, sin(t / waist * PI / 2.0)) if t <= waist else 0.5 * lerpf(
			sqrt(1.0 - pow((t - waist) / (1.0 - waist), 2.0)), 1.0 - (t - waist) / (1.0 - waist), float(shape[1]))
		var y := float(shape[3]) * t * t
		var col := foot.lerp(tip, t * t * t if reach <= RIM else smoothstep(0.0, reach, t))
		for side in 3:
			st.set_color(Color(col.r * rib, col.g * rib, col.b * rib) if side == 1 else col)
			st.add_vertex(Vector3((side - 1) * w, y + (0.0 if side == 1 else float(shape[2]) * w), t))
	for row in count:
		for side in 2:
			var a := row * 3 + side
			for i: int in [a, a + 4, a + 1, a, a + 3, a + 4]:
				st.add_index(i)
	st.generate_normals()
	_blades[key] = st.commit()
	return _blades[key]
