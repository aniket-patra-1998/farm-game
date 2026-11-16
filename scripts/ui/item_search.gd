class_name ItemSearch
extends RefCounted
## What search knows about the game's things (docs/SEARCH.md, data/search.json; our own touch): the words each
## item is found by, the filters each menu offers, and the player's recent searches. One function for every
## menu, read from the catalog, so a new item is searchable with no work and a new word is a line of data.

const DATA := "res://data/search.json"
const SECTION := "search"   # the recent searches' section in user://settings.cfg (PlayerSettings)

static var _data: Dictionary = {}
static var show_on_farm: Callable   # (id): closes the panels and takes the view to the nearest one (Main sets it)


## A rule from data/search.json (from_items, least_letters, typo_from, recent_kept).
static func rule(key: String) -> int:
	_load()
	return int(_data.get(key, 0))


## The words item `id` is found by: its name (`name`, found first) and the rest (`more`): its kind and family,
## what it gives, what it holds and what those give, and the kind's own words (data). {} for a thing that isn't
## in the catalog (its list finds it by its card's name instead).
static func words_of(id: String) -> Dictionary:
	var name := Game.name_of(id)
	if name == "" and Game.crops.has(id):   # (a crop: found by its name and as a crop, a seed)
		var crop: Dictionary = Game.crops[id]
		return {"name": str(crop.get("name", "")), "more": TranslationServer.translate(str(_data_kinds().get("crop", "")))}
	if name == "":
		return {}
	var it := Game.item_data(id)
	var more := PackedStringArray()
	var kind := str(it.get("kind", ""))
	for key in ["kind", "family", "category", "product"]:
		if it.has(key):
			more.append(str(it[key]))
	var kind_key := str((_data_kinds()).get(kind, ""))
	if kind_key != "":
		more.append(TranslationServer.translate(kind_key))
	var holds: Variant = it.get("holds", [])
	for held: Variant in (holds if holds is Array else [holds]):
		more.append(Game.name_of(str(held)))
		more.append(str(Game.item_data(str(held)).get("product", "")))
	return {"name": name, "more": " ".join(more)}


## How many of item `id` stand on the farm or live in a home there.
static func on_farm(id: String) -> int:
	var n := 0
	for o: Dictionary in Game.objects:
		if str(o["id"]) == id:
			n += 1
		n += int((o.get("inside", {}) as Dictionary).get(id, 0))
	return n


## The filters menu `menu` offers: [{key, words (shown), test (id, face) -> bool}].
static func chips_for(menu: String) -> Array:
	_load()
	var out: Array = []
	for c: Dictionary in (_data.get("chips", {}) as Dictionary).get(menu, []):
		var face_key := str(c.get("face", ""))
		var kinds: Array = c.get("kinds", [])
		out.append({"key": str(c["key"]), "words": TranslationServer.translate(str(c["words"])),
			"test": func(id: String, face: Dictionary) -> bool:
				if face_key != "" and not bool(face.get(face_key, false)):
					return false
				return kinds.is_empty() or str(Game.item_data(id).get("kind", "")) in kinds})
	return out


## The recent searches in menu `menu`, newest first.
static func recent(menu: String) -> PackedStringArray:
	return PackedStringArray(PlayerSettings.value(SECTION, menu, PackedStringArray()))


## Keeps `query` as menu `menu`'s newest recent search (once, up to `recent_kept`).
static func remember(menu: String, query: String) -> void:
	var q := query.strip_edges()
	if q.length() < rule("least_letters"):
		return
	var kept := recent(menu)
	var at := kept.find(q)
	if at >= 0:
		kept.remove_at(at)
	kept.insert(0, q)
	kept.resize(mini(kept.size(), rule("recent_kept")))
	PlayerSettings.keep(SECTION, {menu: kept})


static func _data_kinds() -> Dictionary:
	_load()
	return _data.get("kind_words", {})


static func _load() -> void:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed if parsed is Dictionary else {}
