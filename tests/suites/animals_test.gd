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






func test_573_at_most_three_strays_a_week() -> void:
	# Owner, 19 Nov: strays came every 3 to 6 hours, far too often. Now about one every two days, never more than
	# strays.week_most (3) in any 7 days, and the count survives a save.
	var g := _farm()
	var most := Balance.i("strays.week_most")
	_eq(most, 3, "three a week")
	_check(Balance.i("strays.stray_min_gap") >= 86400, "never two in a day")
	var came := 0
	for k in 10:   # every gap forced open, a stray adopted at once: only the cap stops them
		g.strays.next_stray_at = 0
		g.strays.check_strays()
		for o in g.objects.filter(func(o): return o.get("stray", false)):
			g.strays.adopt_stray(int(o["uid"]))
			came += 1
		_skip(g, 3600)
	_eq(came, most, "the fourth waits for the week to turn")
	var data := {}
	g.strays.save_to(data)
	var h := _farm()
	h.strays.load_from(JSON.parse_string(JSON.stringify(data)))
	_eq(h.strays.arrived.size(), most, "the week's count is saved")
	_skip(g, StraySystem.WEEK)
	g.strays.next_stray_at = 0
	g.strays.check_strays()
	_eq(g.objects.filter(func(o): return o.get("stray", false)).size(), 1, "a week later one comes again")
	_done(g)
	_done(h)


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
	_check(not g.land.expansion_needs(hive).is_empty(), "a hive has a second size, like every harvesting building")
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
	_eq(_arrived(g, "berkshire_pig"), 1, "the Berkshire arrives in the Barn or the inbox, as every new animal")
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
	var seedlings: Array = _young_all(g, "mystery_seedling")
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
	_check(not gait_moved_while_still, "legs only cycle while the body actually moves (or steps round: test_432)")
	# A long frame (the app resuming) doesn't fling it.
	var c := AnimalBehaviour.new(cow, 7, Vector2(14, 7))
	var start := c.offset   # (each starts somewhere of its own in its range: never a straight row)
	_check(not AnimalBehaviour.new(cow, 8, Vector2(14, 7)).offset.is_equal_approx(start), "animals start spread out")
	c.update(5.0)
	_check((c.offset - start).length() < 2.0, "a hitch doesn't teleport an animal")
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
	_eq(g.coins - coins, int(Balance.a("mastery.star_coins")[0]), "which pays its coins")
	g.mastery.add("pig", 1000)
	_check(g.objects.any(func(o: Dictionary) -> bool: return o["id"] == "mastery_sign" and o.get("crop") == "pig"),
		"and full mastery puts up the pig's mastery sign")
	_check(not g.mastery.masterable("hay_bale"), "decorations aren't mastered")
	_done(g)


## An animal goes one stride of ground for each cycle of its legs whichever way it walks, so its feet grip the
## ground; it bounds as a thrown body does, not as a ball; and it comes round to its way before it sets off.
func test_432_animals_feet_grip_the_ground() -> void:
	var g := _farm(true)
	var rig := AnimalRig.of(g.item_data("cow"))
	var stride := 0.33
	var speeds: Array[float] = []
	for way: Vector2 in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 1)]:
		var a := AnimalBehaviour.new(rig, 5, Vector2(900, 900))
		a.stride_tiles = stride
		a.offset = Vector2.ZERO
		a._target = way.normalized() * 800.0
		a._enter(AnimalBehaviour.State.WALK, 600.0)
		for i in 60:
			a.update(1.0 / 60.0)   # (its legs blend in)
		var from := a.offset
		var cycles := 0.0
		for i in 120:
			var gait := a.pose.gait
			a.update(1.0 / 60.0)
			cycles += fposmod(a.pose.gait - gait, 1.0)
		var ground := IsoProjection.ground_of(a.offset - from).length()
		_check(absf(ground / cycles - stride) < 0.001, "going %s it covers a stride a cycle (%.4f)" % [way, ground / cycles])
		speeds.append(ground / 2.0)
	_check(absf(speeds[0] - speeds[1]) < 0.001 and absf(speeds[0] - speeds[2]) < 0.001,
		"and goes as fast over the ground up the screen as across it %s" % [speeds])
	# Its body's own stride is what it walks at: the file's walk, measured.
	var made := Animal3D.file_stride("cow")
	_check(made > 0.2 and made < 0.6, "a cow's walk covers a third of a tile or so a cycle (%.3f)" % made)
	var mind := AnimalBehaviour.new(rig, 5, Vector2(60, 30))
	var body := Animal3D.create(g.item_data("cow"), mind, Vector3.ZERO)
	_check(is_equal_approx(mind.stride_tiles, body.stride()) and is_equal_approx(body.stride(), made),
		"and its mind is told so")
	body.free()
	# A bound: up from the ground, highest half way through its flight, down again, and then on the ground.
	var air := AnimalBehaviour.AIR
	_check(is_zero_approx(AnimalBehaviour.bound(0.0)) and is_equal_approx(AnimalBehaviour.bound(air / 2.0), 1.0),
		"a bound leaves the ground and tops out half way through its flight")
	_check(is_equal_approx(AnimalBehaviour.bound(air * 0.25), AnimalBehaviour.bound(air * 0.75)),
		"it falls as it rose")
	_check(is_zero_approx(AnimalBehaviour.bound(air + 0.05)) and is_zero_approx(AnimalBehaviour.bound(0.99)),
		"and it is on the ground between bounds, not bounced straight back up")
	# Facing the wrong way it stands and steps round; once it has come round, it goes.
	var t := AnimalBehaviour.new(rig, 9, Vector2(900, 900))
	t.stride_tiles = stride
	t.offset = Vector2.ZERO
	t._target = Vector2(800, 0)
	t._enter(AnimalBehaviour.State.WALK, 600.0)
	t.turned(PI, 0.0)
	for i in 30:
		t.update(1.0 / 60.0)
	_check(t.offset.length() < 0.001, "an animal facing away doesn't walk off sideways")
	var gait := t.pose.gait
	t.turned(PI * 0.9, stride * 0.25)
	_check(is_equal_approx(fposmod(t.pose.gait - gait, 1.0), 0.25), "its legs step as far as the turn carries its feet")
	t.update(1.0 / 60.0)
	_check(t.pose.stride > 0.0, "(stepping, not sliding round)")
	t.turned(0.0, 0.0)
	for i in 30:
		t.update(1.0 / 60.0)
	_check(t.offset.x > 1.0, "and once it faces its way it sets off")
	# Tapped, it gives a start: off the ground and back, not held up.
	var p := AnimalBehaviour.new(rig, 11, Vector2(60, 30))
	p.poke()
	var top := 0.0
	for i in ceili(AnimalBehaviour.JUMP_TIME * 60.0) + 2:
		p.update(1.0 / 60.0)
		top = maxf(top, p.pose.hop)
	_check(top > AnimalBehaviour.POKE_HOP * 0.9 and is_zero_approx(p.pose.hop),
		"a tapped animal jumps and lands (%.2f)" % top)
	_done(g)


## An animal's day (looks only): lively in the cool of the morning, resting in the afternoon heat; the rhythm is
## data (animal_rigs.json rhythm) and only shifts the lively choices against the restful ones.
func test_450_animals_are_busy_in_the_morning_and_rest_in_the_afternoon_heat() -> void:
	var morning := AnimalRig.busy_at(8.0)
	var afternoon := AnimalRig.busy_at(14.0)
	_check(morning > 1.0 and afternoon < 1.0, "busier than usual at 8 (%.2f), quieter at 14 (%.2f)" % [morning,
		afternoon])
	_check(is_equal_approx(AnimalRig.busy_at(19.0), 1.0) and is_equal_approx(AnimalRig.busy_at(3.0), 1.0),
		"and their usual self in the evening and before dawn (night is sleep's)")
	_check(AnimalRig.busy_at(9.5) < morning and AnimalRig.busy_at(9.5) > 1.0, "eased between the points, not stepped")
	_check(AnimalRig.lively().has("walk") and not AnimalRig.lively().has("graze"), "walking is lively, grazing is not")
	var cow := AnimalRig.of(_farm().item_data("cow"))
	var was_hour := AnimalBehaviour.hour
	var was_night := AnimalBehaviour.night
	AnimalBehaviour.night = false
	var walks := {}
	for h: float in [8.0, 14.0]:
		AnimalBehaviour.hour = h
		var n := 0
		for s in 40:
			var mind := AnimalBehaviour.new(cow, 1000 + s, Vector2(14, 7))
			for k in 12:
				mind.call("_choose_next")
				if mind.state == AnimalBehaviour.State.WALK:
					n += 1
		walks[h] = n
	_check(walks[8.0] > walks[14.0] * 2, "a herd walks about far more at 8 than at 14 (%d against %d of 480 choices)"
		% [walks[8.0], walks[14.0]])
	AnimalBehaviour.hour = was_hour
	AnimalBehaviour.night = was_night


## Animals in the weather (looks only): in the rain one standing about turns its tail to it and stands about
## more; in a storm it keeps close to home (animal_rigs.json weather).
func test_451_animals_turn_from_the_rain_and_keep_close_in_a_storm() -> void:
	var cow := AnimalRig.of(_farm().item_data("cow"))
	var was := [AnimalBehaviour.hour, AnimalBehaviour.night, AnimalBehaviour.rain]
	AnimalBehaviour.night = false
	AnimalBehaviour.hour = 12.0
	var away := signf(AnimalRig.weather("away", -1.0))
	var counts := {}
	for r: float in [0.0, 0.7, 1.0]:
		AnimalBehaviour.rain = r
		var standing := 0
		var turned := 0
		var walks := 0
		var farthest := 0.0
		for s in 40:
			var mind := AnimalBehaviour.new(cow, 2000 + s, Vector2(14, 7))
			for k in 12:
				mind.call("_choose_next")
				if mind.state == AnimalBehaviour.State.WALK or mind.state == AnimalBehaviour.State.FROLIC:
					walks += 1
					farthest = maxf(farthest, mind.call("_norm", mind.get("_target")))
				else:
					standing += 1
					if mind.facing == away:
						turned += 1
		counts[r] = {"standing": standing, "turned": turned, "walks": walks, "farthest": farthest}
	_check(counts[0.0]["turned"] < counts[0.0]["standing"], "in fair weather it faces either way")
	_eq(counts[0.7]["turned"], counts[0.7]["standing"], "in the rain every one standing about has its tail to it")
	_check(counts[0.7]["walks"] < counts[0.0]["walks"], "and it walks about less (%d against %d)"
		% [counts[0.7]["walks"], counts[0.0]["walks"]])
	_check(counts[0.0]["farthest"] > 0.8, "in fair weather it wanders its whole range (%.2f)" % counts[0.0]["farthest"])
	_check(counts[1.0]["farthest"] <= AnimalRig.weather("huddle", 1.0) + 0.001,
		"in a storm it keeps close to home (%.2f of its range)" % counts[1.0]["farthest"])
	var mind := AnimalBehaviour.new(cow, 7, Vector2(14, 7))
	mind.facing = -away
	mind.poke()
	_eq(mind.facing, -away, "one tapped in the rain still looks round at you")
	AnimalBehaviour.hour = was[0]
	AnimalBehaviour.night = was[1]
	AnimalBehaviour.rain = was[2]


## Animals notice the farmer walking by (looks only): one standing near their way turns to watch them a moment,
## facing their side, and not again for a while; one far off, asleep or walking does not.
func test_452_animals_turn_to_watch_the_farmer_walk_by() -> void:
	var cow := AnimalRig.of(_farm().item_data("cow"))
	var was_night := AnimalBehaviour.night
	AnimalBehaviour.night = false
	var mind := AnimalBehaviour.new(cow, 11, Vector2(14, 7))
	mind.state = AnimalBehaviour.State.GRAZE
	mind.facing = 1.0
	_check(mind.see_farmer(-1.0), "a grazing cow turns to the farmer passing on its left")
	_check(mind.state == AnimalBehaviour.State.LOOK and mind.facing == -1.0, "and watches them, facing their way")
	_eq(mind.time_left(), AnimalRig.farmer("look", 0.0), "for a moment")
	mind.state = AnimalBehaviour.State.IDLE
	_check(not mind.see_farmer(1.0), "but not again straight away")
	mind.update(AnimalRig.farmer("again", 9.0) + 0.5)   # (one long step is cut to 0.1 s: wait it out)
	for k in int(AnimalRig.farmer("again", 9.0) * 10.0) + 5:
		mind.update(0.1)
	mind.state = AnimalBehaviour.State.IDLE
	mind.noticed = 0.0
	_check(mind.see_farmer(1.0), "only after a while")
	var sleeper := AnimalBehaviour.new(cow, 12, Vector2(14, 7))
	sleeper.state = AnimalBehaviour.State.SLEEP
	_check(not sleeper.see_farmer(1.0), "a sleeping one sleeps on")
	var life := FarmLife.new()
	var near := AnimalBehaviour.new(cow, 13, Vector2(14, 7))
	var far := AnimalBehaviour.new(cow, 14, Vector2(14, 7))
	near.state = AnimalBehaviour.State.IDLE
	far.state = AnimalBehaviour.State.IDLE
	life.set("_minds", {1: {"mind": near, "home": Vector2(3.5, 3.5)}, 2: {"mind": far, "home": Vector2(12.5, 12.5)}})
	_eq(life.see_farmer(Vector2(4.5, 3.5)), 1, "the farm: only the one near their way turns")
	_eq(near.facing, 1.0, "towards them (a tile further along its column is to the screen's right)")
	life.free()
	AnimalBehaviour.night = was_night


func test_513_kept_strides_are_the_files_own() -> void:
	# Every file-made kind's stride is kept, from its file as it is now (tools/animal_strides writes them), so a
	# farm opening never reads every animal file's moves; a kept one is exactly what its file measures.
	var stale: Array[String] = []
	for id in Animal3D.stride_kinds():
		var kept := Animal3D.kept_stride(id)
		if kept < 0.0 or absf(kept - Animal3D.measure_stride(id)) > 0.00001:
			stale.append(id)
	_check(stale.is_empty(), "every animal's kept stride is its file's (run tools/animal_strides.tscn): %s" % [stale])
	# A kind whose file has changed since is measured as it opens, never given an old stride.
	var data: Dictionary = ArtVersion._data.duplicate(true)
	ArtVersion._data["files"]["cow"] = "changed"
	_check(Animal3D.kept_stride("cow") < 0.0, "a changed file's kept stride is not used")
	ArtVersion._data = data


func test_574_a_test_skip_hurries_timers_never_the_sky() -> void:
	# Owner, 19 Nov: after a few presses of Skip 1 hour the farm showed 10 pm at 5 pm, for good. A skip moves every
	# timer (now) but the farm's look (look_now: sky, clock, the animals' day) stays on the real time; an older save,
	# whose whole offset was skips, comes back to the real time.
	var g := _farm()
	var look := g.look_now()
	var t := g.now()
	g.debug_skip(3600)
	_eq(g.now() - t, 3600, "the timers move an hour")
	_check(absi(g.look_now() - look) <= 1, "the sky does not")
	var data := {"debug_time_offset": 5 * 3600}
	var h := _farm()
	h.debug_time_offset = int(data["debug_time_offset"])
	h.skipped = int(data.get("skipped", h.debug_time_offset))
	_check(absi(h.look_now() - int(Time.get_unix_time_from_system())) <= 1, "an old save's sky is back on real time")
	_done(g)
	_done(h)
