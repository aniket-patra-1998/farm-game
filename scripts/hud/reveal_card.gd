class_name RevealCard
extends Control
## The reveal of a mystery opened from a panel (a Mystery Egg, the Mystery Box): over a dimmed screen the egg or
## the box shakes three times, each harder, bursts, and what was inside is named in the colours of how rare it
## is, with its sparks and its chime (Feedback.rarity: the same look every find has on the farm). A tap, or a
## moment's wait, closes it. Made once and kept. The prize is already given when this plays: it is the telling.

const EGGS := {"white": "#f6f1e4", "brown": "#b9814f", "red": "#c9553d", "grey": "#9aa0a8", "cornish": "#e6cf9a",
	"black": "#3a3640", "golden": "#f2c230"}   # an egg's shell, by its colour's name (data/mystery_eggs.json)
const BOX := "box"            # not-ui: the picture of the Mystery Box
const PICTURE := 150.0        # the mystery's size on screen, in pixels
const SHAKES := 3
const SHAKE_REACH := 9.0      # pixels the first shake goes to either side (each next one, as much again)
const STAY := 2.4             # seconds the prize stays if nobody taps

var _dim: ColorRect
var _picture: Control
var _title: Label
var _prize: Label
var _sparks: Control
var _tween: Tween
var _what := BOX              # which picture: BOX or an egg's colour name
var _open := false            # the prize is showing (a tap closes; before that a tap is ignored)


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.08, 0.05, 0.03, 0.72)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_title = _words(26, Color("#fbf6ea"))
	_title.offset_top = -PICTURE - 70
	var middle := Control.new()   # (the screen's middle: the picture shakes about it)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(middle)
	_picture = Control.new()
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.draw.connect(_draw_picture)
	middle.add_child(_picture)
	_sparks = Control.new()
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(_sparks)
	_prize = _words(40, Color.WHITE)
	_prize.offset_top = -30


## Plays the reveal of `what` (BOX, or an egg's colour name) called `title`: it opens to `prize`, in the colours
## of `rarity`.
func play(what: String, title: String, prize: String, rarity: String) -> void:
	var look := Feedback.rarity(rarity)
	_what = what
	_title.text = title
	_prize.text = prize
	_prize.add_theme_color_override("font_color", look["color"])
	_prize.add_theme_font_size_override("font_size", int(look["words"]) + 8)
	_prize.modulate.a = 0.0
	_prize.scale = Vector2(0.4, 0.4)
	_picture.modulate.a = 1.0
	_picture.scale = Vector2.ONE
	_picture.position = Vector2.ZERO
	_picture.queue_redraw()
	_open = false
	visible = true
	modulate.a = 0.0
	Game.modal_open = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	for k in SHAKES:
		var reach := SHAKE_REACH * (k + 1)
		_tween.tween_callback(func() -> void: Feedback.moment("reveal_shake"))
		_tween.tween_property(_picture, "position:x", reach, 0.05)
		_tween.tween_property(_picture, "position:x", -reach, 0.1)
		_tween.tween_property(_picture, "position:x", 0.0, 0.05)
		_tween.tween_interval(0.12)
	_tween.tween_property(_picture, "scale", Vector2(1.35, 1.35), 0.1).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_picture, "modulate:a", 0.0, 0.1)
	_tween.tween_callback(func() -> void:
		_open = true
		Feedback.moment("reveal_open")
		Feedback.moment(str(look["moment"]))
		_burst(look))
	_tween.tween_property(_prize, "modulate:a", 1.0, 0.12)
	_tween.parallel().tween_property(_prize, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	_tween.tween_interval(STAY)
	_tween.tween_callback(close)


func close() -> void:
	if not visible:
		return
	if _tween != null:
		_tween.kill()
	Game.modal_open = false
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	_tween.tween_callback(func() -> void: visible = false)


func _gui_input(event: InputEvent) -> void:
	var pressed := (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed()
	if _open and pressed:
		close()


func _words(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.custom_minimum_size = Vector2(900, 60)
	label.offset_left = -450
	label.offset_right = 450
	label.pivot_offset = Vector2(450, 30)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.16, 0.1, 0.05))
	label.add_theme_constant_override("outline_size", 10)
	add_child(label)
	return label


## The mystery itself: an egg in its shell's colour, or a wrapped box.
func _draw_picture() -> void:
	var r := PICTURE / 2.0
	if _what == BOX:
		var box := Rect2(-r * 0.8, -r * 0.55, r * 1.6, r * 1.3)
		_picture.draw_rect(box, Color("#c8452f"))
		_picture.draw_rect(Rect2(-r * 0.9, -r * 0.8, r * 1.8, r * 0.32), Color("#dd5a41"))
		_picture.draw_rect(Rect2(-r * 0.11, -r * 0.8, r * 0.22, r * 1.55), Color("#f2c230"))
		_picture.draw_circle(Vector2(-r * 0.2, -r * 0.92), r * 0.2, Color("#f2c230"))
		_picture.draw_circle(Vector2(r * 0.2, -r * 0.92), r * 0.2, Color("#f2c230"))
		return
	var shell := Color(str(EGGS.get(_what, EGGS["white"])))
	var points := PackedVector2Array()
	for k in 40:
		var a := TAU * k / 40.0
		# (an egg: narrower at the top than at the bottom)
		points.append(Vector2(cos(a) * r * (0.72 - 0.1 * sin(a) * -1.0), sin(a) * r * 0.95))
	_picture.draw_colored_polygon(points, shell)
	_picture.draw_circle(Vector2(-r * 0.25, -r * 0.35), r * 0.16, shell.lightened(0.5))


## The sparks of the opening, in the rarity's colour and number.
func _burst(look: Dictionary) -> void:
	var star := PackedVector2Array()
	for j in 8:
		star.append(Vector2.from_angle(TAU * j / 8.0) * (11.0 if j % 2 == 0 else 3.6) * float(look["size"]))
	var sparks := int(look["sparks"]) * 2
	for k in sparks:
		var dot := Polygon2D.new()
		dot.polygon = star
		dot.color = (look["color"] as Color).lerp(Color.WHITE, 0.35 if k % 3 == 0 else 0.0)
		_sparks.add_child(dot)
		var dir := Vector2.from_angle(TAU * (k + randf() * 0.6) / sparks) * float(look["reach"]) * randf_range(1.2, 2.6)
		var fly := dot.create_tween().set_parallel(true)
		fly.tween_property(dot, "position", dir, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		fly.tween_property(dot, "rotation", randf_range(-2.5, 2.5), 0.8)
		fly.tween_property(dot, "scale", Vector2(0.2, 0.2), 0.8).set_ease(Tween.EASE_IN)
		fly.tween_property(dot, "modulate:a", 0.0, 0.3).set_delay(0.5)
		fly.chain().tween_callback(dot.queue_free)
