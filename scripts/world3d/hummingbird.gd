class_name Hummingbird
extends Node3D
## A hummingbird that calls at a limited tree (owner, 20 Nov): it flies in, circles the crown, slips in among the
## leaves as if its nest were there, comes out after a while and is off. One bird, for show: TreeLife sends it
## (`visit`) and steps it (`tick`); nothing here changes the game.

enum Phase { AWAY, COME, CIRCLE, ENTER, NEST, OUT, GO }

const BACK := Color("#1f9d6e")     # its back and head: a green that shines
const THROAT := Color("#d43a5c")
const BELLY := Color("#eef2e6")
const BEAK := Color("#2a2a2e")
const WING := Color("#3a5a52")
const SHINE := 0.6
const SIZE := 0.13            # its body's length (tiles): small, yet seen from the farm's camera
const BEAT := 46.0            # its wings' beat (radians a second: a blur)
const SWEEP := 1.0            # how far a wing swings each way (radians)
const CIRCLE_R := 1.3         # how far out it circles, of the crown's reach
const NEST_R := 0.15          # ..and how far in it goes
const TURNS := 2.25           # times round the crown before it goes in
const TURN_TIME := 2.6        # seconds a turn takes
const FAR := Vector3(5.0, 1.6, 0.0)   # how far off, and how much higher, it comes from and leaves to (tiles)
const COME_TIME := 2.0        # seconds it takes to arrive, and to leave
const IN_TIME := 0.9          # ..to slip in among the leaves, and to come out
const NEST_TIME := Vector2(3.0, 6.0)  # ..and it stays inside
const BOB := 0.05             # how far it rises and dips as it flies (tiles)
const BOB_BEAT := 3.1         # ..radians a second
const OUT_TURN := 2.0         # where it comes out, round from where it went in (radians)

var phase := Phase.AWAY

var _wings: Array[Node3D] = []
var _crown := Vector3.ZERO
var _reach := 0.5
var _from := 0.0              # the angle it arrives at
var _age := 0.0               # seconds into this phase
var _nest := 4.0
var _flown := 0.0


func _init() -> void:
	visible = false
	_build()


## Whether it is off the farm (free to be sent to a tree).
func away() -> bool:
	return phase == Phase.AWAY


## Calls at the crown at `crown` whose leaves reach `reach` out, arriving from angle `from` and staying inside
## `nest` seconds.
func visit(crown: Vector3, reach: float, from: float, nest: float) -> void:
	_crown = crown
	_reach = reach
	_from = from
	_nest = nest
	_start(Phase.COME)
	visible = true
	_place()


## Gone at once (the farm on screen changed).
func leave() -> void:
	phase = Phase.AWAY
	visible = false


## One step of `delta` seconds.
func tick(delta: float) -> void:
	if phase == Phase.AWAY:
		return
	_age += delta
	_flown += delta
	if _age >= time_of(phase):
		_next()
	if phase != Phase.AWAY:
		_place()


## How long phase `p` lasts (seconds).
func time_of(p: Phase) -> float:
	match p:
		Phase.COME, Phase.GO:
			return COME_TIME
		Phase.CIRCLE:
			return TURNS * TURN_TIME
		Phase.ENTER, Phase.OUT:
			return IN_TIME
		Phase.NEST:
			return _nest
	return 0.0


func _start(p: Phase) -> void:
	phase = p
	_age = 0.0


func _next() -> void:
	if phase == Phase.GO:
		leave()
		return
	_start((phase + 1) as Phase)
	visible = phase != Phase.NEST   # (inside, the leaves hide it)


## Puts the bird where this moment of its call has it, facing the way it flies, wings beating.
func _place() -> void:
	var u := clampf(_age / maxf(time_of(phase), 0.001), 0.0, 1.0)
	var at := _at(u)
	var ahead := _at(minf(u + 0.02, 1.0)) if u < 0.98 else at + (at - _at(u - 0.02))
	position = at + Vector3(0, sin(_flown * BOB_BEAT) * BOB, 0)
	if not ahead.is_equal_approx(at):
		look_at_from_position(position, position + (ahead - at), Vector3.UP)
	# Going in, it dwindles among the leaves; coming out, it grows back.
	var size := 1.0 - u if phase == Phase.ENTER else (u if phase == Phase.OUT else 1.0)
	scale = Vector3.ONE * maxf(size, 0.05)
	var swing := sin(_flown * BEAT) * SWEEP
	_wings[0].rotation.z = swing
	_wings[1].rotation.z = -swing


## Where it is `u` of the way through this phase.
func _at(u: float) -> Vector3:
	var ring := _reach * CIRCLE_R
	var turned := _from + TURNS * TAU
	match phase:
		Phase.COME:
			return _far(_from).lerp(_round(_from, ring), ease(u, -2.0))
		Phase.CIRCLE:
			return _round(_from + u * TURNS * TAU, ring)
		Phase.ENTER:
			return _round(turned + u, lerpf(ring, _reach * NEST_R, u))
		Phase.OUT:
			return _round(turned + OUT_TURN + u, lerpf(_reach * NEST_R, ring, u))
		Phase.GO:
			return _round(turned + OUT_TURN + 1.0, ring).lerp(_far(turned + OUT_TURN + 1.0), ease(u, 2.0))
	return _round(turned, _reach * NEST_R)


func _round(angle: float, r: float) -> Vector3:
	return _crown + Vector3(cos(angle), 0, sin(angle)) * r


func _far(angle: float) -> Vector3:
	return _crown + Vector3(cos(angle) * FAR.x, FAR.y, sin(angle) * FAR.x)


## The bird, its beak towards -Z (the way a node looks): body, pale belly, head with a ruby throat, a long thin
## beak, a tail and two wings that turn at the shoulder.
func _build() -> void:
	var s := SIZE
	var back := ModelKit.paint(BACK, SHINE)
	ModelKit.ball(self, Vector3.ZERO, s * 0.5, back, Vector3(0.6, 0.62, 1.0), true)
	ModelKit.ball(self, Vector3(0, -s * 0.08, -s * 0.04), s * 0.42, ModelKit.paint(BELLY), Vector3(0.55, 0.55, 0.9), true)
	ModelKit.ball(self, Vector3(0, s * 0.2, -s * 0.44), s * 0.26, back, Vector3.ONE, true)
	ModelKit.ball(self, Vector3(0, s * 0.08, -s * 0.5), s * 0.19, ModelKit.paint(THROAT, SHINE), Vector3.ONE, true)
	ModelKit.box(self, Vector3(-s * 0.03, s * 0.17, -s * 1.25), Vector3(s * 0.03, s * 0.22, -s * 0.62),
		ModelKit.paint(BEAK))
	ModelKit.box(self, Vector3(-s * 0.14, -s * 0.02, s * 0.4), Vector3(s * 0.14, s * 0.03, s * 0.85), ModelKit.paint(WING))
	for side: float in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * s * 0.2, s * 0.14, -s * 0.1)
		add_child(shoulder)
		ModelKit.box(shoulder, Vector3(minf(0.0, side * s * 0.95), -s * 0.015, -s * 0.2),
			Vector3(maxf(0.0, side * s * 0.95), s * 0.015, s * 0.22), ModelKit.paint(WING))
		_wings.append(shoulder)
	ModelKit.no_shadows(self)
