class_name WorldFx
extends Node2D
## Effects that happen on the farm itself, drawn over the pieces: bursts of dirt when plowing and
## planting, leaves when harvesting, a dust puff when something lands, and the harvested plants popping
## up and away. Bursts use Godot's CPU particle emitters, pooled and reused, so busy farming costs nothing.

const POOL := 6

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




## The harvested plants jump, stretch and vanish upward, so a harvest feels like picking something.
func pop_plants(i: int, crop_id: String, art: String) -> void:
	if crop_id == "" or not Game.crops.has(crop_id):
		return
	var ghost := PlantsGhost.new()
	ghost.crop = Game.crops[crop_id]
	ghost.art = art
	ghost.position = grid.center_of(i) + Vector2(0, -PlaceholderArt.SLAB)
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
			PlaceholderArt.draw_crop(self, Vector2.ZERO, FarmGrid.TILE_W, FarmGrid.TILE_H, crop, "ripe", 1.0)
