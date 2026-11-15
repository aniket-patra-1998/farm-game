class_name ArtVersion
extends RefCounted
## What an item's look is made from, as a fingerprint (data/art_versions.json, written by
## tools/make_art_versions.py and checked in CI): its file's contents when it is made as a file (AssetRegistry; a
## crop by its form's file), else everything the code-built looks are made from. Whatever is made from the art
## (item pictures: ItemIcons) keys itself on `of`, so a change to the art makes it again by itself, on every
## device, with nothing to remember to bump.

const DATA := "res://data/art_versions.json"

static var _data := {}


## The fingerprint of item `id`'s look, and of how its picture is taken.
static func of(id: String) -> String:
	_load()
	var files: Dictionary = _data.get("files", {})
	var own := id
	if Game.crops.has(id) and not Game.items.has(id):
		own = AssetRegistry.CROP + CropForms.form_of(id, str((Game.crops[id] as Dictionary).get("shape", "berry")))
	var look := str(files[own]) if files.has(own) else str(_data.get("built", ""))
	return look + "/" + str(_data.get("studio", ""))


static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_data = parsed if parsed is Dictionary else {"built": "none"}
