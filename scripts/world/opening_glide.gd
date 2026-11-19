class_name OpeningGlide
extends Node
## The opening (wow build, item 2): as the loading cover lifts on the session's first farm, the view comes down
## onto the farm from a little higher and wider over a few seconds (FarmCamera.glide_from) while the light warms
## in from cooler and softer (Farm3D.opening_cool). A tap ends it at once on the farm's own view and does nothing
## else; a drag or a pinch takes over where it is. Only the first farm of a session: the showcase and a return to
## your own open plain. Numbers in data/balance.json feel.opening_*. Our own touch (FarmVille opened flat).
## Cheap: one camera move and two environment numbers a frame for its few seconds, then the node is gone.

static var played := false   # the session's first farm has had its opening

var _camera: FarmCamera
var _world: Farm3D


## Whether this opening should play: the session's first, with a screen, and not in the loading benchmark (it
## times the first frames of play).
static func wanted(benchmark: bool) -> bool:
	return not played and not benchmark and seconds() > 0.0


static func seconds() -> float:
	return Balance.f("feel.opening_seconds")


## The view it starts from, for a farm whose own view is `goal` at zoom `z` on a screen `view_h` high: wider by
## feel.opening_zoom_from (no wider than `least_zoom`) and further up the farm by feel.opening_lift of the screen.
static func start_view(goal: Vector2, z: float, view_h: float, least_zoom: float) -> Vector3:
	var from_z := maxf(z * Balance.f("feel.opening_zoom_from"), least_zoom)
	return Vector3(goal.x, goal.y - view_h * Balance.f("feel.opening_lift") / from_z, from_z)


## How much cooler the light is `t` (0..1) of the way through: feel.opening_dim at the start, none at the end,
## warming fastest at first (ease out), so the farm is already warm as the view settles.
static func cool_at(t: float) -> float:
	var left := 1.0 - clampf(t, 0.0, 1.0)
	return Balance.f("feel.opening_dim") * left * left


## Starts the opening on `camera` (and the 3D farm's light, when there is one), under `parent`.
static func play(parent: Node, camera: FarmCamera, world: Farm3D) -> OpeningGlide:
	played = true
	var g := OpeningGlide.new()
	g._camera = camera
	g._world = world
	parent.add_child(g)
	var view_h := camera.get_viewport_rect().size.y
	var from := start_view(camera.position, camera.target_zoom, view_h, camera.min_zoom)
	camera.glide_from(Vector2(from.x, from.y), from.z, seconds())
	g._light(0.0)
	return g


func _process(_delta: float) -> void:
	var t := _camera.glide_progress()
	_light(t)
	if t >= 1.0:
		queue_free()


## A tap ends the opening on the farm's view; the tap itself is used up (it plows nothing).
func _input(event: InputEvent) -> void:
	var pressed := (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed()
	if pressed and _camera.glide_progress() < 1.0:
		_camera.end_glide()
		_light(1.0)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_light(1.0)


func _light(t: float) -> void:
	if _world != null:
		_world.opening_cool = cool_at(t)
