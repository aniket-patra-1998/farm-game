class_name GroundLayer
extends Node2D
## The ground under everything: the countryside, trees around the farm, the next expansion, and your
## land's grass as one continuous field (no checkerboard). Redrawn only when the farm grows or art arrives.

var grid: FarmGrid


func _draw() -> void:
	grid.draw_ground_on(self)
