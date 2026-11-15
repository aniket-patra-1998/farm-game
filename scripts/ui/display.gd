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


## How far in from each edge (left, top, right, bottom) the interface must stay to clear a phone's notch, camera
## hole, rounded corners and gesture bar, in `viewport`'s own units (the stretch is taken into account). Zero on
## a computer or a screen with no cut-outs.
static func safe_insets(viewport: Viewport) -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if screen.x <= 0.0 or screen.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Vector4.ZERO
	return insets_for(screen, safe, viewport.get_visible_rect().size)


## The insets of a `safe` area on a `screen` of that size, in units of a view `view` across (pure: for tests).
static func insets_for(screen: Vector2, safe: Rect2, view: Vector2) -> Vector4:
	var k := view / screen
	return Vector4(maxf(safe.position.x, 0.0) * k.x, maxf(safe.position.y, 0.0) * k.y,
		maxf(screen.x - safe.end.x, 0.0) * k.x, maxf(screen.y - safe.end.y, 0.0) * k.y)
