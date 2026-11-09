class_name AnimalMotion
extends RefCounted
## The weight of an animal's body: the secondary motion a mind doesn't decide but a body has, worked out
## with springs so it overshoots and settles like flesh does instead of snapping. It leans into the turns,
## lifts its front as it sets off and dips it as it pulls up; its hips sway with its steps; its head lags
## a turn and then catches up, stays steadier than its bobbing body, and turns to look at you when you tap
## it; its tail and ears swing on after the body moves; it squashes when it lands from a hop; and standing
## a while, it rests a hind leg and shifts its weight. It changes into a trot when it runs.
##
## One per 3D animal (Animal3D owns it); fed the animal's speed and turning every frame.

const MAX_STEP := 1.0 / 30.0     # a long frame is taken in steps no longer than this (springs stay stable)
const LEAN_ACCEL := 0.035        # radians of pitch per (walking speeds per second) of speeding up or slowing
const LEAN_TURN := 0.025         # radians of roll per (radian/s of turn x walking speeds)
const MAX_LEAN := 0.16
const SWAY := 0.045              # radians the hips roll with each step
const HEAD_LAG := 0.85           # how far behind a turn the head is left (share of the turn's rate)
const TAIL_SWING := 0.32         # radians of tail swing per radian/s of turn
const SQUASH := 0.16             # how much it squashes landing from its highest hop
const REST_EVERY := Vector2(7.0, 16.0)   # seconds standing still between resting a leg
const REST_FOR := Vector2(3.0, 7.0)
const TROT_FROM := 1.4           # speed, in walking speeds, where a walk becomes a trot

## Phases of the four legs (hind far, fore far, hind near, fore near) in a walk and a trot.
const WALK := [0.5, 0.75, 0.0, 0.25]
const TROT := [0.5, 0.0, 0.0, 0.5]

var pitch := 0.0      ## the body's nose-up (+) or nose-down lean, radians
var roll := 0.0       ## its lean to the near (+) or far side, radians
var head_yaw := 0.0   ## the head's turn from straight ahead, radians (+ toward the far side)
var head_steady := 0.0  ## how much of the body's bob the head takes out (0..1)
var tail := 0.0       ## the tail's swing, radians
var ears := 0.0       ## the ears' swing, radians
var squash := 0.0     ## 0 none .. how flattened the body is from landing
var rest := 0.0       ## 0 standing square .. 1 resting a hind leg
var trot := 0.0       ## 0 walking .. 1 trotting

var _pitch := Spring.new()
var _roll := Spring.new()
var _head := Spring.new()
var _tail := Spring.new()
var _ears := Spring.new()
var _squash := Spring.new()
var _rest := Spring.new()
var _trot := Spring.new()
var _speed := 0.0
var _heading := 0.0
var _started := false
var _air := 0.0
var _rng := RandomNumberGenerator.new()
var _rest_in := 0.0
var _rest_left := 0.0


func _init(seed_value: int) -> void:
	_rng.seed = seed_value
	_rest_in = _rng.randf_range(REST_EVERY.x, REST_EVERY.y)


## One frame: how fast it's going (in walking speeds: 1 is its walk) and which way it faces, how high it
## is in a hop (0 on the ground), how much it's striding (0..1), and where it should look (yaw from
## straight ahead, and how keenly, 0..1).
func step(delta: float, speed: float, heading: float, hop: float, stride: float, look_yaw := 0.0,
		keen := 0.0) -> void:
	if not _started:
		_started = true
		_speed = speed
		_heading = heading
	var left := minf(delta, 0.25)
	while left > 0.0:
		var dt := minf(left, MAX_STEP)
		_step(dt, speed, heading, hop, stride, look_yaw, keen)
		left -= dt


func _step(dt: float, speed: float, heading: float, hop: float, stride: float, look_yaw: float,
		keen: float) -> void:
	var accel := (speed - _speed) / dt
	var turn := wrapf(heading - _heading, -PI, PI) / dt
	_speed = lerpf(_speed, speed, minf(dt * 12.0, 1.0))
	_heading = heading
	# Leaning: pitched by speeding up and slowing down, rolled into turns; the hips sway with the steps.
	# (Setting off, the hindquarters push and the front lifts; pulling up, the weight comes forward onto the
	# front. A turn leans it in toward the inside, which is its left, -z, for a turn to the left, +heading.)
	pitch = _pitch.step(clampf(accel * LEAN_ACCEL, -MAX_LEAN, MAX_LEAN), dt, 2.2, 0.45)
	roll = _roll.step(clampf(-turn * speed * LEAN_TURN, -MAX_LEAN, MAX_LEAN), dt, 2.6, 0.5)
	# The head lags a turn, then catches up past straight and settles; keenly, it looks where it's told.
	var want := lerpf(-turn * HEAD_LAG * 0.12, look_yaw, keen)
	head_yaw = _head.step(clampf(want, -1.1, 1.1), dt, 3.0 if keen > 0.1 else 1.8, 0.55)
	head_steady = clampf(stride, 0.0, 1.0) * 0.6
	# The tail and ears are carried round by the body, and swing on after it.
	tail = _tail.step(clampf(-turn * TAIL_SWING, -0.9, 0.9) + pitch * 1.5, dt, 1.6, 0.25)
	ears = _ears.step(clampf(-turn * 0.08 - accel * 0.02, -0.5, 0.5), dt, 2.4, 0.3)
	# Landing from a hop squashes it, and it springs back.
	if _air > 0.05 and hop <= 0.02:
		_squash.v -= _air * SQUASH * 18.0
	_air = hop
	squash = -_squash.step(0.0, dt, 4.0, 0.35)
	# Into a trot when it runs.
	trot = clampf(_trot.step(smoothstep(TROT_FROM - 0.25, TROT_FROM + 0.25, speed), dt, 3.0, 1.0), 0.0, 1.0)
	# Standing a while, it rests a hind leg, then stands square again before setting off.
	if stride > 0.05 or keen > 0.1:
		_rest_left = 0.0
		_rest_in = maxf(_rest_in, REST_EVERY.x * 0.5)
	elif _rest_left > 0.0:
		_rest_left -= dt
		if _rest_left <= 0.0:
			_rest_in = _rng.randf_range(REST_EVERY.x, REST_EVERY.y)
	else:
		_rest_in -= dt
		if _rest_in <= 0.0:
			_rest_left = _rng.randf_range(REST_FOR.x, REST_FOR.y)
	rest = _rest.step(1.0 if _rest_left > 0.0 else 0.0, dt, 1.2, 1.0)


## The phase of leg `k` (0 hind far, 1 fore far, 2 hind near, 3 fore near), between walk and trot (the
## short way round the cycle, so a leg never runs backwards through it).
func leg_phase(k: int) -> float:
	var a := float(WALK[k])
	return fposmod(a + wrapf(float(TROT[k]) - a, -0.5, 0.5) * trot, 1.0)


## A damped spring: pulled toward a target, it overshoots and settles (frequency in Hz; damping 1 settles
## without overshooting, less wobbles).
class Spring:
	var x := 0.0
	var v := 0.0

	func step(target: float, dt: float, frequency: float, damping: float) -> float:
		var w := TAU * frequency
		v += (w * w * (target - x) - 2.0 * damping * w * v) * dt
		x += v * dt
		return x
