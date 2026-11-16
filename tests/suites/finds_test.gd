extends TestSuite
## FarmVille's random events: surprise drops, collectibles, fuel finds, bunches, mystery prizes.


func test_08_pity_guarantees_a_collectible_within_30_harvests() -> void:
	var g := _farm(true)
	g.coins = 100000
	var found := 0
	var i := _free(g)
	for k in Balance.i("harvest.collectible_pity"):
		var r := _grow_and_harvest(g, i, "strawberries")
		if r.get("drop", "") == "collectible":
			found += 1
	_check(found >= 1, "at least one collectible in %d harvests" % Balance.i("harvest.collectible_pity"))
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
		g.gems = Balance.i("mystery.mystery_box_gem_cost")
		var prize := g.mystery.buy_mystery_box()
		_check(prize != "", "a box opens into a prize")
		# Coins can finish a ribbon that pays gems, so only check boxes that gave neither.
		_check(
			g.gems == 0 or prize.ends_with("gems") or prize.ends_with("coins"),
			"a box costs %d gems (%s left %d)" % [Balance.i("mystery.mystery_box_gem_cost"), prize, g.gems]
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
	g.found.connect(func(_i: int, text: String, _rarity: String) -> void:
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
	g.found.connect(func(_i: int, text: String, _rarity: String) -> void:
		if text.begins_with("Found fuel"):
			fuel_finds[0] += 1)
	for k in 200:
		var i := _free(g)
		g.field.plow(i)
		g.plots[i] = {"state": "grass"}
	_eq(fuel_finds[0], 1, "fuel turns up while plowing, but only once a day")
	_eq(
		g.vehicles.fuel_now(),
		int(Balance.i("vehicles.fuel_tank") * Balance.f("vehicles.fuel_find_share")),
		"a quarter of a tank"
	)
	_skip(g, 86400)
	for k in 200:
		var i := _free(g)
		g.field.plow(i)
		g.plots[i] = {"state": "grass"}
	_eq(fuel_finds[0], 2, "and again the next day")
	var low := _farm(true)
	low.coins = 1000000
	var low_found := [0]
	low.found.connect(func(_i: int, text: String, _rarity: String) -> void:
		if text.begins_with("Found fuel"):
			low_found[0] += 1)
	for k in 100:
		var i := _free(low)
		low.field.plow(i)
		low.plots[i] = {"state": "grass"}
	_eq(low_found[0], 0, "not before level %d" % Balance.i("vehicles.fuel_level"))
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
	_eq(g.shed.bunches.size(), Balance.i("shed.bunch_cap_no_shed"), "10 at most without a Garden Shed")
	g.coins = 29999
	_check(not g.can_afford_item("garden_shed"), "the shed costs 30,000 coins, as in FarmVille")
	g.coins = 1000000
	_check(g.buy_and_place("garden_shed", 8, 8), "Garden Shed built")
	_eq(g.shed.bunch_cap(), 100, "the shed holds 100")
	_eq(
		g.shed.bunches.size(),
		Balance.i("shed.bunch_cap_no_shed") + Balance.i("shed.shed_free_bunches"),
		"and comes with 10 free bunches"
	)
	var at := g.shed.unpack_bunch(0)
	_check(at >= 0, "a bunch taken out to place")
	_check(g.storage.place_from_storage(at, 2, 8) or g.storage.place_from_storage(at, 3, 9), "placed on the farm")
	var placed: Array = g.objects.filter(func(o): return o["id"] == "perfect_bunch")
	_eq(placed.size(), 1, "one bunch on the farm")
	_eq(int(placed[0]["expires"]) - g.now(), Balance.i("barn.bunch_days") * 86400, "it lasts 14 days")
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


func test_182_dogs_are_a_find_family_with_a_home_and_a_helping_share() -> void:
	var g := _farm()
	_check(g.finds.families.has("dog"), "dogs are a family")
	var fam: Dictionary = g.finds.families["dog"]
	for target: String in fam["helps"]:
		_check(g.finds.families.has(target), "dogs help a real family (%s)" % target)
	_eq(g.finds.help_for("gopher"), 0.0, "no dogs, no help")
	_check(not g.can_afford_item("dog_house"), "the Dog House needs a dog")
	g.finds.add("dog", fam["kinds"][0])
	_check(Requirements.first_unmet(g, "dog_house").is_empty(), "one dog meets the need")
	_check(absf(g.finds.help_for("gopher") - 0.03) < 0.0001, "one dog adds its share to gopher finds")
	for k in 40:
		g.finds.add("dog", fam["kinds"][0])
	_check(absf(g.finds.help_for("gopher") - float(fam["help_cap"])) < 0.0001, "and stops at the cap")
	_eq(g.finds.help_for("dog"), 0.0, "dogs don't help themselves")


func test_183_a_dog_house_grows_with_the_dogs_and_dogs_raise_the_gopher_chance() -> void:
	var g := _farm()
	g.coins = 10000000
	g.xp = g.xp_for_level(30)
	g.set_objects([])
	var kinds: Array = g.finds.families["dog"]["kinds"]
	g.finds.add("dog", kinds[0])
	_check(g.buy_and_place("dog_house", 6, 6), "the Dog House is bought")
	var house: Dictionary = g.objects.filter(func(o): return o["id"] == "dog_house")[0]
	for k in 3:
		g.finds.add("dog", kinds[1])
	_eq(g.level_of(house), 2, "four dogs grow it to the next size")
	# More dogs, more gophers: the same dice find more.
	g.finds.pity["gopher"] = 0
	var base := 0
	var helped := 0
	g.drops_enabled = true
	for run in 2:
		g.rng.seed = 7
		var found := 0
		for i in 4000:
			g.finds.owned = {} if run == 0 else {"indie_dog": 20}   # the dice find dogs too: keep the count fixed
			g.finds.pity["gopher"] = 0
			g.finds.pity["dog"] = 0
			for f in g.finds.roll("harvest"):
				found += 1 if f["family"] == "gopher" else 0
		if run == 0:
			base = found
		else:
			helped = found
	_check(helped > base, "20 dogs find more gophers than none (%d vs %d)" % [helped, base])


func test_184_a_queen_bee_is_a_find_that_only_rolls_when_one_would_be_of_use() -> void:
	var g := _farm()
	g.drops_enabled = true
	g.set_objects([])
	g.bees.queen_bees = 0
	_check(g.bees.queen_wanted(), "no hive yet: a queen would be of use")
	g.rng.seed = 3
	var got := 0
	for i in 3000:
		g.bees.queen_bees = 0
		got += g.finds.roll("flower_harvest").size()
	_check(got > 5 and got < 60, "queens are rare finds (%d in 3000 flower harvests)" % got)
	g.bees.queen_bees = 1
	_check(not g.bees.queen_wanted(), "holding one, another is of no use")
	_eq(g.finds.roll("flower_harvest").size(), 0, "so none is rolled")
	g.bees.queen_bees = 0
	g.finds.pity["queen_bee"] = int(g.finds.families["queen_bee"]["trigger"]["pity"]) - 1
	_eq(g.finds.roll("flower_harvest").size(), 1, "the pity count guarantees one")
	_eq(g.bees.queen_bees, 1, "she goes to the Barn for a hive")
	_eq(g.finds.count("queen_bee") > 0, true, "and is counted as a find")
	_check(not g.finds.claimed.get("queen_bee", false), "with no collection prize to claim")


## What a harvest will turn up is decided when the crop is planted and kept with its plot, so the plot can glint
## before the harvest; the harvest gives it and rolls nothing again. A plot from before luck was held (an old
## save) is rolled at its harvest as it always was.
func test_364_a_plot_holds_its_luck_from_planting() -> void:
	var g := _farm(true)
	g.coins = 100000
	g.xp = g.xp_for_level(20)
	var said: Array = []
	g.found.connect(func(i: int, text: String, rarity: String) -> void: said.append([i, text, rarity]))
	var a := _free(g)
	g.field.plow(a)
	g.drops.pity["golden"] = Balance.i("harvest.golden_pity")   # the next crop planted is golden for sure
	g.field.plant(a, "wheat")
	var held: Dictionary = g.plots[a].get("held", {})
	_eq(str(held.get("drop", {}).get("type", "")), "golden", "the golden harvest is decided at planting")
	_eq(int(g.drops.pity["golden"]), 0, "and the luck is spent then")
	_eq(g.field.held_rarity(a), "legendary", "the plot holds something legendary")
	_skip(g, int(g.crops["wheat"]["grow_seconds"]) + 5)
	_eq(g.field.held_rarity(a), "legendary", "still, when ripe")
	said.clear()
	var got := g.field.harvest(a)
	_eq(str(got["drop"]), "golden", "the harvest gives what the plot held")
	_eq(int(g.drops.pity["golden"]), 0, "and rolls nothing again")
	_check(said.any(func(f: Array) -> bool: return f[0] == a and f[2] == "legendary"), "said on the plot as legendary")
	_check(not g.plots[a].has("held"), "the plot holds nothing after")
	# A creature: decided at planting, owned only at the harvest.
	var family: String = g.finds.families.keys()[0]
	var need := int(g.finds.families[family]["trigger"]["pity"])
	g.finds.pity[family] = need
	g.field.plant(a, "wheat")
	var finds: Array = g.plots[a].get("held", {}).get("finds", [])
	_check(finds.any(func(f: Array) -> bool: return f[0] == family), "a %s is in the plot" % family)
	_eq(g.finds.total(family), 0, "not owned yet")
	_check(g.field.held_rarity(a) != "", "and the plot glints for it")
	_skip(g, int(g.crops["wheat"]["grow_seconds"]) + 5)
	said.clear()
	g.field.harvest(a)
	_eq(g.finds.total(family), 1, "owned at the harvest")
	_check(said.size() >= 1, "and said on the plot (%s)" % [said])
	# A small bonus is held too, but does not glint; a plot with nothing held does not either.
	g.field.plant(a, "wheat")
	g.plots[a]["held"] = {"drop": {"type": "bonus_xp"}}
	_eq(g.field.held_rarity(a), "", "a small bonus stays a surprise")
	g.plots[a]["held"] = {}
	_eq(g.field.held_rarity(a), "", "nothing held, no glint")
	# An old save's plot: no `held`, rolled at the harvest.
	g.plots[a].erase("held")
	g.drops.pity["golden"] = Balance.i("harvest.golden_pity")
	_skip(g, int(g.crops["wheat"]["grow_seconds"]) + 5)
	_eq(str(g.field.harvest(a)["drop"]), "golden", "a plot planted before luck was held is rolled at its harvest")
	# A crop left to wither loses what it held.
	g.drops.pity["golden"] = Balance.i("harvest.golden_pity")
	g.field.plant(a, "wheat")
	_skip(g, 40 * 86400)
	_eq(g.field.phase(a), GameState.Phase.WITHERED, "left too long, it withers")
	g.field.plow(a)
	_check(not g.plots[a].has("held"), "and what it held is gone with it")
	_done(g)


## Every find has the one look and sound of its rarity; the field's glints show over ripe plots that hold one;
## a mystery opens to something named in its rarity; a found young one and a baby born are finds too.
func test_365_every_find_shares_one_look_and_the_field_glints() -> void:
	for rarity: String in FindsSystem.RARITIES:
		var look := Feedback.rarity(rarity)
		_check(Feedback.has_moment(str(look["moment"])), "%s has its moment" % rarity)
		_check(int(look["sparks"]) > 0 and float(look["hold"]) > 0.0, "%s has its sparks and its time" % rarity)
	_check(int(Feedback.rarity("legendary")["sparks"]) > int(Feedback.rarity("common")["sparks"]),
		"a legendary find bursts bigger than a common one")
	_eq(Feedback.rarity("no such"), Feedback.rarity("common"), "an unknown rarity is common")
	var g := _farm(true)
	for fid: String in g.finds.families:
		for kind: Dictionary in g.finds.families[fid]["kinds"]:
			_check(FindsSystem.RARITIES.has(str(kind.get("rarity", "common"))), "%s has a known rarity" % kind["id"])
	for item: String in g.collectibles.item_rarity:
		_check(FindsSystem.RARITIES.has(g.collectibles.rarity_of(item)), "%s has a known rarity" % item)
	_eq(MysterySystem.rarity_of_prize([["coins", 1, 97], ["gems", 1, 3]], ["gems", 1, 3]), "legendary",
		"a prize drawn three times in a hundred is legendary")
	_eq(MysterySystem.rarity_of_prize([["coins", 1, 97], ["gems", 1, 3]], ["coins", 1, 97]), "common",
		"the usual one is common")
	# A young one found at a home is said there; grown, it says where it stood and what it is.
	var on: Array = []
	g.found_on.connect(func(uid: int, text: String, rarity: String) -> void: on.append([uid, text, rarity]))
	Release.whole = true
	_check(g.nurture.call("_found", NurtureSystem.BABY, "cow", 77), "a mystery baby is found")
	_check(on.any(func(f: Array) -> bool: return f[0] == 77 and f[2] == "rare"), "and said where it was found, as rare")
	var young: Dictionary = g.objects.filter(func(o: Dictionary) -> bool: return o["id"] == NurtureSystem.BABY)[0]
	young["fed"] = g.nurture.needs(young) - 1
	g.nurture.add_supply(g.nurture.supply_of(young), 1)
	var result := g.nurture.feed(int(young["uid"]))
	_eq(str(result["grown"]), "cow", "fed its last, it is what it was all along")
	_eq(int(result["young"]), int(young["uid"]), "the reveal knows who it was")
	_check(not g.object_by_uid(int(result["grown_uid"])).is_empty(), "who it is now")
	_check(result.has("row") and result.has("col"), "and where it stood")
	_eq(g.rarity_of_item("cow"), "common", "a cow is a common thing to be")
	_done(g)
	# The glints: over a held plot only while it is ripe.
	Game.saving_enabled = false
	Game.reset_game()
	Game.coins = 100000
	Game.xp = Game.xp_for_level(20)
	var drops := Game.drops_enabled
	Game.drops_enabled = true
	var i := -1
	for k in Game.plots.size():
		if i < 0 and not Game.is_occupied(k) and Game.field.phase(k) == GameState.Phase.GRASS:
			i = k
	Game.field.plow(i)
	Game.drops.pity["golden"] = Balance.i("harvest.golden_pity")
	Game.field.plant(i, "wheat")
	var glints := Glints3D.new()
	add_child(glints)
	_check(not glints.shown().has(i), "a growing crop does not glint")
	Game.debug_time_offset += int(Game.crops["wheat"]["grow_seconds"]) + 5
	glints.call("_on_clock")
	_check(glints.shown().has(i), "ripe, the plot that holds a find glints")
	_check(glints.color_of(i).is_equal_approx(Feedback.rarity("legendary")["color"]), "in its rarity's colour")
	_eq(glints.multimesh.instance_count, glints.shown().size(), "one quad for each glinting plot")
	Game.field.harvest(i)
	glints.update([i])
	_check(not glints.shown().has(i), "harvested, the glint is gone")
	glints.queue_free()
	Game.debug_time_offset = 0
	Game.drops_enabled = drops
	Game.reset_game()


## A tree's fruit grows on the tree: every fruit is in the one model, each knowing its own middle and its turn, and
## the tree is told its cycle, so fruit comes one piece at a time and the tree is not rebuilt when it is ready.
func test_366_a_trees_fruit_ripens_on_the_tree() -> void:
	var g := _farm()
	var holder := Node3D.new()
	TreeModel.build_at(holder, Vector3.ZERO, g.item_data("apple_tree"), 1.0, true, 1)
	var baked := ModelKit.bake(holder)
	var turns := {}
	var fruit_surfaces := 0
	var box := AABB()
	for part in baked.find_children("*", "MeshInstance3D", true, false):
		var mesh := (part as MeshInstance3D).mesh
		box = box.merge(mesh.get_aabb())
		for s in mesh.get_surface_count():
			var mat := (part as MeshInstance3D).get_active_material(s) as ShaderMaterial
			if mat == null or mat.shader.resource_path != ModelKit.FRUIT_SHADER:
				continue
			fruit_surfaces += 1
			var arrays := mesh.surface_get_arrays(s)
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			_check(uv2 != null and uv2.size() == uv.size() and uv.size() > 0, "every fruit vertex carries its fruit")
			for k in uv.size():
				turns[snappedf(uv2[k].y, 0.001)] = true
				if k % 37 == 0:
					_check(box.grow(0.05).has_point(Vector3(uv[k].x, uv[k].y, uv2[k].x)),
						"a fruit's middle is on the tree (%s)" % Vector3(uv[k].x, uv[k].y, uv2[k].x))
	_eq(fruit_surfaces, 1, "all the tree's fruit is one surface of its own")
	_check(turns.size() >= 10, "the fruit come at many different turns, not all at once (%d)" % turns.size())
	for turn: float in turns:
		_check(turn >= 0.0 and turn <= 1.0, "a turn is a share of the cycle (%s)" % turn)
	Objects3D.ripen(baked, 500.0 + Crops3D.clock_base, 3600.0)   # (telling a tree its cycle is safe on any model)
	baked.queue_free()   # (the merged model owns what was built into it)
	_done(g)
	Game.saving_enabled = false
	Game.reset_game()
	var tree := {"uid": Game.next_uid, "id": "apple_tree", "row": 2, "col": 2, "t": Game.now()}
	Game.next_uid += 1
	Game.add_object(tree)
	var objects := Objects3D.new()
	add_child(objects)
	var growing: String = objects.call("_key", tree)
	Game.debug_time_offset += Game.cycle_of(tree) + 5
	_check(Game.is_ready(tree), "(the tree is ready)")
	_eq(objects.call("_key", tree), growing, "a tree is the same model ready or not: it is not rebuilt when it ripens")
	objects.queue_free()
	Game.debug_time_offset = 0
	Game.reset_game()

