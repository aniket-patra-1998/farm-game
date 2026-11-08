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
static func draw_object(ci: CanvasItem, it: Dictionary, corners: PackedVector2Array, ready: bool, level: int, inside: int, capacity: int, broken := false) -> void:
	var center := (corners[0] + corners[2]) / 2.0
	var s := (corners[1].x - corners[3].x) / 128.0 # 1.0 for a one-tile object
	match it.get("kind", ""):
		"tree":
			_tree(ci, center, it, ready)
		"animal":
			_animal(ci, center, it, ready)
		"building":
			_building(ci, corners, it, level, inside, capacity, s)
		"barn":
			_building(ci, corners, it, level, inside, capacity, s, not broken, broken)
		"decor":
			match it.get("id", ""):
				"farmhouse":
					_building(ci, corners, it, 1, 0, 0, s, false)
				"mailbox":
					_mailbox(ci, center, it)
				"farm_stand":
					_farm_stand(ci, center, it)


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
	if id.ends_with("chicken") or id == "duck" or id == "goose" or id == "turkey":
		var tall := 1.2 if id == "goose" or id == "turkey" else 1.0
		_ellipse(ci, ground + Vector2(0, -16), 15 * tall, 13 * tall, body)
		ci.draw_circle(ground + Vector2(11, -30 * tall), 9, body)
		if id == "chicken" or id == "turkey":
			_ellipse(ci, ground + Vector2(11, -40 * tall), 4, 5, accent)       # comb or wattle
		if id == "turkey":
			for k in 5:
				var a := PI + 0.35 + k * 0.32
				ci.draw_circle(ground + Vector2(-8, -20) + Vector2(cos(a), sin(a)) * 16, 7, accent.lerp(body, 0.3 + 0.12 * k))
		ci.draw_colored_polygon(PackedVector2Array([ground + Vector2(19, -31), ground + Vector2(27, -28), ground + Vector2(19, -26)]), Color("#f2a33a"))
		ci.draw_circle(ground + Vector2(14, -32), 1.8, Color("#222222"))
		ci.draw_line(ground + Vector2(-4, -4), ground + Vector2(-4, 4), Color("#f2a33a"), 2.5)
		ci.draw_line(ground + Vector2(4, -4), ground + Vector2(4, 4), Color("#f2a33a"), 2.5)
	else:
		var big := 1.25 if id == "horse" or id == "stallion" or id == "bull" else (0.7 if id == "calf" or id == "foal" else 1.0)
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
		if badge != Vector2.ZERO:
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
