class_name BuildingSheet
extends PanelContainer
## A tapped home's sheet: a compact card that slides up from the bottom of the screen, the farm still in view
## above it. What you came for is the one big button (Collect); how full the home is, what it pays (a coin and a
## star, not a sentence), a ring for how long until it is ready, and what its next size adds are each a glance.
## Move and Sell are small; everything else a home can do (feed, its own extras, building the next size) is one
## tap away in its full panel (More).
##
## Built once and kept: opening it for another home, and every change while it is open, only sets its words,
## bars and pictures (`_refill`); nothing is thrown away and built again. Its picture is ItemIcons' own (made
## once per item and kept).

const ACCENT := Color("#4fb043")       # the one colour that means "do this"
const PAPER := Color("#fbf6ea")
const INK := Color("#4a3728")
const SOFT := Color("#8a7763")
const TRACK := Color("#e6dcc6")
const SLIDE := 0.18                    # seconds the sheet takes to slide in
const COUNT_UP := 0.6                  # seconds a collected sum takes to count up
const WIDTH_SHARE := 0.62              # of the screen's width..
const WIDTH_LEAST := 560.0             # ..but never narrower than this
const EDGE := 14.0                     # its gap from the bottom of the screen
const TICK := 1.0                      # seconds between looks at the clock while open
const ADDS := [["upper", "ADDS_FLOOR"], ["silo", "ADDS_SILO"], ["egg_chutes", "ADDS_CHUTE"],
	["stall_doors", "ADDS_STALL"]]   # what a next size adds, most telling first: [what, its words]

var hud: FarmHud
var _uid := -1
var _pic: TextureRect
var _name: Label
var _state: Label
var _ring: Ring
var _spaces: Label
var _bar: ProgressBar
var _inside: HBoxContainer
var _inside_key := ""
var _coins: Label
var _xp: Label
var _next: Label
var _note: Label
var _collect: Button
var _fill: Button
var _move: Button
var _sell: Button
var _turn: Button
var _fill_block: Control
var _next_card: PanelContainer
var _next_pic: TextureRect
var _pay: Control
var _since := 0.0
var _counting := false
var _dirty := false   # the farm changed while the sheet was up: refill it this frame


func _init(owner: FarmHud) -> void:
	hud = owner
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(26)
	sb.set_content_margin_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 14
	add_theme_stylebox_override("panel", sb)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -EDGE
	var gap := int(UiTheme.size("hud_gap"))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	add_child(column)
	column.add_child(_build_head(gap))
	column.add_child(_build_numbers(gap))
	_inside = HBoxContainer.new()
	column.add_child(_inside)
	column.add_child(_build_next(gap))
	_note = BookPanel.text("", 16, UiTheme.color("price_short"))
	column.add_child(_note)
	column.add_child(_build_actions(gap))
	Game.objects_changed.connect(_on_changed)


## Whether thing `o` opens in the sheet: a finished home (a building site, and a home for finds, keep their panel).
static func suits(o: Dictionary) -> bool:
	return Game.is_home(o) and not Game.under_construction(o) \
		and str(Game.item_data(o["id"]).get("special", "")) != "finds_home"


func open(uid: int) -> void:
	_uid = uid
	_inside_key = ""
	_sell.remove_meta(&"sure")
	_sell.text = tr("TOOL_SELL")
	custom_minimum_size.x = maxf(get_parent_area_size().x * WIDTH_SHARE, WIDTH_LEAST)
	_refill()
	if _uid < 0:
		return
	var shown := visible
	visible = true
	if shown:
		return   # (already up: another home tapped, it only changes what it says)
	await get_tree().process_frame
	var rest := get_parent_area_size().y - size.y - EDGE
	position.y = get_parent_area_size().y
	create_tween().tween_property(self, "position:y", rest, SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT)


func close() -> void:
	visible = false
	_uid = -1


func _process(delta: float) -> void:
	if not visible:
		return
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
	_name = BookPanel.text("", 24, INK)
	_state = BookPanel.text("", 17, SOFT)
	words.add_child(_name)
	words.add_child(_state)
	row.add_child(words)
	_ring = Ring.new()
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
	var shut := _small("×")   # not-ui (a symbol)
	shut.pressed.connect(close)
	row.add_child(shut)
	return row


## The next size, as a small card: its picture and what it adds.
func _build_next(gap: int) -> Control:
	_next_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = TRACK.lightened(0.45)
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
	_next = BookPanel.text("", 17, INK)
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
	_spaces = BookPanel.text("", 18, INK)
	fill.add_child(_spaces)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 14
	var track := StyleBoxFlat.new()
	track.bg_color = TRACK
	track.set_corner_radius_all(7)
	var done := StyleBoxFlat.new()
	done.bg_color = ACCENT
	done.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("background", track)
	_bar.add_theme_stylebox_override("fill", done)
	fill.add_child(_bar)
	row.add_child(fill)
	_fill_block = fill
	_pay = HBoxContainer.new()
	_pay.add_theme_constant_override("separation", gap / 2)
	row.add_child(_pay)
	_coins = _number(_pay, "coin")
	_xp = _number(_pay, "star")
	return row


## A picture and a number beside it (what the home pays).
func _number(row: HBoxContainer, icon_kind: String) -> Label:
	var icon := UiIcon.make(icon_kind, UiTheme.size("panel_icon") * 0.42)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var label := BookPanel.text("", 22, INK)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return label


func _build_actions(gap: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	_collect = hud._panel_button(tr("COLLECT"))
	_collect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state: String in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = ACCENT if state != "pressed" else ACCENT.darkened(0.12)
		sb.set_corner_radius_all(18)
		_collect.add_theme_stylebox_override(state, sb)
	_collect.add_theme_color_override("font_color", Color.WHITE)
	_collect.add_theme_color_override("font_hover_color", Color.WHITE)
	_collect.add_theme_color_override("font_pressed_color", Color.WHITE)
	_collect.pressed.connect(_on_collect)
	row.add_child(_collect)
	_fill = hud._panel_button("")
	_fill.pressed.connect(func() -> void: Game.homes.fill_building(_uid))
	row.add_child(_fill)
	var more := hud._panel_button(tr("SHEET_MORE"))
	more.pressed.connect(_on_more)
	row.add_child(more)
	return row


## A small quiet button (Move, Sell, close): there, but not what the sheet is about.
func _small(words: String) -> Button:
	var b := Button.new()
	b.text = words
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", BookPanel.font_px(16))
	b.add_theme_color_override("font_color", SOFT)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_disabled_color", TRACK.darkened(0.15))
	return b


## Sets everything the sheet says from the home as it is now. Nothing is built here but the row of who lives in
## it, and that only when who lives in it has changed.
func _refill() -> void:
	var o := Game.object_by_uid(_uid)
	if o.is_empty() or not suits(o):
		close()
		return
	var id := str(o["id"])
	var total := Game.inside_total(o)
	var cap := Game.capacity(o)
	var ready := Game.is_ready(o)
	_pic.texture = ItemIcons.of(id)
	_name.text = Game.size_name(o)
	_clock(o, ready)
	_fill_block.modulate.a = 1.0 if cap > 0 else 0.0   # (a building that holds nothing: no bar, the row keeps its place)
	_spaces.text = tr("OF_SPACES_USED") % [total, cap]
	_bar.max_value = maxi(cap, 1)
	_bar.value = total
	if not _counting:
		var pay := Game.object_payout(o)
		_coins.text = FarmHud._thousands(pay.x)
		_xp.text = str(pay.y)
	var key := str(o.get("inside", {}))
	if key != _inside_key:
		_inside_key = key
		for c in _inside.get_children():
			c.queue_free()
		var held: Array = []
		for kind: String in o.get("inside", {}):
			held.append([kind, "×%d" % int(o["inside"][kind])])   # not-ui (a count)
		if not held.is_empty():
			var held_row := UiKit.count_row(held)
			held_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_inside.add_child(held_row)
	_inside.visible = total > 0
	var loose := Game.homes.loose_matching(o) if id != "beehive" else 0
	_fill.visible = loose > 0   # (nothing to move in: no button, not a grey one)
	_fill.text = HudBuildings.move_in_words(o, loose)
	_turn.visible = Game.buildings.can_rotate(o).ok()   # (what can never turn has no Turn)
	if _sell.has_meta(&"sure") and not _counting and _sell.text == tr("TOOL_SELL"):
		_sell.remove_meta(&"sure")
	var reasons: Array[String] = []
	for pair: Array in [[_move, Game.buildings.can_move(o)], [_sell, Game.buildings.can_sell(o)]]:
		var verdict: BuildingSystem.Verdict = pair[1]
		(pair[0] as Button).disabled = not verdict.ok()
		# (What is never sold, the Barn, has no Sell and no word about it, as what never turns has no Turn.)
		(pair[0] as Button).visible = verdict.why != BuildingSystem.Why.KEPT
		if not verdict.ok() and verdict.why != BuildingSystem.Why.KEPT and verdict.text != "" \
				and not reasons.has(verdict.text):
			reasons.append(verdict.text)
	_note.text = "\n".join(PackedStringArray(reasons))
	_note.visible = not reasons.is_empty()
	_next.text = _next_size(o, cap)
	_next_card.visible = _next.text != ""
	if _next_card.visible:
		_next_pic.texture = ItemIcons.sized(id, Game.level_of(o) + 1)


## What the clock alone changes, set every second while the sheet is up: how long until ready (its line, its
## ring) and the big button, which says what it is waiting for when it can't be pressed. A building that never
## pays has neither ring nor button.
func _clock(o: Dictionary, ready: bool) -> void:
	_state.text = hud.buildings.state_line(o)
	var cycle := maxf(float(Game.cycle_of(o)), 1.0)
	var along := clampf(1.0 - Game.seconds_until_ready(o) / cycle, 0.0, 1.0) if Game.inside_total(o) > 0 else 0.0
	_ring.share = 1.0 if ready else along
	var pays := Game.object_payout(o) != Vector2i.ZERO or ready
	_pay.visible = pays
	_ring.visible = pays
	_collect.visible = pays
	_collect.disabled = not ready
	_collect.text = tr("COLLECT") if ready else _state.text
	_collect.modulate.a = 1.0 if ready else 0.5


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
	tween.tween_method(func(v: float) -> void: _coins.text = "+" + FarmHud._thousands(int(v)),   # not-ui (a sum)
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
		_sell.text = tr("SELL_FOR_COINS") % FarmHud._thousands(Game.sell_value(o))
		return
	var uid := _uid
	close()
	Game.sell_object(uid)


func _on_more() -> void:
	var o := Game.object_by_uid(_uid)
	if o.is_empty():
		return
	hud.open_building_panel(_uid)   # (which closes this sheet)


## How far along a home is, as a ring that fills.
class Ring:
	extends Control

	var share := 0.0: set = _set_share

	func _set_share(value: float) -> void:
		share = value
		queue_redraw()

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0 - 4.0
		draw_arc(size / 2.0, r, 0.0, TAU, 40, TRACK, 6.0, true)
		if share > 0.0:
			draw_arc(size / 2.0, r, -PI / 2.0, -PI / 2.0 + TAU * share, 40, ACCENT, 6.0, true)
