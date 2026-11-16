class_name CardList
extends Control
## A list of cards that scales to any number of items (our own engineering): it is as tall as all its items, but
## only the ones in view (and a row either side) exist, reused as the list scrolls. Two shapes:
## - a grid of item cards (`make`): light CardFaces, one node each that draws itself; a face is worked out only for
##   a card on screen (`face_of`), and so is its picture (`picture_of`, ItemIcons.of: loaded when first seen);
## - rows (`rows`): one full-width row per item, flat, a thin line between them (no box round each), made by
##   `row_make` once per row on screen and filled for whichever item it shows (`row_fill`).
## `refresh` fills what is on screen again in place (coins changed, an item was bought); `set_ids` when the list
## itself changes (the inbox). Every menu of cards or lines is one: the Market, seeds, the Barn, Collections,
## Ribbons, the inbox, a building's recipes.

const SPARE_ROWS := 1     # rows kept ready above and below the view
const ROW_GUESS := 64.0   # a row's height until the first row on screen is measured
const DIVIDER := 1.0      # the line between rows, px

var ids: Array[String] = []
var face_of: Callable      # grid: (id) -> the card's face (CardFace)
var on_tap: Callable       # grid: (id) -> void
var picture_of: Callable   # grid: (id) -> Texture2D
var row_make: Callable     # rows: () -> Control
var row_fill: Callable     # rows: (row, id) -> void

var columns := 1
var _scroll: ScrollContainer
var _shown := {}           # index -> its card or row
var _spare: Array[Control] = []
var _due := false
var _pop := false          # the panel is opening: the first cards pop in (UiFx)
var _row_high := 0.0       # rows: the tallest row measured so far


## A grid of cards for the `list` ids, for a panel on a screen `view_width` wide.
static func make(list: Array[String], face: Callable, tap: Callable, view_width: float,
		picture := Callable(ItemIcons, "of")) -> CardList:
	var cl := _new_list(list)
	cl.face_of = face
	cl.on_tap = tap
	cl.picture_of = picture
	var room := BookPanel.width_for(view_width) - 2.0 * UiTheme.size("book_margin") - UiTheme.size("scroll_bar")
	cl._set_columns(room)
	return cl


## Rows for the `list` ids: `make_row` () -> a row, `fill` (row, id) shows an item on it.
static func rows(list: Array[String], make_row: Callable, fill: Callable) -> CardList:
	var cl := _new_list(list)
	cl.row_make = make_row
	cl.row_fill = fill
	cl._row_high = ROW_GUESS
	cl._size_to_ids()
	return cl


static func _new_list(list: Array[String]) -> CardList:
	var cl := CardList.new()
	cl.ids = list
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.mouse_filter = Control.MOUSE_FILTER_PASS
	cl._pop = UiFx.pop_next
	return cl


func _ready() -> void:
	# Anything between here and the scroll moving (a page above leaving, a strip opening) moves what is in view.
	var up := get_parent()
	while up != null and not up is ScrollContainer:
		if up is Control:
			(up as Control).item_rect_changed.connect(_later)
		up = up.get_parent()
	_scroll = up as ScrollContainer
	if _scroll != null:
		_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _later())
		_scroll.resized.connect(_later)
	resized.connect(func() -> void:
		if size.x > 0.0 and not _is_rows():
			_set_columns(size.x)
		elif _is_rows():
			for k: int in _shown:
				(_shown[k] as Control).size.x = size.x
		_later())
	item_rect_changed.connect(_later)
	visibility_changed.connect(_later)
	_later()


## Everything on screen is filled again (faces and pictures read again), in place.
func refresh() -> void:
	for k: int in _shown:
		_fill(_shown[k], k)
	queue_redraw()


## The list itself changed (an inbox line taken): the new `list`, laid out again; rows are kept and refilled.
func set_ids(list: Array[String]) -> void:
	ids = list
	for k: int in _shown.keys():
		_put_away(k)
	_size_to_ids()
	_later()


## The same as tapping the card of `id`, whether it is on screen or not (tests, and a list that is searched).
func press(id: String) -> void:
	if on_tap.is_valid():
		on_tap.call(id)


## The cards (or rows) on screen now.
func shown() -> Array:
	var out: Array = []
	for k: int in _shown:
		out.append(_shown[k])
	return out


## The size of one place in the list with the gap after it.
func step() -> Vector2:
	var gap := UiTheme.size("hud_gap")
	if _is_rows():
		return Vector2(size.x, _row_high + DIVIDER)
	return Vector2(UiTheme.size("card_width") + gap, UiTheme.size("card_icon") + UiTheme.size("card_words") + gap)


func _is_rows() -> bool:
	return row_make.is_valid()


func _set_columns(room: float) -> void:
	var cols := maxi(1, floori((room + UiTheme.size("hud_gap")) / step().x))
	if cols == columns and custom_minimum_size.y > 0.0:
		return
	columns = cols
	_size_to_ids()
	for k: int in _shown.keys():
		_put_away(k)


func _size_to_ids() -> void:
	var count := ceili(ids.size() / float(columns))
	var gap := 0.0 if _is_rows() else UiTheme.size("hud_gap")
	custom_minimum_size.y = maxf(0.0, count * step().y - gap)


func _later() -> void:
	if not _due:
		_due = true
		_lay_out.call_deferred()


## Puts cards on the rows in view and takes them off the rest.
func _lay_out() -> void:
	_due = false
	if not is_inside_tree() or not is_visible_in_tree():
		return
	var count := ceili(ids.size() / float(columns))
	var first := 0
	var last := count - 1
	if _scroll != null:
		var top := _scroll.scroll_vertical - _top_in_scroll()
		first = maxi(0, floori(top / step().y) - SPARE_ROWS)
		last = mini(count - 1, floori((top + _scroll.size.y) / step().y) + SPARE_ROWS)
	var lo := first * columns
	var hi := mini(ids.size() - 1, (last + 1) * columns - 1)
	for k: int in _shown.keys():
		if k < lo or k > hi:
			_put_away(k)
	var wide := 0.0 if _is_rows() else maxf(0.0, (size.x - (columns * step().x - UiTheme.size("hud_gap"))) / 2.0)
	var order := 0
	var taller := false
	for k in range(lo, hi + 1):
		if _shown.has(k):
			continue
		var card: Control = _spare.pop_back() if not _spare.is_empty() else _new_card()
		card.position = Vector2(wide + (k % columns) * step().x, floorf(k / float(columns)) * step().y)
		card.scale = Vector2.ONE
		card.visible = true
		_shown[k] = card
		if _is_rows():
			card.size.x = size.x   # (a wrapping line needs its width before it is measured)
		_fill(card, k)
		if _is_rows():
			var need := card.get_combined_minimum_size().y
			if need > _row_high:
				_row_high = need
				taller = true
			card.size = Vector2(size.x, _row_high)
		if _pop:
			UiFx.pop_now(card, order)
			order += 1
	_pop = false
	if taller:   # (a row was taller than thought: every row takes its height)
		_size_to_ids()
		for k: int in _shown:
			var row: Control = _shown[k]
			row.position.y = k * step().y
			row.size.y = _row_high
		_later()
	queue_redraw()


## The thin line between rows.
func _draw() -> void:
	if not _is_rows():
		return
	var line := UiTheme.color("divider")
	for k: int in _shown:
		if k < ids.size() - 1:
			var y := (k + 1) * step().y - DIVIDER / 2.0
			draw_line(Vector2(0, y), Vector2(size.x, y), line, DIVIDER)


func _fill(card: Control, k: int) -> void:
	card.set_meta(&"id", ids[k])
	if _is_rows():
		row_fill.call(card, ids[k])
	else:
		(card as CardFace).show_face(ids[k], face_of.call(ids[k]), picture_of.call(ids[k]))


func _new_card() -> Control:
	var card: Control
	if _is_rows():
		card = row_make.call()
	else:
		var face := CardFace.new()
		face.pressed.connect(func() -> void: on_tap.call(face.id))
		card = face
	add_child(card)
	return card


func _put_away(k: int) -> void:
	var card: Control = _shown[k]
	_shown.erase(k)
	card.visible = false
	_spare.append(card)


## Puts `content` on a reused `row` in place of what it showed (a row filled by building its few parts again: only
## rows on screen are ever filled). Old parts leave at once so the row measures only the new.
static func refill(row: Control, content: Control) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	row.add_child(content)


## How far down the scrolling content this list starts.
func _top_in_scroll() -> float:
	var y := 0.0
	var n: Control = self
	while n != null and n.get_parent() != _scroll:
		y += n.position.y
		n = n.get_parent() as Control
	return y
