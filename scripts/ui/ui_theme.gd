class_name UiTheme
extends RefCounted
## The interface's colours and sizes, by name, from data/ui_theme.json. The kit and the HUD ask here and keep no
## values of their own, so the whole look changes in one file.

const DATA := "res://data/ui_theme.json"

static var _data := {}


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


## A named size, in pixels at the 1280x720 design size (or a share, for those that are).
static func size(key: String) -> float:
	_load()
	var v: Variant = (_data.get("sizes", {}) as Dictionary).get(key)
	if v == null:
		push_error("ui_theme.json has no size '%s'" % key)
		return 0.0
	return float(v)


static func colors() -> Array:
	_load()
	return (_data.get("colors", {}) as Dictionary).keys()


static func sizes() -> Array:
	_load()
	return (_data.get("sizes", {}) as Dictionary).keys()
