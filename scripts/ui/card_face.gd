class_name CardFace
extends BaseButton
## One card of a CardList, light enough for thousands of items: a single node that draws itself (its face, its
## picture with the passing shine, its mastery stars, its name, a line and its price badge), reused for whatever
## item scrolls into its place (`show_face`). Only the badge's coin, gem or lock is a child (the sticker icon).
## A face is a Dictionary: name, line (and line_colour, a theme colour), badge ([icon kind, words, short]) or bar
## ([share, words]: a pill filled that far) or neither, locked, stars ([earned, progress] or empty), long (words for
## a long press), buyable (kept as meta for tests and the panel). In the picture's place a card may show a ring
## (`ring`: [share, words], a collection's progress) or a sticker icon (`icon`: [kind, tint, faded], a ribbon).

const NAME_LINES := 2     # a long name wraps to at most this many lines
const SPACE := 2.0        # px between the parts of a card, top to bottom
const LOCKED_PICTURE := Color(1, 1, 1, 0.45)
const ICON_INSET := 8.0   # the badge's icon is this much smaller than the badge is high
const STARS_WIDE := 3.4   # the stars' width, in stars (MasteryStars)

static var _boxes := {}   # [face colour, state] -> the card's StyleBoxFlat, shared by every card
static var _badge: StyleBoxFlat
static var _gold: StyleBoxFlat   # a progress pill's fill

var id := ""
var face: Dictionary = {}
var picture: Texture2D

var _pic: RID        # the picture on its own canvas item, so only it wears the shine (UiFx.glint)
var _icon: UiIcon    # the badge's icon
var _big: UiIcon     # a sticker icon in the picture's place, made when a face first asks for one


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(UiTheme.size("card_width"), UiTheme.size("card_icon") + UiTheme.size("card_words"))
	size = custom_minimum_size
	_pic = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_pic, get_canvas_item())
	_icon = UiIcon.make("coin", UiTheme.size("badge_height") - ICON_INSET)
	_icon.visible = false
	add_child(_icon)
	UiFx.press_bounce(self)
	UiKit.long_press_name(self, "")
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		RenderingServer.free_rid(_pic)


## Shows item `new_id` with `new_face` and its `new_picture` on this card.
func show_face(new_id: String, new_face: Dictionary, new_picture: Texture2D) -> void:
	id = new_id
	face = new_face
	picture = new_picture
	tooltip_text = str(face.get("long", "")) if str(face.get("long", "")) != "" else str(face.get("name", ""))
	set_meta(&"buyable", bool(face.get("buyable", false)))
	var locked := bool(face.get("locked", false))
	RenderingServer.canvas_item_set_material(_pic, RID() if locked else UiFx.glint().get_rid())
	queue_redraw()


func _draw() -> void:
	var locked := bool(face.get("locked", false))
	var mode := get_draw_mode()
	var state := "pressed" if mode in [DRAW_PRESSED, DRAW_HOVER_PRESSED] else ("hover" if mode == DRAW_HOVER else "normal")
	draw_style_box(_box(locked, state), Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	var pad := UiTheme.size("card_pad")
	var inside := size.x - 2.0 * pad
	var pic_side := UiTheme.size("card_icon")
	var stars: Array = face.get("stars", [])
	var stars_high := UiTheme.size("mastery_star") + MasteryStars.BAR_GAP + UiTheme.size("mastery_bar")
	var name_px := UiTheme.text_px("font_card")
	var line_px := UiTheme.text_px("font_card_small")
	var name := str(face.get("name", ""))
	var line := str(face.get("line", ""))
	var name_high := font.get_multiline_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, inside, name_px, NAME_LINES).y
	var badge_high := UiTheme.size("badge_height") if face.has("badge") or face.has("bar") else 0.0
	var total := pic_side + SPACE + name_high + SPACE + badge_high
	total += (SPACE + stars_high) if not stars.is_empty() else 0.0
	total += (SPACE + font.get_height(line_px)) if line != "" else 0.0
	var y := maxf(pad, (size.y - total) / 2.0)
	# The picture, on its own canvas item (the shine).
	RenderingServer.canvas_item_clear(_pic)
	var spot := Rect2((size.x - pic_side) / 2.0, y, pic_side, pic_side)
	if _big != null:
		_big.visible = face.has("icon")
	if face.has("ring"):
		BuildingSheet.Ring.paint(self, spot, float(face["ring"][0]), str(face["ring"][1]), font)
	elif face.has("icon"):
		_show_big(spot)
	elif picture != null:
		RenderingServer.canvas_item_add_texture_rect(_pic, spot, picture.get_rid(), false,
			LOCKED_PICTURE if locked else Color.WHITE)
	y += pic_side + SPACE
	if not stars.is_empty():
		var wide := UiTheme.size("mastery_star") * STARS_WIDE
		MasteryStars.paint(self, Rect2((size.x - wide) / 2.0, y, wide, stars_high), int(stars[0]), float(stars[1]))
		y += stars_high + SPACE
	draw_multiline_string(font, Vector2(pad, y + font.get_ascent(name_px)), name, HORIZONTAL_ALIGNMENT_CENTER, inside,
		name_px, NAME_LINES, UiTheme.color("ink"))
	y += name_high + SPACE
	if line != "":
		draw_string(font, Vector2(pad, y + font.get_ascent(line_px)), line, HORIZONTAL_ALIGNMENT_CENTER, inside, line_px,
			_colour(face.get("line_colour", "tool_label")))
		y += font.get_height(line_px) + SPACE
	_icon.visible = false
	if face.has("bar"):
		_draw_bar(font, y)
	elif face.has("badge"):
		_draw_badge(font, y)


## The sticker icon in the picture's place (a ribbon's medal in its tier's colour, faded while still to win).
func _show_big(spot: Rect2) -> void:
	if _big == null:
		_big = UiIcon.make("ribbon", spot.size.x)
		add_child(_big)
	var icon: Array = face["icon"]
	_big.visible = true
	_big.kind = str(icon[0])
	_big.tint = icon[1] if icon.size() > 1 else Color(0, 0, 0, 0)
	_big.modulate.a = LOCKED_PICTURE.a if icon.size() > 2 and bool(icon[2]) else 1.0
	_big.position = spot.position
	_big.size = spot.size


## A progress pill where the badge goes: filled `share` of the way, its words in the middle ("12 / 25").
func _draw_bar(font: Font, y: float) -> void:
	var bar: Array = face["bar"]
	var px := UiTheme.text_px("font_badge")
	var rect := Rect2(UiTheme.size("card_pad"), y, size.x - 2.0 * UiTheme.size("card_pad"), UiTheme.size("badge_height"))
	draw_style_box(_badge_box(), rect)
	var share := clampf(float(bar[0]), 0.0, 1.0)
	if share > 0.0:
		if _gold == null:
			_gold = _badge_box().duplicate() as StyleBoxFlat
			_gold.bg_color = UiTheme.color("mastery_gold")
		draw_style_box(_gold, Rect2(rect.position, Vector2(maxf(rect.size.y, rect.size.x * share), rect.size.y)))
	var words := str(bar[1])
	var w := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, Vector2(rect.get_center().x - w / 2.0, y + (rect.size.y - font.get_height(px)) / 2.0
		+ font.get_ascent(px)), words, HORIZONTAL_ALIGNMENT_LEFT, -1, px, UiTheme.color("ink"))


## The price badge: a pill with the coin, gem or lock and the words (red when there isn't enough).
func _draw_badge(font: Font, y: float) -> void:
	var badge: Array = face.get("badge", ["", ""])
	var kind := str(badge[0])
	var words := str(badge[1])
	var short := badge.size() > 2 and bool(badge[2])
	var px := UiTheme.text_px("font_badge")
	var high := UiTheme.size("badge_height")
	var icon_side := high - ICON_INSET if kind != "" else 0.0
	var gap := UiTheme.size("badge_border") * 2.0 if kind != "" else 0.0
	var words_wide := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var wide := minf(size.x, 2.0 * UiTheme.size("badge_pad") + icon_side + gap + words_wide)
	var rect := Rect2((size.x - wide) / 2.0, y, wide, high)
	draw_style_box(_badge_box(), rect)
	var x := rect.position.x + UiTheme.size("badge_pad")
	_icon.visible = kind != ""
	if kind != "":
		_icon.kind = kind
		_icon.position = Vector2(x, y + (high - icon_side) / 2.0)
		_icon.size = Vector2.ONE * icon_side
		x += icon_side + gap
	var base := y + (high - font.get_height(px)) / 2.0 + font.get_ascent(px)
	draw_string(font, Vector2(x, base), words, HORIZONTAL_ALIGNMENT_LEFT, rect.end.x - x, px,
		UiTheme.color("price_short" if short else "ink"))


## A colour given as a Color or a theme colour's name.
static func _colour(c: Variant) -> Color:
	return c if c is Color else UiTheme.color(str(c))


static func _box(locked: bool, state: String) -> StyleBoxFlat:
	var key := "%s/%s" % [locked, state]
	if not _boxes.has(key):
		var face := UiTheme.color("card_locked" if locked else "card_face")
		var sb := UiKit.card_box("card_locked" if locked else "card_face")
		sb.bg_color = face.lightened(0.15) if state == "hover" else (UiTheme.color("tool_face_on") if state == "pressed"
			else face)
		_boxes[key] = sb
	return _boxes[key]


static func _badge_box() -> StyleBoxFlat:
	if _badge == null:
		_badge = StyleBoxFlat.new()
		_badge.bg_color = UiTheme.color("badge_face")
		_badge.border_color = UiTheme.color("card_edge")
		_badge.set_border_width_all(int(UiTheme.size("badge_border")))
		_badge.set_corner_radius_all(int(UiTheme.size("badge_height") / 2.0))
	return _badge
