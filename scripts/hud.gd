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

	for entry in [["Market", _show_market], ["Collections", _show_collections], ["Ribbons", _show_ribbons]]:
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

	var plow := _tool_button("Plow\n%d coins" % GameState.PLOW_COST)
	plow.button_pressed = true
	plow.pressed.connect(func() -> void: tool_selected.emit("plow", ""))
	row.add_child(plow)

	var hand := _tool_button("Inspect\ntap to check")
	hand.pressed.connect(func() -> void: tool_selected.emit("hand", ""))
	row.add_child(hand)

	var fert := _tool_button("Fertilize\n%d coins · +20%%" % GameState.FERTILIZER_COST)
	fert.pressed.connect(func() -> void: tool_selected.emit("fertilize", ""))
	row.add_child(fert)

	_fert_all_button = Button.new()
	_fert_all_button.custom_minimum_size = BUTTON_SIZE
	_fert_all_button.focus_mode = Control.FOCUS_NONE
	_fert_all_button.pressed.connect(func() -> void: Game.use_fertilize_all())
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

	var store := _tool_button("Store\nin the barn")
	store.pressed.connect(func() -> void: tool_selected.emit("store", ""))
	row.add_child(store)

	var move := _tool_button("Move\nbuildings & more")
	move.pressed.connect(func() -> void: tool_selected.emit("move", ""))
	row.add_child(move)

	# Vehicles you own, and the shared fuel tank. Hidden until the first vehicle.
	_vehicle_row = HBoxContainer.new()
	_vehicle_row.add_theme_constant_override("separation", 12)
	row.add_child(_vehicle_row)
	_fuel_button = Button.new()
	_fuel_button.custom_minimum_size = BUTTON_SIZE
	_fuel_button.focus_mode = Control.FOCUS_NONE
	_fuel_button.pressed.connect(func() -> void: _book.open_panel("Fuel", _build_fuel))
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
		rich.text = "Debug\n+10,000 coins"
		rich.custom_minimum_size = BUTTON_SIZE
		rich.focus_mode = Control.FOCUS_NONE
		rich.pressed.connect(func() -> void: Game.debug_add_coins(10000))
		row.add_child(rich)

		var bees := Button.new()
		bees.text = "Debug\n+20 bees"
		bees.custom_minimum_size = BUTTON_SIZE
		bees.focus_mode = Control.FOCUS_NONE
		bees.pressed.connect(func() -> void: Game.debug_add_bees(20))
		row.add_child(bees)

		var mats := Button.new()
		mats.text = "Debug\n+10 materials"
		mats.custom_minimum_size = BUTTON_SIZE
		mats.focus_mode = Control.FOCUS_NONE
		mats.pressed.connect(func() -> void: Game.debug_add_materials(10))
		row.add_child(mats)

		var lvl_up := Button.new()
		lvl_up.text = "Debug\nlevel up"
		lvl_up.custom_minimum_size = BUTTON_SIZE
		lvl_up.focus_mode = Control.FOCUS_NONE
		lvl_up.pressed.connect(Game.debug_level_up)
		row.add_child(lvl_up)

		var skip := Button.new()
		skip.text = "Debug\nskip 1 h"
		skip.custom_minimum_size = BUTTON_SIZE
		skip.focus_mode = Control.FOCUS_NONE
		skip.pressed.connect(func() -> void: Game.debug_skip(3600))
		row.add_child(skip)

		_reset_button = Button.new()
		_reset_button.text = "Debug\nnew farm"
		_reset_button.custom_minimum_size = BUTTON_SIZE
		_reset_button.focus_mode = Control.FOCUS_NONE
		_reset_button.pressed.connect(_on_reset_pressed)
		row.add_child(_reset_button)


## Two taps to reset, so a stray tap can't wipe the farm.
func _on_reset_pressed() -> void:
	if _reset_button.text.begins_with("Tap again"):
		Game.reset_game()
		_reset_button.text = "Debug\nnew farm"
		show_message("Started a new farm")
		return
	_reset_button.text = "Tap again\nto reset"
	get_tree().create_timer(3.0).timeout.connect(_restore_reset_label)


func _restore_reset_label() -> void:
	if is_instance_valid(_reset_button):
		_reset_button.text = "Debug\nnew farm"


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
	cancel.text = "Cancel"
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


func _refresh() -> void:
	var lvl := Game.level()
	var lo := Game.xp_for_level(lvl)
	var hi := Game.xp_for_level(lvl + 1)
	_coins_label.text = "%s coins" % _thousands(Game.coins)
	_gems_label.text = "%d gems" % Game.gems
	_level_label.text = "Level %d" % lvl
	_xp_bar.min_value = lo
	_xp_bar.max_value = hi
	_xp_bar.value = Game.xp
	_xp_label.text = "%d / %d XP" % [Game.xp, hi]


static func _thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


func _refresh_clock() -> void:
	var hour := DayCycle.local_hour(Game.now(), DayCycle.device_bias_minutes())
	_clock_label.text = "%s · %s" % [DayCycle.SEASON, DayCycle.clock_text(hour)]


func _refresh_seed_buttons() -> void:
	for id in _seed_buttons:
		var crop: Dictionary = Game.crops[id]
		var b: Button = _seed_buttons[id]
		var pol := Game.pollinated_seeds(id)
		if Game.is_unlocked(id) and pol > 0:
			b.disabled = false
			b.text = "%s\n%d pollinated · free" % [crop["name"], pol]
		elif Game.is_unlocked(id):
			b.disabled = false
			b.text = "%s\n%d coins · %s" % [crop["name"], int(crop["seed_cost"]),
				FarmGrid.format_duration(int(crop["grow_seconds"]))]
		else:
			b.disabled = true
			b.text = "%s\nLevel %d" % [crop["name"], int(crop["unlock_level"])]


# ---------------------------------------------------------------- menus

func _refresh_book() -> void:
	if _book.visible:
		_book.refresh()


func _show_collections() -> void:
	_book.open_panel("Collections", _build_collections)


func _show_ribbons() -> void:
	_book.open_panel("Ribbons", _build_ribbons)


func _show_market() -> void:
	_book.open_panel("Market", _build_market)


## Opened when a building that isn't ready is tapped.
func show_building(uid: int) -> void:
	_building_uid = uid
	var o := Game.object_by_uid(uid)
	if o.is_empty():
		return
	if o["id"] == "barn":
		_book.open_panel("Barn", _build_barn)
	else:
		_book.open_panel(Game.item_data(o["id"])["name"], _build_building)


func _refresh_unwither() -> void:
	if not _unwither_button:
		return
	if _farmhand_button:
		_farmhand_button.text = "Farmhand\n%d left" % Game.farmhands
		_farmhand_button.disabled = Game.farmhands <= 0
		_arborist_button.text = "Arborist\n%d left" % Game.arborists
		_arborist_button.disabled = Game.arborists <= 0
	if _fert_all_button:
		_fert_all_button.text = "Fertilize All\n%d left" % Game.fertilize_alls
		_fert_all_button.disabled = Game.fertilize_alls <= 0
	if Game.unwithers > 0:
		_unwither_button.text = "Unwither\n%d left" % Game.unwithers
	else:
		_unwither_button.text = "Unwither\n%d gems" % GameState.UNWITHER_GEM_COST


func _build_market(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text("Land", 26, BookPanel.SUN))
	content.add_child(_land_card())
	content.add_child(BookPanel.text(
		"Buy, then drag onto an open grassy spot and let go. Use the Move tool to rearrange later.", 20, BookPanel.CREAM))
	for section in [["tree", "Trees"], ["animal", "Animals"], ["building", "Buildings"], ["vehicle", "Vehicles"]]:
		content.add_child(BookPanel.text(section[1], 26, BookPanel.SUN))
		for id in Game.item_order:
			var it := Game.item_data(id)
			if it["kind"] != section[0] or int(it["unlock_level"]) >= 99:
				continue
			content.add_child(_market_row(id, it))


func _land_card() -> Control:
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	var step := Game.next_expansion()
	var size := Game.farm_size
	if step.is_empty():
		inner.add_child(BookPanel.text("Your farm is full size: %d x %d." % [size, size], 22))
		return BookPanel.card_frame(inner)
	var next := int(step["size"])
	inner.add_child(BookPanel.text("Expand from %d x %d to %d x %d" % [size, size, next, next], 22))
	inner.add_child(BookPanel.text(
		"Adds %d plots. The dashed area on your farm shows the new land." % (next * next - size * size), 17))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 12)
	var with_coins := _panel_button("")
	if Game.level() < int(step["level"]):
		with_coins.text = "Coins: reach level %d" % int(step["level"])
		with_coins.disabled = true
	else:
		with_coins.text = "Expand: %s coins" % _thousands(int(step["coins"]))
		with_coins.disabled = Game.coins < int(step["coins"])
	with_coins.pressed.connect(func() -> void: Game.expand(false))
	row.add_child(with_coins)
	var with_gems := _panel_button("Expand now: %d gems" % int(step["gems"]))
	with_gems.disabled = Game.gems < int(step["gems"])
	with_gems.pressed.connect(func() -> void: Game.expand(true))
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
				holds = "vehicles" if it["holds_kind"] == "vehicle" else "fruit trees"
			else:
				var names: Array[String] = []
				for a in it["holds"]:
					names.append(Game.item_data(a)["name"].to_lower() + "s")
				holds = ", ".join(PackedStringArray(names))
			var fp := Game.footprint(id)
			detail = "Holds %d %s · %dx%d tiles · upgrades to %d" % [
				int(it["levels"][0]), holds, fp.x, fp.y, int(it["levels"][-1])]
		"vehicle":
			var verbs := {"plow": "Plows", "plant": "Plants", "harvest": "Harvests", "all": "Harvests, plows and plants"}
			detail = "%s 2x2 plots a tap · %d fuel a plot · upgrades to 4x4" % [verbs.get(it["job"], ""), int(it.get("fuel_per_plot", 1))]
			if it.has("build_materials"):
				detail += " · chassis finished with %d Vehicle Parts" % int(it["build_materials"]["vehicle_parts"])
		_:
			var what: String = it.get("product", "Fruit")
			detail = "%s every %s · %d coins, %d XP" % [
				what, FarmGrid.format_duration(int(it["cycle_seconds"])), int(it["payout"]), int(it["xp"])]
	info.add_child(BookPanel.text(detail, 17))
	inner.add_child(info)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(150, 52)
	buy.focus_mode = Control.FOCUS_NONE
	if locked:
		buy.text = "Level %d" % int(it["unlock_level"])
		buy.disabled = true
	else:
		buy.text = ("%d gems" % int(it["gem_cost"])) if it.has("gem_cost") else ("%s coins" % _thousands(int(it["cost"])) if int(it["cost"]) > 0 else "Free frame")
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
	status.add_child(BookPanel.text("%s · %d of %d spaces used" % [Game.size_name(o), total, cap], 22))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 18
	bar.max_value = cap
	bar.value = total
	status.add_child(bar)
	var inside: Dictionary = o["inside"]
	if inside.is_empty():
		status.add_child(BookPanel.text("Empty. Move animals in to start producing.", 18))
	else:
		var names: Array[String] = []
		for id in inside:
			names.append("%d %s" % [int(inside[id]), Game.item_data(id)["name"]])
		status.add_child(BookPanel.text("Inside: " + ", ".join(PackedStringArray(names)), 18))
		if total > 0:
			var when := "Ready to collect!" if Game.is_ready(o) else "Ready in " + FarmGrid.format_duration(Game.seconds_until_ready(o))
			status.add_child(BookPanel.text("%s · pays %d coins, %d XP" % [when, pay.x, pay.y], 18))
	content.add_child(BookPanel.card_frame(status))

	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 12)
	actions.add_theme_constant_override("v_separation", 12)
	if Game.is_ready(o):
		var collect := _panel_button("Collect")
		collect.pressed.connect(func() -> void:
			var r := Game.collect(uid)
			if not r.is_empty():
				show_message("+%d coins, +%d XP" % [r["coins"], r["xp"]]))
		actions.add_child(collect)
	if o["id"] != "beehive":
		var loose := Game.loose_matching(o)
		var fill := _panel_button("Move %d in" % loose if loose > 0 else "None on farm")
		fill.disabled = loose == 0
		fill.pressed.connect(func() -> void: Game.fill_building(uid))
		actions.add_child(fill)
	content.add_child(actions)

	_add_building_special_info(content, o)
	_add_expansion_card(content, o, uid)


## Frame being built: what's in, what's missing, and a button to add held materials.
func _build_construction(content: VBoxContainer, o: Dictionary, uid: int) -> void:
	var it := Game.item_data(o["id"])
	content.add_child(BookPanel.text("This is a building frame. Finish it with building materials, found while harvesting and as daily gifts.", 19, BookPanel.CREAM))
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	var need: Dictionary = it.get("build_materials", {})
	var have: Dictionary = o["construction"]
	for m in need:
		var got := int(have.get(m, 0))
		var want := int(need[m])
		card.add_child(BookPanel.text("%s: %d of %d  (you hold %d)" % [GameState.PART_NAMES[m], got, want, int(Game.parts.get(m, 0))], 19))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 14
		bar.max_value = want
		bar.value = got
		card.add_child(bar)
	content.add_child(BookPanel.card_frame(card))
	var add := _panel_button("Add my materials")
	add.pressed.connect(func() -> void: Game.add_materials(uid))
	content.add_child(add)


## What makes this building special, the FarmVille way.
func _add_building_special_info(content: VBoxContainer, o: Dictionary) -> void:
	var it := Game.item_data(o["id"])
	match it.get("special", ""):
		"mystery_eggs":
			content.add_child(BookPanel.text("Harvesting can turn up Mystery Eggs. More chickens, better odds; the egg's colour follows your breeds. Rarer colours hold better prizes.", 17, BookPanel.CREAM))
			var eggs := HFlowContainer.new()
			eggs.add_theme_constant_override("h_separation", 10)
			eggs.add_theme_constant_override("v_separation", 10)
			for colour in Game.egg_data.get("colours", {}):
				var n := int(Game.mystery_eggs.get(colour, 0))
				if n <= 0:
					continue
				var b := _panel_button("Open %s (%d)" % [Game.egg_data["colours"][colour]["name"], n])
				var c: String = colour
				b.pressed.connect(func() -> void:
					var prize := Game.open_mystery_egg(c)
					if prize != "":
						show_message("You got " + prize))
				eggs.add_child(b)
			if eggs.get_child_count() > 0:
				content.add_child(eggs)
		"calves":
			var bull := "A bull lives here: harvests can bring calves." if Game.has_inside(o, "bull") else "No bull yet. A lonely bull sometimes wanders onto farms that have a Dairy Farm: adopt it and move it in for calves."
			content.add_child(BookPanel.text(bull + " Harvests sometimes leave a bag of fertilizer too.", 17, BookPanel.CREAM))
		"foals":
			var st := "A stallion lives here: harvests can bring foals." if Game.has_inside(o, "stallion") else "No stallion yet. A wandering stallion sometimes visits farms with a Horse Stable: adopt it and move it in for foals."
			content.add_child(BookPanel.text("Horses here are ready every day instead of every 3 days. " + st + " Harvests can also give Farmhands and Arborists.", 17, BookPanel.CREAM))
		"nursery":
			var grow := int(it.get("grow_days", 4))
			var lines: Array[String] = []
			for baby in o.get("growing", []):
				lines.append("%s: %d of %d days" % [Game.item_data(baby[0])["name"], int(baby[1]), grow])
			var txt := "Calves and foals grow up here after %d daily collections. Outside the barn they never grow." % grow
			if not lines.is_empty():
				txt += "\n" + "\n".join(PackedStringArray(lines))
			content.add_child(BookPanel.text(txt, 17, BookPanel.CREAM))
		"beehive":
			_add_hive_info(content, o)
		"truffles":
			_add_pig_pen_info(content, o)
		"garage":
			_add_garage_info(content)
		"saplings":
			content.add_child(BookPanel.text("Harvests can sprout a rare sapling of a tree inside: a Rainier Cherry from cherry trees, a Honeycrisp from apple trees... Rare trees pay half as much again. The more of a tree you keep here, the likelier its sapling.", 17, BookPanel.CREAM))


func _add_garage_info(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text("Vehicle Parts held: %d. They turn up while farming and as daily gifts now that you have a Garage. Parked vehicles still work from the toolbar." % int(Game.parts.get("vehicle_parts", 0)), 17, BookPanel.CREAM))
	var owned := Game.owned_vehicles()
	if owned.is_empty():
		content.add_child(BookPanel.text("No vehicles yet. Buy a Tractor, Seeder or Harvester in the Market.", 18, BookPanel.CREAM))
		return
	for id in owned:
		var it := Game.item_data(id)
		var area := Game.vehicle_area(id)
		var card := BookPanel.card()
		card.add_theme_constant_override("separation", 6)
		card.add_child(BookPanel.text("%s · works %dx%d plots · upgrade %d of 4" % [it["name"], area.x, area.y, Game.vehicle_level(id)], 21))
		var cost := Game.vehicle_upgrade_cost(id)
		var vid: String = id
		if cost < 0:
			card.add_child(BookPanel.text("Fully upgraded.", 18))
		else:
			var next: Vector2i = GameState.VEHICLE_SIZES[Game.vehicle_level(id) + 1]
			var need_lvl := Game.vehicle_upgrade_level_needed(id)
			var line := "Next: %dx%d for %d Vehicle Parts" % [next.x, next.y, cost]
			if need_lvl > Game.level():
				line += " (level %d)" % need_lvl
			card.add_child(BookPanel.text(line, 18))
			var up := _panel_button("Upgrade")
			up.disabled = not Game.can_upgrade_vehicle(id)
			up.pressed.connect(func() -> void: Game.upgrade_vehicle(vid))
			card.add_child(up)
		content.add_child(BookPanel.card_frame(card))


func _build_fuel(content: VBoxContainer) -> void:
	var fuel := Game.fuel_now()
	content.add_child(BookPanel.text("All vehicles share one tank of %d. Each plot a vehicle works uses 1 fuel (the Combine 3). The tank refills by itself, 1 fuel every %d minutes, and a spare tank is opened when it runs dry." % [GameState.FUEL_TANK, int(GameState.FUEL_REGEN_SECONDS / 60.0)], 18, BookPanel.CREAM))
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	card.add_child(BookPanel.text("Tank: %d of %d · spare tanks: %d" % [fuel, GameState.FUEL_TANK, Game.fuel_tanks], 21))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 18
	bar.max_value = GameState.FUEL_TANK
	bar.value = fuel
	card.add_child(bar)
	var buy := _panel_button("Buy a full tank: %d gems" % GameState.FUEL_TANK_GEM_COST)
	buy.disabled = Game.gems < GameState.FUEL_TANK_GEM_COST
	buy.pressed.connect(func() -> void: Game.buy_fuel_tank())
	card.add_child(buy)
	content.add_child(BookPanel.card_frame(card))


## One toolbar button per vehicle type you own, with its area and the fuel left.
func _refresh_vehicles() -> void:
	if not _vehicle_row:
		return
	var owned := Game.owned_vehicles()
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
		var area := Game.vehicle_area(id)
		(_vehicle_buttons[id] as Button).text = "%s\n%dx%d · %d fuel" % [Game.item_data(id)["name"], area.x, area.y, int(Game.item_data(id).get("fuel_per_plot", 1)) * area.x * area.y]
	_fuel_button.visible = Game.fuel_unlocked
	_fuel_button.text = "Fuel %d/%d\n+%d tanks" % [Game.fuel_now(), GameState.FUEL_TANK, Game.fuel_tanks]


func _add_hive_info(content: VBoxContainer, o: Dictionary) -> void:
	var uid := int(o["uid"])
	if Game.has_queen(o):
		content.add_child(BookPanel.text("The Queen Bee lives here. Worker bees join while you harvest flowers, up to %d. Each bee makes honey daily." % Game.capacity(o), 17, BookPanel.CREAM))
	else:
		content.add_child(BookPanel.text("This hive needs a Queen Bee before worker bees will join. One may turn up while harvesting flowers, or buy one.", 17, BookPanel.CREAM))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 12)
		var put := _panel_button("Add Queen Bee (%d held)" % Game.queen_bees)
		put.disabled = Game.queen_bees <= 0
		put.pressed.connect(func() -> void: Game.add_queen(uid))
		row.add_child(put)
		var buy := _panel_button("Buy Queen Bee: %d gems" % GameState.QUEEN_GEM_COST)
		buy.disabled = Game.gems < GameState.QUEEN_GEM_COST
		buy.pressed.connect(func() -> void: Game.add_queen(uid, true))
		row.add_child(buy)
		content.add_child(row)
	content.add_child(BookPanel.text("Pollination: harvesting a fertilized crop has a %d%% chance to give 5 pollinated seeds of it (free, last 2 days). Their crops stay ripe twice as long and super-harvest three times as often. Collecting honey can leave a Fertilize All. Bees drift off if you stay away more than %d days." % [int(round(Game.pollination_chance() * 100)), GameState.BEES_STAY_DAYS], 17, BookPanel.CREAM))


func _add_pig_pen_info(content: VBoxContainer, o: Dictionary) -> void:
	var uid := int(o["uid"])
	var pigs := Game.inside_total(o)
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	card.add_child(BookPanel.text("Truffles held: %d" % Game.truffles, 21))
	if not Game.is_foraging(o):
		card.add_child(BookPanel.text("Feed the pigs slop and they forage for 8 hours: 1 truffle for every %d pigs, at least 1." % GameState.PIGS_PER_TRUFFLE, 17))
		var feed := _panel_button("Feed slop: %d coins" % GameState.SLOP_COST)
		feed.disabled = pigs == 0 or Game.coins < GameState.SLOP_COST
		feed.pressed.connect(func() -> void: Game.feed_slop(uid))
		card.add_child(feed)
	elif Game.forage_seconds_left(o) > 0:
		card.add_child(BookPanel.text("Foraging... back in " + FarmGrid.format_duration(Game.forage_seconds_left(o)), 18))
	else:
		var dig := _panel_button("Collect truffles")
		dig.pressed.connect(func() -> void:
			var n := Game.collect_truffles(uid)
			if n > 0:
				show_message("+%d truffles" % n))
		card.add_child(dig)
	card.add_child(BookPanel.text("Trade %d truffles for a rare pig:" % GameState.TRUFFLES_PER_PIG, 18))
	var breeds := HFlowContainer.new()
	breeds.add_theme_constant_override("h_separation", 10)
	breeds.add_theme_constant_override("v_separation", 10)
	for id in Game.rare_pigs():
		var b := _panel_button(Game.item_data(id)["name"])
		b.disabled = Game.truffles < GameState.TRUFFLES_PER_PIG
		var breed: String = id
		b.pressed.connect(func() -> void: Game.trade_truffles(breed))
		breeds.add_child(b)
	card.add_child(breeds)
	content.add_child(BookPanel.card_frame(card))


## Next size and its material cost.
func _add_expansion_card(content: VBoxContainer, o: Dictionary, uid: int) -> void:
	var need := Game.expansion_needs(o)
	if need.is_empty():
		content.add_child(BookPanel.text("Fully expanded.", 18, BookPanel.CREAM))
		return
	var lvl := Game.level_of(o)
	var levels: Array = Game.item_data(o["id"])["levels"]
	var names: Array = Game.item_data(o["id"]).get("level_names", [])
	var next_name: String = names[lvl] if lvl < names.size() else "Next size"
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 6)
	card.add_child(BookPanel.text("Expand to %s: holds %d" % [next_name, int(levels[lvl])], 21))
	for m in need:
		card.add_child(BookPanel.text("•  %s: %d of %d" % [GameState.PART_NAMES[m], mini(int(Game.parts.get(m, 0)), int(need[m])), int(need[m])], 18))
	var up := _panel_button("Expand")
	up.disabled = not Game.can_expand(o)
	up.pressed.connect(func() -> void: Game.upgrade_building(uid))
	card.add_child(up)
	content.add_child(BookPanel.card_frame(card))


func _build_barn(content: VBoxContainer) -> void:
	var b := Game.barn()
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
		"This old barn needs fixing. Collect building parts while you harvest and collect from animals and trees. A few arrive as a daily gift too.", 20, BookPanel.CREAM))
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 10)
	var need := Game.repair_needs()
	for p in GameState.PARTS:
		var want := int(need.get(p, 0))
		var have := int(Game.parts.get(p, 0))
		card.add_child(BookPanel.text("%s: %d of %d" % [GameState.PART_NAMES[p], mini(have, want), want], 20))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 16
		bar.max_value = want
		bar.value = mini(have, want)
		card.add_child(bar)
	card.add_child(BookPanel.text("Reward: %d coins, %d XP, and a barn to store things in" % [int(it.get("repair_coins", 0)), int(it.get("repair_xp", 0))], 17))
	content.add_child(BookPanel.card_frame(card))
	var fix := _panel_button("Repair the barn" if Game.can_repair_barn() else "Not enough parts yet")
	fix.disabled = not Game.can_repair_barn()
	fix.pressed.connect(func() -> void: Game.repair_barn())
	content.add_child(fix)


func _build_barn_storage(content: VBoxContainer) -> void:
	var cap := Game.barn_capacity()
	content.add_child(BookPanel.text(
		"Holds %d of %d. Use the Store tool on trees, animals or scenery to put them away. Tap Place to bring one back out." % [Game.stored.size(), cap], 20, BookPanel.CREAM))
	var parts_line: Array[String] = []
	for p in GameState.PARTS:
		parts_line.append("%s %d" % [GameState.PART_NAMES[p], int(Game.parts.get(p, 0))])
	content.add_child(BookPanel.text("Parts: " + ", ".join(PackedStringArray(parts_line)), 17, BookPanel.CREAM))
	if Game.stored.is_empty():
		content.add_child(BookPanel.card_frame(BookPanel.text("Nothing stored yet.", 20)))
		return
	for k in Game.stored.size():
		var o: Dictionary = Game.stored[k]
		var row := HBoxContainer.new()
		var label := BookPanel.text(Game.item_data(o["id"])["name"], 22)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var place := _panel_button("Place")
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
		"Items turn up while harvesting. Find all five in a set, then trade it in.", 20, BookPanel.CREAM))
	for coll in Game.collections:
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
		trade.text = "Trade in"
		trade.custom_minimum_size = Vector2(140, 48)
		trade.focus_mode = Control.FOCUS_NONE
		trade.disabled = not Game.can_trade_in(coll)
		var coll_id: String = coll["id"]
		trade.pressed.connect(func() -> void: Game.trade_in(coll_id))
		head.add_child(trade)
		inner.add_child(head)

		if coll.get("birds", false):
			inner.add_child(BookPanel.text("Birds can land during any harvest or collection.", 18))
		else:
			inner.add_child(BookPanel.text("Found while harvesting: " + ", ".join(PackedStringArray(crop_names)), 18))

		var items := HFlowContainer.new()
		items.add_theme_constant_override("h_separation", 8)
		items.add_theme_constant_override("v_separation", 8)
		for item in coll["items"]:
			var count := int(Game.owned.get(item["id"], 0))
			var label: String = item["name"] + ("  x%d" % count if count > 1 else "")
			items.add_child(BookPanel.chip(label, count > 0))
		inner.add_child(items)

		inner.add_child(BookPanel.text("Reward: %d coins, %d XP" % [int(coll["reward_coins"]), int(coll["reward_xp"])], 18))
		content.add_child(BookPanel.card_frame(inner))


func _build_ribbons(content: VBoxContainer) -> void:
	var data: Dictionary = Game.ribbon_data
	var tier_names: Array = data.get("tiers", [])
	content.add_child(BookPanel.text(
		"Each ribbon has four tiers: Yellow, White, Red and Blue.", 20, BookPanel.CREAM))
	for r in data.get("ribbons", []):
		var earned := int(Game.ribbon_tiers.get(r["id"], 0))
		var thresholds: Array = r["thresholds"]
		var value := Game.stat(r["stat"])

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
			line = "Complete! %d %s" % [value, r["what"]]
		else:
			var goal := int(thresholds[earned])
			line = "%d / %d %s for %s" % [mini(value, goal), goal, r["what"], tier_names[earned]]
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
