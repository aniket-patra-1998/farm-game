class_name BookPanel
extends Control
## A full-screen overlay menu on the interface kit (UiKit): a dimmed backdrop, a wooden panel with its title on
## a plaque, a round close button, tabs when it has them (the Market's shelves), and scrolling content that a
## builder fills. Each tab's page is built once while the panel is open (going back to a tab shows it again); `refresh`
## builds the page again, or, when its builder marked it live (`set_live`), only updates it in place (a CardList
## reads its faces again). Every panel of the game opens in it.

const WOOD := Color("#7a4f2c")
const WOOD_DARK := Color("#5c3a1e")
const CREAM := Color("#fbefd2")
const INK := Color("#3a2614")
const SUN := Color("#ffd34d")
const MUTED := Color("#c9b48f")
const GOOD := Color("#7ccf5a")
## The panel uses the screen (a phone's 20:9 especially): its scrolling area is this share of the screen's
## height, and it is as wide as the screen allows up to this many times the screen's height.
const HEIGHT_SHARE := 0.66
const INFO_SIZE := 1.6   # an ⓘ's size against the text beside it
const INFO_LEAST := 40.0   # ..and never smaller than this (a finger must hit it)
const WIDEST := 2.0
const SECTION_LINE := 1.0   # px of the thin line under a section (card_frame)
const SECTION_PAD := 10.0   # px above and below a section's content

var _title: Label
var _panel: PanelContainer
var _content: VBoxContainer
var _builder: Callable
var _tab_bar: HBoxContainer
var _tabs: Array = []          # [[name, builder]] of the panel open, or empty
var _tab := 0
var _scroll: ScrollContainer
var _refresh_due := false   # a refresh is waiting for the end of the frame
var _pages := {}            # tab -> its page (a VBoxContainer in the content), built once while the panel is open
var _stale := {}            # tabs whose live page missed a refresh while hidden


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
	_title.add_theme_font_size_override("font_size", UiTheme.text_px("font_book_title"))
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
	get_viewport().size_changed.connect(_on_screen_changed)


## The screen turned or changed size: the panel takes the new width and its grids lay out again.
func _on_screen_changed() -> void:
	if visible:
		_fit_screen()
		_clear_pages()
		_build_now()


## Sizes the panel to the screen: nearly its full height and as wide as it allows (never under the theme's
## design size where the screen has room for it), so a shelf shows more than two rows.
func _fit_screen() -> void:
	var view := get_viewport_rect().size
	_panel.custom_minimum_size.x = width_for(view.x, view.y)
	_scroll.custom_minimum_size.y = view.y * HEIGHT_SHARE


## How wide a panel is on a screen `view_w` across (and `view_h` high: the screen's own when not given): as wide
## as the screen allows up to WIDEST times its height, never under the theme's design width where it fits.
static func width_for(view_w: float, view_h := -1.0) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var h := view_h if view_h > 0.0 else (tree.root.get_visible_rect().size.y if tree != null else view_w / WIDEST)
	return minf(maxf(UiTheme.size("book_width"), h * WIDEST), view_w - UiTheme.size("book_inset"))


## builder(content: VBoxContainer) fills the panel; it runs again on refresh().
func open_panel(title: String, builder: Callable) -> void:
	_tabs = []
	_tab = 0
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
	_show_page()
	_scroll.scroll_vertical = 0


func _show(title: String, builder: Callable) -> void:
	_title.text = title
	_builder = builder
	_fit_screen()
	_build_tab_bar()
	UiFx.pop_next = not visible   # (a panel opening pops its cards in; a tab or a refresh doesn't)
	UiFx.popped = 0
	_clear_pages()
	_build_now()
	UiFx.pop_next = false
	if not visible:
		UiFx.open.call_deferred(_panel)   # (once it has its size)
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


func scroll_to_top() -> void:
	_scroll.scroll_vertical = 0


func close_panel() -> void:
	visible = false
	Game.modal_open = false


func refresh() -> void:
	# Once a frame at most, at its end: many changes in a row (Accept all) rebuild the panel once.
	if not _refresh_due:
		_refresh_due = true
		_build_again.call_deferred()


func _build_again() -> void:
	_refresh_due = false
	if not visible:
		return
	for k: int in _pages.keys():   # (the hidden pages: a live one updates when shown again, others are rebuilt)
		if k != _tab:
			if (_pages[k] as Node).has_meta(&"live"):
				_stale[k] = true
			else:
				(_pages[k] as Node).queue_free()
				_pages.erase(k)
	var shown := page()
	if shown != null and shown.has_meta(&"live"):
		(shown.get_meta(&"live") as Callable).call()
	else:
		_build_now()


## Marks `on_page` live: a refresh calls `update` (which updates it in place) instead of building it again.
static func set_live(on_page: Control, update: Callable) -> void:
	on_page.set_meta(&"live", update)


## The page shown now (the content of the tab open).
func page() -> VBoxContainer:
	return _pages.get(_tab)


## Builds the page of the tab open afresh.
func _build_now() -> void:
	if not _builder.is_valid():
		return
	if _pages.has(_tab):
		(_pages[_tab] as Node).queue_free()
	var fresh := VBoxContainer.new()
	fresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fresh.add_theme_constant_override("separation", 14)
	_content.add_child(fresh)
	_pages[_tab] = fresh
	_stale.erase(_tab)
	_builder.call(fresh)


## Shows the tab open's page, building it the first time.
func _show_page() -> void:
	for k: int in _pages:
		(_pages[k] as Control).visible = k == _tab
	if not _pages.has(_tab):
		_build_now()
	elif _stale.has(_tab):
		_stale.erase(_tab)
		(page().get_meta(&"live") as Callable).call()


func _clear_pages() -> void:
	for child in _content.get_children():
		child.queue_free()
	_pages.clear()
	_stale.clear()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_panel()


# ---------------------------------------------------------------- helpers for builders

static func card() -> VBoxContainer:
	return VBoxContainer.new()


## A section of a panel: flat on the wood, no box round it, a thin line under it (our own look: fewer boxes in
## boxes). The dark words inside turn cream so they read on the wood (words on a card or a button inside keep
## theirs); words added later should be cream already.
static func card_frame(inner: Control) -> PanelContainer:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = UiTheme.color("divider")
	sb.border_width_bottom = int(SECTION_LINE)
	sb.content_margin_top = SECTION_PAD
	sb.content_margin_bottom = SECTION_PAD
	frame.add_theme_stylebox_override("panel", sb)
	frame.add_child(inner)
	on_wood(inner)
	return frame


## Turns the dark words in `node` (not those on a card, button or tile of their own) cream, for the wood.
static func on_wood(node: Node) -> void:
	if node is Label and (node as Label).get_theme_color("font_color").is_equal_approx(INK):
		(node as Label).add_theme_color_override("font_color", CREAM)
	for c in node.get_children():
		if not (c is BaseButton or c is PanelContainer):
			on_wood(c)


static func text(words: String, font_size := 22, color := INK) -> Label:
	var l := Label.new()
	l.text = words
	l.add_theme_font_size_override("font_size", font_px(font_size))
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## One short line with an ⓘ beside it: the line says what matters at a glance, the ⓘ shows `more` (the whole
## explanation) as a message when tapped. Panels open with one of these, never a paragraph.
static func info(words: String, more: String, font_size := 20, color := INK) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var line := text(words, font_size, color)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	var tip := UiKit.icon_button("info", maxf(font_px(font_size) * INFO_SIZE, INFO_LEAST))
	tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tip.pressed.connect(func() -> void: Game.message.emit(more))
	UiKit.long_press_name(tip, more)
	row.add_child(tip)
	return row


## A panel's text size `font_size` (a design size) on this screen (UiTheme.font).
static func font_px(font_size: int) -> int:
	return UiTheme.font(font_size)


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
	l.add_theme_font_size_override("font_size", UiTheme.font(18))
	l.add_theme_color_override("font_color", INK if filled else MUTED.darkened(0.25))
	p.add_child(l)
	return p
