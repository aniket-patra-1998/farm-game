extends TestSuite
## Limited animals and trees in the rest of the game (docs/LIMITED.md): whatever a plain one of their kind does
## there, they do, with nothing of their own to keep in step. How the animals are sold and found is nurture_test's
## test_581, their Market tab hud_test's, their coats' touches world3d_test's; how a limited tree looks is
## trees_test's.

const SAVE := "user://test_limited_save.json"
const PAY_STEP := 5   # coins a limited tree's payout is rounded to (tools/make_limited.py)


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
		var young := g.catalog.get_def(id) as AnimalDef
		if young == null or not young.is_limited() or not young.is_young():
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
	# Owner, 20 Nov ("I don't see the limited banner and animals"): the first release has them, the varieties of
	# the plain kinds it lists; a release with the feature off has none.
	var g := _farm()
	Release.whole = false
	_check(Release.on(LimitedSystem.FEATURE) and g.limited.on(), "the first release has them")
	_check(HudMarket._for_sale("galaxy_cow") and Release.has("galaxy_cow"), "a Galaxy Cow, as it has the Cow")
	var features: Dictionary = Release._data["features"]
	features[LimitedSystem.FEATURE] = false
	var shed := {"id": "cow_shed", "inside": {"cow": 4, "galaxy_cow": 2}}
	Balance.override("limited.rare_share", 1.0)
	Balance.override("limited.find_chance", 1.0)
	Balance.override("limited.rare_find_chance", 1.0)
	_check(not Release.on(LimitedSystem.FEATURE) and not g.limited.on(), "a release with them off")
	_check(not g.limited.rare_find(), "no find is rare")
	_eq(g.limited.found_at(shed, true), "", "none is limited, whatever lives in the home")
	_eq(g.limited.born_at(shed), "", "nor is a baby born there")
	_check(not HudMarket._for_sale("galaxy_cow") and not Release.has("galaxy_cow"), "and the Market does not sell them")
	features[LimitedSystem.FEATURE] = true
	Balance.reload()
	Release.whole = true
	_check(g.limited.on() and HudMarket._for_sale("galaxy_cow"), "with everything on, they are there")
	_done(g)


func test_600_a_limited_tree_does_all_its_plain_tree_does() -> void:
	# Owner, 20 Nov: every tree comes in the varieties the animals do, and all is the same but that it is a tree.
	var g := _farm()
	g.born_day = g.day_number() + 100000   # (its buildings never wear here: wear_test tests wear)
	g.coins = 10000000
	g.farm_size = GameState.MAX_SIZE
	g.xp = g.xp_for_level(ShowcaseFarm.top_level(g))
	g.storage.barn().erase("broken")
	var orchard := _built(g, "orchard")
	var per_gem := Balance.i("market.sell_coins_per_gem")
	var pay := float(Varieties.data()["tree_pay"])
	var of_plain := {}   # a plain tree -> the varieties it comes in
	for id: String in g.item_order:
		var t := g.catalog.get_def(id) as TreeDef
		if t == null or not t.is_limited():
			continue
		var plain := t.limited_of()
		var p := g.catalog.get_def(plain) as TreeDef
		_check(p != null and not p.is_limited(), "%s is a variety of a plain tree" % id)
		_check(t.variety() in Varieties.of_trees(), "%s is one of the trees' varieties" % id)
		_eq(t.touch(), str(Varieties.of(t.variety())["touch"]), "%s has its variety's touch" % id)
		of_plain[plain] = int(of_plain.get(plain, 0)) + 1
		# Priced as a limited animal is: gems only, dearer the later its tree unlocks; it pays more than its tree.
		_eq(t.gem_cost(), _tree_gems(int(p.data["unlock_level"])), "%s costs its level's gems" % id)
		_check(t.coin_cost() == 0 and t.in_market(), "%s is sold for gems only" % id)
		var more := int(t.data["payout"]) - int(p.data["payout"]) * pay
		_check(absf(more) <= PAY_STEP * 0.5 and int(t.data["payout"]) % PAY_STEP == 0,
			"%s pays half as much again as its plain tree, in round coins" % id)
		_eq(g.item_data(id).get("product"), g.item_data(plain).get("product"), "%s gives what its tree gives" % id)
		_eq(g.cycle_of({"id": id}), g.cycle_of({"id": plain}), "%s ripens as its tree does" % id)
		_eq(TreeSpec.shape_of(g.item_data(id)), TreeSpec.shape_of(g.item_data(plain)), "%s has its tree's shape" % id)
		_check(g.goals.matches("tree", id), "%s counts as a tree in goals and jobs" % id)
		_eq(g.limited.plain_of(id, "orchard"), plain, "%s knows its plain tree" % id)
		_eq(g.limited.ordinary({"id": "orchard", "inside": {id: 2}}), {plain: 2},
			"an Orchard of %s alone finds its plain tree" % id)
		# Bought with gems, it stands on the farm, is harvested and sells as any tree does.
		g.gems = t.gem_cost()
		var coins := g.coins
		_check(g.buy_item(id) and g.place_somewhere(id), "%s is bought and stands on the farm" % id)
		_check(g.gems == 0 and g.coins == coins, "%s costs its gems and no coins" % id)
		var o: Dictionary = g.objects[-1]
		var uid := int(o["uid"])
		_eq(g.sell_value(o), t.gem_cost() * per_gem, "%s sells for its gems' worth" % id)
		_skip(g, g.cycle_of(o))
		coins = g.coins
		g.collect(uid)
		_check(g.coins - coins >= int(t.data["payout"]), "%s pays its own payout" % id)
		# Kept in the Barn, and from there into an Orchard, where it pays with the rest.
		_check(g.storage.store_object(uid), "%s is kept in the Barn" % id)
		var at := g.storage.stored.size() - 1
		_check(g.homes.put_in_home(int(orchard["uid"]), id, {"stored": at}), "%s moves into an Orchard" % id)
		_skip(g, g.cycle_of(orchard))
		coins = g.coins
		g.collect(int(orchard["uid"]))
		_check(g.coins > coins, "%s is harvested with its Orchard" % id)
		orchard["inside"] = {}
	var trees := 0
	for id: String in g.item_order:
		var t := g.catalog.get_def(id) as TreeDef
		if t == null or t.is_limited() or not t.in_market():
			continue
		trees += 1
		# (A tree that already has a Golden rare variety keeps that one: it comes in the other four.)
		var golden := g.items.has("golden_" + id) and not g.limited.is_limited("golden_" + id)
		_eq(int(of_plain.get(id, 0)), Varieties.of_trees().size() - (1 if golden else 0), "%s comes in every variety" % id)
	_check(trees >= 30, "every tree the Market sells has its varieties (%d trees)" % trees)
	_done(g)


func test_601_a_limited_tree_is_found_only_in_an_orchard_where_one_stands() -> void:
	var g := _farm(true)
	g.born_day = g.day_number() + 100000   # (its buildings never wear here: wear_test tests wear)
	g.coins = 10000000
	g.farm_size = GameState.MAX_SIZE
	g.xp = g.xp_for_level(ShowcaseFarm.top_level(g))
	g.storage.barn().erase("broken")
	var orchard := _built(g, "orchard")
	Balance.override("nurture.seedling_share", 1.0)   # (every harvest gives a seedling, to see what it is)
	Balance.override("limited.find_chance", 1.0)
	Balance.override("limited.rare_find_chance", 1.0)
	# Where none stands, no seedling is limited, plain or rare.
	orchard["inside"] = {"cherry_tree": 10}
	_harvest(g, orchard, 40)
	for o: Dictionary in _seedlings(g):
		_check(o["becomes"] in ["cherry_tree", "rainier_cherry_tree"], "no limited tree from an Orchard without one")
	_clear_seedlings(g)
	# Where one stands, a seedling may be it, and only it. By the owner's odds: 0.5% of seedlings, 5% of rare ones.
	orchard["inside"] = {"cherry_tree": 5, "galaxy_cherry_tree": 5}
	_harvest(g, orchard, 20)
	_check(_seedlings(g).size() == 20, "every harvest gave a seedling")
	for o: Dictionary in _seedlings(g):
		_eq(o["becomes"], "galaxy_cherry_tree", "a limited find is the limited tree standing there")
	_clear_seedlings(g)
	Balance.reload()
	_eq([Balance.f("limited.find_chance"), Balance.f("limited.rare_find_chance")], [0.005, 0.05], "the owner's odds")
	_eq(g.limited.ordinary(orchard), {"cherry_tree": 5}, "an ordinary seedling is drawn from the plain trees")
	# A Rare Mystery Seedling comes now and then in place of a Mystery Seedling, and is likelier a rare variety.
	Balance.override("nurture.seedling_share", 1.0)
	Balance.override("limited.find_chance", 0.0)
	Balance.override("limited.rare_find_chance", 0.0)
	orchard["inside"] = {"cherry_tree": 10}
	_harvest(g, orchard, 400)
	var plain := _young_all(g, NurtureSystem.SEEDLING)
	var rare := _young_all(g, NurtureSystem.RARE_SEEDLING)
	_eq(plain.size() + rare.size(), 400, "each harvest gave one or the other")
	_check(rare.size() > 15 and rare.size() < 80, "about 1 in 10 is a Rare Mystery Seedling (%d in 400)" % rare.size())
	var fine := rare.filter(func(o: Dictionary) -> bool: return o["becomes"] == "rainier_cherry_tree").size()
	var usual := plain.filter(func(o: Dictionary) -> bool: return o["becomes"] == "rainier_cherry_tree").size()
	_check(fine * plain.size() > usual * rare.size() * 2,
		"a Rare one is far likelier the rare variety (%d of %d against %d of %d)" % [fine, rare.size(), usual, plain.size()])
	_clear_seedlings(g)
	# Watered, a seedling grows into the tree it secretly is: a limited one too.
	_check(g.place_somewhere(NurtureSystem.RARE_SEEDLING), "a Rare Mystery Seedling is planted")
	var seedling: Dictionary = g.objects[-1]
	seedling["becomes"] = "galaxy_cherry_tree"
	g.nurture.supplies["watering_can"] = g.nurture.needs_of(NurtureSystem.RARE_SEEDLING)
	var grown := ""
	for k in g.nurture.needs_of(NurtureSystem.RARE_SEEDLING):
		grown = str(g.nurture.feed(int(seedling["uid"])).get("grown", ""))
	_check(grown != "" and _count(g, "galaxy_cherry_tree") == 1, "eight Watering Cans grow it into its limited tree")
	# A neighbour's seedling is never limited, and nothing else brings one.
	_check(not g.nurture._rare_free("tree").any(g.limited.is_limited), "a neighbour's gift is never a limited tree")
	Balance.reload()
	_done(g)


func test_602_limited_trees_are_saved_and_follow_the_release() -> void:
	var g := _farm()
	g.coins = 10000000
	g.farm_size = GameState.MAX_SIZE
	g.xp = g.xp_for_level(ShowcaseFarm.top_level(g))
	g.storage.barn().erase("broken")
	var orchard := _built(g, "orchard")
	orchard["inside"] = {"apple_tree": 2, "rainbow_apple_tree": 1}
	g.place_somewhere("sunset_lemon_tree")
	g.place_somewhere("golden_cherry_tree")
	g.storage.store_object(int(g.objects[-1]["uid"]))
	g.place_somewhere(NurtureSystem.RARE_SEEDLING)
	g.objects[-1]["becomes"] = "cotton_candy_peach_tree"
	var at := [int(orchard["row"]), int(orchard["col"])]
	g.save_path = SAVE
	g.saving_enabled = true
	g.save_game()
	_done(g)
	var h := GameState.new()
	h.save_path = SAVE
	add_child(h)
	h.saving_enabled = false   # (the scratch file is removed below: not written again)
	var kept: Dictionary = h.object_at(h.index_of(at[0], at[1])).get("inside", {})
	_eq(kept, {"apple_tree": 2, "rainbow_apple_tree": 1}, "in an Orchard")
	_eq(_count(h, "sunset_lemon_tree"), 1, "on the farm")
	_eq(_arrived(h, "golden_cherry_tree"), 1, "in the Barn")
	var waiting: Dictionary = _young_all(h, NurtureSystem.RARE_SEEDLING)[0]
	_eq(waiting.get("becomes"), "cotton_candy_peach_tree", "and waiting in a seedling")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	# The Limited shelf sells them after the animals, each kind under its own heading; the first release has them
	# when it has their plain tree (owner, 20 Nov).
	var market := HudMarket.new(null)
	var animals := market.limited_section("animal")
	var trees := market.limited_section("tree")
	_check(animals.size() >= 50 and trees.size() >= 150,
		"the Limited shelf has both (%d, %d)" % [animals.size(), trees.size()])
	_eq(animals.size() + trees.size(), market.shelf_items(HudMarket.LIMITED).size(), "and nothing else")
	_check(not "galaxy_apple_tree" in market.shelf_items("tree"), "a limited tree is not on the Trees shelf")
	_eq(market.tab_for("galaxy_apple_tree"), market.tab_for("galaxy_cow"), "it is found on the Limited tab")
	Release.whole = false
	_eq(HudMarket._for_sale("galaxy_apple_tree"), Release.has("apple_tree"),
		"the first release sells them with their tree")
	var features: Dictionary = Release._data["features"]
	features[LimitedSystem.FEATURE] = false
	_check(not HudMarket._for_sale("galaxy_apple_tree"), "a release with them off does not sell them")
	_eq(h.limited.found_at({"id": "orchard", "inside": {"galaxy_apple_tree": 3}}, true), "", "nor finds them")
	features[LimitedSystem.FEATURE] = true
	Release.whole = true
	h.queue_free()


## What a limited tree costs in gems when its plain tree unlocks at `level` (data/varieties.json `tree_gems`).
func _tree_gems(level: int) -> int:
	for tier: Array in Varieties.data()["tree_gems"]:
		if level <= int(tier[0]):
			return int(tier[1])
	return 0


func _harvest(g: GameState, orchard: Dictionary, times: int) -> void:
	for k in times:
		_skip(g, g.cycle_of(orchard))
		g.collect(int(orchard["uid"]))


## Every seedling found so far, Mystery or Rare.
func _seedlings(g: GameState) -> Array:
	return _young_all(g, NurtureSystem.SEEDLING) + _young_all(g, NurtureSystem.RARE_SEEDLING)


func _clear_seedlings(g: GameState) -> void:
	var other := func(o: Dictionary) -> bool:
		return not str(o.get("id", "")) in [NurtureSystem.SEEDLING, NurtureSystem.RARE_SEEDLING]
	g.storage.stored = g.storage.stored.filter(other)
	g.social.inbox.assign(g.social.inbox.filter(func(m: Dictionary) -> bool: return other.call(m["give"])))


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
