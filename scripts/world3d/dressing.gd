class_name Dressing
extends RefCounted
## What lies round the foot of things on the farm: tufts of tall grass, wildflowers and stones along the edge
## of each object's footprint, so it stands planted in its place and not set down on bare grass. One rule
## for every kind of object, from data/dressing.json; the same object always gets the same scatter (its
## own seed). Built into one merged mesh per object, swaying in the wind with the rest.

const PATH := "res://data/dressing.json"
const SWAY := 0.03             # how far the tufts bend in the wind (paint3d sway, by height)
const TUFT_BLADES := 3

static var _data := {}


## The dressing for an object of `kind` on a `fp` footprint, as a node to put under the object's model (which
## has the footprint's back corner as its origin); null if that kind gets none.
static func make(kind: String, fp: Vector2i, seed_value: int) -> Node3D:
	_load()
	var rules: Dictionary = (_data.get("kinds", {}) as Dictionary).get(kind, {})
	if rules.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 2654435761 + 17
	var root := Node3D.new()
	var edge := float(fp.x + fp.y) * 2.0
	var band := float(rules.get("band", 0.2))
	var grass: Array = _data.get("grass_colours", ["#5aa33c"])
	var flowers: Array = _data.get("flower_colours", ["#f6e04a"])
	for i in int(round(float(rules.get("tufts", 0.0)) * edge / 4.0)):
		_tuft(root, _spot(rng, fp, band), rng, Color.html(str(grass[rng.randi() % grass.size()])))
	for i in int(round(float(rules.get("flowers", 0.0)) * edge / 4.0)):
		var at := _spot(rng, fp, band)
		var col := Color.html(str(flowers[rng.randi() % flowers.size()]))
		ModelKit.cylinder(root, at, 0.004, 0.06, ModelKit.paint(Color("#4f8a3a")), -1.0, 4)
		ModelKit.ball(root, at + Vector3(0, 0.065, 0), 0.016, ModelKit.paint(col))
	for i in int(round(float(rules.get("stones", 0.0)) * edge / 4.0)):
		var r := rng.randf_range(0.02, 0.045)
		ModelKit.facet_ball(root, _spot(rng, fp, band) + Vector3(0, r * 0.3, 0), r,
			ModelKit.paint(Color("#9a9a94").darkened(rng.randf_range(0.0, 0.18))), Vector3(1.2, 0.6, 1.0))
	ModelKit.sway_all(root, SWAY)
	return ModelKit.bake(root)


## A place in the band just outside the footprint's edge (a point on the perimeter, nudged outward).
static func _spot(rng: RandomNumberGenerator, fp: Vector2i, band: float) -> Vector3:
	var along := rng.randf() * float(fp.x + fp.y) * 2.0
	var out := rng.randf_range(0.0, band)
	var w := float(fp.x)
	var d := float(fp.y)
	if along < w:
		return Vector3(along, 0, d - 0.04 + out * 0.5)
	along -= w
	if along < d:
		return Vector3(w - 0.04 + out * 0.5, 0, along)
	along -= d
	if along < w:
		return Vector3(along, 0, 0.04 - out * 0.5)
	return Vector3(0.04 - out * 0.5, 0, along - w)


## Three blades of grass leaning apart.
static func _tuft(root: Node3D, at: Vector3, rng: RandomNumberGenerator, col: Color) -> void:
	for b in TUFT_BLADES:
		var a := rng.randf() * TAU
		var h := rng.randf_range(0.07, 0.13)
		var blade := ModelKit.cylinder(root, at, 0.012, h, ModelKit.paint(col.darkened(rng.randf_range(0.0, 0.15))),
			0.0, 3)
		blade.position += Vector3(cos(a) * 0.012, 0, sin(a) * 0.012)
		blade.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35)


static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"kinds": {}}
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(PATH + " is missing or not valid JSON")
