class_name AnimalDef
extends ProducerDef
## An animal. Strays wander in once you own their home; everything else is bought or earned.


func is_stray_only() -> bool:
	return bool(data.get("stray_only", false))


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	if is_stray_only():
		if str(data.get("home", "")) == "":
			out.append(_err("a stray needs a home building"))
		if in_market():
			out.append(_err("a stray can't be in the Market (unlock_level 99)"))
	# Every animal should have somewhere to live, or be a loose-only special.
	var homes: Array[String] = catalog.homes_of(id)
	if homes.is_empty() and kind == "animal":
		out.append(_err("no building holds it"))
	return out
