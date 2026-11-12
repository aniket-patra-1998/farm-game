extends TestSuite
## Layout synergies (AdjacencySystem, our own touch): touching pieces of one kind pay more, up to a cap; nothing
## is saved; Balance `synergy.enabled` turns it off.


func _synergy_farm() -> GameState:
	var g := _farm()
	g.coins = 10000000
	g.xp = g.xp_for_level(60)
	g.set_objects([])   # a new farm starts with animals of its own
	return g


func _coop(g: GameState, row: int, col: int) -> Dictionary:
	# Placed directly: the farm's purchase limit (three coops) is another rule, and the cap needs more.
	var o := {"uid": g.next_uid, "id": "chicken_coop", "row": row, "col": col, "t": g.now(), "level": 1, "inside": {}}
	g.next_uid += 1
	g.add_object(o)
	return o


func test_172_every_group_names_real_families_and_sane_numbers() -> void:
	var g := _synergy_farm()
	var fams := {}
	for id in g.item_order:
		fams[str(g.item_data(id).get("family", ""))] = true
	for name: String in g.adjacency._groups:
		var grp: Dictionary = g.adjacency._groups[name]
		_check(not (grp["families"] as Array).is_empty(), "%s lists families" % name)
		for f: String in grp["families"]:
			_check(fams.has(f), "%s: %s is a catalog family" % [name, f])
		_check(float(grp["per_neighbour"]) > 0.0 and float(grp["per_neighbour"]) <= 0.25, "%s share is small" % name)
		_check(int(grp["max_neighbours"]) >= 1, "%s has a cap" % name)


func test_173_only_pieces_of_the_same_kind_that_share_an_edge_count() -> void:
	var g := _synergy_farm()
	var a := _coop(g, 1, 1)
	_eq(g.adjacency.count(a), 0, "alone: no neighbour")
	var b := _coop(g, 1, 4)           # shares an edge with a
	var far := _coop(g, 1, 8)         # a column of grass between: not touching
	_eq(g.adjacency.count(a), 1, "a touches b")
	_eq(g.adjacency.count(b), 1, "b touches a")
	_eq(g.adjacency.count(far), 0, "a gap breaks it")
	_check(g.buy_and_place("rabbit_hutch", 3, 1), "hutch bought below a")
	_eq(g.adjacency.count(a), 1, "another kind of home is not a neighbour")
	_check(absf(g.adjacency.coin_multiplier(a) - 1.1) < 0.0001, "one neighbour is +10%")


func test_174_the_bonus_is_capped_and_a_piece_in_hand_does_not_count() -> void:
	var g := _synergy_farm()
	var mid := _coop(g, 4, 4)
	_coop(g, 4, 7)
	_coop(g, 4, 1)
	_coop(g, 6, 4)
	var top := _coop(g, 2, 4)
	_eq(g.adjacency.neighbours_at("chicken_coop", 4, 4, int(mid["uid"])).size(), 4, "four around")
	_coop(g, 6, 7)   # a fifth, touching the one below
	_eq(g.adjacency.count(mid), 4, "the cap is four neighbours")
	_check(absf(g.adjacency.coin_multiplier(mid) - 1.4) < 0.0001, "capped at +40%")
	_eq(g.adjacency.count_at("chicken_coop", 4, 4, int(top["uid"])), 3, "a piece lifted into the hand stops counting")
	var lone: Array[int] = g.adjacency.neighbours_at("chicken_coop", 4, 4, int(top["uid"]))
	_check(not int(top["uid"]) in lone, "the lifted piece is not a neighbour")


func test_175_a_collect_pays_the_bonus_and_it_can_be_switched_off() -> void:
	var g := _synergy_farm()
	g.feeds.active = false
	var a := _coop(g, 1, 1)
	_coop(g, 1, 4)
	a["inside"] = {"chicken": 3}
	g.debug_time_offset += g.cycle_of(a) + 1
	var base := g.object_payout(a).x
	var before := g.coins
	_check(not g.collect(int(a["uid"])).is_empty(), "collected")
	_eq(g.coins - before, roundi(base * 1.1), "a touching neighbour pays +10%")
	Balance.override("synergy.enabled", 0)
	_check(absf(g.adjacency.coin_multiplier(a) - 1.0) < 0.0001, "off: no bonus")
	Balance.reload()


func _stocked(g: GameState, id: String, row: int, col: int, inside := {"chicken": 1}) -> Dictionary:
	var o := {"uid": g.next_uid, "id": id, "row": row, "col": col, "t": g.now(), "level": 1, "inside": inside}
	g.next_uid += 1
	g.add_object(o)
	return o


func test_176_a_stocked_home_boosts_the_farm_up_to_a_cap() -> void:
	var g := _synergy_farm()
	_check(g.boosts.boost_ids().size() >= 2, "boosts are listed")
	var coop := _stocked(g, "chicken_coop", 1, 1)
	_check(absf(g.boosts.total("feed_chance") - 0.03) < 0.0001, "one stocked home adds its share")
	_check(g.boosts.given_by(coop).has("feed_chance"), "the panel can say what it gives")
	_stocked(g, "chicken_coop", 1, 5)
	_stocked(g, "chicken_coop", 1, 9)
	_stocked(g, "chicken_coop", 4, 1)
	_stocked(g, "chicken_coop", 4, 5)
	_stocked(g, "chicken_coop", 4, 9)
	_stocked(g, "chicken_coop", 7, 1)
	_check(absf(g.boosts.total("feed_chance") - 0.15) < 0.0001, "seven homes stop at the cap")
	_eq(g.boosts.total("nothing"), 0.0, "an unknown boost is zero")


func test_177_an_empty_home_gives_nothing_and_the_switch_turns_it_off() -> void:
	var g := _synergy_farm()
	var empty := _stocked(g, "chicken_coop", 1, 1, {})
	_eq(g.boosts.total("feed_chance"), 0.0, "an empty home gives nothing")
	_check(g.boosts.given_by(empty).is_empty(), "and says nothing")
	_stocked(g, "beehive", 5, 5, {"bee": 1})
	_check(g.boosts.total("golden_luck") > 0.0, "a stocked hive adds golden luck")
	Balance.override("synergy.home_boosts", 0)
	_eq(g.boosts.total("golden_luck"), 0.0, "off: no boost")
	Balance.reload()
