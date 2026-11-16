class_name FloatText
extends RefCounted
## Words with no box (our own look, in the spirit of FarmVille's floating text): bold, white, a dark outline and a
## soft shadow, so they read on grass, sky or a building alike. Every word the game says over the farm uses it:
## the tap bubble, messages, reasons, rewards, the placing hint and the tutorial line. Things to do beside the
## words are small round icon buttons (`action`), never a button in a box.

const OUTLINE_SHARE := 0.28   # the outline's width against the text size
const SHADOW := Color(0, 0, 0, 0.45)
const SHADOW_DROP := 2        # px the shadow falls below the words
const BOLD := 0.7             # how much bolder than the plain font (FontVariation's embolden)
const RISE := 10.0            # px floating words rise as they come
const RISE_TIME := 0.25       # seconds they take to rise and fade in

static var _bold: FontVariation


## Gives `label` the floating look at `design_px` (UiTheme.font) in `colour` (white by default).
static func style(label: Label, design_px := 20, colour := Color(0, 0, 0, 0)) -> Label:
	var px := UiTheme.font(design_px)
	label.add_theme_font_override("font", bold())
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", colour if colour.a > 0.0 else UiTheme.color("float_text"))
	label.add_theme_color_override("font_outline_color", UiTheme.color("float_outline"))
	label.add_theme_constant_override("outline_size", maxi(3, int(px * OUTLINE_SHARE)))
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", SHADOW_DROP)
	label.add_theme_constant_override("shadow_outline_size", maxi(3, int(px * OUTLINE_SHARE)))
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	return label


## A new floating label with `words`.
static func label(words: String, design_px := 20, colour := Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = words
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return style(l, design_px, colour)


## A small round icon button for a thing to do beside floating words (Feed, Expand, more about it, Turn,
## Cancel): the picture says what; its name is on a long press.
static func action(icon_kind: String, words: String, side := 0.0) -> Button:
	var b := UiKit.icon_button(icon_kind, side if side > 0.0 else UiTheme.size("toggle_size"))
	UiKit.long_press_name(b, words)
	b.tooltip_text = words
	return b


## The plain font made bold, once.
static func bold() -> FontVariation:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = BOLD
	return _bold


## Floats `control` in: up from a little below where it ends and from clear to seen.
static func rise_in(control: Control) -> void:
	control.modulate.a = 0.0
	var t := control.create_tween().set_parallel()
	t.tween_property(control, "modulate:a", 1.0, RISE_TIME)
	if not control.get_parent() is Container:   # (a container places its children itself)
		var to := control.position
		control.position = to + Vector2(0, RISE)
		t.tween_property(control, "position", to, RISE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
