extends TestSuite
## The interface kit: every colour and size it asks the theme for exists, each icon draws (rendered ones have a
## model), each part builds, tool names fade once learned, a long press names a button, and panel text is
## scaled once.

const ONE_ICON_SIZE := 0.84   # a vector icon's longest drawn side, at least, of its canvas (FIT 112 of 128)
## Everything that opens or closes (test 549): each goes through UiFx.open and UiFx.close.
const MOTION_SURFACES := ["res://scripts/book_panel.gd", "res://scripts/hud/building_sheet.gd",
	"res://scripts/hud/away_card.gd", "res://scripts/hud/reveal_card.gd", "res://scripts/level_up_popup.gd",
	"res://scripts/hud/hud_bubble.gd", "res://scripts/hud.gd", "res://scripts/ui/ui_kit.gd"]
## ..and the scripts that show or hide themselves for another reason: a sheet's tab row (shown with more than one
## tab, inside the sheet's motion), and the one that moves everything.
const MOTION_EXEMPT := ["sheet_tabs.gd", "ui_fx.gd"]


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
	var lifted: Array[int] = []
	for step: float in UiTheme.TYPE_SCALE:
		lifted.append(UiTheme.font_for(step, 0.5, 0.9))
	_eq(lifted[1], UiTheme.MIN_FONT, "body lifted to the floor on a small interface")
	for i in range(2, lifted.size()):
		_check(lifted[i] > lifted[i - 1], "type step %d still reads larger than the one below once lifted: %s"
			% [i, lifted])
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


## The vector icons share one visual size (tools/make_ui_icons.py fits a smaller drawing to the set's): the seed
## sack, fertilizer and ready pin drew about a tenth smaller than the barn and coin beside them in the tool bar.
func test_513_vector_icons_one_visual_size() -> void:
	for file in DirAccess.get_files_at(UiSvg.DIR):
		if not file.ends_with(".svg"):
			continue
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string(UiSvg.DIR + file), 1.0)
		var box := img.get_used_rect()
		_check(maxi(box.size.x, box.size.y) >= ONE_ICON_SIZE * img.get_width(), "%s fills the set's size (%s)" % [file, box])


## Every coloured shape of a vector icon is drawn: Godot's SVG renderer measures a curved path by its end points,
## so a gradient sized to the shape's box drew nothing on a dome or bowl whose ends sit level (the neighbours'
## bodies and hair, the seed sack's top, the stall's awning tabs). The gradients span the shape in its own units.
func test_453_every_vector_icons_shapes_are_drawn() -> void:
	var dir := "res://art/icons/ui/"
	var rx := RegEx.new()
	rx.compile("<linearGradient [^>]*>")
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".svg"):
			continue
		for m in rx.search_all(FileAccess.get_file_as_string(dir + file)):
			_check(m.get_string().contains("gradientUnits=\"userSpaceOnUse\""), "%s: a gradient in the shape's units" % file)
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string(dir + "neighbours.svg"), 1.0)
	var body := img.get_pixel(40, 96)   # the front neighbour's green shirt
	_check(body.a > 0.9 and body.g > body.r + 0.1, "the neighbours' shirt is drawn (was see-through white)")


## Panel words are sized by their role on the type scale (UiTheme.CAPTION..DISPLAY), never by a bare number: a
## size between two steps snapped silently, so a soft note asked for as 17 showed at heading size.
func test_491_panel_words_take_a_type_role_not_a_number() -> void:
	var call := RegEx.new()
	call.compile("BookPanel\\.(text|info)\\(")
	var bare := RegEx.new()
	bare.compile("^\\s*\\d+\\s*$")
	for dir: String in ["res://scripts/hud/", "res://scripts/"]:
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir + f)
			for m in call.search_all(text):
				var args := _args(text, m.get_end())
				var at := 2 if m.get_string(1) == "info" else 1
				if args.size() > at:
					_check(bare.search(args[at]) == null, "%s: BookPanel.%s(.., %s) takes a UiTheme type role" % [f,
						m.get_string(1), args[at].strip_edges()])


## Panels space on one grid: a gap between a card's lines, rows and buttons is a UiTheme size (hud_gap, row_gap,
## section_gap, scaled with the interface), never a bare number; only hairlines (0, 2, 4) stay bare. The cards'
## inner 6s sat off the grid beside their 8 neighbours. (hud_goals.gd is the goals loop's.)
func test_526_panel_gaps_sit_on_the_spacing_grid() -> void:
	var gap := RegEx.create_from_string("separation\", (\\d+)\\)")
	for dir: String in ["res://scripts/hud/", "res://scripts/", "res://scripts/ui/"]:
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd") or f == "hud_goals.gd":
				continue
			for m in gap.search_all(FileAccess.get_file_as_string(dir + f)):
				_check(int(m.get_string(1)) <= 4, "%s: a separation of %s is a UiTheme gap size" % [f, m.get_string(1)])



## The celebration cards (a mystery's reveal, a level-up) move in the interface's one language: every tween time
## is named (RevealCard's constants, UiFx's), shakes are eased, and nothing pulses in a loop (a level-up is the
## confetti; nothing else bounces).
func test_523_celebration_cards_move_in_one_language() -> void:
	var bare := RegEx.create_from_string("tween_property\\((?:[^()\\n]|\\([^()\\n]*\\))*, [0-9.]+\\)")
	for path: String in ["res://scripts/hud/reveal_card.gd", "res://scripts/level_up_popup.gd"]:
		var code := FileAccess.get_file_as_string(path)
		for m in bare.search_all(code):
			_check(false, "%s: a bare tween time (%s): name it" % [path, m.get_string()])
		_check(not code.contains("set_loops"), "%s: nothing pulses in a loop" % path)
	_check(RevealCard.SHAKE_TIME >= 0.2, "a shake is a rock, not a jitter")


## One motion language: anything springing back settles with one soft overshoot (UiFx.settle), never an elastic
## wobble; the counters' pulse replaces one still running instead of stacking tweens on the same size.
func test_510_nothing_springs_back_like_rubber() -> void:
	for dir: String in _script_dirs("res://scripts/"):
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				_check(not FileAccess.get_file_as_string(dir + f).contains("TRANS_ELASTIC"),
					"%s%s: a spring back is UiFx.settle, not TRANS_ELASTIC" % [dir, f])
	var c := Control.new()
	c.size = Vector2(40, 20)
	add_child(c)
	UiFx.pulse(c)
	var first: Variant = c.get_meta(&"fx_tween") if c.has_meta(&"fx_tween") else null
	UiFx.pulse(c)
	_check(first is Tween and not (first as Tween).is_valid(), "a second pulse replaces the first")
	_check(c.pivot_offset == c.size / 2.0, "a pulse swells from the middle")
	c.queue_free()


## `root` and every folder under it.
static func _script_dirs(root: String) -> PackedStringArray:
	var out := PackedStringArray([root])
	for d: String in DirAccess.get_directories_at(root):
		out.append_array(_script_dirs(root + d + "/"))
	return out

## The top-level arguments of a call whose "(" ends just before `from` (strings and brackets skipped).
static func _args(text: String, from: int) -> PackedStringArray:
	var out := PackedStringArray()
	var depth := 1
	var start := from
	var quote := ""
	var k := from
	while k < text.length() and depth > 0:
		var c := text[k]
		if quote != "":
			if c == "\\":
				k += 1
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c in "([{":
			depth += 1
		elif c in ")]}":
			depth -= 1
			if depth == 0:
				out.append(text.substr(start, k - start))
		elif c == "," and depth == 1:
			out.append(text.substr(start, k - start))
			start = k + 1
		k += 1
	return out


## A count tile's number sits in its bottom corner (the label fills the tile; centred, it lay across the picture's
## middle, over a tree's crown in an orchard's sheet). A "0/4" short of need stays a pill in the same corner.
func test_528_a_count_sits_in_the_tiles_corner() -> void:
	for short: bool in [false, true]:
		var t := UiKit.count_tile(PlaceholderTexture2D.new(), "×1", "", short)
		add_child(t)
		await get_tree().process_frame
		var tile: Control = t.get_child(0)
		var label: Label
		for c in tile.get_children():
			if c is Label:
				label = c
		var text_bottom := label.position.y + label.size.y
		_check(text_bottom >= tile.size.y - 1.0, "the count reaches the tile's bottom (short: %s): %.0f of %.0f"
			% [short, text_bottom, tile.size.y])
		_check(label.size.y < tile.size.y or label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM,
			"the count is written at the bottom (short: %s)" % short)
		t.queue_free()


## Panel motion (docs/ART_POLISH.md): every surface that opens or closes does it through UiFx's one motion, so
## nothing appears or vanishes in one frame. A surface's script never sets its own `visible` but to start hidden
## (UiFx.open and close do), and none is shown or hidden from outside.
func test_549_every_surface_opens_and_closes_through_ui_fx() -> void:
	var own := RegEx.create_from_string("(?<![\\w.])(?:self\\.)?visible\\s*=(?!=)|(?<![\\w.])(?:show|hide)\\(\\)")
	var outside := RegEx.create_from_string(
		"\\b(?:book|sheet|bubble|_away|_reveal|_level_popup|_placing_bar)\\.(?:visible\\s*=(?!=)|show\\(|hide\\()")
	var func_rx := RegEx.create_from_string("^(?:static )?func (\\w+)")
	for dir: String in _script_dirs("res://scripts/"):
		if dir.contains("/world3d/"):   # (the 3D farm's marks are not surfaces)
			continue
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd") or f in MOTION_EXEMPT:
				continue
			var in_func := ""
			var n := 0
			for line in FileAccess.get_file_as_string(dir + f).split("\n"):
				n += 1
				var code := line.get_slice("#", 0)
				var named := func_rx.search(code)
				if named != null:
					in_func = named.get_string(1)
				var starts_hidden := in_func in ["_init", "_ready"] and code.strip_edges() == "visible = false"
				_check(starts_hidden or own.search(code) == null,
					"%s%s:%d shows or hides itself without UiFx (UiFx.open / close)" % [dir, f, n])
				_check(outside.search(code) == null, "%s%s:%d shows or hides a surface without UiFx" % [dir, f, n])
	for path: String in MOTION_SURFACES:
		var code := FileAccess.get_file_as_string(path)
		_check(code.contains("UiFx.open") and code.contains("UiFx.close"), "%s opens and closes through UiFx" % path)


## A panel opens from faded, closes in the motion and only then hides; reopened mid-close it turns back from where
## it was (no jump); Game.modal_open follows it, and a closing panel takes no taps.
func test_550_a_panel_closes_after_its_motion_and_reopens_mid_close() -> void:
	Game.modal_open = false
	var book := BookPanel.new()
	add_child(book)
	var frame := book.get("_frame") as Control
	var dim := book.get("_dim") as Control
	var fill := func(c: VBoxContainer) -> void: c.add_child(Label.new())
	book.open_panel("Test", fill, BookPanel.Shape.LIST)
	_check(book.visible and book.is_open() and Game.modal_open, "it opens and the farm is covered")
	_check(frame.modulate.a < 0.05 and dim.modulate.a < 0.05, "it starts faded: no frame of it at rest first")
	var last := -1.0
	var rising := true
	for k in TestSuite.MOTION_FRAMES:
		if UiFx.share_of(book) >= 1.0:
			break
		rising = rising and frame.modulate.a >= last
		last = frame.modulate.a
		await get_tree().process_frame
	_check(rising, "it fades in steadily, never back")
	_check(frame.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(dim.modulate.a, 1.0), "and rests at its size")
	book.close_panel()
	_check(book.visible and not book.is_open() and not Game.modal_open, "closing: still drawn, no longer open")
	_check(dim.mouse_filter == Control.MOUSE_FILTER_IGNORE, "a closing panel takes no taps")
	await get_tree().create_timer(UiFx.CLOSE_TIME * 0.5).timeout
	var mid := frame.modulate.a
	_check(book.visible and mid > 0.0 and mid < 1.0, "half closed it is half faded")
	book.open_panel("Test", fill, BookPanel.Shape.LIST)
	_check(book.is_open() and Game.modal_open, "reopened mid-close it is open again")
	_check(absf(frame.modulate.a - mid) < 0.05, "and turns back from where it was")
	_check(dim.mouse_filter == Control.MOUSE_FILTER_STOP, "and takes taps again")
	await _motion_ends(book)
	_check(book.is_open() and is_equal_approx(frame.modulate.a, 1.0), "it comes back to rest, not hidden")
	book.close_panel()
	book.close_panel()   # (a second close keeps the motion running)
	await _motion_ends(book)
	_check(not book.visible and not Game.modal_open, "closed: hidden once the motion ends")
	_check(frame.scale.is_equal_approx(Vector2.ONE), "and left at its size for next time")
	var away := Control.new()   # (not on screen: no motion to wait for)
	away.visible = false
	UiFx.open(away)
	_check(away.visible and is_equal_approx(away.modulate.a, 1.0), "off the screen it opens at once")
	UiFx.close(away)
	_check(not away.visible, "and closes at once")
	away.free()
	book.queue_free()


## The icon glow (the owner's pick C, data/ui_theme.json "glow"): gold behind money and rewards, blue-white behind
## something new waiting, nothing behind any other icon or one too small to carry it; one shared still image; the
## menu's pictures glow while their dot or count shows.
func test_553_money_glows_gold_and_news_glows_blue_white() -> void:
	var big := 64.0
	for kind: String in ["coin", "gem", "star", "ribbon"]:
		_check(UiTheme.glow(kind, false, big) == UiTheme.color("glow_gold"), "%s glows gold" % kind)
	for kind: String in ["gear", "market", "hoe", "eye"]:
		_check(UiTheme.glow(kind, false, big).a == 0.0, "%s has no glow" % kind)
	_check(UiTheme.glow("inbox", true, big) == UiTheme.color("glow_new"), "a letter waiting glows blue-white")
	_check(UiTheme.glow("coin", true, big) == UiTheme.color("glow_new"), "news outranks money")
	_check(UiTheme.glow("coin", false, 8.0).a == 0.0, "a coin beside a price is too small to glow")
	_check(UiIcon.glow_texture() == UiIcon.glow_texture(), "every glow draws the one shared image")
	var b := UiKit.tool_button("inbox", "INBOX", 64, 64, 0.0, null, false)
	add_child(b)
	var icon := UiKit.icon_of(b)
	_check(icon != null and icon.kind == "inbox", "a tool button's picture is found")
	HudSide._glow(b, true)
	_check(icon.fresh, "a menu picture glows while something waits")
	HudSide._glow(b, false)
	_check(not icon.fresh, "and stops when nothing does")
	b.queue_free()
