class_name PaintedCrops
extends Node3D
## Every crop on the farm as a painted picture (docs/WORLD.md "Crops are painted pictures"): one flat card to a plot,
## facing the camera, which never turns, so the card is the plant. A picture is a recipe of shapes
## (tools/paint_plants.py writes art/painted/crops/<name>.paint, SVG text) turned into a texture here the first time
## it is shown, so a crop ships as a few kilobytes. Four looks to a crop: the sprouts every crop shares, its plants
## part grown, ripe, and the ripe picture gone dry (painted3d.gdshader).
## One MultiMesh per picture; a plot's card stands on its bed's nearest corner, so it is in front of the bed it
## covers and behind whatever stands in front of the plot.

const SHADER := preload("res://shaders/painted3d.gdshader")
const ART := "res://art/painted/crops/%s.paint"
const PICTURE := Vector2(512, 400)   # a picture's size, in its own pixels..
const TILE_PX := 500.0               # ..its plot's width across (corner to corner)..
const FRONT := Vector2(256, 387)     # ..and where the plot's nearest corner is (tools/paint_plants.py)
const FILL := 0.92                   # a picture's plot is this much of a tile: its bed (Plots3D.BED), and a little over
const SHARPER := 1.0                 # a picture is made this many times its size
const SPROUT := "sprout"             # the one picture every crop shares while it sprouts
const HARVEST := Vector2(256, 256)   # the picture of what a crop gives (its Market picture): its size..
const HARVEST_TILES := 1.0           # ..and how many tiles across it is shown
const KEPT := "user://painted"       # made pictures are kept here, so only the first run paints them
const POP_HEIGHT := 0.5              # how high a harvested plot's card springs before it is gone..
const POP_TIME := 0.42               # ..and how long that takes
const WAITING := -1                   # in `_asked`: not begun yet
const CHECK := 1.0                   # seconds between looks at the clock for the next plot due to change

static var _pictures := {}   # name -> ImageTexture, made once
static var _asked := {}      # name -> its task (WorkerThreadPool) being painted on another thread, or WAITING its turn
static var _queue: Array[String] = []   # asked for and not yet begun: one is painted at a time, so frames stay even
static var _painted: Array = []   # [name, Image] painted there and not yet taken up (under `_lock`)
static var _lock := Mutex.new()

var _layers := {}    # picture name -> MultiMeshInstance3D
var _members := {}   # picture name -> {plot index: its card's data (Color)}
var _shown := {}     # plot index -> [picture name, data]
var _due := -1       # when the soonest plot changes look on its own (Game.now), or -1


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = CHECK
	timer.autostart = true
	timer.timeout.connect(_on_clock)
	add_child(timer)
	update()


func _on_clock() -> void:
	if _due >= 0 and Game.now() >= _due:
		update()


## Painted pictures come in as they are made: the plots waiting for one are laid out when it does.
func _process(_delta: float) -> void:
	if _asked.is_empty():
		return
	_lock.lock()
	var made := _painted.duplicate()
	_painted.clear()
	_lock.unlock()
	for one: Array in made:
		_pictures[one[0]] = ImageTexture.create_from_image(one[1]) if one[1] != null else null
		WorkerThreadPool.wait_for_task_completion(int(_asked[one[0]]))   # (done: this only lets the task go)
		_asked.erase(one[0])
		_lay_out(one[0])
	_begin_next()


## The image of picture `name`, painted from its recipe (10 to 20 ms on a desktop: off the main thread on the farm);
## null when there is none.
static func _paint(name: String) -> Image:
	return paint_at(ART % name)


## The image a recipe file paints (`path`: a .paint file), or null.
## A picture already made on this device is read back, not painted again: kept under its recipe's own mark, so a
## changed recipe is painted afresh (only where models are kept too: ModelStore; tests and tools keep nothing).
static func paint_at(path: String) -> Image:
	var image := Image.new()
	var recipe := FileAccess.get_file_as_string(path)
	if recipe == "":
		return null
	var keeps := ModelStore.stamp != ""
	var kept := "%s/%s_%d_%d.png" % [KEPT, path.get_file().get_basename(), recipe.hash(), recipe.length()]
	if keeps and FileAccess.file_exists(kept) and image.load(kept) == OK:
		image.generate_mipmaps()
		return image
	if image.load_svg_from_string(recipe, SHARPER) != OK:
		return null
	if keeps:
		DirAccess.make_dir_recursive_absolute(KEPT)
		image.save_png(kept)
	image.generate_mipmaps()
	return image


## Has picture `name` painted on another thread, if it is not made or being made already (`_process` takes it up).
static func want(name: String) -> void:
	if _pictures.has(name) or _asked.has(name):
		return
	_asked[name] = WAITING
	_queue.append(name)
	_begin_next()


## Starts painting the next picture asked for, if none is being painted.
static func _begin_next() -> void:
	if _queue.is_empty() or _asked.values().any(func(task: int) -> bool: return task != WAITING):
		return
	var name: String = _queue.pop_front()
	_asked[name] = WorkerThreadPool.add_task(func() -> void:
		var image := _paint(name)
		_lock.lock()
		_painted.append([name, image])
		_lock.unlock())


## Lets go of every picture made, once any still being painted is done (a clean quit; Game.release_statics).
static func release_statics() -> void:
	for task: int in _asked.values():
		if task != WAITING:
			WorkerThreadPool.wait_for_task_completion(task)
	_asked.clear()
	_queue.clear()
	_lock.lock()
	_painted.clear()
	_lock.unlock()
	_pictures.clear()


## The picture `name` (a crop's id and look, or SPROUT), painted here and now if it is not made yet (tests, tools;
## the farm asks ahead with `want`); null when there is none.
static func picture(name: String) -> Texture2D:
	if not _pictures.has(name):
		var image := _paint(name)
		_pictures[name] = ImageTexture.create_from_image(image) if image != null else null
	return _pictures[name]


## The picture a crop at `stage` (Crops3D.stage_of) is shown by, or "" for none (seeds lie under the soil).
static func picture_of(crop_id: String, stage: String) -> String:
	match stage:
		"sprout":
			return SPROUT
		"young":
			return crop_id + "_young"
		"ripe", "withered":
			return crop_id + "_ripe"
	return ""


## What crop `crop_id` gives, gathered, as a card facing `towards` (its Market picture: IconMaker); null for none.
static func harvest_card(crop_id: String, towards: Basis) -> Node3D:
	var art := picture(crop_id + "_harvest")
	if art == null:
		return null
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * HARVEST_TILES
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("picture", art)
	mat.set_shader_parameter("card", quad.size)
	mat.set_shader_parameter("sway", 0.0)
	var card := MeshInstance3D.new()
	card.mesh = quad
	card.material_override = mat
	card.transform = Transform3D(towards, Vector3(0.0, HARVEST_TILES * 0.5, 0.0))
	var root := Node3D.new()
	root.add_child(card)
	return root


## Plot `i` was harvested: its ripe card springs up and is gone (the plot itself is laid out by `update`).
func pop(i: int, crop_id: String) -> void:
	var layer: MultiMeshInstance3D = _layers.get(crop_id + "_ripe")
	if layer == null:
		return
	var ghost := MeshInstance3D.new()
	ghost.mesh = layer.multimesh.mesh
	ghost.material_override = layer.material_override
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.transform = Transform3D(facing(), place_of(i))
	add_child(ghost)
	var tw := ghost.create_tween().set_parallel(true)
	tw.tween_property(ghost, "position:y", ghost.position.y + POP_HEIGHT, POP_TIME).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector3.ONE * 0.05, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ghost.queue_free)


## How many tiles one pixel of a picture is.
static func tiles_per_pixel() -> float:
	return sqrt(2.0) * FILL / TILE_PX


## A card's facing: flat to the farm's camera (IsoProjection), its top up the screen.
static func facing() -> Basis:
	var into := IsoProjection.forward()
	var right := into.cross(Vector3.UP).normalized()
	return Basis(right, right.cross(into).normalized(), -into)


## Where plot `i`'s card is centred: its picture's nearest-corner point on the bed's nearest corner.
static func place_of(i: int) -> Vector3:
	var corner := Vector3(GameState.col_of(i) + 0.5 + 0.5 * FILL, Plots3D.HEIGHT, GameState.row_of(i) + 0.5 + 0.5 * FILL)
	var off := (Vector2(PICTURE.x * 0.5 - FRONT.x, FRONT.y - PICTURE.y * 0.5)) * tiles_per_pixel()
	var b := facing()
	return corner + b.x * off.x + b.y * off.y


## Brings the cards of plots `indices` up to date (all of them when empty); only the pictures a plot left or joined
## are laid out again.
func update(indices: Array = []) -> void:
	if indices.is_empty():
		indices = Crops3D._all_plots()
		indices.append_array(_shown.keys())
		_due = -1
	var dirty := {}
	for i: int in indices:
		var now := _look_of(i) if Game.on_farm(i) else []
		var was: Array = _shown.get(i, [])
		if was == now:
			continue
		if not was.is_empty():
			(_members[was[0]] as Dictionary).erase(i)
			dirty[was[0]] = true
			_shown.erase(i)
		if not now.is_empty():
			_shown[i] = now
			(_members.get_or_add(now[0], {}) as Dictionary)[i] = now[1]
			dirty[now[0]] = true
	for name: String in dirty:
		_lay_out(name)
	for i: int in indices:
		var t := Crops3D.next_change(i) if Game.on_farm(i) and Game.field.crop_at(i) != "" else -1
		if t >= 0 and (_due < 0 or t < _due):
			_due = t


## What plot `i` shows: [picture name, its card's data (withered, fertilised, mastered)], or [] for nothing.
func _look_of(i: int) -> Array:
	var crop_id := Game.field.crop_at(i)
	if crop_id == "" or not Game.crops.has(crop_id):
		return []
	var stage := str(Crops3D.stage_of(i)[0])
	var name := picture_of(crop_id, stage)
	if name == "" or not FileAccess.file_exists(ART % name):
		return []
	return [name, Color(1.0 if stage == "withered" else 0.0, 1.0 if Game.field.is_fertilized(i) else 0.0,
		Crops3D.mastered(crop_id), 0.0)]


## The picture a plot shows now, or "" (for tests).
func shown(i: int) -> String:
	return str((_shown.get(i, [""]) as Array)[0])


func _lay_out(name: String) -> void:
	var plots: Dictionary = _members.get(name, {})
	var layer: MultiMeshInstance3D = _layers.get(name)
	if plots.is_empty():
		if layer != null:
			layer.queue_free()
			_layers.erase(name)
		return
	if layer == null:
		if _pictures.get(name) == null:
			want(name)   # (its plots wait: `_process` lays them out when it is painted)
			return
		layer = MultiMeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = PICTURE * tiles_per_pixel()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = quad
		layer.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("picture", _pictures[name])
		mat.set_shader_parameter("card", quad.size)
		layer.material_override = mat
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(layer)
		_layers[name] = layer
	var mm := layer.multimesh
	mm.instance_count = plots.size()
	var b := facing()
	var k := 0
	for i: int in plots:
		mm.set_instance_transform(k, Transform3D(b, place_of(i)))
		mm.set_instance_custom_data(k, plots[i])
		k += 1
