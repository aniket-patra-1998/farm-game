class_name BuildingDef
extends PlaceableDef
## A building: what it holds, its sizes, its Market tab and how many one farm may have. Its sizes are
## records (data "sizes"), smallest first: size N (1-based) holds capacity(N), is called size_name(N), and
## reaching it from size N-1 takes size_cost(N) (materials, or a crafting building's coins and stars).

const SPECIALS := [
	"mystery_eggs",
	"calves",
	"foals",
	"lambs",
	"truffles",
	"nursery",
	"beehive",
	"saplings",
	"garage",
	"garden_shed"
]


func sizes() -> Array:
	return data.get("sizes", [])


func max_level() -> int:
	return sizes().size()


## The record for a size (clamped into range), or {} for a building with no sizes.
func size(level: int) -> Dictionary:
	return sizes()[clampi(level, 1, max_level()) - 1] if max_level() > 0 else {}


func capacity(level: int) -> int:
	return int(size(level).get("capacity", 0))


## Capacities from smallest to biggest.
func capacities() -> Array[int]:
	var out: Array[int] = []
	for s: Dictionary in sizes():
		out.append(int(s["capacity"]))
	return out


func size_name(level: int) -> String:
	return str(size(level).get("name", name)) if level >= 1 and level <= max_level() else name


## Materials to grow from level - 1 to level ({} for the first size, or none needed).
func size_materials(level: int) -> Dictionary:
	if level < 2 or level > max_level():
		return {}
	return size(level).get("materials", {})


## Its Market tab: animal, storage, crafting or decor.
func tab() -> String:
	return str(data.get("tab", "animal"))


const DEFAULT_LIMIT := 2   # buildings of one kind a farm may have, for now

## How many one farm may have.
func limit() -> int:
	return int(data.get("limit", DEFAULT_LIMIT))


## Buildings that share a limit (all crafting buildings), and how many of them one farm may have.
func limit_group() -> String:
	return str(data.get("limit_group", ""))


func group_limit() -> int:
	return int(data.get("group_limit", 0))


## A home that grows by itself with what has been found (the Gopher Garden), not by materials.
func grows_with_finds() -> bool:
	return str(data.get("home_of", "")) != ""


func holds() -> Array:
	return data.get("holds", [])


func one_each() -> Array:
	return data.get("one_each", [])


## Stores anything already on the farm, instead of housing one kind (the Barn).
func stores_anything() -> bool:
	return false


## Babies moved in here grow up (the Nursery Barn).
func grows_young() -> bool:
	return str(data.get("special", "")) == "nursery"


## Whether item item_kind/item_id can move in.
func accepts(item_id: String, item_kind: String) -> bool:
	if holds().has(item_id) or one_each().has(item_id):
		return true
	return str(data.get("holds_kind", "")) != "" and str(data["holds_kind"]) == item_kind


func can_rotate() -> bool:
	return false


## Whether its sizes are bought with coins and recipe stars (a crafting building) rather than materials.
func grows_by_stars() -> bool:
	return false


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	if max_level() == 0:
		out.append(_err("needs at least one size"))
	for k in range(2, max_level() + 1):
		if capacity(k) <= capacity(k - 1):
			out.append(_err("each size must hold more than the last"))
		if size_materials(k).is_empty() and not grows_by_stars() and not grows_with_finds():
			out.append(_err("size %d says nothing about the materials to reach it" % k))
	if size(1).has("materials"):
		out.append(_err("the first size can't cost materials (build_materials pays for a frame)"))
	if limit() < 1:
		out.append(_err("limit must be at least 1"))
	if limit_group() != "" and group_limit() < 1:
		out.append(_err("limit_group %s needs a group_limit of at least 1" % limit_group()))
	for ref in holds() + one_each():
		if catalog.get_def(str(ref)) == null:
			out.append(_err("holds unknown item %s" % ref))
	for m in data.get("build_materials", {}):
		if not catalog.material_ids().has(m):
			out.append(_err("build_materials uses unknown material %s" % m))
	for k in range(2, max_level() + 1):
		for m in size_materials(k):
			if not catalog.material_ids().has(m):
				out.append(_err("size %d uses unknown material %s" % [k, m]))
	for m in data.get("uses_materials", []):
		if not catalog.material_ids().has(m):
			out.append(_err("uses unknown material %s" % m))
	var grows: Dictionary = data.get("grows_into", {})
	for baby in grows:
		if catalog.get_def(str(baby)) == null or catalog.get_def(str(grows[baby])) == null:
			out.append(_err("grows_into has an unknown animal (%s -> %s)" % [baby, grows[baby]]))
	return out


## A building's stages are its sizes: 1, 2, 3...
func art_stages(_lifecycle: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for n in range(1, max_level() + 1):
		out.append(str(n))
	return out
