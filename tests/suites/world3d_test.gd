extends TestSuite
## The 3D world: the projection that lines it up with the 2D grid, and the models it's built from.

const ANIMAL_DRAWS := 5
const ANIMAL_SHADOW_DRAWS := 2

const TREE_DRAWS := 6




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
		"duck_house", "wing", "lean_to", "weathervane", "arch", "balcony", "hoist", "dormers", "awning", "flag"]
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
	# Every crop has a form, and every form builds every stage.
	for crop_id: String in CropForms.crops():
		_check(g.crops.has(crop_id), "%s in crop_forms.json is a real crop" % crop_id)
		_check(not CropForms.spec(CropForms.form_of(crop_id, "")).is_empty(), "%s has a form" % crop_id)
	for crop_id: String in g.crops:
		_check(CropForms.crops().has(crop_id), "%s has a crop form" % crop_id)
	for form: String in CropForms.forms():
		for stage in CropModels.STAGES:
			var m := CropModels.mesh(form, stage)
			_check(m.get_surface_count() == 1 and m.surface_get_array_len(0) > 3, "%s %s form has a mesh" % [form, stage])
	_done(g)


func test_96_models_are_merged_and_face_outwards() -> void:
	# Baking: a building's hundreds of parts become a couple of meshes, without losing a triangle.
	var g := _farm()
	var built := BuildingModel.build(g.item_data("cow_shed"), Vector2i(4, 3))
	var parts := _count_meshes(built)
	var verts := _count_vertices(built)
	var baked := ModelKit.bake(built)
	_check(parts > 40, "the Dairy Farm is built from many parts (%d)" % parts)
	var doors := baked.get_children().filter(func(n: Node) -> bool: return n.has_meta(BuildingModel.DOOR))
	var door_meshes := 0
	for d: Node in doors:
		door_meshes += _count_meshes(d)
	var pools := baked.get_children().filter(func(n: Node) -> bool:
		return n is MeshInstance3D and (n as MeshInstance3D).material_override == ModelKit.glow_material()).size()
	_check(pools == 2, "with a pool of light at its door and one at its windows (%d)" % pools)
	_check(_count_meshes(baked) - door_meshes - pools <= 2, "and drawn as at most two meshes (%d)" % _count_meshes(baked))
	_check(doors.size() == 2 and door_meshes <= 4, "its barn doors kept whole on hinges, a draw or two each (%d)"
		% door_meshes)
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
	# Pressed and held, the Dairy Farm lifts off; dragged to bare grass and let go, it is set down there.
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = on_dairy
	grid._unhandled_input(press)
	await get_tree().create_timer(FarmGrid.HOLD_TO_LIFT + 0.1).timeout
	grid._process(0.0)
	_eq(int(grid.placing.get("uid", -1)), 9002, "holding the Dairy Farm picks it up")
	var spot := Vector2i(1, 1)
	var fpd := Game.footprint("cow_shed")
	var tile_pos := cam.unproject_position(Vector3(spot.y + fpd.x / 2.0, 0.0, spot.x + fpd.y / 2.0))
	var drop := InputEventScreenTouch.new()
	drop.pressed = false
	drop.position = tile_pos
	_check(Game.can_place("cow_shed", spot.x, spot.y, 9002), "the spot is free")
	grid._unhandled_input(drop)
	_check(grid.placing.is_empty(), "and letting go puts it down")
	_check(int(Game.object_by_uid(9002)["row"]) != 5 or int(Game.object_by_uid(9002)["col"]) != 8, "somewhere new")
	await get_tree().process_frame  # the drop's queued effects run while their scene still stands
	main.free()


func test_101_the_ground_knows_what_stands_on_it() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.objects.clear()
	Game.farm_size = 24  # room for everything below (a new farm starts smaller)
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
			var look := "%d parts, %d vertices" % [_count_meshes(site), _count_vertices(site)]
			var box := _bounds(site)
			site.free()
			_check(not seen.has(look), "%s at %d%% looks different from the stages before" % [id, int(p * 100)])
			seen[look] = true
			_check(box.end.x < fp.x + 0.35 and box.end.z < fp.y + 0.35, "%s site stays near its footprint" % id)
	# Progress is the share of the materials put in.
	var frame := {"uid": 1, "id": "horse_stable", "row": 0, "col": 0, "t": 0, "construction": {}}
	_eq(g.land.construction_progress(frame), 0.0, "a new frame has nothing in it")
	var need: Dictionary = g.item_data("horse_stable")["build_materials"]
	var half := {}
	var total := 0
	for m in need:
		half[m] = int(int(need[m]) / 2.0)
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


func test_104_a_building_shows_how_full_and_how_ready_it_is() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.objects.clear()
	var dairy := {"uid": 9201, "id": "cow_shed", "row": 2, "col": 2, "t": Game.now(), "level": 1, "inside": {}}
	Game.objects.append(dairy)
	Game.rebuild_occupancy()
	var cap := Game.capacity(dairy)
	# How many animals are out in the yard follows how full it is.
	_eq(BuildingFill.shown_count(0, cap, 20), 0, "an empty building has nobody out")
	_eq(BuildingFill.shown_count(1, cap, 20), 1, "one animal in: one out")
	_check(BuildingFill.shown_count(int(cap / 2.0), cap, 20) > 1 and BuildingFill.shown_count(int(cap / 2.0), cap, 20)
		< BuildingFill.shown_count(cap, cap, 20), "half full shows more than one, and fewer than full")
	_eq(BuildingFill.shown_count(cap, cap, 20), BuildingFill.RESIDENTS, "full: the yard is busy")
	# Every animal home has room in its yard, clear of the building and inside the fence.
	for id in ["chicken_coop", "cow_shed", "sheep_pen", "goat_pen", "rabbit_hutch", "pig_pen", "horse_stable",
			"nursery_barn", "duck_pond", "beehive"]:
		for level in range(1, Game.max_level(id) + 1):
			var spec := BuildingModel.spec(id, level)
			var fp := Game.footprint(id)
			var spots := BuildingFill.open_spots(spec, fp, 1)
			_check(spots.size() >= mini(BuildingFill.RESIDENTS, 3), "%s size %d has room for animals in its yard (%d)"
				% [id, level, spots.size()])
			var clash := 0
			for p in spots:
				for r: Rect2 in BuildingModel.taken(spec, fp):
					if r.has_point(Vector2(p.x, p.z)):
						clash += 1
				_check(p.x > 0.0 and p.z > 0.0 and p.x < fp.x and p.z < fp.y, "%s: its yard spots are on its footprint" % id)
			_eq(clash, 0, "%s size %d: nobody stands inside the building" % [id, level])
	# Half full and half way to ready: some cows out, milk churns by the door.
	dairy["inside"] = {"cow": int(cap / 2.0)}
	dairy["t"] = Game.now() - int(Game.cycle_of(dairy) / 2.0)
	var model := ModelKit.bake(BuildingModel.build(Game.item_data("cow_shed"), Game.footprint("cow_shed")))
	var fill := BuildingFill.create(dairy, model)
	model.add_child(fill)
	add_child(model)
	_eq(fill.residents.size(), BuildingFill.shown_count(int(cap / 2.0), cap, 99), "half the yard's worth of cows are out")
	var piled := _count_vertices(fill) - _residents_vertices(fill)
	_check(piled > 0, "milk churns stand by the door as it nears ready")
	dairy["t"] = Game.now() - Game.cycle_of(dairy) + 10
	fill.refresh(dairy)
	await get_tree().process_frame
	_check(_count_vertices(fill) - _residents_vertices(fill) > piled, "more of them, nearer ready")
	# Collected: the doors swing open, then close again.
	_check(not fill.doors_open(), "the doors are shut")
	fill.celebrate()
	await get_tree().create_timer(0.45).timeout
	_check(fill.doors_open(), "collecting opens the doors")
	await get_tree().create_timer(BuildingFill.DOOR_HOLD + 0.8).timeout
	_check(not fill.doors_open(), "and they close again")
	model.queue_free()
	# An orchard shows the trees it holds.
	var orchard := {"uid": 9202, "id": "orchard", "row": 10, "col": 10, "t": Game.now(), "level": 1,
		"inside": {"apple_tree": 2}}
	var om := ModelKit.bake(BuildingModel.build(Game.item_data("orchard"), Game.footprint("orchard")))
	var of := BuildingFill.create(orchard, om)
	var two := _count_vertices(of)
	orchard["inside"] = {"apple_tree": 2, "cherry_tree": 3}
	of.refresh(orchard)
	await get_tree().process_frame
	_check(_count_vertices(of) > two, "five trees in an orchard show more than two")
	of.free()
	om.free()


func _residents_vertices(fill: BuildingFill) -> int:
	var n := 0
	for a in fill.residents:
		n += _count_vertices(a)
	return n


func test_105_animals_move_with_weight() -> void:
	var dt := 1.0 / 60.0
	# Standing still, nothing moves.
	var m := AnimalMotion.new(3)
	for k in 60:
		m.step(dt, 0.0, 0.0, 0.0, 0.0)
	_check(absf(m.pitch) < 0.001 and absf(m.roll) < 0.001 and absf(m.tail) < 0.001, "standing still, it's still")
	# Setting off lifts the front, then it settles level at a steady walk.
	var most := 0.0
	for k in 20:
		m.step(dt, k / 20.0, 0.0, 0.0, k / 20.0)
		most = maxf(most, m.pitch)
	_check(most > 0.03, "setting off, the front lifts (%.3f)" % most)
	for k in 180:
		m.step(dt, 1.0, 0.0, 0.0, 1.0)
	_check(absf(m.pitch) < 0.01, "and at a steady walk it's level again (%.3f)" % m.pitch)
	# Pulling up, the weight comes onto the front.
	var least := 0.0
	for k in 12:
		m.step(dt, 1.0 - k / 12.0, 0.0, 0.0, 1.0 - k / 12.0)
		least = minf(least, m.pitch)
	_check(least < -0.03, "pulling up, the front dips (%.3f)" % least)
	# Turning left (heading rising) at a walk leans it in to its left, and its head and tail lag behind.
	var t := AnimalMotion.new(4)
	var heading := 0.0
	for k in 40:
		heading += 2.0 * dt
		t.step(dt, 1.0, heading, 0.0, 1.0)
	_check(t.roll < -0.02, "turning left it leans left (%.3f)" % t.roll)
	_check(t.head_yaw < -0.02, "its head lags the turn (%.3f)" % t.head_yaw)
	_check(t.tail < -0.02, "and its tail swings out (%.3f)" % t.tail)
	# Landing from a hop, it squashes, and springs back.
	var h := AnimalMotion.new(5)
	for k in 10:
		h.step(dt, 0.0, 0.0, 1.0 - k / 10.0, 0.0)
	var squashed := 0.0
	for k in 20:
		h.step(dt, 0.0, 0.0, 0.0, 0.0)
		squashed = maxf(squashed, h.squash)
	_check(squashed > 0.03, "landing squashes it (%.3f)" % squashed)
	for k in 120:
		h.step(dt, 0.0, 0.0, 0.0, 0.0)
	_check(absf(h.squash) < 0.005, "and it springs back")
	# Running, it trots: diagonal legs together.
	var r := AnimalMotion.new(6)
	_check(is_equal_approx(r.leg_phase(1), 0.75), "walking, the four legs keep the four-beat walk")
	for k in 120:
		r.step(dt, 2.4, 0.0, 0.0, 1.0)
	_check(r.trot > 0.9, "running, it trots (%.2f)" % r.trot)
	# (Phases go round a cycle: 0.99 and 0.0 are together.)
	_check(absf(wrapf(r.leg_phase(0) - r.leg_phase(3), -0.5, 0.5)) < 0.05
		and absf(wrapf(r.leg_phase(1) - r.leg_phase(2), -0.5, 0.5)) < 0.05,
		"in a trot the diagonal pairs move together")
	# Standing a while, it rests a hind leg; told to look at you, it does, then stops resting.
	var s := AnimalMotion.new(7)
	var rested := 0.0
	for k in 60 * 30:
		s.step(dt, 0.0, 0.0, 0.0, 0.0)
		rested = maxf(rested, s.rest)
	_check(rested > 0.8, "standing a while, it rests a hind leg")
	for k in 60:
		s.step(dt, 0.0, 0.0, 0.0, 0.0, 0.8, 1.0)
	_check(absf(s.head_yaw - 0.8) < 0.1, "tapped, it turns its head to look at you (%.2f)" % s.head_yaw)
	_check(s.rest < 0.3, "standing square to do it")


func test_107_buildings_are_compact_and_tall_like_farmville_s() -> void:
	# FarmVille drew its buildings as compact blocks about as tall as they're deep, under steep roofs, and
	# grew them upward; never long low sheds. Every building, at every size, keeps to that.
	var g := _farm()
	for id in g.items:
		if not ["building", "crafting", "barn"].has(str(g.items[id].get("kind", ""))):
			continue
		var fp := g.footprint(id)
		var last_h := 0.0
		for level in range(1, g.max_level(id) + 1):
			var body: Dictionary = BuildingModel.spec(id, level)["body"]
			var bw := float(body.get("w", 0.0)) * fp.x
			var bd := float(body.get("d", 0.0)) * fp.y
			if bw <= 0.0 or bd <= 0.0:
				continue  # a yard with no building on it (a pond, an orchard, hives)
			# A second storey stands on the ground floor: the building is as tall as both.
			var upper: Dictionary = BuildingModel.spec(id, level).get("upper", {})
			var h := float(body.get("h", 0.0)) + float(upper.get("h", 0.0))
			var long_side := maxf(bw, bd)
			var short_side := minf(bw, bd)
			_check(long_side / short_side <= 1.4, "%s size %d is not a long shed (%.2f x %.2f)" % [id, level, bw, bd])
			_check(h >= short_side * 0.5, "%s size %d stands tall for its size (%.2f high, %.2f deep)"
				% [id, level, h, short_side])
			_check(h >= last_h, "%s size %d is no lower than the size before" % [id, level])
			last_h = h
	_done(g)




func test_112_models_keep_to_a_phone_s_draw_budget() -> void:
	# Each colour used to be its own draw and each animal ~24 meshes: the showcase drew 11,000 calls a frame.
	# Now a model's parts share a draw per shader (their colours in their vertices) and an animal is one
	# skinned mesh. These budgets keep it that way.
	var g := _farm()
	for id in g.items:
		var it: Dictionary = g.items[id]
		match str(it.get("kind", "")):
			"animal":
				var a := Animal3D.create(it, null, Vector3.ZERO)
				var draws := _surfaces(a, false)
				_check(draws <= ANIMAL_DRAWS, "%s is %d draws (at most %d)" % [id, draws, ANIMAL_DRAWS])
				_check(_surfaces(a, true) <= ANIMAL_SHADOW_DRAWS, "%s casts its shadow in at most %d draws"
					% [id, ANIMAL_SHADOW_DRAWS])
				a.free()
			"tree":
				var holder := Node3D.new()
				TreeModel.build_at(holder, Vector3.ZERO, it, 1.0, true, 1)
				var baked := ModelKit.bake(holder)
				var draws := _surfaces(baked, false)
				_check(draws <= TREE_DRAWS, "a fruiting %s is %d draws (at most %d)" % [id, draws, TREE_DRAWS])
				baked.free()
	_done(g)




## Draws a model makes: the surfaces of its meshes (only those casting shadows, if `shadow_only`).
func _surfaces(node: Node, shadow_only: bool) -> int:
	var n := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		if not shadow_only or mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			n += mi.mesh.get_surface_count()
	for c in node.get_children():
		n += _surfaces(c, shadow_only)
	return n


func test_115_moving_decorations_move_on_the_gpu() -> void:
	# The fountain sprays and spills, the bonfire flickers and throws embers: each effect one mesh moved by its
	# shader (no script, no nodes per drop), kept out of the bake, casting no shadow, culled by its reach.
	var g := _farm()
	var expect := {"fountain": ["spray3d", "spray3d"], "bonfire": ["flame3d", "spray3d"], "farmhouse": ["spray3d"],
		"birdhouse": ["orbit3d"], "small_pond": ["orbit3d", "orbit3d"], "water_well": ["orbit3d"]}
	for id: String in expect:
		var node := DecorModel.build(g.item_data(id), g.footprint(id), {"id": id, "uid": 1})
		var found: Array[String] = []
		for mi in _meshes_in(node):
			var m := mi.material_override as ShaderMaterial
			if m == null or not m.shader.resource_path.contains("3d.gdshader"):
				continue
			var kind := m.shader.resource_path.get_file().get_basename()
			if kind in ["spray3d", "flame3d", "orbit3d"]:
				found.append(kind)
				_check(mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s's %s casts no shadow"
					% [id, kind])
				_check(kind != "spray3d" or mi.custom_aabb.size.y > 0.1, "%s's spray is culled by how far it flies"
					% id)
		for kind: String in expect[id]:
			_check(found.has(kind), "the %s has its %s" % [id, kind])
		node.free()
	# Drops and smoke puffs face outward (Godot culls the rest: they'd show as hollow outlines).
	for settings: Dictionary in [DecorMotion.JET, DecorMotion.SMOKE]:
		var holder := Node3D.new()
		var mi := DecorMotion.spray(holder, Vector3.ZERO, settings)
		var arrays := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var wrong := 0
		for k in range(0, v.size(), 3):
			var face := (v[k + 1] - v[k]).cross(v[k + 2] - v[k])
			if face.length() > 0.0000001 and face.dot(n[k] + n[k + 1] + n[k + 2]) > 0.0:
				wrong += 1
		_eq(wrong, 0, "every %s triangle faces out" % ("smoke" if settings.get("round", false) else "drop"))
		holder.free()
	_done(g)


func test_126_the_biggest_size_of_a_building_is_a_real_second_storey() -> void:
	var g := _farm()
	var tall := 0
	for id in g.items:
		if not ["building", "crafting", "barn"].has(str(g.items[id].get("kind", ""))):
			continue
		var level := g.max_level(id)
		var spec := BuildingModel.spec(id, level)
		var upper: Dictionary = spec.get("upper", {})
		if upper.is_empty():
			continue
		tall += 1
		_check(float(upper.get("w", 0.8)) <= 1.0 and float(upper.get("d", 0.86)) <= 1.0,
			"%s's upper floor sits inside its ground floor" % id)
		var model := ModelKit.bake(BuildingModel.build(g.item_data(id), g.footprint(id), level))
		var box := AABB()
		for c in model.get_children():
			if c is MeshInstance3D:
				var part := (c as MeshInstance3D).get_aabb()
				box = box.merge(part) if box.size != Vector3.ZERO else part
		var walls := float(spec["body"].get("h", 0.0)) + float(upper.get("h", 0.0))
		_check(box.end.y >= walls, "%s at size %d stands as high as both its floors (%.2f of %.2f)"
			% [id, level, box.end.y, walls])
		model.free()
	_check(tall >= 8, "the bigger buildings have a second storey (%d)" % tall)
	_done(g)


func test_127_things_stand_among_grass_flowers_and_stones() -> void:
	var a := Dressing.make("building", Vector2i(4, 4), 7)
	var b := Dressing.make("building", Vector2i(4, 4), 7)
	var c := Dressing.make("building", Vector2i(4, 4), 8)
	_check(a != null and _count_vertices(a) > 100, "a building has dressing round its foot")
	_eq(_count_vertices(a), _count_vertices(b), "the same object always gets the same scatter")
	_check(_count_vertices(a) != _count_vertices(c) or a.get_child(0).get_aabb() != c.get_child(0).get_aabb(),
		"another object gets its own")
	_check(Dressing.make("tree", Vector2i.ONE, 1) == null, "kinds with no rule get none")
	var box := _bounds(a)
	_check(box.position.x > -0.3 and box.position.z > -0.3 and box.end.x < 4.3 and box.end.z < 4.3,
		"it stays at the footprint's edge (%s)" % box)
	for n: Node in [a, b, c]:
		n.free()


func test_128_the_farm_has_butterflies_fireflies_and_birds_that_cost_three_draws() -> void:
	var life := AmbientLife.new()
	add_child(life)
	_eq(life.get_child_count(), 3, "butterflies, fireflies and a flock of birds, a mesh each")
	for c in life.get_children():
		_check((c as MeshInstance3D).mesh.get_surface_count() == 1, "one draw for all of one kind")
		_check((c as MeshInstance3D).custom_aabb.size.x > 10.0, "they are not culled while wandering")
	var before := _count_vertices(life)
	life.free()
	_check(before > 0, "and there are creatures in them")


func test_129_a_home_shows_each_different_kind_inside_it_up_to_five() -> void:
	var inside := {"a": 8, "b": 1, "c": 1, "d": 1, "e": 1, "f": 1, "g": 1}
	var five := BuildingFill.pick_kinds(inside, 6)
	_eq(five.size(), 6, "as many as asked for")
	var seen := {}
	for id in five:
		seen[id] = true
	_eq(seen.size(), BuildingFill.MAX_KINDS, "the five commonest kinds are each there at least once")
	_check(not seen.has("g") or seen.size() <= BuildingFill.MAX_KINDS, "and never more than five kinds")
	var mixed := BuildingFill.pick_kinds({"x": 4, "y": 4}, 8)
	_check(mixed[0] != mixed[1], "kinds are mixed, not in blocks (%s)" % [mixed])
	_eq(BuildingFill.pick_kinds({}, 5).size(), 0, "nothing inside, nothing shown")
	_eq(BuildingFill.shown_count(5, 100, 20, 5), 5, "a nearly empty home still shows each of its five kinds")
	_eq(BuildingFill.shown_count(3, 100, 20, 3), 3, "or its three")


func test_130_garage_shed_and_barn_show_what_they_keep() -> void:
	for id in ["garage", "garden_shed", "barn"]:
		var fill: Dictionary = BuildingModel.spec(id, 1).get("fill", {})
		_check(BuildingStock.KINDS.has(str(fill.get("stock", ""))), "%s names a stock to show" % id)
	Game.shed.bunches = ["rose", "tulip"]
	var pots := BuildingStock.build("bunches", {}, Vector2i(2, 1), [0.8, 0.95])
	_check(pots.get_child_count() > 0, "bunches in the shed are shown as pots")
	_check(BuildingStock.signature("bunches", {}) != "0", "and the signature follows how many")
	pots.free()
	Game.shed.bunches = []


func test_131_every_kind_stands_within_its_size_range_and_flowers_are_smaller_than_trees() -> void:
	var top := {"tree": 0.0, "bloom": 0.0}
	var low := {"tree": INF, "bloom": INF}
	for id in Game.item_order:
		var kind := str(Game.item_data(id).get("kind", ""))
		if not top.has(kind):
			continue
		var h := ScaleGuide.height_of(id) * ScaleGuide.factor(id)
		top[kind] = maxf(top[kind], h)
		low[kind] = minf(low[kind], h)
	_check(low["tree"] >= 1.19 and top["tree"] <= 2.01,
		"trees stand 1.2-2.0 tiles (%.2f-%.2f)" % [low["tree"], top["tree"]])
	_check(low["bloom"] >= 0.29 and top["bloom"] <= 0.51,
		"blooms stand 0.3-0.5 (%.2f-%.2f)" % [low["bloom"], top["bloom"]])
	_check(top["bloom"] < low["tree"], "the tallest flower is shorter than the shortest tree")


func test_134_new_farms_start_in_fair_weather_and_rain_keeps_the_butterflies_in() -> void:
	var g := _farm(true)
	_check(g.clear_until > g.now(), "a new farm is clear for its first half hour")
	_eq(str(g.weather()["state"]), "clear", "so it is sunny when you open it")
	var was: String = Game.weather_override
	Game.weather_override = "rain"
	var life := AmbientLife.new()
	life.rebuild()
	life._follow_weather()
	_check(not life._butterflies.visible and not life._birds.visible, "no butterflies or birds in the rain")
	Game.weather_override = "clear"
	life._follow_weather()
	_check(life._butterflies.visible and life._birds.visible, "they come back in fair weather")
	life.free()
	Game.weather_override = was
	_done(g)


func test_136_crowds_of_one_model_get_less_detail_each() -> void:
	var tris := func(detail: float) -> int:
		ModelKit.detail = detail
		var holder := Node3D.new()
		TreeModel.build_at(holder, Vector3.ZERO, {"id": "apple", "family": "apple"}, 1.0, false, 1)
		var n := 0
		var stack: Array[Node] = [holder]
		while not stack.is_empty():
			var m: Node = stack.pop_back()
			if m is MeshInstance3D and (m as MeshInstance3D).mesh != null:
				var mesh: Mesh = (m as MeshInstance3D).mesh
				for s in mesh.get_surface_count():
					var arr := mesh.surface_get_arrays(s)
					var idx = arr[Mesh.ARRAY_INDEX]
					n += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			stack.append_array(m.get_children())
		holder.free()
		return n
	var full: int = tris.call(1.0)
	var crowd: int = tris.call(ModelKit.MIN_DETAIL)
	ModelKit.detail = 1.0
	_check(crowd < full * 0.6, "a tree in a crowd has well under 60%% of the triangles (%d vs %d)" % [crowd, full])
	_eq(ModelKit.scaled(12, 5), 12, "full detail changes no count")
	ModelKit.detail = ModelKit.MIN_DETAIL
	_check(ModelKit.scaled(12, 5) >= 5, "and a cut count never drops below its least")
	ModelKit.detail = 1.0


func test_137_marks_on_the_ground_wrap_around_and_fade_away() -> void:
	var t := Trails.new()
	_eq(t.live(), 0, "no marks to start with")
	for i in Trails.CAPACITY + 10:
		t.stamp(Vector3(i * 0.1, Trails.LIFT, 0), 0.0, Trails.FOOT_SIZE, Trails.FOOT)
	_eq(t.live(), Trails.CAPACITY, "a full ring replaces its oldest marks, it never grows")
	t.age(Trails.LIFE * 0.5)
	_eq(t.live(), Trails.CAPACITY, "half way through their life they are all still there")
	_check(t.fade_of(0) > 0.4 and t.fade_of(0) < 0.6, "and they have faded about half")
	t.age(Trails.LIFE)
	_eq(t.live(), 0, "past their life they are gone")
	t.lay_tracks(2, 3, Vector2i(4, 3))
	_eq(t.live(), 2 * 2, "a four wide area is two lanes of two wheel tracks")
	t.free()


func test_138_the_forest_floor_lies_under_the_woods_and_nowhere_else() -> void:
	var img := Ground3D.paint_forest([[-5.0, -5.0, "oak_tree"]])
	var res := Ground3D.FOREST_RES
	var rect := Ground3D.FOREST_RECT
	var at := Vector2i(int((-4.5 - rect.position.x) * res), int((-4.5 - rect.position.y) * res))
	_check(img.get_pixelv(at).r > 0.9, "full forest floor under a tree")
	_check(img.get_pixelv(at + Vector2i(res * 2, 0)).r > 0.0, "fading out beside it")
	_eq(img.get_pixelv(at + Vector2i(res * 5, 0)).r, 0.0, "and none a few tiles off")
	_eq(img.get_pixelv(Vector2i(img.get_width() - 1, img.get_height() - 1)).r, 0.0, "nor far across the meadow")
	var woods := Ground3D.paint_forest(FarmGrid.scenery())
	var lit := 0
	for y in woods.get_height():
		for x in woods.get_width():
			if woods.get_pixel(x, y).r > 0.5:
				lit += 1
	_check(lit > 400, "the real woods cover a good stretch of ground")


func test_141_the_woods_cost_tens_of_draws_not_thousands() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	var objects := Objects3D.new()
	add_child(objects)
	var scenery: Node3D = objects.get("_scenery")
	var meshes := 0
	var stack: Array[Node] = [scenery]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			meshes += (n as MeshInstance3D).mesh.get_surface_count()
	_check(meshes > 0, "there are woods (%d surfaces)" % meshes)
	_check(meshes < 150, "baked into a few draws per area, not one per branch (%d surfaces)" % meshes)
	objects.queue_free()


func test_146_things_standing_together_grow_together_and_cost_less() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.farm_size = 24
	Game.set_objects([])
	var lone := {"uid": 9301, "id": "apple_tree", "row": 10, "col": 10, "t": Game.now()}
	Game.add_object(lone)
	_eq(Crowding.mask(lone), 0, "a tree on its own is not crowded")
	var around: Array[Vector2i] = [Vector2i(9, 9), Vector2i(9, 10), Vector2i(9, 11), Vector2i(10, 9), Vector2i(10, 11)]
	var uid := 9302
	for rc in around:
		Game.add_object({"uid": uid, "id": "apple_tree", "row": rc.x, "col": rc.y, "t": Game.now()})
		uid += 1
	var share := Crowding.share_of(Crowding.mask(lone))
	_check(share > 0.5 and share < 0.7, "five of its eight neighbours are trees (%.2f)" % share)
	_check(Crowding.covered(Crowding.mask(lone), -PI / 2.0), "the side towards the row above is covered")
	_check(not Crowding.covered(Crowding.mask(lone), PI / 2.0), "the open side is not")
	var cow := {"uid": 9310, "id": "cow", "row": 11, "col": 10, "t": Game.now()}
	Game.add_object(cow)
	_eq(Crowding.mask(cow), 0, "animals don't crowd")
	var objects := Objects3D.new()
	add_child(objects)
	var key_with: String = objects.call("_key", lone)
	Game.remove_object(Game.object_by_uid(9302))
	Game.remove_object(Game.object_by_uid(9303))
	_check(objects.call("_key", lone) != key_with, "when neighbours leave, the tree's view is rebuilt")
	# A crowded tree stands on a longer trunk with a wider crown than the same tree alone.
	var a := Node3D.new()
	var b := Node3D.new()
	add_child(a)
	add_child(b)
	TreeModel.build_at(a, Vector3.ZERO, {"id": "apple_tree", "family": "apple"}, 1.0, false, 5, false)
	TreeModel.build_at(b, Vector3.ZERO, {"id": "apple_tree", "family": "apple"}, 1.0, false, 5, false,
		TreeModel.UNSET, 0xff)
	var box_a := _tree_bounds(a)
	var box_b := _tree_bounds(b)
	_check(box_b.size.y > box_a.size.y, "a crowded tree stands taller (%.2f over %.2f)" % [box_b.size.y, box_a.size.y])
	# ...and costs less: the parts that face a neighbour are left out (two side by side cost about 1.5 trees).
	var tris := func(root: Node3D) -> int:
		var n := 0
		for m in _meshes(root):
			var mesh := (m as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				n += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		return n
	var alone: int = tris.call(a)
	var packed: int = tris.call(b)
	_check(packed <= alone * 0.8, "a packed tree draws at most 80%% of a lone one's triangles (%d vs %d)" % [packed,
		alone])
	# Fences share the post where one tile ends and the next begins.
	Game.set_objects([])
	var f1 := {"uid": 9401, "id": "wooden_fence", "row": 5, "col": 5, "t": Game.now()}
	var f2 := {"uid": 9402, "id": "wooden_fence", "row": 6, "col": 5, "t": Game.now()}
	Game.add_object(f1)
	var single := DecorModel.build(Game.item_data("wooden_fence"), Vector2i(1, 1), f1)
	Game.add_object(f2)
	var joined := DecorModel.build(Game.item_data("wooden_fence"), Vector2i(1, 1), f1)
	_check(tris.call(joined) < tris.call(single), "a fence tile joined to the next shares its end post")
	single.free()
	joined.free()
	a.queue_free()
	b.queue_free()
	objects.queue_free()


func _meshes(root: Node) -> Array:
	var out := []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			out.append(n)
	return out


func _tree_bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var box := (n as MeshInstance3D).global_transform * (n as MeshInstance3D).mesh.get_aabb()
			out = box if first else out.merge(box)
			first = false
	return out
