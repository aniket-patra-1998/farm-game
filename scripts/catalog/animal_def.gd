class_name AnimalDef
extends ProducerDef
## An animal. Strays wander in once you own their home; everything else is bought or earned.


func is_stray_only() -> bool:
	return bool(data.get("stray_only", false))


## FarmVille's lost animals: they wander onto the farm and are adopted for free.
func is_lost() -> bool:
	return bool(data.get("lost", false))


func is_young() -> bool:
	return bool(data.get("young", false))


## The baby this breed has; "" means the plain one for its home.
func baby() -> String:
	return str(data.get("baby", ""))


## What it becomes after its first collection, or "".
func grows_into() -> String:
	return str(data.get("grows_into", ""))


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	if is_stray_only():
		if str(data.get("home", "")) == "":
			out.append(_err("a stray needs a home building"))
		if in_market():
			out.append(_err("a stray can't be in the Market (unlock_level 99)"))
	if is_lost() and in_market():
		out.append(_err("a lost animal can't be in the Market (unlock_level 99)"))
	for key in ["baby", "grows_into"]:
		var ref := str(data.get(key, ""))
		if ref != "" and not (catalog.get_def(ref) is AnimalDef):
			out.append(_err("%s names unknown animal %s" % [key, ref]))
	var baby_def = catalog.get_def(baby())
	if baby_def is AnimalDef and not baby_def.is_young():
		out.append(_err("its baby %s should be marked young" % data["baby"]))
	if is_limited() and not is_young() and (gem_cost() <= 0 or not in_market()):
		out.append(_err("a limited animal is sold in the Market for gems (gem_cost, an unlock level)"))
	if touch() != "" and (not is_limited() or not TOUCHES.has(touch())):
		out.append(_err("touch is a limited animal's, one of %s" % str(TOUCHES)))
	if is_limited() and baby_def is AnimalDef and not baby_def.is_limited():
		out.append(_err("a limited animal's baby %s should be limited too" % data["baby"]))
	# Every animal should have somewhere to live, or be a loose-only special.
	var homes: Array[String] = catalog.homes_of(id)
	if homes.is_empty() and kind == "animal":
		out.append(_err("no building holds it"))
	return out
