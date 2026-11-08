class_name MaterialDef
extends ItemDef
## A building material (bricks, Vehicle Parts...).


func is_basic() -> bool:
	return bool(data.get("basic", false))
