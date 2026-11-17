extends TestSuite
## Assets made as files (docs/ASSETS.md): every listed asset loads, fits its budget and its footprint, and names
## its states the one way; the registry draws an unlisted or missing one as its stand-in; states show and hide
## the right parts; plain materials become the master material.

const TEST_FILE := "user://test_asset.scn"
const FIXTURE := "res://tests/fixtures/asset_fixture.glb"   # made by tools/make_asset_fixture.gd


func test_346_every_listed_asset_loads_fits_its_budget_and_its_footprint() -> void:
	var listed := (JSON.parse_string(FileAccess.get_file_as_string(AssetRegistry.DATA)) as Dictionary)
	var budgets: Dictionary = listed["budgets"]
	var found := {}   # animals that are found, not sold (the dogs): data/finds.json
	for family: Dictionary in (JSON.parse_string(FileAccess.get_file_as_string("res://data/finds.json")) as Dictionary) \
			.get("families", {}).values():
		for kind: Dictionary in family.get("kinds", []):
			found[str(kind.get("id", ""))] = true
	for id: String in listed["assets"]:
		var e: Dictionary = listed["assets"][id]
		var form := id.trim_prefix(AssetRegistry.CROP) if id.begins_with(AssetRegistry.CROP) else ""
		_check(not Game.item_data(id).is_empty() or Game.crops.has(id) or found.has(id)
			or form in ExportPlants.crop_forms() or id.begins_with(Farmer3D.FILE),
			"%s is a catalog item, a crop's form or the farmer" % id)
		_check(budgets.has(str(e.get("budget", ""))), "%s has a budget kind" % id)
		# (A tree's file holds each of its looks, ripe and not: one of them is drawn at a time. A building's holds
		# each level and state: it is counted at its top level, crafting and full, the most it ever draws.)
		var node := AssetRegistry.instance(id, {"look": 0, "ready": true, "level": Game.max_level(id), "working": true,
			"fill": BuildingDress.FULL})
		_check(node != null, "%s loads (%s)" % [id, e.get("model", "")])
		if node == null:
			continue
		var tris := AssetRegistry.triangles(node)
		var most := AssetRegistry.budget_of(id)
		_check(tris <= most, "%s: %d triangles within %d" % [id, tris, most])
		var draws := AssetRegistry.draws(node)
		_check(draws <= AssetRegistry.budget_of(id, "draws"), "%s: %d draws within %d" % [id, draws,
			AssetRegistry.budget_of(id, "draws")])
		var fp := Game.footprint(id)
		var box := SpaceFit.reach(node, node.transform)
		# (a tree's crown overhangs by design; an animal walks about its spot, and a horse is longer than a tile)
		if not str(e.get("budget", "")) in ["tree", "animal", "crop", "farmer"]:
			_check(box.size.x <= fp.x + 0.01 and box.size.y <= fp.y + 0.01, "%s fits its %s footprint" % [id, str(fp)])
		node.free()
	for form in ExportPlants.crop_forms():
		_check(listed["assets"].has(AssetRegistry.CROP + form), "crop form %s has its file" % form)


func test_347_an_unlisted_or_missing_asset_is_drawn_by_its_stand_in() -> void:
	_check(AssetRegistry.instance("no_such_item") == null, "an unlisted item has no file: its stand-in is drawn")
	AssetRegistry.add("test_missing", {"model": "res://art/models/not_there.glb", "budget": "decoration"})
	_check(not AssetRegistry.has_model("test_missing"), "a listed file that is missing counts as none")
	_check(AssetRegistry.instance("test_missing") == null, "and its stand-in is drawn")
	AssetRegistry.add("test_missing", {})


func test_348_states_show_their_parts_and_plain_materials_become_the_master() -> void:
	var root := Node3D.new()
	root.name = "Asset"
	var always := ModelKit.box(root, Vector3.ZERO, Vector3.ONE * 0.4, StandardMaterial3D.new())
	always.name = "body"
	for part: Array in [["when_ready_true", 1.0], ["when_level_2", 2.0], ["when_level_3", 3.0]]:
		var holder := Node3D.new()
		holder.name = str(part[0])
		root.add_child(holder)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2 * float(part[1]), 0.5, 0.3)
		ModelKit.box(holder, Vector3.ZERO, Vector3.ONE * 0.2, mat)
	for n in root.get_children():
		_own(n, root)
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, TEST_FILE)
	root.free()
	AssetRegistry.forget()
	AssetRegistry.add("test_asset", {"model": TEST_FILE, "budget": "decoration"})
	var node := AssetRegistry.instance("test_asset", {"ready": true, "level": 2})
	_check(node != null, "the file loads")
	_check((node.get_node("when_ready_true") as Node3D).visible, "a ready part shows while ready")
	_check((node.get_node("when_level_2") as Node3D).visible, "the level's part shows")
	_check(not (node.get_node("when_level_3") as Node3D).visible, "another level's part is hidden")
	_check((node.get_node("body") as Node3D).visible, "a part without a state always shows")
	AssetRegistry.apply_state(node, {"ready": false, "level": 3})
	_check(not (node.get_node("when_ready_true") as Node3D).visible, "and hides when no longer ready")
	_check((node.get_node("when_level_3") as Node3D).visible, "a new level shows its part")
	var mi := node.get_node("body").get_child(0) as MeshInstance3D if node.get_node("body").get_child_count() > 0 \
		else node.get_node("body") as MeshInstance3D
	var m := mi.get_active_material(0)
	_check(m is ShaderMaterial and (m as ShaderMaterial).shader == AssetRegistry.MASTER,
		"plain materials draw as the master")
	_check(AssetRegistry.triangles(node) > 0, "its triangles are counted")
	node.free()
	AssetRegistry.add("test_asset", {})
	AssetRegistry.forget()
	DirAccess.remove_absolute(TEST_FILE)


func _own(n: Node, owner: Node) -> void:
	n.owner = owner
	for c in n.get_children():
		_own(c, owner)


func test_349_a_real_gltf_file_goes_through_the_import_and_the_registry_rules() -> void:
	AssetRegistry.forget()
	AssetRegistry.add("asset_fixture", {"model": FIXTURE, "budget": "building"})
	_check(AssetRegistry.has_model("asset_fixture"), "the imported .glb loads as a scene")
	var node := AssetRegistry.instance("asset_fixture", {"ready": false})
	var body := _find(node, "body") as MeshInstance3D
	_check(body != null and body.mesh is ArrayMesh, "its parts keep their names through glTF")
	if body != null and body.mesh is ArrayMesh:
		_check((body.mesh as ArrayMesh).shadow_mesh != null, "the importer made a cheap shadow mesh")
		_check(body.get_active_material(0) is ShaderMaterial, "its plain material draws as the master")
	_check(not (_find(node, "when_ready_true") as Node3D).visible, "a state part follows the state")
	_check(AssetRegistry.triangles(node) <= AssetRegistry.budget_of("asset_fixture"), "within its triangles")
	_check(AssetRegistry.draws(node) <= AssetRegistry.budget_of("asset_fixture", "draws"), "within its draws")
	Objects3D.mark_parts(node)
	_check((_find(node, "door") as Node).has_meta(BuildingModel.DOOR), "a part named door swings")
	var marked := node.get_children().filter(func(c: Node) -> bool: return c.has_meta(BuildingModel.WINDOWS))
	_eq(marked.size(), 1, "its windows are where animals look out")
	if marked.size() == 1:
		_eq((marked[0].get_meta(BuildingModel.WINDOWS) as Array).size(), 1, "one window")
	node.free()
	AssetRegistry.add("asset_fixture", {})
	AssetRegistry.forget()


func test_350_see_through_glowing_or_two_sided_materials_are_kept_as_made() -> void:
	var plain := StandardMaterial3D.new()
	_check(AssetRegistry.is_plain(plain), "a plain opaque material becomes the master")
	for set_up: Callable in [func(m: StandardMaterial3D) -> void: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA,
			func(m: StandardMaterial3D) -> void: m.emission_enabled = true,
			func(m: StandardMaterial3D) -> void: m.cull_mode = BaseMaterial3D.CULL_DISABLED,
			func(m: StandardMaterial3D) -> void: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]:
		var m := StandardMaterial3D.new()
		set_up.call(m)
		_check(not AssetRegistry.is_plain(m), "a material set up on purpose is kept")
	var rough := StandardMaterial3D.new()
	rough.roughness = 0.3
	_check(AssetRegistry.master_for(rough) != AssetRegistry.master_for(plain), "a different roughness is its own master")


func _find(n: Node, part: String) -> Node:
	if String(n.name) == part:
		return n
	for c in n.get_children():
		var f := _find(c, part)
		if f != null:
			return f
	return null


func test_351_a_file_building_keeps_its_view_shows_states_in_place_and_opens_its_yard() -> void:
	AssetRegistry.forget()
	AssetRegistry.add("chicken_coop", {"model": FIXTURE, "budget": "building"})
	var objects := Objects3D.new()
	var coop := {"uid": 9001, "id": "chicken_coop", "row": 0, "col": 0, "level": 1}
	_check(objects.uses_file(coop), "a listed building is drawn from its file")
	_check(not objects.uses_file({"uid": 9002, "id": "white_picket_fence", "row": 0, "col": 0}),
		"a fence that joins its neighbours stays with the LinkLayer")
	_check(not objects.uses_file({"uid": 9003, "id": "cow", "row": 0, "col": 0}), "an animal waits for its own step")
	var key := objects._key(coop)
	var ready := coop.duplicate()
	ready["t"] = 0   # (a long time ago: ready)
	_eq(objects._key(ready), key, "coming ready doesn't rebuild it (no lost door swing or yard)")
	var higher := coop.duplicate()
	higher["level"] = 2
	_check(objects._key(higher) != key, "a new level is a new model")
	var node := AssetRegistry.instance("chicken_coop", objects.state_of(coop))
	Objects3D.mark_parts(node)
	var fill := BuildingFill.create(coop, node)
	_eq(fill._doors.size(), 1, "its door swings when collected")
	_eq(fill._windows.size(), 1, "its window is where animals look out")
	fill.free()
	node.free()
	objects.free()
	AssetRegistry.add("chicken_coop", {})
	AssetRegistry.forget()


func test_352_a_tap_lands_on_the_animal_under_it_and_a_window_shows_its_own_head() -> void:
	var goat := Animal3D.create(Game.item_data("boer_goat"), null, Vector3.ZERO)
	var box := goat.pick_box()
	_check(box.size.x < 1.0 and box.size.z < 1.0, "a goat's tap box is about its body, not a big square")
	var down := Vector3.DOWN
	_check(goat.hit(Vector3(0, 5, 0), down) < INF, "a tap on its middle lands on it")
	_eq(goat.hit(Vector3(0, 5, box.end.z + 0.2), down), INF, "a tap just beside it does not")
	goat.rotation.y = PI / 2.0
	_eq(goat.hit(Vector3(box.end.x - 0.02, 5, 0), down), INF, "its box turns as it faces")
	goat.free()
	var head := BuildingFill._head_mesh("cow")
	var cow := Animal3D.create(Game.item_data("cow"), null, Vector3.ZERO)
	_check(head != null and head.get_aabb().size.x < cow.pick_box().size.x / cow._size,
		"a window shows the cow's head cut from its file, not the whole cow")
	cow.free()


func test_353_an_items_picture_follows_its_art() -> void:
	var tree := ItemIcons._model("apple_tree")
	_check(AssetRegistry.triangles(tree) > 0, "a tree made as a file is pictured in a look")
	tree.free()
	var before := ItemIcons._key("cow")
	var files: Dictionary = ArtVersion._data["files"]
	var was: String = files["cow"]
	files["cow"] = "changed"
	_check(ItemIcons._key("cow") != before, "new art for the cow: its picture is made again")
	files["cow"] = was
	_eq(ItemIcons._key("cow"), before, "the same art: the same picture")
	_check(ArtVersion.of("wheat") != ArtVersion.of("cow"), "a crop's picture follows its own form's file")


func test_388_crafting_buildings_are_gltf_files_that_follow_the_art_rules() -> void:
	# The four crafting buildings are made as glTF files, one for each level (only the level that stands is
	# loaded), brought in by Godot's importer (shadow meshes). They draw with the master shader and the kit's own
	# shared glass, light pools, shade and water, nothing else. What changes with time (at work or not, how
	# full) is shown on the model that stands, never by building it again; what moves is a named part.
	var objects := Objects3D.new()
	var shared: Array = [ModelKit.glass(), ModelKit.glow_material(), ModelKit.shade_material(), ModelKit.water()]
	for id: String in ["bakery", "winery", "spa", "feed_mill"]:
		_check(AssetRegistry.has_model(id), "%s is made as a file" % id)
		for level in range(1, 5):
			var path := AssetRegistry.file_of(AssetRegistry.entry(id), {"level": level})
			_check(path.ends_with("_%d.glb" % level) and ResourceLoader.exists(path), "%s level %d has its own glTF file"
				% [id, level])
			var at_level := AssetRegistry.instance(id, {"level": level, "working": true, "fill": BuildingDress.FULL})
			var wrong := 0
			var shadowed := 0
			for mi: MeshInstance3D in at_level.find_children("*", "MeshInstance3D", true, false):
				if DecorMotion.is_part(mi.get_parent()) and not String(mi.get_parent().name).begins_with(DecorMotion.SPIN):
					continue   # (an effect the game started under a named part: smoke, steam)
				shadowed += 1 if (mi.mesh as ArrayMesh).shadow_mesh != null else 0
				for k in mi.mesh.get_surface_count():
					var mat := mi.get_active_material(k)
					var master := mat is ShaderMaterial and (mat as ShaderMaterial).shader == AssetRegistry.MASTER
					wrong += 0 if master or mat in shared else 1
			_eq(wrong, 0, "%s level %d draws with the master shader and the kit's shared materials only" % [id, level])
			_check(shadowed > 0, "%s level %d went through the importer (shadow meshes)" % [id, level])
			at_level.free()
		# Going up, it is drawn from files too: one for each stage.
		_check(AssetRegistry.has_site(id), "%s going up is made as files" % id)
		for stage in Objects3D.BUILD_STAGES:
			var going_up := AssetRegistry.instance(id, {"stage": stage})
			var site := ModelKit.bake(BuildingModel.build_site(Game.item_data(id), Game.footprint(id),
				stage / float(Objects3D.BUILD_STAGES)))
			_check(going_up != null and AssetRegistry.triangles(going_up) == AssetRegistry.triangles(site),
				"%s stage %d: its file shows what the builder makes" % [id, stage])
			if going_up != null:
				going_up.free()
			site.free()
	var mill := {"uid": 9101, "id": "feed_mill", "row": 0, "col": 0, "level": 4, "built": true, "slots": []}
	_check(objects.uses_file(mill), "the Feed Mill is drawn from its file")
	var busy := mill.duplicate(true)
	busy["slots"] = [{"r": "animal_feed_sacks", "done": Game.now() + 600, "took": 600}]
	var full := mill.duplicate(true)
	for k in 4:
		full["slots"].append({"r": "animal_feed_sacks", "done": Game.now() - 5, "took": 600})
	_eq(objects._key(busy), objects._key(mill), "starting a craft doesn't build it again")
	_eq(objects._key(full), objects._key(mill), "nor does filling up")
	_eq(objects.state_of(mill)["working"], false, "an empty mill is idle")
	_eq(objects.state_of(busy)["working"], true, "one with something in a slot is at work")
	_eq(objects.state_of(full)["fill"], BuildingDress.FULL, "one with every slot finished is full")
	var node := AssetRegistry.instance("feed_mill", objects.state_of(mill))
	var built := ModelKit.bake(BuildingModel.build(Game.item_data("feed_mill"), Game.footprint("feed_mill"), 4, false))
	_eq(AssetRegistry.triangles(node), AssetRegistry.triangles(built), "idle, the file shows what the builder makes")
	for state: Dictionary in [objects.state_of(busy), objects.state_of(full)]:
		AssetRegistry.apply_state(node, state)
		BuildingModel.show_state(built, state["working"], state["fill"])
		_eq(AssetRegistry.triangles(node), AssetRegistry.triangles(built), "and the same at work %s, fill %d"
			% [state["working"], state["fill"]])
	AssetRegistry.apply_state(node, objects.state_of(busy))
	var spinners := node.find_children("*", "Spinner", true, false)
	_eq(spinners.size(), 1, "its sails are a named part the game turns")
	_check(is_equal_approx((spinners[0] as Spinner).speed, BuildingDress.SAIL_SPEED), "at the speed its name carries")
	var glass := 0
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for k in mi.mesh.get_surface_count():
			glass += 1 if mi.get_active_material(k) == ModelKit.glass() else 0
	_check(glass >= 1, "its windows are the kit's own glass, which glows at night (%d)" % glass)
	node.free()
	built.free()
	objects.free()


func test_389_harvesting_buildings_follow_their_rules() -> void:
	# A harvesting building (animals, bees, trees or blooms live in it and it is collected from) has two sizes:
	# one storey, then two. Each is a glTF file like the crafting buildings, with a rough yard and a couple of
	# hay bales, windows lit at night as every building's are, and a ready part that fills as the collect timer
	# runs. Night hides nothing: the animals sleep where they stand in the yard.
	var harvesting: Array[String] = []
	for id: String in Game.item_order:
		if Game.building_type(id) == Objects3D.HARVESTING:
			harvesting.append(id)
			_eq(Game.max_level(id), 2, "%s has two sizes" % id)
	_eq(harvesting.size(), 12, "the twelve harvesting buildings")
	var objects := Objects3D.new()
	var shared: Array = [ModelKit.glass(), ModelKit.glow_material(), ModelKit.shade_material(), ModelKit.water(),
		ModelKit.pond_water()]
	for id: String in harvesting:
		var fp := Game.footprint(id)
		_check(AssetRegistry.has_model(id), "%s is made as a file" % id)
		var tall: Array[float] = []
		for level in [1, 2]:
			var spec := BuildingModel.spec(id, level)
			var path := AssetRegistry.file_of(AssetRegistry.entry(id), {"level": level})
			_check(path.ends_with("_%d.glb" % level) and ResourceLoader.exists(path), "%s size %d has its own glTF file"
				% [id, level])
			var node := AssetRegistry.instance(id, {"level": level, "fill": BuildingDress.FULL})
			var wrong := 0
			var lit := 0
			var top := 0.0
			for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
				top = maxf(top, (Objects3D._local_to(node, mi) * mi.mesh.get_aabb()).end.y)
				for k in mi.mesh.get_surface_count():
					var mat := mi.get_active_material(k)
					var master := mat is ShaderMaterial and (mat as ShaderMaterial).shader == AssetRegistry.MASTER
					wrong += 0 if master or mat in shared else 1
					lit += 1 if mat == ModelKit.glass() else 0
			tall.append(top)
			_eq(wrong, 0, "%s size %d draws with the master shader and the kit's shared materials only" % [id, level])
			_check(lit > 0 or int(spec.get("windows", 0)) == 0 or float(spec["body"]["w"]) <= 0.0,
				"%s size %d: its windows are the kit's own glass, lit at night" % [id, level])
			_check(AssetRegistry.draws(node) <= AssetRegistry.budget_of(id, "draws"),
				"%s size %d: full, %d draws within %d" % [id, level, AssetRegistry.draws(node),
				AssetRegistry.budget_of(id, "draws")])
			# Its states are parts of the one model: the looks of its ready part.
			for look in range(1, BuildingDress.FILLS):
				var part := node.find_child("%sfill_%d" % [AssetRegistry.STATE, look], true, false) as Node3D
				_check(part != null and part.visible == (look == BuildingDress.FULL), "%s size %d: ready look %d is a part"
					% [id, level, look])
			node.free()
			# A yard is rough ground with a couple of hay bales.
			for f: Dictionary in spec["features"]:
				if f["type"] == "yard":
					_check(f.get("rough", false), "%s size %d: its yard is rough ground" % [id, level])
					var bales := (spec["features"] as Array).filter(func(b: Dictionary) -> bool:
						return b["type"] == "hay_bales")
					_check(bales.size() == 1 and int(bales[0].get("count", 0)) == 2, "%s size %d: with a couple of hay bales"
						% [id, level])
		_check(tall[1] > tall[0] * 1.3, "%s: one storey, then two (%.2f, %.2f tall)" % [id, tall[0], tall[1]])
		_check(AssetRegistry.has_site(id), "%s going up is made as files" % id)
		_check(fp.x > 0, "%s has a footprint" % id)
	# The ready part fills as the collect timer runs, shown in place.
	var dairy := {"uid": 9301, "id": "cow_shed", "row": 0, "col": 0, "level": 2, "built": true, "t": Game.now(),
		"inside": {"cow": 6}}
	var cycle := Game.cycle_of(dairy)
	var key := objects._key(dairy)
	for step: Array in [[0.0, 0], [0.3, 1], [0.6, 2], [1.01, BuildingDress.FULL]]:
		dairy["t"] = Game.now() - int(cycle * float(step[0]))
		_eq(objects.state_of(dairy)["fill"], step[1], "%d%% of the way to ready: ready look %d" % [int(float(step[0])
			* 100.0), step[1]])
		_eq(objects._key(dairy), key, "shown in place, not built again")
	var was_night := AnimalBehaviour.night
	AnimalBehaviour.night = false
	var node := AssetRegistry.instance("cow_shed", objects.state_of(dairy))
	Objects3D.mark_parts(node)
	var fill := BuildingFill.create(dairy, node)
	node.add_child(fill)
	add_child(node)
	_check(fill._doors.size() == 2 and fill._windows.size() >= 2, "its file names its doors and windows (%d, %d)"
		% [fill._doors.size(), fill._windows.size()])
	_check(fill.residents.size() > 0 and fill.residents.all(func(a: Animal3D) -> bool: return a.visible),
		"by day its cows are out in the yard")
	_check(fill._produce == null, "and the yard piles no produce beside its ready part")
	AnimalBehaviour.night = true
	_eq(objects._key(dairy), key, "night doesn't build it again")
	fill.refresh(dairy)
	_check(fill.residents.all(func(a: Animal3D) -> bool: return a.visible),
		"at night its cows are still out in the yard: they sleep where they stand")
	_check(fill._peekers == null or fill._peekers.visible, "and whoever is at a window stays there")
	AnimalBehaviour.night = was_night
	node.queue_free()
	objects.free()


func test_390_storing_buildings_are_gltf_files_too() -> void:
	# The Barn, the Garage and the Garden Shed keep their sizes and what they do; their looks are glTF files
	# like the other buildings', a file for each look and construction stage, drawn with the master shader and
	# the kit's shared materials, within the building budget. The Garage's shutter is a named part that rolls
	# up. The Barn's look follows the VIP level, not its size (docs/VIP.md): fifteen looks, a badge with the
	# level's number that is gold and rides up and down while VIP is active and grey metal when it has lapsed,
	# and a file for the starter Barn standing broken.
	var shared: Array = [ModelKit.glass(), ModelKit.glow_material(), ModelKit.shade_material(), ModelKit.water()]
	var storing: Array[String] = []
	for id: String in Game.item_order:
		if Game.building_type(id) == "storing":
			storing.append(id)
	_eq(storing.size(), 3, "the three storing buildings")
	_eq(Game.building_def("barn").capacities(), [30, 60, 100, 160, 250] as Array[int], "the Barn keeps its five sizes")
	_eq(Game.look_levels("barn"), Game.vip.max_level(), "and has a look for each VIP level")
	_eq(Game.look_levels("garage"), 1, "a building's looks are its sizes otherwise")
	for id: String in storing:
		_check(AssetRegistry.has_model(id) and AssetRegistry.has_site(id), "%s and its building site are files" % id)
		var seen := {}
		for level in range(1, Game.look_levels(id) + 1):
			var path := AssetRegistry.file_of(AssetRegistry.entry(id), {"level": level})
			_check(path.ends_with("_%d.glb" % level) and ResourceLoader.exists(path), "%s look %d has its own glTF file"
				% [id, level])
			var node := AssetRegistry.instance(id, {"level": level, "vip": true})
			var wrong := 0
			for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
				for k in mi.mesh.get_surface_count():
					var mat := mi.get_active_material(k)
					var master := mat is ShaderMaterial and (mat as ShaderMaterial).shader == AssetRegistry.MASTER
					wrong += 0 if master or mat in shared else 1
			_eq(wrong, 0, "%s look %d draws with the master shader and the kit's shared materials only" % [id, level])
			_check(AssetRegistry.draws(node) <= AssetRegistry.budget_of(id, "draws"), "%s look %d: %d draws within %d"
				% [id, level, AssetRegistry.draws(node), AssetRegistry.budget_of(id, "draws")])
			var built := ModelKit.bake(BuildingModel.build(Game.item_data(id), Game.footprint(id), level))
			AssetRegistry.apply_state(built, {"level": level, "vip": true})
			_eq(AssetRegistry.triangles(node), AssetRegistry.triangles(built), "%s look %d: the file is what the builder makes"
				% [id, level])
			seen[JSON.stringify(BuildingModel.spec(id, level))] = true
			built.free()
			node.free()
		_eq(seen.size(), Game.look_levels(id), "%s: each look is its own" % id)
	var garage := AssetRegistry.instance("garage", {"level": 1})
	Objects3D.mark_parts(garage)
	var shutters := garage.get_children().filter(func(n: Node) -> bool: return n.has_meta(BuildingModel.SLIDE))
	_check(shutters.size() == 1 and float(shutters[0].get_meta(BuildingModel.SLIDE)) > 0.3
		and float(shutters[0].get_meta(BuildingModel.DOOR)) == 0.0, "the Garage's shutter is a part that rolls up")
	garage.free()
	# The Barn shows the VIP level and whether VIP is active, in place.
	var objects := Objects3D.new()
	var points := Game.vip.points
	var until := Game.vip.until
	var barn := {"uid": 9401, "id": "barn", "row": 0, "col": 0, "level": 2, "built": true, "t": Game.now()}
	Game.vip.points = 0
	Game.vip.until = 0
	_eq(Game.look_level(barn), 1, "before the first VIP level the Barn wears its first look")
	_check(not objects.state_of(barn).has("vip"), "with no badge")
	Game.vip.points = 1000   # VIP 5
	Game.vip.until = Game.now() + 1000
	_eq(Game.look_level(barn), 5, "at VIP 5 it wears its fifth look, whatever its size")
	_eq(objects.state_of(barn)["level"], 5, "that look's file is the one shown")
	_eq(objects.state_of(barn)["vip"], true, "its badge is the active one")
	var key := objects._key(barn)
	var node := AssetRegistry.instance("barn", objects.state_of(barn))
	var on := node.find_child(AssetRegistry.STATE + "vip_true", true, false) as Node3D
	var off := node.find_child(AssetRegistry.STATE + "vip_false", true, false) as Node3D
	_check(on != null and off != null and on.visible and not off.visible, "gold while VIP is active")
	var riding := 0
	for c in (on.get_children() if on != null else []):
		riding += 1 if String(c.name).begins_with(DecorMotion.BOB) and c.get_children().any(
			func(n: Node) -> bool: return n is Bobber) else 0
	_eq(riding, 1, "and riding gently up and down: a named part the game moves")
	Game.vip.until = Game.now() - 1
	_eq(objects.state_of(barn)["vip"], false, "lapsed: the grey one")
	_eq(objects._key(barn), key, "shown in place, not built again")
	AssetRegistry.apply_state(node, objects.state_of(barn))
	_check(on != null and off != null and off.visible and not on.visible, "grey metal, and still")
	_check(off == null or off.find_children("*", "Bobber", true, false).is_empty(), "nothing moves it")
	Game.vip.points = 1600   # VIP 6
	_check(objects._key(barn) != key, "a new VIP level is a new look")
	node.free()
	barn["broken"] = true
	_check(not objects.state_of(barn).has("vip"), "the starter Barn standing broken wears no badge")
	var broken_path := AssetRegistry.file_of(AssetRegistry.entry("barn"), objects.state_of(barn))
	_check(broken_path.ends_with("barn_broken.glb") and ResourceLoader.exists(broken_path),
		"and has a file of its own for that")
	Game.vip.points = points
	Game.vip.until = until
	objects.free()
