class_name VehicleWork
extends RefCounted
## One vehicle at work on an area, as it really happens: it drives the lanes of VehicleRoute with its weight
## (VehicleMotion), and each plot is worked at the moment the vehicle passes it: fuel is burned for that plot,
## the crop is harvested, planted or the ground plowed then, and coins and XP arrive then. So the field changes
## under the wheels, not before or after, and the farm's state is always whole (a run cut short leaves the
## rest of the area untouched and nothing owed). The farm draws it from this state (VehicleRun); nothing here
## is saved or drawn. Run by VehicleSystem.advance, or all at once with `settle()` (tests, no view).

var id := ""
var job := ""
var crop := ""
var row := 0
var col := 0
var area := Vector2i.ONE
var route := PackedVector2Array()
var lane_of := PackedInt32Array()
var motion: VehicleMotion
var travelled := 0.0
var total := 0.0
var position := Vector2.ZERO     # x = column, y = row, in tiles
var working := false             # on a lane now (not approaching, turning or leaving)
var done := false
var out_of_fuel := false
var result := {"plots": 0, "coins": 0, "xp": 0, "fuel": 0, "drops": []}

var game: GameState
var _system: VehicleSystem
var _stops: Array[Dictionary] = []   # {"dist": tiles along the road, "plot": index}, in driving order
var _next := 0
var _per := 1                         # fuel per plot
var _halt := false                    # out of fuel: stop where it is


## A run of vehicle `vehicle_id` over the area whose top-left plot is (r, c), kept inside the farm.
static func create(system: VehicleSystem, vehicle_id: String, r: int, c: int, crop_id: String) -> VehicleWork:
	var w := VehicleWork.new()
	w._system = system
	w.game = system.game
	w.id = vehicle_id
	var it := system.game.item_data(vehicle_id)
	w.job = str(it["job"])
	w.crop = crop_id
	w._per = int(it.get("fuel_per_plot", 1))
	var full := system.vehicle_area(vehicle_id)
	var game := system.game
	var r0 := maxi(r, 0)
	var c0 := maxi(c, 0)
	var r1 := mini(r + full.y, game.farm_size)
	var c1 := mini(c + full.x, game.farm_size)
	w.row = r0
	w.col = c0
	w.area = Vector2i(maxi(c1 - c0, 0), maxi(r1 - r0, 0))
	w.motion = VehicleMotion.new(float(it.get("weight", 0.5)))
	if w.area.x > 0 and w.area.y > 0:
		w._plan()
	else:
		w.done = true
	return w


func _plan() -> void:
	var plan := VehicleRoute.plan(row, col, area)
	route = plan["points"]
	lane_of = plan["lane_of"]
	total = VehicleRoute.length_of(route)
	# Where along the road each lane starts, and which way it runs.
	var lanes := VehicleRoute.lane_xs(col, area.x)
	var starts: Array[float] = []
	var froms: Array[float] = []
	var cum := 0.0
	starts.resize(lanes.size())
	froms.resize(lanes.size())
	for i in route.size():
		if i > 0:
			cum += route[i].distance_to(route[i - 1])
		if lane_of[i] >= 0 and i + 1 < route.size() and lane_of[i + 1] == lane_of[i]:
			starts[lane_of[i]] = cum
			froms[lane_of[i]] = route[i].y
	# Each plot belongs to the lane nearest its middle and is reached as the vehicle passes its row.
	for r in range(row, row + area.y):
		for c in range(col, col + area.x):
			var i := game.index_of(r, c)
			if game.is_occupied(i):
				continue
			var best := 0
			for k in lanes.size():
				if absf(c + 0.5 - lanes[k]) < absf(c + 0.5 - lanes[best]):
					best = k
			_stops.append({"dist": starts[best] + absf(r + 0.5 - froms[best]), "plot": i})
	_stops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["dist"]) < float(b["dist"]))
	position = route[0]
	var dir := (route[1] - route[0]).normalized()
	motion.yaw = atan2(dir.y, dir.x)


## Does anything in the area need this vehicle's job right now?
func has_work() -> bool:
	for s in _stops:
		if _system.has_work(job, int(s["plot"]), crop):
			return true
	return false


## Time passes by `delta` seconds.
func advance(delta: float) -> void:
	if done:
		return
	var ahead := motion.speed / maxf(float(motion.feel["turn_speed"]), 0.1)
	var here := VehicleRoute.at(route, travelled)
	var look := VehicleRoute.at(route, travelled + maxf(ahead, 0.25))
	var dir: Vector2 = look["dir"]
	var seg: int = here["seg"]
	working = lane_of[seg] >= 0 and lane_of[mini(seg + 1, lane_of.size() - 1)] >= 0
	# Full speed down a lane, slower round the turns, and slowing so as to stop exactly at the end of the road
	# (a creep at the last, so it does arrive).
	var target := float(motion.feel["speed"])
	if not working:
		target *= float(motion.feel["turn_slow"])
	var remaining := total - travelled
	target = minf(target, maxf(sqrt(2.0 * float(motion.feel["brake"]) * remaining), 0.15))
	if remaining <= 0.0 or _halt:
		target = 0.0
	motion.step(delta, target, atan2(dir.y, dir.x))
	travelled = minf(travelled + motion.speed * delta, total)
	position = VehicleRoute.at(route, travelled)["pos"]
	while not _halt and _next < _stops.size() and travelled >= float(_stops[_next]["dist"]):
		_work(int(_stops[_next]["plot"]))
		_next += 1
	if (travelled >= total or _halt) and motion.speed < 0.05:
		_finish()


## Works the plot under the wheels (if there is anything to do there): fuel first, so a dry tank stops the run.
func _work(plot: int) -> void:
	if game.is_occupied(plot) or not _system.has_work(job, plot, crop):
		return
	if not _system.burn_fuel(_per):
		out_of_fuel = true
		_halt = true
		return
	result["fuel"] = int(result["fuel"]) + _per
	var coins_before := game.coins
	var xp_before := game.xp
	if _system.work_plot(job, plot, crop, result):
		result["plots"] = int(result["plots"]) + 1
	result["coins"] = int(result["coins"]) + game.coins - coins_before
	result["xp"] = int(result["xp"]) + game.xp - xp_before


func _finish() -> void:
	if done:
		return
	done = true
	_system.finish(self)


## Runs the whole thing at once (no view): for tests, and anything that needs the result now.
func settle() -> Dictionary:
	var guard := 0
	while not done and guard < 20000:
		advance(0.1)
		guard += 1
	return result
