class_name FrameClock
extends Node
## How long the game's own work took this frame: from the start of the frame's processing (SceneTree.process_frame,
## before any node's _process and the deferred calls flushed with it) to the moment drawing begins
## (RenderingServer.frame_pre_draw), so the deferred calls after the last _process (a change's Objects3D sync),
## tweens and awaits are counted too; input and physics, handled before, are not. The engine's own TIME_PROCESS is
## the worst frame of each second, not this frame's, so a single stall read as a whole second of slow frames (the
## phone benchmark's "script time" and AutoQuality both read it). Without drawing (headless) the frame ends once
## the deferred calls queued by then have run. Started once under the main scene (`start_in`); `process_ms()` is
## the last whole frame's.

const LAST := 1000000     # a process priority after every other node's

static var _began := 0
static var _last_node := 0      # when the last node's _process, then the deferred calls before ours, ended
static var _pre_draw := 0       # when drawing began this frame (0: not yet)
static var _last_ms := 0.0
static var _running := false


## Puts the clock under `parent` (once).
static func start_in(parent: Node) -> void:
	if _running:
		return
	_running = true
	var n := FrameClock.new()
	n.process_priority = LAST
	n.name = "FrameClock"   # not-ui
	parent.add_child(n)
	n.tree_exiting.connect(func() -> void:
		_running = false
		if n.get_tree().process_frame.is_connected(_on_frame_start):
			n.get_tree().process_frame.disconnect(_on_frame_start))
	parent.get_tree().process_frame.connect(_on_frame_start)
	if not RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)


## The game's work last frame (ms); the engine's own count when the clock isn't running.
static func process_ms() -> float:
	return _last_ms if _running else Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0


## A new frame: the last one is told, ending where drawing began (or once its deferred calls ran, without drawing).
static func _on_frame_start() -> void:
	if _began > 0:
		var ended := _pre_draw if _pre_draw > _began else _last_node
		_last_ms = maxf(ended - _began, 0) / 1000.0
	_began = Time.get_ticks_usec()
	_pre_draw = 0


static func _on_pre_draw() -> void:
	if _pre_draw == 0:
		_pre_draw = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	_last_node = Time.get_ticks_usec()
	_after_deferred.call_deferred()   # (queued after the frame's own deferred calls: runs once they have)


func _after_deferred() -> void:
	_last_node = Time.get_ticks_usec()
