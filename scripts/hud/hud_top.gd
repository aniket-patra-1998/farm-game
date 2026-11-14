class_name HudTop
extends RefCounted
## The top of the screen, FarmVille's way: the coin and cash bars at the left (their "+" opens the Market), the
## farm's name on a plaque in the middle with the season, weather and time under it, and the XP bar with the
## level star at the right. Built from the kit (UiKit); the counters' values are set by FarmHud.

var hud: FarmHud
var coins: PanelContainer
var gems: PanelContainer
var coins_label: Label
var gems_label: Label
var plaque: PanelContainer
var clock: Label
var xp: UiXpBar


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
	clock = Label.new()
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock.add_theme_font_size_override("font_size", int(UiTheme.size("font_clock")))
	clock.add_theme_color_override("font_color", UiTheme.color("hud_hint"))
	clock.add_theme_color_override("font_shadow_color", UiTheme.color("bar_text_shadow"))
	clock.add_theme_constant_override("shadow_offset_y", 1)
	middle.add_child(clock)

	xp = UiKit.xp_bar()
	xp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	xp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	xp.offset_right = -margin
	xp.offset_left = -margin - xp.custom_minimum_size.x
	xp.offset_top = margin * 0.5
	xp.offset_bottom = margin * 0.5 + xp.custom_minimum_size.y
	root.add_child(xp)


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
