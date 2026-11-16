extends TestSuite
## The game keeps scaling (scaling report, fix 5): the fullest farm and menus of thousands of items
## stay inside fixed budgets, so the game can't quietly stop scaling again. Budgets are for a desktop CI runner
## (a mid-range phone is a few times slower); what is held is how the cost grows, so they are generous.

const OBJECTS := GameState.MAX_SIZE * GameState.MAX_SIZE   # every tile of the largest farm (900) filled
const IN_PLACE_MS := 0.2      # one thing changed where it stands (a tap's collect or feed), each
const WHOLE_MS := 40.0        # a change to what stands where (a move, a purchase) on the whole farm
const COLLECT_MS := 5.0       # a collect, the rule and its telling, on a full farm


## Every tile of the largest farm holding a thing (900; the scaling report's 2,000 can't stand on 30x30 tiles):
## a change to one costs one, not all (Game.object_changed), and a change to the whole farm stays within budget.
func test_368_a_farm_of_thousands_changes_one_thing_at_one_things_cost() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.objects.clear()
	Game.farm_size = GameState.MAX_SIZE
	var uid := 50000
	for k in OBJECTS:
		Game.objects.append({"uid": uid + k, "id": "hay_bale" if k % 2 == 0 else "cow",
			"row": GameState.row_of(k), "col": GameState.col_of(k), "t": Game.now()})
	Game.rebuild_occupancy()
	Game.objects_updated()   # (the farm as set up, told: what stands where is known)
	_eq(Game.objects.size(), OBJECTS, "the farm holds %d things" % OBJECTS)
	var told := [0]
	var count := func(_u: int) -> void: told[0] += 1
	Game.object_changed.connect(count)
	var began := Time.get_ticks_usec()
	for k in 200:
		Game.objects_updated(uid + k * 4)
	var each := (Time.get_ticks_usec() - began) / 1000.0 / 200.0
	_eq(told[0], 200, "each change in place is told for its thing alone")
	_check(each < IN_PLACE_MS, "a change in place costs %.3f ms on %d things" % [each, OBJECTS])
	began = Time.get_ticks_usec()
	Game.objects_updated()
	var whole := (Time.get_ticks_usec() - began) / 1000.0
	_check(whole < WHOLE_MS, "a change to the whole farm costs %.1f ms" % whole)
	var cow := Game.object_by_uid(uid + 1)
	cow["t"] = Game.now() - 999999
	began = Time.get_ticks_usec()
	Game.collect(uid + 1)
	var collect := (Time.get_ticks_usec() - began) / 1000.0
	_check(collect < COLLECT_MS, "collecting from one cow costs %.2f ms" % collect)
	Game.object_changed.disconnect(count)
	Game.reset_game()
