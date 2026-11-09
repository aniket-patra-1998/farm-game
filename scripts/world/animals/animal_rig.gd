class_name AnimalRig
extends RefCounted
## How an animal is built (sizes, features, markings) and how it behaves, read from data/animal_rigs.json:
## a family's build, overridden by its variant, then by the young-animal adjustments. Built once per item
## and shared by every animal of that kind.

const PATH := "res://data/animal_rigs.json"
const DEFAULT_FAMILY := "cow"

static var _data := {}
static var _cache := {}  # item id -> AnimalRig

var id := ""
var family := ""
var type := "quad"       ## quad, bird, hop (rabbit), shell (turtle), bug (bee)
var young := false
var scale := 1.0         ## the whole animal
var head_scale := 1.0    ## the head on top of that (babies have big heads)
var values := {}         ## every field, merged


static func of(it: Dictionary) -> AnimalRig:
	var item_id := str(it.get("id", ""))
	if _cache.has(item_id):
		return _cache[item_id]
	var r := _build(it)
	_cache[item_id] = r
	return r


## Every family in the rig file (tests check each catalog family has one).
static func families() -> Array:
	_load()
	return (_data.get("families", {}) as Dictionary).keys()


static func variant_ids() -> Array:
	_load()
	return (_data.get("variants", {}) as Dictionary).keys()


static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(PATH + " is missing or not valid JSON")
		parsed = {"families": {DEFAULT_FAMILY: {}}}
	_data = parsed


static func _build(it: Dictionary) -> AnimalRig:
	_load()
	var r := AnimalRig.new()
	r.id = str(it.get("id", ""))
	r.family = str(it.get("family", r.id))
	var families_data: Dictionary = _data.get("families", {})
	var v: Dictionary = (families_data.get(r.family, families_data.get(DEFAULT_FAMILY, {})) as Dictionary).duplicate(true)
	v.merge((_data.get("variants", {}) as Dictionary).get(r.id, {}), true)
	r.young = bool(it.get("young", false))
	if r.young:
		var y: Dictionary = _data.get("young", {})
		r.scale = float(v.get("scale", 1.0)) * float(y.get("scale", 1.0))
		r.head_scale = float(y.get("head_scale", 1.0))
		for k in y:
			if k != "scale" and k != "head_scale":
				v[k] = y[k]
	else:
		r.scale = float(v.get("scale", 1.0))
	r.type = str(v.get("type", "quad"))
	r.values = v
	return r


func num(key: String, fallback := 0.0) -> float:
	return float(values.get(key, fallback))


func text(key: String, fallback := "") -> String:
	return str(values.get(key, fallback))


func flag(key: String) -> bool:
	return bool(values.get(key, false))


## A [x, y] pair, times the animal's scale.
func pair(key: String, fallback := Vector2(10, 10)) -> Vector2:
	var a = values.get(key)
	if typeof(a) != TYPE_ARRAY or (a as Array).size() < 2:
		return fallback * scale
	return Vector2(float(a[0]), float(a[1])) * scale


## A length, times the animal's scale.
func size(key: String, fallback := 10.0) -> float:
	return float(values.get(key, fallback)) * scale


## How far the body travels in one full walk cycle. Behaviour advances the gait by distance / this,
## and the art moves each planted foot backwards by exactly the distance walked, so feet stay planted.
func cycle_length() -> float:
	return AnimalArt.STRIDE * size("leg", 12.0) / AnimalArt.STANCE


## What this animal likes to do, as weights.
func behaviour() -> Dictionary:
	return values.get("behaviour", {"idle": 1.0})
