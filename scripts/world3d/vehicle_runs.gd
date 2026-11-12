class_name VehicleRuns
extends Node3D
## Shows a vehicle at work: whenever the farmer sends one over an area and it finds something to do, a VehicleRun
## drives it over the field (the work itself is already done). A few at a time; when there are too many, the
## rest only leave their tracks. Owns the dust everyone kicks up.

const MAX_RUNS := 3

var puffs := DustPuffs.new()
var trails: Trails
var _runs: Array[VehicleRun] = []


func _ready() -> void:
	add_child(puffs)
	Game.player.action_done.connect(_on_action_done)


func running() -> int:
	return _runs.size()


func _on_action_done(job: Dictionary, result: Dictionary) -> void:
	if str(job.get("kind", "")) != "vehicle" or result.is_empty() or int(result.get("plots", 0)) == 0:
		return
	run(str(job["item"]), int(job["row"]), int(job["col"]))


## Drives vehicle `id` over the area it works from plot (row, col), kept inside the farm. Returns the run, or
## null when it only left tracks (too many already, or none of the area is on the farm).
func run(id: String, row: int, col: int) -> VehicleRun:
	var area := Game.vehicles.vehicle_area(id)
	var r0 := maxi(row, 0)
	var c0 := maxi(col, 0)
	var r1 := mini(row + area.y, Game.farm_size)
	var c1 := mini(col + area.x, Game.farm_size)
	if r1 <= r0 or c1 <= c0:
		return null
	var field := Vector2i(c1 - c0, r1 - r0)
	if _runs.size() >= MAX_RUNS:
		if trails != null:
			trails.lay_tracks(r0, c0, field)
		return null
	var r := VehicleRun.create(Game.item_data(id), r0, c0, field, puffs, trails)
	_runs.append(r)
	r.finished.connect(func() -> void: _runs.erase(r))
	add_child(r)
	return r
