class_name VehicleSystem
extends GameSystem
## Vehicles and the shared fuel tank: plowing, planting and harvesting areas, upgrades, fuel finds.
## Part of the game state: reached as `Game.vehicles`; shared state is on `game`.

signal run_started(run: VehicleWork)    # a vehicle set off over an area (the farm draws it)
signal run_finished(run: VehicleWork)   # it finished: run.result says what it did

var runs: Array[VehicleWork] = []  # vehicles at work now (not saved: a run cut short leaves the rest untouched)
var fuel := 0                      # in the shared tank
var fuel_t := 0                    # when fuel last refilled itself
var fuel_tanks := 0                # spare full tanks, opened when the tank runs dry
var fuel_unlocked := false         # true once the first vehicle is bought
var vehicle_levels := {}           # vehicle id -> upgrades bought (0..4)
var fuel_found_day := 0            # the day fuel was last found while plowing


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
	runs.clear()
	fuel = 0
	fuel_t = 0
	fuel_tanks = 0
	fuel_unlocked = false
	vehicle_levels = {}
	fuel_found_day = 0


func save_to(data: Dictionary) -> void:
	data["fuel"] = fuel
	data["fuel_t"] = fuel_t
	data["fuel_tanks"] = fuel_tanks
	data["fuel_unlocked"] = fuel_unlocked
	data["vehicle_levels"] = vehicle_levels
	data["fuel_found_day"] = fuel_found_day


func load_from(data: Dictionary) -> void:
	fuel = int(data.get("fuel", 0))
	fuel_t = int(data.get("fuel_t", 0))
	fuel_tanks = int(data.get("fuel_tanks", 0))
	fuel_unlocked = bool(data.get("fuel_unlocked", false))
	vehicle_levels = int_map(data.get("vehicle_levels", {}))
	fuel_found_day = int(data.get("fuel_found_day", 0))


## Adds fuel; past a full tank it fills spare tanks.
func add_fuel(n: int) -> void:
	if not fuel_unlocked:
		fuel_unlocked = true
		fuel_t = game.now()
	fuel = fuel_now() + n
	while fuel > Balance.i("vehicles.fuel_tank"):
		fuel -= Balance.i("vehicles.fuel_tank")
		fuel_tanks += 1
	if fuel >= Balance.i("vehicles.fuel_tank"):
		fuel_t = game.now()
	game.inventory_changed.emit()


## FarmVille: plowing your own farm can turn up fuel, at most once a day.
func roll_fuel_find(i: int) -> int:
	if not game.drops_enabled or game.level() < Balance.i("vehicles.fuel_level") or fuel_found_day == game.day_number():
		return 0
	if game.rng.randf() >= Balance.f("vehicles.fuel_find_chance"):
		return 0
	fuel_found_day = game.day_number()
	var n := int(Balance.i("vehicles.fuel_tank") * Balance.f("vehicles.fuel_find_share"))
	add_fuel(n)
	game.found.emit(i, tr("FOUND_FUEL") % n)
	return n


## Vehicle types you can drive: finished ones on the farm or parked in a garage.
func owned_vehicles() -> Array[String]:
	var out: Array[String] = []
	for o in game.objects:
		if game.kind_of(o) == "vehicle" and not game.under_construction(o) and not out.has(o["id"]):
			out.append(o["id"])
		elif o["id"] == "garage":
			for id in o.get("inside", {}):
				if int(o["inside"][id]) > 0 and not out.has(id):
					out.append(id)
	var ordered: Array[String] = []
	for id in game.item_order:
		if out.has(id):
			ordered.append(id)
	return ordered


## Vehicles you can drive: only those parked inside a finished Garage (FarmVille's tools live in the garage).
func usable_vehicles() -> Array[String]:
	var out: Array[String] = []
	for o in game.objects:
		if o["id"] == "garage" and not game.under_construction(o):
			for id in o.get("inside", {}):
				if int(o["inside"][id]) > 0 and not out.has(id):
					out.append(id)
	var ordered: Array[String] = []
	for id in game.item_order:
		if out.has(id):
			ordered.append(id)
	return ordered


## Vehicles you own that are not in a garage yet (standing on the farm): they have to be parked to be used.
func loose_vehicles() -> int:
	var n := 0
	for o in game.objects:
		if game.kind_of(o) == "vehicle" and not game.under_construction(o):
			n += 1
	return n


func vehicle_level(id: String) -> int:
	return int(vehicle_levels.get(id, 0))


## Plots a vehicle works in one tap: columns x rows.
func vehicle_area(id: String) -> Vector2i:
	return VehicleDef.SIZES[clampi(vehicle_level(id), 0, VehicleDef.SIZES.size() - 1)]


## Fuel in the tank now, after its slow refill.
func fuel_now() -> int:
	if not fuel_unlocked:
		return 0
	var t := game.now()
	if fuel >= Balance.i("vehicles.fuel_tank"):
		fuel_t = t
		return fuel
	var gained := int((t - fuel_t) / float(Balance.i("vehicles.fuel_regen_seconds")))
	if gained > 0:
		fuel = mini(Balance.i("vehicles.fuel_tank"), fuel + gained)
		fuel_t = t if fuel >= Balance.i("vehicles.fuel_tank") else fuel_t + gained * Balance.i("vehicles.fuel_regen_seconds")
	return fuel


## Takes fuel for one plot, opening a spare tank when the tank runs dry.
func _burn_fuel(n: int) -> bool:
	fuel_now()
	if fuel < n and fuel_tanks > 0:
		fuel_tanks -= 1
		fuel = mini(Balance.i("vehicles.fuel_tank"), fuel + Balance.i("vehicles.fuel_tank"))
		game.message.emit(tr("OPENED_A_SPARE_FUEL_TANK"))
	if fuel < n:
		return false
	if fuel >= Balance.i("vehicles.fuel_tank"):
		fuel_t = game.now() # the refill clock starts once the tank is below full
	fuel -= n
	return true


func buy_fuel_tank() -> bool:
	if not game.spend_gems(Balance.i("vehicles.fuel_tank_gem_cost")):
		game.message.emit(tr("NOT_ENOUGH_GEMS_FOR_A_FUEL"))
		return false
	fuel_tanks += 1
	game.message.emit(tr("BOUGHT_A_FULL_FUEL_TANK"))
	game.inventory_changed.emit()
	return true


## A vehicle's run is made, but not started: why not (not owned, no seed, no fuel) comes back as a message and null.
func make_run(id: String, row: int, col: int, crop_id := "") -> VehicleWork:
	if not usable_vehicles().has(id):
		if owned_vehicles().has(id):
			game.message.emit(tr("PARK_IT_IN_THE_GARAGE_TO_USE_IT"))
		return null
	var job: String = game.item_data(id)["job"]
	if job == "plant" and crop_id == "":
		game.message.emit(tr("PICK_A_SEED_FIRST_THEN_THE"))
		return null
	if fuel_now() + fuel_tanks * Balance.i("vehicles.fuel_tank") <= 0:
		game.message.emit(tr("OUT_OF_FUEL_IT_REFILLS_SLOWLY"))
		return null
	return VehicleWork.create(self, id, row, col, crop_id)


## Sends the vehicle over the area whose top-left plot is row, col, and it works as it drives (advance). Tractor
## plows, Seeder plants crop_id, Harvester harvests, Combine does all three. Returns the run, or null when it
## couldn't start (a message says why) or there is nothing for it to do there.
func dispatch(id: String, row: int, col: int, crop_id := "") -> VehicleWork:
	for r in runs:
		if r.id == id:
			game.message.emit(tr("IT_IS_ALREADY_WORKING") % game.item_data(id)["name"])
			return null
	var run := make_run(id, row, col, crop_id)
	if run == null:
		return null
	if not run.has_work():
		game.message.emit(tr("NOTHING_FOR_THE_TO_DO_THERE") % game.item_data(id)["name"])
		return null
	runs.append(run)
	run_started.emit(run)
	return run


func is_running(id: String) -> bool:
	for r in runs:
		if r.id == id:
			return true
	return false


## Time passes: every vehicle at work drives on and works what it passes.
func advance(delta: float) -> void:
	for r in runs.duplicate():
		r.advance(delta)


## Drives a vehicle over an area and returns once it has finished (no drive to watch: for tests and anything
## that needs the result at once). {"plots", "coins", "xp", "fuel", "drops":[texts]}, or {} if it couldn't run.
func use_vehicle(id: String, row: int, col: int, crop_id := "") -> Dictionary:
	var run := make_run(id, row, col, crop_id)
	if run == null:
		return {}
	return run.settle()


## A run ended (called by VehicleWork): what it did is added up and told.
func finish(run: VehicleWork) -> void:
	if int(run.result["plots"]) > 0:
		game.ribbons.bump("vehicle_plots", int(run.result["plots"]))
	if run.out_of_fuel:
		game.message.emit(tr("OUT_OF_FUEL_IT_REFILLS_SLOWLY"))
	if runs.has(run):
		runs.erase(run)
		run_finished.emit(run)
	game.inventory_changed.emit()
	game.queue_save()


func has_work(job: String, plot: int, crop_id: String) -> bool:
	return _vehicle_has_work(job, plot, crop_id)


func burn_fuel(n: int) -> bool:
	return _burn_fuel(n)


func work_plot(job: String, plot: int, crop_id: String, out: Dictionary) -> bool:
	return _vehicle_work(job, plot, crop_id, out)


func _vehicle_has_work(job: String, i: int, crop_id: String) -> bool:
	var ph := game.field.phase(i)
	match job:
		"plow":
			return ph == GameState.Phase.GRASS or ph == GameState.Phase.WITHERED
		"plant":
			return ph == GameState.Phase.PLOWED
		"harvest":
			return ph == GameState.Phase.RIPE
		"all":
			return ph == GameState.Phase.RIPE or ph == GameState.Phase.GRASS or ph == GameState.Phase.WITHERED or (
				ph == GameState.Phase.PLOWED and crop_id != ""
			)
	return false


func _vehicle_work(job: String, i: int, crop_id: String, out: Dictionary) -> bool:
	var did := false
	if (job == "harvest" or job == "all") and game.field.phase(i) == GameState.Phase.RIPE:
		var r := game.field.harvest(i)
		if not r.is_empty():
			did = true
			if r.get("drop_text", "") != "":
				(out["drops"] as Array).append(r["drop_text"])
	if (job == "plow" or job == "all") and (
		game.field.phase(i) == GameState.Phase.GRASS or game.field.phase(i) == GameState.Phase.WITHERED
	):
		if game.field.plow(i):
			did = true
			if game.drops_enabled and game.rng.randf() < Balance.f("vehicles.tractor_coin_chance"):
				game.add_coins(Balance.i("vehicles.tractor_coins"))
	if (job == "plant" or job == "all") and crop_id != "" and game.field.phase(i) == GameState.Phase.PLOWED:
		if game.field.plant(i, crop_id):
			did = true
	return did


## FarmVille's Garage upgrades: Vehicle Parts make a vehicle cover more plots, up to 4x4.
func vehicle_upgrade_cost(id: String) -> int:
	var d := game.catalog.get_def(id)
	return (d as VehicleDef).upgrade_cost(vehicle_level(id)) if d is VehicleDef else -1


func vehicle_upgrade_level_needed(id: String) -> int:
	var d := game.catalog.get_def(id)
	return (d as VehicleDef).upgrade_level_needed(vehicle_level(id)) if d is VehicleDef else 0


func has_garage() -> bool:
	for o in game.objects:
		if o["id"] == "garage" and not game.under_construction(o):
			return true
	return false


func can_upgrade_vehicle(id: String) -> bool:
	var cost := vehicle_upgrade_cost(id)
	return has_garage() and usable_vehicles().has(id) and cost > 0 \
		and game.level() >= vehicle_upgrade_level_needed(id) and int(game.parts.get("vehicle_parts", 0)) >= cost


func upgrade_vehicle(id: String) -> bool:
	if not can_upgrade_vehicle(id):
		if not has_garage():
			game.message.emit(tr("BUILD_A_GARAGE_TO_UPGRADE_VEHICLES"))
		elif vehicle_upgrade_cost(id) < 0:
			game.message.emit(tr("YOUR_IS_FULLY_UPGRADED") % game.item_data(id)["name"])
		elif game.level() < vehicle_upgrade_level_needed(id):
			game.message.emit(tr("THIS_UPGRADE_UNLOCKS_AT_LEVEL") % vehicle_upgrade_level_needed(id))
		else:
			game.message.emit(tr("NOT_ENOUGH_VEHICLE_PARTS_YET"))
		return false
	game.parts["vehicle_parts"] = int(game.parts["vehicle_parts"]) - vehicle_upgrade_cost(id)
	vehicle_levels[id] = vehicle_level(id) + 1
	var area := vehicle_area(id)
	game.ribbons.bump("vehicle_upgrades", 1)
	game.message.emit(tr("UPGRADED_IT_NOW_WORKS_X_PLOTS") % [game.item_data(id)["name"], area.x, area.y])
	game.inventory_changed.emit()
	game.objects_updated()
	return true


## The first vehicle bought fills the shared fuel tank.
func on_vehicle_bought() -> void:
	if not fuel_unlocked:
		fuel_unlocked = true
		fuel = Balance.i("vehicles.fuel_tank")
		fuel_t = game.now()
