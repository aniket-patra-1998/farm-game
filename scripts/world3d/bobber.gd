class_name Bobber
extends Node
## Lifts its parent gently up and down, with a slight rock, while the parent shows: a model's `bob_*` part
## (the Barn's VIP badge while VIP is active). Added by DecorMotion.start; the model's file holds only the part
## and its name. It goes by the clock, so it looks the same at any frame rate.

const ROCK := 0.12   # how far it rocks, in radians, as it rides

var height := 0.02   # how far up and down from where it stands, in tiles
var speed := 1.6     # radians of its ride a second

var _rest := Vector3.ZERO   # where it stands when still
var _rest_turn := 0.0
var _at := 0.0


func _ready() -> void:
	var part := get_parent() as Node3D
	if part != null:
		_rest = part.position
		_rest_turn = part.rotation.z


func _process(delta: float) -> void:
	var part := get_parent() as Node3D
	if part == null or not part.is_visible_in_tree():
		return
	_at = fmod(_at + speed * delta, TAU)
	part.position = _rest + Vector3(0.0, sin(_at) * height, 0.0)
	part.rotation.z = _rest_turn + sin(_at * 0.5) * ROCK * 0.5
