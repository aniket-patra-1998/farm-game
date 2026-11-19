class_name LoadingCover
extends CanvasLayer
## What the player sees while a farm is built and drawn (the game's first, and one opened in place: the showcase,
## back to your own): the farm's name on the game's green, a soft pulsing word and how much is built, over
## everything, until every thing stands (Objects3D.all_settled) and the frames that draw it have settled
## (`SETTLE_FRAMES` in a row that are quick or steady: `settled_frame`; or `MOST_SECONDS` at the latest), then it
## fades away. While it
## covers, the farm builds at full speed (Objects3D.COVERED_BUDGET_MS) and is not drawn until it stands (so the
## frames cost nothing but the cover); then, whole and in view, every material is drawn (its shaders made) under
## the cover: the farm appears whole, never thing by thing.
## Our own touch (FarmVille showed a loading bar). Off without a screen (tests, CI).

signal lifting   ## the farm is settled and the cover starts to fade (the opening glide starts here)

const SETTLE_FRAMES := 8      # frames in a row this quick..
const SETTLE_MS := 40.0       # ..mean the farm is ready to be seen
const STEADY_MOST_MS := 150.0 # a slow phone's frame this long or shorter, close to the one before, is its pace..
const STEADY_RATIO := 0.25    # ..when it is within this share of the frame before (a first draw's stall is not)
const MOST_SECONDS := 30.0    # never cover the farm longer than this
const FADE_SECONDS := 0.35
const PULSE_RATE := 3.0

static var covering := 0      # covers on the screen now (Objects3D builds at full speed while any is)

var _world: Node3D   # the 3D farm: not drawn while it is still being built under the cover (frames stay cheap)
var _quick := 0
var _last_ms := -1.0
var _shown := 0.0
var _word: Label
var _fading := false


## Covers the screen under `parent` until the farm has settled (nothing without a screen).
static func cover(parent: Node, farm_name: String, world: Node3D = null) -> LoadingCover:
	if DisplayServer.get_name() == "headless":
		return null
	var c := LoadingCover.new()
	c._world = world
	c.layer = 100
	covering += 1
	parent.add_child(c)
	c._build(farm_name)
	return c


func _build(farm_name: String) -> void:
	var back := ColorRect.new()
	back.color = UiTheme.color("loading_back")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP   # (no taps reach the farm under it)
	add_child(back)
	var col := VBoxContainer.new()
	UiKit.centered(col)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	back.add_child(col)
	col.add_child(UiIcon.make("barn", UiTheme.size("loading_icon")))
	(col.get_child(0) as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var name := Label.new()
	name.text = farm_name
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", UiTheme.text_px("loading_title"))
	name.add_theme_color_override("font_color", UiTheme.color("icon_light"))
	col.add_child(name)
	_word = Label.new()
	_word.text = tr("LOADING_FARM")
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word.add_theme_color_override("font_color", UiTheme.color("icon_light"))
	col.add_child(_word)


## Whether a frame of `ms` (after one of `last_ms`; negative: none) says the farm is drawn and settled: quick
## (under SETTLE_MS), or a slow phone's own steady pace (under STEADY_MOST_MS and within STEADY_RATIO of the frame
## before). A low-end phone that never draws under SETTLE_MS (the Galaxy A05s: ~70-95 ms a frame) was covered for
## MOST_SECONDS at every farm opening; a shader made the first time is a lone long frame, never steady.
static func settled_frame(ms: float, last_ms: float) -> bool:
	if ms < SETTLE_MS:
		return true
	return last_ms > 0.0 and ms <= STEADY_MOST_MS and absf(ms - last_ms) <= last_ms * STEADY_RATIO


func _process(delta: float) -> void:
	_shown += delta
	if _fading:
		return
	_word.modulate.a = 0.55 + 0.45 * sin(_shown * PULSE_RATE)
	var built := Objects3D.progress_in(get_tree())
	if _world != null:
		# Drawing a farm half built is work nobody sees: while it builds, frames draw only the cover, so each
		# gives its time to building. Built, it is drawn under the cover (its materials made) until frames settle.
		_world.visible = built >= 1.0
	_word.text = tr("LOADING_FARM_PERCENT") % UiTheme.number(roundi(built * 100.0)) if built < 1.0 else tr("LOADING_FARM")
	var ms := delta * 1000.0
	_quick = _quick + 1 if built >= 1.0 and settled_frame(ms, _last_ms) else 0
	_last_ms = ms
	if _quick >= SETTLE_FRAMES or _shown >= MOST_SECONDS:
		_fading = true
		covering = maxi(covering - 1, 0)
		if _world != null:
			_world.visible = true
		lifting.emit()
		var fade := create_tween()
		for child in get_children():
			fade.parallel().tween_property(child, "modulate:a", 0.0, FADE_SECONDS)
		fade.finished.connect(queue_free)
