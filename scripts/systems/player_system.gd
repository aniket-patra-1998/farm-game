class_name PlayerSystem
extends GameSystem
## The player's farmer and the work they do, the FarmVille way.
## Part of the game state: reached as `Game.player`; shared state is on `game`.
##
## Farm work isn't instant: each tap queues a job (plow, plant, harvest, fertilize, collect, or a vehicle's
## pass), and the farmer walks to each in turn, round whatever stands in the way, works at it for a moment,
## and only then does it happen (coins, XP and finds arrive as each job completes). Boxed in with nowhere to
## walk, the farmer does the work from where they stand, as FarmVille's did (players fenced theirs in on
## purpose). A queued job can be cancelled before the farmer gets to it; the queue is not saved.
##
## Also the farmer themselves: their name, the farm's name, and how they look (`look`: read by Farmer3D).

signal action_done(job: Dictionary, result: Dictionary)  # a job's turn came; result is empty if it failed
signal queue_changed
signal look_changed

enum Refused { NONE, FULL, QUEUED, NOTHING_TO_DO, COINS }

const WALK_SPEED := 4.5          # tiles a second
const ACTION_SECONDS := 0.75     # the farmer works this long at each job
const QUEUE_MAX := 60
const STAND_OFF := 0.45          # how far short of a plot's centre the farmer stops (they work at its edge)
const DEFAULT_LOOK := {"body": "a", "skin": "#f1c9a5", "hair": "#5a3a1e", "hair_style": "short",
	"shirt": "#d9483b", "overalls": "#3f6fb5", "hat": "straw", "shoes": "#5b3b22"}

var farmer_name := ""
var farm_name := ""
var look := DEFAULT_LOOK.duplicate()
var pos := Vector2.ZERO          # where the farmer stands, in tiles (x: col, y: row; a tile's centre is +0.5)
var facing := Vector2(1, 1)      # the way they face (tiles)
var queue: Array[Dictionary] = []
var progress := 0.0              # seconds worked at the job in hand

var _path: Array[Vector2] = []   # the way to the job in hand (points still to walk to)
var _planned := false            # the job in hand has its path
var _grid: AStarGrid2D
var _grid_stale := true
var _grid_objects := -1           # how many objects the grid was made for


func _init(owner: GameState) -> void:
	super(owner)
	game.objects_changed.connect(_on_farm_changed)
	game.farm_expanded.connect(func(_size: int) -> void: _on_farm_changed())


func reset() -> void:
	farmer_name = ""
	farm_name = ""
	look = DEFAULT_LOOK.duplicate()
	pos = Vector2(game.farm_size / 2.0, game.farm_size / 2.0)
	facing = Vector2(1, 1)
	clear_queue()
	_grid_stale = true


func save_to(data: Dictionary) -> void:
	data["farmer_name"] = farmer_name
	data["farm_name"] = farm_name
	data["farmer_look"] = look
	data["farmer_pos"] = [pos.x, pos.y]


func load_from(data: Dictionary) -> void:
	reset()
	farmer_name = str(data.get("farmer_name", ""))
	farm_name = str(data.get("farm_name", ""))
	var saved: Variant = data.get("farmer_look", {})
	if typeof(saved) == TYPE_DICTIONARY:
		for k in DEFAULT_LOOK:
			look[k] = str(saved.get(k, DEFAULT_LOOK[k]))
	var at: Variant = data.get("farmer_pos", [])
	if typeof(at) == TYPE_ARRAY and at.size() == 2:
		pos = Vector2(clampf(float(at[0]), 0.0, game.farm_size), clampf(float(at[1]), 0.0, game.farm_size))


# ---------------------------------------------------------------- the queue

## Queues a job: {"kind": "plow"|"plant"|"harvest"|"fertilize", "plot": index, ("crop": id)},
## {"kind": "collect", "uid": uid} or {"kind": "vehicle", "item", "row", "col", "crop"}.
## Returns why not, or Refused.NONE.
func enqueue(job: Dictionary) -> Refused:
	if queue.size() >= QUEUE_MAX:
		return Refused.FULL
	if is_queued(job):
		return Refused.QUEUED
	if not can_do(job):
		return Refused.NOTHING_TO_DO
	# Everything queued can be paid for: a job never fails for coins when its turn comes.
	if cost(job) > 0 and game.coins < committed() + cost(job):
		return Refused.COINS
	queue.append(job)
	queue_changed.emit()
	return Refused.NONE


## Is there already a job queued for this job's plot or object?
func is_queued(job: Dictionary) -> bool:
	return _find(job) >= 0


## Takes a queued job for the same plot or object back out. Returns whether there was one.
func cancel(job: Dictionary) -> bool:
	var k := _find(job)
	if k < 0:
		return false
	if k == 0:
		_drop_job_in_hand()
	else:
		queue.remove_at(k)
	queue_changed.emit()
	return true


func clear_queue() -> void:
	if queue.is_empty():
		return
	queue.clear()
	_path.clear()
	_planned = false
	progress = 0.0
	queue_changed.emit()


## The plots with a job waiting (for highlights): plot index -> kind.
func queued_plots() -> Dictionary:
	var out := {}
	for job in queue:
		if int(job.get("plot", -1)) >= 0:
			out[int(job["plot"])] = job["kind"]
	return out


## Is the farmer at the job in hand and working on it (not walking there)?
func is_working() -> bool:
	return not queue.is_empty() and _planned and _path.is_empty()


func is_walking() -> bool:
	return not queue.is_empty() and _planned and not _path.is_empty()


## Coins the queued jobs will cost when their turns come.
func committed() -> int:
	var total := 0
	for job in queue:
		total += cost(job)
	return total


func cost(job: Dictionary) -> int:
	match str(job["kind"]):
		"plow":
			return GameState.PLOW_COST
		"plant":
			return int(game.crops.get(str(job.get("crop", "")), {}).get("seed_cost", 0))
		"fertilize":
			return GameState.FERTILIZER_COST
	return 0


## Is there (still) something for this job to do?
func can_do(job: Dictionary) -> bool:
	var i := int(job.get("plot", -1))
	match str(job["kind"]):
		"plow":
			return i >= 0 and not game.is_occupied(i) \
				and game.phase(i) in [GameState.Phase.GRASS, GameState.Phase.WITHERED]
		"plant":
			return i >= 0 and game.phase(i) == GameState.Phase.PLOWED and game.crops.has(str(job.get("crop", "")))
		"harvest":
			return i >= 0 and game.phase(i) == GameState.Phase.RIPE
		"fertilize":
			return i >= 0 and game.phase(i) == GameState.Phase.GROWING and not game.is_fertilized(i)
		"collect":
			var obj := game.object_by_uid(int(job.get("uid", -1)))
			return not obj.is_empty() and game.is_ready(obj)
		"vehicle":
			return game.items.has(str(job.get("item", "")))
	return false


## Moves time on: the farmer walks to the job in hand, works at it, does it, and goes on to the next.
func advance(delta: float) -> void:
	if _stale():
		_stand_clear()
	while delta > 0.0 and not queue.is_empty():
		var job := queue[0]
		if not _planned:
			_plan(job)
		if not _path.is_empty():
			delta = _walk(delta)
			continue
		var aim := _centre_of(job) - pos
		if aim.length() > 0.01:
			facing = aim.normalized()
		progress += delta
		if progress < ACTION_SECONDS:
			return
		delta = progress - ACTION_SECONDS
		_drop_job_in_hand()
		# What it had to do may have gone while it waited (the crop withered, the animal was sold).
		var result := _perform(job) if can_do(job) else {}
		action_done.emit(job, result)
		queue_changed.emit()


# ---------------------------------------------------------------- doing a job

func _perform(job: Dictionary) -> Dictionary:
	var i := int(job.get("plot", -1))
	match str(job["kind"]):
		"plow":
			return {"ok": true} if game.plow(i) else {}
		"plant":
			return {"ok": true} if game.plant(i, str(job["crop"])) else {}
		"fertilize":
			return {"ok": true} if game.fertilize(i) else {}
		"harvest":
			# What stood there, for whoever shows the harvest (it's gone once harvested).
			job["crop"] = game.crop_at(i)
			job["art"] = game.crop_art_for(i)
			return game.harvest(i)
		"collect":
			return game.collect(int(job["uid"]))
		"vehicle":
			return game.vehicles.use_vehicle(str(job["item"]), int(job["row"]), int(job["col"]),
				str(job.get("crop", "")))
	return {}


func _drop_job_in_hand() -> void:
	queue.pop_front()
	_path.clear()
	_planned = false
	progress = 0.0


func _find(job: Dictionary) -> int:
	var key := _target_key(job)
	for k in queue.size():
		if _target_key(queue[k]) == key:
			return k
	return -1


## What a job is aimed at: one job at a time per plot, object, or vehicle pass.
func _target_key(job: Dictionary) -> String:
	if job["kind"] == "collect":
		return "o%d" % int(job["uid"])
	if job["kind"] == "vehicle":
		return "v%d,%d" % [int(job["row"]), int(job["col"])]
	return "p%d" % int(job["plot"])


# ---------------------------------------------------------------- walking there

## Where a job is, in tiles: its plot's centre, its object's centre, or the middle of a vehicle's pass.
func _centre_of(job: Dictionary) -> Vector2:
	match str(job["kind"]):
		"collect":
			var obj := game.object_by_uid(int(job["uid"]))
			if obj.is_empty():
				return pos
			var fp := game.footprint(obj["id"])
			return Vector2(int(obj["col"]) + fp.x / 2.0, int(obj["row"]) + fp.y / 2.0)
		"vehicle":
			var area: Vector2i = game.vehicles.vehicle_area(str(job["item"]))
			return Vector2(clampf(int(job["col"]) + area.x / 2.0, 0.5, game.farm_size - 0.5),
				clampf(int(job["row"]) + area.y / 2.0, 0.5, game.farm_size - 0.5))
	var i := int(job["plot"])
	return Vector2(i % GameState.MAX_SIZE + 0.5, i / GameState.MAX_SIZE + 0.5)


## Works out the way to a job: to a plot's edge, or to the nearest free tile beside an object. No way
## there (boxed in, or the place is walled off) leaves the path empty: the job is done from here.
func _plan(job: Dictionary) -> void:
	_planned = true
	_path.clear()
	var grid := _walkable()
	var from := _tile()
	if grid.is_point_solid(from):
		return
	var best := PackedVector2Array()
	var found := false
	for goal in _goals(job):
		if grid.is_point_solid(goal):
			continue
		var way := grid.get_point_path(from, goal)
		if goal != from and way.is_empty():
			continue
		if not found or way.size() < best.size():
			best = way
			found = true
	if not found:
		return
	for k in range(1, best.size()):
		_path.append(best[k] + Vector2(0.5, 0.5))
	# At a plot the farmer stops at its edge, not on its middle.
	if job["kind"] != "collect" and not _path.is_empty():
		var before := pos if _path.size() == 1 else _path[-2]
		_path[-1] = _path[-1].lerp(before, STAND_OFF / maxf(_path[-1].distance_to(before), STAND_OFF))


## The tiles the farmer could stand on to do a job: the plot itself, or the ring round an object.
func _goals(job: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if job["kind"] != "collect":
		var c := _centre_of(job)
		out.append(Vector2i(int(c.x), int(c.y)))
		return out
	var obj := game.object_by_uid(int(job["uid"]))
	if obj.is_empty():
		return out
	var fp := game.footprint(obj["id"])
	var r0 := int(obj["row"])
	var c0 := int(obj["col"])
	for r in range(r0 - 1, r0 + fp.y + 1):
		for c in range(c0 - 1, c0 + fp.x + 1):
			var beside := r < r0 or r >= r0 + fp.y or c < c0 or c >= c0 + fp.x
			if beside and game.in_farm(r, c):
				out.append(Vector2i(c, r))
	return out


## Walks along the path for up to `delta` seconds; returns the time left over on arriving.
func _walk(delta: float) -> float:
	while delta > 0.0 and not _path.is_empty():
		var to := _path[0] - pos
		var dist := to.length()
		var step := WALK_SPEED * delta
		if dist > 0.0001:
			facing = to / dist
		if step < dist:
			pos += facing * step
			return 0.0
		pos = _path[0]
		_path.remove_at(0)
		delta -= dist / WALK_SPEED
	return delta


## The farm as somewhere to walk: every tile of it that nothing stands on (plots and crops are walked over).
func _walkable() -> AStarGrid2D:
	if not _stale():
		return _grid
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, GameState.MAX_SIZE, GameState.MAX_SIZE)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for r in GameState.MAX_SIZE:
		for c in GameState.MAX_SIZE:
			if not game.in_farm(r, c) or game.is_occupied(game.index_of(r, c)):
				_grid.set_point_solid(Vector2i(c, r), true)
	_grid_stale = false
	_grid_objects = game.objects.size()
	return _grid


## Has the farm changed since the walking grid was made? (Objects are also added and removed without the
## signal, so their number is checked too.)
func _stale() -> bool:
	return _grid == null or _grid_stale or _grid_objects != game.objects.size()


func _tile() -> Vector2i:
	return Vector2i(clampi(int(pos.x), 0, GameState.MAX_SIZE - 1), clampi(int(pos.y), 0, GameState.MAX_SIZE - 1))


## Something was put down where the farmer stands (or the farm began with something there): they step
## out to the nearest free tile.
func _stand_clear() -> void:
	var grid := _walkable()
	var here := _tile()
	if not grid.is_point_solid(here):
		return
	var best := Vector2i(-1, -1)
	var best_d := INF
	for r in game.farm_size:
		for c in game.farm_size:
			var cell := Vector2i(c, r)
			var d := Vector2(cell - here).length_squared()
			if d < best_d and not grid.is_point_solid(cell):
				best = cell
				best_d = d
	if best.x >= 0:
		pos = Vector2(best) + Vector2(0.5, 0.5)


func _on_farm_changed() -> void:
	_grid_stale = true
