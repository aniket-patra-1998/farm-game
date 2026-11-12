class_name Actions
extends RefCounted
## Who can do each farm action (data/actions.json): the farmer always, and then the helpers (farmhand, arborist,
## gardener) and the vehicles that do it for many things at once. One place to declare it, so a new action is
## offered to the helper that fits and a test can tell when one is not.

const DATA := "res://data/actions.json"

static var _actions := {}


static func all() -> Dictionary:
	if _actions.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_actions = (parsed as Dictionary).get("actions", {}) if parsed is Dictionary else {}
	return _actions


## The action kinds, in the order the file lists them.
static func kinds() -> Array[String]:
	var out: Array[String] = []
	for k: String in all():
		out.append(k)
	return out


## The actions the helper of this kind does when used (Game.HELPERS keys: "animal", "tree", "bloom").
static func for_helper(helper_kind: String) -> Array[String]:
	var out: Array[String] = []
	for k: String in all():
		if helper_kind in (all()[k].get("helpers", []) as Array):
			out.append(k)
	return out


## The vehicle jobs that do this action.
static func vehicle_jobs(action: String) -> Array:
	return all().get(action, {}).get("vehicles", [])


## Whether anything other than the farmer does it.
static func is_shared(action: String) -> bool:
	var a: Dictionary = all().get(action, {})
	return not (a.get("helpers", []) as Array).is_empty() or not (a.get("vehicles", []) as Array).is_empty()
