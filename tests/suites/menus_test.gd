extends TestSuite
## The sweep of every menu: every panel the game opens (each Market tab, Collections and each set, Ribbons,
## Settings, the seed list, the inbox, the fuel panel, every kind of thing on the showcase farm as it opens and
## each building's full panel), on a laptop, a wide phone and a tablet, read for what a player would see broken:
## a word broken inside itself (a wrapping line with no width: letters stacked one a line), a raw id or an
## untranslated key in place of words, a "%s" never filled, and text or a box spilling past its panel's sides.
## And the one look (docs/UI.md): every word standing on the paper reads on it (contrast at least `LEAST_CONTRAST`:
## no cream or yellow left over from the wooden panels), and no wooden box sits inside a panel.
## Every problem is reported once, with where it was, so one run lists them all.

const SHAPES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(2340, 1080), Vector2i(1024, 768)]
const RAW_ID := "\\b[a-z]+_[a-z0-9_]+\\b"        # snake_case: an item or feed id shown as it is stored
const RAW_KEY := "\\b[A-Z]{2,}_[A-Z0-9_]+\\b"    # a strings.csv key never translated

const LEAST_CONTRAST := 3.0   # WCAG's least for large text: words on paper must reach it
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
			var tabs: Array = book.get("_tabs")
			for k in maxi(tabs.size(), 1):
				if tabs.size() > 1:
					book.show_tab(k)
					await _settle()
				var where := "%dx%d %s%s" % [shape.x, shape.y, screen[0],
					"" if tabs.size() < 2 else " / " + str(tabs[k][0])]
				for part: Control in [book, hud.sheet]:
					if part != null and part.is_visible_in_tree():
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


## Every building, tapped, opens as the one sheet (never straight into an old panel): on the screen at the
## bottom, as tall as what it says, with its big button saying what it does, and More (or the big button) opens
## its full panel.
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
		var sheet := hud.sheet
		_check(sheet != null and sheet.visible and not book.visible, "%s opens as the sheet" % id)
		if sheet == null or not sheet.visible:
			continue
		kinds[BuildingSheet.kind_of(o)] = true
		var area := sheet.get_parent_area_size()
		_check(absf(sheet.size.y - sheet.get_combined_minimum_size().y) < 1.0 and sheet.size.y < area.y * 0.8,
			"%s's sheet is as tall as what it says (%d of %d)" % [id, sheet.size.y, area.y])
		# Something to do on it, each saying what: the big button (Collect, Make, Open...), Add N, or More (a
		# store that never pays, the Garage or the Shed, has no Collect: what is inside, Add N and More).
		var doing := 0
		for b: Button in [sheet.get("_collect"), sheet.get("_fill"), sheet.get("_more")]:
			if b.visible:
				doing += 1
				_check(b.text.strip_edges() != "", "%s's sheet: a button with no words" % id)
		_check(doing > 0, "%s's sheet has something to do" % id)
		if BuildingSheet.kind_of(o) != BuildingSheet.Kind.HOME:
			_check((sheet.get("_collect") as Button).visible, "%s's sheet has its big button" % id)
		hud.open_full_panel(int(o["uid"]))
		_check(book.visible and not sheet.visible, "%s's More opens its full panel" % id)
		book.close_panel()
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
		_check(hud.sheet.visible and BuildingSheet.kind_of(site) == BuildingSheet.Kind.BUILD, "a site opens as the sheet")
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
		["Inbox", hud.show_inbox],
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
