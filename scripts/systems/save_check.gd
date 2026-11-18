class_name SaveCheck
extends RefCounted
## Makes a loaded save safe to use: anything damaged or out of range is dropped or mended here, once, so the
## rest of the game can trust what it is handed. A hand-edited, half-written or very old file costs a few things
## at worst, never a crash. `clean` returns how many things it had to drop or mend.

const FIELDS := ["uid", "row", "col", "t"]            # every placed object has these, as whole numbers
const COUNTS := ["coins", "gems", "xp", "unwithers", "fertilize_alls", "farmhands", "arborists", "gardeners",
	"fertilizer_bags", "queen_bees", "truffles", "fuel", "fuel_tanks", "daily_streak"]   # never negative
# (Saved maps of counts are read through GameSystem.int_map, which drops a negative or unreadable entry.)
const MAX_WHOLE := 9007199254740992.0   # 2^53: past it a JSON number is no longer an exact whole number


## `data` is changed in place. `known_items` says which ids exist; `max_size` is the farm grid's edge;
## `empty_plot` replaces a damaged plot.
static func clean(data: Dictionary, known_items: Dictionary, max_size: int, empty_plot: Dictionary) -> int:
	var fixed := 0
	for key: String in COUNTS:
		if data.has(key):
			var v: Variant = whole(data[key])
			if v == null or int(v) < 0:
				data.erase(key)
				fixed += 1
			else:
				data[key] = int(v)
	var objects: Array = data.get("objects", []) if data.get("objects") is Array else []
	var kept: Array = []
	var seen := {}
	var top := 0
	for o in objects:
		var obj := _object(o, known_items, max_size)
		if obj.is_empty() or seen.has(obj["uid"]):
			fixed += 1
			continue
		seen[obj["uid"]] = true
		top = maxi(top, int(obj["uid"]))
		kept.append(obj)
	data["objects"] = kept
	var stored: Array = []
	for o in data.get("stored", []) if data.get("stored") is Array else []:
		var uid: Variant = whole(o.get("uid")) if o is Dictionary else null
		if uid == null or int(uid) <= 0 or seen.has(int(uid)) or not (o.get("id") is String) \
				or not known_items.has(o["id"]):
			fixed += 1
			continue
		o["uid"] = int(uid)
		seen[o["uid"]] = true
		top = maxi(top, int(uid))
		stored.append(o)
	if data.has("stored"):
		data["stored"] = stored
	var next: Variant = whole(data.get("next_uid", 1))
	data["next_uid"] = maxi(1 if next == null else int(next), top + 1)
	if data.get("plots") is Array:
		var plots: Array = data["plots"]
		for i in plots.size():
			if not (plots[i] is Dictionary) or not (plots[i] as Dictionary).has("state"):
				plots[i] = empty_plot.duplicate()
				fixed += 1
	return fixed


## The object as whole numbers, or an empty dictionary if it is beyond mending.
static func _object(o: Variant, known_items: Dictionary, max_size: int) -> Dictionary:
	if not (o is Dictionary):
		return {}
	var obj: Dictionary = o
	if not (obj.get("id") is String) or not known_items.has(obj["id"]):
		return {}
	for field: String in FIELDS:
		var v: Variant = whole(obj.get(field))
		if v == null and field == "t":
			v = 0                                          # when it was made: any time will do
		if v == null:
			return {}
		obj[field] = int(v)
	if int(obj["uid"]) <= 0 or int(obj["row"]) < 0 or int(obj["col"]) < 0 \
			or int(obj["row"]) >= max_size or int(obj["col"]) >= max_size:
		return {}
	for field: String in ["level", "forage_until"]:
		if obj.has(field):
			var v: Variant = whole(obj[field])
			if v == null:
				obj.erase(field)
			else:
				obj[field] = int(v)
	return obj


## A number as a whole number (JSON gives floats), or null for anything else: NaN, infinity and a number too
## big to be exact (a hand-edited 1e300 would turn into the largest int on a phone's ARM chip, and wrap negative
## at the next coin added; on a PC into the most negative one).
static func whole(v: Variant) -> Variant:
	if v is int:
		return v
	if v is float and is_finite(v) and absf(v) <= MAX_WHOLE:
		return int(v)
	return null
