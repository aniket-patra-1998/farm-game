class_name QuadrupedArt
extends RefCounted
## Cows, horses, sheep, goats, pigs, llamas and donkeys: a barrel body on four jointed legs walking a
## four-beat walk (left hind, left fore, right hind, right fore), a neck that lowers the head to graze,
## a head with blinking eyes, flicking ears, horns, and a swishing tail. See AnimalArt.

## Each leg: x along the body (share of its half length), its step's place in the walk cycle, whether
## it's on the near side, and whether it's a foreleg.
const LEGS := [
	[-0.62, 0.5, false, false], [0.6, 0.75, false, true],   # far side first (behind the body)
	[-0.62, 0.0, true, false], [0.6, 0.25, true, true],
]
const SPOTS := [[-0.42, -0.12, 0.2], [0.06, 0.28, 0.17], [0.4, -0.3, 0.13], [-0.08, -0.45, 0.11], [0.55, 0.18, 0.1]]
const PATCHES := [[-0.35, 0.0, 0.34], [0.38, -0.2, 0.24]]
const WHITE := Color("#f4f1ea")
const HORN := Color("#ece3cf")


static func draw(ci: CanvasItem, g: Vector2, rig: AnimalRig, p: AnimalPose, body: Color, accent: Color) -> float:
	var k := rig.scale
	var r := rig.pair("body", Vector2(26, 14))
	var leg := rig.size("leg", 15.0)
	var walk := p.stride
	var rise := pow(sin(p.gait * TAU * 2.0), 2.0) * 1.4 * k * walk  # the body rises as each leg passes under
	var c := g + Vector2(0, -(leg + r.y * 0.62) - rise + p.breath * 0.35 * k)
	var markings := rig.text("markings", "none")
	var head_col := _head_colour(rig, body, accent, markings)

	AnimalArt.shadow(ci, g + Vector2(0, 2), r.x * 1.15, r.y * 0.55)
	for spec in LEGS:
		if not spec[2]:
			_leg(ci, g, c, r, rig, p, spec, body, accent, markings)
	_tail(ci, c, r, rig, p, body, accent)
	if rig.flag("udder"):
		AnimalArt.fill(ci, AnimalArt.ellipse(c + Vector2(-r.x * 0.28, r.y * 0.92), 5.0 * k, 3.4 * k), AnimalArt.PINK, k)
	var shape := AnimalArt.barrel(c, r.x, r.y * (1.0 + 0.015 * p.breath))
	AnimalArt.fill_lit(ci, shape, body, k, not rig.flag("wool"))
	_markings(ci, c, r, k, markings, body, accent)
	if rig.flag("wool"):
		_wool(ci, c, r, k, body)
	for spec in LEGS:
		if spec[2]:
			_leg(ci, g, c, r, rig, p, spec, body, accent, markings)
	return _neck_and_head(ci, g, c, r, rig, p, body, accent, head_col)


static func _head_colour(rig: AnimalRig, body: Color, accent: Color, markings: String) -> Color:
	if markings == "white_face":
		return WHITE
	match rig.text("head_color", "body"):
		"accent":
			return accent
	return body


static func _leg(ci: CanvasItem, g: Vector2, c: Vector2, r: Vector2, rig: AnimalRig, p: AnimalPose,
		spec: Array, body: Color, accent: Color, markings: String) -> void:
	var k := rig.scale
	var leg := rig.size("leg", 15.0)
	var near: bool = spec[2]
	var fore: bool = spec[3]
	var depth := Vector2(0, 0) if near else Vector2(3.5 * k, -2.2 * k)
	var hip := c + Vector2(float(spec[0]) * r.x, r.y * 0.35) + depth
	var rest := Vector2(hip.x + (0.6 if fore else -0.6) * k, g.y + depth.y)
	var u := fposmod(p.gait + float(spec[1]), 1.0)
	var foot := rest + AnimalArt.foot_offset(u, AnimalArt.STRIDE * leg, AnimalArt.LIFT * leg) * p.stride
	var bone := (rest.y - hip.y) * 0.56
	var knee := AnimalArt.joint(hip, foot, bone, bone, -1.0 if fore else 1.0)
	var thick := rig.num("leg_width", 1.0) * (1.35 if rig.family == "pig" else 1.0)
	var upper := body.darkened(0.06 if near else 0.3)
	var lower := upper
	match rig.family:
		"horse":
			lower = accent.lerp(body, 0.35).darkened(0.0 if near else 0.25)
		"sheep", "camelid":
			lower = _head_colour(rig, body, accent, "none").darkened(0.0 if near else 0.25)
	if rig.flag("socks") or (markings == "saddle" and fore):
		lower = WHITE.darkened(0.0 if near else 0.22)
		if markings == "saddle":
			upper = lower
	AnimalArt.limb(ci, hip, knee, 7.5 * k * thick, 5.0 * k * thick, upper, k)
	AnimalArt.limb(ci, knee, foot, 5.0 * k * thick, 3.8 * k * thick, lower, k)
	var hoof := AnimalArt.HOOF if rig.family != "pig" else body.darkened(0.45)
	ci.draw_rect(Rect2(foot + Vector2(-2.6, -2.6) * k * thick, Vector2(5.4, 3.2) * k * thick), hoof)


static func _markings(ci: CanvasItem, c: Vector2, r: Vector2, k: float, markings: String, body: Color,
		accent: Color) -> void:
	match markings:
		"spots":
			for s in SPOTS:
				var rad := float(s[2]) * r.x
				ci.draw_colored_polygon(
					AnimalArt.ellipse(c + Vector2(float(s[0]) * r.x, float(s[1]) * r.y), rad, rad * 0.7, 0.3, 14), accent)
		"patches":
			for s in PATCHES:
				var rad := float(s[2]) * r.x
				ci.draw_colored_polygon(
					AnimalArt.ellipse(c + Vector2(float(s[0]) * r.x, float(s[1]) * r.y), rad, rad * 0.62, -0.2, 16),
					WHITE if body.get_luminance() < 0.5 else accent)
		"belt":
			_band(ci, c, r, -0.22, 0.14, WHITE)
		"saddle":
			_band(ci, c, r, 0.22, 0.58, WHITE)
		"pale_belly", "white_face":
			# A pale underside (and chest, for a white face).
			var pts := PackedVector2Array()
			var steps := 10
			for i in steps + 1:
				var x := lerpf(-0.78, 0.86 if markings == "white_face" else 0.78, float(i) / steps) * r.x
				pts.append(c + Vector2(x, maxf(r.y * 0.38, AnimalArt.barrel_half_height(x, r.x, r.y) * 0.98)))
			for i in range(steps, -1, -1):
				var x := lerpf(-0.78, 0.86 if markings == "white_face" else 0.78, float(i) / steps) * r.x
				pts.append(c + Vector2(x, r.y * 0.38 - 0.5))
			ci.draw_colored_polygon(pts, WHITE.darkened(0.04) if markings == "white_face" else body.lightened(0.45))


## A band around the body between two points along it (shares of the half length).
static func _band(ci: CanvasItem, c: Vector2, r: Vector2, x0: float, x1: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 6
	for i in steps + 1:
		var x := lerpf(x0, x1, float(i) / steps) * r.x
		pts.append(c + Vector2(x, -AnimalArt.barrel_half_height(x, r.x, r.y) * 0.98))
	for i in range(steps, -1, -1):
		var x := lerpf(x0, x1, float(i) / steps) * r.x
		pts.append(c + Vector2(x, AnimalArt.barrel_half_height(x, r.x, r.y) * 1.02))
	ci.draw_colored_polygon(pts, col)


## Fleece: overlapping curls, with only the outer edge outlined.
static func _wool(ci: CanvasItem, c: Vector2, r: Vector2, k: float, body: Color) -> void:
	var curls := PackedVector2Array()
	var n := 14
	for i in n:
		var a := TAU * i / n
		curls.append(c + Vector2(cos(a) * r.x * 0.86, sin(a) * r.y * 0.8))
	var cr := r.y * 0.42
	for v in curls:
		ci.draw_arc(v, cr + 0.6, 0.0, TAU, 14, AnimalArt.OUTLINE, maxf(1.0, 1.4 * k), true)
	var fleece := body.lightened(0.08)
	for v in curls:
		ci.draw_circle(v, cr, fleece)
	ci.draw_colored_polygon(AnimalArt.ellipse(c, r.x * 0.86, r.y * 0.8, 0.0, 18), fleece)
	for i in 6:
		var v := c + Vector2((i % 3 - 1) * r.x * 0.42, (int(i / 3.0) - 0.5) * r.y * 0.6)
		ci.draw_arc(v, cr * 0.55, PI * 1.1, PI * 1.9, 8, body.darkened(0.12), maxf(1.0, 1.2 * k), true)


static func _tail(ci: CanvasItem, c: Vector2, r: Vector2, rig: AnimalRig, p: AnimalPose, body: Color,
		accent: Color) -> void:
	var k := rig.scale
	var base := c + Vector2(-r.x * 0.95, -r.y * 0.42)
	var length := rig.size("tail_len", 14.0)
	match rig.text("tail", "tuft"):
		"tuft", "hair":
			var hair := rig.text("tail") == "hair"
			var pts := PackedVector2Array([base])
			var a := PI * (0.62 if hair else 0.56)
			var at := base
			for i in 4:
				a += p.tail * (0.5 + i * 0.3) + (0.05 if hair else 0.03)
				at += Vector2.from_angle(a) * length / 4.0
				pts.append(at)
			if hair:
				ci.draw_polyline(pts, AnimalArt.OUTLINE, 6.2 * k, true)
				ci.draw_polyline(pts, accent, 5.0 * k, true)
				ci.draw_polyline(pts, accent.lightened(0.15), 1.5 * k, true)
			else:
				ci.draw_polyline(pts, AnimalArt.OUTLINE, 3.2 * k, true)
				ci.draw_polyline(pts, body.darkened(0.1), 2.2 * k, true)
				AnimalArt.fill(ci, AnimalArt.ellipse(at, 2.4 * k, 4.0 * k, a - PI / 2.0, 12), accent, k)
		"curl":
			ci.draw_arc(base + Vector2(-2.6 * k, 0), 2.6 * k, -PI * 0.2 + p.tail, PI * 1.6 + p.tail, 12,
				body.darkened(0.15), 1.8 * k, true)
		"short", "short_up":
			var up := rig.text("tail") == "short_up"
			AnimalArt.fill(ci, AnimalArt.leaf(base, (-PI * 0.8 if up else PI * 0.75) + p.tail * 0.6, length, 4.5 * k),
				body.darkened(0.05), k)


static func _neck_and_head(ci: CanvasItem, g: Vector2, c: Vector2, r: Vector2, rig: AnimalRig, p: AnimalPose,
		body: Color, accent: Color, head_col: Color) -> float:
	var k := rig.scale
	var hs := rig.head_scale
	var neck := rig.pair("neck", Vector2(14, 9))
	var head := rig.pair("head", Vector2(14, 10)) * hs
	var chest := c + Vector2(r.x * 0.72, -r.y * 0.3)
	var down := smoothstep(0.0, 1.0, p.head)
	var up_at := chest + Vector2.from_angle(rig.num("neck_up", -0.6)) * neck.x
	var graze_at := Vector2(chest.x + neck.x * 0.85 + head.x * 0.2, g.y - head.y * 0.55)
	var hc := up_at.lerp(graze_at, down) + Vector2(0, -p.look * 2.2 * k * (1.0 - down))
	var tilt := rig.num("head_tilt", 0.3)
	var angle := lerpf(tilt, 1.2, down) - p.look * 0.2
	AnimalArt.limb(ci, chest, hc, neck.y * 1.9, neck.y * 1.45, body, k)
	match rig.text("mane", ""):
		"long", "short":
			var long_mane := rig.text("mane") == "long"
			var d := (hc - chest).normalized()
			var up := Vector2(d.y, -d.x)
			for i in 6:
				var t := 0.15 + 0.75 * i / 5.0
				var root := chest.lerp(hc, t) + up * neck.y * 0.85
				var sway := sin(p.time * 3.0 + i) * 0.8 * k + p.stride * sin(p.gait * TAU * 2.0 + i) * 1.2 * k
				var tip := root + (Vector2(-5.5 * k, 3.0 * k + sway) if long_mane else up * 3.0 * k)
				ci.draw_line(root, tip, accent, (3.0 if long_mane else 2.4) * k, true)
	_head(ci, hc, angle, head, rig, p, head_col, body, accent)
	return minf(c.y - r.y, hc.y - head.y * 0.9) - 6.0 * k


## The head, drawn in its own frame: x points down the muzzle, rotated by `angle` around `hc`.
static func _head(ci: CanvasItem, hc: Vector2, angle: float, size: Vector2, rig: AnimalRig, p: AnimalPose,
		col: Color, body: Color, accent: Color) -> void:
	var k := rig.scale * rig.head_scale
	var hl := size.x
	var hh := size.y
	var at := func(v: Vector2) -> Vector2: return hc + v.rotated(angle)
	_ears(ci, at, angle, hl, hh, k, rig, p, col)
	var skull := AnimalArt.ellipse(at.call(Vector2(-hl * 0.12, 0)), hl * 0.44, hh * 0.5, angle, 20)
	AnimalArt.fill_lit(ci, skull, col, k)
	var muzzle_col := _muzzle_colour(rig.text("muzzle", "light"), col)
	var jaw := Vector2(0, p.jaw * 0.6 * k)
	if rig.text("muzzle") == "snout":
		var sc: Vector2 = at.call(Vector2(hl * 0.42, hh * 0.06) + jaw)
		AnimalArt.fill(ci, AnimalArt.ellipse(sc, 2.6 * k, hh * 0.34, angle, 14), muzzle_col, k)
		ci.draw_circle(at.call(Vector2(hl * 0.47, -hh * 0.06) + jaw), 0.9 * k, AnimalArt.EYE)
		ci.draw_circle(at.call(Vector2(hl * 0.47, hh * 0.18) + jaw), 0.9 * k, AnimalArt.EYE)
	else:
		var mc: Vector2 = at.call(Vector2(hl * 0.3, hh * 0.12) + jaw)
		AnimalArt.fill(ci, AnimalArt.ellipse(mc, hl * 0.3, hh * 0.38, angle, 18), muzzle_col, k)
		ci.draw_circle(at.call(Vector2(hl * 0.5, hh * 0.02) + jaw), 0.9 * k, AnimalArt.EYE)
	if rig.flag("beard"):
		AnimalArt.fill(ci, AnimalArt.leaf(at.call(Vector2(hl * 0.25, hh * 0.42)), angle + PI * 0.55, 5.0 * k, 3.0 * k),
			col.darkened(0.2), k)
	if rig.flag("tusks"):
		ci.draw_arc(at.call(Vector2(hl * 0.36, hh * 0.3)), 2.0 * k, angle - PI * 0.9, angle - PI * 0.1, 6, AnimalArt.CREAM,
			1.6 * k, true)
	_horns(ci, at, angle, hl, hh, k, rig.text("horns", "none"), accent)
	AnimalArt.eye(ci, at.call(Vector2(-hl * 0.06, -hh * 0.16)), 1.7 * k, p.blink, col, k)


static func _muzzle_colour(kind: String, head_col: Color) -> Color:
	match kind:
		"pink":
			return head_col.lerp(AnimalArt.PINK, 0.65)
		"dark":
			return head_col.darkened(0.35)
		"snout":
			return head_col.lerp(AnimalArt.PINK, 0.35).darkened(0.08)
	return head_col.lightened(0.25)


static func _ears(ci: CanvasItem, at: Callable, angle: float, hl: float, hh: float, k: float, rig: AnimalRig,
		p: AnimalPose, col: Color) -> void:
	var base: Vector2 = at.call(Vector2(-hl * 0.34, -hh * 0.36))
	var flick := p.ear * 0.55
	match rig.text("ears", "side"):
		"up":
			AnimalArt.fill(ci, AnimalArt.leaf(base, angle - PI * 0.62 - flick, 6.5 * k, 3.0 * k), col, k)
		"long":
			AnimalArt.fill(ci, AnimalArt.leaf(base, angle - PI * 0.66 - flick, 11.0 * k, 3.8 * k), col, k)
			ci.draw_line(base, base + Vector2.from_angle(angle - PI * 0.66 - flick) * 8.0 * k, AnimalArt.PINK,
				1.2 * k, true)
		"floppy":
			AnimalArt.fill(ci, AnimalArt.leaf(base, angle + PI * 0.6 + flick, 7.5 * k, 4.8 * k), col.darkened(0.08), k)
		_:
			AnimalArt.fill(ci, AnimalArt.leaf(base, angle + PI * 0.92 - flick, 6.5 * k, 3.4 * k), col, k)
			ci.draw_line(base, base + Vector2.from_angle(angle + PI * 0.92 - flick) * 4.0 * k, AnimalArt.PINK,
				1.0 * k, true)


static func _horns(ci: CanvasItem, at: Callable, angle: float, hl: float, hh: float, k: float, kind: String,
		accent: Color) -> void:
	var root: Vector2 = at.call(Vector2(-hl * 0.18, -hh * 0.46))
	var w := 2.4 * k
	match kind:
		"nubs":
			ci.draw_line(root, root + Vector2(0.6, -2.6) * k, HORN, w, true)
		"short":
			ci.draw_polyline(PackedVector2Array([root, root + Vector2(-1.5, -3.5) * k, root + Vector2(1.5, -6.0) * k]),
				HORN, w * 1.1, true)
		"long":
			for side in [-1.0, 1.0]:
				var col := HORN if side > 0.0 else HORN.darkened(0.25)
				ci.draw_polyline(PackedVector2Array([root, root + Vector2(8.0 * side, -2.5) * k,
					root + Vector2(15.0 * side, -6.5) * k]), col, w * 1.2, true)
		"curl":
			ci.draw_arc(root + Vector2(-2.5, 1.5) * k, 4.2 * k, -PI * 0.4, PI * 1.25, 14, accent.lightened(0.35), w * 1.4, true)
		"back", "long_back":
			var reach := 1.8 if kind == "long_back" else 1.0
			ci.draw_polyline(PackedVector2Array([root, root + Vector2(-2.0, -4.0) * k * reach,
				root + Vector2(-6.5, -5.0) * k * reach]), HORN.darkened(0.15), w, true)
