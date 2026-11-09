class_name SmallAnimalArt
extends RefCounted
## The animals that don't walk on four long legs or two: a rabbit that hops (crouch, spring, land), a
## turtle that paddles along and pulls its head in, and a bee that hovers on blurred wings. See AnimalArt.

const NOSE := Color("#e48f98")
const SHELL_LINE := Color(0.18, 0.13, 0.06, 0.55)
const BEE_STRIPE := Color("#2a2118")
const WING := Color(0.92, 0.97, 1.0, 0.55)


## A rabbit: a round body that gathers on its big hind feet, springs and lands; ears that flick and,
## mid-hop, stream back; a twitching nose and a white puff of a tail.
static func rabbit(ci: CanvasItem, g: Vector2, rig: AnimalRig, p: AnimalPose, body: Color, accent: Color) -> float:
	var k := rig.scale
	var r := rig.pair("body", Vector2(12, 9))
	var air := p.hop * 7.0 * k
	var stretch := 1.0 + 0.18 * p.hop          # long in the air, gathered on the ground
	var crouch := 1.0 - 0.1 * p.stride * (1.0 - p.hop)
	var c := g + Vector2(0, -(r.y * 0.95 * crouch) - air + p.breath * 0.25 * k)
	var tilt := -0.25 * p.hop * signf(cos(p.gait * TAU)) - 0.08
	AnimalArt.shadow(ci, g + Vector2(0, 1.5), r.x * (1.1 - 0.3 * p.hop), r.y * 0.4, 1.0 - 0.5 * p.hop)
	# Hind foot: flat on the ground, then trailing behind in the air.
	var hind := Vector2(c.x - r.x * 0.35 - 6.0 * k * p.hop, minf(g.y, c.y + r.y * 0.9 + 3.0 * k))
	AnimalArt.fill(ci, AnimalArt.ellipse(hind + Vector2(2.0 * k, -1.0 * k), 6.0 * k, 2.4 * k, tilt * 0.5, 12),
		body.darkened(0.12), k)
	ci.draw_circle(c + Vector2(-r.x * 0.95, -r.y * 0.25).rotated(tilt), 3.6 * k, AnimalArt.CREAM)  # tail
	var shape := AnimalArt.ellipse(c, r.x * stretch, r.y / sqrt(stretch), tilt, 22)
	AnimalArt.fill_lit(ci, shape, body, k)
	# Fore paw reaching forward in the air.
	var fore := c + Vector2(r.x * 0.55 + 4.0 * k * p.hop, r.y * 0.75).rotated(tilt)
	AnimalArt.limb(ci, c + Vector2(r.x * 0.45, r.y * 0.3).rotated(tilt), fore, 3.2 * k, 2.6 * k, body.darkened(0.06), k)
	# Head, low at the front; ears stream back mid-hop.
	var head := rig.pair("head", Vector2(9, 8)) * rig.head_scale
	var hc := c + Vector2(r.x * 0.85, -r.y * 0.55).rotated(tilt) + Vector2(0, p.head * r.y * 0.7)
	var ear_a := -PI * 0.58 - p.ear * 0.4 - p.hop * 0.55 + p.look * 0.2
	for side: float in [0.0, 1.0]:
		var base := hc + Vector2(-head.x * 0.3 - side * 2.0 * k, -head.y * 0.6)
		var ear := AnimalArt.leaf(base, ear_a - side * 0.18, 12.0 * k * rig.head_scale, 4.2 * k)
		AnimalArt.fill(ci, ear, body.darkened(0.08 + 0.15 * side), k)
	AnimalArt.fill_lit(ci, AnimalArt.ellipse(hc, head.x * 0.62, head.y * 0.55, tilt * 0.5, 16), body, k)
	var twitch := sin(p.time * 14.0) * 0.4 * k
	ci.draw_circle(hc + Vector2(head.x * 0.58, twitch), 1.3 * k, NOSE)
	AnimalArt.eye(ci, hc + Vector2(head.x * 0.15, -head.y * 0.12), 1.6 * k, p.blink, body, k)
	return c.y - r.y - 14.0 * k


## A turtle: a domed shell over four stubby legs that paddle as it walks, and a head that looks about
## and pulls in a little while it rests.
static func turtle(ci: CanvasItem, g: Vector2, rig: AnimalRig, p: AnimalPose, body: Color, accent: Color) -> float:
	var k := rig.scale
	var r := rig.pair("body", Vector2(16, 10))
	var c := g + Vector2(0, -r.y * 0.55 - 2.0 * k)
	AnimalArt.shadow(ci, g + Vector2(0, 1.5), r.x * 1.1, r.y * 0.45)
	var skin := accent.lerp(Color("#8a9a5b"), 0.6)
	for i in 4:
		var x := (-0.6 if i % 2 == 0 else 0.6) * r.x
		var paddle := sin(p.gait * TAU + i * PI * 0.5) * 2.5 * k * p.stride
		var near := i >= 2
		var foot := Vector2(c.x + x + paddle, g.y - (0.0 if near else 1.5 * k))
		ci.draw_circle(foot, (3.2 if near else 2.8) * k, skin.darkened(0.0 if near else 0.25))
	# Head on a short neck: out while walking or looking, partly in while resting.
	var out := clampf(0.55 + 0.45 * maxf(p.stride, absf(p.look)), 0.0, 1.0)
	var head := rig.pair("head", Vector2(7, 5)) * rig.head_scale
	var hc := c + Vector2(r.x * (0.75 + 0.35 * out), r.y * 0.25 - p.look * 1.5 * k + p.head * 2.0 * k)
	AnimalArt.limb(ci, c + Vector2(r.x * 0.6, r.y * 0.3), hc, head.y * 1.1, head.y, skin, k)
	AnimalArt.fill_lit(ci, AnimalArt.ellipse(hc, head.x * 0.62, head.y * 0.62, 0.0, 14), skin, k)
	AnimalArt.eye(ci, hc + Vector2(head.x * 0.2, -head.y * 0.15), 1.3 * k, p.blink, skin, k)
	# The shell: a dome, its rim, and plates.
	var dome := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		dome.append(c + Vector2(cos(a) * r.x, sin(a) * r.y * 1.25))
	AnimalArt.fill_lit(ci, dome, body, k)
	ci.draw_line(c + Vector2(-r.x, 0), c + Vector2(r.x, 0), accent.darkened(0.2), 2.4 * k, true)
	for i in 3:
		var px := (-0.5 + 0.5 * i) * r.x
		ci.draw_colored_polygon(AnimalArt.ellipse(c + Vector2(px, -r.y * (0.55 if i == 1 else 0.38)),
			r.x * 0.22, r.y * 0.3, 0.0, 6), body.darkened(0.14))
	return c.y - r.y * 1.25 - 4.0 * k


## A bee: hovers above its spot on wings beating too fast to see, bobbing and drifting.
static func bee(ci: CanvasItem, g: Vector2, rig: AnimalRig, p: AnimalPose, body: Color) -> float:
	var k := rig.scale
	var r := rig.pair("body", Vector2(6, 4))
	var hover := rig.size("leg", 18.0) + sin(p.time * 3.3) * 2.0 * k
	var c := g + Vector2(sin(p.time * 1.7) * 1.5 * k, -hover)
	AnimalArt.shadow(ci, g + Vector2(0, 1), r.x * 0.9, r.y * 0.35, 0.6)
	var beat := sin(p.time * 60.0)
	for side: float in [-1.0, 1.0]:
		var wing := AnimalArt.ellipse(c + Vector2(-1.0 * k, -r.y * 0.9), r.x * 0.55, r.y * (0.9 + 0.3 * beat * side),
			-0.5 * side, 12)
		ci.draw_colored_polygon(wing, WING)
	var shape := AnimalArt.ellipse(c, r.x, r.y, 0.0, 16)
	AnimalArt.fill(ci, shape, body, k)
	for i in 2:
		var x := (-0.35 + 0.4 * i) * r.x
		var h := AnimalArt.barrel_half_height(x, r.x, r.y) * 0.95
		ci.draw_line(c + Vector2(x, -h), c + Vector2(x, h), BEE_STRIPE, 2.0 * k)
	ci.draw_circle(c + Vector2(r.x * 0.9, -r.y * 0.2), r.y * 0.6, BEE_STRIPE)
	return c.y - r.y - 6.0 * k
