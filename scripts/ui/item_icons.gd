class_name ItemIcons
extends SubViewport
## Pictures of items for the shop and the lists, made from the items' own 3D models (so a new item gets its
## picture with no art to draw): each is rendered once, off screen, in FarmVille's three-quarter view, into a
## texture that the cards already show, and kept on disk (user://icons), so it is made once per device, not
## once per session. It fills in when its turn comes, one picture every two frames, the ones asked for last
## (the tab on screen) first, so opening the Market never waits. One renderer for the whole game, added by the
## HUD; `of` works before it exists.

const SIDE := 160             # the picture's size in pixels
const PITCH := deg_to_rad(-35.0)
const YAW := deg_to_rad(45.0)
const MARGIN := 1.12          # room round the model inside the picture
const CACHE := "user://icons"
## Bump when the models' look changes, so pictures kept on disk are made again (the item's data and the game's
## version are in the key too).
const LOOK := 1

static var _shown: ItemIcons
static var _textures := {}    # item id -> ImageTexture (blank until made)
static var _waiting: Array[String] = []
static var _asked := {}       # item id -> the frame it was last asked for

var _stage: Node3D
var _camera: Camera3D
var _making := ""             # the item drawn this frame, copied on the next


## The picture for `item_id`: from disk when it was made before, else a texture that is blank until its turn
## comes, then shows the item.
static func of(item_id: String) -> Texture2D:
	if not _textures.has(item_id):
		var kept := Image.load_from_file(_file(item_id)) if FileAccess.file_exists(_file(item_id)) else null
		if kept != null and kept.get_width() == SIDE:
			_textures[item_id] = ImageTexture.create_from_image(kept)
			return _textures[item_id]
		_textures[item_id] = ImageTexture.create_from_image(Image.create(SIDE, SIDE, false, Image.FORMAT_RGBA8))
		_waiting.append(item_id)
	if _waiting.has(item_id):
		_asked[item_id] = Engine.get_process_frames()
	return _textures[item_id]


## Puts the renderer under `parent` (once).
static func start(parent: Node) -> void:
	if is_instance_valid(_shown):
		return
	_shown = ItemIcons.new()
	parent.add_child(_shown)


## Where an item's picture is kept: its key changes with the item's data, the look and the game's version.
static func _file(item_id: String) -> String:
	var key := hash([Game.item_data(item_id), LOOK, ProjectSettings.get_setting("application/config/version", "")])
	return "%s/%s-%x.png" % [CACHE, item_id, key]


## The waiting item asked for most recently (the cards on screen), the first of those in order.
static func _next() -> String:
	var best := ""
	var best_frame := -1
	for id in _waiting:
		var f := int(_asked.get(id, 0))
		if f > best_frame:
			best = id
			best_frame = f
	return best


func _ready() -> void:
	size = Vector2i(SIDE, SIDE)
	transparent_bg = true
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(30.0), 0.0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	add_child(env)


func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		_waiting.clear()         # (nothing draws without a screen: the cards keep their blank pictures)
		return
	if _making != "":
		_finish(_making)
		_making = ""
	if _waiting.is_empty():
		return
	_making = _next()
	_waiting.erase(_making)
	_set_up(_making)
	render_target_update_mode = SubViewport.UPDATE_ONCE   # (drawn at the end of this frame)


## Copies the picture drawn last frame into the item's texture and keeps it on disk.
func _finish(id: String) -> void:
	var image := get_texture().get_image()
	if image != null and not image.is_empty():
		(_textures[id] as ImageTexture).update(image)
		DirAccess.make_dir_recursive_absolute(CACHE)
		_forget_old(id)
		image.save_png(_file(id))
	if is_instance_valid(_stage):
		_stage.queue_free()


## Removes pictures of `id` kept under an older key.
static func _forget_old(id: String) -> void:
	for f in DirAccess.get_files_at(CACHE):
		if f.begins_with(id + "-"):
			DirAccess.remove_absolute(CACHE + "/" + f)


## Builds the item's model on the stage and points the camera at it, so it fills the picture.
func _set_up(id: String) -> void:
	_stage = Node3D.new()
	add_child(_stage)
	var model := _model(id)
	if model == null:
		return
	_stage.add_child(model)
	var box := SpaceFit.reach(model, model.transform)
	var top := ScaleGuide._top(model, model.transform)
	var centre := Vector3(box.get_center().x, top * 0.45, box.get_center().y)
	var span := maxf(maxf(box.size.x, box.size.y) * 1.2, top * 1.3)
	_camera.size = maxf(span, 0.3) * MARGIN
	var back := Basis.from_euler(Vector3(PITCH, YAW, 0.0)) * Vector3(0, 0, 1)
	_camera.look_at_from_position(centre + back * 30.0, centre, Vector3.UP)


## The item as the shop sells it: a building at its first size, anything else as the farm draws it.
static func _model(id: String) -> Node3D:
	var it := Game.item_data(id)
	if str(it.get("kind", "")) in ["building", "barn", "crafting"]:
		return ModelKit.bake(BuildingModel.build(it, Game.footprint(id), 1))
	return ScaleGuide.model_of(id)
