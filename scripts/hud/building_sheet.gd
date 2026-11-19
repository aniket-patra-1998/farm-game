class_name BuildingSheet
extends PanelContainer
## The sheet of a tapped thing that has more to it than a bubble: every building, and an animal to feed, a
## young one growing, a bloom, a vehicle short of fuel. A card that slides up from the bottom of the screen, the
## farm still in view above it. One layout for all (its picture, name and state, a ring for the time to wait,
## Move/Turn/Sell small at the top for a building, a line with a bar, what it holds, the one big button); only the
## middle and the big button differ by its `Kind`:
## - a home: how full, what it pays (a coin and a star), who lives in it, Collect and Add N, what its next size adds;
## - a crafting building: its menu's tabs in the sheet (HudCrafting.tabs: Make with its slots, the recipe picked
##   and every recipe; Goods; Pantry); Collect N when any are done;
## - a building site: how far built and each material had of needed; Add my materials;
## - the Barn: its storage and boosts;
## - anything else (a home for finds, a shed...): its own page;
## - an animal: its feeding; a young one: how it grows and its supply; a bloom: regrowing and upgrading it; a
##   vehicle: the fuel tank.
## Everything a building does is in its sheet; there is no other window. What a building has more of is a tab
## (SheetTabs) whose page is filled by the panel builders (`HudBuildings`, `HudFeed`, `HudBarn`) and scrolls:
## a home's Feed and Grow (its next size) and its own extras by name (`SPECIAL_TABS`: a nursery's Babies, Bees,
## Eggs, the Garage's Vehicles, a Dog House's Finds), the Barn's Storage, Boosts and Fuel; a crafting building's
## menu (HudCrafting.tabs). A site's missing materials to buy sit under its main part. The builders ask for a
## page to be built again through `FarmHud.refresh_panels` (`refill_soon`).
##
## It opens and closes in the interface's one motion (UiFx.open_with / close, on its timing and ease): it slides up
## from below the screen as it fades in, and back down as it fades out; `is_open` is whether it is up.
##
## Two heights: compact (as tall as what it says) and, for a building with more to show (a crafting building's
## recipes as a grid), tall (`TALL_SHARE` of the screen). It is dragged by its handle or any empty part of it: up
## to tall, down to compact, down again to close; a tap on the handle switches; a quick flick counts as a drag.
##
## Built once and kept: opening it for another home, and every change while it is open, only sets its words,
## bars and pictures (`_refill`); nothing is thrown away and built again. Its picture is ItemIcons' own (made
## once per item and kept).

enum Kind { HOME, CRAFT, BUILD, BARN, OTHER, ANIMAL, YOUNG, BLOOM, VEHICLE }   # which middle and big button

const MARGIN := 18.0                   # the paper's inside margin
const COUNT_UP := 0.6                  # seconds a collected sum takes to count up
const WIDTH_SHARE := 0.5               # of the screen's width..
const WIDTH_LEAST := 480.0             # ..but never narrower than this
const EDGE := 14.0                     # its gap from the bottom of the screen
const TICK := 1.0                      # seconds between looks at the clock while open
const TALL_SHARE := 0.78               # the tall sheet's height, of the screen's
const SNAP := 48.0                     # px a drag must go to change height (or close)
const FLICK := 900.0                   # px a second: a quicker drag counts whatever its length
const HANDLE := Vector2(56, 6)         # the handle's size, before the UI's scale
const SETTLE := 0.2                    # seconds to settle at a height
const PAGE_SHARE := 0.42               # a tab's page, compact: at most this share of the screen (it scrolls)
const INSIDE_SHARE := 0.2              # who lives inside, as pictures: at most this share of the screen (it scrolls)
const SPECIAL_TABS := {                # a building's own extras (catalog `special`) get a tab, named for them
	"mystery_eggs": "SHEET_TAB_EGGS", "calves": "SHEET_TAB_BABIES", "foals": "SHEET_TAB_BABIES",
	"nursery": "SHEET_TAB_BABIES", "beehive": "SHEET_TAB_BEES", "truffles": "SHEET_TAB_TRUFFLES",
	"garage": "SHEET_TAB_VEHICLES", "garden_shed": "SHEET_TAB_BLOOMS", "saplings": "SHEET_TAB_SAPLINGS",
	"finds_home": "SHEET_TAB_FINDS",
}
const ADDS := [["upper", "ADDS_FLOOR"], ["silo", "ADDS_SILO"], ["egg_chutes", "ADDS_CHUTE"],
	["stall_doors", "ADDS_STALL"]]   # what a next size adds, most telling first: [what, its words]

var hud: FarmHud
var tall := false           # dragged up to its tall height
var _uid := -1
var _pic: TextureRect
var _name: Label
var _state: Label
var _ring: ProgressRing
var _bar: ProgressBar
var _inside: HBoxContainer
var _inside_scroll: ScrollContainer   # (a full orchard's every kind would push the sheet off the top)
var _inside_key := ""
var _coins: Label
var _xp: Label
var _next: Label
var _note: Label
var _more: Button     # the ⓘ by the name: a home's layout and boost lines
var _collect: Button
var _fill: Button
var _move: Button
var _sell: Button
var _turn: Button
var _fill_block: Control
var _next_card: PanelContainer
var _next_pic: TextureRect
var _pay: Control
var _detail: Label    # a site's materials: a line each
var _tabs: SheetTabs    # a building's tabs (none with one page)
var _specs: Array = []  # each tab: [its words' key, what fills its page (an empty Callable: the main part)]
var _main: VBoxContainer          # the main part: numbers, who's inside, its own extras, the next size
var _extras: VBoxContainer        # ..its own extras, filled by a panel builder
var _page_scroll: ScrollContainer # another tab's page, scrolling
var _page: VBoxContainer
var _page_due := true   # its page is to be built again at the next refill
var _kind := Kind.OTHER
var _since := 0.0
var _counting := false
var _dirty := false   # the farm changed while the sheet was up: refill it this frame
var _shown := 0.0     # how far it has slid up: 0 below the screen, 1 at rest (UiFx's share)
var _area := Vector2.ZERO   # the screen it was placed on (a turned phone or resized window places it again)
var _drag := 0.0            # px it is pulled from where it rests: down positive, up negative
var _press_y := -1.0        # where a drag began (-1: none)
var _press_at := 0          # (ms) when
var _on_handle := false
var _settle: Tween


func _init(owner: FarmHud) -> void:
	hud = owner
	add_to_group(&"keyboard_aware")   # (a search field in it asks it to go tall: SearchBar)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiKit.paper_box(MARGIN))
	theme = UiKit.paper_theme()   # (the same paper as every panel: one look, docs/UI.md)
	var gap := int(UiTheme.size("hud_gap"))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	add_child(column)
	var handle := Handle.new()
	handle.custom_minimum_size = HANDLE * UiTheme.scale() + Vector2(0, gap)
	handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(handle)
	column.add_child(_build_head(gap))
	_tabs = SheetTabs.new()
	_tabs.picked.connect(func(_i: int) -> void:
		_page_due = true
		_fill_page()
		UiFx.crossfade(_page_scroll if _page_scroll.visible else _main))
	column.add_child(_tabs)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", gap)
	column.add_child(_main)
	_main.add_child(_build_numbers(gap))
	_inside_scroll = ScrollContainer.new()
	_inside_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inside = HBoxContainer.new()
	_inside.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inside_scroll.add_child(_inside)
	_main.add_child(_inside_scroll)
	_detail = BookPanel.text("", UiTheme.BODY, UiTheme.color("soft"))
	_main.add_child(_detail)
	_extras = VBoxContainer.new()
	_extras.add_theme_constant_override("separation", gap)
	_main.add_child(_extras)
	_main.add_child(_build_next(gap))
	_page_scroll = ScrollContainer.new()
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_scroll.visible = false
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", gap)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_scroll.add_child(_page)
	column.add_child(_page_scroll)
	_note = BookPanel.text("", UiTheme.BODY, UiTheme.color("price_short"))
	column.add_child(_note)
	column.add_child(_build_actions(gap))
	Game.objects_changed.connect(func() -> void:
		_on_changed()
		_page_due = true)   # (the whole farm changed: everything is looked at again)
	Game.object_changed.connect(func(uid: int) -> void:
		_on_changed()   # (another home fed takes from the same feed: its words and buttons)
		_page_due = _page_due or uid == _uid)   # (its page is built again only for its own change)
	UiKit.keep_fitted(self, _place)   # (as tall as what it says now, and back at the bottom)


## Whether thing `o` opens in the sheet: every building (homes, crafting buildings, the Barn, building sites...),
## and an animal that can be fed, a young one, a bloom, a finished vehicle.
static func suits(o: Dictionary) -> bool:
	return not o.is_empty() and (Game.is_building_item(str(o["id"])) or _thing_kind(o) >= 0)


## Which of the things that aren't buildings `o` is (-1: none of them).
static func _thing_kind(o: Dictionary) -> int:
	if Game.nurture.is_young(o):
		return Kind.YOUNG
	match Game.kind_of(o):
		"bloom":
			return Kind.BLOOM
		"animal":
			return Kind.ANIMAL if Game.feeds.is_feedable(o) else -1
		"vehicle":
			return Kind.VEHICLE if not Game.under_construction(o) else -1
	return -1


## Which middle and big button building `o` gets.
static func kind_of(o: Dictionary) -> Kind:
	var thing := _thing_kind(o)
	if thing >= 0:
		return thing as Kind
	if Game.under_construction(o):
		return Kind.BUILD
	if str(Game.item_data(o["id"]).get("kind", "")) == "barn":
		return Kind.BARN
	if Game.crafting.is_crafting(o):
		return Kind.CRAFT
	if Game.is_home(o) and Game.special_of(o) != "finds_home":
		return Kind.HOME
	return Kind.OTHER


func open(uid: int) -> void:
	if uid != _uid:
		_set_tall(false)
		_tabs.pick(0, true)
	_uid = uid
	_page_due = true
	_inside_key = ""
	_sell.remove_meta(&"sure")
	_sell.text = tr("TOOL_SELL")
	_refill()
	if _uid < 0:
		return
	if is_open():
		return   # (already up: another home tapped, it only changes what it says)
	# It slides by a share of the way, not to a point worked out now: it is sized by what it says, which settles
	# a frame later (wrapped lines learn their width), and every refit puts it back on the same path.
	UiFx.open_with(self, _slid)


## Slides it away (from where it is: pulled down, it goes on down); once gone it forgets the thing it showed.
func close() -> void:
	if _settle != null and _settle.is_valid():
		_settle.kill()
	_press_y = -1.0
	UiFx.close(self, func() -> void:
		_drag = 0.0
		_set_tall(false)
		_uid = -1)


## Whether it is up (not hidden, not on its way out).
func is_open() -> bool:
	return UiFx.is_open(self)


## Its width: a share of the screen, never narrower than a comfortable sheet, never wider than the screen.
static func width_for(area: Vector2) -> float:
	return minf(maxf(area.x * WIDTH_SHARE, WIDTH_LEAST), area.x - 2.0 * EDGE)


func _slid(share: float) -> void:
	_shown = share
	modulate.a = share
	_place()


## Puts the sheet at the bottom middle of the screen (`_shown` of the way up): compact, exactly as big as what it
## says; tall, `TALL_SHARE` of the screen; pulled up from compact it grows, pulled down it moves down.
func _place() -> void:
	var area := get_parent_area_size()
	_area = area
	custom_minimum_size = Vector2(width_for(area), 0.0)
	if _page_scroll.visible:   # compact: as tall as its page up to a share of the screen; tall: what is left
		_page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if tall else Control.SIZE_FILL
		_page_scroll.custom_minimum_size.y = 0.0 if tall \
			else minf(_page.get_combined_minimum_size().y, area.y * PAGE_SHARE)
	_inside_scroll.custom_minimum_size.y = minf(_inside.get_combined_minimum_size().y, area.y * INSIDE_SHARE)
	size = Vector2.ZERO   # (never smaller than its minimum: so exactly that)
	var high := size.y + maxf(-_drag, 0.0)   # compact: pulled up, it grows
	var lower := maxf(_drag, 0.0)            # ..pulled down, it moves down
	if tall:   # tall: pulled down, it shrinks (never below what it says); pulled further, eased by the settle
		high = maxf(area.y * TALL_SHARE, size.y) - _drag
		lower = 0.0
	if tall or _drag < 0.0:   # (otherwise no height of its own: it follows what it says, shrinking too)
		custom_minimum_size.y = clampf(high, size.y, area.y - 2.0 * EDGE)
		size = Vector2.ZERO
	var rest := area.y - size.y - EDGE + lower
	position = Vector2((area.x - size.x) / 2.0, lerpf(area.y, rest, _shown))


## The tabs building `o` has: [its words' key, what fills its page]; an empty Callable is the main part.
func _specs_for(o: Dictionary) -> Array:
	var main := Callable()
	var special := str(Game.item_data(o["id"]).get("special", ""))
	var own: Array = []   # its own extras' tab, if it has any
	if SPECIAL_TABS.has(special):
		own = [SPECIAL_TABS[special], func(page: VBoxContainer) -> void:
			var now := Game.object_by_uid(_uid)
			if special == "finds_home":
				hud.buildings.build_finds_home(page, now)
			else:
				hud.buildings.add_building_special_info(page, now)]
	match _kind:
		Kind.HOME:
			var out: Array = [["SHEET_TAB_HOME", main]]
			if not own.is_empty():
				out.append(own)
			if Game.feeds.is_feedable(o):
				out.append(["SHEET_TAB_FEED", func(page: VBoxContainer) -> void:
					hud.feed.add_feed_card(page, Game.object_by_uid(_uid))])
			if not Game.land.expansion_needs(o).is_empty():
				out.append(["SHEET_TAB_GROW", func(page: VBoxContainer) -> void:
					hud.buildings.add_expansion_card(page, Game.object_by_uid(_uid), _uid)])
			return out
		Kind.CRAFT:
			return hud.crafting.tabs(o)
		Kind.BARN:
			if o.get("broken", false):
				return [["SHEET_TAB_STORAGE", hud.barn.build_barn_repair]]
			var barn: Array = [["SHEET_TAB_STORAGE", hud.barn.build_barn_storage],
				["SHEET_TAB_BOOSTS", hud.barn.add_boosts]]
			if Game.vip.is_on():
				barn.append(["SHEET_TAB_VIP", hud.barn.build_vip])
			if Game.vehicles.fuel_unlocked:
				barn.append(["SHEET_TAB_FUEL", hud.buildings.build_fuel])
			return barn
		Kind.OTHER:
			if not own.is_empty():
				return [own]   # (a store: its own extras are what it shows)
		Kind.ANIMAL:
			return [["SHEET_TAB_FEED", func(page: VBoxContainer) -> void:
				hud.feed.add_feed_card(page, Game.object_by_uid(_uid))]]
		Kind.YOUNG:
			return [["SHEET_TAB_HOME", hud.barn.build_young]]
		Kind.BLOOM:
			return [["SHEET_TAB_HOME", hud.barn.build_bloom]]
		Kind.VEHICLE:
			return [["SHEET_TAB_HOME", func(page: VBoxContainer) -> void:
				hud.buildings.add_rust_card(page, str(Game.object_by_uid(_uid).get("id", "")))
				hud.buildings.build_fuel(page)]]
	return [["SHEET_TAB_HOME", main]]


## The tab in use: the main part, or its page filled again by its builder (small: a page is a building's own).
func _fill_page() -> void:
	var filler: Callable = _specs[_tabs.current][1] if _tabs.current < _specs.size() else Callable()
	_main.visible = not filler.is_valid()
	_page_scroll.visible = filler.is_valid()
	if filler.is_valid() and _page_due:
		_page_due = false
		for c in _page.get_children():
			_page.remove_child(c)
			c.queue_free()
		filler.call(_page)
	if visible:
		_place()


## A few lines under a building's main part: a home's layout and boost lines; a site's reason and its missing
## materials to buy.
func _fill_extras(o: Dictionary) -> void:
	for c in _extras.get_children():
		_extras.remove_child(c)
		c.queue_free()
	match _kind:
		Kind.HOME:   # (its layout and boost lines: details, behind the ⓘ by its name)
			pass
		Kind.BUILD:
			var finish := Game.buildings.can_finish(o)
			if not finish.ok() and finish.text != "":
				_extras.add_child(BookPanel.text(finish.text, UiTheme.BODY, BookPanel.SOFT))
			var uid := _uid
			hud.buildings.add_buy_missing(_extras, Game.land.construction_needs(o),
				func() -> void: Game.land.add_materials(uid))
	_extras.visible = _extras.get_child_count() > 0
	var details := PackedStringArray()
	if _kind == Kind.HOME:
		for line in [hud.feed.layout_line(o), hud.feed.boost_line(o)]:
			if line != "":
				details.append(line)
	BookPanel.set_more(_more, details)


## Whether it has a tall height: a building with more to show there.
func _can_be_tall() -> bool:
	return _tabs.visible or _page_scroll.visible


## Built again at the end of this frame (a builder's page asked: a card picked, a sale).
func refill_soon() -> void:
	_dirty = visible
	_page_due = true


## The page back at its top.
func scroll_to_top() -> void:
	_page_scroll.scroll_vertical = 0


## Shows the page named by `key` (a tab's words' key), if it has one: the Barn's Boosts sends you to its Fuel.
func show_page(key: String) -> void:
	for k in _specs.size():
		if str(_specs[k][0]) == key:
			_tabs.pick(k)
			return


## Dragged up for it: tall, if it has more to show.
## A search field in the sheet took the keyboard: the sheet goes tall, so the field stays above it.
func keyboard_up(_field: Control) -> void:
	if visible and is_ancestor_of(_field):
		make_tall()


func make_tall() -> void:
	if _can_be_tall() and not tall:
		_set_tall(true)
		_place()


func _set_tall(on: bool) -> void:
	tall = on


## Dragging it: up to tall, down to compact or closed; a tap on the handle switches.
func _gui_input(e: InputEvent) -> void:
	var press := e as InputEventMouseButton
	if press != null and press.button_index == MOUSE_BUTTON_LEFT:
		if press.pressed:
			_press_y = press.global_position.y
			_press_at = Time.get_ticks_msec()
			_on_handle = press.position.y < MARGIN + HANDLE.y * UiTheme.scale() + UiTheme.size("hud_gap")
			if _settle != null and _settle.is_valid():
				_settle.kill()
		elif _press_y >= 0.0:
			_let_go(press.global_position.y)
		accept_event()
		return
	var move := e as InputEventMouseMotion
	if move != null and _press_y >= 0.0:
		_drag = move.global_position.y - _press_y
		if not _can_be_tall():
			_drag = maxf(_drag, 0.0)   # (nothing taller to show: only down, to close)
		_place()
		accept_event()


func _let_go(y: float) -> void:
	var moved := y - _press_y
	var speed := moved / maxf((Time.get_ticks_msec() - _press_at) / 1000.0, 0.001)
	_press_y = -1.0
	var up := moved < -SNAP or speed < -FLICK
	var down := moved > SNAP or speed > FLICK
	var before := size.y
	if absf(moved) < 6.0 and _on_handle and _can_be_tall():
		up = not tall
		down = tall
	if up and _can_be_tall() and not tall:
		_set_tall(true)
	elif down and tall:
		_set_tall(false)
	elif down:
		_settle = create_tween()
		_settle.tween_method(func(d: float) -> void:
			_drag = d
			_place(), _drag, get_parent_area_size().y, SETTLE).set_ease(Tween.EASE_IN)
		_settle.tween_callback(close)   # (from where the pull left it: on down, off the screen)
		return
	# From where it is now, eased to its new height (a pull of the difference shows it at its old height).
	_drag = 0.0
	_place()
	_drag = size.y - before
	if not tall:
		_drag = minf(_drag, 0.0)   # (compact only grows from a pull up)
	_place()
	_settle = create_tween()
	_settle.tween_method(func(d: float) -> void:
		_drag = d
		_place(), _drag, 0.0, SETTLE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not visible:
		return
	if get_parent_area_size() != _area:
		_place()
	elif not tall and _drag == 0.0 and size.y > get_combined_minimum_size().y + 1.0:
		_place()   # (what it says shrank without telling: a wrapped line that learnt its width; fitted again)
	if _dirty:   # (however many changes in a frame: refilled once)
		_dirty = false
		_since = 0.0
		_refill()
		return
	_since += delta
	if _since >= TICK:
		_since = 0.0
		var o := Game.object_by_uid(_uid)
		if o.is_empty():
			close()
		else:
			_clock(o, Game.is_ready(o))


func _on_changed() -> void:
	_dirty = visible


func _build_head(gap: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	_pic = TextureRect.new()
	_pic.custom_minimum_size = Vector2.ONE * UiTheme.size("panel_icon")
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_pic)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	_name = BookPanel.text("", UiTheme.TITLE, UiTheme.color("ink"))
	_name.set_meta(&"title", true)
	_state = BookPanel.text("", UiTheme.BODY, UiTheme.color("soft"))
	var title := HBoxContainer.new()   # (the name, and an ⓘ for its details: BookPanel.more_button)
	_name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.add_child(_name)
	_more = BookPanel.more_button()
	title.add_child(_more)
	words.add_child(title)
	words.add_child(_state)
	row.add_child(words)
	_ring = ProgressRing.new()
	_ring.custom_minimum_size = Vector2.ONE * UiTheme.size("panel_icon") * 0.7
	_ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_ring)
	_move = _small(tr("TOOL_MOVE"))
	_move.pressed.connect(_on_move)
	row.add_child(_move)
	_turn = _small(tr("TURN"))
	_turn.pressed.connect(func() -> void: Game.rotate_object(_uid))
	row.add_child(_turn)
	_sell = _small(tr("TOOL_SELL"))
	_sell.pressed.connect(_on_sell)
	row.add_child(_sell)
	var shut := UiKit.close_button()
	shut.pressed.connect(close)
	row.add_child(shut)
	return row


## The next size, as a small card: its picture and what it adds.
func _build_next(gap: int) -> Control:
	_next_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color("track").lightened(0.45)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(10)
	_next_card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	_next_pic = TextureRect.new()
	_next_pic.custom_minimum_size = Vector2.ONE * UiTheme.size("panel_icon") * 0.8
	_next_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_next_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_next_pic)
	_next = BookPanel.text("", UiTheme.BODY, UiTheme.color("ink"))
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_next)
	_next_card.add_child(row)
	return _next_card


func _build_numbers(gap: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	var fill := VBoxContainer.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar = UiKit.word_bar()   # (the count on the bar itself: one thing, not words over a bar)
	fill.add_child(_bar)
	row.add_child(fill)
	_fill_block = fill
	_pay = HBoxContainer.new()
	_pay.add_theme_constant_override("separation", gap / 2)
	row.add_child(_pay)
	_pay.add_child(BookPanel.text(tr("SHEET_PAYS"), UiTheme.BODY, UiTheme.color("soft")))   # "Pays +4.3k (coin) +84"
	_coins = _number(_pay, "coin")
	_xp = _number(_pay, "star")
	return row


## A picture and a number beside it (what the home pays).
func _number(row: HBoxContainer, icon_kind: String) -> Label:
	var icon := UiIcon.make(icon_kind, UiTheme.size("panel_icon") * 0.42)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var label := BookPanel.text("", UiTheme.HEADING, UiTheme.color("ink"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return label


func _build_actions(gap: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	_collect = hud.panel_button(tr("COLLECT"))
	_collect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.primary(_collect)   # (the one main action: the accent, as every panel's)
	_collect.pressed.connect(_on_main)
	row.add_child(_collect)
	_fill = hud.panel_button("")
	_fill.pressed.connect(func() -> void: Game.homes.fill_building(_uid))
	row.add_child(_fill)
	return row


## A small quiet button (Move, Turn, Sell): the kit's, as on every panel.
func _small(words: String) -> Button:
	return UiKit.quiet_button(words, BookPanel.font_px(16))


## Sets everything the sheet says from the home as it is now. Nothing is built here but the row of who lives in
## it, and that only when who lives in it has changed.
func _refill() -> void:
	var o := Game.object_by_uid(_uid)
	if o.is_empty() or not suits(o):
		close()
		return
	var id := str(o["id"])
	_kind = kind_of(o)
	var home := _kind == Kind.HOME
	var total := Game.inside_total(o) if home else 0
	var cap := Game.capacity(o) if home else 0
	var ready := Game.is_ready(o)
	_pic.texture = ItemIcons.of(id)
	_name.text = Game.size_name(o) if Game.is_building_item(id) else Game.name_of(id)
	_clock(o, ready)
	_numbers(o, total, cap)
	if not _counting:
		var pay := Game.object_payout(o)
		_coins.text = UiTheme.signed(pay.x)
		_xp.text = UiTheme.signed(pay.y)
	var key := str(o.get("inside", {}))
	if key != _inside_key:
		_inside_key = key
		for c in _inside.get_children():
			c.queue_free()
		var held: Array = []
		for kind: String in o.get("inside", {}):
			held.append([kind, "×%d" % int(o["inside"][kind])])   # not-ui (a count)
		if not held.is_empty():
			var held_row := UiKit.count_row(held, false)   # (the picture and the count: no cut-off names)
			held_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_inside.add_child(held_row)
	_inside_scroll.visible = home and total > 0
	_specs = _specs_for(o)
	_tabs.set_tabs(_specs.map(func(spec: Array) -> String: return str(spec[0])))
	_fill_extras(o)
	_fill_page()
	var room := Game.homes.room_for_loose(o) if home else 0
	_fill.visible = room > 0   # (nothing that would move in, none loose or no room: no button, not a grey one)
	_fill.text = HudBuildings.move_in_words(o, room)
	var building := Game.is_building_item(id)   # (an animal, a bloom, a vehicle: moved by a press and hold, not here)
	_turn.visible = building and Game.buildings.can_rotate(o).ok()   # (what can never turn has no Turn)
	if _sell.has_meta(&"sure") and not _counting and _sell.text == tr("TOOL_SELL"):
		_sell.remove_meta(&"sure")
	var reasons: Array[String] = []
	var verdicts: Array = [[_move, Game.buildings.can_move(o)], [_sell, Game.buildings.can_sell(o)]] if building \
		else []
	_move.visible = building
	_sell.visible = building
	for pair: Array in verdicts:
		var verdict: BuildingSystem.Verdict = pair[1]
		(pair[0] as Button).disabled = not verdict.ok()
		# (What is never sold, the Barn, has no Sell and no word about it, as what never turns has no Turn.)
		(pair[0] as Button).visible = verdict.why != BuildingSystem.Why.KEPT
		if not verdict.ok() and verdict.why != BuildingSystem.Why.KEPT and verdict.text != "" \
				and not reasons.has(verdict.text):
			reasons.append(verdict.text)
	_note.text = "\n".join(PackedStringArray(reasons))
	_note.visible = not reasons.is_empty()
	_next.text = _next_size(o, cap) if home else ""
	_next_card.visible = _next.text != ""
	if _next_card.visible:
		_next_pic.texture = ItemIcons.sized(id, Game.level_of(o) + 1)


## What the clock alone changes, set every second while the sheet is up: how long until ready (its line, its
## ring) and the big button, which says what it is waiting for when it can't be pressed. A building that never
## pays has neither ring nor button.
func _clock(o: Dictionary, ready: bool) -> void:
	if _kind != Kind.HOME:
		_clock_other(o)
		return
	_state.text = hud.buildings.state_line(o)
	_state.visible = true
	_detail.visible = false
	var cycle := maxf(float(Game.cycle_of(o)), 1.0)
	var along := clampf(1.0 - Game.seconds_until_ready(o) / cycle, 0.0, 1.0) if Game.inside_total(o) > 0 else 0.0
	_ring.share = 1.0 if ready else along
	var pays := Game.object_payout(o) != Vector2i.ZERO or ready
	_pay.visible = pays
	# The ring is the time to wait, with it written inside; nothing inside to wait for: no ring at all.
	_ring.visible = pays and (ready or Game.inside_total(o) > 0)
	_ring.words = "" if ready else FarmGrid.format_duration(Game.seconds_until_ready(o))
	# One fact once: while waiting, the ring says how long (no line, no greyed button saying it again); ready,
	# the big button says Collect.
	_collect.visible = pays and ready
	_collect.disabled = false
	_collect.text = tr("COLLECT")
	_collect.modulate.a = 1.0
	_state.visible = not (_ring.visible and not ready) and not _collect.visible


## What the next size of home `o` adds, in a line ("" at its biggest size): more spaces, and the one new thing
## on the building that tells the sizes apart (a silo, a chute, a stall, a second floor).
func _next_size(o: Dictionary, cap: int) -> String:
	var id := str(o["id"])
	var level := Game.level_of(o)
	if level >= Game.max_level(id):
		return ""
	var bigger := o.duplicate()
	bigger["level"] = level + 1
	var line := tr("SHEET_NEXT_SPACES") % [Game.size_name(bigger), Game.capacity(bigger) - cap]
	var now := BuildingModel.spec(id, level)
	var then := BuildingModel.spec(id, level + 1)
	for add: Array in ADDS:
		if _count(then, str(add[0])) > _count(now, str(add[0])):
			return line + tr("SHEET_AND") + tr(str(add[1]))
	return line


## How many of `what` a building's numbers hold: a second floor, or a feature (its `count`, else one each).
static func _count(spec: Dictionary, what: String) -> int:
	if what == "upper":
		return 0 if (spec.get("upper", {}) as Dictionary).is_empty() else 1
	var n := 0
	for f: Dictionary in spec.get("features", []):
		if f.get("type") == what:
			n += int(f.get("count", 1))
	return n


func _on_collect() -> void:
	var r := Game.collect(_uid)
	if r.is_empty():
		return
	hud.show_message(tr("COINS_XP") % [r["coins"], r["xp"]])
	_counting = true
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _coins.text = UiTheme.signed(int(v)),   # (a sum)
		0.0, float(r["coins"]), COUNT_UP)
	tween.tween_callback(func() -> void:
		_counting = false
		_refill())


func _on_move() -> void:
	var o := Game.object_by_uid(_uid)
	var uid := _uid
	close()
	if hud.grid != null and not o.is_empty():
		hud.grid.start_placing(str(o["id"]), uid)


func _on_sell() -> void:
	var o := Game.object_by_uid(_uid)
	if o.is_empty():
		return
	if not _sell.has_meta(&"sure"):   # (selling asks twice)
		_sell.set_meta(&"sure", true)
		_sell.text = tr("SELL_FOR_COINS") % UiTheme.number(Game.sell_value(o))
		return
	var uid := _uid
	close()
	Game.sell_object(uid)


## The big button: what this building is for, right now.
func _on_main() -> void:
	var o := Game.object_by_uid(_uid)
	if o.is_empty():
		return
	match _kind:
		Kind.HOME:
			_on_collect()
		Kind.CRAFT:
			Game.crafting.finish_crafts(_uid)   # (only shown with something done; the sheet refills from the change)
		Kind.BUILD:
			Game.land.add_materials(_uid)


## The line with a bar: a home's spaces, a crafting building's slots in use, a site's materials, the Barn's
## storage; a building with none of these has no such line.
func _numbers(o: Dictionary, total: int, cap: int) -> void:
	var shown := true
	match _kind:
		Kind.HOME:
			UiKit.set_bar(_bar, total, cap, tr("OF_SPACES_USED") % [total, cap])
			shown = cap > 0
		Kind.CRAFT:
			shown = false   # (its slots say it: its Make page)
		Kind.BUILD:
			UiKit.set_bar(_bar, roundi(Game.land.construction_progress(o) * 100.0), 100, tr("SHEET_MATERIALS"))
		Kind.BARN:
			var held := Game.storage.stored.size()
			UiKit.set_bar(_bar, held, Game.storage.barn_capacity(),
				tr("OF_SPACES_USED") % [held, Game.storage.barn_capacity()])
		_:
			shown = false
	_fill_block.modulate.a = 1.0 if shown else 0.0   # (the pay beside it keeps the row's place)
	(_fill_block.get_parent() as Control).visible = shown or _pay.visible


## The clock's part for a building that isn't a home: its state and ring, its lines (a crafting building's slots,
## a site's materials), and what its big button says.
func _clock_other(o: Dictionary) -> void:
	_pay.visible = false
	_ring.visible = false
	_collect.visible = true
	_collect.disabled = false
	_collect.modulate.a = 1.0
	var state: String = hud.buildings.state_line(o) if Game.is_building_item(str(o["id"])) else FarmGrid.status_of(o)
	var lines: Array[String] = []
	match _kind:
		Kind.CRAFT:
			var done := Game.crafting.crafts_done(o)
			var soonest := -1
			var took := 1   # (how long the soonest craft takes in all: the ring shows its share done)
			for slot: Dictionary in o.get("slots", []):
				var left := int(slot["done"]) - Game.now()
				if left > 0 and (soonest < 0 or left < soonest):
					soonest = left
					took = int(slot.get("took", left))
			if done > 0:
				state = tr("READY_TO_COLLECT")
			elif soonest > 0:
				state = tr("STATE_READY_IN") % FarmGrid.format_duration(soonest)
				_ring.visible = true
				_ring.share = clampf(1.0 - float(soonest) / maxf(float(took), 1.0), 0.0, 1.0)
				_ring.words = FarmGrid.format_duration(soonest)
				state = ""   # (the ring says it)
			else:
				state = ""   # (its empty slots say it)
			_collect.text = tr("CRAFT_COLLECT_N") % done
			_collect.visible = done > 0   # (making is a tap on a recipe: the big button only collects)
		Kind.BUILD:
			var need: Dictionary = Game.item_data(o["id"]).get("build_materials", {})
			var have: Dictionary = o.get("construction", {})
			for m: String in need:
				lines.append(tr("OF_YOU_HOLD") % [GameState.part_names.get(m, m), int(have.get(m, 0)), int(need[m]),
					int(Game.parts.get(m, 0))])
			_collect.text = tr("ADD_MY_MATERIALS")
		_:
			_collect.visible = false   # (the Barn, a store: what it does is on its pages, no big button)
	_state.text = state
	_state.visible = state != ""
	_detail.text = "\n".join(PackedStringArray(lines))
	_detail.visible = not lines.is_empty()


## The little bar at the top of the sheet that says it can be dragged.
class Handle:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE   # (the sheet takes the drag)

	func _draw() -> void:
		var h := BuildingSheet.HANDLE.y * UiTheme.scale()
		var r := Rect2(Vector2(0, 0), Vector2(size.x, h))
		draw_style_box(_pill(h), r)

	static func _pill(h: float) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTheme.color("track")
		sb.set_corner_radius_all(int(h / 2.0))
		return sb
