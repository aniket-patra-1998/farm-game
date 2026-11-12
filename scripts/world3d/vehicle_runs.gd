class_name VehicleRuns
extends Node3D
## Draws the vehicles at work: whenever VehicleSystem sets one off (run_started) a VehicleRun follows it over
## the field. Owns the dust everyone kicks up. A few at a time are drawn (the rest still work, unseen).

const MAX_RUNS := 3

var puffs := DustPuffs.new()
var trails: Trails
var _runs: Array[VehicleRun] = []


func _ready() -> void:
	add_child(puffs)
	Game.vehicles.run_started.connect(show_run)
	for run in Game.vehicles.runs:
		show_run(run)


func running() -> int:
	return _runs.size()


## Starts drawing `work`; returns its picture, or null when too many are drawn already.
func show_run(work: VehicleWork) -> VehicleRun:
	if _runs.size() >= MAX_RUNS:
		return null
	var r := VehicleRun.create(work, puffs, trails)
	_runs.append(r)
	r.finished.connect(func() -> void: _runs.erase(r))
	add_child(r)
	return r
