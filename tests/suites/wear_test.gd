extends TestSuite
## Building wear and climbing upgrade prices (docs/WEAR.md, our own addition; owner, 19 Nov): wear gathers with
## time as rust does, costs each kind of building something of its work, stops it at the last level, and a
## repair (coins and the building's own materials, at most 40% of what it cost) takes it off.

const DAY := 86400


## A farm past its first weeks, with coins and materials to spare.
func _grown_farm() -> GameState:
	var g := _farm()
	g.born_day = g.day_number() - 60
	g.coins = 1000000
	g.xp = g.xp_for_level(30)
	for m: String in ["bricks", "nails", "boards"]:
		g.parts[m] = 500
	return g


func _place(g: GameState, id: String, row: int, col: int, extra := {}) -> Dictionary:
	var o := {"uid": g.next_uid, "id": id, "row": row, "col": col, "level": 1, "inside": {}, "t": g.now()}
	o.merge(extra, true)
	g.next_uid += 1
	g.add_object(o)
	g.objects_updated()
	return g.object_by_uid(int(o["uid"]))


## Sets building `o`'s wear to `level` (just past it), from now.
func _wear(g: GameState, o: Dictionary, level: int) -> void:
	g.wear.buildings[str(o["uid"])] = {"w": level * Balance.f("wear.level_days") * DAY + 60.0, "t": g.now(),
		"p": 1.0, "fix": 0}


func test_587_a_building_wears_with_time_faster_when_bigger_never_while_young() -> void:
	var g := _grown_farm()
	var coop := _place(g, "chicken_coop", 4, 4)
	var days := Balance.i("wear.level_days")
	_eq(g.wear.max_level(), 5, "five levels of wear")
	_eq(g.wear.level_of(coop), 0, "a new coop is like new")
	_skip(g, days * DAY - 60)
	_eq(g.wear.level_of(coop), 0, "not yet")
	_skip(g, 120)
	_eq(g.wear.level_of(coop), 1, "a level in %d days" % days)
	_check(g.wear.needs_repair(coop), "it wants a repair")
	g.land.upgrade_building(int(coop["uid"]))
	_eq(g.level_of(coop), 2, "grown a size")
	_eq(g.wear.level_of(coop), 1, "growing keeps its wear")
	_skip(g, int(days * DAY / (1.0 + Balance.f("wear.size_faster"))) + 60)
	_eq(g.wear.level_of(coop), 2, "a bigger coop wears faster")
	_skip(g, 400 * DAY)
	_eq(g.wear.level_of(coop), 5, "never past the last level")
	_check(g.wear.stopped(coop), "where it stops")
	# A young farm wears nothing in its first weeks.
	var y := _farm()
	var young := _place(y, "chicken_coop", 4, 4)
	_skip(y, (Balance.i("wear.grace_days") - 1) * DAY)
	_eq(y.wear.level_of(young), 0, "a young farm's buildings don't wear")
	_skip(y, (days + 1) * DAY)
	_eq(y.wear.level_of(young), 1, "after its first weeks they do")
	# Decor never wears; the Barn (storage) does.
	_check(not g.wear.wears({"uid": 0, "id": "windmill"}), "decor never wears")
	_eq(g.building_def("barn").wear_kind(), "storage", "the Barn wears as storage")
	_eq(g.building_def("bakery").wear_kind(), "crafting", "a Bakery as crafting")
	_eq(g.building_def("garage").wear_kind(), "garage", "the Garage as a Garage")
	_eq(g.building_def("dog_house").wear_kind(), "home", "the Dog House as a home")
	_done(g)
	_done(y)


func test_588_a_worn_home_gives_less_and_a_worn_out_one_nothing() -> void:
	var g := _grown_farm()
	var cycle := int(g.item_data("chicken_coop").get("cycle_seconds", DAY))
	var coop := _place(g, "chicken_coop", 4, 4, {"inside": {"chicken": 10}})
	coop["t"] = g.now() - cycle - 10
	_check(is_equal_approx(g.wear.goods_factor(coop), 1.0), "like new: its full pay")
	_wear(g, coop, 2)
	_check(is_equal_approx(g.wear.goods_factor(coop), 1.0 - 2 * Balance.f("wear.goods_less")), "worn twice: less")
	_check(not g.collect(int(coop["uid"])).is_empty(), "a worn coop still collects")
	_wear(g, coop, 5)
	coop["t"] = g.now() - cycle - 10
	_check(g.collect(int(coop["uid"])).is_empty(), "worn out: nothing")
	_done(g)


func test_589_a_worn_crafting_building_crafts_slower_and_worn_out_starts_nothing() -> void:
	var g := _grown_farm()
	var bakery := _place(g, "bakery", 4, 4, {"slots": []})
	_check(is_equal_approx(g.wear.craft_factor(bakery), 1.0), "like new: its own time")
	_wear(g, bakery, 3)
	_check(is_equal_approx(g.wear.craft_factor(bakery), 1.0 + 3 * Balance.f("wear.craft_slower")), "worn: slower")
	_wear(g, bakery, 5)
	var rid := g.crafting.recipes_of("bakery")[0].id
	_eq(g.crafting.craft_problem(int(bakery["uid"]), rid), tr("WEAR_STOPPED"), "worn out: starts nothing")
	_done(g)


func test_590_a_worn_out_garage_keeps_no_rust_off() -> void:
	var g := _grown_farm()
	g.buy_and_place("tractor", 11, 0)
	var garage := _place(g, "garage", 4, 0)
	var tractor: Dictionary = g.objects.filter(func(o: Dictionary) -> bool: return o["id"] == "tractor")[0]
	g.homes.put_in_home(int(garage["uid"]), "tractor", {"uid": int(tractor["uid"])})
	_wear(g, g.object_by_uid(int(garage["uid"])), 5)
	var start := g.rust.gathered("tractor")
	_skip(g, DAY)
	_check(is_equal_approx(g.rust.gathered("tractor") - start, DAY * Balance.f("rust.outside_rate")),
		"rusts as fast as outside")
	_done(g)


func test_591_worn_storage_holds_less_throws_nothing_out_and_spoils_late() -> void:
	var g := _grown_farm()
	var barn := g.storage.barn()
	_check(not barn.is_empty(), "the farm has its Barn")
	var room := g.storage.barn_capacity()
	var feed_room := g.feeds.cap()
	_wear(g, barn, 2)
	_eq(g.storage.barn_capacity(), floori(room * (1.0 - 2 * Balance.f("wear.room_less"))), "less room")
	_check(g.feeds.cap() < feed_room, "less room for feed")
	g.feeds.stock = {"corn": 100}
	g.wear.spoil_t = g.now()
	_skip(g, DAY)
	_eq(g.wear.spoil(), 0, "below the spoiling level nothing spoils")
	_eq(int(g.feeds.stock["corn"]), 100, "and nothing is thrown out")
	_wear(g, barn, Balance.i("wear.spoil_from"))
	_skip(g, 5 * DAY)
	var lost := g.wear.spoil()
	_eq(lost, floori(100 * Balance.f("wear.spoil_share") * 5), "a little spoils a day")
	_eq(int(g.feeds.stock["corn"]), 100 - lost, "taken from the stock")
	_done(g)


func test_592_a_repair_costs_coins_and_materials_at_most_40_percent() -> void:
	var g := _grown_farm()
	var coop := _place(g, "chicken_coop", 4, 4)
	g.land.upgrade_building(int(coop["uid"]))
	var price := int(g.item_data("chicken_coop")["cost"])
	var size_parts: Dictionary = g.building_def("chicken_coop").size_materials(2)
	_wear(g, coop, 5)
	var cost := g.wear.repair_cost(int(coop["uid"]))
	_check(int(cost["coins"]) <= roundi(price * 0.4 * g.wear.grown()) and int(cost["coins"]) > 0,
		"coins: %d" % int(cost["coins"]))
	_check(g.wear.grown() > 1.0, "a grown farm's repairs cost more")
	for m: String in size_parts:
		_check(int(cost["materials"].get(m, 0)) <= ceili(int(size_parts[m]) * 0.4) and cost["materials"].has(m),
			"its own materials, a share: %s" % m)
	var coins := g.coins
	var bricks := int(g.parts["bricks"])
	_check(g.wear.repair(int(coop["uid"])), "the repair starts")
	_eq(coins - g.coins, int(cost["coins"]), "coins paid")
	_eq(bricks - int(g.parts["bricks"]), int(cost["materials"].get("bricks", 0)), "materials paid")
	_check(g.wear.repairing(int(coop["uid"])), "under repair")
	_skip(g, int(cost["seconds"]) + 1)
	_eq(g.wear.level_of(coop), 0, "like new")
	_check(not g.wear.needs_repair(coop), "nothing more to repair")
	_done(g)


func test_593_upgrades_get_dearer_with_size_and_with_every_upgrade_owned() -> void:
	var g := _grown_farm()
	var coop := _place(g, "chicken_coop", 4, 4)
	var first := g.land.expansion_coins(coop)
	_check(first > 0, "a size up costs coins: %d" % first)
	var bricks := int(g.building_def("chicken_coop").size_materials(2).get("bricks", 0))
	_eq(int(g.land.expansion_needs(coop).get("bricks", 0)), bricks, "a farm with no upgrades: the catalog's")
	var pen := _place(g, "sheep_pen", 8, 4)
	g.land.upgrade_building(int(pen["uid"]))
	_eq(g.land.upgrades_owned(), 1, "one upgrade owned")
	_check(g.land.expansion_coins(coop) > first, "the next upgrade costs more")
	_check(int(g.land.expansion_needs(coop).get("bricks", 0)) >= bricks, "never fewer materials")
	var coins := g.coins
	_check(g.land.upgrade_building(int(coop["uid"])), "it grows")
	_check(coins - g.coins > first, "and its coins were paid")
	_done(g)


func test_594_wear_is_saved() -> void:
	var g := _grown_farm()
	var coop := _place(g, "chicken_coop", 4, 4)
	_wear(g, coop, 3)
	var data := {}
	g.wear.save_to(data)
	g.wear.buildings = {}
	g.wear.load_from(JSON.parse_string(JSON.stringify(data)))
	_eq(g.wear.level_of(coop), 3, "wear survives a save")
	_done(g)
