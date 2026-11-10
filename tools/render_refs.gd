extends Node2D
## Draws a reference image for every entry in art/manifest.json (today's code drawing of that item at
## that lifecycle stage, at 2x, on the plain grey the art is generated on) into art/refs/.
## These fix the camera angle, outline and footprint that the AI repaints.

const BG := Color("#e8e8e8")
const TILE_W := 256.0
const TILE_H := 128.0

var _vp: SubViewport
var _canvas: Node2D
var _job := {}


func _ready() -> void:
	PlaceholderArt.show_badges = false
	_vp = SubViewport.new()
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_job)
	_vp.add_child(_canvas)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/manifest.json"))
	var out := ProjectSettings.globalize_path("res://art/refs")
	DirAccess.make_dir_recursive_absolute(out)
	var made := 0
	for entry in manifest["items"]:
		var refs: Array = entry["refs"]
		if refs.is_empty() or not str(refs[0]).begins_with("refs/"):
			continue
		var tiles := int(entry["tiles"])
		var w := int(TILE_W * tiles + 96)
		_vp.size = Vector2i(w, int(w * 1.3))
		_job = entry
		_canvas.queue_redraw()
		for k in 3:
			await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png(out + "/" + str(refs[0]).get_file())
		made += 1
	print("REFS ", made)
	get_tree().quit()


func _draw_job() -> void:
	var size := Vector2(_vp.size)
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), BG)
	var tiles := int(_job.get("tiles", 1))
	var top := Vector2(size.x / 2.0, size.y - TILE_H * tiles - 40)
	var corners := PackedVector2Array([top, top + Vector2(TILE_W * tiles / 2.0, TILE_H * tiles / 2.0),
		top + Vector2(0, TILE_H * tiles), top + Vector2(-TILE_W * tiles / 2.0, TILE_H * tiles / 2.0)])
	var stage := str(_job.get("stage", ""))
	var item_id := str(_job.get("item", ""))
	match str(_job.get("class", "")):
		"Ground":
			if stage == "grass":
				PlaceholderArt.draw_grass(_canvas, top, TILE_W, TILE_H, 7, false)
			else:
				PlaceholderArt.draw_soil(_canvas, top, TILE_W, TILE_H, false)
		"Crop":
			var crop: Dictionary = Game.crops[item_id]
			# Plants only: the game draws the soil, so the art mustn't include any.
			var phase: String = {
				"planted": "growing",
				"growing": "growing",
				"ripe": "ripe",
				"withered": "withered"
			}[stage]
			var progress := 0.12 if stage == "planted" else 0.7
			PlaceholderArt.draw_crop(_canvas, top + Vector2(0, TILE_H / 2.0), TILE_W, TILE_H, crop, phase, progress)
		"Tree":
			PlaceholderArt.draw_object(_canvas, Game.item_data(item_id), corners, stage == "ready", 1, 0, 0)
		"Building", "Barn", "Crafting":
			var it := Game.item_data(item_id)
			PlaceholderArt.draw_object(
				_canvas,
				it,
				corners,
				false,
				int(stage),
				5,
				Game.building_def(item_id).capacity(int(stage))
			)
		_:
			PlaceholderArt.draw_object(_canvas, Game.item_data(item_id), corners, false, 1, 0, 0)
