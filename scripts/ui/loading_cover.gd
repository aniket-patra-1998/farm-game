class_name LoadingCover
extends CanvasLayer
## What the player sees while a farm is built and drawn (the game's first, and one opened in place: the showcase,
## back to your own): the farm's name on the game's green, a soft pulsing word and how much is built, over
## everything, until every thing stands (Objects3D.all_settled) and the frames that draw it have settled
## (`SETTLE_FRAMES` in a row under `SETTLE_MS`, or `MOST_SECONDS` at the latest), then it fades away. While it
## covers, the farm builds at full speed (Objects3D.COVERED_BUDGET_MS), and the whole farm is in view, so every
## material is drawn (its shaders made) under the cover: the farm appears whole, never thing by thing.
## Our own touch (FarmVille showed a loading bar). Off without a screen (tests, CI).

const SETTLE_FRAMES := 8      # frames in a row this quick..
const SETTLE_MS := 40.0       # ..mean the farm is ready to be seen
const MOST_SECONDS := 30.0    # never cover the farm longer than this
const FADE_SECONDS := 0.35
const PULSE_RATE := 3.0

static var covering := 0      # covers on the screen now (Objects3D builds at full speed while any is)

var _quick := 0
var _shown := 0.0
var _word: Label
var _fading := false


## Covers the screen under `parent` until the farm has settled (nothing without a screen).
static func cover(parent: Node, farm_name: String) -> LoadingCover:
	if DisplayServer.get_name() == "headless":
		return null
	var c := LoadingCover.new()
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


func _process(delta: float) -> void:
	_shown += delta
	if _fading:
		return
	_word.modulate.a = 0.55 + 0.45 * sin(_shown * PULSE_RATE)
	var built := Objects3D.progress_in(get_tree())
	_word.text = tr("LOADING_FARM_PERCENT") % UiTheme.number(roundi(built * 100.0)) if built < 1.0 else tr("LOADING_FARM")
	_quick = _quick + 1 if delta * 1000.0 < SETTLE_MS and built >= 1.0 else 0
	if _quick >= SETTLE_FRAMES or _shown >= MOST_SECONDS:
		_fading = true
		covering = maxi(covering - 1, 0)
		var fade := create_tween()
		for child in get_children():
			fade.parallel().tween_property(child, "modulate:a", 0.0, FADE_SECONDS)
		fade.finished.connect(queue_free)
