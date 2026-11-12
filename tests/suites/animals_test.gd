extends TestSuite
## Animals: the beehive, pig pen, orchard, strays, breeding, and how animals walk and behave.


func test_14_bees_only_join_a_hive_with_a_queen() -> void:
	var g := _farm(true)
	var hive := _built_hive(g)
	g.bees.queen_bees = 0
	var queens_found := 0
	for k in 200:
		if g.bees.flower_harvest_bees() == "A Queen Bee!":
			queens_found += 1
			g.bees.queen_bees = 0 # keep her out of the hive for this part
	_eq(g.inside_total(hive), 0, "no bees join a hive without a queen")
	_check(queens_found <= 6, "Queen Bees are rare (%d in 200 flower harvests)" % queens_found)
	g.bees.queen_bees = 1
	_check(g.bees.add_queen(int(hive["uid"])), "the queen moves in")
	_eq(g.bees.queen_bees, 0, "the held queen was used")
	for k in 200:
		g.bees.flower_harvest_bees()
	var bees := g.inside_total(hive)
	_check(bees >= 30 and bees <= 70, "about a quarter of flower harvests bring a bee (%d of 200)" % bees)
	_skip(g, 86400)
	var drops := g.drops_enabled
	g.drops_enabled = false
	_eq(int(g.collect(int(hive["uid"]))["coins"]), 6 * bees, "honey pays 6 coins a bee")
	g.drops_enabled = drops
	# Real flower harvests report the bee.
	g.xp = maxi(g.xp, g.xp_for_level(4))
	var seen := false
	for k in 30:
		var r := _grow_and_harvest(g, _free(g), "lilac")
		if str(r.get("bee", "")) != "":
			seen = true
	_check(seen, "a lilac harvest brought a bee")
	_done(g)






func test_15_strays_arrive_get_adopted_or_leave() -> void:
	var g := _farm()
	g.strays.next_stray_at = 0
	g.strays.check_strays()
	var strays := g.objects.filter(func(o): return o.get("stray", false))
	_eq(strays.size(), 1, "one stray arrives")
	var s: Dictionary = strays[0]
	_check(not g.is_ready(s), "strays don't produce")
	g.ribbons.ribbon_tiers["animal_lover"] = 4 # isolate the adoption XP from the first-ribbon reward
	var xp := g.xp
	_check(g.strays.adopt_stray(int(s["uid"])), "adopt")
	_check(not s.get("stray", false), "no longer a stray")
	_eq(g.xp, xp + Balance.i("strays.stray_adopt_xp"), "adoption XP")

	g.strays.next_stray_at = 0
	g.strays.check_strays()
	_eq(g.objects.filter(func(o): return o.get("stray", false)).size(), 1, "another stray")
	g.strays.next_stray_at = g.now() + 999999 # stop new arrivals
	_skip(g, Balance.i("strays.stray_stays") + 1)
	g.strays.check_strays()
	_eq(g.objects.filter(func(o): return o.get("stray", false)).size(), 0, "unadopted stray left")
	_done(g)






## A finished Beehive at 8,8 (frame placed, materials added).
func _built_hive(g: GameState) -> Dictionary:
	g.coins = 1000000
	g.xp = maxi(g.xp, g.xp_for_level(3))
	g.buy_and_place("beehive", 8, 8)
	var hive := g.object_at(g.index_of(8, 8))
	_all_materials(g, 10)
	g.land.add_materials(int(hive["uid"]))
	return hive






func test_47_beehive_frame_and_queen_bee() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(3)
	_check(g.buy_and_place("beehive", 8, 8), "hive frame placed")
	var hive := g.object_at(g.index_of(8, 8))
	var uid := int(hive["uid"])
	_check(g.under_construction(hive), "the Beehive is built from a frame")
	g.gems = 100
	_check(not g.bees.add_queen(uid, true), "no queen in an unfinished frame")
	_all_materials(g, 10)
	g.land.add_materials(uid)
	_check(not g.under_construction(hive), "frame finished with smokers, beeswax and the basics")
	_eq(int(g.parts["smokers"]), 0, "smokers used")
	_eq(g.capacity(hive), 200, "holds up to 200 bees")
	_check(g.land.expansion_needs(hive).is_empty(), "a hive isn't expanded: it grows as bees join")
	g.bees.queen_bees = 0
	_check(not g.bees.add_queen(uid), "no queen held")
	g.gems = Balance.i("bees.queen_gem_cost")
	_check(g.bees.add_queen(uid, true), "queen bought with gems")
	_eq(g.gems, 0, "%d gems spent" % Balance.i("bees.queen_gem_cost"))
	_check(g.bees.has_queen(hive), "the hive has its queen")
	g.bees.queen_bees = 1
	_check(not g.bees.add_queen(uid), "only one queen per hive")
	_eq(g.bees.queen_bees, 1, "the spare queen is kept")
	_check(g.daily.wanted_parts().has("smokers"), "smokers drop once you own a hive")
	_done(g)






func test_48_bees_pollinate_fertilized_crops() -> void:
	var g := _farm(true)
	_eq(g.bees.pollination_chance(), 0.0, "no bees, no pollination")
	var none := 0
	for k in 100:
		none += g.bees.pollinate("strawberries")
	_eq(none, 0, "nothing pollinated without bees")
	var hive := _built_hive(g)
	hive["queen"] = true
	hive["inside"] = {"bee": 100}
	_eq(g.bees.pollination_chance(), 0.25, "100 bees: 25%")
	hive["inside"] = {"bee": 200}
	_eq(g.bees.pollination_chance(), 0.5, "200 bees: 50%, the most")
	# Harvesting fertilized crops gives pollinated seeds; unfertilized ones never do.
	var i := _free(g)
	var from_plain := 0
	for k in 20:
		from_plain += int(_grow_and_harvest(g, i, "strawberries").get("pollinated", 0))
	_eq(from_plain, 0, "unfertilized crops aren't pollinated")
	var got := 0
	for k in 20:
		g.field.plow(i)
		g.bees.pollinated.clear()
		g.field.plant(i, "strawberries")
		g.field.fertilize(i)
		_skip(g, int(g.crops["strawberries"]["grow_seconds"]))
		got += int(g.field.harvest(i).get("pollinated", 0))
	_check(got >= 25, "about half of fertilized harvests were pollinated (%d seeds)" % got)
	# Planting pollinated seeds: free, and the crop stays ripe twice as long.
	g.bees.pollinated = {"strawberries": [2, g.now() + Balance.i("bees.pollinated_lifetime")]}
	var j := g.index_of(10, 10)
	g.field.plow(i)
	g.field.plow(j)
	var coins := g.coins
	_check(g.field.plant(i, "strawberries"), "plant a pollinated seed")
	_eq(g.coins, coins, "pollinated seeds are free")
	_eq(g.bees.pollinated_seeds("strawberries"), 1, "one pollinated seed left")
	_check(g.plots[i].get("pol", false), "the plot is pollinated")
	g.bees.pollinated.clear()
	g.field.plant(j, "strawberries")
	_check(not g.plots[j].get("pol", false), "an ordinary seed")
	var grow := int(g.crops["strawberries"]["grow_seconds"])
	var window := g.field.ripe_window(g.crops["strawberries"])
	_skip(g, grow + window + 3600)
	_eq(g.field.phase(j), GameState.Phase.WITHERED, "the ordinary crop withered")
	_eq(g.field.phase(i), GameState.Phase.RIPE, "the pollinated crop is still ripe")
	_skip(g, window)
	_eq(g.field.phase(i), GameState.Phase.WITHERED, "but not forever")
	# Pollinated seeds expire after 2 days.
	g.bees.pollinated = {"wheat": [5, g.now() + Balance.i("bees.pollinated_lifetime")]}
	_eq(g.bees.pollinated_seeds("wheat"), 5, "5 pollinated wheat seeds")
	_skip(g, Balance.i("bees.pollinated_lifetime"))
	_eq(g.bees.pollinated_seeds("wheat"), 0, "expired after 2 days")
	_done(g)






func test_49_pollinated_crops_super_harvest_three_times_as_often() -> void:
	var g := _farm(true)
	var plain := 0
	var boosted := 0
	g.drops.pity = {"golden": 0, "collectible": 0}
	for k in 6000:
		if str(g.drops.roll_drop("", 0).get("type", "")) == "super_harvest":
			plain += 1
		if str(g.drops.roll_drop("", 0, Balance.i("economy.pollinated_super_mult")).get("type", "")) == "super_harvest":
			boosted += 1
	var ratio := float(boosted) / maxf(1.0, plain)
	_check(ratio > 2.3 and ratio < 3.7, "about 3x the super harvests (%d vs %d)" % [boosted, plain])
	_done(g)






func test_50_fertilize_all_from_the_hive() -> void:
	var g := _farm(true)
	var hive := _built_hive(g)
	hive["queen"] = true
	hive["inside"] = {"bee": 50}
	hive["t"] = g.now()
	for d in 60:
		_skip(g, 86400)
		g.collect(int(hive["uid"]))
	_check(g.fertilize_alls > 0, "collecting honey left a Fertilize All (%d in 60 days)" % g.fertilize_alls)
	# Using it fertilizes every growing crop for free.
	g.drops_enabled = false
	var spots := [g.index_of(9, 0), g.index_of(9, 1), g.index_of(10, 0)]
	for i in spots:
		if g.field.phase(i) != GameState.Phase.PLOWED:
			g.field.plow(i)
		g.field.plant(i, "wheat")
	g.fertilize_alls = 1
	g.fertilizer_bags = 0
	var coins := g.coins
	_check(g.bees.use_fertilize_all() >= 3, "every growing crop fertilized")
	for i in spots:
		_check(g.field.is_fertilized(i), "plot %d fertilized" % i)
	_eq(g.coins, coins, "no coins spent")
	_eq(g.fertilize_alls, 0, "used up")
	_eq(g.bees.use_fertilize_all(), 0, "none left")
	_done(g)






func test_51_bees_leave_when_you_stay_away() -> void:
	var g := _farm()
	var hive := _built_hive(g)
	hive["queen"] = true
	hive["inside"] = {"bee": 100}
	_eq(g.bees.apply_absence(2 * 86400), "", "2 days away: nothing happens")
	_eq(g.inside_total(hive), 100, "all bees stay")
	var note := g.bees.apply_absence(5 * 86400)
	_eq(g.inside_total(hive), 70, "5 days away: 2 days past the limit, 30% leave")
	_check(note.contains("30 bees"), "the player is told (%s)" % note)
	_check(g.bees.has_queen(hive), "the queen stays two weeks")
	g.bees.apply_absence(15 * 86400)
	_eq(g.inside_total(hive), 0, "15 days away: every bee is gone")
	_check(not g.bees.has_queen(hive), "and the queen flew off")
	_done(g)






func test_52_pig_pen_truffles_and_rare_breeds() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(15)
	_check(not g.buy_and_place("pig_pen", 8, 8), "Pig Pen unlocks at level 16")
	g.xp = g.xp_for_level(16)
	_check(g.buy_and_place("pig_pen", 8, 8), "pig pen frame placed")
	var pen := g.object_at(g.index_of(8, 8))
	var uid := int(pen["uid"])
	_check(g.under_construction(pen), "built from a frame")
	_all_materials(g, 8)
	g.land.add_materials(uid)
	_check(not g.under_construction(pen), "boards, bricks and nails finish it")
	_check(not g.pigpen.feed_slop(uid), "no slop without pigs")
	for k in 12:
		g.place_somewhere("pig")
	_eq(g.homes.fill_building(uid), 12, "12 pigs move in")
	var coins := g.coins
	_check(g.pigpen.feed_slop(uid), "feed slop")
	_eq(g.coins, coins - Balance.i("pigpen.slop_cost"), "slop costs %d coins" % Balance.i("pigpen.slop_cost"))
	_check(not g.pigpen.feed_slop(uid), "already foraging")
	_eq(g.pigpen.collect_truffles(uid), 0, "nothing until foraging is over")
	_skip(g, Balance.i("pigpen.forage_seconds"))
	_eq(g.pigpen.collect_truffles(uid), 2, "12 pigs find 2 truffles")
	_eq(g.pigpen.truffles, 2, "truffles held")
	_eq(g.pigpen.collect_truffles(uid), 0, "collected once")
	# Truffles buy rare breeds; rare breeds aren't in the market.
	_check(not g.pigpen.trade_truffles("berkshire_pig"), "10 truffles needed")
	g.pigpen.truffles = 10
	_check(not g.pigpen.trade_truffles("pig"), "only rare breeds")
	_check(g.pigpen.trade_truffles("berkshire_pig"), "trade for a Berkshire")
	_eq(g.pigpen.truffles, 0, "10 truffles spent")
	_eq(_count(g, "berkshire_pig"), 1, "the Berkshire is on the farm")
	_eq(g.homes.fill_building(uid), 1, "and moves into the pen")
	_eq(g.pigpen.rare_pigs().size(), 4, "4 rare breeds")
	for id in g.pigpen.rare_pigs():
		_check(int(g.item_data(id)["payout"]) > int(g.item_data("pig")["payout"]), "%s pays more than a pig" % id)
		_eq(int(g.item_data(id)["unlock_level"]), 99, "%s can't be bought" % id)
	# A pen with a single pig still finds one truffle.
	pen["inside"] = {"pig": 1}
	g.pigpen.feed_slop(uid)
	_skip(g, Balance.i("pigpen.forage_seconds"))
	_eq(g.pigpen.collect_truffles(uid), 1, "one pig finds one truffle")
	_done(g)






func test_53_orchard_harvests_give_mystery_seedlings_or_watering_cans() -> void:
	# FarmVille: every Orchard harvest gives a Mystery Seedling or a Watering Can. A seedling grows into one of
	# the Orchard's trees, now and then its rare variety.
	var g := _farm(true)
	g.coins = 1000000
	g.farm_size = GameState.MAX_SIZE
	g.xp = g.xp_for_level(8)
	_check(g.buy_and_place("orchard", 8, 8), "orchard bought")
	var orch := g.object_at(g.index_of(8, 8))
	orch["inside"] = {"cherry_tree": 10}
	orch["t"] = g.now()
	for k in 200:
		_skip(g, g.cycle_of(orch))
		g.collect(int(orch["uid"]))
	var seedlings: Array = g.objects.filter(func(o: Dictionary) -> bool: return o["id"] == "mystery_seedling")
	var cans := g.nurture.has_supply("watering_can")
	_eq(seedlings.size() + cans, 200, "every harvest gave one or the other")
	_check(seedlings.size() > 70 and seedlings.size() < 130, "about half of them seedlings (%d)" % seedlings.size())
	var rare := 0
	for o: Dictionary in seedlings:
		_check(o["becomes"] in ["cherry_tree", "rainier_cherry_tree"], "a seedling grows into the trees inside")
		_eq(int(o["fed"]), 0, "and starts unwatered")
		if o["becomes"] == "rainier_cherry_tree":
			rare += 1
	_check(rare >= 1 and rare <= seedlings.size() / 4, "about 1 in 10 is the rare Rainier Cherry (%d)" % rare)
	_check(g.building_accepts(orch, "rainier_cherry_tree"), "rare trees can live in the orchard")
	for id in g.item_order:
		var it: Dictionary = g.items[id]
		if it.has("rare_sapling"):
			var r := g.item_data(it["rare_sapling"])
			_check(not r.is_empty(), "%s has its rare variety" % id)
			_eq(r.get("rare_of", ""), id, "%s links back" % r.get("id", "?"))
			_check(int(r["payout"]) > int(it["payout"]), "%s pays more" % r.get("id", "?"))
			_eq(int(r["unlock_level"]), 99, "%s can't be bought" % r.get("id", "?"))
	_done(g)


func test_54_new_building_state_survives_a_save() -> void:
	var path := "user://test_save_buildings.json"
	var g := _farm()
	g.save_path = path
	var hive := _built_hive(g)
	hive["queen"] = true
	hive["inside"] = {"bee": 42}
	g.bees.queen_bees = 1
	g.fertilize_alls = 2
	g.pigpen.truffles = 7
	g.bees.pollinated = {"wheat": [3, g.now() + 3600]}
	g.xp = g.xp_for_level(16)
	g.buy_and_place("pig_pen", 0, 4)
	var pen := g.object_at(g.index_of(0, 4))
	pen.erase("construction")
	pen["inside"] = {"pig": 5}
	g.pigpen.feed_slop(int(pen["uid"]))
	g.saving_enabled = true
	g.save_game()
	g.saving_enabled = false
	_done(g)

	var h := GameState.new()
	h.save_path = path
	add_child(h)
	h.saving_enabled = false
	var hive2 := h.object_at(h.index_of(8, 8))
	_check(h.bees.has_queen(hive2), "queen restored")
	_eq(h.inside_total(hive2), 42, "bees restored")
	_eq(h.bees.queen_bees, 1, "held queen restored")
	_eq(h.fertilize_alls, 2, "Fertilize All restored")
	_eq(h.pigpen.truffles, 7, "truffles restored")
	_eq(h.bees.pollinated_seeds("wheat"), 3, "pollinated seeds restored")
	var pen2 := h.object_at(h.index_of(0, 4))
	_check(h.pigpen.is_foraging(pen2), "foraging restored")
	_check(h.pigpen.forage_seconds_left(pen2) > 0, "foraging time restored")
	h.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))






func test_90_animals_walk_on_their_legs() -> void:
	var g := _farm(true)
	# Every animal in the catalog has a rig, and every rig override is for a real animal.
	for v in AnimalRig.variant_ids():
		_check(g.items.has(v), "rig variant %s is a real animal" % v)
	var families := AnimalRig.families()
	var missing: Array[String] = []
	for id in g.items:
		var it: Dictionary = g.items[id]
		if it.get("kind", "") == "animal" and not families.has(str(it.get("family", id))):
			missing.append(id)
	_eq(missing.size(), 0, "every animal has a rig for its family %s" % [missing])
	# A foot's step cycle closes on itself, and on the ground it slides back exactly its reach.
	var reach := 10.0
	_check(AnimalArt.foot_offset(0.0, reach, 3.0).is_equal_approx(AnimalArt.foot_offset(1.0, reach, 3.0)),
		"a step ends where the next begins")
	var slid := AnimalArt.foot_offset(0.0, reach, 3.0).x - AnimalArt.foot_offset(AnimalArt.STANCE - 0.0001, reach, 3.0).x
	_check(absf(slid - reach) < 0.01, "a planted foot slides back its whole reach (%.3f)" % slid)
	_eq(AnimalArt.foot_offset(0.3, reach, 3.0).y, 0.0, "a planted foot stays on the ground")
	_check(AnimalArt.foot_offset(AnimalArt.STANCE + (1.0 - AnimalArt.STANCE) / 2.0, reach, 3.0).y < -2.9,
		"a stepping foot lifts")
	# The body moves one cycle length per walk cycle: exactly how far a planted foot slides, so feet don't skate.
	var cow := AnimalRig.of(g.item_data("cow"))
	var slide_per_cycle := AnimalArt.STRIDE * cow.size("leg", 12.0) / AnimalArt.STANCE
	_check(is_equal_approx(cow.cycle_length(), slide_per_cycle), "the walk cycle matches the stride")
	# The knee joint keeps both bones their length.
	var hip := Vector2(0, 0)
	var foot := Vector2(3, 14)
	var knee := AnimalArt.joint(hip, foot, 8.0, 8.0, 1.0)
	_check(is_equal_approx(knee.distance_to(hip), 8.0) and is_equal_approx(knee.distance_to(foot), 8.0),
		"a leg bends at the knee without stretching")
	# Behaviour: deterministic per animal, stays near home, walks only while its legs are moving.
	var a := AnimalBehaviour.new(cow, 42, Vector2(14, 7))
	var b := AnimalBehaviour.new(cow, 42, Vector2(14, 7))
	var other := AnimalBehaviour.new(cow, 43, Vector2(14, 7))
	var states := {}
	var max_out := 0.0
	var differs := false
	var gait_moved_while_still := false
	for i in 3000:
		var before := a.offset
		var gait_before := a.pose.gait
		a.update(1.0 / 30.0)
		b.update(1.0 / 30.0)
		other.update(1.0 / 30.0)
		states[a.state] = true
		max_out = maxf(max_out, Vector2(a.offset.x / 14.0, a.offset.y / 7.0).length())
		differs = differs or not a.offset.is_equal_approx(other.offset)
		if a.offset.is_equal_approx(before) and not is_equal_approx(a.pose.gait, gait_before):
			gait_moved_while_still = true
	_check(a.offset.is_equal_approx(b.offset) and a.state == b.state, "the same animal moves the same way every load")
	_check(differs, "two animals don't move in step")
	_check(max_out <= 1.001, "an animal stays within its wander range (went %.2f)" % max_out)
	_check(states.has(AnimalBehaviour.State.WALK) and states.has(AnimalBehaviour.State.GRAZE),
		"over a few minutes a cow walks and grazes")
	_check(not gait_moved_while_still, "legs only cycle while the body actually moves")
	# A long frame (the app resuming) doesn't fling it.
	var c := AnimalBehaviour.new(cow, 7, Vector2(14, 7))
	c.update(5.0)
	_check(c.offset.length() < 2.0, "a hitch doesn't teleport an animal")
	# Birds peck, and a turkey displays.
	var turkey := AnimalBehaviour.new(AnimalRig.of(g.item_data("turkey")), 3, Vector2(14, 7))
	var pecked := false
	var displayed := false
	for i in 6000:
		turkey.update(1.0 / 30.0)
		pecked = pecked or turkey.pose.head > 0.9
		displayed = displayed or turkey.pose.display > 0.9
	_check(pecked and displayed, "a turkey pecks and fans its tail")
	# Young animals are smaller with bigger heads.
	var calf := AnimalRig.of(g.item_data("calf"))
	_check(calf.young and calf.scale < cow.scale and calf.head_scale > 1.0, "a calf is small with a big head")
	_done(g)


func test_91_babies_look_and_play_alike() -> void:
	var g := _farm(true)
	var young_weights := {}
	for id in g.items:
		var it: Dictionary = g.items[id]
		if it.get("kind", "") != "animal":
			continue
		var rig := AnimalRig.of(it)
		if not rig.young:
			continue
		# One temperament for every baby, whatever the species.
		var w := JSON.stringify(rig.behaviour())
		young_weights[w] = true
		_check(rig.behaviour().has("frolic"), "%s plays" % id)
		_check(rig.num("eye_scale", 1.0) > 1.0, "%s has big baby eyes" % id)
		_check(not rig.flag("udder") and rig.text("horns", "none") == "none", "%s has no udder or horns" % id)
	_eq(young_weights.size(), 1, "every baby shares one way of behaving")
	var cow := AnimalRig.of(g.item_data("cow"))
	var calf := AnimalRig.of(g.item_data("calf"))
	_check(calf.size("leg") / calf.pair("body").x > cow.size("leg") / cow.pair("body").x,
		"a calf is leggy: long legs for its short body")
	_check(AnimalRig.of(g.item_data("baby_turkey")).flag("fluff"), "a poult is fluffy")
	# A calf frolics: it dashes and bounces off the ground, then settles.
	var b := AnimalBehaviour.new(calf, 11, Vector2(14, 7))
	var bounced := false
	var dashed := false
	for i in 4000:
		b.update(1.0 / 30.0)
		if b.state == AnimalBehaviour.State.FROLIC:
			dashed = true
			bounced = bounced or b.pose.hop > 0.8
	_check(dashed and bounced, "a calf frolics and bounces")
	var adult := AnimalBehaviour.new(cow, 11, Vector2(14, 7))
	var adult_frolics := false
	for i in 4000:
		adult.update(1.0 / 30.0)
		adult_frolics = adult_frolics or adult.state == AnimalBehaviour.State.FROLIC
	_check(not adult_frolics, "grown cows don't frolic")
	_done(g)


func test_116_animals_and_trees_are_mastered_and_collecting_gives_no_xp() -> void:
	# FarmVille: collecting an animal or tree pays coins and mastery, never XP; a home's harvest counts every
	# animal in it toward that animal's mastery, so keeping more of a kind masters it sooner.
	var g := _farm()
	g.farm_size = GameState.MAX_SIZE
	g.place_somewhere("cow")
	var cow: Dictionary = g.objects[-1]
	_skip(g, g.cycle_of(cow))
	var xp := g.xp
	var got := g.collect(int(cow["uid"]))
	_check(int(got.get("coins", 0)) > 0, "a cow pays coins")
	_eq(g.xp - xp, int(got.get("xp", 0)), "and only a bonus drop gives XP")
	_eq(g.mastery.points_of("cow"), 1, "one harvest, one mastery point")
	g.xp = g.xp_for_level(16)
	g.coins = 1000000
	_check(g.buy_and_place("pig_pen", 20, 20), "a pig pen goes up")
	var pen := g.object_at(g.index_of(20, 20))
	_all_materials(g, 8)
	g.land.add_materials(int(pen["uid"]))
	for k in 12:
		g.place_somewhere("pig")
	g.homes.fill_building(int(pen["uid"]))
	_skip(g, g.cycle_of(pen))
	g.collect(int(pen["uid"]))
	_eq(g.mastery.points_of("pig"), 12, "a pen of 12 pigs harvested: 12 points toward pig mastery")
	var need: int = g.mastery.thresholds("pig")[0]
	g.mastery.points["pig"] = need - 1
	var coins := g.coins
	_eq(g.mastery.add("pig", 1), 1, "the next harvest reaches a star")
	_eq(g.coins - coins, MasterySystem.STAR_COINS[0], "which pays its coins")
	g.mastery.add("pig", 1000)
	_check(g.objects.any(func(o: Dictionary) -> bool: return o["id"] == "mastery_sign" and o.get("crop") == "pig"),
		"and full mastery puts up the pig's mastery sign")
	_check(not g.mastery.masterable("hay_bale"), "decorations aren't mastered")
	_done(g)
