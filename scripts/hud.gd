class_name FarmHud
extends CanvasLayer
## Top bar (coins, level, XP), bottom toolbar (tools and seeds) and short messages.
## Built in code so it scales cleanly between phone and tablet.

signal tool_selected(tool: String, crop_id: String)

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


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_top_bar(root)
	_build_toolbar(root)
	_build_tutorial(root)
	_build_toast(root)
	_book = BookPanel.new()
	root.add_child(_book)
	Game.collections_changed.connect(_refresh_book)
	Game.ribbons_changed.connect(_refresh_book)
	Game.coins_changed.connect(func(_c: int) -> void: _refresh())
	Game.xp_changed.connect(func(_x: int, _l: int) -> void: _refresh())
	Game.leveled_up.connect(func(_l: int) -> void: _refresh_seed_buttons())
	Game.tutorial_changed.connect(func(_s: int) -> void: _refresh_tutorial())
	_refresh()
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

	_coins_label = Label.new()
	_coins_label.add_theme_color_override("font_color", SUN)
	_coins_label.add_theme_font_size_override("font_size", 34)
	row.add_child(_coins_label)

	for entry in [["Collections", _show_collections], ["Ribbons", _show_ribbons]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(130, 56)
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
	xp_box.custom_minimum_size.x = 220
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

	var hand := _tool_button("Hand\nmove & inspect")
	hand.pressed.connect(func() -> void: tool_selected.emit("hand", ""))
	row.add_child(hand)

	for id in Game.crop_order:
		var b := _tool_button("")
		var crop_id: String = id
		b.pressed.connect(func() -> void: tool_selected.emit("plant", crop_id))
		_seed_buttons[crop_id] = b
		row.add_child(b)
	_refresh_seed_buttons()

	if OS.is_debug_build():
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
	_tutorial.visible = text != ""
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
	_coins_label.text = "%d coins" % Game.coins
	_level_label.text = "Level %d" % lvl
	_xp_bar.min_value = lo
	_xp_bar.max_value = hi
	_xp_bar.value = Game.xp
	_xp_label.text = "%d / %d XP" % [Game.xp, hi]


func _refresh_seed_buttons() -> void:
	for id in _seed_buttons:
		var crop: Dictionary = Game.crops[id]
		var b: Button = _seed_buttons[id]
		if Game.is_unlocked(id):
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


func _build_collections(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text(
		"Items turn up while harvesting. Find all five in a set, then trade it in.", 20, BookPanel.CREAM))
	for coll in Game.collections:
		var inner := BookPanel.card()
		inner.add_theme_constant_override("separation", 10)

		var crop_names: Array[String] = []
		for crop_id in coll["crops"]:
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
