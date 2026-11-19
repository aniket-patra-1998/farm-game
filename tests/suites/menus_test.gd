extends TestSuite
## The sweep of every menu: every panel the game opens (each Market tab, Collections and each set, Ribbons,
## Settings, the seed list, the inbox, the fuel panel, every kind of thing on the showcase farm as it opens and
## each building's full panel), on a laptop, a wide phone and a tablet, read for what a player would see broken:
## a word broken inside itself (a wrapping line with no width: letters stacked one a line), a raw id or an
## untranslated key in place of words, a "%s" never filled, text or a box spilling past its panel's sides, a panel
## running off the screen (a sheet where it rests, not on its way up), and a button too small for a finger (under
## panel_button_height either way, less `TAP_SLACK`).
## And the one look (docs/UI.md): every word standing on the paper reads on it (contrast at least `LEAST_CONTRAST`:
## no cream or yellow left over from the wooden panels), and no wooden box sits inside a panel.
## Every problem is reported once, with where it was, so one run lists them all.

const SHAPES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(2340, 1080), Vector2i(1024, 768)]
const RAW_ID := "\\b[a-z]+_[a-z0-9_]+\\b"        # snake_case: an item or feed id shown as it is stored
const RAW_KEY := "\\b[A-Z]{2,}_[A-Z0-9_]+\\b"    # a strings.csv key never translated

const TAP_SLACK := 2.0   # (units: the round close button is 38 across)
const LEAST_CONTRAST := 3.0   # WCAG's least for large text: words on paper must reach it
const POP_SETTLES := 1.1   # seconds the level-up's pop-in and its number's pulses take
const BUSIEST_UP_TO := 70   # levels searched for the level-up with the most unlocks
const WOOD_KEYS: Array[String] = ["wood", "wood_dark", "wood_light", "plaque"]   # the old frame's colours

var _raw_id := RegEx.create_from_string(RAW_ID)
var _raw_key := RegEx.create_from_string(RAW_KEY)


func test_380_every_menu_reads_whole_on_every_screen() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.open_showcase()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var book: BookPanel = hud.get("book")
	for f in Game.feeds.feed_ids():
		Game.feeds.add(f)   # (so feed cards have their buttons)
	var window := get_tree().root
	var was := window.size
	var bad := {}
	var seen := 0
	for shape: Vector2i in SHAPES:
		window.size = shape
		await get_tree().process_frame
		for screen: Array in _screens(hud):
			(screen[1] as Callable).call()
			await _settle()
			if book.is_open() or (hud.sheet != null and hud.sheet.is_open()):   # (swept where it rests, not on its way up)
				await _motion_ends(book)
				await _motion_ends(hud.sheet)
				await _settle()
			var tabs: Array = book.get("_tabs")
			for k in maxi(tabs.size(), 1):
				if tabs.size() > 1:
					book.show_tab(k)
					await _settle()
				var where := "%dx%d %s%s" % [shape.x, shape.y, screen[0],
					"" if tabs.size() < 2 else " / " + str(tabs[k][0])]
				for part: Control in [book, hud.sheet]:   # (one on its way out is not swept)
					if part != null and part.is_visible_in_tree() and part.call("is_open"):
						_sweep(part, where, bad)
						seen += 1
			book.close_panel()
			if hud.sheet != null:
				hud.sheet.close()
			Game.modal_open = false
	window.size = was
	_check(seen > 60, "many screens swept (%d)" % seen)
	for problem: String in bad:
		_check(false, problem)
	Game.open_own_farm()
	main.queue_free()
	await get_tree().process_frame


## Every building, tapped, opens as the one sheet (never an old panel): on the screen at the bottom, as tall as
## what it says, with something to do in it, and everything it does there: no other window.
func test_369_every_building_opens_as_the_sheet() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.open_showcase()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var book: BookPanel = hud.get("book")
	var kinds := {}
	var seen := {}
	for o in Game.objects.duplicate():
		var id := str(o["id"])
		if seen.has(id) or not Game.is_building_item(id):
			continue
		seen[id] = true
		hud.show_building(int(o["uid"]))
		await _settle()
		var sheet: BuildingSheet = hud.sheet
		_check(sheet != null and sheet.is_open() and not book.is_open(), "%s opens as the sheet" % id)
		if sheet == null or not sheet.is_open():
			continue
		kinds[BuildingSheet.kind_of(o)] = true
		var area := sheet.get_parent_area_size()
		_check(absf(sheet.size.y - sheet.get_combined_minimum_size().y) < 1.0 and sheet.size.y < area.y * 0.8,
			"%s's sheet is as tall as what it says (%d of %d)" % [id, sheet.size.y, area.y])
		# Something to do on it, each saying what: the big button (Collect, Make, Open...), Add N, or More (a
		# store that never pays, the Garage or the Shed, has no Collect: what is inside, Add N and More).
		var doing := 0
		for b: Button in [sheet.get("_collect"), sheet.get("_fill")]:
			if b.visible:
				doing += 1
				_check(b.text.strip_edges() != "", "%s's sheet: a button with no words" % id)
		for part: String in ["_tabs", "_extras", "_page_scroll"]:   # (its pages, its own extras)
			doing += 1 if (sheet.get(part) as Control).visible else 0
		_check(doing > 0, "%s's sheet has something to do" % id)
		if BuildingSheet.kind_of(o) == BuildingSheet.Kind.BUILD:
			_check((sheet.get("_collect") as Button).visible, "%s's sheet has its big button" % id)
		hud.open_full_panel(int(o["uid"]))
		await _settle()
		_check(sheet.is_open() and not book.is_open(), "%s: everything is in its sheet, no other window" % id)
		sheet.close()
		Game.modal_open = false
	_check(seen.size() >= 6, "many buildings tapped (%d)" % seen.size())
	for k: BuildingSheet.Kind in [BuildingSheet.Kind.HOME, BuildingSheet.Kind.CRAFT, BuildingSheet.Kind.BARN]:
		_check(kinds.has(k), "a %s among them" % BuildingSheet.Kind.keys()[k])
	# A building site gets the sheet too: its materials, and Add my materials.
	Game.coins = 10000000
	Game.xp = Game.xp_for_level(40)
	var site := {}
	for id: String in Game.items:
		if site.is_empty() and Game.is_building_item(id) \
				and not (Game.item_data(id).get("build_materials", {}) as Dictionary).is_empty():
			for r in Game.farm_size:
				for c in Game.farm_size:
					if site.is_empty() and Game.can_place(id, r, c) and Game.buy_and_place(id, r, c):
						site = Game.object_at(Game.index_of(r, c))
	_check(not site.is_empty() and Game.under_construction(site), "a building site")
	if not site.is_empty():
		hud.show_building(int(site["uid"]))
		await _settle()
		_check(hud.sheet.is_open() and BuildingSheet.kind_of(site) == BuildingSheet.Kind.BUILD, "a site opens as the sheet")
		_eq((hud.sheet.get("_collect") as Button).text, tr("ADD_MY_MATERIALS"), "its big button adds materials")
		_check((hud.sheet.get("_detail") as Label).visible, "and it lists the materials")
		hud.sheet.close()
	Game.open_own_farm()
	main.queue_free()
	await get_tree().process_frame


## A crafting recipe that makes Animal Feed says so by name (not "Rich animal_feed"), and finishing it says it
## went to the young ones' supplies, not the Barn.
func test_370_feed_recipes_name_what_they_make() -> void:
	var g := _farm()
	var feeds := 0
	var supplies := 0
	for id: String in g.items:
		if str(g.item_data(id).get("kind", "")) != "crafting":
			continue
		for r: RecipeDef in g.crafting.recipes_of(id):
			if not r.makes_feed():
				continue
			feeds += 1
			var words := g.crafting.feed_product_name(r)
			_check(_raw_id.search(words) == null, "%s makes \"%s\", in words" % [r.id, words])
			if CraftingSystem.makes_supply(r):
				supplies += 1
				_eq(words, g.nurture.supply_name(str(r.feed()["type"])), "%s makes the supply by its name" % r.id)
	_check(feeds > 1 and supplies >= 1, "feed recipes checked (%d, %d of them supplies)" % [feeds, supplies])
	_done(g)


func _settle() -> void:
	for f in 3:
		await get_tree().process_frame


## Every screen to sweep: [name, how to open it].
func _screens(hud: FarmHud) -> Array:
	var out: Array = [["Market", hud.show_market], ["Collections", hud.show_collections],
		["Ribbons", hud.show_ribbons], ["Settings", hud.show_settings], ["Seeds", hud.show_seeds],
		["Inbox", hud.show_inbox], ["Goals", hud.show_goals],
		["Fuel", func() -> void: hud.book.open_panel(tr("FUEL"), hud.buildings.build_fuel)]]
	for coll: Dictionary in Game.collectibles.collections:
		var cid := str(coll["id"])
		out.append(["Collection " + cid, func() -> void:
			hud.book.open_panel(str(coll["name"]), func(c: VBoxContainer) -> void: hud.books.build_collection(c, cid))])
	var seen := {}
	for o in Game.objects:
		var id := str(o["id"])
		if seen.has(id) or not HudBubble.has_panel(o):
			continue
		seen[id] = true
		var uid := int(o["uid"])
		out.append(["tap " + id, func() -> void: hud.show_building(uid)])
		if Game.is_building_item(id):
			out.append(["full panel " + id, func() -> void: hud.open_full_panel(uid)])
	return out


## Reads every visible thing under `root` for what a player would see broken; each problem once, in `bad`.
func _sweep(root: Control, where: String, bad: Dictionary) -> void:
	if root is BookPanel:
		root = root.get("_panel") as Control   # (what it shows: not the full-screen frame that centres it)
	var page := root.get_global_rect()
	var screen := root.get_viewport_rect().grow(1.0)
	if not screen.encloses(page):
		bad["%s: the panel runs off the screen (%s on %s)" % [where, page, screen.size]] = true
	for c: Control in root.find_children("*", "Control", true, false):
		if c.is_queued_for_deletion() or not c.is_visible_in_tree():
			continue
		var text := ""
		if c is Label:
			text = (c as Label).text
		elif c is Button:
			text = (c as Button).text
		if text.strip_edges() != "":
			var short := text.replace("\n", " ").left(60)
			if _raw_id.search(text) != null:
				bad["%s: a raw id in \"%s\"" % [where, short]] = true
			if _raw_key.search(text) != null:
				bad["%s: an untranslated key in \"%s\"" % [where, short]] = true
			if UiTheme.tidy(text) != text:
				bad["%s: a number written long in \"%s\" (UiTheme.number: 4.8k)" % [where, short]] = true
			var size_px := c.get_theme_font_size("font_size")
			if size_px > UiTheme.font(UiTheme.HEADING) and not c.has_meta(&"title"):
				bad["%s: %s \"%s\" is larger than a heading (%d px; only titles are)" % [where, c.get_class(), short,
					size_px]] = true
			if text.contains("%s") or text.contains("%d"):
				bad["%s: an unfilled \"%%s\" in \"%s\"" % [where, short]] = true
			if c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
				var l := c as Label
				var font := l.get_theme_font("font")
				var px := l.get_theme_font_size("font_size")
				for word in text.replace("\n", " ").split(" ", false):
					if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > l.size.x + 1.0:
						bad["%s: \"%s\" breaks inside a word (%d px wide)" % [where, short, l.size.x]] = true
						break
		if c is Label and text.strip_edges() != "" and _on_paper(c, root):
			var ratio := contrast(c.get_theme_color("font_color"), UiTheme.color("paper"))
			if ratio < LEAST_CONTRAST:
				bad["%s: \"%s\" is too faint on the paper (%.1f:1)" % [where, text.left(40), ratio]] = true
		if c is PanelContainer and c.has_theme_stylebox("panel") and c.get_theme_stylebox("panel") is StyleBoxFlat:
			var face := (c.get_theme_stylebox("panel") as StyleBoxFlat).bg_color
			for key in WOOD_KEYS:
				if face.a > 0.5 and face.is_equal_approx(UiTheme.color(key)):
					bad["%s: a %s box inside the paper" % [where, key]] = true
		if c is BaseButton and minf(c.size.x, c.size.y) < UiTheme.size("panel_button_height") - TAP_SLACK:
			bad["%s: %s \"%s\" is too small to tap (%dx%d)" % [where, c.get_class(), text.left(40), c.size.x,
				c.size.y]] = true
		if (c is Label or c is Container) and c.size.x > 0.0:
			var r := c.get_global_rect()
			if r.position.x < page.position.x - 1.0 or r.end.x > page.end.x + 1.0:
				bad["%s: %s \"%s\" spills past the panel's side" % [where, c.get_class(), text.left(40)]] = true


## Whether label `l` stands on the paper itself: not on a button, nor on a tile, badge or box of its own.
func _on_paper(l: Control, root: Control) -> bool:
	var n := l.get_parent()
	while n != null and n != root:
		if n is BaseButton:
			return false
		if n is PanelContainer and (n as Control).has_theme_stylebox("panel"):
			var box := (n as Control).get_theme_stylebox("panel")
			if box is StyleBoxFlat and (box as StyleBoxFlat).bg_color.a > 0.5:
				return false
		n = n.get_parent()
	return true


## How far apart two colours read (WCAG): 1 is the same, 21 black on white.
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * float(lin.call(c.r)) + 0.7152 * float(lin.call(c.g)) + 0.0722 * float(lin.call(c.b))


## A crafting building does everything in its sheet, never another window: its menu's tabs (Make, Goods,
## Pantry) are the sheet's pages, and a done craft is collected from the sheet's big button.
func test_382_crafting_happens_in_the_sheet() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.open_showcase()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var book: BookPanel = hud.book
	var o := {}
	for x: Dictionary in Game.objects:
		if o.is_empty() and Game.crafting.is_crafting(x) and not Game.under_construction(x) \
				and HudCrafting.makes_goods(x):
			o = x
	_check(not o.is_empty(), "a crafting building")
	if o.is_empty():
		main.queue_free()
		return
	var uid := int(o["uid"])
	o["slots"] = []
	hud.show_building(uid)
	await _settle()
	var tabs: SheetTabs = hud.sheet.get("_tabs")
	_check(hud.sheet.is_open() and tabs.visible and not book.is_open(), "its menu's tabs in the sheet, no other window")
	_eq(tabs.get_child_count(), hud.crafting.tabs(o).size(), "Make, Goods and Pantry")
	_check((hud.sheet.get("_page") as Control).get_child_count() > 0, "its Make page is filled")
	var r: RecipeDef = Game.crafting.recipes_of(str(o["id"]))[0]
	for crop: String in r.inputs():
		Game.crafting.bushels[crop] = int(r.inputs()[crop])
	_check(Game.crafting.start_craft(uid, r.id), "a craft started")
	for slot: Dictionary in Game.object_by_uid(uid)["slots"]:
		slot["done"] = 0
	hud.sheet.call("_refill")
	var collect: Button = hud.sheet.get("_collect")
	_check(collect.visible, "something done: Collect")
	collect.pressed.emit()
	await _settle()
	_eq((Game.object_by_uid(uid)["slots"] as Array).size(), 0, "collected from the sheet")
	_check(not book.is_open(), "and still no other window")
	hud.sheet.close()
	main.queue_free()
	await get_tree().process_frame


## The sheet drags: a crafting building's goes up to tall (its page filling it), down to compact, down again to
## close; a home with pages (Feed, Grow) goes tall too; one with nothing more to show only closes.
func test_383_the_sheet_drags_tall_and_closed() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.open_showcase()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var craft_uid := -1
	var home_uid := -1
	for x: Dictionary in Game.objects:
		match BuildingSheet.kind_of(x):
			BuildingSheet.Kind.CRAFT:
				craft_uid = int(x["uid"]) if craft_uid < 0 else craft_uid
			BuildingSheet.Kind.HOME:
				home_uid = int(x["uid"]) if home_uid < 0 else home_uid
	hud.show_building(craft_uid)
	await _motion_ends(hud.sheet)
	var sheet: BuildingSheet = hud.sheet
	var compact := sheet.size.y
	await _pull(sheet, -200.0)
	_check(sheet.tall, "pulled up: tall")
	_check(sheet.size.y > compact * 1.3, "and taller (%d > %d)" % [sheet.size.y, compact])
	_check((sheet.get("_page_scroll") as Control).visible, "its page fills the tall sheet")
	await _pull(sheet, 200.0)
	_check(not sheet.tall and sheet.is_open(), "pulled down: compact")
	await _pull(sheet, 200.0)
	_check(not sheet.is_open(), "pulled down again: closed")
	hud.show_building(home_uid)
	await _motion_ends(hud.sheet)
	var pages := (sheet.get("_tabs") as Control).visible
	await _pull(sheet, -200.0)
	_check(sheet.tall == pages and sheet.is_open(), "a home goes tall only with pages to show (pages: %s)" % pages)
	sheet.close()
	main.queue_free()
	await get_tree().process_frame


## A drag of `dy` px on the sheet (from its middle), then time to settle.
func _pull(sheet: BuildingSheet, dy: float) -> void:
	var at := sheet.size / 2.0
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = sheet.global_position + at
	sheet._gui_input(down)
	for k in 5:
		var move := InputEventMouseMotion.new()
		move.global_position = down.global_position + Vector2(0, dy * (k + 1) / 5.0)
		sheet._gui_input(move)
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.global_position = down.global_position + Vector2(0, dy)
	sheet._gui_input(up)
	await get_tree().create_timer(BuildingSheet.SETTLE + 0.15).timeout


## The cards that come over the farm (While you were away with every kind of row and its notes, the level-up
## with the most unlocks) read whole on every screen, as the menus do, and the away card keeps
## clear of the tool bar and the side buttons, whose taps it would otherwise cover.
func test_449_the_cards_over_the_farm_read_whole_on_every_screen() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.tutorial_step = GameState.Tutorial.DONE
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var rows: Array = []
	for kind: String in AwayCard.ICONS:
		rows.append({"kind": kind, "count": 12})
	var notes: Array = ["The bees left the hive while you were away", "Some buildings changed shape and moved"]   # not-ui
	var busiest := 2
	for lvl in range(2, BUSIEST_UP_TO + 1):
		if Game.unlock_ids_at(lvl).size() > Game.unlock_ids_at(busiest).size():
			busiest = lvl
	var window := get_tree().root
	var was := window.size
	var bad := {}
	for shape: Vector2i in SHAPES:
		window.size = shape
		await _settle()
		var where := "%dx%d" % [shape.x, shape.y]
		hud.call("_show_away", rows, notes)
		await _settle()
		var card: AwayCard = hud.get("_away")
		_sweep(card, where + " away card", bad)
		var others: Array[Control] = [hud.tools.panel]
		others.append_array(hud.side.hideable())
		for other in others:
			if other.is_visible_in_tree() and card.get_global_rect().intersects(other.get_global_rect()):
				bad["%s away card covers %s" % [where, other.name]] = true
		card.close()
		var popup: LevelUpPopup = hud.call("level_popup")
		popup.call("_show", busiest)
		await get_tree().create_timer(POP_SETTLES).timeout   # (read where it rests, not mid-pop or mid-pulse)
		var party := {}   # (a celebration on its own dark card: its big words and light colours are its look)
		_sweep(popup.get("_card") as Control, "%s level-up %d" % [where, busiest], party)
		for problem: String in party:
			if not ("larger than a heading" in problem or "too faint" in problem):
				bad[problem] = true
		popup.visible = false
		Game.modal_open = false
	window.size = was
	_check(Game.unlock_ids_at(busiest).size() > 1, "the busiest level-up shows several unlocks (level %d)" % busiest)
	for problem: String in bad:
		_check(false, problem)
	main.queue_free()
	await get_tree().process_frame
