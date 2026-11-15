class_name ExportPlants
extends Node
## Exports every tree and crop look to files (docs/ASSETS.md: art is made ahead of time as files, asked for by
## name through AssetRegistry), from the code builders that author them (TreeModel, CropModels/CropForms).
## Scenes, not glTF: the leaves' and crops' own shaders (sway, growth) only survive in Godot's format.
##   art/models/trees/<id>.scn    a lone tree: parts when_look_<n> (n < TREE_LOOKS), each when_ready_<bool>
##   art/models/crops/<form>.scn  a crop form: one MeshInstance3D per stage, named after it
## Lists them in data/assets.json. Run: godot --headless --path . res://tools/export_plants.tscn

const TREES := "res://art/models/trees/"
const CROPS := "res://art/models/crops/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TREES))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CROPS))
	var listed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AssetRegistry.DATA))
	var assets: Dictionary = listed["assets"]
	var n := 0
	for id: String in Game.item_order:
		if str(Game.items[id].get("kind", "")) != "tree":
			continue
		var path := TREES + id + ".scn"
		_save(_tree(id), path)
		assets[id] = {"model": path, "budget": "tree"}
		n += 1
	for form: String in crop_forms():
		var path := CROPS + form + ".scn"
		_save(_crop(form), path)
		assets[AssetRegistry.CROP + form] = {"model": path, "budget": "crop"}
		n += 1
	FileAccess.open(AssetRegistry.DATA, FileAccess.WRITE).store_string(JSON.stringify(listed, "  ", false) + "\n")
	print("exported %d plant files" % n)   # not-ui (a tool's log)
	# The files are now what the builders make: record it, and the pictures' fingerprints (tools/make_art_versions.py).
	OS.execute("python3", [ProjectSettings.globalize_path("res://tools/make_art_versions.py"), "--exported", "plants"])
	get_tree().quit()


## Every crop form the field draws (each crop's form, or its shape's).
static func crop_forms() -> Array[String]:
	var out: Array[String] = []
	for crop_id: String in Game.crops:
		var form := CropForms.form_of(crop_id, str((Game.crops[crop_id] as Dictionary).get("shape", "berry")))
		if not form in out:
			out.append(form)
	out.sort()
	return out


func _tree(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	for look in Objects3D.TREE_LOOKS:
		var holder := Node3D.new()
		holder.name = "when_look_%d" % look
		root.add_child(holder)
		for ready: bool in [false, true]:
			var tree := Objects3D.tree_look(id, ready, 0, look, false)
			tree.name = "when_ready_%s" % str(ready).to_lower()
			holder.add_child(tree)
	return root


func _crop(form: String) -> Node3D:
	var root := Node3D.new()
	root.name = form
	for stage: String in CropModels.STAGES:
		var mi := MeshInstance3D.new()
		mi.name = stage
		mi.mesh = CropModels.mesh(form, stage, false)
		root.add_child(mi)
	return root


static func _save(root: Node3D, path: String) -> void:
	_own(root, root)
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS)
	root.free()


static func _own(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		_own(c, owner)
