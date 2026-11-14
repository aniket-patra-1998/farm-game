class_name HudSettings
extends RefCounted
## Settings (sound, vibration) and the showcase farm card.
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

const NAME_MAX := 24     # letters in a farm's name (the plaque fits them)

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner


## The farm's name (on the plaque at the top); sound volume and mute, and vibration: the player's own, kept on the
## phone (not in the farm's save).
func build_settings(content: VBoxContainer) -> void:
	content.add_child(name_card())
	var inner := BookPanel.card()
	inner.add_theme_constant_override("separation", 12)
	inner.add_child(BookPanel.text(tr("SOUND_EFFECTS"), 26))
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = Sound.volume
	volume.custom_minimum_size = Vector2(320, 40)
	volume.focus_mode = Control.FOCUS_NONE
	volume.value_changed.connect(func(v: float) -> void: Sound.volume = v)
	volume.drag_ended.connect(func(_changed: bool) -> void: Feedback.moment("volume_check"))  # hear the new level
	inner.add_child(volume)
	var mute := CheckButton.new()
	mute.text = tr("MUTE_SOUND")
	mute.button_pressed = Sound.muted
	mute.focus_mode = Control.FOCUS_NONE
	mute.toggled.connect(func(on: bool) -> void:
		Sound.muted = on
		hud.side.show_sound())
	inner.add_child(mute)
	var buzz := CheckButton.new()
	buzz.text = tr("VIBRATION")
	buzz.button_pressed = Sound.vibration
	buzz.focus_mode = Control.FOCUS_NONE
	buzz.toggled.connect(func(on: bool) -> void:
		Sound.vibration = on
		Feedback.moment("vibration_check"))  # feel it come on
	inner.add_child(buzz)
	content.add_child(BookPanel.card_frame(inner))
	if OS.is_debug_build():
		content.add_child(showcase_card())
		content.add_child(debug_card())


## The farm's name, shown on the plaque (FarmVille's farm sign); empty brings back "My Farm".
func name_card() -> PanelContainer:
	var inner := BookPanel.card()
	inner.add_theme_constant_override("separation", 10)
	inner.add_child(BookPanel.text(tr("FARM_NAME"), 26))
	var field := LineEdit.new()
	field.text = Game.player.farm_name
	field.placeholder_text = tr("MY_FARM")
	field.max_length = NAME_MAX
	field.custom_minimum_size = Vector2(320, 48)
	field.text_submitted.connect(func(_t: String) -> void: field.release_focus())
	field.text_changed.connect(func(t: String) -> void:
		Game.player.farm_name = t.strip_edges()
		Game.queue_save()
		hud.top.show_name())
	inner.add_child(field)
	return BookPanel.card_frame(inner)


## Debug builds: quick changes for testing (moved here from the tool bar): coins, bees, materials, a level, an hour,
## a new farm (two taps).
func debug_card() -> PanelContainer:
	var inner := BookPanel.card()
	inner.add_theme_constant_override("separation", 10)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	inner.add_child(row)
	for entry: Array in [["DEBUG_COINS", func() -> void: Game.debug_add_coins(10000)],
			["DEBUG_BEES", func() -> void: Game.debug_add_bees(20)],
			["DEBUG_MATERIALS", func() -> void: Game.debug_add_materials(10)],
			["DEBUG_LEVEL_UP", Game.debug_level_up], ["DEBUG_SKIP_H", func() -> void: Game.debug_skip(3600)]]:
		var b := hud._panel_button(tr(str(entry[0])))
		b.pressed.connect(entry[1])
		row.add_child(b)
	var reset := hud._panel_button(tr("DEBUG_NEW_FARM"))
	reset.pressed.connect(func() -> void:
		if reset.text == tr("TAP_AGAIN_TO_RESET"):
			Game.reset_game()
			hud.show_message(tr("STARTED_A_NEW_FARM"))
			reset.text = tr("DEBUG_NEW_FARM")
		else:
			reset.text = tr("TAP_AGAIN_TO_RESET"))
	row.add_child(reset)
	return BookPanel.card_frame(inner)


## Debug builds only: switch to the farm with everything on it for testing, and back to your own; and show the
## performance numbers (PerfReadout).
func showcase_card() -> PanelContainer:
	var inner := BookPanel.card()
	inner.add_theme_constant_override("separation", 10)
	inner.add_child(BookPanel.text(tr("TESTING"), 26))
	inner.add_child(BookPanel.text(tr("SHOWCASE_HELP"), 18))
	var go := Button.new()
	go.text = tr("BACK_TO_MY_FARM") if Game.in_showcase() else tr("OPEN_SHOWCASE_FARM")
	go.custom_minimum_size = Vector2(320, 56)
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func() -> void:
		hud._book.close_panel()
		if Game.in_showcase():
			Game.open_own_farm()
		else:
			Game.open_showcase())
	inner.add_child(go)
	inner.add_child(BookPanel.text(tr("PERF_READOUT_HELP"), 18))
	var perf := CheckButton.new()
	perf.text = tr("PERF_READOUT_TOGGLE")
	perf.button_pressed = PerfReadout.wanted()
	perf.focus_mode = Control.FOCUS_NONE
	perf.toggled.connect(func(on: bool) -> void:
		PerfReadout.set_wanted(on)
		PerfReadout.show_in(hud.get_tree(), on))
	inner.add_child(perf)
	var trace := LoadTrace.previous()
	if trace != "":
		inner.add_child(BookPanel.text(tr("LOAD_TRACE_HELP"), 18))
		inner.add_child(BookPanel.text(trace, 14))
	return BookPanel.card_frame(inner)
