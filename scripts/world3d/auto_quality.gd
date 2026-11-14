class_name AutoQuality
extends Node
## The first launch picks the graphics level for this device: once the farm has settled (`warmup`), it watches
## what each frame costs for `window` seconds and moves one level down when the median frame can't keep up
## (`down_ms`), or up when it has plenty to spare (`up_ms`) (data/quality.json `auto`). Done once and kept as
## the device's own default (`Quality.keep_measured`); a level the player picks in Settings always wins, and
## nothing is measured at all then. Without a screen (tests, CI) it does nothing.
##
## A frame's cost is the work the game and the renderer did for it, not the time between frames, which the
## screen's refresh and the frame cap hold to a floor; where the renderer can't time itself, the time between
## frames stands in for it (it can still tell a phone that is too slow).

var _waited := 0.0
var _costs: PackedFloat32Array = []
var _viewport := RID()


## Starts the measurement under `parent`, unless the player has chosen or the device was measured before.
static func start_in(parent: Node) -> AutoQuality:
	if DisplayServer.get_name() == "headless" or Quality.chosen_by_player() or Quality.measured():
		return null
	var auto := AutoQuality.new()
	auto.name = "AutoQuality"
	parent.add_child(auto)
	return auto


func _ready() -> void:
	_viewport = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport, true)


func _process(delta: float) -> void:
	_waited += delta
	if _waited < Quality.auto_rule("warmup"):
		return
	_costs.append(frame_cost(delta))
	if _waited < Quality.auto_rule("warmup") + Quality.auto_rule("window"):
		return
	Quality.keep_measured(verdict(Quality.level(), median(_costs)))
	RenderingServer.viewport_set_measure_render_time(_viewport, false)
	queue_free()


## What this frame cost, in milliseconds.
func frame_cost(delta: float) -> float:
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_viewport)
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(_viewport) \
		+ Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	if gpu <= 0.0:
		return delta * 1000.0
	return maxf(cpu, gpu)


## The level to keep after measuring `cost_ms` (the median frame) on level `now`.
static func verdict(now: String, cost_ms: float) -> String:
	if cost_ms > Quality.auto_rule("down_ms"):
		return Quality.step(now, -1)
	if cost_ms < Quality.auto_rule("up_ms"):
		return Quality.step(now, 1)
	return now


static func median(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]
