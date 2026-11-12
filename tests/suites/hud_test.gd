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
		main.free()
		return
	var book: BookPanel = hud.get("_book")
	var opened := 0
	for panel in ["_show_market", "_show_collections", "_show_ribbons", "_show_settings"]:
		hud.call(panel)
		opened += 1
		_check(book.visible, "%s opens the book" % panel)
	var seen := {}
	for o in Game.objects.duplicate():
		var key := str(o["id"])
		if seen.has(key) or Game.kind_of(o) not in ["building", "bloom"]:  # (the farm taps only these open a panel)
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
	main.free()
