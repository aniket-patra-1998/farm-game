extends Node
## Makes the game's asset packs (docs/PACKS.md): godot --headless --path . res://tools/make_packs.tscn -- --out=<folder>
## Every pack AssetPacks knows (a limited animal and its baby each) and their manifest.json go to the folder;
## upload its contents to the address in data/packs.json.


func _ready() -> void:
	var out := "user://packs_made"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):   # not-ui
			out = arg.trim_prefix("--out=")   # not-ui
	var packs := AssetPacks.shared.packs() if AssetPacks.shared != null else {}
	var failed := PackMaker.make_all(packs, out)
	var bytes := 0
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join(PackMaker.MANIFEST)))
	for pack: String in manifest:
		bytes += int(manifest[pack]["bytes"])
	var where := ProjectSettings.globalize_path(out)
	print("make_packs: %d packs, %.1f MB, in %s" % [manifest.size(), bytes / 1048576.0, where])  # not-ui
	if not failed.is_empty():
		push_error("make_packs: could not make %s" % str(failed))   # not-ui
	get_tree().quit(1 if not failed.is_empty() else 0)
