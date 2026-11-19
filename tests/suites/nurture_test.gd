extends TestSuite
## FarmVille's mystery young: seedlings and babies, raised on their supplies (NurtureSystem).


func test_120_a_mystery_young_grows_into_its_secret_on_the_last_supply() -> void:
	var g := _farm()
	g.farm_size = GameState.MAX_SIZE
	var p := g.player
	_check(_find_young(g, "mystery_seedling", "apple_tree"), "a seedling is found")
	var o: Dictionary = g.objects[-1]
	var uid := int(o["uid"])
	var at := Vector2i(int(o["row"]), int(o["col"]))
	_eq(p.enqueue({"kind": "nurture", "uid": uid}), PlayerSystem.Refused.SUPPLY, "nothing to give it yet")
	g.nurture.add_supply("watering_can", 10)
	var need := g.nurture.needs(o)
	_eq(need, 8, "FarmVille: 8 Watering Cans")
	for k in need - 1:
		_eq(p.enqueue({"kind": "nurture", "uid": uid}), PlayerSystem.Refused.NONE, "can %d queued" % (k + 1))
		p.advance(60.0)
	_eq(g.nurture.fed(o), need - 1, "watered once per job")
	_eq(g.object_by_uid(uid)["id"], "mystery_seedling", "still a seedling one can short")
	_eq(g.nurture.has_supply("watering_can"), 10 - (need - 1), "each can is used up")
	p.enqueue({"kind": "nurture", "uid": uid})
	p.advance(60.0)
	_check(g.object_by_uid(uid).is_empty(), "the seedling is gone")
	var grown := g.object_at(g.index_of(at.x, at.y))
	_eq(grown.get("id", ""), "apple_tree", "an apple tree stands where it grew")
	_eq(g.nurture.has_supply("watering_can"), 2, "8 cans in all")
	# Supplies promised to queued jobs aren't promised twice.
	_find_young(g, "mystery_baby", "cow")
	var baby: Dictionary = g.objects[-1]
	g.nurture.add_supply("animal_feed", 1)
	_eq(p.enqueue({"kind": "nurture", "uid": int(baby["uid"])}), PlayerSystem.Refused.NONE, "one feed queued")
	_eq(g.nurture.free_supply("animal_feed"), 0, "and promised")
	_check(p.cancel({"kind": "nurture", "uid": int(baby["uid"])}), "cancelled")
	_eq(g.nurture.free_supply("animal_feed"), 1, "and free again")
	# Supplies for gems; saved with the farm.
	g.gems = 10
	_check(g.nurture.buy_supply("animal_feed", 2), "feed bought with gems")
	_eq(g.gems, 10 - 2 * NurtureSystem.gem_cost("animal_feed"), "at its price")
	for s: String in NurtureSystem.SUPPLIES:
		_check(NurtureSystem.gem_cost(s) > 0, "%s has its gem price in data (nurture.supply_gems)" % s)
	_check(not g.nurture.buy_supply("animal_feed", 100), "not with gems you don't have")
	var data := {}
	g.nurture.save_to(data)
	g.nurture.reset()
	g.nurture.load_from(JSON.parse_string(JSON.stringify(data)))
	_eq(g.nurture.has_supply("animal_feed"), 3, "supplies are saved")
	_done(g)


func test_121_animal_homes_give_mystery_babies_of_their_kinds_and_feed() -> void:
	var g := _farm(true)
	g.coins = 1000000
	g.farm_size = GameState.MAX_SIZE
	g.xp = g.xp_for_level(ShowcaseFarm.top_level(g))
	_check(g.buy_and_place("cow_shed", 20, 20), "a dairy farm")
	var shed := g.object_at(g.index_of(20, 20))
	_all_materials(g, 8)
	g.land.add_materials(int(shed["uid"]))
	shed["inside"] = {"cow": 6, "calf": 2}
	var found := 0
	for k in 300:
		_skip(g, g.cycle_of(shed))
		g.collect(int(shed["uid"]))
	for o: Dictionary in _young_all(g, "mystery_baby"):
		found += 1
		_eq(o["becomes"], "cow", "a baby of the home's grows into its adult")
	_check(found > 5 and found < 50, "babies now and then (%d in 300)" % found)
	_check(g.nurture.has_supply("animal_feed") > 30, "and feed (%d)" % g.nurture.has_supply("animal_feed"))
	# What's found arrives in the Barn, never dropped on the farm.
	var kept := _young_all(g, "mystery_seedling").size()
	var on_farm := g.objects.size()
	g.nurture._found("mystery_seedling", "apple_tree")
	_eq(_young_all(g, "mystery_seedling").size(), kept + 1, "it's kept in the Barn (or the inbox)")
	_eq(g.objects.size(), on_farm, "not on the farm")
	_eq(_young_all(g, "mystery_seedling")[-1]["becomes"], "apple_tree", "still knowing what it'll be")
	_done(g)


func test_122_blooms_wither_regrow_upgrade_and_share_mastery() -> void:
	# FarmVille's Blooms: a Single Bloom left ready for 7 days withers (Flower Food regrows it); a Full Bloom,
	# upgraded with Farm Cash (gems), never withers and counts double toward the flower's one mastery.
	var g := _farm()
	g.farm_size = GameState.MAX_SIZE
	g.coins = 100000
	g.xp = g.xp_for_level(ShowcaseFarm.top_level(g))
	var p := g.player
	_check(g.buy_and_place("rose_bloom", 20, 20), "a Single Rose Bloom")
	var rose := g.object_at(g.index_of(20, 20))
	var uid := int(rose["uid"])
	_check(not g.is_ready(rose), "growing at first")
	_skip(g, g.cycle_of(rose))
	_check(g.is_ready(rose) and not g.is_withered(rose), "ready after its cycle")
	var got := g.collect(uid)
	_check(int(got.get("coins", 0)) > 0, "harvested for coins")
	_eq(g.mastery.points_of("rose_bloom"), 1, "one mastery point")
	_skip(g, g.cycle_of(rose) + Balance.i("blooms.wither_after"))
	_check(g.is_withered(rose) and not g.is_ready(rose), "left ready 7 days: withered")
	_check(g.collect(uid).is_empty(), "a withered bloom can't be harvested")
	_eq(p.enqueue({"kind": "nurture", "uid": uid}), PlayerSystem.Refused.SUPPLY, "no Flower Food to regrow it")
	g.nurture.add_supply("flower_food", 1)
	_eq(p.enqueue({"kind": "nurture", "uid": uid}), PlayerSystem.Refused.NONE, "the farmer goes to regrow it")
	p.advance(60.0)
	_check(not g.is_withered(rose) and not g.is_ready(rose), "regrown: growing again")
	_eq(g.nurture.has_supply("flower_food"), 0, "with one Flower Food")
	# Upgraded with gems to a Full Bloom: never withers, counts double.
	g.gems = 100
	_check(g.nurture.upgrade_bloom(uid), "upgraded")
	_eq(g.object_by_uid(uid)["id"], "rose_full_bloom", "to its Full Bloom")
	_eq(g.gems, 100 - int(g.item_data("rose_bloom")["upgrade_gems"]), "for its gems")
	_check(not g.nurture.upgrade_bloom(uid), "a Full Bloom can't be upgraded again")
	_skip(g, g.cycle_of(rose) + Balance.i("blooms.wither_after") * 3)
	_check(g.is_ready(rose) and not g.is_withered(rose), "a Full Bloom never withers")
	g.collect(uid)
	_eq(g.mastery.points_of("rose_bloom"), 3, "and counts double toward the rose's shared mastery")
	# A Gardener harvests every ready bloom at once.
	g.buy_and_place("tulip_bloom", 22, 22)
	_skip(g, g.cycle_of(rose))
	g.gardeners = 1
	_eq(g.use_helper("bloom"), 2, "a Gardener harvests both blooms")
	_eq(g.gardeners, 0, "and is used up")
	_done(g)


func test_123_mystery_bulbs_and_the_bloom_garden() -> void:
	var g := _farm(true)
	g.farm_size = GameState.MAX_SIZE
	g.coins = 100000
	g.xp = g.xp_for_level(ShowcaseFarm.top_level(g))
	# A Mystery Bulb: 5 Flower Food grow it into a Single Bloom.
	_find_young(g, "mystery_bulb", "lily_bloom")
	var bulb: Dictionary = g.objects[-1]
	_eq(g.nurture.needs(bulb), 5, "FarmVille: about 5 Flower Food")
	g.nurture.add_supply("flower_food", 5)
	for k in 5:
		g.player.enqueue({"kind": "nurture", "uid": int(bulb["uid"])})
		g.player.advance(60.0)
	_eq(g.object_at(g.index_of(int(bulb["row"]), int(bulb["col"]))).get("id", ""), "lily_bloom",
		"a lily grows where the bulb was")
	# The Bloom Garden: built with its own materials; blooms in it never wither; harvests give Flower Food.
	_check(g.buy_and_place("bloom_garden", 14, 14), "a Bloom Garden")
	var garden := g.object_at(g.index_of(14, 14))
	for m in ["flower_ties", "garden_edging", "trellises"]:
		_check(g.item_data("bloom_garden")["build_materials"].has(m), "built with %s" % m)
	_all_materials(g, 10)
	g.land.add_materials(int(garden["uid"]))
	_check(not g.under_construction(garden), "and finished")
	_eq(g.capacity(garden), 20, "holds 20 blooms")
	_check(g.building_accepts(garden, "rose_full_bloom") and not g.building_accepts(garden, "apple_tree"),
		"blooms only")
	garden["inside"] = {"rose_bloom": 10, "iris_full_bloom": 2}
	_skip(g, g.cycle_of(garden) + Balance.i("blooms.wither_after") * 2)
	var food := g.nurture.has_supply("flower_food")
	_check(not g.collect(int(garden["uid"])).is_empty(), "blooms in the garden never wither")
	_eq(g.nurture.has_supply("flower_food"), food + Balance.i("nurture.garden_food"), "and its harvest gives Flower Food")
	_eq(g.mastery.points_of("iris_bloom"), 4, "Full Blooms inside count double toward mastery")
	# Blooms on the farm give bulbs now and then, Full Blooms twice as often.
	for k in 400:
		g.nurture.from_bloom({"id": "daisy_bloom"})
	var bulbs := _young_all(g, "mystery_bulb").size()
	_check(bulbs > 5 and bulbs < 40, "bulbs now and then (%d in 400)" % bulbs)
	for o: Dictionary in _young_all(g, "mystery_bulb"):
		_check(g.catalog.get_def(o["becomes"]) is BloomDef and not (g.catalog.get_def(o["becomes"]) as BloomDef).is_full(),
			"a bulb grows into a Single Bloom")
	_done(g)


## How many of `id` have arrived (the Barn, or the inbox when it was full).
func _arrived(g: GameState, id: String) -> int:
	var n := 0
	for o: Dictionary in g.storage.stored:
		n += 1 if str(o["id"]) == id else 0
	for m: Dictionary in g.social.inbox:
		n += 1 if str((m["give"] as Dictionary).get("id", "")) == id else 0
	return n


## Limited animals (the unique coats): sold in the Market for gems only; and a home's finds (a Mystery Baby, a
## Mystery Egg, a birth) turn out to be one only where one already lives, 0.5% of the time, 5% for a rare find.
func test_581_limited_animals_are_sold_for_gems_and_found_only_where_one_lives() -> void:
	var g := _farm(true)
	var adults := 0
	for id: String in g.item_order:
		var a := g.catalog.get_def(id) as AnimalDef
		if a == null or not a.is_limited():
			continue
		if a.is_young():
			_check(g.limited.is_limited(g.specials.adult_of(id)), "%s is raised into its limited animal" % id)
			continue
		adults += 1
		_check(a.gem_cost() > 0 and a.coin_cost() == 0 and a.in_market(), "%s is sold for gems only" % id)
		_check(not g.catalog.homes_of(id).is_empty(), "%s has a home" % id)
	_check(adults >= 50, "the limited animals are in the catalog (%d)" % adults)
	g.coins = 1000000
	g.farm_size = GameState.MAX_SIZE
	g.xp = g.xp_for_level(ShowcaseFarm.top_level(g))
	g.gems = 0
	_check(not g.can_afford_item("galaxy_cow"), "coins don't buy one")
	g.gems = g.catalog.get_def("galaxy_cow").gem_cost()
	_check(g.can_afford_item("galaxy_cow"), "its gems do")
	_check(g.buy_and_place("cow_shed", 20, 20), "a dairy farm")
	var shed := g.object_at(g.index_of(20, 20))
	_all_materials(g, 8)
	g.land.add_materials(int(shed["uid"]))
	# Where none lives, nothing found is limited, however rare the find.
	shed["inside"] = {"cow": 6}
	var came := 0
	for k in 2000:
		came += 1 if g.limited.found_at(shed, true) != "" else 0
	_eq(came, 0, "no limited animal from a home that has none")
	# Where one lives: 0.5% of ordinary finds, 5% of rare ones, and always one that lives there.
	shed["inside"] = {"cow": 6, "galaxy_cow": 1}
	g.rng.seed = 7
	var plain := 0
	var rare := 0
	for k in 20000:
		var one := g.limited.found_at(shed, false)
		plain += 1 if one != "" else 0
		_check(one in ["", "galaxy_cow"], "it is one that lives there")
		rare += 1 if g.limited.found_at(shed, true) != "" else 0
	_check(plain > 60 and plain < 150, "an ordinary find is limited 0.5%% of the time (%d in 20000)" % plain)
	_check(rare > 850 and rare < 1150, "a rare find 5%% of the time (%d in 20000)" % rare)
	# Ordinary finds and births are drawn from the home's other animals, never its limited ones.
	_eq(g.limited.ordinary(shed), {"cow": 6}, "ordinary finds leave the limited ones out")
	_eq(g.limited.ordinary({"id": "cow_shed", "inside": {"galaxy_cow": 3}}), {"cow": 3},
		"a home of limited animals only still gives their plain kind")
	# A rare baby, and a limited one in it when the chance comes up.
	Balance.override("nurture.mystery_baby_chance", 1.0)
	Balance.override("limited.rare_share", 1.0)
	Balance.override("limited.rare_find_chance", 1.0)
	_skip(g, g.cycle_of(shed))
	g.collect(int(shed["uid"]))
	var babies := _young_all(g, NurtureSystem.RARE_BABY)
	_eq(babies.size(), 1, "a Rare Mystery Baby is found")
	_eq(str(babies[0]["becomes"]) if babies.size() == 1 else "", "galaxy_cow", "and it is the home's limited animal")
	Balance.override("limited.rare_share", 0.0)
	Balance.override("limited.find_chance", 0.0)
	_skip(g, g.cycle_of(shed))
	g.collect(int(shed["uid"]))
	var ordinary := _young_all(g, NurtureSystem.BABY)
	_eq(ordinary.size(), 1, "an ordinary Mystery Baby next")
	_eq(str(ordinary[0]["becomes"]) if ordinary.size() == 1 else "", "cow", "of the home's plain kind")
	# A birth: the limited animal's own baby when the chance comes up, and the Nursery raises it into the animal.
	Balance.override("nurture.mystery_baby_chance", 0.0)
	Balance.override("specials.calf_chance", 1.0)
	Balance.override("limited.find_chance", 1.0)
	shed["inside"] = {"cow": 6, "galaxy_cow": 1, "bull": 1}
	_skip(g, 2 * 86400)   # (a calf a day at most)
	g.collect(int(shed["uid"]))
	_eq(_arrived(g, "galaxy_calf"), 1, "a limited calf is born")
	_eq(g.specials.adult_of("galaxy_calf"), "galaxy_cow", "which grows into the limited cow")
	Balance.override("limited.find_chance", 0.0)
	var calves := _arrived(g, "calf")
	_skip(g, 2 * 86400)
	g.collect(int(shed["uid"]))
	_eq(_arrived(g, "calf"), calves + 1, "and otherwise a plain calf, never the limited one's")
	# An egg: a rare one, with the Coop's limited bird in it, shown when it is opened.
	Balance.override("limited.rare_share", 1.0)
	var coop := {"id": "chicken_coop", "uid": 9001, "inside": {"chicken": 10, "silkie_chicken": 1}}
	var odds := [g.mystery.egg_data["chance_per_chicken"], g.mystery.egg_data["max_chance"]]
	g.mystery.egg_data["chance_per_chicken"] = 1.0
	g.mystery.egg_data["max_chance"] = 1.0
	_eq(g.mystery.find_egg(coop), MysterySystem.RARE_EGG, "a Rare Mystery Egg is found")
	g.mystery.egg_data["chance_per_chicken"] = odds[0]
	g.mystery.egg_data["max_chance"] = odds[1]
	_eq(g.mystery.egg_fates.get(MysterySystem.RARE_EGG, []), ["silkie_chicken"], "with the limited bird in it")
	var kept := {}
	g.mystery.save_to(kept)
	g.mystery.load_from(kept)
	_eq(g.mystery.egg_fates.get(MysterySystem.RARE_EGG, []), ["silkie_chicken"], "kept through a save")
	_check(g.mystery.open_mystery_egg(MysterySystem.RARE_EGG) != "", "it opens")
	_eq(g.mystery.last_rarity, "legendary", "as the rarest prize")
	_eq(_arrived(g, "silkie_chicken"), 1, "and the limited bird arrives")
	_check(g.mystery.egg_fates.is_empty(), "once")
	Balance.reload()
	_done(g)

