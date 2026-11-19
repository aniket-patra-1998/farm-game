class_name WorldFx
extends Node2D
## Effects that happen on the farm itself, drawn over the pieces: bursts of dirt when plowing and
## planting, leaves when harvesting, a dust puff when something lands, and the harvested plants popping
## up and away. Bursts use Godot's CPU particle emitters, pooled and reused, so busy farming costs nothing.

const POOL := 6
const HEART_POOL := 6   # hearts in the air at once: a quick run of taps reuses the oldest, never makes more

const KINDS := {
	"dirt":    {
		"colors": ["#6e4c37", "#8a6247", "#4e3426"],
		"amount": 14,
		"speed": [70.0, 150.0],
		"gravity": 520.0,
		"size": [3.0, 6.0],
		"life": 0.55,
		"spread": 70.0,
		"up": true
	},
	"leaves":  {
		"colors": ["#5aa843", "#7cc65a", "#3f8a32"],
		"amount": 12,
		"speed": [80.0, 170.0],
		"gravity": 380.0,
		"size": [3.0, 6.0],
		"life": 0.7,
		"spread": 80.0,
		"up": true
	},
	"dust":    {
		"colors": ["#efe6d2", "#d9cdb3"],
		"amount": 18,
		"speed": [60.0, 110.0],
		"gravity": -20.0,
		"size": [6.0, 12.0],
		"life": 0.6,
		"spread": 180.0,
		"up": false
	},
	"sparkle": {
		"colors": ["#fff3b0", "#ffd23f", "#ffffff"],
		"amount": 16,
		"speed": [60.0, 160.0],
		"gravity": 60.0,
		"size": [2.5, 5.0],
		"life": 0.8,
		"spread": 180.0,
		"up": false
	},
}


static var _dot: Texture2D



var grid: FarmGrid

var _pools := {}   # kind -> Array[CPUParticles2D]
var _next := {}    # kind -> next emitter to use
var _hearts: Array[Heart] = []   # pooled, hidden while idle (hearts)
var _next_heart := 0


func _ready() -> void:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 16
		tex.height = 16
		_dot = tex
	for kind in KINDS:
		var pool: Array[CPUParticles2D] = []
		for k in POOL:
			pool.append(_make_emitter(KINDS[kind]))
		_pools[kind] = pool
		_next[kind] = 0




func _make_emitter(spec: Dictionary) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.emitting = false
	e.one_shot = true
	e.explosiveness = 0.95
	e.amount = int(spec["amount"])
	e.lifetime = float(spec["life"])
	e.texture = _dot
	e.direction = Vector2(0, -1) if spec["up"] else Vector2(1, 0)
	e.spread = float(spec["spread"])
	e.initial_velocity_min = spec["speed"][0]
	e.initial_velocity_max = spec["speed"][1]
	e.gravity = Vector2(0, float(spec["gravity"]))
	e.scale_amount_min = float(spec["size"][0]) / 8.0
	e.scale_amount_max = float(spec["size"][1]) / 8.0
	var fade := Curve.new()
	fade.add_point(Vector2(0, 1))
	fade.add_point(Vector2(0.7, 0.8))
	fade.add_point(Vector2(1, 0))
	e.scale_amount_curve = fade
	var ramp := Gradient.new()
	var cols: Array = spec["colors"]
	ramp.set_color(0, Color.html(cols[0]))
	ramp.set_color(1, Color(Color.html(cols[-1]), 0.0))
	e.color_ramp = ramp
	e.color_initial_ramp = _initial_ramp(cols)
	add_child(e)
	return e




static func _initial_ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color.html(cols[0]))
	g.set_color(1, Color.html(cols[-1]))
	if cols.size() > 2:
		g.add_point(0.5, Color.html(cols[1]))
	return g




## One burst of a kind ("dirt", "leaves", "dust", "sparkle") at a farm position.
func burst(kind: String, at: Vector2) -> void:
	var pool: Array = _pools.get(kind, [])
	if pool.is_empty():
		return
	var e: CPUParticles2D = pool[_next[kind]]
	_next[kind] = (int(_next[kind]) + 1) % pool.size()
	e.position = at
	e.restart()
	e.emitting = true




## A tapped animal's answer (wow build, item 4): a small soft heart pops up over its back, rises and fades; a
## richer feel lets a few go, one after another, drifting apart. Pooled and tween-driven: nothing runs between
## taps. Numbers and colours in Balance feel.heart.
func hearts(at: Vector2) -> void:
	var feel: Dictionary = Balance.d("feel.heart")
	var count := int(feel["count"])
	for k in count:
		var h := _free_heart()
		h.fill = Color.html(str(feel["tint"]))
		h.rim = Color.html(str(feel["rim"]))
		h.px = float(feel["px"]) * (1.0 if k == 0 else float(feel["after_scale"]))
		h.queue_redraw()
		var side := float(feel["drift"]) + (0.0 if k == 0 else float(feel["spread"]) * (1.0 if k % 2 == 1 else -1.0))
		var wait := float(feel["stagger"]) * k
		var life := float(feel["seconds"])
		h.position = at
		h.scale = Vector2.ZERO
		h.modulate.a = 1.0
		h.visible = true
		var tw := h.create_tween().set_parallel(true)
		h.tween = tw
		tw.tween_property(h, "scale", Vector2.ONE * float(feel["pop"]), life * 0.18).set_delay(wait) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(h, "scale", Vector2.ONE, life * 0.12).set_delay(wait + life * 0.18) \
			.set_trans(Tween.TRANS_QUAD)
		tw.tween_property(h, "position", at + Vector2(side, -float(feel["rise"])), life) \
			.set_delay(wait).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(h, "modulate:a", 0.0, life * 0.4).set_delay(wait + life * 0.6)
		tw.chain().tween_callback(h.hide)


## The hearts in the air now (tests).
func hearts_now() -> int:
	var n := 0
	for h in _hearts:
		n += int(h.visible)
	return n


func _free_heart() -> Heart:
	for h in _hearts:
		if not h.visible:
			return h
	if _hearts.size() < HEART_POOL:
		var made := Heart.new()
		made.z_index = 1
		made.visible = false
		add_child(made)
		_hearts.append(made)
		return made
	var oldest := _hearts[_next_heart]   # (all in the air: the oldest is reused)
	_next_heart = (_next_heart + 1) % _hearts.size()
	if oldest.tween != null:
		oldest.tween.kill()
	return oldest


## One soft heart drawn round its own origin: a cream rim, a rose fill and a small light on its left lobe.
class Heart extends Node2D:
	const POINTS := 28
	var fill := Color.WHITE
	var rim := Color.WHITE
	var px := 22.0
	var tween: Tween

	func _draw() -> void:
		draw_colored_polygon(_shape(px * 0.5 + 2.5), rim)
		draw_colored_polygon(_shape(px * 0.5), fill)
		draw_circle(Vector2(-px * 0.2, -px * 0.16), px * 0.09, Color(rim, 0.85))

	## The classic heart curve, `half` across each way, its middle at the origin.
	static func _shape(half: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in POINTS:
			var t := TAU * k / POINTS
			var x := 16.0 * pow(sin(t), 3)
			var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
			pts.append(Vector2(x, -y - 2.5) * (half / 16.0))
		return pts


## The harvested plants jump, stretch and vanish upward, so a harvest feels like picking something.
func pop_plants(i: int, crop_id: String, art: String) -> void:
	if crop_id == "" or not Game.crops.has(crop_id):
		return
	var ghost := PlantsGhost.new()
	ghost.crop = Game.crops[crop_id]
	ghost.art = art
	ghost.position = grid.center_of(i) + Vector2(0, -FarmGrid.SLAB)
	add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "scale", Vector2(1.22, 0.78), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2(0.86, 1.25), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(
		ghost,
		"position:y",
		ghost.position.y - 46.0,
		0.32
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2(0.45, 0.45), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.26).set_delay(0.08)
	tw.chain().tween_callback(ghost.queue_free)




## A copy of a plot's plants, drawn around its own origin, for the harvest pop.
class PlantsGhost extends Node2D:
	var crop: Dictionary
	var art := ""

	func _draw() -> void:
		if art != "":
			SpriteBank.draw(self, art, Vector2.ZERO)
		else:
			FarmGrid.art().draw_crop(self, Vector2.ZERO, FarmGrid.TILE_W, FarmGrid.TILE_H, crop, "ripe", 1.0)


## Lets go of the looks kept in statics (Game, on quit), so none is still held when the engine shuts down.
static func release_statics() -> void:
	_dot = null
