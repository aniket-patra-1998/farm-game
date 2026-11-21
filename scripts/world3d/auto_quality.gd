class_name AutoQuality
extends Node
## Keeps the game smooth on the device it runs on (data/quality.json `auto`), all session, while the player hasn't
## picked a level. It times each frame's work (what the game and the renderer did, not the time between frames,
## which the screen's refresh and any cap hold to a floor) in windows of `frames` frames. When a window's median
## is slower than the rung it is on holds (`hold_ms` uncapped, about 55 fps; `down_ms` when capped at 30), it
## steps one rung down the `ladder` at once (high, mid, mid capped at 30, low) and keeps it (`Quality.keep_measured`),
## then waits `warmup` again. So a farm that grows from 12 by 12 to 30 by 30 is followed, and a phone that can't
## hold 60 runs an even 30 rather than wobbling between 30 and 40. Only the first window on a never-measured
## computer may step up a level (under `up_ms`; `up_on_mobile` for phones). Frames over `max_frame_ms` (a hitch,
## a resume) aren't counted, unless `slow_run` of them come in a row, each within `steady_ratio` of the one before:
## that is the phone's own pace (the Galaxy A05s on mid: ~256 ms a frame, so it was never stepped down), and a
## window whose median is over `max_frame_ms` goes straight to the ladder's last rung. Leaving the app starts the
## window again. Where the renderer can't time itself, the
## time between frames stands in (it can still tell a device that is too slow, never one with time to spare).
## The player's choice always wins: nothing is watched then. No screen (tests, CI): nothing runs.

static var paused := false   # nothing is measured or moved while set (the phone benchmark sets it)
var mobile := OS.has_feature("mobile")
var _rules := {}
var _waited := 0.0
var _costs := PackedFloat32Array()
var _timed := true          # every frame this window was timed by the renderer
var _first := true          # the first window on a device never measured before (it alone may step up)
var _viewport := RID()
var _slow_in_row := 0       # frames over `max_frame_ms` in a row, each close to the one before
var _last_slow_ms := 0.0


## Starts watching under `parent` when it should (`should_watch`) and there is a screen.
static func start_in(parent: Node) -> AutoQuality:
	if DisplayServer.get_name() == "headless" or not should_watch():
		return null
	var auto := AutoQuality.new()
	parent.add_child(auto)
	return auto


## Whether this device is watched: the player hasn't chosen, and the rules are there (missing rules are a
## mistake, said once, and watch nothing rather than guess).
static func should_watch() -> bool:
	if Quality.chosen_by_player():
		return false
	if Quality.auto_rules().is_empty():
		push_error("data/quality.json: the `auto` rules are missing or incomplete")
		return false
	return true


func _init() -> void:
	_rules = Quality.auto_rules()
	_first = not Quality.measured()


func _ready() -> void:
	_viewport = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport, true)
	Quality.notifier.emitted.connect(_on_level)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		restart()


func _process(delta: float) -> void:
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_viewport)
	# (The render and process times read here are the last frame's.)
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(_viewport) + FrameClock.process_ms()
	if paused:
		return   # (the benchmark measures one level from start to end)
	var rung := add_sample(delta, maxf(cpu, gpu), gpu > 0.0)
	if not rung.is_empty():
		Quality.keep_measured(str(rung[0]), int(rung[1]))


## The player picked a level: nothing to watch any more.
func _on_level() -> void:
	if Quality.chosen_by_player():
		RenderingServer.viewport_set_measure_render_time(_viewport, false)
		queue_free()


## Counts one frame: `delta` since the last (seconds), `cost_ms` its work, `timed` whether the renderer timed it.
## Returns the rung to move to ([level, cap]) when a window ends slow (or, the first time, fast), else [].
func add_sample(delta: float, cost_ms: float, timed: bool) -> Array:
	if not counts(delta * 1000.0):
		return []   # a hitch or a resume: neither counted nor waited through
	_waited += delta
	if _waited < float(_rules["warmup"]):
		return []
	_timed = _timed and timed
	_costs.append(cost_ms if timed else delta * 1000.0)
	if _costs.size() < int(_rules["frames"]):
		return []
	var now := rung_now()
	var next := verdict(now, median(_costs), _first and _timed and (not mobile or bool(_rules["up_on_mobile"])))
	_first = false
	restart()
	return next if next != now else []


## Whether a frame `ms` long counts: under `max_frame_ms`, or one of a steady run of slower frames (`slow_run` in a
## row, each within `steady_ratio` of the one before; a hitch or a first draw's stall is a lone long frame).
func counts(ms: float) -> bool:
	if ms <= float(_rules["max_frame_ms"]):
		_slow_in_row = 0
		_last_slow_ms = 0.0
		return true
	var steady := _last_slow_ms > 0.0 and absf(ms - _last_slow_ms) <= _last_slow_ms * float(_rules["steady_ratio"])
	_slow_in_row = _slow_in_row + 1 if steady else 1
	_last_slow_ms = ms
	return _slow_in_row >= int(_rules["slow_run"])


## Starts the window again from the warmup (after a step, or the app coming back: not a fair frame yet).
func restart() -> void:
	_waited = 0.0
	_costs.clear()
	_timed = true
	_slow_in_row = 0
	_last_slow_ms = 0.0


## The rung in use: [level, the cap AutoQuality set (0 none)].
func rung_now() -> Array:
	return [Quality.level(), Quality.measured_cap()]


## The rung to be on after a window whose median frame took `cost_ms` on rung `now`: one down the ladder when
## slower than `now` holds (to the last rung when over `max_frame_ms`: it can't play there at all), one level up
## when `may_rise` and under `up_ms`, else `now`.
func verdict(now: Array, cost_ms: float, may_rise: bool) -> Array:
	var ladder: Array = _rules["ladder"]
	var at := _index(ladder, now)
	var slow := float(_rules["down_ms"]) if int(now[1]) > 0 else float(_rules["hold_ms"])
	if cost_ms > slow:
		var r: Array = ladder[ladder.size() - 1] if cost_ms > float(_rules["max_frame_ms"]) \
			else ladder[mini(at + 1, ladder.size() - 1)]
		return [str(r[0]), int(r[1])]   # (the data's numbers come as floats)
	if may_rise and cost_ms < float(_rules["up_ms"]):
		var up := Quality.step(str(now[0]), 1)
		return [up, 0] if Quality.offered().has(up) else [str(now[0]), int(now[1])]
	return [str(now[0]), int(now[1])]


## Where rung `now` stands on the ladder (a level not on it: the first rung of that level, else the top).
static func _index(ladder: Array, now: Array) -> int:
	var first_of_level := -1
	for k in ladder.size():
		var r: Array = ladder[k]
		if str(r[0]) == str(now[0]):
			if int(r[1]) == int(now[1]):
				return k
			if first_of_level < 0:
				first_of_level = k
	return maxi(first_of_level, 0)


## The middle value of `values` (the upper of the two middle ones for an even count), so one slow frame
## doesn't decide; 0 for none.
static func median(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]
