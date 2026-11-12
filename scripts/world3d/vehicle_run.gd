class_name VehicleRun
extends Node3D
## A vehicle driving over the area it just worked: it pops in beside the field, drives the lanes of
## VehicleRoute with the weight of its kind (VehicleMotion: slow to pull away and to stop, soft springs, late
## turns), its wheels turning with the ground it covers, the reel turning while it works, dust thrown up behind
## the rear wheels and smoke from the exhaust, and the wheel tracks laid lane by lane as it goes. Then it
## leaves. Purely a show: the work itself was done the moment the farmer got there.

signal finished

const POP_SECONDS := 0.35
const LEAVE_SECONDS := 0.3
const REEL_WORK := 7.0         # radians per second a reel turns while working
const REEL_IDLE := 2.0
const DUST_SPREAD := 0.35      # how far out from the line the dust flies, tiles per second
const TRACK_EVERY := 1.0       # tiles between wheel track marks while driving a lane

var item := {}
var route := PackedVector2Array()
var lane_of := PackedInt32Array()
var motion: VehicleMotion
var travelled := 0.0           # tiles along the route
var elapsed := 0.0
var puffs: DustPuffs
var trails: Trails
var area := Vector2i.ONE
var corner := Vector2i.ZERO    # the area's top-left plot (row, col)

var _model: Node3D
var _sprung: Node3D
var _wheels: Array[Node3D] = []        # the pivots that turn with the ground
var _wheel_rest: Array[Transform3D] = []
var _wheel_radius: Array[float] = []   # in tiles
var _reels: Array[Node3D] = []
var _reel_rest: Array[Transform3D] = []
var _reel_angle := 0.0
var _reel_rate := 0.0
var _rear: Array[Vector3] = []         # where the dust leaves (rear wheels), in this node's space
var _smoke_at := Vector3.ZERO
var _dust_owed := 0.0
var _smoke_owed := 0.0
var _track_owed := 0.0
var _dust_tint := Color.WHITE
var _scale := 1.0
var _leaving := false
var _leave_t := 0.0
var _total := 0.0
var _last_lane := -2
var _sprung_rest := Vector3.ZERO


## A run for vehicle `it` over `area` whose top-left plot is (row, col).
static func create(it: Dictionary, row: int, col: int, field: Vector2i, dust: DustPuffs, tracks: Trails) -> VehicleRun:
	var r := VehicleRun.new()
	r.item = it
	r.area = field
	r.corner = Vector2i(row, col)
	r.puffs = dust
	r.trails = tracks
	r._start()
	return r


func _start() -> void:
	var plan := VehicleRoute.plan(corner.x, corner.y, area)
	route = plan["points"]
	lane_of = plan["lane_of"]
	_total = VehicleRoute.length_of(route)
	motion = VehicleMotion.new(float(item.get("weight", 0.5)))
	_scale = VehicleModel.scale_of(item)
	_dust_tint = VehicleMotion.dust_colour(str(item.get("job", "all")))
	_dust_tint.a = 0.35
	_model = VehicleModel.build(item, false, true)
	_model.position = Vector3(-0.5, 0, -0.5)     # turn about the vehicle's middle
	add_child(_model)
	_rig()
	var first := VehicleRoute.at(route, 0.0)
	var dir: Vector2 = first["dir"]
	motion.yaw = atan2(dir.y, dir.x)
	_place(first["pos"])
	scale = Vector3.ZERO     # pops in


## Finds the wheels and reels in the built model and hangs the body on its own springy pivot.
func _rig() -> void:
	var rest := Vector3(0.5, 0.1, 0.5)
	_sprung = Node3D.new()
	_sprung.position = rest
	_sprung_rest = rest
	_model.add_child(_sprung)
	for child in _model.get_children():
		if child == _sprung or not child is Node3D:
			continue
		var n := child as Node3D
		if n.has_meta(VehicleModel.SPIN):
			var radius := float(n.get_meta(VehicleModel.SPIN))
			if radius > 0.0:
				_wheels.append(n)
				_wheel_rest.append(n.transform)
				_wheel_radius.append(radius * _scale)
			else:
				_hang(n)
				_reels.append(n)
				_reel_rest.append(n.transform)
		else:
			_hang(n)
	# Dust leaves behind the rear wheels (the pair furthest back); smoke from the stack.
	var back := INF
	for w in _wheels:
		back = minf(back, w.position.x)
	for w in _wheels:
		if w.position.x < back + 0.05:
			_rear.append(w.position + _model.position + Vector3(0, -w.position.y + 0.02, 0))
	var ex: Vector3 = VehicleModel.EXHAUST.get(str(item.get("id", "")), Vector3(0.0, 0.4, 0.0))
	_smoke_at = Vector3(0.5, 0, 0.5) + ex * _scale + _model.position


func wheels() -> int:
	return _wheels.size()


func reels() -> int:
	return _reels.size()


## Moves a part of the model onto the sprung body, keeping it where it is.
func _hang(n: Node3D) -> void:
	var t := n.transform
	n.get_parent().remove_child(n)
	_sprung.add_child(n)
	n.transform = Transform3D(t.basis, t.origin - _sprung_rest)


func _process(delta: float) -> void:
	advance(minf(delta, 0.1))


## Time passes by `delta` seconds (the farm calls this each frame; a test calls it by hand).
func advance(delta: float) -> void:
	elapsed += delta
	if not _leaving:
		_drive(delta)
		if scale != Vector3.ONE:
			var t := clampf(elapsed / POP_SECONDS, 0.0, 1.0)
			scale = Vector3.ONE * _pop(t)
		if travelled >= _total and motion.speed < 0.05:
			_leaving = true
			_leave_t = 0.0
	else:
		_leave_t += delta
		motion.step(delta, 0.0, motion.yaw)
		var t := clampf(_leave_t / LEAVE_SECONDS, 0.0, 1.0)
		scale = Vector3.ONE * (1.0 - t * t)
		if t >= 1.0:
			finished.emit()
			queue_free()
	_pose()


## A little overshoot on the way in, like something dropped in place.
static func _pop(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0) * cos(t * 9.0) if t < 1.0 else 1.0


func _drive(delta: float) -> void:
	var ahead := motion.speed / maxf(float(motion.feel["turn_speed"]), 0.1)
	var here := VehicleRoute.at(route, travelled)
	var look := VehicleRoute.at(route, travelled + maxf(ahead, 0.25))
	var dir: Vector2 = look["dir"]
	var seg: int = here["seg"]
	var on_lane := lane_of[mini(seg + 1, lane_of.size() - 1)] >= 0 and lane_of[seg] >= 0
	# Full speed down a lane, slower round the turns, and it eases to a stop at the end of the route.
	var target := float(motion.feel["speed"])
	if not on_lane:
		target *= float(motion.feel["turn_slow"])
	var remaining := _total - travelled
	# Slows so as to stop exactly at the end of the road (a creep at the last, so it does arrive).
	target = minf(target, maxf(sqrt(2.0 * float(motion.feel["brake"]) * remaining), 0.15))
	if remaining <= 0.0:
		target = 0.0
	motion.step(delta, target, atan2(dir.y, dir.x))
	var before := travelled
	travelled = minf(travelled + motion.speed * delta, _total)
	var moved := travelled - before
	var at := VehicleRoute.at(route, travelled)
	_place(at["pos"])
	_wheels_turn()
	_reel_step(delta, on_lane)
	_throw_dust(delta, on_lane)
	if on_lane and trails != null:
		_track_owed += moved
		if _track_owed >= TRACK_EVERY:
			_track_owed = 0.0
			_lay_tracks(at["pos"])


func _place(p: Vector2) -> void:
	position = Vector3(p.x, 0, p.y)
	rotation.y = -motion.yaw


func _wheels_turn() -> void:
	for k in _wheels.size():
		var angle := -(motion.distance / maxf(_wheel_radius[k], 0.01))
		_wheels[k].transform = Transform3D(_wheel_rest[k].basis * Basis(Vector3.BACK, angle), _wheel_rest[k].origin)


func _reel_step(delta: float, working: bool) -> void:
	var want := REEL_WORK if working else REEL_IDLE
	# A heavy reel spins up slowly.
	_reel_rate = lerpf(_reel_rate, want, 1.0 - exp(-delta * lerpf(5.0, 2.0, motion.weight)))
	_reel_angle -= _reel_rate * delta
	for k in _reels.size():
		_reels[k].transform = Transform3D(_reel_rest[k].basis * Basis(Vector3.BACK, _reel_angle), _reel_rest[k].origin)


func _pose() -> void:
	# The body rides its springs about its pivot: rises and falls, tips and leans.
	var lift := motion.lift() * _scale
	_sprung.transform = Transform3D(motion.lean(), _sprung_rest + Vector3(0, lift, 0))


func _throw_dust(delta: float, working: bool) -> void:
	if puffs == null:
		return
	var rate := motion.dust_rate() * (1.0 if working else 0.3)
	_dust_owed += rate * delta
	var heading := Basis(Vector3.UP, rotation.y)
	while _dust_owed >= 1.0:
		_dust_owed -= 1.0
		for r in _rear:
			var side := signf(r.z) if absf(r.z) > 0.001 else 1.0
			var at := position + heading * r
			var drift := heading * Vector3(-0.15, 0, side * DUST_SPREAD) + Vector3(0, float(motion.feel["dust_rise"]), 0)
			puffs.emit(at, drift, float(motion.feel["dust_size"]), float(motion.feel["dust_life"]), _dust_tint)
	_smoke_owed += motion.smoke_rate() * delta
	while _smoke_owed >= 1.0:
		_smoke_owed -= 1.0
		var tint := VehicleMotion.smoke_colour()
		tint.a = 0.3
		puffs.emit(position + heading * (_smoke_at + Vector3(0, 0, 0)), Vector3(0, 0.45, 0),
			float(motion.feel["smoke_size"]), 0.9, tint, 3.0)


## The two wheel tracks of the lane just driven, up to here.
func _lay_tracks(p: Vector2) -> void:
	trails.lay_pass(p, motion.yaw)
