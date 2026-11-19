extends TestSuite
## The weather's moments (docs/WEATHER.md, data/weather.json): lightning only in a storm and as often as the
## data says, thunder for every strike, a bolt and a flash in 3D, fog that begins past the farm, and the rain's
## sound only while it rains.


func test_389_lightning_strikes_only_in_a_storm_as_often_as_the_data_says() -> void:
	var events := WeatherEvents.new()
	add_child(events)
	var strikes := [0]
	events.struck.connect(func(_far: float, _toward: float) -> void: strikes[0] += 1)
	events.look = {"rain": 0.7, "lightning": 0.0}
	for k in 600:   # (a minute of rain, in tenths of a second)
		events._process(0.1)
	_eq(strikes[0], 0, "no lightning in plain rain")
	events.look = {"rain": 1.0, "lightning": 1.0}
	for k in 6000:   # (ten minutes of a full storm)
		events._process(0.1)
	var rate: Array = WeatherEvents.rule("storm", "strikes_per_minute")
	_check(strikes[0] >= int(float(rate[0]) * 10 * 0.6) and strikes[0] <= int(float(rate[1]) * 10 * 1.4),
		"a storm strikes about as often as the data says (%d in ten minutes)" % strikes[0])
	for name in ["thunder_near", "thunder_mid", "thunder_far"]:
		_check(Feedback.has_moment(name), "%s is a moment" % name)
	_check(Feedback.has_hum("rain"), "rain has its sound")
	events.look = {}
	events._process(0.1)
	events.queue_free()


func test_390_a_strike_draws_a_bolt_past_the_farm_and_the_fog_begins_past_it() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var world: Farm3D = main.get("world_3d")
	_check(world != null, "the 3D world is up")
	if world == null:
		main.queue_free()
		return
	world.lightning.strike(0.1, PI, world.camera, Game.farm_size, WeatherEvents.data("storm"))
	var bolt: MeshInstance3D = world.lightning.get_child(0)
	_check(bolt.mesh != null and bolt.visible, "a strike draws a bolt")
	var n := float(Game.farm_size)
	var middle := Vector3(n / 2.0, 0.0, n / 2.0)
	var foot := Vector2(world.lightning.foot.x, world.lightning.foot.z)   # (where it meets the ground, not its branches)
	var on_farm := foot.x > 0.0 and foot.x < n and foot.y > 0.0 and foot.y < n
	_check(not on_farm, "it falls past the farm's edge, never on it (%s)" % foot)
	_check(world.lightning.flash > 0.0, "and the frame flashes")
	var w := Weather.current(Game.now(), "summer", 12.0, "fog")
	world.set_daylight(12.0, w)
	world._fit_fog()   # (at once: the next frame's own weather would set the day's sky again)
	var env := world.environment
	_check(env.fog_enabled and env.fog_mode == Environment.FOG_MODE_DEPTH, "fog is depth fog")
	var ahead := -world.camera.global_transform.basis.z
	var far_corner := (middle - world.camera.global_position).dot(ahead) + n * 0.7071
	_check(env.fog_depth_begin >= far_corner - 0.5, "it begins past the farm's far corner: the farm stays clear")
	main.queue_free()
	await get_tree().process_frame


func test_591_a_soft_rainbow_shows_after_rain_while_the_farm_is_wet_and_the_sun_out() -> void:
	var r := WeatherEvents.data("rainbow")
	var clear: Dictionary = Weather.LOOKS["clear"]
	var cover := float(clear["cover"])
	_check(WeatherLayer.rainbow_strength(1.0, 0.0, cover, 0.0, r) == 1.0, "just after rain, sun out: a full rainbow")
	_check(WeatherLayer.rainbow_strength(0.0, 0.0, cover, 0.0, r) == 0.0, "a dry farm: none")
	_check(WeatherLayer.rainbow_strength(1.0, float(Weather.LOOKS["rain"]["rain"]), cover, 0.0, r) == 0.0,
		"while it still rains: none")
	_check(WeatherLayer.rainbow_strength(1.0, 0.0, float(Weather.LOOKS["cloudy"]["cover"]), 0.0, r) == 0.0,
		"under a cloudy sky: none")
	_check(WeatherLayer.rainbow_strength(1.0, 0.0, cover, 1.0, r) == 0.0, "at night: none")
	var half := WeatherLayer.rainbow_strength(float(r["full_wet"]) * 0.5, 0.0, cover, 0.0, r)
	_check(half > 0.0 and half < 1.0, "it fades as the farm dries (%.2f)" % half)
	_check(float(r["strength"]) <= 0.3 and float(r["saturation"]) <= 0.8, "light and gentle, as the owner asked")
	_check(not bool(Quality.value("rainbow", "low")) and bool(Quality.value("rainbow", "mid")), "off on low")
	# The layer: hidden (no cost) on a dry farm; shown after rain; it dries and goes.
	var layer := WeatherLayer.new()
	add_child(layer)
	layer.look = clear.duplicate()
	layer._process(0.1)
	_check(not layer._rainbow.visible, "a dry farm draws nothing")
	layer.look = Weather.LOOKS["rain"].duplicate()
	for k in 40:
		layer._process(1.0)
	_check(layer.wet > 0.9 and not layer._rainbow.visible, "it soaks while it rains, no rainbow yet")
	layer.look = clear.duplicate()
	for k in 10:
		layer._process(1.0)
	_check(layer._rainbow.visible == bool(Quality.value("rainbow")), "the rain stops: the rainbow comes")
	for k in 400:
		layer._process(1.0)
	_check(not layer._rainbow.visible, "the farm dries: it is gone")
	layer.queue_free()
