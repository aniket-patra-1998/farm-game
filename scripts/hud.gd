class_name FarmHud
extends CanvasLayer
## The heads-up display, FarmVille's way, built from the kit (UiKit, data/ui_theme.json): the top (coins, cash,
## farm name, XP and level: HudTop), the tool panel (HudTools), the sides (view toggles, menu, zoom, neighbours'
## strip: HudSide), and short messages, the tutorial banner and the placing bar. The panels live in scripts/hud/.

signal tool_selected(tool: String, crop_id: String)
signal place_requested(item_id: String)
signal cancel_place_requested

signal place_stored_requested(index: int)


const REST_FADE := 1.4     # seconds the interface takes to fade away over an idle farm..
const WAKE_FADE := 0.2     # ..and to come back at a touch
const AWAY_WAIT := 0.5     # seconds between looks for a panel to close before the away card shows

const WOOD := Color("#7a4f2c")
const WOOD_DARK := Color("#5c3a1e")
const CREAM := Color("#fbefd2")
const INK := Color("#3a2614")
const SUN := Color("#ffd34d")

const LOCKED := Color("#d8cbb0")


var top: HudTop
var sheet: BuildingSheet   # a tapped home's sheet (made when first needed, then kept)
var bubble: HudBubble   # what a tapped thing says about itself, above it
var tools: HudTools
var side: HudSide
var helpers: HudHelpers   # the helpers' flower, bottom left
var interface_hidden := false
var camera: FarmCamera              # set by Main, for the zoom buttons
var grid: FarmGrid                  # set by Main: what is being moved (the placing bar's Turn button)
var go_to: Callable                 # set by Main: goes to the nearest thing of a kind ("ripe", "hungry"...)
var resting := false                # the interface has faded away over an idle farm (set_resting)
var next_ready: Callable            # set by Main: goes to the next thing ready to take
var fit_view: Callable              # set by Main: shows the whole farm
var book: BookPanel      # every full panel opens in it (panels and the sheet reach it as hud.book)
var building_uid := -1   # the building whose panel is open

var _reveal: RevealCard   # the reveal of a mystery egg or box (made when first needed, then kept)
var _away: AwayCard   # the While you were away card (made when first needed, then kept)
var _rest_tween: Tween
var _toast: Label
var _toast_tween: Tween
var _toast_holder: CenterContainer
var _tutorial: Label
var _level_popup: LevelUpPopup
var _placing_bar: PanelContainer
var _placing_label: Label
var _turn_button: Button


var _shown_coins := -1.0   # the number the coin counter shows while it rolls toward Game.coins

var _coin_roll: Tween

# The panels moved out of this class (scripts/hud/): each builds its content into the book.
var _root: Control   # the interface's root, kept inside the safe area
@onready var market := HudMarket.new(self)
@onready var crafting := HudCrafting.new(self)
@onready var buildings := HudBuildings.new(self)
@onready var barn := HudBarn.new(self)
@onready var feed := HudFeed.new(self)
@onready var books := HudBooks.new(self)
@onready var inbox := HudInbox.new(self)
@onready var settings := HudSettings.new(self)
@onready var seeds := HudSeeds.new(self)



## The top strip the counters stand in (the camera keeps the farm's middle clear of it), at the interface's scale.
static func top_h() -> float:
	return UiTheme.size("top_height")


## And the bottom one the tool panel stands in.
static func bottom_h() -> float:
	return UiTheme.size("bottom_height")

func _ready() -> void:
	layer = 10 # above the sky, the farm and the night lights
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_root = root
	_fit_safe_area()
	get_viewport().size_changed.connect(_fit_safe_area)
	ItemIcons.start(self)   # the shop's pictures, made from the models when first shown
	top = HudTop.new(self)
	top.build(root)
	top.sky_tapped.connect(func() -> void:   # (the icons' words, on a tap)
		show_message("%s · %s" % [tr("SEASON_" + Game.season().to_upper()), tr(Game.weather()["name"])]))
	side = HudSide.new(self)
	side.build(root)
	tools = HudTools.new(self)
	tools.build(root)
	helpers = HudHelpers.new(self)
	helpers.build(root)
	_build_tutorial(root)
	_build_toast(root)
	bubble = HudBubble.new(self)
	root.add_child(bubble)
	_build_placing_bar(root)
	book = BookPanel.new()
	root.add_child(book)
	_level_popup = LevelUpPopup.new()
	root.add_child(_level_popup)
	Game.leveled_up.connect(_level_popup.celebrate)
	Game.leveled_up.connect(func(_l: int) -> void:
		Feedback.moment("level_up"))
	Game.collections_changed.connect(_refresh_book)
	Game.ribbons_changed.connect(_refresh_book)
	Game.objects_changed.connect(_refresh_book)
	Game.object_changed.connect(func(_uid: int) -> void: _refresh_book())
	Game.coins_changed.connect(func(_c: int) -> void: _refresh_book())
	Game.coins_changed.connect(func(_c: int) -> void: _refresh())
	Game.gems_changed.connect(func(_g: int) -> void: _refresh())
	Game.inventory_changed.connect(_refresh_book)
	Game.farm_expanded.connect(func(_s: int) -> void: _refresh_book())
	Game.xp_changed.connect(func(_x: int, _l: int) -> void: _refresh())
	Game.tutorial_changed.connect(func(_s: int) -> void: _refresh_tutorial())
	Game.away_recap.connect(_show_away)
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_refresh_clock)
	add_child(tick)
	_refresh()
	_refresh_clock()
	_refresh_tutorial()


# ---------------------------------------------------------------- layout


## Keeps the whole interface inside the screen's safe area (clear of a notch, a camera hole, rounded corners
## and the gesture bar): the root's edges move in by the insets, and everything is laid out inside it.
func _fit_safe_area() -> void:
	var inset := Display.safe_insets(get_viewport())
	_root.offset_left = inset.x
	_root.offset_top = inset.y
	_root.offset_right = -inset.z
	_root.offset_bottom = -inset.w


func _build_placing_bar(root: Control) -> void:
	# The placing hint in floating words with Turn and Cancel as small round buttons beside it: no box.
	_placing_bar = PanelContainer.new()
	_placing_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_placing_bar.add_child(row)
	_placing_label = FloatText.label("", 20)
	_placing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_placing_label)
	# A decoration being moved can be turned here (FarmVille's rotate, folded into Move).
	_turn_button = FloatText.action("turn", tr("TURN"))
	_turn_button.pressed.connect(func() -> void: Game.rotate_object(_moving_uid()))
	row.add_child(_turn_button)
	var cancel := FloatText.action("cross", tr("CANCEL"))
	cancel.pressed.connect(func() -> void: cancel_place_requested.emit())
	row.add_child(cancel)
	_placing_bar.visible = false
	_top_holder(root, top_h() + 10).add_child(_placing_bar)


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
	book.open_panel(tr("SEED_LIST"), seeds.build_seeds)


## A seed picked: it goes in hand, and the Plant tool lights.
func choose_seed(crop_id: String) -> void:
	book.close_panel()
	tool_selected.emit("plant", crop_id)
	tools.show_tool("plant")
	show_message(tr("TAP_PLOWED_PLOTS_TO_PLANT") % Game.crops[crop_id]["name"])


## Hides the whole interface (for looking at the farm, or a screenshot), or shows it again.
func set_interface_hidden(on: bool) -> void:
	interface_hidden = on
	var all: Array[Control] = top.hideable()
	all.append(tools.panel)
	all.append_array(side.hideable())
	for c in all:
		c.visible = not on


## Fades the whole interface away over an idle farm (Main, after Balance `feel.idle_view_seconds` with no touch),
## or brings it back at the next touch. Unlike the eye, nothing is hidden for good: it is a rest, not a mode.
func set_resting(on: bool) -> void:
	if resting == on:
		return
	resting = on
	if _rest_tween != null:
		_rest_tween.kill()
	_rest_tween = create_tween()
	_rest_tween.tween_property(_root, "modulate:a", 0.0 if on else 1.0, REST_FADE if on else WAKE_FADE)


## Whether something is up that a player may be reading (a home's sheet, the away card): the interface doesn't
## fade from under it.
func reading() -> bool:
	return (sheet != null and sheet.visible) or (_away != null and _away.visible)


## The reveal of a mystery opened from a panel (an egg's colour name or RevealCard.BOX): it shakes, bursts, and
## what was inside is named in its rarity's colours, over everything.
func reveal(what: String, title: String, prize: String, rarity: String) -> void:
	if _reveal == null:
		_reveal = RevealCard.new()
		add_child(_reveal)   # (over the panels: it is the last thing added)
	_reveal.move_to_front()
	_reveal.play(what, title, prize, rarity)


## While you were away, as a card of rows (Game.away_recap). It waits for a panel that opened first (the daily
## gift) to close.
func _show_away(rows: Array, notes: Array) -> void:
	if Game.modal_open:
		get_tree().create_timer(AWAY_WAIT).timeout.connect(_show_away.bind(rows, notes))
		return
	if _away == null:
		_away = AwayCard.new(self)
		_root.add_child(_away)
	_away.open(rows, notes)


## The zoom buttons: in or out about the middle of the screen, or 0 for the whole farm.
func zoom_view(factor: float) -> void:
	if factor <= 0.0:
		if fit_view.is_valid():
			fit_view.call()
	elif camera != null:
		camera.zoom_by(factor, get_viewport().get_visible_rect().size / 2.0)


func _build_tutorial(root: Control) -> void:
	_tutorial = FloatText.label("", 24, SUN)   # (the next step in floating words, sun-yellow: no box)
	_top_holder(root, top_h() + 12).add_child(_tutorial)


func _refresh_tutorial() -> void:
	var text := Game.tutorial_text()
	_tutorial.text = text
	_tutorial.visible = text != "" and not (_placing_bar and _placing_bar.visible)
	# Keep messages clear of the tutorial banner while it shows.
	var y := top_h() + (80.0 if _tutorial.visible else 16.0)
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
	_toast = FloatText.label("", 22)   # (floating words, no box: FloatText)
	_toast.modulate.a = 0.0
	_toast_holder = _top_holder(root, top_h() + 16)
	_toast_holder.add_child(_toast)


# ---------------------------------------------------------------- updates


func show_message(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, FloatText.RISE_TIME)
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
	top.coins_label.text = UiTheme.short_number(int(round(v)))


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
	top.gems_label.text = UiTheme.short_number(Game.gems)
	var ratio := clampf(float(Game.xp - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
	# The bar fills smoothly; on a level-up it starts again from the new level.
	if top.xp.level != lvl or ratio < top.xp.ratio:
		top.xp.ratio = ratio
	else:
		var tw := top.xp.create_tween()
		tw.tween_property(top.xp, "ratio", ratio, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	top.xp.level = lvl
	top.xp.text = tr("XP_2") % [UiTheme.number(Game.xp), UiTheme.number(hi)]



func _refresh_clock() -> void:
	var hour := DayCycle.local_hour(Game.now(), DayCycle.device_bias_minutes())
	var weather := Game.weather()
	var state := str(weather.get("state", "clear"))
	var night := hour < DayCycle.SUNRISE or hour >= DayCycle.SUNSET
	top.season_icon.kind = str(HudTop.SEASON_ICONS.get(Game.season(), "sun"))
	top.weather_icon.kind = "moon" if state == "clear" and night else str(HudTop.WEATHER_ICONS.get(state, "sun"))
	top.clock.text = DayCycle.clock_text(hour)
	top.show_forecast(Game.forecast() if Season.enabled() else {})


# ---------------------------------------------------------------- menus


func _refresh_book() -> void:
	if book.visible:
		book.refresh()


func show_collections() -> void:
	book.open_panel(tr("COLLECTIONS"), books.build_collections)


func show_inbox() -> void:
	var note := Game.social.settle()
	if note != "":
		show_message(note)
	book.open_panel(tr("INBOX"), inbox.build_inbox)


func show_ribbons() -> void:
	book.open_panel(tr("RIBBONS"), books.build_ribbons)


func show_settings() -> void:
	book.open_panel(tr("SETTINGS"), settings.build_settings)


func show_market() -> void:
	book.open_tabs(tr("MARKET"), market.tabs(), 1)   # (the first shelf after Seeds: trees, as FarmVille opened)


## Opened when a building that isn't ready is tapped.
func show_building(uid: int) -> void:
	building_uid = uid
	var o := Game.object_by_uid(uid)
	PerfReadout.note(str(o.get("id", "")))   # (a building opened)
	if o.is_empty():
		return
	if BuildingSheet.suits(o):
		# Every building (and an animal to feed, a young one, a bloom, a vehicle) opens as its sheet at the bottom,
		# the farm still in view: everything it does is in it.
		if sheet == null:
			sheet = BuildingSheet.new(self)
			book.get_parent().add_child(sheet)
		book.close_panel()
		sheet.open(uid)


## A building's everything: its sheet, tall. A building has no other window (the sheet holds its pages).
func open_full_panel(uid: int) -> void:
	show_building(uid)
	if sheet != null and sheet.visible:
		sheet.make_tall()


## The panel or sheet on screen shows things as they are now (a card picked, a sale): built again, once a frame.
## (A building's pages are built by the same builders whether they are in the sheet or a panel.)
func refresh_panels() -> void:
	if book.visible:
		book.refresh()
	elif sheet != null and sheet.visible:
		sheet.refill_soon()


## The panel or sheet on screen back at its top (a recipe picked shows at the top).
func scroll_panels_to_top() -> void:
	if book.visible:
		book.scroll_to_top()
	elif sheet != null and sheet.visible:
		sheet.scroll_to_top()


## Every panel and sheet away: something was taken in hand (to place, to drive), the farm comes back in view.
func close_panels() -> void:
	book.close_panel()
	if sheet != null:
		sheet.close()


func panel_button(words: String) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size = Vector2(UiTheme.size("panel_button_width"), UiTheme.size("panel_button_height"))
	b.focus_mode = Control.FOCUS_NONE
	UiFx.press_bounce(b)
	return b


# ---------------------------------------------------------------- theme


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = UiTheme.font(22)

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
	t.set_stylebox("pressed", "Button", _button_box(SUN, INK, true))
	t.set_stylebox("hover_pressed", "Button", _button_box(SUN, INK, true))
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
	_theme_fields(t, bar_fill)
	return t


## Text boxes and sliders on the kit: a cream field with a wooden edge, a wooden groove with a green fill and
## a sun-yellow knob (the stock grey ones looked borrowed).
func _theme_fields(t: Theme, fill: StyleBoxFlat) -> void:
	for state in ["normal", "focus", "read_only"]:
		var field := _button_box(Color.WHITE.lerp(CREAM, 0.6) if state != "focus" else Color.WHITE, WOOD_DARK)
		field.content_margin_left = 12
		field.content_margin_right = 12
		t.set_stylebox(state, "LineEdit", field)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK.lightened(0.5))
	t.set_color("caret_color", "LineEdit", INK)
	var groove := StyleBoxFlat.new()
	groove.bg_color = WOOD_DARK
	groove.set_corner_radius_all(int(UiTheme.size("slider_groove") / 2.0))
	groove.content_margin_top = UiTheme.size("slider_groove") / 2.0
	groove.content_margin_bottom = UiTheme.size("slider_groove") / 2.0
	var filled := fill.duplicate() as StyleBoxFlat
	filled.content_margin_top = groove.content_margin_top
	filled.content_margin_bottom = groove.content_margin_bottom
	var slider := "HSlider"   # not-ui
	t.set_stylebox("slider", slider, groove)
	t.set_stylebox("grabber_area", slider, filled)
	t.set_stylebox("grabber_area_highlight", slider, filled)
	var knob := UiIcon.knob(int(UiTheme.size("slider_knob")), SUN, WOOD_DARK)
	t.set_icon("grabber", slider, knob)
	t.set_icon("grabber_highlight", slider, knob)


## A plush button: round, a darker lip underneath like a key that can be pressed (thinner when pressed: it has
## gone down), and a soft shadow on what it sits on.
func _button_box(fill: Color, border: Color, down := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(int(UiTheme.size("button_border")))
	sb.border_width_bottom = int(UiTheme.size("button_border") * (1.5 if down else 3.0))
	sb.set_corner_radius_all(int(UiTheme.size("button_radius") * 1.6))
	sb.shadow_color = Color(0, 0, 0, 0.0 if down else 0.22)
	sb.shadow_size = int(UiTheme.size("button_border") * 2.0)
	sb.shadow_offset = Vector2(0, UiTheme.size("button_border"))
	sb.anti_aliasing_size = 1.2
	sb.content_margin_left = UiTheme.size("button_pad")
	sb.content_margin_right = UiTheme.size("button_pad")
	sb.content_margin_top = UiTheme.size("button_pad") * 0.4
	sb.content_margin_bottom = UiTheme.size("button_pad") * 0.4 + (0.0 if down else UiTheme.size("button_border") * 1.5)
	return sb
