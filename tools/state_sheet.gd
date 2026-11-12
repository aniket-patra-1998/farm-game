extends Node3D
## State sheets: every building in each state it can be seen in, side by side: a frame half built, empty,
## half full (part way through its cycle), and full and ready. For reviewing whether a building reads as
## empty, filling, full and ready at a glance. Writes ci_shots/state_<page>.png. Needs a renderer:
##   xvfb-run godot --rendering-method gl_compatibility --path . res://tools/state_sheet.tscn

const ROWS := 4
const CELL := 6.0
const STATES: Array[String] = ["frame", "empty", "half", "full"]
const PAGE_SIZE := Vector2i(1600, 1200)

var _cam: Camera3D


func _ready() -> void:
	get_window().size = PAGE_SIZE
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#8db864")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#cfe0ff")
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	Game.set_process(false)
	var ids: Array[String] = []
	for id in Game.item_order:
		if str(Game.items[id].get("kind", "")) in ["building", "barn", "crafting"]:
			ids.append(id)
	for page in ceili(float(ids.size()) / ROWS):
		await _page(page, ids.slice(page * ROWS, (page + 1) * ROWS))
	get_tree().quit()


func _page(page: int, ids: Array[String]) -> void:
	var holder := Node3D.new()
	add_child(holder)
	for r in ids.size():
		for c in STATES.size():
			var at := Vector3(c * CELL, 0, r * CELL)
			var node := LookModels.building(ids[r], STATES[c], r * 10 + c)
			if node != null:
				var fp := Game.footprint(ids[r])
				var fit := 4.2 / maxf(maxf(fp.x, fp.y), 1.0)
				node.scale = Vector3.ONE * minf(fit, 1.4)
				node.position = at - Vector3(fp.x, 0, fp.y) * node.scale.x / 2.0
				holder.add_child(node)
			var label := Label3D.new()
			label.text = "%s: %s" % [ids[r], STATES[c]]
			label.font_size = 56
			label.pixel_size = 0.005
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.modulate = Color.BLACK
			label.outline_modulate = Color.WHITE
			label.position = at + Vector3(0, 0, 2.6)
			holder.add_child(label)
	var centre := Vector3((STATES.size() - 1) * CELL / 2.0, 0, (ROWS - 1) * CELL / 2.0)
	_cam.size = (STATES.size() + ROWS) * CELL * 0.6
	_cam.look_at_from_position(centre + Vector3(14, 14, 14), centre)
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://ci_shots/state_%d.png" % page)
	holder.queue_free()
	Game.set_objects([])
	await get_tree().process_frame
