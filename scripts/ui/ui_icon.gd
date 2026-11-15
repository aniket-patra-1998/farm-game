class_name UiIcon
extends Control
## The game's icons, drawn in code so they are sharp at any size, in one sticker style (our own look, in the
## spirit of FarmVille's chunky glossy buttons): every shape has a soft shadow under it, a dark brown outline, a
## fill that is lighter at the top and deeper at the bottom, and a glossy highlight; details are drawn on top in
## the same ink. Money (coin, gem, star), the view buttons (eye, speaker, note, zoom in and out, frame all, camera),
## the tools (arrow, hoe, seeds, basket, fertilizer, move, barn, tag), the menu (market, album, ribbon,
## neighbours, gear) and the small marks (plus, cross, lock). Square; it fills the smaller side. A ribbon takes
## its colour from `tint` (the tiers: yellow, white, red, blue). `knob` makes a round slider grabber.

const KINDS: Array[String] = ["coin", "gem", "star", "eye", "speaker", "note", "zoom_in", "zoom_out", "fit", "camera",
	"arrow", "ribbon", "plus", "hoe", "seeds", "basket", "fertilizer", "move", "barn", "tag", "market", "album",
	"neighbours", "gear", "cross", "lock", "ready"]
const READY_PINK := Color(1.0, 0.66, 0.8)   # the ready sign's pink (shaders/ready3d.gdshader)
const STAR_POINTS := 5
const STAR_INNER := 0.45   # the inner radius of a star, of its outer
const KNOB_RING := 0.12    # a knob's ring, of its width
const OUTLINE := 0.075     # the outline's width, of the icon's size
const SHADOW_DROP := 0.05  # how far the shadow falls below a shape, of the icon's size
const SHADE_TOP := 0.22    # a fill is lightened this much at its top..
const SHADE_BOTTOM := 0.18 # ..and darkened this much at its bottom
const GLOSS := 0.42        # the highlight's strength
const ROUND := 20          # points on a circle
const RENDER_INSET := 0.04 # a rendered picture sits this far in from the icon's edge (room for its outline)
const RENDER_RECHECK := 0.3   # seconds before looking again for a rendered picture still being made

@export var kind := "coin": set = _set_kind
## A muted icon (sound off, UI hidden) is drawn with a slash through it.
@export var struck := false: set = _set_struck
## A ribbon's colour (Color(0, 0, 0, 0): the theme's gold).
@export var tint := Color(0, 0, 0, 0): set = _set_tint
## Drawn from its rendered 3D picture when it has one (UiModels); false keeps the drawn glyph (tools, tests).
@export var rendered := true

var _s := 1.0   # the icon's size this draw
var _c := Vector2.ZERO
var _r := 1.0


static func make(icon_kind: String, px := 0.0, colour := Color(0, 0, 0, 0)) -> UiIcon:
	var icon := UiIcon.new()
	icon.kind = icon_kind
	icon.tint = colour
	var s := px if px > 0.0 else UiTheme.size("icon_size")
	icon.custom_minimum_size = Vector2(s, s)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## A round knob as a texture (a slider's grabber): `fill` inside a ring of `edge`, softened at its rim.
static func knob(px: int, fill: Color, edge: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var r := px / 2.0
	var ring := maxf(2.0, px * KNOB_RING)
	for y in px:
		for x in px:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var col := fill if d < r - ring else edge
			col.a = clampf(r - d, 0.0, 1.0)   # (one pixel of soft edge)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## The points of a star of `points` tips about `c`.
static func star_points(c: Vector2, r: float, points := STAR_POINTS) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in points * 2:
		var a := -PI / 2.0 + PI * k / points
		var rr := r if k % 2 == 0 else r * STAR_INNER
		out.append(c + Vector2(cos(a), sin(a)) * rr)
	return out


func _set_kind(v: String) -> void:
	kind = v
	queue_redraw()


func _set_struck(v: bool) -> void:
	struck = v
	queue_redraw()


func _set_tint(v: Color) -> void:
	tint = v
	queue_redraw()


# ---------------------------------------------------------------- the sticker style


## A point of the icon from unit coordinates (-1..1 across, y down).
func _p(x: float, y: float) -> Vector2:
	return _c + Vector2(x, y) * _r


func _pts(coords: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(0, coords.size(), 2):
		out.append(_p(coords[k], coords[k + 1]))
	return out


## A circle's outline points about (x, y), radius `rr`, squashed by `squash` in height.
func _ring(x: float, y: float, rr: float, squash := 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in ROUND:
		var a := TAU * k / ROUND
		out.append(_p(x + cos(a) * rr, y + sin(a) * rr * squash))
	return out


## One shape in the sticker style: shadow, outline, a fill lighter at the top, and a gloss on its upper part.
func _shape(pts: PackedVector2Array, fill: Color, gloss := true, shadow := true) -> void:
	if pts.size() < 3:
		return
	var w := maxf(1.5, _s * OUTLINE)
	var ink := UiTheme.color("icon_outline")
	if shadow:
		var drop := PackedVector2Array()
		for p in pts:
			drop.append(p + Vector2(0, _s * SHADOW_DROP))
		draw_colored_polygon(drop, UiTheme.color("icon_shadow"))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, ink, w, true)
	var top := INF
	var bottom := -INF
	for p in pts:
		top = minf(top, p.y)
		bottom = maxf(bottom, p.y)
	var cols := PackedColorArray()
	for p in pts:
		var t := (p.y - top) / maxf(bottom - top, 0.001)
		cols.append(fill.lightened(SHADE_TOP * (1.0 - t)).darkened(SHADE_BOTTOM * t))
	draw_polygon(pts, cols)
	if gloss:
		# The highlight: the shape pulled in toward its middle, cut to its upper part, in see-through white (cut
		# with Geometry2D, so any shape, concave too, gives a clean one).
		var mid := Vector2.ZERO
		for p in pts:
			mid += p
		mid /= pts.size()
		var inset := PackedVector2Array()
		for p in pts:
			inset.append(mid + (p - mid) * 0.74 + Vector2(0, -_s * 0.02))
		var band := PackedVector2Array([Vector2(-_s, top - _s), Vector2(_s * 2.0, top - _s),
			Vector2(_s * 2.0, lerpf(top, bottom, 0.42)), Vector2(-_s, lerpf(top, bottom, 0.42))])
		for shine: PackedVector2Array in Geometry2D.intersect_polygons(inset, band):
			if shine.size() >= 3 and not Geometry2D.is_polygon_clockwise(shine):   # (a clockwise one is a hole)
				draw_colored_polygon(shine, Color(1, 1, 1, GLOSS * 0.55))


## A line of detail in the outline's ink (or `col`).
func _line(a: Vector2, b: Vector2, width := 0.06, col := Color(0, 0, 0, 0)) -> void:
	draw_line(a, b, col if col.a > 0.0 else UiTheme.color("icon_outline"), maxf(1.2, _s * width), true)


func _dot(at: Vector2, rr: float, col: Color) -> void:
	draw_circle(at, rr * _r, col)


func _draw() -> void:
	_s = minf(size.x, size.y)
	if _s <= 0.0:
		return
	_c = size / 2.0
	_r = _s / 2.0 * 0.86   # (room for the outline and the shadow)
	if _draw_rendered():
		return
	var light := UiTheme.color("icon_light")
	match kind:
		"coin":
			_shape(_ring(0, 0, 0.92), UiTheme.color("coin"))
			draw_arc(_c, _r * 0.62, 0.0, TAU, ROUND * 2, UiTheme.color("coin_edge"), maxf(1.0, _s * 0.05), true)
			_shape(star_points(_c + Vector2(0, _r * 0.04), _r * 0.36), UiTheme.color("coin").lightened(0.15), false,
				false)
		"gem":
			var outline := _pts([-0.85, -0.25, -0.45, -0.8, 0.45, -0.8, 0.85, -0.25, 0.0, 0.9])
			_shape(outline, UiTheme.color("gem"), false)
			draw_colored_polygon(_pts([-0.45, -0.8, 0.0, -0.25, -0.85, -0.25]), Color(1, 1, 1, 0.45))
			draw_colored_polygon(_pts([0.45, -0.8, 0.85, -0.25, 0.0, -0.25]), UiTheme.color("gem").darkened(0.15))
			draw_colored_polygon(_pts([0.0, -0.25, 0.85, -0.25, 0.0, 0.9]), UiTheme.color("gem").darkened(0.25))
			_line(_p(-0.85, -0.25), _p(0.85, -0.25), 0.04, UiTheme.color("gem_edge"))
			_line(_p(-0.45, -0.8), _p(0.0, -0.25), 0.035, UiTheme.color("gem_edge"))
			_line(_p(0.45, -0.8), _p(0.0, -0.25), 0.035, UiTheme.color("gem_edge"))
			_line(_p(0.0, -0.25), _p(0.0, 0.9), 0.035, UiTheme.color("gem_edge"))
		"star":
			_shape(star_points(_p(0, 0.06), _r * 1.0), UiTheme.color("star"))
		"eye":
			var lid := PackedVector2Array()
			for k in 13:
				var t := float(k) / 12.0
				lid.append(_p(lerpf(-0.95, 0.95, t), -sin(t * PI) * 0.6))
			for k in 13:
				var t := 1.0 - float(k) / 12.0
				lid.append(_p(lerpf(-0.95, 0.95, t), sin(t * PI) * 0.6))
			_shape(lid, light, false)
			_shape(_ring(0, 0, 0.38), UiTheme.color("sky_ink"), false, false)
			_dot(_c, 0.18, UiTheme.color("icon_outline"))
			_dot(_p(-0.12, -0.14), 0.09, Color.WHITE)
		"speaker":
			_shape(_pts([-0.85, -0.3, -0.4, -0.3, 0.1, -0.75, 0.1, 0.75, -0.4, 0.3, -0.85, 0.3]), UiTheme.color("metal"))
			for k in 2:
				draw_arc(_p(0.15, 0), _r * (0.38 + 0.3 * k), -0.85, 0.85, 12, UiTheme.color("icon_outline"),
					maxf(1.5, _s * 0.08), true)
		"note":
			_shape(_ring(-0.32, 0.5, 0.3, 0.8), UiTheme.color("sky_ink"))
			_shape(_pts([0.0, 0.45, -0.02, -0.75, 0.12, -0.75, 0.12, 0.45]), UiTheme.color("sky_ink"), false)
			_shape(_pts([0.05, -0.78, 0.7, -0.5, 0.7, -0.15, 0.08, -0.4]), UiTheme.color("sky_ink"))
		"zoom_in", "zoom_out", "fit":
			_shape(_pts([0.3, 0.42, 0.45, 0.28, 0.95, 0.78, 0.8, 0.93]), UiTheme.color("wood_light"), false)
			_shape(_ring(-0.15, -0.15, 0.62), UiTheme.color("gem").lightened(0.4))
			var lens := _p(-0.15, -0.15)
			if kind != "fit":
				_line(lens + Vector2(-_r * 0.32, 0), lens + Vector2(_r * 0.32, 0), 0.09)
			if kind == "zoom_in":
				_line(lens + Vector2(0, -_r * 0.32), lens + Vector2(0, _r * 0.32), 0.09)
			if kind == "fit":
				draw_rect(Rect2(lens - Vector2(_r * 0.28, _r * 0.28), Vector2(_r * 0.56, _r * 0.56)),
					UiTheme.color("icon_outline"), false, maxf(1.5, _s * 0.07))
		"ready":   # the farm's ready sign: a soft pink triangle pointing down (ReadyMarks)
			_shape(_pts([-0.82, -0.62, 0.82, -0.62, 0.0, 0.8]), READY_PINK)
			_shape(_pts([-0.5, -0.44, 0.5, -0.44, 0.0, 0.42]), READY_PINK.lightened(0.45), false, false)
		"camera":
			_shape(_pts([-0.9, -0.45, -0.35, -0.45, -0.25, -0.7, 0.3, -0.7, 0.4, -0.45, 0.9, -0.45, 0.9, 0.7,
				-0.9, 0.7]), UiTheme.color("metal").darkened(0.25))
			_shape(_ring(0, 0.1, 0.4), UiTheme.color("sky_ink"), true, false)
			_dot(_p(-0.12, -0.02), 0.1, Color(1, 1, 1, 0.8))
		"arrow":
			_shape(_pts([-0.5, -0.9, -0.5, 0.55, -0.15, 0.25, 0.1, 0.88, 0.38, 0.76, 0.12, 0.18, 0.55, 0.15]), Color.WHITE)
		"ribbon":
			var col := tint if tint.a > 0.0 else UiTheme.color("star")
			_shape(_pts([-0.35, 0.05, -0.65, 0.95, -0.25, 0.75, -0.02, 0.98, 0.05, 0.05]), col.darkened(0.2))
			_shape(_pts([0.35, 0.05, 0.65, 0.95, 0.25, 0.75, 0.02, 0.98, -0.05, 0.05]), col.darkened(0.1))
			var pleats := PackedVector2Array()
			for k in 24:
				var a := TAU * k / 24.0
				var rr := 0.62 if k % 2 == 0 else 0.52
				pleats.append(_p(cos(a) * rr, -0.25 + sin(a) * rr))
			_shape(pleats, col)
			_shape(_ring(0, -0.25, 0.32), col.lightened(0.25), true, false)
		"plus":
			_shape(_pts([-0.25, -0.75, 0.25, -0.75, 0.25, -0.25, 0.75, -0.25, 0.75, 0.25, 0.25, 0.25, 0.25, 0.75,
				-0.25, 0.75, -0.25, 0.25, -0.75, 0.25, -0.75, -0.25, -0.25, -0.25]), UiTheme.color("plus"), false)
		"hoe", "seeds", "basket", "fertilizer", "move", "barn", "tag":
			_draw_tool(light)
		"market", "album", "neighbours", "gear":
			_draw_menu(light)
		"cross":
			_shape(_pts([-0.62, -0.42, -0.42, -0.62, 0.0, -0.2, 0.42, -0.62, 0.62, -0.42, 0.2, 0.0, 0.62, 0.42,
				0.42, 0.62, 0.0, 0.2, -0.42, 0.62, -0.62, 0.42, -0.2, 0.0]), UiTheme.color("berry"), false)
		"lock":
			draw_arc(_p(0, -0.2), _r * 0.4, PI, TAU, 16, UiTheme.color("icon_outline"), maxf(2.5, _s * 0.16), true)
			draw_arc(_p(0, -0.2), _r * 0.4, PI, TAU, 16, UiTheme.color("metal"), maxf(1.2, _s * 0.07), true)
			_shape(_pts([-0.65, -0.2, 0.65, -0.2, 0.65, 0.85, -0.65, 0.85]), UiTheme.color("coin"))
			_dot(_p(0, 0.25), 0.13, UiTheme.color("icon_outline"))
			_line(_p(0, 0.3), _p(0, 0.55), 0.08)
		_:
			draw_rect(Rect2(Vector2.ZERO, Vector2(_s, _s)), Color.MAGENTA, false, 2.0)
	if struck:
		_line(_p(-0.95, -0.95), _p(0.95, 0.95), 0.16)
		_line(_p(-0.95, -0.95), _p(0.95, 0.95), 0.09, Color("#e0493a"))


## Draws this icon's rendered picture (UiModels, made once by ItemIcons) when it has one and it is ready: its
## shadow, a dark outline all round (the picture stamped in the outline's colour a little off each way), then
## the picture. Until it is ready the drawn version shows and this looks again shortly. Returns whether it drew.
func _draw_rendered() -> bool:
	if not rendered or not UiModels.KINDS.has(kind) or (kind == "ribbon" and tint.a > 0.0):
		return false
	var id := ItemIcons.UI + kind
	var tex := ItemIcons.of(id)
	if not ItemIcons.is_made(id):
		get_tree().create_timer(RENDER_RECHECK).timeout.connect(queue_redraw, CONNECT_ONE_SHOT)
		return false
	var rect := Rect2(_c - Vector2.ONE * _s / 2.0, Vector2.ONE * _s).grow(-_s * RENDER_INSET)
	var w := maxf(1.0, _s * OUTLINE * 0.5)
	draw_texture_rect(tex, Rect2(rect.position + Vector2(0, _s * SHADOW_DROP), rect.size), false,
		UiTheme.color("icon_shadow"))
	var ink := UiTheme.color("icon_outline")
	for k in 8:
		var a := TAU * k / 8.0
		draw_texture_rect(tex, Rect2(rect.position + Vector2(cos(a), sin(a)) * w, rect.size), false, ink)
	draw_texture_rect(tex, rect, false)
	if struck:
		_line(_p(-0.95, -0.95), _p(0.95, 0.95), 0.16)
		_line(_p(-0.95, -0.95), _p(0.95, 0.95), 0.09, Color("#e0493a"))
	return true


## The farm tools: a hoe, a seed bag, a basket of produce, a fertilizer sack, four-way arrows, a red barn, a price
## tag.
func _draw_tool(light: Color) -> void:
	match kind:
		"hoe":
			_shape(_pts([-0.82, 0.74, -0.72, 0.86, 0.42, -0.32, 0.32, -0.44]), UiTheme.color("wood_light"), false)
			_shape(_pts([0.1, -0.78, 0.9, -0.5, 0.66, -0.12, 0.28, -0.36]), UiTheme.color("metal"))
			_line(_p(0.3, -0.62), _p(0.72, -0.44), 0.035, Color(1, 1, 1, 0.7))
		"seeds":
			_shape(_pts([-0.62, -0.3, -0.36, -0.62, 0.36, -0.62, 0.62, -0.3, 0.72, 0.88, -0.72, 0.88]), UiTheme.color("sack"))
			_shape(_pts([-0.45, -0.62, -0.2, -0.95, 0.0, -0.7, 0.2, -0.95, 0.45, -0.62]), UiTheme.color("sack").darkened(0.08),
				false, false)
			_line(_p(-0.42, -0.58), _p(0.42, -0.58), 0.07, UiTheme.color("berry"))
			_shape(_ring(0, 0.3, 0.34), light, false, false)
			_line(_p(0.0, 0.52), _p(0.0, 0.18), 0.05, UiTheme.color("leaf").darkened(0.35))
			_shape(_ring(-0.13, 0.14, 0.13, 0.6), UiTheme.color("leaf"), false, false)
			_shape(_ring(0.13, 0.1, 0.13, 0.6), UiTheme.color("leaf").lightened(0.15), false, false)
		"basket":
			_shape(_ring(-0.42, -0.18, 0.3), UiTheme.color("berry"))
			_shape(_pts([0.0, -0.75, 0.18, -0.2, -0.16, -0.2]), UiTheme.color("coin"))
			_shape(_ring(0.42, -0.16, 0.28), UiTheme.color("leaf").lightened(0.2))
			_line(_p(-0.4, -0.46), _p(-0.32, -0.62), 0.05, UiTheme.color("leaf"))
			var b := _pts([-0.92, -0.02, 0.92, -0.02, 0.66, 0.9, -0.66, 0.9])
			_shape(b, UiTheme.color("wood_light"))
			for k in 3:   # the weave
				var y := 0.2 + 0.24 * k
				_line(_p(-0.8 + 0.08 * k, y), _p(0.8 - 0.08 * k, y), 0.03)
			for k in 5:
				var x := -0.5 + 0.25 * k
				_line(_p(x * 1.2, 0.0), _p(x, 0.88), 0.03)
		"fertilizer":
			_shape(_pts([-0.6, -0.65, 0.6, -0.65, 0.68, 0.88, -0.68, 0.88]), UiTheme.color("sack"))
			_shape(_pts([-0.6, -0.65, 0.6, -0.65, 0.5, -0.9, -0.5, -0.9]), UiTheme.color("sack").darkened(0.12), false,
				false)
			_shape(_ring(0, 0.12, 0.38), UiTheme.color("leaf").lightened(0.35), false, false)
			_shape(_pts([0.0, 0.42, -0.26, 0.0, 0.0, -0.22, 0.24, 0.0]), UiTheme.color("leaf"), false, false)
			_line(_p(0.0, 0.42), _p(0.0, -0.12), 0.035, UiTheme.color("leaf").darkened(0.4))
		"move":
			var col := UiTheme.color("sky_ink")
			_shape(_pts([-0.16, -0.62, -0.42, -0.62, 0.0, -0.98, 0.42, -0.62, 0.16, -0.62, 0.16, -0.16, 0.62, -0.16,
				0.62, -0.42, 0.98, 0.0, 0.62, 0.42, 0.62, 0.16, 0.16, 0.16, 0.16, 0.62, 0.42, 0.62, 0.0, 0.98,
				-0.42, 0.62, -0.16, 0.62, -0.16, 0.16, -0.62, 0.16, -0.62, 0.42, -0.98, 0.0, -0.62, -0.42, -0.62, -0.16,
				-0.16, -0.16]), col)
		"barn":
			_shape(_pts([-0.9, -0.1, -0.62, -0.62, 0.0, -0.92, 0.62, -0.62, 0.9, -0.1, 0.82, 0.88, -0.82, 0.88]),
				UiTheme.color("barn_red"))
			_shape(_pts([-0.98, -0.06, -0.66, -0.7, 0.0, -1.02, 0.66, -0.7, 0.98, -0.06, 0.86, 0.02, 0.58, -0.54,
				0.0, -0.82, -0.58, -0.54, -0.86, 0.02]), UiTheme.color("icon_outline").lightened(0.15), false, false)
			_shape(_pts([-0.36, 0.1, 0.36, 0.1, 0.36, 0.88, -0.36, 0.88]), light, false, false)
			_line(_p(-0.32, 0.14), _p(0.32, 0.84), 0.05, UiTheme.color("barn_red"))
			_line(_p(0.32, 0.14), _p(-0.32, 0.84), 0.05, UiTheme.color("barn_red"))
			_shape(_ring(0, -0.36, 0.13), light, false, false)
		"tag":
			_shape(_pts([-0.9, 0.08, -0.08, -0.82, 0.82, -0.82, 0.82, 0.02, -0.02, 0.9]), UiTheme.color("coin"))
			_shape(_ring(0.5, -0.5, 0.13), UiTheme.color("icon_light"), false, false)
			draw_arc(_p(0.5, -0.5), _r * 0.13, 0.0, TAU, 12, UiTheme.color("icon_outline"), maxf(1.0, _s * 0.04), true)
			_shape(star_points(_p(0.0, 0.08), _r * 0.3), UiTheme.color("coin_edge"), false, false)


## The menu: a market stall under a striped awning, the collections album, two neighbours, a gear.
func _draw_menu(light: Color) -> void:
	match kind:
		"market":
			_shape(_pts([-0.78, -0.1, 0.78, -0.1, 0.78, 0.9, -0.78, 0.9]), UiTheme.color("wood_light"))
			_shape(_pts([-0.62, 0.18, 0.62, 0.18, 0.62, 0.5, -0.62, 0.5]), UiTheme.color("wood_light").darkened(0.25),
				false, false)
			for k in 3:   # produce on the counter
				_shape(_ring(-0.42 + 0.42 * k, 0.22, 0.17), [UiTheme.color("berry"), UiTheme.color("coin"),
					UiTheme.color("leaf").lightened(0.2)][k], true, false)
			var awning := PackedVector2Array([_p(-0.95, -0.78), _p(0.95, -0.78), _p(0.95, -0.12)])
			for k in 5:   # its scalloped edge, right to left
				var x := 0.95 - 0.38 * k
				for j in 5:
					var a := PI * j / 4.0
					awning.append(_p(x - 0.19 + cos(a) * 0.19, -0.12 + sin(a) * 0.14))
			awning.append(_p(-0.95, -0.12))
			_shape(awning, light)
			for k in 3:   # its red stripes
				var x := -0.95 + 0.76 * k
				draw_colored_polygon(_pts([x, -0.78, x + 0.38, -0.78, x + 0.38, -0.12, x, -0.12]),
					UiTheme.color("barn_red"))
			_line(_p(-0.95, -0.78), _p(0.95, -0.78), 0.06)
		"album":
			_shape(_pts([-0.9, -0.7, 0.0, -0.56, 0.9, -0.7, 0.9, 0.78, 0.0, 0.92, -0.9, 0.78]), UiTheme.color("sky_ink"))
			_shape(_pts([-0.78, -0.58, -0.06, -0.46, -0.06, 0.74, -0.78, 0.64]), light, false, false)
			_shape(_pts([0.06, -0.46, 0.78, -0.58, 0.78, 0.64, 0.06, 0.74]), light, false, false)
			_line(_p(0.0, -0.56), _p(0.0, 0.92), 0.05)
			_shape(star_points(_p(-0.42, 0.06), _r * 0.24), UiTheme.color("star"), false, false)
			_shape(_ring(0.42, 0.06, 0.2), UiTheme.color("berry"), false, false)
		"neighbours":
			for k in 2:
				var x := 0.34 if k == 0 else -0.34
				var shirt := UiTheme.color("cash_bar") if k == 0 else UiTheme.color("coin_bar")
				_shape(_pts([x - 0.46, 0.92, x - 0.36, 0.2, x + 0.36, 0.2, x + 0.46, 0.92]), shirt)
				_shape(_ring(x, -0.3, 0.32), UiTheme.color("skin"))
				var hair := PackedVector2Array()   # a cap of hair over the top half of the head
				for j in 9:
					var a := PI + PI * j / 8.0
					hair.append(_p(x + cos(a) * 0.34, -0.32 + sin(a) * 0.34))
				hair.append(_p(x + 0.3, -0.28))
				hair.append(_p(x - 0.3, -0.28))
				_shape(hair, UiTheme.color("wood_light").darkened(0.15 + 0.2 * k), false, false)
				for e in 2:
					_dot(_p(x - 0.11 + 0.22 * e, -0.16), 0.045, UiTheme.color("icon_outline"))
				draw_arc(_p(x, -0.12), _r * 0.13, 0.4, PI - 0.4, 8, UiTheme.color("icon_outline"), maxf(1.0, _s * 0.03), true)
		"gear":
			var teeth := PackedVector2Array()
			for k in 32:
				var a := TAU * (k / 32.0)
				var out := 0.95 if (k / 2) % 2 == 0 else 0.7
				teeth.append(_p(cos(a) * out, sin(a) * out))
			_shape(teeth, UiTheme.color("metal").darkened(0.15))
			_shape(_ring(0, 0, 0.3), light, false, false)
			draw_arc(_c, _r * 0.3, 0.0, TAU, ROUND, UiTheme.color("icon_outline"), maxf(1.2, _s * 0.05), true)
