class_name SkyLayer
extends CanvasLayer
## The sky behind the farm: a gradient that follows the real time of day,
## the sun and moon on their arcs, stars at night and drifting clouds.
## Drawn in screen space, so it stays put while the camera zooms and pans.

const CLOUD_COUNT := 18  # all of them show when it's overcast; a few on a clear day
const STAR_COUNT := 70

var hour := 12.0
var weather := {}  # from Weather.current, set by main
var _canvas: Node2D
var _clouds: Array = []   # {x, y, scale, speed, puffs:[Vector3(dx, dy, r)]}
var _stars: Array = []    # Vector3(x 0..1, y 0..1, phase)


func _ready() -> void:
	layer = -1
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_sky)
	add_child(_canvas)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for k in CLOUD_COUNT:
		var puffs: Array = []
		var n := rng.randi_range(4, 7)
		for p in n:
			puffs.append(Vector3(rng.randf_range(-60, 60), rng.randf_range(-12, 8), rng.randf_range(18, 34)))
		_clouds.append({"x": rng.randf(), "y": rng.randf_range(0.06, 0.42), "scale": rng.randf_range(0.6, 1.25),
			"speed": rng.randf_range(6.0, 14.0), "puffs": puffs})
	for k in STAR_COUNT:
		_stars.append(Vector3(rng.randf(), rng.randf_range(0.0, 0.6), rng.randf() * TAU))


func _process(delta: float) -> void:
	hour = DayCycle.local_hour(Game.now(), DayCycle.device_bias_minutes())
	var w := get_viewport().get_visible_rect().size.x
	for c in _clouds:
		var cloud_scale: float = c["scale"]
		c["x"] = float(c["x"]) + float(c["speed"]) * cloud_scale * delta / maxf(1.0, w)
		if float(c["x"]) > 1.15:
			c["x"] = -0.15
	_canvas.queue_redraw()


func _draw_sky() -> void:
	var size := get_viewport().get_visible_rect().size
	var look := DayCycle.sample(hour)
	var dark: float = look["dark"]
	var top: Color = look["top"]
	var horizon: Color = look["horizon"]
	var cover := float(weather.get("cover", 0.1))
	var dim := float(weather.get("dim", 0.0))
	# Cloud cover greys the sky; a storm darkens it.
	var grey := Color("#9aa4b2").lerp(Color("#232836"), dark)
	top = top.lerp(grey.darkened(dim), cover * 0.75)
	horizon = horizon.lerp(grey.lightened(0.1).darkened(dim), cover * 0.7)

	# Gradient: a few bands blended top to horizon (cheap and smooth enough at phone sizes).
	var bands := 24
	for b in bands:
		var t0 := float(b) / bands
		var t1 := float(b + 1) / bands
		var c0 := top.lerp(horizon, pow(t0, 1.4))
		var c1 := top.lerp(horizon, pow(t1, 1.4))
		_canvas.draw_polygon(
			PackedVector2Array([Vector2(0, size.y * t0), Vector2(size.x, size.y * t0), Vector2(size.x, size.y * t1), Vector2(0, size.y * t1)]),
			PackedColorArray([c0, c0, c1, c1]))

	# Stars fade in after dusk and twinkle.
	if dark > 0.05 and cover < 0.7:
		var now_s := Time.get_ticks_msec() / 1000.0
		for s in _stars:
			var tw := 0.55 + 0.45 * sin(now_s * 1.7 + s.z)
			var p := Vector2(s.x * size.x, s.y * size.y)
			_canvas.draw_circle(p, 1.2 + 0.8 * tw, Color(1, 1, 0.92, dark * tw * 0.9))

	# Sun and moon ride an arc from the left horizon to the right.
	var horizon_y := size.y * 0.62
	var arc_h := size.y * 0.5
	var sun_p := DayCycle.sun_progress(hour)
	if sun_p >= 0.0:
		var pos := Vector2(lerpf(size.x * 0.06, size.x * 0.94, sun_p), horizon_y - sin(sun_p * PI) * arc_h)
		var low := 1.0 - sin(sun_p * PI) # 1 near the horizon
		var core := Color("#fff6c8").lerp(Color("#ffb066"), low * 0.8)
		core.a = clampf(1.2 - cover * 1.3, 0.0, 1.0)  # hidden behind thick cloud
		for g in 4:
			_canvas.draw_circle(pos, 34.0 + g * 18.0, Color(core.r, core.g, core.b, (0.10 - g * 0.02) * core.a))
		_canvas.draw_circle(pos, 26.0, core)
	var moon_p := DayCycle.moon_progress(hour)
	if moon_p >= 0.0 and cover < 0.75:
		var mpos := Vector2(lerpf(size.x * 0.06, size.x * 0.94, moon_p), horizon_y - sin(moon_p * PI) * arc_h * 0.9)
		_canvas.draw_circle(mpos, 40.0, Color(0.85, 0.9, 1.0, 0.08))
		_canvas.draw_circle(mpos, 20.0, Color("#eef1ff"))
		_canvas.draw_circle(mpos + Vector2(7, -5), 17.0, top.lerp(horizon, 0.3)) # crescent shadow

	# Clouds take the light's colour: white by day, peach at sunset, slate at night.
	var cloud_col := Color(1, 1, 1).lerp(look["light"], 0.65).lerp(Color("#7d8796"), cover * 0.6).darkened(dim * 1.2)
	cloud_col.a = 0.92 - 0.25 * dark
	var shade := cloud_col.darkened(0.12)
	var shown := int(round(lerpf(5.0, float(CLOUD_COUNT), clampf(cover, 0.0, 1.0))))
	for c in _clouds.slice(0, shown):
		var base := Vector2(float(c["x"]) * size.x, float(c["y"]) * size.y)
		var sc: float = c["scale"]
		for puff in c["puffs"]:
			_canvas.draw_circle(base + Vector2(puff.x, puff.y + 6) * sc, puff.z * sc, shade)
		for puff in c["puffs"]:
			_canvas.draw_circle(base + Vector2(puff.x, puff.y) * sc, puff.z * sc, cloud_col)
