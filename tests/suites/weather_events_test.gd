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
	var aabb := bolt.mesh.get_aabb()
	var n := float(Game.farm_size)
	var middle := Vector3(n / 2.0, 0.0, n / 2.0)
	var foot := Vector2(aabb.position.x + aabb.size.x / 2.0, aabb.position.z + aabb.size.z / 2.0)
	_check(foot.distance_to(Vector2(middle.x, middle.z)) > n * 0.7, "it falls past the farm's edge, never on it")
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
