class_name BookPanel
extends Control
## A full-screen overlay menu: a dimmed backdrop and a wooden panel with a title,
## a close button and scrolling content. Used for Collections and Ribbons.

const WOOD := Color("#7a4f2c")
const WOOD_DARK := Color("#5c3a1e")
const CREAM := Color("#fbefd2")
const INK := Color("#3a2614")
const SUN := Color("#ffd34d")
const MUTED := Color("#c9b48f")
const GOOD := Color("#7ccf5a")

var _title: Label
var _panel: PanelContainer
var _content: VBoxContainer
var _builder: Callable


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_backdrop_input)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)

	var panel := PanelContainer.new()
	_panel = panel
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD
	sb.border_color = WOOD_DARK
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", SUN)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(120, 56)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_panel)
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 460)
	col.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	scroll.add_child(_content)


## builder(content: VBoxContainer) fills the panel; it runs again on refresh().
func open_panel(title: String, builder: Callable) -> void:
	_title.text = title
	_builder = builder
	# Up to 760 wide, narrower on portrait phones.
	_panel.custom_minimum_size.x = minf(760.0, get_viewport_rect().size.x - 80.0)
	refresh()
	visible = true
	Game.modal_open = true


func close_panel() -> void:
	visible = false
	Game.modal_open = false


func refresh() -> void:
	if not _builder.is_valid():
		return
	for child in _content.get_children():
		child.queue_free()
	_builder.call(_content)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_panel()


# ---------------------------------------------------------------- helpers for builders

static func card() -> VBoxContainer:
	return VBoxContainer.new()


static func card_frame(inner: Control) -> PanelContainer:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.border_color = WOOD_DARK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(16)
	frame.add_theme_stylebox_override("panel", sb)
	frame.add_child(inner)
	return frame


static func text(words: String, font_size := 22, color := INK) -> Label:
	var l := Label.new()
	l.text = words
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func chip(words: String, filled: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = SUN if filled else Color(0, 0, 0, 0)
	sb.border_color = WOOD_DARK if filled else MUTED
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = words
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", INK if filled else MUTED.darkened(0.25))
	p.add_child(l)
	return p
