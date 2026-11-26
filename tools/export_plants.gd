class_name ExportPlants
extends Node
## Exports every tree look to files (docs/ASSETS.md: art is made ahead of time as files, asked for by name through
## AssetRegistry), from the code builder that authors them (TreeModel). Crops and flowers are not models: they are
## painted pictures (tools/paint_plants.py).
## Scenes, not glTF: the leaves' own shader (sway) only survives in Godot's format.
##   art/models/trees/<id>.scn    a lone tree: parts when_look_<n> (n < TREE_LOOKS), the whole tree
## Lists them in data/assets.json. Run: godot --headless --path . res://tools/export_plants.tscn

const TREES := "res://art/models/trees/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TREES))
	var listed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AssetRegistry.DATA))
	var assets: Dictionary = listed["assets"]
	var n := 0
	for id: String in Game.item_order:
		# (A limited tree has no file: there are five of every tree, some 60 MB of them, so each is built on the
		# device the first time it is shown and kept there: ModelStore.)
		if str(Game.items[id].get("kind", "")) != "tree" or Game.limited.is_limited(id):
			continue
		var path := TREES + id + ".scn"
		_save(_tree(id), path)
		assets[id] = {"model": path, "budget": "tree"}
		n += 1
	FileAccess.open(AssetRegistry.DATA, FileAccess.WRITE).store_string(JSON.stringify(listed, "  ", false) + "\n")
	print("exported %d plant files" % n)   # not-ui (a tool's log)
	# The files are now what the builders make: record it, and the pictures' fingerprints (tools/make_art_versions.py).
	OS.execute("python3", [ProjectSettings.globalize_path("res://tools/make_art_versions.py"), "--exported", "plants"])
	get_tree().quit()


func _tree(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	for look in Objects3D.TREE_LOOKS:
		var holder := Node3D.new()
		holder.name = "when_look_%d" % look
		root.add_child(holder)
		# (one model whether ready or not: its fruit grows on it, shaders/fruit3d.gdshader)
		var tree := Objects3D.tree_look(id, 0, look, false)
		tree.name = "tree"   # not-ui
		holder.add_child(tree)
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
