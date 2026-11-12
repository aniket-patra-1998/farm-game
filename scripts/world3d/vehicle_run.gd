class_name VehicleRun
extends Node3D
## The picture of a vehicle at work: it follows a VehicleWork (the real run, which drives the lanes and works
## each plot as it passes), popping in beside the field and leaving when the work is done. All it adds is
## what is only for the eye: wheels turning with the ground covered, the reel turning while it works, the
## body riding its springs (VehicleMotion's lift and lean), dust behind the rear wheels, smoke from the
## exhaust, and wheel tracks laid down each lane. It never changes the farm.

signal finished

const POP_SECONDS := 0.35
const LEAVE_SECONDS := 0.3
const REEL_WORK := 7.0         # radians per second a reel turns while working
const REEL_IDLE := 2.0
const DUST_SPREAD := 0.35      # how far out from the line the dust flies, tiles per second
const LIFT_RATE := 5.0          # how quickly an implement is raised or lowered (per second, eased)
const HUM_IDLE_PITCH := 0.8     # the engine's pitch standing and while working slowly, to its pitch at full speed
const HUM_TOP_PITCH := 1.25
const HUM_WORK_DB := 3.0        # louder when the machine is under load
const HUM_IDLE_DB := -3.0
const TRACK_EVERY := 1.0       # tiles between wheel track marks while driving a lane

var work: VehicleWork
var item := {}
var puffs: DustPuffs
var trails: Trails
var elapsed := 0.0

var _model: Node3D
var _sprung: Node3D
var _wheels: Array[Node3D] = []        # the pivots that turn with the ground
var _wheel_rest: Array[Transform3D] = []
var _wheel_radius: Array[float] = []   # in tiles
var _reels: Array[Node3D] = []
var _reel_rest: Array[Transform3D] = []
var _tools: Array[Node3D] = []         # implements: lowered while working, lifted while driving
var _tool_rest: Array[Transform3D] = []
var _tool_lift: Array[float] = []
var _hum: AudioStreamPlayer
var _hum_db := 0.0                     # the engine's volume as it started: loud and soft are around it
var _lowered := 0.0                    # 0 lifted .. 1 working depth
var _reel_angle := 0.0
var _reel_rate := 0.0
var _rear: Array[Vector3] = []         # where the dust leaves (rear wheels), in this node's space
var _smoke_at := Vector3.ZERO
var _dust_owed := 0.0
var _smoke_owed := 0.0
var _track_from := 0.0                 # distance driven at the last track mark
var _dust_tint := Color.WHITE
var _scale := 1.0
var _leaving := false
var _leave_t := 0.0
var _sprung_rest := Vector3.ZERO


## The picture of `run`.
static func create(run: VehicleWork, dust: DustPuffs, tracks: Trails) -> VehicleRun:
	var r := VehicleRun.new()
	r.work = run
	r.item = run.game.item_data(run.id)
	r.puffs = dust
	r.trails = tracks
	r._start()
	return r


func _start() -> void:
	_scale = VehicleModel.scale_of(item)
	_dust_tint = VehicleMotion.dust_colour(work.job)
	_dust_tint.a = 0.45
	_model = VehicleModel.build(item, false, true)
	_model.position = Vector3(-0.5, 0, -0.5)     # turn about the vehicle's middle
	add_child(_model)
	_rig()
	_place()
	_hum = Feedback.hum("engine")
	_hum_db = _hum.volume_db if _hum != null else 0.0
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
		elif n.has_meta(VehicleModel.LIFT):
			_hang(n)
			_tools.append(n)
			_tool_rest.append(n.transform)
			_tool_lift.append(float(n.get_meta(VehicleModel.LIFT)))
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


func tools() -> int:
	return _tools.size()


## How far down the implements are: 0 lifted, 1 working.
func lowered() -> float:
	return _lowered


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
	var m := work.motion
	if not _leaving:
		var t := clampf(elapsed / POP_SECONDS, 0.0, 1.0)
		scale = Vector3.ONE * _pop(t)
		if work.done:
			_leaving = true
			_leave_t = 0.0
	else:
		_leave_t += delta
		var t := clampf(_leave_t / LEAVE_SECONDS, 0.0, 1.0)
		scale = Vector3.ONE * (1.0 - t * t)
		if t >= 1.0:
			Sound.stop_loop(_hum)
			_hum = null
			finished.emit()
			queue_free()
			return
	_place()
	_wheels_turn()
	_reel_step(delta, work.working)
	_tools_step(delta, work.working)
	_hum_step(work.working)
	_pose()
	_throw_dust(delta, work.working)
	if work.working and trails != null and m.distance - _track_from >= TRACK_EVERY:
		_track_from = m.distance
		trails.lay_pass(work.position, m.yaw)


## A little overshoot on the way in, like something dropped in place.
static func _pop(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0) * cos(t * 9.0) if t < 1.0 else 1.0


func _place() -> void:
	position = Vector3(work.position.x, 0, work.position.y)
	rotation.y = -work.motion.yaw


func _wheels_turn() -> void:
	for k in _wheels.size():
		var angle := -(work.motion.distance / maxf(_wheel_radius[k], 0.01))
		_wheels[k].transform = Transform3D(_wheel_rest[k].basis * Basis(Vector3.BACK, angle), _wheel_rest[k].origin)


func _reel_step(delta: float, working: bool) -> void:
	var want := REEL_WORK if working else REEL_IDLE
	# A heavy reel spins up slowly.
	_reel_rate = lerpf(_reel_rate, want, 1.0 - exp(-delta * lerpf(5.0, 2.0, work.motion.weight)))
	_reel_angle -= _reel_rate * delta
	for k in _reels.size():
		_reels[k].transform = Transform3D(_reel_rest[k].basis * Basis(Vector3.BACK, _reel_angle), _reel_rest[k].origin)


## The engine note rises with the machine's speed and swells when it works.
func _hum_step(working: bool) -> void:
	if _hum == null or not is_instance_valid(_hum):
		return
	var speed := clampf(work.motion.speed / maxf(float(work.motion.feel["speed"]), 0.01), 0.0, 1.0)
	_hum.pitch_scale = lerpf(HUM_IDLE_PITCH, HUM_TOP_PITCH, speed)
	_hum.volume_db = _hum_db + (HUM_WORK_DB if working else HUM_IDLE_DB)


func _exit_tree() -> void:
	Sound.stop_loop(_hum)
	_hum = null


## Implements go down to work and are lifted to drive; a heavy machine is slower about it.
func _tools_step(delta: float, working: bool) -> void:
	if _tools.is_empty():
		return
	var rate := LIFT_RATE * lerpf(1.0, 0.6, work.motion.weight)
	_lowered = lerpf(_lowered, 1.0 if working else 0.0, 1.0 - exp(-delta * rate))
	for k in _tools.size():
		var up := -_tool_lift[k] * (1.0 - _lowered)
		_tools[k].transform = Transform3D(_tool_rest[k].basis * Basis(Vector3.BACK, up), _tool_rest[k].origin)


func _pose() -> void:
	# The body rides its springs about its pivot: rises and falls, tips and leans.
	var m := work.motion
	_sprung.transform = Transform3D(m.lean(), _sprung_rest + Vector3(0, m.lift() * _scale, 0))


func _throw_dust(delta: float, working: bool) -> void:
	if puffs == null:
		return
	var m := work.motion
	_dust_owed += m.dust_rate() * (1.0 if working else 0.3) * delta
	var heading := Basis(Vector3.UP, rotation.y)
	while _dust_owed >= 1.0:
		_dust_owed -= 1.0
		for r in _rear:
			var side := signf(r.z) if absf(r.z) > 0.001 else 1.0
			var at := position + heading * r
			var drift := heading * Vector3(-0.15, 0, side * DUST_SPREAD) + Vector3(0, float(m.feel["dust_rise"]), 0)
			puffs.emit(at, drift, float(m.feel["dust_size"]), float(m.feel["dust_life"]), _dust_tint)
	_smoke_owed += m.smoke_rate() * delta
	while _smoke_owed >= 1.0:
		_smoke_owed -= 1.0
		var tint := VehicleMotion.smoke_colour()
		tint.a = 0.3
		puffs.emit(position + heading * _smoke_at, Vector3(0, 0.45, 0), float(m.feel["smoke_size"]), 0.9, tint, 3.0)
