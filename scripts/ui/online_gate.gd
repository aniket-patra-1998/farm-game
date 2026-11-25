class_name OnlineGate
extends CanvasLayer
## The game plays only online (owner, 25 Nov; docs/PACKS.md, Online): on a phone, the packs' list is fetched
## while the farm opens (AssetPacks.reach), so an online player waits for nothing. Without an answer, this covers
## the game, paused, in the loading cover's look: "You're offline", and Retry, until the list comes. A
## connection lost later lets play go on (packs wait and are tried again). Off without a phone (tests, CI,
## desktop) or when data/packs.json says the game may play offline.

const LAYER := 110   # over the loading cover

var _word: Label
var _retry: Button


## Asks the source at the start, and covers the game under `parent` if it does not answer.
static func check(parent: Node) -> void:
	var packs := AssetPacks.shared
	if packs == null or not packs.online_only or not OS.has_feature("android"):   # not-ui
		return
	packs.reach(func(ok: bool) -> void:
		if not ok and is_instance_valid(parent):
			var gate := OnlineGate.new()
			parent.add_child(gate)
			gate._build())


func _build() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var back := ColorRect.new()
	back.color = UiTheme.color("loading_back")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(back)
	var col := VBoxContainer.new()
	UiKit.centered(col)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", UiTheme.size("loading_gap"))
	back.add_child(col)
	var title := Label.new()
	title.text = UiTheme.tidy(tr("OFFLINE_TITLE"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UiTheme.text_px("loading_title"))
	title.add_theme_color_override("font_color", UiTheme.color("icon_light"))
	col.add_child(title)
	_word = Label.new()
	_word.text = UiTheme.tidy(tr("OFFLINE_WHY"))
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_word.custom_minimum_size.x = UiTheme.size("loading_text_w")
	_word.add_theme_color_override("font_color", UiTheme.color("icon_light"))
	col.add_child(_word)
	_retry = UiKit.primary(Button.new())
	_retry.text = UiTheme.tidy(tr("OFFLINE_RETRY"))
	_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_retry.pressed.connect(_try)
	col.add_child(_retry)


func _try() -> void:
	_retry.disabled = true
	_word.text = UiTheme.tidy(tr("OFFLINE_TRYING"))
	AssetPacks.shared.reach(func(ok: bool) -> void:
		if ok:
			get_tree().paused = false
			queue_free()
		else:
			_retry.disabled = false
			_word.text = UiTheme.tidy(tr("OFFLINE_WHY")))
