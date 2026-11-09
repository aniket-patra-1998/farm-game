class_name RecipeDef
extends ItemDef
## A good a crafting building makes from bushels (FarmVille's Pumpkin Bread, Red Table Wine...).

## What a good sells for, over the value of its bushels, plus 10% per recipe mastery star.
const SELL_MARKUP := 1.5
## Fuel a good gives when used, plus FUEL_PER_STAR per recipe mastery star.
const FUEL_BASE := 20
const FUEL_PER_STAR := 10


func building() -> String:
	return str(data.get("building", ""))


func star() -> int:
	return int(data.get("star", 1))


## Crop id -> bushels needed.
func inputs() -> Dictionary:
	return data.get("inputs", {})


func bushel_count() -> int:
	var n := 0
	for c in inputs():
		n += int(inputs()[c])
	return n


## crops = the game's crop dictionaries (id -> crop).
func sell_price(crops: Dictionary, mastery_stars: int) -> int:
	var v := 0.0
	for c in inputs():
		v += float(crops[c]["sell_price"]) * int(inputs()[c])
	return int(round(v * SELL_MARKUP * (1.0 + 0.1 * mastery_stars)))


func fuel(mastery_stars: int) -> int:
	return FUEL_BASE + FUEL_PER_STAR * mastery_stars


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	if not (catalog.get_def(building()) is CraftingDef):
		out.append(_err("made in unknown crafting building %s" % building()))
	elif star() > (catalog.get_def(building()) as CraftingDef).max_level():
		out.append(
			_err(
				"needs star %d but %s only has %d" % [
					star(),
					building(),
					(catalog.get_def(building()) as CraftingDef).max_level()
				]
			)
		)
	for c in inputs():
		var d = catalog.get_def(str(c))
		if not (d is CropDef):
			out.append(_err("uses unknown crop %s" % c))
		if int(inputs()[c]) <= 0:
			out.append(_err("needs at least one %s" % c))
	if inputs().is_empty():
		out.append(_err("has no ingredients"))
	return out
