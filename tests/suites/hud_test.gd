extends TestSuite
## Every panel the HUD can open builds without a script error, with a full farm behind it (the panels live in
## scripts/hud/ and are only built when opened, so a broken one would otherwise show only to a player).


func test_145_every_hud_panel_opens_on_the_showcase_farm() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.open_showcase()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	_check(hud != null, "the HUD exists")
	if hud == null:
		main.queue_free()
		await get_tree().process_frame
		return
	var book: BookPanel = hud.get("_book")
	var opened := 0
	for panel in ["_show_market", "_show_collections", "_show_ribbons", "_show_settings"]:
		hud.call(panel)
		opened += 1
		_check(book.visible, "%s opens the book" % panel)
	var seen := {}
	for f in Game.feeds.feed_ids():
		Game.feeds.add(f)   # so the feed cards have buttons to build
	for o in Game.objects.duplicate():
		var key := str(o["id"])
		var opens := Game.kind_of(o) in ["building", "bloom"] or Game.feeds.is_feedable(o)  # (what the farm opens)
		if seen.has(key) or not opens:
			continue
		seen[key] = true
		hud.show_building(int(o["uid"]))
		opened += 1
		_check(book.visible, "tapping %s opens its panel" % key)
	_check(opened > 20, "many different panels were opened (%d)" % opened)
	var box := VBoxContainer.new()
	main.add_child(box)
	hud.barn.build_barn_storage(box)
	_check(box.get_child_count() > 0, "the barn's storage list builds")
	book.close_panel()  # (the book holds the farm's taps while open: leave it as found)
	await get_tree().process_frame
	Game.open_own_farm()
	await get_tree().process_frame
	main.queue_free()
	await get_tree().process_frame


func test_146_the_perf_readout_counts_frames_and_is_kept_switched() -> void:
	var r := PerfReadout.new()
	add_child(r)
	for k in 10:
		r._process(0.02)
	var text := r.text_now()
	_check(text.contains("20.0"), "ten 20 ms frames read as 20.0 ms (%s)" % text.replace("\n", " | "))
	r._process(0.1)
	_check(r.text_now().contains("100.0"), "the worst frame shows")
	r.free()
	var was := PerfReadout.wanted()
	PerfReadout.set_wanted(true)
	_check(PerfReadout.wanted(), "switched on, it stays on (in a debug build)")
	PerfReadout.set_wanted(was)
	_eq(PerfReadout.wanted(), was, "and back")


## The HUD at the shapes phones and tablets come in: every part on screen, none on another, every button big
## enough for a thumb, and the seven tools in FarmVille's order (no Move: hold lifts).
func test_147_the_hud_fits_every_screen_shape_without_overlaps() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var ids: Array[String] = []
	for t: Array in HudTools.TOOLS:
		ids.append(str(t[0]))
	_eq(ids, ["hand", "plow", "plant", "harvest", "fertilize", "store", "sell"], "the seven tools (hold lifts: no Move)")
	var window := get_tree().root
	var was := window.size
	for shape: Vector2i in [Vector2i(1280, 720), Vector2i(2340, 1080), Vector2i(1024, 768), Vector2i(2560, 1600)]:
		window.size = shape
		await get_tree().process_frame
		await get_tree().process_frame
		var view := hud.get_viewport().get_visible_rect()
		var parts: Array[Control] = hud.top.hideable()
		parts.append(hud.tools.panel)
		parts.append_array(hud.side.hideable())
		parts.append(hud.side.toggles)
		for a in parts:
			var ra := a.get_global_rect()
			_check(view.grow(1.0).encloses(ra), "%s: %s is on screen (%s in %s)" % [shape, a.name, ra, view.size])
			for b in parts:
				if a == b or a.is_ancestor_of(b) or b.is_ancestor_of(a):
					continue
				if a.get_global_rect().intersects(b.get_global_rect()):
					_check(false, "%s: %s and %s don't overlap" % [shape, a.name, b.name])
		for b: Button in hud.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and not b.get_parent() is HFlowContainer:
				_check(b.size.x >= 44.0 and b.size.y >= 44.0, "%s: a button is big enough to tap (%s)" % [shape, b.size])
	window.size = was
	main.queue_free()
	await get_tree().process_frame


func test_148_plant_asks_for_a_seed_and_the_eye_hides_the_interface() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var grid: FarmGrid = main.get("grid")
	(hud.tools.buttons["plant"] as Button).pressed.emit()
	var book: BookPanel = hud.get("_book")
	_check(book.visible, "Plant opens the seed list")
	hud.choose_seed("strawberries")
	_check(not book.visible, "picking a seed closes it")
	_eq(grid.tool, "plant", "and the plant tool is in hand")
	_eq(grid.selected_crop, "strawberries", "with that seed")
	_check((hud.tools.buttons["plant"] as Button).button_pressed, "Plant is lit")
	(hud.tools.buttons["harvest"] as Button).pressed.emit()
	_eq(grid.tool, "harvest", "Harvest goes in hand")
	hud.set_interface_hidden(true)
	_check(not hud.tools.panel.visible and not hud.top.xp.visible and not hud.side.menu.visible, "the eye hides it all")
	_check(hud.side.toggles.visible, "but the eye itself")
	hud.set_interface_hidden(false)
	_check(hud.tools.panel.visible, "and brings it back")
	main.queue_free()
	await get_tree().process_frame


## The Market opens on its shelves as tabs; every shelf is a grid with a card for every item of its kind, and
## tapping a card of something affordable puts it in hand to place.
func test_149_the_market_shelves_are_tabs_of_item_cards() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.coins = 1000000
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var book: BookPanel = hud.get("_book")
	hud._show_market()
	var tabs: Array = book.get("_tabs")
	_eq(tabs.size(), HudMarket.SHELVES.size() + 2, "Seeds, a shelf per kind and Specials")
	# Every building for sale is in exactly one section, every other item on its kind's shelf: counted from
	# the catalog's classes, not from the Market's own lists.
	var sections := {}
	for tab: Array in HudMarket.BUILDING_TABS:
		for id in hud.market.building_section(str(tab[0])):
			sections[id] = int(sections.get(id, 0)) + 1
	var want := {}
	var filled := 0
	for tab: Array in HudMarket.BUILDING_TABS:
		filled += 1 if not hud.market.building_section(str(tab[0])).is_empty() else 0
	for id in Game.item_order:
		var it := Game.item_data(id)
		if int(it["unlock_level"]) >= 99:
			continue
		var shelf := "building" if Game.catalog.get_def(id) is BuildingDef else str(it["kind"])
		want[shelf] = int(want.get(shelf, 0)) + 1
		if shelf == "building":
			_eq(int(sections.get(id, 0)), 1, "%s is in exactly one section of the Buildings shelf" % id)
	for k in range(1, HudMarket.SHELVES.size() + 1):
		book.show_tab(k)
		var kind := str(HudMarket.SHELVES[k - 1][0])
		var cards := 0
		var grids := 0
		for grid: GridContainer in book.find_children("*", "GridContainer", true, false):
			if not grid.is_queued_for_deletion():
				cards += grid.get_child_count()
				grids += 1
		_eq(cards, int(want.get(kind, 0)), "the %s shelf has a card for each" % kind)
		if kind == "building":
			_eq(grids, filled, "a grid under a heading for each section that has buildings")
	var placed := []
	hud.place_requested.connect(func(id: String) -> void: placed.append(id))
	book.show_tab(HudMarket.SHELVES.find(["decor", "DECORATIONS"]) + 1)
	var bought := false
	var told := false
	for grid: GridContainer in book.find_children("*", "GridContainer", true, false):
		if grid.is_queued_for_deletion():
			continue
		for card: Button in grid.get_children():
			if not told and not card.get_meta(&"buyable", true):
				card.pressed.emit()
				told = true
	_check(told, "the decorations shelf has a card that can't be bought yet")
	var strips := 0
	for strip: PanelContainer in book.find_children("*", "PanelContainer", true, false):
		if strip.visible and not strip.is_queued_for_deletion() and strip.has_meta(&"about"):
			strips += 1
	_check(strips == 1 and placed.is_empty() and book.visible,
		"tapping it shows all about it at the top of the shelf, and buys nothing")
	for grid: GridContainer in book.find_children("*", "GridContainer", true, false):
		if grid.is_queued_for_deletion():
			continue
		for card: Button in grid.get_children():
			if not bought and card.get_meta(&"buyable", false):
				card.pressed.emit()
				bought = true
	_check(bought and placed.size() == 1, "tapping an open card puts that item in hand")
	_check(not book.visible, "and closes the Market")
	main.queue_free()
	await get_tree().process_frame


## Item pictures are made for the cards on screen first (the ones asked for last), and kept under a key that
## changes with the item's data, so an item that changes gets a new picture.
func test_150_item_pictures_come_on_screen_first_and_are_kept_by_key() -> void:
	var was_waiting := ItemIcons._waiting.duplicate()
	var was_asked := ItemIcons._asked.duplicate()
	ItemIcons._waiting.assign(["a_item", "b_item", "c_item"])
	ItemIcons._asked = {"a_item": 5, "b_item": 9, "c_item": 9}
	_eq(ItemIcons._next(), "b_item", "the first of the cards asked for last comes first")
	ItemIcons._asked["a_item"] = 12
	_eq(ItemIcons._next(), "a_item", "a card asked for again moves ahead")
	ItemIcons._waiting.assign(was_waiting)
	ItemIcons._asked = was_asked
	_check(ItemIcons._file("cow") != ItemIcons._file("chicken"), "each item has its own picture file")
	_check(ItemIcons._file("cow").begins_with(ItemIcons.CACHE + "/cow-"), "kept under the item's name and key")


## Every building's panel opens with its picture, name and state, and Move, Turn and Sell; a refusal is
## explained under the buttons (from Game.buildings), and selling asks twice.
func test_151_a_building_panel_moves_turns_and_sells_or_says_why_not() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.coins = 1000000
	Game.xp = Game.xp_for_level(20)
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var book: BookPanel = hud.get("_book")
	var spot := Vector2i(-1, -1)
	for r in Game.farm_size:
		for c in Game.farm_size:
			if spot.x < 0 and Game.can_place("chicken_coop", r, c):
				spot = Vector2i(r, c)
	_check(Game.buy_and_place("chicken_coop", spot.x, spot.y), "a Coop")
	var coop := Game.object_at(Game.index_of(spot.x, spot.y))
	hud.show_building(int(coop["uid"]))
	var buttons := {}
	for b: Button in book.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion():
			buttons[b.text] = b
	for word: String in [tr("TOOL_MOVE"), tr("TOOL_SELL")]:
		_check(buttons.has(word), "the panel offers %s" % word)
	var turn := Game.buildings.can_rotate(coop)
	_eq(buttons.has(tr("TURN")), turn.ok(),
		"Turn is offered only to what can ever turn")
	if buttons.has(tr("TURN")):
		var was := bool(coop.get("flip", false))
		(buttons[tr("TURN")] as Button).pressed.emit()
		_eq(bool(coop.get("flip", false)) != was, turn.ok(), "Turn turns it exactly when the rules allow")
	# Something that can't be sold (the starter Barn) has Sell greyed, with the reason already showing.
	var barn := Game.storage.barn()
	if not barn.is_empty():
		hud.show_building(int(barn["uid"]))
		var refusal := Game.buildings.can_sell(barn)
		var greyed := false
		var told := false
		for b: Button in book.find_children("*", "Button", true, false):
			greyed = greyed or (not b.is_queued_for_deletion() and b.text == tr("TOOL_SELL") and b.disabled)
		for l: Label in book.find_children("*", "Label", true, false):
			told = told or (not l.is_queued_for_deletion() and l.text.contains(refusal.text))
		_check(not refusal.ok() and greyed and told, "the Barn's Sell is greyed and says why before any tap")
		hud.show_building(int(coop["uid"]))
		buttons.clear()
		for b: Button in book.find_children("*", "Button", true, false):
			if not b.is_queued_for_deletion():
				buttons[b.text] = b
	var sell: Button = buttons[tr("TOOL_SELL")]
	sell.pressed.emit()
	_check(book.visible and not Game.object_by_uid(int(coop["uid"])).is_empty(), "the first tap on Sell only asks")
	_check(sell.text != tr("TOOL_SELL"), "with the price on the button (%s)" % sell.text)
	sell.pressed.emit()
	_check(Game.object_by_uid(int(coop["uid"])).is_empty() and not book.visible, "the second sells it")
	main.queue_free()
	await get_tree().process_frame


## Mastery shows where FarmVille showed it: three stars and the way to the next on every seed, tree and animal
## card; a seed card picks its crop.
func test_328_seed_tree_and_animal_cards_wear_their_mastery_stars() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	var crop: String = Game.crop_order[0]
	var need: Array = Game.mastery.thresholds(crop)
	Game.mastery.points[crop] = int(need[0]) + (int(need[1]) - int(need[0])) / 2
	_eq(Game.mastery.stars(crop), 1, "(one star earned)")
	_check(is_equal_approx(Game.mastery.progress(crop), 0.5), "half way to the second")
	_eq(Game.mastery.next_need(crop), int(need[1]), "the second star's points are next")
	Game.mastery.points[crop] = int(need[2])
	_eq(Game.mastery.progress(crop), 1.0, "a mastered crop's bar is full")
	var stars := MasteryStars.of(crop)
	_eq(stars.earned, 3, "and its card shows three stars")
	stars.free()
	var deco := ""
	for id: String in Game.items:
		if str(Game.items[id].get("kind", "")) == "decor":
			deco = id
			break
	_check(MasteryStars.of(deco) == null, "a decoration has no mastery, so no stars")
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var content := VBoxContainer.new()
	hud.seeds.build_seeds(content)
	var cards := content.find_children("*", "Button", true, false)
	_eq(cards.size(), Game.crop_order.size(), "a card for every crop")
	_eq((cards[0] as Node).find_children("*", "MasteryStars", true, false).size(), 1, "each wearing its stars")
	(cards[0] as Button).pressed.emit()
	_eq(main.get("grid").get("selected_crop"), crop, "tapping a card picks its seed")
	content.free()
	main.free()
	Game.reset_game()


## Every "what's inside" row shows each thing's picture, count and name: animals in a home, bushels (crops) and a
## recipe's inputs, and the building parts; so every crop and part has a picture model and a name.
func test_330_contents_rows_show_a_picture_a_count_and_a_name_for_everything() -> void:
	for id: String in Game.crops.keys() + GameState.part_ids:
		var model := ItemIcons._model(id)
		_check(model != null, "%s has a picture" % id)
		_check(Game.name_of(id) != "", "and a name")
		if model != null:
			model.free()
	var crop: String = Game.crop_order[0]
	var row := UiKit.count_row([[crop, "3/5", true], [GameState.part_ids[0], "×2"]])
	_eq(row.get_child_count(), 2, "one tile each")
	var names := row.find_children("*", "Label", true, false).filter(
		func(l: Label) -> bool: return l.has_meta(&"count_name"))
	_eq((names[0] as Label).text, Game.name_of(crop), "its name under it")
	var counts := (row.get_child(0) as Node).find_children("*", "Label", true, false)
	_check(counts.any(func(l: Label) -> bool: return l.text == "3/5"), "its count on it")
	row.free()


## Every collection item has a picture: a look whose shape ThingIcon draws, and two colours.
func test_331_every_collection_item_has_a_picture() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/collections.json"))
	var n := 0
	for coll: Dictionary in (data as Dictionary)["collections"]:
		for item: Dictionary in coll["items"]:
			var look: Array = item.get("look", [])
			_check(look.size() == 3 and ThingIcon.SHAPES.has(str(look[0])), "%s has a known shape" % item["name"])
			_check(look.size() == 3 and Color.html_is_valid(str(look[1])) and Color.html_is_valid(str(look[2])),
				"%s has its two colours" % item["name"])
			n += 1
	_check(n >= 100, "(every item looked at: %d)" % n)


## Every ribbon tier the data names has its colour in the theme, so a fifth tier can't come out magenta.
func test_332_every_ribbon_tier_has_its_colour() -> void:
	var tiers: Array = Game.ribbons.ribbon_data.get("tiers", [])
	_check(tiers.size() >= 4, "(the four tiers)")
	var colours: Array = UiTheme.colors()
	for k in tiers.size():
		_check(colours.has("ribbon_tier_%d" % k), "tier %d (%s) has a colour" % [k, tiers[k]])


## The interface keeps clear of a phone's notch and gesture bar: a safe area's insets in the view's own units.
func test_334_the_interface_keeps_inside_the_safe_area() -> void:
	var inset := Display.insets_for(Vector2(1080, 2400), Rect2(0, 120, 1080, 2400 - 120 - 60), Vector2(540, 1200))
	_eq(inset, Vector4(0, 60, 0, 30), "a notch at the top and a gesture bar below, at the view's half scale")
	_eq(Display.insets_for(Vector2(1920, 1080), Rect2(0, 0, 1920, 1080), Vector2(1920, 1080)), Vector4.ZERO,
		"no cut-outs: nothing moves")
	_check(ItemIcons.side() >= ItemIcons.SIDE and ItemIcons.side() <= ItemIcons.SIDE_MOST,
		"pictures are made at this screen's density, within bounds")


## The interface takes a set share of the screen, and on a phone never less than a comfortable touch.
func test_337_the_interface_scales_with_the_screen() -> void:
	var rules := {"short_share": 0.075, "touch_mm": 7.0, "least": 0.7, "most": 1.2}
	_check(is_equal_approx(UiTheme.scale_for(720.0, 64.0, 1.0, 96.0, false, rules), 0.075 * 720.0 / 64.0),
		"a computer: its share of the screen")
	var phone := UiTheme.scale_for(720.0, 64.0, 2.0, 440.0, true, rules)
	_check(64.0 * phone * 2.0 / 440.0 * 25.4 >= 6.99, "a dense phone: never under 7 mm to touch")
	_eq(UiTheme.scale_for(4000.0, 64.0, 1.0, 96.0, false, rules), 1.2, "never past the most")
	_eq(UiTheme.size("round_share"), 0.5, "shares aren't scaled")


func test_352_the_release_shows_only_its_items_and_features() -> void:
	Release.whole = false
	var data := JSON.parse_string(FileAccess.get_file_as_string(Release.DATA)) as Dictionary
	for id: String in data["items"]:
		_check(Game.items.has(id) or Game.crops.has(id), "%s in data/v1.json is a catalog item or crop" % id)
	for f: String in data["features"]:
		_eq(Release.on(f), bool(data["features"][f]), "feature %s as the release sets it" % f)
	_check(Release.on("no_such_feature"), "a feature the release doesn't name is on")
	var off := ""
	for id in Game.item_order:
		if not Release.has(id) and int(Game.item_data(id)["unlock_level"]) < 99:
			off = id
			break
	_check(off != "", "some content is left for updates")
	if off != "":
		_check(not HudMarket._for_sale(off), "%s, not in this release, is not for sale" % off)
		var lvl := int(Game.item_data(off)["unlock_level"])
		_check(not Game.unlocks_at(lvl).has(str(Game.item_data(off)["name"])), "and doesn't unlock")
	Release.whole = true
	_check(Release.has(off) and Release.balance("synergy.enabled") == null, "with everything on, all is in")


func test_353_a_tapped_thing_tells_about_itself_in_a_bubble() -> void:
	var hen := {"uid": 7001, "id": "chicken", "row": 0, "col": 0, "t": Game.now()}
	_check(FarmGrid.status_of(hen).begins_with(tr("BUBBLE_READY_IN").split("%")[0]), "a hen not ready says when it will be")
	_eq(FarmGrid.status_of({"uid": 7002, "id": "bench", "row": 0, "col": 0}), "", "a decoration just says its name")
	_check(not HudBubble.has_panel({"uid": 7002, "id": "bench", "row": 0, "col": 0}), "a decoration has no panel")
	_check(HudBubble.has_panel({"uid": 7003, "id": "chicken_coop", "row": 0, "col": 0}), "a home offers its panel")
	var hud := FarmHud.new()
	add_child(hud)
	await get_tree().process_frame
	hud.bubble.to_screen = func(p: Vector2) -> Vector2: return p
	hud.bubble.show_at(Vector2(300, 300), "Chicken", "Ready in 14 h", -1)
	_check(hud.bubble.visible, "the bubble shows")
	_check(hud.bubble.global_position.y < 300.0, "above the thing")
	hud.bubble.close()
	_check(not hud.bubble.visible, "and goes")
	hud.queue_free()
