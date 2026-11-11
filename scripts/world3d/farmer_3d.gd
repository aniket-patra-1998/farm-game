class_name Farmer3D
extends Node3D
## The player's farmer on the farm: built in code from how they look (Game.player.look), standing where
## PlayerSystem has them, walking when they walk and working when they work. FarmVille's proportions: a
## big head on a small body, in overalls and a straw hat. One farmer, so a handful of draws: each limb, the
## torso and the head are one merged mesh apiece, swung from their joints.

const HIP := 0.24                 # leg length (tiles); everything else stands on it
const TORSO := 0.2
const HEAD_R := 0.13
const TURN_RATE := 10.0           # radians a second
const STRIDE_RATE := 11.0         # leg swings: radians of the cycle a second
const STRIDE := 0.7               # how far a leg swings (radians)
const WORK_RATE := 14.0
const EASE := 12.0                # how fast limbs settle back when they stop

var _body: Node3D                 # everything, facing +x
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _cycle := 0.0


func _ready() -> void:
	Game.player.look_changed.connect(rebuild)
	rebuild()


## Builds the farmer from Game.player.look (again whenever it changes).
func rebuild() -> void:
	if _body != null:
		_body.free()
	_legs.clear()
	_arms.clear()
	var look: Dictionary = Game.player.look
	var skin := ModelKit.paint(Color.html(str(look["skin"])))
	var shirt := ModelKit.paint(Color.html(str(look["shirt"])))
	var overalls := ModelKit.paint(Color.html(str(look["overalls"])))
	var shoes := ModelKit.paint(Color.html(str(look["shoes"])))
	var slim := 0.85 if str(look["body"]) == "b" else 1.0
	_body = Node3D.new()
	add_child(_body)
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0, HIP, side * 0.055 * slim)
		_body.add_child(leg)
		ModelKit.box(leg, Vector3(-0.045, -HIP + 0.04, -0.045), Vector3(0.045, 0.02, 0.045), overalls)
		ModelKit.box(leg, Vector3(-0.05, -HIP, -0.05), Vector3(0.085, -HIP + 0.05, 0.05), shoes)
		ModelKit.merge_leaves(leg, [])
		_legs.append(leg)
	var torso := Node3D.new()
	_body.add_child(torso)
	var w := 0.11 * slim
	ModelKit.box(torso, Vector3(-0.075, HIP, -w), Vector3(0.075, HIP + TORSO * 0.62, w), overalls)
	ModelKit.box(torso, Vector3(-0.07, HIP + TORSO * 0.62, -w), Vector3(0.07, HIP + TORSO, w), shirt)
	# The bib and its straps, front and back.
	ModelKit.box(torso, Vector3(-0.08, HIP + TORSO * 0.5, -w * 0.6), Vector3(0.08, HIP + TORSO * 0.85, w * 0.6), overalls)
	for side: float in [-1.0, 1.0]:
		ModelKit.box(torso, Vector3(-0.078, HIP + TORSO * 0.8, side * w * 0.55 - 0.012),
			Vector3(0.078, HIP + TORSO + 0.004, side * w * 0.55 + 0.012), overalls)
	ModelKit.merge_leaves(torso, [])
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0, HIP + TORSO - 0.02, side * (w + 0.03))
		_body.add_child(arm)
		ModelKit.box(arm, Vector3(-0.032, -0.09, -0.03), Vector3(0.032, 0.02, 0.03), shirt)
		ModelKit.box(arm, Vector3(-0.028, -0.16, -0.026), Vector3(0.028, -0.09, 0.026), skin)
		ModelKit.ball(arm, Vector3(0, -0.175, 0), 0.032, skin)
		ModelKit.merge_leaves(arm, [])
		_arms.append(arm)
	_build_head(look, skin)


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
	_legs[0].rotation.z = lerpf(_legs[0].rotation.z, leg, k)
	_legs[1].rotation.z = lerpf(_legs[1].rotation.z, -leg, k)
	for a in 2:
		_arms[a].rotation.z = lerpf(_arms[a].rotation.z, arms[a], k)
	_body.rotation.z = lerpf(_body.rotation.z, lean, k)
	_body.position.y = lerpf(_body.position.y, lift, k)


func _build_head(look: Dictionary, skin: Material) -> void:
	var head := Node3D.new()
	head.position = Vector3(0, HIP + TORSO + HEAD_R * 0.85, 0)
	_body.add_child(head)
	ModelKit.ball(head, Vector3.ZERO, HEAD_R, skin, Vector3(0.95, 1.0, 1.0))
	var dark := ModelKit.paint(Color("#2a2320"))
	for side: float in [-1.0, 1.0]:
		ModelKit.ball(head, Vector3(HEAD_R * 0.86, 0.01, side * 0.05), 0.016, dark, Vector3(0.6, 1.3, 1.0))
		ModelKit.ball(head, Vector3(0, -0.005, side * HEAD_R * 0.97), 0.028, skin, Vector3(0.7, 1.0, 0.5))
	ModelKit.ball(head, Vector3(HEAD_R * 0.95, -0.03, 0), 0.02, skin)
	var hair := ModelKit.paint(Color.html(str(look["hair"])))
	match str(look["hair_style"]):
		"short":
			ModelKit.ball(head, Vector3(-0.035, 0.04, 0), HEAD_R * 1.02, hair, Vector3(0.98, 0.85, 1.02))
		"long":
			ModelKit.ball(head, Vector3(-0.035, 0.04, 0), HEAD_R * 1.02, hair, Vector3(0.98, 0.85, 1.04))
			ModelKit.ball(head, Vector3(-0.07, -0.07, 0), HEAD_R * 0.9, hair, Vector3(0.6, 1.3, 1.05))
		"ponytail":
			ModelKit.ball(head, Vector3(-0.035, 0.04, 0), HEAD_R * 1.02, hair, Vector3(0.98, 0.85, 1.02))
			ModelKit.ball(head, Vector3(-HEAD_R * 1.1, -0.02, 0), 0.05, hair, Vector3(0.8, 1.6, 0.8))
	match str(look["hat"]):
		"straw":
			# Worn on the back of the head, so the face shows from the farm's high camera.
			var straw := ModelKit.paint(Color("#e3c77a"))
			var hat := Node3D.new()
			hat.position = Vector3(-HEAD_R * 0.3, HEAD_R * 0.72, 0)
			hat.rotation.z = 0.3
			head.add_child(hat)
			ModelKit.cylinder(hat, Vector3.ZERO, HEAD_R * 1.45, 0.014, straw, -1.0, 16)
			ModelKit.cylinder(hat, Vector3.ZERO, HEAD_R * 0.8, 0.08, straw, HEAD_R * 0.66, 12)
			ModelKit.cylinder(hat, Vector3(0, 0.012, 0), HEAD_R * 0.82, 0.02, ModelKit.paint(Color("#b5492f")), -1.0, 12)
		"cap":
			var cloth := ModelKit.paint(Color.html(str(look["shirt"])).darkened(0.15))
			ModelKit.ball(head, Vector3(0, HEAD_R * 0.45, 0), HEAD_R * 1.03, cloth, Vector3(1.0, 0.6, 1.0))
			ModelKit.box(head, Vector3(HEAD_R * 0.6, HEAD_R * 0.42, -0.07), Vector3(HEAD_R * 1.6, HEAD_R * 0.5, 0.07), cloth)
	# The hat's parts are under their own tilted node: merged with the head's by baking the lot.
	var baked := ModelKit.bake(head)
	_body.add_child(baked)
