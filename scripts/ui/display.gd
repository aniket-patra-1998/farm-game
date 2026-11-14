class_name Display
extends RefCounted
## The game's window on a computer: it opens maximised (project.godot's window mode, so it never shows small
## first; a phone is always full screen), or full screen when the player chose that in Settings (PlayerSettings).

const SECTION := "display"
const KEY := "fullscreen"


## Whether this device has a window to size (a computer); a phone or a headless run has none.
static func has_window() -> bool:
	return not OS.has_feature("mobile") and DisplayServer.get_name() != "headless"


static func fullscreen() -> bool:
	return bool(PlayerSettings.value(SECTION, KEY, false))


## Keeps the choice and applies it.
static func set_fullscreen(on: bool) -> void:
	PlayerSettings.keep(SECTION, {KEY: on})
	apply()


## The window mode for the player's choice.
static func mode() -> DisplayServer.WindowMode:
	return DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen() else DisplayServer.WINDOW_MODE_MAXIMIZED


## Opens the window as the player wants it: full screen, or maximised.
static func apply() -> void:
	if has_window() and DisplayServer.window_get_mode() != mode():
		DisplayServer.window_set_mode(mode())
