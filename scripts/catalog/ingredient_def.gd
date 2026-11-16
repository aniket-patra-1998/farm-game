class_name IngredientDef
extends ItemDef
## Produce for crafting (our own touch): what an animal, the beehive, a tree or a bloom gives beside its coins
## (milk, eggs, honey, apples, roses). Held with the bushels and used by recipes like one.


## What one is worth in coins: a recipe's price follows its ingredients' worth.
func value() -> int:
	return int(data.get("value", 0))


## How it is pictured (GoodsModel).
func shape() -> String:
	return str(data.get("shape", ""))


## Whether the thing with catalog data `it` gives this: by its id, by what an animal is said to give (its
## `product`), or by a tree's or a bloom's family.
func given_by(it: Dictionary) -> bool:
	if (data.get("items", []) as Array).has(str(it.get("id", ""))):
		return true
	if str(it.get("kind", "")) in ["tree", "bloom"]:
		return (data.get("families", []) as Array).has(str(it.get("family", "")))
	return str(it.get("kind", "")) == "animal" and (data.get("products", []) as Array).has(str(it.get("product", "")))


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	if value() <= 0:
		out.append(_err("is worth nothing"))
	if (data.get("items", []) as Array).is_empty() and (data.get("families", []) as Array).is_empty() \
			and (data.get("products", []) as Array).is_empty():
		out.append(_err("comes from nothing (items, families or products)"))
	for id in data.get("items", []):
		if catalog.get_def(str(id)) == null:
			out.append(_err("comes from unknown %s" % id))
	return out
