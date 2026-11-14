class_name AnimalArt
extends RefCounted
## Animals, drawn in code from their rig (data/animal_rigs.json) and a pose (AnimalPose): a quadruped's four
## jointed legs walking a real gait, a bird's two legs, head bob and wings, a rabbit's hops. Called every
## frame for animals on the farm, and with a resting pose for previews and the art references.
##
## Everything is drawn in side view facing right; the animal's node flips it to face left. Drawing never
## changes the canvas transform (callers may have set one), so all rotation is done on the points here.
## Shapes: QuadrupedArt, BirdArt and SmallAnimalArt; the shared helpers are below.

const STRIDE := 0.7          # a foot's reach, front to back, as a share of the leg's length
const STANCE := 0.62         # share of the walk cycle each foot is on the ground
const LIFT := 0.3            # how high a stepping foot lifts, as a share of the leg's length
const OUTLINE := Color(0.16, 0.1, 0.06, 0.62)
const EYE := Color("#1b140f")
const HOOF := Color("#3a2c22")
const CREAM := Color("#fbf6ec")
const PINK := Color("#eba9a3")
const BUBBLE := Color("#fffaf0")
const BUBBLE_EDGE := Color("#5c3a1e")
const READY_LIFT := 22.0   # how far over an animal's top the ready sign hovers, in pixels

static var _circles := {}  # n -> unit circle points
static var _barrels := {}  # n -> unit barrel points


## Draws one animal standing on `ground` (the middle of its feet). Pass the animal's pose to animate it;
## without one it stands still.
static func draw(ci: CanvasItem, ground: Vector2, it: Dictionary, ready: bool, pose: AnimalPose = null) -> void:
	var p: AnimalPose = pose if pose != null else AnimalPose.rest()
	var rig := AnimalRig.of(it)
	var body := rig.body_color
	var accent := rig.accent_color
	var top: float
	match rig.type:
		"bird":
			top = BirdArt.draw(ci, ground, rig, p, body, accent)
		"hop":
			top = SmallAnimalArt.rabbit(ci, ground, rig, p, body, accent)
		"shell":
			top = SmallAnimalArt.turtle(ci, ground, rig, p, body, accent)
		"bug":
			top = SmallAnimalArt.bee(ci, ground, rig, p, body)
		_:
			top = QuadrupedArt.draw(ci, ground, rig, p, body, accent)
	if ready:   # the one ready sign everything wears, bobbing over the animal
		PlaceholderArt.draw_ready_marker(ci, Vector2(ground.x, top - READY_LIFT), p.time)


## A product bubble over an animal that's ready to collect; it bobs gently.
static func bubble(ci: CanvasItem, at: Vector2, product: Color, time: float) -> void:
	var c := at + Vector2(0, sin(time * 2.4) * 2.0)
	ci.draw_circle(c, 13.0, BUBBLE)
	ci.draw_arc(c, 13.0, 0.0, TAU, 28, BUBBLE_EDGE, 2.0, true)
	ci.draw_circle(c, 6.0, product)
	ci.draw_arc(c, 6.0, 0.0, TAU, 16, OUTLINE, 1.0, true)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 11), c + Vector2(4, 11), c + Vector2(-1, 18)]), BUBBLE)


# ---------------------------------------------------------------- walking


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


# ---------------------------------------------------------------- shapes


## Points around an ellipse, rotated by `angle` (from a cached unit circle: no trigonometry per point).
static func ellipse(c: Vector2, rx: float, ry: float, angle := 0.0, n := 20) -> PackedVector2Array:
	var unit := _circle(n)
	var pts := PackedVector2Array()
	pts.resize(n)
	var xf := Transform2D(angle, c) * Transform2D(Vector2(rx, 0), Vector2(0, ry), Vector2.ZERO)
	for i in n:
		pts[i] = xf * unit[i]
	return pts


static func _circle(n: int) -> PackedVector2Array:
	var pts: PackedVector2Array = _circles.get(n, PackedVector2Array())
	if pts.is_empty():
		pts.resize(n)
		for i in n:
			pts[i] = Vector2.from_angle(TAU * i / n)
		_circles[n] = pts
	return pts


## A filled shape with an outline.
static func fill(ci: CanvasItem, pts: PackedVector2Array, col: Color, k: float) -> void:
	ci.draw_colored_polygon(pts, col)
	outline(ci, pts, k)


## A filled shape, lit from above: lighter on top, darker underneath.
static func fill_lit(ci: CanvasItem, pts: PackedVector2Array, col: Color, k: float, outlined := true) -> void:
	var lo := INF
	var hi := -INF
	for v in pts:
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	var span := maxf(hi - lo, 0.001)
	var cols := PackedColorArray()
	var light := col.lightened(0.12)
	var dark := col.darkened(0.2)
	for v in pts:
		cols.append(light.lerp(dark, (v.y - lo) / span))
	ci.draw_polygon(pts, cols)
	if outlined:
		outline(ci, pts, k)


static func outline(ci: CanvasItem, pts: PackedVector2Array, k: float) -> void:
	var w := maxf(1.0, 1.5 * k)
	ci.draw_polyline(pts, OUTLINE, w, true)
	ci.draw_line(pts[pts.size() - 1], pts[0], OUTLINE, w, true)


## A tapered limb from a (width wa) to b (width wb), with rounded joints and outlined sides.
static func limb(ci: CanvasItem, a: Vector2, b: Vector2, wa: float, wb: float, col: Color, k: float) -> void:
	var d := b - a
	if d.length() < 0.5:
		ci.draw_circle(a, maxf(wa, wb) / 2.0, col)
		return
	var n := Vector2(-d.y, d.x).normalized()
	var l1 := a + n * wa / 2.0
	var l2 := b + n * wb / 2.0
	var r1 := a - n * wa / 2.0
	var r2 := b - n * wb / 2.0
	ci.draw_colored_polygon(PackedVector2Array([l1, l2, r2, r1]), col)
	ci.draw_circle(a, wa / 2.0, col)
	ci.draw_circle(b, wb / 2.0, col)
	var w := maxf(1.0, 1.2 * k)
	ci.draw_line(l1, l2, OUTLINE, w, true)
	ci.draw_line(r1, r2, OUTLINE, w, true)


## A leaf shape (an ear, a feather, a wing) from `base` pointing along `angle`.
static func leaf(base: Vector2, angle: float, length: float, width: float) -> PackedVector2Array:
	var dir := Vector2.from_angle(angle)
	var n := Vector2(-dir.y, dir.x)
	var mid := base + dir * length * 0.42
	return PackedVector2Array([
		base + n * width * 0.22, mid + n * width * 0.5, base + dir * length, mid - n * width * 0.5,
		base - n * width * 0.22])


## An eye that blinks: white, pupil, a glint; shut, it's a lid in the head's colour and a line.
static func eye(ci: CanvasItem, c: Vector2, r: float, blink: float, lid: Color, k: float) -> void:
	if blink > 0.6:
		ci.draw_circle(c, r, lid)
		ci.draw_line(c + Vector2(-r, 0), c + Vector2(r, 0.3), EYE, maxf(1.0, 1.1 * k), true)
		return
	ci.draw_circle(c, r, Color.WHITE)
	ci.draw_circle(c + Vector2(r * 0.15, 0), r * 0.7, EYE)
	ci.draw_circle(c + Vector2(r * 0.4, -r * 0.35), r * 0.25, Color.WHITE)
	if blink > 0.05:
		# The lid coming down.
		ci.draw_rect(Rect2(c - Vector2(r, r), Vector2(2.0 * r, 2.0 * r * blink)), lid)


static func shadow(ci: CanvasItem, c: Vector2, rx: float, ry: float, strength := 1.0) -> void:
	ci.draw_colored_polygon(ellipse(c, rx, ry, 0.0, 18), Color(0.05, 0.09, 0.03, 0.22 * strength))


## Points on a body-shaped superellipse (boxier than an ellipse, like a barrel); the unit shape is cached.
static func barrel(c: Vector2, rx: float, ry: float, angle := 0.0, n := 28) -> PackedVector2Array:
	var unit: PackedVector2Array = _barrels.get(n, PackedVector2Array())
	if unit.is_empty():
		unit.resize(n)
		for i in n:
			var a := TAU * i / n
			var sy := signf(sin(a)) * pow(absf(sin(a)), 0.77)
			unit[i] = Vector2(signf(cos(a)) * pow(absf(cos(a)), 0.77), sy * (1.06 if sy > 0.0 else 1.0))
		_barrels[n] = unit
	var xf := Transform2D(angle, c) * Transform2D(Vector2(rx, 0), Vector2(0, ry), Vector2.ZERO)
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		pts[i] = xf * unit[i]
	return pts


## Half the height of barrel() at x (from its centre): for bands and patches that follow the body.
static func barrel_half_height(x: float, rx: float, ry: float) -> float:
	var u := clampf(absf(x) / maxf(rx, 0.001), 0.0, 1.0)
	return ry * pow(maxf(0.0, 1.0 - pow(u, 2.6)), 1.0 / 2.6)
