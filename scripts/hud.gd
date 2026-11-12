class_name FarmHud
extends CanvasLayer
## Top bar (coins, level, XP), bottom toolbar (tools and seeds) and short messages.
## Built in code so it scales cleanly between phone and tablet.

signal tool_selected(tool: String, crop_id: String)
signal place_requested(item_id: String)
signal cancel_place_requested

signal place_stored_requested(index: int)


const TOP_H := 84.0
const BOTTOM_H := 150.0

const BUTTON_SIZE := Vector2(150, 112)
const GROUP_PAGE := 30     # rows of a long grouped list (the barn) built at a time
const LEVEL_UP_BUZZ := 60     # ms of vibration for a level up
const COIN_LAND_DB := -8.0  # each landing coin chinks softly; a shower of them adds up

const WOOD := Color("#7a4f2c")
const WOOD_DARK := Color("#5c3a1e")
const CREAM := Color("#fbefd2")
const INK := Color("#3a2614")
const SUN := Color("#ffd34d")

const LOCKED := Color("#d8cbb0")


var _coins_label: Label
var _gems_label: Label
var _clock_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _toast: Label
var _toast_tween: Tween
var _toast_holder: CenterContainer
var _tutorial: Label
var _reset_button: Button
var _tool_group := ButtonGroup.new()
var _seed_buttons := {} # crop id -> Button
var _book: BookPanel
var _unwither_button: Button
var _farmhand_button: Button
var _arborist_button: Button
var _gardener_button: Button
var _fert_all_button: Button
var _vehicle_row: HBoxContainer
var _fuel_button: Button
var _level_popup: LevelUpPopup
var _placing_bar: PanelContainer
var _placing_label: Label

var _building_uid := -1


var _shown_coins := -1.0   # the number the coin counter shows while it rolls toward Game.coins

var _coin_roll: Tween

# The panels moved out of this class (scripts/hud/): each builds its content into the book.
@onready var market := HudMarket.new(self)
@onready var crafting := HudCrafting.new(self)
@onready var buildings := HudBuildings.new(self)
@onready var barn := HudBarn.new(self)
@onready var books := HudBooks.new(self)
@onready var settings := HudSettings.new(self)


func _ready() -> void:
	layer = 10 # above the sky, the farm and the night lights
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_top_bar(root)
	_build_toolbar(root)
	_build_tutorial(root)
	_build_toast(root)
	_build_placing_bar(root)
	_book = BookPanel.new()
	root.add_child(_book)
	_level_popup = LevelUpPopup.new()
	root.add_child(_level_popup)
	Game.leveled_up.connect(_level_popup.celebrate)
	Game.leveled_up.connect(func(_l: int) -> void:
		Sound.play("level_up")
		Sound.buzz(LEVEL_UP_BUZZ))
	Game.collections_changed.connect(_refresh_book)
	Game.ribbons_changed.connect(_refresh_book)
	Game.objects_changed.connect(_refresh_book)
	Game.coins_changed.connect(func(_c: int) -> void: _refresh_book())
	Game.coins_changed.connect(func(_c: int) -> void: _refresh())
	Game.gems_changed.connect(func(_g: int) -> void: _refresh())
	Game.inventory_changed.connect(_refresh_unwither)
	Game.inventory_changed.connect(_refresh_seed_buttons)
	Game.inventory_changed.connect(_refresh_vehicles)
	Game.objects_changed.connect(_refresh_vehicles)
	Game.inventory_changed.connect(_refresh_book)
	Game.farm_expanded.connect(func(_s: int) -> void: _refresh_book())
	Game.xp_changed.connect(func(_x: int, _l: int) -> void: _refresh())
	Game.leveled_up.connect(func(_l: int) -> void: _refresh_seed_buttons())
	Game.tutorial_changed.connect(func(_s: int) -> void: _refresh_tutorial())
	_refresh()
	_refresh_clock()
	_refresh_tutorial()


# ---------------------------------------------------------------- layout


func _build_top_bar(root: Control) -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size.y = TOP_H
	root.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)

	# Coins on top, gems underneath, so both fit beside the menu buttons.
	var money := VBoxContainer.new()
	money.alignment = BoxContainer.ALIGNMENT_CENTER
	money.add_theme_constant_override("separation", 0)
	row.add_child(money)
	_coins_label = Label.new()
	_coins_label.add_theme_color_override("font_color", SUN)
	_coins_label.add_theme_font_size_override("font_size", 26)
	money.add_child(_coins_label)
	_gems_label = Label.new()
	_gems_label.add_theme_color_override("font_color", Color("#9be7ff"))
	_gems_label.add_theme_font_size_override("font_size", 20)
	money.add_child(_gems_label)

	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 16)
	money.add_child(_clock_label)
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_refresh_clock)
	add_child(tick)

	for entry in [[tr("MARKET"), _show_market], [tr("COLLECTIONS"), _show_collections], [tr("RIBBONS"), _show_ribbons],
			[tr("SETTINGS"), _show_settings]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(104, 56)
		b.add_theme_font_size_override("font_size", 18)
		b.toggle_mode = false
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(entry[1])
		row.add_child(b)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# Level, XP bar and XP numbers stack in one column so the bar fits portrait screens.
	var xp_box := VBoxContainer.new()
	xp_box.alignment = BoxContainer.ALIGNMENT_CENTER
	xp_box.custom_minimum_size.x = 180
	xp_box.add_theme_constant_override("separation", 2)
	row.add_child(xp_box)

	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 22)
	xp_box.add_child(_level_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size.y = 16
	xp_box.add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.add_theme_font_size_override("font_size", 16)
	xp_box.add_child(_xp_label)


func _build_toolbar(root: Control) -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -BOTTOM_H
	bar.offset_bottom = 0
	bar.custom_minimum_size.y = BOTTOM_H
	root.add_child(bar)

	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bar.add_child(scroll)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	scroll.add_child(row)

	var plow := _tool_button(tr("PLOW_COINS") % GameState.PLOW_COST)
	plow.button_pressed = true
	plow.pressed.connect(func() -> void: tool_selected.emit("plow", ""))
	row.add_child(plow)

	var hand := _tool_button(tr("INSPECT_TAP_TO_CHECK"))
	hand.pressed.connect(func() -> void: tool_selected.emit("hand", ""))
	row.add_child(hand)

	var fert := _tool_button(tr("FERTILIZE_COINS") % GameState.FERTILIZER_COST)
	fert.pressed.connect(func() -> void: tool_selected.emit("fertilize", ""))
	row.add_child(fert)

	_fert_all_button = Button.new()
	_fert_all_button.custom_minimum_size = BUTTON_SIZE
	_fert_all_button.focus_mode = Control.FOCUS_NONE
	_fert_all_button.pressed.connect(func() -> void: Game.bees.use_fertilize_all())
	row.add_child(_fert_all_button)

	# Unwither is an action, not a tool, so it isn't part of the tool group.
	_unwither_button = Button.new()
	_unwither_button.custom_minimum_size = BUTTON_SIZE
	_unwither_button.focus_mode = Control.FOCUS_NONE
	_unwither_button.pressed.connect(Game.use_unwither)
	row.add_child(_unwither_button)

	_farmhand_button = Button.new()
	_farmhand_button.custom_minimum_size = BUTTON_SIZE
	_farmhand_button.focus_mode = Control.FOCUS_NONE
	_farmhand_button.pressed.connect(func() -> void: Game.use_helper("animal"))
	row.add_child(_farmhand_button)

	_arborist_button = Button.new()
	_arborist_button.custom_minimum_size = BUTTON_SIZE
	_arborist_button.focus_mode = Control.FOCUS_NONE
	_arborist_button.pressed.connect(func() -> void: Game.use_helper("tree"))
	row.add_child(_arborist_button)

	_gardener_button = Button.new()
	_gardener_button.custom_minimum_size = BUTTON_SIZE
	_gardener_button.focus_mode = Control.FOCUS_NONE
	_gardener_button.pressed.connect(func() -> void: Game.use_helper("bloom"))
	row.add_child(_gardener_button)
	_refresh_unwither()

	var store := _tool_button(tr("STORE_IN_THE_BARN"))
	store.pressed.connect(func() -> void: tool_selected.emit("store", ""))
	row.add_child(store)

	var move := _tool_button(tr("MOVE_BUILDINGS_MORE"))
	move.pressed.connect(func() -> void: tool_selected.emit("move", ""))
	row.add_child(move)

	var turn := _tool_button(tr("ROTATE_TURN_DECORATIONS"))
	turn.pressed.connect(func() -> void: tool_selected.emit("rotate", ""))
	row.add_child(turn)

	var sell := _tool_button(tr("SELL_BACK"))
	sell.pressed.connect(func() -> void: tool_selected.emit("sell", ""))
	row.add_child(sell)

	# Vehicles you own, and the shared fuel tank. Hidden until the first vehicle.
	_vehicle_row = HBoxContainer.new()
	_vehicle_row.add_theme_constant_override("separation", 12)
	row.add_child(_vehicle_row)
	_fuel_button = Button.new()
	_fuel_button.custom_minimum_size = BUTTON_SIZE
	_fuel_button.focus_mode = Control.FOCUS_NONE
	_fuel_button.pressed.connect(func() -> void: _book.open_panel(tr("FUEL"), buildings.build_fuel))
	row.add_child(_fuel_button)
	var fuel_tick := Timer.new()
	fuel_tick.wait_time = 5.0
	fuel_tick.autostart = true
	fuel_tick.timeout.connect(_refresh_vehicles)
	add_child(fuel_tick)
	_refresh_vehicles()

	for id in Game.crop_order:
		var b := _tool_button("")
		var crop_id: String = id
		b.pressed.connect(func() -> void: tool_selected.emit("plant", crop_id))
		_seed_buttons[crop_id] = b
		row.add_child(b)
	_refresh_seed_buttons()

	if OS.is_debug_build():
		var rich := Button.new()
		rich.text = tr("DEBUG_COINS")
		rich.custom_minimum_size = BUTTON_SIZE
		rich.focus_mode = Control.FOCUS_NONE
		rich.pressed.connect(func() -> void: Game.debug_add_coins(10000))
		row.add_child(rich)

		var bees := Button.new()
		bees.text = tr("DEBUG_BEES")
		bees.custom_minimum_size = BUTTON_SIZE
		bees.focus_mode = Control.FOCUS_NONE
		bees.pressed.connect(func() -> void: Game.debug_add_bees(20))
		row.add_child(bees)

		var mats := Button.new()
		mats.text = tr("DEBUG_MATERIALS")
		mats.custom_minimum_size = BUTTON_SIZE
		mats.focus_mode = Control.FOCUS_NONE
		mats.pressed.connect(func() -> void: Game.debug_add_materials(10))
		row.add_child(mats)

		var lvl_up := Button.new()
		lvl_up.text = tr("DEBUG_LEVEL_UP")
		lvl_up.custom_minimum_size = BUTTON_SIZE
		lvl_up.focus_mode = Control.FOCUS_NONE
		lvl_up.pressed.connect(Game.debug_level_up)
		row.add_child(lvl_up)

		var skip := Button.new()
		skip.text = tr("DEBUG_SKIP_H")
		skip.custom_minimum_size = BUTTON_SIZE
		skip.focus_mode = Control.FOCUS_NONE
		skip.pressed.connect(func() -> void: Game.debug_skip(3600))
		row.add_child(skip)

		_reset_button = Button.new()
		_reset_button.text = tr("DEBUG_NEW_FARM")
		_reset_button.custom_minimum_size = BUTTON_SIZE
		_reset_button.focus_mode = Control.FOCUS_NONE
		_reset_button.pressed.connect(_on_reset_pressed)
		row.add_child(_reset_button)


## Two taps to reset, so a stray tap can't wipe the farm.
func _on_reset_pressed() -> void:
	if _reset_button.text.begins_with(tr("TAP_AGAIN")):
		Game.reset_game()
		_reset_button.text = tr("DEBUG_NEW_FARM")
		show_message(tr("STARTED_A_NEW_FARM"))
		return
	_reset_button.text = tr("TAP_AGAIN_TO_RESET")
	get_tree().create_timer(3.0).timeout.connect(_restore_reset_label)


func _restore_reset_label() -> void:
	if is_instance_valid(_reset_button):
		_reset_button.text = tr("DEBUG_NEW_FARM")


func _build_placing_bar(root: Control) -> void:
	_placing_bar = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.border_color = WOOD_DARK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 20
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_placing_bar.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_placing_bar.add_child(row)
	_placing_label = Label.new()
	_placing_label.add_theme_color_override("font_color", INK)
	_placing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_placing_label)
	var cancel := Button.new()
	cancel.text = tr("CANCEL")
	cancel.custom_minimum_size = Vector2(110, 48)
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func() -> void: cancel_place_requested.emit())
	row.add_child(cancel)
	_placing_bar.visible = false
	_top_holder(root, TOP_H + 10).add_child(_placing_bar)


## Shows the placement banner; empty text hides it.
func show_placing(text: String) -> void:
	_placing_label.text = text
	_placing_bar.visible = text != ""
	_refresh_tutorial()


func _build_tutorial(root: Control) -> void:
	_tutorial = Label.new()
	_tutorial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial.add_theme_color_override("font_color", INK)
	_tutorial.add_theme_font_size_override("font_size", 24)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SUN
	sb.border_color = WOOD_DARK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_tutorial.add_theme_stylebox_override("normal", sb)
	_top_holder(root, TOP_H + 12).add_child(_tutorial)


func _refresh_tutorial() -> void:
	var text := Game.tutorial_text()
	_tutorial.text = text
	_tutorial.visible = text != "" and not (_placing_bar and _placing_bar.visible)
	# Keep messages clear of the tutorial banner while it shows.
	var y := TOP_H + (80.0 if _tutorial.visible else 16.0)
	_toast_holder.offset_top = y
	_toast_holder.offset_bottom = y + 60.0


## A full-width strip under the top bar that keeps its child centred whatever its text.
func _top_holder(root: Control, y: float) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = y
	holder.offset_bottom = y + 60.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	return holder


func _build_toast(root: Control) -> void:
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_color_override("font_color", INK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.shadow_size = 4
	_toast.add_theme_stylebox_override("normal", sb)
	_toast.modulate.a = 0.0
	_toast_holder = _top_holder(root, TOP_H + 16)
	_toast_holder.add_child(_toast)


func _tool_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = _tool_group
	b.custom_minimum_size = BUTTON_SIZE
	b.focus_mode = Control.FOCUS_NONE
	return b


# ---------------------------------------------------------------- updates


func show_message(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


# ---------------------------------------------------------------- rolling counters and reward targets


## Where flying coins and XP stars land (screen positions).
func coins_target() -> Vector2:
	return _coins_label.get_global_rect().get_center()


func xp_target() -> Vector2:
	return _xp_bar.get_global_rect().get_center()


## A quick swell as a reward lands on a counter.
func pulse(which: String) -> void:
	if which == "coins":
		Sound.play("coin", COIN_LAND_DB)  # each coin chinks as it lands
	var c: Control = _coins_label if which == "coins" else _xp_bar
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.18, 1.18), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _set_shown_coins(v: float) -> void:
	_shown_coins = v
	_coins_label.text = "%s coins" % _thousands(int(round(v)))


## The coin counter rolls to the new amount instead of jumping (spends snap down at once).
func _roll_coins() -> void:
	if _shown_coins < 0.0 or Game.coins < _shown_coins:
		if _coin_roll != null and _coin_roll.is_valid():
			_coin_roll.kill()
		_set_shown_coins(Game.coins)
		return
	if is_equal_approx(_shown_coins, float(Game.coins)):
		return
	if _coin_roll != null and _coin_roll.is_valid():
		_coin_roll.kill()
	_coin_roll = create_tween()
	_coin_roll.tween_method(
		_set_shown_coins,
		_shown_coins,
		float(Game.coins),
		0.75
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	var lvl := Game.level()
	var lo := Game.xp_for_level(lvl)
	var hi := Game.xp_for_level(lvl + 1)
	_roll_coins()
	_gems_label.text = "%d gems" % Game.gems
	_level_label.text = tr("LEVEL") % lvl
	_xp_bar.min_value = lo
	_xp_bar.max_value = hi
	# The bar fills smoothly; on a level-up it starts again from the new level.
	if Game.xp < _xp_bar.value or Game.xp > hi:
		_xp_bar.value = Game.xp
	else:
		var tw := _xp_bar.create_tween()
		tw.tween_property(_xp_bar, "value", float(Game.xp), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_xp_label.text = tr("XP_2") % [Game.xp, hi]


static func _thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


func _refresh_clock() -> void:
	var hour := DayCycle.local_hour(Game.now(), DayCycle.device_bias_minutes())
	_clock_label.text = "%s · %s · %s" % [
		tr("SEASON_" + DayCycle.SEASON.to_upper()),
		tr(Game.weather()["name"]),
		DayCycle.clock_text(hour)
	]


func _refresh_seed_buttons() -> void:
	for id in _seed_buttons:
		var crop: Dictionary = Game.crops[id]
		var b: Button = _seed_buttons[id]
		var pol := Game.bees.pollinated_seeds(id)
		if Game.is_unlocked(id) and pol > 0:
			b.disabled = false
			b.text = tr("POLLINATED_FREE") % [crop["name"], pol]
		elif Game.is_unlocked(id):
			b.disabled = false
			b.text = tr("COINS") % [crop["name"], int(crop["seed_cost"]),
				FarmGrid.format_duration(int(crop["grow_seconds"]))]
		else:
			b.disabled = true
			b.text = tr("LEVEL_2") % [crop["name"], int(crop["unlock_level"])]


# ---------------------------------------------------------------- menus


func _refresh_book() -> void:
	if _book.visible:
		_book.refresh()


func _show_collections() -> void:
	_book.open_panel(tr("COLLECTIONS"), books.build_collections)


func _show_ribbons() -> void:
	_book.open_panel(tr("RIBBONS"), books.build_ribbons)


func _show_settings() -> void:
	_book.open_panel(tr("SETTINGS"), settings.build_settings)


func _show_market() -> void:
	_book.open_panel(tr("MARKET"), market.build_market)


## Opened when a building that isn't ready is tapped.
func show_building(uid: int) -> void:
	_building_uid = uid
	var o := Game.object_by_uid(uid)
	if o.is_empty():
		return
	if Game.nurture.is_young(o):
		_book.open_panel(Game.item_data(o["id"])["name"], barn.build_young)
	elif Game.kind_of(o) == "bloom":
		_book.open_panel(Game.item_data(o["id"])["name"], barn.build_bloom)
	elif o["id"] == "barn":
		_book.open_panel(tr("BARN"), barn.build_barn)
	elif Game.crafting.is_crafting(o):
		Game.crafting.finish_crafts(uid)
		_book.open_panel(Game.size_name(o), crafting.build_crafting)
	else:
		_book.open_panel(Game.item_data(o["id"])["name"], buildings.build_building)


func _refresh_unwither() -> void:
	if not _unwither_button:
		return
	if _farmhand_button:
		_farmhand_button.text = tr("FARMHAND_LEFT") % Game.farmhands
		_farmhand_button.disabled = Game.farmhands <= 0
		_arborist_button.text = tr("ARBORIST_LEFT") % Game.arborists
		_arborist_button.disabled = Game.arborists <= 0
		_gardener_button.text = tr("GARDENER_LEFT") % Game.gardeners
		_gardener_button.disabled = Game.gardeners <= 0
	if _fert_all_button:
		_fert_all_button.text = tr("FERTILIZE_ALL_LEFT") % Game.fertilize_alls
		_fert_all_button.disabled = Game.fertilize_alls <= 0
	if Game.unwithers > 0:
		_unwither_button.text = tr("UNWITHER_LEFT") % Game.unwithers
	else:
		_unwither_button.text = tr("UNWITHER_GEMS") % GameState.UNWITHER_GEM_COST


## One toolbar button per vehicle type you own, with its area and the fuel left.
func _refresh_vehicles() -> void:
	if not _vehicle_row:
		return
	_fuel_button.visible = Game.vehicles.fuel_unlocked
	_fuel_button.text = tr("FUEL_TANKS") % [
		Game.vehicles.fuel_now(),
		VehicleSystem.FUEL_TANK,
		Game.vehicles.fuel_tanks
	]


func _panel_button(words: String) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size = Vector2(180, 56)
	b.focus_mode = Control.FOCUS_NONE
	return b


# ---------------------------------------------------------------- theme


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22

	var panel := StyleBoxFlat.new()
	panel.bg_color = WOOD
	panel.border_color = WOOD_DARK
	panel.set_border_width_all(0)
	panel.border_width_bottom = 4
	panel.content_margin_left = 20
	panel.content_margin_right = 20
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	t.set_stylebox("panel", "PanelContainer", panel)

	t.set_stylebox("normal", "Button", _button_box(CREAM, WOOD_DARK))
	t.set_stylebox("hover", "Button", _button_box(CREAM.lightened(0.3), WOOD_DARK))
	t.set_stylebox("pressed", "Button", _button_box(SUN, INK))
	t.set_stylebox("hover_pressed", "Button", _button_box(SUN, INK))
	t.set_stylebox("disabled", "Button", _button_box(LOCKED, WOOD_DARK))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", INK)
	t.set_color("font_disabled_color", "Button", INK.lightened(0.45))

	t.set_color("font_color", "Label", CREAM)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = WOOD_DARK
	bar_bg.set_corner_radius_all(11)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("#7ccf5a")
	bar_fill.set_corner_radius_all(11)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t


func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	return sb
