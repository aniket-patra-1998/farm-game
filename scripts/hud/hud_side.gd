class_name HudSide
extends RefCounted
## The sides of the screen, FarmVille's way: at the left the view toggles (hide the interface, sound on/off); at the
## right the menu (Market, Collections, Ribbons, Neighbours, Settings) and the zoom buttons; at the bottom left the
## neighbours' strip (a placeholder until neighbours land: their names from the social system, our own touch).

const STRIP_NEIGHBOURS := 4      # neighbours shown on the strip

var hud: FarmHud
var toggles: VBoxContainer
var menu: VBoxContainer
var zoom: HBoxContainer
var strip: PanelContainer
var _eye: Button
var _sound: Button


func _init(owner: FarmHud) -> void:
	hud = owner


func build(root: Control) -> void:
	var margin := UiTheme.size("hud_margin")
	var gap := UiTheme.size("hud_gap")
	var top := UiTheme.size("top_height") + margin

	toggles = VBoxContainer.new()
	toggles.position = Vector2(margin, top)
	toggles.add_theme_constant_override("separation", int(gap))
	root.add_child(toggles)
	_eye = UiKit.icon_button("eye", UiTheme.size("toggle_size"))
	_eye.pressed.connect(func() -> void: hud.set_interface_hidden(not hud.interface_hidden))
	toggles.add_child(_eye)
	_sound = UiKit.icon_button("speaker", UiTheme.size("toggle_size"))
	_sound.pressed.connect(func() -> void:
		Sound.muted = not Sound.muted
		show_sound())
	toggles.add_child(_sound)
	show_sound()

	menu = VBoxContainer.new()
	menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu.offset_right = -margin
	menu.offset_top = top + gap
	menu.add_theme_constant_override("separation", int(gap))
	root.add_child(menu)
	var w := UiTheme.size("side_width")
	var h := UiTheme.size("side_height")
	for entry: Array in [["market", "MARKET", hud._show_market], ["album", "COLLECTIONS", hud._show_collections],
			["ribbon", "RIBBONS", hud._show_ribbons], ["neighbours", "NEIGHBOURS", _show_neighbours],
			["gear", "SETTINGS", hud._show_settings]]:
		var b := UiKit.tool_button(str(entry[0]), tr(str(entry[1])), w, h, UiTheme.size("side_icon"))
		b.pressed.connect(entry[2])
		menu.add_child(b)

	zoom = HBoxContainer.new()
	zoom.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	zoom.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	zoom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	zoom.offset_right = -margin
	zoom.offset_bottom = -(UiTheme.size("bottom_height") + margin + gap)
	zoom.add_theme_constant_override("separation", int(gap))
	root.add_child(zoom)
	for entry: Array in [["zoom_in", 1.25], ["zoom_out", 0.8], ["fit", 0.0]]:
		var b := UiKit.icon_button(str(entry[0]), UiTheme.size("zoom_size"))
		var factor: float = entry[1]
		b.pressed.connect(func() -> void: hud.zoom_view(factor))
		zoom.add_child(b)

	strip = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", UiKit.panel_box())
	strip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	strip.offset_left = margin
	strip.offset_bottom = -margin
	root.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(gap * 0.6))
	strip.add_child(row)
	var names := Game.social.roster()
	for k in mini(STRIP_NEIGHBOURS, names.size()):
		var b := UiKit.tool_button("neighbours", names[k], UiTheme.size("neighbour_width"), UiTheme.size("tool_size"))
		b.pressed.connect(_show_neighbours)
		row.add_child(b)


## The speaker shows struck through while the sound is off.
func show_sound() -> void:
	(_sound.get_meta("icon") as UiIcon).struck = Sound.muted


## Neighbours aren't in the game yet: say so.
func _show_neighbours() -> void:
	hud.show_message(tr("NEIGHBOURS_SOON"))


## Everything but the eye, to hide with it.
func hideable() -> Array[Control]:
	var out: Array[Control] = [_sound, menu, zoom, strip]
	return out


func show_eye(hidden: bool) -> void:
	(_eye.get_meta("icon") as UiIcon).struck = hidden
