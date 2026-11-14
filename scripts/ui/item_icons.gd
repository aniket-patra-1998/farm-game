class_name ItemIcons
extends Node
## Pictures of items for the shop and the lists, made from the items' own 3D models (so a new item gets its
## picture with no art to draw): each is rendered off screen, in FarmVille's three-quarter view, into a texture
## that the cards already show, and kept on disk (user://icons), so it is made once per device, not once per
## session. A few are made together (`SLOTS` small viewports drawn in the same frame and read back the next, so
## the GPU waits once for all of them), as many as fit `BUDGET_MS` of building, the cards asked for last (the
## tab on screen) first, so opening the Market never waits. One renderer for the whole game, added by the HUD;
## `of` works before it exists.

const SIDE := 160             # the picture's size in pixels
const PITCH := deg_to_rad(-35.0)
const YAW := deg_to_rad(45.0)
const MARGIN := 1.12          # room round the model inside the picture
const SLOTS := 4              # pictures drawn in one frame at most
const BUDGET_MS := 8          # building models for pictures stops after this much of a frame
const CACHE := "user://icons"
## Bump when the models' look changes, so pictures kept on disk are made again (the item's data and the game's
## version are in the key too).
const LOOK := 1
## The global shader values that change how the farm looks (weather, night). A picture made while any is set
## is shown this session but not kept, so a snowy or dark picture is never saved for good.
const MOODS: Array[StringName] = [&"wetness", &"snow_cover", &"dark"]
const CALM := 0.01
const STAGE := &"Stage"   # not-ui (the node holding the model in a slot)

static var _shown: ItemIcons
static var _textures := {}    # item id -> ImageTexture (blank until made)
static var _waiting: Array[String] = []
static var _asked := {}       # item id -> the frame it was last asked for

var _slots: Array[SubViewport] = []
var _making: Array[String] = []   # the item drawn in each slot this frame ("" when the slot is idle)


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


## Whether the farm looks as it does on a dry, clear day (a picture made now may be kept).
static func _calm() -> bool:
	for mood in MOODS:
		if float(ModelKit.globals.get(mood, 0.0)) > CALM:
			return false
	return true


func _ready() -> void:
	for k in SLOTS:
		_slots.append(_slot())
		_making.append("")


## One small viewport with its own world, camera, sun and plain light.
func _slot() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIDE, SIDE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(camera)
	vp.set_meta(&"camera", camera)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(30.0), 0.0)
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	vp.add_child(env)
	add_child(vp)
	return vp


func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		_waiting.clear()         # (nothing draws without a screen: the cards keep their blank pictures)
		return
	var keep := _calm()
	for k in SLOTS:
		if _making[k] != "":
			_finish(k, keep)
	var started := Time.get_ticks_msec()
	for k in SLOTS:
		if _waiting.is_empty() or (k > 0 and Time.get_ticks_msec() - started > BUDGET_MS):
			break
		var id := _next()
		_waiting.erase(id)
		if _set_up(k, id):
			_making[k] = id
			_slots[k].render_target_update_mode = SubViewport.UPDATE_ONCE   # (drawn at the end of this frame)


## Copies the picture drawn last frame in slot `k` into its item's texture, and keeps it on disk when `keep`.
func _finish(k: int, keep: bool) -> void:
	var id := _making[k]
	_making[k] = ""
	var image := _slots[k].get_texture().get_image()
	if image != null and not image.is_empty():
		(_textures[id] as ImageTexture).update(image)
		if keep:
			DirAccess.make_dir_recursive_absolute(CACHE)
			_forget_old(id)
			image.save_png(_file(id))
	var stage: Node = _slots[k].get_node_or_null(NodePath(STAGE))
	if stage != null:
		stage.name = &"Done"   # not-ui (freed at the end of the frame; the next stage takes the name now)
		stage.queue_free()


## Removes pictures of `id` kept under an older key.
static func _forget_old(id: String) -> void:
	for f in DirAccess.get_files_at(CACHE):
		if f.begins_with(id + "-"):
			DirAccess.remove_absolute(CACHE + "/" + f)


## Builds the item's model in slot `k` and points its camera at it, so it fills the picture. False when the item
## has no model (its card keeps a blank picture; nothing is drawn or saved).
func _set_up(k: int, id: String) -> bool:
	ModelKit.lods = false     # (a picture is drawn once, close up: simpler levels would be wasted work)
	var model := _model(id)
	ModelKit.lods = true
	if model == null:
		return false
	var stage := Node3D.new()
	stage.name = STAGE
	_slots[k].add_child(stage)
	stage.add_child(model)
	var box := SpaceFit.reach(model, model.transform)
	var top := ScaleGuide._top(model, model.transform)
	var centre := Vector3(box.get_center().x, top * 0.45, box.get_center().y)
	var span := maxf(maxf(box.size.x, box.size.y) * 1.2, top * 1.3)
	var camera: Camera3D = _slots[k].get_meta(&"camera")
	camera.size = maxf(span, 0.3) * MARGIN
	var back := Basis.from_euler(Vector3(PITCH, YAW, 0.0)) * Vector3(0, 0, 1)
	camera.look_at_from_position(centre + back * 30.0, centre, Vector3.UP)
	return true


## The item as the shop sells it: a building at its first size, anything else as the farm draws it.
static func _model(id: String) -> Node3D:
	var it := Game.item_data(id)
	if it.is_empty():
		return null
	if str(it.get("kind", "")) in ["building", "barn", "crafting"]:
		return ModelKit.bake(BuildingModel.build(it, Game.footprint(id), 1))
	return ScaleGuide.model_of(id)
