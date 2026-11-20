class_name ProducerDef
extends PlaceableDef
## Collected every cycle for coins and XP.

const TOUCHES: Array[String] = ["stars", "rainbow", "sunset", "glint", "embers", "shake"]   # not-ui



func cycle_seconds() -> int:
	return int(data["cycle_seconds"])


func payout() -> int:
	return int(data.get("payout", 0))


func validate(catalog) -> Array[String]:
	var out := super.validate(catalog)
	if cycle_seconds() <= 0:
		out.append(_err("cycle_seconds must be positive"))
	return out


## A limited animal or tree (LimitedSystem, docs/LIMITED.md): bought with gems, and found only where one
## already lives.
func is_limited() -> bool:
	return bool(data.get("limited", false))


## A limited one's own touch (docs/LIMITED.md): one of TOUCHES, or "" for none.
func touch() -> String:
	return str(data.get("touch", ""))


## The variety a limited one is (data/varieties.json: Galaxy, Rainbow...), or "".
func variety() -> String:
	return str(data.get("variety", ""))
