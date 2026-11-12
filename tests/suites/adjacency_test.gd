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
	_check(g.buy_and_place("chicken_coop", row, col), "coop bought at %d,%d" % [row, col])
	return g.object_at(g.index_of(row, col))


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
	var a := _coop(g, 11, 11)
	_eq(g.adjacency.count(a), 0, "alone: no neighbour")
	var b := _coop(g, 11, 14)           # shares an edge with a
	var far := _coop(g, 11, 18)         # a column of grass between: not touching
	_eq(g.adjacency.count(a), 1, "a touches b")
	_eq(g.adjacency.count(b), 1, "b touches a")
	_eq(g.adjacency.count(far), 0, "a gap breaks it")
	_check(g.buy_and_place("rabbit_hutch", 13, 11), "hutch bought below a")
	_eq(g.adjacency.count(a), 1, "another kind of home is not a neighbour")
	_check(absf(g.adjacency.coin_multiplier(a) - 1.1) < 0.0001, "one neighbour is +10%")


func test_174_the_bonus_is_capped_and_a_piece_in_hand_does_not_count() -> void:
	var g := _synergy_farm()
	var mid := _coop(g, 12, 12)
	_coop(g, 12, 15)
	_coop(g, 12, 9)
	_coop(g, 14, 12)
	var top := _coop(g, 10, 12)
	_eq(g.adjacency.neighbours_at("chicken_coop", 12, 12, int(mid["uid"])).size(), 4, "four around")
	_check(g.buy_and_place("chicken_coop", 14, 15), "fifth home")
	_eq(g.adjacency.count(mid), 4, "the cap is four neighbours")
	_check(absf(g.adjacency.coin_multiplier(mid) - 1.4) < 0.0001, "capped at +40%")
	_eq(g.adjacency.count_at("chicken_coop", 12, 12, int(top["uid"])), 4, "ignoring a piece in hand")
	var lone := g.adjacency.neighbours_at("chicken_coop", 12, 12, int(top["uid"]))
	_check(not int(top["uid"]) in lone, "the lifted piece is not a neighbour")


func test_175_a_collect_pays_the_bonus_and_it_can_be_switched_off() -> void:
	var g := _synergy_farm()
	g.feeds.active = false
	var a := _coop(g, 11, 11)
	_coop(g, 11, 14)
	a["inside"] = {"chicken": 3}
	g.debug_time_offset += g.cycle_of(a) + 1
	var base := g.object_payout(a).x
	var before := g.coins
	_check(not g.collect(int(a["uid"])).is_empty(), "collected")
	_eq(g.coins - before, roundi(base * 1.1), "a touching neighbour pays +10%")
	Balance.override("synergy.enabled", 0)
	_check(absf(g.adjacency.coin_multiplier(a) - 1.0) < 0.0001, "off: no bonus")
	Balance.reload()
