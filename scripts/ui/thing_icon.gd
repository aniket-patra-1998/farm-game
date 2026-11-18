class_name ThingIcon
extends UiIcon
## A collection item's picture (our own touch: FarmVille had a painted picture for each): one of a set of small
## things (a jar, a key, a bird, a straw hat...), drawn in the icons' sticker style in the item's own colour and
## accent (data/collections.json `look`: [shape, colour, accent]). Square; it fills the smaller side.

const SHAPES: Array[String] = ["apple", "badge", "ball", "basket", "bell", "bird", "boll", "book", "bow", "bowl",
	"box", "brush", "bug", "bulb", "button", "can", "cane", "card", "charm", "clip", "clover", "crate", "crock",
	"crown", "cube", "cushion", "daisies", "dipper", "doll", "drill", "flail", "flower", "glove", "grater", "hat",
	"hook", "horseshoe", "jar", "jug", "key", "knife", "lantern", "map", "mortar", "net", "onions", "packet", "pad",
	"pail", "peeler", "picker", "pot", "pouch", "quilt", "rattle", "ribbon", "ristra", "rose", "sack", "saw", "scale",
	"scoop", "shears", "sickle", "spindle", "splat", "spool", "tag", "thimble", "tin", "top", "tray", "trowel", "tube",
	"vase", "whisk"]
const WOOD := Color("#a8743f")
const STEEL := Color("#b7c0c7")
const LEAF := Color("#5c9a3e")

var shape := "jar"
var colour := Color("#c89a5a")
var accent := Color("#c0392b")


## The picture for `look` ([shape, colour, accent]) at `px` across.
static func of(look: Array, px: float) -> ThingIcon:
	var t := ThingIcon.new()
	t.kind = "thing"
	t.shape = str(look[0]) if look.size() > 0 else "jar"
	t.colour = Color.html(str(look[1])) if look.size() > 1 else t.colour
	t.accent = Color.html(str(look[2])) if look.size() > 2 else t.accent
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _draw() -> void:
	_s = minf(size.x, size.y)
	if _s <= 0.0:
		return
	_c = size / 2.0
	_r = _s / 2.0 * 0.86
	_painted()


func _paint() -> void:
	_thing()


## A handle from (x0, y0) to (x1, y1) as a thick stick of `col`.
func _stick(x0: float, y0: float, x1: float, y1: float, w: float, col: Color) -> void:
	var a := Vector2(x0, y0)
	var b := Vector2(x1, y1)
	var side := (b - a).normalized().orthogonal() * w
	_shape(_pts([a.x + side.x, a.y + side.y, b.x + side.x, b.y + side.y, b.x - side.x, b.y - side.y,
		a.x - side.x, a.y - side.y]), col, false)


func _thing() -> void:
	var a := colour
	var b := accent
	var light := UiTheme.color("icon_light")
	match shape:
		"apple":
			_shape(_pts([0.0, -0.45, 0.45, -0.6, 0.85, -0.2, 0.75, 0.45, 0.35, 0.85, 0.0, 0.7, -0.35, 0.85, -0.75, 0.45,
				-0.85, -0.2, -0.45, -0.6]), a)
			_line(_p(0.0, -0.45), _p(0.08, -0.85), 0.07, WOOD.darkened(0.3))
			_shape(_ring(0.3, -0.75, 0.2, 0.5), b, false, false)
		"badge", "button", "charm":
			_shape(_ring(0, 0, 0.82), a)
			if shape == "button":
				for k in 4:
					_dot(_p(-0.2 + 0.4 * (k % 2), -0.2 + 0.4 * (k / 2)), 0.1, b)
			elif shape == "badge":
				_shape(_ring(0, 0.05, 0.42, 0.7), b, false, false)
				for k in 2:
					_line(_p(-0.3, -0.05 + 0.2 * k), _p(0.3, -0.05 + 0.2 * k), 0.07, a)
			else:
				_shape(star_points(_p(0, 0.04), _r * 0.48), b, false, false)
				_line(_p(0, -0.82), _p(0, -1.0), 0.08)
		"ball", "boll":
			_shape(_ring(0, 0.05, 0.78), a)
			if shape == "ball":
				for k in 3:
					draw_arc(_p(0, 0.05), _r * (0.3 + 0.18 * k), -2.4 + k * 0.4, 0.2 + k * 0.4, 10, b,
						maxf(1.0, _s * 0.035), true)
			else:
				for k in 3:
					_shape(_ring(-0.3 + 0.3 * k, -0.1 + 0.12 * (k % 2), 0.36), a, false, false)
				_shape(_pts([-0.45, 0.45, 0.45, 0.45, 0.0, 0.95]), b)
		"basket", "crate", "tray":
			if shape == "basket":
				for k in 3:
					_shape(_ring(-0.4 + 0.4 * k, -0.15, 0.25), b, true, false)
			if shape == "crate":
				for k in 2:
					_shape(_ring(-0.3 + 0.6 * k, -0.2, 0.36), b)
			var top := -0.05 if shape != "tray" else 0.1
			_shape(_pts([-0.92, top, 0.92, top, 0.7 if shape != "crate" else 0.85, 0.85, -0.7 if shape != "crate" else -0.85,
				0.85]), a)
			for k in 3:
				_line(_p(-0.8, top + 0.22 + 0.22 * k), _p(0.8, top + 0.22 + 0.22 * k), 0.03)
			if shape == "tray":
				for k in 4:
					_dot(_p(-0.45 + 0.3 * k, 0.0), 0.09, b)
		"bell":
			_shape(_pts([-0.15, -0.8, 0.15, -0.8, 0.45, -0.3, 0.55, 0.5, 0.75, 0.65, -0.75, 0.65, -0.55, 0.5, -0.45, -0.3]), a)
			_shape(_ring(0, 0.72, 0.16), b)
			_line(_p(-0.5, 0.35), _p(0.5, 0.35), 0.05, b)
		"bird":
			_shape(_pts([-0.85, 0.1, -0.45, -0.1, -0.2, -0.55, 0.25, -0.65, 0.55, -0.4, 0.8, -0.3, 0.55, -0.15, 0.5, 0.3,
				0.0, 0.6, -0.5, 0.5]), a)
			_shape(_pts([-0.1, 0.0, 0.42, -0.1, 0.4, 0.3, 0.0, 0.5]), b, false, false)
			_shape(_pts([-0.55, 0.1, -0.05, -0.05, -0.2, 0.3]), a.darkened(0.2), false, false)
			_dot(_p(0.3, -0.42), 0.06, UiTheme.color("icon_outline"))
			_line(_p(0.0, 0.58), _p(-0.05, 0.85), 0.04)
			_line(_p(0.2, 0.52), _p(0.18, 0.85), 0.04)
		"book", "map", "card", "packet", "quilt", "tag":
			var shift := -0.15 if shape == "book" else 0.0
			_shape(_pts([-0.62 + shift, -0.8, 0.62 + shift, -0.8, 0.62 + shift, 0.8, -0.62 + shift, 0.8]),
				a if shape != "map" else light)
			match shape:
				"book":
					_shape(_pts([0.47, -0.72, 0.75, -0.62, 0.75, 0.88, 0.47, 0.78]), light, false, false)
					_shape(_pts([-0.5, -0.4, 0.3, -0.4, 0.3, 0.0, -0.5, 0.0]), b, false, false)
				"map":
					_line(_p(-0.45, 0.5), _p(-0.1, 0.0), 0.04, b)
					_line(_p(-0.1, 0.0), _p(0.35, 0.2), 0.04, b)
					_line(_p(0.35, 0.2), _p(0.3, -0.5), 0.04, b)
					_shape(_ring(0.3, -0.5, 0.12), Color("#d9442f"), false, false)
				"card":
					for k in 4:
						_line(_p(-0.42, -0.4 + 0.25 * k), _p(0.42 - 0.2 * (k % 2), -0.4 + 0.25 * k), 0.035)
					_shape(_ring(0.3, 0.5, 0.18), b, false, false)
				"packet":
					_shape(_ring(0, 0.0, 0.38), b, false, false)
					_line(_p(-0.62, -0.55), _p(0.62, -0.55), 0.05)
				"quilt":
					for k in 4:
						draw_colored_polygon(_pts([-0.62 + 0.62 * (k % 2), -0.8 + 0.8 * (k / 2), 0.62 * (k % 2), -0.8 + 0.8 * (k / 2),
							0.62 * (k % 2), 0.8 * (k / 2), -0.62 + 0.62 * (k % 2), 0.8 * (k / 2)]), b if (k % 3) == 0 else a)
					_line(_p(0, -0.8), _p(0, 0.8), 0.03)
					_line(_p(-0.62, 0), _p(0.62, 0), 0.03)
				"tag":
					_shape(_ring(0, -0.5, 0.12), light, false, false)
					_shape(_ring(0, 0.2, 0.3), b, false, false)
		"bow", "ribbon":
			if shape == "ribbon":
				_shape(_pts([-0.3, 0.1, -0.55, 0.95, -0.2, 0.75, 0.0, 0.98, 0.05, 0.1]), b.darkened(0.15))
				_shape(_pts([0.3, 0.1, 0.55, 0.95, 0.2, 0.75, 0.0, 0.98, -0.05, 0.1]), b)
				var pleats := PackedVector2Array()
				for k in 24:
					var ang := TAU * k / 24.0
					var rr := 0.6 if k % 2 == 0 else 0.5
					pleats.append(_p(cos(ang) * rr, -0.25 + sin(ang) * rr))
				_shape(pleats, a)
				_shape(_ring(0, -0.25, 0.3), a.lightened(0.25), true, false)
			else:
				_shape(_pts([0.0, 0.0, -0.9, -0.55, -0.9, 0.5]), a)
				_shape(_pts([0.0, 0.0, 0.9, -0.55, 0.9, 0.5]), a)
				_shape(_pts([-0.1, 0.1, -0.4, 0.9, -0.15, 0.75]), b, false)
				_shape(_pts([0.1, 0.1, 0.4, 0.9, 0.15, 0.75]), b, false)
				_shape(_ring(0, 0, 0.2), b)
		"bowl", "mortar":
			if shape == "mortar":
				_stick(0.1, -0.9, 0.4, 0.0, 0.11, a.lightened(0.15))
			else:
				for k in 3:
					_shape(_ring(-0.35 + 0.35 * k, -0.15, 0.24), b, true, false)
			_shape(_pts([-0.9, -0.05, 0.9, -0.05, 0.65, 0.55, 0.35, 0.75, -0.35, 0.75, -0.65, 0.55]), a)
			_line(_p(-0.85, 0.05), _p(0.85, 0.05), 0.04, light)
		"box", "tin", "cube":
			var d := 0.25
			_shape(_pts([-0.7, -0.35, 0.45, -0.35, 0.45, 0.85, -0.7, 0.85]), a)
			_shape(_pts([-0.7, -0.35, -0.7 + d, -0.35 - d, 0.45 + d, -0.35 - d, 0.45, -0.35]), a.lightened(0.2), false)
			_shape(_pts([0.45, -0.35, 0.45 + d, -0.35 - d, 0.45 + d, 0.85 - d, 0.45, 0.85]), a.darkened(0.2), false)
			if shape == "box":
				_line(_p(-0.7, -0.05), _p(0.45, -0.05), 0.05, b)
				_shape(_ring(-0.12, 0.35, 0.17), b, false, false)
			elif shape == "tin":
				_shape(_pts([-0.5, 0.05, 0.25, 0.05, 0.25, 0.55, -0.5, 0.55]), b, false, false)
		"brush", "whisk":
			_stick(-0.1, 0.9, 0.0, -0.15, 0.12, WOOD if shape == "brush" else a)
			var bristles := _pts([-0.45, -0.2, 0.45, -0.2, 0.55, -0.9, -0.55, -0.9]) if shape == "brush" else \
				_pts([-0.15, -0.1, 0.15, -0.1, 0.5, -0.85, -0.5, -0.85])
			_shape(bristles, b if shape == "brush" else a)
			for k in 5:
				_line(_p(-0.4 + 0.2 * k, -0.25), _p(-0.45 + 0.225 * k, -0.85), 0.025)
		"bug":
			_shape(_ring(0, 0.1, 0.75, 0.85), a)
			_shape(_ring(0, -0.6, 0.3, 0.7), b, false)
			_line(_p(0, -0.55), _p(0, 0.82), 0.05)
			for k in 4:
				_dot(_p(-0.35 + 0.7 * (k % 2), -0.1 + 0.45 * (k / 2)), 0.13, b)
		"bulb":
			_shape(_pts([0.0, -0.5, 0.5, -0.1, 0.6, 0.35, 0.3, 0.75, -0.3, 0.75, -0.6, 0.35, -0.5, -0.1]), a)
			_stick(0.0, -0.45, 0.0, -0.95, 0.08, b)
			for k in 3:
				_line(_p(-0.25 + 0.25 * k, 0.75), _p(-0.3 + 0.3 * k, 0.95), 0.03)
		"can", "pail", "jug", "pot", "crock", "jar", "vase", "lantern", "thimble":
			_vessel(a, b, light)
		"cane":
			var pts := PackedVector2Array()
			for k in 9:
				var ang := PI + PI * k / 8.0
				pts.append(_p(0.05 + cos(ang) * 0.42, -0.45 + sin(ang) * 0.42))
			pts.append(_p(0.47, -0.45))
			for k in range(8, -1, -1):
				var ang := PI + PI * k / 8.0
				pts.append(_p(0.05 + cos(ang) * 0.2, -0.45 + sin(ang) * 0.2))
			pts.append(_p(-0.15, 0.9))
			pts.append(_p(-0.37, 0.9))
			_shape(pts, a)
			for k in 4:
				_line(_p(-0.37, 0.75 - 0.3 * k), _p(-0.15, 0.6 - 0.3 * k), 0.06, b)
		"clip", "hook":
			if shape == "clip":
				_shape(_pts([-0.8, -0.15, 0.6, -0.35, 0.9, -0.1, 0.6, 0.15, -0.8, 0.05]), a)
				_shape(_pts([-0.8, 0.15, 0.6, 0.3, 0.9, 0.55, 0.6, 0.65, -0.8, 0.35]), a.darkened(0.15))
				_shape(_ring(-0.6, 0.1, 0.18), b)
			else:
				_stick(0.0, 0.95, 0.0, 0.1, 0.13, b)
				draw_arc(_p(0.25, -0.2), _r * 0.32, PI * 0.1, PI * 1.05, 14, UiTheme.color("icon_outline"),
					maxf(2.5, _s * 0.14), true)
				draw_arc(_p(0.25, -0.2), _r * 0.32, PI * 0.1, PI * 1.05, 14, a, maxf(1.5, _s * 0.07), true)
		"clover", "flower", "daisies", "rose", "pad":
			_bloom(a, b)
		"crown":
			for k in 5:
				var ang := -PI / 2.0 + (k - 2) * 0.35
				_shape(_pts([0.0, 0.35, cos(ang) * 0.95, sin(ang) * 0.95 + 0.2, cos(ang) * 0.75 + 0.15,
					sin(ang) * 0.75 + 0.3]), a.lightened(0.08 * k))
			_shape(_ring(0, 0.62, 0.32, 0.8), b)
		"cushion":
			_shape(_pts([-0.85, -0.35, -0.6, -0.55, 0.6, -0.55, 0.85, -0.35, 0.85, 0.45, 0.6, 0.65, -0.6, 0.65, -0.85,
				0.45]), a)
			_line(_p(-0.6, 0.05), _p(0.6, 0.05), 0.04, b)
			for k in 3:
				_dot(_p(-0.4 + 0.4 * k, 0.05), 0.07, b)
		"dipper", "scoop", "trowel", "picker", "peeler":
			_tool(a, b)
		"doll":
			_shape(_pts([-0.15, -0.35, 0.15, -0.35, 0.65, 0.9, -0.65, 0.9]), a)
			_shape(_ring(0, -0.6, 0.28), a.lightened(0.1))
			_line(_p(-0.5, 0.0), _p(0.5, 0.0), 0.08, b)
			for k in 4:
				_line(_p(-0.4 + 0.27 * k, 0.3), _p(-0.5 + 0.33 * k, 0.88), 0.025)
		"drill", "tube":
			_stick(-0.8, 0.4, 0.75, -0.3, 0.2, a)
			if shape == "drill":
				for k in 2:
					_shape(_ring(-0.45 + 0.9 * k, 0.6, 0.25), STEEL)
			else:
				_shape(_ring(0.75, -0.3, 0.2), b)
		"flail":
			_stick(-0.75, 0.9, 0.1, -0.1, 0.09, a)
			_stick(0.15, -0.15, 0.75, -0.75, 0.12, b)
			_dot(_p(0.12, -0.12), 0.1, UiTheme.color("icon_outline"))
		"glove":
			_shape(_pts([-0.45, 0.9, -0.5, 0.0, -0.85, -0.25, -0.75, -0.4, -0.45, -0.2, -0.45, -0.75, -0.25, -0.75,
				-0.2, -0.3, -0.1, -0.85, 0.1, -0.85, 0.12, -0.3, 0.25, -0.75, 0.42, -0.7, 0.4, -0.25, 0.55, -0.55, 0.7,
				-0.48, 0.5, 0.2, 0.45, 0.9]), a)
			_shape(_pts([-0.5, 0.55, 0.47, 0.55, 0.45, 0.9, -0.45, 0.9]), b, false)
		"grater", "scale":
			if shape == "scale":
				_shape(_pts([-0.5, -0.1, 0.5, -0.1, 0.65, 0.85, -0.65, 0.85]), a)
				_shape(_ring(0, 0.35, 0.3), light, false, false)
				_line(_p(0, 0.35), _p(0.18, 0.2), 0.04, Color("#d9442f"))
				_shape(_pts([-0.8, -0.35, 0.8, -0.35, 0.6, -0.1, -0.6, -0.1]), STEEL)
				_shape(_ring(0.1, -0.55, 0.28), b)
			else:
				_shape(_pts([-0.45, -0.7, 0.45, -0.7, 0.55, 0.85, -0.55, 0.85]), a)
				for k in 12:
					_dot(_p(-0.3 + 0.3 * (k % 3), -0.45 + 0.4 * (k / 3)), 0.06, UiTheme.color("icon_outline"))
				_stick(0.0, -0.7, 0.0, -1.0, 0.1, b)
		"hat":
			_shape(_ring(0, 0.4, 0.95, 0.35), a)
			_shape(_pts([-0.5, 0.35, -0.42, -0.3, -0.2, -0.5, 0.2, -0.5, 0.42, -0.3, 0.5, 0.35]), a.lightened(0.05))
			_shape(_pts([-0.47, 0.05, 0.47, 0.05, 0.5, 0.3, -0.5, 0.3]), b, false)
		"horseshoe":
			draw_arc(_p(0, 0.05), _r * 0.58, PI * 0.95, PI * 2.05, 18, UiTheme.color("icon_outline"), maxf(4.0, _s * 0.3),
				true)
			draw_arc(_p(0, 0.05), _r * 0.58, PI * 0.95, PI * 2.05, 18, a, maxf(2.5, _s * 0.2), true)
			draw_arc(_p(0, 0.05), _r * 0.58, PI * 0.95, PI * 1.25, 8, a.lightened(0.3), maxf(1.0, _s * 0.05), true)
			for k in 6:
				var ang := PI * (1.05 + 0.18 * k)
				_dot(_p(cos(ang) * 0.58, 0.05 + sin(ang) * 0.58), 0.05, b)
		"key":
			_shape(_ring(-0.45, -0.4, 0.38), a)
			_shape(_ring(-0.45, -0.4, 0.15), light, false, false)
			_stick(-0.2, -0.15, 0.75, 0.8, 0.1, a)
			_stick(0.42, 0.47, 0.6, 0.3, 0.07, a)
			_stick(0.6, 0.65, 0.78, 0.48, 0.07, a)
		"knife", "sickle", "saw", "shears":
			_blade(a, b)
		"net":
			_stick(-0.8, 0.9, -0.15, 0.1, 0.08, b)
			_shape(_ring(0.25, -0.35, 0.6), a)
			for k in 4:
				_line(_p(-0.25 + 0.25 * k, -0.85), _p(-0.25 + 0.25 * k, 0.15), 0.025)
				_line(_p(-0.3, -0.75 + 0.25 * k), _p(0.8, -0.75 + 0.25 * k), 0.025)
		"onions", "ristra":
			_line(_p(0, -0.95), _p(0, 0.85), 0.05, WOOD)
			for k in 5:
				var y := -0.65 + 0.35 * k
				var x := 0.22 if k % 2 == 0 else -0.22
				if shape == "onions":
					_shape(_pts([x, y - 0.32, x + 0.28, y, x, y + 0.28, x - 0.28, y]), a)
				else:
					_shape(_pts([x, y - 0.2, x + 0.16, y - 0.1, x * 0.2, y + 0.4]), a)
					_line(_p(x, y - 0.2), _p(x * 0.5, y - 0.3), 0.04, b)
		"pouch", "sack":
			_shape(_pts([-0.3, -0.45, 0.3, -0.45, 0.75, 0.2, 0.6, 0.85, -0.6, 0.85, -0.75, 0.2]), a)
			_shape(_pts([-0.3, -0.45, -0.45, -0.85, 0.0, -0.65, 0.45, -0.85, 0.3, -0.45]), a.darkened(0.08), false)
			_line(_p(-0.32, -0.47), _p(0.32, -0.47), 0.07, b)
			if shape == "sack":
				for k in 3:
					_line(_p(-0.3, 0.2 + 0.18 * k), _p(0.3, 0.2 + 0.18 * k), 0.03, b)
		"rattle":
			_stick(0.0, 0.95, 0.0, 0.1, 0.1, WOOD)
			_shape(_ring(0, -0.3, 0.55, 1.1), a)
			for k in 3:
				_line(_p(-0.3, -0.6 + 0.3 * k), _p(0.3, -0.55 + 0.3 * k), 0.04, b)
		"spindle", "spool":
			if shape == "spindle":
				_stick(0.0, -0.95, 0.0, 0.95, 0.06, WOOD)
				_shape(_ring(0, 0.0, 0.5, 0.7), b)
				_shape(_ring(0, 0.6, 0.35, 0.3), a)
			else:
				_shape(_pts([-0.6, -0.8, 0.6, -0.8, 0.6, -0.6, -0.6, -0.6]), WOOD)
				_shape(_pts([-0.45, -0.6, 0.45, -0.6, 0.45, 0.6, -0.45, 0.6]), b)
				for k in 5:
					_line(_p(-0.45, -0.45 + 0.24 * k), _p(0.45, -0.4 + 0.24 * k), 0.025, b.darkened(0.25))
				_shape(_pts([-0.6, 0.6, 0.6, 0.6, 0.6, 0.8, -0.6, 0.8]), WOOD)
		"splat":
			var pts := PackedVector2Array()
			for k in 16:
				var ang := TAU * k / 16.0
				pts.append(_p(cos(ang) * (0.75 if k % 2 == 0 else 0.48), sin(ang) * (0.75 if k % 2 == 0 else 0.48)))
			_shape(pts, a)
			_shape(_ring(0.15, -0.1, 0.25), b, true, false)
		"top":
			_shape(_pts([0.0, 0.95, 0.85, -0.05, 0.0, -0.45, -0.85, -0.05]), a)
			_shape(_pts([-0.85, -0.05, 0.85, -0.05, 0.6, 0.2, -0.6, 0.2]), b, false)
			_stick(0.0, -0.45, 0.0, -0.95, 0.09, WOOD)
		_:
			_shape(_ring(0, 0, 0.7), a)


## Things that hold something: jars, jugs, pails, cans, pots, a vase, a lantern, a thimble.
func _vessel(a: Color, b: Color, light: Color) -> void:
	match shape:
		"jar", "crock":
			_shape(_pts([-0.55, -0.5, 0.55, -0.5, 0.7, -0.2, 0.7, 0.75, 0.5, 0.9, -0.5, 0.9, -0.7, 0.75, -0.7, -0.2]),
				a if shape == "crock" else a.lerp(light, 0.15))
			_shape(_pts([-0.6, -0.85, 0.6, -0.85, 0.6, -0.5, -0.6, -0.5]), b)
			if shape == "jar":
				_shape(_pts([-0.45, 0.0, 0.45, 0.0, 0.45, 0.5, -0.45, 0.5]), light, false, false)
		"jug":
			_shape(_pts([-0.25, -0.85, 0.25, -0.85, 0.25, -0.45, 0.7, -0.1, 0.7, 0.75, 0.5, 0.9, -0.5, 0.9, -0.7, 0.75,
				-0.7, -0.1, -0.25, -0.45]), a)
			draw_arc(_p(0.7, 0.15), _r * 0.25, -PI / 2.0, PI / 2.0, 10, UiTheme.color("icon_outline"), maxf(2.0, _s * 0.1),
				true)
			_shape(_pts([-0.5, 0.1, 0.5, 0.1, 0.5, 0.4, -0.5, 0.4]), b, false, false)
		"pail", "can":
			draw_arc(_p(0, -0.25), _r * 0.6, PI, TAU, 14, UiTheme.color("icon_outline"), maxf(2.0, _s * 0.07), true)
			_shape(_pts([-0.7, -0.3, 0.7, -0.3, 0.55, 0.88, -0.55, 0.88]), a)
			_line(_p(-0.66, 0.0), _p(0.66, 0.0), 0.04, a.darkened(0.25))
			if shape == "can":
				_stick(0.6, 0.0, 0.98, -0.5, 0.09, a.darkened(0.1))
				_shape(_ring(0.95, -0.55, 0.12), a.darkened(0.2), false)
			else:
				_shape(_ring(0, -0.3, 0.6, 0.22), b, false, false)
		"pot":
			_shape(_pts([-0.7, -0.35, 0.7, -0.35, 0.5, 0.88, -0.5, 0.88]), a)
			_shape(_pts([-0.8, -0.55, 0.8, -0.55, 0.8, -0.3, -0.8, -0.3]), a.lightened(0.1))
			for k in 3:
				_dot(_p(-0.3 + 0.3 * k, 0.25), 0.08, b)
		"vase":
			_line(_p(-0.25, -0.5), _p(-0.4, -0.85), 0.05, LEAF)
			_line(_p(0.25, -0.5), _p(0.45, -0.85), 0.05, LEAF)
			_shape(_ring(-0.4, -0.85, 0.15), b, false)
			_shape(_ring(0.45, -0.85, 0.15), b, false)
			_shape(_pts([-0.25, -0.55, 0.25, -0.55, 0.2, -0.2, 0.6, 0.3, 0.4, 0.88, -0.4, 0.88, -0.6, 0.3, -0.2, -0.2]), a)
		"lantern":
			draw_arc(_p(0, -0.65), _r * 0.25, PI, TAU, 10, UiTheme.color("icon_outline"), maxf(2.0, _s * 0.07), true)
			_shape(_pts([-0.5, -0.65, 0.5, -0.65, 0.4, -0.45, -0.4, -0.45]), a)
			_shape(_pts([-0.4, -0.45, 0.4, -0.45, 0.45, 0.6, -0.45, 0.6]), b.lerp(light, 0.4))
			_shape(_ring(0, 0.1, 0.18, 1.4), b, false, false)
			_shape(_pts([-0.55, 0.6, 0.55, 0.6, 0.55, 0.85, -0.55, 0.85]), a)
		"thimble":
			_shape(_pts([-0.55, 0.8, -0.45, -0.3, -0.25, -0.65, 0.25, -0.65, 0.45, -0.3, 0.55, 0.8]), a)
			for k in 8:
				_dot(_p(-0.25 + 0.17 * (k % 4), -0.25 + 0.3 * (k / 4)), 0.05, b)
			_line(_p(-0.55, 0.65), _p(0.55, 0.65), 0.05, b)


## Flowers: a poppy, a daisy chain, a rose, a four-leaf clover, a lily pad.
func _bloom(a: Color, b: Color) -> void:
	match shape:
		"flower", "rose":
			_line(_p(0, 0.2), _p(0.05, 0.95), 0.06, LEAF.darkened(0.2))
			_shape(_pts([0.05, 0.6, 0.5, 0.35, 0.3, 0.75]), LEAF, false)
			for k in 5:
				var ang := TAU * k / 5.0 - PI / 2.0
				_shape(_ring(cos(ang) * 0.3, -0.3 + sin(ang) * 0.3, 0.3), a, k == 0)
			_shape(_ring(0, -0.3, 0.2), b if shape == "flower" else a.darkened(0.25), false)
		"daisies":
			for f in 3:
				var at := Vector2(-0.55 + 0.55 * f, -0.1 + 0.25 * (f % 2))
				for k in 6:
					var ang := TAU * k / 6.0
					_shape(_ring(at.x + cos(ang) * 0.17, at.y + sin(ang) * 0.17, 0.12), a, false)
				_shape(_ring(at.x, at.y, 0.1), b, false, false)
		"clover":
			for k in 4:
				var ang := TAU * k / 4.0 + PI / 4.0
				_shape(_ring(cos(ang) * 0.32, -0.2 + sin(ang) * 0.32, 0.3), a.lightened(0.05 * k))
			_line(_p(0, -0.2), _p(0.2, 0.95), 0.06, b)
		"pad":
			var pts := PackedVector2Array([_c])
			for k in 21:
				var ang := 0.35 + (TAU - 0.7) * k / 20.0
				pts.append(_p(cos(ang) * 0.85, sin(ang) * 0.6))
			_shape(pts, a)
			_shape(_ring(-0.2, -0.3, 0.22), b)
			_shape(_ring(-0.2, -0.35, 0.1), b.lightened(0.2), false, false)


## Hand tools with a handle: a scoop, a trowel, a honey dipper, a fruit picker, a peeler.
func _tool(a: Color, b: Color) -> void:
	match shape:
		"scoop":
			_stick(0.45, 0.85, 0.15, 0.25, 0.1, a.darkened(0.15) if a != WOOD else WOOD)
			_shape(_pts([-0.85, -0.35, 0.35, -0.75, 0.55, 0.0, -0.6, 0.35]), a)
			for k in 3:
				_dot(_p(-0.35 + 0.25 * k, -0.15 - 0.08 * k), 0.08, b)
		"trowel":
			_stick(0.45, 0.9, 0.2, 0.35, 0.1, b)
			_shape(_pts([0.25, 0.4, -0.55, -0.15, -0.6, -0.9, 0.0, -0.75, 0.4, -0.2]), a)
		"dipper":
			_stick(0.65, 0.9, 0.0, -0.15, 0.07, a)
			for k in 4:
				_shape(_ring(-0.15 - 0.08 * k, -0.25 - 0.15 * k, 0.28 - 0.03 * (k % 2), 0.55), a.lightened(0.05 * k))
			_shape(_ring(-0.35, -0.55, 0.12, 1.4), b, false, false)
		"picker":
			_stick(0.7, 0.95, -0.05, -0.2, 0.07, WOOD)
			_shape(_pts([-0.3, -0.25, 0.1, -0.25, 0.25, -0.9, -0.45, -0.9]), STEEL)
			for k in 4:
				_line(_p(-0.4 + 0.2 * k, -0.9), _p(-0.32 + 0.15 * k, -0.6), 0.03)
			_shape(_ring(-0.1, -0.55, 0.18), b, true, false)
		"peeler":
			_stick(0.55, 0.85, 0.1, 0.15, 0.13, b)
			_shape(_pts([0.15, 0.2, -0.65, -0.55, -0.55, -0.7, 0.3, 0.05]), a)
			_line(_p(-0.25, -0.25), _p(0.05, 0.0), 0.03)


## Things with a blade: a knife, a sickle, a saw, snips.
func _blade(a: Color, b: Color) -> void:
	match shape:
		"knife":
			_stick(0.45, 0.9, 0.15, 0.3, 0.12, b)
			_shape(_pts([0.2, 0.35, -0.65, -0.65, -0.35, -0.8, 0.35, 0.2]), a)
			_line(_p(-0.5, -0.7), _p(0.25, 0.25), 0.03, Color(1, 1, 1, 0.7))
		"sickle":
			_stick(0.1, 0.95, 0.05, 0.35, 0.11, b)
			draw_arc(_p(-0.1, -0.15), _r * 0.55, -PI * 0.1, PI * 0.95, 18, UiTheme.color("icon_outline"), maxf(3.0,
				_s * 0.2), true)
			draw_arc(_p(-0.1, -0.15), _r * 0.55, -PI * 0.1, PI * 0.95, 18, a, maxf(2.0, _s * 0.12), true)
		"saw":
			var pts := _pts([-0.85, -0.2, 0.45, -0.55, 0.45, 0.05, -0.85, 0.2])
			_shape(pts, a)
			for k in 8:
				var x := -0.8 + 0.16 * k
				draw_colored_polygon(_pts([x, 0.18 - 0.05 * k * 0.6, x + 0.08, 0.32 - 0.05 * k * 0.6, x + 0.16,
					0.15 - 0.05 * k * 0.6]), a.darkened(0.2))
			_shape(_pts([0.4, -0.65, 0.9, -0.75, 0.95, 0.15, 0.4, 0.15]), b)
			_shape(_ring(0.68, -0.25, 0.12), UiTheme.color("icon_light"), false, false)
		"shears":
			for k in 2:
				var side := -1.0 if k == 0 else 1.0
				_shape(_pts([0.0, 0.05, side * 0.15, -0.9, side * 0.3, -0.85, side * 0.12, 0.05]), a)
				_shape(_ring(side * 0.35, 0.55, 0.28), b)
				_shape(_ring(side * 0.35, 0.55, 0.13), UiTheme.color("icon_light"), false, false)
			_dot(_p(0, 0.05), 0.08, UiTheme.color("icon_outline"))
