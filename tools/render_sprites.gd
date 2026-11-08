extends Node
## Renders 3D models (CC0 packs, imported into res://art_src) to isometric sprites that match
## the farm grid: camera 30 degrees above the ground, turned 45 degrees, orthographic.
## Writes res://sprites/<id>.png, res://sprites/sprites.json (anchor = ground centre in the image)
## and res://ci_shots/contact.png (every sprite on one sheet, for checking).

const PX_PER_TILE := 256.0          # sprites are drawn at 2x and shown at half size
const TILE_DIAGONAL := sqrt(2.0)    # a 1x1 tile is 1 unit square; its diagonal spans the tile's width

var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.88, 0.95)
	e.ambient_light_energy = 0.55
	env.environment = e
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.15
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	await _render_all()
	get_tree().quit()


func _render_all() -> void:
	var out_dir := ProjectSettings.globalize_path("res://sprites")
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ci_shots"))
	var meta := {}
	var images: Array[Image] = []
	var names: Array[String] = []
	var f := FileAccess.open("res://tools/resolved.txt", FileAccess.READ)
	while f and not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts := line.split("|")
		var id := parts[0].strip_edges()
		var path := parts[1].strip_edges()
		var tiles := float(parts[2])
		var turn := float(parts[3])
		var img := await _render(path, tiles, turn)
		if img == null:
			print("SPRITE FAILED ", id, " ", path)
			continue
		var used := img.get_used_rect()
		var anchor := Vector2(img.get_width() / 2.0, img.get_height() * 0.75) - Vector2(used.position)
		var cropped := img.get_region(used)
		cropped.save_png(out_dir + "/" + id + ".png")
		meta[id] = {"anchor": [anchor.x, anchor.y], "scale": 0.5}
		images.append(cropped)
		names.append(id)
		print("SPRITE OK ", id, " ", cropped.get_size())
	var mf := FileAccess.open(out_dir + "/sprites.json", FileAccess.WRITE)
	mf.store_string(JSON.stringify(meta, "\t"))
	_contact_sheet(images, names)


## Renders one model; the footprint centre sits at 3/4 down the image, centred left to right.
func _render(path: String, tiles: float, turn: float) -> Image:
	var res := load(path)
	var node: Node3D
	if res is PackedScene:
		node = (res as PackedScene).instantiate() as Node3D
	elif res is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = res
		node = mi
	if node == null:
		return null
	_holder.add_child(node)
	node.rotation_degrees.y = turn
	await get_tree().process_frame
	# Fit: the model's widest ground extent fills its footprint.
	var box := _aabb(node)
	var ground := maxf(box.size.x, box.size.z)
	var s := (tiles * 0.9) / maxf(ground, 0.001)
	node.scale = Vector3.ONE * s
	box = _aabb(node)
	node.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	# Camera: 30 degrees above the ground, turned 45 degrees.
	var w := int(PX_PER_TILE * tiles) + 32
	var h := int(w * 1.6)
	_vp.size = Vector2i(w, h)
	var ppu := PX_PER_TILE / TILE_DIAGONAL
	_cam.size = h / ppu
	var dir := Vector3(sin(deg_to_rad(45)) * cos(deg_to_rad(30)), sin(deg_to_rad(30)), cos(deg_to_rad(45)) * cos(deg_to_rad(30)))
	# Put the ground centre 3/4 of the way down: look at a point above it.
	var up := Vector3(0, 1, 0)
	var look_at_pt := Vector3.ZERO + (up - dir * dir.dot(up)).normalized() * (h * 0.25 / ppu)
	_cam.position = look_at_pt + dir * 50.0
	_cam.look_at(look_at_pt, up)
	for k in 4:
		await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	node.queue_free()
	await get_tree().process_frame
	return img


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b := m.global_transform * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _contact_sheet(images: Array[Image], names: Array[String]) -> void:
	var cell := 200
	var cols := 6
	var rows := int(ceil(images.size() / float(cols)))
	var sheet := Image.create(cell * cols, cell * maxi(rows, 1), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.56, 0.81, 0.37))
	for k in images.size():
		var img := images[k].duplicate() as Image
		var sc := minf(1.0, (cell - 10) / float(maxi(img.get_width(), img.get_height())))
		img.resize(maxi(1, int(img.get_width() * sc)), maxi(1, int(img.get_height() * sc)))
		var at := Vector2i((k % cols) * cell + (cell - img.get_width()) / 2, int(k / float(cols)) * cell + (cell - img.get_height()) / 2)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.save_png(ProjectSettings.globalize_path("res://ci_shots/contact.png"))
