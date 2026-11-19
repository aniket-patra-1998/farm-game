class_name AnimalGait
extends RefCounted
## How an animal's legs walk: a foot's step cycle and a two-bone limb's middle joint. The 2D drawing (AnimalArt)
## and the 3D animals (Animal3D) both walk by it; kept apart so the 3D farm's start never compiles the 2D drawing
## (docs/PERF_RUN.md, the start).

const STRIDE := 0.7          # a foot's reach, front to back, as a share of the leg's length
const STANCE := 0.62         # share of the walk cycle each foot is on the ground
const LIFT := 0.3            # how high a stepping foot lifts, as a share of the leg's length


## Where a foot is, relative to its resting spot, `u` (0..1) of the way through its own step cycle:
## on the ground it slides back by exactly `reach` (the body walks forward that far), then lifts and
## swings forward again.
static func foot_offset(u: float, reach: float, lift: float) -> Vector2:
	if u < STANCE:
		var t := u / STANCE
		return Vector2(lerpf(0.5, -0.5, t) * reach, 0.0)
	var s := (u - STANCE) / (1.0 - STANCE)
	return Vector2(lerpf(-0.5, 0.5, smoothstep(0.0, 1.0, s)) * reach, -sin(PI * s) * lift)


## The middle joint of a two-bone limb from `hip` to `foot` (bones `a` and `b` long). bend 1 puts the
## joint behind the line (a hock), -1 in front (a knee). A foot out of reach straightens the limb.
static func joint(hip: Vector2, foot: Vector2, a: float, b: float, bend: float) -> Vector2:
	var d := foot - hip
	var dist := clampf(d.length(), 0.001, a + b - 0.001)
	var dir := d.normalized() if d.length() > 0.001 else Vector2.DOWN
	var along := (a * a - b * b + dist * dist) / (2.0 * dist)
	var out := sqrt(maxf(0.0, a * a - along * along))
	return hip + dir * along + Vector2(-dir.y, dir.x) * out * bend
