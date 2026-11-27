class_name ClockHands
extends Node
## Turns a clock face's two hands to the farm's hour: a model's `clock_*` part, whose first two parts are the
## hour hand and then the minute hand (by order: a bake keeps no names), each built pointing up from the middle
## of the face, the face looking along the part's +z. Added by DecorMotion.start. The hour is the one the sky
## goes by (DayCycle.local_hour).

const HOURS_ROUND := 12.0   # the hour hand goes round once in these
const EVERY := 1.0          # seconds between looks at the time: a minute hand moves too slowly to need more

var _wait := 0.0


func _ready() -> void:
	show_hour(DayCycle.local_hour(Game.look_now(), DayCycle.device_bias_minutes()))


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = EVERY
	var part := get_parent() as Node3D
	if part != null and part.is_visible_in_tree():
		show_hour(DayCycle.local_hour(Game.look_now(), DayCycle.device_bias_minutes()))


## Points the hands at `hour` (0..24, with its fraction for the minutes).
func show_hour(hour: float) -> void:
	var hands: Array[Node3D] = []
	for c in (get_parent().get_children() if get_parent() != null else []):
		if c is Node3D:
			hands.append(c as Node3D)
	if hands.size() > 0:
		hands[0].rotation.z = -TAU * fposmod(hour, HOURS_ROUND) / HOURS_ROUND
	if hands.size() > 1:
		hands[1].rotation.z = -TAU * fposmod(hour, 1.0)
