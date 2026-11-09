class_name WeatherLayer
extends CanvasLayer
## Weather drawn over the farm in screen space: rain streaks and splashes, snowflakes and
## lightning flashes. Main sets `look` (from Weather.current) every frame.

const MAX_DROPS := 320
const MAX_FLAKES := 180

var look := {}
var _canvas: Node2D
var _drops: Array = []   # Vector3(x 0..1, y 0..1, speed)
var _flakes: Array = []  # Vector4(x, y, speed, phase)
var _splashes: Array = [] # Vector3(x, y, age)
var _flash := 0.0
var _next_flash := 4.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 1
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_weather)
	add_child(_canvas)
	_rng.seed = 99
	for k in MAX_DROPS:
		_drops.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.9, 1.4)))
	for k in MAX_FLAKES:
		_flakes.append(Vector4(_rng.randf(), _rng.randf(), _rng.randf_range(0.6, 1.2), _rng.randf() * TAU))


func _process(delta: float) -> void:
	var rain := float(look.get("rain", 0.0))
	var snow := float(look.get("snow", 0.0))
	var lightning := float(look.get("lightning", 0.0))
	for k in _drops.size():
		var d: Vector3 = _drops[k]
		d.y += delta * 1.6 * d.z
		d.x -= delta * 0.18 * d.z
		if d.y > 1.0:
			if rain > 0.0 and _rng.randf() < 0.35:
				_splashes.append(Vector3(d.x, _rng.randf_range(0.3, 0.98), 0.0))
			d = Vector3(_rng.randf() * 1.2, -0.05, d.z)
		_drops[k] = d
	for k in _flakes.size():
		var f: Vector4 = _flakes[k]
		f.y += delta * 0.09 * f.z
		f.x += delta * 0.02 * sin(f.y * 9.0 + f.w)
		if f.y > 1.02:
			f = Vector4(_rng.randf(), -0.02, f.z, f.w)
		_flakes[k] = f
	var kept: Array = []
	for s in _splashes:
		s.z += delta
		if s.z < 0.25:
			kept.append(s)
	_splashes = kept.slice(-120)
	_flash = maxf(0.0, _flash - delta * 2.8)
	if lightning > 0.0:
		_next_flash -= delta
		if _next_flash <= 0.0:
			_flash = 1.0
			_next_flash = _rng.randf_range(5.0, 13.0)
	if rain > 0.0 or snow > 0.0 or _flash > 0.0 or not _splashes.is_empty():
		_canvas.queue_redraw()
	elif _canvas.visible:
		_canvas.queue_redraw()


func _draw_weather() -> void:
	var size := get_viewport().get_visible_rect().size
	var rain := float(look.get("rain", 0.0))
	var snow := float(look.get("snow", 0.0))
	if rain > 0.01:
		var n := int(MAX_DROPS * rain)
		var col := Color(0.82, 0.88, 0.98, 0.32 + 0.2 * rain)
		var streak := Vector2(-0.18, 1.6).normalized() * (14.0 + 10.0 * rain)
		for k in n:
			var d: Vector3 = _drops[k]
			var p := Vector2(d.x * size.x, d.y * size.y)
			_canvas.draw_line(p, p + streak * d.z, col, 1.4)
		for s in _splashes:
			var a: float = (1.0 - s.z / 0.25) * 0.5 * rain
			var p := Vector2(s.x * size.x, s.y * size.y)
			_canvas.draw_arc(p, 3.0 + s.z * 22.0, PI, TAU, 8, Color(0.85, 0.9, 1.0, a), 1.2)
	if snow > 0.01:
		var n := int(MAX_FLAKES * snow)
		for k in n:
			var f: Vector4 = _flakes[k]
			var p := Vector2(f.x * size.x, f.y * size.y)
			_canvas.draw_circle(p, 1.6 + 1.6 * f.z, Color(1, 1, 1, 0.85))
	if _flash > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.92, 0.95, 1.0, 0.55 * _flash * _flash))
