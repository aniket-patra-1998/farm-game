extends TestSuite
## The 3D world: the projection that lines it up with the 2D grid, and the models it's built from.

const ANIMAL_DRAWS := 5
const ANIMAL_SHADOW_DRAWS := 2

const TREE_DRAWS := 7 # one of them the leaf cards
const LEAF_KEEPS_COLOUR := 0.6 # a toned crown keeps at least this share of its kind's saturation
## Telling buildings apart by shape (test_320).
const SILHOUETTE_GRID := 40
const SILHOUETTE_SPAN := 8.0
const SILHOUETTE_STEP := 0.12
const SILHOUETTE_APART := 0.06
const LOOK_IS_CONTENTS := ["orchard", "bloom_garden"]
const BUDGET_SEED := 7   # the showcase the draw budget is measured on (test 338)




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
	var known := ["yard", "silo", "stilts", "ramp", "egg_chutes", "chimney", "cupola", "loft_door",
		"stall_doors", "porch", "terrace",
		"nest_boxes", "water_trough", "hay_bales", "beehives", "trees", "pond", "sign", "flowers", "barrels",
		"duck_house", "wing", "lean_to", "weathervane", "arch", "balcony", "hoist", "dormers", "awning", "flag",
		"hive", "vip_badge"]
	known.append_array(BuildingModel.SIGNATURES)
	known.append_array(BuildingDress.FEATURES)   # (the dressing's own: sacks, a windmill, an oven...)
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
	_check(pools == 1, "with the pools of light at its door and its windows, drawn as one (%d)" % pools)
	var shades := baked.get_children().filter(func(n: Node) -> bool:
		var plane := n is MeshInstance3D and (n as MeshInstance3D).mesh is PlaneMesh
		return plane and (n as MeshInstance3D).material_override != ModelKit.glow_material()).size()
	_eq(shades, 1, "and the soft shade round its foot")
	var body := baked.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D).size()
	_check(body - pools - shades <= 2, "and drawn as at most two meshes (%d)" % body)
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


func test_384_a_mill_shows_its_work_and_grows_with_its_level() -> void:
	# The Feed Mill is a tower windmill. Its sails turn only while it works; at level 1 one is broken off and they
	# never turn; maxed it has two storeys, one bigger set and a grain chute.
	var g := _farm()
	var it := g.item_data("feed_mill")
	var fp := Vector2i(3, 3)
	var idle := BuildingModel.build(it, fp, 4, false)
	var busy := BuildingModel.build(it, fp, 4, true)
	var second := BuildingModel.build(it, fp, 2, true)
	var first := BuildingModel.build(it, fp, 1, true)
	_eq(_turning(idle), 0, "an idle mill's sails stand still")
	_check(_turning(busy) == 1 and _turning(second) == 1, "a working mill's sails turn, from level 2 up")
	_eq(_shaded(busy, DecorMotion.SPRAY_SHADER), 1, "and grain runs down the maxed mill's chute")
	_eq(_turning(first), 0, "the level 1 mill's broken sails never turn")
	_check(_bounds(idle).size.y > _bounds(first).size.y * 1.3, "the maxed mill stands well over the first one")
	for n: Node3D in [idle, busy, second, first]:
		n.free()
	_done(g)


func test_385_crafting_buildings_follow_the_building_rules() -> void:
	# The rules for crafting buildings (CLAUDE.md): four levels, each with its own look; animated parts 0, 1, 1, 2
	# by level, each a machine you can see standing still, moving while the building crafts and only then;
	# storage parts 1, 1, 2, then 2 or 3, with four looks (empty, a quarter, half, full) by how full it is.
	var g := _farm()
	var moving: Array[String] = [DecorMotion.ORBIT_SHADER, DecorMotion.SPRAY_SHADER, DecorMotion.FLAME_SHADER]
	var named := 0
	var checked := 0
	for id: String in g.items:
		var it: Dictionary = g.item_data(id)
		if str(it.get("kind", "")) != "crafting":
			continue
		checked += 1
		_eq(g.max_level(id), 4, "%s has four levels" % id)
		var fp := g.footprint(id)
		var looks := {}
		for level in range(1, 5):
			var parts := {BuildingDress.ANIMATED: 0, BuildingDress.STORAGE: 0}
			for f: Dictionary in BuildingModel.spec(id, level).get("features", []):
				if parts.has(str(f.get("part", ""))):
					parts[str(f["part"])] += 1
				if str(f.get("part", "")) == BuildingDress.ANIMATED:
					_check(BuildingDress.MACHINES.has(str(f["type"])), "%s level %d: its animated part is a machine (%s)"
						% [id, level, f["type"]])
			var animated: int = parts[BuildingDress.ANIMATED]
			_eq(animated, [0, 1, 1, 2][level - 1], "%s level %d: its animated parts" % [id, level])
			var stores: int = parts[BuildingDress.STORAGE]
			_check(stores == [1, 1, 2, 2][level - 1] or (level == 4 and stores == 3),
				"%s level %d: its storage parts (%d)" % [id, level, stores])
			var idle := BuildingModel.build(it, fp, level, false)
			var busy := BuildingModel.build(it, fp, level, true)
			var still := _turning(idle)
			var moves := _turning(busy)
			named += _named_parts(busy)
			for shader in moving:
				still += _shaded(idle, shader)
				moves += _shaded(busy, shader)
			_eq(still, 0, "%s level %d: nothing moves when it is not crafting" % [id, level])
			_check(moves >= animated and (animated > 0 or moves == 0),
				"%s level %d: each animated part moves while it crafts, and nothing else (%d)" % [id, level, moves])
			looks[_outline(idle)] = true
			var fills := {}
			for fill in BuildingDress.FILLS:
				var held := BuildingModel.build(it, fp, level, false, false, fill)
				fills[_outline(held)] = true
				# One model holds every state: switching it shows what building it in that state does.
				BuildingModel.show_state(idle, true, fill)
				var built := BuildingModel.build(it, fp, level, true, false, fill)
				_eq(_outline(idle), _outline(built), "%s level %d: switched to crafting and fill %d in place"
					% [id, level, fill])
				held.free()
				built.free()
			_eq(fills.size(), BuildingDress.FILLS, "%s level %d: its storage shows empty, a quarter, half and full"
				% [id, level])
			idle.free()
			busy.free()
		_eq(looks.size(), 4, "%s has a look for each level" % id)
	_check(checked >= 4, "the Bakery, Winery, Spa and Feed Mill were checked (%d)" % checked)
	_check(named >= 16, "what moves is a named part, as a file names it: smoke_3, spin_55_2 (%d)" % named)
	_done(g)


func test_387_storage_looks_follow_the_share_of_slots_finished() -> void:
	# A storage part shows a quarter from a quarter of the slots finished, half from half, full when all are.
	for row: Array in [[0, 1, 0], [1, 1, 3], [1, 2, 2], [2, 2, 3], [1, 3, 1], [2, 3, 2], [3, 3, 3], [1, 4, 1], [2, 4, 2],
			[3, 4, 2], [4, 4, 3], [0, 4, 0]]:
		_eq(Objects3D.store_fill_for(row[0], row[1]), row[2], "%d of %d slots finished" % [row[0], row[1]])


## Meshes under `node` drawn with `shader`, leaving out parts hidden for another state.
func _shaded(node: Node, shader: String) -> int:
	var n := 0
	for mi in _shown_meshes(node):
		var mat := mi.material_override as ShaderMaterial
		if mat != null and mat.shader != null and mat.shader.resource_path == shader:
			n += 1
	return n


## Parts under `node` that a Spinner is turning, leaving out parts hidden for another state.
func _turning(node: Node) -> int:
	if node is Node3D and not (node as Node3D).visible:
		return 0
	var n := 1 if node is Spinner else 0
	for c in node.get_children():
		n += _turning(c)
	return n


## Named parts under `node` that the game gives life to (DecorMotion.start), shown or not.
func _named_parts(node: Node) -> int:
	var n := 1 if DecorMotion.is_part(node) else 0
	for c in node.get_children():
		n += _named_parts(c)
	return n


func _shown_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is Node3D and not (node as Node3D).visible:
		return out
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_shown_meshes(c))
	return out


## A number that changes when what a model shows changes (every vertex of every mesh shown, weighed by where
## it is).
func _outline(node: Node) -> int:
	var sum := 0.0
	for mi in _shown_meshes(node):
		for k in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX]:
				sum += 1.0 + absf(v.x) + 2.0 * absf(v.y) + 3.0 * absf(v.z)
	return roundi(sum * 1000.0)


func _count_meshes(node: Node) -> int:
	var n := 1 if node is MeshInstance3D else 0
	for c in node.get_children():
		n += _count_meshes(c)
	return n


func _count_vertices(node: Node) -> int:
	var n := 0
	if String(node.name).begins_with(AssetRegistry.STATE + BuildingModel.PLAN):
		return 0   # (the frame of what a building does not have yet is not part of it)
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var idx: Variant = arrays[Mesh.ARRAY_INDEX]
			n += (idx as PackedInt32Array).size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		var multi := (node as MultiMeshInstance3D).multimesh
		var per := 0
		for s in multi.mesh.get_surface_count():
			per += (multi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		n += per * multi.instance_count
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
	_eq(grid.picker.call(Vector2(5, FarmHud.top_h() + 5)), -1, "a tap on open grass picks nothing")
	# Tapped, the cow stops and looks round, and gives a little start.
	grid.object_poked.emit(9001)
	_eq(mind.state, AnimalBehaviour.State.LOOK, "a tapped cow looks round")
	mind.update(1.0 / 60.0)   # (its jump takes off)
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
	# A fence is laid as a line: press at one tile, drag along the ground, let go, and each tile gets a piece.
	Game.coins = 100000
	Game.xp = Game.xp_for_level(10)
	grid.placement.start("wooden_fence")
	_check(grid.placement.state.has("item") and not grid.placing.is_empty(), "a bought fence is in hand")
	var free_row := -1
	for r in Game.farm_size:
		var clear := true
		for c in range(3, 9):
			clear = clear and Game.can_place("wooden_fence", r, c)
		if clear:
			free_row = r
	var from := Vector2i(free_row, 3)
	var to := Vector2i(free_row, 8)
	var press_at := InputEventScreenTouch.new()
	press_at.pressed = true
	press_at.position = cam.unproject_position(Vector3(from.y + 0.5, 0.0, from.x + 0.5))
	grid._unhandled_input(press_at)
	var drag := InputEventScreenDrag.new()
	drag.position = cam.unproject_position(Vector3(to.y + 0.5, 0.0, to.x + 0.5))
	grid._unhandled_input(drag)
	_eq((grid.placing.get("line", []) as Array).size(), 6, "dragging along the ground plans a line of six")
	var before := Game.coins
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = drag.position
	grid._unhandled_input(release)
	var laid := 0
	for c in range(3, 9):
		if Game.object_at(Game.index_of(free_row, c)).get("id", "") == "wooden_fence":
			laid += 1
	_eq(laid, 6, "letting go lays all six")
	_check(Game.coins < before, "and charges for them (level-up gifts may soften it)")
	_check(grid.placing.is_empty(), "and the hand is empty")
	await get_tree().process_frame
	await get_tree().process_frame
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
	# Every kind keeps its own hue but is toned into the farm's one family: never more saturated than its data.
	# And still reads as itself (owner, 18 Nov): a pink crown stays clearly pink, softer, never grey or salmon.
	for id in shapes:
		if not (shapes[id] is Dictionary and (shapes[id] as Dictionary).has("leaf")):
			continue
		var raw := Color.html(str((shapes[id] as Dictionary)["leaf"]))
		var toned := TreeModel.tone(raw)
		_check(toned.s < raw.s, "%s's leaves are softened into the farm's family" % id)
		_check(toned.s >= raw.s * LEAF_KEEPS_COLOUR, "%s's leaves keep their colour (%.2f of %.2f)" % [id, toned.s, raw.s])
		_check(absf(wrapf(toned.h - raw.h + 0.5, 0.0, 1.0) - 0.5) < 0.01, "%s's leaves keep their own hue" % id)
	_done(g)


func _family_with(shapes: Dictionary, form: String) -> String:
	for f in shapes:
		if str((shapes[f] as Dictionary).get("form", "round")) == form:
			return f
	return ""


func _pack(id: String, level: int, radii: Array[float]) -> Dictionary:
	var fp := Game.footprint(id)
	return SpaceFit.pack(SpaceFit.yard_room(fp), BuildingFill.kept_clear(BuildingModel.spec(id, level), fp), radii, 3,
		BuildingFill.ANIMAL_SMALLEST)


func test_105_orchards_and_gardens_keep_their_plants_inside_the_tile() -> void:
	Game.reset_game()
	Game.objects.clear()
	for id in ["orchard", "bloom_garden"]:
		var plant := ""
		for item in Game.item_order:
			if str(Game.item_data(item).get("kind", "")) == ("tree" if id == "orchard" else "bloom"):
				plant = item
				break
		var level := Game.max_level(id)
		var field := {"uid": 9301, "id": id, "row": 2, "col": 2, "t": Game.now(), "level": level, "inside": {}}
		field["inside"] = {plant: Game.capacity(field)}
		Game.objects.append(field)
		Game.rebuild_occupancy()
		var model := ModelKit.bake(BuildingModel.build(Game.item_data(id), Game.footprint(id), level))
		var fill := BuildingFill.create(field, model)
		model.add_child(fill)
		add_child(model)
		var fp := Game.footprint(id)
		var box := SpaceFit.reach(fill)
		_check(Rect2(0, 0, fp.x, fp.y).grow(0.001).encloses(box), "%s: its plants stay on its footprint (%s)" % [id, box])
		Game.objects.clear()
		model.free()


func test_481_a_bloom_gardens_blooms_are_kept_and_come_back_the_same() -> void:
	# A garden of blooms is built once and kept (ModelStore), then loaded as the same model: no building again.
	Game.reset_game()
	Game.objects.clear()
	ModelStore.stamp = "test"   # (kept in user://models/test, as on a phone)
	var blooms: Array = Game.item_order.filter(func(i: String) -> bool:
		return str(Game.item_data(i).get("kind", "")) == "bloom")
	var level := Game.max_level("bloom_garden")
	var field := {"uid": 9302, "id": "bloom_garden", "row": 2, "col": 2, "t": Game.now(), "level": level, "inside": {}}
	field["inside"] = {blooms[0]: 3, blooms[1]: 2}
	Game.objects.append(field)
	Game.rebuild_occupancy()
	var made: Array[Vector3] = []   # (saved, loaded, surfaces) for each opening
	for k in 2:
		var saved := ModelStore.saved
		var loaded := ModelStore.loaded
		var model := ModelKit.bake(BuildingModel.build(Game.item_data("bloom_garden"), Game.footprint("bloom_garden"),
			level))
		var fill := BuildingFill.create(field, model)
		model.add_child(fill)
		add_child(model)
		made.append(Vector3(ModelStore.saved - saved, ModelStore.loaded - loaded, _surfaces(fill.get("_plants"), false)))
		model.free()
	_check(made[0].x >= 1 and made[0].y == 0, "the first opening builds the garden and keeps it (%s)" % made[0])
	_check(made[1].y >= 1 and made[1].x == 0, "the next one loads it, building nothing (%s)" % made[1])
	_eq(made[1].z, made[0].z, "the same model comes back")
	ModelStore._remove_tree(ModelStore.KEPT + "/test")
	ModelStore.stamp = ""
	Game.objects.clear()


func test_104_a_building_shows_how_full_and_how_ready_it_is() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.objects.clear()
	var dairy := {"uid": 9201, "id": "cow_shed", "row": 2, "col": 2, "t": Game.now(), "level": 1, "inside": {}}
	Game.objects.append(dairy)
	Game.rebuild_occupancy()
	var cap := Game.capacity(dairy)
	# How many animals are out in the yard follows the room there is: all of them when few, as many as fit (at full
	# size, FarmVille's way) when many; and never more than the size of the building allows.
	var cow_size := AnimalRig.of(Game.item_data("cow")).scale
	AnimalRig.scaled(Game.item_data("cow"), 0.5)
	_eq(AnimalRig.of(Game.item_data("cow")).scale, cow_size, "drawing an animal smaller never changes the shared rig")
	var cow_r := BuildingFill.radius_of(Game.item_data("cow"))
	var pair := _pack("cow_shed", 1, [cow_r, cow_r])
	var herd := _pack("cow_shed", 1, [cow_r, cow_r, cow_r, cow_r, cow_r, cow_r, cow_r, cow_r])
	_eq((pair["spots"] as Array).size(), 2, "two cows in a roomy yard: both are out")
	_check((herd["spots"] as Array).size() < 8 and float(herd["size"]) >= BuildingFill.ANIMAL_SMALLEST - 0.001,
		"a crowd is not drawn smaller: fewer of it are out")
	var top := Game.max_level("cow_shed")
	_eq(BuildingFill.shown_cap(1, top), BuildingFill.SHOWN_FIRST, "the first size shows the fewest at most")
	_eq(BuildingFill.shown_cap(top, top), BuildingFill.SHOWN_BIGGEST, "the biggest size shows the most at most")
	_check(BuildingFill.shown_cap(2, top) > BuildingFill.SHOWN_FIRST - 1, "a size in between shows at least the fewest")
	var rare := BuildingFill.rarest({"cow": 3, "red_cow": 1, "ox": 2}, 3)
	_eq(rare[0], "red_cow", "the rarest animal is shown first")
	_eq(rare.size(), 3, "and as many as asked for")
	# Every home's biggest crowd (its five rarest animals) fits its yard, inside the fence and clear of the walls.
	for id in ["chicken_coop", "cow_shed", "sheep_pen", "goat_pen", "rabbit_hutch", "pig_pen", "horse_stable",
			"nursery_barn", "duck_pond"]:
		var top_level := Game.max_level(id)
		var spec := BuildingModel.spec(id, top_level)
		var fp := Game.footprint(id)
		var inside := {}
		for a in (Game.catalog.get_def(id) as BuildingDef).holds():
			inside[str(a)] = 6
		var picks := BuildingFill.rarest(inside, BuildingFill.SHOWN_BIGGEST)
		var radii: Array[float] = []
		for a in picks:
			radii.append(BuildingFill.radius_of(Game.item_data(a)))
		var fit := _pack(id, top_level, radii)
		var spots: Array = fit["spots"]
		_check(float(fit["size"]) >= BuildingFill.ANIMAL_SMALLEST - 0.001, "%s: its animals are drawn about full size" % id)
		_check(spots.size() >= 1, "%s: an animal fits its yard (%d)" % [id, spots.size()])
		var yard := SpaceFit.yard_room(fp)
		for k in spots.size():
			var at: Vector2 = spots[k]
			var r := radii[k] * float(fit["size"])
			_check(yard.grow(0.001).encloses(Rect2(at - Vector2.ONE * r, Vector2.ONE * r * 2.0)),
				"%s: %s stands clear inside the fence" % [id, picks[k]])
			for q: Rect2 in BuildingFill.kept_clear(spec, fp):
				_check(not q.grow(r * SpaceFit.WALL_CLEAR - 0.001).has_point(at),
					"%s: %s stands clear of the building and its footing" % [id, picks[k]])
	# Every building keeps a clear border inside its tile, so neighbours never touch.
	for id in Game.item_order:
		var kind := str(Game.item_data(id).get("kind", ""))
		if not (kind in ["building", "crafting", "barn"]):
			continue
		var fp := Game.footprint(id)
		var edge := Vector2.ONE * SpaceFit.TILE_MARGIN
		var room := Rect2(edge, Vector2(fp) - edge * 2.0)
		for level in range(1, Game.max_level(id) + 1):
			var node := BuildingModel.build(Game.item_data(id), fp, level)
			var box := SpaceFit.reach(node, node.transform)
			_check(room.grow(0.002).encloses(box), "%s size %d stays inside its tile's border (%s in %s)"
				% [id, level, box, room])
			node.free()
	# Half full and half way to ready: some cows out, milk churns by the door.
	dairy["inside"] = {"cow": int(cap / 2.0)}
	dairy["t"] = Game.now() - int(Game.cycle_of(dairy) / 2.0)
	var model := ModelKit.bake(BuildingModel.build(Game.item_data("cow_shed"), Game.footprint("cow_shed")))
	var fill := BuildingFill.create(dairy, model)
	model.add_child(fill)
	add_child(model)
	_check(fill.residents.size() >= 2 and fill.residents.size() <= BuildingFill.SHOWN_BIGGEST,
		"some of the yard's cows are out (%d)" % fill.residents.size())
	# What it has made stands on its own ready part (milk cans on a table: a look of the model, shown in place),
	# so the yard piles nothing beside it.
	_eq(Objects3D.store_fill(dairy), 2, "half way to ready, its ready part is half full")
	dairy["t"] = Game.now() - Game.cycle_of(dairy) - 10
	fill.refresh(dairy)
	await get_tree().process_frame
	_eq(Objects3D.store_fill(dairy), BuildingDress.FULL, "and full when it is ready to collect")
	_check(fill._produce == null, "the yard piles no produce of its own beside a building that shows it")
	dairy["t"] = Game.now() - int(Game.cycle_of(dairy) / 2.0)
	# Whoever lives in a home looks out of its windows, half full or full (when a head fits them: one too big for
	# the windows doesn't squeeze in, and nobody looks out).
	var fits := fill._windows.is_empty() or BuildingFill._file_head("cow", float(fill._windows[0]["size"])) != null
	_check(not fits or (fill._peekers != null and fill._peekers.get_child_count() > 0),
		"a half-full home has heads at its windows when a head fits them")
	dairy["inside"] = {"cow": cap}
	fill.refresh(dairy)
	_check(not fits or (fill._peekers != null and fill._peekers.get_child_count() > 0),
		"a full home looks out of its windows when a head fits them")
	_check(fill._peekers == null or fill._peekers.get_child_count() <= BuildingFill.PEEKERS, "but only a few at a time")
	dairy["inside"] = {"cow": int(cap / 2.0)}
	fill.refresh(dairy)
	_check(fill._peekers != null, "and they stay when it is no longer full")
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
	# FarmVille drew its buildings as compact blocks, never long low sheds, and grew them upward. Its animal homes
	# were one low storey, a couple of animals tall, so the animals in the yard read against them; the others
	# (barns, workshops) stand about as tall as they're deep.
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
	# (Barns and workshops; an animal home stays one storey, test_107.)
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
	_check(tall >= 4, "the bigger barns and workshops have a second storey (%d)" % tall)
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
	# On the farm it is drawn in batches: two buildings alike share theirs, and none is a mesh under the model.
	Game.saving_enabled = false
	Game.reset_game()
	var objects := Objects3D.new()
	var shed := ""
	for id: String in Game.items:
		if Game.kind_of({"id": id}) == "building" and not AssetRegistry.has_model(id):
			shed = id
			break
	var one: Node3D = objects._build({"uid": 1, "id": shed, "row": 0, "col": 0})
	var two: Node3D = objects._build({"uid": 1 + Objects3D.DRESSINGS, "id": shed, "row": 0, "col": 8})
	var round_one := Objects3D.dressing_id(1)
	var round_two := Objects3D.dressing_id(1 + Objects3D.DRESSINGS)
	_check(objects.decor.has_piece(round_one) and objects.decor.has_piece(round_two),
		"a building's grass and stones are drawn by the batching layer")
	_check(objects.decor.meshes_of(round_one) == objects.decor.meshes_of(round_two),
		"two buildings alike share one batch for them")
	for n: Node in [one, two, objects]:
		n.free()
	Game.reset_game()


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
	_check(low["tree"] >= 1.39 and top["tree"] <= 2.41,
		"trees stand 1.4-2.4 tiles (%.2f-%.2f)" % [low["tree"], top["tree"]])
	_check(low["bloom"] >= 0.84 and top["bloom"] <= 1.11,
		"blooms stand 0.85-1.1 tiles, a flower filling its tile (%.2f-%.2f)" % [low["bloom"], top["bloom"]])
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
	t.lay_pass(Vector2(3.0, 2.0), 0.0)
	_eq(t.live(), 2, "a vehicle's pass leaves two wheel tracks, one for each side")
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
	var waited := 0
	while waited < 600 and scenery.get_child_count() < 4:   # the woods go up over a few frames
		await get_tree().process_frame
		waited += 1
	for k in 60:
		await get_tree().process_frame
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


## Feeding shows (our own touch): a fed animal hops and says what it got. (A hungry one wears no sign of its
## own: the farm has one sign, the ready one; hunger shows in the animal's panel.)
func test_185_a_fed_animal_hops() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.objects.clear()
	Game.feeds.active = true
	Game.objects.append({"uid": 9101, "id": "cow", "row": 5, "col": 5, "t": Game.now()})
	Game.rebuild_occupancy()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: FarmGrid = main.get("grid")
	var cow := Game.object_by_uid(9101)
	_check(Game.feeds.is_hungry(cow), "an unfed cow is hungry")
	cow[FeedSystem.FED] = {"effect": "produce", "power": 0.2, "t": int(cow["t"])}
	_check(not Game.feeds.is_hungry(cow), "fed, it isn't")
	var mind := grid.life.mind(9101)
	if mind != null:
		mind.pose.hop = 0.0
	grid._show_fed(9101, {"feed": "greens", "effect": "produce"})
	if mind != null:
		mind.update(1.0 / 60.0)   # (its jump takes off)
		_check(mind.pose.hop > 0.0, "a fed animal hops")
	Game.feeds.active = false
	main.free()


func test_186_ambient_life_listens_for_land_once_not_every_frame() -> void:
	var before := Game.farm_expanded.get_connections().size()
	var life := AmbientLife.new()
	add_child(life)
	var after_ready := Game.farm_expanded.get_connections().size()
	for i in 20:
		life._process(0.1)
	_eq(Game.farm_expanded.get_connections().size(), after_ready, "twenty frames connect nothing more")
	_eq(after_ready, before + 1, "it listens once, from _ready")
	life.free()
	_eq(Game.farm_expanded.get_connections().size(), before, "and lets go when it is freed")


func test_191_a_clipped_hedge_stands_still_and_swaying_pieces_sway_on_their_own_beat() -> void:
	var it := Game.item_data("hedge")
	_check(not it.is_empty(), "there is a hedge")
	var swaying := false
	for p: Dictionary in LinkModels.parts(it, LinkShape.Kind.END, 0):
		var mesh := p["mesh"] as ArrayMesh
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s) as ShaderMaterial
			var sway: Variant = m.get_shader_parameter("sway") if m != null else null
			swaying = swaying or (sway != null and float(sway) > 0.0)
	_check(not swaying, "a clipped hedge is a solid wall of leaves: it doesn't wobble in the wind")
	for id in ["arbor", "haystack"]:
		_check(not DecorModel.SWAY_BY_ID.has(id), "%s is solid: it stands still" % id)
	for path in ["res://shaders/paint3d.gdshader", "res://shaders/canopy3d.gdshader"]:
		var code := FileAccess.get_file_as_string(path)
		_check(code.contains("MODEL_MATRIX[3]") and not code.contains("NODE_POSITION_WORLD"),
			"%s takes each instance's own foot, so pieces of a MultiMesh do not sway as one" % path)


## Lifting something into the hand and carrying it for drawn frames: one of every kind of catalog item, and
## homes standing edge to edge (the layout bonus is drawn while one is carried).
## Needs real frames, so the runner awaits it.
func test_193_anything_can_be_lifted_and_carried() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.set_objects([])
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var grid: FarmGrid = main.get("grid")
	Game.set_objects([])
	Game.add_object({"uid": 9101, "id": "chicken_coop", "row": 4, "col": 4, "t": Game.now(), "level": 1, "inside": {}})
	Game.add_object({"uid": 9102, "id": "chicken_coop", "row": 4, "col": 6, "t": Game.now(), "level": 1, "inside": {}})
	await get_tree().process_frame
	for uid in [9101, 9102]:
		grid.start_placing("chicken_coop", uid)
		_check(not grid.placing.is_empty(), "a coop beside another is lifted (%d)" % uid)
		for i in 3:
			await get_tree().process_frame
		grid.cancel_placing()
		await get_tree().process_frame
	var kinds := {}
	for id: String in Game.items:
		var def: Object = Game.catalog.get_def(id)
		if def == null or def is CropDef or kinds.has(def.get_script()):
			continue
		Game.set_objects([])
		var at := Game.free_spot_for(id)
		if at.x < 0:
			continue
		kinds[def.get_script()] = true
		Game.add_object({"uid": 9200, "id": id, "row": at.x, "col": at.y, "t": Game.now(), "level": 1, "inside": {}})
		await get_tree().process_frame
		grid.start_placing(id, 9200)
		_check(not grid.placing.is_empty(), "%s can be lifted" % id)
		await get_tree().process_frame
		grid.cancel_placing()
	_check(kinds.size() >= 4, "several kinds were lifted (%d)" % kinds.size())
	main.free()


## What a growing plant carries for the shader, and when the farm redraws it: the numbers stay small, a stage
## spans the right stretch of the growing time, and growing within a stage changes nothing to rebuild.
func test_207_a_growing_plant_carries_its_stage_and_the_shader_does_the_growing() -> void:
	# (Instance data stays small: the compatibility renderer keeps it as 16-bit floats, which overflow past 65,504
	# and went black when a colour was packed into one big number.)
	for started in [-200000.0, 0.0, 12.5, 90000.0]:
		for length in [0.0, 7200.0, 172800.0, 345600.0]:
			var data := Crops3D.pack(started, length, true)
			_check(is_equal_approx(data.r, started / 60.0) and is_equal_approx(data.g, length / 60.0) and data.b == 1.0,
				"start, length, richness are carried (%s)" % data)
			for v: float in [data.r, data.g, data.b]:
				_check(absf(v) < 20000.0, "%s is small enough for a 16-bit float" % v)
	var saved_plots: Array = Game.plots.duplicate(true)
	var saved_offset := Game.debug_time_offset
	var crop_id := str(Game.crops.keys()[0])
	var grow := float(Game.crops[crop_id]["grow_seconds"])
	for k in Game.plots.size():
		Game.plots[k] = {"state": "grass"}   # only this plot grows, so only it can change the picture
	var i := Game.index_of(1, 1)
	Game.plots[i] = {"state": "planted", "crop": crop_id, "planted_at": Game.now()}
	var seeds := Crops3D.stage_of(i)
	_eq(seeds, ["seeds", 0.0, 0.0, 0.0, false], "just planted: seeds, nothing growing yet")
	var planted := float(Game.plots[i]["planted_at"])
	Game.debug_time_offset = saved_offset + int(grow * (Crops3D.SPROUT_FROM + 0.01))
	var sprout := Crops3D.stage_of(i)
	_eq(str(sprout[0]), "sprout", "then a sprout")
	_check(is_equal_approx(float(sprout[1]), planted + Crops3D.SPROUT_FROM * grow), "that began at the sprouting point")
	var sprouting := (Crops3D.YOUNG_FROM - Crops3D.SPROUT_FROM) * grow
	_check(is_equal_approx(float(sprout[2]), sprouting), "and lasts until it is young")
	Game.debug_time_offset = saved_offset + int(grow * (Crops3D.YOUNG_FROM + 0.01))
	var young := Crops3D.stage_of(i)
	_eq(str(young[0]), "young", "then a young plant")
	var finishes := float(young[1]) + float(young[2])
	_check(is_equal_approx(finishes, planted + Crops3D.RIPEN_FROM * grow), "which grows until the ripe plant takes over")
	_check(float(young[3]) >= Crops3D.FROM_LEAST and float(young[3]) <= Crops3D.FROM_MOST,
		"starting at the height the sprout ended at (%.2f of its own)" % float(young[3]))
	# The ripe plant is drawn from before it is ripe: growing still, its fruit colouring up, so nothing snaps.
	Game.debug_time_offset = saved_offset + int(grow * (Crops3D.RIPEN_FROM + 0.01))
	var ripening := Crops3D.stage_of(i)
	_eq(str(ripening[0]), "ripe", "then the ripe plant, before it is ripe")
	_check(bool(ripening[4]), "its fruit ripening")
	_check(is_equal_approx(float(ripening[1]) + float(ripening[2]), planted + grow), "done growing exactly when ripe")
	_check(float(ripening[3]) >= Crops3D.FROM_LEAST and float(ripening[3]) <= Crops3D.FROM_MOST,
		"starting at the height the young plant ended at (%.2f of its own)" % float(ripening[3]))
	_eq(Game.field.phase(i), GameState.Phase.GROWING, "(the crop itself is still growing)")
	# Ripe: the same model stays, and it carries when it will start to wilt, and for how long, before it withers.
	Game.debug_time_offset = saved_offset + int(grow) + 5
	var ripe := Crops3D.stage_of(i)
	_eq(str(ripe[0]), "ripe", "ripe: the same plant, no change of model")
	_check(not bool(ripe[4]) and float(ripe[2]) < 0.0, "now carrying its wilting (a negative stretch)")
	var window := float(Game.field.window_of(Game.plots[i], Game.crops[crop_id]))
	_check(is_equal_approx(float(ripe[1]) - float(ripe[2]), planted + grow + window), "which ends as it withers")
	_check(is_equal_approx(-float(ripe[2]), Crops3D.WILT_SHARE * window), "and takes the last part of its ripe time")
	var carried := Crops3D.pack(60.0, 120.0, true, 0.5, 0.4, true)
	_check(is_equal_approx(carried.b, 1.4) and is_equal_approx(Crops3D.mastered_in(carried), 0.5) and carried.a >= 1.0,
		"richness, start size, mastery and ripening share two numbers and come back whole (%s)" % carried)
	Game.debug_time_offset = saved_offset + int(grow * (Crops3D.YOUNG_FROM + 0.01))
	# Within a stage the picture does not change, so nothing is laid out again as time passes.
	var crops := Crops3D.new()
	var before: Array = crops.call("_look_of", i)
	Game.debug_time_offset += int(grow * 0.05)
	_eq(crops.call("_look_of", i), before, "growing within a stage leaves the plot's look as it was")
	crops.free()
	Game.debug_time_offset = saved_offset
	Game.plots = saved_plots


## Trees in a row crowd each other's crowns on screen; a tap in the middle of a crown still picks that tree, and so
## does a tap on its trunk.
func test_208_a_tap_on_a_tree_in_a_grove_picks_that_tree() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.objects.clear()
	var tree_id := ""
	for id: String in Game.items:
		if Game.catalog.get_def(id) is TreeDef:
			tree_id = id
			break
	_check(tree_id != "", "there is a kind of tree")
	for k in 3:
		Game.objects.append({"uid": 9100 + k, "id": tree_id, "row": 6, "col": 4 + k, "t": Game.now()})
	Game.rebuild_occupancy()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var world: Farm3D = main.get("world_3d")
	if world == null:
		main.free()
		_check(false, "the farm is drawn in 3D")
		return
	var grid: FarmGrid = main.get("grid")
	var views: Dictionary = world.objects.get("_views")
	for k in 3:
		var uid := 9100 + k
		var crown: Dictionary = views[uid]["crown"]
		var middle := world.camera.unproject_position(crown["centre"])
		_eq(grid.picker.call(middle), uid, "a tap in the middle of tree %d's crown picks it" % k)
		var trunk_box: AABB = crown["trunk"]
		var foot := world.camera.unproject_position(Vector3(trunk_box.get_center().x, trunk_box.position.y + 0.06,
			trunk_box.get_center().z))   # low down, where no crown in front of it covers it
		_eq(grid.picker.call(foot), uid, "and a tap on its trunk picks it too")
	main.free()


func test_209_the_2d_fallback_joins_fences_on_the_sides_the_farm_says() -> void:
	var g := PackedVector2Array([Vector2(0, -32), Vector2(64, 0), Vector2(0, 32), Vector2(-64, 0)])
	_eq(PlaceholderArt._arm_ends(g, Vector2.ZERO, -1).size(), 2, "unknown joins: the one run across the tile")
	var alone := PlaceholderArt._arm_ends(g, Vector2.ZERO, 0)
	_check(alone.size() == 2 and alone[0].length() < 40.0, "alone: a short post, not a run to the edge")
	_eq(PlaceholderArt._arm_ends(g, Vector2.ZERO, LinkShape.N | LinkShape.E).size(), 2, "a corner has two arms")
	_eq(PlaceholderArt._arm_ends(g, Vector2.ZERO, 15).size(), 4, "a cross has four")
	var north := PlaceholderArt._arm_ends(g, Vector2.ZERO, LinkShape.N)
	_check(north[0].is_equal_approx(Vector2(32, -16)), "north is the tile's upper-right edge")
	_check(north.size() == 2 and north[1].length() < north[0].length(), "and a free end stubs out the other way")


func test_210_rain_wets_and_snow_settles_gradually_and_both_fade() -> void:
	var rain := {"rain": 0.7, "snow": 0.0}
	var w := SurfaceWeather.new()
	w.advance(rain, 1.0)
	_check(w.wet > 0.0 and w.wet < 0.1, "a second of rain wets a little, not all at once (%.3f)" % w.wet)
	w.advance(rain, 60.0)
	_eq(w.wet, 1.0, "a long shower soaks everything")
	w.advance({"rain": 0.0, "snow": 0.0}, 10.0)
	_check(w.wet < 1.0 and w.wet > 0.8, "it dries out slowly (%.3f)" % w.wet)
	w.advance({"rain": 0.0, "snow": 0.7}, 90.0)
	_eq(w.snow, 1.0, "snow builds up")
	w.advance({"rain": 0.0, "snow": 0.0}, 200.0)
	_eq(w.snow, 0.0, "and melts away")
	_eq(w.wet, 0.0, "the ground is dry again")
	w.free()
	for shader in ["ground3d", "wall3d", "paint3d", "canopy3d", "foliage3d"]:
		var code := FileAccess.get_file_as_string("res://shaders/%s.gdshader" % shader)
		_check(code.contains("global uniform float snow_cover") and code.contains("global uniform float wetness"),
			"%s shows the weather" % shader)


func test_211_a_timer_tick_looks_only_at_what_time_changes() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.open_showcase()
	for o in Game.objects:
		var kind := Game.kind_of(o)
		_eq(Objects3D.timed(o), Objects3D.TIMED_KINDS.has(kind) or Game.under_construction(o),
			"%s: timed only if time can change it" % o["id"])
	var kinds := {}
	for o in Game.objects:
		kinds[Game.kind_of(o)] = true
	_check(kinds.has("tree") and kinds.has("decor"), "the showcase has both kinds of thing")
	Game.reset_game()


func test_307_every_building_site_stays_inside_its_tile_border() -> void:
	for id: String in Game.items:
		if not Game.catalog.get_def(id) is BuildingDef:
			continue
		var fp := Game.footprint(id)
		var room := SpaceFit.tile_room(fp).grow(0.02)
		for progress: float in [0.1, 0.4, 0.7, 0.95]:
			var model := ModelKit.bake(BuildingModel.build_site(Game.item_data(id), fp, progress))
			var reach := SpaceFit.reach(model, model.transform)
			_check(room.encloses(reach), "%s's site at %.0f%% stays inside its tile border (reaches %s)" % [
				id, progress * 100.0, reach])
			model.free()


func test_310_everything_but_trees_as_placed_stay_inside_their_tile_border() -> void:
	# (Built the way the farm builds them, so the clamp is checked where it matters: a model that fits on its own can
	# still lose its fit when it is put in place. Trees overhang their tiles by design and are left out, as is the
	# grass drawn round everything.)
	var view := Objects3D.new()
	for id: String in Game.items:
		var def := Game.catalog.get_def(id)
		if not (def is BuildingDef or def is DecorationDef or def is BloomDef or def is VehicleDef or def is YoungDef) \
				or id.ends_with("_tree") or Game.links.group_of(id) != "":
			continue
		var fp := Game.footprint(id)
		var holder: Node3D = view._build({"uid": 7, "id": id, "row": 0, "col": 0, "t": Game.now()})
		var model := holder.get_child(0) as Node3D
		for fill: BuildingFill in model.find_children("*", "BuildingFill", true, false):
			if fill._props != null:
				fill._props.free()   # (the trees of the Barn's yard overhang as any tree does)
		var reach := SpaceFit.reach(model, model.transform)
		var room := SpaceFit.tile_room(fp).grow(0.02)
		room.position -= Vector2(fp) / 2.0   # (the model is measured about the footprint's centre)
		_check(room.encloses(reach), "%s as placed stays inside its tile border (reaches %s)" % [id, reach])
		holder.free()
	view.free()


func test_311_a_higher_level_never_shows_fewer_animals() -> void:
	for id: String in Game.items:
		var def := Game.catalog.get_def(id)
		if not (def is BuildingDef) or (def as BuildingDef).holds().is_empty():
			continue
		var inside := {}
		for aid: String in (def as BuildingDef).holds():
			inside[aid] = 40
		var top := Game.max_level(id)
		var last := 0
		for lv in range(1, top + 1):
			var radii: Array[float] = []
			for pick in BuildingFill.rarest(inside, BuildingFill.shown_cap(lv, top)):
				radii.append(BuildingFill.radius_of(Game.item_data(pick)))
			var n := BuildingFill.shown_count(id, lv, top, radii, 7)
			_check(n >= last, "%s shows %d at level %d, fewer than the %d below" % [id, n, lv, last])
			# (At full size: a small yard shows fewer, never smaller animals.)
			_check(n >= mini(radii.size(), 2), "%s shows at least 2 at level %d (shows %d)" % [id, lv, n])
			last = n


func test_312_gophers_and_dogs_stand_in_their_yard_clear_of_the_building() -> void:
	var homes := 0
	for id: String in Game.items:
		var def := Game.catalog.get_def(id)
		if not def is BuildingDef:
			continue
		var kind := str(BuildingSpec.fill_of(id, 1).get("stock", ""))
		if kind != "gophers" and kind != "dogs":
			continue
		homes += 1
		var fp := Game.footprint(id)
		var o := {"uid": 5, "id": id, "row": 0, "col": 0, "t": Game.now()}
		var count := BuildingStock.MAX_MOUNDS if kind == "gophers" else BuildingStock.MAX_DOGS
		var radius := BuildingStock.MOUND_RADIUS if kind == "gophers" else BuildingStock.DOG_RADIUS
		var fit := BuildingStock._in_yard(o, fp, count, radius)
		var yard := SpaceFit.yard_room(fp)
		var taken := BuildingSpec.taken(BuildingModel.spec(id, 1), fp)
		_check((fit["spots"] as Array).size() >= 1, "%s: at least one %s fits" % [id, kind])
		for at: Vector2 in fit["spots"]:
			_check(yard.has_point(at), "%s: a spot %s is inside the yard" % [id, at])
			for r: Rect2 in taken:
				_check(not r.has_point(at), "%s: a spot %s is not inside the building (%s)" % [id, at, r])
	_check(homes >= 2, "a gopher yard and a dog house were checked (%d)" % homes)


func test_313_every_tree_stands_on_a_bare_trunk_under_a_crown_that_is_not_a_blob() -> void:
	# The rule, measured on the tree as built: bare trunk for at least TRUNK_SHARE of the height, and a crown
	# that reaches no further than CROWN_REACH_MAX from the trunk. Palms and bananas are all trunk already.
	var holder := Node3D.new()
	add_child(holder)
	var checked := 0
	var trees: Array = []
	for id: String in Game.items:
		if str(Game.items[id].get("kind", "")) == "tree":
			trees.append(Game.items[id])
	# The decoration and scenery trees too (the willow's hanging curtain, the oak, the maple).
	for id: String in ["willow_tree", "oak_tree", "maple_tree"]:
		trees.append({"id": id})
	for it: Dictionary in trees:
		var id := str(it["id"])
		for seed_value in 4:
			for mask: int in [0, 0xff]:
				var tree := TreeModel.build_at(holder, Vector3.ZERO, it, 1.0, true, seed_value, true, TreeModel.UNSET,
					mask)
				if tree.has_meta(TreeModel.META_SHARE):
					var share := float(tree.get_meta(TreeModel.META_SHARE))
					var reach := float(tree.get_meta(TreeModel.META_REACH))
					_check(share >= TreeModel.TRUNK_SHARE - 0.001, "%s: trunk is %.2f of the height" % [id, share])
					_check(reach <= TreeModel.CROWN_REACH_MAX + 0.001, "%s: crown reaches %.2f" % [id, reach])
					checked += 1
				tree.free()
	_check(checked > 100, "trees were measured (%d)" % checked)
	holder.queue_free()


func test_314_animal_shades_are_one_batch_that_follows_them_and_frees_their_slots() -> void:
	var farm := Node3D.new()
	add_child(farm)
	var animals: Array[Animal3D] = []
	for k in 3:
		var a := Animal3D.create(Game.items["cow"], null, Vector3(2 + k * 2, 0, 3))
		farm.add_child(a)
		a.update(0.016)
		animals.append(a)
	var batch := ContactShades.of(animals[0])
	await get_tree().process_frame
	_eq(batch.get_parent(), farm, "one batch, under the farm")
	_eq(farm.find_children("*", "ContactShades", false, false).size(), 1, "and only one")
	var slot := animals[1]._shade_slot
	var at := batch.where_of(slot)
	_check(Vector2(at.x - 4.0, at.z - 3.0).length() < 0.6, "a cow's shade lies under it (%s)" % str(at))
	_check(batch.strength_of(slot) > 0.3, "and shows")
	animals[1].visible = false
	_eq(batch.strength_of(slot), 0.0, "a hidden cow's shade hides")
	animals[1].free()
	_check(batch.take() == slot, "a cow that leaves gives its slot to the next")
	farm.free()


func test_315_a_big_farm_is_built_over_frames_not_in_one_long_freeze() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.open_showcase()
	var objects := Objects3D.new()
	var began := Time.get_ticks_msec()
	add_child(objects)                       # its first sync runs here, on a budget
	var first := Time.get_ticks_msec() - began
	var views: Dictionary = objects.get("_views")
	var wanted := 0
	for o in Game.objects:
		if objects.handles(o):
			wanted += 1
	_check(views.size() < wanted, "the showcase isn't built all at once (%d of %d)" % [views.size(), wanted])
	_check(first < Objects3D.BUILD_BUDGET_MS * 20, "the first frame's share stays short (%d ms)" % first)
	var frames := 0
	while views.size() < wanted and frames < 400:
		await get_tree().process_frame
		frames += 1
	_eq(views.size(), wanted, "every object stands in the end (%d frames)" % frames)
	_check(not objects.get("_synced_once") or views.size() == wanted, "nothing drops in while it is laid out")
	objects.queue_free()
	await get_tree().process_frame
	Game.reset_game()


func test_316_graphics_quality_levels_set_the_world_and_are_kept() -> void:
	var keys := ["shadows", "shadow_splits", "shadow_distance", "glow", "scale", "lod_pixels", "pose_every",
		"crop_shadows", "max_fps", "screen_grade", "msaa", "shadow_size", "animal_shadows"]
	for name: String in Quality.LEVELS:
		for k: String in keys:
			_check(Quality.value(k, name) != null, "%s sets %s" % [name, k])
	_check(float(Quality.value("scale", "low")) < float(Quality.value("scale", "high")), "low draws fewer pixels")
	_check(not bool(Quality.value("shadows", "low")), "low has no shadows")
	var was := Quality.level()
	var sun := DirectionalLight3D.new()
	var env := Environment.new()
	var vp := SubViewport.new()
	for name: String in Quality.LEVELS:
		Quality.choose(name)
		_eq(Quality.level(), name, "%s is kept" % name)
		Quality.apply(sun, env, vp)   # (the frame cap follows the choice by itself)
		_eq(sun.shadow_enabled, bool(Quality.value("shadows")), "%s: shadows" % name)
		_eq(env.glow_enabled, bool(Quality.value("glow")), "%s: glow" % name)
		_check(is_equal_approx(vp.scaling_3d_scale, float(Quality.value("scale"))), "%s: resolution" % name)
		_check(is_equal_approx(vp.mesh_lod_threshold, float(Quality.value("lod_pixels"))), "%s: detail" % name)
		_eq(vp.msaa_3d, Quality.MSAA[int(Quality.value("msaa"))], "%s: anti-aliasing" % name)
		_eq(Engine.max_fps, int(Quality.value("max_fps")), "%s: frame cap" % name)
		_eq(Crops3D._shadow_setting() != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			bool(Quality.value("crop_shadows")), "%s: crop shadows" % name)
	_check(int(Quality.value("max_fps", "low")) > 0, "low caps the frame rate (a cheap phone runs cooler)")
	_eq(int(Quality.value("msaa", "low")), 0, "low draws without anti-aliasing")
	_check(int(Quality.value("msaa", "ultra")) > int(Quality.value("msaa", "high")), "ultra smooths edges more")
	_check(int(Quality.value("shadow_size", "ultra")) > int(Quality.value("shadow_size", "high")), "and sharper shadows")
	_check(not bool(Quality.value("screen_grade", "low")), "low skips the full-screen grade pass")
	Quality.choose(was)
	Engine.max_fps = 0
	sun.free()
	vp.free()


func test_317_big_baked_models_carry_simpler_levels_of_detail() -> void:
	var it := Game.item_data("cow_shed")
	var node := ModelKit.bake(BuildingModel.build(it, Game.footprint("cow_shed")))
	var with_lods := 0
	var meshes := 0
	for c in node.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is ArrayMesh:
			var m := (c as MeshInstance3D).mesh as ArrayMesh
			meshes += 1
			if int(m.get_meta(ModelKit.LOD_LEVELS, 0)) > 0:
				with_lods += 1
	_check(meshes > 0 and with_lods > 0,
		"the cow shed's big meshes have levels of detail (%d of %d)" % [with_lods, meshes])
	node.free()


## Global shader values are set only through ShaderGlobals (which remembers them; the engine can't be asked),
## except the crop clock, set every frame and never read back. Item pictures are kept on disk only on a calm
## day: never wet, snowy or dark.
func test_318_shader_globals_go_through_one_place_and_pictures_wait_for_calm() -> void:
	var direct := RegEx.create_from_string("global_shader_parameter_set\\((&?\"[a-z_]+\")")
	for dir in ["res://scripts", "res://autoload"]:
		for path in _gd_files(dir):
			if path.ends_with("shader_globals.gd"):
				continue
			for m in direct.search_all(FileAccess.get_file_as_string(path)):
				_check(m.get_string(1).contains("crop_clock"), "%s sets %s through ShaderGlobals" % [path, m.get_string(1)])
	ShaderGlobals.reset()
	_check(ItemIcons._calm(), "a fresh farm is calm")
	for mood in ItemIcons.MOODS:
		ShaderGlobals.set_value(mood, 0.5)
		_check(not ItemIcons._calm(), "%s: no picture is kept" % mood)
		ShaderGlobals.set_value(mood, 0.0)
	_check(ItemIcons._calm(), "calm again when it clears")
	_eq(float(ShaderGlobals.value(&"wetness")), 0.0, "the value is remembered")
	ShaderGlobals.reset()


static func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(d)))
	return out


## Each building is recognisable from its shape alone (docs/buildings plan): drawn from the camera at its first
## size, no two buildings look near the same. Each is rasterised on a grid (SILHOUETTE_GRID cells over
## SILHOUETTE_SPAN tiles of the view) as the height of what is seen in each cell, so a flat yard and a rock in it,
## or a tall roof and a low one, differ; two buildings are apart by the share of their cells that differ by more
## than a SILHOUETTE_STEP. Buildings whose look is what they hold (an orchard's trees, a garden's blooms) are
## told apart by that, not by their fences.


func test_320_every_building_has_its_own_silhouette() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BuildingModel.PATH))
	var shapes := {}
	for id: String in data["buildings"]:
		var it := Game.item_data(id)
		if it.is_empty() or LOOK_IS_CONTENTS.has(id) or int(it.get("unlock_level", 1)) >= 99 and id != "barn":
			continue
		var model := ModelKit.bake(BuildingModel.build(it, Game.footprint(id), 1))
		shapes[id] = _silhouette(model)
		model.free()
	var ids := shapes.keys()
	for a in ids.size():
		for b in range(a + 1, ids.size()):
			var x: PackedFloat32Array = shapes[ids[a]]
			var y: PackedFloat32Array = shapes[ids[b]]
			var seen := 0
			var differ := 0
			for k in x.size():
				if x[k] < 0.0 and y[k] < 0.0:
					continue
				seen += 1
				differ += 1 if x[k] < 0.0 or y[k] < 0.0 or absf(x[k] - y[k]) > SILHOUETTE_STEP else 0
			var apart := float(differ) / maxf(seen, 1.0)
			_check(apart >= SILHOUETTE_APART, "%s and %s look different (%.2f of their shape apart)" % [ids[a],
				ids[b], apart])


## The height of the highest surface the camera sees in each cell of its view (-1 where there is none).
static func _silhouette(root: Node3D) -> PackedFloat32Array:
	var cells := PackedFloat32Array()
	cells.resize(SILHOUETTE_GRID * SILHOUETTE_GRID)
	cells.fill(-1.0)
	var view := Basis.from_euler(Vector3(ItemIcons.PITCH, ItemIcons.YAW, 0.0))
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		var node: Node3D = top[0]
		var xf: Transform3D = top[1]
		for c in node.get_children():
			if not c is Node3D:
				continue
			var cxf := xf * (c as Node3D).transform
			stack.append([c, cxf])
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				var faces := (c as MeshInstance3D).mesh.get_faces()
				for k in range(0, faces.size(), 3):
					var tri: Array[Vector3] = []
					for j in 3:
						var p: Vector3 = cxf * faces[k + j]
						var flat := (Vector2(p.dot(view.x), p.dot(view.y)) / SILHOUETTE_SPAN + Vector2(0.5, 0.5)) \
							* SILHOUETTE_GRID
						tri.append(Vector3(flat.x, flat.y, p.y))
					_fill(cells, tri)
	return cells


## Fills a triangle (x, y on the grid, z its height) into `cells`, keeping the highest height in each.
static func _fill(cells: PackedFloat32Array, t: Array[Vector3]) -> void:
	var a := Vector2(t[0].x, t[0].y)
	var b := Vector2(t[1].x, t[1].y)
	var c := Vector2(t[2].x, t[2].y)
	var area := (b - a).cross(c - a)
	if absf(area) < 1e-6:
		return
	var lo := a.min(b).min(c).floor()
	var hi := a.max(b).max(c).ceil()
	for y in range(maxi(int(lo.y), 0), mini(int(hi.y), SILHOUETTE_GRID)):
		for x in range(maxi(int(lo.x), 0), mini(int(hi.x), SILHOUETTE_GRID)):
			var p := Vector2(x + 0.5, y + 0.5)
			var w0 := (b - p).cross(c - p) / area
			var w1 := (c - p).cross(a - p) / area
			var w2 := 1.0 - w0 - w1
			if w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0:
				var i := y * SILHOUETTE_GRID + x
				cells[i] = maxf(cells[i], w0 * t[0].z + w1 * t[1].z + w2 * t[2].z)


## The one ready sign (ReadyMarks) is over exactly what has something to collect: a home whose cycle is done, a
## tree, an animal; not over a building still working, a frame or a decoration.
## The starter Barn looks broken until repaired: another look (its own Instancer key) and a different model.
func test_321_ready_things_wear_the_one_sign_and_the_broken_barn_looks_broken() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.farm_size = 24
	Game.set_objects([])
	var long_ago := Game.now() - 10 * 86400
	var ready := {"uid": 9401, "id": "chicken_coop", "row": 1, "col": 1, "t": long_ago, "level": 1,
		"inside": {"chicken": 4}}
	var waiting := {"uid": 9402, "id": "cow_shed", "row": 1, "col": 8, "t": Game.now(), "level": 1,
		"inside": {"cow": 2}}
	var frame := {"uid": 9403, "id": "pig_pen", "row": 8, "col": 1, "t": long_ago, "level": 1, "inside": {},
		"construction": {}}
	var bale := {"uid": 9404, "id": "hay_bale", "row": 8, "col": 8, "t": long_ago}
	var tree := {"uid": 9406, "id": "apple_tree", "row": 16, "col": 2, "t": long_ago}
	var cow := {"uid": 9407, "id": "cow", "row": 16, "col": 10, "t": long_ago}
	for o in [ready, waiting, frame, bale, tree, cow]:
		Game.add_object(o)
	var objects := Objects3D.new()
	add_child(objects)
	await Objects3D.until_settled(get_tree(), 600)
	objects.sync()
	_check(Game.is_ready(tree) and Game.is_ready(cow), "(the tree and the cow are ready too)")
	_eq(objects.ready_marks(), 3, "one sign each over the ready Coop, tree and cow: not the Dairy at work, the "
		+ "frame or the bale")
	ready["t"] = Game.now()
	tree["t"] = Game.now()
	objects.sync()
	_eq(objects.ready_marks(), 1, "collected: their signs go, the cow's stays")
	# The cow's sign walks with it.
	var marks := objects.ready_marks_node()
	var beast := objects.view_of(int(cow["uid"])) as Animal3D
	beast.position += Vector3(1.5, 0, 0.5)
	marks.follow_animals()
	var sign_at := marks.where(0)
	var want := beast.position + Vector3(0, beast.reach().y + ReadyMarks.ABOVE, 0)
	_check(sign_at.is_equal_approx(want), "the cow's sign is over the cow after it walks (%s, %s)" % [sign_at, want])
	objects.queue_free()
	# The broken Barn.
	var it := Game.item_data("barn")
	var fp := Game.footprint("barn")
	var whole := ModelKit.bake(BuildingModel.build(it, fp, 1, true, false))
	var broken := ModelKit.bake(BuildingModel.build(it, fp, 1, true, true))
	var faces := [0, 0]
	for k in 2:
		for n in ([whole, broken][k] as Node3D).find_children("*", "MeshInstance3D", true, false):
			var planned := String(n.get_parent().name).begins_with(AssetRegistry.STATE + BuildingModel.PLAN)
			if (n as MeshInstance3D).mesh != null and not planned:   # (not the frame of what is still to come)
				faces[k] += (n as MeshInstance3D).mesh.get_faces().size()
	_check(faces[1] > faces[0], "the broken Barn has its tarp, gaps and loose boards (%d > %d)" % [faces[1], faces[0]])
	var barn := {"uid": 9405, "id": "barn", "row": 14, "col": 14, "t": Game.now(), "level": 1, "broken": true}
	var view := Objects3D.new()
	var key_broken: String = view.call("_key", barn)
	barn.erase("broken")
	_check(key_broken != view.call("_key", barn), "repairing it rebuilds its look")
	view.free()
	whole.free()
	broken.free()


## Plot by plot: planting or clearing one plot changes only that plot's plants (the rest of the field is kept as it
## was), and what is drawn is exactly what a full rebuild would draw.
func test_324_one_plot_changes_only_its_own_plants() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.farm_size = 20
	var crop_id: String = Game.crops.keys()[0]
	for r in 20:
		for c in 20:
			Game.plots[Game.index_of(r, c)] = {"state": "planted", "crop": crop_id, "planted_at": Game.now()}
	var crops := Crops3D.new()
	add_child(crops)
	var full := crops.plant_count()
	_eq(full, 400 * Crops3D.spots_of(crop_id).size(), "a planted 20x20 field: its plants on every plot")
	var i := Game.index_of(7, 7)
	Game.plots[i] = {"state": "plowed"}
	var began := Time.get_ticks_usec()
	crops.update([i])
	var one := Time.get_ticks_usec() - began
	_eq(crops.plant_count(), full - Crops3D.spots_of(crop_id).size(), "clearing one plot takes away its plants")
	Game.plots[i] = {"state": "planted", "crop": crop_id, "planted_at": Game.now()}
	crops.update([i])
	_eq(crops.plant_count(), full, "and planting it again brings them back")
	began = Time.get_ticks_usec()
	crops.update()
	var all := Time.get_ticks_usec() - began
	_eq(crops.plant_count(), full, "a full look changes nothing more")
	var fresh := Crops3D.new()
	add_child(fresh)
	_eq(fresh.plant_count(), crops.plant_count(), "the same as a farm built from scratch")
	print("PERF one plot %d us, whole field (nothing changed) %d us" % [one, all])  # not-ui
	crops.queue_free()
	fresh.queue_free()
	Game.reset_game()


func test_326_beds_tufts_and_plants_follow_each_plot_and_a_smaller_farm() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.farm_size = 12
	var crop_id: String = Game.crops.keys()[0]
	for r in 12:
		for c in 12:
			Game.plots[Game.index_of(r, c)] = {"state": "planted", "crop": crop_id, "planted_at": Game.now()}
	var plots := Plots3D.new()
	var ground := Ground3D.new()
	var crops := Crops3D.new()
	for n: Node in [plots, ground, crops]:
		add_child(n)
	var tufts := ground.farm_tuft_count()
	var i := Game.index_of(3, 4)
	Game.plots[i] = {"state": "grass"}
	plots.update([i])
	ground.update_tiles([i])
	var fresh_plots := Plots3D.new()
	var fresh_ground := Ground3D.new()
	add_child(fresh_plots)
	add_child(fresh_ground)
	_eq(plots.buffer(), fresh_plots.buffer(), "one plot back to grass: every bed slot matches a field built from scratch")
	_check(ground.farm_tuft_count() > tufts, "and grass grows tufts on it again")
	_eq(ground.farm_tuft_count(), fresh_ground.farm_tuft_count(), "the same tufts as a fresh ground")
	# A load or a reset can make the farm smaller: nothing it drew past the new edge stays behind.
	Game.farm_size = 6
	crops.update()
	var small := Crops3D.new()
	add_child(small)
	_eq(crops.plant_count(), small.plant_count(), "plants on the smaller farm only")
	_eq(crops.plant_count(), 35 * Crops3D.spots_of(crop_id).size(),
		"six by six plots of plants, less the one back to grass")
	plots.update([])
	ground.update_tiles([])
	var small_plots := Plots3D.new()
	var small_ground := Ground3D.new()
	add_child(small_plots)
	add_child(small_ground)
	_eq(plots.buffer(), small_plots.buffer(), "the beds follow the smaller farm")
	_eq(ground.farm_tuft_count(), small_ground.farm_tuft_count(), "and so do the tufts")
	var tufts_small := ground.farm_tuft_count()
	ground.update_tiles([Game.index_of(10, 10)])
	_eq(ground.farm_tuft_count(), tufts_small, "a tile off the farm now is ignored")
	small_plots.queue_free()
	small_ground.queue_free()
	for n: Node in [plots, ground, crops, fresh_plots, fresh_ground, small]:
		n.queue_free()
	Game.reset_game()



## Decorations and blooms are built once per look and shared (Instancer): two of a kind in the same look share
## their meshes, and what changes a look (a sign's mastered crop) gives a new one; a bloom's
## life is its shader's, not a new look.
func test_329_decor_and_blooms_share_built_looks_by_what_they_show() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Instancer.clear()
	var objects := Objects3D.new()
	add_child(objects)
	var deco := ""
	for id: String in Game.items:
		var it: Dictionary = Game.items[id]
		if str(it.get("kind", "")) == "decor" and Game.links.group_of(id) == "" and Game.footprint(id) == Vector2i.ONE \
				and id not in ["mastery_sign", "perfect_bunch"]:
			deco = id
			break
	var look := Instancer.VARIANTS   # (two tiles VARIANTS apart along a row are the same variant)
	var a: Node3D = objects._build({"uid": 1, "id": deco, "row": 2, "col": 2})
	var b: Node3D = objects._build({"uid": 2, "id": deco, "row": 2, "col": 2 + look})
	# (A decoration is drawn in a batch with the others of its look: its node is only a stand-in.)
	_check(_mesh_ids(a).is_empty() and objects.decor.has_piece(1) and objects.decor.has_piece(2),
		"a %s is drawn by the decoration layer, not as meshes of its own" % deco)
	_check(objects.decor.meshes_of(1) == objects.decor.meshes_of(2) and not objects.decor.meshes_of(1).is_empty(),
		"two %s in one look share their meshes" % deco)
	var crops: Array = Game.crop_order.slice(0, 2)
	var s1: Node3D = objects._build({"uid": 3, "id": "mastery_sign", "row": 4, "col": 4, "crop": crops[0]})
	var s2: Node3D = objects._build({"uid": 4, "id": "mastery_sign", "row": 4, "col": 4 + look, "crop": crops[1]})
	_check(objects.decor.meshes_of(3) != objects.decor.meshes_of(4), "mastery signs for two crops are built apart")
	var bloom := ""
	for id: String in Game.items:
		if str(Game.items[id].get("kind", "")) == "bloom":
			bloom = id
			break
	var cycle := int(Game.item_data(bloom).get("cycle_seconds", 86400))
	var young: Node3D = objects._build({"uid": 5, "id": bloom, "row": 6, "col": 6, "t": Game.now()})
	var ready: Node3D = objects._build({"uid": 6, "id": bloom, "row": 6, "col": 6 + look, "t": Game.now() - cycle - 1})
	_check(_mesh_ids(young) == _mesh_ids(ready), "a bloom is one model in bud and in bloom (its shader opens it)")
	for n: Node in [a, b, s1, s2, young, ready, objects]:
		n.free()
	Game.reset_game()


## The meshes of the model drawn under `node`, by identity (the grass and stones at its foot are the
## DecorLayer's, never under it).
func _mesh_ids(node: Node) -> Array:
	var out: Array = []
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		out.append((mi as MeshInstance3D).mesh.get_instance_id())
	return out


## The crops' clock wakes only when the soonest plot is due to change look: before then a tick changes nothing.
func test_333_the_crop_clock_wakes_only_when_a_plot_is_due() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	var crop: String = Game.crop_order[0]
	var grow := int(Game.crops[crop]["grow_seconds"])
	for k in Game.plots.size():
		Game.plots[k] = {"state": "grass"}   # (only this plot grows: a new farm's own crops have their own due times)
	var i := Game.index_of(1, 1)
	Game.plots[i] = {"state": "planted", "crop": crop, "planted_at": Game.now()}
	var crops := Crops3D.new()
	add_child(crops)
	_eq(crops.due(), int(Game.plots[i]["planted_at"]) + ceili(Crops3D.SPROUT_FROM * grow), "due when the seeds sprout")
	var seeds: Array = crops._plot_look[i]
	crops._on_clock()
	_eq(crops._plot_look[i], seeds, "a tick before then changes nothing")
	Game.debug_time_offset += ceili(Crops3D.SPROUT_FROM * grow) + 1
	crops._on_clock()
	_check(crops._plot_look[i] != seeds, "at the due time the sprouts show")
	_eq(crops.due(), int(Game.plots[i]["planted_at"]) + ceili(Crops3D.YOUNG_FROM * grow), "next: young plants")
	Game.debug_time_offset += ceili((Crops3D.YOUNG_FROM - Crops3D.SPROUT_FROM) * grow)
	crops._on_clock()
	_eq(crops.due(), int(Game.plots[i]["planted_at"]) + ceili(Crops3D.RIPEN_FROM * grow), "then: the ripe plant, ripening")
	Game.debug_time_offset += grow
	crops._on_clock()
	_eq(Crops3D.stage_of(i)[0], "ripe", "(ripe now)")
	_check(crops.due() > Game.now(), "and next it withers")
	crops.free()
	Game.debug_time_offset = 0
	Game.reset_game()


## Far out over a big farm, the signs over small things fade and the buildings' stay; the night stays playable.
func test_335_far_out_small_signs_fade_and_night_stays_playable() -> void:
	_eq(ReadyMarks.minor_fade(ReadyMarks.MINOR_FADE_FROM - 1.0), 0.0, "close in, every sign shows")
	_eq(ReadyMarks.minor_fade(ReadyMarks.MINOR_FADE_TO + 1.0), 1.0, "far out, small things' signs are gone")
	_check(Farm3D.NIGHT_AMBIENT >= 0.4 and Farm3D.MOON_ENERGY >= 0.5, "a bright moonlit night")
	DayCycle.set_always_day(true)
	_eq(DayCycle.lit_hour(23.0), DayCycle.SUNSET - 0.25, "always daytime: the night keeps the evening's light")
	_eq(DayCycle.lit_hour(3.0), DayCycle.SUNRISE + 0.75, "and the small hours the morning's")
	_eq(DayCycle.darkness(DayCycle.lit_hour(23.0)), 0.0, "never dark")
	DayCycle.set_always_day(false)
	_eq(DayCycle.lit_hour(23.0), 23.0, "off: the clock's own hour")


## A pond stands on the farm's ground, never in it: the ground is one solid sheet that hides anything below it
## (a pond dug under it showed only its stones on a phone). Its bank, bed and water are at or above y 0 (stones and
## pebbles may sit a little into the ground, as stones do).
func test_336_a_pond_stands_on_the_ground_never_under_it() -> void:
	var root := Node3D.new()
	PondModel.build(root, Vector3(0.5, 0, 0.5), 0.4, 0.34, 3)
	var lowest := INF
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var box: AABB = g.transform * (g as VisualInstance3D).get_aabb()
		if box.size.x > 0.3:   # (the bank and bed, and the water: the pond itself)
			lowest = minf(lowest, box.position.y)
	_check(lowest >= 0.0, "nothing below the ground (lowest %.3f)" % lowest)
	_check(PondModel.WATER_LEVEL > PondModel.DEEP_HEIGHT, "the water stands over its bed")
	root.free()


## Performance is a rule, not a hope: the showcase farm (the heaviest there is) stays inside data/perf_budget.json
## on the phone's level, counted as the renderer would: each mesh or batch drawn, plus again in the sun's shadow
## when it casts one, and their triangles.
func test_338_the_heaviest_farm_stays_inside_its_draw_budget() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/perf_budget.json"))
	var was_level := Quality.level()
	Game.saving_enabled = false
	for budget: Dictionary in data["budgets"]:
		Quality._level = str(budget["level"])
		Quality.notifier.emitted.emit()
		Game.reset_game()
		# (the same showcase every time: its random picks moved the count by ~3k triangles run to run, 2.297-2.302M
		# against 2.3M, so the budget failed one precheck in three without anything changing)
		Game.rng.seed = BUDGET_SEED
		ShowcaseFarm.build(Game)
		var objects := Objects3D.new()
		add_child(objects)
		await Objects3D.until_settled(get_tree(), 3000)
		objects.sync()
		var cost := Objects3D.draw_cost(objects)
		var name := str(budget["name"])
		print("PERF %s budget (%s): %d draws, %d triangles; target %s draws" % [name, budget["level"], cost.x, cost.y,
			budget.get("target_draws", "-")])  # not-ui
		_check(cost.x <= int(budget["draws"]), "%s: draws %d within %d" % [name, cost.x, int(budget["draws"])])
		_check(cost.y <= int(budget["triangles"]), "%s: triangles %d within %d" % [name, cost.y, int(budget["triangles"])])
		objects.free()
		await get_tree().process_frame
	Game.reset_game()
	Quality._level = was_level
	Quality.notifier.emitted.emit()


func test_345_a_kept_model_comes_back_the_same_and_shares_its_materials() -> void:
	ModelStore.stamp = "test"
	ModelStore.target = "user://test_models"
	var build := func() -> Node3D:
		var root := Node3D.new()
		ModelKit.box(root, Vector3.ZERO, Vector3.ONE * 0.5, ModelKit.paint(Color.RED))
		return ModelKit.bake(root)
	var built := ModelStore.cached("test-box", build)
	_eq(ModelStore.saved > 0, true, "a new model is kept")
	ModelStore.target = ""
	var path := "user://test_models/" + "test-box".md5_text() + ".scn"
	_check(FileAccess.file_exists(path), "on disk")
	var scene := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var again := scene.instantiate() as Node3D
	ModelStore._relink(again)
	var a := built.get_child(0) as MeshInstance3D
	var b := again.get_child(0) as MeshInstance3D
	_eq(b.mesh.get_surface_count(), a.mesh.get_surface_count(), "the same mesh comes back")
	_eq(ModelStore.signature(b.get_surface_override_material(0)), ModelStore.signature(a.get_surface_override_material(0)),
		"with the same material settings")
	var again2 := scene.instantiate() as Node3D
	ModelStore._relink(again2)
	_check((again2.get_child(0) as MeshInstance3D).get_surface_override_material(0) == b.get_surface_override_material(0),
		"two loaded copies share one material")
	for n: Node in [built, again, again2]:
		n.free()
	ModelStore._remove_tree("user://test_models")
	ModelStore.stamp = ""


func test_353_crops_stand_level_and_show_their_harvest() -> void:
	# Every crop stands about as tall as the next (data/crop_forms.json "look"), ripe or growing.
	var cap := CropForms.look("height", 0.0)
	_check(cap > 0.0, "the height crops are kept to is set")
	for form: String in CropForms.forms():
		_check(CropModels.mesh(form, "ripe").get_aabb().end.y <= cap + 0.001, "ripe %s stands no taller than the rest" % form)
		_check(CropModels.mesh(form, "young").get_aabb().end.y <= cap * CropForms.look("young", 1.0) + 0.001,
			"growing %s stands no taller than the rest" % form)
	# A tall plant's stem is shortened under its produce, which keeps its size and stays on top.
	var tall := MeshBuilder.new()
	tall.cone(Vector3.ZERO, 0.01, 0.01, 0.6, Color.GREEN, 4)
	tall.ellipsoid(Vector3(0, 0.65, 0), Vector3.ONE * 0.05, Color(1, 1, 1, 0.0))
	var fitted := CropModels._fit(tall.commit(), 0.2)
	_check(absf(fitted.get_aabb().end.y - 0.2) < 0.001, "a tall plant is brought down to the shared height")
	_check(absf(fitted.get_aabb().size.x - 0.1) < 0.005, "and its produce keeps its size")
	var cols: PackedColorArray = CropModels._fit(tall.commit(), 0.2, 0.5).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	_check(cols[0].g < 0.6, "a ripe plant's green leaves are darkened, so its harvest stands out")
	# A crop drawn a plot at a time stands once on its plot, covers it from edge to edge and shows its produce.
	_check(CropForms.is_plot("watermelon") and not CropForms.is_plot("no_such_form"), "crops are drawn a plot at a time")
	_eq(Crops3D.spots_of("watermelon").size(), 1, "such a crop stands once on its plot")
	_eq(Crops3D.spots_of("no_such_crop").size(), 9, "a crop whose form is not, in three rows of three")
	for form: String in CropForms.forms():
		if CropForms.is_plot(form):
			var box := CropModels.mesh(form, "ripe").get_aabb()
			_check(box.size.x * Crops3D.PLANT_SCALE >= 1.0 and box.size.z * Crops3D.PLANT_SCALE >= 1.0,
				"ripe %s covers its plot, so plots of it join" % form)
			_check(CropModels.mesh(form, "sprout").get_aabb().size.x * Crops3D.PLANT_SCALE > 0.5,
				"%s sprouts all over its plot" % form)
	# Small produce is drawn bigger than asked, big produce and leaves as asked.
	for part: Array in [[0.01, 0.0, 2.0, "small produce is drawn bigger"], [0.06, 0.0, 1.0, "big produce as asked"],
			[0.01, 1.0, 1.0, "a leaf as asked"]]:
		var mb := MeshBuilder.new()
		mb.produce_scale = 2.0
		mb.ellipsoid(Vector3.ZERO, Vector3.ONE * float(part[0]), Color(1, 1, 1, float(part[1])))
		_check(absf(mb.commit().get_aabb().size.y - 2.0 * float(part[0]) * float(part[2])) < 0.001, str(part[3]))


## Standalone decorations are drawn in batches (DecorLayer): what they cost to draw follows how many kinds
## there are, not how many things; one moved, lifted or sold is followed by its batch.
func test_356_decorations_are_drawn_in_batches_that_follow_each_one() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Instancer.clear()
	for i in Game.plots.size():
		Game.plots[i] = {"state": "grass"}
	var objects := Objects3D.new()
	add_child(objects)
	var uids: Array[int] = []
	for k in 12:
		var o := {"uid": Game.next_uid, "id": "bench" if k % 2 == 0 else "garden_gnome", "row": 2, "col": 1 + k,
			"t": Game.now()}
		Game.next_uid += 1
		Game.add_object(o)
		uids.append(int(o["uid"]))
	for k in 40:   # (a farm is built over frames: until everything stands)
		objects.sync()
	objects.decor.flush()
	var twelve := objects.decor.counts()
	_check(objects.decor.has_piece(uids[0]) and objects.decor.has_piece(uids[11]) and twelve.y >= 12,
		"each decoration stands in the layer (%s)" % twelve)
	var meshes := 0
	for uid: int in uids:
		meshes += (objects.call("_node", uid) as Node3D).find_children("*", "MeshInstance3D", true, false).size()  # not-ui
	_eq(meshes, 0, "none of them is drawn as meshes of its own")
	for k in 12:   # twice as many of the same two kinds, in the same region: no more batches
		var o := {"uid": Game.next_uid, "id": "bench" if k % 2 == 0 else "garden_gnome", "row": 4, "col": 1 + k,
			"t": Game.now()}
		Game.next_uid += 1
		Game.add_object(o)
	for k in 40:
		objects.sync()
	objects.decor.flush()
	_eq(objects.decor.counts().x, twelve.x, "twice the decorations of the same kinds are the same batches")
	# Moved: it stands at its new place, once. In hand: it shows nothing. Sold: it has gone.
	var first := Game.object_by_uid(uids[0])
	_check(Game.move_object(uids[0], 8, 8), "a bench moves")
	objects.queue_sync()             # (as the farm does when something on it changes)
	await get_tree().process_frame   # (the stand-in it had goes at the end of the frame: its thing must stay)
	await get_tree().process_frame
	objects.decor.flush()
	_check(objects.decor.has_piece(uids[0]), "the moved bench still stands in the layer")
	_check(absf(objects.decor.transform_of(uids[0]).origin.z - 8.5) < 0.8, "at its new place (%s)"
		% objects.decor.transform_of(uids[0]).origin)
	objects.call("_show", uids[0], false)
	_check(objects.decor.transform_of(uids[0]).basis.get_scale().length() < 0.001, "in hand it is drawn as nothing")
	objects.call("_show", uids[0], true)
	_check(objects.decor.transform_of(uids[0]).basis.get_scale().length() > 0.5, "and put down it stands again")
	Game.remove_object(first)
	objects.sync()
	await get_tree().process_frame
	_check(not objects.decor.has_piece(uids[0]), "sold, it has left the layer")
	objects.queue_free()
	Game.reset_game()
	await get_tree().process_frame


## A change on the farm lays again only the plots whose tile holds something else now: none when a thing is
## turned, the tiles it left and took when it moves (the whole field was laid again after every change).
func test_357_only_the_plots_under_what_moved_are_laid_again() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	for i in Game.plots.size():
		Game.plots[i] = {"state": "grass"}
	var told: Array = []
	var listen := func(i: int) -> void: told.append(i)
	Game.plot_changed.connect(listen)
	var bench := {"uid": Game.next_uid, "id": "bench", "row": 3, "col": 3, "t": Game.now()}
	Game.next_uid += 1
	Game.add_object(bench)
	Game.objects_updated()
	_eq(told, [Game.index_of(3, 3)], "placed: the one tile it stands on")
	var tiles := Game.tiles_revision
	told.clear()
	bench["flip"] = true
	Game.objects_updated()
	_check(told.is_empty(), "turned: no plot is laid again (%s)" % [told])
	_eq(Game.tiles_revision, tiles, "and nothing that follows the ground is told it moved")
	bench["row"] = 5
	Game.objects_updated()
	told.sort()
	_eq(told, [Game.index_of(3, 3), Game.index_of(5, 3)], "moved: the tile it left and the tile it took")
	_check(Game.tiles_revision > tiles, "and the ground's followers know")
	Game.plot_changed.disconnect(listen)
	Game.reset_game()


## A thing that changes where it stands (fed, collected, grown ready) is told alone (Game.object_changed): the 3D
## world looks at it only and shows the change, the ground isn't redone; a move is still the whole farm's change.
func test_371_a_thing_changed_in_place_is_looked_at_alone() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.objects.clear()
	var cow := {"uid": 9101, "id": "cow", "row": 5, "col": 5, "t": Game.now()}
	Game.objects.append(cow)
	Game.rebuild_occupancy()
	Game.objects_updated()   # (the farm as set up, told: what stands where is known)
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var world: Farm3D = main.get("world_3d")
	_check(world != null, "the farm is drawn in 3D")
	if world == null:
		main.free()
		return
	var whole := [0]
	var one: Array[int] = []
	var count_whole := func() -> void: whole[0] += 1
	var count_one := func(uid: int) -> void: one.append(uid)
	Game.objects_changed.connect(count_whole)
	Game.object_changed.connect(count_one)
	var before := world.objects.ready_shown
	cow["t"] = Game.now() - int(Game.item_data("cow").get("cycle_seconds", 86400)) - 10   # (ready now)
	Game.objects_updated(9101)
	_eq(one, [9101] as Array[int], "the change is told for the cow alone")
	_eq(whole[0], 0, "and not as a change to the whole farm")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(world.objects.ready_shown == before + 1, "the cow wears its ready sign at once")
	Game.hold_updates()
	Game.objects_updated(9101)
	Game.objects_updated(9101)
	Game.release_updates()
	_eq(one.size(), 2, "changes held in a batch are told once a thing")
	_check(Game.move_object(9101, 7, 7), "the cow moves")
	_eq(whole[0], 1, "a move is the whole farm's change (what stands where changed)")
	Game.objects_updated(424242)
	_eq(whole[0], 2, "a thing not on the farm is told as a whole change, never lost")
	Game.objects_changed.disconnect(count_whole)
	Game.object_changed.disconnect(count_one)
	main.free()
	Game.reset_game()


## A standing decoration is grounded as an animal is: a contact shade in the farm's one batch of them, under it,
## gone while it is in hand, its slot given back when it goes; joined pieces (fences) and flat things get none.
func test_447_standing_decorations_have_a_contact_shade_as_animals_do() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	for i in Game.plots.size():
		Game.plots[i] = {"state": "grass"}
	var objects := Objects3D.new()
	add_child(objects)
	var gnome := {"uid": Game.next_uid, "id": "garden_gnome", "row": 3, "col": 3, "t": Game.now()}
	Game.next_uid += 1
	Game.add_object(gnome)
	var fence := {"uid": Game.next_uid, "id": "wooden_fence", "row": 6, "col": 6, "t": Game.now()}
	Game.next_uid += 1
	Game.add_object(fence)
	for k in 40:
		objects.sync()
	await get_tree().process_frame
	var shades := (objects.call("_node", int(gnome["uid"])) as Node3D).find_children("*", "GroundShade", true, false)
	_eq(shades.size(), 1, "a gnome has one contact shade")
	var shade := shades[0] as GroundShade
	var at := shade._shades.where_of(shade._slot)
	_check(Vector2(at.x - 3.5, at.z - 3.5).length() < 0.6, "under it (%s)" % str(at))
	_check(shade._shades.strength_of(shade._slot) > 0.5, "and it shows")
	_eq((objects.call("_node", int(fence["uid"])) as Node3D).find_children("*", "GroundShade", true, false).size(), 0,
		"a fence, joined to its neighbours, has none")
	_check(not GroundShade.fits(AABB(Vector3.ZERO, Vector3(1, 0.1, 1))), "nor has a flat thing")
	_check(not GroundShade.fits(AABB(Vector3.ZERO, Vector3(3, 2, 3))), "nor a large one (its tile is shaded)")
	objects.call("_show", int(gnome["uid"]), false)
	_eq(shade._shades.strength_of(shade._slot), 0.0, "in hand, its shade has gone")
	var slot := shade._slot
	var batch := shade._shades
	Game.remove_object(Game.object_by_uid(int(gnome["uid"])))
	objects.queue_sync()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(batch.take() == slot, "sold, it gives its slot back")
	# The farmer (and a vehicle at work) has one too, and it follows them.
	var farmer := Farmer3D.new()
	objects.add_child(farmer)
	await get_tree().process_frame
	var follows := farmer.find_children("*", "GroundShade", false, false)
	_eq(follows.size(), 1, "the farmer has a contact shade")
	var walker := follows[0] as GroundShade
	walker.global_position = Vector3(7, 0, 9)   # (the farmer walks where Game.player is: here, it is moved)
	await get_tree().process_frame
	var now := walker._shades.where_of(walker._slot)
	var feet := walker.global_position
	_check(Vector2(now.x - feet.x, now.z - feet.z).length() < 0.05, "that walks with them (%s)" % str(now))
	objects.queue_free()
	await get_tree().process_frame
	Game.reset_game()


func test_497_the_phone_benchmark_line_reads_back_whole() -> void:
	# The phone run (phone_bench.yml) reads the "BENCH {..}" lines in a phone's log: after every phase the report
	# so far, so a run cut short still says what it measured, and "done" says whether it got to the end (it keeps
	# the done one, else the longest: Robo relaunches the app after it quits, which starts a new report).
	var report := {"device": {"model": "test"}, "startup_ms": 12, "done": false, "showcase_cold": {"built_ms": 3}}
	var line := LoadBenchmark.line_of(report)
	_check(line.begins_with("BENCH {") and line.ends_with("}") and not line.contains("\n"), "one line (%s)" % line)
	var back: Variant = JSON.parse_string(line.trim_prefix(LoadBenchmark.MARK))
	_check(back is Dictionary and back.get("done") == false, "it says the run is not done yet")
	_eq(int((back as Dictionary).get("showcase_cold", {}).get("built_ms", -1)), 3, "and keeps what was measured")


func test_526_the_phone_report_says_where_the_start_went() -> void:
	# A phone's startup_ms (8.3 s on the Galaxy A05s) is split into the start's steps, in order: the engine up
	# (the first autoload), every script compiled (Game made), its systems made, the other autoloads made, the
	# catalog, data and save loaded, the main scene made, its 3D world, its HUD and its farm laid out.
	var marks := LoadBenchmark.start_marks()
	var last := 0
	for step in ["engine", "scripts", "made", "ready", "catalog", "data", "game", "main_made", "world", "hud",
			"main_built"]:
		_check(marks.has(step), "the start marks %s (%s)" % [step, str(marks)])
		_check(int(marks.get(step, -1)) >= last, "after the step before it (%s)" % str(marks))
		last = int(marks.get(step, last))
	_check(last <= Time.get_ticks_msec(), "and none is in the future")


func test_547_the_debug_tools_compile_after_the_first_screen() -> void:
	# The start marks its steps through StartMarks (the first autoload) and opens the showcase and the load trace
	# by path, so nothing on the way to the first screen names the debug tools (docs/PERF_RUN.md, the start).
	for path: String in ["res://autoload/game.gd", "res://scripts/main.gd", "res://scripts/world3d/objects_3d.gd",
			"res://autoload/start_clock.gd"]:
		var code := RegEx.create_from_string("#.*").sub(FileAccess.get_file_as_string(path), "", true)
		for tool in ["LoadBenchmark", "LoadTrace", "ShowcaseFarm"]:
			_check(not RegEx.create_from_string("\\b%s\\b" % tool).search(code), "%s does not name %s" % [path, tool])
	_eq(load(GameState.SHOWCASE_SCRIPT).get("SAVE_PATH"), GameState.SHOWCASE_SAVE_PATH, "the showcase's save is Game's")
	_eq(load(StartMarks.BENCHMARK).get("FEATURE"), StartMarks.BENCHMARK_FEATURE,
		"the benchmark is the one the start opens")
	_check(load(GameState.LOAD_TRACE_SCRIPT).has_method("mark"), "the trace is where Game opens it")
	_eq(LoadBenchmark.start_marks(), StartMarks.marks(), "the report reads the start's own marks")


func test_511_every_phone_build_ships_its_shaders_compiled() -> void:
	# A phone compiles a shader the first time something draws with it, a stall it feels (docs/PERF_RUN.md, win 1):
	# every Android export bakes them ahead (apk.yml exports under a Vulkan so the baker runs).
	var presets := _export_presets()
	var android := _android_options(presets)
	for section in android:
		_check(presets.get_value(section, "shader_baker/enabled", false) == true, "%s bakes its shaders" % section)
	_check(android.size() >= 2, "the Android presets are found (%d)" % android.size())


## export_presets.cfg, read once per test.
func _export_presets() -> ConfigFile:
	var presets := ConfigFile.new()
	_eq(presets.load("res://export_presets.cfg"), OK, "the export presets read")
	return presets


## The ".options" sections of the Android presets.
func _android_options(presets: ConfigFile) -> Array[String]:
	var found: Array[String] = []
	for section in presets.get_sections():
		var preset := (section as String).trim_suffix(".options")
		if preset != section and presets.get_value(preset, "platform", "") == "Android":
			found.append(section)
	return found


func test_535_every_phone_installs_it_and_plays_in_landscape() -> void:
	# Budget phones (a Galaxy A10, many A13s) run 32-bit Android: every Android export carries 32-bit and 64-bit
	# ARM, or such a phone cannot install the game (owner, 19 Nov). And a phone always plays in landscape.
	var presets := _export_presets()
	var android := _android_options(presets)
	for section in android:
		for arch in ["armeabi-v7a", "arm64-v8a"]:
			_check(presets.get_value(section, "architectures/" + arch, false) == true, "%s ships %s" % [section, arch])
	_check(android.size() >= 2, "the Android presets are found (%d)" % android.size())
	_eq(int(ProjectSettings.get_setting("display/window/handheld/orientation")), Display.ORIENTATION,
		"the phone's manifest asks for landscape, either way up")
	_check(Display.ORIENTATION in [DisplayServer.SCREEN_LANDSCAPE, DisplayServer.SCREEN_REVERSE_LANDSCAPE,
		DisplayServer.SCREEN_SENSOR_LANDSCAPE], "and it is a landscape one")


## The farmer's mesh, recoloured for the player's look, keeps the file's levels of detail: zoomed out it is drawn
## with half the triangles (it drew all 15k at every zoom), close up exactly as before.
func test_570_the_farmer_recoloured_keeps_its_levels_of_detail() -> void:
	var model := AssetRegistry.instance("%s%s_%s" % [Farmer3D.FILE, "a", "short"])
	if model == null:
		_check(true, "(no farmer file: the farmer is built in code)")
		return
	var src := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var tints: Array[Color] = []
	for i in 6:
		tints.append(Color(0.5, 0.6, 0.7))
	var out := Farmer3D.tinted(src.mesh as ArrayMesh, tints)
	for s in src.mesh.get_surface_count():
		var had := Farmer3D.surface_lods(src.mesh, s)
		var kept := Farmer3D.surface_lods(out, s)
		_check(not had.is_empty(), "the file has levels of detail")
		_eq(kept.size(), had.size(), "the recoloured farmer keeps every level")
		for edge in had:
			_check(kept.has(edge) and kept[edge] == had[edge], "level %s: the same triangles" % edge)
	_eq(out.get_blend_shape_count(), src.mesh.get_blend_shape_count(), "and its moves")
	model.free()


func test_571_the_phone_report_says_where_a_play_frame_goes() -> void:
	# A play frame of 95 ms on the Galaxy A05s does not say whether the GPU or the scripts are the wall: the play
	# phase keeps each frame's render CPU and GPU time and the scripts' time, reported as medians (a level stepped
	# down mid-phase skews a maximum, not a median).
	_eq(LoadBenchmark.medians({"gpu": [9.0, 1.0, 4.04], "none": []}), {"gpu": 4.0, "none": 0.0},
		"each list's middle value, to a tenth; nothing measured is 0")
	var lines := LoadBenchmark.summary({"play": {"avg_ms": 95.0, "split": {"render_gpu_ms": 80.0}}})
	_check(lines.contains("GPU 80"), "the summary says it (%s)" % lines)


func test_572_the_phone_report_says_whose_meshes_cost_the_gpu() -> void:
	# The A05s's play frame is GPU-bound (run 21: 93.6 ms of GPU, 3.4 ms of render CPU): the owner sweep names
	# whose meshes the GPU time goes to, by the nearest named script above a mesh (perf_probe uses the same rule).
	var holder := Node3D.new()
	holder.set_script(load("res://scripts/world3d/ground_shade.gd"))
	var mid := Node3D.new()
	var mesh := MeshInstance3D.new()
	holder.add_child(mid)
	mid.add_child(mesh)
	_eq(LoadBenchmark.owner_of(mesh), "GroundShade", "a mesh belongs to the nearest named script above it")
	var lone := Node3D.new()
	_eq(LoadBenchmark.owner_of(lone), "(none)", "a node with none above it: (none)")
	lone.free()
	holder.free()


func test_577_the_building_builders_compile_when_a_look_is_built() -> void:
	# The farm asks what a building is (BuildingSpec) every sync; the builders (BuildingModel, BuildingDress, 2k
	# lines) load by path only when a look has to be built, which a look kept on disk never needs, so the start
	# does not compile them (docs/PERF_RUN.md, the start).
	for path: String in ["res://scripts/world3d/objects_3d.gd", "res://scripts/world3d/building_fill.gd",
			"res://scripts/world3d/decor_model.gd", "res://scripts/world3d/building_stock.gd",
			"res://scripts/ui/item_icons.gd", "res://scripts/world3d/building_spec.gd"]:
		var code := RegEx.create_from_string("#.*").sub(FileAccess.get_file_as_string(path), "", true)
		_check(not RegEx.create_from_string("\\bBuilding(Model|Dress)\\b").search(code),
			"%s does not name the builders" % path)
	_eq(BuildingSpec.model().resource_path, BuildingSpec.MODEL, "the builders come from their own file")
	for id: String in ["chicken_coop", "cow_shed"]:
		_eq(BuildingSpec.spec(id, 2), BuildingModel.spec(id, 2), "%s: one description, asked either way" % id)
	var built: Node3D = BuildingSpec.model().build(Game.item_data("chicken_coop"), Game.footprint("chicken_coop"))
	_check(built != null and built.get_child_count() > 0, "a building is still built through the path")
	built.free()
