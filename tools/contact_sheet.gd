extends Node3D
## Contact sheets: every model in the game, a labelled cell each, a page per kind, so every piece can be
## looked over for anything broken. Writes ci_shots/contact_<kind>_<page>.png. Needs a renderer:
##   xvfb-run godot --rendering-method gl_compatibility --path . res://tools/contact_sheet.tscn

const COLS := 6
const ROWS := 4
const CELL := 4.0          # world units between cells
const PAGE_SIZE := Vector2i(1500, 1000)
const CROP_ZOOM := LookModels.CROP_ZOOM
const ANIMAL_ZOOM := LookModels.ANIMAL_ZOOM
const KINDS: Array[String] = ["building", "decor", "tree", "animal", "vehicle", "young", "bloom", "crop"]

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
	for kind in _wanted():
		var ids := _ids(kind)
		var per := COLS * ROWS
		for page in ceili(float(ids.size()) / per):
			await _page(kind, page, ids.slice(page * per, (page + 1) * per))
	get_tree().quit()


## All the kinds, or only those named in `-- --kinds=tree,bloom` (a quick look at one kind after a change).
func _wanted() -> Array[String]:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kinds="):
			var out: Array[String] = []
			for k in arg.substr(8).split(","):
				if k in KINDS:
					out.append(k)
			return out
	return KINDS


## Only the items named in `-- --ids=cow,horse` (with --kinds=animal), for a quick look at a few.
func _only_ids() -> Array[String]:
	var out: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ids="):
			for id in arg.substr(6).split(","):
				out.append(id)
	return out


func _ids(kind: String) -> Array[String]:
	var out: Array[String] = []
	var only := _only_ids()
	if not only.is_empty():
		for id in only:
			if kind == "crop" and Game.crops.has(id) or str(Game.items.get(id, {}).get("kind", "")) == kind:
				out.append(id)
		return out
	if kind == "crop":
		for id: String in Game.crops:
			out.append(id)
		return out
	for id in Game.item_order:
		var k := str(Game.items[id].get("kind", ""))
		if k == kind or (kind == "building" and k in ["crafting", "barn"]):
			out.append(id)
	return out


func _page(kind: String, page: int, ids: Array[String]) -> void:
	var holder := Node3D.new()
	add_child(holder)
	var tight := not _only_ids().is_empty()   # a few named items: shown big in one row
	for k in ids.size():
		var at := Vector3((k % COLS) * CELL, 0, (k / COLS) * CELL)
		if tight:
			at = Vector3(k * CELL * 0.5, 0, -k * CELL * 0.5)   # a diagonal row: left to right across the screen
		var node := LookModels.model(ids[k], "row" if kind == "crop" else "empty", k)
		if kind == "crop":
			node.scale = Vector3.ONE * CROP_ZOOM
			node.position = at - Vector3(1.0, 0, 0) * CROP_ZOOM
			holder.add_child(node)
		elif node != null:
			var fp := Game.footprint(ids[k])
			var fit := 3.0 / maxf(maxf(fp.x, fp.y), 1.0)  # big buildings are shrunk to fit their cell
			node.scale = Vector3.ONE * (ANIMAL_ZOOM if kind in ["animal", "vehicle"] else minf(fit, 1.6))
			node.position = at - Vector3(fp.x, 0, fp.y) * node.scale.x / 2.0
			holder.add_child(node)
		var label := Label3D.new()
		label.text = ids[k]
		label.font_size = 64
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color.BLACK
		label.outline_modulate = Color.WHITE
		label.position = at + Vector3(0, 0, 1.7)
		holder.add_child(label)
	var centre := Vector3((COLS - 1) * CELL / 2.0, 0, (ROWS - 1) * CELL / 2.0)
	_cam.size = (COLS + ROWS) * CELL * 0.62  # the grid seen corner-on, with a margin
	if tight:
		centre = Vector3((ids.size() - 1) * CELL * 0.25, 0, -(ids.size() - 1) * CELL * 0.25)
		_cam.size = maxf(ids.size() * CELL * 0.8, 8.0)
	_cam.look_at_from_position(centre + Vector3(14, 14, 14), centre)
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ci_shots"))
	get_viewport().get_texture().get_image().save_png("res://ci_shots/contact_%s_%d.png" % [kind, page])
	holder.queue_free()
	Game.set_objects([])
	await get_tree().process_frame
