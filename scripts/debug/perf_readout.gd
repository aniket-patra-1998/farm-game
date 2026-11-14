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

static var _shown: PerfReadout

var _label: Label
var _times := PackedFloat32Array()
var _next := 0
var _since := 0.0


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


func _process(delta: float) -> void:
	_times[_next % WINDOW] = delta
	_next += 1
	_since += delta
	if _since < REFRESH:
		return
	_since = 0.0
	_label.text = text_now()


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
		RenderingServer.get_video_adapter_name(), int(size.x), int(size.y)]
