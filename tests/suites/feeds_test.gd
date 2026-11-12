extends TestSuite
## Feeding animals (FeedSystem, our own touch): the data is complete, harvests drop feed, an animal is fed one
## effect for its cycle and goes hungry (fewer coins, never none) otherwise, helpers do it too, and every
## farm action is declared for helpers (data/actions.json).


func _feed_farm() -> GameState:
	var g := _farm()
	g.feeds.active = true
	g.coins = 10000000
	g.xp = g.xp_for_level(60)
	g.set_objects([])   # a new farm starts with animals of its own
	return g


## A loose animal, ready to be fed.
func _animal(g: GameState, id := "chicken", row := 11, col := 11) -> Dictionary:
	_check(g.buy_and_place(id, row, col), "%s bought" % id)
	return g.object_at(g.index_of(row, col))


func _wait_cycle(g: GameState, o: Dictionary) -> void:
	g.debug_time_offset += g.cycle_of(o) + 1


func test_164_every_animal_family_has_a_taste_and_every_crop_family_a_feed() -> void:
	var g := _feed_farm()
	var tastes: Dictionary = g.feeds._tastes
	var fams := {}
	for id in g.item_order:
		var it := g.item_data(id)
		if str(it.get("kind", "")) == "animal":
			fams[str(it.get("family", ""))] = true
	for fam: String in fams:
		if fam != "bee":
			_check(tastes.has(fam), "%s has a taste" % fam)
	for fam: String in tastes:
		_check(fams.has(fam), "taste %s is a real animal family" % fam)
		var t: Dictionary = tastes[fam]
		_check(not (t["favourite"] as Array).is_empty(), "%s has a favourite" % fam)
		for f: String in (t["favourite"] as Array) + (t["accepted"] as Array):
			_check(f in g.feeds.feed_ids(), "%s's %s is a feed" % [fam, f])
	for f in g.feeds.feed_ids():
		_check(g.feeds.feed_name(f) != "FEED_" + f.to_upper(), "feed %s has a name" % f)
	for crop in g.crop_order:
		var fam := str(g.crops[crop].get("family", ""))
		_check(fam != "", "%s knows its family" % crop)
		if fam != "fibre":
			_check(g.feeds.crop_feed(crop) != "", "%s (%s) gives a feed" % [crop, fam])
	_eq(g.feeds.taste("chicken", "grain"), 1.0, "a favourite is full")
	_eq(g.feeds.taste("chicken", "greens"), Balance.f("feeds.accepted_share"), "an accepted one is a share")
	_eq(g.feeds.taste("chicken", "roots"), 0.0, "anything else is refused")
	_done(g)


func test_165_harvests_drop_feed_only_when_something_eats_it_and_the_barn_has_a_cap() -> void:
	var g := _feed_farm()
	g.drops_enabled = true
	Balance.override("feeds.chance_base", 1.0)
	var wheat := "wheat"
	_eq(g.feeds.roll_harvest(wheat, 0, false), "", "no animal on the farm, no feed (nobody would eat it)")
	_animal(g)
	_eq(g.feeds.roll_harvest(wheat, 0, false), "grain", "a hen is there: wheat drops grain")
	_eq(g.feeds.count("grain"), 1, "kept in the Barn")
	_eq(g.feeds.roll_harvest(wheat, 0, true), "grain", "a Rich one")
	_eq(g.feeds.count("grain", true), 1, "kept apart as Rich")
	_eq(g.feeds.roll_harvest("strawberries", 0, false), "", "nothing eats fruit yet")
	var coins := g.coins
	for k in g.feeds.cap() + 5:
		g.feeds.add("grain")
	_eq(g.feeds.total("grain"), g.feeds.cap(), "the Barn holds only its cap")
	_check(g.coins >= coins + 5 * Balance.i("feeds.overflow_coins"), "the rest is sold, not lost")
	g.feeds.active = false
	_eq(g.feeds.roll_harvest(wheat, 0, false), "", "switched off, nothing drops")
	Balance.reload()
	_done(g)


func test_166_a_fed_animal_pays_more_a_hungry_one_less_and_the_effect_ends_with_the_collect() -> void:
	var g := _feed_farm()
	var o := _animal(g)
	var base := int(g.item_data("chicken")["payout"])
	_check(g.feeds.is_hungry(o), "unfed, it is hungry")
	_wait_cycle(g, o)
	_eq(g.collect(int(o["uid"]))["coins"], roundi(base * (1.0 - Balance.f("feeds.hunger_penalty"))),
		"a hungry animal pays less, never nothing")
	_eq(g.feeds.problem(o, "grain", "produce"), "NOT_ENOUGH_FEED", "no feed in the Barn")
	g.feeds.add("grain")
	g.feeds.add("greens")
	g.feeds.add("roots")
	_eq(g.feeds.problem(o, "roots", "produce"), "IT_WON_T_EAT_THAT", "a hen refuses roots")
	_wait_cycle(g, o)
	_eq(
		g.feeds.problem(o, "grain", "produce"),
		"COLLECT_IT_FIRST",
		"no feeding what is ready: a hungry round can't be undone"
	)
	g.collect(int(o["uid"]))
	var r := g.feeds.feed(int(o["uid"]), "grain", "produce")
	_eq(r["units"], 1, "one unit")
	_eq(g.feeds.count("grain"), 0, "used up")
	_check(absf(float(r["power"]) - Balance.f("feeds.produce_bonus")) < 0.0001, "a favourite gives the full effect")
	_check(not g.feeds.is_hungry(o), "fed, it is not hungry")
	_eq(g.feeds.problem(o, "greens", "produce"), "ALREADY_WELL_FED", "a lesser feed can't replace a better one")
	_wait_cycle(g, o)
	_eq(
		g.collect(int(o["uid"]))["coins"],
		roundi(base * (1.0 + Balance.f("feeds.produce_bonus"))),
		"paid with the bonus"
	)
	_check(g.feeds.is_hungry(o), "and hungry again for the next round")
	# Accepted feed gives half; Rich adds; speed shortens the cycle; rare raises the chance.
	g.feeds.add("greens")
	var half := g.feeds.feed(int(o["uid"]), "greens", "speed")
	_check(absf(float(half["power"]) - Balance.f("feeds.speed_bonus") * Balance.f("feeds.accepted_share")) < 0.0001,
		"an accepted feed gives its share")
	var plain := int(g.item_data("chicken")["cycle_seconds"])
	_check(g.cycle_of(o) < plain, "a speed feed shortens the cycle")
	_eq(g.feeds.rare_multiplier(o), 1.0, "and gives no rare boost")
	_check(g.feeds.power("produce", 1.0, true) > g.feeds.power("produce", 1.0, false), "Rich is stronger")
	_done(g)


func test_167_a_home_takes_one_unit_for_a_few_animals_and_is_judged_on_what_is_inside() -> void:
	var g := _feed_farm()
	var coop := {"uid": g.next_uid, "id": "chicken_coop", "row": 6, "col": 6, "level": 1,
		"inside": {"chicken": 4, "cow": 0}, "t": g.now()}
	g.next_uid += 1
	g.add_object(coop)
	var o := g.object_by_uid(int(coop["uid"]))
	_check(g.feeds.is_feedable(o), "a home with animals can be fed")
	_eq(g.feeds.units_needed(o), ceili(4.0 / Balance.i("feeds.animals_per_feed")), "units follow the animals inside")
	_eq(g.feeds.grade(o, "grain"), 1.0, "hens love grain")
	_eq(g.feeds.family_counts(o), {"chicken": 4}, "only the real animals count")
	var empty := {"uid": g.next_uid, "id": "chicken_coop", "row": 8, "col": 8, "level": 1, "inside": {}, "t": g.now()}
	g.next_uid += 1
	g.add_object(empty)
	_check(not g.feeds.is_feedable(g.object_by_uid(int(empty["uid"]))), "an empty home has nothing to feed")
	_done(g)


func test_168_the_farmhand_collects_then_feeds_what_is_hungry() -> void:
	var g := _feed_farm()
	var o := _animal(g)
	g.farmhands = 2
	g.feeds.add("grain")
	g.feeds.add("grain", true)
	_wait_cycle(g, o)
	var n := g.use_helper("animal")
	_eq(n, 2, "it collected one animal and fed one")
	_eq(g.farmhands, 1, "using one farmhand")
	_check(not g.feeds.is_hungry(g.object_by_uid(int(o["uid"]))), "and the animal is fed for the next round")
	_eq(g.feeds.count("grain"), 0, "the plain feed was used before the Rich one")
	_eq(g.feeds.count("grain", true), 1, "the Rich one is kept")
	_eq(g.use_helper("animal"), 0, "nothing left to do")
	_eq(g.farmhands, 1, "and no farmhand is spent for nothing")
	_done(g)


func test_169_the_farmer_feeds_as_a_queued_job() -> void:
	var g := _feed_farm()
	var o := _animal(g)
	g.feeds.add("grain")
	var job := {"kind": "feed", "uid": int(o["uid"]), "feed": "grain", "effect": "produce", "rich": false}
	_eq(g.player.enqueue(job), PlayerSystem.Refused.NONE, "the job is accepted")
	_eq(g.player.enqueue({"kind": "collect", "uid": int(o["uid"])}), PlayerSystem.Refused.NOTHING_TO_DO,
		"collecting a hungry one that isn't ready is still nothing to do")
	var done := []
	g.player.action_done.connect(func(_j: Dictionary, res: Dictionary) -> void: done.append(res.is_empty()))
	g.player.advance(30.0)
	_eq(done, [false], "the farmer walked there and fed it")
	_check(not g.feeds.is_hungry(g.object_by_uid(int(o["uid"]))), "it is fed")
	_done(g)


func test_170_every_farm_action_is_declared_for_helpers_and_vehicles() -> void:
	var kinds: Array = PlayerSystem.JOB_KINDS.duplicate()
	var declared: Array = Actions.kinds()
	kinds.sort()
	declared.sort()
	_eq(declared, kinds, "data/actions.json lists exactly the farmer's job kinds")
	var vehicle_jobs := ["plow", "plant", "harvest", "all"]
	for k in Actions.kinds():
		var a: Dictionary = Actions.all()[k]
		_check(Actions.is_shared(k) or str(a.get("reason", "")) != "", "%s is shared, or says why it is not" % k)
		for h: String in a.get("helpers", []):
			_check(GameState.HELPERS.has(h), "%s names a real helper (%s)" % [k, h])
		for j: String in a.get("vehicles", []):
			_check(j in vehicle_jobs, "%s names a real vehicle job (%s)" % [k, j])
	for h: String in GameState.HELPERS:
		_check(not Actions.for_helper(h).is_empty(), "the %s helper does something" % h)
	for id in Game.item_order:
		var it := Game.item_data(id)
		if str(it.get("kind", "")) == "vehicle":
			var covered := false
			for k in Actions.kinds():
				if str(it["job"]) in Actions.vehicle_jobs(k):
					covered = true
			_check(covered, "%s's job is a declared action" % id)


func test_171_feed_stock_and_what_a_home_was_fed_are_saved() -> void:
	var g := _feed_farm()
	var o := _animal(g)
	g.feeds.add("grain")
	g.feeds.add("greens", true)
	g.feeds.feed(int(o["uid"]), "grain", "rare")
	var data := {}
	g.feeds.save_to(data)
	var h := _feed_farm()
	h.feeds.load_from(data)
	_eq(h.feeds.count("greens", true), 1, "stock comes back")
	var back := g.object_by_uid(int(o["uid"]))
	_check(not g.feeds.effect_of(back).is_empty(), "the object keeps what it was fed (its own field)")
	_check(g.feeds.rare_multiplier(back) > 1.0, "and the rare boost")
	_done(g)
	_done(h)
