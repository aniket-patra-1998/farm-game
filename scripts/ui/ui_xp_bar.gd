class_name UiXpBar
extends Control
## FarmVille's level meter: a dark bar with a white fill and the XP numbers on it, a gold star with the level
## sitting over its right end. Drawn in code from the theme.

## How full the bar is, 0 to 1.
@export var ratio := 0.0: set = _set_ratio
@export var level := 1: set = _set_level
## What is written on the bar (XP so far and to go).
@export var text := "": set = _set_text


static func make() -> UiXpBar:
	var bar := UiXpBar.new()
	bar.custom_minimum_size = Vector2(UiTheme.size("xp_bar_width") + UiTheme.size("star_size") * 0.4,
		UiTheme.size("star_size"))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


## Where the star's centre is (floating level-up effects fly to it).
func star_centre() -> Vector2:
	return Vector2(size.x - UiTheme.size("star_size") / 2.0, size.y / 2.0)


func _set_ratio(v: float) -> void:
	ratio = clampf(v, 0.0, 1.0)
	queue_redraw()


func _set_level(v: int) -> void:
	level = v
	queue_redraw()


func _set_text(v: String) -> void:
	text = v
	queue_redraw()


func _draw() -> void:
	var bar_h := UiTheme.size("xp_bar_height")
	var star_d := UiTheme.size("star_size")
	var radius := int(bar_h / 2.0)
	var rect := Rect2(0, (size.y - bar_h) / 2.0, size.x - star_d * 0.5, bar_h)
	var back := StyleBoxFlat.new()
	back.bg_color = UiTheme.color("xp_back")
	back.border_color = UiTheme.color("xp_edge")
	back.set_border_width_all(int(UiTheme.size("bar_border")))
	back.set_corner_radius_all(radius)
	draw_style_box(back, rect)
	var inner := rect.grow(-UiTheme.size("bar_border"))
	if ratio > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = UiTheme.color("xp_fill")
		fill.set_corner_radius_all(maxi(radius - 3, 1))
		draw_style_box(fill, Rect2(inner.position, Vector2(maxf(inner.size.x * ratio, inner.size.y), inner.size.y)))
	if text != "":
		var font := get_theme_default_font()
		var fs := int(UiTheme.size("font_xp"))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2(rect.position.x + (rect.size.x - w) / 2.0 - star_d * 0.2,
			rect.position.y + rect.size.y / 2.0 + fs * 0.35)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, UiTheme.color("xp_edge"))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.color("xp_text"))
	# The star over the right end, with the level on it.
	var c := star_centre()
	var pts := UiIcon.star_points(c + Vector2(0, 2), star_d * 0.52)
	draw_colored_polygon(pts, UiTheme.color("star"))
	draw_polyline(PackedVector2Array(Array(pts) + [pts[0]]), UiTheme.color("star_edge"), 3.0)
	var font2 := get_theme_default_font()
	var fs2 := int(UiTheme.size("font_star"))
	var label := str(level)
	var lw := font2.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	draw_string(font2, c + Vector2(-lw / 2.0, fs2 * 0.42), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2,
		UiTheme.color("star_text"))
