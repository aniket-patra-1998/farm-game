extends TestSuite
## The farmer and their queue of work (PlayerSystem).


func test_117_work_is_queued_and_the_farmer_walks_to_it() -> void:
	# FarmVille: a tap queues the job; it happens (and is paid for) when the farmer has walked there and
	# worked at it, one job after another.
	var g := _farm()
	g.coins = 1000
	g.farm_size = GameState.MAX_SIZE
	var p := g.player
	p.pos = Vector2(2.5, 20.5)
	var done: Array = []
	p.action_done.connect(func(job: Dictionary, result: Dictionary) -> void: done.append([job["kind"], result]))
	var far := g.index_of(20, 9)
	var near := g.index_of(20, 10)
	_eq(p.enqueue({"kind": "plow", "plot": far}), PlayerSystem.Refused.NONE, "a plow job is queued")
	_eq(p.enqueue({"kind": "plow", "plot": near}), PlayerSystem.Refused.NONE, "and another behind it")
	_eq(g.field.phase(far), GameState.Phase.GRASS, "nothing happens at the tap")
	_eq(g.coins, 1000, "and nothing is paid yet")
	_eq(p.queued_plots().size(), 2, "both plots show as waiting")
	p.advance(0.5)
	_check(p.is_walking(), "the farmer is on the way")
	_check(p.pos.x > 2.5 and p.pos.x < 9.0, "part of the way there after half a second")
	p.advance(6.5 / PlayerSystem.WALK_SPEED)
	_check(p.is_working(), "then at the plot, working")
	_eq(g.field.phase(far), GameState.Phase.GRASS, "not done until the work is")
	p.advance(PlayerSystem.ACTION_SECONDS)
	_eq(g.field.phase(far), GameState.Phase.PLOWED, "the first plot is plowed")
	_eq(g.coins, 1000 - Balance.i("economy.plow_cost"), "and paid for then")
	_eq(done.size(), 1, "its completion is announced")
	p.advance(10.0)
	_eq(g.field.phase(near), GameState.Phase.PLOWED, "the second follows")
	_check(p.queue.is_empty() and not p.is_working() and not p.is_walking(), "and the farmer rests")
	_check(p.pos.distance_to(Vector2(10.5, 20.5)) < 0.6, "standing at the last plot's edge")
	_done(g)


func test_118_the_farmer_walks_round_things_and_works_from_where_they_stand_if_boxed_in() -> void:
	var g := _farm()
	g.coins = 100000
	g.farm_size = GameState.MAX_SIZE
	var p := g.player
	p.pos = Vector2(20.5, 20.5)
	# A wall of hay bales between the farmer and the plot: the walk goes round its end.
	for r in range(17, 24):
		_check(g.buy_and_place("hay_bale", r, 22), "a bale at row %d" % r)
	p.enqueue({"kind": "plow", "plot": g.index_of(20, 24)})
	var walked := 0.0
	var crossed_wall := false
	while p.queue.size() > 0 and walked < 20.0:
		p.advance(0.05)
		walked += 0.05
		if int(p.pos.x) == 22 and int(p.pos.y) >= 17 and int(p.pos.y) < 24:
			crossed_wall = true
	_eq(g.field.phase(g.index_of(20, 24)), GameState.Phase.PLOWED, "the plot beyond the wall is plowed")
	_check(not crossed_wall, "without walking through the bales")
	_check(walked > 4.0 / PlayerSystem.WALK_SPEED + PlayerSystem.ACTION_SECONDS, "by the long way round")
	# Boxed in on every side (FarmVille's fenced-in farmer): the work is done from where they stand.
	p.pos = Vector2(26.5, 26.5)
	for cell: Vector2i in [Vector2i(25, 25), Vector2i(25, 26), Vector2i(25, 27), Vector2i(26, 25), Vector2i(26, 27),
			Vector2i(27, 25), Vector2i(27, 26), Vector2i(27, 27)]:
		_check(g.buy_and_place("hay_bale", cell.x, cell.y), "boxed in at %s" % cell)
	p.enqueue({"kind": "plow", "plot": g.index_of(27, 14)})
	p.advance(PlayerSystem.ACTION_SECONDS + 0.01)
	_eq(g.field.phase(g.index_of(27, 14)), GameState.Phase.PLOWED, "a boxed-in farmer plows at once")
	_eq(p.pos, Vector2(26.5, 26.5), "without moving")
	# Something put down on the farmer: they step out to the nearest free tile.
	p.pos = Vector2(15.5, 15.5)
	g.buy_and_place("hay_bale", 15, 15)
	p.advance(0.01)
	_check(not g.is_occupied(g.index_of(int(p.pos.y), int(p.pos.x))), "the farmer steps off a tile that's built on")
	_done(g)


func test_119_the_queue_refuses_what_cannot_be_done_or_paid_for_and_jobs_can_be_cancelled() -> void:
	var g := _farm()
	var p := g.player
	g.farm_size = GameState.MAX_SIZE
	var a := g.index_of(20, 3)
	var b := g.index_of(20, 4)
	g.coins = Balance.i("economy.plow_cost")
	_eq(p.enqueue({"kind": "harvest", "plot": a}), PlayerSystem.Refused.NOTHING_TO_DO, "grass can't be harvested")
	_eq(p.enqueue({"kind": "plow", "plot": a}), PlayerSystem.Refused.NONE, "one plow is affordable")
	_eq(p.enqueue({"kind": "plow", "plot": a}), PlayerSystem.Refused.QUEUED, "a plot takes one job at a time")
	_eq(p.enqueue({"kind": "plow", "plot": b}), PlayerSystem.Refused.COINS,
		"a second can't be paid for with the first still owed")
	_check(p.cancel({"kind": "plow", "plot": a}), "a waiting job can be cancelled")
	_check(p.queue.is_empty() and not p.cancel({"kind": "plow", "plot": a}), "and then it's gone")
	p.advance(5.0)
	_eq(g.field.phase(a), GameState.Phase.GRASS, "a cancelled job never happens")
	_eq(g.coins, Balance.i("economy.plow_cost"), "or costs anything")
	# A job whose work has gone by the time the farmer arrives reports nothing done.
	var results: Array = []
	p.action_done.connect(func(_job: Dictionary, result: Dictionary) -> void: results.append(result))
	p.enqueue({"kind": "plow", "plot": a})
	g.field.plow(a)
	g.coins = 0
	p.advance(20.0)
	_check(results.size() == 1 and results[0].is_empty(), "an overtaken job reports an empty result")
	g.coins = 1000000
	for k in PlayerSystem.QUEUE_MAX + 5:
		p.enqueue({"kind": "plow", "plot": g.index_of(22 + k / 10, k % 10)})
	_eq(p.queue.size(), PlayerSystem.QUEUE_MAX, "the queue fills to its limit and no further")
	# The farmer is saved (name, look, place); the queue is not.
	p.clear_queue()
	p.farmer_name = "Asha"
	p.farm_name = "Mango Acres"
	p.look["hat"] = "cap"
	p.pos = Vector2(4.5, 7.5)
	p.enqueue({"kind": "plow", "plot": b})
	var data := {}
	p.save_to(data)
	var back: Dictionary = JSON.parse_string(JSON.stringify(data))
	p.reset()
	p.load_from(back)
	_eq(p.farmer_name, "Asha", "the farmer's name is saved")
	_eq(p.farm_name, "Mango Acres", "and the farm's")
	_eq(str(p.look["hat"]), "cap", "and their look")
	_eq(p.pos, Vector2(4.5, 7.5), "and where they stand")
	_check(p.queue.is_empty(), "but not the queue")
	_done(g)


func test_120_one_search_finds_the_nearest_side_and_the_grid_follows_every_move() -> void:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 10, 10)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(0, 9):
		grid.set_point_solid(Vector2i(5, y), true)          # a wall with a gap at the bottom
	var goals: Array[Vector2i] = [Vector2i(9, 0), Vector2i(4, 0), Vector2i(6, 9)]
	var way := PlayerSystem._nearest_way(grid, Vector2i(0, 0), goals)
	_eq(way[-1], Vector2i(4, 0), "the nearest reachable goal is chosen")
	_eq(way.size(), 5, "by the fewest steps")
	var round := PlayerSystem._nearest_way(grid, Vector2i(0, 0), [Vector2i(9, 0)] as Array[Vector2i])
	_check(round.has(Vector2i(5, 9)), "a goal behind the wall is reached through the gap")
	for k in range(1, round.size()):
		_check(not grid.is_point_solid(round[k]), "never through the wall")
	grid.set_point_solid(Vector2i(5, 9), true)
	_check(PlayerSystem._nearest_way(grid, Vector2i(0, 0), [Vector2i(9, 0)] as Array[Vector2i]).is_empty(),
		"no way at all gives nothing")
	# The walking grid follows a move that leaves the number of objects the same.
	var g := _farm()
	g.coins = 100000
	g.buy_and_place("hay_bale", 2, 2)
	var p := g.player
	_check(p._walkable().is_point_solid(Vector2i(2, 2)), "the hay bale's tile is solid")
	var to := g.nearest_free_spot("hay_bale", 6, 6)
	_check(g.move_object(int(g.object_at(g.index_of(2, 2))["uid"]), to.x, to.y), "moved")
	_check(not p._walkable().is_point_solid(Vector2i(2, 2)), "its old tile is free again")
	_check(p._walkable().is_point_solid(Vector2i(to.y, to.x)), "its new tile is solid")
	_done(g)
