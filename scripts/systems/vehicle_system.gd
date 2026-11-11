class_name VehicleSystem
extends GameSystem
## Vehicles and the shared fuel tank: plowing, planting and harvesting areas, upgrades, fuel finds.
## Part of the game state: reached as `Game.vehicles`; shared state is on `game`.

const FUEL_TANK := 150
const FUEL_REGEN_SECONDS := 600    # the tank slowly refills: 1 fuel every 10 minutes
const FUEL_TANK_GEM_COST := 3
const TRACTOR_COIN_CHANCE := 0.05  # coins pop out of the ground while a vehicle plows
const TRACTOR_COINS := 10
const FUEL_LEVEL := 12               # FarmVille: fuel finds from level 12
const FUEL_FIND_CHANCE := 0.08      # FarmVille: plowing your own farm can turn up fuel, once a day
const FUEL_FIND_SHARE := 0.25       # of a full tank

var fuel := 0                      # in the shared tank
var fuel_t := 0                    # when fuel last refilled itself
var fuel_tanks := 0                # spare full tanks, opened when the tank runs dry
var fuel_unlocked := false         # true once the first vehicle is bought
var vehicle_levels := {}           # vehicle id -> upgrades bought (0..4)
var fuel_found_day := 0            # the day fuel was last found while plowing


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
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
	while fuel > FUEL_TANK:
		fuel -= FUEL_TANK
		fuel_tanks += 1
	if fuel >= FUEL_TANK:
		fuel_t = game.now()
	game.inventory_changed.emit()


## FarmVille: plowing your own farm can turn up fuel, at most once a day.
func roll_fuel_find(i: int) -> int:
	if not game.drops_enabled or game.level() < FUEL_LEVEL or fuel_found_day == game.day_number():
		return 0
	if game.rng.randf() >= FUEL_FIND_CHANCE:
		return 0
	fuel_found_day = game.day_number()
	var n := int(FUEL_TANK * FUEL_FIND_SHARE)
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
	if fuel >= FUEL_TANK:
		fuel_t = t
		return fuel
	var gained := int((t - fuel_t) / float(FUEL_REGEN_SECONDS))
	if gained > 0:
		fuel = mini(FUEL_TANK, fuel + gained)
		fuel_t = t if fuel >= FUEL_TANK else fuel_t + gained * FUEL_REGEN_SECONDS
	return fuel


## Takes fuel for one plot, opening a spare tank when the tank runs dry.
func _burn_fuel(n: int) -> bool:
	fuel_now()
	if fuel < n and fuel_tanks > 0:
		fuel_tanks -= 1
		fuel = mini(FUEL_TANK, fuel + FUEL_TANK)
		game.message.emit(tr("OPENED_A_SPARE_FUEL_TANK"))
	if fuel < n:
		return false
	if fuel >= FUEL_TANK:
		fuel_t = game.now() # the refill clock starts once the tank is below full
	fuel -= n
	return true


func buy_fuel_tank() -> bool:
	if not game.spend_gems(FUEL_TANK_GEM_COST):
		game.message.emit(tr("NOT_ENOUGH_GEMS_FOR_A_FUEL"))
		return false
	fuel_tanks += 1
	game.message.emit(tr("BOUGHT_A_FULL_FUEL_TANK"))
	game.inventory_changed.emit()
	return true


## Drives a vehicle over the area whose back corner is row, col.
## Tractor plows, Seeder plants crop_id, Harvester harvests, Combine does all three.
## Returns {"plots", "coins", "xp", "fuel", "drops":[texts]}, or {} if it couldn't run.
func use_vehicle(id: String, row: int, col: int, crop_id := "") -> Dictionary:
	if not owned_vehicles().has(id):
		return {}
	var it := game.item_data(id)
	var job: String = it["job"]
	if job == "plant" and crop_id == "":
		game.message.emit(tr("PICK_A_SEED_FIRST_THEN_THE"))
		return {}
	if fuel_now() + fuel_tanks * FUEL_TANK <= 0:
		game.message.emit(tr("OUT_OF_FUEL_IT_REFILLS_SLOWLY"))
		return {}
	var per := int(it.get("fuel_per_plot", 1))
	var area := vehicle_area(id)
	var out := {"plots": 0, "coins": 0, "xp": 0, "fuel": 0, "drops": []}
	var coins_before := game.coins
	var xp_before := game.xp
	var out_of_fuel := false
	for r in range(row, row + area.y):
		for c in range(col, col + area.x):
			if not game.in_farm(r, c):
				continue
			var i := game.index_of(r, c)
			if game.is_occupied(i) or not _vehicle_has_work(job, i, crop_id):
				continue
			if not _burn_fuel(per):
				out_of_fuel = true
				break
			out["fuel"] = int(out["fuel"]) + per
			if _vehicle_work(job, i, crop_id, out):
				out["plots"] = int(out["plots"]) + 1
		if out_of_fuel:
			break
	out["coins"] = game.coins - coins_before
	out["xp"] = game.xp - xp_before
	if int(out["plots"]) > 0:
		game.ribbons.bump("vehicle_plots", int(out["plots"]))
	if out_of_fuel:
		game.message.emit(tr("OUT_OF_FUEL_IT_REFILLS_SLOWLY"))
	game.inventory_changed.emit()
	game.queue_save()
	return out


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
			if game.drops_enabled and game.rng.randf() < TRACTOR_COIN_CHANCE:
				game.add_coins(TRACTOR_COINS)
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
	return has_garage() and owned_vehicles().has(id) and cost > 0 \
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
		fuel = FUEL_TANK
		fuel_t = game.now()
