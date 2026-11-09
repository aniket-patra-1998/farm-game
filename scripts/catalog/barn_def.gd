class_name BarnDef
extends BuildingDef
## The starter barn: broken until repaired with materials, then storage.


func stores_anything() -> bool:
	return true


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	for m in data.get("repair_parts", {}):
		if not catalog.material_ids().has(m):
			out.append(_err("repair needs unknown material %s" % m))
	return out
