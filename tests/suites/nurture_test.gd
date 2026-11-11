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
