class_name CropFormSpec
extends RefCounted
## What a crop form is (data/crop_forms.json): which crop is drawn as which form, each form's numbers and the look
## every crop shares. The farm asks this every time it draws a plot; the builders that draw a form (CropForms)
## load by path through `builder()` only when a look has to be built, so the start does not compile them
## (docs/PERF_RUN.md, the start).

const PATH := "res://data/crop_forms.json"
const BUILDER := "res://scripts/world3d/crop_forms.gd"

static var _data := {}


static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"forms": {}, "crops": {}}
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(PATH + " is missing or not valid JSON")


## The form a crop is drawn as: its own, or its catalog shape when it has none.
static func form_of(crop_id: String, shape: String) -> String:
	_load()
	return str((_data["crops"] as Dictionary).get(crop_id, shape))


## A number of the look every crop shares (data/crop_forms.json "look"): how tall a crop may stand, how much
## its produce is enlarged.
static func look(key: String, fallback: float) -> float:
	_load()
	return float((_data.get("look", {}) as Dictionary).get(key, fallback))


## Whether `form` is drawn a plot at a time (it has a "plot": a carpet of leaves and a few big pieces of produce
## laid out over the whole plot) and not as a plant repeated in rows.
static func is_plot(form: String) -> bool:
	return spec(form).has("plot")


static func spec(form: String) -> Dictionary:
	_load()
	return (_data["forms"] as Dictionary).get(form, {})


static func forms() -> Array:
	_load()
	return (_data["forms"] as Dictionary).keys()


static func crops() -> Dictionary:
	_load()
	return _data["crops"]


## The builders that draw a form into a MeshBuilder (CropForms: build, harvest), loaded when first asked.
static func builder() -> GDScript:
	return load(BUILDER)
