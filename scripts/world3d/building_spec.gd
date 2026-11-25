class_name BuildingSpec
extends RefCounted
## What a building is, from data/building_models.json, without building it: its description at a size, what it
## takes up on its footprint, where its yard's things and troughs stand, and the names its parts carry. The farm
## asks these every sync; BuildingModel (loaded by path, only when a look has to be built) builds the model.
## Kept apart so a phone's start does not compile the builders (docs/PERF_RUN.md, the start).

const PATH := "res://data/building_models.json"
const MODEL := "res://scripts/world3d/building_model.gd"   # the builders, loaded when first asked for (`model`)
const FOOT_OUT := 0.085      # a building's stone footing is this much wider than its walls (BuildingModel.PLINTH)
const WINDOWS := &"window_spots"   # meta on a marker child: the windows animals can look out of ([{at, size}])
const DOOR := &"door_swing"   # meta on a door's hinge: which way it swings open
const SLIDE := "slide"   # not-ui (a meta on a door that rolls up: how far)
const PLAN := "plan"         # not-ui (the state of the part that shows what is still to be built: `_plan`)
const BALE := Vector3(0.13, 0.15, 0.09)   # a hay bale's half length, its height and half width, in tiles
const SKEP_R := 0.165         # a straw hive's radius at its foot, in tiles (a hive drawn `scale` times this)..
const SKEP_ROOM := 1.35       # ..and the room it keeps clear round it in its yard, against that radius
const FEATURE_R := {"rock": 0.3, "pool": 0.32, "wallow": 0.34, "carrots": 0.26, "fuel_pump": 0.18, "burrow": 0.34}
const WOOD := Color("#8a5a36")
const HAY := Color("#e2c25a")

static var _data := {}
static var _fills := {}   # fill_of, by "id|level"


## How a building is built at a size (`level`, 1 the smallest): its own description over the defaults,
## then each size's changes up to `level` laid on in turn (data "levels": {"2": {...}, "3": {...}}).
## A size's "drop" first removes features of those types; its "features" are added; anything else
## (body, roof, door: merged; windows, window_rows: replaced) changes the building itself.
## A number of the look every building shares (data/building_models.json "look"); 1 when it is not set.
static func look_of(key: String) -> float:
	_load()
	return float((_data.get("look", {}) as Dictionary).get(key, 1.0))


## The shared look laid over a building's own numbers: lower walls and a bigger door (chunky, as the farm art
## these follow is), and for a home with a yard a smaller shed drawn back into its corner, so the yard and the
## animals in it are most of what is seen.
static func _styled(s: Dictionary) -> Dictionary:
	var body: Dictionary = s["body"]
	body["h"] = float(body.get("h", 0.85)) * look_of("walls")
	var yard := (s.get("features", []) as Array).any(func(f: Dictionary) -> bool: return f.get("type") == "yard")
	if yard:
		var k := look_of("shed")
		var at: Array = body.get("at", [0.5, 0.42])
		var w := float(body.get("w", 0.7))
		var d := float(body.get("d", 0.66))
		body["at"] = [float(at[0]) - w * (1.0 - k) / 2.0, float(at[1]) - d * (1.0 - k) / 2.0]
		body["w"] = w * k
		body["d"] = d * k
	var door: Dictionary = s.get("door", {})
	door["w"] = float(door.get("w", 0.28)) * look_of("door")
	door["h"] = minf(float(door.get("h", 0.55)) * look_of("door"), float(body["h"]) * 0.8)
	s["door"] = door
	return s


static func spec(id: String, level := 1) -> Dictionary:
	_load()
	var out: Dictionary = (_data["default"] as Dictionary).duplicate(true)
	var own: Dictionary = ((_data.get("buildings", {}) as Dictionary).get(id, {}) as Dictionary).duplicate(true)
	var sizes: Dictionary = own.get("levels", {})
	own.erase("levels")
	_lay_on(out, own)
	for l in range(2, level + 1):
		var step: Dictionary = sizes.get(str(l), {})
		var dropped: Array = step.get("drop", [])
		out["features"] = (out.get("features", []) as Array).filter(
			func(f: Dictionary) -> bool: return not dropped.has(f.get("type")))
		(out["features"] as Array).append_array(step.get("features", []))
		var rest := step.duplicate(true)
		rest.erase("drop")
		rest.erase("features")
		_lay_on(out, rest)
	return _styled(out)


## What a building's model says about its fill (see BuildingFill): cached, since it is asked for every sync.
## Read-only: callers must not change it.
static func fill_of(id: String, level := 1) -> Dictionary:
	var key := "%s|%d" % [id, level]
	if not _fills.has(key):
		_fills[key] = spec(id, level).get("fill", {})
	return _fills[key]


## The sizes a building has changes for (2, 3...), from its description (tests check them).
static func sizes_of(id: String) -> Array:
	_load()
	var own: Dictionary = (_data.get("buildings", {}) as Dictionary).get(id, {})
	return (own.get("levels", {}) as Dictionary).keys().map(func(k: String) -> int: return int(k))


static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"default": {}, "buildings": {}}
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(PATH + " is missing or not valid JSON")


static func _lay_on(out: Dictionary, changes: Dictionary) -> void:
	for k in changes:
		if typeof(changes[k]) == TYPE_DICTIONARY and typeof(out.get(k)) == TYPE_DICTIONARY:
			(out[k] as Dictionary).merge(changes[k], true)
		else:
			out[k] = changes[k]


## What a building at `spec` takes up on its footprint, as rectangles on the ground (x along columns, y
## along rows): its main block and its annexes, and what stands beside it (a silo, a trough, a deck...).
## Where animals can stand in the yard is the rest (BuildingFill).
static func taken(s: Dictionary, fp: Vector2i) -> Array[Rect2]:
	var fw := float(fp.x)
	var fd := float(fp.y)
	var body: Dictionary = s["body"]
	var bw := float(body.get("w", 0.7)) * fw
	var bd := float(body.get("d", 0.66)) * fd
	var at: Array = body.get("at", [0.5, 0.42])
	var lo := Vector2(float(at[0]) * fw - bw / 2.0, float(at[1]) * fd - bd / 2.0)
	var hi := lo + Vector2(bw, bd)
	var out: Array[Rect2] = []
	if bw > 0.0:
		out.append(Rect2(lo, hi - lo))
	for f: Dictionary in s.get("features", []):
		match str(f.get("type", "")):
			"wing":
				var depth := float(f.get("depth", 0.32))
				if str(f.get("side", "right")) == "front":
					out.append(Rect2(lo.x, hi.y, bw, depth))
				else:
					out.append(Rect2(hi.x, lo.y, depth, bd))
			"hay_bales" when f.has("at"):
				var spot := yard_spot(f, fw, fd)
				var half := Vector2(BALE.x * 2.0 + 0.04, BALE.z * 2.0) * float(f.get("scale", 1.0))
				out.append(Rect2(spot - half, half * 2.0))
			"rack" when f.has("at"):
				var spot := yard_spot(f, fw, fd)
				out.append(Rect2(spot.x - 0.28, spot.y - 0.16, 0.56, 0.32))
			"skep":
				var spot := yard_spot(f, fw, fd)
				var room := SKEP_R * SKEP_ROOM * float(f.get("scale", 1.0))
				out.append(Rect2(spot.x - room, spot.y - room, room * 2.0, room * 2.0 + 0.08))
			"lean_to", "terrace", "barrels", "hay_bales":
				out.append(Rect2(hi.x, lo.y, minf(0.5, fw - hi.x), bd))
			"porch", "stall_doors":
				out.append(Rect2(lo.x, hi.y, bw, 0.32))
			"water_trough":
				var spot := trough_at(hi, fw, fd)
				out.append(Rect2(spot.x - 0.22, spot.y - 0.09, 0.44, 0.18))
			"silo":
				var p: Array = f.get("at", [0.85, 0.2])
				var r := float(f.get("r", 0.22)) + 0.04
				out.append(Rect2(float(p[0]) * fw - r, float(p[1]) * fd - r, r * 2.0, r * 2.0))
			"duck_house":
				var p: Array = f.get("at", [0.82, 0.2])
				out.append(Rect2(float(p[0]) * fw - 0.24, float(p[1]) * fd - 0.2, 0.48, 0.8))
			"beehives":
				var n := int(f.get("count", 3))
				for k in n:
					var x := lerpf(0.4, fw - 0.4, k / maxf(n - 1.0, 1.0))
					out.append(Rect2(x - 0.18, fd * (0.4 + 0.2 * (k % 2)) - 0.16, 0.36, 0.32))
			"ramp":
				out.append(Rect2((lo.x + hi.x) / 2.0 - 0.1, hi.y, 0.2, 0.45))
			"nest_boxes":
				out.append(Rect2(hi.x, lo.y, 0.14, bd))
			"rock", "pool", "wallow", "carrots", "fuel_pump", "burrow":
				var spot := yard_spot(f, fw, fd)
				var r := float(f.get("r", FEATURE_R.get(str(f["type"]), 0.3)))
				out.append(Rect2(spot.x - r, spot.y - r, r * 2.0, r * 2.0))
	return out


## Where a yard's water trough stands, by its building's front right corner `hi` (x, z).
static func trough_at(hi: Vector2, fw: float, fd: float) -> Vector2:
	return Vector2(minf(hi.x + 0.45, fw - 0.3), minf(hi.y + 0.35, fd - 0.2))


## Where the animals of a yard can drink: the middle of each water trough in it (BuildingFill sends them).
static func troughs(s: Dictionary, fp: Vector2i) -> Array[Vector2]:
	var body: Dictionary = s["body"]
	var at: Array = body.get("at", [0.5, 0.42])
	var hi := Vector2(float(at[0]) * fp.x + float(body.get("w", 0.7)) * fp.x / 2.0,
		float(at[1]) * fp.y + float(body.get("d", 0.66)) * fp.y / 2.0)
	var out: Array[Vector2] = []
	for f: Dictionary in s.get("features", []):
		if str(f.get("type", "")) == "water_trough":
			out.append(trough_at(hi, fp.x, fp.y))
	return out


## Where a feature that stands in the yard goes: its `at` (shares of the footprint), or the front right corner.
static func yard_spot(f: Dictionary, fw: float, fd: float) -> Vector2:
	var at: Array = f.get("at", [0.74, 0.74])
	return Vector2(float(at[0]) * fw, float(at[1]) * fd)


## The whole building at its size, under a new node. `fp` is the footprint in tiles (columns, rows).
## `active` is whether it is at work (a bakery with something in the oven): only then does its chimney smoke.


## The builders (BuildingModel), loaded by path the first time a building's look has to be built: a look kept
## on disk (ModelStore) never needs them, so a start never compiles them for it.
static func model() -> GDScript:
	return load(MODEL)
