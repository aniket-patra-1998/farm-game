extends TestSuite
## Assets made as files (docs/ASSETS.md): every listed asset loads, fits its budget and its footprint, and names
## its states the one way; the registry draws an unlisted or missing one as its stand-in; states show and hide
## the right parts; plain materials become the master material.

const TEST_FILE := "user://test_asset.scn"
const FIXTURE := "res://tests/fixtures/asset_fixture.glb"   # made by tools/make_asset_fixture.gd


func test_346_every_listed_asset_loads_fits_its_budget_and_its_footprint() -> void:
	var listed := (JSON.parse_string(FileAccess.get_file_as_string(AssetRegistry.DATA)) as Dictionary)
	var budgets: Dictionary = listed["budgets"]
	for id: String in listed["assets"]:
		var e: Dictionary = listed["assets"][id]
		_check(not Game.item_data(id).is_empty() or Game.crops.has(id), "%s is a catalog item" % id)
		_check(budgets.has(str(e.get("budget", ""))), "%s has a budget kind" % id)
		var node := AssetRegistry.instance(id)
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
		if str(Game.item_data(id).get("kind", "")) != "tree":   # (a tree's crown overhangs by design)
			_check(box.size.x <= fp.x + 0.01 and box.size.y <= fp.y + 0.01, "%s fits its %s footprint" % [id, str(fp)])
		node.free()


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


func test_351_a_crop_made_as_a_file_is_drawn_by_the_same_crop_code_and_a_file_tree_sways() -> void:
	AssetRegistry.forget()
	# A listed crop: the crop code takes each stage's plant from the file (its growth, sway and produce colour are
	# the crop shader's, as for every crop); bare seeds, which the file leaves out, are built as before.
	var shape := str((Game.crops["strawberries"] as Dictionary).get("shape", "berry"))
	var look := CropForms.look_of("strawberries", shape)
	_check(look.begins_with(CropForms.FILE), "a crop listed in data/assets.json is drawn from its file")
	for stage: String in ["sprout", "young", "ripe", "withered"]:
		var m := CropModels.mesh(look, stage)
		_check(m != null and m == AssetRegistry.part_mesh("strawberries", "stage", stage),
			"its %s plant is the file's" % stage)
		_check(m != null and m.get_surface_count() == 1 and m.surface_get_array_len(0) > 3,
			"and is one surface (%s)" % stage)
	_check(CropModels.mesh(look, "seeds") == CropModels.mesh(CropForms.form_of("strawberries", shape), "seeds"),
		"a stage the file leaves out is built as before")
	_check(AssetRegistry.part_mesh("strawberries", "stage", "no_such_stage") == null,
		"a part the file lacks is none")
	# An unlisted crop is untouched.
	_check(CropForms.look_of("corn", "stalk") == CropForms.form_of("corn", "stalk"),
		"a crop without a file keeps its form")
	# A tree made as a file: its fruit follows `ready`, and its entry's `sway` bends it in the wind like every tree.
	var tree := AssetRegistry.instance("apple_tree", {"ready": true})
	_check(tree != null, "the apple tree's file loads")
	if tree != null:
		_check((_find(tree, "when_ready_true") as Node3D).visible, "ripe fruit shows while ready")
		_check(not (_find(tree, "when_ready_false") as Node3D).visible, "and growing fruit is hidden")
		var body := _find(tree, "body") as MeshInstance3D
		var m := body.get_active_material(0) as ShaderMaterial
		_check(m != null and m.shader == AssetRegistry.MASTER, "it draws with the master material")
		_check(m != null and is_equal_approx(float(m.get_shader_parameter("sway")), TreeModel.SWAY),
			"bending as built trees do")
		tree.free()

