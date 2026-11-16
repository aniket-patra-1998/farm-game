class_name RecipeDef
extends ItemDef
## A good a crafting building makes from bushels and produce (Pumpkin Bread, Apple Cider, Goat Milk Soap...).
## What it is worth follows what goes into it and its star: its price, the fuel it gives, the XP for making it
## and the time it takes all rise with the star that unlocks it (balance: recipes, crafting).


func building() -> String:
	return str(data.get("building", ""))


func star() -> int:
	return int(data.get("star", 1))


## A feed recipe (Feed Mill, our own touch) makes rich feed for the Barn instead of a good: {"type", "units"}.
func feed() -> Dictionary:
	return data.get("feed", {})


func makes_feed() -> bool:
	return not feed().is_empty()


## Crop id -> bushels needed.
func inputs() -> Dictionary:
	return data.get("inputs", {})


func bushel_count() -> int:
	var n := 0
	for c in inputs():
		n += int(inputs()[c])
	return n


## What one of ingredient `id` is worth in coins: a crop's bushel what the crop sells for, produce its own value.
static func worth_of(catalog, id: String) -> int:
	var d = catalog.get_def(id)
	if d is IngredientDef:
		return (d as IngredientDef).value()
	return int(d.data.get("sell_price", 0)) if d is CropDef else 0


## What everything that goes into it is worth.
func worth(catalog) -> int:
	var v := 0
	for c: String in inputs():
		v += worth_of(catalog, c) * int(inputs()[c])
	return v


## What the good sells for: its ingredients' worth marked up, more for a higher star, plus 10% per recipe
## mastery star.
func sell_price(catalog, mastery_stars: int) -> int:
	var markup := Balance.f("recipes.sell_markup") + Balance.f("recipes.markup_per_star") * (star() - 1)
	return int(round(worth(catalog) * markup * (1.0 + 0.1 * mastery_stars)))


## Fuel the good gives when used: more for a higher star, and for each recipe mastery star.
func fuel(mastery_stars: int) -> int:
	return Balance.i("recipes.fuel_base") + Balance.i("recipes.fuel_per_recipe_star") * (star() - 1) \
		+ Balance.i("recipes.fuel_per_star") * mastery_stars


## How long it takes to make: its star's time, unless it names its own.
func craft_seconds() -> int:
	if data.has("craft_seconds"):
		return int(data["craft_seconds"])
	var hours := Balance.a("crafting.craft_hours_by_star")
	return int(float(hours[clampi(star(), 1, hours.size()) - 1]) * 3600.0)


## XP for making one.
func xp() -> int:
	return Balance.i("crafting.craft_xp_base") + Balance.i("crafting.craft_xp_per_star") * star()


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
		if not (d is CropDef or d is IngredientDef):
			out.append(_err("uses unknown crop or ingredient %s" % c))
		if int(inputs()[c]) <= 0:
			out.append(_err("needs at least one %s" % c))
	if inputs().is_empty():
		out.append(_err("has no ingredients"))
	return out
