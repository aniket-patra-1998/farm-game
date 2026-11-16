class_name BloomModel
extends RefCounted
## A Bloom in 3D, each kind its own flower: a rose is a cup of layered petals, a tulip an egg of six, a daisy a
## ring of white rays round a yellow button, a sunflower a dark disc in two rows of rays, a lily six long petals
## curling back round its stamens, an iris three standards up and three falls down. A Single Bloom is one tall
## flower on its leafy stem with a smaller one beside it; a Full Bloom a bunch of seven that fills its tile.
## Each kind has its own leaves too (a tulip's straps, a sunflower's hearts, an iris's swords). Built from the
## catalog's colour and accent.
##
## One model holds a bloom's whole life: its heads are built open, and the bloom's shader (bloom3d) shows each
## one as a closed green bud that opens at its turn in the cycle, and wilts the whole plant little by little
## when it is left too long (ModelKit.mark_bloom says which head each part belongs to). So a bloom is never
## rebuilt when it comes ready or withers; Objects3D tells it its cycle (`ripen`).
##
## Nothing in a flower is ruled: stems bend, heads look a little their own way, no two petals or leaves sit, tilt
## or measure quite alike, and each flower takes its own tone of the kind's colour (all from the bloom's seed, so
## it is the same flower every time it is built).
## Petals and leaves are small cupped blades (a dozen triangles each, made once and shared), not balls.

const STEM := Color("#5a8f42")             # a stem at its top..
const STEM_FOOT := Color("#3d6a30")        # ..and at its foot
const LEAF := Color("#356b2c")            # a leaf at its foot..
const LEAF_TIP := Color("#6aa24a")        # ..and at its tip
const BLUE_LEAF := Color("#42805a")       # a tulip's and an iris's leaves: a bluer green
const BLUE_LEAF_TIP := Color("#7bb284")
const ANTHER := Color("#a8552a")          # the pollen on a lily's stamens
const SOFT := 0.86                        # how strong the catalog's colours are painted: petals aren't paint
const TONES := [[0.0, 1.0], [-0.012, 0.95], [0.012, 1.0], [0.0, 0.91], [0.007, 0.97]]   # a flower's own tone of
                                          # its kind's colour: [hue shift, brightness], picked by its seed
const SHADES := [0.9, 1.0, 1.1]           # and a leaf's own shade of green
const TUBE_SIDES := 5                     # a stem is a bent tube this many sides round
const GOLDEN := 2.39996                   # the angle between one rose petal and the next (as petals really grow)
const STEMS_FULL := 7                     # flowers in a Full Bloom: one in the middle, the rest round it
const STEMS_SINGLE := 2                   # flowers in a Single Bloom: its own, and a smaller one beside it
const FULL_SPREAD := 0.1                  # how far from the middle a Full Bloom's outer stems stand, in tiles
const FULL_LEAN := 0.16                   # and how far they lean outward, in radians (they bend outward too)
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
const VEIN := 1.12                        # a leaf's midrib, against the leaf (lighter)
const CREASE := 0.9                       # a petal's midrib, against the petal (darker)

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
# it curls along its length (up, or down when negative), how many rows it is made of, how far its rim rolls back].
const BLADES := {
	"petal": [0.62, 0.0, 0.6, 0.34, 4, 0.2],        # a rose's petal: a cup with its rim rolled back
	"round": [0.6, 0.0, 0.55, 0.3, 4, 0.06],        # an iris's standard, a sunflower's leaf
	"pointed": [0.45, 0.8, 0.6, 0.12, 4, 0.05],     # a tulip's petal
	"ray": [0.6, 0.3, 0.2, 0.06, 2, 0.0],           # a daisy's and a sunflower's rays, a stamen (many, so lighter)
	"recurved": [0.4, 0.9, 0.35, -0.55, 4, 0.0],    # a lily's petal, curling back
	"fall": [0.62, 0.15, 0.3, -0.45, 4, 0.0],       # an iris's fall, hanging
	"leaf": [0.42, 1.0, 0.3, -0.3, 3, 0.0],
	"strap": [0.35, 0.8, 0.55, -0.15, 3, 0.0],      # a tulip's and an iris's long leaves
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
	var col := soft(Color.html(str(it.get("color", "#d6304a"))))
	var accent := soft(Color.html(str(it.get("accent", "#f2c94c"))))
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)
	var stems := maxi(3, roundi(ModelKit.scaled(STEMS_FULL, 4) * (1.0 - 0.4 * crowd))) if full else 1
	var turn_around := rng.randf() * TAU
	var lift := 1.0 + Crowding.setting("bloom", "lift") * crowd
	for k in stems:
		var a := turn_around + TAU * k / maxi(stems - 1, 1) + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a)) if (full and k > 0) else Vector3.ZERO
		var h := float(form["height"]) * size * lift * rng.randf_range(0.94, 1.06)
		var turn := 1.0 if stems == 1 else lerpf(FIRST_TURN, 1.0, float(k) / (stems - 1))
		var flower := Node3D.new()
		root.add_child(flower)
		if full:
			h *= FULL_TALL * (1.1 if k == 0 else rng.randf_range(0.7, 0.98))
			flower.position = out * FULL_SPREAD * size * rng.randf_range(0.8, 1.2)
			flower.rotation = Vector3(out.z, 0, -out.x) * FULL_LEAN * rng.randf_range(0.6, 1.2)   # (like a bunch)
			var bend := (out * rng.randf_range(0.06, 0.16) + _aside(rng) * 0.05) * h
			_stem(kind, flower, h, bend, size * FULL_HEAD, tone(col, rng), accent, turn, out, form, rng,
				1.0 if k == 0 else 0.6, 1.0 if k == 0 else FULL_LEAF, true)
		else:
			_stem(kind, flower, h, _aside(rng) * rng.randf_range(0.06, 0.14) * h, size, tone(col, rng), accent, turn, out,
				form, rng, 1.0)
			# A Single Bloom's second, smaller flower on a shorter stem beside it: it opens before the main one.
			var to := (SIDEWAYS * (1.0 if rng.randf() < 0.5 else -1.0) + TOWARDS * 0.35).normalized()
			var side := Node3D.new()
			side.position = to * SIDE_OUT * size
			side.rotation = Vector3(to.z, 0, -to.x) * SIDE_LEAN * rng.randf_range(0.75, 1.1)
			flower.add_child(side)
			var short := h * SIDE_TALL * rng.randf_range(0.9, 1.15)
			_stem(kind, side, short, to * 0.14 * short, size * SIDE_SIZE, tone(col, rng), accent, 0.6, to * 0.5, form,
				rng, 0.0, 1.0, true)
	if full:
		# A Full Bloom stands in a rosette of big leaves, so it is a mass of green under its flowers.
		for k in ModelKit.scaled(8, 4):
			_leaf(root, kind, Vector3.ZERO, turn_around + TAU * k / 8.0 + 0.3, 1.05, 0.34 * size, 0.15 * size, rng)


## One stem `h` tall standing in `flower`, bending `bend` aside by its top, with its leaves (`leafy`: how many of
## its usual leaves, 0..1; `leaf_size`: their size against the kind's own) and its head on top, looking up the
## end of the stem, towards the camera and, for a stem that leans `out`, outward too, give or take. `light`: its
## head is one of a bunch, or a small one (see `_head`).
static func _stem(kind: String, flower: Node3D, h: float, bend: Vector3, size: float, col: Color, accent: Color,
		turn: float, out: Vector3, form: Dictionary, rng: RandomNumberGenerator, leafy: float, leaf_size := 1.0,
		light := false) -> void:
	_tube(flower, h, bend, float(form["stem"]) * size, 3 if light else 4)
	if leafy > 0.0:
		_leaves(kind, flower, h, bend, size * leaf_size, rng, leafy)
	var face := (TOWARDS + out * 0.7).normalized().rotated(Vector3.UP, rng.randf_range(-0.45, 0.45))
	var tilt := float(form["tilt"]) * rng.randf_range(0.8, 1.15)
	var up := (Vector3.UP * cos(tilt) + face * sin(tilt) + _along(h, bend, 1.0) * 0.4).normalized()
	var head := Node3D.new()
	head.transform = Transform3D(_basis_up(up, rng.randf() * TAU), _on(h, bend, 1.0))
	flower.add_child(head)
	_head(kind, head, float(form["head"]) * size, col, accent, turn, light, rng)


## A point on a stem `h` tall that bends `bend` aside by its top: `t` of the way up it.
static func _on(h: float, bend: Vector3, t: float) -> Vector3:
	return Vector3(bend.x * t * t, h * t, bend.z * t * t)


## The way that stem runs there.
static func _along(h: float, bend: Vector3, t: float) -> Vector3:
	return Vector3(2.0 * bend.x * t, h, 2.0 * bend.z * t).normalized()


## A turn with its y along `up`, spun `spin` about it.
static func _basis_up(up: Vector3, spin: float) -> Basis:
	var x := up.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized().rotated(up, spin)
	return Basis(x, up, x.cross(up))


## A level direction, any.
static func _aside(rng: RandomNumberGenerator) -> Vector3:
	var a := rng.randf() * TAU
	return Vector3(cos(a), 0, sin(a))


## The stem itself: a tube of `parts` lengths along its bend, thinner and lighter towards its top.
static func _tube(flower: Node3D, h: float, bend: Vector3, r: float, parts: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in parts + 1:
		var t := float(i) / parts
		var along := _along(h, bend, t)
		var u := along.cross(Vector3.FORWARD).normalized()
		var v := u.cross(along)
		st.set_color(STEM_FOOT.lerp(STEM, t))
		for side in TUBE_SIDES:
			var a := TAU * side / TUBE_SIDES
			st.add_vertex(_on(h, bend, t) + (u * cos(a) + v * sin(a)) * r * lerpf(1.0, 0.7, t))
	for i in parts:
		for side in TUBE_SIDES:
			var a := i * TUBE_SIDES + side
			var b := i * TUBE_SIDES + (side + 1) % TUBE_SIDES
			for j: int in [a, a + TUBE_SIDES, b, b, a + TUBE_SIDES, b + TUBE_SIDES]:
				st.add_index(j)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = ModelKit.bloom_paint(Color.WHITE)   # (its colours are in its points)
	flower.add_child(mi)
	ModelKit.mark_bloom(mi, NOT_A_HEAD)


## A bloom on the farm, as its own baked model (`look`: the variant its small differences come from, or its uid).
static func build(it: Dictionary, o: Dictionary, scale := 1.0, look := -1) -> Node3D:
	var holder := Node3D.new()
	var d := Game.catalog.get_def(str(it.get("id", ""))) as BloomDef
	build_at(holder, Vector3(0.5, 0, 0.5), it, 1.6 * scale, d != null and d.is_full(),
		look if look >= 0 else int(o.get("uid", 0)), Crowding.mask(o))
	return ModelKit.bake(holder)


## The kind of flower an item is: the first word of its id (rose_bloom, rose_full_bloom), a rose if unknown.
static func kind_of(it: Dictionary) -> String:
	var kind := str(it.get("id", "")).get_slice("_", 0)
	return kind if FORMS.has(kind) else "rose"


## A catalog colour as a petal wears it: a little less strong, a little lighter.
static func soft(col: Color) -> Color:
	return Color.from_hsv(col.h, col.s * SOFT, lerpf(col.v, 1.0, 0.06))


## One flower's own tone of its kind's colour (one of TONES, so the blades' meshes are few).
static func tone(col: Color, rng: RandomNumberGenerator) -> Color:
	var by: Array = TONES[rng.randi() % TONES.size()]
	return Color.from_hsv(fposmod(col.h + float(by[0]), 1.0), col.s, minf(col.v * float(by[1]), 1.0))


## The flower head of a kind, built open about `head`'s origin, facing up its y: radius `r`. Petals shade from
## their foot to their tip and carry a darker crease, so a head has depth and is not one flat colour. A `light`
## head (one of a Full Bloom's seven, a Single's small second flower) leaves out what a bunch hides or a small
## head doesn't show (the second row of rays, the sepals behind, half the stamens), and its petals are made of
## fewer points.
static func _head(kind: String, head: Node3D, r: float, col: Color, accent: Color, turn: float, light: bool,
		rng: RandomNumberGenerator) -> void:
	var cols := 3 if light else 5
	match kind:
		"rose":
			# Petals one after another round a spiral, as a rose grows them: upright and small at the heart, lying
			# open and large outside, each dark at its foot with a lighter, rolled-back rim.
			var heart := col.darkened(0.3)
			_ball(head, Vector3(0, r * 0.3, 0), r * 0.26, heart, turn, Vector3(1, 1.2, 1), not light)
			var petals := ModelKit.scaled(12 if light else 20, 8)
			for k in petals:
				var f := (k + 0.5) / petals
				var a := k * GOLDEN
				var tilt := lerpf(0.14, 1.36, pow(f, 0.85)) + rng.randf_range(-0.06, 0.06)
				var big := lerpf(0.74, 1.12, f) * rng.randf_range(0.94, 1.06)
				var radial := Vector3(cos(a), 0, sin(a))
				_blade_at(head, "petal", radial * r * lerpf(0.03, 0.1, f) + Vector3(0, r * 0.08, 0),
					radial * sin(tilt) + Vector3(0, cos(tilt), 0), r * big, r * big, heart.lerp(col.darkened(0.38), f),
					col.lightened(lerpf(0.0, 0.22, f)), 1.0, turn, RIM, cols, rng.randf_range(-0.2, 0.2))
			if not light:
				_ring(head, rng, "leaf", 5, 2.0, r * 0.6, r * 0.22, LEAF, LEAF_TIP, turn, 0.3, r * 0.05)
		"tulip":   # an egg of six pointed petals, three inside three, warm at the foot
			var foot := accent.lerp(col, 0.25)
			_ring(head, rng, "pointed", 3, 0.13, r * 2.3, r * 1.55, foot, col.lightened(0.14), turn, 0.0, r * 0.2, 0.0,
				CREASE, 0.7, cols, 0.5)
			_ring(head, rng, "pointed", 3, 0.26, r * 2.2, r * 1.6, foot, col.darkened(0.05), turn, PI / 3.0, r * 0.22, 0.0,
				CREASE, 0.7, cols, 0.5)
		"daisy":   # white rays (two rows of them) round a domed yellow button
			var shade := col.lerp(accent, 0.18).darkened(0.12)
			_ring(head, rng, "ray", 15, 1.4, r * 1.0, r * 0.33, shade, col, turn, 0.0, r * 0.22)
			_ball(head, Vector3(0, r * 0.06, 0), r * 0.36, accent, turn, Vector3(1, 0.6, 1), not light)
			if not light:
				_ring(head, rng, "ray", 15, 1.5, r * 0.92, r * 0.3, shade, col.darkened(0.06), turn, PI / 15.0, r * 0.2)
				_ball(head, Vector3(0, r * 0.16, 0), r * 0.18, accent.darkened(0.2), turn, Vector3(1, 0.6, 1))
		"sunflower":   # a dark seed disc in rays that start orange (two rows of them), green bracts behind
			var ember := col.lerp(Color("#d9620f"), 0.6)
			_ring(head, rng, "ray", 16, 1.36, r * 0.82, r * 0.28, ember, col, turn, 0.0, r * 0.46)
			_ball(head, Vector3(0, r * 0.03, 0), r * 0.54, accent, turn, Vector3(1, 0.36, 1), not light)
			_ball(head, Vector3(0, r * 0.1, 0), r * 0.3, accent.darkened(0.4), turn, Vector3(1, 0.4, 1))
			if not light:
				_ring(head, rng, "ray", 16, 1.48, r * 0.72, r * 0.28, ember, col.lerp(Color("#f0a020"), 0.4), turn,
					PI / 16.0, r * 0.43)
				_ring(head, rng, "leaf", 8, 1.78, r * 0.62, r * 0.3, LEAF, LEAF_TIP, turn, 0.2, r * 0.3)
		"lily":   # six long petals curling back, pale in the throat with a dark stripe, round long stamens
			var throat := col.lerp(Color.WHITE, 0.55).lerp(accent, 0.25)
			_ring(head, rng, "recurved", 3, 0.9, r * 1.6, r * 0.62, throat, col.darkened(0.05), turn, 0.0, r * 0.08, 0.0,
				0.78, 0.7, cols)
			_ring(head, rng, "recurved", 3, 1.0, r * 1.55, r * 0.56, throat, col.lightened(0.1), turn, PI / 3.0, r * 0.08,
				0.0, 0.78, 0.7, cols)
			var stamens := 3 if light else ModelKit.scaled(6, 3)
			for k in stamens:
				var a := TAU * k / stamens + rng.randf_range(-0.2, 0.2)
				var lean := 0.42 + rng.randf_range(-0.08, 0.08)
				var dir := Vector3(sin(lean) * cos(a), cos(lean), sin(lean) * sin(a))
				_blade_at(head, "ray", Vector3.ZERO, dir, r * 1.0, r * 0.07, accent, accent.lightened(0.2), 1.0, turn)
				_blade_at(head, "leaf", dir * r * 0.95, dir, r * 0.32, r * 0.17, ANTHER, ANTHER.lightened(0.15), 1.0, turn)
		"iris":   # three ruffled standards up, three falls down with a yellow signal at the foot of each
			_ring(head, rng, "round", 3, 0.26, r * 1.5, r * 1.0, col, col.lightened(0.3), turn, 0.0, r * 0.08, 0.0, CREASE,
				0.7, cols)
			_ring(head, rng, "fall", 3, 1.9, r * 1.65, r * 1.15, accent, col.darkened(0.12), turn, PI / 3.0, r * 0.12, 0.0,
				0.9, 0.34, cols)
			if not light:
				_ring(head, rng, "leaf", 3, 1.2, r * 0.7, r * 0.3, col.lightened(0.35), col.lightened(0.5), turn, PI / 3.0,
					r * 0.05)


static func _leaf_blade(kind: String) -> String:
	return "strap" if kind in ["tulip", "iris"] else ("round" if kind == "sunflower" else "leaf")


static func _leaf_col(kind: String) -> Color:
	return BLUE_LEAF if kind in ["tulip", "iris"] else LEAF


static func _leaf_tip(kind: String) -> Color:
	return BLUE_LEAF_TIP if kind in ["tulip", "iris"] else LEAF_TIP


## A kind's leaves on a stem `h` tall that bends `bend`, standing in `flower`: big, a mass of green (`leafy`: the
## share of them a short side stem carries).
static func _leaves(kind: String, flower: Node3D, h: float, bend: Vector3, size: float, rng: RandomNumberGenerator,
		leafy: float) -> void:
	var start := rng.randf() * TAU
	match kind:
		"rose":   # oval leaves up the stem, side to side
			for k in maxi(1, roundi(ModelKit.scaled(5, 3) * leafy)):
				_leaf(flower, kind, _on(h, bend, 0.18 + 0.14 * k), start + PI * k + 0.5, 1.05, 0.26 * size, 0.14 * size, rng)
		"tulip":   # broad straps rising from the foot
			for k in maxi(1, roundi(ModelKit.scaled(4, 2) * leafy)):
				_leaf(flower, kind, Vector3.ZERO, start + TAU * k / 4.0, 0.42, h * 0.85, 0.16 * size, rng)
		"daisy":   # a low tuft, and a few up the stem
			for k in maxi(1, roundi(ModelKit.scaled(6, 3) * leafy)):
				_leaf(flower, kind, _on(h, bend, 0.09 * k), start + 2.4 * k, 1.1, 0.22 * size, 0.09 * size, rng)
		"sunflower":   # big heart-shaped leaves
			for k in maxi(1, roundi(ModelKit.scaled(5, 3) * leafy)):
				_leaf(flower, kind, _on(h, bend, 0.16 + 0.15 * k), start + 2.2 * k, 1.15, 0.34 * size, 0.27 * size, rng)
		"lily":   # many narrow leaves spiralling up
			for k in maxi(2, roundi(ModelKit.scaled(9, 4) * leafy)):
				_leaf(flower, kind, _on(h, bend, 0.08 + 0.09 * k), start + 2.4 * k, 0.95, 0.27 * size, 0.07 * size, rng)
		"iris":   # a fan of swords from the foot
			for k in maxi(1, roundi(ModelKit.scaled(5, 3) * leafy)):
				_leaf(flower, kind, Vector3.ZERO, start + TAU * k / 5.0, 0.22, h * (0.8 + 0.07 * k), 0.1 * size, rng)


## One leaf from `base`, pointing out at angle `around` and `tilt` from straight up, give or take; no two are the
## same length, twist or shade.
static func _leaf(flower: Node3D, kind: String, base: Vector3, around: float, tilt: float, length: float,
		width: float, rng: RandomNumberGenerator) -> void:
	around += rng.randf_range(-0.35, 0.35)
	tilt += rng.randf_range(-0.12, 0.15)
	var dir := Vector3(sin(tilt) * cos(around), cos(tilt), sin(tilt) * sin(around))
	var shade: float = SHADES[rng.randi() % SHADES.size()]
	_blade_at(flower, _leaf_blade(kind), base, dir, length * rng.randf_range(0.82, 1.12), width, _leaf_col(kind) * shade,
		_leaf_tip(kind) * shade, VEIN, NOT_A_HEAD, 0.7, 3, rng.randf_range(-0.35, 0.35))


## A ring of `count` blades round a head's middle: each `tilt` from straight up (0 upright, a quarter turn flat,
## more hanging down), starting `out` from the middle and `lift` up, the first at angle `start`. Each shades from
## `foot` to `tip` (the foot's colour reaching `reach` of the way along) with its midrib `rib` times as bright,
## and is `cols` points across. No two sit, tilt, measure or twist quite alike (`loose`: how far they stray).
static func _ring(head: Node3D, rng: RandomNumberGenerator, blade: String, count: int, tilt: float, length: float,
		width: float, foot: Color, tip: Color, turn: float, start: float, out: float, lift := 0.0, rib := CREASE,
		reach := 0.7, cols := 3, loose := 1.0) -> void:
	var n := ModelKit.scaled(count, mini(count, 3))
	for k in n:
		var a := start + TAU * (k + rng.randf_range(-0.22, 0.22) * loose) / n
		var lean := tilt + rng.randf_range(-0.08, 0.08) * loose
		var radial := Vector3(cos(a), 0, sin(a))
		_blade_at(head, blade, radial * out + Vector3(0, lift, 0), radial * sin(lean) + Vector3(0, cos(lean), 0),
			length * rng.randf_range(1.0 - 0.1 * loose, 1.0 + 0.06 * loose), width, foot, tip, rib, turn, reach, cols,
			rng.randf_range(-0.18, 0.18) * loose)


## A blade from `base` along `dir`, `length` long and `width` across, its cupped face turned up and inward (and
## twisted `roll` about its length), shading from `foot` to `tip`. `turn`: the head it belongs to opens at (its
## middle is the parent's origin), or NOT_A_HEAD for a leaf.
static func _blade_at(parent: Node3D, blade: String, base: Vector3, dir: Vector3, length: float, width: float,
		foot: Color, tip: Color, rib: float, turn: float, reach := 0.7, cols := 3, roll := 0.0) -> void:
	var z := dir.normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized().rotated(z, roll)
	var mi := MeshInstance3D.new()
	mi.mesh = blade_mesh(blade, foot, tip, rib, reach, cols)
	mi.transform = Transform3D(Basis(x * width, z.cross(x) * width, z * length), base)
	mi.material_override = ModelKit.bloom_paint(Color.WHITE)   # (its colours are in its points)
	parent.add_child(mi)
	ModelKit.mark_bloom(mi, turn)


## A ball of a head (its heart, its button), opening with it.
static func _ball(head: Node3D, at: Vector3, r: float, col: Color, turn: float, scale := Vector3.ONE,
		smooth := false) -> void:
	ModelKit.mark_bloom(ModelKit.ball(head, at, r, ModelKit.bloom_paint(col), scale, smooth), turn)


## A blade's mesh, made once per shape and colours: lying along +z from its base at the origin, 1 long and 1
## across at its widest, `cols` points across each row (a curved cup, not a fold), its points shared so it is lit
## as one smooth surface. Its shape is BLADES[name]; its points shade from `foot` (as far as `reach` of the way
## along, or only at the rim when `reach` is RIM) to `tip`, the midrib `rib` times as bright (a petal's dark
## crease, a leaf's light vein), fading to the edges.
static func blade_mesh(name: String, foot: Color, tip: Color, rib: float, reach := 0.7, cols := 3) -> ArrayMesh:
	var key := "%s|%s|%s|%.2f|%.2f|%d" % [name, foot.to_html(false), tip.to_html(false), rib, reach, cols]
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
		var y := float(shape[3]) * t * t - float(shape[5]) * smoothstep(0.55, 1.0, t)
		var col := foot.lerp(tip, t * t * t if reach <= RIM else smoothstep(0.0, reach, t))
		for c in cols:
			var u := 2.0 * c / (cols - 1) - 1.0   # -1 at one edge, 0 on the midrib, 1 at the other edge
			var bright := lerpf(rib, 1.0, absf(u))
			st.set_color(Color(col.r * bright, col.g * bright, col.b * bright))
			st.add_vertex(Vector3(u * w, y + float(shape[2]) * w * u * u, t))
	for row in count:
		for c in cols - 1:
			var a := row * cols + c
			for i: int in [a, a + cols + 1, a + 1, a, a + cols, a + cols + 1]:
				st.add_index(i)
	st.generate_normals()
	_blades[key] = st.commit()
	return _blades[key]
