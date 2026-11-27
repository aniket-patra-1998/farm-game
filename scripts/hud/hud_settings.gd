class_name HudSettings
extends RefCounted
## Settings (sound, vibration) and the showcase farm card.
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

const QUALITY_WORDS := {"low": "GRAPHICS_LOW", "mid": "GRAPHICS_MID", "high": "GRAPHICS_HIGH",
	"ultra": "GRAPHICS_ULTRA"}

const KIND_WORDS := {"a": "FARMER_BOY", "b": "FARMER_GIRL"}   # the look's body -> its words
const FARMER_STYLES := {"a": "short", "b": "long"}   # a look's body -> its picture's hair (PortraitIcon)
const FIELD_WIDE := 3.0   # a row's field or slider, in panel buttons' least widths
## What each graphics level does, in a word.
const QUALITY_EFFECTS := {"low": "GRAPHICS_LOW_EFFECT", "mid": "GRAPHICS_MID_EFFECT", "high": "GRAPHICS_HIGH_EFFECT",
	"ultra": "GRAPHICS_ULTRA_EFFECT"}
const ADMOB_LICENCE := "res://addons/admob/LICENSE"   # exported by the include_filter too   # not-ui
const BILLING_LICENCE := "res://addons/GodotGooglePlayBilling/LICENSE"   # exported by the include_filter   # not-ui
const FONT_LICENCE := "res://fonts/OFL.txt"   # exported by the presets' include_filter   # not-ui

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner


## Settings as a list (our own look, the way phones lay them out): a few sections, each a heading over rows of a
## name and its control (BookPanel.row: a switch, a few pills, a slider, a field); what a choice does is said on a
## long press of its name, not printed under it. Built from the kit, so a new setting is one more row.
func build_settings(content: VBoxContainer) -> void:
	content.add_child(farm_card())
	content.add_child(quality_card())
	content.add_child(sound_card())
	content.add_child(about_card())
	if OS.is_debug_build():
		content.add_child(showcase_card())
		content.add_child(debug_card())


## The farm: its name (on the plaque), the farmer (a boy or a girl) and, where seasons are on, where it is.
func farm_card() -> PanelContainer:
	var inner := BookPanel.card()
	inner.add_child(BookPanel.heading(tr("SETTINGS_FARM")))
	var field := LineEdit.new()
	field.text = Game.player.farm_name
	field.placeholder_text = tr("MY_FARM")
	field.max_length = PlayerSystem.NAME_MAX
	field.custom_minimum_size.x = UiTheme.size("panel_button_width") * FIELD_WIDE
	field.text_submitted.connect(func(_t: String) -> void: field.release_focus())
	field.text_changed.connect(func(t: String) -> void:
		Game.player.set_farm_name(t)
		hud.top.show_name())
	inner.add_child(BookPanel.row(tr("FARM_NAME"), field))
	var farmers: Array = []
	for kind: String in KIND_WORDS:   # (a boy with short hair, a girl with long: a picture each)
		var face := Game.player.look.duplicate()
		face["style"] = FARMER_STYLES[kind]
		farmers.append([kind, tr(KIND_WORDS[kind]), PortraitIcon.of(face, UiTheme.size("panel_button_height"))])
	inner.add_child(BookPanel.row(tr("YOUR_FARMER"), BookPanel.choice(farmers, str(Game.player.look["body"]),
		func(kind: String) -> void:
			Game.player.set_kind(kind)
			hud.book.refresh())))
	if Season.enabled():
		var places: Array = []
		for region: String in Season.regions():
			places.append([region, tr(str(Season.data()["regions"][region]["name"]))])
		inner.add_child(BookPanel.row(tr("SEASONS"), BookPanel.choice(places, Season.region(),
			func(region: String) -> void:
				Season.set_region(region)   # (the clock's line follows at its next tick; the lawn at the next start)
				hud.book.refresh()),
			tr("YOUR_SEASONS") % tr("SEASON_" + Game.season().to_upper())))
	return BookPanel.card_frame(inner)


## Graphics: the quality (what each does on a long press), daytime always, and full screen on a computer.
func quality_card() -> PanelContainer:
	var inner := BookPanel.card()
	inner.add_child(BookPanel.heading(tr("GRAPHICS")))
	var levels: Array = []
	var says := PackedStringArray()
	for name: String in Quality.offered():
		levels.append([name, tr(QUALITY_WORDS[name])])
		says.append("%s: %s" % [tr(QUALITY_WORDS[name]), tr(QUALITY_EFFECTS[name])])   # not-ui (a list)
	inner.add_child(BookPanel.row(tr("QUALITY"), BookPanel.choice(levels, Quality.level(),
		func(name: String) -> void: Quality.choose(name)), " · ".join(says)))
	var rates: Array = []   # (the frame rate apart from the level, as big mobile games offer it)
	for fps: Variant in Quality.fps_choices():
		rates.append([str(int(fps)), tr("FPS_AUTO") if int(fps) == 0 else UiTheme.number(int(fps))])
	inner.add_child(BookPanel.row(tr("FRAME_RATE"), BookPanel.choice(rates, str(Quality.fps_choice()),
		func(fps: String) -> void: Quality.choose_fps(int(fps))), tr("FRAME_RATE_SAYS")))
	inner.add_child(BookPanel.row(tr("ALWAYS_DAYTIME"), BookPanel.switch(DayCycle.always_day(), DayCycle.set_always_day)))
	inner.add_child(BookPanel.row(tr("NOTIFY_SETTING"), BookPanel.switch(PhoneNotices.wanted(), PhoneNotices.set_wanted)))
	if Display.has_window():
		inner.add_child(BookPanel.row(tr("FULL_SCREEN"), BookPanel.switch(Display.fullscreen(),
			func(on: bool) -> void: Display.set_fullscreen(on))))
	return BookPanel.card_frame(inner)


## Sound: its volume, mute, and vibration (the player's own, kept on the phone, not in the farm's save).
func sound_card() -> PanelContainer:
	var inner := BookPanel.card()
	inner.add_child(BookPanel.heading(tr("SOUND_EFFECTS")))
	var volume := _volume_slider(Sound.volume, func(v: float) -> void: Sound.volume = v)
	volume.drag_ended.connect(func(_changed: bool) -> void: Feedback.moment("volume_check"))  # hear the new level
	inner.add_child(BookPanel.row(tr("VOLUME"), volume))
	inner.add_child(BookPanel.row(tr("FARM_SOUNDS"),
		_volume_slider(Sound.ambience_volume, func(v: float) -> void: Sound.ambience_volume = v)))
	if Sound.soundscape != null and Sound.soundscape.has_music():
		inner.add_child(BookPanel.row(tr("MUSIC"),
			_volume_slider(Sound.music_volume, func(v: float) -> void: Sound.music_volume = v)))
	# (a switch says what is on, as phones do: Sound on plays, off is silence; never a "Mute" that is on)
	inner.add_child(BookPanel.row(tr("SOUND_ON"), BookPanel.switch(not Sound.muted,
		func(on: bool) -> void: Sound.muted = not on)))
	inner.add_child(BookPanel.row(tr("VIBRATION"), BookPanel.switch(Sound.vibration, func(on: bool) -> void:
		Sound.vibration = on
		Feedback.moment("vibration_check"))))  # feel it come on
	return BookPanel.card_frame(inner)


## A 0..1 volume slider, as wide as a settings field, that hands each new value to `on_change`.
func _volume_slider(value: float, on_change: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size.x = UiTheme.size("panel_button_width") * FIELD_WIDE
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(on_change)
	return slider


## Debug builds: quick changes for testing (moved here from the tool bar): coins, bees, materials, a level, an hour,
## a new farm (two taps).
func debug_card() -> PanelContainer:
	var inner := BookPanel.card()
	inner.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap")))
	row.add_theme_constant_override("v_separation", int(UiTheme.size("hud_gap")))
	inner.add_child(row)
	for entry: Array in [["DEBUG_COINS", func() -> void: Game.debug_add_coins(10000)],
			["DEBUG_BEES", func() -> void: Game.debug_add_bees(20)],
			["DEBUG_MATERIALS", func() -> void: Game.debug_add_materials(10)],
			["DEBUG_LEVEL_UP", Game.debug_level_up], ["DEBUG_SKIP_H", func() -> void: Game.debug_skip(3600)]]:
		var b := hud.panel_button(tr(str(entry[0])))
		b.pressed.connect(entry[1])
		row.add_child(b)
	var reset := hud.panel_button(tr("DEBUG_NEW_FARM"))
	reset.pressed.connect(func() -> void:
		if reset.text == tr("TAP_AGAIN_TO_RESET"):
			Game.reset_game()
			hud.show_message(tr("STARTED_A_NEW_FARM"))
			reset.text = tr("DEBUG_NEW_FARM")
		else:
			reset.text = tr("TAP_AGAIN_TO_RESET"))
	row.add_child(reset)
	return BookPanel.card_frame(inner)


## About: the notices the game's parts ask to be shown (Godot's licence and its third-party parts, the
## Poppins font's OFL). The sounds are CC0 or made here (art/sound/SOURCES.md): they ask for none.
func about_card() -> PanelContainer:
	var inner := BookPanel.card()
	inner.add_child(BookPanel.heading(tr("SETTINGS_ABOUT")))
	inner.add_child(BookPanel.row(tr("SHARE_STATS"), BookPanel.switch(
		bool(PlayerSettings.value(Analytics.SETTINGS[0], Analytics.SETTINGS[1], true)), func(on: bool) -> void:
			PlayerSettings.keep(Analytics.SETTINGS[0], {Analytics.SETTINGS[1]: on})
			if Analytics.shared != null:
				Analytics.shared.start())))   # (on: starts; off: stops sending at once)
	var open := hud.panel_button(tr("LICENCES"))
	open.pressed.connect(func() -> void: hud.book.open_panel(tr("LICENCES"), build_licences, BookPanel.Shape.LIST))
	inner.add_child(BookPanel.row(tr("LICENCES_ROW"), open))
	return BookPanel.card_frame(inner)


## The licences page: each part's name and its notice, as its licence asks.
func build_licences(content: VBoxContainer) -> void:
	for part: Array in licences():
		var inner := BookPanel.card()
		inner.add_child(BookPanel.heading(str(part[0])))
		var words := BookPanel.text(str(part[1]), UiTheme.CAPTION)
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(words)
		content.add_child(BookPanel.card_frame(inner))


## [name, notice] for every part whose licence asks to be shown: Godot (its own licence), each third-party
## component Godot lists (Engine.get_copyright_info) with its licence text, and the font.
static func licences() -> Array:
	var out: Array = [["Godot Engine", Engine.get_license_text()]]   # not-ui (a name)
	var texts := Engine.get_license_info()
	for component: Dictionary in Engine.get_copyright_info():
		var lines := PackedStringArray()
		for part: Dictionary in component["parts"]:
			for holder: String in part["copyright"]:
				lines.append("© " + holder)   # not-ui (a copyright line)
			lines.append(str(texts.get(part["license"], part["license"])))
		out.append([str(component["name"]), "\n".join(lines)])
	out.append(["Poppins", FileAccess.get_file_as_string(FONT_LICENCE)])   # not-ui (a name)
	out.append(["AdMob plugin (Poing Studios)", FileAccess.get_file_as_string(ADMOB_LICENCE)])   # not-ui (a name)
	out.append(["Google Play Billing plugin (Godot)", FileAccess.get_file_as_string(BILLING_LICENCE)])   # not-ui
	out.append(["In-app Review plugin (Cengiz)", "MIT License. Copyright (c) 2024-present Cengiz."])   # not-ui
	return out


## Debug builds only: switch to the farm with everything on it for testing, and back to your own; and show the
## performance numbers (PerfReadout).
func showcase_card() -> PanelContainer:
	var inner := BookPanel.card()
	inner.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
	inner.add_child(BookPanel.heading(tr("TESTING")))
	var go := hud.panel_button(tr("BACK_TO_MY_FARM") if Game.in_showcase() else tr("OPEN_SHOWCASE_FARM"))
	go.tooltip_text = tr("SHOWCASE_HELP")
	go.pressed.connect(func() -> void:
		hud.book.close_panel()
		if Game.in_showcase():
			Game.open_own_farm()
		else:
			Game.open_showcase())
	inner.add_child(go)
	if Game.in_showcase():
		# What stands at one size or level at a time is walked by hand (ShowcaseFarm): every building's looks, and
		# the Barn's by its VIP level.
		var walk := HFlowContainer.new()
		walk.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap")))
		walk.add_theme_constant_override("v_separation", int(UiTheme.size("hud_gap")))
		inner.add_child(walk)
		for entry: Array in [["SHOWCASE_SIZES_DOWN", ShowcaseFarm.step_sizes.bind(Game, -1)],
				["SHOWCASE_SIZES_UP", ShowcaseFarm.step_sizes.bind(Game, 1)],
				["SHOWCASE_VIP_DOWN", ShowcaseFarm.step_vip.bind(Game, -1)],
				["SHOWCASE_VIP_UP", ShowcaseFarm.step_vip.bind(Game, 1)],
				["SHOWCASE_VIP_TOGGLE", ShowcaseFarm.toggle_vip.bind(Game)]]:
			var step := hud.panel_button(tr(str(entry[0])))
			step.pressed.connect(entry[1])
			walk.add_child(step)
	inner.add_child(BookPanel.row(tr("PERF_READOUT_TOGGLE"), BookPanel.switch(PerfReadout.wanted(),
		func(on: bool) -> void:
			PerfReadout.set_wanted(on)
			PerfReadout.show_in(hud.get_tree(), on)), tr("PERF_READOUT_HELP")))
	var measure := hud.panel_button(tr("BENCHMARK_RUN"))
	measure.tooltip_text = tr("BENCHMARK_HELP")
	measure.pressed.connect(func() -> void:
		hud.book.close_panel()
		var bench := LoadBenchmark.start(hud.get_parent())
		bench.finished.connect(func(report: Dictionary) -> void:
			DisplayServer.clipboard_set(JSON.stringify(report))
			hud.show_message(tr("BENCHMARK_DONE") % LoadBenchmark.summary(report))))
	inner.add_child(measure)
	var trace := LoadTrace.previous()
	if trace != "":
		inner.add_child(BookPanel.text(tr("LOAD_TRACE_HELP"), UiTheme.CAPTION, BookPanel.SOFT))
		inner.add_child(BookPanel.text(trace, UiTheme.CAPTION, BookPanel.SOFT))
	return BookPanel.card_frame(inner)
