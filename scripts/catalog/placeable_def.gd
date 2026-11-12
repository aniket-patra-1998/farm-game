class_name PlaceableDef
extends ItemDef
## Anything placed on the farm: it has a footprint, can be sold, and maybe turned.



func footprint() -> Vector2i:
	return Vector2i(int(data.get("w", 1)), int(data.get("h", 1)))


func sell_value() -> int:
	if gem_cost() > 0:
		return gem_cost() * Balance.i("market.sell_coins_per_gem")
	return int(round(coin_cost() * Balance.f("market.sell_share")))


## Arrives as a frame or a chassis and is finished with materials on the farm (FarmVille's way), so it
## can't be bought straight into a home.
func built_in_place() -> bool:
	return data.has("build_materials")


## Square things turn without changing size. Buildings keep their level badge readable.
func can_rotate() -> bool:
	var fp := footprint()
	return fp.x == fp.y


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	var fp := footprint()
	if fp.x < 1 or fp.y < 1:
		out.append(_err("footprint must be at least 1x1"))
	if in_market() and coin_cost() <= 0 and gem_cost() <= 0 and Catalog.FREE_IN_MARKET.find(id) < 0:
		out.append(_err("is in the Market but costs nothing"))
	return out
