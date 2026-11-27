class_name Quality
extends RefCounted
## How good the farm looks against what it costs the phone: low, mid, high or ultra (data/quality.json; ultra
## offered on computers only), the player's choice kept in user://settings.cfg beside the sound settings. A
## phone starts on mid, a computer on high; until the player chooses, AutoQuality may move the device down a
## rung (`keep_measured`: a level and maybe a 30 fps cap) whenever frames stay slow. `apply` sets the 3D world
## to a level: shadows (splits, reach, map size), glow, anti-aliasing, the 3D resolution (the interface stays
## sharp), how soon models switch to their simpler levels, and how often animals are posed. Changing the level
## applies it at once (`notifier`).

const DATA := "res://data/quality.json"
const SECTION := "graphics"
const KEY := "quality"
const AUTO_KEY := "auto"   # the level AutoQuality measured for this device, while the player hasn't chosen
const AUTO_CAP_KEY := "auto_cap"   # and the frame cap it found the device needs (0: none beyond the level's)
const FPS_KEY := "fps"   # the frame rate the player picked in Settings (0: the level's own; 30 or 60)
const LEVELS: Array[String] = ["low", "mid", "high", "ultra"]
const AUTO_RULES: Array[String] = ["warmup", "frames", "max_frame_ms", "hold_ms", "down_ms", "up_ms",
	"up_on_mobile", "ladder", "slow_run", "steady_ratio"]
const COMPUTER_ONLY: Array[String] = ["ultra"]
const MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]

static var _data := {}
static var _level := ""   # the level in use, read from the settings file once
static var notifier := Signals.new()


## The level in use: the player's choice, else what this device measured on its first launch (AutoQuality),
## else the default for this kind of device. Read once.
static func level() -> String:
	if _level == "":
		var chosen := _kept(KEY)
		var measured_level := _kept(AUTO_KEY)
		_level = chosen if chosen != "" else measured_level if measured_level != "" else device_default()
	return _level


## The level a device starts on before anything is measured: a phone on `default_phone`, a low-end one (its
## graphics chip named in `low_end_gpus`, or less memory than `low_end_memory_mb`) on `low` (the A05s started on
## mid and ran at 3 to 4 frames a second until AutoQuality stepped it down), a computer on `default_computer`.
static func device_default() -> String:
	var data := _load()
	if not OS.has_feature("mobile"):
		return str(data.get("default_computer", "high"))
	if is_low_end(RenderingServer.get_video_adapter_name(), int(OS.get_memory_info().get("physical", 0)) / 1048576):
		return "low"
	return str(data.get("default_phone", "mid"))


## Whether a phone with graphics chip `gpu` and `memory_mb` of memory is low-end (data/quality.json).
static func is_low_end(gpu: String, memory_mb: int) -> bool:
	var data := _load()
	for name: String in data.get("low_end_gpus", []):
		if gpu.containsn(name):
			return true
	return memory_mb > 0 and memory_mb < int(data.get("low_end_memory_mb", 0))


## Picks a level, keeps it and applies it everywhere (the 3D world through `notifier`, the frame cap here).
static func choose(name: String) -> void:
	if not LEVELS.has(name):
		return
	PlayerSettings.keep(SECTION, {KEY: name})
	_level = name
	apply_frame_cap()
	notifier.emitted.emit()


## Whether the player has picked a level themselves (then nothing measures or moves it).
static func chosen_by_player() -> bool:
	return _kept(KEY) != ""


## Whether this device's first launch has been measured.
static func measured() -> bool:
	return _kept(AUTO_KEY) != ""


## Keeps `name` (and a frame cap, 0 for none) as what this device measured, and, while the player hasn't chosen,
## uses it at once: AutoQuality only ever steps down mid-session, so the picture gets lighter, never jumps up.
static func keep_measured(name: String, cap := 0) -> void:
	if not LEVELS.has(name):
		return
	PlayerSettings.keep(SECTION, {AUTO_KEY: name, AUTO_CAP_KEY: cap})
	if not chosen_by_player():
		_level = name
		apply_frame_cap()
		notifier.emitted.emit()


## The frame cap AutoQuality found this device needs (0: none), while the player hasn't chosen.
static func measured_cap() -> int:
	return 0 if chosen_by_player() else int(PlayerSettings.value(SECTION, AUTO_CAP_KEY, 0))


## The levels the player may pick on this device (ultra only on a computer).
static func offered() -> Array[String]:
	var out: Array[String] = []
	for name: String in LEVELS:
		if not (OS.has_feature("mobile") and COMPUTER_ONLY.has(name)):
			out.append(name)
	return out


## The level one step `by` from `name` (held at the ends).
static func step(name: String, by: int) -> String:
	return LEVELS[clampi(LEVELS.find(name) + by, 0, LEVELS.size() - 1)]


## The first-launch measurement's rules (data/quality.json `auto`), or {} when they are missing or incomplete.
static func auto_rules() -> Dictionary:
	var rules: Dictionary = _load().get("auto", {})
	for key: String in AUTO_RULES:
		if not rules.has(key):
			return {}
	return rules


## A level kept under `key` in the settings, or "".
static func _kept(key: String) -> String:
	var v := str(PlayerSettings.value(SECTION, key, ""))
	return v if LEVELS.has(v) else ""


## One setting of the level in use (or of `name`).
static func value(key: String, name := "") -> Variant:
	var levels: Dictionary = _load().get("levels", {})
	var lv: Dictionary = levels.get(name if name != "" else level(), levels.get("mid", {}))
	return lv.get(key)


## Sets a 3D world to the level in use: its sun's shadows, its glow, and its viewport's resolution and detail.
static func apply(sun: DirectionalLight3D, env: Environment, viewport: Viewport) -> void:
	sun.shadow_enabled = bool(value("shadows"))
	var splits := int(value("shadow_splits"))
	sun.directional_shadow_mode = (DirectionalLight3D.SHADOW_ORTHOGONAL if splits <= 1
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if splits == 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	RenderingServer.directional_shadow_atlas_set_size(int(value("shadow_size")), true)
	viewport.msaa_3d = MSAA[clampi(int(value("msaa")), 0, MSAA.size() - 1)]
	sun.directional_shadow_max_distance = float(value("shadow_distance"))
	env.glow_enabled = bool(value("glow"))
	# (Drawn smaller and brought up with AMD FSR 1 where the renderer has it, and never taller than the ceiling.)
	var up: Dictionary = _load().get("upscale", {})
	var high := float(viewport.size.y if viewport is Window else viewport.get_visible_rect().size.y)
	var scale := float(value("scale"))
	if high > 0.0 and float(up.get("max_3d_height", 0)) > 0.0:
		scale = minf(scale, float(up["max_3d_height"]) / high)
	var fsr := scale < 1.0 and RenderingServer.get_current_rendering_method() != "gl_compatibility"   # not-ui
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if fsr else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.fsr_sharpness = float(up.get("fsr_sharpness", 0.2))
	viewport.scaling_3d_scale = scale
	viewport.mesh_lod_threshold = float(value("lod_pixels"))


## The engine-wide frame cap: the level's, or the one AutoQuality found the device needs when that is lower (0:
## none; the screen's refresh still limits it). Set when the game starts and whenever the level or the cap
## changes, apart from any one 3D world.
static func apply_frame_cap() -> void:
	if fps_choice() > 0:   # (the player's own pick in Settings wins: smoother, or cooler and longer on battery)
		Engine.max_fps = fps_choice()
		return
	var caps := [int(value("max_fps")), measured_cap()].filter(func(c: int) -> bool: return c > 0)
	Engine.max_fps = caps.min() if not caps.is_empty() else 0


## The frame rate the player picked (Settings, apart from the graphics level, as big mobile games offer it): 0 for
## the level's own, or one of data/quality.json `fps_choices`.
static func fps_choice() -> int:
	return int(PlayerSettings.value(SECTION, FPS_KEY, 0))


static func fps_choices() -> Array[int]:
	var out: Array[int] = []
	for f: Variant in _load().get("fps_choices", [0, 30, 60]):
		out.append(int(f))
	return out


static func choose_fps(fps: int) -> void:
	PlayerSettings.keep(SECTION, {FPS_KEY: fps})
	apply_frame_cap()


static func _load() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed if parsed is Dictionary else {"levels": {}}
	return _data


## A holder for the `emitted` signal (a static class can't have signals of its own).
class Signals:
	extends RefCounted
	signal emitted
