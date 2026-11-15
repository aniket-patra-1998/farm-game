class_name UiTheme
extends RefCounted
## The interface's colours and sizes, by name, from data/ui_theme.json. The kit and the HUD ask here and keep no
## values of their own, so the whole look changes in one file. Sizes are drawn at `scale()`: the interface takes
## a set share of the screen (`scale.short_share` of its shorter side for a tool button) and never less than a
## comfortable touch on a phone (`scale.touch_mm`), so it is neither huge on a small screen nor tiny on a dense one.

const DATA := "res://data/ui_theme.json"

static var _data := {}
static var _scale := 0.0   # worked out once (and again after a resize: `rescale`)


static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if parsed is Dictionary:
		_data = parsed
	else:
		push_error(DATA + " is missing or not valid JSON")
		_data = {"colors": {}, "sizes": {}}


## A named colour (magenta, loudly, when the name is not in the data).
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
	_scale = scale_for(minf(view.x, view.y), tool, Vector2(DisplayServer.window_get_size()).y / maxf(view.y, 1.0),
		float(DisplayServer.screen_get_dpi()), OS.has_feature("mobile"), rules)
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
