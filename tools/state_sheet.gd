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
			var node := _model(ids[r], STATES[c], r * 10 + c)
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
	Game.objects.clear()
	await get_tree().process_frame


## The building in a state, as the farm draws it (model and what fills it).
func _model(id: String, state: String, uid: int) -> Node3D:
	var it := Game.item_data(id)
	var fp := Game.footprint(id)
	var level := Game.max_level(id)
	if state == "frame":
		if not it.has("build_materials"):
			return null
		return ModelKit.bake(BuildingModel.build_site(it, fp, 0.5))
	var cycle := Game.cycle_of({"id": id})
	var o := {"id": id, "uid": 9000 + uid, "row": 0, "col": 0, "level": level, "inside": {}}
	o["t"] = Game.now() - (cycle + 1 if state == "full" else cycle / 2 if state == "half" else 0)
	if state != "empty":
		var cap := Game.capacity(o) if Game.is_building(o) else 0
		var want := cap if state == "full" else cap / 2
		var takes: Array[String] = []
		for k in Game.item_order:
			if Game.building_accepts(o, k) and not Game.items[k].has("rare_of") and not Game.items[k].has("single_of"):
				takes.append(k)
		var n := 0
		while n < want and not takes.is_empty():
			var k: String = takes[n % mini(takes.size(), 3)]
			o["inside"][k] = int(o["inside"].get(k, 0)) + 1
			n += 1
	Game.objects.append(o)
	var node := ModelKit.bake(BuildingModel.build(it, fp, level))
	if BuildingFill.shows(o):
		node.add_child(BuildingFill.create(o, node))
	return node
