extends TestSuite
## Picking things up and dropping them: what is carried is offered only to the buildings that will take it now
## (finished, of the right kind, with room), never to an unbuilt, broken or full one; a drop that can't happen
## sends what was lifted back where it came from. The building rules are worked out from the catalog's own data,
## so a new home is covered without a new test.

const FIT := HousingSystem.Fit


func _finished(id: String, uid: int) -> Dictionary:
	return {"uid": uid, "id": id, "row": 20, "col": 20, "t": 0, "level": 1, "inside": {}}


func test_201_every_home_takes_what_it_holds_only_when_finished_with_room() -> void:
	var g := _farm()
	var pairs := 0
	for id: String in g.items:
		var def := g.catalog.get_def(id) as BuildingDef
		if def == null or def.stores_anything():
			continue
		for item: String in g.items:
			var loose := {"uid": 7001, "id": item, "row": 0, "col": 0, "t": 0}
			if not def.accepts(item, str(g.item_data(item).get("kind", ""))) or g.is_building(loose):
				continue
			pairs += 1
			var home := _finished(id, 7000)
			_eq(g.homes.fit(home, item, {"uid": 7001}), FIT.FITS, "a finished %s takes a %s" % [id, item])
			var frame := _finished(id, 7000)
			frame["construction"] = {}
			_check(g.homes.fit(frame, item, {"uid": 7001}) != FIT.FITS, "an unbuilt %s takes no %s" % [id, item])
			if not g.is_one_each(home, item):
				home["inside"] = {item: g.capacity(home)}
				_check(g.homes.fit(home, item, {"uid": 7001}) != FIT.FITS, "a full %s takes no %s" % [id, item])
	_check(pairs >= 10, "many home and kind pairs were checked (%d)" % pairs)
	_done(g)


func test_202_the_barn_takes_things_only_once_it_is_repaired() -> void:
	var g := _farm()
	var barn := g.storage.barn()
	_check(barn.get("broken", false), "the barn starts broken")
	var samples := {}
	for id: String in g.items:
		var kind := str(g.item_data(id).get("kind", ""))
		if not samples.has(kind) and not g.catalog.get_def(id) is CropDef:
			samples[kind] = id
	for kind: String in ["tree", "animal", "decor"]:
		_check(samples.has(kind), "the catalog has a %s" % kind)
		g.set_objects(g.objects.filter(func(o: Dictionary) -> bool: return o["id"] == "barn"))
		g.add_object({"uid": 7100, "id": samples[kind], "row": 3, "col": 3, "t": 0})
		_eq(g.homes.fit(barn, samples[kind], {"uid": 7100}), FIT.BARN_BROKEN, "a broken barn takes no %s" % kind)
	barn.erase("broken")
	for kind: String in ["tree", "animal", "decor"]:
		g.set_objects(g.objects.filter(func(o: Dictionary) -> bool: return o["id"] == "barn"))
		g.add_object({"uid": 7100, "id": samples[kind], "row": 3, "col": 3, "t": 0})
		_eq(g.homes.fit(barn, samples[kind], {"uid": 7100}), FIT.FITS, "a repaired barn takes a %s" % kind)
	g.add_object({"uid": 7101, "id": "cow_shed", "row": 9, "col": 9, "t": 0, "level": 1, "inside": {}})
	_eq(g.homes.fit(barn, "cow_shed", {"uid": 7101}), FIT.WRONG_KIND, "but not a building")
	_done(g)


## Needs real frames and the real scene, so the runner awaits it.
func test_203_a_drop_on_a_home_that_cannot_take_it_sends_the_thing_back() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: FarmGrid = main.get("grid")
	var world: Farm3D = main.get("world_3d")
	var barn := Game.storage.barn()
	_check(barn.get("broken", false), "the barn is broken")
	_check(Game.place_somewhere("cow"), "a cow is on the farm")
	var cow: Dictionary = Game.objects[-1]
	var uid := int(cow["uid"])
	var at := Vector2i(int(cow["row"]), int(cow["col"]))
	await get_tree().process_frame
	# Lifted, and carried over the broken barn: it is not offered, and letting go sends the cow back.
	grid.start_placing("cow", uid)
	var over := _screen_of(world, barn)
	grid.placement.input(_touch(over, false))
	_eq(int(grid.placing.get("home", -2)), -1, "a broken barn is not a target")
	_eq(int(grid.placing.get("refused", -1)), int(barn["uid"]), "but it is known to be the one under the finger")
	grid.placement.input(_touch(over, true))
	_check(grid.placing.is_empty(), "letting go empties the hand")
	_eq(Game.storage.stored.size(), 0, "nothing was stored")
	_eq([int(Game.object_by_uid(uid)["row"]), int(Game.object_by_uid(uid)["col"])], [at.x, at.y],
		"the cow is where it was")
	# The barn mended, the same drop stores it.
	barn.erase("broken")
	await get_tree().process_frame
	grid.start_placing("cow", uid)
	grid.placement.input(_touch(over, false))
	_eq(int(grid.placing.get("home", -1)), int(barn["uid"]), "a repaired barn is a target")
	_check(grid.outliner.is_valid() and grid.outliner.call(int(barn["uid"])).size() >= 4, "with an outline to light")
	grid.placement.input(_touch(over, true))
	_check(grid.placing.is_empty(), "the hand is empty")
	_check(Game.object_by_uid(uid).is_empty(), "the cow has left the farm")
	_eq(Game.storage.stored.size(), 1, "and is in the barn")
	main.free()


func _screen_of(world: Farm3D, building: Dictionary) -> Vector2:
	var fp := Game.footprint(building["id"])
	return world.camera.unproject_position(
		Vector3(int(building["col"]) + fp.x / 2.0, 0.3, int(building["row"]) + fp.y / 2.0))


func _touch(pos: Vector2, released: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.pressed = not released
	e.position = pos
	return e
