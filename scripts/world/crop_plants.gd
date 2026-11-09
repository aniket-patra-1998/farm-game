class_name CropPlants
extends Node2D
## The plants on a plot, drawn above its soil. Positioned at the bed's top centre so skewing it sways the
## plants from their stems while the soil stays still.

var piece: FarmPiece


func _draw() -> void:
	draw_set_transform(-position - piece.position)
	piece.grid.draw_plants_on(self, piece.plot)
