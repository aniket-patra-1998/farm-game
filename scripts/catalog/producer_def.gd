class_name ProducerDef
extends PlaceableDef
## Collected every cycle for coins and XP.


func cycle_seconds() -> int:
	return int(data["cycle_seconds"])


func payout() -> int:
	return int(data.get("payout", 0))


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	if cycle_seconds() <= 0:
		out.append(_err("cycle_seconds must be positive"))
	return out
