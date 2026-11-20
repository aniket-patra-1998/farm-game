class_name Varieties
extends RefCounted
## The varieties limited animals and trees come in (data/varieties.json; owner, 20 Nov: one structure over both,
## so a variety is described once and worn by either, and a new one is a row). A limited item names its variety
## (catalog `variety`). A tree takes its look from here; an animal's is drawn by the art tool.

const FILE := "res://data/varieties.json"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = DataFile.read(FILE)
	return _data


static func has(id: String) -> bool:
	return (data()["varieties"] as Dictionary).has(id)


## Variety `id`'s row ({} if there is none).
static func of(id: String) -> Dictionary:
	return (data()["varieties"] as Dictionary).get(id, {})


## The varieties trees come in, in the order they are shown.
static func of_trees() -> Array:
	return data()["trees"]


## The colours of a tree's crown in variety `id`: its masses' in turn ([] if the variety has no look for trees).
static func leaves(id: String) -> Array[Color]:
	var out: Array[Color] = []
	for hex: String in of(id).get("leaves", []):
		out.append(Color.html(hex))
	return out
