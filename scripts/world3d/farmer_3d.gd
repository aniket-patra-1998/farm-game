class_name Farmer3D
extends Node3D
## The player's farmer on the farm, standing where PlayerSystem has them, walking when they walk and working
## when they work. FarmVille's proportions: a head nearly half the height on a slim body, in a T-shirt and bib
## overalls. Drawn from a file made the way the animals are (tools/animal_art `farmer`: one smooth skin with a
## drawn face, a file for a boy and a girl in each hair style): the file carries no colours of its own, each
## point says whose colour it wears (REGIONS) and the mesh is tinted once for the player's look; its limbs move
## by blend shapes. Without the file the farmer is built in code from simple parts, swung from their joints
## (the stand-in).

const HIP := 0.19                 # leg length (tiles); everything else stands on it
const TORSO := 0.17
const HEAD_R := 0.16              # (the head is nearly half the farmer's height, as FarmVille drew its farmers)
const HEAD_TILT := 0.2            # the head is tipped back this far, so the face shows to the farm's high camera
const EYE := Color("#3b6fb8")
const TURN_RATE := 10.0           # radians a second
const STRIDE_RATE := 11.0         # leg swings: radians of the cycle a second
const STRIDE := 0.7               # how far a leg swings (radians)
const WORK_RATE := 14.0
const FILE := "farmer_"            # the farmer's files in data/assets.json: FILE + the look's body + "_" + hair style
const REGIONS := ["", "skin", "hair", "shirt", "overalls", "shoes"]   # whose colour a point wears (its first UV)
const REGION_STEPS := 8.0          # a region's number is its UV x times this, rounded down
const ARM_BACK := 0.5              # the angles the file's arm moves stand for (tools/animal_art farmer.py)
const ARM_F1 := 0.72
const ARM_F2 := 1.45
const BLINK_EVERY := 3.6           # seconds between blinks, and how long one lasts
const BLINK_FOR := 0.13
const FILE_HEAD := Vector3(-0.01, 0.6, 0.0)   # the file's head: its middle (tiles), and its radius, for a hat
const FILE_HEAD_R := 0.15
const ROUND := 12                 # sides of a limb or the body
const FOOT := 0.26                # tiles: the span of the contact shade under the farmer (GroundShade), as an animal's
const DEEP := 0.72                # the body's depth, front to back, against its width
const SMILE := 7                  # dots in the smile
const CHEEK := Color("#f08a8a")   # the blush mixed into the skin on the cheeks
const SKULL := Vector3(0.94, 0.95, 1.06)   # the head's shape: a little wider than it is deep or tall
const EASE := 12.0                # how fast limbs settle back when they stop

var _body: Node3D                 # everything, facing +x
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _cycle := 0.0
var _file_mesh: MeshInstance3D   # the farmer drawn from its file (null: built in code)
var _moves := {}                 # the file's blend shapes: name -> index
var _clock := 0.0
var _swing: Array[float] = [0.0, 0.0, 0.0, 0.0]   # the file's limbs now: both legs, then both arms (radians)


func _ready() -> void:
	Game.player.look_changed.connect(rebuild)
	rebuild()
	add_child(GroundShade.under(AABB(Vector3(-FOOT / 2.0, 0, -FOOT / 2.0), Vector3(FOOT, HIP, FOOT)), true))


## Builds the farmer from Game.player.look (again whenever it changes).
func rebuild() -> void:
	if _body != null:
		_body.free()
	_legs.clear()
	_arms.clear()
	_file_mesh = null
	_moves.clear()
	var look: Dictionary = Game.player.look
	if _build_file(look):
		return
	var skin := ModelKit.paint(Color.html(str(look["skin"])))
	var shirt := ModelKit.paint(Color.html(str(look["shirt"])))
	var overalls := ModelKit.paint(Color.html(str(look["overalls"])))
	var shoes := ModelKit.paint(Color.html(str(look["shoes"])))
	var slim := 0.85 if str(look["body"]) == "b" else 1.0
	_body = Node3D.new()
	add_child(_body)
	var cuff := ModelKit.paint(Color.html(str(look["overalls"])).darkened(0.18))
	for side: float in [-1.0, 1.0]:
		# A leg: a trouser leg tapering to a rolled cuff, over a round-toed boot.
		var leg := Node3D.new()
		leg.position = Vector3(0, HIP, side * 0.055 * slim)
		_body.add_child(leg)
		ModelKit.cylinder(leg, Vector3(0, -HIP + 0.05, 0), 0.047, HIP - 0.03, overalls, 0.056, ROUND)
		ModelKit.cylinder(leg, Vector3(0, -HIP + 0.042, 0), 0.054, 0.022, cuff, -1.0, ROUND)
		ModelKit.ball(leg, Vector3(0.018, -HIP + 0.032, 0), 0.052, shoes, Vector3(1.4, 0.62, 1.0), true)
		ModelKit.merge_leaves(leg, [])
		_legs.append(leg)
	var torso := Node3D.new()
	_body.add_child(torso)
	var w := 0.11 * slim
	# The body is round, wider across than deep: overalls to the chest, the shirt above, soft shoulders, a neck.
	ModelKit.cylinder(torso, Vector3(0, HIP - 0.015, 0), w * 0.98, TORSO * 0.62 + 0.015, overalls, w, ROUND) \
		.scale.x = DEEP
	ModelKit.cylinder(torso, Vector3(0, HIP + TORSO * 0.62, 0), w, TORSO * 0.36, shirt, w * 0.84, ROUND).scale.x = DEEP
	ModelKit.ball(torso, Vector3(0, HIP + TORSO * 0.96, 0), w * 0.86, shirt, Vector3(DEEP, 0.42, 1.04), true)
	ModelKit.cylinder(torso, Vector3(0, HIP + TORSO - 0.01, 0), 0.036, 0.035, skin, -1.0, ROUND)
	# The bib with its pocket and two brass buttons, and the straps over the shoulders.
	var front := w * DEEP
	ModelKit.box(torso, Vector3(front - 0.02, HIP + TORSO * 0.5, -w * 0.56), Vector3(front + 0.006, HIP + TORSO * 0.9,
		w * 0.56), overalls)
	ModelKit.box(torso, Vector3(front, HIP + TORSO * 0.56, -w * 0.3), Vector3(front + 0.011, HIP + TORSO * 0.74, w * 0.3),
		cuff)
	var brass := ModelKit.paint(Color("#e8c14a"), 0.5)
	for side: float in [-1.0, 1.0]:
		ModelKit.ball(torso, Vector3(front + 0.008, HIP + TORSO * 0.85, side * w * 0.42), 0.012, brass)
		ModelKit.box(torso, Vector3(-front - 0.004, HIP + TORSO * 0.82, side * w * 0.5 - 0.014),
			Vector3(front + 0.004, HIP + TORSO + 0.012, side * w * 0.5 + 0.014), overalls)
	ModelKit.merge_leaves(torso, [])
	for side: float in [-1.0, 1.0]:
		# An arm: a round shoulder, a sleeve to the elbow, a bare forearm and a hand.
		var arm := Node3D.new()
		arm.position = Vector3(0, HIP + TORSO - 0.025, side * (w + 0.026))
		_body.add_child(arm)
		ModelKit.ball(arm, Vector3.ZERO, 0.037, shirt, Vector3.ONE, true)
		ModelKit.cylinder(arm, Vector3(0, -0.085, 0), 0.03, 0.085, shirt, 0.035, ROUND)
		ModelKit.cylinder(arm, Vector3(0, -0.155, 0), 0.024, 0.075, skin, 0.027, ROUND)
		ModelKit.ball(arm, Vector3(0, -0.17, 0), 0.033, skin, Vector3(1.0, 1.05, 0.9), true)
		ModelKit.merge_leaves(arm, [])
		_arms.append(arm)
	_build_head(look, skin)


## The farmer from its file, tinted for `look`; false when there is no file (the stand-in is built).
func _build_file(look: Dictionary) -> bool:
	var model := AssetRegistry.instance("%s%s_%s" % [FILE, look["body"], look["hair_style"]])
	var mi: MeshInstance3D = null
	if model != null:
		mi = model as MeshInstance3D if model is MeshInstance3D else null
		for found in model.find_children("*", "MeshInstance3D", true, false):   # not-ui
			mi = found if mi == null else mi
	if mi == null or not mi.mesh is ArrayMesh:
		if model != null:
			model.free()
		return false
	var tints: Array[Color] = []
	for region: String in REGIONS:
		tints.append(Color.WHITE if region == "" else Color.html(str(look[region])))
	mi.mesh = tinted(mi.mesh as ArrayMesh, tints)
	_body = Node3D.new()
	add_child(_body)
	_body.add_child(model)
	_file_mesh = mi
	for k in mi.mesh.get_blend_shape_count():
		_moves[String(mi.mesh.get_blend_shape_name(k))] = k
	if str(look["hat"]) in ["straw", "cap"]:
		var holder := Node3D.new()
		var head := Node3D.new()
		head.position = FILE_HEAD
		holder.add_child(head)
		_hat_on(head, look, FILE_HEAD_R)
		_body.add_child(ModelKit.bake(holder))
	return true


## A copy of the farmer's mesh with each point coloured for the look: its own painted light times the colour of
## the region it wears (`tints`, by REGIONS), its moves kept.
static func tinted(mesh: ArrayMesh, tints: Array[Color]) -> ArrayMesh:
	var out := ArrayMesh.new()
	for k in mesh.get_blend_shape_count():
		out.add_blend_shape(mesh.get_blend_shape_name(k))
	out.blend_shape_mode = mesh.blend_shape_mode
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i in colours.size():
			var region := clampi(int(uvs[i].x * REGION_STEPS), 0, tints.size() - 1)
			var tint := tints[region]
			colours[i] = Color(colours[i].r * tint.r, colours[i].g * tint.g, colours[i].b * tint.b, colours[i].a)
		arrays[Mesh.ARRAY_COLOR] = colours
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, mesh.surface_get_blend_shape_arrays(s))
		out.surface_set_material(s, mesh.surface_get_material(s))
	return out


## Sets one of the file's moves (nothing when the file has none by that name).
func _move(move: String, weight: float) -> void:
	if _moves.has(move):
		_file_mesh.set_blend_shape_value(_moves[move], clampf(weight, 0.0, 1.0))


func _process(delta: float) -> void:
	var p := Game.player
	position = Vector3(p.pos.x, 0.0, p.pos.y)
	rotation.y = rotate_toward(rotation.y, atan2(-p.facing.y, p.facing.x), TURN_RATE * delta)
	var leg := 0.0
	var arms := [0.0, 0.0]
	var lean := 0.0
	var lift := 0.0
	if p.is_walking():
		_cycle += delta * STRIDE_RATE
		leg = sin(_cycle) * STRIDE
		arms = [-leg * 0.7, leg * 0.7]
		lift = absf(sin(_cycle)) * 0.012
	elif p.is_working():
		# Both arms out in front, pumping (hoeing, sowing, picking), leaning into it.
		_cycle += delta * WORK_RATE
		var reach := 1.0 + sin(_cycle) * 0.45
		arms = [reach, reach]
		lean = -0.14
		lift = -0.01
	var k := minf(delta * EASE, 1.0)
	if _file_mesh != null:
		# The file's limbs: each eased toward its angle, then shown by the moves that stand for it.
		_swing[0] = lerpf(_swing[0], leg, k)
		_swing[1] = lerpf(_swing[1], -leg, k)
		_swing[2] = lerpf(_swing[2], arms[0], k)
		_swing[3] = lerpf(_swing[3], arms[1], k)
		for side in 2:
			var name: String = ["l", "r"][side]
			_move("leg_%s_f" % name, _swing[side] / STRIDE)
			_move("leg_%s_b" % name, -_swing[side] / STRIDE)
			var arm: float = _swing[2 + side]
			var high := clampf((arm - ARM_F1) / (ARM_F2 - ARM_F1), 0.0, 1.0)   # past the first raise: toward the second
			_move("arm_%s_b" % name, -arm / ARM_BACK)
			_move("arm_%s_f1" % name, minf(arm / ARM_F1, 1.0) * (1.0 - high))
			_move("arm_%s_f2" % name, high)
		_clock += delta
		_move("blink", 1.0 if fmod(_clock, BLINK_EVERY) < BLINK_FOR else 0.0)
	else:
		_legs[0].rotation.z = lerpf(_legs[0].rotation.z, leg, k)
		_legs[1].rotation.z = lerpf(_legs[1].rotation.z, -leg, k)
		for a in 2:
			_arms[a].rotation.z = lerpf(_arms[a].rotation.z, arms[a], k)
	_body.rotation.z = lerpf(_body.rotation.z, lean, k)
	_body.position.y = lerpf(_body.position.y, lift, k)


## The head: big and round, with a face that reads from the farm's high camera: large eyes (a white, a coloured
## iris, a pupil and a glint), brows, a small nose, rosy cheeks and a smile; ears; a full head of hair with a
## fringe and a tuft; and the hat, when one is worn.
func _build_head(look: Dictionary, skin: Material) -> void:
	var r := HEAD_R
	var head := Node3D.new()
	head.position = Vector3(0, HIP + TORSO + r * 0.85, 0)
	head.rotation.z = HEAD_TILT
	_body.add_child(head)
	ModelKit.ball(head, Vector3.ZERO, r, skin, SKULL, true)
	var skin_col := Color.html(str(look["skin"]))
	var hair_col := Color.html(str(look["hair"]))
	var dark := ModelKit.paint(Color("#231c1a"))
	var white := ModelKit.paint(Color("#fbfaf6"))
	var hair := ModelKit.paint(hair_col)
	var flat := Vector3(0.4, 1.22, 0.95)   # an eye's parts: thin front to back, taller than wide
	for side: float in [-1.0, 1.0]:
		var z := side * 0.36 * r
		ModelKit.ball(head, Vector3(0.8 * r, 0.02 * r, z), 0.27 * r, white, flat, true)
		ModelKit.ball(head, Vector3(0.87 * r, 0.0, z), 0.17 * r, ModelKit.paint(EYE), flat, true)
		ModelKit.ball(head, Vector3(0.915 * r, -0.01 * r, z), 0.095 * r, dark, flat, true)
		ModelKit.ball(head, Vector3(0.955 * r, 0.09 * r, z - 0.05 * r), 0.05 * r, white)
		ModelKit.box(head, Vector3(0.75 * r, 0.37 * r, z - 0.17 * r), Vector3(0.85 * r, 0.43 * r, z + 0.17 * r),
			ModelKit.paint(hair_col.darkened(0.25)))
		ModelKit.ball(head, Vector3(0.76 * r, -0.3 * r, side * 0.56 * r), 0.17 * r,
			ModelKit.paint(skin_col.lerp(CHEEK, 0.4)), Vector3(0.4, 0.7, 1.0), true)
		ModelKit.ball(head, Vector3(0, -0.03 * r, side * 1.03 * r), 0.22 * r, skin, Vector3(0.7, 1.0, 0.5), true)
		ModelKit.ball(head, Vector3(0.1 * r, 0.22 * r, side * 0.93 * r), 0.4 * r, hair, Vector3(0.9, 1.0, 0.4), true)
	ModelKit.ball(head, Vector3(0.93 * r, -0.16 * r, 0), 0.09 * r, ModelKit.paint(skin_col.darkened(0.07)), Vector3.ONE,
		true)
	var lip := ModelKit.paint(Color("#8a3f33"))
	for k in SMILE:   # a smile: a row of dots along the head's curve, its ends turned up
		var z := lerpf(-0.24, 0.24, float(k) / (SMILE - 1)) * r
		var y := -0.46 * r + 0.1 * r * pow(z / (0.24 * r), 2.0)
		var x := SKULL.x * sqrt(maxf(r * r - pow(y / SKULL.y, 2.0) - pow(z / SKULL.z, 2.0), 0.0))
		ModelKit.ball(head, Vector3(x * 0.99, y, z), 0.05 * r, lip)
	# Hair: a cap of it over the top and back, a fringe over the forehead (clear of the brows) and a tuft.
	ModelKit.ball(head, Vector3(-0.22 * r, 0.3 * r, 0), r * 1.03, hair, Vector3(1.0, 0.86, 1.05), true)
	for z: float in [-0.45, 0.0, 0.45]:
		ModelKit.ball(head, Vector3(0.5 * r, 0.74 * r, z * r), 0.36 * r, hair, Vector3(0.85, 0.5, 1.0), true)
	ModelKit.ball(head, Vector3(0.6 * r, 0.92 * r, 0.12 * r), 0.28 * r, hair, Vector3(1.25, 0.6, 0.8), true)
	match str(look["hair_style"]):
		"long":
			ModelKit.ball(head, Vector3(-0.55 * r, -0.5 * r, 0), r * 0.9, hair, Vector3(0.6, 1.3, 1.05), true)
		"ponytail":
			ModelKit.ball(head, Vector3(-r * 1.1, -0.1 * r, 0), 0.4 * r, hair, Vector3(0.8, 1.6, 0.8), true)
	_hat_on(head, look, r)
	# The hat's parts are under their own tilted node: merged with the head's by baking the lot.
	var baked := ModelKit.bake(head)
	_body.add_child(baked)


## The look's hat (if any) on a head of radius `r`, as parts under `head`.
func _hat_on(head: Node3D, look: Dictionary, r: float) -> void:
	match str(look["hat"]):
		"straw":
			# Worn on the back of the head, so the face shows from the farm's high camera.
			var straw := ModelKit.paint(Color("#e3c77a"))
			var hat := Node3D.new()
			hat.position = Vector3(-r * 0.45, r * 0.78, 0)
			hat.rotation.z = 0.35
			head.add_child(hat)
			ModelKit.cylinder(hat, Vector3.ZERO, r * 1.5, 0.012, straw, r * 1.4, 20)
			ModelKit.cylinder(hat, Vector3(0, 0.012, 0), r * 1.4, 0.008, ModelKit.paint(Color("#cfae5c")), r, 20)
			ModelKit.cylinder(hat, Vector3.ZERO, r * 0.82, 0.075, straw, r * 0.7, 14)
			ModelKit.ball(hat, Vector3(0, 0.075, 0), r * 0.7, straw, Vector3(1.0, 0.32, 1.0), true)
			ModelKit.cylinder(hat, Vector3(0, 0.014, 0), r * 0.84, 0.022, ModelKit.paint(Color("#b5492f")), -1.0, 14)
		"cap":
			var cloth := ModelKit.paint(Color.html(str(look["shirt"])).darkened(0.15))
			ModelKit.ball(head, Vector3(0, r * 0.45, 0), r * 1.06, cloth, Vector3(1.0, 0.6, 1.0), true)
			ModelKit.box(head, Vector3(r * 0.6, r * 0.42, -0.5 * r), Vector3(r * 1.6, r * 0.5, 0.5 * r), cloth)
