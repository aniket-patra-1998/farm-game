class_name FxLayer
extends CanvasLayer
## Rewards that fly from the farm to the top bar: coins arc up to the coin counter, XP stars to the XP
## bar, and the counter pulses as each lands. Drawn above the HUD, in screen space.

const MAX_FLYERS := 60   # a cap, so a vehicle harvesting a whole field stays smooth
const PRODUCE_POOL := 6  # produce in the air at once: a fast sweep reuses the oldest, it never makes more

var hud: FarmHud
var _flying := 0
var _produce: Array[Produce] = []   # the produce flyers, made as needed (at most PRODUCE_POOL) and reused


func _ready() -> void:
	layer = 20


## Coins from a screen point to the coin counter: more coins, more of them (but never a flood).
func coins(from: Vector2, amount: int) -> void:
	if amount <= 0 or hud == null:
		return
	var n := clampi(int(round(log(float(amount)) / log(2.0))), 2, 8)
	_spray(from, n, Flyer.COIN, hud.coins_target(), func() -> void: hud.pulse("coins"))


func xp(from: Vector2, amount: int) -> void:
	if amount <= 0 or hud == null:
		return
	_spray(from, clampi(amount, 1, 4), Flyer.STAR, hud.xp_target(), func() -> void: hud.pulse("xp"))


func _spray(from: Vector2, n: int, kind: int, to: Vector2, on_land: Callable) -> void:
	for k in n:
		if _flying >= MAX_FLYERS:
			return
		var f := Flyer.new()
		f.kind = kind
		f.position = from
		add_child(f)
		_flying += 1
		# First a little burst outward, then an arc up to the counter, each a moment after the last.
		var out := from + Vector2.from_angle(randf_range(-PI, 0.0)) * randf_range(28.0, 64.0)
		var lift := Vector2(randf_range(-120.0, 120.0), -randf_range(80.0, 180.0))
		var delay := 0.05 * k
		var tw := f.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(f, "position", out, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(t: float) -> void:
			f.position = _bezier(out, out + lift, to, t)
			f.scale = Vector2.ONE * lerpf(1.0, 0.65, t), 0.0, 1.0, randf_range(0.48, 0.62)
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			on_land.call()
			_flying -= 1
			f.queue_free())


## The harvested thing itself (wow build): its picture pops up out of the plot with a little overshoot, hangs a
## beat, then arcs to the coin counter it is sold into, shrinking, a short sparkle trail behind it (data/balance.json
## `feel.produce`; the trail only where Quality `fx_trails` allows). Pooled: a sweep reuses the flyers.
func produce(from: Vector2, picture: Texture2D) -> void:
	if picture == null or hud == null:
		return
	var look := Balance.d("feel.produce")
	var p := _free_produce()
	p.start(from, picture, look, bool(look.get("trail", true)) and bool(Quality.value("fx_trails")), hud.coins_target())


## How many produce flyers exist (the pool, for tests).
func produce_made() -> int:
	return _produce.size()


func _free_produce() -> Produce:
	for p in _produce:
		if not p.busy:
			return p
	if _produce.size() < PRODUCE_POOL:
		var p := Produce.new()
		add_child(p)
		_produce.append(p)
		return p
	var oldest := _produce[0]   # the longest in the air lands early
	_produce.remove_at(0)
	_produce.append(oldest)
	return oldest


static func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


## A coin or an XP star, drawn in code (art can replace it later).
class Flyer extends Node2D:
	const COIN := 0
	const STAR := 1
	var kind := COIN

	func _process(_d: float) -> void:
		rotation += 0.0  # kept still: coins read better upright

	func _draw() -> void:
		if kind == COIN:
			draw_circle(Vector2(0, 2), 11.0, Color(0, 0, 0, 0.18))
			draw_circle(Vector2.ZERO, 11.0, Color("#c98a12"))
			draw_circle(Vector2.ZERO, 9.0, Color("#ffd23f"))
			draw_arc(Vector2.ZERO, 6.0, 0, TAU, 20, Color("#e8a91c"), 1.6)
			draw_circle(Vector2(-3.5, -3.5), 2.6, Color(1, 1, 1, 0.85))
		else:
			var pts := PackedVector2Array()
			for k in 10:
				var r := 12.0 if k % 2 == 0 else 5.0
				var a := -PI / 2.0 + k * PI / 5.0
				pts.append(Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, Color("#9be7ff"))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#3aa7d8"), 1.5)
			draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.9))


## One harvested thing in the air: its picture and a sparkle trail (a CPU particle set, emitted in world space so
## it streams behind; no script runs per spark).
class Produce extends Sprite2D:
	var busy := false
	var trail: CPUParticles2D
	var _tw: Tween

	func _init() -> void:
		modulate.a = 0.0   # (a flyer, not a surface: unseen at rest, faded out when it lands)
		trail = CPUParticles2D.new()
		trail.local_coords = false
		trail.emitting = false
		trail.show_behind_parent = true
		trail.texture = UiIcon.glow_texture()
		trail.direction = Vector2.DOWN
		trail.spread = 180.0
		trail.gravity = Vector2(0, 60)
		trail.initial_velocity_min = 8.0
		trail.initial_velocity_max = 26.0
		var fade := Gradient.new()
		fade.set_color(0, Color(1.0, 0.97, 0.82, 1.0))
		fade.set_color(1, Color(1.0, 0.78, 0.25, 0.0))
		trail.color_ramp = fade
		add_child(trail)

	func start(from: Vector2, picture: Texture2D, look: Dictionary, sparkle: bool, to: Vector2) -> void:
		if _tw != null:
			_tw.kill()
		busy = true
		trail.emitting = false
		texture = picture
		var px := float(look.get("px", 46))
		var full := Vector2.ONE * px / maxf(1.0, float(picture.get_width()))
		position = from
		scale = full * 0.2
		modulate.a = 1.0
		trail.amount = int(look.get("sparks", 12))
		trail.lifetime = float(look.get("spark_seconds", 0.4))
		trail.scale_amount_min = float(look.get("spark_px", 10)) * 0.5 / 64.0 / full.x
		trail.scale_amount_max = float(look.get("spark_px", 10)) / 64.0 / full.x
		var up := from + Vector2(randf_range(-10.0, 10.0), -float(look.get("rise", 56)))
		_tw = create_tween()
		var pop := float(look.get("pop_seconds", 0.22))
		_tw.tween_property(self, "position", up, pop).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.parallel().tween_property(self, "scale", full, pop).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_interval(float(look.get("hang_seconds", 0.12)))
		if sparkle:
			_tw.tween_callback(func() -> void: trail.emitting = true)
		var lift := up + Vector2(randf_range(-60.0, 60.0), -float(look.get("arc", 120)))
		_tw.tween_method(func(t: float) -> void:
			position = FxLayer._bezier(up, lift, to, t)
			scale = full * lerpf(1.0, float(look.get("land_scale", 0.45)), t), 0.0, 1.0, float(look.get("fly_seconds", 0.6))
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_tw.tween_callback(func() -> void: trail.emitting = false)
		_tw.tween_property(self, "modulate:a", 0.0, 0.08)
		_tw.tween_callback(func() -> void: busy = false)
