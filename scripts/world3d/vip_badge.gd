class_name VipBadge
extends RefCounted
## The VIP badge the Barn wears on its roof (docs/VIP.md; the building feature `"type": "vip_badge"` in
## data/building_models.json, built by BuildingDress as any other): `build`.

const R := 0.36             # its radius, in tiles (big: it is what the eye goes to)..
const RIM := 0.13           # ..its rim's thickness, against that..
const POST := 0.12          # ..the foot it stands on..
const TURN := 0.6           # ..how fast it turns while VIP is active, in radians a second..
const TIER := 3             # ..and the VIP levels to a tier of it
## A tier's metal, the enamel its number stands on, and the balls of its crown: bronze, silver, then gold on
## red, on green and on royal purple.
const METALS: Array[Color] = [Color("#d08a48"), Color("#dfe4ea"), Color("#f7c63f"), Color("#f7c63f"),
	Color("#ffd75e")]
const ENAMELS: Array[Color] = [Color("#7a3015"), Color("#2450a8"), Color("#c21f33"), Color("#12894f"),
	Color("#6a2bd0")]
const GEMS: Array[Color] = [Color("#ffd9a8"), Color("#7fd0ff"), Color("#ff5c5c"), Color("#7dffb0"),
	Color("#ffffff")]
const FONT := preload("res://fonts/Poppins-Bold.ttf")   # not-ui (the game's own bold face, as its numbers)
const NUMBER_FILL := 0.92   # its number: how far out on the face it may reach, outline and all..
const NUMBER_ROUND := 0.9         # ..how much of its box's half diagonal it reaches (digits have round corners)..
const NUMBER_OUTLINE := 0.045     # ..its dark outline's width, against its digits' height..
const NUMBER_RING := 6            # ..the copies of it, a ring round, that make that outline..
const NUMBER_DEPTH := 0.03        # ..how far it stands out of the face, in tiles..
const NUMBER_PX := 64             # ..and the size its letters are cut at, with the curve step that keeps them light
const NUMBER_STEP := 4.0


## The Barn's VIP badge (docs/VIP.md): one big, round, simple thing over the roof, in the farm's own chunky
## look, as a farm game shows a level: a fat coin with a thick rim, a domed enamel face, the VIP level's number
## large and outlined on it (the building's level, BarnDef.look_level), and a crown on top. Only its colours
## change by tier (three levels each): bronze, silver, then gold on red, on green and on royal purple. Two
## looks of one part, switched in place: while VIP is active its metal glimmers (ModelKit.to_shine), a few big
## glints twinkle round it and it turns slowly on its foot, its number on both faces (`when_vip_true`); lapsed,
## the same badge stands still in dull grey, facing out (`when_vip_false`). Neither shows before the first VIP
## level.
static func build(ctx: Dictionary, lo: Vector3, hi: Vector3) -> void:
	var root: Node3D = ctx["root"]
	var w_lo: Vector3 = ctx.get("upper_lo", lo)
	var w_hi: Vector3 = ctx.get("upper_hi", hi)
	var foot := Vector3((w_lo.x + w_hi.x) / 2.0, float(ctx.get("top", w_hi.y)) - 0.03, (w_lo.z + w_hi.z) / 2.0)
	var at := foot + Vector3(0, POST + R, 0)
	var turn := Vector3(0, PI / 4.0, 0)   # (its face to the camera)
	var level := int(ctx.get("level", 1))
	var tier := clampi((level - 1) / TIER, 0, METALS.size() - 1)
	# What it stands on: a short turned foot of dark iron (it never changes).
	var iron := ModelKit.paint(Color("#3f454c"), 0.5)
	ModelKit.cylinder(root, foot, 0.09, 0.035, iron, 0.06, 10)
	ModelKit.cylinder(root, foot + Vector3(0, 0.035, 0), 0.04, POST - 0.035, iron, 0.03, 10)
	for on: bool in [true, false]:
		var face := Node3D.new()
		_crest(face, level, tier, on)
		var part := BuildingDress.when(ctx, "vip", on)
		if on:
			# It turns slowly on its foot, its metal glimmering; the glints stay facing out, round where it turns.
			ModelKit.to_shine(DecorMotion.spin(part, at, turn, face, TURN))
			var glints := DecorMotion.effect(part, "sparkle", at)
			glints.rotation = Vector3(PI / 2.0, turn.y, 0)   # (its ring upright, facing the camera)
		else:
			face.position = at
			face.rotation = turn
			part.add_child(face)


## The badge itself, built facing +z about its own middle: `on` in its tier's metal and enamel, or in greys.
static func _crest(face: Node3D, level: int, tier: int, on: bool) -> void:
	var metal_col: Color = METALS[tier] if on else Color("#8f969d")
	var metal := ModelKit.paint(metal_col, 0.9 if on else 0.3)
	var pale := ModelKit.paint(metal_col.lightened(0.3), 0.9 if on else 0.3)
	var enamel := ModelKit.paint(ENAMELS[tier] if on else Color("#4f555c"), 0.7 if on else 0.1)
	var ink := ModelKit.paint(Color("#fffaf0") if on else Color("#c2c8ce"), 0.8 if on else 0.2)
	var edge := ModelKit.paint((ENAMELS[tier] if on else Color("#4f555c")).darkened(0.55), 0.2)
	var gem := ModelKit.paint(GEMS[tier] if on else Color("#737a82"), 1.0 if on else 0.2)
	# A fat round rim, and a domed face within it.
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.outer_radius = R
	ring.inner_radius = R * (1.0 - RIM * 2.0)
	ring.rings = 24
	ring.ring_segments = 8
	rim.mesh = ring
	rim.material_override = metal
	rim.rotation.x = PI / 2.0
	face.add_child(rim)
	BuildingDress.bead(face, Vector3.ZERO, R * (1.0 - RIM), enamel, Vector3(1, 1, 0.22))
	# The number: big, in the game's own bold face, a dark outline round it so it reads from afar; on both
	# faces (it turns, and reads from either side).
	var front := R * (1.0 - RIM) * 0.22
	for side in 2:
		var half := _turned(face, Vector3.ZERO, 0.0)
		half.rotation.y = PI * side
		_number(half, level, ink, edge, ring.inner_radius, front)
	# A crown on top: a band, three fat points, a ball on each.
	var base := Vector3(0, R * 0.93, 0)
	var wide := R * 0.52
	var crown := metal if tier >= 2 else pale
	ModelKit.box(face, base + Vector3(-wide, 0, -0.045), base + Vector3(wide, R * 0.2, 0.045), crown, false)
	for k in 3:
		var x := (k - 1) * wide * 0.72
		var tall := R * (0.42 if k == 1 else 0.32)
		ModelKit.cylinder(face, base + Vector3(x, R * 0.2, 0), wide * 0.36, tall, crown, 0.0, 8)
		BuildingDress.bead(face, base + Vector3(x, R * 0.2 + tall, 0), R * 0.1, gem)


## A node at `at` turned by `turn` about the axis out of the crest's face: what is built under it points along
## its own upright.
static func _turned(face: Node3D, at: Vector3, turn: float) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.rotation.z = turn
	face.add_child(n)
	return n


## A number on the badge's round face (`room` its radius, `z` its surface), as big as fits it: the game's bold
## letters standing out of the face in `ink`, with an outline in `edge` (the same letters flat on the face, a
## ring of them round). It is sized by what it really covers, so one digit or two both sit inside the rim.
static func _number(face: Node3D, number: int, ink: Material, edge: Material, room: float, z: float) -> void:
	var text := TextMesh.new()
	text.text = str(clampi(number, 0, 99))
	text.font = FONT
	text.font_size = NUMBER_PX
	text.curve_step = NUMBER_STEP
	var box := text.get_aabb()
	var reach := Vector2(box.size.x, box.size.y).length() / 2.0 * NUMBER_ROUND
	var outline := box.size.y * room * NUMBER_FILL / reach * NUMBER_OUTLINE
	var size := (room * NUMBER_FILL - outline) / reach
	text.depth = NUMBER_DEPTH / size
	var flat: TextMesh = text.duplicate()
	flat.depth = 0.0   # (the outline's copies are only seen from the front: a face each, no sides or back)
	# (its letters are laid out on their baseline: it is centred by what is drawn)
	var middle := Vector3(box.get_center().x, box.get_center().y, 0) * size
	for k in NUMBER_RING + 1:
		var mi := MeshInstance3D.new()
		mi.mesh = text if k == 0 else flat
		mi.scale = Vector3.ONE * size
		mi.material_override = ink if k == 0 else edge
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # (too small for its shadow to show)
		var out := Vector3(0, 0, NUMBER_DEPTH / 2.0)
		if k > 0:
			out = Vector3(outline, 0, NUMBER_DEPTH * 0.2).rotated(Vector3.BACK, TAU * k / NUMBER_RING)
		mi.position = Vector3(0, 0, z) - middle + out
		face.add_child(mi)
