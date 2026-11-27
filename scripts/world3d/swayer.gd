class_name Swayer
extends Node
## Floats its parent while the parent shows: a slow rise and fall and a slight lean, as a moored balloon rides
## the air. A model's `sway_*` part; added by DecorMotion.start.

const RISE := 0.05      # tiles up and down from where it rests
const LEAN := 0.022     # radians to either side
const PERIOD := 7.0     # seconds for one rise and fall
const LEAN_PERIOD := 11.0

var _rest := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
	var part := get_parent() as Node3D
	if part != null:
		_rest = part.position
		_t = fposmod(_rest.x * 3.1 + _rest.z * 1.7, PERIOD)   # (two side by side are out of step)


func _process(delta: float) -> void:
	var part := get_parent() as Node3D
	if part == null or not part.is_visible_in_tree():
		return
	_t += delta
	part.position = _rest + Vector3(0.0, RISE * sin(TAU * _t / PERIOD), 0.0)
	part.rotation.z = LEAN * sin(TAU * _t / LEAN_PERIOD)
	part.rotation.x = LEAN * 0.6 * cos(TAU * _t / LEAN_PERIOD * 0.7)
