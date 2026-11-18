class_name LevelUpPopup
extends Control
## Full-screen level-up celebration: confetti, the new level in big type,
## the coin reward and everything that just unlocked. Levels reached together queue up.

const WOOD := Color("#7a4f2c")
const WOOD_DARK := Color("#5c3a1e")
const CREAM := Color("#fbefd2")
const INK := Color("#3a2614")
const SUN := Color("#ffd34d")
const CONFETTI := [
	Color("#ffd34d"),
	Color("#ff6b6b"),
	Color("#7ccf5a"),
	Color("#5bc0eb"),
	Color("#ff9ad5"),
	Color("#fbefd2")
]

var _queue: Array[int] = []
var _card: PanelContainer
var _level_label: Label
var _reward_label: Label
var _unlocks: HFlowContainer
var _unlock_title: Label
var _confetti_layer: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD
	sb.border_color = SUN
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(32)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 12
	_card.add_theme_stylebox_override("panel", sb)
	center.add_child(_card)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(UiTheme.size("section_gap")))
	_card.add_child(col)

	var eyebrow := _label(tr("LEVEL_UP"), 28, CREAM)
	col.add_child(eyebrow)

	_level_label = _label("", 96, SUN)
	_level_label.add_theme_color_override("font_outline_color", WOOD_DARK)
	_level_label.add_theme_constant_override("outline_size", 14)
	col.add_child(_level_label)

	_reward_label = _label("", 30, CREAM)
	col.add_child(_reward_label)

	_unlock_title = _label(tr("NEW_IN_THE_MARKET"), 22, SUN)
	col.add_child(_unlock_title)

	_unlocks = HFlowContainer.new()
	_unlocks.alignment = FlowContainer.ALIGNMENT_CENTER
	_unlocks.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap")))
	_unlocks.add_theme_constant_override("v_separation", int(UiTheme.size("hud_gap")))
	col.add_child(_unlocks)

	var go := Button.new()
	go.text = tr("KEEP_FARMING")
	go.custom_minimum_size = Vector2(260, 64)
	go.focus_mode = Control.FOCUS_NONE
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.add_theme_font_size_override("font_size", UiTheme.font(26))
	go.pressed.connect(_next)
	col.add_child(go)

	_confetti_layer = Control.new()
	_confetti_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confetti_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_confetti_layer)


func celebrate(lvl: int) -> void:
	_queue.append(lvl)
	if not visible:
		_show(_queue.pop_front())


func _show(lvl: int) -> void:
	visible = true
	Game.modal_open = true
	_level_label.text = str(lvl)
	_reward_label.text = tr("COINS_GEM") % [Game.level_reward(lvl), Balance.i("economy.gems_per_level")]
	for child in _unlocks.get_children():
		child.queue_free()
	# What's new, as pictures (its name on a long press): the pictures say it faster than a list of names.
	var ids := Game.unlock_ids_at(lvl)
	_unlock_title.visible = not ids.is_empty()
	for id in ids:
		_unlocks.add_child(_picture(id))
	_card.custom_minimum_size.x = minf(620.0, get_viewport_rect().size.x - 64.0)
	_pop_in()
	_burst_confetti()


func _picture(id: String) -> Control:
	var pic := TextureRect.new()
	pic.texture = ItemIcons.of(id)
	pic.custom_minimum_size = Vector2.ONE * UiTheme.size("unlock_picture")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var it: Dictionary = Game.item_data(id) if not Game.crops.has(id) else Game.crops[id]
	pic.tooltip_text = str(it.get("name", id))
	return pic


func _next() -> void:
	if _queue.is_empty():
		visible = false
		Game.modal_open = false
	else:
		_show(_queue.pop_front())


## The card swells open like every panel (UiFx.open) and the new level swells once as it lands: the confetti is
## the celebration, nothing else bounces.
func _pop_in() -> void:
	UiFx.open(_card)
	_level_label.pivot_offset = _level_label.size / 2.0
	var land := create_tween()
	land.tween_interval(UiFx.OPEN_TIME * 0.6)
	land.tween_callback(func() -> void: UiFx.pulse(_level_label))


func _burst_confetti() -> void:
	var view := get_viewport_rect().size
	for k in 90:
		var piece := ColorRect.new()
		piece.color = CONFETTI[k % CONFETTI.size()]
		piece.size = Vector2(randf_range(8, 16), randf_range(12, 22))
		piece.pivot_offset = piece.size / 2.0
		piece.position = Vector2(randf_range(0, view.x), randf_range(-view.y * 0.4, -20))
		piece.rotation = randf_range(0, TAU)
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_confetti_layer.add_child(piece)
		var fall := randf_range(1.8, 3.2)
		var t := piece.create_tween().set_parallel(true)
		t.tween_property(piece, "position:y", view.y + 40, fall).set_delay(randf_range(0, 0.6)).set_ease(Tween.EASE_IN)
		t.tween_property(piece, "position:x", piece.position.x + randf_range(-120, 120), fall)
		t.tween_property(piece, "rotation", piece.rotation + randf_range(-8, 8), fall)
		t.chain().tween_callback(piece.queue_free)


func _label(words: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = words
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UiTheme.font(size))
	l.add_theme_color_override("font_color", color)
	return l


