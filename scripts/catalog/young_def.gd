class_name YoungDef
extends PlaceableDef
## A mystery young (FarmVille's Mystery Seedling, Mystery Baby): found, given its supply on the farm, and
## grown into a tree or animal that was decided when it was found (NurtureSystem).


func supply() -> String:
	return str(data.get("supply", ""))


func needs() -> int:
	return int(data.get("needs", 8))


func grows() -> String:
	return str(data.get("grows", ""))


func can_rotate() -> bool:
	return false


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	if not NurtureSystem.SUPPLIES.has(supply()):
		out.append(_err("supply must be one of %s" % str(NurtureSystem.SUPPLIES.keys())))
	if needs() <= 0:
		out.append(_err("needs must be at least 1"))
	if not grows() in ["tree", "animal"]:
		out.append(_err("grows must be tree or animal"))
	return out
