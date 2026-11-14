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
func test_37_tap_farms_and_drag_moves_the_view() -> void:
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

	# A drag moves the view and leaves the plot under the finger alone.
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
