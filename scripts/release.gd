class_name Release
extends RefCounted
## What the current release shows (docs/V1.md, data/v1.json): its items (crops, animals, trees, buildings,
## decorations for sale, unlocked, given or found), its features (vehicles, raising, strays...) and the balance
## values it changes (layout bonuses off...). Nothing outside it is deleted: it is switched off, and an update
## switches it back on in the data. Tests run with everything on (`whole`), so every system stays tested.

const DATA := "res://data/v1.json"

static var whole := false    # everything on (tests, tools)
static var _data := {}
static var _items := {}
static var _read := false


## Whether item or crop `id` is in this release. Building parts and anything not sold (materials) always are.
static func has(id: String) -> bool:
	_load()
	if whole or _items.is_empty():
		return true
	return _items.has(id) or not (Game.items.has(id) or Game.crops.has(id))


## Whether `feature` is on in this release (a feature not named in the data is on).
static func on(feature: String) -> bool:
	_load()
	return whole or bool((_data.get("features", {}) as Dictionary).get(feature, true))


## The release's own value for balance number `key`, if it sets one (Balance asks first).
static func balance(key: String) -> Variant:
	_load()
	if whole:
		return null
	return (_data.get("balance", {}) as Dictionary).get(key, null)


static func _load() -> void:
	if _read:
		return
	_read = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not parsed is Dictionary:
		push_error(DATA + " is missing or not valid JSON")
		return
	_data = parsed
	for id: String in _data.get("items", []):
		_items[id] = true
