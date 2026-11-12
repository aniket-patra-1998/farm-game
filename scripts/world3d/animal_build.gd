class_name AnimalBuild
extends RefCounted
## The build of each four-legged family (data/animal_builds.json): the masses its torso is made of, how thick
## and how straight its legs are, the shape of its head. Every skin of a species shares its build, so a cow is
## always a cow and a horse a horse; the rig data (animal_rigs.json) only sizes and colours it.

const PATH := "res://data/animal_builds.json"

static var _data := {}


## A family's build (empty if it has none: the animal keeps the old plain shapes).
static func of(family: String) -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = (parsed as Dictionary).get("families", {}) if typeof(parsed) == TYPE_DICTIONARY else {"_": {}}
	return _data.get(family, {})


static func families() -> Array:
	of("")
	return _data.keys()


## The torso: each mass an ellipsoid of the body (`r` is its half length, height and width), all in `mat`.
static func torso(parent: Node3D, masses: Array, r: Vector3, mat: Material) -> void:
	for m: Array in masses:
		ModelKit.ball(parent, Vector3(float(m[0]) * r.x, float(m[1]) * r.y, float(m[2]) * r.z), 1.0, mat,
			Vector3(float(m[3]) * r.x, float(m[4]) * r.y, float(m[5]) * r.z), true)


## A number from a build's block ("leg", "thick"), or `fallback`.
static func num(build: Dictionary, block: String, key: String, fallback: float) -> float:
	return float((build.get(block, {}) as Dictionary).get(key, fallback))


## A pair or triple from a build's block as a Vector3 (missing parts from `fallback`).
static func vec(build: Dictionary, block: String, key: String, fallback: Vector3) -> Vector3:
	var a: Array = (build.get(block, {}) as Dictionary).get(key, [])
	if a.size() < 2:
		return fallback
	return Vector3(float(a[0]), float(a[1]), float(a[2]) if a.size() > 2 else fallback.z)
