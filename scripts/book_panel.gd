class_name BookPanel
extends Control
## A full-screen overlay menu on the interface kit (UiKit), in the unified paper look (docs/UI.md): a dimmed
## backdrop, the paper surface with its title in ink at the left and the round close button at the right, pill tabs
## when it has them (the Market's shelves), and scrolling content that a
## builder fills. Each tab's page is built once while the panel is open (going back to a tab shows it again); `refresh`
## builds the page again, or, when its builder marked it live (`set_live`), only updates it in place (a CardList
## reads its faces again). Every panel of the game opens in it, and opens and closes in the interface's one motion
## (UiFx.open / close: the paper fades and rises in over its dim; a tab's page fades in); `is_open` is whether it
## is up (a closing panel is still drawn for a moment, but is no longer open).

signal opened   # a panel came up from closed (or closing)

## Words on paper, by their role (the values are data/ui_theme.json's "ink", "soft" and "done"): INK for what is
## read, SOFT for what is said beside it (a hint, a time, a reason), HEAD for a section's heading, GOOD for done
## ("done"). A test holds every word on the paper to a readable contrast.
enum Shape { CARDS, LIST }   # what a panel holds, and so how wide it is (`open_panel`)

const INK := Color("#3a2614")
const SOFT := Color("#8a7763")
const HEAD := Color("#3a2614")
const GOOD := Color("#3c7a2a")   # (the "done" green: the accent itself is too light for words)
const DIM := 0.35          # the backdrop's darkness
## The panel uses the screen (a phone's 20:9 especially): its scrolling area is this share of the screen's
## height, and it is as wide as the screen allows up to this many times the screen's height.
const HEIGHT_SHARE := 0.66
const INFO_SIZE := 1.6   # an ⓘ's size against the text beside it
const INFO_LEAST := 40.0   # ..and never smaller than this (a finger must hit it)
const PICTURE_PILL := 1.4   # a picture pill's side, in panel buttons' heights
const WIDEST := 2.0
const SECTION_LINE := 1.0   # px of the thin line under a section (card_frame)
const SECTION_PAD := 10.0   # px above and below a section's content

var shape := Shape.CARDS   # what the panel open holds (`open_panel`)
var _title: Label
var _dim: ColorRect
var _frame: MarginContainer   # (what moves as it opens: the paper's holder, outside any container)
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
	_dim = dim
	dim.color = Color(0, 0, 0, DIM)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_backdrop_input)
	add_child(dim)

	var margin := MarginContainer.new()
	_frame = margin
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
	panel.add_theme_stylebox_override("panel", UiKit.paper_box(UiTheme.size("book_margin")))
	panel.theme = UiKit.paper_theme()
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
	panel.add_child(col)

	# The title in ink at the left (as a building's sheet names it), the close button at the right.
	var header := HBoxContainer.new()
	col.add_child(header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", UiTheme.text_px("font_book_title"))
	_title.set_meta(&"title", true)   # (the one text larger than a heading: tests/suites/menus_test.gd)
	_title.add_theme_color_override("font_color", INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title)
	var close := UiKit.close_button()
	close.pressed.connect(close_panel)
	header.add_child(close)

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
	_content.add_theme_constant_override("separation", int(UiTheme.size("section_gap")))
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
	_panel.custom_minimum_size.x = width_for(view.x, view.y) if shape == Shape.CARDS \
		else minf(UiTheme.size("book_list_width"), view.x - UiTheme.size("book_inset"))
	_scroll.custom_minimum_size.y = view.y * HEIGHT_SHARE


## How wide a panel is on a screen `view_w` across (and `view_h` high: the screen's own when not given): as wide
## as the screen allows up to WIDEST times its height, never under the theme's design width where it fits.
static func width_for(view_w: float, view_h := -1.0) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var h := view_h if view_h > 0.0 else (tree.root.get_visible_rect().size.y if tree != null else view_w / WIDEST)
	return minf(maxf(UiTheme.size("book_width"), h * WIDEST), view_w - UiTheme.size("book_inset"))


## builder(content: VBoxContainer) fills the panel; it runs again on refresh(). `as_shape`: CARDS (a shelf of
## cards: as wide as the screen allows) or LIST (rows and choices, Settings, the inbox: a column as wide as its
## words need, `book_list_width`).
func open_panel(title: String, builder: Callable, as_shape := Shape.CARDS) -> void:
	shape = as_shape
	_tabs = []
	_tab = 0
	_show(title, builder)


## Opens a panel with tabs: `tabs` = [[name, builder]], `first` the one shown (FarmVille's Market shelves).
func open_tabs(title: String, tabs: Array, first := 0) -> void:
	shape = Shape.CARDS
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
	UiFx.crossfade(page())
	_scroll.scroll_vertical = 0


func _show(title: String, builder: Callable) -> void:
	_title.text = title
	_builder = builder
	_fit_screen()
	_build_tab_bar()
	var opening := not is_open()
	UiFx.pop_next = opening   # (a panel opening pops its cards in; a tab or a refresh doesn't)
	UiFx.popped = 0
	_clear_pages()
	_build_now()
	UiFx.pop_next = false
	if not opening:
		UiFx.crossfade(page())   # (another panel in the open one: its page changes, the paper stays)
	UiFx.open(self, _frame, _dim)
	Game.modal_open = true
	if opening:
		opened.emit()


## Whether a panel is up (not hidden, not on its way out).
func is_open() -> bool:
	return UiFx.is_open(self)


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


## Closes the panel in the one motion (hidden once it has gone); the farm takes taps again at once.
func close_panel() -> void:
	UiFx.close(self)
	Game.modal_open = false


func refresh() -> void:
	# Once a frame at most, at its end: many changes in a row (Accept all) rebuild the panel once.
	if not _refresh_due:
		_refresh_due = true
		_build_again.call_deferred()


func _build_again() -> void:
	_refresh_due = false
	if not is_open():
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
	fresh.add_theme_constant_override("separation", int(UiTheme.size("section_gap")))
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


## A section's heading (heading size, the head ink): what a group of rows is about.
static func heading(words: String) -> Label:
	return text(words, UiTheme.HEADING, HEAD)


## The ⓘ for what a thing has to say beyond its one line (our own look: details on asking, not printed): a tap
## says `lines` in the message strip. `set_more` changes them; it hides itself with none.
static func more_button(lines := PackedStringArray()) -> Button:
	var b := UiKit.icon_button("info", INFO_LEAST)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	set_more(b, lines)
	b.pressed.connect(func() -> void:
		var said: PackedStringArray = b.get_meta(&"lines", PackedStringArray())
		if not said.is_empty():
			Game.message.emit("\n".join(said)))
	return b


## Sets what a `more_button` says (shown only when there is something).
static func set_more(b: Button, lines: PackedStringArray) -> void:
	b.set_meta(&"lines", lines)
	b.visible = not lines.is_empty()


## A setting's row, as phones lay them out (our own look): its name at the left, its control at the right, one
## line high. `help` (optional) is said on a long press of the row's name, not printed under it.
static func row(words: String, control: Control, help := "") -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", int(SECTION_PAD))
	var name := text(words)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF   # (a setting's name is a few words: it keeps its line)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not control is FlowContainer else Control.SIZE_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(name)
	if help != "":
		name.tooltip_text = UiTheme.tidy(help)
		name.mouse_filter = Control.MOUSE_FILTER_PASS
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if control is FlowContainer:   # (choices take the rest of the line, and wrap onto a second when they must)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(control)
	return r


## A switch for a row (on or off), `toggled(on)` told when flipped.
static func switch(on: bool, toggled: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(toggled)
	UiKit.tappable(c)
	return c


## A small set of choices in one line (pills, the one in use lit): `options` [[key, words]] or [[key, words,
## picture]] (a picture pill: the picture alone, its words on a long press), `pick(key)` told on a tap. Each pill
## is as wide as its words.
static func choice(options: Array, current: String, pick: Callable) -> HFlowContainer:
	var r := HFlowContainer.new()
	r.alignment = FlowContainer.ALIGNMENT_END
	r.add_theme_constant_override("h_separation", int(SECTION_PAD / 2.0))
	r.add_theme_constant_override("v_separation", int(SECTION_PAD / 2.0))
	var group := ButtonGroup.new()
	for o: Array in options:
		var b := Button.new()
		b.text = str(o[1])
		if o.size() > 2 and o[2] is Control:   # (a picture in place of the words)
			b.text = ""
			var pic: Control = o[2]
			b.custom_minimum_size = Vector2.ONE * UiTheme.size("panel_button_height") * PICTURE_PILL
			b.add_child(pic)
			UiKit.centered(pic)
			UiKit.long_press_name(b, str(o[1]))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = str(o[0]) == current
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", font_px(UiTheme.BODY))
		var key := str(o[0])
		b.pressed.connect(func() -> void: pick.call(key))
		UiFx.press_bounce(b)
		UiKit.tappable(b)
		r.add_child(b)
	return r


## A section of a panel: flat on the paper, no box round it, a thin line under it (our own look: fewer boxes in
## boxes).
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
	return frame


static func text(words: String, font_size := UiTheme.BODY, color := INK) -> Label:
	var l := PanelText.new()   # (wraps only where it has a width: never a letter a line)
	l.text = UiTheme.tidy(words)
	l.add_theme_font_size_override("font_size", font_px(font_size))
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## One short line with an ⓘ beside it: the line says what matters at a glance, the ⓘ shows `more` (the whole
## explanation) as a message when tapped. Panels open with one of these, never a paragraph.
static func info(words: String, more: String, font_size := UiTheme.BODY, color := INK) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
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

