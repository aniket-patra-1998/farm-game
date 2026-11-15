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
			or form in ExportPlants.crop_forms(), "%s is a catalog item or a crop's form" % id)
		_check(budgets.has(str(e.get("budget", ""))), "%s has a budget kind" % id)
		# (A tree's file holds each of its looks, ripe and not: one of them is drawn at a time.)
		var node := AssetRegistry.instance(id, {"look": 0, "ready": true})
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
		if not str(e.get("budget", "")) in ["tree", "animal", "crop"]:
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
