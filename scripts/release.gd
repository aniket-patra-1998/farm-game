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
	if _items.has(id) or not (Game.items.has(id) or Game.crops.has(id)):
		return true
	# A limited variety comes with its feature, on the plain kind it is a variety of (owner, 20 Nov: "I don't see
	# the limited banner and animals"; they were listed nowhere, so the release had none).
	return on("limited") and Game.limited.is_limited(id) and _plain_in(id)


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


## Whether the plain kind a limited variety is a coat of is in this release (a tree names it; an animal's family
## needs one of its plain animals listed).
static func _plain_in(id: String) -> bool:
	var it: Dictionary = Game.items.get(id, {})
	var of := str(it.get("limited_of", ""))
	if of != "":
		return _items.has(of)
	var family := str(it.get("family", ""))
	for listed: String in _items:
		var other: Dictionary = Game.items.get(listed, {})
		if str(other.get("family", "")) == family and str(other.get("kind", "")) == str(it.get("kind", "")):
			return true
	return false


static func _load() -> void:
	if _read:
		return
	_read = true
	_data = DataFile.read(DATA)
	if _data.is_empty():
		return
	for id: String in _data.get("items", []):
		_items[id] = true
