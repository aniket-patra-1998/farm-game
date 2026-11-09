class_name OverlayLayer
extends Node2D
## Drawn over the whole farm every frame, and cheap: where a vehicle just worked, building count signs,
## twinkles over ready things, hearts over lost animals, and the ghost of something being placed.

var grid: FarmGrid
var objects: ObjectLayer


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	grid.draw_overlay_on(self, objects.ready_pieces())
