class_name BloomDef
extends ProducerDef
## A FarmVille Bloom. A Single Bloom links to the Full Bloom it upgrades to (`full`), and the Full Bloom back
## (`single_of`). Single and Full of a flower share one mastery, the Full counting double.



func is_full() -> bool:
	return str(data.get("single_of", "")) != ""


## The Single Bloom of this flower: itself, or what a Full Bloom was upgraded from.
func single_id() -> String:
	return str(data["single_of"]) if is_full() else id


func full_id() -> String:
	return str(data.get("full", ""))


func upgrade_gems() -> int:
	return int(data.get("upgrade_gems", 0))


func withers() -> bool:
	return not is_full()


## Mastery points a harvest earns (FarmVille: Full Blooms double).
func mastery_points() -> int:
	return 2 if is_full() else 1


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	if is_full():
		var single = catalog.get_def(single_id())
		if single == null or str(single.data.get("full", "")) != id:
			out.append(_err("single_of %s doesn't name it as its full" % single_id()))
	else:
		var full = catalog.get_def(full_id())
		if full == null or str(full.data.get("single_of", "")) != id:
			out.append(_err("full %s doesn't link back with single_of" % full_id()))
		if upgrade_gems() <= 0:
			out.append(_err("needs upgrade_gems"))
	return out
