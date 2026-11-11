extends TestSuite
## Placing, moving and rotating things, land expansion, and FarmVille's animal buildings.


func test_10_place_and_move_objects() -> void:
	var g := _farm()
	_check(g.buy_and_place("chicken", 8, 8), "buy a chicken")
	_eq(g.coins, GameState.START_COINS - 120, "chicken price")
	_check(not g.can_place("chicken", 8, 8), "can't stack on another object")
	_check(not g.can_place("chicken", 1, 1), "can't place on the farmhouse")
	_check(not g.can_place("chicken", 5, 4), "can't place on planted crops")
	_check(not g.can_place("chicken", 12, 0), "can't place off the farm")
	var uid := int(g.object_at(g.index_of(8, 8))["uid"])
	_check(g.move_object(uid, 11, 11), "move it")
	_check(g.object_at(g.index_of(8, 8)).is_empty(), "old tile is free")
	_eq(int(g.object_at(g.index_of(11, 11))["uid"]), uid, "new tile holds it")
	_check(not g.field.plow(g.index_of(11, 11)), "can't plow under an object")
	_done(g)






func test_11_shelter_fill_collect_upgrade() -> void:
	var g := _farm()
	g.coins = 100000
	_check(not g.buy_and_place("chicken_coop", 8, 8), "coop locked at level 1")
	g.add_xp(g.xp_for_level(4))
	_check(g.buy_and_place("chicken_coop", 8, 8), "buy coop at level 4")
	for c in 3:
		_check(g.buy_and_place("chicken", 11, c), "buy chicken %d" % c)
	var coop := g.object_at(g.index_of(8, 8))
	var uid := int(coop["uid"])
	_eq(g.homes.fill_building(uid), 5, "3 bought + 2 starter chickens move in")
	_eq(g.inside_total(coop), 5, "coop holds five")
	_eq(g.homes.loose_matching(coop), 0, "no loose chickens left")
	_check(g.collect(uid).is_empty(), "not ready straight away")
	_skip(g, 86400)
	_eq(g.collect(uid)["coins"], 200, "5 chickens x 40 coins")
	_check(not g.land.upgrade_building(uid), "can't expand without materials")
	for m in GameState.basic_parts:
		g.parts[m] = 10
	_check(g.land.upgrade_building(uid), "expand with 10 bricks, nails and boards")
	_eq(g.capacity(coop), 40, "Big Chicken Coop holds 40")
	_eq(g.size_name(coop), "Big Chicken Coop", "named like FarmVille")
	_eq(int(g.parts["bricks"]), 0, "materials used up")
	_done(g)






func test_12_expand_with_coins_needs_level_gems_do_not() -> void:
	var g := _farm()
	g.coins = 100000
	_check(not g.land.expand(false), "coins need level 5")
	g.gems = 20
	_check(g.land.expand(true), "gems expand at level 1")
	_eq(g.farm_size, 14, "farm grew to 14")
	_eq(g.gems, 10, "10 gems spent")
	_check(g.can_place("chicken", 13, 13), "new land is usable")
	_done(g)






func test_13_old_12x12_saves_migrate() -> void:
	var g := _farm()
	var old: Array = []
	for k in 144:
		old.append({"state": "grass"})
	old[5 * 12 + 7] = {"state": "plowed"}
	var wide := g._widen_old_grid(old)
	_eq(wide.size(), GameState.MAX_SIZE * GameState.MAX_SIZE, "widened size")
	_eq(wide[g.index_of(5, 7)]["state"], "plowed", "plot keeps its row and column")
	_done(g)






func test_38_stable_is_built_from_a_frame_with_materials() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(12)
	_check(g.buy_and_place("horse_stable", 8, 8), "stable frame placed")
	var st := g.object_at(g.index_of(8, 8))
	var uid := int(st["uid"])
	_check(g.under_construction(st), "it arrives as a frame")
	_check(not g.is_ready(st), "a frame never produces")
	g.place_somewhere("horse")
	_eq(g.homes.fill_building(uid), 0, "can't move horses into a frame")
	_eq(g.land.add_materials(uid), 0, "nothing to add with no materials")
	g.parts["bricks"] = 4
	_eq(g.land.add_materials(uid), 4, "adds the 4 bricks held")
	_eq(int(g.land.construction_needs(st)["bricks"]), 6, "6 bricks still missing")
	_all_materials(g, 10)
	g.land.add_materials(uid)
	_check(not g.under_construction(st), "finished once every material is in")
	_eq(int(g.parts["harnesses"]), 0, "harnesses used")
	_eq(int(g.parts["bricks"]), 4, "spare bricks kept (4 were already in)")
	_eq(g.homes.fill_building(uid), 1, "the horse moves in")
	_done(g)






func test_39_stable_horses_daily_stallion_brings_foals() -> void:
	var g := _farm(true)
	g.coins = 1000000
	g.xp = g.xp_for_level(12)
	g.buy_and_place("horse_stable", 8, 8)
	var st := g.object_at(g.index_of(8, 8))
	var uid := int(st["uid"])
	_all_materials(g, 10)
	g.land.add_materials(uid)
	for k in 4:
		g.place_somewhere("horse")
	_eq(g.cycle_of(g.objects.filter(func(o): return o["id"] == "horse")[0]), 3 * 86400, "a loose horse takes 3 days")
	_eq(g.cycle_of(st), 86400, "horses in the stable are ready daily")
	g.homes.fill_building(uid)
	# No stallion: no foals, ever.
	for d in 20:
		_skip(g, 86400)
		g.collect(uid)
	_eq(_count(g, "foal"), 0, "no stallion, no foals")
	# With a stallion: foals arrive, and he takes no space.
	g.place_somewhere("stallion")
	var inside_before := g.inside_total(st)
	g.homes.fill_building(uid)
	_check(g.has_inside(st, "stallion"), "stallion moved in")
	_eq(g.inside_total(st), inside_before, "the stallion doesn't take a space")
	g.place_somewhere("stallion")
	g.homes.fill_building(uid)
	_eq(int(st["inside"]["stallion"]), 1, "only one stallion lives inside")
	for d in 40:
		_skip(g, 86400)
		g.collect(uid)
	_check(_count(g, "foal") > 0, "foals were born (%d)" % _count(g, "foal"))
	_check(g.farmhands + g.arborists > 0, "harvests gave farmhands or arborists")
	_done(g)






func test_40_dairy_bull_brings_calves_and_fertilizer() -> void:
	var g := _farm(true)
	g.coins = 1000000
	g.xp = g.xp_for_level(6)
	_check(g.buy_and_place("cow_shed", 8, 8), "Dairy Farm bought outright, no frame")
	var dairy := g.object_at(g.index_of(8, 8))
	var uid := int(dairy["uid"])
	_check(not g.under_construction(dairy), "no construction needed")
	for k in 3:
		g.place_somewhere("cow")
	g.place_somewhere("bull")
	g.homes.fill_building(uid)
	_check(g.has_inside(dairy, "bull"), "the bull lives inside")
	_eq(g.inside_total(dairy), 4, "4 cows take spaces; the bull doesn't")
	for d in 40:
		_skip(g, 86400)
		g.collect(uid)
	_check(_count(g, "calf") > 0, "calves were born (%d)" % _count(g, "calf"))
	_check(g.fertilizer_bags > 0, "harvests left fertilizer")
	# A fertilizer bag is used before coins.
	var i := _free(g)
	if g.is_occupied(i):
		i = g.index_of(7, 4)
	if g.field.phase(i) != GameState.Phase.PLOWED:
		g.field.plow(i)
	g.field.plant(i, "strawberries")
	var coins := g.coins
	var bags := g.fertilizer_bags
	_check(g.field.fertilize(i), "fertilize")
	_eq(g.coins, coins, "no coins spent while a bag is held")
	_eq(g.fertilizer_bags, bags - 1, "a bag was used")
	_done(g)






func test_41_nursery_raises_babies_into_adults() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(8)
	_check(g.buy_and_place("nursery_barn", 8, 8), "nursery frame placed")
	var n := g.object_at(g.index_of(8, 8))
	var uid := int(n["uid"])
	_all_materials(g, 10)
	g.land.add_materials(uid)
	_check(not g.under_construction(n), "nursery finished")
	g.place_somewhere("calf")
	g.place_somewhere("foal")
	_eq(g.homes.fill_building(uid), 2, "a calf and a foal move in")
	var cows := _count(g, "cow")
	var horses := _count(g, "horse")
	for d in 3:
		_skip(g, 86400)
		g.collect(uid)
	_eq(_count(g, "cow"), cows, "not grown after 3 days")
	_skip(g, 86400)
	g.collect(uid)
	_eq(_count(g, "cow"), cows + 1, "the calf grew into a cow")
	_eq(_count(g, "horse"), horses + 1, "the foal grew into a horse")
	_eq(g.inside_total(n), 0, "the babies left the nursery")
	# Outside the nursery, babies never grow.
	g.place_somewhere("calf")
	for d in 10:
		_skip(g, 86400)
	_eq(_count(g, "calf"), 1, "a calf outside stays a calf")
	_done(g)






func test_42_coop_mystery_eggs_follow_breeds() -> void:
	var g := _farm(true)
	g.coins = 1000000
	g.xp = g.xp_for_level(4)
	g.buy_and_place("chicken_coop", 8, 8)
	var coop := g.object_at(g.index_of(8, 8))
	var uid := int(coop["uid"])
	coop["level"] = 3
	coop["inside"] = {"chicken": 40, "brown_chicken": 20}
	coop["t"] = g.now()
	for d in 40:
		_skip(g, 86400)
		g.collect(uid)
	var total := 0
	for colour in g.mystery.mystery_eggs:
		total += int(g.mystery.mystery_eggs[colour])
		_check(colour == "white" or colour == "brown", "egg colours match the breeds (got %s)" % colour)
	_check(total >= 4, "60 chickens find eggs regularly (%d in 40 days)" % total)
	var colour: String = "white" if int(g.mystery.mystery_eggs.get("white", 0)) > 0 else "brown"
	var before := int(g.mystery.mystery_eggs[colour])
	var prize := g.mystery.open_mystery_egg(colour)
	_check(prize != "", "opening an egg gives a prize (%s)" % prize)
	_eq(int(g.mystery.mystery_eggs[colour]), before - 1, "the egg is used up")
	_eq(g.mystery.open_mystery_egg("golden"), "", "can't open an egg you don't have")
	_done(g)






func test_43_expansions_cost_materials_and_follow_farmville_sizes() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(12)
	g.buy_and_place("horse_stable", 8, 8)
	var st := g.object_at(g.index_of(8, 8))
	var uid := int(st["uid"])
	_all_materials(g, 1000)
	g.land.add_materials(uid)
	var sizes: Array[int] = [g.capacity(st)]
	while g.land.upgrade_building(uid):
		sizes.append(g.capacity(st))
	_eq(sizes, [20, 25, 30, 35, 40] as Array[int], "stable grows 20 to 40 in steps of 5")
	_check(not g.land.can_expand(st), "no expansion past full size")
	_eq(g.cycle_of(st), 86400, "expanding doesn't change timing")
	_eq(g.building_def("chicken_coop").capacities(), [20, 40, 60] as Array[int], "Chicken Coop, Big, Huge: 20, 40, 60")
	_done(g)






func test_44_specific_materials_only_drop_for_buildings_you_own() -> void:
	var g := _farm()
	var pool := g.daily.wanted_parts()
	_check(not pool.has("harnesses"), "no harnesses before owning a stable")
	_check(not pool.has("bottles"), "no bottles before owning a nursery")
	g.coins = 1000000
	g.xp = g.xp_for_level(12)
	g.buy_and_place("horse_stable", 8, 8)
	pool = g.daily.wanted_parts()
	_check(pool.has("harnesses") and pool.has("horseshoes"), "stable materials drop once you own the frame")
	_check(not pool.has("smokers"), "beehive materials still don't")
	_done(g)






func test_45_gem_breeds_and_helpers() -> void:
	var g := _farm()
	g.xp = g.xp_for_level(5)
	var coins := g.coins
	g.gems = 5
	_check(g.buy_and_place("brown_chicken", 8, 8), "brown chicken bought with gems")
	_eq(g.gems, 0, "5 gems spent")
	_eq(g.coins, coins, "no coins spent")
	_check(not g.buy_and_place("brown_chicken", 8, 9), "no gems left for another")
	# A farmhand collects every ready animal at once.
	_skip(g, 86400)
	g.farmhands = 1
	var collected := g.use_helper("animal")
	_check(collected >= 4, "farmhand collected every animal (%d)" % collected)
	_eq(g.farmhands, 0, "farmhand used")
	for o in g.objects:
		if g.kind_of(o) == "animal":
			_check(not g.is_ready(o), "%s collected" % o["id"])
	_done(g)






func test_46_bull_and_stallion_only_wander_in_with_their_building() -> void:
	var g := _farm()
	g.xp = g.xp_for_level(20)
	var seen := {}
	for k in 300:
		if g.strays._spawn_stray():
			var s: Dictionary = g.objects[-1]
			seen[s["id"]] = true
			g.objects.pop_back()
			g.rebuild_occupancy()
	_check(not seen.has("bull") and not seen.has("stallion"), "no bull or stallion without their buildings")
	g.coins = 10000000
	g.buy_and_place("cow_shed", 8, 8)
	seen = {}
	for k in 300:
		if g.strays._spawn_stray():
			seen[g.objects[-1]["id"]] = true
			g.objects.pop_back()
			g.rebuild_occupancy()
	_check(seen.has("bull"), "a lonely bull can wander in once you own a Dairy Farm")
	_check(not seen.has("stallion"), "still no stallion without a stable")
	_done(g)


func test_92_animals_only_go_into_homes_made_for_them() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(15)
	g.farm_size = 24  # room for three buildings
	const FIT := HousingSystem.Fit
	_check(g.buy_and_place("cow_shed", 8, 8), "a Dairy Farm")
	_check(g.buy_and_place("chicken_coop", 8, 14), "a Chicken Coop")
	_check(g.buy_and_place("horse_stable", 14, 8), "a Horse Stable frame")
	var dairy := g.object_at(g.index_of(8, 8))
	var coop := g.object_at(g.index_of(8, 14))
	var stable := g.object_at(g.index_of(14, 8))
	# What fits where.
	_eq(g.homes.fit(dairy, "cow"), FIT.FITS, "a cow fits the Dairy Farm")
	_eq(g.homes.fit(coop, "cow"), FIT.WRONG_KIND, "a cow can't live in the Coop")
	_eq(g.homes.fit(coop, "turkey"), FIT.FITS, "the Coop takes turkeys as well as chickens")
	_eq(g.homes.fit(stable, "horse"), FIT.NOT_BUILT, "a frame takes no one yet")
	var cow_homes: Array = g.homes.homes_for("cow").map(func(pair: Array) -> String: return pair[0]["id"])
	_check(cow_homes.has("cow_shed") and not cow_homes.has("chicken_coop") and not cow_homes.has("horse_stable"),
		"only the Dairy Farm lights up for a cow (%s)" % [cow_homes])
	# A cow on the farm, dropped on the wrong home, stays put; on the right one, it moves in.
	_check(g.place_somewhere("cow"), "a cow on the farm")
	var cow_uid := int(g.objects[-1]["uid"])
	_check(not g.homes.put_in_home(int(coop["uid"]), "cow", {"uid": cow_uid}), "refused by the Coop")
	_check(not g.object_by_uid(cow_uid).is_empty(), "and still on the farm")
	var t0 := g.now()
	_skip(g, 100)
	_check(g.homes.put_in_home(int(dairy["uid"]), "cow", {"uid": cow_uid}), "the cow moves into the Dairy Farm")
	_check(g.object_by_uid(cow_uid).is_empty(), "off the farm")
	_eq(int(dairy["inside"]["cow"]), 1, "and inside")
	_eq(int(dairy["t"]), t0 + 100, "the first one in starts the building's cycle")
	# Bought straight into its home: paid for once, no spot on the farm needed.
	var coins := g.coins
	var objects := g.objects.size()
	_check(g.homes.put_in_home(int(coop["uid"]), "chicken", {"buy": true}), "a chicken bought straight into the Coop")
	_eq(g.coins, coins - int(g.item_data("chicken")["cost"]), "paid its price")
	_eq(g.objects.size(), objects, "nothing new standing on the farm")
	_eq(int(coop["inside"]["chicken"]), 1, "it's inside")
	# A bull is one-each: the second is turned away, without taking a space.
	_check(not g.homes.put_in_home(int(dairy["uid"]), "bull", {"buy": true}), "a bull can't be bought (it's won)")
	g.place_somewhere("bull")
	var bull := int(g.objects[-1]["uid"])
	g.place_somewhere("bull")
	var bull2 := int(g.objects[-1]["uid"])
	var spaces := g.inside_total(dairy)
	_check(g.homes.put_in_home(int(dairy["uid"]), "bull", {"uid": bull}), "a bull moves in")
	_eq(g.inside_total(dairy), spaces, "without taking a space")
	_eq(g.homes.fit(dairy, "bull"), FIT.HAS_ONE, "only one bull")
	_check(not g.homes.put_in_home(int(dairy["uid"]), "bull", {"uid": bull2}), "a second bull is refused")
	_check(not g.object_by_uid(bull2).is_empty(), "and stays on the farm")
	# A full home is lit amber and refuses more.
	dairy["inside"]["cow"] = g.capacity(dairy)
	_eq(g.homes.fit(dairy, "cow"), FIT.FULL, "a full Dairy Farm")
	_check(g.homes.homes_for("cow").has([dairy, FIT.FULL]), "still lit (amber) while full")
	# From the Barn into a home.
	g.storage.stored.append({"uid": 9999, "id": "turkey", "t": 0})
	var stored_n := g.storage.stored.size()
	_check(g.homes.put_in_home(int(coop["uid"]), "turkey", {"stored": stored_n - 1}),
		"a stored turkey moves into the Coop")
	_eq(g.storage.stored.size(), stored_n - 1, "out of the Barn")
	# The Barn takes anything already on the farm (once it's fixed), but sells nothing.
	var barn := {}
	for o in g.objects:
		if o["id"] == "barn":
			barn = o
	var flamingo: Dictionary = g.objects[-1] if g.place_somewhere("pink_flamingo") else {}
	if not barn.is_empty() and not flamingo.is_empty():
		_eq(g.homes.fit(barn, "chicken"), FIT.WRONG_KIND, "the Barn isn't a shop")
		if g.storage.barn_repaired():
			_check(g.homes.put_in_home(int(barn["uid"]), "pink_flamingo", {"uid": int(flamingo["uid"])}),
				"the Barn stores a decoration dropped on it")
		else:
			_eq(g.homes.fit(barn, "pink_flamingo", {"uid": int(flamingo["uid"])}), FIT.BARN_BROKEN, "a broken Barn")
	_done(g)


func test_93_vehicles_and_babies_through_the_drop() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(35)
	g.farm_size = 24
	const FIT := HousingSystem.Fit
	_check(g.buy_and_place("garage", 8, 8), "a Garage")
	var garage := g.object_at(g.index_of(8, 8))
	_all_materials(g, 100)
	if g.under_construction(garage):
		g.land.add_materials(int(garage["uid"]))
	_check(not g.under_construction(garage), "the Garage is built")
	# The first vehicle bought straight into the Garage still fills the fuel tank.
	_check(not g.vehicles.fuel_unlocked, "no fuel before any vehicle")
	_check(g.homes.put_in_home(int(garage["uid"]), "tractor", {"buy": true}), "a tractor bought into the Garage")
	_check(g.vehicles.fuel_unlocked and g.vehicles.fuel > 0, "buying it filled the fuel tank")
	# A Combine is built from its chassis on the farm: it can't skip that by going straight in.
	_eq(g.homes.fit(garage, "combine", {"buy": true}), FIT.BUILD_FIRST, "a Combine is built where it stands")
	var coins := g.coins
	_check(not g.homes.put_in_home(int(garage["uid"]), "combine", {"buy": true}), "refused")
	_eq(g.coins, coins, "and not charged")
	_check(g.buy_and_place("combine", 14, 14), "a Combine chassis on the farm")
	var chassis := g.object_at(g.index_of(14, 14))
	_eq(g.homes.fit(garage, "combine", {"uid": int(chassis["uid"])}), FIT.BUILD_FIRST,
		"an unfinished chassis isn't lit up as fitting")
	_check(not g.homes.put_in_home(int(garage["uid"]), "combine", {"uid": int(chassis["uid"])}),
		"but an unfinished chassis can't park")
	# A calf dropped in the Nursery Barn starts growing up.
	_check(g.buy_and_place("nursery_barn", 8, 14), "a Nursery Barn")
	var nursery := g.object_at(g.index_of(8, 14))
	g.land.add_materials(int(nursery["uid"]))
	_check(not g.under_construction(nursery), "the Nursery is built")
	g.place_somewhere("calf")
	var calf := int(g.objects[-1]["uid"])
	_check(g.homes.put_in_home(int(nursery["uid"]), "calf", {"uid": calf}), "the calf moves in")
	_eq((nursery.get("growing", []) as Array).size(), 1, "and starts growing up")
	_done(g)
