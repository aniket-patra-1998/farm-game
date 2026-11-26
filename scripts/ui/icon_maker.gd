extends Node
## The renderer of ItemIcons' pictures: each item's 3D model drawn off screen in a few small viewports, read back,
## developed and kept (ItemIcons says what and where). Loaded by path when ItemIcons.start runs (a frame after the
## first screen), never named, so the start does not compile it or the models it builds pictures from.

const MARGIN := 1.12          # room round the model inside the picture
const SLOTS := 4              # pictures drawn in one frame at most
const BUDGET_MS := 8          # building models for pictures stops after this much of a frame
const DEVELOP_US := 4000      # developing pictures (IconDevelop) stops after this much of a frame
const UI_CLOSE := 1.0   # interface icons are framed as items are (room for their outline and white edge)
## The state an item made as a file is pictured in (AssetRegistry): its first look and size, ready (a tree in
## fruit).
const PICTURED := {"look": 0, "ready": true, "level": 1}
const PICTURE_PLANTS := 4         # trees or blooms standing in a home for them, in its picture..
const PICTURE_SPREAD := 0.2       # ..this share of its footprint out from the middle each way..
const PICTURE_PLANT_SIZE := 0.8   # ..at this share of their own size
## The studio's lights: [pitch°, yaw°, colour, energy, shadows]: key, fill, rim.
const LIGHTS := [[-48.0, 28.0, Color(1.0, 0.96, 0.88), 0.85, true], [-20.0, -120.0, Color(0.75, 0.84, 1.0), 0.18,
	false], [-25.0, 200.0, Color(1.0, 0.97, 0.9), 0.35, false]]
const AMBIENT := Color(0.42, 0.42, 0.48)
const STAGE := &"Stage"   # not-ui (the node holding the model in a slot)

var _style: IconStyle            # the flat look, drawn on each picture once (IconStyle)
var _to_style: Array[IconDevelop] = []
var _slots: Array[SubViewport] = []
var _making: Array[String] = []   # the item drawn in each slot ("" when the slot is idle)
var _pass: Array[int] = []        # each slot's render under way: 0 on black, 1 on white (IconDevelop)
var _read: Array[int] = []        # each slot's read back: 0 not asked, 1 under way (GpuRead), 2 come
var _got: Array = []              # each slot's image read back
var _blacks: Array[Image] = []    # each slot's render on black, kept until the one on white comes
var _stand_in: Array[bool] = []   # each slot's item drawn by its stand-in (its file's pack is not here): not kept
var _developing: Array[IconDevelop] = []


## Whether `item_id`'s picture is under way here (drawn, developed or styled).
func holds(item_id: String) -> bool:
	var mine := func(j: IconDevelop) -> bool: return j.id == item_id
	return _making.has(item_id) or _developing.any(mine) or _to_style.any(mine) or _style.holds(item_id)


func _ready() -> void:
	_style = IconStyle.new()
	add_child(_style)
	for k in SLOTS:
		_slots.append(_slot())
		_making.append("")
		_pass.append(0)
		_read.append(0)
		_got.append(null)
		_blacks.append(null)
		_stand_in.append(false)
	if AssetPacks.shared != null and not AssetPacks.shared.arrived.is_connected(remake):
		AssetPacks.shared.arrived.connect(remake)   # (a static: connected once, whichever renderer is first)


## One small viewport with its own world, camera and a studio's lights: a warm key with soft shadows, a cool
## fill from the other side and a rim from behind that lifts the item's edge off the card. It draws on a plain
## colour (black, then white: IconDevelop cuts the item out from the two), SUPER times the picture's size.
func _slot() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i.ONE * ItemIcons.side() * IconDevelop.SUPER
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
	var pt := PerfReadout.start()
	_process_timed(_delta)
	PerfReadout.stop("item_pictures", pt)


func _process_timed(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		ItemIcons._waiting.clear()         # (nothing draws without a screen: the cards keep their blank pictures)
		return
	var keep := ItemIcons._calm()
	var pt := PerfReadout.start()
	_develop()
	PerfReadout.stop("pictures_develop", pt)
	pt = PerfReadout.start()
	_style_next()
	PerfReadout.stop("pictures_style", pt)
	for k in SLOTS:
		if _making[k] != "":
			_finish(k, keep and not _stand_in[k])
	var started := Time.get_ticks_msec()
	for k in SLOTS:
		if ItemIcons._waiting.is_empty() or (k > 0 and Time.get_ticks_msec() - started > BUDGET_MS):
			break
		if _making[k] != "":
			continue   # (still on its second render)
		var id := ItemIcons._next()
		ItemIcons._waiting.erase(id)
		var su := PerfReadout.start()
		var ready := _set_up(k, id)
		PerfReadout.stop("pictures_build", su)
		if ready:
			_making[k] = id
			_pass[k] = 0
			(_slots[k].get_meta(&"env") as Environment).background_color = Color.BLACK
			_slots[k].render_target_update_mode = SubViewport.UPDATE_ONCE   # (drawn at the end of this frame)


## Takes the render drawn last frame in slot `k`: the one on black is kept and the item drawn again on white; with
## both, the picture goes to be developed (IconDevelop) and the slot is free.
func _finish(k: int, keep: bool) -> void:
	if _read[k] == 0:   # (the render is drawn: copy it off the chip in the background, not stopping the frame)
		_read[k] = 1
		var pt := PerfReadout.start()
		GpuRead.take(_slots[k], func(img: Image) -> void:
			_got[k] = img
			_read[k] = 2)
		PerfReadout.stop("pictures_read", pt)
	if _read[k] != 2:
		return
	_read[k] = 0
	var image: Image = _got[k]
	_got[k] = null
	if _pass[k] == 0 and image != null:
		_blacks[k] = image
		_pass[k] = 1
		(_slots[k].get_meta(&"env") as Environment).background_color = Color.WHITE
		_slots[k].render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	var id := _making[k]
	_making[k] = ""
	if image != null and not image.is_empty() and _blacks[k] != null:
		_developing.append(IconDevelop.new(id, _blacks[k], image, ItemIcons.side(), keep, false))   # (flat: no shadow)
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
		_to_style.append(job)


## The flat look (IconStyle): one developed picture a turn is drawn through it, then shown and kept.
func _style_next() -> void:
	var job := _style.finished()
	if job != null:
		_show_and_keep(job)
	if not _style.busy() and not _to_style.is_empty():
		_style.take(_to_style.pop_front())


func _show_and_keep(job: IconDevelop) -> void:
	(ItemIcons._textures[job.id] as ImageTexture).update(job.picture)
	if job.keep and ItemIcons.shipping:
		DirAccess.make_dir_recursive_absolute(ItemIcons.SHIPPED)
		ResourceSaver.save(job.picture, ItemIcons._shipped(job.id), ResourceSaver.FLAG_COMPRESS)
	elif job.keep:
		# Kept on disk off the main thread (writing a PNG is a frame's worth of work).
		var path := ItemIcons._file(job.id)
		var old := ItemIcons._forget_old(job.id)
		var picture := job.picture
		ItemIcons._finish_saves(false)
		ItemIcons._saving.append(WorkerThreadPool.add_task(func() -> void:
			DirAccess.make_dir_recursive_absolute(ItemIcons.CACHE)
			for f in old:
				DirAccess.remove_absolute(f)
			picture.save_png(path)))


## Files that were not in the app have arrived (AssetPacks.arrived): the pictures shown of their stand-ins are
## made again, of the files.
static func remake(paths: Array[String]) -> void:
	for id: String in ItemIcons._textures:
		var file := AssetRegistry.file_of(AssetRegistry.entry(id.split(ItemIcons.SIZED)[0]), {})
		if file in paths and not ItemIcons._waiting.has(id):
			ItemIcons._waiting.append(id)


## Builds the item's model in slot `k` and points its camera at it, so it fills the picture. False when the item
## has no model (its card keeps a blank picture; nothing is drawn or saved).
func _set_up(k: int, id: String) -> bool:
	ModelKit.lods = false     # (a picture is drawn once, close up: simpler levels would be wasted work)
	AssetRegistry.fetches = false   # (nor does a picture fetch a pack: a stand-in's picture is shown, not kept)
	var model := model(id)
	AssetRegistry.fetches = true
	ModelKit.lods = true
	_stand_in[k] = AssetRegistry.away(id.split(ItemIcons.SIZED)[0])
	if model == null:
		return false
	var stage := Node3D.new()
	stage.name = STAGE
	_slots[k].add_child(stage)
	stage.add_child(model)
	var box := SpaceFit.reach(model, model.transform)
	var top := ScaleGuide._top(model, Transform3D.IDENTITY)   # (_top applies the model's own transform itself)
	var centre := Vector3(box.get_center().x, top * 0.45, box.get_center().y)
	var span := maxf(maxf(box.size.x, box.size.y) * 1.2, top * 1.3)
	if id.begins_with(ItemIcons.UI):
		span *= UI_CLOSE   # (an interface icon fills its button: no ground around it to show)
	var camera: Camera3D = _slots[k].get_meta(&"camera")
	camera.size = maxf(span, 0.3) * MARGIN
	var back := Basis.from_euler(Vector3(ItemIcons.PITCH, ItemIcons.YAW, 0.0)) * Vector3(0, 0, 1)
	camera.look_at_from_position(centre + back * 30.0, centre, Vector3.UP)
	return true


## The item as the shop sells it: a building at its first size, a crop as a ripe bed, a building part as itself,
## anything else as the farm draws it.
static func model(id: String) -> Node3D:
	if id.begins_with(ItemIcons.UI):
		return UiModels.build(id.trim_prefix(ItemIcons.UI))   # an interface icon (UiIcon draws it)
	if id.contains(ItemIcons.SIZED):   # a building at one of its sizes (what its next size looks like)
		var sized := id.split(ItemIcons.SIZED)
		return Objects3D.building_look(sized[0], int(sized[1]))   # (shared with the farm's: built once)
	var painted := Release.on("painted_crops")   # (crops and flowers are painted pictures: so are their pictures)
	var towards := Basis.from_euler(Vector3(ItemIcons.PITCH, ItemIcons.YAW, 0.0))
	if painted and str(Game.item_data(id).get("kind", "")) == "bloom":
		return PaintedBloom.picture_card(id, towards)
	var art := AssetRegistry.instance(id, PICTURED)   # (made as a file: its picture is of the file)
	if art != null:
		return art
	var it := Game.item_data(id)
	if it.is_empty():
		# A crop: one ripe bed of it; a crafted good or produce: the thing itself (GoodsModel); a building part
		# likewise (null for anything unknown).
		if Game.crops.has(id):
			return PaintedCrops.harvest_card(id, towards) if painted else Crops3D.picture_model(id)
		var good := GoodsModel.build(id)
		return good if good != null else MaterialModel.build(id)
	if str(it.get("kind", "")) in ["building", "barn", "crafting"]:
		var home := Objects3D.building_look(id, 1)   # (the farm's own copy when it stands there)
		_plant_picture(home, it, Game.footprint(id))
		return home
	return ScaleGuide.model_of(id)


## A home for trees or blooms (the Orchard, the Bloom Garden) is pictured with a few of them standing in it: an
## empty one is a flat square of grass and says nothing.
static func _plant_picture(home: Node3D, it: Dictionary, fp: Vector2i) -> void:
	var holds := str(it.get("holds_kind", ""))
	if not holds in ["tree", "bloom"]:
		return
	var first := ""
	for other: String in Game.item_order:
		if str(Game.item_data(other).get("kind", "")) == holds:
			first = other
			break
	if first == "":
		return
	for k in PICTURE_PLANTS:
		var plant := model(first)
		if plant == null:
			continue
		var side := 1.0 if k % 2 == 0 else -1.0
		var row := 1.0 if k < 2 else -1.0
		plant.position = Vector3(side * fp.x * PICTURE_SPREAD, 0.0, row * fp.y * PICTURE_SPREAD)
		plant.scale = Vector3.ONE * PICTURE_PLANT_SIZE
		home.add_child(plant)


## Lets go of the looks kept in statics (Game, on quit), so none is still held when the engine shuts down.
