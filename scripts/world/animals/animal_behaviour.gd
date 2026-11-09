class_name AnimalBehaviour
extends RefCounted
## What one animal is doing. FarmVille's animals stood, wandered a little near their spot and ate; this
## keeps that rhythm and adds our own touch: real walk cycles, grazing and chewing, looking around, the
## odd flap or tail fan, and babies of every species sharing one temperament (their rig's young
## behaviour): restless, with bursts of bouncing play. Runs a small state machine and writes an
## AnimalPose every frame; the animal's piece reads `offset` and `facing`.
##
## Every value eases toward its target (no snapping), the walk cycle advances with the distance actually
## walked (so feet stay planted), and each animal has its own random stream, seeded by its uid, so a farm
## looks the same every time it loads but no two animals move in step.

enum State { IDLE, WALK, GRAZE, LOOK, FLAP, DISPLAY, FROLIC }

const TURN_SPEED := 7.0          # facing changes through 0: the body narrows, then widens the other way
const STRIDE_EASE := 7.0         # how fast the legs blend between standing and walking
const HEAD_DOWN_EASE := 3.2      # lowering the head to graze
const HEAD_UP_EASE := 5.0
const PECK_RATE := 2.6           # pecks a second while pecking
const BLINK_EVERY := Vector2(2.0, 6.0)
const BLINK_TIME := 0.13
const EAR_EVERY := Vector2(2.5, 8.0)
const EAR_TIME := 0.35
const SWISH_EVERY := Vector2(3.0, 9.0)
const SWISH_TIME := 1.2
const MIN_WALK := 0.35           # a walk covers at least this share of the wander range
const ARRIVED := 0.6             # px
const FROLIC_SPEED := 2.4        # a frolic is a dash: this many times walking speed
const BOUNCE_RATE := 3.0         # bounces a second while frolicking
const FROLIC_AGAIN := 0.45       # chance a frolic runs straight into another

const DURATIONS := {
	State.IDLE: Vector2(1.5, 4.0),
	State.WALK: Vector2(2.0, 6.0),     # the most a walk may take
	State.GRAZE: Vector2(3.0, 7.0),
	State.LOOK: Vector2(1.2, 2.6),
	State.FLAP: Vector2(0.6, 0.9),
	State.DISPLAY: Vector2(2.5, 4.0),
	State.FROLIC: Vector2(1.0, 2.2),
}

var rig: AnimalRig
var pose := AnimalPose.new()
var state: State = State.IDLE
var offset := Vector2.ZERO       ## from the animal's home spot (its tile centre), in px
var facing := 1.0                ## the way it's heading: 1 right, -1 left
var shown_facing := 1.0          ## eases toward facing (the turn)
var range_px := Vector2(14, 7)   ## how far it may wander: an ellipse, flattened like the ground

var _rng := RandomNumberGenerator.new()
var _left := 0.0                 # seconds left in this state
var _target := Vector2.ZERO
var _look_to := 0.0
var _blink_in := 0.0
var _blink_left := 0.0
var _ear_in := 0.0
var _ear_left := 0.0
var _swish_in := 0.0
var _swish_left := 0.0
var _phase := 0.0                # a per-animal offset for the slow idle motions


func _init(animal_rig: AnimalRig, seed_value: int, wander: Vector2) -> void:
	rig = animal_rig
	range_px = wander
	_rng.seed = seed_value
	_phase = _rng.randf() * TAU
	facing = 1.0 if _rng.randf() < 0.5 else -1.0
	shown_facing = facing
	_blink_in = _rng.randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
	_ear_in = _rng.randf_range(EAR_EVERY.x, EAR_EVERY.y)
	_swish_in = _rng.randf_range(SWISH_EVERY.x, SWISH_EVERY.y)
	_enter(State.IDLE, _rng.randf_range(0.2, 3.0))  # start out of step with the others


func is_bird() -> bool:
	return rig.type == "bird"


func update(delta: float) -> void:
	delta = minf(delta, 0.1)  # a long frame (a hitch, the app resuming) doesn't fling animals across the farm
	pose.time += delta
	_left -= delta
	if state == State.WALK or state == State.FROLIC:
		_walk(delta)
	if _left <= 0.0:
		_choose_next()
	_ease_body(delta)
	_idle_motions(delta)
	shown_facing = move_toward(shown_facing, facing, delta * TURN_SPEED)


## Seconds left in what it's doing (tests).
func time_left() -> float:
	return _left


func _choose_next() -> void:
	var weights := rig.behaviour()
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var pick := _rng.randf() * maxf(total, 0.001)
	var next := "idle"
	for k in weights:
		pick -= float(weights[k])
		if pick <= 0.0:
			next = str(k)
			break
	match next:
		"walk":
			_start_walk()
		"frolic":
			_start_walk(true)
		"graze", "peck":
			_enter(State.GRAZE)
		"look":
			_look_to = _rng.randf_range(-1.0, 1.0)
			_enter(State.LOOK)
		"flap":
			_enter(State.FLAP)
		"display":
			_enter(State.DISPLAY)
		_:
			_enter(State.IDLE)


func _enter(s: State, seconds := -1.0) -> void:
	state = s
	var d: Vector2 = DURATIONS[s]
	_left = seconds if seconds >= 0.0 else _rng.randf_range(d.x, d.y)


func _start_walk(frolic := false) -> void:
	# A spot inside the wander ellipse, far enough away to be worth the walk.
	for attempt in 6:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf())
		var to := Vector2(cos(a) * range_px.x, sin(a) * range_px.y) * r
		if _norm(to - offset) >= MIN_WALK or attempt == 5:
			_target = to
			break
	if absf(_target.x - offset.x) > 1.0:
		facing = signf(_target.x - offset.x)
	_enter(State.FROLIC if frolic else State.WALK)


## Distance in units of the wander ellipse (1 = its edge).
func _norm(v: Vector2) -> float:
	return Vector2(v.x / maxf(range_px.x, 0.001), v.y / maxf(range_px.y, 0.001)).length()


func _walk(delta: float) -> void:
	var to := _target - offset
	if to.length() <= ARRIVED:
		if state == State.FROLIC and _rng.randf() < FROLIC_AGAIN:
			_start_walk(true)  # and off again
		else:
			_enter(State.IDLE)
		return
	# Speed follows the legs: slow while they blend in, full once walking.
	var speed := rig.num("speed", 10.0) * rig.scale * (FROLIC_SPEED if state == State.FROLIC else 1.0)
	var step := minf(to.length(), speed * delta * maxf(pose.stride, 0.15))
	offset += to.normalized() * step
	pose.gait = fposmod(pose.gait + step / maxf(rig.cycle_length(), 0.001), 1.0)


func _ease_body(delta: float) -> void:
	var walking := state == State.WALK or state == State.FROLIC
	pose.stride = move_toward(pose.stride, 1.0 if walking else 0.0, delta * STRIDE_EASE)
	var head_to := 0.0
	var look_to := 0.0
	match state:
		State.GRAZE:
			if is_bird():
				# Pecking: quick dips, a pause, more dips.
				var p := sin(pose.time * PECK_RATE * TAU + _phase)
				head_to = 1.0 if p > 0.35 else 0.15
			else:
				head_to = 1.0
		State.LOOK:
			look_to = _look_to
		State.WALK:
			look_to = 0.0
	var rate := HEAD_DOWN_EASE if head_to > pose.head else HEAD_UP_EASE
	if is_bird():
		rate *= 4.0  # birds peck fast
	pose.head = move_toward(pose.head, head_to, delta * rate)
	pose.look = lerpf(pose.look, look_to, 1.0 - exp(-delta * 4.0))
	pose.jaw = sin(pose.time * 11.0) * pose.head if state == State.GRAZE and not is_bird() else 0.0
	pose.wing = move_toward(pose.wing, 1.0 if state == State.FLAP else 0.0, delta * 9.0)
	pose.display = move_toward(pose.display, 1.0 if state == State.DISPLAY else 0.0, delta * 2.5)
	if rig.type == "hop":
		pose.hop = absf(sin(pose.gait * TAU)) * pose.stride
	elif state == State.FROLIC:
		pose.hop = pow(absf(sin(pose.time * BOUNCE_RATE * PI + _phase)), 0.7) * pose.stride
	else:
		pose.hop = move_toward(pose.hop, 0.0, delta * 6.0)


func _idle_motions(delta: float) -> void:
	pose.breath = sin(pose.time * 2.1 + _phase)
	# Blink.
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_left = BLINK_TIME
		_blink_in = _rng.randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
	_blink_left = maxf(0.0, _blink_left - delta)
	pose.blink = sin(PI * _blink_left / BLINK_TIME) if _blink_left > 0.0 else 0.0
	# Ear flick.
	_ear_in -= delta
	if _ear_in <= 0.0:
		_ear_left = EAR_TIME
		_ear_in = _rng.randf_range(EAR_EVERY.x, EAR_EVERY.y)
	_ear_left = maxf(0.0, _ear_left - delta)
	pose.ear = sin(PI * _ear_left / EAR_TIME) if _ear_left > 0.0 else 0.0
	# The tail sways gently, with a proper swish now and then (at flies).
	_swish_in -= delta
	if _swish_in <= 0.0:
		_swish_left = SWISH_TIME
		_swish_in = _rng.randf_range(SWISH_EVERY.x, SWISH_EVERY.y)
	_swish_left = maxf(0.0, _swish_left - delta)
	var swish := sin(PI * _swish_left / SWISH_TIME) if _swish_left > 0.0 else 0.0
	pose.tail = sin(pose.time * 1.4 + _phase) * 0.12 + swish * sin(pose.time * 10.0) * 0.45 \
		+ pose.stride * sin(pose.gait * TAU * 2.0) * 0.1
