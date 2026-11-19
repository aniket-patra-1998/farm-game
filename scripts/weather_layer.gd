class_name WeatherLayer
extends CanvasLayer
## Weather drawn over the farm in screen space: rain streaks and splashes, snowflakes and
## lightning flashes. Main sets `look` (from Weather.current) and `dark` every frame; a strike (WeatherEvents.struck)
## flashes the screen (`flash_now`). After rain, while the farm is still wet and the sun is out, a soft rainbow
## (shaders/rainbow.gdshader, data/weather.json "rainbow"; Quality `rainbow`, off on low) stands over the farm:
## like a real one it stays where it is on the screen as the view moves, and it fades as the farm dries.

const MAX_DROPS := 320
const MAX_FLAKES := 180
const FLASH_FALL := 2.8   # a flash fades this fast (a second)
const RAINBOW_SHADER := preload("res://shaders/rainbow.gdshader")
const RAINBOW_SHOWN := 0.004   # below this the rainbow's rect is hidden (no cost at all)

var look := {}
var dark := 0.0          # how dark the hour is, 0 day .. 1 night (main, from DayCycle)
var wet := 0.0           # how wet the farm still is from rain, eased as SurfaceWeather does
var rainbow := 0.0       # the rainbow shown now, eased toward rainbow_strength
var rainbow_look := {}:  # tools only: overrides of data/weather.json "rainbow" (variants for a sheet)
	set(v):
		rainbow_look = v
		_rule = {}
var _rainbow: ColorRect
var _rule := {}
var _canvas: Node2D
var _drops: Array = []   # Vector3(x 0..1, y 0..1, speed)
var _flakes: Array = []  # Vector4(x, y, speed, phase)
var _splashes: Array = [] # Vector3(x, y, age)
var _flash := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 1
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_weather)
	add_child(_canvas)
	_rainbow = ColorRect.new()
	_rainbow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rainbow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rainbow.material = ShaderMaterial.new()
	(_rainbow.material as ShaderMaterial).shader = RAINBOW_SHADER
	_rainbow.visible = false
	add_child(_rainbow)
	move_child(_rainbow, 0)   # (under the rain, which falls in front of it)
	_rng.seed = 99
	for k in MAX_DROPS:
		_drops.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.9, 1.4)))
	for k in MAX_FLAKES:
		_flakes.append(Vector4(_rng.randf(), _rng.randf(), _rng.randf_range(0.6, 1.2), _rng.randf() * TAU))


## A lightning strike's flash on the screen, `strength` 0..1 (a near strike is brighter).
func flash_now(strength: float) -> void:
	_flash = maxf(_flash, clampf(strength, 0.0, 1.0))


func _process(delta: float) -> void:
	var rain := float(look.get("rain", 0.0))
	var snow := float(look.get("snow", 0.0))
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
	_flash = maxf(0.0, _flash - delta * FLASH_FALL)
	_advance_rainbow(rain, delta)
	if rain > 0.0 or snow > 0.0 or _flash > 0.0 or not _splashes.is_empty():
		_canvas.queue_redraw()
	elif _canvas.visible:
		_canvas.queue_redraw()


## The rainbow's look: data/weather.json "rainbow" with this layer's overrides on top.
func rainbow_rule() -> Dictionary:
	if _rule.is_empty():
		_rule = WeatherEvents.data("rainbow").duplicate()
		_rule.merge(rainbow_look, true)
	return _rule


func _advance_rainbow(rain: float, delta: float) -> void:
	wet = SurfaceWeather.ease_toward(wet, minf(rain / SurfaceWeather.RAIN_FOR_FULL, 1.0), delta,
		SurfaceWeather.WET_RISE, SurfaceWeather.WET_FALL)
	var r := rainbow_rule()
	var target := 0.0
	if bool(Quality.value("rainbow")):
		target = rainbow_strength(wet, rain, float(look.get("cover", 0.0)), dark, r)
	rainbow = SurfaceWeather.ease_toward(rainbow, target, delta, float(r["ease"]), float(r["ease"]))
	_rainbow.visible = rainbow > RAINBOW_SHOWN
	if not _rainbow.visible:
		return
	var m := _rainbow.material as ShaderMaterial
	var size := get_viewport().get_visible_rect().size
	m.set_shader_parameter("strength", rainbow * float(r["strength"]))
	m.set_shader_parameter("saturation", float(r["saturation"]))
	m.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	m.set_shader_parameter("centre_x", float(r["centre_x"]))
	m.set_shader_parameter("centre_y", float(r["centre_y"]))
	m.set_shader_parameter("radius", float(r["radius"]))
	m.set_shader_parameter("width", float(r["width"]))


## How much of a rainbow shows (0..1) on a farm `wet` (0..1) from rain that has stopped (`rain` under the rule's
## `rain_below`), under `cover` cloud (none past `max_cover`, fading in over the last `cover_fade` of it), at an
## hour `dark` (none past `max_dark`: the sun must be up): full while the farm is at least `full_wet` wet, then
## fading as it dries.
static func rainbow_strength(wet_now: float, rain: float, cover: float, dark_now: float, rule: Dictionary) -> float:
	if rain >= float(rule["rain_below"]) or cover >= float(rule["max_cover"]) or dark_now >= float(rule["max_dark"]):
		return 0.0
	var by_wet := clampf(wet_now / float(rule["full_wet"]), 0.0, 1.0)
	var by_cover := clampf((float(rule["max_cover"]) - cover) / float(rule["cover_fade"]), 0.0, 1.0)
	var by_sun := clampf((float(rule["max_dark"]) - dark_now) / float(rule["max_dark"]), 0.0, 1.0)
	return by_wet * by_cover * sqrt(by_sun)


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
