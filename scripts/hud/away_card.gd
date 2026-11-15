class_name AwayCard
extends PanelContainer
## "While you were away", as a card under the top bar when the farm opens (our own touch: FarmVille said nothing):
## a row for each kind of thing that happened (crops ripened, crops withered, things ready, things hungry, a stray
## waiting), and a press on a row takes the view to the nearest such thing (FarmHud.go_to). It is the reason to
## come back, put where the eye lands. It goes by itself after a while, at its cross, or when a row is pressed.
## Made once and kept; it is not a modal: the farm under it works.

const ICONS := {"ripe": "basket", "withered": "hoe", "ready": "ready", "hungry": "barn", "stray": "star"}
const PAPER := Color("#fbf6ea")
const INK := Color("#4a3728")
const SOFT := Color("#8a7763")
const ROW := Color("#efe6d0")
const WIDTH := 480.0
const GO := "›"              # not-ui: a row's "go there" mark
const ROW_HEIGHT := 52.0
const SLIDE := 0.22          # seconds it takes to drop in, and to leave
const DROP := 26.0           # how far above its place it starts, in pixels
const GAP_BELOW_BAR := 14.0

var hud: FarmHud
var _rows: VBoxContainer
var _tween: Tween
var _left := 0.0             # seconds until it leaves by itself


func _init(owner: FarmHud) -> void:
	hud = owner
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.26)
	sb.shadow_size = 12
	add_theme_stylebox_override("panel", sb)
	anchor_left = 0.5
	anchor_right = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = FarmHud.top_h() + GAP_BELOW_BAR
	custom_minimum_size.x = WIDTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := Label.new()
	title.text = tr("AWAY_TITLE")
	title.add_theme_color_override("font_color", INK)
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var cross := UiKit.icon_button("cross", 40.0)
	cross.pressed.connect(close)
	head.add_child(cross)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	column.add_child(_rows)
	set_process(false)


## Shows the card for `rows` ([{kind, count}], AbsenceReport.items) with `notes` (plain lines) under them.
func open(rows: Array, notes: Array) -> void:
	for c in _rows.get_children():
		c.queue_free()
	for item: Dictionary in rows:
		_rows.add_child(_row(item))
	for text: String in notes:
		var note := Label.new()
		note.text = text
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = WIDTH
		note.add_theme_color_override("font_color", SOFT)
		note.add_theme_font_size_override("font_size", 18)
		_rows.add_child(note)
	_left = Balance.f("feel.away_card_seconds")
	visible = true
	modulate.a = 0.0
	var top := FarmHud.top_h() + GAP_BELOW_BAR
	offset_top = top - DROP
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, SLIDE)
	_tween.tween_property(self, "offset_top", top, SLIDE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_process(true)


func close() -> void:
	if not visible:
		return
	set_process(false)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, SLIDE)
	_tween.tween_callback(func() -> void: visible = false)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		close()


## One row: its picture, its words, and an arrow: a press goes to the nearest such thing.
func _row(item: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(WIDTH, ROW_HEIGHT)
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = ROW.darkened(0.08) if state.contains("pressed") else ROW
		sb.set_corner_radius_all(14)
		b.add_theme_stylebox_override(state, sb)
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 12
	line.offset_right = -12
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(line)
	var icon := UiIcon.make(str(ICONS.get(item["kind"], "star")), 30.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	var words := Label.new()
	words.text = AbsenceReport.words(item)
	words.add_theme_color_override("font_color", INK)
	words.add_theme_font_size_override("font_size", 20)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.clip_text = true   # (a long line in another language is cut, not pushed out of the row)
	words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(words)
	var go := Label.new()
	go.text = GO
	go.add_theme_color_override("font_color", SOFT)
	go.add_theme_font_size_override("font_size", 30)
	go.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(go)
	var kind := str(item["kind"])
	b.pressed.connect(func() -> void:
		Feedback.moment("tap")
		if hud.go_to.is_valid():
			hud.go_to.call(kind)
		close())
	UiFx.press_bounce(b)
	return b
