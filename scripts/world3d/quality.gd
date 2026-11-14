class_name Quality
extends RefCounted
## How good the farm looks against what it costs the phone: low, mid or high (data/quality.json), the player's
## choice kept in user://settings.cfg beside the sound settings. A phone starts on mid, a computer on high.
## `apply` sets the 3D world to a level: shadows (and how many splits and how far), glow, the 3D resolution
## (the interface stays sharp), how soon models switch to their simpler levels, and how often animals are
## posed (every frame, or every other on low). Changing the level applies it at once (`notifier`).

const DATA := "res://data/quality.json"
const SECTION := "graphics"
const KEY := "quality"
const AUTO_KEY := "auto"   # the level the first launch measured (AutoQuality), when the player hasn't chosen
const LEVELS: Array[String] = ["low", "mid", "high"]

static var _data := {}
static var _level := ""   # the level in use, read from the settings file once
static var notifier := Signals.new()


## The level in use: the player's choice, or the default for this kind of device.
static func level() -> String:
	if _level != "":
		return _level
	var chosen := str(PlayerSettings.value(SECTION, KEY, ""))
	if LEVELS.has(chosen):
		_level = chosen
		return _level
	var measured := str(PlayerSettings.value(SECTION, AUTO_KEY, ""))
	if LEVELS.has(measured):
		_level = measured
		return _level
	var data := _load()
	_level = str(data.get("default_phone" if OS.has_feature("mobile") else "default_computer", "mid"))
	return _level


## Picks a level, keeps it and applies it everywhere.
static func choose(name: String) -> void:
	if not LEVELS.has(name):
		return
	PlayerSettings.keep(SECTION, {KEY: name})
	_level = name
	notifier.emitted.emit()


## Whether the player has picked a level themselves (then nothing measures and moves it).
static func chosen_by_player() -> bool:
	return LEVELS.has(str(PlayerSettings.value(SECTION, KEY, "")))


## Whether the first launch's measurement has been made on this device.
static func measured() -> bool:
	return LEVELS.has(str(PlayerSettings.value(SECTION, AUTO_KEY, "")))


## Keeps `name` as what this device measured (not the player's choice) and applies it.
static func keep_measured(name: String) -> void:
	if not LEVELS.has(name):
		return
	PlayerSettings.keep(SECTION, {AUTO_KEY: name})
	if not chosen_by_player():
		_level = name
		notifier.emitted.emit()


## The level one step `by` from `name` (held at the ends).
static func step(name: String, by: int) -> String:
	return LEVELS[clampi(LEVELS.find(name) + by, 0, LEVELS.size() - 1)]


## The first-launch measurement's numbers (data/quality.json `auto`).
static func auto_rule(key: String) -> float:
	return float((_load().get("auto", {}) as Dictionary).get(key, 0.0))


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


## The engine-wide frame cap of the level in use (0: none; the screen's refresh still limits it). Set by the game
## when it starts and when the level changes, apart from any one 3D world.
static func apply_frame_cap() -> void:
	Engine.max_fps = int(value("max_fps"))


static func _load() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed if parsed is Dictionary else {"levels": {}}
	return _data


## A holder for the `emitted` signal (a static class can't have signals of its own).
class Signals:
	extends RefCounted
	signal emitted
