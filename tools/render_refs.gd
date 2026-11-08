extends Node2D
## Draws the current code-made art for the items in art/manifest.json at 2x, on the plain grey
## background the AI art is generated on, and saves them to art/refs/. These fix the camera
## angle, outline and footprint that the AI restyles.

const BG := Color("#e8e8e8")
const TILE_W := 256.0
const TILE_H := 128.0

var _vp: SubViewport
var _canvas: Node2D
var _job := {}


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_job)
	_vp.add_child(_canvas)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/manifest.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/refs"))
	for item in manifest["items"]:
		for ref in item["refs"]:
			if not str(ref).begins_with("refs/"):
				continue
			var id := str(ref).get_file().get_basename()
			var tiles := int(item["tiles"])
			var w := int(TILE_W * tiles + 96)
			_vp.size = Vector2i(w, int(w * 1.3))
			_job = {"id": id, "tiles": tiles}
			_canvas.queue_redraw()
			for k in 3:
				await RenderingServer.frame_post_draw
			_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://" + "art/" + str(ref)))
			print("REF ", ref)
	get_tree().quit()


func _draw_job() -> void:
	var size := Vector2(_vp.size)
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), BG)
	var tiles := int(_job.get("tiles", 1))
	var id: String = _job.get("id", "")
	# Ground footprint centred left to right, sitting in the lower part of the image.
	var top := Vector2(size.x / 2.0, size.y - TILE_H * tiles - 40)
	var corners := PackedVector2Array([top, top + Vector2(TILE_W * tiles / 2.0, TILE_H * tiles / 2.0),
		top + Vector2(0, TILE_H * tiles), top + Vector2(-TILE_W * tiles / 2.0, TILE_H * tiles / 2.0)])
	if id.begins_with("crop_"):
		var parts := id.split("_")
		var stage := parts[-1]
		var crop_id := "_".join(parts.slice(1, parts.size() - 1))
		var crop: Dictionary = Game.crops[crop_id]
		PlaceholderArt.draw_soil(_canvas, top, TILE_W, TILE_H, true)
		var phase := "ripe" if stage == "ripe" else "growing"
		var progress := 0.15 if stage == "sprout" else 0.6
		PlaceholderArt.draw_crop(_canvas, top + Vector2(0, TILE_H / 2.0), TILE_W, TILE_H, crop, phase, progress)
		return
	var it := Game.item_data(id)
	var ready := it.get("kind", "") == "tree"
	var cap := 20 if it.get("kind", "") == "building" else 0
	PlaceholderArt.draw_object(_canvas, it, corners, ready, 1, 5 if cap > 0 else 0, cap)
