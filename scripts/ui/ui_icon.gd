class_name UiIcon
extends Control
## A small icon drawn in code, sharp at any size: a coin, a gem, a star, an eye, a speaker, a note, a magnifier
## (plus or minus), a frame-all, a camera, an arrow, a ribbon, a plus; the tools (hoe, seeds, basket, fertilizer,
## move, barn, tag), the menu (market, album, neighbours, gear), a close cross and a lock. Square; it fills the
## smaller side. `knob` makes a round knob texture (a slider's grabber).

const KINDS: Array[String] = ["coin", "gem", "star", "eye", "speaker", "note", "zoom_in", "zoom_out", "fit", "camera",
	"arrow", "ribbon", "plus", "hoe", "seeds", "basket", "fertilizer", "move", "barn", "tag", "market", "album",
	"neighbours", "gear", "cross", "lock"]
const STAR_POINTS := 5
const STAR_INNER := 0.45   # the inner radius of a star, of its outer
const KNOB_RING := 0.12    # a knob's ring, of its width

@export var kind := "coin": set = _set_kind
## A muted icon (sound off, UI hidden) is drawn with a slash through it.
@export var struck := false: set = _set_struck


static func make(icon_kind: String, px := 0.0) -> UiIcon:
	var icon := UiIcon.new()
	icon.kind = icon_kind
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


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 0.0:
		return
	var c := size / 2.0
	var r := s / 2.0
	var ink := UiTheme.color("icon_ink")
	var light := UiTheme.color("icon_light")
	match kind:
		"coin":
			draw_circle(c, r * 0.92, UiTheme.color("coin_edge"))
			draw_circle(c, r * 0.8, UiTheme.color("coin"))
			draw_arc(c, r * 0.55, 0.0, TAU, 24, UiTheme.color("coin_edge"), maxf(1.0, s * 0.06))
			draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.18, light)
		"gem":
			var pts := PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.2), c + Vector2(-r * 0.4, -r * 0.7),
				c + Vector2(r * 0.4, -r * 0.7), c + Vector2(r * 0.7, -r * 0.2), c + Vector2(0, r * 0.85)])
			draw_colored_polygon(pts, UiTheme.color("gem"))
			draw_polyline(PackedVector2Array(Array(pts) + [pts[0]]), UiTheme.color("gem_edge"), maxf(1.5, s * 0.07))
			draw_line(c + Vector2(-r * 0.7, -r * 0.2), c + Vector2(r * 0.7, -r * 0.2), UiTheme.color("gem_edge"),
				maxf(1.0, s * 0.05))
			draw_line(c + Vector2(-r * 0.4, -r * 0.7), c + Vector2(-r * 0.15, -r * 0.2), light, maxf(1.0, s * 0.05))
		"star":
			var pts := star_points(c + Vector2(0, r * 0.05), r * 0.95)
			draw_colored_polygon(pts, UiTheme.color("star"))
			draw_polyline(PackedVector2Array(Array(pts) + [pts[0]]), UiTheme.color("star_edge"), maxf(1.5, s * 0.07))
		"eye":
			var up := PackedVector2Array()
			var down := PackedVector2Array()
			for k in 13:
				var t := float(k) / 12.0
				var x := lerpf(-r * 0.9, r * 0.9, t)
				var y := sin(t * PI) * r * 0.5
				up.append(c + Vector2(x, -y))
				down.append(c + Vector2(x, y))
			down.reverse()
			up.append_array(down)
			draw_colored_polygon(up, light)
			draw_polyline(PackedVector2Array(Array(up) + [up[0]]), ink, maxf(1.5, s * 0.07))
			draw_circle(c, r * 0.28, ink)
			draw_circle(c + Vector2(-r * 0.08, -r * 0.08), r * 0.08, light)
		"speaker":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.25), c + Vector2(-r * 0.4, -r * 0.25),
				c + Vector2(0, -r * 0.65), c + Vector2(0, r * 0.65), c + Vector2(-r * 0.4, r * 0.25),
				c + Vector2(-r * 0.8, r * 0.25)]), ink)
			for k in 2:
				draw_arc(c + Vector2(r * 0.05, 0), r * (0.35 + 0.28 * k), -0.9, 0.9, 12, ink, maxf(1.5, s * 0.08))
		"note":
			draw_circle(c + Vector2(-r * 0.3, r * 0.5), r * 0.28, ink)
			draw_line(c + Vector2(-r * 0.05, r * 0.45), c + Vector2(-r * 0.05, -r * 0.7), ink, maxf(2.0, s * 0.1))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.05, -r * 0.7), c + Vector2(r * 0.6, -r * 0.45),
				c + Vector2(r * 0.6, -r * 0.1), c + Vector2(-r * 0.05, -r * 0.35)]), ink)
		"zoom_in", "zoom_out", "fit":
			var lens := c + Vector2(-r * 0.12, -r * 0.12)
			draw_circle(lens, r * 0.55, light)
			draw_arc(lens, r * 0.55, 0.0, TAU, 24, ink, maxf(2.0, s * 0.1))
			draw_line(lens + Vector2(r * 0.4, r * 0.4), c + Vector2(r * 0.85, r * 0.85), ink, maxf(2.5, s * 0.14))
			if kind != "fit":
				draw_line(lens + Vector2(-r * 0.3, 0), lens + Vector2(r * 0.3, 0), ink, maxf(1.5, s * 0.08))
			if kind == "zoom_in":
				draw_line(lens + Vector2(0, -r * 0.3), lens + Vector2(0, r * 0.3), ink, maxf(1.5, s * 0.08))
			if kind == "fit":
				draw_rect(Rect2(lens - Vector2(r * 0.25, r * 0.25), Vector2(r * 0.5, r * 0.5)), ink, false,
					maxf(1.5, s * 0.07))
		"camera":
			draw_rect(Rect2(c + Vector2(-r * 0.85, -r * 0.45), Vector2(r * 1.7, r * 1.1)), ink)
			draw_rect(Rect2(c + Vector2(-r * 0.35, -r * 0.7), Vector2(r * 0.7, r * 0.3)), ink)
			draw_circle(c + Vector2(0, r * 0.1), r * 0.38, light)
			draw_circle(c + Vector2(0, r * 0.1), r * 0.22, ink)
		"arrow":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.8), c + Vector2(-r * 0.45, r * 0.55),
				c + Vector2(-r * 0.12, r * 0.25), c + Vector2(r * 0.12, r * 0.85), c + Vector2(r * 0.35, r * 0.75),
				c + Vector2(r * 0.1, r * 0.2), c + Vector2(r * 0.5, r * 0.15)]), light)
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.8), c + Vector2(-r * 0.45, r * 0.55),
				c + Vector2(-r * 0.12, r * 0.25), c + Vector2(r * 0.12, r * 0.85), c + Vector2(r * 0.35, r * 0.75),
				c + Vector2(r * 0.1, r * 0.2), c + Vector2(r * 0.5, r * 0.15), c + Vector2(-r * 0.45, -r * 0.8)]), ink,
				maxf(1.5, s * 0.07))
		"ribbon":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, r * 0.1), c + Vector2(-r * 0.6, r * 0.9),
				c + Vector2(-r * 0.2, r * 0.7), c + Vector2(0, r * 0.95), c + Vector2(r * 0.05, r * 0.1)]),
				UiTheme.color("coin_bar_dark"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.35, r * 0.1), c + Vector2(r * 0.6, r * 0.9),
				c + Vector2(r * 0.2, r * 0.7), c + Vector2(0, r * 0.95), c + Vector2(-r * 0.05, r * 0.1)]),
				UiTheme.color("coin_bar"))
			draw_circle(c + Vector2(0, -r * 0.25), r * 0.55, UiTheme.color("star"))
			draw_arc(c + Vector2(0, -r * 0.25), r * 0.55, 0.0, TAU, 24, UiTheme.color("star_edge"), maxf(1.5, s * 0.07))
			draw_circle(c + Vector2(0, -r * 0.25), r * 0.22, light)
		"plus":
			draw_line(c + Vector2(-r * 0.6, 0), c + Vector2(r * 0.6, 0), UiTheme.color("plus"), maxf(2.5, s * 0.2))
			draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6), UiTheme.color("plus"), maxf(2.5, s * 0.2))
		"hoe", "seeds", "basket", "fertilizer", "move", "barn", "tag":
			_draw_tool(c, r, s, ink, light)
		"market", "album", "neighbours", "gear":
			_draw_menu(c, r, s, ink, light)
		"cross":
			draw_line(c + Vector2(-r * 0.5, -r * 0.5), c + Vector2(r * 0.5, r * 0.5), ink, maxf(2.5, s * 0.14))
			draw_line(c + Vector2(r * 0.5, -r * 0.5), c + Vector2(-r * 0.5, r * 0.5), ink, maxf(2.5, s * 0.14))
		"lock":
			draw_arc(c + Vector2(0, -r * 0.15), r * 0.38, PI, TAU, 16, ink, maxf(2.0, s * 0.1))
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.15), Vector2(r * 1.2, r * 0.95)), UiTheme.color("coin_edge"))
			draw_circle(c + Vector2(0, r * 0.25), r * 0.12, ink)
		_:
			draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)), Color.MAGENTA, false, 2.0)
	if struck:
		draw_line(c + Vector2(-r * 0.85, -r * 0.85), c + Vector2(r * 0.85, r * 0.85), Color("#d23b2e"), maxf(2.5, s * 0.12))



## The farm tools: a hoe, a seed bag, a basket of produce, a fertilizer sack, four-way arrows, a red barn, a price tag.
func _draw_tool(c: Vector2, r: float, s: float, ink: Color, light: Color) -> void:
	var w := maxf(1.5, s * 0.07)
	match kind:
		"hoe":
			draw_line(c + Vector2(-r * 0.7, r * 0.8), c + Vector2(r * 0.35, -r * 0.45), UiTheme.color("wood_light"),
				maxf(2.5, s * 0.12))
			var blade := PackedVector2Array([c + Vector2(r * 0.15, -r * 0.75), c + Vector2(r * 0.85, -r * 0.5),
				c + Vector2(r * 0.6, -r * 0.15), c + Vector2(r * 0.3, -r * 0.4)])
			draw_colored_polygon(blade, UiTheme.color("metal"))
			draw_polyline(PackedVector2Array(Array(blade) + [blade[0]]), ink, w)
		"seeds":
			var bag := PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.35), c + Vector2(-r * 0.3, -r * 0.75),
				c + Vector2(r * 0.3, -r * 0.75), c + Vector2(r * 0.6, -r * 0.35), c + Vector2(r * 0.7, r * 0.85),
				c + Vector2(-r * 0.7, r * 0.85)])
			draw_colored_polygon(bag, UiTheme.color("sack"))
			draw_polyline(PackedVector2Array(Array(bag) + [bag[0]]), ink, w)
			draw_circle(c + Vector2(0, r * 0.2), r * 0.28, UiTheme.color("leaf"))
		"basket":
			draw_circle(c + Vector2(-r * 0.35, -r * 0.15), r * 0.28, UiTheme.color("berry"))
			draw_circle(c + Vector2(r * 0.05, -r * 0.3), r * 0.28, UiTheme.color("coin"))
			draw_circle(c + Vector2(r * 0.4, -r * 0.12), r * 0.28, UiTheme.color("leaf"))
			var b := PackedVector2Array([c + Vector2(-r * 0.85, 0), c + Vector2(r * 0.85, 0),
				c + Vector2(r * 0.6, r * 0.85), c + Vector2(-r * 0.6, r * 0.85)])
			draw_colored_polygon(b, UiTheme.color("wood_light"))
			draw_polyline(PackedVector2Array(Array(b) + [b[0]]), ink, w)
		"fertilizer":
			draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.7), Vector2(r * 1.1, r * 1.5)), UiTheme.color("sack"))
			draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.7), Vector2(r * 1.1, r * 1.5)), ink, false, w)
			draw_circle(c + Vector2(0, r * 0.05), r * 0.3, UiTheme.color("leaf"))
		"move":
			var col := UiTheme.color("sky_ink")
			draw_line(c + Vector2(-r * 0.75, 0), c + Vector2(r * 0.75, 0), col, maxf(2.0, s * 0.1))
			draw_line(c + Vector2(0, -r * 0.75), c + Vector2(0, r * 0.75), col, maxf(2.0, s * 0.1))
			for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				var tip := c + d * r * 0.9
				var side := Vector2(-d.y, d.x) * r * 0.25
				draw_colored_polygon(PackedVector2Array([tip, tip - d * r * 0.35 + side, tip - d * r * 0.35 - side]), col)
		"barn":
			var house := PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.15), c + Vector2(0, -r * 0.8),
				c + Vector2(r * 0.8, -r * 0.15), c + Vector2(r * 0.8, r * 0.8), c + Vector2(-r * 0.8, r * 0.8)])
			draw_colored_polygon(house, UiTheme.color("barn_red"))
			draw_polyline(PackedVector2Array(Array(house) + [house[0]]), ink, w)
			draw_rect(Rect2(c + Vector2(-r * 0.3, r * 0.15), Vector2(r * 0.6, r * 0.65)), light)
		"tag":
			var tag := PackedVector2Array([c + Vector2(-r * 0.85, r * 0.05), c + Vector2(-r * 0.05, -r * 0.8),
				c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.0), c + Vector2(0, r * 0.85)])
			draw_colored_polygon(tag, UiTheme.color("coin"))
			draw_polyline(PackedVector2Array(Array(tag) + [tag[0]]), UiTheme.color("coin_edge"), w)
			draw_circle(c + Vector2(r * 0.45, -r * 0.45), r * 0.12, UiTheme.color("coin_edge"))


## The menu: a market stall, a collection album, two neighbours, a gear.
func _draw_menu(c: Vector2, r: float, s: float, ink: Color, light: Color) -> void:
	var w := maxf(1.5, s * 0.07)
	match kind:
		"market":
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.1), Vector2(r * 1.4, r * 0.9)), light)
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.1), Vector2(r * 1.4, r * 0.9)), ink, false, w)
			for k in 4:
				var x := -r * 0.85 + r * 0.425 * k
				draw_colored_polygon(PackedVector2Array([c + Vector2(x, -r * 0.75), c + Vector2(x + r * 0.425, -r * 0.75),
					c + Vector2(x + r * 0.425, -r * 0.1), c + Vector2(x, -r * 0.1)]),
					UiTheme.color("barn_red") if k % 2 == 0 else light)
			draw_rect(Rect2(c + Vector2(-r * 0.85, -r * 0.75), Vector2(r * 1.7, r * 0.65)), ink, false, w)
		"album":
			draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.75), Vector2(r * 1.5, r * 1.5)), UiTheme.color("sky_ink"))
			for k in 4:
				var at := c + Vector2(-r * 0.55 + (k % 2) * r * 0.6, -r * 0.55 + int(k / 2.0) * r * 0.6)
				draw_rect(Rect2(at, Vector2(r * 0.5, r * 0.5)), light)
		"neighbours":
			for k in 2:
				var x := -r * 0.35 + r * 0.7 * k
				var col := UiTheme.color("skin") if k == 0 else UiTheme.color("skin").darkened(0.2)
				draw_circle(c + Vector2(x, -r * 0.35), r * 0.3, col)
				draw_colored_polygon(PackedVector2Array([c + Vector2(x - r * 0.45, r * 0.85),
					c + Vector2(x - r * 0.3, r * 0.1), c + Vector2(x + r * 0.3, r * 0.1), c + Vector2(x + r * 0.45, r * 0.85)]),
					UiTheme.color("cash_bar"))
		"gear":
			for k in 8:
				var a := TAU * k / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.45, c + Vector2(cos(a), sin(a)) * r * 0.88, ink,
					maxf(3.0, s * 0.16))
			draw_circle(c, r * 0.55, ink)
			draw_circle(c, r * 0.24, light)
