class_name WeatherLayer
extends CanvasLayer
## Weather drawn over the farm in screen space: rain streaks and splashes, snowflakes and lightning flashes. Main
## sets `look` (from Weather.current) every frame; a strike (WeatherEvents.struck) flashes the screen (`flash_now`).
## Rain and snow are Godot's own GPU particles (owner, 27 Nov: the engine's, not ours drawn by hand each frame):
## the graphics chip moves them, how much falls is each emitter's `amount_ratio`, and their pictures are gradients
## made here (no files). Snow falls in two depths: far flakes small, faint and slow, near ones bigger and quicker.

const MAX_DROPS := 320
const MAX_SPLASHES := 90
const MAX_FAR_FLAKES := 180
const MAX_NEAR_FLAKES := 80
const SCREEN := 1080.0     # sizes and speeds are for a screen this tall (in pixels), scaled to the real one
const FLASH_FALL := 2.8    # a flash fades this fast (a second)
const DROP_SECONDS := 0.75 # a raindrop's fall across the screen
const RAIN_SLANT := -0.11  # the rain's lean (x per y)
## Frames the weather is drawn under the first loading cover, all but unseen: the A05s froze 2.3 s the first time
## rain fell (its marks drawn the first time), so every emitter runs once where nobody sees it.
const WARM_FRAMES := 3
const WARM_ALPHA := 0.02

var look := {}
var _rain: GPUParticles2D
var _splash: GPUParticles2D
var _far: GPUParticles2D
var _near: GPUParticles2D
var _canvas: Node2D        # the lightning flash
var _flash := 0.0
var _warm_left := WARM_FRAMES


func _ready() -> void:
	layer = 1
	_rain = _emitter(MAX_DROPS, DROP_SECONDS, _streak(), true)
	_splash = _emitter(MAX_SPLASHES, 0.25, _ring(), false)
	_far = _emitter(MAX_FAR_FLAKES, 7.0, _flake(), false)
	_near = _emitter(MAX_NEAR_FLAKES, 4.0, _flake(), false)
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_flash)
	add_child(_canvas)
	get_viewport().size_changed.connect(_fit)
	_fit()


## A lightning strike's flash on the screen, `strength` 0..1 (a near strike is brighter).
func flash_now(strength: float) -> void:
	_flash = maxf(_flash, clampf(strength, 0.0, 1.0))


func _process(delta: float) -> void:
	var rain := float(look.get("rain", 0.0))
	var snow := float(look.get("snow", 0.0))
	var warming := _warm_left > 0 and LoadingCover.covering > 0
	if warming:
		_warm_left -= 1
		rain = WARM_ALPHA
		snow = WARM_ALPHA
	_tune(_rain, rain, Color(0.82, 0.88, 0.98, 0.32 + 0.2 * rain))
	_tune(_splash, rain, Color(0.85, 0.9, 1.0, 0.5 * rain))
	_tune(_far, snow, Color(1, 1, 1, 0.6 * snow))
	_tune(_near, snow, Color(1, 1, 1, 0.85 * snow))
	_flash = maxf(0.0, _flash - delta * FLASH_FALL)
	if _flash > 0.0 or _canvas.visible:
		_canvas.visible = _flash > 0.0
		_canvas.queue_redraw()


static func _tune(p: GPUParticles2D, amount: float, tint: Color) -> void:
	var on := amount > 0.005
	if on and not p.emitting:
		p.restart()   # (from the start, with its preprocess: the sky already full, not filling from the top)
	p.emitting = on
	p.amount_ratio = clampf(amount, 0.0, 1.0)
	p.modulate = tint


func _draw_flash() -> void:
	if _flash > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size),
			Color(0.92, 0.95, 1.0, 0.55 * _flash * _flash))


## Each emitter placed and sized for the screen as it is now (sizes for a SCREEN-tall one, scaled).
func _fit() -> void:
	var size := get_viewport().get_visible_rect().size
	var k := size.y / SCREEN
	var fall := size.y / DROP_SECONDS
	_shape(_rain, Vector2(size.x * 0.55, -size.y * 0.05), Vector2(size.x * 0.7, 4.0),
		Vector2(RAIN_SLANT, 1.0), fall * 0.9, fall * 1.3, 0.0, k * 0.9, k * 1.4)
	_shape(_splash, Vector2(size.x * 0.5, size.y * 0.65), Vector2(size.x * 0.5, size.y * 0.33),
		Vector2.UP, 0.0, 0.0, 0.0, k * 0.5, k * 1.0)
	(_splash.process_material as ParticleProcessMaterial).scale_curve = _grow()
	(_splash.process_material as ParticleProcessMaterial).color_ramp = _fade()
	# (Flakes are born all over the screen and fade in and out, so the whole sky is snowing at once.)
	_shape(_far, size / 2.0, size * 0.6, Vector2.DOWN, size.y * 0.035, size.y * 0.07, 1.0, k * 0.6, k * 1.0)
	_shape(_near, size / 2.0, size * 0.6, Vector2.DOWN, size.y * 0.08, size.y * 0.12, 1.6, k * 1.2, k * 1.8)
	for p: GPUParticles2D in [_far, _near]:
		(p.process_material as ParticleProcessMaterial).color_ramp = _born_and_gone()
	for p: GPUParticles2D in [_rain, _splash, _far, _near]:
		p.visibility_rect = Rect2(-size * 0.2, size * 1.4)


## Where an emitter's particles start (a box about `at`, half-extents `half`), which way and how fast they go,
## how much they sway (`sway`, turbulence) and how big they are.
static func _shape(p: GPUParticles2D, at: Vector2, half: Vector2, way: Vector2, slow: float, fast: float,
		sway: float, small: float, big: float) -> void:
	p.position = at
	var m := p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(half.x, half.y, 0.0)
	m.direction = Vector3(way.x, way.y, 0.0)
	m.spread = 2.0
	m.initial_velocity_min = slow
	m.initial_velocity_max = fast
	m.gravity = Vector3.ZERO
	m.scale_min = small
	m.scale_max = big
	m.turbulence_enabled = sway > 0.0   # (each flake drifts on its own sway)
	m.turbulence_noise_strength = sway
	m.turbulence_noise_scale = 3.0
	m.turbulence_noise_speed_random = 0.5
	m.turbulence_influence_min = 0.05
	m.turbulence_influence_max = 0.15


func _emitter(amount: int, life: float, picture: Texture2D, along: bool) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life   # (a shower starts with the sky already full)
	p.texture = picture
	p.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.particle_flag_disable_z = true
	if along:   # (a streak points the way it falls)
		m.particle_flag_align_y = true
	p.process_material = m
	p.emitting = false
	add_child(p)
	return p


## The pictures: a raindrop's streak, a splash's ring and a soft round flake, all gradients.
static func _streak() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 1))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 2
	t.height = 22
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	return t


static func _ring() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 0.85, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return _round(g, 16)


static func _flake() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	return _round(g, 12)


static func _round(g: Gradient, size: int) -> Texture2D:
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## A flake fades in as it is born and out before it goes.
static func _born_and_gone() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.85, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## A splash's ring fades as it grows.
static func _fade() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## A splash's ring grows as it fades.
static func _grow() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.3))
	c.add_point(Vector2(1.0, 1.6))
	c.max_value = 2.0
	var t := CurveTexture.new()
	t.curve = c
	return t
