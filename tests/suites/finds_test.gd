extends TestSuite
## FarmVille's random events: surprise drops, collectibles, fuel finds, bunches, mystery prizes.


func test_08_pity_guarantees_a_collectible_within_30_harvests() -> void:
	var g := _farm(true)
	g.coins = 100000
	var found := 0
	var i := _free(g)
	for k in HarvestDrops.COLLECTIBLE_PITY:
		var r := _grow_and_harvest(g, i, "strawberries")
		if r.get("drop", "") == "collectible":
			found += 1
	_check(found >= 1, "at least one collectible in %d harvests" % HarvestDrops.COLLECTIBLE_PITY)
	_done(g)






func test_09_collection_trade_in() -> void:
	var g := _farm()
	var coll: Dictionary = g.collectibles.collections[0]
	_check(not g.collectibles.can_trade_in(coll), "empty set can't be traded")
	var need := g.collectibles.coll_need(coll)
	_eq(need.values(), [3, 3, 3, 2, 1], "level 1: 3 of each common, 2 uncommon, 1 rare (FarmVille)")
	for id in need:
		g.collectibles.owned[id] = int(need[id]) + 1
	# Isolate the trade-in: no first-ribbon reward, and no level-up from its XP.
	g.ribbons.ribbon_tiers["collector"] = 4
	g.xp = g.xp_for_level(10)
	var coins := g.coins
	_check(g.collectibles.trade_in(coll["id"]), "full set trades in")
	_eq(g.coins, coins + 500, "level 1 pays 500 coins")
	_eq(int(g.collectibles.owned[coll["items"][0]["id"]]), 1, "the items it took are used up")
	_eq(g.collectibles.coll_level(coll), 1, "on to level 2")
	_eq(g.collectibles.coll_need(coll).values(), [6, 6, 6, 4, 2], "level 2: 6/4/2")
	g.collectibles.coll_levels[coll["id"]] = 2
	_eq(g.collectibles.coll_need(coll).values(), [12, 12, 12, 8, 4], "level 3: 12/8/4")
	_eq(int(g.collectibles.coll_reward(coll)["coins"]), 1500, "level 3 pays 1,500 coins")
	g.collectibles.coll_levels[coll["id"]] = 3
	_eq(g.collectibles.coll_level(coll), 0, "after level 3 it starts over")
	_done(g)






func test_74_lost_animals_wander_in_and_are_never_sold() -> void:
	var g := _farm()
	g.xp = g.xp_for_level(5)
	var lost: Array[String] = []
	for id in g.item_order:
		var d := g.catalog.get_def(id)
		if d is AnimalDef and (d as AnimalDef).is_lost():
			lost.append(id)
			_check(not d.in_market(), "%s isn't sold in the Market" % id)
	for id in [
		"brown_cow",
		"pink_cow",
		"black_sheep",
		"ugly_duckling",
		"wild_turkey",
		"gray_horse",
		"black_pony",
		"turtle"
	]:
		_check(lost.has(id), "%s is a lost animal, as in FarmVille" % id)
	var seen := {}
	for k in 400:
		if g.strays._spawn_stray():
			seen[g.objects[-1]["id"]] = true
			g.objects.pop_back()
			g.rebuild_occupancy()
	var lost_seen := 0
	for id in lost:
		if seen.has(id):
			lost_seen += 1
	_check(lost_seen >= lost.size() / 2.0, "most lost animals turn up over time (%d of %d)" % [lost_seen, lost.size()])
	_check(not seen.has("hereford_cow") and not seen.has("baby_turkey"), "gem animals never wander in")
	_done(g)






func test_75_breeds_have_their_own_babies() -> void:
	var g := _farm(true)
	_eq((g.catalog.get_def("hereford_cow") as AnimalDef).baby(), "hereford_calf", "a Hereford Cow has Hereford Calves")
	_check((g.catalog.get_def("hereford_calf") as AnimalDef).is_young(), "a calf is young")
	_eq(g.specials._pick_baby({"inside": {"cow": 4, "bull": 1}}, "calf"), "calf", "plain cows have plain calves")
	_eq(
		g.specials._pick_baby({"inside": {"hereford_cow": 3, "bull": 1}}, "calf"),
		"hereford_calf",
		"Herefords have Hereford calves"
	)
	_eq(
		g.specials._pick_baby({"inside": {"gray_horse": 2, "stallion": 1}}, "foal"),
		"gray_foal",
		"gray horses have gray foals"
	)
	var nursery := g.catalog.get_def("nursery_barn") as BuildingDef
	for baby in ["hereford_calf", "pink_calf", "gray_foal", "mustang_foal"]:
		_check(nursery.accepts(baby, "animal"), "the Nursery raises %s" % baby)
	_eq(nursery.data["grows_into"]["pink_calf"], "pink_cow", "a pink calf grows into a pink cow")
	# In a real Dairy Farm with a bull, calves follow the breeds inside.
	g.coins = 1000000
	g.xp = g.xp_for_level(6)
	g.buy_and_place("cow_shed", 8, 8)
	var dairy := g.object_at(g.index_of(8, 8))
	dairy["inside"] = {"jersey_cow": 4, "bull": 1}
	for d in 40:
		_skip(g, 86400)
		g.collect(int(dairy["uid"]))
	_check(_count(g, "jersey_calf") > 0, "Jersey calves were born (%d)" % _count(g, "jersey_calf"))
	_eq(_count(g, "calf"), 0, "and no plain calves")
	_done(g)






func test_76_baby_turkey_and_ugly_duckling_grow_up() -> void:
	var g := _farm()
	_check(g.place_somewhere("baby_turkey"), "a baby turkey on the farm")
	var t: Dictionary = g.objects[-1]
	_skip(g, 2 * 86400)
	var r := g.collect(int(t["uid"]))
	_eq(r.get("name", ""), "Baby Turkey", "it was collected as a baby")
	_eq(t["id"], "turkey", "and grew into a turkey after its first collection")
	_check(r["extras"].has("Grew up!"), "the collection says so")
	# Inside a home too.
	g.coins = 1000000
	g.xp = g.xp_for_level(6)
	g.buy_and_place("duck_pond", 8, 8)
	var pond := g.object_at(g.index_of(8, 8))
	pond.erase("construction")
	pond["inside"] = {"ugly_duckling": 2, "duck": 1}
	_skip(g, 2 * 86400)
	g.collect(int(pond["uid"]))
	_eq(int(pond["inside"].get("swan", 0)), 2, "ugly ducklings grew into swans")
	_check(not pond["inside"].has("ugly_duckling"), "no ducklings left")
	_done(g)






func test_77_mystery_box_and_cornish_eggs() -> void:
	var g := _farm()
	_check(not g.catalog.get_def("donkey").in_market(), "the Donkey only comes in a Mystery Box")
	_check(
		g.mystery.box_data["prizes"].any(func(p): return p[1] is String and p[1] == "donkey"),
		"the box can hold a Donkey"
	)
	g.gems = 0
	_eq(g.mystery.buy_mystery_box(), "", "no box without gems")
	var got := {}
	for k in 30:
		g.gems = MysterySystem.MYSTERY_BOX_GEM_COST
		var prize := g.mystery.buy_mystery_box()
		_check(prize != "", "a box opens into a prize")
		# Coins can finish a ribbon that pays gems, so only check boxes that gave neither.
		_check(
			g.gems == 0 or prize.ends_with("gems") or prize.ends_with("coins"),
			"a box costs %d gems (%s left %d)" % [MysterySystem.MYSTERY_BOX_GEM_COST, prize, g.gems]
		)
		got[prize] = true
	_check(got.size() >= 4, "boxes give different things (%d kinds)" % got.size())
	_eq(g.ribbons.stat("boxes_opened"), 30, "boxes are counted")
	# Cornish hens lay Cornish eggs.
	_check(g.mystery.egg_data["colours"].has("cornish"), "there is a Cornish Mystery Egg")
	_eq(g.item_data("cornish_chicken")["breed"], "cornish", "Cornish hens are their own breed")
	g.mystery.mystery_eggs["cornish"] = 3
	for k in 3:
		_check(g.mystery.open_mystery_egg("cornish") != "", "a Cornish egg opens")
	_done(g)






func test_78_every_new_item_has_a_home_and_art() -> void:
	var g := _farm()
	for id in g.item_order:
		var d := g.catalog.get_def(id)
		if d is AnimalDef:
			_check(not g.catalog.homes_of(id).is_empty(), "%s has a home" % id)
	_check(
		g.crops.has("forget_me_nots") and g.crops.has("saffron"),
		"every FarmVille market crop to level 90 is in the game"
	)
	_check(g.items.has("pistachio_tree") and g.items.has("date_tree"), "the extra fruit and nut trees are in the game")
	_eq(int(g.items["almond_tree"]["gem_cost"]), 3, "nut trees cost gems, as Farm Cash trees did in FarmVille")
	_done(g)






func test_84_collectibles_turn_up_on_every_action_and_rare_ones_are_rare() -> void:
	var g := _farm(true)
	for coll in g.collectibles.collections:
		var r: Array = coll["items"].map(func(it): return it["rarity"])
		_eq(r, ["common", "common", "common", "uncommon", "rare"], "%s: 3 common, 1 uncommon, 1 rare" % coll["id"])
		_eq((coll["rewards"] as Array).size(), 3, "%s has a prize per level" % coll["id"])
	_check(
		not g.collectibles.tree_collection.is_empty() and not g.collectibles.animal_collection.is_empty(),
		"sets for trees and for animals"
	)
	# Rarity: with nothing owned, commons come up most and the rare least.
	var coll: Dictionary = g.collectibles.collections[0]
	var seen := {"common": 0, "uncommon": 0, "rare": 0}
	for k in 3000:
		for it in coll["items"]:
			g.collectibles.owned[it["id"]] = 0
		var id := g.collectibles.pick_item(coll)
		for it in coll["items"]:
			if it["id"] == id:
				seen[it["rarity"]] += 1
	_check(
		seen["common"] > seen["uncommon"] and seen["uncommon"] > seen["rare"] and seen["rare"] > 0,
		"rarer items turn up less (%s)" % str(seen)
	)
	# Plowing, planting and fertilizing can all turn one up.
	g.coins = 1000000
	var finds := [0]
	g.found.connect(func(_i: int, text: String) -> void:
		if text.begins_with("Found:"):
			finds[0] += 1)
	for k in 300:
		var i := _free(g)
		g.field.plow(i)
		g.field.plant(i, "strawberries")
		g.field.fertilize(i)
		g.plots[i] = {"state": "grass"}
	_check(finds[0] > 0, "plowing, planting and fertilizing found %d collectibles in 300 rounds" % finds[0])
	_check(finds[0] < 60, "but not too many (%d)" % finds[0])
	_done(g)






func test_85_fuel_found_while_plowing_once_a_day() -> void:
	var g := _farm(true)
	g.coins = 1000000
	g.xp = g.xp_for_level(12)
	g.vehicles.fuel_unlocked = true
	g.vehicles.fuel = 0
	g.vehicles.fuel_t = g.now()
	g.vehicles.fuel_tanks = 0
	var fuel_finds := [0]
	g.found.connect(func(_i: int, text: String) -> void:
		if text.begins_with("Found fuel"):
			fuel_finds[0] += 1)
	for k in 200:
		var i := _free(g)
		g.field.plow(i)
		g.plots[i] = {"state": "grass"}
	_eq(fuel_finds[0], 1, "fuel turns up while plowing, but only once a day")
	_eq(g.vehicles.fuel_now(), int(VehicleSystem.FUEL_TANK * VehicleSystem.FUEL_FIND_SHARE), "a quarter of a tank")
	_skip(g, 86400)
	for k in 200:
		var i := _free(g)
		g.field.plow(i)
		g.plots[i] = {"state": "grass"}
	_eq(fuel_finds[0], 2, "and again the next day")
	var low := _farm(true)
	low.coins = 1000000
	var low_found := [0]
	low.found.connect(func(_i: int, text: String) -> void:
		if text.begins_with("Found fuel"):
			low_found[0] += 1)
	for k in 100:
		var i := _free(low)
		low.field.plow(i)
		low.plots[i] = {"state": "grass"}
	_eq(low_found[0], 0, "not before level %d" % VehicleSystem.FUEL_LEVEL)
	_done(g)






func test_86_bushels_come_with_one_extra_per_mastery_star() -> void:
	var g := _farm(true)
	_crafting_building(g)
	g.mastery.points["wheat"] = 100000
	var stars := g.mastery.stars("wheat")
	_check(stars >= 1, "wheat is mastered (%d stars)" % stars)
	var got := {}
	for k in 80:
		got = _grow_and_harvest(g, _open_plot(g), "wheat")
		if got.get("bushel", "") != "":
			break
	_eq(int(got.get("bushels", 0)), 1 + stars, "a bushel plus one per mastery star (FarmVille)")
	_eq(int(g.crafting.bushels["wheat"]), 1 + stars, "all of them kept")
	_done(g)






func test_87_perfect_bunches_and_the_garden_shed() -> void:
	var g := _farm(true)
	g.coins = 1000000
	g.xp = g.xp_for_level(15)
	g.objects = g.objects.filter(func(o): return g.kind_of(o) != "animal")
	g.rebuild_occupancy()
	var bunch := ""
	for k in 400:
		var r := _grow_and_harvest(g, _open_plot(g), "lilac")
		if r.get("bunch", "") != "":
			bunch = r["bunch"]
			break
	_eq(bunch, "lilac", "harvesting flowers gives a Perfect Bunch now and then")
	_eq(g.shed.bunches, ["lilac"], "kept")
	var wheat_bunch := false
	for k in 100:
		if _grow_and_harvest(g, _open_plot(g), "wheat").get("bunch", "") != "":
			wheat_bunch = true
	_check(not wheat_bunch, "only flowers give bunches")
	for k in 20:
		g.shed.add_bunch("lilac")
	_eq(g.shed.bunches.size(), GardenShedSystem.BUNCH_CAP_NO_SHED, "10 at most without a Garden Shed")
	g.coins = 29999
	_check(not g.can_afford_item("garden_shed"), "the shed costs 30,000 coins, as in FarmVille")
	g.coins = 1000000
	_check(g.buy_and_place("garden_shed", 8, 8), "Garden Shed built")
	_eq(g.shed.bunch_cap(), 100, "the shed holds 100")
	_eq(
		g.shed.bunches.size(),
		GardenShedSystem.BUNCH_CAP_NO_SHED + GardenShedSystem.SHED_FREE_BUNCHES,
		"and comes with 10 free bunches"
	)
	var at := g.shed.unpack_bunch(0)
	_check(at >= 0, "a bunch taken out to place")
	_check(g.storage.place_from_storage(at, 2, 8) or g.storage.place_from_storage(at, 3, 9), "placed on the farm")
	var placed: Array = g.objects.filter(func(o): return o["id"] == "perfect_bunch")
	_eq(placed.size(), 1, "one bunch on the farm")
	_eq(int(placed[0]["expires"]) - g.now(), BarnStorage.BUNCH_DAYS * 86400, "it lasts 14 days")
	_skip(g, 15 * 86400)
	g.strays.check_strays()
	_eq(g.objects.filter(func(o): return o["id"] == "perfect_bunch").size(), 0, "then wilts away")
	_done(g)


func test_132_finds_come_from_harvesting_by_weight_with_pity_and_a_collection_reward() -> void:
	var g := _farm(true)
	var fam: Dictionary = g.finds.families["gopher"]
	var pity := int(fam["trigger"]["pity"])
	for k in pity:
		g.finds.roll("harvest", 0)
	_check(g.finds.total("gopher") >= 1, "a gopher turns up within the pity count (%d rolls)" % pity)
	_eq(g.finds.tier("gopher"), 1, "owning one raises the family's home to level 1")
	var coins := g.coins
	for kind: Dictionary in fam["kinds"]:
		g.finds.add("gopher", kind)
	_check(g.finds.is_complete("gopher"), "every kind found completes the collection")
	_check(g.coins >= coins + int(fam["reward"]["coins"]), "and pays the reward (more if the XP levels you up)")
	var after := g.coins
	g.finds.add("gopher", fam["kinds"][0])
	_eq(g.coins, after, "never twice")
	var saved := {}
	g.finds.save_to(saved)
	var g2 := _farm(true)
	g2.finds.load_from(saved)
	_eq(g2.finds.total("gopher"), g.finds.total("gopher"), "finds survive a save")
	_eq(g2.finds.tier("gopher"), g.finds.tier("gopher"), "and so does the home's level")
	g.drops_enabled = false
	_eq(g.finds.roll("harvest", 0).size(), 0, "nothing is found when drops are off")
	_done(g)
	_done(g2)


func test_133_the_gopher_garden_needs_a_gopher_and_grows_with_the_finds() -> void:
	var g := _farm(true)
	g.coins = 1000000
	g.xp = 100000000
	_check(not g.can_afford_item("gopher_garden"), "it can't be bought before a gopher is found")
	var unmet := Requirements.first_unmet(g, "gopher_garden")
	_check(not unmet.is_empty() and str(unmet["text"]).contains("gopher"), "and says what is missing (%s)" % [unmet])
	var kinds: Array = g.finds.families["gopher"]["kinds"]
	g.finds.add("gopher", kinds[0])
	_check(Requirements.first_unmet(g, "gopher_garden").is_empty(), "one gopher meets the need")
	_check(g.buy_and_place("gopher_garden", 6, 6), "so it can be bought")
	var garden: Dictionary = g.objects.filter(func(o): return o["id"] == "gopher_garden")[0]
	_eq(g.level_of(garden), 1, "it starts small")
	for k in 3:
		g.finds.add("gopher", kinds[1])
	_eq(g.level_of(garden), 2, "four gophers grow it to the next size, by itself")
	for k in 40:
		g.finds.add("gopher", kinds[2])
	_eq(g.level_of(garden), g.max_level("gopher_garden"), "and it stops at its biggest size")
	_check(not g.can_afford_item("gopher_garden"), "only one is allowed per farm")
	_done(g)
