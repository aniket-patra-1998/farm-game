class_name UiKit
extends RefCounted
## The interface's parts, built from the theme: a wooden panel, a glossy meter with an icon (coins, cash), a
## name plaque, a square icon button, the XP bar with its star. The HUD and the panels use these and nothing
## else, so every screen looks like one game.


## A wooden panel's style (the frame of the HUD's bars and of every panel).
const LONG_PRESS := 0.45     # seconds held before a button's name shows (and the press is let go)
const BUBBLE_SECONDS := 1.2   # how long a name bubble stays
const PAPER_RADIUS := 26       # a sheet's or a panel's corners
const PAPER_SHADOW := 14       # ..and its soft shadow
const METER_SHADOW := 0.14   # the soft shadow under a HUD pill or round button
const HALO := 0.5            # a HUD button's paper disc under a finger (its alpha)..
const HALO_ON := 0.85        # ..and round the tool in hand
const HALO_RING := 1.6       # the tool in hand's green ring, against a button's edge
const FLOAT_ICON := 0.82     # a floating button's icon, of its size (no disc round it to leave room for)

static var _paper_theme: Theme

## The one surface of the interface (the unified look, docs/UI.md): warm paper with round corners and a soft
## shadow, no frame. Every panel, sheet, card that floats and the tool panel stand on it.

static func panel_box(radius := -1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color("paper")
	sb.set_corner_radius_all(radius if radius >= 0 else int(UiTheme.size("panel_radius")))
	sb.shadow_color = Color(0, 0, 0, 0.26)
	sb.shadow_size = PAPER_SHADOW
	sb.shadow_offset = Vector2(0, 3)
	return sb


## A panel or sheet's own paper (`panel_box` at the large radius, with `margin` inside).
static func paper_box(margin: float) -> StyleBoxFlat:
	var sb := panel_box(PAPER_RADIUS)
	sb.set_content_margin_all(margin)
	return sb


## What stands on paper reads the paper way: dark ink words, flat boxes (no box in a box), a light track with
## the accent fill for bars. Set on a panel's or sheet's root; its buttons keep the interface's own.
static func paper_theme() -> Theme:
	if _paper_theme == null:
		var t := Theme.new()
		t.set_color("font_color", "Label", UiTheme.color("ink"))
		var flat := StyleBoxEmpty.new()
		t.set_stylebox("panel", "PanelContainer", flat)
		var track := StyleBoxFlat.new()
		track.bg_color = UiTheme.color("track")
		track.set_corner_radius_all(7)
		var fill := StyleBoxFlat.new()
		fill.bg_color = UiTheme.color("accent")
		fill.set_corner_radius_all(7)
		t.set_stylebox("background", "ProgressBar", track)
		t.set_stylebox("fill", "ProgressBar", fill)
		_paper_theme = t
	return _paper_theme


## The close button of every panel and sheet: the same round cross everywhere.
static func close_button() -> Button:
	var b := icon_button("cross", UiTheme.size("toggle_size") * 0.8)
	b.tooltip_text = TranslationServer.translate("CLOSE")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## A quiet text button (Move, Turn, Sell): there, but not what the panel is about. The same everywhere.
static func quiet_button(words: String, px: int) -> Button:
	var b := Button.new()
	b.text = words
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", px)
	b.add_theme_color_override("font_color", UiTheme.color("soft"))
	b.add_theme_color_override("font_hover_color", UiTheme.color("ink"))
	b.add_theme_color_override("font_pressed_color", UiTheme.color("ink"))
	b.add_theme_color_override("font_disabled_color", UiTheme.color("track").darkened(0.15))
	UiFx.press_bounce(b)
	return b


## Makes `b` the one main action of what it stands in (Collect, Make, Buy...): filled with the accent, white words.
## A panel or sheet has at most one.
static func primary(b: Button) -> Button:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTheme.color("accent").darkened(0.12) if state.contains("pressed") else UiTheme.color("accent")
		if state == "disabled":
			sb.bg_color = UiTheme.color("track")
		sb.set_corner_radius_all(int(UiTheme.size("button_radius")) + 6)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		b.add_theme_stylebox_override(state, sb)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, UiTheme.color("accent_text"))
	b.add_theme_color_override("font_disabled_color", UiTheme.color("soft"))
	return b


## A glossy rounded bar: a face colour, a darker edge, and a light sheen over its top half.
static func meter_box(face: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.border_color = edge
	sb.set_border_width_all(int(UiTheme.size("bar_border")))
	sb.set_corner_radius_all(int(UiTheme.size("bar_height") / 2.0))   # (a pill)
	sb.shadow_color = Color(0, 0, 0, METER_SHADOW)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 1)
	return sb


## A counter with its icon on the left and a number (the coins, the cash): a paper pill, the number in bold ink
## (the modern look: one surface, no coloured boxes). `kind` is "coin" or "gem". With `plus` a small round green
## "+" sits at its right end (what opens the Market); `value_label` and `plus_button` are found by those meta names
## on the returned control.
static func meter(kind: String, plus := false) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", meter_box(UiTheme.color("paper"), UiTheme.color("card_edge")))
	box.custom_minimum_size.y = UiTheme.size("bar_height")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiTheme.size("bar_padding")))
	box.add_child(row)
	row.add_child(UiIcon.make(kind))
	var value := Label.new()
	value.add_theme_font_override("font", UiTheme.bold())
	value.add_theme_font_size_override("font_size", UiTheme.text_px("font_bar"))
	value.add_theme_color_override("font_color", UiTheme.color("ink"))
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	box.set_meta("value_label", value)
	if plus:
		var add := icon_button("plus", UiTheme.size("bar_height") - 8.0)
		add.add_theme_stylebox_override("normal", meter_box(UiTheme.color("accent"), UiTheme.color("accent")))
		add.add_theme_stylebox_override("pressed", meter_box(UiTheme.color("coin_bar_dark"), UiTheme.color("coin_bar_dark")))
		add.add_theme_stylebox_override("hover", meter_box(UiTheme.color("accent").lightened(0.15),
			UiTheme.color("accent")))
		row.add_child(add)
		box.set_meta("plus_button", add)
	return box


## A round button with an icon: a cream face, a dark edge, the icon centred.
static func icon_button(kind: String, side := 0.0) -> Button:
	var px := side if side > 0.0 else UiTheme.size("button_size")
	var b := Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.focus_mode = Control.FOCUS_NONE
	_float_states(b, px, px)
	var icon := UiIcon.make(kind, px * FLOAT_ICON)
	icon.size = icon.custom_minimum_size
	icon.position = (Vector2(px, px) - icon.size) / 2.0
	b.add_child(icon)
	b.set_meta("icon", icon)
	UiFx.press_bounce(b)
	return b


## A HUD button's look (the modern look: the icon is the button, a flat sticker floating over the farm): nothing
## drawn at rest, a soft paper disc under a finger, and a fuller one ringed green while it is the one in hand.
static func _float_states(b: Button, w: float, h: float) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		if state in ["normal", "disabled"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			continue
		var on := (state as String).contains("pressed")
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(UiTheme.color("paper"), HALO_ON if on else HALO)
		if on:   # (green on the grass would vanish: the paper disc carries it, its ring says "in hand")
			sb.border_color = UiTheme.color("accent")
			sb.set_border_width_all(int(UiTheme.size("button_border") * HALO_RING))
		sb.set_corner_radius_all(int(minf(w, h) / 2.0))
		b.add_theme_stylebox_override(state, sb)


## A brown name plaque (the farm's name).
static func plaque(text: String) -> PanelContainer:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color("paper")   # (a paper pill like the counters)
	sb.border_color = UiTheme.color("card_edge")
	sb.set_border_width_all(int(UiTheme.size("bar_border")))
	sb.set_corner_radius_all(int(UiTheme.size("plaque_height") / 2.0))
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	box.add_theme_stylebox_override("panel", sb)
	box.custom_minimum_size.y = UiTheme.size("plaque_height")
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", UiTheme.text_px("font_plaque"))
	label.add_theme_color_override("font_color", UiTheme.color("ink"))
	box.add_child(label)
	box.set_meta("label", label)
	return box


## The level meter with its star.
static func xp_bar() -> UiXpBar:
	return UiXpBar.make()


## A tool or menu button: an icon over a short label, floating (no face; a green halo round the tool in hand).
## `w` and `h` default to the theme's tool size.
static func tool_button(kind: String, words: String, w := 0.0, h := 0.0, icon_px := 0.0,
		picture: UiIcon = null, labelled := true) -> Button:
	var bw := w if w > 0.0 else UiTheme.size("tool_size")
	var bh := h if h > 0.0 else UiTheme.size("tool_size")
	var b := Button.new()
	b.custom_minimum_size = Vector2(bw, bh)
	b.focus_mode = Control.FOCUS_NONE
	_float_states(b, bw, bh)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var px := icon_px if icon_px > 0.0 else UiTheme.size("tool_icon")
	if not labelled:   # no words under it: the picture takes the room
		px = minf(bw, bh) * UiTheme.size("icon_alone_share")
	var icon := picture if picture != null else UiIcon.make(kind, px)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var label := Label.new()
	label.text = words
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FloatText.style(label, int(UiTheme.design("font_tool")))   # (over the farm: white with an outline, as all its words)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = labelled
	box.add_child(label)
	if labelled:   # (a longer word, "Fertilize", widens its button rather than being cut or shrunk)
		var font := label.get_theme_default_font()
		var wide := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.text_px("font_tool")).x
		b.custom_minimum_size.x = maxf(bw, wide + UiTheme.size("button_pad"))
	b.set_meta("icon", icon)
	b.set_meta("label", label)
	long_press_name(b, words)
	UiFx.press_bounce(b)
	return b


## Holding `button` a moment shows its name in a small bubble above it (an icon-only button's name, on a phone
## where nothing hovers), and that hold doesn't press it.
static func long_press_name(button: BaseButton, words: String) -> void:
	button.tooltip_text = words
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = LONG_PRESS
	button.add_child(timer)
	button.button_down.connect(timer.start)
	button.button_up.connect(timer.stop)
	timer.timeout.connect(func() -> void:
		# Off for a moment: that drops the press under way, so letting go doesn't press it; on again next frame.
		button.disabled = true
		button.set_deferred("disabled", false)
		name_bubble(button, button.tooltip_text if button.tooltip_text != "" else words))


## A small name bubble over `control` that fades after a moment.
static func name_bubble(control: Control, words: String) -> void:
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", panel_box())
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", UiTheme.text_px("font_tool"))
	label.add_theme_color_override("font_color", UiTheme.color("tool_label"))
	bubble.add_child(label)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.top_level = true
	control.add_child(bubble)
	bubble.reset_size()
	bubble.global_position = control.global_position + Vector2((control.size.x - bubble.size.x) / 2.0,
		-bubble.size.y - UiTheme.size("hud_gap"))
	var fade := bubble.create_tween()
	fade.tween_interval(BUBBLE_SECONDS)
	fade.tween_property(bubble, "modulate:a", 0.0, 0.25)
	fade.finished.connect(bubble.queue_free)


## A tab of a panel (the Market's shelves): wooden when not shown, cream when it is.
static func tab_button(words: String, on: bool) -> Button:
	var b := Button.new()
	b.text = words
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = UiTheme.size("tab_height")
	b.add_theme_font_size_override("font_size", UiTheme.text_px("font_tab"))
	var face := UiTheme.color("tab_face_on" if on else "tab_face")
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = face.lightened(0.12) if state == "hover" and not on else face   # (pills on paper, no frame)
		sb.set_corner_radius_all(int(UiTheme.size("tab_height") / 2.0))
		sb.content_margin_left = UiTheme.size("tab_pad")
		sb.content_margin_right = UiTheme.size("tab_pad")
		b.add_theme_stylebox_override(state, sb)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, UiTheme.color("tab_text_on" if on else "tab_text"))
	UiFx.press_bounce(b)
	return b


## What a home, a store or a recipe holds, FarmVille's way: each thing as its picture with its count on it and its
## name under it (`entries`: [[item id, count text, short]], `short` paints the count in the price-short red: not
## enough yet). One row that wraps, for every "what's inside" in the game.
static func count_row(entries: Array, named := true) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap") * 0.5))
	flow.add_theme_constant_override("v_separation", int(UiTheme.size("hud_gap") * 0.5))
	for e: Array in entries:
		var id := str(e[0])
		var tile := count_tile(ItemIcons.of(id), str(e[1]), Game.name_of(id) if named else "", e.size() > 2 and bool(e[2]))
		tile.tooltip_text = Game.name_of(id)
		flow.add_child(tile)
	return flow


## One thing and how many: its picture (a texture, or a drawn Control such as a ThingIcon) on a soft tile of the
## theme's colour `face`, the count in a corner, its name underneath (one line).
static func count_tile(picture: Variant, count: String, name: String, short := false, face := "count_tile") -> Control:
	var side := UiTheme.size("count_tile")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size.x = side
	col.tooltip_text = name
	var tile := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color(face)
	sb.set_corner_radius_all(int(UiTheme.size("button_radius")))
	tile.add_theme_stylebox_override("panel", sb)
	tile.custom_minimum_size = Vector2.ONE * side
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tile)
	if picture is Control:
		tile.add_child(picture)
	else:
		var pic := TextureRect.new()
		pic.texture = picture
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(pic)
	var label := Label.new()
	label.text = count
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", UiTheme.text_px("font_badge"))
	if short:
		# Not enough of it ("0/4"): a red pill with white words under the corner, read at a glance.
		var pill := StyleBoxFlat.new()
		pill.bg_color = UiTheme.color("badge")
		pill.set_corner_radius_all(int(UiTheme.size("button_radius")))
		pill.content_margin_left = 4
		pill.content_margin_right = 4
		label.add_theme_stylebox_override("normal", pill)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.size_flags_horizontal = Control.SIZE_SHRINK_END
		label.size_flags_vertical = Control.SIZE_SHRINK_END
	else:
		label.add_theme_color_override("font_color", UiTheme.color("ink"))
		label.add_theme_color_override("font_outline_color", UiTheme.color(face))
		label.add_theme_constant_override("outline_size", int(UiTheme.size("count_outline")))
	tile.add_child(label)
	if name == "":   # (no name under it: its picture and count say it; the name is its tooltip)
		return col
	var caption := Label.new()
	caption.text = name
	caption.set_meta(&"count_name", true)
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.custom_minimum_size.x = side
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", UiTheme.text_px("font_count_name"))
	caption.add_theme_color_override("font_color", UiTheme.color("tool_label"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(caption)
	return col


## A small round count in the top right corner of `button` (things waiting). Returns its label; its parent
## (the round) is what to hide when the count is zero.
static func count_badge(button: Control) -> Label:
	var dot := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color("badge")
	sb.border_color = UiTheme.color("cream")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(UiTheme.size("badge_size")))
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	dot.add_theme_stylebox_override("panel", sb)
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	dot.offset_top = -UiTheme.size("badge_size") * 0.3
	dot.offset_right = UiTheme.size("badge_size") * 0.3
	dot.custom_minimum_size = Vector2.ONE * UiTheme.size("badge_size")
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", UiTheme.text_px("font_badge"))
	label.add_theme_color_override("font_color", UiTheme.color("cream"))
	dot.add_child(label)
	button.add_child(dot)
	return label


## An item's card in a shop grid: its picture, its name, a line about it and its price badge; the whole card is
## the button. A locked one is greyed with a lock and the level it opens at instead of a price. `extra` (its
## mastery stars, say) goes under the picture.
## A card's face (`face`, a theme colour), its edge and its corners: what every card in a grid is drawn with.
static func card_box(face := "card_face") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color(face)
	sb.border_color = UiTheme.color("card_edge")
	sb.set_border_width_all(int(UiTheme.size("button_border")))
	sb.set_corner_radius_all(int(UiTheme.size("button_radius")))
	return sb


## Keeps `card`, a panel floating free on the interface (not inside a container), exactly as big as what it holds,
## whenever that changes, then calls `place` (if given) so a card kept to an edge of the screen puts itself back.
## Godot only ever grows such a Control to its minimum size, never shrinks it: a card whose wrapped text was
## first measured before it had a width (one word a line, very tall), or that once held more, would otherwise
## stay that big for good, mostly empty, and pushed off the screen. Every free-floating card fits through this.
static func keep_fitted(card: Control, place := Callable()) -> void:
	var fit := func() -> void:
		if not is_instance_valid(card):
			return
		card.set_meta(&"fitting", false)
		card.size = Vector2.ZERO   # (a Control is never smaller than its minimum: this is the minimum)
		if place.is_valid():
			place.call()
	card.minimum_size_changed.connect(func() -> void:
		if not card.get_meta(&"fitting", false):   # (however many changes in a frame: fitted once, after them)
			card.set_meta(&"fitting", true)
			fit.call_deferred())


## Puts `c` in the middle of its parent and has it grow from there, both ways. A Control is centred by its size at
## the moment it is anchored, and one not yet in a tree has none (its `custom_minimum_size` comes later): left to
## grow the default way, its corner sits at the middle and it spills down and right. Centre things with this.
static func centered(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	return c
