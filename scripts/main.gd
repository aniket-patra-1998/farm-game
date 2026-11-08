extends Node2D
## Wires the farm, camera and HUD together, frames the farm on any screen,
## and handles zooming and moving around the farm.
##
## Touch: pinch to zoom, two-finger drag to move, or one-finger drag with the Hand tool.
## Mouse: wheel to zoom, right- or middle-drag to move. Trackpad gestures also work.

const MAX_ZOOM_FACTOR := 3.5 # how far you can zoom in, relative to the whole-farm view
const WHEEL_STEP := 1.1

var grid: FarmGrid
var camera: Camera2D
var hud: FarmHud

var _base_zoom := 1.0       # zoom that shows the whole farm; also the furthest out
var _touches := {}          # finger index -> screen position
var _pinch_dist := 0.0
var _mouse_panning := false


func _ready() -> void:
	grid = FarmGrid.new()
	add_child(grid)

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	hud = FarmHud.new()
	add_child(hud)

	hud.tool_selected.connect(grid.set_tool)
	grid.info.connect(hud.show_message)
	Game.message.connect(hud.show_message)

	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


## Zoom so the whole farm fits between the top bar and the toolbar,
## in landscape or portrait, on phones and tablets.
func _fit_camera() -> void:
	var view := get_viewport_rect().size
	var bounds := grid.get_bounds()
	var usable := view - Vector2(0, FarmHud.TOP_H + FarmHud.BOTTOM_H)
	_base_zoom = minf(usable.x / (bounds.size.x * 1.04), usable.y / (bounds.size.y * 1.04))
	camera.zoom = Vector2(_base_zoom, _base_zoom)
	# The free area is shifted down by half the difference between the bars.
	var shift := (FarmHud.TOP_H - FarmHud.BOTTOM_H) / 2.0
	camera.position = bounds.get_center() - Vector2(0, shift / _base_zoom)


# ---------------------------------------------------------------- zoom and move

func _unhandled_input(event: InputEvent) -> void:
	if Game.modal_open:
		_touches.clear()
		_mouse_panning = false
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, WHEEL_STEP)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / WHEEL_STEP)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mouse_panning = mb.pressed

	elif event is InputEventMouseMotion and _mouse_panning:
		_pan((event as InputEventMouseMotion).relative)

	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		_zoom_at(mg.position, mg.factor)

	elif event is InputEventPanGesture:
		_pan(-(event as InputEventPanGesture).delta * 24.0)

	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
		if _touches.size() == 2:
			# A second finger means zoom or move, never farming.
			grid.cancel_paint()
			_pinch_dist = _two_finger_distance()

	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if not _touches.has(d.index):
			return
		_touches[d.index] = d.position
		if _touches.size() >= 2:
			var dist := _two_finger_distance()
			if _pinch_dist > 0.0:
				_zoom_at(_two_finger_center(), dist / _pinch_dist)
			_pinch_dist = dist
			_pan(d.relative / 2.0)
		elif grid.tool == "hand" and d.index == 0:
			_pan(d.relative)


func _two_finger_distance() -> float:
	var pts := _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _two_finger_center() -> Vector2:
	var pts := _touches.values()
	return ((pts[0] as Vector2) + (pts[1] as Vector2)) / 2.0


## Screen point -> world point for the current camera (the camera is centred on the view).
func _to_world(screen_pos: Vector2) -> Vector2:
	var view := get_viewport_rect().size
	return camera.position + (screen_pos - view / 2.0) / camera.zoom.x


## Zooms keeping the point under the finger or cursor in place.
func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := _to_world(screen_pos)
	var z := clampf(camera.zoom.x * factor, _base_zoom, _base_zoom * MAX_ZOOM_FACTOR)
	camera.zoom = Vector2(z, z)
	camera.position += before - _to_world(screen_pos)
	_clamp_camera()


func _pan(screen_delta: Vector2) -> void:
	camera.position -= screen_delta / camera.zoom.x
	_clamp_camera()


## Keeps the farm on screen. At the whole-farm zoom this pins the camera to the framed view.
func _clamp_camera() -> void:
	var z := camera.zoom.x
	var view := get_viewport_rect().size
	var area := grid.get_bounds().grow_individual(0, FarmHud.TOP_H / z, 0, FarmHud.BOTTOM_H / z)
	var half := view / (2.0 * z)
	var lo := area.position + half
	var hi := area.end - half
	camera.position.x = clampf(camera.position.x, lo.x, hi.x) if lo.x <= hi.x else area.get_center().x
	camera.position.y = clampf(camera.position.y, lo.y, hi.y) if lo.y <= hi.y else area.get_center().y
