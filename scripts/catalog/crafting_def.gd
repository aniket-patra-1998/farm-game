class_name CraftingDef
extends BuildingDef
## FarmVille's crafting cottages (Bakery, Winery, Spa). Its sizes are star levels: star N has N crafting
## slots and unlocks the recipes marked star N. Going up a star takes coins plus recipe mastery stars,
## or gems instead.

## Recipe mastery: a recipe earns a star at each of these craft counts.
const RECIPE_STARS_AT := [5, 15, 30, 50, 80]


func craft_seconds() -> int:
	return int(data.get("craft_seconds", 21600))


func slots(star: int) -> int:
	return capacity(star)


## Coins, recipe stars and gems for going from star to star + 1, or {} at the top.
func star_cost(star: int) -> Dictionary:
	if star < 1 or star >= max_level():
		return {}
	var s := size(star + 1)
	return {"coins": int(s.get("coins", 0)), "recipe_stars": int(s.get("recipe_stars", 0)),
		"gems": int(s.get("gems", 0))}


func grows_by_stars() -> bool:
	return true


static func recipe_stars(crafted: int) -> int:
	var n := 0
	for at in RECIPE_STARS_AT:
		if crafted >= at:
			n += 1
	return n


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	for k in range(2, max_level() + 1):
		for key in ["coins", "recipe_stars", "gems"]:
			if not size(k).has(key):
				out.append(_err("star %d needs %s" % [k, key]))
	return out
