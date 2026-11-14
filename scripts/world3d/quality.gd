class_name Quality
extends RefCounted
## How good the farm looks against what it costs the phone: low, mid or high (data/quality.json), the player's
## choice kept in user://settings.cfg beside the sound settings. A phone starts on mid, a computer on high.
## `apply` sets the 3D world to a level: shadows (and how many splits and how far), glow, the 3D resolution
## (the interface stays sharp), how soon models switch to their simpler levels, and how often animals are
## posed (every frame, or every other on low). Changing the level applies it at once (`notifier`).

const DATA := "res://data/quality.json"
const SETTINGS := "user://settings.cfg"
const SECTION := "graphics"
const KEY := "quality"
const LEVELS: Array[String] = ["low", "mid", "high"]

static var _data := {}
static var _level := ""   # the level in use, read from the settings file once
static var notifier := Signals.new()


## The level in use: the player's choice, or the default for this kind of device.
static func level() -> String:
	if _level != "":
		return _level
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		var chosen := str(cfg.get_value(SECTION, KEY, ""))
		if LEVELS.has(chosen):
			_level = chosen
			return _level
	var data := _load()
	_level = str(data.get("default_phone" if OS.has_feature("mobile") else "default_computer", "mid"))
	return _level


## Picks a level, keeps it and applies it everywhere.
static func choose(name: String) -> void:
	if not LEVELS.has(name):
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value(SECTION, KEY, name)
	cfg.save(SETTINGS)
	_level = name
	notifier.emitted.emit()


## One setting of the level in use (or of `name`).
static func value(key: String, name := "") -> Variant:
	var levels: Dictionary = _load().get("levels", {})
	var lv: Dictionary = levels.get(name if name != "" else level(), levels.get("mid", {}))
	return lv.get(key)


## Sets a 3D world to the level in use: its sun's shadows, its glow, and its viewport's resolution and detail.
static func apply(sun: DirectionalLight3D, env: Environment, viewport: Viewport) -> void:
	sun.shadow_enabled = bool(value("shadows"))
	sun.directional_shadow_mode = (DirectionalLight3D.SHADOW_ORTHOGONAL if int(value("shadow_splits")) <= 1
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	sun.directional_shadow_max_distance = float(value("shadow_distance"))
	env.glow_enabled = bool(value("glow"))
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = float(value("scale"))
	viewport.mesh_lod_threshold = float(value("lod_pixels"))


static func _load() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed if parsed is Dictionary else {"levels": {}}
	return _data


## A holder for the `emitted` signal (a static class can't have signals of its own).
class Signals:
	extends RefCounted
	signal emitted
