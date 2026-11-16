class_name CardList
extends Control
## A grid of item cards that scales to any number of items (our own engineering): it is as tall as all its rows,
## but only the cards in view (and a row either side) exist, a few CardFaces reused as the list scrolls. A face is
## worked out only for a card on screen (`face_of`), and so is its picture (`picture_of`, ItemIcons.of: a picture
## is loaded when its card is first seen). `refresh` reads the faces on screen again in place (coins changed, an
## item was bought): nothing is built. Every menu of cards is one (the Market's shelves, the Barn, the seeds...).

const SPARE_ROWS := 1   # rows kept ready above and below the view

var ids: Array[String] = []
var face_of: Callable      # (id) -> the card's face (CardFace)
var on_tap: Callable       # (id) -> void
var picture_of: Callable   # (id) -> Texture2D

var columns := 1
var _scroll: ScrollContainer
var _shown := {}           # index -> its CardFace
var _spare: Array[CardFace] = []
var _due := false
var _pop := false          # the panel is opening: the first cards pop in (UiFx)


## A list of `list` ids for a panel on a screen `view_width` wide.
static func make(list: Array[String], face: Callable, tap: Callable, view_width: float,
		picture := Callable(ItemIcons, "of")) -> CardList:
	var cl := CardList.new()
	cl.ids = list
	cl.face_of = face
	cl.on_tap = tap
	cl.picture_of = picture
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.mouse_filter = Control.MOUSE_FILTER_PASS
	cl._pop = UiFx.pop_next
	var room := BookPanel.width_for(view_width) - 2.0 * UiTheme.size("book_margin") - UiTheme.size("scroll_bar")
	cl._set_columns(room)
	return cl


func _ready() -> void:
	var up := get_parent()
	while up != null and not up is ScrollContainer:
		up = up.get_parent()
	_scroll = up as ScrollContainer
	if _scroll != null:
		_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _later())
		_scroll.resized.connect(_later)
	resized.connect(func() -> void:
		if size.x > 0.0:
			_set_columns(size.x)
		_later())
	visibility_changed.connect(_later)
	_later()


## Every card on screen reads its face again (and its picture), in place.
func refresh() -> void:
	for k: int in _shown:
		var card: CardFace = _shown[k]
		card.show_face(ids[k], face_of.call(ids[k]), picture_of.call(ids[k]))


## The same as tapping the card of `id`, whether it is on screen or not (tests, and a list that is searched).
func press(id: String) -> void:
	on_tap.call(id)


## The cards on screen now.
func shown() -> Array[CardFace]:
	var out: Array[CardFace] = []
	for k: int in _shown:
		out.append(_shown[k])
	return out


## The height of a card and the gap after it.
static func step() -> Vector2:
	var gap := UiTheme.size("hud_gap")
	return Vector2(UiTheme.size("card_width") + gap, UiTheme.size("card_icon") + UiTheme.size("card_words") + gap)


func _set_columns(room: float) -> void:
	var cols := maxi(1, floori((room + UiTheme.size("hud_gap")) / step().x))
	if cols == columns and custom_minimum_size.y > 0.0:
		return
	columns = cols
	var rows := ceili(ids.size() / float(columns))
	custom_minimum_size.y = maxf(0.0, rows * step().y - UiTheme.size("hud_gap"))
	for k: int in _shown.keys():
		_put_away(k)


func _later() -> void:
	if not _due:
		_due = true
		_lay_out.call_deferred()


## Puts cards on the rows in view and takes them off the rest.
func _lay_out() -> void:
	_due = false
	if not is_inside_tree() or not is_visible_in_tree() or ids.is_empty():
		return
	var rows := ceili(ids.size() / float(columns))
	var first := 0
	var last := rows - 1
	if _scroll != null:
		var top := _scroll.scroll_vertical - _top_in_scroll()
		first = maxi(0, floori(top / step().y) - SPARE_ROWS)
		last = mini(rows - 1, floori((top + _scroll.size.y) / step().y) + SPARE_ROWS)
	var lo := first * columns
	var hi := mini(ids.size() - 1, (last + 1) * columns - 1)
	for k: int in _shown.keys():
		if k < lo or k > hi:
			_put_away(k)
	var wide := (size.x - (columns * step().x - UiTheme.size("hud_gap"))) / 2.0   # (the grid centred)
	var order := 0
	for k in range(lo, hi + 1):
		if _shown.has(k):
			continue
		var card: CardFace = _spare.pop_back() if not _spare.is_empty() else _new_card()
		card.position = Vector2(maxf(0.0, wide) + (k % columns) * step().x, floorf(k / float(columns)) * step().y)
		card.scale = Vector2.ONE
		card.visible = true
		card.show_face(ids[k], face_of.call(ids[k]), picture_of.call(ids[k]))
		_shown[k] = card
		if _pop:
			UiFx.pop_now(card, order)
			order += 1
	_pop = false


func _new_card() -> CardFace:
	var card := CardFace.new()
	card.pressed.connect(func() -> void: on_tap.call(card.id))
	add_child(card)
	return card


func _put_away(k: int) -> void:
	var card: CardFace = _shown[k]
	_shown.erase(k)
	card.visible = false
	_spare.append(card)


## How far down the scrolling content this list starts.
func _top_in_scroll() -> float:
	var y := 0.0
	var n: Control = self
	while n != null and n.get_parent() != _scroll:
		y += n.position.y
		n = n.get_parent() as Control
	return y
