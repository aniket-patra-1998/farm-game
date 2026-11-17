class_name AnimalBehaviour
extends RefCounted
## What one animal is doing. FarmVille's animals stood, wandered a little near their spot and ate; this
## keeps that rhythm and adds our own touch: real walk cycles, grazing and chewing, looking around, the
## odd flap or tail fan, and babies of every species sharing one temperament (their rig's young
## behaviour): restless, with bursts of bouncing play. Runs a small state machine and writes an
## AnimalPose every frame; the animal's piece reads `offset` and `facing`.
##
## Every value eases toward its target (no snapping), the walk cycle advances with the ground actually
## walked (so feet stay planted), and each animal has its own random stream, seeded by its uid, so a farm
## looks the same every time it loads but no two animals move in step.

enum State { IDLE, WALK, GRAZE, LOOK, FLAP, DISPLAY, FROLIC, SLEEP }

const TURN_SPEED := 7.0          # facing changes through 0: the body narrows, then widens the other way
const STRIDE_EASE := 7.0         # how fast the legs blend between standing and walking
const HEAD_DOWN_EASE := 3.2      # lowering the head to graze
const HEAD_UP_EASE := 5.0
const PECK_RATE := 1.1           # pecks a second while pecking (a hen's unhurried dips, not a woodpecker)
const BIRD_HEAD := 2.0           # a bird lowers and lifts its head this many times as fast as a grazer
const BLINK_EVERY := Vector2(2.0, 6.0)
const BLINK_TIME := 0.13
const EAR_EVERY := Vector2(2.5, 8.0)
const EAR_TIME := 0.35
const SWISH_EVERY := Vector2(3.0, 9.0)
const SWISH_TIME := 1.2
const START_SPREAD := 0.85      # how far into its wander range an animal starts (of the range)
const MIN_WALK := 0.35           # a walk covers at least this share of the wander range
const ARRIVED := 0.6             # px
const FROLIC_SPEED := 2.4        # a frolic is a dash: this many times walking speed
const AIR := 0.8                 # of a bounding stride it is off the ground; the rest it lands and gathers
const AIR_PACE := 1.2            # it covers ground faster in the air than its even pace..
const LAND_PACE := 0.4           # ..and checks as it lands (its weight comes down before it springs again)
const TURN_FREE := 0.5           # radians off its way it may be and still walk on (it curves round)
const TURN_HOLD := 1.6           # this far off it stands and comes round first: it never walks sideways
const SHUFFLE := 0.45            # how much of a stride its legs take stepping round on the spot
const SHUFFLE_FOR := 0.2         # seconds its legs stay ready after the last step of a turn
const JUMP_TIME := 0.32          # seconds a tapped animal's start takes, up and down
const FROLIC_AGAIN := 0.45       # chance a frolic runs straight into another
const POKE_LOOK := 1.6           # seconds a tapped animal looks round at you
const HUNGRY_SHARE := 0.7        # of a hungry animal's choices that are to look up and about for feed
const SLEEP_SHARE := 0.85        # of an animal's choices at night that are to sleep
const SLEEP_HEAD := 0.75         # how low a sleeping animal's head hangs (1: grazing)
const SLEEP_BREATH := 1.1        # a sleeper's breathing, slower than awake (2.1)
const POKE_HOP := 0.45           # how high it starts when tapped (of a frolic's bounce)
const DRINK_SHARE := 0.2         # of the choices of an animal with water near that are to go and drink
const DRINK_REACH := 4.0         # how far past its wander range it may go for a drink (times the range)

const DURATIONS := {
	State.IDLE: Vector2(1.5, 4.0),
	State.WALK: Vector2(2.0, 6.0),     # the most a walk may take
	State.GRAZE: Vector2(3.0, 7.0),
	State.LOOK: Vector2(1.2, 2.6),
	State.FLAP: Vector2(0.6, 0.9),
	State.DISPLAY: Vector2(2.5, 4.0),
	State.FROLIC: Vector2(1.0, 2.2),
	State.SLEEP: Vector2(9.0, 20.0),   # a doze: then it may stir, look about, and doze again
}

## Night on the farm (Main sets it from the day's light; never with "always daytime"): the animals sleep.
static var night := false


var rig: AnimalRig
var pose := AnimalPose.new()
var state: State = State.IDLE
var offset := Vector2.ZERO       ## from the animal's home spot (its tile centre), in px
var facing := 1.0                ## the way it's heading: 1 right, -1 left
var shown_facing := 1.0          ## eases toward facing (the turn)
var range_px := Vector2(14, 7)   ## how far it may wander: an ellipse, flattened like the ground
var hungry := false              ## its home is waiting to be fed (BuildingFill): it looks about instead of grazing
var noticed := 0.0               ## seconds left looking at whoever tapped it
var drink_at := Vector2.INF      ## water near enough to drink from, from its home spot, in px (BuildingFill)
var drinking := false            ## it has gone to the water and has its head down to it
var stride_tiles := 0.0          ## the ground one cycle of its legs covers, in tiles (its body says: Animal3D)
var going := Vector2.ZERO        ## the way it is walking, in px (a direction; zero while it stays where it is)

var _rng := RandomNumberGenerator.new()
var _left := 0.0                 # seconds left in this state
var _target := Vector2.ZERO
var _to_drink := false           # the walk it is on ends at the water
var _look_to := 0.0
var _blink_in := 0.0
var _blink_left := 0.0
var _ear_in := 0.0
var _ear_left := 0.0
var _swish_in := 0.0
var _swish_left := 0.0
var _phase := 0.0                # a per-animal offset for the slow idle motions
var _off_course := 0.0           # radians its body still has to come round to face its way (turned)
var _shuffle := 0.0              # seconds its legs stay stepping after a turn on the spot
var _jump := 0.0                 # seconds left of the start it gives when tapped


func _init(animal_rig: AnimalRig, seed_value: int, wander: Vector2) -> void:
	rig = animal_rig
	range_px = wander
	_rng.seed = seed_value
	_phase = _rng.randf() * TAU
	facing = 1.0 if _rng.randf() < 0.5 else -1.0
	shown_facing = facing
	# Each starts somewhere of its own inside its range, so a row of animals never stands in a straight line.
	var a := _rng.randf() * TAU
	offset = Vector2(cos(a) * range_px.x, sin(a) * range_px.y) * sqrt(_rng.randf()) * START_SPREAD
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
	noticed = maxf(noticed - delta, 0.0)
	_shuffle = maxf(_shuffle - delta, 0.0)
	if state == State.WALK or state == State.FROLIC:
		_walk(delta)
	else:
		going = Vector2.ZERO
	if _left <= 0.0:
		_choose_next()
	_ease_body(delta)
	_idle_motions(delta)
	shown_facing = move_toward(shown_facing, facing, delta * TURN_SPEED)


## Seconds left in what it's doing (tests).
## Tapped: it stops what it's doing, gives a little start (a hop, or a flap for a bird) and looks round at
## you for a moment before carrying on.
func poke() -> void:
	_enter(State.LOOK, POKE_LOOK)
	noticed = POKE_LOOK
	_look_to = 1.0
	_target = offset
	_jump = JUMP_TIME
	if is_bird():
		pose.wing = 1.0


func time_left() -> float:
	return _left


func _choose_next() -> void:
	drinking = false
	# At night most of what an animal does is sleep where it stands: head low, eyes shut, breathing slow. Now and
	# then one stirs (the rest of the time's choices), so a sleeping farm is still alive.
	if night and _rng.randf() < SLEEP_SHARE:
		_enter(State.SLEEP)
		return
	# Hungry (its home's trough is empty): it leaves off grazing and playing and looks up and about for its feed.
	if hungry and _rng.randf() < HUNGRY_SHARE:
		_look_to = _rng.randf_range(0.2, 1.0)
		_enter(State.LOOK)
		return
	# Water near (a trough in its yard): now and then it walks up to it and drinks, its head down to the water.
	if drink_at.is_finite() and _rng.randf() < DRINK_SHARE:
		_target = drink_at / maxf(_norm(drink_at) / DRINK_REACH, 1.0)   # (as near as it may stray)
		if absf(_target.x - offset.x) > 1.0:
			facing = signf(_target.x - offset.x)
		_to_drink = true
		_enter(State.WALK)
		return
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
		going = Vector2.ZERO
		if state == State.FROLIC and _rng.randf() < FROLIC_AGAIN:
			_start_walk(true)  # and off again
		elif _to_drink:
			_to_drink = false
			drinking = true
			_enter(State.GRAZE)
		else:
			_enter(State.IDLE)
		return
	# It goes at the pace of its legs: one cycle of them carries it one stride over the ground, whichever way
	# that is on the screen (a pixel up the screen is twice the ground of a pixel across), so its feet grip.
	# Slow while the legs blend in; standing to come round first when it faces the wrong way.
	going = to.normalized()
	var per_px := IsoProjection.ground_of(going).length()
	var stride := stride_on_ground()
	var speed := stride * rig.num("speed", 10.0) * rig.scale / maxf(rig.cycle_length(), 0.001)
	speed *= (FROLIC_SPEED if state == State.FROLIC else 1.0) * _flight_pace()
	speed *= 1.0 - smoothstep(TURN_FREE, TURN_HOLD, _off_course)
	var ground := minf(to.length() * per_px, speed * delta * maxf(pose.stride, 0.15))
	offset += going * ground / per_px
	pose.gait = fposmod(pose.gait + ground / stride, 1.0)


## The ground one cycle of its legs covers, in tiles: what its body measured (`stride_tiles`), or, with no
## body, its rig's stride as drawn across the screen.
func stride_on_ground() -> float:
	if stride_tiles > 0.0:
		return stride_tiles
	return maxf(IsoProjection.ground_of(Vector2(rig.cycle_length(), 0)).length(), 0.001)


## Its body says how it stands to where it is going (Animal3D, every frame): `off` radians it still has to
## come round, and `feet` tiles the turn it just made carried its feet. It steps round on the spot as it
## turns, and `_walk` waits for it to face its way, so its feet never slide.
func turned(off: float, feet: float) -> void:
	_off_course = off
	if feet > 0.0:
		pose.gait = fposmod(pose.gait + feet / stride_on_ground(), 1.0)
		_shuffle = SHUFFLE_FOR


## How high a bounding animal is at `u` of its stride (0..1), 0 on the ground .. 1 at the top: it springs up
## and falls as a thrown thing does, then is down for the rest of the stride, gathering for the next (a ball
## bounces straight back up; a body does not).
static func bound(u: float) -> float:
	var t := fposmod(u, 1.0) / AIR
	return 4.0 * t * (1.0 - t) if t < 1.0 else 0.0


## Whether its going is a bounding one: a hopper's always, anyone's frolic.
func _bounds() -> bool:
	return rig.type == "hop" or state == State.FROLIC


func _flight_pace() -> float:
	if not _bounds():
		return 1.0
	return AIR_PACE if pose.gait < AIR else LAND_PACE


func _ease_body(delta: float) -> void:
	var walking := state == State.WALK or state == State.FROLIC
	# (standing to come round, or stepping round on the spot, its legs take part of a stride)
	var stride_to := lerpf(1.0, SHUFFLE, smoothstep(TURN_FREE, TURN_HOLD, _off_course)) if walking else (
		SHUFFLE if _shuffle > 0.0 else 0.0)
	pose.stride = move_toward(pose.stride, stride_to, delta * STRIDE_EASE)
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
		State.SLEEP:
			head_to = SLEEP_HEAD
			if not night:
				_left = minf(_left, 0.5)   # (dawn: it wakes)
	var rate := HEAD_DOWN_EASE if head_to > pose.head else HEAD_UP_EASE
	if is_bird():
		rate *= BIRD_HEAD  # a bird's head moves quicker than a cow's, though not in a blur
	pose.head = move_toward(pose.head, head_to, delta * rate)
	pose.look = lerpf(pose.look, look_to, 1.0 - exp(-delta * 4.0))
	pose.jaw = sin(pose.time * 11.0) * pose.head if state == State.GRAZE and not is_bird() else 0.0
	pose.wing = move_toward(pose.wing, 1.0 if state == State.FLAP else 0.0, delta * 9.0)
	pose.display = move_toward(pose.display, 1.0 if state == State.DISPLAY else 0.0, delta * 2.5)
	if _jump > 0.0:
		_jump = maxf(_jump - delta, 0.0)
		var t := 1.0 - _jump / JUMP_TIME
		pose.hop = POKE_HOP * 4.0 * t * (1.0 - t)
	elif walking and _bounds():
		pose.hop = bound(pose.gait) * pose.stride
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
	if state == State.SLEEP:
		pose.blink = 1.0   # eyes shut
		pose.breath = sin(pose.time * SLEEP_BREATH + _phase)
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
