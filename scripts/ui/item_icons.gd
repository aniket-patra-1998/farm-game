class_name ItemIcons
extends Node
## Pictures of items for the shop and the lists, made from the items' own 3D models (so a new item gets its
## picture with no art to draw): each is rendered off screen, in FarmVille's three-quarter view, into a texture
## that the cards already show, and kept on disk (user://icons), so it is made once per device, not once per
## session. A few are made together (`SLOTS` small viewports drawn in the same frame and read back the next, so
## the GPU waits once for all of them), as many as fit `BUDGET_MS` of building, the cards asked for last (the
## tab on screen) first, so opening the Market never waits. One renderer for the whole game, added by the HUD;
## `of` works before it exists.

const SIDE := 160             # the picture's size in pixels on a screen drawn at the game's own scale..
const SIDE_MOST := 384        # ..and the most on a dense one (`side`: sharp, not wasteful)
const PITCH := deg_to_rad(-35.0)
const YAW := deg_to_rad(45.0)
const MARGIN := 1.12          # room round the model inside the picture
const SLOTS := 4              # pictures drawn in one frame at most
const BUDGET_MS := 8          # building models for pictures stops after this much of a frame
const DEVELOP_US := 4000      # developing pictures (IconDevelop) stops after this much of a frame
const CACHE := "user://icons"
const SHIPPED := "res://baked/icons"   # every picture made ahead of time by CI, in the game
const UI := "ui:"             # an interface icon's picture is asked for as "ui:<kind>" (UiModels)
const UI_CLOSE := 0.8   # interface icons are framed this much closer than items
## Bump when the models' look changes, so pictures kept on disk are made again (the item's data and the game's
## version are in the key too).
const LOOK := 7
## The global shader values that change how the farm looks (weather, night). A picture made while any is set
## is shown this session but not kept, so a snowy or dark picture is never saved for good.
const MOODS: Array[StringName] = [&"wetness", &"snow_cover", &"dark"]
const CALM := 0.01
## The studio's lights: [pitch°, yaw°, colour, energy, shadows]: key, fill, rim.
const LIGHTS := [[-48.0, 28.0, Color(1.0, 0.96, 0.88), 0.85, true], [-20.0, -120.0, Color(0.75, 0.84, 1.0), 0.18,
	false], [-25.0, 200.0, Color(1.0, 0.97, 0.9), 0.35, false]]
const AMBIENT := Color(0.42, 0.42, 0.48)
const STAGE := &"Stage"   # not-ui (the node holding the model in a slot)

const SIZED := "@"            # "cow_shed@3": the picture of a building at that size (see `sized`)

static var shipping := false   # making the pictures that go into the game (tools/bake_icons.tscn)
static var _shown: ItemIcons
static var _side := 0          # this screen's picture size, worked out once
static var _textures := {}    # item id -> ImageTexture (blank until made)
static var _waiting: Array[String] = []
static var _asked := {}       # item id -> the frame it was last asked for

var _slots: Array[SubViewport] = []
var _making: Array[String] = []   # the item drawn in each slot ("" when the slot is idle)
var _pass: Array[int] = []        # each slot's render under way: 0 on black, 1 on white (IconDevelop)
var _blacks: Array[Image] = []    # each slot's render on black, kept until the one on white comes
var _developing: Array[IconDevelop] = []


## The picture for `item_id`: from disk when it was made before, else a texture that is blank until its turn
## comes, then shows the item.
static func of(item_id: String) -> Texture2D:
	if not _textures.has(item_id):
		var kept := Image.load_from_file(_file(item_id)) if FileAccess.file_exists(_file(item_id)) else null
		if kept == null and not shipping and ResourceLoader.exists(_shipped(item_id)):
			kept = load(_shipped(item_id)) as Image   # made by CI, in the game (tools/bake_icons.tscn)
			if kept != null and kept.get_width() != side():
				kept = kept.duplicate() as Image
				kept.resize(side(), side(), Image.INTERPOLATE_LANCZOS)
		if kept != null and kept.get_width() == side():
			_textures[item_id] = ImageTexture.create_from_image(kept)
			return _textures[item_id]
		_textures[item_id] = ImageTexture.create_from_image(Image.create(side(), side(), false, Image.FORMAT_RGBA8))
		_waiting.append(item_id)
	if _waiting.has(item_id):
		_asked[item_id] = Engine.get_process_frames()
	return _textures[item_id]


## The picture of building `id` at size `level` (made once and kept, like any item's).
static func sized(id: String, level: int) -> Texture2D:
	return of("%s%s%d" % [id, SIZED, level])


## The pictures' size in pixels on this screen: SIDE at the game's own scale, more where the screen draws the
## interface larger (a dense phone), up to SIDE_MOST, so cards stay sharp. Worked out once.
static func side() -> int:
	if _side == 0:
		var tree := Engine.get_main_loop() as SceneTree
		var dense := 1.0
		if tree != null and DisplayServer.get_name() != "headless":
			var view := tree.root.get_visible_rect().size
			dense = Vector2(DisplayServer.window_get_size()).x / maxf(view.x, 1.0)
		_side = clampi(int(SIDE * maxf(dense, 1.0) / 16.0) * 16, SIDE, SIDE_MOST)
	return _side


## Whether `item_id`'s picture is drawn (from disk, or made this session): until then it is blank.
static func is_made(item_id: String) -> bool:
	return _textures.has(item_id) and not _waiting.has(item_id) and not _shown_making(item_id)


static func _shown_making(item_id: String) -> bool:
	if not is_instance_valid(_shown):
		return false
	return _shown._making.has(item_id) or _shown._developing.any(func(j: IconDevelop) -> bool: return j.id == item_id)


## Puts the renderer under `parent` (once).
static func start(parent: Node) -> void:
	if is_instance_valid(_shown):
		return
	_shown = ItemIcons.new()
	parent.add_child(_shown)


## Where an item's picture is kept: its key changes with the item's data, the look and the game's version.
static func _file(item_id: String) -> String:
	return "%s/%s-%x.png" % [CACHE, item_id, _key(item_id)]


## Where CI keeps an item's picture in the game, made at SIDE_MOST (shrunk to the screen's size when loaded).
static func _shipped(item_id: String) -> String:
	return "%s/%s-%x.res" % [SHIPPED, item_id, _key(item_id)]


static func _key(item_id: String) -> int:
	# (a building at one of its sizes, "id@size", is keyed by the building's data and that size's numbers)
	var sized := item_id.split(SIZED)
	var data: Variant = Game.item_data(sized[0])
	if sized.size() > 1:
		data = [data, BuildingModel.spec(sized[0], int(sized[1]))]
	return hash([data, LOOK, ProjectSettings.get_setting("application/config/version", "")])


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
		if float(ShaderGlobals.value(mood)) > CALM:
			return false
	return true


func _ready() -> void:
	for k in SLOTS:
		_slots.append(_slot())
		_making.append("")
		_pass.append(0)
		_blacks.append(null)


## One small viewport with its own world, camera and a studio's lights: a warm key with soft shadows, a cool
## fill from the other side and a rim from behind that lifts the item's edge off the card. It draws on a plain
## colour (black, then white: IconDevelop cuts the item out from the two), SUPER times the picture's size.
func _slot() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i.ONE * side() * IconDevelop.SUPER
	vp.transparent_bg = false
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(camera)
	vp.set_meta(&"camera", camera)
	for light: Array in LIGHTS:
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(deg_to_rad(float(light[0])), deg_to_rad(float(light[1])), 0.0)
		sun.light_color = light[2]
		sun.light_energy = float(light[3])
		sun.shadow_enabled = bool(light[4])
		vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = AMBIENT
	vp.add_child(env)
	vp.set_meta(&"env", env.environment)
	add_child(vp)
	return vp


func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		_waiting.clear()         # (nothing draws without a screen: the cards keep their blank pictures)
		return
	var keep := _calm()
	_develop()
	for k in SLOTS:
		if _making[k] != "":
			_finish(k, keep)
	var started := Time.get_ticks_msec()
	for k in SLOTS:
		if _waiting.is_empty() or (k > 0 and Time.get_ticks_msec() - started > BUDGET_MS):
			break
		if _making[k] != "":
			continue   # (still on its second render)
		var id := _next()
		_waiting.erase(id)
		if _set_up(k, id):
			_making[k] = id
			_pass[k] = 0
			(_slots[k].get_meta(&"env") as Environment).background_color = Color.BLACK
			_slots[k].render_target_update_mode = SubViewport.UPDATE_ONCE   # (drawn at the end of this frame)


## Takes the render drawn last frame in slot `k`: the one on black is kept and the item drawn again on white; with
## both, the picture goes to be developed (IconDevelop) and the slot is free.
func _finish(k: int, keep: bool) -> void:
	var image := _slots[k].get_texture().get_image()
	if _pass[k] == 0 and image != null:
		_blacks[k] = image
		_pass[k] = 1
		(_slots[k].get_meta(&"env") as Environment).background_color = Color.WHITE
		_slots[k].render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	var id := _making[k]
	_making[k] = ""
	if image != null and not image.is_empty() and _blacks[k] != null:
		_developing.append(IconDevelop.new(id, _blacks[k], image, side(), keep, not id.begins_with(UI)))
	_blacks[k] = null
	var stage: Node = _slots[k].get_node_or_null(NodePath(STAGE))
	if stage != null:
		stage.name = &"Done"   # not-ui (freed at the end of the frame; the next stage takes the name now)
		stage.queue_free()


## Develops the pictures under way a few rows a frame; a finished one shows on its cards and is kept on disk.
func _develop() -> void:
	var started := Time.get_ticks_usec()
	while not _developing.is_empty() and Time.get_ticks_usec() - started < DEVELOP_US:
		var job: IconDevelop = _developing[0]
		if not job.step():
			continue
		_developing.pop_front()
		(_textures[job.id] as ImageTexture).update(job.picture)
		if job.keep and shipping:
			DirAccess.make_dir_recursive_absolute(SHIPPED)
			ResourceSaver.save(job.picture, _shipped(job.id), ResourceSaver.FLAG_COMPRESS)
		elif job.keep:
			DirAccess.make_dir_recursive_absolute(CACHE)
			_forget_old(job.id)
			job.picture.save_png(_file(job.id))


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
	if id.begins_with(UI):
		span *= UI_CLOSE   # (an interface icon fills its button: no ground around it to show)
	var camera: Camera3D = _slots[k].get_meta(&"camera")
	camera.size = maxf(span, 0.3) * MARGIN
	var back := Basis.from_euler(Vector3(PITCH, YAW, 0.0)) * Vector3(0, 0, 1)
	camera.look_at_from_position(centre + back * 30.0, centre, Vector3.UP)
	return true


## The item as the shop sells it: a building at its first size, a crop as a ripe bed, a building part as itself,
## anything else as the farm draws it.
static func _model(id: String) -> Node3D:
	if id.begins_with(UI):
		return UiModels.build(id.trim_prefix(UI))   # an interface icon (UiIcon draws it)
	if id.contains(SIZED):   # a building at one of its sizes (what its next size looks like)
		var sized := id.split(SIZED)
		return ModelKit.bake(BuildingModel.build(Game.item_data(sized[0]), Game.footprint(sized[0]), int(sized[1])))
	var art := AssetRegistry.instance(id)   # (made as a file: its picture is of the file)
	if art != null:
		return art
	var it := Game.item_data(id)
	if it.is_empty():
		# A crop: one ripe bed of it; a building part: the thing itself (null for anything unknown).
		return Crops3D.picture_model(id) if Game.crops.has(id) else MaterialModel.build(id)
	if str(it.get("kind", "")) in ["building", "barn", "crafting"]:
		return ModelKit.bake(BuildingModel.build(it, Game.footprint(id), 1))
	return ScaleGuide.model_of(id)
