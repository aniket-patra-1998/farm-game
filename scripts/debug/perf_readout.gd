class_name PerfReadout
extends CanvasLayer
## Debug builds only: how hard the phone is working, in the corner of the screen, for measuring on real
## devices. Frames a second, the average and the worst frame of the last couple of seconds, draw calls,
## triangles, objects drawn, memory, and the graphics chip. Switched on and off in Settings (Testing); the
## choice is kept in user://settings.cfg. Costs nothing while off; while on, a few numbers twice a second.

const SECTION := "debug"
const KEY := "perf_readout"
const WINDOW := 120          # frames the average and the worst are taken over (about two seconds)
const REFRESH := 0.5         # seconds between updates of the text
const LAYER := 100           # above everything else
const FONT_SIZE := 22
const HITCH_MS := 25.0       # a frame this long (and well over the average) is a hitch, kept with what came before it
const HITCH_OVER := 1.8      # ..and at least this many times the average frame
const HITCHES_KEPT := 4      # the latest hitches listed under the numbers
const TOP_PARTS := 4        # the timed parts a hitch lists
const PART_SHOWN_US := 1000  # ..each when it took at least this long (µs)
const AFTER_MS := 1500       # a hitch this soon after an action names it

static var last_action := ""   # the latest thing the player did (Feedback.moment, a building opened), for hitches
static var last_action_at := 0
static var timing := false     # while the readout is on: the heavy parts of a frame time themselves (`start`/`stop`)
static var _spans := {}        # part -> microseconds it took since the last frame was looked at

static var _shown: PerfReadout

var _label: Label
var _times := PackedFloat32Array()
var _next := 0
var _since := 0.0
var _hitches: Array[String] = []


## The start of a timed part (0 while nothing is measuring: no cost).
static func start() -> int:
	return Time.get_ticks_usec() if timing else 0


## The end of timed part `part`, begun at `began`; a hitch lists the parts that took longest.
static func stop(part: String, began: int) -> void:
	if timing and began != 0:
		_spans[part] = int(_spans.get(part, 0)) + Time.get_ticks_usec() - began


## Notes what the player just did, so a hitch right after it says so (called by Feedback.moment and the HUD).
static func note(action: String) -> void:
	last_action = action
	last_action_at = Time.get_ticks_msec()


## Whether the readout is switched on (always off in a release build).
static func wanted() -> bool:
	if not OS.is_debug_build():
		return false
	return bool(PlayerSettings.value(SECTION, KEY, false))


## Switches it on or off, and keeps the choice.
static func set_wanted(on: bool) -> void:
	PlayerSettings.keep(SECTION, {KEY: on})


## Shows the readout over the whole game, or takes it away (one at a most).
static func show_in(tree: SceneTree, on: bool) -> void:
	if on and not is_instance_valid(_shown):
		_shown = PerfReadout.new()
		tree.root.add_child.call_deferred(_shown)
	elif not on and is_instance_valid(_shown):
		_shown.queue_free()
		_shown = null


func _ready() -> void:
	layer = LAYER
	_times.resize(WINDOW)
	var back := PanelContainer.new()
	back.position = Vector2(8, 8)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_content_margin_all(8)
	back.add_theme_stylebox_override("panel", style)
	add_child(back)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color.WHITE)
	back.add_child(_label)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	timing = true
	tree_exiting.connect(func() -> void: timing = false)


func _process(delta: float) -> void:
	_watch_hitch(delta)
	_times[_next % WINDOW] = delta
	_next += 1
	_since += delta
	if _since < REFRESH:
		return
	_since = 0.0
	_label.text = text_now()


## A frame far over the average: what it cost where (scripts, the renderer on the processor, the graphics chip)
## and what the player did just before, listed and written to the log (user://logs) for measuring on a PC.
func _watch_hitch(delta: float) -> void:
	var parts := _spans
	_spans = {}
	var n := mini(_next, WINDOW)
	if n < WINDOW / 2:
		return
	var total := 0.0
	for i in n:
		total += _times[i]
	var ms := delta * 1000.0
	if ms < HITCH_MS or ms < total / n * 1000.0 * HITCH_OVER:
		return
	var vp := get_viewport().get_viewport_rid()
	var since := Time.get_ticks_msec() - last_action_at
	var line := tr("PERF_HITCH") % [ms,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp),
		(tr("PERF_HITCH_AFTER") % [since, last_action]) if since < AFTER_MS else ""]
	line += _top_parts(parts)
	print(line)   # not-ui (a measurement for the log)
	_hitches.push_front(line)
	_hitches.resize(mini(_hitches.size(), HITCHES_KEPT))


## The parts that took longest since the frame before, longest first ("objects 3D sync 95.2").
static func _top_parts(parts: Dictionary) -> String:
	var names := parts.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return int(parts[a]) > int(parts[b]))
	var out := PackedStringArray()
	for part: String in names.slice(0, TOP_PARTS):
		if int(parts[part]) >= PART_SHOWN_US:
			out.append("%s %.1f" % [part, int(parts[part]) / 1000.0])
	return ("\n    " + " · ".join(out)) if not out.is_empty() else ""


## The readout's text for the frames measured so far.
func text_now() -> String:
	var n := mini(_next, WINDOW)
	var total := 0.0
	var worst := 0.0
	for i in n:
		total += _times[i]
		worst = maxf(worst, _times[i])
	var avg_ms := total / maxf(n, 1) * 1000.0
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
	return tr("PERF_READOUT") % [
		Engine.get_frames_per_second(), avg_ms, worst * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0),
		RenderingServer.get_video_adapter_name(), int(size.x), int(size.y)] \
		+ ("\n" + "\n".join(_hitches) if not _hitches.is_empty() else "")
