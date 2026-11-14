class_name AutoQuality
extends Node
## The first launch picks the graphics level for this device (data/quality.json `auto`): once the farm has
## settled (`warmup` seconds) it times `frames` frames and keeps one level down when the median frame's work is
## more than `down_ms`, or one up when it is under `up_ms`. Phones only ever step down unless `up_on_mobile`
## (a first farm is the lightest it will ever be), and so does a device whose renderer can't time itself (the
## time between frames, held to the screen's refresh, can only tell a phone that is too slow). A frame over
## `max_frame_ms` is a hitch or a resume and isn't counted; leaving the app starts the count again. Measured
## once, used from the next launch (`Quality.keep_measured`), so nothing changes under the player's thumb; a
## level the player picks always wins, and then nothing is measured at all. No screen (tests, CI): nothing.

var mobile := OS.has_feature("mobile")
var _rules := {}
var _waited := 0.0
var _costs := PackedFloat32Array()
var _timed := true        # every frame so far was timed by the renderer (not just the time between frames)
var _viewport := RID()


## Starts the measurement under `parent` when it should run (`should_measure`) and there is a screen.
static func start_in(parent: Node) -> AutoQuality:
	if DisplayServer.get_name() == "headless" or not should_measure():
		return null
	var auto := AutoQuality.new()
	parent.add_child(auto)
	return auto


## Whether this device still needs measuring: the player hasn't chosen, it wasn't measured before, and the rules
## are there (missing rules are a mistake, said once, and measure nothing rather than guess).
static func should_measure() -> bool:
	if Quality.chosen_by_player() or Quality.measured():
		return false
	if Quality.auto_rules().is_empty():
		push_error("data/quality.json: the `auto` rules are missing or incomplete")
		return false
	return true


func _init() -> void:
	_rules = Quality.auto_rules()


func _ready() -> void:
	_viewport = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		restart()


func _process(delta: float) -> void:
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_viewport)
	# (The render and process times read here are the last frame's.)
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(_viewport) \
		+ Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var verdict := add_sample(delta, maxf(cpu, gpu), gpu > 0.0)
	if verdict != "":
		Quality.keep_measured(verdict)
		RenderingServer.viewport_set_measure_render_time(_viewport, false)
		queue_free()


## Counts one frame: `delta` since the last (seconds), `cost_ms` its work, `timed` whether the renderer timed it
## (if not, the time between frames stands in). Returns the level to keep once enough frames are in, else "".
func add_sample(delta: float, cost_ms: float, timed: bool) -> String:
	if delta * 1000.0 > float(_rules["max_frame_ms"]):
		return ""   # a hitch or a resume: neither counted nor waited through
	_waited += delta
	if _waited < float(_rules["warmup"]):
		return ""
	_timed = _timed and timed
	_costs.append(cost_ms if timed else delta * 1000.0)
	if _costs.size() < int(_rules["frames"]):
		return ""
	return verdict(Quality.level(), median(_costs), _timed and (not mobile or bool(_rules["up_on_mobile"])))


## Starts counting again from the warmup (the app went to the background: what comes back is not a fair frame).
func restart() -> void:
	_waited = 0.0
	_costs.clear()


## The level to keep after a median frame of `cost_ms` on level `now`; a step up only when `may_rise`.
func verdict(now: String, cost_ms: float, may_rise: bool) -> String:
	if cost_ms > float(_rules["down_ms"]):
		return Quality.step(now, -1)
	if may_rise and cost_ms < float(_rules["up_ms"]):
		return Quality.step(now, 1)
	return now


## The middle value of `values` (the upper of the two middle ones for an even count), so one slow frame
## doesn't decide; 0 for none.
static func median(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]
