class_name FrameClock
extends Node
## How long the scripts took this frame: the time from the first node's _process to the last one's (a node at
## each end of the order). The engine's own TIME_PROCESS is the worst frame of each second, not this frame's, so a
## single stall read as a whole second of slow frames (the phone benchmark's "script time" and AutoQuality both
## read it). Started once under the main scene (`start_in`); `process_ms()` is the last frame's.

const FIRST := -1000000   # a process priority before every other node's
const LAST := 1000000     # and after

static var _began := 0
static var _last_ms := 0.0
static var _running := false

var _end := false


## Puts the two ends of the clock under `parent` (once).
static func start_in(parent: Node) -> void:
	if _running:
		return
	_running = true
	for end in [false, true]:
		var n := FrameClock.new()
		n._end = end
		n.process_priority = LAST if end else FIRST
		n.name = "FrameClockEnd" if end else "FrameClockStart"   # not-ui
		parent.add_child(n)
		n.tree_exiting.connect(func() -> void: _running = false)


## The scripts' time last frame (ms); the engine's own count when the clock isn't running.
static func process_ms() -> float:
	return _last_ms if _running else Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0


func _process(_delta: float) -> void:
	if _end:
		_last_ms = (Time.get_ticks_usec() - _began) / 1000.0
	else:
		_began = Time.get_ticks_usec()
