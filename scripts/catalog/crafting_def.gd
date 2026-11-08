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
	var k := star - 1
	return {"coins": int(data["star_coins"][k]), "recipe_stars": int(data["star_recipe_stars"][k]),
		"gems": int(data["star_gems"][k])}


static func recipe_stars(crafted: int) -> int:
	var n := 0
	for at in RECIPE_STARS_AT:
		if crafted >= at:
			n += 1
	return n


func validate(catalog) -> Array[String]:
	# Stars go up with coins and recipes, not materials, so a crafting building needs no expand_materials.
	var out: Array[String] = []
	for e in super.validate(catalog):
		if not e.contains("expand_materials"):
			out.append(e)
	for key in ["star_coins", "star_recipe_stars", "star_gems"]:
		if (data.get(key, []) as Array).size() != max_level() - 1:
			out.append(_err("%s needs one entry per star after the first" % key))
	return out
