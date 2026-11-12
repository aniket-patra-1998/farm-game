class_name OverlayLayer
extends Node2D
## Drawn over the whole farm every frame, and cheap: where a vehicle just worked, building count signs,
## twinkles over ready things, hearts over lost animals, and the ghost of something being placed.

const REDRAW_EVERY := 1.0 / 30.0   # twinkles and signs need no more than 30 a second

var grid: FarmGrid
var objects: ObjectLayer
var _since := 0.0


func _process(delta: float) -> void:
	_since += delta
	if _since >= REDRAW_EVERY:
		_since = 0.0
		queue_redraw()


func _draw() -> void:
	grid.draw_overlay_on(self, objects.ready_pieces(), objects.hungry_pieces())
