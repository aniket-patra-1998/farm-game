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
	return out
