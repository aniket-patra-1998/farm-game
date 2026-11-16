class_name ExportBuildings
extends Node
## Exports the crafting buildings to files (docs/ASSETS.md: art is made ahead of time as files, asked for by
## name through AssetRegistry), from the code builder that authors them (BuildingModel, BuildingDress).
## Scenes, not glTF: their walls', sails' and smoke's own shaders only survive in Godot's format.
##   art/models/buildings/<id>.scn   parts when_level_<n>, each the whole building at that level, with its
##                                   states inside it (when_working_true/false, when_fill_<n>)
## Lists them in data/assets.json. Run: godot --headless --path . res://tools/export_buildings.tscn

const BUILDINGS := "res://art/models/buildings/"
const KINDS: Array[String] = ["crafting"]   # the kinds of building made as files so far


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BUILDINGS))
	var listed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AssetRegistry.DATA))
	var assets: Dictionary = listed["assets"]
	var n := 0
	for id: String in Game.item_order:
		if not str(Game.items[id].get("kind", "")) in KINDS:
			continue
		var path := BUILDINGS + id + ".scn"
		ExportPlants._save(building(id), path)
		assets[id] = {"model": path, "budget": "building"}
		n += 1
	FileAccess.open(AssetRegistry.DATA, FileAccess.WRITE).store_string(JSON.stringify(listed, "  ", false) + "\n")
	print("exported %d building files" % n)   # not-ui (a tool's log)
	# The files are now what the builders make: record it (tools/make_art_versions.py).
	OS.execute("python3", [ProjectSettings.globalize_path("res://tools/make_art_versions.py"), "--exported",
		"buildings"])
	get_tree().quit()


## Building `id` as its file holds it: every level, each with every state.
static func building(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	for level in range(1, Game.max_level(id) + 1):
		var built := ModelKit.bake(BuildingModel.build(Game.item_data(id), Game.footprint(id), level, false))
		built.name = "%slevel_%d" % [AssetRegistry.STATE, level]
		root.add_child(built)
	return root
