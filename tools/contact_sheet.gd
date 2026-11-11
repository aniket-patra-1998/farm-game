extends Node3D
## Contact sheets: every model in the game, a labelled cell each, a page per kind, so every piece can be
## looked over for anything broken. Writes ci_shots/contact_<kind>_<page>.png. Needs a renderer:
##   xvfb-run godot --rendering-method gl_compatibility --path . res://tools/contact_sheet.tscn

const COLS := 6
const ROWS := 4
const CELL := 4.0          # world units between cells
const PAGE_SIZE := Vector2i(1500, 1000)
const CROP_ZOOM := 2.2     # crops are small too
const ANIMAL_ZOOM := 3.0   # animals are small: shown bigger
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


func _ids(kind: String) -> Array[String]:
	var out: Array[String] = []
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
	for k in ids.size():
		var at := Vector3((k % COLS) * CELL, 0, (k / COLS) * CELL)
		var node := _crop_row(ids[k]) if kind == "crop" else _model(ids[k])
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
	_cam.look_at_from_position(centre + Vector3(14, 14, 14), centre)
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://ci_shots/contact_%s_%d.png" % [kind, page])
	holder.queue_free()
	await get_tree().process_frame


## The model as the farm shows it, finished and at its biggest; animals posed.
func _model(id: String) -> Node3D:
	var it := Game.item_data(id)
	var fp := Game.footprint(id)
	match str(it.get("kind", "")):
		"animal":
			var a := Animal3D.create(it, null, Vector3(fp.x / 2.0, 0, fp.y / 2.0))
			a.update(0.016)
			var wrap := Node3D.new()
			wrap.add_child(a)
			return wrap
		"tree":
			var t := Node3D.new()
			TreeModel.build_at(t, Vector3(fp.x / 2.0, 0, fp.y / 2.0), it, ScaleGuide.factor(id), true, 7 + hash(id) % 50)
			return ModelKit.bake(t)
		"vehicle":
			return VehicleModel.build(it, false)
		"decor":
			return DecorModel.build(it, fp, {"id": id, "uid": 7})
		"bloom":
			return BloomModel.build(it, {"id": id, "uid": 7, "t": Game.now() - int(it.get("cycle_seconds", 86400)) - 1})
		"young":
			return DecorModel.build_young(it, {"id": id, "uid": 7, "fed": 4}, 0.5)
		_:
			return ModelKit.bake(BuildingModel.build(it, fp, Game.max_level(id)))


## A crop at young, ripe and withered side by side, as the field draws it (crop material, produce coloured).
func _crop_row(id: String) -> Node3D:
	var crop: Dictionary = Game.crops[id]
	var form := CropForms.form_of(id, str(crop.get("shape", "berry")))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/crop3d.gdshader")
	var row := Node3D.new()
	for k in 3:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = CropModels.mesh(form, ["young", "ripe", "withered"][k])
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ONE * Crops3D.PLANT_SCALE), Vector3(k * 1.0, 0, 0)))
		mm.set_instance_custom_data(0, Color.html(str(crop.get("color", "#e2453c"))))
		mmi.multimesh = mm
		mmi.material_override = mat
		row.add_child(mmi)
	return row
