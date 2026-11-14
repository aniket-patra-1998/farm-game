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
## enough for a thumb, and the eight tools in FarmVille's order.
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
	_eq(ids, ["hand", "plow", "plant", "harvest", "fertilize", "move", "store", "sell"], "the eight tools")
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
	for k in range(1, HudMarket.SHELVES.size() + 1):
		book.show_tab(k)
		var kind := str(HudMarket.SHELVES[k - 1][0])
		var want := 0
		for id in Game.item_order:
			if Game.item_data(id)["kind"] == kind and int(Game.item_data(id)["unlock_level"]) < 99:
				want += 1
		var cards := 0
		for grid: GridContainer in book.find_children("*", "GridContainer", true, false):
			if not grid.is_queued_for_deletion():
				cards += grid.get_child_count()
		_eq(cards, want, "the %s shelf has a card for each" % kind)
	var placed := []
	hud.place_requested.connect(func(id: String) -> void: placed.append(id))
	book.show_tab(HudMarket.SHELVES.find(["decor", "DECORATIONS"]) + 1)
	var bought := false
	for grid: GridContainer in book.find_children("*", "GridContainer", true, false):
		if grid.is_queued_for_deletion():
			continue
		for card: Button in grid.get_children():
			if not bought and card.get_theme_stylebox("normal").bg_color == UiTheme.color("card_face"):
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
