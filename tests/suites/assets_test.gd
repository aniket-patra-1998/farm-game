extends TestSuite
## Assets made as files (docs/ASSETS.md): every listed asset loads, fits its budget and its footprint, and names
## its states the one way; the registry draws an unlisted or missing one as its stand-in; states show and hide
## the right parts; plain materials become the master material.

const TEST_FILE := "user://test_asset.scn"


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
