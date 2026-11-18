class_name Grade
extends RefCounted
## The farm's colour grade through the day, from data/grade.json: how rich the colour is by day and night, the
## contrast, and how warm the low sun makes the highlights (and cool the shadows). Read once.

const DATA := "res://data/grade.json"

static var _data := {}


## A number of the grade (data/grade.json), 0 if it has none.
static func value(key: String) -> float:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed if parsed is Dictionary else {"_": ""}
	return float(_data.get(key, 0.0))
