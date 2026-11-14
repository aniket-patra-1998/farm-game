class_name LoadTrace
extends RefCounted
## Debug builds: a timed trace of opening a farm, written line by line to user://load_trace.txt and flushed at
## once, so it survives the app being killed (Android's "not responding"). The trace before the last one is
## kept too, and Settings > Testing shows it after a restart: the gap between two lines is where the time went.

const PATH := "user://load_trace.txt"
const PREVIOUS := "user://load_trace_previous.txt"
const SLOW_FRAME_MS := 50      # a frame this slow or slower is written down..
const FRAMES_WATCHED := 30     # ..among the first this many after the trace begins

static var _file: FileAccess
static var _start := 0
static var _frames := 0
static var _last_frame := 0


## Starts a new trace (the last one becomes the previous one) and watches the first frames after it.
static func begin(what: String, tree: SceneTree = null) -> void:
	if not OS.is_debug_build():
		return
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(PATH, PREVIOUS)
	_file = FileAccess.open(PATH, FileAccess.WRITE)
	_start = Time.get_ticks_msec()
	_last_frame = _start
	_frames = 0
	mark("begin " + what)  # not-ui
	if tree != null and not tree.process_frame.is_connected(_on_frame):
		tree.process_frame.connect(_on_frame)


## One line: milliseconds since the trace began, and what just happened.
static func mark(what: String) -> void:
	if _file == null:
		return
	_file.store_line("%7d ms  %s" % [Time.get_ticks_msec() - _start, what])
	_file.flush()


## The trace before the current one ("" if there is none).
static func previous() -> String:
	return FileAccess.get_file_as_string(PREVIOUS) if FileAccess.file_exists(PREVIOUS) else ""


static func _on_frame() -> void:
	var now := Time.get_ticks_msec()
	var took := now - _last_frame
	_last_frame = now
	_frames += 1
	if took >= SLOW_FRAME_MS:
		mark("frame %d took %d ms" % [_frames, took])  # not-ui
	if _frames >= FRAMES_WATCHED:
		mark("watched %d frames" % _frames)  # not-ui
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.process_frame.is_connected(_on_frame):
			tree.process_frame.disconnect(_on_frame)
