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
		"duck_house", "wing", "lean_to", "weathervane"]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BuildingModel.PATH))
	for id in data["buildings"]:
		for f: Dictionary in (data["buildings"][id] as Dictionary).get("features", []):
			_check(known.has(f.get("type")), "%s: feature %s is buildable" % [id, f.get("type")])
		for size: String in ((data["buildings"][id] as Dictionary).get("levels", {}) as Dictionary):
			for f: Dictionary in (data["buildings"][id]["levels"][size] as Dictionary).get("features", []):
				_check(known.has(f.get("type")), "%s size %s: feature %s is buildable" % [id, size, f.get("type")])
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


func test_101_the_ground_knows_what_stands_on_it() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.objects.clear()
	Game.objects.append({"uid": 9101, "id": "cow_shed", "row": 6, "col": 6, "t": Game.now(), "level": 1, "inside": {}})
	Game.objects.append({"uid": 9102, "id": "cow", "row": 15, "col": 15, "t": Game.now()})
	Game.rebuild_occupancy()
	var ground := Ground3D.new()
	add_child(ground)
	var fp := Game.footprint("cow_shed")
	var inside := Vector2(6 + fp.x / 2.0, 6 + fp.y / 2.0)  # x along columns, y along rows
	var beside := Vector2(6 + fp.x + 0.15, 6 + fp.y / 2.0)
	var far := Vector2(1.5, 20.5)
	_check(ground.shade_at(inside).x > 0.5, "the grass under a building is in its shade (%s)" % ground.shade_at(inside))
	_check(ground.shade_at(beside).x > 0.08, "and right beside it, shaded a little (%s)" % ground.shade_at(beside))
	_check(ground.shade_at(beside).y > 0.3, "and worn where feet go round it (%s)" % ground.shade_at(beside))
	_check(ground.shade_at(far) == Vector2.ZERO, "open grass far away is untouched")
	_check(ground.shade_at(Vector2(15.5, 15.5)).y > 0.2, "a grazing animal wears its patch")
	# No grass grows through the building.
	var mm: MultiMesh = (ground.get("_tufts") as MultiMeshInstance3D).multimesh
	var through := 0
	for i in mm.instance_count:
		var at := mm.get_instance_transform(i).origin
		if Game.object_at(Game.index_of(int(at.z), int(at.x))).get("id", "") == "cow_shed":
			through += 1
	_eq(through, 0, "no tuft grows through the building")
	_check(mm.instance_count > 500, "and plenty grow everywhere else (%d)" % mm.instance_count)
	# Moving the building moves its shade (once things have settled, a frame later).
	Game.objects[0]["row"] = 14
	Game.objects[0]["col"] = 2
	Game.rebuild_occupancy()
	ground.queue_rebuild()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(ground.shade_at(inside).x < 0.05, "moved away, its old spot is open grass again")
	ground.queue_free()



func test_102_bigger_buildings_look_bigger_and_sites_build_up() -> void:
	var g := _farm()
	for id in g.items:
		if not g.items[id].get("kind", "") == "building":
			continue
		var fp := g.footprint(id)
		var most := g.max_level(id)
		for size: int in BuildingModel.sizes_of(id):
			_check(size >= 2 and size <= most, "%s: changes for size %d, which it has (1..%d)" % [id, size, most])
		# Each size up that changes anything adds to the building, and it stays on its footprint.
		var last := 0
		for level in range(1, most + 1):
			var built := BuildingModel.build(g.item_data(id), fp, level)
			var verts := _count_vertices(built)
			var box := _bounds(built)
			built.free()
			if level == 1 or BuildingModel.sizes_of(id).has(level):
				_check(verts > last, "%s size %d has more to it than the size before (%d > %d)" % [id, level, verts, last])
			_check(box.position.x > -0.2 and box.position.z > -0.2 and box.end.x < fp.x + 0.2 and box.end.z < fp.y + 0.2,
				"%s size %d stays on its footprint (%s)" % [id, level, box])
			last = verts
	# A building site shows how far it has got: every stage looks different, and it never spills off.
	for id in ["horse_stable", "pig_pen", "nursery_barn", "garage"]:
		var fp := g.footprint(id)
		var seen := {}
		for p: float in [0.0, 0.15, 0.3, 0.42, 0.6, 0.85, 0.95]:
			var site := BuildingModel.build_site(g.item_data(id), fp, p)
			var verts := _count_vertices(site)
			var box := _bounds(site)
			site.free()
			_check(not seen.has(verts), "%s at %d%% looks different from the stage before" % [id, int(p * 100)])
			seen[verts] = true
			_check(box.end.x < fp.x + 0.35 and box.end.z < fp.y + 0.35, "%s site stays near its footprint" % id)
	# Progress is the share of the materials put in.
	var frame := {"uid": 1, "id": "horse_stable", "row": 0, "col": 0, "t": 0, "construction": {}}
	_eq(g.land.construction_progress(frame), 0.0, "a new frame has nothing in it")
	var need: Dictionary = g.item_data("horse_stable")["build_materials"]
	var half := {}
	var total := 0
	for m in need:
		half[m] = int(need[m]) / 2
		total += int(need[m])
	frame["construction"] = half
	var given := 0
	for m in half:
		given += int(half[m])
	_check(is_equal_approx(g.land.construction_progress(frame), float(given) / total),
		"half the materials, about half built")
	_done(g)


## The space a model takes up (its meshes' boxes, in the model's own space).
func _bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in _meshes_in(node):
		var box := _local_xf(mi, node) * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _meshes_in(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes_in(c))
	return out


func _local_xf(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var at: Node = n
	while at != root and at is Node3D:
		xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf


func test_103_every_kind_of_tree_grows_its_own_way() -> void:
	var g := _farm()
	var shapes: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(TreeModel.PATH)) as Dictionary)["families"]
	var forms := TreeModel.forms()
	# Every fruit tree's family has a shape, and every shape is a form the model knows.
	for id in g.items:
		var it: Dictionary = g.items[id]
		if it.get("kind", "") != "tree":
			continue
		_check(shapes.has(str(it.get("family", ""))), "%s (%s) has its own shape" % [id, it.get("family", "")])
		_check(forms.has(TreeModel.shape_of(it)["form"]), "%s grows as a known form" % id)
	# Each form builds, and builds differently from the others.
	var by_form := {}
	for form: String in forms:
		var holder := Node3D.new()
		TreeModel.build_at(holder, Vector3.ZERO, {"id": "test", "family": _family_with(shapes, form)}, 1.0, true, 1)
		var verts := _count_vertices(holder)
		holder.free()
		_check(verts > 100, "a %s tree has a body (%d vertices)" % [form, verts])
		_check(not by_form.values().has(verts), "a %s tree is built unlike the other forms" % form)
		by_form[form] = verts
	# Two trees of one kind differ: their own height, lean and crown.
	var a := Node3D.new()
	var b := Node3D.new()
	TreeModel.build_at(a, Vector3.ZERO, g.item_data("apple_tree"), 1.0, true, 1)
	TreeModel.build_at(b, Vector3.ZERO, g.item_data("apple_tree"), 1.0, true, 2)
	_check(not _bounds(a).is_equal_approx(_bounds(b)), "two apple trees are not copies of each other")
	a.free()
	b.free()
	_done(g)


func _family_with(shapes: Dictionary, form: String) -> String:
	for f in shapes:
		if str((shapes[f] as Dictionary).get("form", "round")) == form:
			return f
	return ""
