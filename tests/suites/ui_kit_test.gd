extends TestSuite
## The interface kit: every colour and size it asks the theme for exists, each icon draws (rendered ones have a
## model), each part builds, tool names fade once learned, a long press names a button, and panel text is
## scaled once.


func test_215_the_theme_has_every_name_the_kit_asks_for() -> void:
	var names := {"colors": [], "sizes": []}
	for file in ["res://scripts/ui/ui_kit.gd", "res://scripts/ui/ui_icon.gd", "res://scripts/ui/ui_xp_bar.gd"]:
		var text := FileAccess.get_file_as_string(file)
		var rx := RegEx.new()
		rx.compile("UiTheme\\.(color|size)\\(\"([a-z_]+)\"\\)")
		for m in rx.search_all(text):
			(names["colors" if m.get_string(1) == "color" else "sizes"] as Array).append(m.get_string(2))
	_check(not (names["colors"] as Array).is_empty(), "the kit asks for colours")
	for key: String in names["colors"]:
		_check(UiTheme.colors().has(key), "colour '%s' is in ui_theme.json" % key)
	for key: String in names["sizes"]:
		_check(UiTheme.sizes().has(key), "size '%s' is in ui_theme.json" % key)


func test_216_every_icon_has_a_drawing_and_every_part_builds() -> void:
	for kind in UiIcon.KINDS:
		var icon := UiIcon.make(kind)
		_eq(icon.kind, kind, "icon %s" % kind)
		_check(icon.custom_minimum_size.x > 0.0, "%s has a size" % kind)
		icon.free()
	var coins := UiKit.meter("coin", true)
	_check(coins.has_meta("value_label") and coins.has_meta("plus_button"), "the coin meter has its label and plus")
	var cash := UiKit.meter("gem")
	_check(cash.has_meta("value_label") and not cash.has_meta("plus_button"), "a meter without a plus has none")
	var button := UiKit.icon_button("eye")
	_check(button.custom_minimum_size.x >= 48.0, "an icon button is at least 48 px, a finger's width")
	var plaque := UiKit.plaque("Farm")
	_eq((plaque.get_meta("label") as Label).text, "Farm", "the plaque shows its name")
	var xp := UiKit.xp_bar()
	xp.ratio = 2.0
	_eq(xp.ratio, 1.0, "the XP bar's fill is held between empty and full")
	for n: Node in [coins, cash, button, plaque, xp]:
		n.free()


func test_339_every_rendered_icon_has_a_model() -> void:
	for kind in UiModels.KINDS:
		_check(kind in UiIcon.KINDS, "rendered icon %s is an icon kind" % kind)
		var model := UiModels.build(kind)
		_check(model != null and model.get_child_count() > 0, "icon %s builds a model" % kind)
		if model != null:
			model.free()
	_check(UiModels.build("eye") == null, "a glyph has no model (it stays drawn)")


func test_340_a_tools_name_shows_until_it_is_learned() -> void:
	var id := "test_tool"
	PlayerSettings.keep(HudTools.LEARNED, {id: null})
	_check(not HudTools.learned(id), "a new tool is not learned")
	for k in HudTools.LEARN_USES - 1:
		_check(not HudTools.count_pick(id), "pick %d: its name still shows" % (k + 1))
	_check(HudTools.count_pick(id), "picked LEARN_USES times, it is learned")
	_check(HudTools.count_pick(id), "and stays learned")
	_eq(int(PlayerSettings.value(HudTools.LEARNED, id, 0)), HudTools.LEARN_USES, "the count stops at LEARN_USES")
	PlayerSettings.keep(HudTools.LEARNED, {id: null})
	var shown := UiKit.tool_button("hoe", "Plow", 64.0, 64.0, 0.0)
	var bare := UiKit.tool_button("hoe", "Plow", 64.0, 64.0, 0.0, null, false)
	_check((shown.get_meta("label") as Label).visible, "a labelled tool shows its name")
	_check(not (bare.get_meta("label") as Label).visible, "a learned tool shows its picture only")
	_eq(bare.tooltip_text, "Plow", "and keeps its name for a long press")
	shown.free()
	bare.free()


func test_341_a_long_press_names_the_button_without_pressing_it() -> void:
	var b := Button.new()
	UiKit.long_press_name(b, "Market")
	var timers := b.get_children().filter(func(n: Node) -> bool: return n is Timer)
	_eq(timers.size(), 1, "a long press is timed")
	_eq((timers[0] as Timer).wait_time, UiKit.LONG_PRESS, "for LONG_PRESS seconds")
	_check((timers[0] as Timer).one_shot, "once per hold")
	(timers[0] as Timer).timeout.emit()   # (held long enough)
	_check(b.disabled, "the hold drops the press under way, so letting go doesn't press it")
	b.free()


func test_342_panel_text_is_scaled_once_and_never_too_small() -> void:
	_eq(UiTheme.font_for(20.0, 1.0, 0.9), 18, "a design size at scale 1 and share 0.9")
	_eq(UiTheme.font_for(30.0, 0.7, 0.9), 19, "smaller on a smaller interface, rounded")
	_eq(UiTheme.font_for(12.0, 0.7, 0.9), UiTheme.MIN_FONT, "never under MIN_FONT")
	_eq(BookPanel.font_px(20), UiTheme.font(20.0), "panels size their text through UiTheme.font")
	_eq(UiTheme.design("font_section") * UiTheme.scale(), UiTheme.size("font_section"), "design is size before scale")
	for file in ["res://scripts/hud.gd", "res://scripts/level_up_popup.gd", "res://scripts/book_panel.gd"]:
		var rx := RegEx.create_from_string("font_size\", [0-9]")
		_check(rx.search(FileAccess.get_file_as_string(file)) == null, "%s sizes no text by a bare number" % file)
	var market := FileAccess.get_file_as_string("res://scripts/hud/hud_market.gd")
	_check(not market.contains("BookPanel.text(tr(str(section[1])), int(UiTheme.size("), "no scaled size scaled again")


func test_344_a_picture_is_cut_out_from_its_renders_on_black_and_white() -> void:
	var side := 8
	var black := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var white := Image.create(side, side, false, Image.FORMAT_RGBA8)
	black.fill(Color.BLACK)
	white.fill(Color.WHITE)
	var red := Color8(200, 40, 40)
	for y in side:   # the left half solid red, one column half see-through, the rest background
		for x in 3:
			black.set_pixel(x, y, red)
			white.set_pixel(x, y, red)
		black.set_pixel(3, y, Color8(100, 20, 20))
		white.set_pixel(3, y, Color8(228, 148, 148))
	var job := IconDevelop.new("t", black, white, side, false, false)
	while not job.step():
		pass
	var pic := job.picture
	_eq(pic.get_pixel(1, 4).a8, 255, "a solid pixel stays solid")
	_eq(pic.get_pixel(1, 4).r8, 200, "with its own colour")
	_eq(pic.get_pixel(6, 4).a8, 0, "the background is see-through: no grey square")
	_check(absi(pic.get_pixel(3, 4).a8 - 127) <= 2, "an edge lets half through")
	_check(absi(pic.get_pixel(3, 4).r8 - 200) <= 3, "and keeps the item's colour, not the background's")
	var shaded := IconDevelop.new("t", black, white, side, false, true)
	while not shaded.step():
		pass
	_check(shaded.picture.get_pixel(6, side - 1).a8 < 255, "the shadow is soft and see-through")


## Every vector icon (art/icons/ui) loads and is drawn at the size asked for, with see-through corners.
func test_384_vector_icons_draw() -> void:
	var dir := DirAccess.open(UiSvg.DIR)
	var count := 0
	for f in dir.get_files():
		if not f.ends_with(".svg"):
			continue
		count += 1
		var kind := f.get_basename()
		var tex := UiSvg.of(kind, 40.0)
		_check(tex != null, "%s draws" % kind)
		if tex != null:
			var img := tex.get_image()
			_check(img.get_width() >= 40 and img.get_pixel(0, 0).a < 0.1, "%s is its size, see-through round it" % kind)
	_check(count >= 20, "the HUD's icons are files")
	_check(UiSvg.of("no_such_icon", 40.0) == null, "a kind with no file draws nothing (the drawn one stays)")
