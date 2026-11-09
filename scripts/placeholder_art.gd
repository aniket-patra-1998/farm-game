class_name PlaceholderArt
extends RefCounted
## All visuals are drawn here with simple shapes so the game runs with no image files.
## To switch to real art later, replace these functions with sprite drawing
## (e.g. ci.draw_texture(...)) — nothing else in the game needs to change.

const GRASS_A := Color("#8fcf5f")
const GRASS_B := Color("#86c757")
const GRASS_TUFT := Color("#6fb146")
const SOIL := Color("#a86f3d")
const SOIL_FURROW := Color("#8a5629")
const SOIL_WET := Color("#93602f")
const EDGE_LEFT := Color("#7a4a24")
const EDGE_RIGHT := Color("#5f3a1c")
const LEAF := Color("#4fa83d")
const LEAF_DARK := Color("#3c8a2e")
const STEM := Color("#5c9e3a")
const WITHERED := Color("#8b7355")
const WITHERED_DARK := Color("#6e5a42")
const OUTLINE := Color(0, 0, 0, 0.12)


# ---------------------------------------------------------------- ground

static func diamond(top: Vector2, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		top,
		top + Vector2(w / 2.0, h / 2.0),
		top + Vector2(0, h),
		top + Vector2(-w / 2.0, h / 2.0),
	])


## Earth sides under the front two edges of the farm, so it reads as a raised plot.
## The countryside around the farm: meadow out to the edges of the view, a little darker than your land,
## so the farm sits in open country (as in FarmVille) instead of floating in the sky.
const MEADOW := Color("#7cb653")
const MEADOW_DARK := Color("#6fa84a")
const MEADOW_TUFT := Color("#5f9a3e")


static func draw_meadow(ci: CanvasItem, n: int, w: float, h: float, margin: int) -> void:
	var a := -float(margin)
	var b := float(n + margin)
	var top := Vector2((a - a) * w / 2.0, (a + a) * h / 2.0)
	var right := Vector2((b - a) * w / 2.0, (b + a) * h / 2.0)
	var bottom := Vector2((b - b) * w / 2.0, (b + b) * h / 2.0)
	var left := Vector2((a - b) * w / 2.0, (a + b) * h / 2.0)
	ci.draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), MEADOW)
	# Patches of darker grass and tufts, the same every time.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k in 260:
		var r := rng.randf_range(a, b)
		var c := rng.randf_range(a, b)
		if r > -0.5 and r < n + 0.5 and c > -0.5 and c < n + 0.5:
			continue
		var p := Vector2((c - r) * w / 2.0, (c + r) * h / 2.0)
		if k % 3 == 0:
			draw_ellipse_at(ci, p, w * rng.randf_range(0.4, 1.1), h * rng.randf_range(0.35, 0.9), MEADOW_DARK)
		else:
			ci.draw_line(p, p + Vector2(-3, -7), MEADOW_TUFT, 2.0)
			ci.draw_line(p, p + Vector2(0, -9), MEADOW_TUFT, 2.0)
			ci.draw_line(p, p + Vector2(3, -7), MEADOW_TUFT, 2.0)


static func draw_ellipse_at(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 20:
		var t := TAU * k / 20.0
		pts.append(center + Vector2(cos(t) * rx, sin(t) * ry))
	ci.draw_colored_polygon(pts, col)


## Your land's grass as one continuous field: a base colour with soft patches of lighter and darker
## grass and tufts, the same every time (no checkerboard).
static func draw_field(ci: CanvasItem, n: int, w: float, h: float) -> void:
	var t := Vector2(0, 0)
	var r := Vector2(n * w / 2.0, n * h / 2.0)
	var b := Vector2(0, n * h)
	var l := Vector2(-n * w / 2.0, n * h / 2.0)
	ci.draw_colored_polygon(PackedVector2Array([t, r, b, l]), GRASS_A)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1717
	var light := GRASS_A.lightened(0.06)
	var dark := GRASS_A.darkened(0.06)
	for k in n * n / 3:
		var row := rng.randf_range(0.3, n - 0.3)
		var col := rng.randf_range(0.3, n - 0.3)
		var p := Vector2((col - row) * w / 2.0, (col + row) * h / 2.0)
		draw_ellipse_at(ci, p, w * rng.randf_range(0.25, 0.6), h * rng.randf_range(0.2, 0.5), light if k % 2 == 0 else dark)
	for k in n * n * 2:
		var row := rng.randf_range(0.1, n - 0.1)
		var col := rng.randf_range(0.1, n - 0.1)
		var p := Vector2((col - row) * w / 2.0, (col + row) * h / 2.0)
		ci.draw_line(p, p + Vector2(-3, -7), GRASS_TUFT, 2.0)
		ci.draw_line(p, p + Vector2(0, -9), GRASS_TUFT, 2.0)
		ci.draw_line(p, p + Vector2(3, -7), GRASS_TUFT, 2.0)


## A soft line where your land ends, instead of the old floating-island edges.
static func draw_farm_border(ci: CanvasItem, n: int, w: float, h: float) -> void:
	var t := Vector2(0, 0)
	var r := Vector2(n * w / 2.0, n * h / 2.0)
	var b := Vector2(0, n * h)
	var l := Vector2(-n * w / 2.0, n * h / 2.0)
	ci.draw_polyline(PackedVector2Array([t, r, b, l, t]), Color(0.25, 0.4, 0.15, 0.35), 3.0)


static func draw_farm_edges(ci: CanvasItem, n: int, w: float, h: float, depth: float) -> void:
	var left := Vector2(-n * w / 2.0, n * h / 2.0)
	var bottom := Vector2(0, n * h)
	var right := Vector2(n * w / 2.0, n * h / 2.0)
	var down := Vector2(0, depth)
	ci.draw_colored_polygon(PackedVector2Array([left, bottom, bottom + down, left + down]), EDGE_LEFT)
	ci.draw_colored_polygon(PackedVector2Array([bottom, right, right + down, bottom + down]), EDGE_RIGHT)


static func draw_grass(ci: CanvasItem, top: Vector2, w: float, h: float, seed_value: int, checker: bool) -> void:
	ci.draw_colored_polygon(diamond(top, w, h), GRASS_A if checker else GRASS_B)
	# A few deterministic tufts so the field doesn't look flat.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var center := top + Vector2(0, h / 2.0)
	for k in 3:
		var p := center + Vector2(rng.randf_range(-w * 0.22, w * 0.22), rng.randf_range(-h * 0.2, h * 0.2))
		ci.draw_line(p, p + Vector2(-3, -7), GRASS_TUFT, 2.0)
		ci.draw_line(p, p + Vector2(0, -9), GRASS_TUFT, 2.0)
		ci.draw_line(p, p + Vector2(3, -7), GRASS_TUFT, 2.0)


## Plowed plots are raised beds, like FarmVille's and like the painted crop art: a soil top lifted by
## SLAB px over the tile, with darker sides.
const SLAB := 10.0
const BED_TOP := Color("#6e4c37")
const BED_TOP_WET := Color("#5f412f")
const BED_LEFT := Color("#4a3123")
const BED_RIGHT := Color("#33211a")
const BED_FURROW := Color("#4e3426")
const BED_RIDGE := Color("#8a6247")


static func draw_soil(ci: CanvasItem, top: Vector2, w: float, h: float, planted: bool) -> void:
	var base := diamond(top, w, h)
	var up := Vector2(0, -SLAB * w / 128.0)
	var pts := PackedVector2Array([base[0] + up, base[1] + up, base[2] + up, base[3] + up])
	# Sides of the bed: earth in shade.
	ci.draw_colored_polygon(PackedVector2Array([pts[3], pts[2], base[2], base[3]]), BED_LEFT)
	ci.draw_colored_polygon(PackedVector2Array([pts[2], pts[1], base[1], base[2]]), BED_RIGHT)
	ci.draw_colored_polygon(pts, BED_TOP_WET if planted else BED_TOP)
	# Soft mounded rows: each a lighter band that fades into the furrow beside it, with a few clods.
	var t_ := pts[0]
	var r_ := pts[1]
	var b_ := pts[2]
	var l_ := pts[3]
	var top_col := BED_TOP_WET if planted else BED_TOP
	for k in 4:
		var f0 := (k + 0.18) / 4.0
		var f1 := (k + 0.62) / 4.0
		var ridge := PackedVector2Array([t_.lerp(l_, f0), r_.lerp(b_, f0), r_.lerp(b_, f1), t_.lerp(l_, f1)])
		ci.draw_colored_polygon(ridge, top_col.lightened(0.09))
		var g0 := (k + 0.78) / 4.0
		ci.draw_line(t_.lerp(l_, g0), r_.lerp(b_, g0), BED_FURROW, 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(top.x * 7.0 + top.y * 13.0)
	for k in 7:
		var u := rng.randf_range(0.1, 0.9)
		var v := rng.randf_range(0.1, 0.9)
		var p := t_.lerp(r_, u).lerp(l_.lerp(b_, u), v)
		ci.draw_circle(p, rng.randf_range(1.0, 2.2) * w / 128.0, top_col.darkened(0.25))
	# A soft dark rim where the top meets the sides, instead of a hard outline.
	ci.draw_polyline(PackedVector2Array([pts[3], pts[2], pts[1]]), BED_LEFT.darkened(0.3), 1.5)


# ---------------------------------------------------------------- crops

## Positions of the plants within one plot, back to front.
static func plant_spots(w: float, h: float) -> Array[Vector2]:
	return [
		Vector2(0, -h * 0.2),
		Vector2(-w * 0.18, 0),
		Vector2(w * 0.18, 0),
		Vector2(0, h * 0.2),
	]


## stage: "growing" (uses progress 0..1), "ripe" or "withered".
static func draw_crop(ci: CanvasItem, center: Vector2, w: float, h: float, crop: Dictionary, stage: String, progress: float) -> void:
	var s := w / 128.0
	for spot in plant_spots(w, h):
		var p := center + spot
		match stage:
			"withered":
				_withered(ci, p, s)
			"ripe":
				_ripe(ci, p, s, crop)
			_:
				if progress < 0.25:
					_seeds(ci, p, s)
				elif progress < 0.6:
					_sprout(ci, p, s)
				else:
					_young(ci, p, s)


static func _seeds(ci: CanvasItem, p: Vector2, s: float) -> void:
	ci.draw_circle(p + Vector2(-4, 0) * s, 2.5 * s, SOIL_FURROW)
	ci.draw_circle(p + Vector2(4, 1) * s, 2.5 * s, SOIL_FURROW)


static func _sprout(ci: CanvasItem, p: Vector2, s: float) -> void:
	ci.draw_line(p, p + Vector2(0, -8) * s, STEM, 2.5 * s)
	_ellipse(ci, p + Vector2(-5, -9) * s, 5 * s, 3 * s, LEAF)
	_ellipse(ci, p + Vector2(5, -9) * s, 5 * s, 3 * s, LEAF)


static func _young(ci: CanvasItem, p: Vector2, s: float) -> void:
	ci.draw_line(p, p + Vector2(0, -18) * s, STEM, 3 * s)
	_ellipse(ci, p + Vector2(-7, -10) * s, 7 * s, 4 * s, LEAF_DARK)
	_ellipse(ci, p + Vector2(7, -13) * s, 7 * s, 4 * s, LEAF)
	_ellipse(ci, p + Vector2(0, -19) * s, 5 * s, 4 * s, LEAF)


static func _withered(ci: CanvasItem, p: Vector2, s: float) -> void:
	ci.draw_line(p, p + Vector2(-2, -12) * s, WITHERED_DARK, 3 * s)
	ci.draw_line(p + Vector2(-2, -12) * s, p + Vector2(-9, -6) * s, WITHERED, 2.5 * s)
	ci.draw_line(p + Vector2(-1, -8) * s, p + Vector2(7, -4) * s, WITHERED, 2.5 * s)


static func _ripe(ci: CanvasItem, p: Vector2, s: float, crop: Dictionary) -> void:
	var c := Color.html(str(crop.get("color", "#ffffff")))
	match crop.get("shape", ""):
		"berry":
			_ellipse(ci, p + Vector2(0, -7) * s, 12 * s, 8 * s, LEAF_DARK)
			_ellipse(ci, p + Vector2(0, -10) * s, 9 * s, 6 * s, LEAF)
			for o in [Vector2(-6, -6), Vector2(5, -8), Vector2(0, -12), Vector2(7, -3)]:
				ci.draw_circle(p + o * s, 3.2 * s, c)
		"grain":
			for dx in [-8, -4, 0, 4, 8]:
				var base: Vector2 = p + Vector2(dx, 0) * s
				var tip: Vector2 = base + Vector2(dx * 0.3, -24) * s
				ci.draw_line(base, tip, c.darkened(0.25), 2 * s)
				_ellipse(ci, tip, 2.6 * s, 6 * s, c)
		"root":
			for dx in [-7, 0, 7]:
				var b: Vector2 = p + Vector2(dx, -2) * s
				ci.draw_circle(b, 4 * s, c)
				ci.draw_line(b, b + Vector2(-3, -10) * s, LEAF, 2.5 * s)
				ci.draw_line(b, b + Vector2(3, -11) * s, LEAF_DARK, 2.5 * s)
		"stalk":
			for dx in [-6, 6]:
				var b2: Vector2 = p + Vector2(dx, 0) * s
				ci.draw_line(b2, b2 + Vector2(0, -32) * s, STEM, 3.5 * s)
				_ellipse(ci, b2 + Vector2(-5, -16) * s, 7 * s, 2.5 * s, LEAF)
				_ellipse(ci, b2 + Vector2(5, -24) * s, 7 * s, 2.5 * s, LEAF_DARK)
				_ellipse(ci, b2 + Vector2(2, -22) * s, 3 * s, 7 * s, c)
		"flower":
			ci.draw_line(p, p + Vector2(0, -30) * s, STEM, 3 * s)
			_ellipse(ci, p + Vector2(-6, -14) * s, 6 * s, 3 * s, LEAF)
			var head := p + Vector2(0, -32) * s
			for k in 10:
				var a := TAU * k / 10.0
				ci.draw_circle(head + Vector2(cos(a), sin(a)) * 7 * s, 4 * s, c)
			ci.draw_circle(head, 5 * s, Color("#6b4423"))
		"fruit":
			_ellipse(ci, p + Vector2(0, -10) * s, 11 * s, 9 * s, LEAF_DARK)
			for o in [Vector2(-5, -7), Vector2(5, -10), Vector2(0, -15)]:
				ci.draw_circle(p + o * s, 4.5 * s, c)
		"gourd":
			_ellipse(ci, p + Vector2(-6, -4) * s, 8 * s, 4 * s, LEAF_DARK)
			_ellipse(ci, p + Vector2(0, -6) * s, 11 * s, 8 * s, c)
			ci.draw_line(p + Vector2(0, -13) * s, p + Vector2(0, 1) * s, c.darkened(0.2), 1.5 * s)
			ci.draw_line(p + Vector2(0, -14) * s, p + Vector2(2, -18) * s, STEM, 3 * s)
		"leafy":
			for o in [Vector2(-7, -6), Vector2(7, -6), Vector2(0, -12), Vector2(0, -2)]:
				_ellipse(ci, p + o * s, 9 * s, 6 * s, c.darkened(0.1) if o.y < -8 else c)
			_ellipse(ci, p + Vector2(0, -8) * s, 4 * s, 3 * s, c.lightened(0.25))
		"spike":
			for dx in [-6, 0, 6]:
				var b3: Vector2 = p + Vector2(dx, 0) * s
				ci.draw_line(b3, b3 + Vector2(0, -22) * s, STEM, 2 * s)
				_ellipse(ci, b3 + Vector2(0, -24) * s, 2.8 * s, 8 * s, c)
		"fluff":
			ci.draw_line(p, p + Vector2(0, -18) * s, WITHERED_DARK, 2.5 * s)
			for o in [Vector2(-6, -16), Vector2(6, -18), Vector2(0, -24)]:
				ci.draw_circle(p + o * s, 5 * s, c)
		_:
			_young(ci, p, s)


static func _ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, color)


## A four-point sparkle; alpha 0..1. Used to make ripe crops shimmer.
static func draw_twinkle(ci: CanvasItem, center: Vector2, size: float, alpha: float) -> void:
	var c := Color(1.0, 0.98, 0.8, 0.35 + 0.65 * alpha)
	var thin := size * 0.22
	ci.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -size), center + Vector2(thin, -thin),
		center + Vector2(size, 0), center + Vector2(thin, thin),
		center + Vector2(0, size), center + Vector2(-thin, thin),
		center + Vector2(-size, 0), center + Vector2(-thin, -thin),
	]), c)
	ci.draw_circle(center, thin * 1.1, Color(1, 1, 1, c.a))


# ---------------------------------------------------------------- placed objects

## corners: the footprint's top, right, bottom and left points on the ground.
## false when drawing art references: no level badges for the AI to copy.
static var show_badges := true


static func draw_object(ci: CanvasItem, it: Dictionary, corners: PackedVector2Array, ready: bool, level: int, inside: int, capacity: int, broken := false) -> void:
	var center := (corners[0] + corners[2]) / 2.0
	var s := (corners[1].x - corners[3].x) / 128.0 # 1.0 for a one-tile object
	match it.get("kind", ""):
		"tree":
			_tree(ci, center, it, ready)
		"animal":
			_animal(ci, center, it, ready)
		"vehicle":
			_vehicle(ci, center, it)
		"building":
			_building(ci, corners, it, level, inside, capacity, s)
		"barn":
			_building(ci, corners, it, level, inside, capacity, s, not broken, broken)
		"crafting":
			_crafting(ci, corners, it, level, s)
		"decor":
			match it.get("id", ""):
				"farmhouse":
					_building(ci, corners, it, 1, 0, 0, s, false)
				"mailbox":
					_mailbox(ci, center, it)
				"farm_stand":
					_farm_stand(ci, center, it)
				_:
					_decor(ci, corners, center, it)


static func _shadow(ci: CanvasItem, center: Vector2, rx: float, ry: float) -> void:
	_ellipse(ci, center, rx, ry, Color(0, 0, 0, 0.16))


static func _tree(ci: CanvasItem, ground: Vector2, it: Dictionary, ready: bool) -> void:
	_shadow(ci, ground + Vector2(0, 4), 34, 14)
	ci.draw_rect(Rect2(ground + Vector2(-6, -40), Vector2(12, 42)), Color("#7a4f2c"))
	ci.draw_line(ground + Vector2(0, -26), ground + Vector2(-14, -44), Color("#7a4f2c"), 5)
	var canopy := ground + Vector2(0, -62)
	ci.draw_circle(canopy + Vector2(-20, 6), 24, LEAF_DARK)
	ci.draw_circle(canopy + Vector2(20, 6), 24, LEAF_DARK)
	ci.draw_circle(canopy + Vector2(0, -10), 30, LEAF)
	ci.draw_circle(canopy + Vector2(-8, -18), 12, Color(1, 1, 1, 0.12))
	var fruit := Color.html(str(it.get("color", "#d93b30")))
	var spots := [Vector2(-22, 8), Vector2(14, -14), Vector2(24, 12), Vector2(-6, -24), Vector2(2, 14), Vector2(-26, -10)]
	var count := spots.size() if ready else 2
	for k in count:
		ci.draw_circle(canopy + spots[k], 6.5 if ready else 4.0, fruit if ready else fruit.lerp(LEAF, 0.6))


static func _animal(ci: CanvasItem, ground: Vector2, it: Dictionary, ready: bool) -> void:
	var body := Color.html(str(it.get("color", "#ffffff")))
	var accent := Color.html(str(it.get("accent", "#333333")))
	var id: String = it.get("id", "")
	var sp := str(it.get("family", id))   # species: breeds of one family share a shape
	var baby := bool(it.get("young", false))
	_shadow(ci, ground + Vector2(0, 2), 30, 11)
	if sp in ["chicken", "duck", "goose", "turkey"]:
		var tall := (1.2 if sp == "goose" or sp == "turkey" or id == "swan" else 1.0) * (0.75 if baby else 1.0)
		_ellipse(ci, ground + Vector2(0, -16), 15 * tall, 13 * tall, body)
		ci.draw_circle(ground + Vector2(11, -30 * tall), 9, body)
		if sp == "chicken" or sp == "turkey":
			_ellipse(ci, ground + Vector2(11, -40 * tall), 4, 5, accent)       # comb or wattle
		if id == "turkey" or id == "wild_turkey":
			for k in 5:
				var a := PI + 0.35 + k * 0.32
				ci.draw_circle(ground + Vector2(-8, -20) + Vector2(cos(a), sin(a)) * 16, 7, accent.lerp(body, 0.3 + 0.12 * k))
		ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(19, -31), ground + Vector2(27, -28), ground + Vector2(19, -26)]), Color("#f2a33a"))
		ci.draw_circle(ground + Vector2(14, -32), 1.8, Color("#222222"))
		ci.draw_line(ground + Vector2(-4, -4), ground + Vector2(-4, 4), Color("#f2a33a"), 2.5)
		ci.draw_line(ground + Vector2(4, -4), ground + Vector2(4, 4), Color("#f2a33a"), 2.5)
	else:
		var big := 0.7 if baby else (0.9 if id.ends_with("pony") else (1.25 if sp == "horse" or id in ["bull", "ox"] else 1.0))
		for x in [-16.0, -8.0, 10.0, 18.0]:
			ci.draw_line(ground + Vector2(x * big, -14), ground + Vector2(x * big, 2), accent if sp == "horse" else body.darkened(0.25), 4.5)
		_ellipse(ci, ground + Vector2(0, -22 * big), 26 * big, 15 * big, body)
		if sp == "cow" and id != "bull":
			_ellipse(ci, ground + Vector2(-8, -24), 8, 6, accent)
			_ellipse(ci, ground + Vector2(10, -18), 6, 5, accent)
		if sp == "sheep" or sp == "camelid":
			for k in 6:
				ci.draw_circle(ground + Vector2(-18 + k * 7, -32 + (k % 2) * 4), 7, body.lightened(0.3))
		var head := ground + Vector2(26 * big, -32 * big)
		ci.draw_circle(head, 10 * big, accent if id == "sheep" else body)
		if sp == "horse":
			_ellipse(ci, head + Vector2(6, 4), 9, 7, body)
			ci.draw_line(head + Vector2(-8, -4), ground + Vector2(10, -34), accent, 6) # mane
		if sp == "pig":
			_ellipse(ci, head + Vector2(8, 2), 5, 4, accent)
		if id in ["ram", "bull", "ox", "longhorn", "mouflon_sheep", "arapawa_goat"]:
			ci.draw_arc(head + Vector2(-2, -6), 7, PI, TAU, 8, Color("#e8e2d4") if id != "ram" else accent, 3) # horns
		ci.draw_circle(head + Vector2(2, -2), 1.8, Color("#222222"))
		ci.draw_line(ground + Vector2(-26 * big, -24 * big), ground + Vector2(-32 * big, -16 * big), accent, 3) # tail
	if ready:
		# A product bubble shows the animal is ready to collect.
		var bubble := ground + Vector2(-4, -64)
		ci.draw_circle(bubble, 13, Color("#fffaf0"))
		ci.draw_arc(bubble, 13, 0, TAU, 24, Color("#5c3a1e"), 2)
		ci.draw_circle(bubble, 6, accent if id != "chicken" else Color("#f6e7c1"))


## Each animal building has its own shape, so you can tell them apart at a glance.
## show_sign: level badge and count sign; broken: weathered colours, missing roof and boarded door.
static func _building(ci: CanvasItem, g: PackedVector2Array, it: Dictionary, level: int, inside: int, capacity: int, s: float, show_sign := true, broken := false) -> void:
	if show_sign and not broken:
		var badge := Vector2.ZERO
		match it.get("id", ""):
			"chicken_coop":
				badge = _coop(ci, g, it, level, inside, capacity, s)
			"cow_shed":
				badge = _dairy(ci, g, it, level, s)
			"horse_stable":
				badge = _stable(ci, g, it, level, s)
			"nursery_barn":
				badge = _nursery(ci, g, it, level, s)
			"beehive":
				badge = _hive(ci, g, inside, capacity, s)
			"orchard":
				badge = _orchard(ci, g, level, inside, s)
			"pig_pen":
				badge = _pig_pen(ci, g, it, inside, s)
			"garage":
				badge = _garage(ci, g, it, inside, s)
			"duck_pond":
				badge = _duck_pond(ci, g, it, inside)
			"sheep_pen", "goat_pen":
				badge = _pen(ci, g, it, inside)
			"rabbit_hutch":
				badge = _hutch(ci, g, it, inside)
		if badge != Vector2.ZERO:
			if show_badges:
				_signs(ci, g, badge, level, inside, capacity)
			return
	_plain_building(ci, g, it, level, inside, capacity, s, show_sign, broken)


static func _plain_building(ci: CanvasItem, g: PackedVector2Array, it: Dictionary, level: int, inside: int, capacity: int, s: float, show_sign := true, broken := false) -> void:
	var wall := Color.html(str(it.get("color", "#c0392b")))
	var roof := Color.html(str(it.get("roof", "#6b4a3a")))
	if broken:
		wall = wall.lerp(Color("#8a7f72"), 0.55)
		roof = roof.lerp(Color("#6e675e"), 0.5)
	# Inset the walls from the footprint edge so a yard shows around the building.
	var c := (g[0] + g[2]) / 2.0
	var top := c.lerp(g[0], 0.78)
	var right := c.lerp(g[1], 0.78)
	var bottom := c.lerp(g[2], 0.78)
	var left := c.lerp(g[3], 0.78)
	var hgt := 34.0 * s + 10.0 * level
	var up := Vector2(0, -hgt)
	_ellipse(ci, c + Vector2(0, 6), (g[1].x - g[3].x) * 0.42, (g[2].y - g[0].y) * 0.42, Color(0, 0, 0, 0.12))
	ci.draw_colored_polygon(PackedVector2Array([left, bottom, bottom + up, left + up]), wall.darkened(0.12))
	ci.draw_colored_polygon(PackedVector2Array([bottom, right, right + up, bottom + up]), wall.darkened(0.3))
	# Door on the left face.
	var door_base := left.lerp(bottom, 0.5)
	var dw := (bottom - left) * 0.14
	var dh := Vector2(0, -hgt * 0.62)
	ci.draw_colored_polygon(PackedVector2Array([door_base - dw, door_base + dw, door_base + dw + dh, door_base - dw + dh]), Color("#4a2c18"))
	ci.draw_line(door_base - dw + dh * 0.5, door_base + dw + dh * 0.5, Color("#f4e3c3"), 2)
	# Pitched roof: ridge runs from the back-left to the front-right.
	var ridge_up := Vector2(0, -26.0 * s)
	var r_a := top.lerp(left, 0.5) + up + ridge_up
	var r_b := right.lerp(bottom, 0.5) + up + ridge_up
	ci.draw_colored_polygon(PackedVector2Array([left + up, bottom + up, r_b, r_a]), roof)
	ci.draw_colored_polygon(PackedVector2Array([top + up, right + up, r_b, r_a]), roof.darkened(0.2))
	ci.draw_colored_polygon(PackedVector2Array([bottom + up, right + up, r_b]), wall.darkened(0.3))
	ci.draw_line(r_a, r_b, roof.lightened(0.25), 3)
	if broken:
		# Holes in the roof, a boarded-up door and loose planks.
		ci.draw_colored_polygon(PackedVector2Array([left.lerp(r_a, 0.4) + up * 0.0, left.lerp(r_a, 0.7), bottom.lerp(r_b, 0.55) + up, bottom.lerp(r_b, 0.3) + up]), Color("#2b2420"))
		var plank := Color("#a07850")
		ci.draw_line(door_base - dw + dh * 0.2, door_base + dw + dh * 0.8, plank, 5)
		ci.draw_line(door_base + dw + dh * 0.2, door_base - dw + dh * 0.8, plank, 5)
		ci.draw_line(bottom + Vector2(10, 14), bottom + Vector2(46, 4), plank, 6)
		ci.draw_line(bottom + Vector2(18, 22), bottom + Vector2(52, 18), plank.darkened(0.2), 6)
		var mark := r_b + Vector2(0, -30)
		ci.draw_circle(mark, 17, Color("#ffd34d"))
		ci.draw_arc(mark, 17, 0, TAU, 24, Color("#5c3a1e"), 2.5)
		ci.draw_string(ThemeDB.fallback_font, mark + Vector2(-16, 8), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 24, Color("#3a2614"))
		return
	if not show_sign:
		return
	# Upgrades show on the building itself.
	if level >= 2:
		_upgrade_trim(ci, g, left, bottom, right, up, roof)
	if level >= 3:
		_upgrade_top(ci, right, bottom, up, r_a, s)
	if show_badges:
		_signs(ci, g, r_b + Vector2(0, -26), level, inside, capacity)


## Level badge over the building.
static func _signs(ci: CanvasItem, _g: PackedVector2Array, badge: Vector2, level: int, _inside: int, _capacity: int) -> void:
	var font := ThemeDB.fallback_font
	ci.draw_circle(badge, 16, Color("#ffd34d"))
	ci.draw_arc(badge, 16, 0, TAU, 24, Color("#5c3a1e"), 2.5)
	ci.draw_string(font, badge + Vector2(-16, 7), str(level), HORIZONTAL_ALIGNMENT_CENTER, 32, 20, Color("#3a2614"))


## The "inside / spaces" sign in front of a building. Drawn after the whole farm,
## because it hangs past the footprint and the ground in front would cover it.
static func draw_count_sign(ci: CanvasItem, g: PackedVector2Array, inside: int, capacity: int) -> void:
	var c := (g[0] + g[2]) / 2.0
	var sign_pos := c.lerp(g[2], 0.78) + Vector2(-34, 22)
	ci.draw_rect(Rect2(sign_pos, Vector2(68, 24)), Color("#fbefd2"))
	ci.draw_rect(Rect2(sign_pos, Vector2(68, 24)), Color("#5c3a1e"), false, 2)
	ci.draw_string(ThemeDB.fallback_font, sign_pos + Vector2(0, 18), "%d/%d" % [inside, capacity], HORIZONTAL_ALIGNMENT_CENTER, 68, 16, Color("#3a2614"))


# ---------------------------------------------------------------- building shapes

## Footprint corners pulled toward the centre: [top, right, bottom, left].
static func _inset(g: PackedVector2Array, f: float) -> PackedVector2Array:
	var c := (g[0] + g[2]) / 2.0
	return PackedVector2Array([c.lerp(g[0], f), c.lerp(g[1], f), c.lerp(g[2], f), c.lerp(g[3], f)])


## The two walls you can see of a box standing on base (raised by lift). Returns the wall-top corners.
static func _box(ci: CanvasItem, base: PackedVector2Array, hgt: float, wall: Color, lift := 0.0) -> PackedVector2Array:
	var l := Vector2(0, -lift)
	var up := Vector2(0, -hgt - lift)
	ci.draw_colored_polygon(PackedVector2Array([base[3] + l, base[2] + l, base[2] + up, base[3] + up]), wall.darkened(0.12))
	ci.draw_colored_polygon(PackedVector2Array([base[2] + l, base[1] + l, base[1] + up, base[2] + up]), wall.darkened(0.3))
	return PackedVector2Array([base[0] + up, base[1] + up, base[2] + up, base[3] + up])


## A pitched roof over wall tops; the ridge runs back-left to front-right. Returns the ridge ends.
static func _gable(ci: CanvasItem, t: PackedVector2Array, rise: float, roof: Color, gable_wall: Color) -> PackedVector2Array:
	var r_a := t[0].lerp(t[3], 0.5) + Vector2(0, -rise)
	var r_b := t[1].lerp(t[2], 0.5) + Vector2(0, -rise)
	ci.draw_colored_polygon(PackedVector2Array([t[3], t[2], r_b, r_a]), roof)
	ci.draw_colored_polygon(PackedVector2Array([t[0], t[1], r_b, r_a]), roof.darkened(0.2))
	ci.draw_colored_polygon(PackedVector2Array([t[2], t[1], r_b]), gable_wall.darkened(0.3))
	ci.draw_line(r_a, r_b, roof.lightened(0.25), 3)
	return PackedVector2Array([r_a, r_b])


## A door on the left wall at a fraction along it.
static func _door(ci: CanvasItem, base: PackedVector2Array, at: float, width: float, hgt: float, col: Color, lift := 0.0) -> void:
	var foot := base[3].lerp(base[2], at) + Vector2(0, -lift)
	var dw := (base[2] - base[3]) * width
	var dh := Vector2(0, -hgt)
	ci.draw_colored_polygon(PackedVector2Array([foot - dw, foot + dw, foot + dw + dh, foot - dw + dh]), col)


static func _weathervane(ci: CanvasItem, ridge: Vector2) -> void:
	var gold := Color("#f2c230")
	ci.draw_line(ridge, ridge + Vector2(0, -26), Color("#5c3a1e"), 2.5)
	ci.draw_colored_polygon(PackedVector2Array([ridge + Vector2(0, -26), ridge + Vector2(16, -21), ridge + Vector2(0, -16)]), gold)
	ci.draw_circle(ridge + Vector2(0, -28), 3.0, gold)


## Fence posts and two rails around a ground outline, with a gap for a gate on the front-left side.
static func _fence(ci: CanvasItem, base: PackedVector2Array, wood: Color) -> void:
	for k in 4:
		var a := base[k]
		var b := base[(k + 1) % 4]
		var steps := 8
		for j in steps + 1:
			if k == 2 and j >= 3 and j <= 5:
				continue # the gate
			var p := a.lerp(b, float(j) / steps)
			ci.draw_line(p, p + Vector2(0, -16), wood.darkened(0.2), 3.5)
		for h in [-6.0, -13.0]:
			if k == 2:
				ci.draw_line(a + Vector2(0, h), a.lerp(b, 3.0 / 8) + Vector2(0, h), wood, 2.5)
				ci.draw_line(a.lerp(b, 5.0 / 8) + Vector2(0, h), b + Vector2(0, h), wood, 2.5)
			else:
				ci.draw_line(a + Vector2(0, h), b + Vector2(0, h), wood, 2.5)


static func _yard_shadow(ci: CanvasItem, g: PackedVector2Array, f := 0.42) -> void:
	var c := (g[0] + g[2]) / 2.0
	_ellipse(ci, c + Vector2(0, 6), (g[1].x - g[3].x) * f, (g[2].y - g[0].y) * f, Color(0, 0, 0, 0.12))


## Chicken Coop: a small hen house up on legs, with a ramp, nesting boxes and a run.
static func _coop(ci: CanvasItem, g: PackedVector2Array, it: Dictionary, level: int, inside: int, capacity: int, s: float) -> Vector2:
	var wall := Color.html(str(it.get("color", "#e9c46a")))
	var roof := Color.html(str(it.get("roof", "#b5482f")))
	var wood := Color("#8a5a32")
	_yard_shadow(ci, g)
	# Wire run in front, with a few hens pecking.
	var run := _inset(g, 0.9)
	ci.draw_colored_polygon(run, Color(0.85, 0.75, 0.5, 0.35))
	_fence(ci, run, Color("#d8d2c4"))
	var hens := mini(5, int(ceil(inside * 5.0 / maxf(1.0, capacity))))
	for k in hens:
		var p := run[3].lerp(run[2], 0.25 + 0.14 * k) + Vector2(6, -6)
		_ellipse(ci, p, 7, 6, Color("#fbf6ec"))
		ci.draw_circle(p + Vector2(5, -6), 4, Color("#fbf6ec"))
		ci.draw_circle(p + Vector2(5, -10), 2, Color("#e2453c"))
	var f := 0.5 + 0.06 * level
	var base := _inset(g, f)
	var lift := 16.0 * s * 0.5
	for p in [base[3], base[2], base[1]]:
		ci.draw_line(p, p + Vector2(0, -lift), wood, 4.0)
	var t := _box(ci, base, 26.0 * s * 0.6 + 6.0 * level, wall, lift)
	# Nesting boxes stick out of the right wall.
	for k in 2 + level:
		var at := base[2].lerp(base[1], 0.2 + 0.6 * k / float(1 + level)) + Vector2(0, -lift - 10)
		ci.draw_rect(Rect2(at + Vector2(-7, -10), Vector2(14, 10)), roof.darkened(0.1))
		ci.draw_circle(at + Vector2(0, -6), 3, Color("#f6e7c1"))
	# Pop-hole and ramp down to the ground.
	_door(ci, base, 0.5, 0.12, 16, Color("#3a2614"), lift)
	var hole := base[3].lerp(base[2], 0.5) + Vector2(0, -lift)
	var foot := hole + Vector2(-34, 22)
	ci.draw_line(hole, foot, wood.lightened(0.15), 7.0)
	for k in 4:
		var q := hole.lerp(foot, 0.2 + 0.2 * k)
		ci.draw_line(q + Vector2(-3, -3), q + Vector2(3, 3), wood.darkened(0.2), 2.0)
	var ridge := _gable(ci, t, 22.0 * s * 0.6, roof, wall)
	if level >= 2:
		ci.draw_polyline(PackedVector2Array([t[3], t[2], t[1]]), Color("#fbf6ec"), 3.0)
	if level >= 3:
		_weathervane(ci, ridge[0].lerp(ridge[1], 0.5))
	return ridge[1] + Vector2(0, -26)


## Dairy Farm: a tall red barn with a two-slope (gambrel) roof, a silo and milk cans.
static func _dairy(ci: CanvasItem, g: PackedVector2Array, it: Dictionary, level: int, _s: float) -> Vector2:
	var wall := Color.html(str(it.get("color", "#c0392b")))
	var roof := Color.html(str(it.get("roof", "#6b4a3a")))
	_yard_shadow(ci, g)
	var base := _inset(g, 0.66 + 0.06 * level)
	# Silo behind the barn's right end.
	var silo := base[1].lerp(base[0], 0.4) + Vector2(10, 0)
	var sw := 30.0
	var sh := 120.0 + 14.0 * level
	ci.draw_rect(Rect2(silo + Vector2(-sw / 2.0, -sh), Vector2(sw, sh)), Color("#d7dde3"))
	ci.draw_rect(Rect2(silo + Vector2(-sw / 2.0, -sh), Vector2(sw * 0.35, sh)), Color("#eef2f5"))
	for k in 5:
		ci.draw_line(silo + Vector2(-sw / 2.0, -sh * (0.15 + k * 0.17)), silo + Vector2(sw / 2.0, -sh * (0.15 + k * 0.17)), Color("#aab3bb"), 1.5)
	ci.draw_circle(silo + Vector2(0, -sh), sw / 2.0, roof.lightened(0.15))
	var hgt := 52.0 + 8.0 * level
	var t := _box(ci, base, hgt, wall)
	# Big doors with the white X.
	var foot := base[3].lerp(base[2], 0.5)
	var dw := (base[2] - base[3]) * 0.16
	var dh := Vector2(0, -hgt * 0.72)
	ci.draw_colored_polygon(PackedVector2Array([foot - dw, foot + dw, foot + dw + dh, foot - dw + dh]), wall.darkened(0.35))
	var white := Color("#fbf6ec")
	ci.draw_polyline(PackedVector2Array([foot - dw, foot + dw, foot + dw + dh, foot - dw + dh, foot - dw]), white, 2.5)
	ci.draw_line(foot - dw, foot + dw + dh, white, 2.5)
	ci.draw_line(foot + dw, foot - dw + dh, white, 2.5)
	ci.draw_polyline(PackedVector2Array([base[3] + Vector2(0, -hgt), base[2] + Vector2(0, -hgt), base[1] + Vector2(0, -hgt)]), white, 3.0)
	# Gambrel roof: steep lower slopes, shallow upper ones.
	var mid_l := PackedVector2Array([t[3].lerp(t[0], 0.18) + Vector2(0, -22), t[2].lerp(t[1], 0.18) + Vector2(0, -22)])
	var mid_r := PackedVector2Array([t[0].lerp(t[3], 0.18) + Vector2(0, -22), t[1].lerp(t[2], 0.18) + Vector2(0, -22)])
	var r_a := t[0].lerp(t[3], 0.5) + Vector2(0, -36)
	var r_b := t[1].lerp(t[2], 0.5) + Vector2(0, -36)
	ci.draw_colored_polygon(PackedVector2Array([t[3], t[2], mid_l[1], mid_l[0]]), roof)
	ci.draw_colored_polygon(PackedVector2Array([mid_l[0], mid_l[1], r_b, r_a]), roof.lightened(0.1))
	ci.draw_colored_polygon(PackedVector2Array([t[0], t[1], mid_r[1], mid_r[0]]), roof.darkened(0.25))
	ci.draw_colored_polygon(PackedVector2Array([mid_r[0], mid_r[1], r_b, r_a]), roof.darkened(0.15))
	ci.draw_colored_polygon(PackedVector2Array([t[2], t[1], mid_r[1], r_b, mid_l[1]]), wall.darkened(0.3))
	ci.draw_circle(t[2].lerp(t[1], 0.5) + Vector2(0, -18), 7, Color("#f4e3c3")) # hayloft window
	ci.draw_line(r_a, r_b, roof.lightened(0.3), 3)
	# Milk cans by the door.
	for k in 2 + mini(level, 2):
		var cp := base[2] + Vector2(-34 + k * 12, 12)
		ci.draw_rect(Rect2(cp + Vector2(-5, -16), Vector2(10, 16)), Color("#c9d1d8"))
		ci.draw_rect(Rect2(cp + Vector2(-3, -20), Vector2(6, 4)), Color("#9aa4ad"))
	if level >= 3:
		_weathervane(ci, r_a.lerp(r_b, 0.5))
	return r_b + Vector2(0, -26)


## Horse Stable: long and low, a row of half-doors with horses looking out, hay bales in front.
static func _stable(ci: CanvasItem, g: PackedVector2Array, it: Dictionary, level: int, _s: float) -> Vector2:
	var wall := Color.html(str(it.get("color", "#a8743f")))
	var roof := Color.html(str(it.get("roof", "#3f5f7a")))
	_yard_shadow(ci, g)
	var base := _inset(g, 0.82)
	# Make it long: squash the depth so the left wall runs the length of the footprint.
	var c := (base[0] + base[2]) / 2.0
	base[0] = base[0].lerp(base[3], 0.55)
	base[1] = base[1].lerp(base[2], 0.55)
	var hgt := 34.0 + 2.0 * level
	var t := _box(ci, base, hgt, wall)
	var stalls := 2 + level
	var horse := Color("#7a4a2a")
	for k in stalls:
		var at := (k + 0.5) / stalls
		var foot := base[3].lerp(base[2], at)
		var dw := (base[2] - base[3]) * (0.3 / stalls)
		var top_half := Vector2(0, -hgt * 0.75)
		var mid := Vector2(0, -hgt * 0.4)
		ci.draw_colored_polygon(PackedVector2Array([foot - dw, foot + dw, foot + dw + mid, foot - dw + mid]), wall.darkened(0.4))
		ci.draw_colored_polygon(PackedVector2Array([foot - dw + mid, foot + dw + mid, foot + dw + top_half, foot - dw + top_half]), Color("#2b1d12"))
		ci.draw_line(foot - dw + mid, foot + dw + mid, Color("#f4e3c3"), 2.0)
		if k % 2 == 0:
			ci.draw_circle(foot + mid + Vector2(0, -8), 6, horse) # a horse looking out
	# Low hip roof with a little cupola.
	var r_a := t[0].lerp(t[3], 0.5) + Vector2(0, -18)
	var r_b := t[1].lerp(t[2], 0.5) + Vector2(0, -18)
	r_a = r_a.lerp(r_b, 0.12)
	r_b = r_b.lerp(r_a, 0.12)
	ci.draw_colored_polygon(PackedVector2Array([t[3], t[2], r_b, r_a]), roof)
	ci.draw_colored_polygon(PackedVector2Array([t[0], t[1], r_b, r_a]), roof.darkened(0.2))
	ci.draw_colored_polygon(PackedVector2Array([t[2], t[1], r_b]), roof.darkened(0.3))
	var cup := r_a.lerp(r_b, 0.5)
	ci.draw_rect(Rect2(cup + Vector2(-8, -14), Vector2(16, 14)), Color("#fbf6ec"))
	ci.draw_colored_polygon(PackedVector2Array([cup + Vector2(-11, -14), cup + Vector2(11, -14), cup + Vector2(0, -26)]), roof.lightened(0.15))
	# Hay bales in front.
	for k in mini(level, 3):
		var hp := base[2] + Vector2(-46 + k * 20, 16)
		ci.draw_rect(Rect2(hp + Vector2(-9, -12), Vector2(18, 12)), Color("#e3c46a"))
		ci.draw_line(hp + Vector2(-9, -6), hp + Vector2(9, -6), Color("#b8963e"), 1.5)
	if level >= 3:
		_weathervane(ci, cup + Vector2(0, -26))
	return c + Vector2(0, -hgt - 60)


## Nursery Barn: a small pastel barn with a heart sign and a little pen for the babies.
static func _nursery(ci: CanvasItem, g: PackedVector2Array, it: Dictionary, level: int, _s: float) -> Vector2:
	var wall := Color.html(str(it.get("color", "#e9d8a6")))
	var roof := Color.html(str(it.get("roof", "#7a9e7e")))
	_yard_shadow(ci, g)
	# Pen on the front half of the footprint.
	var pen := PackedVector2Array([g[0].lerp(g[2], 0.45).lerp(g[3], 0.1), g[1].lerp(g[3], 0.1).lerp(g[2], 0.45),
		g[2].lerp(g[0], 0.08), g[3].lerp(g[1], 0.1).lerp(g[2], 0.45)])
	ci.draw_colored_polygon(pen, Color("#b9df8a"))
	_fence(ci, pen, Color("#f4efe4"))
	var base := _inset(g, 0.5 + 0.05 * level)
	var shift := (g[0] - g[2]) * 0.18
	for k in 4:
		base[k] += shift
	var hgt := 40.0 + 6.0 * level
	var t := _box(ci, base, hgt, wall)
	_door(ci, base, 0.5, 0.14, hgt * 0.6, Color("#c98fa0"))
	var ridge := _gable(ci, t, 26.0, roof, wall)
	# Heart on the gable end.
	var heart := t[2].lerp(t[1], 0.5) + Vector2(0, -12)
	var pink := Color("#ef6f8f")
	ci.draw_circle(heart + Vector2(-4, -2), 5, pink)
	ci.draw_circle(heart + Vector2(4, -2), 5, pink)
	ci.draw_colored_polygon(PackedVector2Array([heart + Vector2(-9, 0), heart + Vector2(9, 0), heart + Vector2(0, 10)]), pink)
	# Baby bottle by the pen.
	var bottle := pen[2] + Vector2(18, -4)
	ci.draw_rect(Rect2(bottle + Vector2(-4, -14), Vector2(8, 14)), Color("#fbf6ec"))
	ci.draw_rect(Rect2(bottle + Vector2(-2, -19), Vector2(4, 5)), Color("#f2a33a"))
	if level >= 2:
		ci.draw_polyline(PackedVector2Array([t[3], t[2], t[1]]), Color("#fbf6ec"), 3.0)
	if level >= 3:
		_weathervane(ci, ridge[0].lerp(ridge[1], 0.5))
	return ridge[1] + Vector2(0, -26)


## Beehive: stacked white hive boxes on a stand. More bees, more boxes, and bees buzz around it.
static func _hive(ci: CanvasItem, g: PackedVector2Array, inside: int, capacity: int, _s: float) -> Vector2:
	_yard_shadow(ci, g, 0.3)
	var c := (g[0] + g[2]) / 2.0
	# Flowers around the stand.
	var petals := [Color("#ff6b8a"), Color("#ffd34d"), Color("#b98cff"), Color("#ff8a4d")]
	for k in 8:
		var a := TAU * k / 8.0
		var p := c + Vector2(cos(a) * 58, sin(a) * 26)
		ci.draw_line(p, p + Vector2(0, -8), STEM, 2.0)
		ci.draw_circle(p + Vector2(0, -9), 4, petals[k % 4])
	var base := _inset(g, 0.34)
	for p in [base[3], base[2], base[1]]:
		ci.draw_line(p, p + Vector2(0, -12), Color("#7a4f2c"), 4.0)
	var boxes := 1 + clampi(int(3.0 * inside / maxf(1.0, capacity) + 0.999), 0, 3)
	var white := Color("#f6f1e4")
	var t := PackedVector2Array()
	for k in boxes:
		t = _box(ci, base, 20.0, white if k % 2 == 0 else Color("#f2e3b8"), 12.0 + 20.0 * k)
		ci.draw_line(base[3].lerp(base[2], 0.2) + Vector2(0, -22 - 20.0 * k), base[3].lerp(base[2], 0.8) + Vector2(0, -22 - 20.0 * k), Color("#c9b98f"), 1.5)
	# Flat lid and the entrance slot.
	var lid := Vector2(0, -6)
	ci.draw_colored_polygon(PackedVector2Array([t[0] + lid, t[1] + lid, t[2] + lid, t[3] + lid]), Color("#c98a1a"))
	ci.draw_colored_polygon(PackedVector2Array([t[3], t[2], t[2] + lid, t[3] + lid]), Color("#a8700f"))
	ci.draw_colored_polygon(PackedVector2Array([t[2], t[1], t[1] + lid, t[2] + lid]), Color("#8a5c0c"))
	var slot := base[3].lerp(base[2], 0.5) + Vector2(0, -15)
	ci.draw_line(slot + Vector2(-8, 0), slot + Vector2(8, 0), Color("#3a2614"), 3.0)
	# Bees buzzing around: one for every 25 inside.
	var tsec := Time.get_ticks_msec() / 1000.0
	var top_c := (t[0] + t[2]) / 2.0
	for k in mini(8, int(ceil(inside / 25.0))):
		var a := tsec * (1.4 + 0.2 * k) + k * 1.7
		var p := top_c + Vector2(cos(a) * (30 + 6 * k), sin(a * 1.3) * 14 - 10)
		ci.draw_circle(p, 3.5, Color("#f2c230"))
		ci.draw_line(p + Vector2(-1, -3), p + Vector2(-1, 3), Color("#2b2420"), 1.5)
		ci.draw_circle(p + Vector2(0, -4), 2, Color(1, 1, 1, 0.7))
	return top_c + Vector2(0, -34)


## Orchard: a fenced field with trees in rows, filling up as trees move in.
static func _orchard(ci: CanvasItem, g: PackedVector2Array, level: int, inside: int, _s: float) -> Vector2:
	var field := _inset(g, 0.94)
	ci.draw_colored_polygon(field, Color("#9fd36c"))
	var rows := 3
	var shown := mini(inside, rows * rows)
	var k := 0
	for r in rows:
		for col in rows:
			var u := (r + 0.5) / rows
			var v := (col + 0.5) / rows
			var p := field[0].lerp(field[3], u).lerp(field[1].lerp(field[2], u), v)
			if k < shown:
				ci.draw_rect(Rect2(p + Vector2(-3, -16), Vector2(6, 16)), Color("#7a4f2c"))
				ci.draw_circle(p + Vector2(0, -26), 15, LEAF_DARK)
				ci.draw_circle(p + Vector2(-3, -30), 11, LEAF)
				ci.draw_circle(p + Vector2(6, -24), 3, Color("#e2453c"))
				ci.draw_circle(p + Vector2(-7, -22), 3, Color("#e2453c"))
			else:
				_ellipse(ci, p, 10, 5, SOIL) # an empty spot waiting for a tree
			k += 1
	_fence(ci, field, Color("#c9a26a") if level < 2 else Color("#f4efe4"))
	# Ladder and fruit basket by the gate.
	var gate := field[3].lerp(field[2], 0.5)
	ci.draw_rect(Rect2(gate + Vector2(14, -10), Vector2(18, 10)), Color("#a8743f"))
	for j in 3:
		ci.draw_circle(gate + Vector2(18 + j * 5, -11), 3.5, Color("#e2453c"))
	if level >= 3:
		var arch_l := field[3].lerp(field[2], 3.0 / 8)
		var arch_r := field[3].lerp(field[2], 5.0 / 8)
		ci.draw_line(arch_l, arch_l + Vector2(0, -34), Color("#7a4f2c"), 4)
		ci.draw_line(arch_r, arch_r + Vector2(0, -34), Color("#7a4f2c"), 4)
		ci.draw_line(arch_l + Vector2(0, -34), arch_r + Vector2(0, -34), Color("#7a4f2c"), 5)
	return (field[0] + field[2]) / 2.0 + Vector2(0, -80)


## Pig Pen: a fenced mud yard with a puddle, a trough and a little lean-to shed.
static func _pig_pen(ci: CanvasItem, g: PackedVector2Array, it: Dictionary, inside: int, _s: float) -> Vector2:
	var roof := Color.html(str(it.get("roof", "#7a5230")))
	var yard := _inset(g, 0.94)
	ci.draw_colored_polygon(yard, Color("#b98a5a"))
	var c := (yard[0] + yard[2]) / 2.0
	_ellipse(ci, c + Vector2(-10, 16), 54, 20, Color("#6e4a2c"))
	_ellipse(ci, c + Vector2(-18, 12), 22, 7, Color(1, 1, 1, 0.12))
	# Lean-to shed at the back corner.
	var shed := PackedVector2Array([yard[0], yard[0].lerp(yard[1], 0.45), Vector2.ZERO, yard[0].lerp(yard[3], 0.4)])
	shed[2] = shed[1] + (shed[3] - shed[0])
	var t := _box(ci, shed, 30.0, Color("#a8743f"))
	ci.draw_colored_polygon(PackedVector2Array([t[0] + Vector2(0, -12), t[1] + Vector2(0, -12), t[2], t[3]]), roof)
	ci.draw_colored_polygon(PackedVector2Array([t[3], t[2], t[2] + Vector2(0, 6), t[3] + Vector2(0, 6)]), roof.darkened(0.25))
	# Trough.
	var trough := yard[2].lerp(yard[1], 0.35) + Vector2(-6, -14)
	ci.draw_colored_polygon(PackedVector2Array([trough + Vector2(-22, 0), trough + Vector2(10, -12), trough + Vector2(18, -8), trough + Vector2(-14, 4)]), Color("#8a5a32"))
	# Pigs: one drawn for every few inside.
	var pink := Color("#f4b6b8")
	for k in mini(5, int(ceil(inside / 6.0))):
		var p := c + Vector2(-40 + k * 22, -6 + (k % 2) * 18)
		_ellipse(ci, p, 13, 8, pink)
		ci.draw_circle(p + Vector2(12, -3), 6, pink)
		_ellipse(ci, p + Vector2(17, -2), 3, 2.5, Color("#d9878b"))
	_fence(ci, yard, Color("#9a6a3a"))
	return c + Vector2(0, -78)


## Tinted footprint shown while placing: green where it fits, red where it doesn't.
static func draw_footprint(ci: CanvasItem, corners: PackedVector2Array, ok: bool) -> void:
	var fill := Color(0.45, 0.95, 0.4, 0.35) if ok else Color(1.0, 0.3, 0.25, 0.4)
	ci.draw_colored_polygon(corners, fill)
	var edge := PackedVector2Array(corners)
	edge.append(corners[0])
	ci.draw_polyline(edge, Color(1, 1, 1, 0.9), 2.5)


## Small green pellets on the soil mark a fertilized plot.
static func draw_fertilizer(ci: CanvasItem, top: Vector2, w: float, h: float) -> void:
	var c := top + Vector2(0, h / 2.0)
	var pellet := Color("#7fd35b")
	for o in [Vector2(-0.3, 0.05), Vector2(0.28, -0.04), Vector2(-0.1, 0.28), Vector2(0.12, -0.3), Vector2(0.34, 0.2), Vector2(-0.36, -0.18)]:
		ci.draw_circle(c + Vector2(o.x * w * 0.5, o.y * h * 0.5), 3.2, pellet)
		ci.draw_circle(c + Vector2(o.x * w * 0.5 - 1, o.y * h * 0.5 - 1), 1.2, Color(1, 1, 1, 0.6))


## Land not yet bought: a dim, dashed-edged area the farm can grow into.
static func draw_wild_land(ci: CanvasItem, corners: PackedVector2Array) -> void:
	ci.draw_colored_polygon(corners, Color(0.42, 0.62, 0.3, 0.45))
	for k in 4:
		var a := corners[k]
		var b := corners[(k + 1) % 4]
		var steps := 24
		for j in steps:
			if j % 2 == 0:
				ci.draw_line(a.lerp(b, float(j) / steps), a.lerp(b, float(j + 1) / steps), Color(1, 1, 1, 0.5), 2.0)


## A heart in a bubble over a stray animal: tap to adopt.
static func draw_stray_marker(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_circle(at, 16, Color("#fffaf0"))
	ci.draw_arc(at, 16, 0, TAU, 24, Color("#5c3a1e"), 2)
	var red := Color("#e2453c")
	ci.draw_circle(at + Vector2(-4, -2), 5, red)
	ci.draw_circle(at + Vector2(4, -2), 5, red)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-9, 0), at + Vector2(9, 0), at + Vector2(0, 10)]), red)



static func _mailbox(ci: CanvasItem, ground: Vector2, it: Dictionary) -> void:
	var box := Color.html(str(it.get("color", "#3f6fb5")))
	_shadow(ci, ground + Vector2(0, 2), 16, 6)
	ci.draw_line(ground, ground + Vector2(0, -30), Color("#7a4f2c"), 5)
	ci.draw_rect(Rect2(ground + Vector2(-14, -48), Vector2(28, 18)), box)
	ci.draw_circle(ground + Vector2(-14, -39), 9, box.lightened(0.1))
	ci.draw_line(ground + Vector2(12, -48), ground + Vector2(12, -60), Color("#e2453c"), 3)
	ci.draw_rect(Rect2(ground + Vector2(12, -60), Vector2(9, 6)), Color("#e2453c"))


static func _farm_stand(ci: CanvasItem, ground: Vector2, it: Dictionary) -> void:
	var awning := Color.html(str(it.get("color", "#c0392b")))
	_shadow(ci, ground + Vector2(0, 2), 30, 10)
	var wood := Color("#a8743f")
	ci.draw_line(ground + Vector2(-24, 0), ground + Vector2(-24, -44), wood, 4)
	ci.draw_line(ground + Vector2(24, 0), ground + Vector2(24, -44), wood, 4)
	ci.draw_rect(Rect2(ground + Vector2(-28, -18), Vector2(56, 10)), wood.darkened(0.15))
	for k in 4:
		ci.draw_circle(ground + Vector2(-16 + k * 11, -22), 5, [Color("#e2453c"), Color("#f28a2e"), Color("#7ccf5a"), Color("#f7c51e")][k])
	for k in 4:
		var x := -30.0 + k * 15.0
		ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(x, -52), ground + Vector2(x + 15, -52), ground + Vector2(x + 15, -42), ground + Vector2(x, -42)]), awning if k % 2 == 0 else Color("#fbefd2"))



## Level 2: a white trim along the eaves and a picket fence around the front of the yard.
static func _upgrade_trim(ci: CanvasItem, g: PackedVector2Array, left: Vector2, bottom: Vector2, right: Vector2, up: Vector2, roof: Color) -> void:
	var trim := Color("#fbf6ec")
	ci.draw_polyline(PackedVector2Array([left + up, bottom + up, right + up]), trim, 4.0)
	var fence := Color("#f4efe4")
	var shade := Color("#cfc6b4")
	# Pickets along the two front edges of the footprint, set in a little from the corners.
	for edge in [[g[3], g[2]], [g[2], g[1]]]:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var steps := 10
		for k in range(1, steps):
			var p := a.lerp(b, float(k) / steps) + Vector2(0, -2)
			ci.draw_line(p, p + Vector2(0, -14), fence, 3.0)
			ci.draw_circle(p + Vector2(0, -14), 1.6, fence)
		ci.draw_line(a.lerp(b, 0.08) + Vector2(0, -9), a.lerp(b, 0.92) + Vector2(0, -9), shade, 2.0)


## Level 3: a silo beside the building, flower boxes and a golden weathervane on the roof.
static func _upgrade_top(ci: CanvasItem, right: Vector2, bottom: Vector2, up: Vector2, ridge: Vector2, s: float) -> void:
	# Silo: a cylinder standing just behind the right wall.
	var base := right.lerp(bottom, 0.18) + Vector2(14, -4)
	var w := 22.0 * maxf(1.0, s * 0.6)
	var h := -up.y + 26.0
	ci.draw_rect(Rect2(base + Vector2(-w / 2.0, -h), Vector2(w, h)), Color("#d7dde3"))
	ci.draw_rect(Rect2(base + Vector2(-w / 2.0, -h), Vector2(w * 0.35, h)), Color("#eef2f5"))
	for k in 4:
		ci.draw_line(base + Vector2(-w / 2.0, -h * (0.2 + k * 0.2)), base + Vector2(w / 2.0, -h * (0.2 + k * 0.2)), Color("#aab3bb"), 1.5)
	var dome := base + Vector2(0, -h)
	ci.draw_circle(dome, w / 2.0, Color("#b84a3a"))
	ci.draw_rect(Rect2(dome + Vector2(-w / 2.0, 0), Vector2(w, 3)), Color("#8f3528"))
	# Flower boxes under the front wall.
	for k in 2:
		var c := bottom.lerp(right, 0.3 + 0.4 * k) + up * 0.35
		ci.draw_rect(Rect2(c + Vector2(-9, 0), Vector2(18, 6)), Color("#7a4f2c"))
		for f in 3:
			ci.draw_circle(c + Vector2(-6 + f * 6, -2), 3.0, [Color("#ff6b8a"), Color("#ffd34d"), Color("#ff8a4d")][f])
	# Golden weathervane on the ridge.
	var gold := Color("#f2c230")
	ci.draw_line(ridge, ridge + Vector2(0, -26), Color("#5c3a1e"), 2.5)
	ci.draw_colored_polygon(PackedVector2Array([ridge + Vector2(0, -26), ridge + Vector2(16, -21), ridge + Vector2(0, -16)]), gold)
	ci.draw_circle(ridge + Vector2(0, -28), 3.0, gold)



## A building frame under construction: a floor, wooden posts and scaffold rails.
static func draw_frame(ci: CanvasItem, g: PackedVector2Array, it: Dictionary) -> void:
	var c := (g[0] + g[2]) / 2.0
	var top := c.lerp(g[0], 0.78)
	var right := c.lerp(g[1], 0.78)
	var bottom := c.lerp(g[2], 0.78)
	var left := c.lerp(g[3], 0.78)
	var floor_col := Color("#c9a77a")
	ci.draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), floor_col)
	ci.draw_polyline(PackedVector2Array([top, right, bottom, left, top]), floor_col.darkened(0.3), 2.0)
	var wood := Color("#a8743f")
	var up := Vector2(0, -46)
	for p in [left, bottom, right, top]:
		ci.draw_line(p, p + up, wood, 5.0)
	for k in 2:
		var h := up * (0.45 + 0.5 * k)
		ci.draw_polyline(PackedVector2Array([left + h, bottom + h, right + h]), wood.darkened(0.15), 3.0)
	ci.draw_line(left + up * 0.95, bottom + up * 0.1, wood.darkened(0.25), 2.5) # cross brace
	# A little stack of bricks and boards in front.
	var pile := bottom + Vector2(-26, 10)
	for k in 3:
		ci.draw_rect(Rect2(pile + Vector2(k * 9, -6), Vector2(8, 6)), Color("#b5523b"))
	ci.draw_rect(Rect2(pile + Vector2(0, -12), Vector2(30, 5)), Color("#d4a76a"))
	var sign_pos := c + Vector2(-40, -70)
	ci.draw_rect(Rect2(sign_pos, Vector2(80, 22)), Color("#ffd34d"))
	ci.draw_rect(Rect2(sign_pos, Vector2(80, 22)), Color("#5c3a1e"), false, 2)
	ci.draw_string(ThemeDB.fallback_font, sign_pos + Vector2(0, 16), "Building", HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Color("#3a2614"))


# ---------------------------------------------------------------- vehicles

## Side-on vehicles facing right: body, cab, big back wheel, small front wheel, and each one's tool.
static func _vehicle(ci: CanvasItem, ground: Vector2, it: Dictionary) -> void:
	var body := Color.html(str(it.get("color", "#c0392b")))
	var dark := Color.html(str(it.get("accent", "#2b2b30")))
	var id: String = it.get("id", "")
	var big := 1.25 if id == "combine" else 1.0
	_shadow(ci, ground + Vector2(0, 2), 40 * big, 13 * big)
	var o := ground + Vector2(0, -6)
	match id:
		"harvester", "combine":
			# A wide header with a reel at the front, a grain tank on top.
			ci.draw_rect(Rect2(o + Vector2(-30, -40) * big, Vector2(52, 26) * big), body)
			ci.draw_rect(Rect2(o + Vector2(-26, -58) * big, Vector2(26, 18) * big), body.lightened(0.15))
			ci.draw_rect(Rect2(o + Vector2(-24, -56) * big, Vector2(10, 10) * big), Color("#bfe3f2"))
			ci.draw_rect(Rect2(o + Vector2(22, -26) * big, Vector2(16, 18) * big), dark)
			for k in 4:
				ci.draw_line(o + Vector2(24, -24 + k * 5) * big, o + Vector2(36, -24 + k * 5) * big, body, 2)
			if id == "combine":
				ci.draw_rect(Rect2(o + Vector2(-40, -36), Vector2(10, 18)), dark.darkened(0.1)) # seed box
				ci.draw_line(o + Vector2(-48, -16), o + Vector2(-34, -24), dark, 3) # plow blade
		"seeder":
			# A tractor body pulling a hopper with seed tubes.
			ci.draw_rect(Rect2(o + Vector2(-6, -34), Vector2(34, 20)), body)
			ci.draw_rect(Rect2(o + Vector2(0, -50), Vector2(18, 16)), body.lightened(0.15))
			ci.draw_rect(Rect2(o + Vector2(3, -47), Vector2(8, 8)), Color("#bfe3f2"))
			ci.draw_rect(Rect2(o + Vector2(-40, -36), Vector2(26, 18)), Color("#e3c46a"))
			for k in 3:
				ci.draw_line(o + Vector2(-36 + k * 9, -18), o + Vector2(-36 + k * 9, -4), dark, 2)
		_:
			# Tractor: a hood, a cab and an exhaust stack.
			ci.draw_rect(Rect2(o + Vector2(-20, -34), Vector2(44, 20)), body)
			ci.draw_rect(Rect2(o + Vector2(-18, -54), Vector2(20, 20)), body.lightened(0.15))
			ci.draw_rect(Rect2(o + Vector2(-15, -51), Vector2(9, 9)), Color("#bfe3f2"))
			ci.draw_line(o + Vector2(14, -34), o + Vector2(14, -48), dark, 3)
			ci.draw_line(o + Vector2(-30, -16), o + Vector2(-22, -24), dark, 3) # hitch
	# Wheels.
	ci.draw_circle(o + Vector2(-12, -12) * big, 13 * big, dark)
	ci.draw_circle(o + Vector2(-12, -12) * big, 5 * big, body.lightened(0.3))
	ci.draw_circle(o + Vector2(18, -8) * big, 8 * big, dark)
	ci.draw_circle(o + Vector2(18, -8) * big, 3 * big, body.lightened(0.3))


## The Combine's chassis before it's finished: a bare frame on wheels with a parts pile.
static func draw_chassis(ci: CanvasItem, g: PackedVector2Array, _it: Dictionary) -> void:
	var c := (g[0] + g[2]) / 2.0 + Vector2(0, -6)
	_shadow(ci, c + Vector2(0, 8), 44, 14)
	var steel := Color("#8a949c")
	ci.draw_line(c + Vector2(-34, -16), c + Vector2(30, -16), steel, 5)
	ci.draw_line(c + Vector2(-34, -30), c + Vector2(16, -30), steel, 4)
	for x in [-30.0, -6.0, 14.0]:
		ci.draw_line(c + Vector2(x, -16), c + Vector2(x, -30), steel, 3)
	ci.draw_circle(c + Vector2(-16, -8), 13, Color("#2b2b30"))
	ci.draw_circle(c + Vector2(20, -6), 8, Color("#2b2b30"))
	for k in 3:
		ci.draw_rect(Rect2(c + Vector2(30 + k * 7, -4 - k * 3), Vector2(8, 6)), Color("#c9d1d8"))
	var sign_pos := c + Vector2(-40, -70)
	ci.draw_rect(Rect2(sign_pos, Vector2(80, 22)), Color("#ffd34d"))
	ci.draw_rect(Rect2(sign_pos, Vector2(80, 22)), Color("#5c3a1e"), false, 2)
	ci.draw_string(ThemeDB.fallback_font, sign_pos + Vector2(0, 16), "Chassis", HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Color("#3a2614"))


## Garage: a grey workshop with a big roll-up door, a wrench sign and a fuel pump.
static func _garage(ci: CanvasItem, g: PackedVector2Array, it: Dictionary, inside: int, _s: float) -> Vector2:
	var wall := Color.html(str(it.get("color", "#9aa4ad")))
	var roof := Color.html(str(it.get("roof", "#4a5560")))
	_yard_shadow(ci, g)
	# Concrete apron in front.
	var apron := _inset(g, 0.92)
	ci.draw_colored_polygon(PackedVector2Array([apron[3], apron[2], apron[2].lerp(apron[1], 0.5), apron[3].lerp(apron[0], 0.5)]), Color("#cfcabf"))
	var base := _inset(g, 0.68)
	var hgt := 48.0
	var t := _box(ci, base, hgt, wall)
	# Roll-up door with slats; parked vehicles peek out when there are any.
	var foot := base[3].lerp(base[2], 0.5)
	var dw := (base[2] - base[3]) * 0.3
	var dh := Vector2(0, -hgt * 0.75)
	ci.draw_colored_polygon(PackedVector2Array([foot - dw, foot + dw, foot + dw + dh, foot - dw + dh]), Color("#3a3f45") if inside > 0 else wall.lightened(0.2))
	for k in 5:
		var y := dh * (0.2 + 0.16 * k)
		ci.draw_line(foot - dw + y, foot + dw + y, wall.darkened(0.2), 1.5)
	if inside > 0:
		ci.draw_circle(foot + Vector2(-6, -8), 7, Color("#2b2b30"))
		ci.draw_rect(Rect2(foot + Vector2(-14, -26), Vector2(26, 12)), Color("#c0392b"))
	# Flat roof with a lip.
	ci.draw_colored_polygon(PackedVector2Array([t[0] + Vector2(0, -6), t[1] + Vector2(0, -6), t[2] + Vector2(0, -6), t[3] + Vector2(0, -6)]), roof)
	ci.draw_colored_polygon(PackedVector2Array([t[3], t[2], t[2] + Vector2(0, -6), t[3] + Vector2(0, -6)]), roof.darkened(0.2))
	ci.draw_colored_polygon(PackedVector2Array([t[2], t[1], t[1] + Vector2(0, -6), t[2] + Vector2(0, -6)]), roof.darkened(0.35))
	# Wrench sign on the right wall.
	var sign_c := base[2].lerp(base[1], 0.5) + Vector2(0, -hgt * 0.55)
	ci.draw_circle(sign_c, 11, Color("#ffd34d"))
	ci.draw_line(sign_c + Vector2(-5, 5), sign_c + Vector2(5, -5), Color("#3a2614"), 3)
	ci.draw_circle(sign_c + Vector2(5, -5), 3.5, Color("#3a2614"))
	# Fuel pump by the apron.
	var pump := apron[2].lerp(apron[1], 0.25) + Vector2(-4, -6)
	ci.draw_rect(Rect2(pump + Vector2(-7, -26), Vector2(14, 26)), Color("#e2453c"))
	ci.draw_rect(Rect2(pump + Vector2(-4, -22), Vector2(8, 6)), Color("#fbefd2"))
	ci.draw_line(pump + Vector2(7, -16), pump + Vector2(12, -4), Color("#2b2b30"), 2)
	return (t[0] + t[2]) / 2.0 + Vector2(0, -36)


# ---------------------------------------------------------------- decorations

## Decorations by shape. corners = the footprint on the ground, ground = its centre.
static func _decor(ci: CanvasItem, g: PackedVector2Array, ground: Vector2, it: Dictionary) -> void:
	var col := Color.html(str(it.get("color", "#a8743f")))
	var acc := Color.html(str(it.get("accent", "#5c3a1e")))
	match it.get("shape", ""):
		"path":
			var tile := _inset(g, 0.98)
			ci.draw_colored_polygon(tile, col)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(it.get("id", ""))
			for k in 6:
				var p := ground + Vector2(rng.randf_range(-34, 34), rng.randf_range(-12, 12))
				_ellipse(ci, p, 9, 4, col.darkened(0.15))
		"fence", "hedge", "wall":
			# Runs along the tile's back-left to front-right diagonal; Rotate turns it.
			var a := g[3].lerp(g[0], 0.5)
			var b := g[1].lerp(g[2], 0.5)
			if it["shape"] == "hedge":
				for k in 5:
					var p := a.lerp(b, 0.1 + 0.2 * k)
					ci.draw_circle(p + Vector2(0, -12), 13, col)
					ci.draw_circle(p + Vector2(-3, -17), 6, col.lightened(0.15))
			elif it["shape"] == "wall":
				for row in 3:
					for k in 4:
						var p := a.lerp(b, 0.12 + 0.25 * k + (0.12 if row % 2 == 1 else 0.0) * 0.5) + Vector2(0, -6 - row * 9)
						_ellipse(ci, p, 11, 5, col.darkened(0.05 * ((k + row) % 3)))
			else:
				for k in 5:
					var p := a.lerp(b, 0.1 + 0.2 * k)
					ci.draw_line(p, p + Vector2(0, -24), col.darkened(0.15), 4.0)
					ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-2, -24), p + Vector2(2, -24), p + Vector2(0, -28)]), col.darkened(0.15))
				for h in [-9.0, -18.0]:
					ci.draw_line(a + Vector2(0, h), b + Vector2(0, h), col, 3.0)
		"haybale":
			_shadow(ci, ground + Vector2(0, 2), 26, 9)
			ci.draw_rect(Rect2(ground + Vector2(-22, -22), Vector2(44, 22)), col)
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-22, -22), ground + Vector2(22, -22), ground + Vector2(30, -30), ground + Vector2(-14, -30)]), col.lightened(0.1))
			ci.draw_line(ground + Vector2(-8, -22), ground + Vector2(-8, 0), acc, 2)
			ci.draw_line(ground + Vector2(10, -22), ground + Vector2(10, 0), acc, 2)
		"haystack":
			_shadow(ci, ground + Vector2(0, 2), 28, 10)
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-26, 0), ground + Vector2(26, 0), ground + Vector2(12, -34), ground + Vector2(0, -44), ground + Vector2(-12, -34)]), col)
			for k in 4:
				ci.draw_line(ground + Vector2(-18 + k * 12, -2), ground + Vector2(-10 + k * 7, -30), acc, 1.5)
		"scarecrow":
			ci.draw_line(ground, ground + Vector2(0, -58), Color("#7a4f2c"), 4)
			ci.draw_line(ground + Vector2(-20, -42), ground + Vector2(20, -42), Color("#7a4f2c"), 4)
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-12, -46), ground + Vector2(12, -46), ground + Vector2(14, -20), ground + Vector2(-14, -20)]), Color("#3f6fb5"))
			ci.draw_circle(ground + Vector2(0, -58), 9, col)
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-14, -64), ground + Vector2(14, -64), ground + Vector2(0, -78)]), acc)
		"flowerbed":
			var bed := _inset(g, 0.8)
			ci.draw_colored_polygon(bed, SOIL)
			var cols := [col, acc, Color("#b98cff"), Color("#ffffff")]
			for k in 9:
				var p := bed[0].lerp(bed[2], 0.15 + 0.35 * (k % 3)).lerp(bed[3].lerp(bed[1], 0.15 + 0.35 * int(k / 3.0)), 0.5)
				ci.draw_line(p, p + Vector2(0, -8), STEM, 2)
				ci.draw_circle(p + Vector2(0, -10), 4.5, cols[k % 4])
		"flamingo":
			ci.draw_line(ground, ground + Vector2(0, -26), acc, 2)
			_ellipse(ci, ground + Vector2(0, -30), 12, 8, col)
			ci.draw_line(ground + Vector2(8, -32), ground + Vector2(10, -50), col, 4)
			ci.draw_circle(ground + Vector2(12, -52), 5, col)
			ci.draw_line(ground + Vector2(15, -52), ground + Vector2(21, -48), acc, 2.5)
		"bench":
			_shadow(ci, ground + Vector2(0, 2), 26, 8)
			ci.draw_rect(Rect2(ground + Vector2(-24, -18), Vector2(48, 6)), col)
			ci.draw_rect(Rect2(ground + Vector2(-24, -34), Vector2(48, 5)), col)
			ci.draw_rect(Rect2(ground + Vector2(-24, -27), Vector2(48, 5)), col.darkened(0.1))
			for x in [-20.0, 18.0]:
				ci.draw_line(ground + Vector2(x, -12), ground + Vector2(x, 0), acc, 3)
		"shadetree":
			_shadow(ci, ground + Vector2(0, 4), 36, 14)
			match it.get("variant", "oak"):
				"pine":
					ci.draw_rect(Rect2(ground + Vector2(-4, -16), Vector2(8, 16)), Color("#7a4f2c"))
					for k in 3:
						var y := -16.0 - k * 20.0
						ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-30 + k * 7, y), ground + Vector2(30 - k * 7, y), ground + Vector2(0, y - 34)]), col.lightened(0.08 * k))
				"willow":
					ci.draw_rect(Rect2(ground + Vector2(-5, -40), Vector2(10, 40)), Color("#7a4f2c"))
					ci.draw_circle(ground + Vector2(0, -62), 30, col)
					for k in 9:
						var x := -30.0 + k * 7.5
						ci.draw_line(ground + Vector2(x, -58), ground + Vector2(x * 1.15, -14), col.darkened(0.15), 3)
				_:
					ci.draw_rect(Rect2(ground + Vector2(-6, -44), Vector2(12, 44)), Color("#7a4f2c"))
					ci.draw_circle(ground + Vector2(-20, -60), 24, col.darkened(0.12))
					ci.draw_circle(ground + Vector2(20, -60), 24, col.darkened(0.12))
					ci.draw_circle(ground + Vector2(0, -78), 30, col)
		"trough":
			_shadow(ci, ground + Vector2(0, 2), 28, 8)
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-28, -18), ground + Vector2(28, -18), ground + Vector2(22, 0), ground + Vector2(-22, 0)]), col)
			_ellipse(ci, ground + Vector2(0, -18), 26, 5, acc)
		"bonfire":
			for k in 5:
				var a := TAU * k / 5.0
				ci.draw_circle(ground + Vector2(cos(a) * 16, sin(a) * 7), 5, Color("#8a949c"))
			ci.draw_line(ground + Vector2(-12, -2), ground + Vector2(12, -10), acc, 4)
			ci.draw_line(ground + Vector2(12, -2), ground + Vector2(-12, -10), acc, 4)
			var flick := sin(Time.get_ticks_msec() / 120.0) * 3.0
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-12, -6), ground + Vector2(12, -6), ground + Vector2(0, -38 - flick)]), col)
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-6, -6), ground + Vector2(6, -6), ground + Vector2(0, -24 + flick)]), Color("#ffe066"))
		"wheelbarrow":
			_shadow(ci, ground + Vector2(0, 2), 24, 8)
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-22, -26), ground + Vector2(14, -26), ground + Vector2(8, -10), ground + Vector2(-16, -10)]), col)
			ci.draw_circle(ground + Vector2(12, -8), 7, acc)
			ci.draw_line(ground + Vector2(-20, -24), ground + Vector2(-34, -16), Color("#7a4f2c"), 3)
			ci.draw_line(ground + Vector2(-12, -10), ground + Vector2(-14, 0), acc, 3)
		"birdhouse":
			ci.draw_line(ground, ground + Vector2(0, -40), Color("#7a4f2c"), 4)
			ci.draw_rect(Rect2(ground + Vector2(-11, -60), Vector2(22, 20)), acc)
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-15, -60), ground + Vector2(15, -60), ground + Vector2(0, -74)]), col)
			ci.draw_circle(ground + Vector2(0, -50), 4, Color("#2b2420"))
		"birdbath":
			ci.draw_rect(Rect2(ground + Vector2(-4, -24), Vector2(8, 24)), col.darkened(0.1))
			_ellipse(ci, ground + Vector2(0, -26), 22, 8, col)
			_ellipse(ci, ground + Vector2(0, -27), 16, 5, acc)
		"picnic":
			_shadow(ci, ground + Vector2(0, 2), 30, 10)
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-30, -22), ground + Vector2(20, -22), ground + Vector2(30, -14), ground + Vector2(-20, -14)]), col)
			for k in 3:
				ci.draw_line(ground + Vector2(-22 + k * 18, -21), ground + Vector2(-14 + k * 18, -15), acc, 3)
			for x in [-20.0, 20.0]:
				ci.draw_line(ground + Vector2(x, -14), ground + Vector2(x - 6, 0), col.darkened(0.2), 3)
		"well":
			_shadow(ci, ground + Vector2(0, 2), 26, 10)
			ci.draw_rect(Rect2(ground + Vector2(-20, -24), Vector2(40, 24)), col)
			_ellipse(ci, ground + Vector2(0, -24), 20, 7, Color("#2b3a4a"))
			for x in [-18.0, 18.0]:
				ci.draw_line(ground + Vector2(x, -24), ground + Vector2(x, -54), acc, 3)
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-26, -52), ground + Vector2(26, -52), ground + Vector2(0, -70)]), acc.lightened(0.1))
		"gnome":
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-9, 0), ground + Vector2(9, 0), ground + Vector2(7, -18), ground + Vector2(-7, -18)]), acc)
			ci.draw_circle(ground + Vector2(0, -22), 6, Color("#f2c7a8"))
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-6, -16), ground + Vector2(6, -16), ground + Vector2(0, -8)]), Color("#fbf6ec"))
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-8, -26), ground + Vector2(8, -26), ground + Vector2(0, -44)]), col)
		"lamp":
			ci.draw_line(ground, ground + Vector2(0, -60), col, 4)
			ci.draw_rect(Rect2(ground + Vector2(-8, -74), Vector2(16, 14)), acc)
			ci.draw_rect(Rect2(ground + Vector2(-10, -78), Vector2(20, 4)), col)
		"sundial":
			ci.draw_rect(Rect2(ground + Vector2(-8, -26), Vector2(16, 26)), col)
			_ellipse(ci, ground + Vector2(0, -27), 16, 6, col.lightened(0.15))
			ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(-2, -28), ground + Vector2(10, -28), ground + Vector2(-2, -40)]), acc)
		"pond":
			var pond := _inset(g, 0.75)
			var c := (pond[0] + pond[2]) / 2.0
			_ellipse(ci, c, (pond[1].x - pond[3].x) * 0.5, (pond[2].y - pond[0].y) * 0.5, col.darkened(0.15))
			_ellipse(ci, c + Vector2(0, -3), (pond[1].x - pond[3].x) * 0.44, (pond[2].y - pond[0].y) * 0.4, col)
			for k in 3:
				_ellipse(ci, c + Vector2(-40 + k * 34, -4 + (k % 2) * 10), 9, 4, acc)
			for k in 4:
				var p := pond[3].lerp(pond[2], 0.2 + 0.2 * k)
				ci.draw_line(p, p + Vector2(0, -16), STEM, 2)
		"arbor":
			for x in [-22.0, 22.0]:
				ci.draw_line(ground + Vector2(x, 0), ground + Vector2(x, -50), col, 4)
			ci.draw_arc(ground + Vector2(0, -50), 22, PI, TAU, 16, col, 4)
			for k in 8:
				var a := PI + PI * k / 7.0
				ci.draw_circle(ground + Vector2(0, -50) + Vector2(cos(a), sin(a)) * 22, 4, acc if k % 2 == 0 else LEAF)
		"bridge":
			var a2 := g[3].lerp(g[2], 0.5)
			var b2 := g[0].lerp(g[1], 0.5)
			_ellipse(ci, ground, 40, 14, acc)
			ci.draw_line(a2 + Vector2(0, -4), b2 + Vector2(0, -4), col, 14)
			for k in 6:
				var p := a2.lerp(b2, 0.1 + 0.16 * k)
				ci.draw_line(p + Vector2(-5, -10), p + Vector2(5, 2), col.darkened(0.2), 2)
			ci.draw_line(a2 + Vector2(0, -22), b2 + Vector2(0, -22), col.darkened(0.15), 3)
		"fountain":
			var fc := (g[0] + g[2]) / 2.0
			_shadow(ci, fc + Vector2(0, 6), 70, 24)
			_ellipse(ci, fc, 62, 22, col.darkened(0.15))
			_ellipse(ci, fc + Vector2(0, -6), 56, 18, acc)
			ci.draw_rect(Rect2(fc + Vector2(-7, -50), Vector2(14, 44)), col)
			_ellipse(ci, fc + Vector2(0, -50), 22, 8, col)
			var sp := sin(Time.get_ticks_msec() / 200.0) * 2.0
			for k in 5:
				ci.draw_line(fc + Vector2(0, -56), fc + Vector2(-20 + k * 10, -20 + sp), acc.lightened(0.3), 2)
		"gazebo":
			var gc := (g[0] + g[2]) / 2.0
			_shadow(ci, gc + Vector2(0, 6), 64, 22)
			_ellipse(ci, gc, 58, 20, col.darkened(0.1))
			for k in 6:
				var a := PI * 0.1 + PI * 0.8 * k / 5.0
				var p := gc + Vector2(cos(a) * -52, sin(a) * 16)
				ci.draw_line(p, p + Vector2(0, -60), col, 4)
			ci.draw_colored_polygon(PackedVector2Array([gc + Vector2(-66, -60), gc + Vector2(66, -60), gc + Vector2(0, -104)]), acc)
			ci.draw_line(gc + Vector2(0, -104), gc + Vector2(0, -116), acc.darkened(0.3), 3)
		"cabin":
			var base := _inset(g, 0.7)
			_yard_shadow(ci, g)
			var t := _box(ci, base, 56.0, col)
			for k in 6:
				var y := Vector2(0, -8.0 - k * 8.0)
				ci.draw_line(base[3] + y, base[2] + y, col.darkened(0.3), 2)
				ci.draw_line(base[2] + y, base[1] + y, col.darkened(0.45), 2)
			_door(ci, base, 0.5, 0.12, 34, acc.darkened(0.3))
			_gable(ci, t, 34.0, acc, col)
			var chim := t[0].lerp(t[1], 0.3) + Vector2(0, -18)
			ci.draw_rect(Rect2(chim + Vector2(-6, -30), Vector2(12, 30)), Color("#8a949c"))
		"mastery":
			ci.draw_line(ground, ground + Vector2(0, -36), Color("#7a4f2c"), 4)
			ci.draw_rect(Rect2(ground + Vector2(-24, -62), Vector2(48, 28)), Color("#fbefd2"))
			ci.draw_rect(Rect2(ground + Vector2(-24, -62), Vector2(48, 28)), acc, false, 2)
			ci.draw_circle(ground + Vector2(-12, -48), 8, col)
			for k in 3:
				var sc := ground + Vector2(4 + k * 8, -48)
				ci.draw_colored_polygon(PackedVector2Array([sc + Vector2(0, -5), sc + Vector2(2, -1), sc + Vector2(5, -1), sc + Vector2(2, 1), sc + Vector2(3, 5), sc + Vector2(0, 2), sc + Vector2(-3, 5), sc + Vector2(-2, 1), sc + Vector2(-5, -1), sc + Vector2(-2, -1)]), Color("#f2c230"))
		_:
			_shadow(ci, ground, 16, 6)
			ci.draw_circle(ground + Vector2(0, -12), 10, col)


## Duck Pond: water with a little duck house on stilts and ducks bobbing.
static func _duck_pond(ci: CanvasItem, g: PackedVector2Array, it: Dictionary, inside: int) -> Vector2:
	var water := Color.html(str(it.get("color", "#5fa8d3")))
	var field := _inset(g, 0.9)
	ci.draw_colored_polygon(field, Color("#9fd36c"))
	var c := (field[0] + field[2]) / 2.0
	_ellipse(ci, c + Vector2(0, 6), (field[1].x - field[3].x) * 0.42, (field[2].y - field[0].y) * 0.38, water.darkened(0.15))
	_ellipse(ci, c + Vector2(0, 4), (field[1].x - field[3].x) * 0.38, (field[2].y - field[0].y) * 0.32, water)
	for k in mini(5, int(ceil(inside / 4.0))):
		var p := c + Vector2(-50 + k * 24, 4 + (k % 2) * 10)
		_ellipse(ci, p, 8, 5, Color("#fbf6ec"))
		ci.draw_circle(p + Vector2(6, -5), 4, Color("#fbf6ec"))
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(9, -6), p + Vector2(14, -4), p + Vector2(9, -3)]), Color("#f2a33a"))
	var house := field[0].lerp(c, 0.45)
	for x in [-14.0, 14.0]:
		ci.draw_line(house + Vector2(x, 0), house + Vector2(x, -14), Color("#7a5230"), 3)
	ci.draw_rect(Rect2(house + Vector2(-18, -34), Vector2(36, 20)), Color("#e9d8a6"))
	ci.draw_colored_polygon(PackedVector2Array([house + Vector2(-22, -34), house + Vector2(22, -34), house + Vector2(0, -50)]), Color.html(str(it.get("roof", "#7a5230"))))
	ci.draw_circle(house + Vector2(0, -24), 5, Color("#3a2614"))
	return c + Vector2(0, -70)


## Sheep Pen and Goat Pen: a fenced grassy yard with a small shed and the flock grazing.
static func _pen(ci: CanvasItem, g: PackedVector2Array, it: Dictionary, inside: int) -> Vector2:
	var wall := Color.html(str(it.get("color", "#d9c9a3")))
	var roof := Color.html(str(it.get("roof", "#8a5a32")))
	var yard := _inset(g, 0.94)
	ci.draw_colored_polygon(yard, Color("#a9d97a"))
	var c := (yard[0] + yard[2]) / 2.0
	var shed := PackedVector2Array([yard[0], yard[0].lerp(yard[1], 0.42), Vector2.ZERO, yard[0].lerp(yard[3], 0.42)])
	shed[2] = shed[1] + (shed[3] - shed[0])
	var t := _box(ci, shed, 30.0, wall)
	_gable(ci, t, 16.0, roof, wall)
	var goat: bool = it.get("id", "") == "goat_pen"
	var body := Color("#e8e2d4") if goat else Color("#fbf6ec")
	for k in mini(5, int(ceil(inside / 5.0))):
		var p := c + Vector2(-34 + k * 20, 4 + (k % 2) * 16)
		if goat:
			_ellipse(ci, p, 11, 7, body)
			ci.draw_circle(p + Vector2(10, -6), 5, body)
			ci.draw_line(p + Vector2(9, -10), p + Vector2(6, -16), Color("#8a7a5a"), 2)
		else:
			for j in 4:
				ci.draw_circle(p + Vector2(-6 + j * 4, -2 + (j % 2) * 3), 6, body)
			ci.draw_circle(p + Vector2(11, -4), 4, Color("#3b3330"))
	var trough := yard[2].lerp(yard[1], 0.3) + Vector2(-6, -12)
	ci.draw_rect(Rect2(trough + Vector2(-14, -6), Vector2(28, 8)), Color("#8a5a32"))
	_fence(ci, yard, Color("#c9a26a"))
	return c + Vector2(0, -72)


## Rabbit Hutch: a small wooden hutch on legs with a wire front and a carrot patch.
static func _hutch(ci: CanvasItem, g: PackedVector2Array, it: Dictionary, inside: int) -> Vector2:
	var wall := Color.html(str(it.get("color", "#e8c9a0")))
	var roof := Color.html(str(it.get("roof", "#a8743f")))
	_yard_shadow(ci, g, 0.36)
	var base := _inset(g, 0.62)
	for p in [base[3], base[2], base[1]]:
		ci.draw_line(p, p + Vector2(0, -14), Color("#7a5230"), 4.0)
	var t := _box(ci, base, 26.0, wall, 14.0)
	# Wire mesh on the front wall.
	for k in 6:
		var a := base[3].lerp(base[2], 0.15 + 0.12 * k) + Vector2(0, -14)
		ci.draw_line(a, a + Vector2(0, -22), Color("#5c6670"), 1.2)
	ci.draw_line(base[3].lerp(base[2], 0.15) + Vector2(0, -26), base[3].lerp(base[2], 0.87) + Vector2(0, -26), Color("#5c6670"), 1.2)
	_gable(ci, t, 14.0, roof, wall)
	if inside > 0:
		var r := base[3].lerp(base[2], 0.5) + Vector2(0, -22)
		_ellipse(ci, r, 7, 5, Color("#f4efe4"))
		_ellipse(ci, r + Vector2(-2, -8), 2, 5, Color("#f4efe4"))
		_ellipse(ci, r + Vector2(3, -8), 2, 5, Color("#f4efe4"))
	for k in 3:
		var cp := g[2].lerp(g[1], 0.25 + 0.15 * k) + Vector2(0, -10)
		ci.draw_line(cp, cp + Vector2(0, -8), STEM, 2)
		ci.draw_colored_polygon(PackedVector2Array([cp + Vector2(-2, 0), cp + Vector2(2, 0), cp + Vector2(0, 6)]), Color("#f28a2e"))
	return (t[0] + t[2]) / 2.0 + Vector2(0, -30)


## FarmVille's crafting cottages: one silhouette each, a bit grander per star.
static func _crafting(ci: CanvasItem, g: PackedVector2Array, it: Dictionary, level: int, s: float) -> void:
	var c := (g[0] + g[2]) / 2.0
	var u := s / 2.0  # detail scale: 2 in the game for a 4x4 building
	var front := c.lerp(g[2], 0.8)
	var hgt := 34.0 * s + 10.0 * level
	_plain_building(ci, g, it, level, 0, 0, s, false)
	var roof := Color.html(str(it.get("roof", "#6b4a3a")))
	var left_wall := c.lerp(g[3], 0.39).lerp(c.lerp(g[2], 0.78), 0.5) # middle of the front-left wall, at the ground
	match it.get("id", ""):
		"bakery":
			var chim := c.lerp(g[1], 0.3) + Vector2(0, -hgt - 34.0 * s)
			ci.draw_rect(Rect2(chim + Vector2(-9, -30) * u, Vector2(18, 44) * u), Color("#9a4a32"))
			for k in 3:
				ci.draw_circle(chim + Vector2(6 + k * 8, -40 - k * 16) * u, (7 + k * 3) * u, Color(1, 1, 1, 0.6 - k * 0.15))
			for k in 6: # striped awning over the window
				var x := left_wall + Vector2(-40 + k * 13, -hgt * 0.75 / u + k * 6.5) * u
				ci.draw_colored_polygon(PackedVector2Array([x, x + Vector2(13, 6.5) * u, x + Vector2(13, 22) * u, x + Vector2(0, 15.5) * u]),
					Color("#d94a3a") if k % 2 == 0 else Color("#fbf3e4"))
			ci.draw_rect(Rect2(front + Vector2(-70, -40) * u, Vector2(36, 22) * u), Color("#6b4423")) # sign board
			_ellipse(ci, front + Vector2(-52, -29) * u, 12 * u, 7 * u, Color("#e0a85a"))
		"winery":
			for k in 3:
				var b := front + Vector2(-70 + k * 30, -4 + (k % 2) * 8) * u
				_ellipse(ci, b + Vector2(0, -14) * u, 14 * u, 17 * u, Color("#8a5a32"))
				ci.draw_line(b + Vector2(-14, -21) * u, b + Vector2(14, -21) * u, Color("#3b3330"), 3 * u)
				ci.draw_line(b + Vector2(-14, -7) * u, b + Vector2(14, -7) * u, Color("#3b3330"), 3 * u)
			for k in 8: # grapevine across the wall
				ci.draw_circle(left_wall + Vector2(-50 + k * 12, -hgt * 0.8 / u + k * 6 + (k % 2) * 6) * u, 6 * u, Color("#6a2a5a") if k % 3 else Color("#4a8a3a"))
		"spa":
			var tub := front + Vector2(50, -6) * u
			_ellipse(ci, tub, 30 * u, 14 * u, Color("#f4f1ea"))
			_ellipse(ci, tub + Vector2(0, -4) * u, 23 * u, 9 * u, Color("#8fd0e0"))
			for k in 3:
				ci.draw_arc(tub + Vector2(-10 + k * 10, -22 - k * 6) * u, 6 * u, PI, TAU, 8, Color(1, 1, 1, 0.75), 2 * u)
			for k in 6: # flower box under the window
				ci.draw_circle(left_wall + Vector2(-36 + k * 12, -hgt * 0.45 / u + k * 6) * u, 6 * u, Color("#f29ab8") if k % 2 == 0 else Color("#f2d04a"))
	if not show_badges:
		return
	# A star per level over the door.
	for k in level:
		var p := left_wall + Vector2(-20 + k * 11 - level * 5.5 + 26, -hgt * 0.95 / u) * u
		ci.draw_circle(p, 5 * u, Color("#ffd34d"))
		ci.draw_arc(p, 5 * u, 0, TAU, 10, roof.darkened(0.3), 1.0)
