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
