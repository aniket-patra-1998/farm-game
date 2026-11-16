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
const LEAF := Color("#3d7a2c")
const BLUE_LEAF := Color("#4a8f5a")       # a tulip's and an iris's leaves: a bluer green
const ANTHER := Color("#b5541a")          # the pollen on a lily's stamens
const STEMS_FULL := 5                     # flowers in a Full Bloom
const FULL_SPREAD := 0.17                 # how far from the middle a Full Bloom's outer stems stand, in tiles
const FULL_LEAN := 0.2                    # and how far they lean outward, in radians
const TOWARDS := Vector3(0.7, 0.0, 0.7)   # the side a flower turns its face to: the camera's
const NOT_A_HEAD := -1.0                  # the turn a stem or a leaf is marked with (ModelKit.mark_bloom)
const FIRST_TURN := 0.35                  # a Full Bloom's first head opens at this turn, its last at 1

# Each kind's measures for a bloom of size 1, in tiles: its head's radius, its stem's height and thickness, and
# how far its face tilts from straight up (radians).
const FORMS := {
	"rose": {"head": 0.135, "height": 0.5, "stem": 0.014, "tilt": 0.4},
	"tulip": {"head": 0.1, "height": 0.46, "stem": 0.015, "tilt": 0.08},
	"daisy": {"head": 0.13, "height": 0.44, "stem": 0.01, "tilt": 0.6},
	"sunflower": {"head": 0.175, "height": 0.6, "stem": 0.02, "tilt": 0.85},
	"lily": {"head": 0.15, "height": 0.52, "stem": 0.013, "tilt": 0.6},
	"iris": {"head": 0.125, "height": 0.5, "stem": 0.013, "tilt": 0.15},
}

# The blades: [where along it is widest, how pointed its end (0 round, 1 a point), how cupped across, how much
# it curls along its length (up, or down when negative), how many rows of two quads it is made of].
const BLADES := {
	"round": [0.6, 0.0, 0.5, 0.25, 3],        # a rose's petal, a sunflower's leaf
	"pointed": [0.45, 0.85, 0.5, 0.12, 3],    # a tulip's petal
	"ray": [0.55, 0.35, 0.15, 0.05, 2],       # a daisy's and a sunflower's rays, a stamen (many, so lighter)
	"recurved": [0.4, 0.9, 0.3, -0.5, 3],     # a lily's petal, curling back
	"fall": [0.6, 0.2, 0.25, -0.4, 3],        # an iris's fall, hanging
	"leaf": [0.4, 1.0, 0.25, -0.25, 2],
	"strap": [0.35, 0.8, 0.5, -0.12, 3],      # a tulip's and an iris's long leaves
}

static var _blades := {}   # blade name -> its mesh (made once)


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
	var stems := maxi(2, roundi(ModelKit.scaled(STEMS_FULL, 3) * (1.0 - 0.4 * crowd))) if full else 1
	var turn_around := rng.randf() * TAU
	for k in stems:
		var a := turn_around + TAU * k / maxi(stems - 1, 1)
		var out := Vector3(cos(a), 0, sin(a)) if (full and k > 0) else Vector3.ZERO
		var h := float(form["height"]) * (1.0 + rng.randf_range(-0.06, 0.06)) * size \
			* (1.0 + Crowding.setting("bloom", "lift") * crowd) * (1.0 if k == 0 else rng.randf_range(0.74, 0.92))
		var flower := Node3D.new()
		flower.position = out * FULL_SPREAD * size
		if k > 0:
			flower.rotation = Vector3(out.z, 0, -out.x) * FULL_LEAN   # (leaning out from the middle, like a bunch)
		root.add_child(flower)
		var r := float(form["stem"]) * size
		ModelKit.mark_bloom(ModelKit.cylinder(flower, Vector3.ZERO, r, h, ModelKit.bloom_paint(STEM), r * 0.75, 5),
			NOT_A_HEAD)
		_leaves(kind, flower, h, size, rng)
		# The head: on the stem's top, its face tilted towards the camera (an outer stem's, outward too).
		var head := Node3D.new()
		head.position = Vector3(0, h, 0)
		var face := (TOWARDS + out * 0.6).normalized()
		head.rotation = Vector3(face.z, 0, -face.x) * float(form["tilt"])
		head.rotate_y(rng.randf() * TAU)
		flower.add_child(head)
		var turn := 1.0 if stems == 1 else lerpf(FIRST_TURN, 1.0, float(k) / (stems - 1))
		_head(kind, head, float(form["head"]) * size * (1.1 if not full else 1.0), col, accent, turn)


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


## The flower head of a kind, built open about `head`'s origin, facing up its y: radius `r`.
static func _head(kind: String, head: Node3D, r: float, col: Color, accent: Color, turn: float) -> void:
	match kind:
		"rose":   # a cup of layered petals: a tight heart, then three rings opening outward, on green sepals
			_ball(head, Vector3(0, r * 0.3, 0), r * 0.3, col.darkened(0.22), turn, Vector3(1, 1.2, 1))
			_ring(head, "round", 5, 0.28, r * 0.85, r * 0.75, col.darkened(0.12), turn, 0.0, r * 0.12)
			_ring(head, "round", 6, 0.78, r * 1.0, r * 0.9, col, turn, 0.5, r * 0.12)
			_ring(head, "round", 7, 1.22, r * 1.05, r * 0.92, col.lightened(0.14), turn, 0.2, r * 0.1)
			_ring(head, "leaf", 5, 2.0, r * 0.6, r * 0.2, LEAF, turn, 0.3, r * 0.05)
		"tulip":   # an egg of six pointed petals, three inside three
			_ring(head, "pointed", 3, 0.2, r * 2.1, r * 1.35, col.lightened(0.12), turn, 0.0, r * 0.2)
			_ring(head, "pointed", 3, 0.34, r * 2.0, r * 1.4, col, turn, PI / 3.0, r * 0.22)
		"daisy":   # two rows of thin white rays round a yellow button
			_ring(head, "ray", 13, 1.42, r * 1.0, r * 0.3, col, turn, 0.0, r * 0.2)
			_ring(head, "ray", 13, 1.52, r * 0.9, r * 0.28, col.darkened(0.08), turn, PI / 13.0, r * 0.18)
			_ball(head, Vector3(0, r * 0.06, 0), r * 0.36, accent, turn, Vector3(1, 0.55, 1))
		"sunflower":   # a dark disc in two rows of rays, green bracts behind
			_ring(head, "ray", 14, 1.38, r * 0.85, r * 0.3, col, turn, 0.0, r * 0.45)
			_ring(head, "ray", 14, 1.5, r * 0.75, r * 0.3, col.lerp(Color("#e8861a"), 0.35), turn, PI / 14.0, r * 0.42)
			_ball(head, Vector3(0, r * 0.03, 0), r * 0.52, accent, turn, Vector3(1, 0.34, 1))
			_ring(head, "leaf", 6, 1.78, r * 0.6, r * 0.3, LEAF, turn, 0.2, r * 0.3)
		"lily":   # six long petals curling back, round a throat of stamens
			_ring(head, "recurved", 3, 0.95, r * 1.5, r * 0.55, col, turn, 0.0, r * 0.1)
			_ring(head, "recurved", 3, 1.05, r * 1.45, r * 0.5, col.lightened(0.12), turn, PI / 3.0, r * 0.1)
			_ring(head, "leaf", 3, 0.5, r * 0.4, r * 0.3, accent, turn, PI / 6.0, 0.0)   # its throat
			for k in ModelKit.scaled(5, 3):
				var a := TAU * k / 5.0
				var dir := Vector3(sin(0.4) * cos(a), cos(0.4), sin(0.4) * sin(a))
				_blade_at(head, "ray", Vector3.ZERO, dir, r * 0.95, r * 0.07, accent, turn)
				_blade_at(head, "leaf", dir * r * 0.9, dir, r * 0.3, r * 0.16, ANTHER, turn)
		"iris":   # three standards up, three falls down, each fall with its yellow signal
			_ring(head, "round", 3, 0.3, r * 1.4, r * 0.85, col.lightened(0.16), turn, 0.0, r * 0.1)
			_ring(head, "fall", 3, 2.0, r * 1.45, r * 0.95, col.darkened(0.06), turn, PI / 3.0, r * 0.15)
			_ring(head, "leaf", 3, 1.9, r * 0.6, r * 0.3, accent, turn, PI / 3.0, r * 0.2, r * 0.03)


## A kind's leaves on a stem `h` tall, standing in `flower`.
static func _leaves(kind: String, flower: Node3D, h: float, size: float, rng: RandomNumberGenerator) -> void:
	var start := rng.randf() * TAU
	match kind:
		"rose":   # small oval leaves up the stem, side to side
			for k in ModelKit.scaled(4, 2):
				_leaf(flower, "leaf", h * (0.24 + 0.15 * k), start + PI * k + 0.4, 1.1, 0.14 * size, 0.08 * size, LEAF)
		"tulip":   # broad straps rising from the foot
			for k in ModelKit.scaled(3, 2):
				_leaf(flower, "strap", 0.0, start + TAU * k / 3.0, 0.4, h * 0.72, 0.085 * size, BLUE_LEAF)
		"daisy":   # a low tuft
			for k in ModelKit.scaled(5, 3):
				_leaf(flower, "leaf", h * 0.08 * k, start + 2.4 * k, 1.15, 0.11 * size, 0.05 * size, LEAF)
		"sunflower":   # big heart-shaped leaves
			for k in ModelKit.scaled(4, 2):
				_leaf(flower, "round", h * (0.22 + 0.16 * k), start + 2.2 * k, 1.2, 0.2 * size, 0.16 * size, LEAF)
		"lily":   # many narrow leaves spiralling up
			for k in ModelKit.scaled(8, 4):
				_leaf(flower, "leaf", h * (0.12 + 0.09 * k), start + 2.4 * k, 1.0, 0.15 * size, 0.035 * size, LEAF)
		"iris":   # a fan of swords from the foot
			for k in ModelKit.scaled(4, 2):
				_leaf(flower, "strap", 0.0, start + TAU * k / 4.0, 0.2, h * (0.7 + 0.08 * k), 0.05 * size, BLUE_LEAF)


## One leaf on the stem at `height`, pointing out at angle `around` and `tilt` from straight up.
static func _leaf(flower: Node3D, blade: String, height: float, around: float, tilt: float, length: float,
		width: float, col: Color) -> void:
	var dir := Vector3(sin(tilt) * cos(around), cos(tilt), sin(tilt) * sin(around))
	_blade_at(flower, blade, Vector3(0, height, 0), dir, length, width, col, NOT_A_HEAD)


## A ring of `count` blades round a head's middle: each `tilt` from straight up (0 upright, a quarter turn flat,
## more hanging down), starting `out` from the middle and `lift` up, the first at angle `start`.
static func _ring(head: Node3D, blade: String, count: int, tilt: float, length: float, width: float, col: Color,
		turn: float, start: float, out: float, lift := 0.0) -> void:
	var n := ModelKit.scaled(count, mini(count, 3))
	for k in n:
		var a := start + TAU * k / n
		var radial := Vector3(cos(a), 0, sin(a))
		_blade_at(head, blade, radial * out + Vector3(0, lift, 0), radial * sin(tilt) + Vector3(0, cos(tilt), 0),
			length, width, col, turn)


## A blade from `base` along `dir`, `length` long and `width` across, its cupped face turned up and inward.
## `turn`: the head it belongs to opens at (its middle is the parent's origin), or NOT_A_HEAD for a leaf.
static func _blade_at(parent: Node3D, blade: String, base: Vector3, dir: Vector3, length: float, width: float,
		col: Color, turn: float) -> void:
	var z := dir.normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var mi := MeshInstance3D.new()
	mi.mesh = blade_mesh(blade)
	mi.transform = Transform3D(Basis(x * width, z.cross(x) * width, z * length), base)
	mi.material_override = ModelKit.bloom_paint(col)
	parent.add_child(mi)
	ModelKit.mark_bloom(mi, turn)


## A ball of a head (its heart, its button, an anther), opening with it.
static func _ball(head: Node3D, at: Vector3, r: float, col: Color, turn: float, scale := Vector3.ONE) -> void:
	ModelKit.mark_bloom(ModelKit.ball(head, at, r, ModelKit.bloom_paint(col), scale), turn)


## A blade's mesh, made once: lying along +z from its base at the origin, 1 long and 1 across at its widest, a
## midrib with an edge either side (rows of two quads). Its shape is BLADES[name].
static func blade_mesh(name: String) -> ArrayMesh:
	if _blades.has(name):
		return _blades[name]
	var shape: Array = BLADES[name]
	var waist := float(shape[0])
	var count := int(shape[4])
	var rows: Array = []
	for row in count + 1:
		var t := float(row) / count
		var w := lerpf(0.16, 0.5, sin(t / waist * PI / 2.0)) if t <= waist else 0.5 * lerpf(
			cos((t - waist) / (1.0 - waist) * PI / 2.0), 1.0 - (t - waist) / (1.0 - waist), float(shape[1]))
		var y := float(shape[3]) * t * t
		rows.append([Vector3(-w, y + float(shape[2]) * w, t), Vector3(0, y, t), Vector3(w, y + float(shape[2]) * w, t)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in count:
		for side in 2:
			var a: Vector3 = rows[row][side]
			var b: Vector3 = rows[row][side + 1]
			var c: Vector3 = rows[row + 1][side + 1]
			var d: Vector3 = rows[row + 1][side]
			for v: Vector3 in [a, c, b, a, d, c]:
				st.add_vertex(v)
	st.generate_normals()
	_blades[name] = st.commit()
	return _blades[name]
