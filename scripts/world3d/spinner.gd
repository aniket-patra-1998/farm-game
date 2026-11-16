class_name Spinner
extends Node
## Turns its parent about the parent's own upright while the parent shows: a model's `spin_*` part (windmill
## sails, a press's bar). Added by DecorMotion.start; the model's file holds only the part and its name.

var speed := 1.0   # radians a second


func _process(delta: float) -> void:
	var part := get_parent() as Node3D
	if part != null and part.is_visible_in_tree():
		part.rotate_object_local(Vector3.UP, speed * delta)
