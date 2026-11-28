class_name PortraitIcon
extends UiIcon
## A person's face: the farmer a player picks in Settings, and a neighbour's in their mail and on a goal (our own
## touch; on Facebook FarmVille showed your friends' photos). A look that names a `portrait` shows that picture
## (art/portraits, drawn by tools/make_portraits.py: soft light and shadow, a face of her own for each; the owner
## found the faces drawn here "too bad" and picked that style, 27 Nov). A look without one, such as a stranger
## the game has no picture of, is still drawn here in the icons' sticker style from its skin, hair in one of a few
## styles (short, long, bun, a cap, a straw hat), and shirt.

const STYLES: Array[String] = ["short", "long", "bun", "cap", "straw_hat"]
const HEAD_TOP := 0.68   # the top of the head, up from the middle (in the icon's units)
const PICTURES := "res://art/portraits/%s.png"   # a look's `portrait` -> its picture
const PICTURE_FILL := 0.96   # how much of the icon's box a picture fills

var look := {}
var picture: Texture2D   # the person's drawn picture, when the look names one


## The portrait for `face_look` ({skin, hair, style, shirt, and a `portrait` when she has a picture}) at `px`
## across.
static func of(face_look: Dictionary, px: float) -> PortraitIcon:
	var p := PortraitIcon.new()
	p.kind = "portrait"
	p.look = face_look
	p.picture = picture_of(face_look)
	if p.picture != null:   # a picture is shown much smaller than it is drawn
		p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## The picture `face_look` names, or null when it names none or the file is not there.
static func picture_of(face_look: Dictionary) -> Texture2D:
	var who := str(face_look.get("portrait", ""))
	if who == "" or not ResourceLoader.exists(PICTURES % who):
		return null
	return load(PICTURES % who) as Texture2D


func _col(key: String, otherwise: String) -> Color:
	return Color.html(str(look.get(key, otherwise)))


func _draw() -> void:
	_s = minf(size.x, size.y)
	if _s <= 0.0:
		return
	_c = size / 2.0
	_r = _s / 2.0 * 0.86
	if picture != null:
		var half := Vector2.ONE * _s / 2.0 * PICTURE_FILL
		draw_texture_rect(picture, Rect2(_c - half, half * 2.0), false)
		return
	_painted()


func _paint() -> void:
	var skin := _col("skin", "#f1c7a1")
	var hair := _col("hair", "#6b4423")
	var style := str(look.get("style", "short"))
	# The shoulders and collar.
	_shape(_pts([-0.85, 0.98, -0.7, 0.62, -0.25, 0.48, 0.25, 0.48, 0.7, 0.62, 0.85, 0.98]), _col("shirt", "#5c9a3e"))
	_shape(_pts([-0.22, 0.5, 0.0, 0.72, 0.22, 0.5]), UiTheme.color("icon_light"), false, false)
	if style == "long":   # hair falling behind the head to the shoulders
		_shape(_pts([-0.62, -0.2, -0.66, 0.55, -0.3, 0.6, 0.3, 0.6, 0.66, 0.55, 0.62, -0.2]), hair.darkened(0.12), false)
	_shape(_ring(0, -0.08, 0.55, 1.05), skin)   # the face
	for side: float in [-1.0, 1.0]:   # ears
		_shape(_ring(side * 0.56, -0.02, 0.1, 1.3), skin.darkened(0.05), false, false)
	match style:
		"cap":
			_shape(_cap(-0.3, 0.6), _col("shirt", "#c0392b").darkened(0.1))
			_shape(_pts([0.1, -0.36, 0.85, -0.3, 0.75, -0.2, 0.05, -0.24]), _col("shirt", "#c0392b").darkened(0.3), false)
		"straw_hat":
			_shape(_ring(0, -0.42, 0.95, 0.22), Color("#e7c66a"))
			_shape(_cap(-0.45, 0.48), Color("#e7c66a").darkened(0.05))
			_line(_p(-0.46, -0.5), _p(0.46, -0.5), 0.06, Color("#c0392b"))
		_:
			_shape(_cap(-0.28, 0.6), hair)
			if style == "bun":
				_shape(_ring(0, -0.92, 0.22), hair)
			if style == "short":   # a fringe
				_shape(_pts([-0.5, -0.4, -0.1, -0.22, 0.2, -0.38, 0.5, -0.3, 0.5, -0.5, -0.5, -0.5]), hair, false, false)
	for side: float in [-1.0, 1.0]:   # eyes with a glint, rosy cheeks
		_dot(_p(side * 0.2, -0.02), 0.075, UiTheme.color("icon_outline"))
		_dot(_p(side * 0.2 - 0.025, -0.05), 0.025, Color.WHITE)
		_dot(_p(side * 0.33, 0.18), 0.09, Color(0.95, 0.45, 0.45, 0.35))
	draw_arc(_p(0, 0.16), _r * 0.18, 0.35, PI - 0.35, 10, UiTheme.color("icon_outline"), maxf(1.2, _s * 0.035), true)


## The top of the head covered from `y` up (a cap of hair or a hat's crown), `w` wide.
func _cap(y: float, w: float) -> PackedVector2Array:
	var pts := PackedVector2Array()   # a half ellipse from the head's top (-0.68) down to `y`
	for k in 13:
		var a := PI + PI * k / 12.0
		pts.append(_p(cos(a) * w, y + sin(a) * (y + HEAD_TOP)))
	return pts
