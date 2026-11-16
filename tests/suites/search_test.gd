extends TestSuite

const BUDGET_MS := 4.0   # a letter typed over 5,000 things (CI machines are slower than phones are fast)
## Search (docs/SEARCH.md): finding by name, word start, what a thing gives and holds, plurals and one typo;
## every typed word must be found; chips narrow; nothing found offers the nearest name; a list puts a field over
## itself once it holds enough; the Market searches every shelf; 5,000 things searched within budget.


func _index(names: Array) -> SearchIndex:
	var ids: Array[String] = []
	for n: String in names:
		ids.append(n.to_snake_case())
	return SearchIndex.new(ids, func(id: String) -> Dictionary:
		var i := ids.find(id)
		return {"name": names[i], "more": "egg" if names[i].contains("Chicken") else ""})


func test_385_search_finds_by_word_start_plural_and_one_typo() -> void:
	var idx := _index(["Peach Tree", "Chicken Coop", "Strawberry", "Straw Hat", "Cherry Tree"])
	_eq(idx.find("ch")[0], "chicken_coop", "a word begun at its start comes before one inside (Peach)")
	_check("cherry_tree" in idx.find("ch"), "every name with a word starting so")
	_eq(idx.find("eggs"), ["chicken_coop"] as Array[String], "what a thing gives finds it, plurals as one")
	_eq(idx.find("strawbery"), ["strawberry"] as Array[String], "one letter off finds it")
	_eq(idx.find("straw hat"), ["straw_hat"] as Array[String], "every typed word must be found")
	_eq(idx.find("").size(), 5, "an empty query shows everything")
	_eq(idx.find("tree", func(id: String) -> bool: return id.begins_with("peach")), ["peach_tree"] as Array[String],
		"a filter narrows what is found")
	_eq(idx.find("qqqq").size(), 0, "nonsense finds nothing")
	_eq(idx.nearest("strwberry"), "Strawberry", "nothing found offers the nearest name")
	_eq(SearchIndex.one_of("berries"), "berry", "plurals: -ies")
	_eq(SearchIndex.one_of("grass"), "grass", "a double s stays")


func test_386_items_are_found_by_what_they_are_give_and_hold() -> void:
	Game.reset_game()
	var coop := ItemSearch.words_of("chicken_coop")
	_check(str(coop["more"]).to_lower().contains("egg"), "a coop is found by the eggs of what it holds")
	var cow := ItemSearch.words_of("cow")
	_check(str(cow["more"]).to_lower().contains("animal"), "a cow by its kind's words")
	_eq(ItemSearch.words_of("no_such_thing"), {}, "a thing not in the catalog has no words of its own")
	for menu in ["market", "barn", "seeds"]:
		_check(not ItemSearch.chips_for(menu).is_empty(), "%s has its filters" % menu)


func test_387_5000_things_are_searched_within_budget() -> void:
	var names: Array = []
	var ids: Array[String] = []
	for k in 5000:
		names.append("Item %d Thing%d" % [k, k % 97])
		ids.append("item_%d" % k)
	var idx := SearchIndex.new(ids, func(id: String) -> Dictionary:
		return {"name": names[int(id.trim_prefix("item_"))], "more": "farm stuff"})
	var began := Time.get_ticks_usec()
	for q in ["t", "th", "thi", "thin", "thing", "thing4", "thing42"]:
		idx.find(q)
	var each := (Time.get_ticks_usec() - began) / 1000.0 / 7.0
	_check(each < BUDGET_MS, "a letter typed over 5,000 things costs %.2f ms" % each)


func test_388_menus_get_a_search_field_and_the_market_searches_every_shelf() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.tutorial_step = GameState.Tutorial.DONE
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	hud.call("show_market")
	for f in 4:
		await get_tree().process_frame
	var bars := hud.book.find_children("*", "SearchBar", true, false)
	_check(bars.size() == 1, "the Market's shelf has one search field (%d)" % bars.size())
	if not bars.is_empty():
		var bar: SearchBar = bars[0]
		bar.search("coop")
		await get_tree().process_frame
		await get_tree().process_frame
		_check("chicken_coop" in bar.list.ids, "searching a shelf finds things on another (the coop)")
		_check(str(bar.list.face("chicken_coop").get("line", "")) != "", "and says its shelf, or its own line")
		bar.search("strawbery")
		await get_tree().process_frame
		await get_tree().process_frame
		_check(bar.list.ids.any(func(id: String) -> bool: return Game.crops.has(id)),
			"seeds are found from any shelf, one typo and all")
		bar.search("")
		await get_tree().process_frame
		_eq(bar.list.ids, bar.list.all_ids, "clearing shows the shelf again")
	hud.book.close_panel()
	Game.modal_open = false
	main.queue_free()
	await get_tree().process_frame
