class_name BookPanel
extends Control
## A full-screen overlay menu on the interface kit (UiKit): a dimmed backdrop, a wooden panel with its title on
## a plaque, a round close button, tabs when it has them (the Market's shelves), and scrolling content that a
## builder fills (and fills again on `refresh`). Every panel of the game opens in it.

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
var _tab_bar: HBoxContainer
var _tabs: Array = []          # [[name, builder]] of the panel open, or empty
var _tab := 0
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_backdrop_input)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)

	var panel := PanelContainer.new()
	_panel = panel
	var sb := UiKit.panel_box()
	sb.set_corner_radius_all(int(UiTheme.size("book_radius")))
	sb.set_border_width_all(int(UiTheme.size("book_border")))
	sb.set_content_margin_all(UiTheme.size("book_margin"))
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
	panel.add_child(col)

	# The title on a plaque in the middle, the close button at the right.
	var header := HBoxContainer.new()
	col.add_child(header)
	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(left)
	var plaque := UiKit.plaque("")
	_title = plaque.get_meta("label")
	_title.add_theme_font_size_override("font_size", int(UiTheme.size("font_book_title")))
	header.add_child(plaque)
	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(right)
	var close := UiKit.icon_button("cross", UiTheme.size("toggle_size"))
	close.tooltip_text = tr("CLOSE")
	close.pressed.connect(close_panel)
	right.add_child(close)

	# Tabs, when the panel has them.
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", int(UiTheme.size("hud_gap") * 0.6))
	_tab_bar.visible = false
	col.add_child(_tab_bar)

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, UiTheme.size("book_height"))
	col.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	scroll.add_child(_content)


## builder(content: VBoxContainer) fills the panel; it runs again on refresh().
func open_panel(title: String, builder: Callable) -> void:
	_tabs = []
	_show(title, builder)


## Opens a panel with tabs: `tabs` = [[name, builder]], `first` the one shown (FarmVille's Market shelves).
func open_tabs(title: String, tabs: Array, first := 0) -> void:
	_tabs = tabs
	_tab = clampi(first, 0, tabs.size() - 1)
	_show(title, tabs[_tab][1])


## Shows tab `index` of the panel open.
func show_tab(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		return
	_tab = index
	_builder = _tabs[index][1]
	_build_tab_bar()
	refresh()
	_scroll.scroll_vertical = 0


func _show(title: String, builder: Callable) -> void:
	_title.text = title
	_builder = builder
	# As wide as the theme says, narrower on small screens.
	_panel.custom_minimum_size.x = minf(UiTheme.size("book_width"), get_viewport_rect().size.x - 80.0)
	_build_tab_bar()
	refresh()
	visible = true
	Game.modal_open = true


func _build_tab_bar() -> void:
	for c in _tab_bar.get_children():
		c.queue_free()
	_tab_bar.visible = not _tabs.is_empty()
	for k in _tabs.size():
		var b := UiKit.tab_button(str(_tabs[k][0]), k == _tab)
		var index := k
		b.pressed.connect(func() -> void: show_tab(index))
		_tab_bar.add_child(b)


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
