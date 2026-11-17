class_name RustSystem
extends GameSystem
## Vehicle rust (our own addition, docs/RUST.md). A vehicle rusts with time wherever it stands: a level every
## Balance `rust.level_days` parked in a Garage, `rust.outside_rate` times as fast standing outside. Each level
## burns more fuel a plot and works fewer plots; at the last it does not work. A repair (coins and time, more at
## each level) takes all of it off. Rust is worked out from the clock: what is kept for a vehicle is the rust
## it had gathered when it last changed places or was repaired, and when that was.
## Part of the game state: reached as `Game.rust`. Switch: Release "rust".

const DAY := 86400.0

## vehicle id -> {"w": rust gathered by `t`, in seconds parked (a second outside counts for more), "t": when,
## "out": whether it stood outside from then on, "fix": when its repair is done (0: not being repaired)}
var vehicles := {}


func _init(owner: GameState) -> void:
	super(owner)
	# Where a vehicle stands changes its pace: both ways a change on the farm is told lead here.
	game.objects_changed.connect(settle)
	game.object_changed.connect(_on_object_changed)


func reset() -> void:
	vehicles = {}


func save_to(data: Dictionary) -> void:
	data["rust"] = vehicles


func load_from(data: Dictionary) -> void:
	vehicles = {}
	var saved: Variant = data.get("rust", {})
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for id: String in saved:
		var v: Variant = saved[id]
		if typeof(v) == TYPE_DICTIONARY and game.items.has(id):
			vehicles[id] = {"w": maxf(0.0, float(v.get("w", 0.0))), "t": int(v.get("t", game.now())),
				"out": bool(v.get("out", false)), "fix": int(v.get("fix", 0))}


## Whether rust is part of this release at all.
func is_on() -> bool:
	return Release.on("rust")


## The most rust there is: at this level a vehicle does not work.
func max_level() -> int:
	return Balance.a("rust.repair_share").size()


## Whether a vehicle of this kind stands outside now (on the farm, not in a Garage).
func stands_outside(id: String) -> bool:
	for o in game.objects:
		if str(o["id"]) == id and game.kind_of(o) == "vehicle":
			return true
	return false


## Vehicles came, went or changed places: each one's rust up to now is banked at the pace of where it stood,
## and it gathers on from here at the pace of where it stands now. (A vehicle put away in the Barn keeps its
## rust and gathers on at the parked pace: nothing takes rust off but a repair.)
func settle() -> void:
	if not is_on():
		return
	for id: String in game.vehicles.owned_vehicles():
		var out := stands_outside(id)
		if not vehicles.has(id):
			bought(id)
		elif bool(vehicles[id]["out"]) != out or _repaired(id):
			_bank(id)
		vehicles[id]["out"] = out


## A vehicle was just bought: it starts clean, whatever one of its kind had gathered before.
func bought(id: String) -> void:
	if not is_on():
		return
	vehicles[id] = {"w": 0.0, "t": game.now(), "out": stands_outside(id), "fix": 0}


func _on_object_changed(uid: int) -> void:
	var o := game.object_by_uid(uid)
	if not o.is_empty() and (game.special_of(o) == "garage" or game.kind_of(o) == "vehicle"):
		settle()


## The rust a vehicle has gathered by now, in seconds parked.
func gathered(id: String) -> float:
	if not is_on() or not vehicles.has(id):
		return 0.0
	var v: Dictionary = vehicles[id]
	var rate := Balance.f("rust.outside_rate") if bool(v["out"]) else 1.0
	if _repaired(id):
		return maxf(0.0, float(game.now() - int(v["fix"]))) * rate   # (it came out of its repair clean)
	if int(v["fix"]) > 0:
		return float(v["w"])   # (in the workshop: it gathers none)
	return float(v["w"]) + maxf(0.0, float(game.now() - int(v["t"]))) * rate


## A vehicle's level of rust: 0 clean, up to max_level().
func level(id: String) -> int:
	return clampi(floori(gathered(id) / (Balance.f("rust.level_days") * DAY)), 0, max_level())


## Whether it is too rusty to work at all.
func seized(id: String) -> bool:
	return level(id) >= max_level()


## What each plot's fuel is multiplied by for this vehicle's rust.
func fuel_factor(id: String) -> float:
	return 1.0 + Balance.f("rust.fuel_more") * level(id)


## How many of `plots` this vehicle works with its rust: fewer at each level, rounded down, never under one.
func plots_worked(id: String, plots: int) -> int:
	var at := level(id)
	if at <= 0 or plots <= 0:
		return plots
	return maxi(1, floori(plots * (1.0 - Balance.f("rust.area_less") * at)))


## Whether it is being repaired now, and the seconds left.
func repairing(id: String) -> bool:
	return repair_left(id) > 0


func repair_left(id: String) -> int:
	return maxi(0, int((vehicles.get(id, {}) as Dictionary).get("fix", 0)) - game.now()) if is_on() else 0


## The coins and the seconds a repair takes now ({} when there is nothing to repair).
func repair_cost(id: String) -> Dictionary:
	var at := level(id)
	if at <= 0:
		return {}
	return {"coins": roundi(float(game.item_data(id).get("cost", 0)) * float(Balance.a("rust.repair_share")[at - 1])),
		"seconds": int(Balance.a("rust.repair_seconds")[at - 1])}


## Whether a repair can start now: rusty, not being repaired or at work, and the coins are there.
func can_repair(id: String) -> bool:
	var cost := repair_cost(id)
	return not cost.is_empty() and not repairing(id) and not game.vehicles.is_running(id) \
		and game.coins >= int(cost["coins"])


## Starts the repair: the coins are paid now, and the vehicle is out of use until it is done.
func repair(id: String) -> bool:
	if not can_repair(id):
		return false
	var cost := repair_cost(id)
	if not game.spend(int(cost["coins"])):
		return false
	_bank(id)
	vehicles[id]["fix"] = game.now() + int(cost["seconds"])
	game.message.emit(tr("RUST_REPAIR_STARTED") % str(game.item_data(id)["name"]))
	game.objects_updated()
	game.queue_save()
	return true


## Whether its repair has finished since it was last looked at (it is clean from that moment).
func _repaired(id: String) -> bool:
	var fix := int((vehicles.get(id, {}) as Dictionary).get("fix", 0))
	return fix > 0 and game.now() >= fix


## Writes down the rust `id` has gathered up to now, so it can gather on at another pace.
func _bank(id: String) -> void:
	var v: Dictionary = vehicles[id]
	v["w"] = gathered(id)
	v["t"] = game.now()
	if _repaired(id):
		v["fix"] = 0
