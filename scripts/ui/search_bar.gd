class_name SearchBar
extends VBoxContainer
## The search field over a list (docs/SEARCH.md; our own touch), on the paper look: a pill with a magnifier,
## what is typed and a clear button; the menu's filter chips under it; recent searches while it is empty and in
## use; one line when nothing matches ("Did you mean Strawberry?" or Clear filters). It drives one `CardList`
## (`CardList.show_ids`), so cards are reused and nothing is built again, and while it searches the rest of its
## page after the list steps aside (the Market's other sections). A CardList puts one over itself once it holds
## `from_items` things (data/search.json), so every list gets search with no work of its own.

const FIELD_HIGH := 1.2   # the field's height, in panel buttons' heights
const ICON_SHARE := 0.55  # the magnifier, of the field's height

var list: CardList
var menu := ""
var field: LineEdit
var _index: SearchIndex
var _chips: Array = []
var _chips_on := {}
var _chip_row: HFlowContainer
var _recent_row: HFlowContainer
var _none: HBoxContainer
var _due := false
var _stepped_aside: Array[Control] = []


## A bar over `cards` (it searches the list's `searched()` ids and shows what it finds there), for menu
## `menu_key` (its chips and recent searches).
func _init(cards: CardList, menu_key: String) -> void:
	list = cards
	menu = menu_key
	add_theme_constant_override("separation", int(BookPanel.SECTION_PAD / 2.0))
	add_child(_field_row())
	_chips = ItemSearch.chips_for(menu)
	_chip_row = _flow()
	for c: Dictionary in _chips:
		var key := str(c["key"])
		var b := _pill(str(c["words"]))
		b.toggle_mode = true
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_chips_on[key] = true
			else:
				_chips_on.erase(key)
			_later())
		_chip_row.add_child(b)
	_chip_row.visible = not _chips.is_empty()
	add_child(_chip_row)
	_recent_row = _flow()
	_recent_row.visible = false
	add_child(_recent_row)
	_none = HBoxContainer.new()
	_none.visible = false
	add_child(_none)


## Whether it is narrowing the list now (words typed or a chip on).
func searching() -> bool:
	return field.text.strip_edges() != "" or not _chips_on.is_empty()


## Types `query` (tests, a recent search, "did you mean").
func search(query: String) -> void:
	field.text = query
	field.caret_column = query.length()
	_later()


## The list's ids changed (the inbox took a line): searched again as it stands.
func reapply() -> void:
	_index = null
	_apply()


func _field_row() -> PanelContainer:
	var high := UiTheme.size("panel_button_height") * FIELD_HIGH
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color("paper").lightened(0.4)
	sb.border_color = UiTheme.color("card_edge")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(high))
	sb.content_margin_left = high * 0.35
	sb.content_margin_right = high * 0.2
	pill.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	pill.add_child(row)
	var glass := UiIcon.make("search", high * ICON_SHARE)
	glass.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glass)
	field = LineEdit.new()
	field.placeholder_text = tr("SEARCH_HINT")
	field.clear_button_enabled = true
	field.custom_minimum_size.y = high
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	field.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	field.add_theme_font_size_override("font_size", BookPanel.font_px(UiTheme.BODY))
	field.add_theme_color_override("font_color", UiTheme.color("ink"))
	field.add_theme_color_override("font_placeholder_color", BookPanel.SOFT)
	field.text_changed.connect(func(_t: String) -> void: _later())
	field.text_submitted.connect(func(t: String) -> void:
		ItemSearch.remember(menu, t)
		field.release_focus())
	field.focus_entered.connect(func() -> void:
		_show_recent()
		get_tree().call_group(&"keyboard_aware", &"keyboard_up", self))   # (a sheet goes tall: the field in view)
	field.focus_exited.connect(func() -> void:
		ItemSearch.remember(menu, field.text)
		_recent_row.visible = false)
	row.add_child(field)
	return pill


## Back clears what is typed first; a second back closes as ever.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and is_visible_in_tree() and searching():
		field.text = ""
		_chips_on.clear()
		for b: Button in _chip_row.get_children():
			b.set_pressed_no_signal(false)
		_apply()
		get_viewport().set_input_as_handled()


func _later() -> void:
	if not _due:
		_due = true
		_apply.call_deferred()   # (letters typed in one frame are searched once)


func _apply() -> void:
	_due = false
	if not is_instance_valid(list):
		return
	_recent_row.visible = false
	if not searching():
		list.show_ids(list.all_ids)
		_step_back()
		_none.visible = false
		if field.has_focus():
			_show_recent()
		return
	if _index == null:   # (made at the first letter: a menu never searched costs nothing)
		_index = SearchIndex.new(list.searched(), list.words_of_card)
	var found := _index.find(field.text, _keep())
	list.show_ids(found)
	_step_aside()
	_show_none(found.is_empty())


## The filters on now, as one test.
func _keep() -> Callable:
	if _chips_on.is_empty():
		return Callable()
	var on: Array = []
	for c: Dictionary in _chips:
		if _chips_on.has(str(c["key"])):
			on.append(c["test"])
	return func(id: String) -> bool:
		var face: Dictionary = list.face_of.call(id) if list.face_of.is_valid() else {}
		for test: Callable in on:
			if not test.call(id, face):
				return false
		return true


func _show_recent() -> void:
	for c in _recent_row.get_children():
		c.queue_free()
	var kept := ItemSearch.recent(menu)
	if field.text != "" or kept.is_empty():
		_recent_row.visible = false
		return
	_recent_row.add_child(BookPanel.text(tr("SEARCH_RECENT"), UiTheme.CAPTION, BookPanel.SOFT))
	for q in kept:
		var b := UiKit.quiet_button(q, BookPanel.font_px(UiTheme.BODY))
		b.pressed.connect(func() -> void: search(q))
		_recent_row.add_child(b)
	_recent_row.visible = true


func _show_none(empty: bool) -> void:
	for c in _none.get_children():
		c.queue_free()
	_none.visible = empty
	if not empty:
		return
	_none.add_child(BookPanel.text(tr("SEARCH_NONE"), UiTheme.BODY, BookPanel.SOFT))
	var near := _index.nearest(field.text) if field.text.strip_edges() != "" else ""
	if near != "":
		var b := UiKit.quiet_button(tr("SEARCH_DID_YOU_MEAN") % near, BookPanel.font_px(UiTheme.BODY))
		b.pressed.connect(func() -> void: search(near))
		_none.add_child(b)
	elif not _chips_on.is_empty():
		var c := UiKit.quiet_button(tr("SEARCH_CLEAR_FILTERS"), BookPanel.font_px(UiTheme.BODY))
		c.pressed.connect(func() -> void:
			_chips_on.clear()
			for b: Button in _chip_row.get_children():
				b.set_pressed_no_signal(false)
			_apply())
		_none.add_child(c)


## While searching, the rest of the page after the list steps aside (its other sections, a land card).
func _step_aside() -> void:
	if not _stepped_aside.is_empty():
		return
	var page := list.get_parent()
	if page == null:
		return
	for k in range(list.get_index() + 1, page.get_child_count()):
		var c := page.get_child(k) as Control
		if c != null and c.visible:
			c.visible = false
			_stepped_aside.append(c)


func _step_back() -> void:
	for c in _stepped_aside:
		if is_instance_valid(c):
			c.visible = true
	_stepped_aside.clear()


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", int(BookPanel.SECTION_PAD / 2.0))
	f.add_theme_constant_override("v_separation", int(BookPanel.SECTION_PAD / 2.0))
	return f


func _pill(words: String) -> Button:
	var b := Button.new()
	b.text = words
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", BookPanel.font_px(UiTheme.BODY))
	UiFx.press_bounce(b)
	return b
