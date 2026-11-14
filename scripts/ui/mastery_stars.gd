class_name MasteryStars
extends Control
## An item's mastery as FarmVille showed it on its card: three stars, gold for each one earned, and a thin bar
## of the way to the next (full and gold once all three are earned). Drawn, so it is crisp at any size and needs
## no font glyph. Reads Game.mastery when built (`of`); nothing for an item that can't be mastered.

const STAR_INNER := 0.45   # a star's inner points, of its outer radius
const BAR_GAP := 3.0       # between the stars and the bar, in pixels

var earned := 0
var progress := 0.0        # of the way to the next star (1 when all are earned)


## The stars of `id`, or null when it can't be mastered.
static func of(id: String) -> MasteryStars:
	if not Game.mastery.masterable(id):
		return null
	var m := MasteryStars.new()
	m.earned = Game.mastery.stars(id)
	m.progress = Game.mastery.progress(id)
	m.tooltip_text = TranslationServer.translate("MASTERY_PROGRESS") % [m.earned, Game.mastery.points_of(id),
		Game.mastery.next_need(id)] if m.earned < 3 else TranslationServer.translate("MASTERED")
	m.custom_minimum_size = Vector2(UiTheme.size("mastery_star") * 3.4, UiTheme.size("mastery_star") + BAR_GAP
		+ UiTheme.size("mastery_bar"))
	m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	return m


func _draw() -> void:
	var r := UiTheme.size("mastery_star") / 2.0
	var gold := UiTheme.color("mastery_gold")
	var empty := UiTheme.color("mastery_empty")
	var edge := UiTheme.color("card_edge")
	var step := size.x / 3.0
	for k in 3:
		var c := Vector2(step * (k + 0.5), r)
		var pts := PackedVector2Array()
		for p in 10:
			var a := -PI / 2.0 + p * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * (r if p % 2 == 0 else r * STAR_INNER))
		draw_colored_polygon(pts, gold if k < earned else empty)
		pts.append(pts[0])
		draw_polyline(pts, edge, 1.2, true)
	var bar := Rect2(0, r * 2.0 + BAR_GAP, size.x, UiTheme.size("mastery_bar"))
	draw_rect(bar, empty)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(progress, 0.0, 1.0), bar.size.y)), gold)
