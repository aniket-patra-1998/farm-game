class_name ProgressRing
extends Control
## How far along a home is, as a ring that fills (a building's sheet; CardFace and the goal faces draw one with
## `paint`). Its own file, not BuildingSheet's inner class, so the cards and goal faces drawn on the first screen
## do not compile the whole sheet before it (docs/PERF_RUN.md, the start).

var share := 0.0: set = _set_share
var words := "": set = _set_words   # the time left, written in the middle


func _set_share(value: float) -> void:
	share = value
	queue_redraw()


func _set_words(value: String) -> void:
	if value != words:
		words = value
		queue_redraw()


func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), share, words, get_theme_default_font())


## Draws a ring `share` full with `words` in the middle on `on`, inside `rect` (a CardFace draws one itself).
static func paint(on: CanvasItem, rect: Rect2, filled: float, middle: String, font: Font) -> void:
	var r := minf(rect.size.x, rect.size.y) / 2.0 - 4.0
	var c := rect.get_center()
	on.draw_arc(c, r, 0.0, TAU, 40, UiTheme.color("track"), 6.0, true)
	if filled > 0.0:
		on.draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * filled, 40, UiTheme.color("accent"), 6.0, true)
	if middle != "":
		var px := UiTheme.min_font()
		var w := font.get_string_size(middle, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		on.draw_string(font, c + Vector2(-w / 2.0, px * 0.35), middle, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
			UiTheme.color("ink"))
