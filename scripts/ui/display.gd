class_name Display
extends RefCounted
## The game's window on a computer: it opens maximised (a phone is always full screen), or full screen when the
## player chose that in Settings; the choice is kept in user://settings.cfg beside the sound and graphics ones.

const SETTINGS := "user://settings.cfg"
const SECTION := "display"
const KEY := "fullscreen"


## Whether this device has a window to size (a computer); a phone or a headless run has none.
static func has_window() -> bool:
	return not OS.has_feature("mobile") and DisplayServer.get_name() != "headless"


static func fullscreen() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SETTINGS) == OK and bool(cfg.get_value(SECTION, KEY, false))


## Keeps the choice and applies it.
static func set_fullscreen(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value(SECTION, KEY, on)
	cfg.save(SETTINGS)
	apply()


## Opens the window as the player wants it: full screen, or maximised.
static func apply() -> void:
	if not has_window():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen()
		else DisplayServer.WINDOW_MODE_MAXIMIZED)
