class_name Linking
extends RefCounted
## Which pieces join their neighbours into one structure (fences, hedges, walls, paths), read from
## data/linking.json. A group is named after the catalog `shape` its pieces share.

const PATH := "res://data/linking.json"

static var _groups: Dictionary = {}


static func _load() -> void:
	if not _groups.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_groups = (parsed as Dictionary).get("groups", {})


## The group a catalog shape belongs to ("" when its pieces don't join).
static func group_of_shape(shape: String) -> String:
	_load()
	return shape if _groups.has(shape) else ""


static func groups() -> Array:
	_load()
	return _groups.keys()


## Whether a piece of group `a` connects to a neighbouring piece of group `b`.
static func joins(a: String, b: String) -> bool:
	_load()
	return b in (_groups.get(a, {}) as Dictionary).get("joins", [])


static func setting(group: String, key: String, fallback := 0.0) -> float:
	_load()
	return float((_groups.get(group, {}) as Dictionary).get(key, fallback))
