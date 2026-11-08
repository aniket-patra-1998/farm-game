class_name CropDef
extends ItemDef
## A crop. FarmVille's ripe window: as long as it takes to grow, at least 4 hours, at most 2 days.

const MIN_RIPE_WINDOW := 4 * 3600
const MAX_RIPE_WINDOW := 2 * 86400


func grow_seconds() -> int:
	return int(data["grow_seconds"])


func ripe_window() -> int:
	return clampi(grow_seconds(), MIN_RIPE_WINDOW, MAX_RIPE_WINDOW)


## Coins earned per hour of growing, after the seed cost.
func profit_per_hour() -> float:
	return (int(data["sell_price"]) - int(data["seed_cost"])) / (grow_seconds() / 3600.0)


func validate(_catalog) -> Array[String]:
	var out: Array[String] = []
	if int(data["sell_price"]) <= int(data["seed_cost"]):
		out.append(_err("sells for no more than its seeds cost"))
	if grow_seconds() <= 0:
		out.append(_err("grow_seconds must be positive"))
	return out
