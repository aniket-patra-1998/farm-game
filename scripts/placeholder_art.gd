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


static func draw_soil(ci: CanvasItem, top: Vector2, w: float, h: float, planted: bool) -> void:
	var pts := diamond(top, w, h)
	ci.draw_colored_polygon(pts, SOIL_WET if planted else SOIL)
	# Furrows run parallel to the top-right edge.
	var t_ := pts[0]
	var r_ := pts[1]
	var b_ := pts[2]
	var l_ := pts[3]
	for k in range(1, 5):
		var f := k / 5.0
		ci.draw_line(t_.lerp(l_, f), r_.lerp(b_, f), SOIL_FURROW, 2.5)
	ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), OUTLINE, 1.5)


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
static func draw_object(ci: CanvasItem, it: Dictionary, corners: PackedVector2Array, ready: bool, level: int, inside: int, capacity: int) -> void:
	var center := (corners[0] + corners[2]) / 2.0
	var s := (corners[1].x - corners[3].x) / 128.0 # 1.0 for a one-tile object
	match it.get("kind", ""):
		"tree":
			_tree(ci, center, it, ready)
		"animal":
			_animal(ci, center, it, ready)
		"building":
			_building(ci, corners, it, level, inside, capacity, s)


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
	_shadow(ci, ground + Vector2(0, 2), 30, 11)
	if id == "chicken":
		_ellipse(ci, ground + Vector2(0, -16), 15, 13, body)
		ci.draw_circle(ground + Vector2(11, -30), 9, body)
		_ellipse(ci, ground + Vector2(11, -40), 4, 5, accent)       # comb
		ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(19, -31), ground + Vector2(27, -28), ground + Vector2(19, -26)]), Color("#f2a33a"))
		ci.draw_circle(ground + Vector2(14, -32), 1.8, Color("#222222"))
		ci.draw_line(ground + Vector2(-4, -4), ground + Vector2(-4, 4), Color("#f2a33a"), 2.5)
		ci.draw_line(ground + Vector2(4, -4), ground + Vector2(4, 4), Color("#f2a33a"), 2.5)
	else:
		var big := 1.25 if id == "horse" else 1.0
		for x in [-16.0, -8.0, 10.0, 18.0]:
			ci.draw_line(ground + Vector2(x * big, -14), ground + Vector2(x * big, 2), accent if id == "horse" else body.darkened(0.25), 4.5)
		_ellipse(ci, ground + Vector2(0, -22 * big), 26 * big, 15 * big, body)
		if id == "cow":
			_ellipse(ci, ground + Vector2(-8, -24), 8, 6, accent)
			_ellipse(ci, ground + Vector2(10, -18), 6, 5, accent)
		if id == "sheep":
			for k in 6:
				ci.draw_circle(ground + Vector2(-18 + k * 7, -32 + (k % 2) * 4), 7, body.lightened(0.3))
		var head := ground + Vector2(26 * big, -32 * big)
		ci.draw_circle(head, 10 * big, accent if id == "sheep" else body)
		if id == "horse":
			_ellipse(ci, head + Vector2(6, 4), 9, 7, body)
			ci.draw_line(head + Vector2(-8, -4), ground + Vector2(10, -34), accent, 6) # mane
		if id == "pig":
			_ellipse(ci, head + Vector2(8, 2), 5, 4, accent)
		ci.draw_circle(head + Vector2(2, -2), 1.8, Color("#222222"))
		ci.draw_line(ground + Vector2(-26 * big, -24 * big), ground + Vector2(-32 * big, -16 * big), accent, 3) # tail
	if ready:
		# A product bubble shows the animal is ready to collect.
		var bubble := ground + Vector2(-4, -64)
		ci.draw_circle(bubble, 13, Color("#fffaf0"))
		ci.draw_arc(bubble, 13, 0, TAU, 24, Color("#5c3a1e"), 2)
		ci.draw_circle(bubble, 6, accent if id != "chicken" else Color("#f6e7c1"))


static func _building(ci: CanvasItem, g: PackedVector2Array, it: Dictionary, level: int, inside: int, capacity: int, s: float) -> void:
	var wall := Color.html(str(it.get("color", "#c0392b")))
	var roof := Color.html(str(it.get("roof", "#6b4a3a")))
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
	# Level badge and count sign.
	var font := ThemeDB.fallback_font
	var badge := r_b + Vector2(0, -26)
	ci.draw_circle(badge, 16, Color("#ffd34d"))
	ci.draw_arc(badge, 16, 0, TAU, 24, Color("#5c3a1e"), 2.5)
	ci.draw_string(font, badge + Vector2(-16, 7), str(level), HORIZONTAL_ALIGNMENT_CENTER, 32, 20, Color("#3a2614"))
	var sign_pos := bottom + Vector2(-34, 22)
	ci.draw_rect(Rect2(sign_pos, Vector2(68, 24)), Color("#fbefd2"))
	ci.draw_rect(Rect2(sign_pos, Vector2(68, 24)), Color("#5c3a1e"), false, 2)
	ci.draw_string(font, sign_pos + Vector2(0, 18), "%d/%d" % [inside, capacity], HORIZONTAL_ALIGNMENT_CENTER, 68, 16, Color("#3a2614"))


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
