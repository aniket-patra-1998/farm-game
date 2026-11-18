class_name Grade
extends RefCounted
## The farm's colour grade through the day, from data/grade.json: how rich the colour is by day and night, the
## contrast, and how warm the low sun makes the highlights (and cool the shadows). Read once.

const DATA := "res://data/grade.json"

static var _data := {}


## A number of the grade (data/grade.json), 0 if it has none.
static func value(key: String) -> float:
	if _data.is_empty():
		_data = DataFile.read(DATA)
		if _data.is_empty():
			_data = {"_": ""}   # (read once, even when missing)
	return float(_data.get(key, 0.0))
