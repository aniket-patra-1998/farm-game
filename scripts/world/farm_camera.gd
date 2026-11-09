class_name FarmCamera
extends Camera2D
## The farm camera: eased zoom that keeps the point under the cursor or fingers still, panning that
## glides on after you let go and slows naturally, and soft edges: you can pull a little past the end
## of the land, and it springs back. Everything is frame-rate independent (exponential easing).
##
## Main feeds it input (pan_by, zoom_by, begin_drag, end_drag); bounds come from area_provider.

const ZOOM_EASE := 14.0      # how quickly zoom catches up with its target (per second)
const FRICTION := 5.5        # how quickly a glide slows down (per second)
const SPRING := 10.0         # how quickly it springs back inside the edges (per second)
const STRETCH := 0.35        # how much a drag past the edge still moves (rubber band)
const MIN_GLIDE := 8.0       # glides slower than this (px/s on screen) stop

var min_zoom := 0.2
var max_zoom := 2.0
var target_zoom := 1.0
var top_margin := 0.0        # screen px covered by the top bar
var bottom_margin := 0.0     # screen px covered by the toolbar
var area_provider: Callable  # () -> Rect2: the world area the view may show

var _focus := Vector2.ZERO   # screen point a zoom is anchored to
var _velocity := Vector2.ZERO  # world units per second, while gliding
var _dragging := false
var _last_pan_msec := 0


## Jumps straight to a view, with no easing or glide.
func snap(world_pos: Vector2, z: float) -> void:
	target_zoom = clampf(z, min_zoom, max_zoom)
	zoom = Vector2(target_zoom, target_zoom)
	position = world_pos
	_velocity = Vector2.ZERO


func begin_drag() -> void:
	_dragging = true
	_velocity = Vector2.ZERO


func end_drag() -> void:
	_dragging = false
	# A finger that stopped before lifting shouldn't fling the view.
	if Time.get_ticks_msec() - _last_pan_msec > 80:
		_velocity = Vector2.ZERO


func is_dragging() -> bool:
	return _dragging


## Moves the view by a screen distance (finger or mouse movement), tracking speed for the glide.
func pan_by(screen_delta: Vector2) -> void:
	var world := screen_delta / zoom.x
	var lo_hi := _limits(zoom.x)
	# Past the edge, a drag only moves a fraction as far: the edge feels elastic.
	var next := position - world
	if lo_hi.size() == 2:
		var lo: Vector2 = lo_hi[0]
		var hi: Vector2 = lo_hi[1]
		if (next.x < lo.x and world.x > 0.0) or (next.x > hi.x and world.x < 0.0):
			world.x *= STRETCH
		if (next.y < lo.y and world.y > 0.0) or (next.y > hi.y and world.y < 0.0):
			world.y *= STRETCH
	position -= world
	var now := Time.get_ticks_msec()
	var dt := maxf(0.001, (now - _last_pan_msec) / 1000.0)
	_last_pan_msec = now
	if dt < 0.1:
		# Smoothed speed, so one jittery sample doesn't decide the glide.
		_velocity = _velocity.lerp(-world / dt, 0.5)
	else:
		_velocity = Vector2.ZERO


## Zooms by a factor around a screen point. Instant for pinches (it must follow the fingers), eased
## for the mouse wheel and buttons.
func zoom_by(factor: float, screen_pos: Vector2, instant := false) -> void:
	target_zoom = clampf(target_zoom * factor, min_zoom, max_zoom)
	_focus = screen_pos
	if instant:
		_apply_zoom(target_zoom)


## Screen point -> world point for the current view (the camera is centred on the view).
func to_world(screen_pos: Vector2) -> Vector2:
	var view := get_viewport_rect().size
	return position + (screen_pos - view / 2.0) / zoom.x


func _process(delta: float) -> void:
	if absf(zoom.x - target_zoom) > 0.0001:
		_apply_zoom(lerpf(zoom.x, target_zoom, 1.0 - exp(-ZOOM_EASE * delta)))
	if not _dragging:
		if _velocity.length() * zoom.x > MIN_GLIDE:
			position += _velocity * delta
			_velocity *= exp(-FRICTION * delta)
		else:
			_velocity = Vector2.ZERO
		_spring_back(delta)


func _apply_zoom(z: float) -> void:
	var before := to_world(_focus)
	zoom = Vector2(z, z)
	position += before - to_world(_focus)


## Eases the view back inside its limits, and stops any glide heading further out.
func _spring_back(delta: float) -> void:
	var lo_hi := _limits(zoom.x)
	if lo_hi.size() != 2:
		return
	var lo: Vector2 = lo_hi[0]
	var hi: Vector2 = lo_hi[1]
	var inside := Vector2(clampf(position.x, lo.x, hi.x), clampf(position.y, lo.y, hi.y))
	if inside.is_equal_approx(position):
		return
	if (position.x < lo.x and _velocity.x < 0.0) or (position.x > hi.x and _velocity.x > 0.0):
		_velocity.x = 0.0
	if (position.y < lo.y and _velocity.y < 0.0) or (position.y > hi.y and _velocity.y > 0.0):
		_velocity.y = 0.0
	position = position.lerp(inside, 1.0 - exp(-SPRING * delta))


## [lo, hi] for the camera position at a zoom, or [] when there are no limits yet.
func _limits(z: float) -> Array:
	if not area_provider.is_valid():
		return []
	var area: Rect2 = area_provider.call()
	var view := get_viewport_rect().size
	area = area.grow_individual(0, top_margin / z, 0, bottom_margin / z)
	var half := view / (2.0 * z)
	var lo := area.position + half
	var hi := area.end - half
	# When the view is bigger than the area, centre on it.
	if lo.x > hi.x:
		lo.x = area.get_center().x
		hi.x = lo.x
	if lo.y > hi.y:
		lo.y = area.get_center().y
		hi.y = lo.y
	return [lo, hi]
