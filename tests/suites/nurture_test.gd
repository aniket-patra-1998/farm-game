extends TestSuite
## FarmVille's mystery young: seedlings and babies, raised on their supplies (NurtureSystem).


func test_120_a_mystery_young_grows_into_its_secret_on_the_last_supply() -> void:
	var g := _farm()
	g.farm_size = GameState.MAX_SIZE
	var p := g.player
	_check(g.nurture._found("mystery_seedling", "apple_tree"), "a seedling is found")
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
	g.nurture._found("mystery_baby", "cow")
	var baby: Dictionary = g.objects[-1]
	g.nurture.add_supply("animal_feed", 1)
	_eq(p.enqueue({"kind": "nurture", "uid": int(baby["uid"])}), PlayerSystem.Refused.NONE, "one feed queued")
	_eq(g.nurture.free_supply("animal_feed"), 0, "and promised")
	_check(p.cancel({"kind": "nurture", "uid": int(baby["uid"])}), "cancelled")
	_eq(g.nurture.free_supply("animal_feed"), 1, "and free again")
	# Supplies for gems; saved with the farm.
	g.gems = 10
	_check(g.nurture.buy_supply("animal_feed", 2), "feed bought with gems")
	_eq(g.gems, 10 - 2 * int(NurtureSystem.SUPPLIES["animal_feed"]["gem_cost"]), "at its price")
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
	for o in g.objects:
		if o["id"] == "mystery_baby":
			found += 1
			_eq(o["becomes"], "cow", "a baby of the home's grows into its adult")
	_check(found > 5 and found < 50, "babies now and then (%d in 300)" % found)
	_check(g.nurture.has_supply("animal_feed") > 30, "and feed (%d)" % g.nurture.has_supply("animal_feed"))
	# With no room on the farm, what's found waits in the Barn.
	var stored := g.storage.stored.size()
	g.farm_size = 0
	g.nurture._found("mystery_seedling", "apple_tree")
	_eq(g.storage.stored.size(), stored + 1, "no room: it's kept in the Barn")
	_eq(g.storage.stored[-1]["becomes"], "apple_tree", "still knowing what it'll be")
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
	_skip(g, g.cycle_of(rose) + BloomDef.WITHER_AFTER)
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
	_skip(g, g.cycle_of(rose) + BloomDef.WITHER_AFTER * 3)
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
	g.nurture._found("mystery_bulb", "lily_bloom")
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
	_skip(g, g.cycle_of(garden) + BloomDef.WITHER_AFTER * 2)
	var food := g.nurture.has_supply("flower_food")
	_check(not g.collect(int(garden["uid"])).is_empty(), "blooms in the garden never wither")
	_eq(g.nurture.has_supply("flower_food"), food + NurtureSystem.GARDEN_FOOD, "and its harvest gives Flower Food")
	_eq(g.mastery.points_of("iris_bloom"), 4, "Full Blooms inside count double toward mastery")
	# Blooms on the farm give bulbs now and then, Full Blooms twice as often.
	for k in 400:
		g.nurture.from_bloom({"id": "daisy_bloom"})
	var bulbs := g.objects.filter(func(o: Dictionary) -> bool: return o["id"] == "mystery_bulb").size()
	_check(bulbs > 5 and bulbs < 40, "bulbs now and then (%d in 400)" % bulbs)
	for o in g.objects:
		if o["id"] == "mystery_bulb":
			_check(g.catalog.get_def(o["becomes"]) is BloomDef and not (g.catalog.get_def(o["becomes"]) as BloomDef).is_full(),
				"a bulb grows into a Single Bloom")
	_done(g)
