extends TestSuite
## Vehicle rust (docs/RUST.md, our own addition): how fast it gathers parked and outside, what it costs a
## vehicle at work, and its repair.

const DAY := 86400


## A farm with a Tractor standing outside, fuel in the tank and coins to spare.
func _tractor_farm() -> GameState:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(30)
	g.buy_and_place("tractor", 11, 0)
	return g


## A finished, empty Garage.
func _add_garage(g: GameState) -> Dictionary:
	var garage := {"uid": g.next_uid, "id": "garage", "row": 4, "col": 0, "level": 1, "inside": {}, "t": g.now()}
	g.next_uid += 1
	g.add_object(garage)
	g.objects_updated()
	return garage


func _park(g: GameState, garage: Dictionary) -> void:
	var tractor: Dictionary = g.objects.filter(func(o: Dictionary) -> bool: return o["id"] == "tractor")[0]
	g.homes.put_in_home(int(garage["uid"]), "tractor", {"uid": int(tractor["uid"])})


func test_410_a_vehicle_rusts_a_level_a_week_outside_and_a_fortnight_parked() -> void:
	var g := _tractor_farm()
	_eq(g.rust.max_level(), 5, "five levels of rust")
	_eq(g.rust.level("tractor"), 0, "a new tractor is clean")
	_check(g.rust.stands_outside("tractor"), "it stands outside")
	_skip(g, 7 * DAY - 60)
	_eq(g.rust.level("tractor"), 0, "not yet a week")
	_skip(g, 120)
	_eq(g.rust.level("tractor"), 1, "a week outside: level 1")
	_skip(g, 7 * DAY)
	_eq(g.rust.level("tractor"), 2, "two weeks outside: level 2")
	# Parked from here on, it gathers half as fast, and keeps what it had.
	_park(g, _add_garage(g))
	_check(not g.rust.stands_outside("tractor"), "parked in the Garage")
	_eq(g.rust.level("tractor"), 2, "parking takes no rust off")
	_skip(g, 7 * DAY)
	_eq(g.rust.level("tractor"), 2, "a week parked is half a level")
	_skip(g, 7 * DAY + 60)
	_eq(g.rust.level("tractor"), 3, "a fortnight parked: a level")
	_skip(g, 400 * DAY)
	_eq(g.rust.level("tractor"), 5, "never past the last level")
	_check(g.rust.seized("tractor"), "at which it does not work")
	_done(g)


func test_411_rust_burns_more_fuel_and_works_fewer_plots() -> void:
	var g := _tractor_farm()
	_check(is_equal_approx(g.rust.fuel_factor("tractor"), 1.0), "clean: the fuel it always took")
	_eq(g.rust.plots_worked("tractor", 4), 4, "and all its plots")
	_skip(g, 7 * DAY + 60)
	_check(is_equal_approx(g.rust.fuel_factor("tractor"), 1.1), "level 1: a tenth more fuel")
	_eq(g.rust.plots_worked("tractor", 4), 3, "a fifth fewer plots, rounded down: 3 of 4")
	_eq(g.rust.plots_worked("tractor", 16), 12, "12 of 16")
	var fuel := g.vehicles.fuel_now()
	var r := g.vehicles.use_vehicle("tractor", 8, 8)
	_eq(int(r["plots"]), 3, "one tap plows 3 of its 4 plots")
	_eq(int(r["fuel"]), 3, "three plots at 1.1 fuel: 3, the rest carried")
	_eq(g.vehicles.fuel_now(), fuel - 3, "taken from the tank")
	_skip(g, 21 * DAY)   # level 4
	_eq(g.rust.level("tractor"), 4, "level 4")
	_check(is_equal_approx(g.rust.fuel_factor("tractor"), 1.4), "four tenths more fuel")
	_eq(g.rust.plots_worked("tractor", 4), 1, "a fifth of 4 rounds down to none: it still works one")
	_eq(g.rust.plots_worked("tractor", 16), 3, "3 of 16")
	r = g.vehicles.use_vehicle("tractor", 5, 8)
	_eq(int(r["plots"]), 1, "one plot plowed")
	_skip(g, 7 * DAY)
	_check(g.rust.seized("tractor"), "level 5")
	_check(g.vehicles.use_vehicle("tractor", 4, 8).is_empty(), "it does not work at all")
	# Ten plots at a tenth more fuel burn eleven.
	var work := VehicleWork.create(g.vehicles, "tractor", 8, 2, "")
	work._fuel_factor = 1.1
	var burned := 0
	for plot in 10:
		var burn := floori(work._owed + work._per * work._fuel_factor + 0.0001)
		work._owed += work._per * work._fuel_factor - burn
		burned += burn
	_eq(burned, 11, "ten plots at level 1 burn 11 fuel")
	_done(g)


func test_412_a_repair_costs_coins_and_time_and_takes_all_the_rust_off() -> void:
	var g := _tractor_farm()
	var price := int(g.item_data("tractor")["cost"])
	_check(g.rust.repair_cost("tractor").is_empty() and not g.rust.repair("tractor"), "nothing to repair when clean")
	var coins: Array[int] = []
	var seconds: Array[int] = []
	for level in 5:
		_skip(g, 7 * DAY + 60 if level == 0 else 7 * DAY)
		coins.append(int(g.rust.repair_cost("tractor")["coins"]))
		seconds.append(int(g.rust.repair_cost("tractor")["seconds"]))
	_eq(coins, [price * 5 / 100, price * 12 / 100, price * 22 / 100, price * 35 / 100, price / 2] as Array[int],
		"5%, 12%, 22%, 35% and half of its price")
	_eq(seconds, [600, 1800, 3600, 7200, 14400] as Array[int], "10 and 30 minutes, 1, 2 and 4 hours")
	g.coins = 10
	_check(not g.rust.repair("tractor"), "not without the coins")
	g.coins = 5000
	_check(g.rust.repair("tractor"), "repair started")
	_eq(g.coins, 5000 - price / 2, "half its price paid")
	_check(g.rust.repairing("tractor"), "it is in the workshop")
	_eq(g.rust.repair_left("tractor"), 14400, "for four hours")
	_check(not g.rust.repair("tractor"), "it is not repaired twice")
	_check(g.vehicles.use_vehicle("tractor", 8, 8).is_empty(), "and cannot work meanwhile")
	_skip(g, 14400 + 1)
	_check(not g.rust.repairing("tractor"), "done")
	_eq(g.rust.level("tractor"), 0, "all its rust is gone")
	_eq(int(g.vehicles.use_vehicle("tractor", 8, 8)["plots"]), 4, "and it works its whole area again")
	_skip(g, 7 * DAY)
	_eq(g.rust.level("tractor"), 1, "it gathers again from the repair on")
	_done(g)


func test_413_after_a_job_a_vehicle_outside_goes_into_a_garage_with_room() -> void:
	var g := _tractor_farm()
	_eq(int(g.vehicles.use_vehicle("tractor", 8, 8)["plots"]), 4, "driven from where it stands")
	_check(g.rust.stands_outside("tractor"), "with no Garage it stays out")
	var garage := _add_garage(g)
	_eq(int(g.vehicles.use_vehicle("tractor", 8, 10)["plots"]), 4, "another job")
	_check(not g.rust.stands_outside("tractor"), "after it, it is in the Garage")
	_eq(int((garage["inside"] as Dictionary).get("tractor", 0)), 1, "parked there")
	_eq(g.vehicles.owned_vehicles(), ["tractor"] as Array[String], "still one tractor")
	_eq(int(g.vehicles.use_vehicle("tractor", 10, 8)["plots"]), 4, "and it works from there")
	_done(g)


func test_414_rust_is_saved_and_a_new_vehicle_starts_clean() -> void:
	var g := _tractor_farm()
	_skip(g, 15 * DAY)
	_eq(g.rust.level("tractor"), 2, "two weeks outside")
	var saved := {}
	g.rust.save_to(saved)
	var other := _tractor_farm()
	other.debug_time_offset = g.debug_time_offset
	other.rust.load_from(JSON.parse_string(JSON.stringify(saved)))
	_eq(other.rust.level("tractor"), 2, "its rust is saved")
	other.rust.load_from({})
	_eq(other.rust.level("tractor"), 0, "an older save has no rust")
	other.rust.load_from({"rust": {"tractor": "nonsense", "no_such_vehicle": {"w": 5}}})
	_eq(other.rust.level("tractor"), 0, "a damaged save is mended")
	# Sold and bought again: the new one is clean.
	g.rust.bought("tractor")
	_eq(g.rust.level("tractor"), 0, "a tractor just bought has no rust")
	_done(other)
	_done(g)


func test_415_a_rusty_vehicle_wears_the_rust_sign_and_a_tap_on_it_offers_only_its_repair() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.farm_size = 24
	Game.set_objects([])
	Game.coins = 1000000
	Game.xp = Game.xp_for_level(30)
	Game.buy_and_place("tractor", 11, 0)
	var objects := Objects3D.new()
	add_child(objects)
	await Objects3D.until_settled(get_tree(), 600)
	objects.sync()
	var marks := objects.rust_marks_node()
	_check(marks.ids().is_empty() and not marks.visible, "a clean vehicle wears no sign")
	_skip(Game, 15 * DAY)
	objects.sync()
	_eq(marks.ids(), ["tractor"] as Array[String], "two weeks outside: the Tractor wears the rust sign")
	_check(is_equal_approx(marks.shares()[0], 2.0 / Game.rust.max_level()), "which shows its two levels of rust")
	# A tap anywhere on the sign is for the sign; beside it, not.
	var at := marks.where(0)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ReadyMarks.ZOOM_REF
	add_child(cam)
	cam.position = at + Vector3(0, 0, 10)
	var middle := cam.unproject_position(at)
	_eq(marks.pick(cam, middle), "tractor", "a tap on the sign finds its vehicle")
	_eq(marks.pick(cam, middle + Vector2(get_viewport().get_visible_rect().size.y * 0.2, 0)), "", "one beside it does not")
	# The bubble it opens offers the repair and nothing else.
	var hud := FarmHud.new()
	add_child(hud)
	await get_tree().process_frame
	hud.bubble.to_screen = func(p: Vector2) -> Vector2: return p
	hud.bubble.show_repair(Vector2(300, 300), "tractor")
	_check(UiFx.is_open(hud.bubble) and hud.bubble._act.visible and not hud.bubble._open.visible,
		"its bubble has the Repair button and no way to the vehicle's sheet")
	_check(hud.bubble._line.text.contains(str(int(Game.rust.repair_cost("tractor")["coins"]))), "and says what it costs")
	# In a Garage, the Garage wears the sign of the rustiest vehicle in it.
	var garage := _add_garage(Game)
	_park(Game, garage)
	Game.objects_updated()
	await Objects3D.until_settled(get_tree(), 600)
	objects.sync()
	_eq(marks.ids(), ["tractor"] as Array[String], "parked: its Garage wears the sign")
	_check(marks.where(0).distance_to(at) > 1.0, "over the Garage, not where it stood")
	# The button starts the repair, and a vehicle in for repair wears no sign.
	var deed := HudBubble.repair_of("tractor")
	_eq(str(deed["icon"]), "repair", "the button is the broken gear")
	(deed["do"] as Callable).call()
	_check(Game.rust.repairing("tractor"), "the bubble's button starts the repair")
	objects.sync()
	_check(marks.ids().is_empty(), "in for repair: no sign")
	hud.queue_free()
	cam.queue_free()
	objects.queue_free()
