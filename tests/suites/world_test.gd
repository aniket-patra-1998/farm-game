extends TestSuite
## The world around the farm: day and night, weather, and touch input on the real scene.

## The farm grid and the main scene (camera), in the order Godot delivers input to them.
var _input_targets: Array = []


func test_33_day_and_night_follow_the_clock() -> void:
	_eq(DayCycle.darkness(12.0), 0.0, "noon is full daylight")
	_eq(DayCycle.darkness(0.0), 1.0, "midnight is full night")
	_eq(DayCycle.darkness(23.0), 1.0, "11 pm is night")
	var dawn := DayCycle.darkness(DayCycle.SUNRISE)
	_check(dawn > 0.0 and dawn < 1.0, "sunrise is part-way (got %.2f)" % dawn)
	_eq(DayCycle.phase_name(12.0), "midday", "noon label")
	_eq(DayCycle.phase_name(2.0), "night", "2 am label")
	_eq(DayCycle.phase_name(6.0), "dawn", "6 am label")
	_check(DayCycle.sun_progress(12.0) > 0.0 and DayCycle.sun_progress(12.0) < 1.0, "sun is up at noon")
	_eq(DayCycle.sun_progress(23.0), -1.0, "sun is down at night")
	_check(DayCycle.moon_progress(23.0) >= 0.0, "moon is up at night")
	_eq(DayCycle.moon_progress(12.0), -1.0, "moon is down at noon")






func test_34_day_colours_change_smoothly_and_wrap_at_midnight() -> void:
	var before := DayCycle.sample(23.99)
	var after := DayCycle.sample(0.0)
	_check((before["top"] as Color).is_equal_approx(after["top"]), "sky matches across midnight")
	# No jumps: a minute apart the light changes by only a little, all day long.
	var worst := 0.0
	for m in range(0, 24 * 60, 5):
		var a: Color = DayCycle.sample(m / 60.0)["light"]
		var b: Color = DayCycle.sample((m + 1) / 60.0)["light"]
		worst = maxf(worst, absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b))
	_check(worst < 0.05, "light never jumps between minutes (worst %.3f)" % worst)
	var noon: Color = DayCycle.sample(12.0)["light"]
	var night: Color = DayCycle.sample(1.0)["light"]
	_check(noon.get_luminance() > night.get_luminance() + 0.2, "noon is clearly brighter than night")






func test_35_local_time_and_clock_text() -> void:
	_eq(DayCycle.local_hour(0, 0), 0.0, "unix 0 is midnight UTC")
	_eq(DayCycle.local_hour(0, 330), 5.5, "India is 5 h 30 m ahead")
	_eq(DayCycle.local_hour(3600, -300), 20.0, "behind UTC wraps to the previous evening")
	_eq(DayCycle.clock_text(19.7), "7:42 pm", "evening clock")
	_eq(DayCycle.clock_text(0.25), "12:15 am", "just after midnight")
	_eq(DayCycle.clock_text(12.0), "12:00 pm", "noon")






func test_36_the_whole_game_scene_loads() -> void:
	# Catches broken scripts anywhere in the game, not just the rules.
	var packed := MAIN_SCENE
	_check(packed != null, "main scene loads")
	if packed == null:
		return
	var main := packed.instantiate()
	_check(main != null, "main scene instantiates")
	if main == null:
		return
	add_child(main)
	_check(main.get("grid") != null, "farm grid created")
	_check(main.get("hud") != null, "HUD created")
	_check(main.get("sky") != null, "sky created")
	await get_tree().process_frame  # let the layout's queued (deferred) work run before the scene goes
	main.free() # free now, so the next test doesn't share the screen with this one







## Hands a touch straight to the farm and camera handlers. (Faking touches through the
## OS layer on a screenless test machine adds emulated mouse moves a phone never sends.)
func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos
	ev.pressed = pressed
	for t in _input_targets:
		t._unhandled_input(ev)
	await get_tree().process_frame






func _drag(pos: Vector2, relative: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = pos
	ev.relative = relative
	for t in _input_targets:
		t._unhandled_input(ev)
	await get_tree().process_frame






func _screen_pos(grid: FarmGrid, i: int) -> Vector2:
	return get_viewport().get_canvas_transform() * grid.to_global(grid.center_of(i))






## Needs real frames for input to arrive: the runner awaits it.
func test_37_tap_farms_swipe_farms_and_hand_drag_moves_the_view() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam: Camera2D = main.get("camera")
	var grid: FarmGrid = main.get("grid")
	_input_targets = [grid, main] # children get input before their parent
	cam.force_update_scroll()
	var view := get_viewport().get_visible_rect().size

	# A tap on grass plows it.
	var i := Game.index_of(11, 11)
	_eq(Game.field.phase(i), GameState.Phase.GRASS, "tile starts as grass")
	var tap_at := _screen_pos(grid, i)
	_check(grid._on_farm_area(tap_at), "the tile is on screen (view %s, tile at %s)" % [str(view), str(tap_at)])
	await _touch(tap_at, true)
	await _touch(tap_at, false)
	Game.player.advance(60.0)  # the farmer walks over and does it
	_eq(Game.field.phase(i), GameState.Phase.PLOWED, "a tap plows")

	# With the Hand tool, a drag moves the view and leaves the plot under the finger alone.
	grid.tool = "hand"
	main.call("_zoom_at", view / 2.0, 2.0)
	await get_tree().process_frame
	cam.force_update_scroll()
	var start := view / 2.0
	var under := grid.index_at(grid.to_local(get_viewport().get_canvas_transform().affine_inverse() * start))
	var before_plot: Dictionary = Game.plots[under].duplicate() if under >= 0 else {}
	var objects_before := Game.objects.size()
	var cam_before := cam.position
	await _touch(start, true)
	for k in range(1, 11):
		await _drag(start + Vector2(20 * k, 0), Vector2(20, 0))
	await _touch(start + Vector2(200, 0), false)
	if under >= 0:
		_eq(Game.plots[under], before_plot, "the plot under the drag is unchanged")
	_eq(Game.objects.size(), objects_before, "nothing placed or removed by a drag")
	_check(not cam.position.is_equal_approx(cam_before), "the drag moved the view")

	# A tiny wobble while tapping still counts as a tap.
	grid.tool = "plow"
	var k2 := Game.index_of(11, 10)
	cam.position = cam_before
	main.call("_fit_camera")
	await get_tree().process_frame
	cam.force_update_scroll()
	var wobble_at := _screen_pos(grid, k2)
	await _touch(wobble_at, true)
	await _drag(wobble_at + Vector2(4, 3), Vector2(4, 3))
	await _touch(wobble_at + Vector2(4, 3), false)
	Game.player.advance(60.0)  # the farmer walks over and does it
	_eq(Game.field.phase(k2), GameState.Phase.PLOWED, "a slightly shaky tap still plows")

	# Swipe to farm: with the plow, a drag across a row of grass plows every plot it crosses, once each, and
	# the view stays put; the finger's first plot lit the moment it landed.
	var row: Array[int] = []
	for r in Game.farm_size:
		for c in Game.farm_size - 4:
			if not row.is_empty():
				break
			var run: Array[int] = []
			for k in 4:
				var p := Game.index_of(r, c + k)
				if Game.field.phase(p) == GameState.Phase.GRASS and grid._on_farm_area(_screen_pos(grid, p)) \
						and grid.swipe_start(_screen_pos(grid, p), "plow") == p:   # (open, nothing drawn over it)
					run.append(p)
			if run.size() == 4:
				row = run
	_eq(row.size(), 4, "(a row of four grass plots to swipe across)")
	var cam_still := cam.position
	var from := _screen_pos(grid, row[0])
	var to := _screen_pos(grid, row[3])
	await _touch(from, true)
	_eq(grid.touched_plot(), row[0], "the plot under the finger lights as it lands")
	await _drag(to, to - from)   # one fast flick, straight across all four: none of them is skipped
	_check(grid.is_swiping() and not grid.is_dragging(), "a swipe farms, it doesn't move the view")
	await _touch(to, false)
	_check(cam.position.is_equal_approx(cam_still), "the view stayed put")
	for p in row:
		_check(Game.player.queued_plots().has(p), "plot %d queued by one flick across it" % p)
	# Swiping the same row again before the farmer gets there takes nothing back: a swipe only adds.
	await _touch(from, true)
	await _drag(to, to - from)
	await _touch(to, false)
	for p in row:
		_check(Game.player.queued_plots().has(p), "plot %d still queued after a second swipe" % p)
	Game.player.advance(240.0)
	for p in row:
		_eq(Game.field.phase(p), GameState.Phase.PLOWED, "plot %d plowed by the swipe" % p)
	# A drag from a plot the tool can't work (the plow on plowed ground) pans, as any drag would.
	await _touch(from, true)
	_check(grid.touched_plot() == row[0] and not grid.is_swiping(), "(lit, but nothing to plow there)")
	await _drag(to, to - from)
	_check(grid.is_dragging(), "so the drag moves the view")
	await _touch(to, false)
	cam.snap(cam_still, cam.zoom.x)   # (back where it was, and no glide)
	await get_tree().process_frame
	cam.force_update_scroll()
	from = _screen_pos(grid, row[0])
	to = _screen_pos(grid, row[3])
	# Out of coins half way: said once, not once a plot, and the swipe works no more plots.
	grid.tool = "plant"
	grid.selected_crop = Game.crops.keys()[0]
	var seed_cost := int(Game.crops[grid.selected_crop]["seed_cost"])
	Game.coins = seed_cost * 2
	var said := [0]
	var count_it := func(_t: String) -> void: said[0] += 1
	grid.info.connect(count_it)
	await _touch(from, true)
	await _drag(to, to - from)
	await _touch(to, false)
	grid.info.disconnect(count_it)
	_eq(Game.player.queued_plots().size(), 2, "two plots' seeds paid for, two planted")
	_eq(said[0], 1, "and running out is said once")
	Game.player.advance(240.0)
	# A second finger ends a swipe (a pinch), and with swiping switched off every drag pans.
	Game.coins = 100000
	grid.tool = "fertilize"
	await _touch(from, true)
	_check(grid.is_swiping(), "a fertilizer swipe starts on growing crops")
	grid.cancel_paint()
	_check(not grid.is_swiping(), "a second finger ends it")
	await _touch(from, false)
	Balance.override("input.swipe_farm", 0)
	await _touch(from, true)
	_check(not grid.is_swiping(), "swipe to farm switched off: no swipe")
	await _touch(from, false)
	Balance.reload()
	grid.tool = "plow"
	await get_tree().process_frame  # queued effects of the taps run while their scene still stands
	main.free()








func test_83_weather_is_steady_seasonal_and_eases_in() -> void:
	var t0 := 1_800_000_000 - 1_800_000_000 % Weather.block()
	_eq(
		Weather.state_at(t0 + 100, "Summer", 12.0),
		Weather.state_at(t0 + 9000, "Summer", 14.5),
		"one weather per 3-hour block"
	)
	_eq(
		Weather.state_at(t0 + 100, "Summer", 12.0),
		Weather.state_at(t0 + 100, "Summer", 12.0),
		"the same every time you look"
	)
	var count := {}
	for b in 2000:
		var t := t0 + b * Weather.block()
		var hour := fposmod(12.0 + b * 3.0, 24.0)
		var s := Weather.state_at(t, "Summer", hour)
		count[s] = int(count.get(s, 0)) + 1
		_check(Weather.STATES.has(s), "%s is a known state" % s)
		if s == "fog":
			_check(hour >= 3.0 and hour < 9.0, "fog only in the early morning (got it at %.0f:00)" % hour)
	_check(not count.has("snow"), "no snow in summer")
	_check(int(count.get("clear", 0)) > int(count.get("rain", 0)) * 3, "summer is mostly sunny (%s)" % str(count))
	_check(count.has("rain") and count.has("storm"), "but it rains sometimes")
	var winter_snow := 0
	for b in 500:
		if Weather.state_at(t0 + b * Weather.block(), "Winter", 12.0) == "snow":
			winter_snow += 1
	_check(winter_snow > 50, "winter brings snow (%d of 500)" % winter_snow)
	_eq(Weather.strength_at(t0), 0.0, "weather starts faded out at a block's edge")
	_eq(Weather.strength_at(t0 + Weather.block() / 2), 1.0, "and is full strength mid-block")
	var storm := Weather.current(t0, "Summer", 12.0, "storm")
	_eq(storm["state"], "storm", "an override forces the weather")
	_eq(float(storm["rain"]), 1.0, "a storm rains hard")
	_check(float(storm["lightning"]) > 0.0 and float(storm["dim"]) > 0.3, "with lightning, and dark")
	var g := _farm()
	g.weather_override = "fog"
	_eq(tr(g.weather()["name"]), "Fog", "the game reports its weather, by a key in the strings file")
	_done(g)


func test_113_finding_an_object_by_uid_stays_right_however_the_list_changes() -> void:
	# object_by_uid is an index now (it was a scan of every object, many times a frame); systems add, remove
	# and replace objects directly, so it must notice every kind of change by itself.
	var g := _farm()
	g.farm_size = GameState.MAX_SIZE
	var uids: Array[int] = []
	for o in g.objects:
		uids.append(int(o["uid"]))
	for uid in uids:
		_eq(int(g.object_by_uid(uid).get("uid", -1)), uid, "uid %d found" % uid)
	var gone: Dictionary = g.objects[0]
	g.objects.erase(gone)
	_check(g.object_by_uid(int(gone["uid"])).is_empty(), "a removed object is no longer found")
	for o in g.objects:
		_eq(int(g.object_by_uid(int(o["uid"])).get("uid", -1)), int(o["uid"]), "the rest still are, shifted along")
	g.objects = g.objects.slice(1)
	_eq(int(g.object_by_uid(int(g.objects[0]["uid"])).get("uid", -1)), int(g.objects[0]["uid"]),
		"after the list is replaced too")
	g.objects.append({"uid": 99999, "id": "hay_bale", "row": 25, "col": 25, "t": 0})
	_eq(str(g.object_by_uid(99999).get("id", "")), "hay_bale", "and an object added directly is found")
	_check(g.object_by_uid(-1).is_empty(), "nothing has uid -1")
	_done(g)


## The overlay draws what is being placed (its ghost footprint, the homes that take it): a guard against the call
## being lost when the overlay's other layers change, as it once was.
func test_322_the_overlay_draws_what_is_being_placed() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/farm_grid.gd")
	var start := src.find("func draw_overlay_on(")
	var end := src.find("\nfunc ", start + 10)
	_check(start >= 0 and src.substr(start, end - start).contains("_draw_placing(ci)"),
		"draw_overlay_on draws the placing ghost")


## The closest zoom shows about the same few tiles across on any farm (it used to be a multiple of the whole-farm
## view, so it got weaker as the farm grew), and you can pull back a little past the whole farm.
func test_323_the_closest_zoom_is_the_same_on_any_farm_and_you_can_pull_back() -> void:
	var width := 1280.0
	for tiles: int in [12, 20, 30]:
		var base := width / (tiles * FarmGrid.TILE_W * 1.04)   # the whole farm fits across
		var limits := FarmMain.zoom_limits(width, base)
		var across := width / (limits.y * FarmGrid.TILE_W)
		_check(across <= FarmMain.CLOSEST_TILES + 0.01, "a %d-tile farm: the closest zoom shows %.1f tiles" % [tiles, across])
		_check(limits.x < base, "a %d-tile farm: you can pull back past the whole farm" % tiles)
		_check(limits.y >= base * FarmMain.MIN_CLOSE_FACTOR, "and the closest is always closer than the whole farm")


## The player's settings live in one file, read and written only through PlayerSettings: a section's keys are
## kept without touching another's, and the full-screen choice (Display) is kept there too.
func test_325_player_settings_keep_each_owners_keys_and_the_window_choice() -> void:
	var was_full := Display.fullscreen()
	var was_volume: Variant = PlayerSettings.value("sound", "volume", 1.0)
	PlayerSettings.keep("test_section", {"a": 3})
	_eq(int(PlayerSettings.value("test_section", "a", 0)), 3, "a value is kept")
	_eq(PlayerSettings.value("sound", "volume", 1.0), was_volume, "and another section's is untouched")
	_eq(PlayerSettings.value("test_section", "missing", "none"), "none", "a missing key gives the default")
	Display.set_fullscreen(true)
	_check(Display.fullscreen(), "full screen is kept")
	_eq(Display.mode(), DisplayServer.WINDOW_MODE_FULLSCREEN, "and asks for a full-screen window")
	Display.set_fullscreen(false)
	_eq(Display.mode(), DisplayServer.WINDOW_MODE_MAXIMIZED, "otherwise a maximised one")
	_check(not Display.has_window(), "(no window to size in a headless run)")
	Display.set_fullscreen(was_full)
	PlayerSettings.keep("test_section", {"a": null})


## The first launch picks a level from what a frame costs; the player's own choice always wins over it.
func test_327_the_first_launch_measures_the_level_and_the_players_choice_wins() -> void:
	var was_chosen: Variant = PlayerSettings.value(Quality.SECTION, Quality.KEY, null)
	var was_auto: Variant = PlayerSettings.value(Quality.SECTION, Quality.AUTO_KEY, null)
	var rules := Quality.auto_rules()
	_check(not rules.is_empty(), "the rules are all in data/quality.json")
	var slow := float(rules["down_ms"]) + 5.0
	var fast := float(rules["up_ms"]) - 2.0
	var easy := (float(rules["down_ms"]) + float(rules["up_ms"])) / 2.0
	var auto := AutoQuality.new()
	_eq(auto.verdict("mid", slow, true), "low", "a device that can't keep up steps down")
	_eq(auto.verdict("mid", fast, true), "high", "one with plenty to spare steps up")
	_eq(auto.verdict("mid", fast, false), "mid", "but not where stepping up isn't allowed")
	_eq(auto.verdict("mid", easy, true), "mid", "and one in between stays")
	_eq(auto.verdict("low", slow, true), "low", "never past the ends")
	_eq(AutoQuality.median(PackedFloat32Array([30.0, 5.0, 80.0, 10.0, 12.0])), 12.0, "the median frame, not one hitch")
	PlayerSettings.keep(Quality.SECTION, {Quality.KEY: null, Quality.AUTO_KEY: null})
	Quality._level = ""
	_check(AutoQuality.should_measure(), "a new device is measured")
	# The flow: nothing in the warmup, a resume's huge frame isn't counted, then `frames` frames decide.
	var frame := 1.0 / 60.0
	var verdict := ""
	var n := 0
	auto.restart()
	_eq(auto.add_sample(float(rules["warmup"]) + 1.0, slow, true), "", "a long frame (a resume) decides nothing")
	while verdict == "" and n < 100000:
		verdict = auto.add_sample(frame, slow, true)
		n += 1
	_eq(n, int(float(rules["warmup"]) / frame) + int(rules["frames"]), "the warmup, then exactly the frames counted")
	_eq(verdict, Quality.step(Quality.level(), -1), "a slow device steps down")
	auto.mobile = true
	auto.restart()
	verdict = ""
	while verdict == "":
		verdict = auto.add_sample(frame, fast, true)
	_eq(verdict, Quality.level(), "a phone never steps up from its first, lightest farm")
	auto.free()
	var before := Quality.level()
	Quality.keep_measured("low")
	_check(Quality.measured() and not AutoQuality.should_measure(), "measured once, kept")
	_eq(Quality.level(), before, "and nothing changes until the next launch")
	Quality._level = ""
	_eq(Quality.level(), "low", "which uses it")
	Quality.choose("high")
	_eq(Engine.max_fps, int(Quality.value("max_fps")), "choosing a level sets the frame cap itself")
	Quality.keep_measured("low")
	Quality._level = ""
	_eq(Quality.level(), "high", "a level the player chose wins")
	_check(not AutoQuality.should_measure(), "and then nothing is measured")
	PlayerSettings.keep(Quality.SECTION, {Quality.KEY: was_chosen, Quality.AUTO_KEY: was_auto})
	Quality._level = ""
	Quality.apply_frame_cap()
	Quality.notifier.emitted.emit()
