class_name SaveMigrations
extends RefCounted
## Brings a save from an older version up to the current one, one step at a time. `STEPS[v]` turns a version-v save
## into a version v+1 save, so a save several versions old runs every step in between, in order. A change to what a
## save holds that isn't just a new field with a default bumps `GameState.SAVE_VERSION`, adds a step here for the
## old version, and a test (saving_test) writes the old shape and loads it.

## From version -> the step that makes the next one. (Fields that were only added since take their defaults when
## each system loads, so most steps are empty; the list still records every version.)
const STEPS := {
	1: "v1_to_v2",   # 2: FarmVille footprints. Objects keep their saved tiles; Game.settle_objects fixes shapes on load.
}


## `data` upgraded to the current version (in place). False when it can't be (too old, or from a newer game).
static func upgrade(data: Dictionary) -> bool:
	var version := int(data.get("version", 0))
	if version > GameState.SAVE_VERSION or version < GameState.OLDEST_SAVE_VERSION:
		return false
	while version < GameState.SAVE_VERSION:
		_step(version, data)
		version += 1
		data["version"] = version
	_widen_old_grid_in(data)
	return true


## Runs the step that turns a version-`from` save into the next version. Each step in STEPS has a case here.
static func _step(from: int, data: Dictionary) -> void:
	match from:
		1:
			pass   # v1 -> v2: the shapes are mended by Game.settle_objects after the objects are in
		_:
			push_warning("Save: no step recorded for version %d (%s)" % [from, data.get("version")])


## Saves from before land expansion stored a 12x12 grid whatever their version: copy it into the full-size grid.
static func _widen_old_grid_in(data: Dictionary) -> void:
	var plots: Array = data.get("plots", [])
	if plots.size() == GameState.OLD_GRID_SIZE * GameState.OLD_GRID_SIZE:
		data["plots"] = widen_old_grid(plots)


## Copy the 12x12 grid into the top-left of the full-size grid.
static func widen_old_grid(old: Array) -> Array:
	var wide: Array = []
	for i in GameState.MAX_SIZE * GameState.MAX_SIZE:
		wide.append({"state": "grass"})
	for r in GameState.OLD_GRID_SIZE:
		for c in GameState.OLD_GRID_SIZE:
			wide[r * GameState.MAX_SIZE + c] = old[r * GameState.OLD_GRID_SIZE + c]
	return wide
