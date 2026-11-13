extends TestSuite
## SpaceFit, the game's rules for fitting things into space: a clear border inside every tile, and things packed
## into a room clear of its edges, of what is already there and of each other, drawn smaller when it is crowded.


func _radii(n: int, r: float) -> Array[float]:
	var out: Array[float] = []
	for i in n:
		out.append(r)
	return out


func test_301_a_roomy_room_holds_everything_at_full_size() -> void:
	var fit := SpaceFit.pack(Rect2(0, 0, 4, 3), [], _radii(3, 0.3), 1)
	_eq((fit["spots"] as Array).size(), 3, "all three are placed")
	_eq(float(fit["size"]), 1.0, "at full size")


func test_302_a_crowd_is_drawn_smaller_then_thinned_out() -> void:
	var room := Rect2(0, 0, 2, 2)
	var few := SpaceFit.pack(room, [], _radii(2, 0.4), 1)
	var many := SpaceFit.pack(room, [], _radii(30, 0.5), 1)
	_check(float(many["size"]) < float(few["size"]), "a crowd is drawn smaller than a pair")
	_check((many["spots"] as Array).size() < 30, "and past the smallest size only as many as fit are placed")
	_check(float(many["size"]) >= SpaceFit.MIN_SIZE, "never smaller than the least allowed")


func test_303_everything_stands_clear_of_edges_taken_ground_and_each_other() -> void:
	var room := Rect2(0.2, 0.2, 3.0, 2.0)
	var taken: Array[Rect2] = [Rect2(0.5, 0.5, 1.2, 1.0)]
	var radii := _radii(6, 0.3)
	var fit := SpaceFit.pack(room, taken, radii, 7)
	var spots: Array = fit["spots"]
	var r := 0.3 * float(fit["size"])
	for i in spots.size():
		var at: Vector2 = spots[i]
		_check(room.grow(0.001).encloses(Rect2(at - Vector2.ONE * r, Vector2.ONE * r * 2.0)),
			"spot %d is inside the room" % i)
		_check(not taken[0].grow(r * SpaceFit.WALL_CLEAR - 0.001).has_point(at), "spot %d is clear of what is taken" % i)
		for j in range(i + 1, spots.size()):
			_check((spots[j] as Vector2).distance_to(at) >= r * 2.0, "spots %d and %d do not overlap" % [i, j])


func test_304_the_same_question_gets_the_same_answer() -> void:
	var a := SpaceFit.pack(Rect2(0, 0, 3, 3), [], _radii(5, 0.3), 9)
	var b := SpaceFit.pack(Rect2(0, 0, 3, 3), [], _radii(5, 0.3), 9)
	_eq(a["spots"], b["spots"], "same places")


func test_305_a_room_too_small_for_one_still_gives_it_a_place() -> void:
	var fit := SpaceFit.pack(Rect2(0, 0, 0.3, 0.3), [], _radii(2, 0.5), 1)
	_eq((fit["spots"] as Array).size(), 1, "one place, inside the room")
	_check(Rect2(0, 0, 0.3, 0.3).grow(0.001).has_point(fit["spots"][0]), "inside the room")


func test_306_a_tile_keeps_a_clear_border_and_a_yard_keeps_off_its_fence() -> void:
	var tile := SpaceFit.tile_room(Vector2i(3, 2))
	_eq(tile.position, Vector2.ONE * SpaceFit.TILE_MARGIN, "the border is inside every side of the footprint")
	_check(tile.end.is_equal_approx(Vector2(3, 2) - Vector2.ONE * SpaceFit.TILE_MARGIN), "on the far sides too")
	_check(tile.encloses(SpaceFit.yard_room(Vector2i(3, 2))), "a yard is inside its tile's room")
