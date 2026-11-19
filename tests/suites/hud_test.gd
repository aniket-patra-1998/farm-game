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
	var book: BookPanel = hud.get("book")
	var opened := 0
	for panel in ["show_market", "show_collections", "show_ribbons", "show_settings"]:
		hud.call(panel)
		opened += 1
		_check(book.is_open(), "%s opens the book" % panel)
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
		var sheet_up: bool = hud.sheet != null and hud.sheet.is_open()   # (a finished building opens as its sheet)
		_check(book.is_open() or sheet_up, "tapping %s opens its panel" % key)
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
	var book: BookPanel = hud.get("book")
	_check(book.is_open(), "Plant opens the seed list")
	hud.choose_seed("strawberries")
	_check(not book.is_open(), "picking a seed closes it")
	_eq(grid.tool, "plant", "and the plant tool is in hand")
	_eq(grid.selected_crop, "strawberries", "with that seed")
	_check((hud.tools.buttons["plant"] as Button).button_pressed, "Plant is lit")
	(hud.tools.buttons["harvest"] as Button).pressed.emit()
	_eq(grid.tool, "harvest", "Harvest goes in hand")
	hud.set_interface_hidden(true)
	_check(not hud.tools.panel.visible and not hud.top.xp.visible and not hud.side.menu.visible,
		"hiding the interface hides it all")
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
	var book: BookPanel = hud.get("book")
	hud.show_market()
	var tabs: Array = book.get("_tabs")
	# (The Mystery Box opens Decorations and land closes Buildings: no Specials tab.)
	_eq(tabs.size(), HudMarket.SHELVES.size() + 1, "Seeds and a shelf per kind")
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
		var lists := book.page().find_children("*", "CardList", true, false)
		for list: CardList in lists:
			cards += list.ids.size()
		_eq(cards, int(want.get(kind, 0)), "the %s shelf has a card for each" % kind)
		if kind == "building":
			_eq(lists.size(), filled, "a grid under a heading for each section that has buildings")
	var placed := []
	hud.place_requested.connect(func(id: String) -> void: placed.append(id))
	book.show_tab(HudMarket.SHELVES.find(["decor", "DECORATIONS"]) + 1)
	await get_tree().process_frame
	var shelf: CardList = book.page().find_children("*", "CardList", true, false)[0]
	_check(not shelf.shown().is_empty() and shelf.shown().size() <= shelf.ids.size(),
		"the shelf shows cards for the items in view")
	var told := false
	for id in shelf.ids:
		if not told and not hud.market.card_face(id)["buyable"]:
			shelf.press(id)
			told = true
	_check(told, "the decorations shelf has a card that can't be bought yet")
	var strips := 0
	for strip: PanelContainer in book.page().find_children("*", "PanelContainer", true, false):
		if strip.visible and not strip.is_queued_for_deletion() and strip.has_meta(&"about"):
			strips += 1
	_check(strips == 1 and placed.is_empty() and book.is_open(),
		"tapping it shows all about it at the top of the shelf, and buys nothing")
	var bought := false
	for card in shelf.shown():
		if not bought and card.get_meta(&"buyable", false):
			card.pressed.emit()
			bought = true
	_check(bought and placed.size() == 1, "tapping an open card puts that item in hand")
	_check(not book.is_open(), "and closes the Market")
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
	var book: BookPanel = hud.get("book")
	var spot := Vector2i(-1, -1)
	for r in Game.farm_size:
		for c in Game.farm_size:
			if spot.x < 0 and Game.can_place("chicken_coop", r, c):
				spot = Vector2i(r, c)
	_check(Game.buy_and_place("chicken_coop", spot.x, spot.y), "a Coop")
	var coop := Game.object_at(Game.index_of(spot.x, spot.y))
	hud.show_building(int(coop["uid"]))
	var buttons := {}
	for b: Button in hud.sheet.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.is_visible_in_tree():
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
		# What is never sold (the Barn) has no Sell and no word about it, as what never turns has no Turn.
		var refusal := Game.buildings.can_sell(barn)
		var shown := false
		var told := false
		for b: Button in book.find_children("*", "Button", true, false):
			shown = shown or (not b.is_queued_for_deletion() and b.text == tr("TOOL_SELL") and b.is_visible_in_tree())
		for l: Label in book.find_children("*", "Label", true, false):
			told = told or (not l.is_queued_for_deletion() and l.is_visible_in_tree() and l.text.contains(refusal.text))
		_check(not refusal.ok() and not shown and not told, "the Barn, never sold, has no Sell and no refusal under it")
		hud.show_building(int(coop["uid"]))
		buttons.clear()
		for b: Button in hud.sheet.find_children("*", "Button", true, false):
			if not b.is_queued_for_deletion():
				buttons[b.text] = b
	var sell: Button = buttons[tr("TOOL_SELL")]
	sell.pressed.emit()
	_check(hud.sheet.is_open() and not Game.object_by_uid(int(coop["uid"])).is_empty(), "the first tap on Sell only asks")
	_check(sell.text != tr("TOOL_SELL"), "with the price on the button (%s)" % sell.text)
	sell.pressed.emit()
	_check(Game.object_by_uid(int(coop["uid"])).is_empty() and not hud.sheet.is_open(), "the second sells it")
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
	var list: CardList = content.find_children("*", "CardList", true, false)[0]
	var sold := Game.crop_order.filter(func(id: String) -> bool: return not Game.crops[id].get("starter", false))
	_eq(list.ids.size(), sold.size(), "a card for every crop (Starter Seeds only while given)")
	_eq(hud.seeds.seed_face(crop)["stars"], [3, 1.0], "each wearing its stars")
	# The card's price is what a harvest pays now: three stars raise it (it showed the bare price before).
	var price := int(Game.crops[crop]["sell_price"])
	var pays := Game.field.sells_for(crop, Game.off_season(crop))
	var raised := roundi(price * (1.0 + 3 * Balance.f("economy.mastery_price_bonus"))
		* (Balance.f("seasons.off_price_mult") if Game.off_season(crop) else 1.0))
	_eq(pays, raised, "a mastered crop sells for its price raised by its stars")
	_check(str(hud.seeds.seed_face(crop)["line"]).contains("%d coins" % pays), "and its seed card says so")
	list.press(crop)
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
	_check(FarmGrid.status_of(hen).begins_with(tr("BUBBLE_READY_IN").split("%")[0]),
		"a hen not ready says when it will be")
	_eq(FarmGrid.status_of({"uid": 7002, "id": "bench", "row": 0, "col": 0}), "", "a decoration just says its name")
	_check(not HudBubble.has_panel({"uid": 7002, "id": "bench", "row": 0, "col": 0}), "a decoration has no panel")
	_check(HudBubble.has_panel({"uid": 7003, "id": "chicken_coop", "row": 0, "col": 0}), "a home offers its panel")
	_check(not HudBubble.has_panel(hen), "an animal has no panel: its bubble says it all")
	_check(HudBubble.action_of({"uid": 7002, "id": "bench", "row": 0, "col": 0}).is_empty(), "a bench has nothing to do")
	var hud := FarmHud.new()
	add_child(hud)
	await get_tree().process_frame
	hud.bubble.to_screen = func(p: Vector2) -> Vector2: return p
	hud.bubble.show_at(Vector2(300, 300), "Chicken", "Ready in 14 h", -1)
	_check(UiFx.is_open(hud.bubble), "the bubble shows")
	_check(hud.bubble.global_position.y < 300.0, "above the thing")
	hud.bubble.close()
	var view := hud.get_viewport().get_visible_rect()
	for at: Vector2 in [Vector2(2, 2), Vector2(view.end.x - 2, 10), Vector2(3, view.end.y - 3), view.end - Vector2(1, 1)]:
		hud.bubble.show_at(at, "Chicken", "Ready in 14 h", -1)
		await get_tree().process_frame
		hud.bubble.call("_follow")
		_check(view.encloses(hud.bubble.get_global_rect()), "a bubble for a thing at the edge (%s) stays on the screen" % at)
		hud.bubble.close()
	_check(not UiFx.is_open(hud.bubble), "and goes")
	hud.queue_free()


func test_354_a_home_opens_as_a_sheet_that_is_kept_and_only_refilled() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.coins = 1000000
	Game.xp = Game.xp_for_level(20)
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var spot := Vector2i(-1, -1)
	for r in Game.farm_size:
		for c in Game.farm_size:
			if spot.x < 0 and Game.can_place("chicken_coop", r, c):
				spot = Vector2i(r, c)
	_check(Game.buy_and_place("chicken_coop", spot.x, spot.y), "a Coop")
	var coop := Game.object_at(Game.index_of(spot.x, spot.y))
	hud.show_building(int(coop["uid"]))
	_check(hud.sheet != null and hud.sheet.is_open(), "a finished home opens as its sheet")
	_check(not (hud.get("book") as BookPanel).visible, "not as the full panel")
	var before: Array[Node] = hud.sheet.find_children("*", "Control", true, false)
	var words := ""
	for l: Label in hud.sheet.find_children("*", "Label", true, false):
		words += l.text + "|"
	_check(words.contains(tr("ADDS_FLOOR")), "it says what the next size adds (%s)" % words)
	# A change on the farm, and tapping the same home again, refill it: nothing is built again.
	Game.objects_changed.emit()
	hud.show_building(int(coop["uid"]))
	var after: Array[Node] = hud.sheet.find_children("*", "Control", true, false)
	_eq(after.size(), before.size(), "refilled with the same parts")
	_check(after.size() > 0 and after[0] == before[0] and after[-1] == before[-1], "the very same ones")
	# One window at a time: a panel opened from the HUD puts the sheet away (it was drawn over the panel).
	hud.show_seeds()
	_check((hud.get("book") as BookPanel).visible, "Seeds opens over a home's sheet")
	_check(not hud.sheet.is_open(), "and the sheet goes")
	(hud.get("book") as BookPanel).close_panel()   # (Game.modal_open is shared with the next test)
	# A card's line too wide for it leaves off its last parts whole, never cut mid-word ("4h · 53 coins ·").
	var f := ThemeDB.fallback_font
	var short := "4h · 53 coins"   # not-ui
	_eq(CardFace.fitted_line(f, short, 1000.0, 12), short, "a line that fits is whole")
	var room := f.get_string_size(short, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 1.0
	_eq(CardFace.fitted_line(f, short + " · off-season", room, 12), short, "a wide one loses its last part")   # not-ui
	# Cards in a row keep their pictures level whether a name takes one line or two (the album's rings stood lower
	# under a one-line name).
	var tops: Array[float] = []
	# A card with a bar (a ribbon on its way) stands level too: it was centred taller, so its picture stood higher.
	var faces: Array[Dictionary] = [{"name": "Pea Pod"}, {"name": "Wildflower Meadow Overflowing"},   # not-ui
		{"name": "Regular", "bar": [0.2, "1 / 5"]}]   # not-ui
	for face: Dictionary in faces:
		var card := CardFace.new()
		card.size = Vector2(UiTheme.size("card_width"), UiTheme.size("card_icon") + UiTheme.size("card_words"))
		add_child(card)
		face["ring"] = [0.0, "0/5"]   # not-ui
		card.show_face("pea", face, null)
		await get_tree().process_frame
		await get_tree().process_frame
		tops.append(card.picture_top)
		card.queue_free()
	_check(tops[0] > 0.0, "a card's picture was drawn")
	_eq(tops[0], tops[1], "a one-line and a two-line name leave the picture at one height")
	_eq(tops[0], tops[2], "a card with a bar leaves its picture at the same height")
	# A shelf where some cards have mastery stars and some none (the Market's trees): pictures stand level too.
	var starred := {"name": "Apple Tree", "stars": [1, 0.5], "badge": ["coin", "150"]}   # not-ui
	var plain := {"name": "Lemon Tree", "badge": ["coin", "250"]}   # not-ui
	var shelf_tops: Array[float] = []
	var high := 0.0
	for face: Dictionary in [starred, plain]:
		var card := CardFace.new()
		add_child(card)
		card.show_face("tree", face, null)
		high = maxf(high, card.needed_height())
		card.queue_free()
	for face: Dictionary in [starred, plain]:
		var card := CardFace.new()
		card.size = Vector2(UiTheme.size("card_width"), high)
		add_child(card)
		card.show_face("tree", face, null)
		await get_tree().process_frame
		await get_tree().process_frame
		shelf_tops.append(card.picture_top)
		card.queue_free()
	_eq(shelf_tops[0], shelf_tops[1], "a card with no stars leaves its picture where a starred card's is")
	main.queue_free()
	await get_tree().process_frame


## A run of the same work climbs a scale and counts: a swipe's plots as they are given to the farmer, and the
## farmer's jobs of one kind done one after another (feel only: it pays nothing).
func test_358_a_swipe_and_a_streak_climb_a_scale_and_count() -> void:
	_eq(Feedback.pitch_of(0), 1.0, "the first of a run plays as written")
	_check(Feedback.pitch_of(3) > Feedback.pitch_of(2) and Feedback.pitch_of(2) > 1.0, "each step is a note higher")
	_eq(Feedback.pitch_of(500), Feedback.pitch_of(Balance.a("feel.run_scale").size() - 1), "and the top note holds")
	Game.saving_enabled = false
	Game.reset_game()
	Game.coins = 100000
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: FarmGrid = main.get("grid")
	_eq(int(grid.call("_run", "harvest", 0)), 0, "a first harvest starts a streak")
	_eq(int(grid.call("_run", "harvest", 1)), 1, "the next one soon after is a step on")
	_eq(int(grid.call("_run", "plow", 1)), 0, "another kind of work starts again")
	grid.set("_streak_msec", Time.get_ticks_msec() - 60000)
	_eq(int(grid.call("_run", "plow", 2)), 0, "and so does the same work after a pause")
	grid.tool = "plow"
	var given := 0
	for i in Game.plots.size():
		if given < 3 and not Game.is_occupied(i) and Game.field.phase(i) == GameState.Phase.GRASS:
			grid.call("_queue", grid.job_for(i), false)
			given += 1
	_eq(int(grid.get("_swipe_count")), 3, "a swipe counts the plots it gives the farmer")
	var combo: Label = grid.get("_combo")
	_check(combo != null and combo.text == FarmGrid.COUNT_TAG % 3, "and says the count over the last one")
	if combo != null:
		_check(combo.get_theme_font("font") == FloatText.bold()
				and combo.get_theme_color("font_outline_color") == UiTheme.color("float_outline")
				and combo.get_theme_constant("shadow_offset_y") == FloatText.SHADOW_DROP,
				"in the floating words' look (bold, their outline, their shadow), as every word over the farm")
	var words_before := grid.get_child_count()
	grid.float_words(Vector2.ZERO, "+1500", "coins")
	var words: Label = grid.get_child(words_before)
	_check(words.get_theme_font("font") == FloatText.bold()
			and words.get_theme_color("font_outline_color") == UiTheme.color("float_outline"),
			"coins and XP over a plot float in the same look")
	_eq(words.text, UiTheme.tidy("+1500"), "with their numbers tidied as every shown number")
	main.queue_free()
	await get_tree().process_frame
	Game.reset_game()


## Harvest juice (wow build): the crop's picture flies from the plot in a small reused pool, never more at once
## than the pool holds; a sweep ends on its count once, only when the farmer has no more of that work queued and
## the run was long enough; the trail is off on the low graphics level.
func test_560_harvest_produce_flies_pooled_and_a_sweep_ends_on_its_count() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: FarmGrid = main.get("grid")
	var fx: FxLayer = grid.fx
	var pic := UiIcon.glow_texture()
	for k in FxLayer.PRODUCE_POOL * 2:
		fx.produce(Vector2(100, 400), pic)
	_eq(fx.produce_made(), FxLayer.PRODUCE_POOL, "a fast sweep reuses the produce flyers, it never makes more")
	fx.produce(Vector2(100, 400), null)
	_eq(fx.produce_made(), FxLayer.PRODUCE_POOL, "and a crop with no picture flies nothing")
	_check(not bool(Quality.value("fx_trails", "low")) and bool(Quality.value("fx_trails", "mid")),
			"the sparkle trail is off on low, on from mid")
	Game.player.clear_queue()
	var least := Balance.i("feel.combo_min")
	_check(least > 1, "a sweep needs a few in a row to say its count")
	for k in least - 1:
		grid.call("_run", "harvest", 0)
	_check(not bool(grid.call("_sweep_end", "harvest", 0)), "a run shorter than that ends quietly")
	grid.call("_run", "harvest", 0)
	Game.player.queue.append({"kind": "harvest", "plot": 1})
	_check(not bool(grid.call("_sweep_end", "harvest", 0)), "while more of it is queued the sweep goes on")
	Game.player.queue.clear()
	_check(not bool(grid.call("_sweep_end", "plow", 0)), "another kind of work's end says nothing of it")
	var before := grid.get_child_count()
	_check(bool(grid.call("_sweep_end", "harvest", 0)), "the sweep's last harvest says its count")
	var said: Label = grid.get_child(before)
	_eq(said.text, FarmGrid.COUNT_TAG % least, "the run's length, once, over the last plot")
	Balance.override("feel.combo_min", 0)
	_check(not bool(grid.call("_sweep_end", "harvest", 0)), "0 turns it off")
	Balance.override("feel.combo_min", least)
	main.queue_free()
	await get_tree().process_frame
	Game.reset_game()

## The Next ready button goes to the nearest ready thing it has not shown yet, round and round, and the view
## travels there by itself until a finger takes it.
func test_359_next_ready_goes_round_everything_ready() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.coins = 100000
	var planted := 0
	for i in Game.plots.size():
		if planted < 3 and not Game.is_occupied(i) and Game.field.phase(i) == GameState.Phase.GRASS:
			Game.field.plow(i)
			Game.field.plant(i, "strawberries")
			planted += 1
	Game.debug_time_offset += int(Game.crops["strawberries"]["grow_seconds"]) + 60
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: FarmGrid = main.get("grid")
	var hud: FarmHud = main.get("hud")
	var camera: FarmCamera = main.get("camera")
	var spots := grid.ready_spots()
	_check(spots.size() >= 3, "the ripe plots are ready spots (%d)" % spots.size())
	_eq(grid.ready_count(), spots.size(), "counted as they are listed")
	var from: Vector2 = spots[0]["at"]
	var first := grid.next_ready(from)
	_eq(first["key"], spots[0]["key"], "the nearest first")
	var seen := {first["key"]: true}
	for k in spots.size() - 1:
		var next := grid.next_ready(from)
		_check(not seen.has(next["key"]), "then one not shown yet (%s)" % next["key"])
		seen[next["key"]] = true
	_eq(grid.next_ready(from)["key"], first["key"], "and when all were shown, round again")
	hud.side.show_ready_count()
	var button: Button = hud.side.get("_ready")
	_check(button.visible, "the button is there while something is ready")
	_eq((hud.side.get("_ready_badge") as Label).text, str(spots.size()), "with the count on it")
	var far: Dictionary = spots[spots.size() - 1]
	camera.go_to(grid.to_global(far["at"]))
	_check(camera.is_going(), "the view sets off")
	var before := camera.position.distance_to(grid.to_global(far["at"]))
	for k in 40:
		camera._process(0.1)
	_check(not camera.is_going(), "and arrives")
	_check(camera.position.distance_to(grid.to_global(far["at"])) <= before, "nearer than it was")
	camera.go_to(camera.position + Vector2(4000, 0))
	camera.begin_drag()
	_check(not camera.is_going(), "a finger on the view ends the journey")
	camera.end_drag()
	var withered := grid.spots_of("withered").size()
	Game.debug_time_offset += 60 * 86400
	_check(grid.spots_of("withered").size() >= withered + 3, "two months on, the plots are withered spots")
	_eq(grid.spots_of("ripe").size(), 0, "and no longer ripe ones")
	Game.debug_time_offset = 0
	main.queue_free()
	await get_tree().process_frame
	Game.reset_game()


## While you were away is a card of rows that each go to their thing; and an idle farm sheds its interface until
## the next touch, which brings it back and does nothing else.
func test_360_the_away_card_and_the_idle_view() -> void:
	var g := _farm()
	var i := _free(g)
	g.field.plow(i)
	g.field.plant(i, "strawberries")
	var from_t := g.now()
	_skip(g, int(g.crops["strawberries"]["grow_seconds"]) + 600)
	var rows := AbsenceReport.items(g, from_t, g.now())
	_check(not rows.is_empty() and str(rows[0]["kind"]) == "ripe", "crops ripened: the first row")
	_check(int(rows[0]["count"]) >= 1, "the one planted among them")
	_eq(AbsenceReport.words(rows[0]), tr("ABSENT_RIPE") % int(rows[0]["count"]), "said in the row's words")
	_eq(AbsenceReport.line(rows), AbsenceReport.build(g, from_t, g.now()), "the one line says the same rows")
	var said: Array = []
	g.message.connect(func(text: String) -> void: said.append(text))
	g.absence_note = "a line"   # not-ui
	g.call("_show_absence")
	_eq(said, ["a line"], "with nothing to show a card, it is said as a line")
	_done(g)
	Game.saving_enabled = false
	Game.reset_game()
	Game.tutorial_step = GameState.Tutorial.DONE
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	Game.absence_items = [{"kind": "ripe", "count": 3}]
	Game.absence_head = "head"   # not-ui
	Game.absence_note = "head\nthe bees left"   # not-ui
	Game.call("_show_absence")
	var card: AwayCard = hud.get("_away")
	_check(card != null and card.visible, "the card shows")
	_eq(Game.absence_note, "", "and it is said once")
	if card != null:
		var list: VBoxContainer = card.get("_rows")
		_eq(list.get_child_count(), 2, "a row for the crops and the bees' line under it")
		_check(list.get_child(0) is Button and list.get_child(1) is Label, "the row is pressed, the line is read")
		_check(hud.reading(), "the interface doesn't fade from under it")
		main.set("_last_input_msec", Time.get_ticks_msec() - 600000)
		main.call("_rest_when_idle")
		_check(not hud.resting, "so an idle farm keeps its interface while the card is up")
		card.visible = false
	main.set("_last_input_msec", 0)
	main.call("_rest_when_idle")
	_check(not hud.resting, "never touched (a tool, a test): the interface stays")
	main.set("_last_input_msec", Time.get_ticks_msec() - 600000)
	main.call("_rest_when_idle")
	_check(hud.resting, "ten minutes with no touch: the interface fades away")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	main.call("_input", press)
	_check(not hud.resting, "a touch brings it back")
	_check(main.get("_waking"), "and that press does nothing else")
	press.pressed = false
	main.call("_input", press)
	_check(not main.get("_waking"), "to its release")
	main.queue_free()
	await get_tree().process_frame
	Game.reset_game()



func test_373_no_text_in_the_interface_is_under_the_smallest_size() -> void:
	# Every word on the main screen and in every panel is at least UiTheme.min_font: nothing to squint at.
	Game.saving_enabled = false
	Game.reset_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var least := UiTheme.min_font()
	var screens: Array = [["the main screen", func() -> void: pass], ["the Market", hud.show_market],
		["Collections", hud.show_collections], ["Ribbons", hud.show_ribbons], ["Settings", hud.show_settings],
		["the inbox", hud.show_inbox],
		["the Barn", func() -> void: hud.show_building(int(Game.objects.filter(
			func(o: Dictionary) -> bool: return o["id"] == "barn")[0]["uid"]))]]
	for screen: Array in screens:
		(screen[1] as Callable).call()
		await get_tree().process_frame
		for l: Label in hud.find_children("*", "Label", true, false):
			if l.is_visible_in_tree() and l.text.strip_edges() != "":
				var px := l.get_theme_font_size("font_size")
				_check(px >= least, "%s: \"%s\" is %d, at least %d" % [screen[0], l.text.left(30), px, least])
	(hud.get("book") as BookPanel).close_panel()
	Game.modal_open = false
	main.queue_free()
	await get_tree().process_frame


## A menu of cards scales to any number of items (scaling report: menus build only what's visible): a list of
## 5,000 made-up items keeps only the cards in view, opens, scrolls and refreshes within a budget, and a refresh
## reads only the faces on screen.
func test_374_a_card_list_of_thousands_keeps_only_the_cards_in_view() -> void:
	const ITEMS := 5000
	const MOST_CARDS := 90       # cards that may exist at once, whatever the count (a screen and a spare row each way)
	const OPEN_MS := 20.0        # budgets on a desktop CI runner (a phone is a few times slower); about 2 ms now
	const SCROLL_MS := 20.0
	const REFRESH_MS := 10.0
	var ids: Array[String] = []
	for k in ITEMS:
		ids.append("fake_%d" % k)
	var asked := [0]
	var picture := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var face := func(id: String) -> Dictionary:
		asked[0] += 1
		return {"name": id, "line": "", "badge": ["coin", "100"], "locked": false, "stars": [], "buyable": true}
	var tapped := []
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(1200, 700)
	add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	# (Only the list's own work is timed: making it, then laying out its first screen. The frames between are the
	# engine's and the whole test scene's, not the list's, and timing them made the budget flaky.)
	var started := Time.get_ticks_usec()
	var list := CardList.make(ids, face, func(id: String) -> void: tapped.append(id), 1200.0,
		func(_id: String) -> Texture2D: return picture)
	page.add_child(list)
	var open_ms := (Time.get_ticks_usec() - started) / 1000.0
	await get_tree().process_frame
	await get_tree().process_frame
	for card: CardFace in list.shown():   # (the first screen again, from nothing, now the list has its size)
		card.queue_free()
	list._shown.clear()
	list._spare.clear()
	await get_tree().process_frame
	open_ms += _fastest_ms(func() -> void:   # (the first screen laid out from nothing, each try)
		for card: CardFace in list.shown():
			card.free()
		list._shown.clear()
		list._spare.clear()
		list._lay_out())
	_check(list.get_child_count() <= MOST_CARDS and not list.shown().is_empty(),
		"only the cards in view are made (%d of %d)" % [list.get_child_count(), ITEMS])
	_check(list.custom_minimum_size.y > scroll.size.y * 10.0, "but the list is as tall as all its rows")
	_check(open_ms < OPEN_MS, "it opens within budget (%.1f ms)" % open_ms)
	var scroll_ms := _fastest_ms(func() -> void:
		for k in 10:
			scroll.scroll_vertical = int(list.custom_minimum_size.y * k / 10.0)
			list._lay_out())
	_check(scroll_ms < SCROLL_MS, "scrolling the whole list is within budget (%.1f ms)" % scroll_ms)
	_check(list.get_child_count() <= MOST_CARDS, "and the cards are reused, not made again (%d)" % list.get_child_count())
	var last: CardFace = list.shown()[0]
	_check(int(last.id.trim_prefix("fake_")) > ITEMS / 2, "the cards show the items scrolled to")
	asked[0] = 0
	var refresh_ms := _fastest_ms(func() -> void: list.refresh())
	_check(asked[0] == list.shown().size() * TIMING_TRIES, "a refresh reads only the faces on screen")
	_check(refresh_ms < REFRESH_MS, "within budget (%.1f ms)" % refresh_ms)
	list.press("fake_4999")
	_eq(tapped, ["fake_4999"], "a card's item can be pressed whether it is on screen or not")
	scroll.free()


## A home's sheet is exactly as tall as what it says and sits wholly on the screen at the bottom: its wrapped
## lines were once measured before they had a width (a word a line), so it opened screen-tall with only its
## buttons in view, the rest an empty box. It also shrinks back when it says less, comes back fitted after a stale
## size, keeps inside a narrow screen, and the away card (the other free-floating card) shrinks the same way.
func test_366_a_home_sheet_fits_what_it_says_and_stays_on_the_screen() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.coins = 1000000
	Game.xp = Game.xp_for_level(20)
	Game.tutorial_step = GameState.Tutorial.DONE
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var homes := 0
	for id: String in ["chicken_coop", "dairy_farm", "horse_stable", "pig_pen", "goat_pen"]:
		if not Game.items.has(id):
			continue
		var spot := Vector2i(-1, -1)
		for r in Game.farm_size:
			for c in Game.farm_size:
				if spot.x < 0 and Game.can_place(id, r, c):
					spot = Vector2i(r, c)
		if spot.x < 0 or not Game.buy_and_place(id, spot.x, spot.y):
			continue
		var home := Game.object_at(Game.index_of(spot.x, spot.y))
		_all_materials(Game, 10)
		Game.land.add_materials(int(home["uid"]))
		if not BuildingSheet.suits(home):
			continue
		homes += 1
		hud.show_building(int(home["uid"]))
		for f in 4:   # (the slide, and the frame its wrapped lines learn their width)
			await get_tree().process_frame
		await _motion_ends(hud.sheet)
		_sheet_fits(hud.sheet, "%s's sheet" % id)
	_check(homes >= 2, "several homes opened as sheets (%d)" % homes)
	var sheet: BuildingSheet = hud.sheet
	if sheet == null:
		main.queue_free()
		await get_tree().process_frame
		return
	# Says more, then less: it grows, then shrinks back, still at the bottom.
	var note: Label = sheet.get("_note")
	var before := sheet.size.y
	note.text = "a\nb\nc\nd\ne"   # not-ui
	note.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	_check(sheet.size.y > before, "five more lines: taller (%d > %d)" % [sheet.size.y, before])
	_sheet_fits(sheet, "taller")
	note.text = ""
	note.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	_check(absf(sheet.size.y - before) < 1.0, "the lines gone: back to its size (%d, was %d)" % [sheet.size.y, before])
	_sheet_fits(sheet, "shrunk back")
	# A stale, screen-high size (the bug) is gone when it opens again.
	var uid := int(sheet.get("_uid"))
	sheet.close()
	sheet.size = Vector2(sheet.size.x, sheet.get_parent_area_size().y * 3.0)
	hud.show_building(uid)
	await _motion_ends(sheet)
	_sheet_fits(sheet, "opened again after a stale size")
	sheet.close()
	for area: Vector2 in [Vector2(360, 780), Vector2(780, 360), Vector2(2560, 1440)]:
		var w := BuildingSheet.width_for(area)
		_check(w <= area.x - 2.0 * BuildingSheet.EDGE and w > 0.0, "a %s screen keeps it inside (%d)" % [area, w])
	# The away card, the other free-floating card: fewer rows, smaller card.
	Game.absence_items = [{"kind": "ripe", "count": 3}, {"kind": "ripe", "count": 4}, {"kind": "ripe", "count": 5}]
	Game.absence_note = "head\none\ntwo\nthree"   # not-ui
	Game.call("_show_absence")
	await get_tree().process_frame
	await get_tree().process_frame
	var card: AwayCard = hud.get("_away")
	var tall := card.size.y if card != null else 0.0
	Game.absence_items = [{"kind": "ripe", "count": 1}]
	Game.absence_note = "head"   # not-ui
	Game.call("_show_absence")
	for f in 3:
		await get_tree().process_frame
	if card != null:
		_check(card.size.y < tall, "the away card shrinks with fewer rows (%d < %d)" % [card.size.y, tall])
		_check(absf(card.size.y - card.get_combined_minimum_size().y) < 1.0, "and is just as big as they are")
		card.close()
	main.queue_free()
	await get_tree().process_frame


func _sheet_fits(sheet: BuildingSheet, what: String) -> void:
	var area := sheet.get_parent_area_size()
	_check(sheet.is_open(), "%s is up" % what)
	_check(absf(sheet.size.y - sheet.get_combined_minimum_size().y) < 1.0,
		"%s is as tall as what it says (%d, needs %d)" % [what, sheet.size.y, sheet.get_combined_minimum_size().y])
	_check(sheet.size.y < area.y * 0.8, "%s is not screen-tall (%d of %d)" % [what, sheet.size.y, area.y])
	_check(sheet.position.y >= 0.0 and absf(sheet.position.y + sheet.size.y - (area.y - BuildingSheet.EDGE)) < 1.0,
		"%s sits wholly on the screen at the bottom (top %d)" % [what, sheet.position.y])
	_check(sheet.position.x >= 0.0 and sheet.position.x + sheet.size.x <= area.x + 0.5, "%s is inside the width" % what)


## The farmer pictures in Settings sit in the middle of their buttons: they were centred before they had a size,
## so each hung off its button's corner over the line below. Anything anchored to the middle of its parent in the
## panel lies inside it, and `UiKit.centered` centres a thing that has no size yet.
func test_367_centred_pictures_sit_inside_their_buttons() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.tutorial_step = GameState.Tutorial.DONE
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var book: BookPanel = hud.get("book")
	hud.call("show_settings")
	for f in 3:
		await get_tree().process_frame
	var faces := book.find_children("*", "PortraitIcon", true, false)
	_check(faces.size() >= 2, "a picture for each farmer (%d)" % faces.size())
	for face: PortraitIcon in faces:
		var inside: Rect2 = face.get_global_rect()
		var holder: Rect2 = (face.get_parent() as Control).get_global_rect()
		_check(face.size.x > 0.0 and holder.grow(0.5).encloses(inside),
			"a farmer picture lies inside its button (%s in %s)" % [inside, holder])
		_check(inside.get_center().distance_to(holder.get_center()) < 1.0, "and in its middle")
	var centred := 0
	for c: Control in book.find_children("*", "Control", true, false):
		var parent := c.get_parent() as Control
		if parent == null or not c.is_visible_in_tree() or c.anchor_left != 0.5 or c.anchor_top != 0.5:
			continue
		centred += 1
		_check(parent.get_global_rect().grow(0.5).encloses(c.get_global_rect()),
			"%s, centred, lies inside %s" % [c.name, parent.name])
	_check(centred >= 2, "the panel has centred things to check (%d)" % centred)
	book.close_panel()
	Game.modal_open = false
	# Centred before it has a size: it grows from the middle once it gets one.
	var box := Control.new()
	box.size = Vector2(100, 100)
	add_child(box)
	var thing := UiKit.centered(Control.new())
	thing.custom_minimum_size = Vector2(40, 20)
	box.add_child(thing)
	await get_tree().process_frame
	_eq(thing.position, Vector2(30, 40), "a thing centred before it had a size grows from the middle")
	box.free()
	main.queue_free()
	await get_tree().process_frame


## The words on every label and button showing under `node`, and the buttons by their words.
func _words_on(node: Node) -> Dictionary:
	var out := {"words": {}, "buttons": {}}
	for c in node.find_children("*", "Control", true, false):
		if c.is_queued_for_deletion() or not (c as Control).is_visible_in_tree():
			continue
		if c is Label:
			out["words"][(c as Label).text] = true
		elif c is Button:
			out["words"][(c as Button).text] = true
			if not out["buttons"].has((c as Button).text):
				out["buttons"][(c as Button).text] = []
			out["buttons"][(c as Button).text].append(c)
	return out


## The card lists on the page showing, top to bottom.
func _lists_on(book: BookPanel) -> Array:
	return _lists_in(book.page())


## The card lists in `node` (a panel's page, a sheet's page).
func _lists_in(node: Node) -> Array:
	var out: Array = []
	for c in node.find_children("*", "CardList", true, false):
		if not c.is_queued_for_deletion():
			out.append(c)
	return out


func test_373_the_crafting_menu_is_tabs_of_slots_recipe_cards_goods_and_a_pantry() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.coins = 1000000
	Game.xp = Game.xp_for_level(30)
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var book := hud.book
	var tab_row: SheetTabs
	var page: VBoxContainer
	var spot := Vector2i(-1, -1)
	for r in Game.farm_size:
		for c in Game.farm_size:
			if spot.x < 0 and Game.can_place("bakery", r, c):
				spot = Vector2i(r, c)
	_check(Game.buy_and_place("bakery", spot.x, spot.y), "a Bakery")
	var o := Game.object_at(Game.index_of(spot.x, spot.y))
	var uid := int(o["uid"])
	Game.crafting.bushels = {"pumpkins": 8, "wheat": 12, "strawberries": 4}
	_check(Game.crafting.start_craft(uid, "pumpkin_bread"), "a loaf in the oven")
	Game.crafting.goods = {"strawberry_shortcake": 2}
	hud.open_full_panel(uid)
	for f in 3:
		await get_tree().process_frame
	_check(hud.sheet.is_open() and not book.is_open(), "the menu is in the building's sheet, not another window")
	tab_row = hud.sheet.get("_tabs")
	page = hud.sheet.get("_page")
	var tabs: Array = hud.sheet.get("_specs")
	_eq(tabs.map(func(t: Array) -> String: return str(t[0])), [tr("CRAFT_TAB_MAKE"), tr("CRAFT_TAB_GOODS"),
		tr("CRAFT_TAB_PANTRY")], "three tabs: Make, Goods, Pantry")
	_eq(hud.crafting.tabs({"id": "feed_mill"}).size(), 2, "a Feed Mill makes no goods: no Goods tab")
	# Make: the slots and the recipes are the menus' own card lists; the recipe picked is told in the strip.
	var lists := _lists_in(page)
	_eq(lists.size(), 2, "Make is two card lists: the slots, the recipes")
	var slots: CardList = lists[0]
	var recipes: CardList = lists[1]
	_eq(slots.ids, [HudCrafting.SLOT + "0", HudCrafting.NEXT] as Array[String],
		"the craft under way and the next star's slot")
	var cooking: Dictionary = slots.face_of.call(slots.ids[0])
	_eq(cooking["name"], Game.name_of("pumpkin_bread"), "the slot's card names what is cooking")
	_check(cooking.has("bar") and float(cooking["bar"][0]) < 0.1, "with a bar that has just begun")
	_check(bool(slots.face_of.call(HudCrafting.NEXT)["locked"]), "the next star's slot is locked")
	_eq(recipes.ids.size(), 15, "every recipe has its card")
	var bread: Dictionary = recipes.face_of.call("pumpkin_bread")
	_eq(bread["badge"], ["coin", UiTheme.number(Game.crafting.good_price("pumpkin_bread"))],
		"a recipe's card says what the good sells for")
	_check(bool(recipes.face_of.call("truffle_pie")["locked"]) and recipes.face_of.call("truffle_pie")["line"]
		== tr("UNLOCKS_AT_STARS") % 4, "a locked one says the star it unlocks at")
	_eq(recipes.face_of.call("carrot_muffins")["line"], tr("CRAFT_NEEDS_MORE") % 5,
		"one short of ingredients says how many (3 carrots, 2 eggs)")
	var seen := _words_on(page)
	_check(seen["words"].has(hud.crafting.gives(Game.catalog.get_def("pumpkin_bread") as RecipeDef)),
		"the strip tells what the recipe picked gives (the first there are ingredients for)")
	var makes: Array = seen["buttons"].get(tr("MAKE_IT"), [])
	_eq(makes.size(), 1, "one Make button, for the recipe picked")
	_check((makes[0] as Button).disabled and seen["words"].has(tr("EVERY_SLOT_IS_BUSY")),
		"which can't start: every slot is busy")
	# The craft finishes while the panel is open: it lands in Goods and the slot is free.
	Game.debug_time_offset += 3600
	await get_tree().create_timer(HudCrafting.TICK + 0.3).timeout
	for f in 3:
		await get_tree().process_frame
	_eq(int(Game.crafting.goods.get("pumpkin_bread", 0)), 1, "the loaf is done, with the panel open")
	lists = _lists_in(page)
	_eq((lists[0] as CardList).ids, [HudCrafting.FREE + "0", HudCrafting.NEXT] as Array[String], "its slot shows free")
	(lists[1] as CardList).press("strawberry_shortcake")
	for f in 3:
		await get_tree().process_frame
	seen = _words_on(page)
	_check(seen["words"].has(hud.crafting.gives(Game.catalog.get_def("strawberry_shortcake") as RecipeDef)),
		"tapping a recipe's card picks it: the strip tells about it")
	makes = seen["buttons"].get(tr("MAKE_IT"), [])
	_check(makes.size() == 1 and not (makes[0] as Button).disabled, "and it can be made")
	(makes[0] as Button).pressed.emit()
	_eq((o.get("slots", []) as Array).size(), 1, "Make starts it")
	_eq(str(o["slots"][0]["r"]), "strawberry_shortcake", "the recipe picked")
	# Goods: each good a card; the one picked is sold or used; all sold at once.
	tab_row.pick(1)
	for f in 3:
		await get_tree().process_frame
	lists = _lists_in(page)
	_eq((lists[0] as CardList).ids, ["pumpkin_bread", "strawberry_shortcake"] as Array[String], "the goods on the shelf")
	_eq((lists[0] as CardList).face_of.call("strawberry_shortcake")["count"], tr("TIMES_N") % 2, "two shortcakes")
	(lists[0] as CardList).press("strawberry_shortcake")
	for f in 3:
		await get_tree().process_frame
	seen = _words_on(page)
	_check(seen["buttons"].has(tr("USE_FUEL") % Game.crafting.good_fuel("strawberry_shortcake")),
		"the one picked can be used for fuel")
	var coins := Game.coins
	var worth := 2 * Game.crafting.good_price("strawberry_shortcake") + Game.crafting.good_price("pumpkin_bread")
	_check(seen["buttons"].has(tr("SELL_ALL_GOODS") % UiTheme.number(worth)), "Sell all says what it brings")
	(seen["buttons"][tr("SELL_ALL_GOODS") % UiTheme.number(worth)][0] as Button).pressed.emit()
	_check(Game.coins >= coins + worth, "and brings it (a first sale's ribbon may add its own)")
	_check(Game.crafting.goods.is_empty(), "the shelf is empty")
	# Pantry: what is held, and the Farmers Market's offer as cards: a tap buys one.
	tab_row.pick(2)
	for f in 3:
		await get_tree().process_frame
	seen = _words_on(page)
	_check(seen["words"].has(tr("BUSHELS_OF") % [Game.crafting.total_bushels(), Balance.i("crafting.bushel_cap")]),
		"the pantry says how full it is")
	var stall: CardList = _lists_in(page)[0]
	_eq(stall.ids.size(), Balance.i("crafting.stall_crops"), "the market's offer for today")
	var id: String = stall.ids[0]
	_eq(stall.face_of.call(id)["badge"], ["coin", UiTheme.number(Game.crafting.bushel_price(id)), false],
		"a market card says its price")
	var had := int(Game.crafting.bushels.get(id, 0))
	stall.press(id)
	_eq(int(Game.crafting.bushels.get(id, 0)), had + 1, "a tap buys one")
	hud.sheet.close()
	main.queue_free()


## Numbers and type (the type pass): one formatter (grouped digits, short past a million where room is tight, a
## reward's sign), every text size on the type scale, and the bold face's digits one width so a changing number
## never shifts sideways.
func test_375_numbers_are_written_alike_and_text_sits_on_the_type_scale() -> void:
	_eq(UiTheme.number(950), "950", "in full below a thousand")
	_eq(UiTheme.number(4860), "4.8k", "short from a thousand, rounded down")
	_eq(UiTheme.number(12000), "12k", "no .0")
	_eq(UiTheme.number(125999), "125k", "whole units from a hundred")
	_eq(UiTheme.number(1250000), "1.2M", "millions")
	_eq(UiTheme.number(-1500), "-1.5k", "a negative too")
	_eq(UiTheme.exact(12450), "12,450", "exact: every digit, grouped by commas")
	_eq(UiTheme.signed(4860), "+4.8k", "a reward carries its sign")
	_eq(UiTheme.tidy("Sold the Cow for 12450 coins, +1,500 XP at 10:30, level 12"),
		"Sold the Cow for 12.4k coins, +1.5k XP at 10:30, level 12", "numbers in words come out the one way")
	for px in [11.0, 13.0, 17.0, 20.0, 26.0, 40.0]:
		_check(UiTheme.on_scale(px) in UiTheme.TYPE_SCALE, "%d px asked comes out on the scale" % px)
	var bold := UiTheme.bold()
	var widths := {}
	for d in 10:
		widths[bold.get_string_size(str(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x] = true
	_eq(widths.size(), 1, "every digit of the bold face is one width")


func test_391_the_helpers_flower_opens_close_round_its_button() -> void:
	var side := 100.0
	for n in [1, 3, 5, 6]:   # (the flower holds six at most)
		var spots := HudHelpers.spots_for(n, side)
		_eq(spots.size(), n, "every petal has a place (%d)" % n)
		var petal := side * HudHelpers.PETAL_SHARE
		for i in n:
			_check(spots[i].length() <= side * 2.3, "petals stay close: within 2.3 buttons (%d)" % n)
			_check(spots[i].x >= -0.01 and spots[i].y <= 0.01, "up and to the right, on the screen (%d)" % n)
			for j in range(i + 1, n):
				_check(spots[i].distance_to(spots[j]) >= petal * 0.99, "petals never overlap (%d)" % n)


## The info texts name the data's numbers, not their own copy of them (a changed number in the data changes the
## text): the Stable's day against a loose horse's three, the seedling's cans, a Single Bloom's days ready.
func test_440_info_texts_take_their_numbers_from_the_data() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.farm_size = GameState.MAX_SIZE
	Game.coins = 1000000
	Game.xp = Game.xp_for_level(ShowcaseFarm.top_level(Game))
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var shown := func(content: VBoxContainer) -> String:
		var out := ""
		for l: Label in content.find_children("*", "Label", true, false):
			out += l.text + "\n"
		for b: BaseButton in content.find_children("*", "BaseButton", true, false):
			out += b.tooltip_text + "\n"   # (an info button's longer words)
		content.free()
		return out
	var stable_box := VBoxContainer.new()
	hud.buildings.add_building_special_info(stable_box, {"id": "horse_stable", "uid": -1})
	var horse := int(Game.item_data("horse")["cycle_seconds"])
	var text: String = shown.call(stable_box)
	_check(FarmGrid.format_duration(horse) in text and FarmGrid.format_duration(86400) in text,
		"the Stable's text names its day and a loose horse's cycle: %s" % text)
	var sapling_box := VBoxContainer.new()
	hud.buildings.add_building_special_info(sapling_box, {"id": "orchard", "uid": -1})
	var cans := (Game.catalog.get_def("mystery_seedling") as YoungDef).needs()
	text = shown.call(sapling_box)
	_check(str(cans) in text and not "%d" in text, "the Orchard's text names the seedling's %d cans" % cans)
	_check(Game.buy_and_place("rose_bloom", 20, 20), "(a Single Rose Bloom)")
	hud.building_uid = int(Game.object_at(Game.index_of(20, 20))["uid"])
	var bloom_box := VBoxContainer.new()
	hud.barn.build_bloom(bloom_box)
	text = shown.call(bloom_box)
	_check(text.count(FarmGrid.format_duration(Balance.i("blooms.wither_after"))) >= 2 and not "%s" in text,
		"a Single Bloom's text names its days ready")
	main.queue_free()
	await get_tree().process_frame


## The inbox's lines keep one column: a line with no thing to show (a help, a plain gift) keeps the thing's room,
## so every sender's name starts where the others' do instead of jumping left under the picture above it.
func test_524_inbox_names_stand_in_one_column() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.open_showcase()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var widths: Array[float] = []
	for give: Dictionary in [{"what": InboxItem.ITEM, "id": "cow", "n": 1}, {"what": InboxItem.COINS, "n": 50},
			{"what": InboxItem.FUEL, "n": 1}]:
		var line: Control = hud.inbox.line_for(InboxItem.make(900 + widths.size(), InboxItem.GIFT, 1, 0, give))
		add_child(line)
		widths.append(line.get_child(1).get_combined_minimum_size().x)
		line.queue_free()
	for w in widths:
		_check(w > 0.0 and absf(w - widths[0]) < 1.0, "each inbox line keeps the thing's room (%s)" % str(widths))
	main.queue_free()
	await get_tree().process_frame


## The top bar at its widest: the longest farm name (in the widest letter) and a late farm's counters fit beside
## the coins and the level star on every screen; a longer name from a hand-edited save is cut to the longest.
func test_525_the_top_bar_fits_the_longest_name_and_the_biggest_counters() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	var data := {}
	Game.player.farm_name = "W".repeat(PlayerSystem.NAME_MAX * 3)
	Game.player.save_to(data)
	Game.player.load_from(data)
	_eq(Game.player.farm_name, "W".repeat(PlayerSystem.NAME_MAX), "a saved name longer than the longest is cut")
	Game.player.set_farm_name("  %s  " % "M".repeat(PlayerSystem.NAME_MAX + 5))
	_eq(Game.player.farm_name.length(), PlayerSystem.NAME_MAX, "a name is kept at most the longest")
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	Game.player.farm_name = "W".repeat(PlayerSystem.NAME_MAX)
	hud.top.show_name()
	Game.coins = 987654321
	Game.gems = 99999
	Game.xp = 99999999
	Game.coins_changed.emit(Game.coins)
	Game.gems_changed.emit(Game.gems)
	Game.xp_changed.emit(Game.xp, Game.level())
	var window := get_tree().root
	var was := window.size
	for shape: Vector2i in [Vector2i(1280, 720), Vector2i(2340, 1080), Vector2i(1024, 768)]:
		window.size = shape
		await get_tree().process_frame
		await get_tree().process_frame
		var parts: Array[Control] = hud.top.hideable()
		for a in parts:
			for b in parts:
				if a != b and a.get_global_rect().intersects(b.get_global_rect()):
					_check(false, "%s: %s and %s don't overlap at the widest" % [shape, a.name, b.name])
	window.size = was
	main.queue_free()
	await get_tree().process_frame


func test_545_the_panels_compile_after_the_first_screen() -> void:
	# The start compiles every script the first screen names (8.2 s on the Galaxy A05s, ~3.7 s of it compiling): the
	# HUD loads its panels and the building sheet by path, so nothing on the way to the first screen names their
	# classes (docs/PERF_RUN.md, the start). Each panel is still its own class, made once, on first use.
	for path: String in ["res://scripts/hud.gd", "res://scripts/ui/card_face.gd", "res://scripts/hud/hud_goals.gd"]:
		var code := RegEx.create_from_string("#.*").sub(FileAccess.get_file_as_string(path), "", true)
		for cls in ["HudMarket", "HudCrafting", "HudBuildings", "HudBarn", "HudFeed", "HudBooks", "HudInbox",
				"HudSettings", "HudSeeds", "BuildingSheet"]:
			_check(not RegEx.create_from_string("\\b%s\\b" % cls).search(code), "%s does not name %s" % [path, cls])
	Game.reset_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	for id: StringName in FarmHud.PANEL_SCRIPTS:
		var panel: Variant = hud.get(id)
		_check(panel != null and (panel as RefCounted).get_script().resource_path == FarmHud.PANEL_SCRIPTS[id],
			"%s is its own panel" % id)
		_check(is_same(panel, hud.get(id)), "%s is made once" % id)
	main.queue_free()
	await get_tree().process_frame


func test_551_the_pictures_renderer_compiles_after_the_first_screen() -> void:
	# ItemIcons is the lookup the first screen needs (shipped and kept pictures); the renderer that makes a missing
	# one from its model loads by path a frame after the first screen, so the start never compiles it or the models
	# it pictures (docs/PERF_RUN.md, the start).
	var code := RegEx.create_from_string("#.*").sub(FileAccess.get_file_as_string("res://scripts/ui/item_icons.gd"),
		"", true)
	for cls in ["IconStyle", "IconDevelop", "GpuRead", "GoodsModel", "MaterialModel", "AssetRegistry", "Crops3D",
			"ScaleGuide"]:
		_check(not RegEx.create_from_string("\\b%s\\b" % cls).search(code), "ItemIcons does not name %s" % cls)
	Game.reset_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	var hud: FarmHud = main.get("hud")
	_check(hud.find_children("*", "SubViewport", true, false).is_empty(), "no renderer at the first screen")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_instance_valid(ItemIcons._shown) and ItemIcons._shown.get_script().resource_path == ItemIcons.MAKER,
		"the renderer comes a frame later, from its own file")
	_check(not ItemIcons.is_made("a_thing_never_asked"), "an unknown picture is not made")
	main.queue_free()
	await get_tree().process_frame


func test_552_the_moment_cards_compile_when_first_shown() -> void:
	# The level-up, a mystery's reveal and the away card are made when first needed and load by path then (and a
	# few frames after the first screen), so the start never compiles them (docs/PERF_RUN.md, the start).
	var code := RegEx.create_from_string("#.*").sub(FileAccess.get_file_as_string("res://scripts/hud.gd"), "", true)
	for cls in ["LevelUpPopup", "RevealCard", "AwayCard"]:
		_check(not RegEx.create_from_string("\\b%s\\b" % cls).search(code), "the HUD does not name %s" % cls)
	Game.reset_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	_check(hud.get("_level_popup") == null, "no level-up at the first screen")
	Game.leveled_up.emit(2)
	var popup: Control = hud.get("_level_popup")
	_check(popup != null and popup.get_script().resource_path == FarmHud.LEVEL_SCRIPT, "made at the first level up")
	_check(popup != null and popup.get_parent() == hud.get("_level_slot") and popup.visible, "in its layer, shown")
	_check(is_same(popup, hud.level_popup()), "made once")
	Game.modal_open = false
	main.queue_free()
	await get_tree().process_frame
