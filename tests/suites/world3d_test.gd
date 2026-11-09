extends TestSuite
## The 3D world: the projection that lines it up with the 2D grid, and the models it's built from.


func test_94_the_3d_world_lines_up_with_the_2d_grid() -> void:
	# Every tile corner and centre maps to the same place both ways.
	for p: Vector2i in [Vector2i(0, 0), Vector2i(3, 7), Vector2i(11, 2), Vector2i(29, 29)]:
		var flat := Vector2((p.y - p.x) * FarmGrid.TILE_W / 2.0, (p.y + p.x) * FarmGrid.TILE_H / 2.0)
		var world := IsoProjection.ground_of(flat)
		_check(world.is_equal_approx(Vector3(p.y, 0, p.x)), "tile corner %s lands on the 3D grid (%s)" % [p, world])
		_check(IsoProjection.grid_of(world).is_equal_approx(flat), "and back")
	# Height rises straight up the screen by HEIGHT_PX a unit.
	_check(IsoProjection.grid_of(Vector3(2, 1, 3)).is_equal_approx(IsoProjection.grid_of(Vector3(2, 0, 3))
		- Vector2(0, IsoProjection.HEIGHT_PX)), "a unit up is HEIGHT_PX up the screen")
	# The camera looks down 30 degrees, turned 45: a tile is twice as wide as tall on screen.
	var cam := Camera3D.new()
	add_child(cam)
	IsoProjection.aim(cam, Vector2(0, 320), 1.0, 720.0)
	var f := -cam.global_transform.basis.z
	_check(f.is_equal_approx(IsoProjection.forward()), "the camera looks along forward()")
	_check(is_equal_approx(asin(-f.y), PI / 6.0), "30 degrees down")
	_check(is_equal_approx(cam.size, 720.0 / IsoProjection.PX_PER_UNIT), "the view is as tall as the screen")
	cam.queue_free()


func test_95_every_thing_on_the_farm_has_a_3d_model() -> void:
	var g := _farm()
	var missing: Array[String] = []
	for id in g.items:
		var it: Dictionary = g.items[id]
		if it.get("kind", "") == "decor" and not DecorModel.IDS.has(id):
			missing.append(id)
	_eq(missing.size(), 0, "every decoration has a 3D model %s" % [missing])
	# Building features are all ones BuildingModel knows how to build.
	var known := ["yard", "silo", "stilts", "ramp", "chimney", "cupola", "loft_door", "stall_doors", "porch", "terrace",
		"nest_boxes", "water_trough", "hay_bales", "beehives", "trees", "pond", "sign", "flowers", "barrels",
		"duck_house"]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BuildingModel.PATH))
	for id in data["buildings"]:
		for f: Dictionary in (data["buildings"][id] as Dictionary).get("features", []):
			_check(known.has(f.get("type")), "%s: feature %s is buildable" % [id, f.get("type")])
	# Every crop shape at every stage makes a mesh with something in it.
	for shape in ["grain", "stalk", "berry", "fruit", "gourd", "root", "leafy", "flower", "spike", "fluff"]:
		for stage in CropModels.STAGES:
			var m := CropModels.mesh(shape, stage)
			_check(m.get_surface_count() == 1 and m.surface_get_array_len(0) > 3, "%s %s has a mesh" % [shape, stage])
	_done(g)


func test_96_models_are_merged_and_face_outwards() -> void:
	# Baking: a building's hundreds of parts become a couple of meshes, without losing a triangle.
	var g := _farm()
	var built := BuildingModel.build(g.item_data("cow_shed"), Vector2i(4, 3))
	var parts := _count_meshes(built)
	var verts := _count_vertices(built)
	var baked := ModelKit.bake(built)
	_check(parts > 40, "the Dairy Farm is built from many parts (%d)" % parts)
	_check(_count_meshes(baked) <= 2, "and drawn as at most two meshes (%d)" % _count_meshes(baked))
	_eq(_count_vertices(baked), verts, "with every vertex kept")
	baked.free()
	# MeshBuilder winds every triangle so its front faces along its normal (Godot: clockwise from outside).
	var mb := MeshBuilder.new()
	mb.box(Transform3D(Basis.IDENTITY, Vector3.ZERO), Color.WHITE)
	mb.ellipsoid(Vector3(2, 0, 0), Vector3(0.5, 0.3, 0.4), Color.WHITE)
	mb.blade(Vector3.ZERO, Vector3(0, 1, 0.2), 0.2, Color.WHITE, Color.WHITE)
	var arrays := mb.commit().surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var wrong := 0
	for k in range(0, v.size(), 3):
		var face := (v[k + 1] - v[k]).cross(v[k + 2] - v[k])
		if face.length() > 0.000001 and face.dot(n[k] + n[k + 1] + n[k + 2]) > 0.0:
			wrong += 1
	_eq(wrong, 0, "every triangle faces out")
	_done(g)


func _count_meshes(node: Node) -> int:
	var n := 1 if node is MeshInstance3D else 0
	for c in node.get_children():
		n += _count_meshes(c)
	return n


func _count_vertices(node: Node) -> int:
	var n := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var idx: Variant = arrays[Mesh.ARRAY_INDEX]
			n += (idx as PackedInt32Array).size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for c in node.get_children():
		n += _count_vertices(c)
	return n


## Needs real frames (the camera aims itself each frame): the runner awaits it.
func test_97_taps_land_on_what_is_drawn_and_it_reacts() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.objects.clear()
	var cow := {"uid": 9001, "id": "cow", "row": 5, "col": 5, "t": Game.now()}
	var dairy := {"uid": 9002, "id": "cow_shed", "row": 5, "col": 8, "t": Game.now(), "level": 1, "inside": {}}
	Game.objects.append(cow)
	Game.objects.append(dairy)
	Game.rebuild_occupancy()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var world: Farm3D = main.get("world_3d")
	_check(world != null, "the farm is drawn in 3D")
	if world == null:
		main.free()
		return
	var grid: FarmGrid = main.get("grid")
	# Make the cow wander off its tile centre, then tap where it's drawn.
	var mind := grid.life.mind(9001)
	_check(mind != null, "the cow has a mind")
	if mind != null:
		mind.offset = Vector2(20, 8)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam: Camera3D = world.camera
	var cow_view: Node3D = world.objects.get("_views")[9001]["node"]
	var at := cam.unproject_position(cow_view.global_position + Vector3(0, 0.2, 0))
	_eq(grid.picker.call(at), 9001, "a tap on the cow where it stands now picks the cow")
	var dairy_view: Node3D = world.objects.get("_views")[9002]["node"]
	var on_dairy := cam.unproject_position(dairy_view.global_position + Vector3(0, 0.5, 0))
	_eq(grid.picker.call(on_dairy), 9002, "a tap on the Dairy Farm's walls picks the Dairy Farm")
	_eq(grid.picker.call(Vector2(5, FarmHud.TOP_H + 5)), -1, "a tap on open grass picks nothing")
	# Tapped, the cow stops and looks round, and gives a little start.
	grid.object_poked.emit(9001)
	_eq(mind.state, AnimalBehaviour.State.LOOK, "a tapped cow looks round")
	_check(mind.pose.hop > 0.0, "with a little start")
	main.free()
