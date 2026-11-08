class_name DecorationDef
extends PlaceableDef
## Scenery. FarmVille gave at least 5 XP for any bought decoration.

const MIN_XP := 5
const STARTER_SCENERY := ["farmhouse", "mailbox", "farm_stand"]  ## drawn by id, not shape


func buy_xp() -> int:
	if coin_cost() <= 0:
		return super.buy_xp()
	return maxi(MIN_XP, super.buy_xp())


func can_sell() -> bool:
	return id != "farmhouse"


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	if str(data.get("shape", "")) == "" and not STARTER_SCENERY.has(id):
		out.append(_err("needs a shape to draw until it has final art"))
	return out
