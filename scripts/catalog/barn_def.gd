class_name BarnDef
extends BuildingDef
## The starter barn: broken until repaired with materials, then storage. It is the farm's centre: its look
## follows the VIP level, not its size, and it wears the VIP badge (docs/VIP.md).


func stores_anything() -> bool:
	return true


func look_levels() -> int:
	return maxi(Balance.a("vip.level_points").size(), 1)


func look_level(_obj: Dictionary, game: GameState) -> int:
	return clampi(game.vip.level(), 1, look_levels())


func shows_vip() -> bool:
	return true


func grand() -> bool:
	return true


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	for m in data.get("repair_parts", {}):
		if not catalog.material_ids().has(m):
			out.append(_err("repair needs unknown material %s" % m))
	return out
