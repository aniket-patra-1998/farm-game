extends TestSuite
## Water (our own touch): where a thing's water is, what lives at a pond, birds that swim and dabble, the rings
## on it, the weather on it, and animals that drink.


## The 3D farm with `things` standing on it, settled.
func _world(things: Array) -> Objects3D:
	Game.saving_enabled = false
	Game.reset_game()
	ShaderGlobals.reset()
	Game.farm_size = 24
	Game.set_objects([])
	for o: Dictionary in things:
		Game.add_object(o)
	var objects := Objects3D.new()
	add_child(objects)
	await Objects3D.until_settled(get_tree(), 600)
	objects.sync()
	return objects


func test_417_a_pond_is_found_and_comes_to_life_and_a_tap_on_water_splashes() -> void:
	var pond := {"uid": 9601, "id": "small_pond", "row": 2, "col": 2, "t": Game.now()}
	var basin := {"uid": 9602, "id": "fountain", "row": 2, "col": 8, "t": Game.now()}
	var bench := {"uid": 9603, "id": "bench", "row": 8, "col": 2, "t": Game.now()}
	var objects: Objects3D = await _world([pond, basin, bench])
	var found: Dictionary = objects._views[9601]["water"]
	_check(bool(found.get("pond", false)), "the small pond's water is found, and it is a pond")
	_check((found["reach"] as Vector2).x > 0.5 and absf((found["at"] as Vector3).x) < 0.2,
		"in the middle of its plot, most of its width")
	_check(not bool(objects._views[9602]["water"].get("pond", true)), "the fountain's is a basin, not a pond")
	_check((objects._views[9603]["water"] as Dictionary).is_empty(), "a bench has no water")
	var lives := func(uid: int) -> int:
		return (objects._views[uid]["node"] as Node3D).find_children("*", "PondLife", true, false).size()
	_eq([lives.call(9601), lives.call(9602), lives.call(9603)], [1, 0, 0], "only the pond has a pond's life")
	# A tap on water splashes: rings on it. Not beside water, and not on ice.
	var rings := objects.rings_node()
	objects.splash(9603, Vector3(2.5, 0, 8.5))
	_eq(rings.live(), 0, "a tap on a bench splashes nothing")
	objects.splash(9601, Vector3(3.0, 0, 3.0))
	_eq(rings.live(), WaterRings.SPLASH.size(), "a tap on the pond: a splash's rings")
	rings.advance(WaterRings.SPLASH_LIFE + 0.5)
	_check(rings.live() == 0 and not rings.is_processing(), "they spread and are gone, and the layer sleeps")
	ShaderGlobals.set_value(&"snow_cover", 1.0)
	objects.splash(9601, Vector3(3.0, 0, 3.0))
	_eq(rings.live(), 0, "frozen over: no splash")
	ShaderGlobals.reset()
	objects.queue_free()


func test_418_birds_on_a_pond_swim_low_and_dabble_and_stand_on_its_ice() -> void:
	var home := {"uid": 9611, "id": "duck_pond", "row": 2, "col": 2, "t": Game.now(), "level": 1, "inside": {"duck": 6}}
	var objects: Objects3D = await _world([home])
	var fill := objects.fill_of(9611)
	_check(not fill._water.is_empty(), "the Duck Pond's yard knows its pond")
	fill._swim(0.1)
	var swimmers := fill.residents.filter(func(a: Animal3D) -> bool: return a.afloat)
	_check(swimmers.size() > 0, "ducks over the water are afloat (%d of %d)" % [swimmers.size(), fill.residents.size()])
	var duck: Animal3D = swimmers[0]
	for step in 20:
		duck.update(0.1)
	_check(duck.float_share > 0.99 and duck.position.y < -0.01, "it settles low in the water, its legs under")
	_check(is_zero_approx(duck.rotation.z), "and sits level while it is not feeding")
	duck.behaviour.state = AnimalBehaviour.State.GRAZE
	duck.behaviour.pose.head = 1.0
	for step in 20:
		duck.update(0.1)
	_check(duck.rotation.z < -1.0, "feeding, it tips forward: head under, tail up")
	duck.behaviour.state = AnimalBehaviour.State.SLEEP
	for step in 20:
		duck.update(0.1)
	_check(is_zero_approx(duck.rotation.z), "asleep with its head low, it does not go under")
	# Swimmers leave rings on the water, each in its turn.
	var rings := objects.rings_node()
	fill._swim(0.0)
	var afloat := 0
	for a: Animal3D in fill.residents:
		a.float_share = 1.0 if a.afloat else 0.0
		afloat += 1 if a.afloat else 0
	rings.advance(60.0)   # (whatever was on the water while the farm settled is gone)
	fill._wake_in = 0.0
	for turn in BuildingFill.WAKE_TURNS:
		fill._swim(BuildingFill.WAKE_EVERY + 0.01)
	_eq(rings.live(), afloat, "one ring from each swimmer over a round of turns")
	# Frozen over, they stand on the ice.
	ShaderGlobals.set_value(&"snow_cover", 1.0)
	fill._swim(0.1)
	_check(not fill.residents.any(func(a: Animal3D) -> bool: return a.afloat), "on ice nobody swims")
	ShaderGlobals.reset()
	objects.queue_free()


func test_419_animals_with_a_trough_near_go_to_it_and_drink() -> void:
	var spec := BuildingModel.spec("cow_shed", 1)
	var fp := Game.footprint("cow_shed")
	_eq(BuildingModel.troughs(spec, fp).size(), 1, "a Cow Shed's yard has its water trough")
	_check(BuildingModel.troughs(BuildingModel.spec("chicken_coop", 1), Game.footprint("chicken_coop")).is_empty(),
		"a Chicken Coop's has none")
	var mind := AnimalBehaviour.new(AnimalRig.of(Game.item_data("cow")), 7, Vector2(14, 7))
	mind.offset = Vector2.ZERO
	var drank := false
	for step in 4000:
		mind.update(0.1)
		drank = drank or mind.drinking
	_check(not drank, "with no water near, a cow never goes to drink")
	mind.drink_at = Vector2(30, 6)
	var nearest := INF
	for step in 4000:
		mind.update(0.1)
		if mind.drinking:
			drank = true
			nearest = minf(nearest, mind.offset.distance_to(mind.drink_at))
			_check(mind.state == AnimalBehaviour.State.GRAZE, "while it drinks its head is down")
			break
	_check(drank and nearest < 1.0, "with a trough near, it walks to it and drinks (within %.1f px)" % nearest)


func test_420_the_weather_shows_on_the_water() -> void:
	ShaderGlobals.reset()
	var weather := SurfaceWeather.new()
	weather.advance({"rain": 0.7}, 10.0)
	_check(float(ShaderGlobals.value(&"rain")) > 0.9, "rain is told to the water at once, for its rings")
	weather.advance({}, 10.0)
	_check(float(ShaderGlobals.value(&"rain")) < 0.1, "and stops with the rain, while the farm is still wet")
	_check(weather.wet > 0.1, "(the wetness lingers)")
	_check(ItemIcons.MOODS.has(&"rain"), "a picture of a thing is never kept from a rainy moment")
	_check(not PondLife.frozen(), "open water on a day without snow")
	ShaderGlobals.set_value(&"snow_cover", 1.0)
	_check(PondLife.frozen(), "snow lying: ponds are frozen over")
	ShaderGlobals.reset()
	weather.free()
