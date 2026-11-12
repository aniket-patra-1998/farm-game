class_name VehicleMotion
extends RefCounted
## How a vehicle drives, as a few springs (like AnimalMotion for animals): speed eases toward its target with the
## machine's own pull and braking, the heading follows the road late (a heavy one turns late), and the body rides
## on suspension: the ground's ruts push it up and down, braking and pulling tip it forward and back, a turn
## leans it out, and the engine shakes it a little all the time. Weight is the one dial, 0 (light) to 1 (heavy);
## data/vehicle_motion.json holds the two ends. Pure numbers, no nodes, so the same input always gives the same
## drive and a test can check it.

const DATA := "res://data/vehicle_motion.json"
const MAX_STEP := 1.0 / 60.0   # a longer frame is split, so the springs stay steady on a slow phone

static var _data := {}

var weight := 0.5
var feel := {}            # the numbers for this weight
var speed := 0.0          # tiles per second now
var distance := 0.0       # tiles driven
var yaw := 0.0            # heading, radians (0 = along +x)
var yaw_rate := 0.0
var bob := 0.0            # body height over its rest, in model units (up is positive)
var bob_speed := 0.0
var pitch := 0.0          # nose up is positive
var pitch_speed := 0.0
var roll := 0.0           # leaning to the outside of a turn
var roll_speed := 0.0
var clock := 0.0


func _init(w := 0.5) -> void:
	weight = clampf(w, 0.0, 1.0)
	feel = feel_for(weight)


## The two ends of data/vehicle_motion.json blended at `w`.
static func feel_for(w: float) -> Dictionary:
	var d := _load()
	var light: Dictionary = d["light"]
	var heavy: Dictionary = d["heavy"]
	var out := {}
	for k: String in light:
		out[k] = lerpf(float(light[k]), float(heavy[k]), clampf(w, 0.0, 1.0))
	return out


static func dust_colour(job: String) -> Color:
	var cols: Dictionary = _load()["dust_colour"]
	return Color.html(str(cols.get(job, cols["all"])))


static func smoke_colour() -> Color:
	return Color.html(str(_load()["smoke_colour"]))


static func _load() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed as Dictionary if parsed is Dictionary else {}
	return _data


## Moves on by `delta` seconds toward `target_speed` (tiles per second) and a heading of `target_yaw`.
func step(delta: float, target_speed: float, target_yaw: float) -> void:
	var left := delta
	while left > 0.0:
		var dt := minf(left, MAX_STEP)
		_step(dt, target_speed, target_yaw)
		left -= dt


func _step(dt: float, target_speed: float, target_yaw: float) -> void:
	clock += dt
	# Speed: pulls with `accel`, brakes harder than it pulls.
	var before := speed
	var rate := float(feel["accel"]) if target_speed > speed else float(feel["brake"])
	speed = move_toward(speed, target_speed, rate * dt)
	var accel := (speed - before) / dt
	distance += speed * dt
	# Heading: a critically damped follow, slower the heavier it is; it can't turn much standing still.
	var turn := float(feel["turn_speed"])
	var diff := wrapf(target_yaw - yaw, -PI, PI)
	var moving := clampf(speed / maxf(float(feel["speed"]) * 0.35, 0.01), 0.0, 1.0)
	var want_rate := diff * turn * moving
	yaw_rate = lerpf(yaw_rate, want_rate, 1.0 - exp(-turn * dt))
	yaw += yaw_rate * dt
	# Suspension: the ground's ruts (a few sines of the distance driven) push the body; the spring lets it sink
	# and settle. Underdamped, so a heavy one wallows a little after a bump.
	var k := float(feel["spring"])
	var zeta := float(feel["damping"])
	var ruts := (sin(distance * 9.0) + 0.5 * sin(distance * 23.0 + 1.3)) * minf(speed, 1.5) / 1.5
	bob_speed += (k * k * (float(feel["bump"]) * ruts - bob) - 2.0 * zeta * k * bob_speed) * dt
	bob += bob_speed * dt
	# Pitch: tips back when pulling away, forward when braking, and a little with every rut.
	var pitch_goal := accel * float(feel["pitch_per_accel"]) + ruts * float(feel["bump_pitch"]) * 0.3
	pitch_speed += (k * k * (pitch_goal - pitch) - 2.0 * zeta * k * pitch_speed) * dt
	pitch += pitch_speed * dt
	# Roll: leans out of a turn (turning toward +z leans toward -z).
	var roll_goal := -yaw_rate * minf(speed, 3.0) * float(feel["roll_per_turn"])
	roll_speed += (k * k * (roll_goal - roll) - 2.0 * zeta * k * roll_speed) * dt
	roll += roll_speed * dt


## How high the body sits over its rest now, in model units: the suspension's travel plus the engine's shake
## (which goes straight into the body, the springs are too soft to pass it on).
func lift() -> float:
	var shake := float(feel["rumble"]) * sin(clock * TAU * float(feel["rumble_hz"]))
	return bob + shake * (0.4 + 0.6 * clampf(speed / float(feel["speed"]), 0.0, 1.0))


## The body's lean: nose up/down about z, and over to the side about x.
func lean() -> Basis:
	return Basis(Vector3.BACK, pitch) * Basis(Vector3.RIGHT, roll)


## Dust thrown up per second at the speed now (none standing still).
func dust_rate() -> float:
	return float(feel["dust_per_second"]) * clampf(speed / float(feel["speed"]), 0.0, 1.0)


## Exhaust puffs per second: it works harder under way.
func smoke_rate() -> float:
	return float(feel["smoke_per_second"]) * (0.5 + 0.5 * clampf(speed / float(feel["speed"]), 0.0, 1.0))
