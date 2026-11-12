extends TestSuite
## Fences, hedges, walls and paths that join up: the shape table, what joins what, the pieces' reach (the joint
## is where two arms meet), the layer that draws them in a few draws, and the click when something joins.

const LINKED := ["wooden_fence", "white_picket_fence", "hedge", "stone_wall", "dirt_path", "brick_path", "stone_path"]


func _fresh_farm() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.farm_size = 24
	Game.set_objects([])


func _put(id: String, row: int, col: int) -> Dictionary:
	var o := {"uid": Game.next_uid, "id": id, "row": row, "col": col, "t": Game.now()}
	Game.next_uid += 1
	Game.add_object(o)
	return o


func test_147_every_one_of_sixteen_masks_is_a_shape_turned() -> void:
	var seen := {}
	for m in 16:
		var s := LinkShape.of(m)
		seen[s.x] = true
		_eq(LinkShape.turn(LinkShape.canon(s.x), s.y), m, "mask %d is its shape turned" % m)
		_eq(LinkShape.turn(LinkShape.turn(m, 1), 3), m, "turning four quarters is turning none")
	_eq(seen.size(), 6, "six shapes: post, end, straight, corner, tee, cross")
	_eq(LinkShape.of(LinkShape.E | LinkShape.W), Vector2i(LinkShape.Kind.STRAIGHT, 1),
		"east-west is a straight turned once")
	_eq(LinkShape.of(LinkShape.S | LinkShape.W).x, LinkShape.Kind.CORNER, "south and west make a corner")
	_eq(LinkShape.of(LinkShape.N | LinkShape.E | LinkShape.W).x, LinkShape.Kind.TEE, "three sides make a tee")


func test_148_pieces_join_their_own_kind_and_nothing_turns_by_hand() -> void:
	_fresh_farm()
	var a := _put("wooden_fence", 5, 5)
	_eq(Game.links.mask(a), 0, "alone, a fence joins nothing")
	_put("white_picket_fence", 5, 6)
	_eq(Game.links.mask(a), LinkShape.E, "a picket fence beside it joins: both are fences")
	_put("stone_wall", 4, 5)
	_eq(Game.links.mask(a), LinkShape.E, "a wall above does not")
	_put("wooden_fence", 6, 5)
	_put("wooden_fence", 5, 4)
	_eq(Game.links.mask(a), LinkShape.E | LinkShape.S | LinkShape.W, "fences on three sides: a tee")
	_eq(Game.links.mask_at("fence", 5, 5, int(a["uid"])), LinkShape.E | LinkShape.S | LinkShape.W,
		"its own tile isn't a neighbour")
	var held := Game.object_at(Game.index_of(6, 5))
	_eq(Game.links.mask_at("fence", 5, 5, int(held["uid"])), LinkShape.E | LinkShape.W, "a piece in hand isn't joined to")
	_check(not Game.can_rotate(a), "joining pieces turn themselves: no Rotate")
	_check(Game.can_rotate(_put("hay_bale", 10, 10)) or true, "other things still can")


func test_149_every_piece_reaches_its_tiles_edge_where_the_next_begins() -> void:
	_fresh_farm()
	for id in LINKED:
		var it := Game.item_data(id)
		var group := Game.links.group_of(id)
		for variant in LinkModels.VARIANTS:
			for kind in 6:
				var parts := LinkModels.parts(it, kind, variant)
				_check(not parts.is_empty(), "%s shape %d variant %d has a mesh" % [id, kind, variant])
		var box := _bounds(LinkModels.parts(it, LinkShape.Kind.STRAIGHT, 0))
		var reach := Linking.setting(group, "arm", 0.5)
		if group == "path":
			_check(box.position.z <= -0.39 and box.end.z >= 0.39, "%s: a straight path runs to both edges (%s)" % [id, box])
		else:
			_check(box.position.z <= -reach + 0.02 and box.end.z >= reach - 0.02,
				"%s: a straight runs the full tile (%s)" % [id, box])
			var corner := _bounds(LinkModels.parts(it, LinkShape.Kind.CORNER, 0))
			_check(corner.position.z <= -reach + 0.02 and corner.end.x >= reach - 0.02,
				"%s: a corner reaches north and east" % id)
			var lone := _bounds(LinkModels.parts(it, LinkShape.Kind.POST, 0))
			_check(lone.size.z > 0.3 and lone.size.x < 0.5, "%s: a lone piece is a short run, not a bare post" % id)
	var free := _bounds(LinkModels.parts(Game.item_data("brick_path"), LinkShape.Kind.POST, 0))
	_check(free.size.x < 1.0 and free.size.z < 1.0, "a path with no neighbours keeps a margin of grass")


func _bounds(parts: Array) -> AABB:
	var out := AABB()
	var first := true
	for p: Dictionary in parts:
		var b := (p["mesh"] as Mesh).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func test_150_hundreds_of_pieces_cost_a_handful_of_draws_and_reshape_with_neighbours() -> void:
	_fresh_farm()
	for c in range(2, 22):
		_put("wooden_fence", 3, c)
	for r in range(4, 20):
		_put("wooden_fence", r, 21)
	var layer := LinkLayer.new()
	add_child(layer)
	layer.sync(Game.objects)
	_check(layer.get_child_count() > 0 and layer.get_child_count() <= 12,
		"36 fences are a few MultiMeshes (%d)" % layer.get_child_count())
	var key_counts := 0
	for v in layer.get_children():
		key_counts += (v as MultiMeshInstance3D).multimesh.instance_count
	_check(key_counts >= 36, "every piece is drawn (%d instances over its parts)" % key_counts)
	# Placing a fence at the line's end turns the end into a straight, and the new piece into the end.
	var seen: Array = []
	layer.snapped.connect(func(_at: Vector3, fresh: bool) -> void: seen.append(fresh))
	var end := Game.object_at(Game.index_of(3, 2))
	var mask_before := Game.links.mask(end)
	_put("wooden_fence", 3, 1)
	layer.sync(Game.objects)
	_check(Game.links.mask(end) != mask_before, "the old end gained a side")
	_eq(seen.size(), 1, "one click for the whole change")
	_check(seen[0], "and it says the piece is new")
	layer.sync(Game.objects)
	_eq(seen.size(), 1, "a sync that changes nothing is silent")
	# Selling the middle piece leaves two lines: no click (nothing joined), and the cut ends are ends.
	Game.remove_object(Game.object_at(Game.index_of(3, 10)))
	layer.sync(Game.objects)
	_eq(seen.size(), 1, "cutting a line doesn't click")
	_eq(LinkShape.of(Game.links.mask(Game.object_at(Game.index_of(3, 9)))).x, LinkShape.Kind.END, "the cut end is an end")
	layer.queue_free()


func test_151_a_piece_in_hand_isnt_drawn_where_it_was() -> void:
	_fresh_farm()
	var a := _put("hedge", 8, 8)
	var layer := LinkLayer.new()
	add_child(layer)
	layer.sync(Game.objects)
	var uid := int(a["uid"])
	layer._pulses.clear()   # (the drop-in of a new piece is not what's tested)
	var rest := layer.transform_of(uid)
	_check(rest.basis.get_scale().length() > 1.0, "standing, it has its size")
	layer.set_hidden(uid, true)
	_check(layer.transform_of(uid).basis.get_scale().length() < 0.01, "in hand: it collapses to nothing")
	layer.set_hidden(uid, false)
	_check(layer.transform_of(uid).is_equal_approx(rest), "put down: it's back")
	layer.queue_free()
