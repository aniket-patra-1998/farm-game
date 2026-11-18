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
	# (a crop's picture is its harvest, built from the crop builders' code, not its exported field: CropForms.harvest)
	var look := str(files[id]) if files.has(id) else str(_data.get("built", ""))
	return look + "/" + str(_data.get("studio", ""))


## The fingerprint of the file item `id` is made from ("" when it is code-built).
static func file_of(id: String) -> String:
	_load()
	return str((_data.get("files", {}) as Dictionary).get(id, ""))


static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_data = parsed if parsed is Dictionary else {"built": "none"}
