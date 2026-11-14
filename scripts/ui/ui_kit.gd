class_name UiKit
extends RefCounted
## The interface's parts, built from the theme: a wooden panel, a glossy meter with an icon (coins, cash), a
## name plaque, a square icon button, the XP bar with its star. The HUD and the panels use these and nothing
## else, so every screen looks like one game.


## A wooden panel's style (the frame of the HUD's bars and of every panel).
static func panel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color("wood")
	sb.border_color = UiTheme.color("wood_dark")
	sb.set_border_width_all(int(UiTheme.size("panel_border")))
	sb.set_corner_radius_all(int(UiTheme.size("panel_radius")))
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	return sb


## A glossy rounded bar: a face colour, a darker edge, and a light sheen over its top half.
static func meter_box(face: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.border_color = edge
	sb.set_border_width_all(int(UiTheme.size("bar_border")))
	sb.set_corner_radius_all(int(UiTheme.size("bar_radius")))
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb


## A counter with its icon on the left and a number (the coins, the cash). `kind` is "coin" or "gem". With
## `plus` a "+" button sits at its right end (what opens the Market); `value_label` and `plus_button` are found
## by those meta names on the returned control.
static func meter(kind: String, plus := false) -> PanelContainer:
	var coin := kind == "coin"
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", meter_box(UiTheme.color("coin_bar" if coin else "cash_bar"),
		UiTheme.color("coin_bar_dark" if coin else "cash_bar_dark")))
	box.custom_minimum_size.y = UiTheme.size("bar_height")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiTheme.size("bar_padding")))
	box.add_child(row)
	row.add_child(UiIcon.make(kind))
	var value := Label.new()
	value.add_theme_font_size_override("font_size", int(UiTheme.size("font_bar")))
	value.add_theme_color_override("font_color", UiTheme.color("bar_text"))
	value.add_theme_color_override("font_shadow_color", UiTheme.color("bar_text_shadow"))
	value.add_theme_constant_override("shadow_offset_y", 2)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	box.set_meta("value_label", value)
	if plus:
		var add := icon_button("plus", UiTheme.size("bar_height") - 8.0)
		add.add_theme_stylebox_override("normal", meter_box(UiTheme.color("plus_face"), UiTheme.color("coin_bar_dark")))
		add.add_theme_stylebox_override("pressed", meter_box(UiTheme.color("coin_bar_dark"), UiTheme.color("ink")))
		add.add_theme_stylebox_override("hover", meter_box(UiTheme.color("plus_face").lightened(0.15),
			UiTheme.color("coin_bar_dark")))
		row.add_child(add)
		box.set_meta("plus_button", add)
	return box


## A square button with an icon: a cream face, a dark edge, the icon centred.
static func icon_button(kind: String, side := 0.0) -> Button:
	var px := side if side > 0.0 else UiTheme.size("button_size")
	var b := Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var face := UiTheme.color("button_face_down" if state.contains("pressed") else "button_face")
		if state == "hover":
			face = face.lightened(0.25)
		var sb := StyleBoxFlat.new()
		sb.bg_color = face
		sb.border_color = UiTheme.color("button_edge")
		sb.set_border_width_all(int(UiTheme.size("button_border")))
		sb.set_corner_radius_all(int(UiTheme.size("button_radius")))
		b.add_theme_stylebox_override(state, sb)
	var icon := UiIcon.make(kind, px * 0.62)
	icon.size = icon.custom_minimum_size
	icon.position = (Vector2(px, px) - icon.size) / 2.0
	b.add_child(icon)
	b.set_meta("icon", icon)
	return b


## A brown name plaque (the farm's name).
static func plaque(text: String) -> PanelContainer:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color("plaque")
	sb.border_color = UiTheme.color("wood_dark")
	sb.set_border_width_all(int(UiTheme.size("button_border")))
	sb.set_corner_radius_all(int(UiTheme.size("plaque_radius")))
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	box.add_theme_stylebox_override("panel", sb)
	box.custom_minimum_size.y = UiTheme.size("plaque_height")
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(UiTheme.size("font_plaque")))
	label.add_theme_color_override("font_color", UiTheme.color("plaque_text"))
	box.add_child(label)
	box.set_meta("label", label)
	return box


## The level meter with its star.
static func xp_bar() -> UiXpBar:
	return UiXpBar.make()


## A tool or menu button: an icon over a short label, on a cream face; lit (the tool in hand) when pressed.
## `w` and `h` default to the theme's tool size.
static func tool_button(kind: String, words: String, w := 0.0, h := 0.0, icon_px := 0.0) -> Button:
	var bw := w if w > 0.0 else UiTheme.size("tool_size")
	var bh := h if h > 0.0 else UiTheme.size("tool_size")
	var b := Button.new()
	b.custom_minimum_size = Vector2(bw, bh)
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var face := UiTheme.color("tool_face_on" if state.contains("pressed") else "button_face")
		if state == "hover":
			face = face.lightened(0.25)
		var sb := StyleBoxFlat.new()
		sb.bg_color = face
		sb.border_color = UiTheme.color("cream") if state.contains("pressed") else UiTheme.color("button_edge")
		sb.set_border_width_all(int(UiTheme.size("button_border")))
		sb.set_corner_radius_all(int(UiTheme.size("button_radius")))
		b.add_theme_stylebox_override(state, sb)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var icon := UiIcon.make(kind, icon_px if icon_px > 0.0 else UiTheme.size("tool_icon"))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var label := Label.new()
	label.text = words
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(UiTheme.size("font_tool")))
	label.add_theme_color_override("font_color", UiTheme.color("tool_label"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	b.set_meta("icon", icon)
	b.set_meta("label", label)
	return b
