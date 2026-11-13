extends TestSuite
## The interface kit: every colour and size it asks the theme for exists, each icon draws, and each part builds.


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
