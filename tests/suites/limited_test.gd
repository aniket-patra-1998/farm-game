extends TestSuite
## Limited animals in the rest of the game (docs/LIMITED.md): whatever a plain animal of their kind does there,
## they do, with nothing of their own to keep in step. How they are sold and found is nurture_test's test_581,
## their Market tab hud_test's, their coats' touches world3d_test's.

const SAVE := "user://test_limited_save.json"


func test_585_a_limited_animal_does_all_its_plain_kind_does() -> void:
	var g := _farm()
	g.coins = 10000000
	g.farm_size = GameState.MAX_SIZE
	g.xp = g.xp_for_level(ShowcaseFarm.top_level(g))
	g.storage.barn().erase("broken")
	var homes := {}   # a home's id -> the one built on this farm
	var per_gem := Balance.i("market.sell_coins_per_gem")
	for id: String in g.item_order:
		var a := g.catalog.get_def(id) as AnimalDef
		if a == null or not a.is_limited() or a.is_young():
			continue
		var home_id := _home_of(g, id)
		if not homes.has(home_id):
			homes[home_id] = _built(g, home_id)
		var home: Dictionary = homes[home_id]
		var plain := g.limited.plain_of(id, home_id)
		_eq(g.limited.ordinary({"id": home_id, "inside": {id: 2}}), {plain: 2},
			"a home of %s alone finds its plain kind" % id)
		# Its kind's voice, feed and produce.
		_eq(AnimalRig.of(g.item_data(id)).family, AnimalRig.of(g.item_data(plain)).family,
			"%s moves and calls as its kind does" % id)
		_check(not Sound._voice_pitch.has(id), "%s has its kind's own voice, at its kind's pitch" % id)
		_eq(g.item_data(id).get("product"), g.item_data(plain).get("product"), "%s gives what its kind gives" % id)
		_check(g.goals.matches("animal", id), "%s counts as an animal in goals and jobs" % id)
		# Bought with gems, it stands on the farm, eats, pays and sells as any animal does.
		g.gems = a.gem_cost()
		var coins := g.coins
		_check(g.buy_item(id) and g.place_somewhere(id), "%s is bought and stands on the farm" % id)
		_check(g.gems == 0 and g.coins == coins, "%s costs its gems and no coins" % id)
		var o: Dictionary = g.objects[-1]
		var uid := int(o["uid"])
		_eq(g.feeds.family_counts(o).keys(), g.feeds.family_counts({"id": plain, "uid": -1}).keys(),
			"%s eats what its kind eats" % id)
		_eq(g.sell_value(o), a.gem_cost() * per_gem, "%s sells for its gems' worth" % id)
		_skip(g, g.cycle_of(o))
		coins = g.coins
		g.collect(uid)
		_check(g.coins - coins >= int(g.item_data(id)["payout"]), "%s pays its own payout" % id)
		# Kept in the Barn, and from there into its kind's home, where it pays with the rest.
		_check(g.storage.store_object(uid), "%s is kept in the Barn" % id)
		var at := g.storage.stored.size() - 1
		_check(g.homes.put_in_home(int(home["uid"]), id, {"stored": at}), "%s moves into its kind's home" % id)
		_eq(int((home["inside"] as Dictionary).get(id, 0)), 1, "%s lives there" % id)
		_skip(g, g.cycle_of(home))
		coins = g.coins
		g.collect(int(home["uid"]))
		_check(g.coins > coins, "%s is collected from with its home" % id)
		home["inside"] = {}
	# Every limited baby is raised in the Nursery into its own limited animal.
	var nursery := _built(g, "nursery_barn")
	var raised := 0
	for id: String in g.item_order:
		if not g.limited.is_limited(id) or not (g.catalog.get_def(id) as AnimalDef).is_young():
			continue
		raised += 1
		var adult := g.specials.adult_of(id)
		var had := _arrived(g, adult)
		g.place_somewhere(id)
		_eq(g.homes.fill_building(int(nursery["uid"])), 1, "%s moves into the Nursery" % id)
		g.nurture.supplies["animal_feed"] = g.raising.need_each()
		_eq(g.raising.pour(int(nursery["uid"])), [g.name_of(adult)], "%s is raised into its own animal" % id)
		_eq(_arrived(g, adult) - had, 1, "and the %s arrives" % adult)
	_check(raised >= 20, "the limited babies are raised (%d)" % raised)
	# Nothing but its own ways brings one: a neighbour's mystery gift is never limited.
	var gifts := g.nurture._rare_free("animal")
	_check(not gifts.is_empty() and not gifts.any(func(k: String) -> bool: return g.limited.is_limited(k)),
		"a neighbour's mystery gift is never a limited animal")
	# Found by the word on its Market tab.
	_check(tr("LIMITED").to_lower() in str(ItemSearch.words_of("galaxy_cow")["more"]).to_lower()
		and not tr("LIMITED").to_lower() in str(ItemSearch.words_of("cow")["more"]).to_lower(),
		"search finds the limited animals by that word")
	_done(g)


func test_586_limited_animals_are_saved_wherever_they_are() -> void:
	var g := _farm()
	g.coins = 10000000
	g.farm_size = GameState.MAX_SIZE
	g.xp = g.xp_for_level(ShowcaseFarm.top_level(g))
	g.storage.barn().erase("broken")
	var shed := _built(g, "cow_shed")
	shed["inside"] = {"cow": 2, "galaxy_cow": 1}
	g.place_somewhere("rainbow_cow")
	g.place_somewhere("panda_calf")
	g.storage.store_object(int(g.objects[-1]["uid"]))
	g.mystery.egg_fates = {"rare": ["bubblegum_chicken"]}
	var at := [int(shed["row"]), int(shed["col"])]
	g.save_path = SAVE
	g.saving_enabled = true
	g.save_game()
	_done(g)
	var h := GameState.new()
	h.save_path = SAVE
	add_child(h)
	h.saving_enabled = false   # (the scratch file is removed below: not written again)
	_eq(h.object_at(h.index_of(at[0], at[1])).get("inside", {}), {"cow": 2, "galaxy_cow": 1}, "in a home")
	_eq(_count(h, "rainbow_cow"), 1, "on the farm")
	_eq(_arrived(h, "panda_calf"), 1, "in the Barn")
	_eq(h.mystery.egg_fates, {"rare": ["bubblegum_chicken"]}, "and waiting in an egg")
	h.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func test_587_a_release_without_them_sells_and_finds_none() -> void:
	var g := _farm()
	Release.whole = false
	_check(not Release.on(LimitedSystem.FEATURE) and not g.limited.on(), "the first release leaves them out")
	var shed := {"id": "cow_shed", "inside": {"cow": 4, "galaxy_cow": 2}}
	Balance.override("limited.rare_share", 1.0)
	Balance.override("limited.find_chance", 1.0)
	Balance.override("limited.rare_find_chance", 1.0)
	_check(not g.limited.rare_find(), "no find is rare")
	_eq(g.limited.found_at(shed, true), "", "none is limited, whatever lives in the home")
	_eq(g.limited.born_at(shed), "", "nor is a baby born there")
	_check(not HudMarket._for_sale("galaxy_cow"), "and the Market does not sell them")
	Balance.reload()
	Release.whole = true
	_check(g.limited.on() and HudMarket._for_sale("galaxy_cow"), "with everything on, they are there")
	_done(g)


## The home that takes animal `id` (not the Barn, which stores anything).
func _home_of(g: GameState, id: String) -> String:
	for home in g.catalog.homes_of(id):
		if id in g.item_data(home).get("holds", []):
			return home
	return ""


## Building `id` bought, placed on the first open ground that takes it and finished.
func _built(g: GameState, id: String) -> Dictionary:
	for r in g.farm_size:
		for c in g.farm_size:
			if g.can_place(id, r, c) and g.buy_and_place(id, r, c):
				var b := g.object_at(g.index_of(r, c))
				_all_materials(g, 30)
				g.land.add_materials(int(b["uid"]))
				_check(not g.under_construction(b), "%s is built" % id)
				return b
	_check(false, "%s finds room on the farm" % id)
	return {}
