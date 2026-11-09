class_name FxLayer
extends CanvasLayer
## Rewards that fly from the farm to the top bar: coins arc up to the coin counter, XP stars to the XP
## bar, and the counter pulses as each lands. Drawn above the HUD, in screen space.

const MAX_FLYERS := 60   # a cap, so a vehicle harvesting a whole field stays smooth

var hud: FarmHud
var _flying := 0


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
			f.scale = Vector2.ONE * lerpf(1.0, 0.65, t), 0.0, 1.0, randf_range(0.48, 0.62)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			on_land.call()
			_flying -= 1
			f.queue_free())


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
