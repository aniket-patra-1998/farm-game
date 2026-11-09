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
var _fert_all_button: Button
var _vehicle_row: HBoxContainer
var _vehicle_buttons := {} # vehicle id -> Button
var _fuel_button: Button
var _level_popup: LevelUpPopup
var _placing_bar: PanelContainer
var _placing_label: Label

var _building_uid := -1


var _shown_coins := -1.0   # the number the coin counter shows while it rolls toward Game.coins

var _coin_roll: Tween




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

	for entry in [[tr("MARKET"), _show_market], [tr("COLLECTIONS"), _show_collections], [tr("RIBBONS"), _show_ribbons]]:
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
	_fuel_button.pressed.connect(func() -> void: _book.open_panel(tr("FUEL"), _build_fuel))
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
	_book.open_panel(tr("COLLECTIONS"), _build_collections)




func _show_ribbons() -> void:
	_book.open_panel(tr("RIBBONS"), _build_ribbons)




func _show_market() -> void:
	_book.open_panel(tr("MARKET"), _build_market)




## Opened when a building that isn't ready is tapped.
func show_building(uid: int) -> void:
	_building_uid = uid
	var o := Game.object_by_uid(uid)
	if o.is_empty():
		return
	if o["id"] == "barn":
		_book.open_panel(tr("BARN"), _build_barn)
	elif Game.crafting.is_crafting(o):
		Game.crafting.finish_crafts(uid)
		_book.open_panel(Game.size_name(o), _build_crafting)
	else:
		_book.open_panel(Game.item_data(o["id"])["name"], _build_building)




func _refresh_unwither() -> void:
	if not _unwither_button:
		return
	if _farmhand_button:
		_farmhand_button.text = tr("FARMHAND_LEFT") % Game.farmhands
		_farmhand_button.disabled = Game.farmhands <= 0
		_arborist_button.text = tr("ARBORIST_LEFT") % Game.arborists
		_arborist_button.disabled = Game.arborists <= 0
	if _fert_all_button:
		_fert_all_button.text = tr("FERTILIZE_ALL_LEFT") % Game.fertilize_alls
		_fert_all_button.disabled = Game.fertilize_alls <= 0
	if Game.unwithers > 0:
		_unwither_button.text = tr("UNWITHER_LEFT") % Game.unwithers
	else:
		_unwither_button.text = tr("UNWITHER_GEMS") % GameState.UNWITHER_GEM_COST




func _build_market(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text(tr("LAND"), 26, BookPanel.SUN))
	content.add_child(_land_card())
	content.add_child(_mystery_box_card())
	content.add_child(BookPanel.text(
		tr("BUY_THEN_DRAG_ONTO_AN_OPEN"), 20, BookPanel.CREAM))
	for section in [
		["tree", tr("TREES")],
		["animal", tr("ANIMALS")],
		["building", tr("BUILDINGS")],
		["crafting", tr("CRAFTING")],
		["vehicle", tr("VEHICLES")],
		["decor", tr("DECORATIONS")]
	]:
		content.add_child(BookPanel.text(section[1], 26, BookPanel.SUN))
		for id in Game.item_order:
			var it := Game.item_data(id)
			if it["kind"] != section[0] or int(it["unlock_level"]) >= 99:
				continue
			content.add_child(_market_row(id, it))




## FarmVille's Mystery Box: one random prize, and the only way to get a Donkey.
func _mystery_box_card() -> Control:
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	inner.add_child(BookPanel.text(tr("MYSTERY_BOX"), 22))
	inner.add_child(
		BookPanel.text(
			tr("ONE_SURPRISE_INSIDE_A_RARE_DECORATION"),
			17
		)
	)
	var cost := int(Game.mystery.box_data.get("gem_cost", MysterySystem.MYSTERY_BOX_GEM_COST))
	var buy := _panel_button(tr("OPEN_ONE_GEMS") % cost)
	buy.disabled = Game.gems < cost
	buy.pressed.connect(func() -> void:
		var prize := Game.mystery.buy_mystery_box()
		if prize != "":
			show_message(tr("YOU_GOT") + prize)
			_book.refresh())
	inner.add_child(buy)
	return BookPanel.card_frame(inner)




## A crafting building: slots in use, recipes by star, goods made, bushels and the Farmers Market.
func _build_crafting(content: VBoxContainer) -> void:
	var o := Game.object_by_uid(_building_uid)
	if o.is_empty():
		_book.close_panel()
		return
	var uid := _building_uid
	var lvl := Game.level_of(o)
	# Slots
	var top := BookPanel.card()
	top.add_child(
		BookPanel.text(
			tr("OF_STARS_CRAFTING_SLOTS_RECIPE_MASTERY") % [
				lvl,
				lvl,
				Game.crafting.building_recipe_stars(o["id"])
			],
			20
		)
	)
	for slot in o.get("slots", []):
		var left := int(slot["done"]) - Game.now()
		var what := tr("SLOT_READY") if left <= 0 else tr("READY_IN_3") + FarmGrid.format_duration(left)
		top.add_child(BookPanel.text("%s: %s" % [Game.catalog.get_def(slot["r"]).name, what], 18))
	if Game.crafting.free_slots(o) > 0:
		top.add_child(
			BookPanel.text(
				(tr("ONE_FREE_SLOT_PICK_A_RECIPE") if Game.crafting.free_slots(o) == 1
					else tr("FREE_SLOTS_PICK_A_RECIPE_BELOW")) % Game.crafting.free_slots(o),
				18,
				BookPanel.CREAM
			)
		)
	content.add_child(BookPanel.card_frame(top))
	# Recipes
	content.add_child(BookPanel.text(tr("RECIPES"), 26, BookPanel.SUN))
	for r in Game.crafting.recipes_of(o["id"]):
		content.add_child(_recipe_row(uid, o, r))
	# Goods
	content.add_child(BookPanel.text(tr("YOUR_GOODS"), 26, BookPanel.SUN))
	var any_goods := false
	for r in Game.crafting.recipes_of(o["id"]):
		var n := int(Game.crafting.goods.get(r.id, 0))
		if n <= 0:
			continue
		any_goods = true
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 10)
		row.add_child(BookPanel.text("%d %s" % [n, r.name], 20))
		var rid := r.id
		var sell := _panel_button(tr("SELL_COINS") % _thousands(Game.crafting.good_price(rid)))
		sell.pressed.connect(func() -> void:
			Game.crafting.sell_good(rid)
			_book.refresh())
		row.add_child(sell)
		var use := _panel_button(tr("USE_FUEL") % Game.crafting.good_fuel(rid))
		use.pressed.connect(func() -> void:
			show_message(tr("FUEL_2") % Game.crafting.use_good(rid))
			_book.refresh())
		row.add_child(use)
		content.add_child(BookPanel.card_frame(row))
	if not any_goods:
		content.add_child(
			BookPanel.text(
				tr("NOTHING_YET_FINISHED_CRAFTS_LAND_HERE"),
				17,
				BookPanel.CREAM
			)
		)
	# Stars
	var cost := Game.crafting.star_cost(o)
	if not cost.is_empty():
		var up := BookPanel.card()
		var have := Game.crafting.building_recipe_stars(o["id"])
		up.add_child(BookPanel.text(tr("NEXT_STAR_COINS_AND_RECIPE_MASTERY") % [
			_thousands(int(cost["coins"])), int(cost["recipe_stars"]), have, int(cost["gems"])], 18))
		var row2 := HFlowContainer.new()
		row2.add_theme_constant_override("h_separation", 10)
		var with_coins := _panel_button(tr("UPGRADE_WITH_COINS"))
		with_coins.disabled = not Game.crafting.can_add_star(uid, false)
		with_coins.pressed.connect(func() -> void:
			Game.crafting.add_star(uid, false)
			_book.refresh())
		row2.add_child(with_coins)
		var with_gems := _panel_button(tr("UPGRADE_GEMS") % int(cost["gems"]))
		with_gems.disabled = not Game.crafting.can_add_star(uid, true)
		with_gems.pressed.connect(func() -> void:
			Game.crafting.add_star(uid, true)
			_book.refresh())
		row2.add_child(with_gems)
		up.add_child(row2)
		content.add_child(BookPanel.card_frame(up))
	# Bushels and the Farmers Market
	content.add_child(
		BookPanel.text(
			tr("BUSHELS_OF") % [Game.crafting.total_bushels(), CraftingSystem.BUSHEL_CAP],
			26,
			BookPanel.SUN
		)
	)
	var held: Array[String] = []
	for c in Game.crafting.bushels:
		held.append("%d %s" % [int(Game.crafting.bushels[c]), Game.crops[c]["name"]])
	content.add_child(
		BookPanel.text(
			", ".join(PackedStringArray(held)) if not held.is_empty() else tr("NONE_YET_HARVESTS_DROP_BUSHELS_OF"),
			17,
			BookPanel.CREAM
		)
	)
	content.add_child(BookPanel.text(tr("FARMERS_MARKET_TODAY"), 22, BookPanel.SUN))
	var stall := Game.crafting.market_stall()
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	for c in stall:
		var crop_id: String = c
		var b := _panel_button(
			tr("LEFT_COINS") % [Game.crops[crop_id]["name"], int(stall[c]), Game.crafting.bushel_price(crop_id)]
		)
		var full := Game.crafting.total_bushels() >= CraftingSystem.BUSHEL_CAP
		b.disabled = int(stall[c]) <= 0 or Game.coins < Game.crafting.bushel_price(crop_id) or full
		b.pressed.connect(func() -> void:
			Game.crafting.buy_bushel(crop_id)
			_book.refresh())
		flow.add_child(b)
	content.add_child(flow)




func _recipe_row(uid: int, o: Dictionary, r: RecipeDef) -> Control:
	var inner := VBoxContainer.new()
	var unlocked := Game.crafting.recipe_unlocked(o, r.id)
	var stars := Game.crafting.recipe_stars(r.id)
	inner.add_child(BookPanel.text(r.name + (tr("MASTERY_OF") % stars if stars > 0 else ""), 20))
	var need: Array[String] = []
	for c in r.inputs():
		need.append("%d/%d %s" % [int(Game.crafting.bushels.get(c, 0)), int(r.inputs()[c]), Game.crops[c]["name"]])
	inner.add_child(BookPanel.text(", ".join(PackedStringArray(need)), 17))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	if not unlocked:
		row.add_child(BookPanel.text(tr("UNLOCKS_AT_STARS") % r.star(), 17, BookPanel.CREAM))
	else:
		var make := _panel_button(tr("MAKE_IT"))
		make.disabled = Game.crafting.craft_problem(uid, r.id) != ""
		var rid := r.id
		make.pressed.connect(func() -> void:
			Game.crafting.start_craft(uid, rid)
			_book.refresh())
		row.add_child(make)
		var missing := Game.crafting.missing_bushels(r.id)
		if not missing.is_empty() and Game.crafting.free_slots(o) > 0:
			var n := 0
			for c in missing:
				n += int(missing[c])
			var buy := _panel_button(tr("BUY_MISSING_GEMS") % (n * CraftingSystem.BUSHEL_GEM_COST))
			buy.disabled = Game.gems < n * CraftingSystem.BUSHEL_GEM_COST
			buy.pressed.connect(func() -> void:
				Game.crafting.buy_missing_and_craft(uid, rid)
				_book.refresh())
			row.add_child(buy)
	inner.add_child(row)
	return BookPanel.card_frame(inner)




func _land_card() -> Control:
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	var step := Game.land.next_expansion()
	var size := Game.farm_size
	if step.is_empty():
		inner.add_child(BookPanel.text(tr("YOUR_FARM_IS_FULL_SIZE_X") % [size, size], 22))
		return BookPanel.card_frame(inner)
	var next := int(step["size"])
	inner.add_child(BookPanel.text(tr("EXPAND_FROM_X_TO_X") % [size, size, next, next], 22))
	inner.add_child(BookPanel.text(
		tr("ADDS_PLOTS_THE_DASHED_AREA_ON") % (next * next - size * size), 17))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 12)
	var with_coins := _panel_button("")
	if Game.level() < int(step["level"]):
		with_coins.text = tr("COINS_REACH_LEVEL") % int(step["level"])
		with_coins.disabled = true
	else:
		with_coins.text = tr("EXPAND_COINS") % _thousands(int(step["coins"]))
		with_coins.disabled = Game.coins < int(step["coins"])
	with_coins.pressed.connect(func() -> void: Game.land.expand(false))
	row.add_child(with_coins)
	var with_gems := _panel_button(tr("EXPAND_NOW_GEMS") % int(step["gems"]))
	with_gems.disabled = Game.gems < int(step["gems"])
	with_gems.pressed.connect(func() -> void: Game.land.expand(true))
	row.add_child(with_gems)
	inner.add_child(row)
	return BookPanel.card_frame(inner)




func _market_row(id: String, it: Dictionary) -> Control:
	var locked := Game.level() < int(it["unlock_level"])
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(BookPanel.text(it["name"], 22))
	var detail: String
	match it["kind"]:
		"building":
			var holds: String
			if it.has("holds_kind"):
				holds = tr("HOLDS_VEHICLES") if it["holds_kind"] == "vehicle" else tr("FRUIT_TREES")
			else:
				var names: Array[String] = []
				for a in it["holds"]:
					names.append(Game.item_data(a)["name"].to_lower() + "s")
				holds = ", ".join(PackedStringArray(names))
			var fp := Game.footprint(id)
			detail = tr("HOLDS_X_TILES_UPGRADES_TO") % [
				int(it["levels"][0]), holds, fp.x, fp.y, int(it["levels"][-1])]
		"crafting":
			detail = tr("CRAFTING_RECIPES_OVER_STARS_PER_CRAFT") % FarmGrid.format_duration(int(it.get("craft_seconds", 21600)))
		"vehicle":
			var verbs := {
				"plow": tr("PLOWS"),
				"plant": tr("PLANTS"),
				"harvest": tr("HARVESTS"),
				"all": tr("HARVESTS_PLOWS_AND_PLANTS")
			}
			detail = tr("X_PLOTS_A_TAP_FUEL_A") % [
				verbs.get(it["job"], ""),
				int(it.get("fuel_per_plot", 1))
			]
			if it.has("build_materials"):
				detail += tr("CHASSIS_FINISHED_WITH_VEHICLE_PARTS") % int(it["build_materials"]["vehicle_parts"])
		"decor":
			var fpd := Game.footprint(id)
			detail = tr("DECORATION_XP_X_SELLS_FOR") % [
				Game.buy_xp(id),
				fpd.x,
				fpd.y,
				int(round(int(it["cost"]) * GameState.SELL_SHARE))
			]
		_:
			var what: String = it.get("product", tr("FRUIT"))
			detail = tr("EVERY_COINS_XP") % [
				what, FarmGrid.format_duration(int(it["cycle_seconds"])), int(it["payout"]), int(it["xp"])]
	info.add_child(BookPanel.text(detail, 17))
	inner.add_child(info)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(150, 52)
	buy.focus_mode = Control.FOCUS_NONE
	if locked:
		buy.text = tr("LEVEL") % int(it["unlock_level"])
		buy.disabled = true
	else:
		if it["kind"] == "crafting":
			var price := Game.crafting.crafting_price(id)
			buy.text = ("%d gems" % int(price["gems"])) if price.has("gems") else "%s coins" % _thousands(int(price["coins"]))
		else:
			buy.text = ("%d gems" % int(it["gem_cost"])) if it.has("gem_cost") else (
				"%s coins" % _thousands(int(it["cost"])) if int(it["cost"]) > 0 else tr("FREE_FRAME")
			)
		buy.disabled = not Game.can_afford_item(id)
		buy.pressed.connect(func() -> void:
			_book.close_panel()
			place_requested.emit(id))
	inner.add_child(buy)
	return BookPanel.card_frame(inner)




func _build_building(content: VBoxContainer) -> void:
	var o := Game.object_by_uid(_building_uid)
	if o.is_empty():
		_book.close_panel()
		return
	var uid := _building_uid
	if Game.under_construction(o):
		_build_construction(content, o, uid)
		return
	var total := Game.inside_total(o)
	var cap := Game.capacity(o)
	var pay := Game.object_payout(o)

	var status := BookPanel.card()
	status.add_theme_constant_override("separation", 8)
	status.add_child(BookPanel.text(tr("OF_SPACES_USED") % [Game.size_name(o), total, cap], 22))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 18
	bar.max_value = cap
	bar.value = total
	status.add_child(bar)
	var inside: Dictionary = o["inside"]
	if inside.is_empty():
		status.add_child(BookPanel.text(tr("EMPTY_MOVE_ANIMALS_IN_TO_START"), 18))
	else:
		var names: Array[String] = []
		for id in inside:
			names.append("%d %s" % [int(inside[id]), Game.item_data(id)["name"]])
		status.add_child(BookPanel.text(tr("INSIDE").join(PackedStringArray(names)), 18))
		if total > 0:
			var when := tr("READY_TO_COLLECT") if Game.is_ready(o) \
				else tr("READY_IN_4") + FarmGrid.format_duration(Game.seconds_until_ready(o))
			status.add_child(BookPanel.text(tr("PAYS_COINS_XP") % [when, pay.x, pay.y], 18))
	content.add_child(BookPanel.card_frame(status))

	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 12)
	actions.add_theme_constant_override("v_separation", 12)
	if Game.is_ready(o):
		var collect := _panel_button(tr("COLLECT"))
		collect.pressed.connect(func() -> void:
			var r := Game.collect(uid)
			if not r.is_empty():
				show_message(tr("COINS_XP") % [r["coins"], r["xp"]]))
		actions.add_child(collect)
	if o["id"] != "beehive":
		var loose := Game.homes.loose_matching(o)
		var fill := _panel_button(tr("MOVE_IN") % loose if loose > 0 else tr("NONE_ON_FARM"))
		fill.disabled = loose == 0
		fill.pressed.connect(func() -> void: Game.homes.fill_building(uid))
		actions.add_child(fill)
	content.add_child(actions)

	_add_building_special_info(content, o)
	_add_expansion_card(content, o, uid)




## Frame being built: what's in, what's missing, and a button to add held materials.
func _build_construction(content: VBoxContainer, o: Dictionary, uid: int) -> void:
	var it := Game.item_data(o["id"])
	content.add_child(
		BookPanel.text(
			tr("THIS_IS_A_BUILDING_FRAME_FINISH"),
			19,
			BookPanel.CREAM
		)
	)
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	var need: Dictionary = it.get("build_materials", {})
	var have: Dictionary = o["construction"]
	for m in need:
		var got := int(have.get(m, 0))
		var want := int(need[m])
		card.add_child(
			BookPanel.text(
				tr("OF_YOU_HOLD") % [GameState.part_names[m], got, want, int(Game.parts.get(m, 0))],
				19
			)
		)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 14
		bar.max_value = want
		bar.value = got
		card.add_child(bar)
	content.add_child(BookPanel.card_frame(card))
	var add := _panel_button(tr("ADD_MY_MATERIALS"))
	add.pressed.connect(func() -> void: Game.land.add_materials(uid))
	content.add_child(add)




## What makes this building special, the FarmVille way.
func _add_building_special_info(content: VBoxContainer, o: Dictionary) -> void:
	var it := Game.item_data(o["id"])
	match it.get("special", ""):
		"mystery_eggs":
			content.add_child(
				BookPanel.text(
					tr("HARVESTING_CAN_TURN_UP_MYSTERY_EGGS"),
					17,
					BookPanel.CREAM
				)
			)
			var eggs := HFlowContainer.new()
			eggs.add_theme_constant_override("h_separation", 10)
			eggs.add_theme_constant_override("v_separation", 10)
			for colour in Game.mystery.egg_data.get("colours", {}):
				var n := int(Game.mystery.mystery_eggs.get(colour, 0))
				if n <= 0:
					continue
				var b := _panel_button(tr("OPEN") % [Game.mystery.egg_data["colours"][colour]["name"], n])
				var c: String = colour
				b.pressed.connect(func() -> void:
					var prize := Game.mystery.open_mystery_egg(c)
					if prize != "":
						show_message(tr("YOU_GOT") + prize))
				eggs.add_child(b)
			if eggs.get_child_count() > 0:
				content.add_child(eggs)
		"calves":
			var bull := tr("A_BULL_LIVES_HERE_HARVESTS_CAN") if Game.has_inside(o, "bull") else tr("NO_BULL_YET_A_LONELY_BULL")
			content.add_child(
				BookPanel.text(bull + tr("HARVESTS_SOMETIMES_LEAVE_A_BAG_OF"), 17, BookPanel.CREAM)
			)
		"foals":
			var st := tr("A_STALLION_LIVES_HERE_HARVESTS_CAN") if Game.has_inside(o, "stallion") \
				else tr("NO_STALLION_YET_A_WANDERING_STALLION")
			content.add_child(
				BookPanel.text(
					tr("HORSES_HERE_ARE_READY_EVERY_DAY") + st + tr("HARVESTS_CAN_ALSO_GIVE_FARMHANDS_AND"),
					17,
					BookPanel.CREAM
				)
			)
		"nursery":
			var grow := int(it.get("grow_days", 4))
			var lines: Array[String] = []
			for baby in o.get("growing", []):
				lines.append(tr("OF_DAYS") % [Game.item_data(baby[0])["name"], int(baby[1]), grow])
			var txt := tr("CALVES_AND_FOALS_GROW_UP_HERE") % grow
			if not lines.is_empty():
				txt += "\n\n".join(PackedStringArray(lines))
			content.add_child(BookPanel.text(txt, 17, BookPanel.CREAM))
		"beehive":
			_add_hive_info(content, o)
		"truffles":
			_add_pig_pen_info(content, o)
		"garage":
			_add_garage_info(content)
		"garden_shed":
			_add_shed_info(content)
		"saplings":
			content.add_child(
				BookPanel.text(
					tr("HARVESTS_CAN_SPROUT_A_RARE_SAPLING"),
					17,
					BookPanel.CREAM
				)
			)




## The Garden Shed: Perfect Bunches found while harvesting flowers, ready to place for 14 days.
func _add_shed_info(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text(tr("PERFECT_BUNCHES_OF_HARVESTING_FLOWERS_SOMETIMES") % [
		Game.shed.bunches.size(), Game.shed.bunch_cap(), BarnStorage.BUNCH_DAYS], 17, BookPanel.CREAM))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	for k in Game.shed.bunches.size():
		var flower: String = Game.shed.bunches[k]
		var b := _panel_button(tr("PLACE") % Game.crops[flower]["name"])
		var idx := k
		b.pressed.connect(func() -> void:
			var at := Game.shed.unpack_bunch(idx)
			if at >= 0:
				_book.close_panel()
				place_stored_requested.emit(at))
		flow.add_child(b)
	content.add_child(flow)




func _add_garage_info(content: VBoxContainer) -> void:
	content.add_child(
		BookPanel.text(
			tr("VEHICLE_PARTS_HELD_THEY_TURN_UP") % int(Game.parts.get("vehicle_parts", 0)),
			17,
			BookPanel.CREAM
		)
	)
	var owned := Game.vehicles.owned_vehicles()
	if owned.is_empty():
		content.add_child(
			BookPanel.text(tr("NO_VEHICLES_YET_BUY_A_TRACTOR"), 18, BookPanel.CREAM)
		)
		return
	for id in owned:
		var it := Game.item_data(id)
		var area := Game.vehicles.vehicle_area(id)
		var card := BookPanel.card()
		card.add_theme_constant_override("separation", 6)
		card.add_child(
			BookPanel.text(
				tr("WORKS_X_PLOTS_UPGRADE_OF") % [
					it["name"],
					area.x,
					area.y,
					Game.vehicles.vehicle_level(id)
				],
				21
			)
		)
		var cost := Game.vehicles.vehicle_upgrade_cost(id)
		var vid: String = id
		if cost < 0:
			card.add_child(BookPanel.text(tr("FULLY_UPGRADED"), 18))
		else:
			var next: Vector2i = GameState.VEHICLE_SIZES[Game.vehicles.vehicle_level(id) + 1]
			var need_lvl := Game.vehicles.vehicle_upgrade_level_needed(id)
			var line := tr("NEXT_X_FOR_VEHICLE_PARTS") % [next.x, next.y, cost]
			if need_lvl > Game.level():
				line += tr("LEVEL_3") % need_lvl
			card.add_child(BookPanel.text(line, 18))
			var up := _panel_button(tr("UPGRADE"))
			up.disabled = not Game.vehicles.can_upgrade_vehicle(id)
			up.pressed.connect(func() -> void: Game.vehicles.upgrade_vehicle(vid))
			card.add_child(up)
		content.add_child(BookPanel.card_frame(card))




func _build_fuel(content: VBoxContainer) -> void:
	var fuel := Game.vehicles.fuel_now()
	content.add_child(
		BookPanel.text(
			tr("ALL_VEHICLES_SHARE_ONE_TANK_OF") % [
				VehicleSystem.FUEL_TANK,
				int(VehicleSystem.FUEL_REGEN_SECONDS / 60.0)
			],
			18,
			BookPanel.CREAM
		)
	)
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	card.add_child(
		BookPanel.text(
			tr("TANK_OF_SPARE_TANKS") % [fuel, VehicleSystem.FUEL_TANK, Game.vehicles.fuel_tanks],
			21
		)
	)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 18
	bar.max_value = VehicleSystem.FUEL_TANK
	bar.value = fuel
	card.add_child(bar)
	var buy := _panel_button(tr("BUY_A_FULL_TANK_GEMS") % VehicleSystem.FUEL_TANK_GEM_COST)
	buy.disabled = Game.gems < VehicleSystem.FUEL_TANK_GEM_COST
	buy.pressed.connect(func() -> void: Game.vehicles.buy_fuel_tank())
	card.add_child(buy)
	content.add_child(BookPanel.card_frame(card))




## One toolbar button per vehicle type you own, with its area and the fuel left.
func _refresh_vehicles() -> void:
	if not _vehicle_row:
		return
	var owned := Game.vehicles.owned_vehicles()
	for id in _vehicle_buttons.keys():
		if not owned.has(id):
			(_vehicle_buttons[id] as Button).queue_free()
			_vehicle_buttons.erase(id)
	for id in owned:
		if not _vehicle_buttons.has(id):
			var b := _tool_button("")
			var vid: String = id
			b.pressed.connect(func() -> void: tool_selected.emit("vehicle", vid))
			_vehicle_row.add_child(b)
			_vehicle_buttons[id] = b
		var area := Game.vehicles.vehicle_area(id)
		(_vehicle_buttons[id] as Button).text = tr("X_FUEL") % [
			Game.item_data(id)["name"],
			area.x,
			area.y,
			int(Game.item_data(id).get("fuel_per_plot", 1)) * area.x * area.y
		]
	_fuel_button.visible = Game.vehicles.fuel_unlocked
	_fuel_button.text = tr("FUEL_TANKS") % [
		Game.vehicles.fuel_now(),
		VehicleSystem.FUEL_TANK,
		Game.vehicles.fuel_tanks
	]




func _add_hive_info(content: VBoxContainer, o: Dictionary) -> void:
	var uid := int(o["uid"])
	if Game.bees.has_queen(o):
		content.add_child(BookPanel.text(tr("THE_QUEEN_BEE_LIVES_HERE_WORKER") % Game.capacity(o), 17, BookPanel.CREAM))
	else:
		content.add_child(
			BookPanel.text(
				tr("THIS_HIVE_NEEDS_A_QUEEN_BEE"),
				17,
				BookPanel.CREAM
			)
		)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 12)
		var put := _panel_button(tr("ADD_QUEEN_BEE_HELD") % Game.bees.queen_bees)
		put.disabled = Game.bees.queen_bees <= 0
		put.pressed.connect(func() -> void: Game.bees.add_queen(uid))
		row.add_child(put)
		var buy := _panel_button(tr("BUY_QUEEN_BEE_GEMS") % BeehiveSystem.QUEEN_GEM_COST)
		buy.disabled = Game.gems < BeehiveSystem.QUEEN_GEM_COST
		buy.pressed.connect(func() -> void: Game.bees.add_queen(uid, true))
		row.add_child(buy)
		content.add_child(row)
	content.add_child(
		BookPanel.text(
			tr("POLLINATION_HARVESTING_A_FERTILIZED_CROP_HAS") % [
				int(round(Game.bees.pollination_chance() * 100)),
				BeehiveSystem.BEES_STAY_DAYS
			],
			17,
			BookPanel.CREAM
		)
	)




func _add_pig_pen_info(content: VBoxContainer, o: Dictionary) -> void:
	var uid := int(o["uid"])
	var pigs := Game.inside_total(o)
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	card.add_child(BookPanel.text(tr("TRUFFLES_HELD") % Game.pigpen.truffles, 21))
	if not Game.pigpen.is_foraging(o):
		card.add_child(BookPanel.text(tr("FEED_THE_PIGS_SLOP_AND_THEY") % PigPenSystem.PIGS_PER_TRUFFLE, 17))
		var feed := _panel_button(tr("FEED_SLOP_COINS") % PigPenSystem.SLOP_COST)
		feed.disabled = pigs == 0 or Game.coins < PigPenSystem.SLOP_COST
		feed.pressed.connect(func() -> void: Game.pigpen.feed_slop(uid))
		card.add_child(feed)
	elif Game.pigpen.forage_seconds_left(o) > 0:
		card.add_child(
			BookPanel.text(tr("FORAGING_BACK_IN") + FarmGrid.format_duration(Game.pigpen.forage_seconds_left(o)), 18)
		)
	else:
		var dig := _panel_button(tr("COLLECT_TRUFFLES"))
		dig.pressed.connect(func() -> void:
			var n := Game.pigpen.collect_truffles(uid)
			if n > 0:
				show_message(tr("TRUFFLES") % n))
		card.add_child(dig)
	card.add_child(BookPanel.text(tr("TRADE_TRUFFLES_FOR_A_RARE_PIG") % PigPenSystem.TRUFFLES_PER_PIG, 18))
	var breeds := HFlowContainer.new()
	breeds.add_theme_constant_override("h_separation", 10)
	breeds.add_theme_constant_override("v_separation", 10)
	for id in Game.pigpen.rare_pigs():
		var b := _panel_button(Game.item_data(id)["name"])
		b.disabled = Game.pigpen.truffles < PigPenSystem.TRUFFLES_PER_PIG
		var breed: String = id
		b.pressed.connect(func() -> void: Game.pigpen.trade_truffles(breed))
		breeds.add_child(b)
	card.add_child(breeds)
	content.add_child(BookPanel.card_frame(card))




## Next size and its material cost.
func _add_expansion_card(content: VBoxContainer, o: Dictionary, uid: int) -> void:
	var need := Game.land.expansion_needs(o)
	if need.is_empty():
		content.add_child(BookPanel.text(tr("FULLY_EXPANDED"), 18, BookPanel.CREAM))
		return
	var lvl := Game.level_of(o)
	var levels: Array = Game.item_data(o["id"])["levels"]
	var names: Array = Game.item_data(o["id"]).get("level_names", [])
	var next_name: String = names[lvl] if lvl < names.size() else tr("NEXT_SIZE")
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 6)
	card.add_child(BookPanel.text(tr("EXPAND_TO_HOLDS") % [next_name, int(levels[lvl])], 21))
	for m in need:
		card.add_child(
			BookPanel.text(
				tr("OF") % [
					GameState.part_names[m],
					mini(int(Game.parts.get(m, 0)), int(need[m])),
					int(need[m])
				],
				18
			)
		)
	var up := _panel_button(tr("EXPAND"))
	up.disabled = not Game.land.can_expand(o)
	up.pressed.connect(func() -> void: Game.land.upgrade_building(uid))
	card.add_child(up)
	content.add_child(BookPanel.card_frame(card))




func _build_barn(content: VBoxContainer) -> void:
	var b := Game.storage.barn()
	if b.is_empty():
		_book.close_panel()
		return
	if b.get("broken", false):
		_build_barn_repair(content)
	else:
		_build_barn_storage(content)




func _build_barn_repair(content: VBoxContainer) -> void:
	var it := Game.item_data("barn")
	content.add_child(BookPanel.text(
		tr("THIS_OLD_BARN_NEEDS_FIXING_COLLECT"), 20, BookPanel.CREAM))
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 10)
	var need := Game.storage.repair_needs()
	for p in GameState.part_ids:
		var want := int(need.get(p, 0))
		var have := int(Game.parts.get(p, 0))
		card.add_child(BookPanel.text(tr("OF_2") % [GameState.part_names[p], mini(have, want), want], 20))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 16
		bar.max_value = want
		bar.value = mini(have, want)
		card.add_child(bar)
	card.add_child(
		BookPanel.text(
			tr("REWARD_COINS_XP_AND_A_BARN") % [
				int(it.get("repair_coins", 0)),
				int(it.get("repair_xp", 0))
			],
			17
		)
	)
	content.add_child(BookPanel.card_frame(card))
	var fix := _panel_button(tr("REPAIR_THE_BARN") if Game.storage.can_repair_barn() else tr("NOT_ENOUGH_PARTS_YET"))
	fix.disabled = not Game.storage.can_repair_barn()
	fix.pressed.connect(func() -> void: Game.storage.repair_barn())
	content.add_child(fix)




func _build_barn_storage(content: VBoxContainer) -> void:
	var cap := Game.storage.barn_capacity()
	content.add_child(BookPanel.text(
		tr("HOLDS_OF_USE_THE_STORE_TOOL") % [Game.storage.stored.size(), cap], 20, BookPanel.CREAM))
	var parts_line: Array[String] = []
	for p in GameState.part_ids:
		parts_line.append("%s %d" % [GameState.part_names[p], int(Game.parts.get(p, 0))])
	content.add_child(BookPanel.text(tr("PARTS").join(PackedStringArray(parts_line)), 17, BookPanel.CREAM))
	if Game.storage.stored.is_empty():
		content.add_child(BookPanel.card_frame(BookPanel.text(tr("NOTHING_STORED_YET"), 20)))
		return
	for k in Game.storage.stored.size():
		var o: Dictionary = Game.storage.stored[k]
		var row := HBoxContainer.new()
		var label := BookPanel.text(Game.item_data(o["id"])["name"], 22)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var place := _panel_button(tr("PLACE_2"))
		var index := k
		place.pressed.connect(func() -> void:
			_book.close_panel()
			place_stored_requested.emit(index))
		row.add_child(place)
		content.add_child(BookPanel.card_frame(row))




func _panel_button(words: String) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size = Vector2(180, 56)
	b.focus_mode = Control.FOCUS_NONE
	return b




func _build_collections(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text(
		tr("ITEMS_TURN_UP_WHILE_YOU_FARM"), 20, BookPanel.CREAM))
	for coll in Game.collectibles.collections:
		var inner := BookPanel.card()
		inner.add_theme_constant_override("separation", 10)

		var crop_names: Array[String] = []
		for crop_id in coll.get("crops", []):
			crop_names.append(Game.crops[crop_id]["name"])
		var head := HBoxContainer.new()
		var title := BookPanel.text(coll["name"], 26)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var trade := Button.new()
		trade.text = tr("TRADE_IN")
		trade.custom_minimum_size = Vector2(140, 48)
		trade.focus_mode = Control.FOCUS_NONE
		trade.disabled = not Game.collectibles.can_trade_in(coll)
		var coll_id: String = coll["id"]
		trade.pressed.connect(func() -> void: Game.collectibles.trade_in(coll_id))
		head.add_child(trade)
		inner.add_child(head)

		if coll.get("birds", false):
			inner.add_child(BookPanel.text(tr("BIRDS_CAN_LAND_DURING_ANY_HARVEST"), 18))
		elif coll.get("source", "") == "trees":
			inner.add_child(BookPanel.text(tr("FOUND_WHILE_HARVESTING_TREES"), 18))
		elif coll.get("source", "") == "animals":
			inner.add_child(BookPanel.text(tr("FOUND_WHILE_COLLECTING_FROM_ANIMALS_AND"), 18))
		else:
			inner.add_child(BookPanel.text(tr("FOUND_WHILE_HARVESTING").join(PackedStringArray(crop_names)), 18))

		var items := HFlowContainer.new()
		items.add_theme_constant_override("h_separation", 8)
		items.add_theme_constant_override("v_separation", 8)
		var need := Game.collectibles.coll_need(coll)
		for item in coll["items"]:
			var count := int(Game.collectibles.owned.get(item["id"], 0))
			var rarity: String = item.get("rarity", "common")
			var label: String = "%s  %d/%d%s" % [
				item["name"],
				count,
				int(need[item["id"]]),
				"" if rarity == "common" else "  (" + rarity + ")"
			]
			items.add_child(BookPanel.chip(label, count >= int(need[item["id"]])))
		inner.add_child(items)

		var reward := Game.collectibles.coll_reward(coll)
		inner.add_child(
			BookPanel.text(
				tr("LEVEL_REWARD_COINS_XP_AND") % [
					Game.collectibles.coll_level(coll) + 1,
					int(reward["coins"]),
					int(reward["xp"]),
					_prize_text(reward["prize"])
				],
				18
			)
		)
		content.add_child(BookPanel.card_frame(inner))




## A prize ([kind, amount or item]) in words, for reward lines.
func _prize_text(prize: Array) -> String:
	match str(prize[0]):
		"item":
			return "a " + str(Game.item_data(str(prize[1])).get("name", prize[1]))
		"fertilize_all":
			return tr("FERTILIZE_ALL") % int(prize[1])
		"unwither":
			return tr("UNWITHER") % int(prize[1])
		"fuel":
			return "%d fuel" % int(prize[1])
	return "%d %s" % [int(prize[1]), str(prize[0]).capitalize()]




func _build_ribbons(content: VBoxContainer) -> void:
	var data: Dictionary = Game.ribbons.ribbon_data
	var tier_names: Array = data.get("tiers", [])
	content.add_child(BookPanel.text(
		tr("EACH_RIBBON_HAS_FOUR_TIERS_YELLOW"), 20, BookPanel.CREAM))
	for r in data.get("ribbons", []):
		var earned := int(Game.ribbons.ribbon_tiers.get(r["id"], 0))
		var thresholds: Array = r["thresholds"]
		var value := Game.ribbons.stat(r["stat"])

		var inner := BookPanel.card()
		inner.add_theme_constant_override("separation", 8)
		var head := HBoxContainer.new()
		var title := BookPanel.text(r["name"], 26)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var tiers := HBoxContainer.new()
		tiers.add_theme_constant_override("separation", 6)
		for k in tier_names.size():
			tiers.add_child(BookPanel.chip(tier_names[k], k < earned))
		head.add_child(tiers)
		inner.add_child(head)

		var line: String
		if earned >= thresholds.size():
			line = tr("COMPLETE") % [value, r["what"]]
		else:
			var goal := int(thresholds[earned])
			line = tr("FOR") % [mini(value, goal), goal, r["what"], tier_names[earned]]
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size.y = 18
			bar.max_value = goal
			bar.value = mini(value, goal)
			inner.add_child(BookPanel.text(line, 18))
			inner.add_child(bar)
			content.add_child(BookPanel.card_frame(inner))
			continue
		inner.add_child(BookPanel.text(line, 18))
		content.add_child(BookPanel.card_frame(inner))




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
