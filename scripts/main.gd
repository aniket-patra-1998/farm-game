extends Node2D
## Wires the farm, camera and HUD together and keeps the farm framed on any screen.

var grid: FarmGrid
var camera: Camera2D
var hud: FarmHud


func _ready() -> void:
	grid = FarmGrid.new()
	add_child(grid)

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	hud = FarmHud.new()
	add_child(hud)

	hud.tool_selected.connect(grid.set_tool)
	grid.info.connect(hud.show_message)
	Game.message.connect(hud.show_message)

	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


## Zoom so the whole farm fits between the top bar and the toolbar,
## in landscape or portrait, on phones and tablets.
func _fit_camera() -> void:
	var view := get_viewport_rect().size
	var bounds := grid.get_bounds()
	var usable := view - Vector2(0, FarmHud.TOP_H + FarmHud.BOTTOM_H)
	var z := minf(usable.x / (bounds.size.x * 1.04), usable.y / (bounds.size.y * 1.04))
	camera.zoom = Vector2(z, z)
	# The free area is shifted down by half the difference between the bars.
	var shift := (FarmHud.TOP_H - FarmHud.BOTTOM_H) / 2.0
	camera.position = bounds.get_center() - Vector2(0, shift / z)
