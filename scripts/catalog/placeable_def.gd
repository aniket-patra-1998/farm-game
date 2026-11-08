class_name PlaceableDef
extends ItemDef
## Anything placed on the farm: it has a footprint, can be sold, and maybe turned.

const SELL_SHARE := 0.05          # FarmVille sold anything back for 5% of its price
const SELL_COINS_PER_GEM := 50    # our guess for items bought with gems


func footprint() -> Vector2i:
	return Vector2i(int(data.get("w", 1)), int(data.get("h", 1)))


func sell_value() -> int:
	if gem_cost() > 0:
		return gem_cost() * SELL_COINS_PER_GEM
	return int(round(coin_cost() * SELL_SHARE))


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
