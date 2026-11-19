class_name UiTheme
extends RefCounted
## The interface's colours and sizes, by name, from data/ui_theme.json. The kit and the HUD ask here and keep no
## values of their own, so the whole look changes in one file. Sizes are drawn at `scale()`: the interface takes
## a set share of the screen (`scale.short_share` of its shorter side for a tool button) and never less than a
## comfortable touch on a phone (`scale.touch_mm`), so it is neither huge on a small screen nor tiny on a dense one.

const MIN_FONT := 14   # no text smaller than this many units..
const MIN_FONT_DP := 14.0   # ..nor, on a phone, than this many dp (Android's density-independent pixels)
## Where the smallest text lifts a size, each step of the type scale above body stays this many units above the
## one below, so a heading, title and display still read larger than body on a phone (all drew at the floor).
const TYPE_FLOOR_STEP := 2
const DATA := "res://data/ui_theme.json"

const BOLD := preload("res://fonts/Poppins-BoldTab.ttf")   # not-ui (its digits one width: tools/make_tabular_font.py)
## The type scale, design px: caption, body, heading, title, display (docs/UI.md).
const TYPE_SCALE: Array[float] = [12.0, 15.0, 18.0, 24.0, 32.0]
const CAPTION := 12   # the type scale by role (design px): small notes..
const BODY := 15      # ..panel words, buttons, rows..
const HEADING := 18   # ..a section's heading, a sheet's figures..
const TITLE := 24     # ..a panel's or sheet's title..
const DISPLAY := 32   # ..and a big moment (level up)
const SHORT_STEPS := [[1000000000, "B"], [1000000, "M"], [1000, "k"]]   # not-ui (the short forms' units)
const DIGITS := "(?<![\\w.,:/])\\d{1,3}(?:,\\d{3})+(?![\\w.,]?\\d)|(?<![\\w.,:/])\\d{4,}(?![\\w.]?\\d)"   # not-ui

static var _data := {}
static var _scale := 0.0   # worked out once (and again after a resize: `rescale`)
static var _digits: RegEx   # (tidy: whole numbers in digits)
static var _least := MIN_FONT   # the smallest text on this screen (`min_font`), worked out with the scale


static func _load() -> void:
	if not _data.is_empty():
		return
	_data = DataFile.read(DATA)
	if _data.is_empty():
		_data = {"colors": {}, "sizes": {}}


## A number as the game writes it everywhere (our own look, data/ui_theme.json "numbers"): in full below
## `short_from` ("950"), then short and rounded down so it never claims more than there is: "4.8k", "12.4k",
## "125k", "1.2M". Prices, pay, rewards, counts and messages all go through here (or `tidy`); only `exact` writes
## every digit, for the few places the exact figure matters.
static func number(n: int) -> String:
	_load()
	var rules: Dictionary = _data.get("numbers", {})
	var from := int(rules.get("short_from", 1000))
	var a := absi(n)
	if a < from:
		return exact(n)
	var out := ""
	for step: Array in SHORT_STEPS:
		if a >= int(step[0]):
			var v := float(a) / float(step[0])
			if v < float(rules.get("one_decimal_below", 100)):
				var tenth := floorf(v * 10.0) / 10.0
				out = (str(int(tenth)) if is_equal_approx(tenth, roundf(tenth)) else "%.1f" % tenth) + str(step[1])
			else:
				out = str(int(floorf(v))) + str(step[1])
			break
	return ("-" if n < 0 else "") + out


## Every digit, with commas ("12,450"): only where the exact figure matters (the player's own sums when asked).
static func exact(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## A change shown as a reward ("+250", "+4.8k", "-40").
static func signed(n: int) -> String:
	return ("+" if n >= 0 else "") + number(n)


## `text` with every whole number written in digits (12450, 12,450) written as `number` does ("12.4k"): the
## places that show the game's words (messages, the tap bubble, floating words, panel text, cards, buttons) pass
## their text through here, so a message made anywhere, now or later, writes its numbers the one way.
static func tidy(text: String) -> String:
	if text.length() < 4:
		return text
	if _digits == null:
		_digits = RegEx.create_from_string(DIGITS)
	var out := ""
	var at := 0
	for m in _digits.search_all(text):
		out += text.substr(at, m.get_start() - at) + number(int(m.get_string().replace(",", "")))
		at = m.get_end()
	return out + text.substr(at) if at > 0 else text


## The game's bold face (Poppins Bold with its digits one width, fonts/: numbers, prices, names that lead, floating
## words); the regular text
## is Poppins Medium, the project's own font (project.godot gui/theme/custom_font).
static func bold() -> Font:
	return BOLD


static func color(key: String) -> Color:
	_load()
	var hex: Variant = (_data.get("colors", {}) as Dictionary).get(key)
	if hex == null:
		push_error("ui_theme.json has no colour '%s'" % key)
		return Color.MAGENTA
	return Color.html(str(hex))


## A named size in pixels, at the interface's scale (or a share, for those named `*_share`, never scaled).
static func size(key: String) -> float:
	_load()
	var v: Variant = (_data.get("sizes", {}) as Dictionary).get(key)
	if v == null:
		push_error("ui_theme.json has no size '%s'" % key)
		return 0.0
	return float(v) if key.ends_with("_share") else float(v) * scale()


## A named size as designed, before the interface's scale (for passing on to something that scales it itself).
static func design(key: String) -> float:
	return size(key) / (1.0 if key.ends_with("_share") else maxf(scale(), 0.01))


## A panel text's design size `design_px` in pixels on this screen: at the interface's scale and `text_share`
## (panel text reads best a little smaller than its design size on a phone), never under MIN_FONT. Every panel,
## popup and strip of words sizes its text through this, once (a size from `size` is already scaled).
static func font(design_px: float) -> int:
	return font_for(on_scale(design_px), scale(), size("text_share"), min_font())


## `design_px` brought to the nearest step of the type scale (TYPE_SCALE: caption, body, heading, title, display),
## so every text in the game is one of a few sizes whatever size its code asked for.
static func on_scale(design_px: float) -> float:
	var best: float = TYPE_SCALE[0]
	for step: float in TYPE_SCALE:
		if absf(step - design_px) < absf(best - design_px):
			best = step
	return best


## `font`'s sum on its own: `design_px` at `ui_scale` and `share`, never under `least`, and a step of the type
## scale above body never under the step below it lifted (TYPE_FLOOR_STEP), so the hierarchy survives the floor.
static func font_for(design_px: float, ui_scale: float, share: float, least := MIN_FONT) -> int:
	var floor_px := least
	for step: float in TYPE_SCALE:
		if step > BODY and step <= design_px:
			floor_px += TYPE_FLOOR_STEP
	return maxi(int(round(design_px * ui_scale * share)), floor_px)


## A text size from the theme's sizes (`key`, already scaled), never under `min_font`: the one way the interface's
## own labels (bars, tools, tabs, badges) are sized, so nothing is too small to read.
static func text_px(key: String) -> int:
	return maxi(int(size(key)), min_font())


## The smallest text on this screen, in units: MIN_FONT, and on a phone never under MIN_FONT_DP.
static func min_font() -> int:
	scale()
	return _least


## How big the interface is drawn against its design sizes: a tool button `short_share` of the screen's shorter
## side, held between `least` and `most`, and on a phone never under `touch_mm` millimetres across. 1 without a
## screen (tests stay the same everywhere).
static func scale() -> float:
	if _scale > 0.0:
		return _scale
	_load()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or DisplayServer.get_name() == "headless":
		_scale = 1.0
		return _scale
	var rules: Dictionary = _data.get("scale", {})
	var view := tree.root.get_visible_rect().size
	var tool := float((_data.get("sizes", {}) as Dictionary).get("tool_size", 64))
	var px_per_unit := Vector2(DisplayServer.window_get_size()).y / maxf(view.y, 1.0)
	var dpi := float(DisplayServer.screen_get_dpi())
	_scale = scale_for(minf(view.x, view.y), tool, px_per_unit, dpi, OS.has_feature("mobile"), rules)
	_least = MIN_FONT
	if OS.has_feature("mobile") and dpi > 0.0:
		_least = maxi(MIN_FONT, ceili(MIN_FONT_DP * dpi / 160.0 / maxf(px_per_unit, 0.01)))
	return _scale


## The scale for a view whose shorter side is `short` units, a tool button `tool` units across, `px_per_unit`
## screen pixels a unit, a screen of `dpi` (pure: for tests).
static func scale_for(short: float, tool: float, px_per_unit: float, dpi: float, phone: bool,
		rules: Dictionary) -> float:
	var s := float(rules.get("short_share", 0.085)) * short / maxf(tool, 1.0)
	if phone and dpi > 0.0:
		var touch := float(rules.get("touch_mm", 8.0)) / 25.4 * dpi / maxf(tool * px_per_unit, 1.0)
		s = maxf(s, touch)
	return clampf(s, float(rules.get("least", 0.7)), float(rules.get("most", 1.2)))


## Works the scale out again (the window was resized or the phone turned).
static func rescale() -> void:
	_scale = 0.0


static func colors() -> Array:
	_load()
	return (_data.get("colors", {}) as Dictionary).keys()


static func sizes() -> Array:
	_load()
	return (_data.get("sizes", {}) as Dictionary).keys()
