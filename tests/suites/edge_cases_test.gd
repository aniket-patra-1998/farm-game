extends TestSuite
## Awkward inputs to the farm's own actions: unknown uids, off-farm tiles, exact and short money, doing a thing twice.
## None of these may crash, charge for nothing, or leave the farm inconsistent.


## A bare farm: the starter animals, buildings and planted plots are cleared away.
func _bare(g: GameState) -> void:
	g.set_objects([])
	for i in g.plots.size():
		g.plots[i] = {"state": "grass"}


func test_195_actions_on_things_that_are_not_there_do_nothing() -> void:
	var g := _farm()
	var objects := g.objects.size()
	var coins := g.coins
	_eq(g.collect(987654), {}, "collecting an unknown uid gives nothing")
	_check(not g.sell_object(987654), "selling an unknown uid is refused")
	_check(not g.move_object(987654, 3, 3), "moving an unknown uid is refused")
	_eq(g.object_by_uid(-1), {}, "uid -1 is no object")
	_eq(g.objects.size(), objects, "no object appeared or vanished")
	_eq(g.coins, coins, "and no money moved")
	_done(g)


func test_196_nothing_can_be_put_off_the_farm_or_on_top_of_something() -> void:
	var g := _farm()
	g.coins = 1_000_000
	g.xp = g.xp_for_level(30)
	_bare(g)
	for t: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(g.farm_size, 0), Vector2i(0, g.farm_size),
			Vector2i(g.farm_size - 1, g.farm_size - 1)]:
		_check(not g.buy_and_place("cow_shed", t.x, t.y), "a Dairy Farm at %s does not fit" % t)
	_eq(g.coins, 1_000_000, "a refused purchase costs nothing")
	_check(g.buy_and_place("chicken_coop", 2, 2), "a coop goes on open grass")
	var uid := int(g.object_at(g.index_of(2, 2))["uid"])
	_check(not g.buy_and_place("chicken_coop", 2, 2), "not on the same tile")
	_check(not g.buy_and_place("chicken_coop", 3, 3), "not on its second tile")
	_check(g.move_object(uid, 2, 2), "moving a thing onto where it already stands is fine")
	_check(not g.move_object(uid, -3, 4), "moving off the farm is refused")
	_eq(int(g.object_by_uid(uid)["row"]), 2, "and it stays where it was")
	_done(g)


func test_197_money_exactly_enough_buys_and_one_short_does_not() -> void:
	var g := _farm()
	_bare(g)
	var price := int(g.item_data("chicken_coop")["cost"])
	g.xp = g.xp_for_level(30)
	g.coins = price - 1
	_check(not g.buy_and_place("chicken_coop", 4, 4), "one coin short is refused")
	_eq(g.coins, price - 1, "and nothing is taken")
	g.coins = price
	_check(g.buy_and_place("chicken_coop", 4, 4), "exactly enough buys")
	_eq(g.coins, 0, "leaving nothing, never below")
	_done(g)


func test_198_a_thing_removed_twice_or_sold_twice_is_only_gone_once() -> void:
	var g := _farm()
	g.coins = 1_000_000
	g.xp = g.xp_for_level(30)
	_bare(g)
	_check(g.buy_and_place("chicken_coop", 5, 5), "a coop is bought")
	var obj := g.object_at(g.index_of(5, 5))
	var uid := int(obj["uid"])
	_check(g.sell_object(uid), "sold")
	var after := g.coins
	_check(not g.sell_object(uid), "selling it again is refused")
	g.remove_object(obj)
	_eq(g.coins, after, "no second payment")
	_check(not g.is_occupied(g.index_of(5, 5)), "its tile is free")
	_done(g)


func test_199_the_farm_stops_growing_at_its_largest_size() -> void:
	var g := _farm()
	g.coins = 999_999_999
	g.gems = 999_999
	g.xp = g.xp_for_level(60)
	var grew := 0
	while g.land.expand(true) and grew < 40:
		grew += 1
	_check(grew < 40, "expansion ends (%d steps)" % grew)
	_check(g.farm_size <= GameState.MAX_SIZE, "never past the plots that exist (%d)" % g.farm_size)
	var coins := g.coins
	_check(not g.land.expand(false), "nothing more to buy")
	_eq(g.coins, coins, "and nothing charged")
	_done(g)


func test_200_a_planted_plot_is_not_built_on_and_a_building_blocks_planting() -> void:
	var g := _farm()
	g.coins = 1_000_000
	g.xp = g.xp_for_level(30)
	_bare(g)
	var i := g.index_of(8, 8)
	g.plots[i] = {"state": "grass"}
	_check(g.field.plow(i), "grass is plowed")
	var crop := ""
	for id: String in g.crops:
		crop = id
		break
	_check(g.field.plant(i, crop), "and planted")
	_check(not g.buy_and_place("chicken_coop", 8, 8), "a coop is not built over a planted plot")
	_check(g.buy_and_place("chicken_coop", 9, 9), "a coop is built beside it")
	_check(not g.field.plant(g.index_of(9, 9), crop), "nothing is planted under the coop")
	_done(g)
