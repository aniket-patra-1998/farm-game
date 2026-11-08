class_name BuildingDef
extends PlaceableDef
## A building that holds things. Size N (1-based) holds levels[N-1]; expanding pays expand_materials.

const SPECIALS := ["mystery_eggs", "calves", "foals", "lambs", "truffles", "nursery", "beehive", "saplings", "garage"]


func levels() -> Array:
	return data.get("levels", [])


func max_level() -> int:
	return levels().size()


func capacity(level: int) -> int:
	return int(levels()[clampi(level, 1, max_level()) - 1])


func size_name(level: int) -> String:
	var names: Array = data.get("level_names", [])
	return str(names[level - 1]) if level >= 1 and level <= names.size() else name


func holds() -> Array:
	return data.get("holds", [])


func one_each() -> Array:
	return data.get("one_each", [])


## Whether item item_kind/item_id can move in.
func accepts(item_id: String, item_kind: String) -> bool:
	if holds().has(item_id) or one_each().has(item_id):
		return true
	return str(data.get("holds_kind", "")) != "" and str(data["holds_kind"]) == item_kind


func can_rotate() -> bool:
	return false


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	if max_level() == 0:
		out.append(_err("needs at least one size in levels"))
	for k in range(1, max_level()):
		if int(levels()[k]) <= int(levels()[k - 1]):
			out.append(_err("each size must hold more than the last"))
	var names: Array = data.get("level_names", [])
	if not names.is_empty() and names.size() != max_level():
		out.append(_err("level_names needs one name per size"))
	if max_level() > 1 and not data.has("expand_materials"):
		out.append(_err("has more than one size but no expand_materials"))
	for ref in holds() + one_each():
		if catalog.get_def(str(ref)) == null:
			out.append(_err("holds unknown item %s" % ref))
	for key in ["build_materials", "expand_materials"]:
		for m in data.get(key, {}):
			if not catalog.material_ids().has(m):
				out.append(_err("%s uses unknown material %s" % [key, m]))
	for m in data.get("uses_materials", []):
		if not catalog.material_ids().has(m):
			out.append(_err("uses unknown material %s" % m))
	var grows: Dictionary = data.get("grows_into", {})
	for baby in grows:
		if catalog.get_def(str(baby)) == null or catalog.get_def(str(grows[baby])) == null:
			out.append(_err("grows_into has an unknown animal (%s -> %s)" % [baby, grows[baby]]))
	return out
