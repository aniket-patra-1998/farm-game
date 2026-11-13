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
var body_color := Color.WHITE    ## the coat (lighter for babies), parsed once
var accent_color := Color.BLACK  ## markings, mane, comb


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


## This animal drawn at `size` times its size (a rig of its own: the shared one, from `of`, is never changed).
static func scaled(it: Dictionary, size: float) -> AnimalRig:
	var r := _build(it)
	r.scale *= size
	return r


static func _build(it: Dictionary) -> AnimalRig:
	_load()
	var r := AnimalRig.new()
	r.id = str(it.get("id", ""))
	r.family = str(it.get("family", r.id))
	var families_data: Dictionary = _data.get("families", {})
	var family: Dictionary = families_data.get(r.family, families_data.get(DEFAULT_FAMILY, {}))
	var v: Dictionary = family.duplicate(true)
	var own: Dictionary = (_data.get("variants", {}) as Dictionary).get(r.id, {})
	v.merge(own, true)
	r.young = bool(it.get("young", false))
	# How big the kind is (a chicken against a cow) times how big this breed is among its kind (a pony).
	r.scale = float(family.get("scale", 1.0)) * float(own.get("scale", 1.0))
	if r.young:
		_make_young(r, v)
	r.type = str(v.get("type", "quad"))
	r.values = v
	r.body_color = Color.html(str(it.get("color", "#ffffff"))).lightened(float(v.get("lighten", 0.0)))
	r.accent_color = Color.html(str(it.get("accent", "#333333")))
	return r


## Turns a grown animal's build into its baby: one set of rules for every species (data/animal_rigs.json
## "young", adjusted for its body type by "by_type"), so all babies look and behave alike.
static func _make_young(r: AnimalRig, v: Dictionary) -> void:
	var y: Dictionary = (_data.get("young", {}) as Dictionary).duplicate(true)
	var type := str(v.get("type", "quad"))
	y.merge(((y.get("by_type", {}) as Dictionary).get(type, {}) as Dictionary), true)
	r.scale *= float(y.get("scale", 1.0))
	r.head_scale = float(y.get("head_scale", 1.0))
	_scale_pair(v, "body", y.get("body_scale", [1.0, 1.0]))
	_scale_pair(v, "neck", [float(y.get("neck_scale", 1.0)), 1.0])
	for k in [["leg", "leg_scale"], ["tail_len", "tail_scale"], ["speed", "speed_scale"]]:
		if v.has(k[0]):
			v[k[0]] = float(v[k[0]]) * float(y.get(k[1], 1.0))
	for k in y:
		if not (k in ["scale", "head_scale", "body_scale", "neck_scale", "leg_scale", "tail_scale", "speed_scale",
				"by_type"]):
			v[k] = y[k]


static func _scale_pair(v: Dictionary, key: String, by: Variant) -> void:
	var a = v.get(key)
	if typeof(a) == TYPE_ARRAY and (a as Array).size() >= 2 and typeof(by) == TYPE_ARRAY:
		v[key] = [float(a[0]) * float(by[0]), float(a[1]) * float(by[1])]


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
