class_name HudTop
extends RefCounted
## The top of the screen, FarmVille's way: the coin and cash bars at the left (their "+" opens the Market), the
## farm's name on a plaque in the middle with the season and the sky as icons and the time under it, and the XP
## bar with the level star at the right. Built from the kit (UiKit); the counters' values are set by FarmHud.

signal sky_tapped   # the season and sky icons tapped: their words are shown (FarmHud)

const SKY_ICON := 2.2   # the season and sky icons, as a share of the clock's text size
## The season's sign, by season (Season names): a flower, the sun, a leaf, a snowflake, rain drops.
const SEASON_ICONS := {"Spring": "flower", "Summer": "sun", "Autumn": "leaf", "Winter": "flake", "Monsoon": "drops"}
## The sky's picture, by weather state (Weather.NAMES); a clear night shows the moon.
const WEATHER_ICONS := {"clear": "sun", "partly_cloudy": "sun_cloud", "cloudy": "cloud", "rain": "rain",
	"storm": "storm", "fog": "fog", "snow": "snow"}

var hud: FarmHud
var coins: PanelContainer
var gems: PanelContainer
var coins_label: Label
var gems_label: Label
var plaque: PanelContainer
var clock: Label   # the time alone (the season and sky are the icons beside it)
var season_icon: UiIcon
var weather_icon: UiIcon
var forecast: Label   # under the clock: "Rain at 4:00 pm: watered crops pay +10%" (hidden when nothing is due)
var xp: UiXpBar
var _forecast_at := -2   # the forecast last shown (its time; -1 none)


func _init(owner: FarmHud) -> void:
	hud = owner


func build(root: Control) -> void:
	var margin := UiTheme.size("hud_margin")
	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
	money.position = Vector2(margin, margin)
	root.add_child(money)
	coins = UiKit.meter("coin", true)
	coins.custom_minimum_size.x = UiTheme.size("coin_bar_width")
	coins_label = coins.get_meta("value_label")
	(coins.get_meta("plus_button") as Button).pressed.connect(hud._show_market)
	money.add_child(coins)
	gems = UiKit.meter("gem", true)
	gems.custom_minimum_size.x = UiTheme.size("gem_bar_width")
	gems_label = gems.get_meta("value_label")
	(gems.get_meta("plus_button") as Button).pressed.connect(hud._show_market)
	money.add_child(gems)

	# The farm's name in the middle, and the time of day under it.
	var middle := VBoxContainer.new()
	middle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	middle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	middle.offset_top = margin * 0.5
	middle.alignment = BoxContainer.ALIGNMENT_BEGIN
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_theme_constant_override("separation", 2)
	root.add_child(middle)
	plaque = UiKit.plaque(farm_name())
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(plaque)
	# The season and the sky as two icons and the time beside them: read at a glance, the words on a tap.
	var sky := HBoxContainer.new()
	sky.alignment = BoxContainer.ALIGNMENT_CENTER
	sky.add_theme_constant_override("separation", 4)
	sky.mouse_filter = Control.MOUSE_FILTER_STOP
	sky.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			sky_tapped.emit())
	middle.add_child(sky)
	var px := UiTheme.size("font_clock") * SKY_ICON
	season_icon = UiIcon.make("sun", px)
	weather_icon = UiIcon.make("sun", px)
	for icon: UiIcon in [season_icon, weather_icon]:
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sky.add_child(icon)
	clock = Label.new()
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock.add_theme_font_size_override("font_size", UiTheme.text_px("font_clock"))
	clock.add_theme_color_override("font_color", UiTheme.color("hud_hint"))
	clock.add_theme_color_override("font_shadow_color", UiTheme.color("bar_text_shadow"))
	clock.add_theme_constant_override("shadow_offset_y", 1)
	sky.add_child(clock)
	# The forecast (our own touch): when rain is due or will stop, so a visit can be planned round it.
	forecast = Label.new()
	forecast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forecast.add_theme_font_size_override("font_size", UiTheme.text_px("font_clock"))
	forecast.add_theme_color_override("font_color", UiTheme.color("hud_hint"))
	forecast.add_theme_color_override("font_shadow_color", UiTheme.color("bar_text_shadow"))
	forecast.add_theme_constant_override("shadow_offset_y", 1)
	forecast.visible = false
	middle.add_child(forecast)

	xp = UiKit.xp_bar()
	xp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	xp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	xp.offset_right = -margin
	xp.offset_left = -margin - xp.custom_minimum_size.x
	xp.offset_top = margin * 0.5
	xp.offset_bottom = margin * 0.5 + xp.custom_minimum_size.y
	root.add_child(xp)


## The forecast line for what the sky does next (Game.forecast: {name, at, starts}; {} hides it): rain to come
## says what it is worth, rain falling says when it stops.
func show_forecast(next: Dictionary) -> void:
	var at_unix := int(next.get("at", -1))
	if at_unix == _forecast_at:
		return   # (asked every second; it changes every few hours)
	_forecast_at = at_unix
	forecast.visible = not next.is_empty()
	if next.is_empty():
		return
	var at := DayCycle.clock_text(DayCycle.local_hour(int(next["at"]), DayCycle.device_bias_minutes()))
	if next["starts"]:
		forecast.text = tr("FORECAST_STARTS") % [tr(str(next["name"])), at,
			roundi(Balance.f("seasons.rain_bonus") * 100.0)]
	else:
		forecast.text = tr("FORECAST_ENDS") % [tr(str(next["name"])), at]


## The farm's name as the player set it (Settings), or "My Farm".
static func farm_name() -> String:
	var own := Game.player.farm_name.strip_edges()
	return own if own != "" else TranslationServer.translate("MY_FARM")


## What hides with the interface (the eye toggle).
func hideable() -> Array[Control]:
	var out: Array[Control] = [coins.get_parent(), plaque.get_parent(), xp]
	return out


## Shows a new name on the plaque.
func show_name() -> void:
	(plaque.get_meta("label") as Label).text = farm_name()
