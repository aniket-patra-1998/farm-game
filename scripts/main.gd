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
var sky: SkyLayer
var light: CanvasModulate  # tints the whole farm for the time of day
var night: NightGlow
var shadows: CloudShadows
var grade: ColorRect       # colour grade over the farm and sky
var weather_fx: WeatherLayer

var _base_zoom := 1.0       # zoom that shows the whole farm; also the furthest out
var _touches := {}          # finger index -> screen position
var _pinch_dist := 0.0
var _mouse_panning := false


func _ready() -> void:
	sky = SkyLayer.new()
	add_child(sky)

	light = CanvasModulate.new()
	add_child(light)

	grid = FarmGrid.new()
	add_child(grid)

	shadows = CloudShadows.new()
	shadows.grid = grid
	add_child(shadows)

	var grade_layer := CanvasLayer.new()
	grade_layer.layer = 1
	add_child(grade_layer)
	grade = ColorRect.new()
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grade.gdshader")
	grade.material = mat
	grade_layer.add_child(grade)

	weather_fx = WeatherLayer.new()
	add_child(weather_fx)

	night = NightGlow.new()
	night.grid = grid
	add_child(night)

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	hud = FarmHud.new()
	add_child(hud)

	hud.tool_selected.connect(grid.set_tool)
	hud.place_requested.connect(grid.start_placing)
	hud.cancel_place_requested.connect(grid.cancel_placing)
	hud.place_stored_requested.connect(grid.start_placing_stored)
	grid.placing_changed.connect(hud.show_placing)
	grid.object_tapped.connect(hud.show_building)
	grid.info.connect(hud.show_message)
	Game.message.connect(hud.show_message)

	get_viewport().size_changed.connect(_fit_camera)
	Game.farm_expanded.connect(func(_size: int) -> void: _fit_camera())
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


# ---------------------------------------------------------------- time of day

func _process(_delta: float) -> void:
	var hour := sky.hour
	var look := DayCycle.sample(hour)
	var w := Game.weather()
	var dark: float = look["dark"]
	# Light on the farm: the time of day's colour, greyer and dimmer under cloud.
	var l: Color = look["light"]
	l = l.lerp(Color(l.v, l.v, l.v), float(w["desat"]) * 0.5).darkened(float(w["dim"]))
	light.color = l
	sky.weather = w
	weather_fx.look = w
	# Windows light up at night and in a dark storm.
	night.dark = maxf(dark, clampf(float(w["dim"]) * 1.6 - 0.2, 0.0, 0.7))
	# Cloud shadows need the sun out and some cloud about.
	var sun := DayCycle.sun_progress(hour)
	var cover: float = w["cover"]
	shadows.strength = 0.0 if sun < 0.0 else (1.0 - dark) * clampf(1.0 - absf(cover - 0.45) / 0.4, 0.0, 1.0)
	# Colour grade: richer by day, cool and soft at night, warm low sun, fog haze.
	var m := grade.material as ShaderMaterial
	m.set_shader_parameter("saturation", lerpf(1.1, 0.8, dark) * (1.0 - float(w["desat"])))
	m.set_shader_parameter("contrast", lerpf(1.05, 0.95, dark))
	m.set_shader_parameter("lift", Vector3(0.02, 0.035, 0.08) * dark)
	var low := 0.0 if sun < 0.0 else pow(1.0 - sin(sun * PI), 3.0)  # 1 right at sunrise and sunset
	m.set_shader_parameter("warm", Color(1.0, 0.62, 0.32, 0.45 * low * (1.0 - cover)))
	m.set_shader_parameter("warm_from", Vector2(0.0 if sun < 0.5 else 1.0, 0.3))
	m.set_shader_parameter("haze", Color(0.84, 0.87, 0.9, float(w["fog"]) * 0.75).lerp(Color(0.25, 0.3, 0.42, float(w["fog"]) * 0.6), dark))
	m.set_shader_parameter("vignette", lerpf(0.18, 0.4, dark))


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
		elif d.index == 0 and grid.placing.is_empty() and grid.is_dragging():
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
