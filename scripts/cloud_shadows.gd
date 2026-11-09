class_name CloudShadows
extends Node2D
## Soft shadows of passing clouds drifting across the farm, drawn over the objects. Strongest on a
## partly cloudy day with the sun out; gone when it's clear, overcast or night.

const COUNT := 6

var grid: FarmGrid
var strength := 0.0  # set by main
var _clouds: Array = [] # {u, v, r, speed}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 311
	for k in COUNT:
		_clouds.append(
			{"u": rng.randf(), "v": rng.randf(), "r": rng.randf_range(2.0, 4.0), "speed": rng.randf_range(0.006, 0.012)}
		)


func _process(delta: float) -> void:
	for c in _clouds:
		c["u"] = float(c["u"]) + float(c["speed"]) * delta
		if float(c["u"]) > 1.3:
			c["u"] = -0.3
	if strength > 0.01:
		queue_redraw()
	elif visible:
		queue_redraw()


func _draw() -> void:
	if strength <= 0.01 or grid == null:
		return
	var n := float(Game.farm_size)
	for c in _clouds:
		var center := grid.top_of_f(float(c["v"]) * n, float(c["u"]) * n)
		var r: float = float(c["r"]) * 64.0
		for ring in 5:
			var k := 1.0 - ring * 0.18
			draw_set_transform(center, 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, r * k, Color(0.05, 0.08, 0.2, strength * 0.07))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
