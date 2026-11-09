extends TestSuite
## Vehicles, fuel and the garage.


func _all_plots(g: GameState, r0: int, c0: int, w: int, h: int, ph: GameState.Phase) -> bool:
	for r in range(r0, r0 + h):
		for c in range(c0, c0 + w):
			if g.phase(g.index_of(r, c)) != ph:
				return false
	return true






func test_55_tractor_plows_two_by_two_with_fuel() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(11)
	_check(not g.buy_and_place("tractor", 11, 0), "Tractor unlocks at level 12")
	_check(not g.vehicles.fuel_unlocked, "no fuel before a vehicle")
	g.xp = g.xp_for_level(12)
	_check(g.buy_and_place("tractor", 11, 0), "Tractor bought for 5,000 coins")
	_check(g.vehicles.fuel_unlocked, "the first vehicle unlocks the fuel tank")
	_eq(g.vehicles.fuel_now(), VehicleSystem.FUEL_TANK, "it starts full: 150")
	_eq(g.vehicles.vehicle_area("tractor"), Vector2i(2, 2), "a new tractor works 2x2")
	_check(g.vehicles.use_vehicle("seeder", 8, 8, "wheat").is_empty(), "can't drive a vehicle you don't own")
	var coins := g.coins
	var r := g.vehicles.use_vehicle("tractor", 8, 8)
	_eq(int(r["plots"]), 4, "one tap plows 4 plots")
	_eq(int(r["fuel"]), 4, "1 fuel a plot")
	_eq(g.vehicles.fuel_now(), VehicleSystem.FUEL_TANK - 4, "fuel left")
	_eq(g.coins, coins - 4 * GameState.PLOW_COST, "plowing still costs coins")
	_check(_all_plots(g, 8, 8, 2, 2, GameState.Phase.PLOWED), "all 4 plowed")
	_eq(int(g.vehicles.use_vehicle("tractor", 8, 8)["plots"]), 0, "nothing left to plow there")
	_eq(g.vehicles.fuel_now(), VehicleSystem.FUEL_TANK - 4, "no fuel used when there's no work")
	# Objects in the way are skipped, without using fuel.
	g.buy_and_place("chicken", 9, 10)
	r = g.vehicles.use_vehicle("tractor", 8, 10)
	_eq(int(r["plots"]), 3, "the plot under the chicken is skipped")
	_eq(int(r["fuel"]), 3, "and costs no fuel")
	_done(g)






func test_56_seeder_plants_and_harvester_harvests() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(14)
	for v in ["tractor", "seeder", "harvester"]:
		_check(g.buy_and_place(v, 11, ["tractor", "seeder", "harvester"].find(v)), "%s bought" % v)
	g.vehicles.use_vehicle("tractor", 8, 8)
	_check(g.vehicles.use_vehicle("seeder", 8, 8, "").is_empty(), "the seeder needs a seed")
	var coins := g.coins
	_eq(int(g.vehicles.use_vehicle("seeder", 8, 8, "wheat")["plots"]), 4, "seeder plants 4 plots")
	_eq(g.coins, coins - 4 * int(g.crops["wheat"]["seed_cost"]), "seeds are paid for")
	_check(_all_plots(g, 8, 8, 2, 2, GameState.Phase.GROWING), "all 4 growing")
	_eq(int(g.vehicles.use_vehicle("harvester", 8, 8)["plots"]), 0, "nothing ripe yet")
	_skip(g, int(g.crops["wheat"]["grow_seconds"]))
	var before := g.ribbons.stat("harvests")
	var r := g.vehicles.use_vehicle("harvester", 8, 8)
	_eq(int(r["plots"]), 4, "harvester harvests 4 plots")
	_check(int(r["coins"]) > 0 and int(r["xp"]) > 0, "harvests pay coins and XP")
	_eq(g.ribbons.stat("harvests") - before, 4, "they count as harvests")
	_check(_all_plots(g, 8, 8, 2, 2, GameState.Phase.PLOWED), "plots left plowed")
	_done(g)






func test_57_fuel_refills_slowly_and_spare_tanks() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(12)
	g.buy_and_place("tractor", 11, 0)
	g.vehicles.fuel = 0
	g.vehicles.fuel_t = g.now()
	_check(g.vehicles.use_vehicle("tractor", 8, 8).is_empty(), "nothing runs on an empty tank")
	_skip(g, 10 * VehicleSystem.FUEL_REGEN_SECONDS)
	_eq(g.vehicles.fuel_now(), 10, "1 fuel every 10 minutes")
	_skip(g, 1000 * VehicleSystem.FUEL_REGEN_SECONDS)
	_eq(g.vehicles.fuel_now(), VehicleSystem.FUEL_TANK, "never more than a full tank")
	g.vehicles.fuel = 2
	g.vehicles.fuel_t = g.now()
	g.vehicles.fuel_tanks = 1
	var r := g.vehicles.use_vehicle("tractor", 8, 8)
	_eq(int(r["plots"]), 4, "a spare tank is opened when the tank runs dry")
	_eq(g.vehicles.fuel_tanks, 0, "spare tank used")
	_eq(g.vehicles.fuel_now(), VehicleSystem.FUEL_TANK - 2, "the tank was refilled")
	g.gems = VehicleSystem.FUEL_TANK_GEM_COST
	_check(g.vehicles.buy_fuel_tank(), "buy a tank for %d gems" % VehicleSystem.FUEL_TANK_GEM_COST)
	_eq(g.vehicles.fuel_tanks, 1, "a spare tank held")
	_check(not g.vehicles.buy_fuel_tank(), "no gems left")
	_done(g)






func test_58_garage_upgrades_vehicles_with_parts() -> void:
	var g := _farm()
	g.coins = 10000000
	g.xp = g.xp_for_level(22)
	g.buy_and_place("tractor", 11, 0)
	_check(not g.daily.wanted_parts().has("vehicle_parts"), "no Vehicle Parts drop before a Garage")
	g.parts["vehicle_parts"] = 100
	_check(not g.vehicles.upgrade_vehicle("tractor"), "no upgrades without a Garage")
	_check(g.buy_and_place("garage", 0, 4), "Garage frame placed")
	var garage := g.object_at(g.index_of(0, 4))
	_check(g.under_construction(garage), "the Garage is built from a frame")
	_check(g.daily.wanted_parts().has("vehicle_parts"), "Vehicle Parts drop once you own a Garage")
	_check(not g.vehicles.upgrade_vehicle("tractor"), "not until it's finished")
	for m in ["bricks", "nails", "boards"]:
		g.parts[m] = 10
	g.land.add_materials(int(garage["uid"]))
	_check(not g.under_construction(garage), "10 bricks, nails and boards finish it")
	var sizes: Array = [g.vehicles.vehicle_area("tractor")]
	_check(g.vehicles.upgrade_vehicle("tractor"), "upgrade 1")
	sizes.append(g.vehicles.vehicle_area("tractor"))
	_check(g.vehicles.upgrade_vehicle("tractor"), "upgrade 2")
	sizes.append(g.vehicles.vehicle_area("tractor"))
	_eq(int(g.parts["vehicle_parts"]), 100 - 2 - 5, "2 then 5 parts")
	_check(not g.vehicles.upgrade_vehicle("tractor"), "upgrade 3 needs level 26")
	g.xp = g.xp_for_level(26)
	_check(g.vehicles.upgrade_vehicle("tractor"), "upgrade 3")
	sizes.append(g.vehicles.vehicle_area("tractor"))
	_check(g.vehicles.upgrade_vehicle("tractor"), "upgrade 4")
	sizes.append(g.vehicles.vehicle_area("tractor"))
	_check(not g.vehicles.upgrade_vehicle("tractor"), "fully upgraded")
	_eq(
		sizes,
		[Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 4)],
		"2x2 up to 4x4, FarmVille's sizes"
	)
	_eq(int(g.parts["vehicle_parts"]), 100 - 32, "32 parts in all")
	_eq(g.ribbons.stat("vehicle_upgrades"), 4, "upgrades counted for the Gearhead ribbon")
	_check(int(g.ribbons.ribbon_tiers.get("gearhead", 0)) >= 2, "Gearhead ribbon earned")
	var r := g.vehicles.use_vehicle("tractor", 8, 8)
	_eq(int(r["plots"]), 16, "a 4x4 tractor plows 16 plots in one tap")
	_done(g)






func test_59_combine_chassis_and_all_in_one() -> void:
	var g := _farm()
	g.coins = 10000000
	g.xp = g.xp_for_level(30)
	_check(not g.buy_and_place("combine", 11, 0), "Combine unlocks at level 31")
	g.xp = g.xp_for_level(31)
	_check(g.buy_and_place("combine", 11, 0), "Combine chassis bought")
	var combine := g.object_at(g.index_of(11, 0))
	_check(g.under_construction(combine), "it arrives as a chassis")
	_check(g.vehicles.use_vehicle("combine", 8, 8, "wheat").is_empty(), "a chassis can't drive")
	_check(g.daily.wanted_parts().has("vehicle_parts"), "Vehicle Parts drop for the chassis")
	g.parts["vehicle_parts"] = 40
	var xp_before := g.xp
	g.land.add_materials(int(combine["uid"]))
	_check(not g.under_construction(combine), "40 Vehicle Parts finish it")
	_check(g.xp - xp_before >= 5000, "finishing it gives 5,000 XP")
	var r := g.vehicles.use_vehicle("combine", 8, 8, "wheat")
	_eq(int(r["plots"]), 4, "plows and plants 4 plots in one tap")
	_eq(int(r["fuel"]), 12, "3 fuel a plot")
	_check(_all_plots(g, 8, 8, 2, 2, GameState.Phase.GROWING), "planted")
	_skip(g, int(g.crops["wheat"]["grow_seconds"]))
	var before := g.ribbons.stat("harvests")
	r = g.vehicles.use_vehicle("combine", 8, 8, "wheat")
	_eq(g.ribbons.stat("harvests") - before, 4, "harvested")
	_check(_all_plots(g, 8, 8, 2, 2, GameState.Phase.GROWING), "and planted again, in the same tap")
	_done(g)






func test_60_garage_parks_vehicles_and_state_saves() -> void:
	var path := "user://test_save_vehicles.json"
	var g := _farm()
	g.save_path = path
	g.coins = 10000000
	g.xp = g.xp_for_level(31)
	g.buy_and_place("garage", 0, 4)
	var garage := g.object_at(g.index_of(0, 4))
	garage.erase("construction")
	g.buy_and_place("tractor", 11, 0)
	g.buy_and_place("combine", 11, 2)
	_eq(g.fill_building(int(garage["uid"])), 1, "the tractor parks; the unfinished combine doesn't")
	_check(g.object_at(g.index_of(11, 0)).is_empty(), "the tractor left the field")
	_check(g.vehicles.owned_vehicles().has("tractor"), "a parked tractor still counts")
	_eq(int(g.vehicles.use_vehicle("tractor", 8, 8)["plots"]), 4, "and still works from the toolbar")
	_skip(g, 30 * 86400)
	_check(not g.is_ready(garage), "a garage never needs collecting")
	_check(g.collect(int(garage["uid"])).is_empty(), "nothing to collect")
	g.vehicles.vehicle_levels["tractor"] = 2
	g.vehicles.fuel = 77
	g.vehicles.fuel_t = g.now()
	g.vehicles.fuel_tanks = 3
	g.saving_enabled = true
	g.save_game()
	g.saving_enabled = false
	_done(g)

	var h := GameState.new()
	h.save_path = path
	add_child(h)
	h.saving_enabled = false
	_check(h.vehicles.fuel_unlocked, "fuel tank restored")
	_eq(h.vehicles.fuel_now(), 77, "fuel restored")
	_eq(h.vehicles.fuel_tanks, 3, "spare tanks restored")
	_eq(h.vehicles.vehicle_area("tractor"), Vector2i(3, 3), "upgrades restored")
	_check(h.vehicles.owned_vehicles().has("tractor"), "the parked tractor is still there")
	h.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
