class_name FarmHud
extends CanvasLayer
## The heads-up display, FarmVille's way, built from the kit (UiKit, data/ui_theme.json): the top (coins, cash,
## farm name, XP and level: HudTop), the tool panel (HudTools), the sides (view toggles, menu, zoom, neighbours'
## strip: HudSide), and short messages, the tutorial banner and the placing bar. The panels live in scripts/hud/.

signal tool_selected(tool: String, crop_id: String)
signal place_requested(item_id: String)
signal cancel_place_requested

signal place_stored_requested(index: int)


const TOP_H := 72.0        # the top strip the counters stand in (the camera keeps the farm's middle clear of it)
const BOTTOM_H := 102.0    # and the bottom one the tool panel stands in
const GROUP_PAGE := 30     # rows of a long grouped list (the barn) built at a time

const WOOD := Color("#7a4f2c")
const WOOD_DARK := Color("#5c3a1e")
const CREAM := Color("#fbefd2")
const INK := Color("#3a2614")
const SUN := Color("#ffd34d")

const LOCKED := Color("#d8cbb0")


var top: HudTop
var tools: HudTools
var side: HudSide
var interface_hidden := false
var camera: FarmCamera              # set by Main, for the zoom buttons
var grid: FarmGrid                  # set by Main: what is being moved (the placing bar's Turn button)
var fit_view: Callable              # set by Main: shows the whole farm

var _toast: Label
var _toast_tween: Tween
var _toast_holder: CenterContainer
var _tutorial: Label
var _book: BookPanel
var _level_popup: LevelUpPopup
var _placing_bar: PanelContainer
var _placing_label: Label
var _turn_button: Button

var _building_uid := -1


var _shown_coins := -1.0   # the number the coin counter shows while it rolls toward Game.coins

var _coin_roll: Tween

# The panels moved out of this class (scripts/hud/): each builds its content into the book.
@onready var market := HudMarket.new(self)
@onready var crafting := HudCrafting.new(self)
@onready var buildings := HudBuildings.new(self)
@onready var barn := HudBarn.new(self)
@onready var feed := HudFeed.new(self)
@onready var books := HudBooks.new(self)
@onready var settings := HudSettings.new(self)
@onready var seeds := HudSeeds.new(self)


func _ready() -> void:
	layer = 10 # above the sky, the farm and the night lights
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	top = HudTop.new(self)
	top.build(root)
	side = HudSide.new(self)
	side.build(root)
	tools = HudTools.new(self)
	tools.build(root)
	_build_tutorial(root)
	_build_toast(root)
	_build_placing_bar(root)
	_book = BookPanel.new()
	root.add_child(_book)
	_level_popup = LevelUpPopup.new()
	root.add_child(_level_popup)
	Game.leveled_up.connect(_level_popup.celebrate)
	Game.leveled_up.connect(func(_l: int) -> void:
		Feedback.moment("level_up"))
	Game.collections_changed.connect(_refresh_book)
	Game.ribbons_changed.connect(_refresh_book)
	Game.objects_changed.connect(_refresh_book)
	Game.coins_changed.connect(func(_c: int) -> void: _refresh_book())
	Game.coins_changed.connect(func(_c: int) -> void: _refresh())
	Game.gems_changed.connect(func(_g: int) -> void: _refresh())
	Game.inventory_changed.connect(_refresh_book)
	Game.farm_expanded.connect(func(_s: int) -> void: _refresh_book())
	Game.xp_changed.connect(func(_x: int, _l: int) -> void: _refresh())
	Game.tutorial_changed.connect(func(_s: int) -> void: _refresh_tutorial())
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_refresh_clock)
	add_child(tick)
	_refresh()
	_refresh_clock()
	_refresh_tutorial()


# ---------------------------------------------------------------- layout


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
	# A decoration being moved can be turned here (FarmVille's rotate, folded into Move).
	_turn_button = Button.new()
	_turn_button.text = tr("TURN")
	_turn_button.custom_minimum_size = Vector2(110, 48)
	_turn_button.focus_mode = Control.FOCUS_NONE
	_turn_button.pressed.connect(func() -> void: Game.rotate_object(_moving_uid()))
	row.add_child(_turn_button)
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
	_turn_button.visible = text != "" and Game.can_rotate(Game.object_by_uid(_moving_uid()))
	_refresh_tutorial()


## The uid of what is being moved (-1 for a purchase, or when nothing is).
func _moving_uid() -> int:
	if grid == null or grid.placement == null:
		return -1
	return int(grid.placement.state.get("uid", -1))


## Opens the seed list (the Plant tool).
func show_seeds() -> void:
	_book.open_panel(tr("SEED_LIST"), seeds.build_seeds)


## A seed picked: it goes in hand, and the Plant tool lights.
func choose_seed(crop_id: String) -> void:
	_book.close_panel()
	tool_selected.emit("plant", crop_id)
	tools.show_tool("plant")
	show_message(tr("TAP_PLOWED_PLOTS_TO_PLANT") % Game.crops[crop_id]["name"])


## Hides everything but the eye (FarmVille's view toggle, for looking at the farm), or shows it again.
func set_interface_hidden(on: bool) -> void:
	interface_hidden = on
	var all: Array[Control] = top.hideable()
	all.append(tools.panel)
	all.append_array(side.hideable())
	for c in all:
		c.visible = not on
	side.show_eye(on)


## The zoom buttons: in or out about the middle of the screen, or 0 for the whole farm.
func zoom_view(factor: float) -> void:
	if factor <= 0.0:
		if fit_view.is_valid():
			fit_view.call()
	elif camera != null:
		camera.zoom_by(factor, get_viewport().get_visible_rect().size / 2.0)


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
	return top.coins.get_global_rect().get_center()


func xp_target() -> Vector2:
	return top.xp.get_global_rect().position + top.xp.star_centre()


## A quick swell as a reward lands on a counter.
func pulse(which: String) -> void:
	if which == "coins":
		Feedback.moment("coin_land")  # each coin chinks as it lands
	var c: Control = top.coins if which == "coins" else top.xp
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.18, 1.18), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _set_shown_coins(v: float) -> void:
	_shown_coins = v
	top.coins_label.text = _thousands(int(round(v)))


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
	top.gems_label.text = _thousands(Game.gems)
	var ratio := clampf(float(Game.xp - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
	# The bar fills smoothly; on a level-up it starts again from the new level.
	if top.xp.level != lvl or ratio < top.xp.ratio:
		top.xp.ratio = ratio
	else:
		var tw := top.xp.create_tween()
		tw.tween_property(top.xp, "ratio", ratio, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	top.xp.level = lvl
	top.xp.text = tr("XP_2") % [_thousands(Game.xp), _thousands(hi)]


static func _thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


func _refresh_clock() -> void:
	var hour := DayCycle.local_hour(Game.now(), DayCycle.device_bias_minutes())
	top.clock.text = "%s · %s · %s" % [
		tr("SEASON_" + DayCycle.SEASON.to_upper()),
		tr(Game.weather()["name"]),
		DayCycle.clock_text(hour)
	]


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
	elif Game.kind_of(o) == "animal" and Game.feeds.is_feedable(o):
		_book.open_panel(Game.item_data(o["id"])["name"], feed.build_animal)
	elif Game.kind_of(o) == "vehicle" and not Game.under_construction(o):
		_book.open_panel(tr("FUEL"), buildings.build_fuel)   # a vehicle tapped with an empty tank
	elif Game.crafting.is_crafting(o):
		Game.crafting.finish_crafts(uid)
		_book.open_panel(Game.size_name(o), crafting.build_crafting)
	else:
		_book.open_panel(Game.item_data(o["id"])["name"], buildings.build_building)


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
