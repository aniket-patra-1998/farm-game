class_name BirdArt
extends RefCounted
## Chickens, turkeys, ducks, geese and swans: a tilted body on two legs that walk heel-and-toe, a head
## that bobs with each step (and stays put while the foot is planted, as a chicken's does), quick pecks,
## folded wings that open into a flap, a comb and wattle, and a turkey's tail that fans out in display.
## See AnimalArt.

const BEAK := Color("#f2a33a")
const SHANK := Color("#e8a634")
const COMB := Color("#d8382f")
const GLINT := Color(1.0, 0.97, 0.75, 0.9)
const LEG_PHASES := [0.5, 0.0]  # far leg first (behind the body), then the near leg


## Draws the bird and returns the y of its top (for the bubble over it).
static func draw(ci: CanvasItem, g: Vector2, rig: AnimalRig, p: AnimalPose, body: Color, accent: Color) -> float:
	var k := rig.scale
	var r := rig.pair("body", Vector2(13, 11))
	var leg := rig.size("leg", 9.0)
	var waddle := rig.flag("waddle")
	# Each step lifts the body a little; a waddler rolls from foot to foot instead.
	var bob := absf(sin(p.gait * TAU)) * 1.2 * k * p.stride
	var roll := sin(p.gait * TAU) * 0.13 * p.stride if waddle else 0.0
	var tilt := -0.22 + roll - 0.12 * p.head  # rear up a little; tips forward to peck
	var c := g + Vector2(0, -(leg + r.y * 0.8) - bob + p.breath * 0.25 * k)

	AnimalArt.shadow(ci, g + Vector2(0, 1.5), r.x * 1.05, r.y * 0.42)
	_leg(ci, g, c, r, rig, p, LEG_PHASES[0], false)
	_tail(ci, c, r, rig, p, tilt, body, accent)
	var shape := AnimalArt.ellipse(c, r.x, r.y, tilt, 24)
	AnimalArt.fill_lit(ci, shape, body, k)
	if rig.flag("shine"):
		_glints(ci, c, r, p, k)
	_wing(ci, c, r, rig, p, tilt, body, accent, true)
	_leg(ci, g, c, r, rig, p, LEG_PHASES[1], true)
	return _neck_and_head(ci, g, c, r, rig, p, tilt, body, accent)


## A leg: the shank from under the body to the foot, bending back at the ankle, and three toes.
static func _leg(ci: CanvasItem, g: Vector2, c: Vector2, r: Vector2, rig: AnimalRig, p: AnimalPose,
		phase: float, near: bool) -> void:
	var k := rig.scale
	var leg := rig.size("leg", 9.0)
	var depth := Vector2.ZERO if near else Vector2(2.5 * k, -1.5 * k)
	var hip := c + Vector2(r.x * 0.05, r.y * 0.62) + depth
	var u := fposmod(p.gait + phase, 1.0)
	var foot := Vector2(hip.x, g.y + depth.y) + AnimalArt.foot_offset(u, 0.9 * leg, 0.45 * leg) * p.stride
	var bone := (foot.y - hip.y) * 0.56
	var ankle := AnimalArt.joint(hip, foot, bone, bone, 1.0)
	var col := (BEAK if rig.flag("webbed") else SHANK).darkened(0.0 if near else 0.25)
	var w := maxf(1.2, 1.9 * k)
	ci.draw_line(hip, ankle, col, w, true)
	ci.draw_line(ankle, foot, col, w, true)
	if rig.flag("webbed"):
		ci.draw_colored_polygon(PackedVector2Array([foot + Vector2(-1.5, 0) * k, foot + Vector2(5.0, -0.5) * k,
			foot + Vector2(4.0, 1.4) * k]), col)
	else:
		for toe: Vector2 in [Vector2(4.2, 0.4), Vector2(3.0, 1.4), Vector2(-2.6, 0.3)]:
			ci.draw_line(foot, foot + toe * k, col, maxf(1.0, 1.3 * k), true)


static func _tail(ci: CanvasItem, c: Vector2, r: Vector2, rig: AnimalRig, p: AnimalPose, tilt: float,
		body: Color, accent: Color) -> void:
	var k := rig.scale
	var base := c + Vector2(-r.x * 0.82, -r.y * 0.2).rotated(tilt)
	match rig.text("tail", "fan"):
		"fan":
			# A cockerel-style plume: a few feathers sweeping up and back, swaying with the steps.
			for i in 4:
				var a := -PI * (0.62 + 0.09 * i) + p.tail * 0.5 + tilt
				var col := accent.lerp(body, 0.25 * i)
				AnimalArt.fill(ci, AnimalArt.leaf(base, a, (11.0 - i * 1.2) * k, 4.2 * k), col, k)
		"turkey":
			# Folded, the tail trails behind; in display it rises into a full fan of banded feathers.
			var fan := smoothstep(0.0, 1.0, p.display)
			var n := 9
			var spread := lerpf(0.35, 1.25, fan)
			var centre := lerpf(PI * 0.92, -PI * 0.55, fan) + tilt * (1.0 - fan)
			var length := lerpf(12.0, 24.0, fan) * k
			for i in n:
				var a := centre + spread * (float(i) / (n - 1) - 0.5) + sin(p.time * 9.0 + i) * 0.02 * fan
				var tip := base + Vector2.from_angle(a) * length
				AnimalArt.fill(ci, AnimalArt.leaf(base, a, length, 6.5 * k), accent.lerp(body, 0.15), k)
				ci.draw_line(base.lerp(tip, 0.78), base.lerp(tip, 0.88), AnimalArt.CREAM, 2.0 * k, true)
		_:
			# A duck's short tail, flicking up.
			AnimalArt.fill(ci, AnimalArt.leaf(base, PI * 1.05 + tilt - 0.35 + p.tail * 0.4, 7.0 * k, 5.0 * k),
				body.darkened(0.08), k)


## The wing on the near side: folded along the body, or opened and beating in a flap.
static func _wing(ci: CanvasItem, c: Vector2, r: Vector2, rig: AnimalRig, p: AnimalPose, tilt: float,
		body: Color, accent: Color, near: bool) -> void:
	var k := rig.scale
	var shoulder := c + Vector2(r.x * 0.3, -r.y * 0.25).rotated(tilt)
	var beat := sin(p.time * 26.0) * 0.6 * p.wing
	var a := PI + tilt + 0.12 - p.wing * 1.4 + beat
	var length := r.x * lerpf(1.15, 1.45, p.wing)
	var col := body.darkened(0.1) if near else body.darkened(0.3)
	AnimalArt.fill(ci, AnimalArt.leaf(shoulder, a, length, r.y * lerpf(0.95, 0.7, p.wing)), col, k)
	if rig.family != "duck" or rig.id == "belted_duck":
		# Flight feathers at the tip, in the accent colour.
		var tip := shoulder + Vector2.from_angle(a) * length
		ci.draw_line(shoulder.lerp(tip, 0.6), tip, accent.lerp(col, 0.4), 2.2 * k, true)


static func _neck_and_head(ci: CanvasItem, g: Vector2, c: Vector2, r: Vector2, rig: AnimalRig, p: AnimalPose,
		tilt: float, body: Color, accent: Color) -> float:
	var k := rig.scale
	var hs := rig.head_scale
	var neck := rig.pair("neck", Vector2(7, 7))
	var head_r := rig.pair("head", Vector2(6.5, 6.5)) * hs
	var shoulder := c + Vector2(r.x * 0.7, -r.y * 0.35).rotated(tilt)
	var down := smoothstep(0.0, 1.0, p.head)
	# The head holds still while the foot is down, then thrusts forward: the classic bird head-bob.
	var thrust := (fposmod(p.gait * 2.0, 1.0) - 0.5) * -3.0 * k * p.stride
	var up_at := shoulder + Vector2.from_angle(rig.num("neck_up", -1.25)) * neck.x + Vector2(thrust, 0)
	var peck_at := Vector2(shoulder.x + neck.x * 0.9 + head_r.x, g.y - head_r.y * 0.8)
	var hc := up_at.lerp(peck_at, down) + Vector2(0, -p.look * 1.5 * k)
	var curve := rig.num("neck_curve", 0.0)
	if curve > 0.0:
		# An S-shaped neck (geese, swans): a curve bowing back, drawn as a thick polyline.
		var mid := shoulder.lerp(hc, 0.5) + Vector2(-curve * neck.x * 0.45 * (1.0 - down), 0)
		var pts := PackedVector2Array()
		for i in 9:
			var t := i / 8.0
			pts.append(shoulder.lerp(mid, t).lerp(mid.lerp(hc, t), t))
		ci.draw_polyline(pts, AnimalArt.OUTLINE, neck.y * 1.5 + 1.5 * k, true)
		ci.draw_polyline(pts, body, neck.y * 1.5, true)
	else:
		AnimalArt.limb(ci, shoulder, hc, neck.y * 1.8, neck.y * 1.3, body, k)
	var angle := lerpf(-0.1, 1.0, down) - p.look * 0.25
	_head(ci, hc, angle, head_r, rig, p, body, accent)
	return minf(c.y - r.y, hc.y - head_r.y) - 6.0 * k


static func _head(ci: CanvasItem, hc: Vector2, angle: float, size: Vector2, rig: AnimalRig, p: AnimalPose,
		body: Color, accent: Color) -> void:
	var k := rig.scale * rig.head_scale
	var at := func(v: Vector2) -> Vector2: return hc + v.rotated(angle)
	if rig.flag("comb"):
		for i in 3:
			ci.draw_circle(at.call(Vector2((-0.3 + 0.3 * i) * size.x, -size.y * (1.0 - 0.06 * absf(i - 1.0)))),
				(2.2 - 0.3 * absf(i - 1.0)) * k, COMB)
	var head_col := body
	if rig.family == "turkey":
		head_col = Color("#c9a7a0")  # a turkey's bare head
	AnimalArt.fill_lit(ci, AnimalArt.ellipse(hc, size.x, size.y, angle, 16), head_col, k)
	var open := 0.0 if p.head < 0.8 else absf(sin(p.time * 18.0)) * 0.25  # nibbling at the ground
	match rig.text("beak", "pointed"):
		"bill":
			var b0: Vector2 = at.call(Vector2(size.x * 0.8, -size.y * 0.1))
			AnimalArt.fill(ci, AnimalArt.ellipse(b0 + Vector2.from_angle(angle) * size.x * 0.45, size.x * 0.62,
				size.y * 0.3, angle + open * 0.3, 12), BEAK, k)
		_:
			var root: Vector2 = at.call(Vector2(size.x * 0.75, -size.y * 0.05))
			var tip: Vector2 = at.call(Vector2(size.x * 1.55, size.y * 0.15))
			var low: Vector2 = at.call(Vector2(size.x * 0.75, size.y * (0.35 + open)))
			AnimalArt.fill(ci, PackedVector2Array([root, tip, low]), BEAK, k)
	if rig.flag("wattle"):
		var wc: Vector2 = at.call(Vector2(size.x * 0.75, size.y * 0.85))
		AnimalArt.fill(ci, AnimalArt.ellipse(wc + Vector2(0, sin(p.time * 7.0) * 0.4 * k), 1.6 * k, 2.6 * k, 0.0, 10),
			COMB, k)
	AnimalArt.eye(ci, at.call(Vector2(size.x * 0.2, -size.y * 0.2)), 1.5 * k, p.blink, head_col, k)


## A golden bird glitters: small star glints come and go on its body.
static func _glints(ci: CanvasItem, c: Vector2, r: Vector2, p: AnimalPose, k: float) -> void:
	for i in 3:
		var t := fposmod(p.time * 0.7 + i * 0.33, 1.0)
		var s := sin(PI * t) * 2.6 * k
		var at := c + Vector2((-0.4 + 0.4 * i) * r.x, (-0.3 + 0.25 * (i % 2)) * r.y)
		ci.draw_line(at - Vector2(s, 0), at + Vector2(s, 0), GLINT, 1.2, true)
		ci.draw_line(at - Vector2(0, s), at + Vector2(0, s), GLINT, 1.2, true)
