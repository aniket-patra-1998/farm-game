extends TestSuite
## VIP (docs/VIP.md, our own addition): points and levels, the time it is active, what active VIP multiplies,
## and that it gates and takes away nothing.

const DAY := 86400


## A farm with no VIP yet, whatever its first daily gift would bring.
func _plain_farm() -> GameState:
	var g := _farm()
	g.vip.reset()
	return g


func test_400_points_make_levels_that_are_kept() -> void:
	var g := _plain_farm()
	_eq(g.vip.max_level(), 15, "fifteen VIP levels")
	_eq(g.vip.level(), 0, "no VIP level before the first points")
	_check(not g.vip.active() and is_equal_approx(g.vip.boost(), 1.0), "and nothing is multiplied")
	g.vip.add_points(10)
	_eq(g.vip.level(), 1, "10 points: VIP 1")
	_eq(g.vip.level_for(99), 1, "99 points is still VIP 1")
	_eq(g.vip.level_for(100), 2, "100 points: VIP 2")
	_eq(g.vip.level_for(18000), 15, "18,000 points: the top level")
	_eq(g.vip.level_for(10000000), 15, "and never past it")
	_eq(g.vip.next_level_points(), 100, "the next level's points are told")
	g.vip.points = 18000
	_eq(g.vip.next_level_points(), -1, "at the top there is no next level")
	_skip(g, 400 * DAY)
	_eq(g.vip.level(), 15, "a level is kept for good, long after VIP has lapsed")
	_done(g)


func test_401_logging_in_every_day_brings_more_points_up_to_a_cap() -> void:
	var g := _plain_farm()
	g.daily.last_daily_day = g.day_number() - 5   # (no streak running)
	g.daily.daily_streak = 0
	var got: Array[int] = []
	for day in 7:
		var before := g.vip.points
		g.daily.check_daily_gift()
		got.append(g.vip.points - before)
		_skip(g, DAY)
	_eq(got, [10, 20, 30, 40, 50, 50, 50] as Array[int], "10 more each day in a row, up to 50 a day")
	_skip(g, 2 * DAY)   # (a day missed)
	var before := g.vip.points
	g.daily.check_daily_gift()
	_eq(g.vip.points - before, 10, "a missed day starts again at 10")
	_eq(g.vip.points, 260, "and the points gathered are kept")
	# A free player who logs in every day reaches the top level in about a year.
	var days := 4 + ceili((18000 - 100) / 50.0)
	_check(days > 330 and days < 400, "the top level takes about twelve months of daily logins (%d days)" % days)
	_done(g)


func test_402_a_new_level_brings_three_days_and_more_cost_gems() -> void:
	var g := _plain_farm()
	g.vip.add_points(10)
	_check(g.vip.active(), "reaching VIP 1 turns VIP on")
	_eq(g.vip.seconds_left(), 3 * DAY, "for three days")
	_skip(g, DAY)
	g.vip.add_points(90)
	_eq(g.vip.level(), 2, "VIP 2")
	_eq(g.vip.seconds_left(), 5 * DAY, "its three days are added to the two left")
	_skip(g, 5 * DAY + 1)
	_check(not g.vip.active(), "the time runs out")
	_eq(g.vip.level(), 2, "the level stays")
	_check(is_equal_approx(g.vip.boost(), 1.0), "and nothing is multiplied any more")
	# A week for gems: 5, and 3 more for each level.
	_eq(g.vip.week_cost(), 5 + 3 * 2, "a week at VIP 2 costs 11 gems")
	g.gems = 10
	_check(not g.vip.buy_week(), "not with too few gems")
	g.gems = 30
	_check(g.vip.buy_week(), "bought")
	_eq(g.gems, 19, "the gems are spent")
	_eq(g.vip.seconds_left(), 7 * DAY, "seven days from now, when it had lapsed")
	_check(g.vip.buy_week(), "and another")
	_eq(g.vip.seconds_left(), 14 * DAY, "added to the time left")
	g.vip.points = 18000
	_eq(g.vip.week_cost(), 50, "50 gems a week at the top level")
	var none := _plain_farm()
	none.gems = 100
	_check(not none.vip.buy_week(), "no VIP time before the first VIP level")
	_eq(none.gems, 100, "and no gems taken")
	_done(none)
	_done(g)


func test_403_points_are_bought_with_gems() -> void:
	var g := _plain_farm()
	g.gems = 25
	_check(g.vip.buy_points(10), "10 gems")
	_eq(g.vip.points, 100, "buy 100 VIP points")
	_eq(g.gems, 15, "the gems are spent")
	_eq(g.vip.level(), 2, "two levels at once")
	_eq(g.vip.seconds_left(), 6 * DAY, "each brings its three days")
	_eq(g.vip.gems_to_next_level(), 20, "the next level is 200 points away: 20 gems")
	_check(not g.vip.buy_points(20), "not with too few gems")
	_eq(g.vip.points, 100, "and nothing changes")
	_check(not g.vip.buy_points(0), "nothing for nothing")
	g.vip.points = 18000
	_eq(g.vip.gems_to_next_level(), 0, "nothing to buy towards at the top")
	_done(g)


func test_404_active_vip_multiplies_what_buildings_give() -> void:
	var g := _plain_farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(30)
	g.vip.points = 300   # VIP 3
	g.vip.until = g.now() + DAY
	_check(is_equal_approx(g.vip.boost(), 1.0 + 3.0 / 15.0), "VIP 3 of 15: a fifth of the way from 1 to 2 (%.3f)"
		% g.vip.boost())
	g.vip.points = 18000
	_check(is_equal_approx(g.vip.boost(), 2.0), "the top level: twice")
	_check(is_equal_approx(g.vip.chance(0.1), 0.2), "a chance of 10% becomes 20%")
	_check(is_equal_approx(g.vip.chance(0.8), 1.0), "and never more than certain")
	# Pieces of one kind that touch pay more: twice the bonus.
	_check(g.buy_and_place("chicken_coop", 8, 4) and g.buy_and_place("chicken_coop", 8, 6), "two coops side by side")
	var coop := g.object_at(g.index_of(8, 4))
	var with_vip := g.adjacency.coin_multiplier(coop) - 1.0
	g.vip.until = 0
	var without := g.adjacency.coin_multiplier(coop) - 1.0
	_check(without > 0.0 and is_equal_approx(with_vip, without * 2.0),
		"the layout bonus is doubled (%.2f, %.2f without VIP)" % [with_vip, without])
	# The boosts stocked homes give the farm, caps and all.
	var boosted := 0
	for boost: String in g.boosts.boost_ids():
		g.vip.until = 0
		var plain := g.boosts.total(boost)
		g.vip.until = g.now() + DAY
		_check(is_equal_approx(g.boosts.total(boost), plain * 2.0), "the %s boost is doubled" % boost)
		boosted += 1
	_check(boosted > 0, "there are home boosts to double")
	_done(g)


func test_405_vip_is_saved_and_gates_nothing() -> void:
	var g := _plain_farm()
	g.vip.add_points(650)
	var saved := {}
	g.vip.save_to(saved)
	var other := _plain_farm()
	other.vip.load_from(saved)
	_eq(other.vip.points, 650, "the points are saved")
	_eq(other.vip.until, g.vip.until, "and when it runs out")
	other.vip.load_from({})
	_eq(other.vip.level(), 0, "an older save has no VIP yet")
	other.vip.load_from({"vip_points": -5, "vip_until": -9})
	_check(other.vip.points == 0 and other.vip.until == 0, "a damaged save is mended")
	# Only the farmer's level gates things: a shop item is as buyable with VIP as without.
	g.coins = 1000000
	g.xp = g.xp_for_level(3)
	var can := g.buildings.can_buy("cow_shed").ok()
	g.vip.points = 18000
	g.vip.until = g.now() + DAY
	_eq(g.buildings.can_buy("cow_shed").ok(), can, "VIP unlocks nothing")
	_done(other)
	_done(g)
