class_name TreeDef
extends ProducerDef
## A fruit or nut tree. A rare variety links back to its parent, and the parent to it.


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	var rare := str(data.get("rare_sapling", ""))
	if rare != "":
		var r = catalog.get_def(rare)
		if r == null or str(r.data.get("rare_of", "")) != id:
			out.append(_err("rare_sapling %s doesn't link back with rare_of" % rare))
	var parent := str(data.get("rare_of", ""))
	if parent != "":
		var p = catalog.get_def(parent)
		if p == null or str(p.data.get("rare_sapling", "")) != id:
			out.append(_err("rare_of %s doesn't name it as its rare_sapling" % parent))
		elif payout() <= (p as TreeDef).payout():
			out.append(_err("a rare variety should pay more than %s" % parent))
	if is_limited():
		var plain = catalog.get_def(limited_of())
		if not plain is TreeDef or (plain as TreeDef).is_limited() \
				or str(plain.data.get("family", "")) != str(data.get("family", "")):
			out.append(_err("a limited tree is a variety of a plain tree of its family (limited_of)"))
		elif payout() <= (plain as TreeDef).payout():
			out.append(_err("a limited tree should pay more than %s" % limited_of()))
		if gem_cost() <= 0 or not in_market():
			out.append(_err("a limited tree is sold in the Market for gems (gem_cost, an unlock level)"))
		if not Varieties.has(variety()):
			out.append(_err("variety %s is not one of data/varieties.json" % variety()))
	if touch() != "" and (not is_limited() or not TOUCHES.has(touch())):
		out.append(_err("touch is a limited tree's, one of %s" % str(TOUCHES)))
	return out


## For a limited tree: the plain tree it is a variety of.
func limited_of() -> String:
	return str(data.get("limited_of", ""))
