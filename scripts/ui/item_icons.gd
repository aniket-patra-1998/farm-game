class_name ItemIcons
extends RefCounted
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
const CACHE := "user://icons"
const SHIPPED := "res://baked/icons"   # every picture made ahead of time by CI, in the game
const UI := "ui:"             # an interface icon's picture is asked for as "ui:<kind>" (UiModels)
## The global shader values that change how the farm looks (weather, night). A picture made while any is set
## is shown this session but not kept, so a snowy or dark picture is never saved for good.
const MOODS: Array[StringName] = [&"wetness", &"snow_cover", &"dark", &"rain", &"cloud_shade"]
const CALM := 0.01

## The renderer, loaded by path when started (a frame after the first screen), so the start never compiles it.
const MAKER := "res://scripts/ui/icon_maker.gd"
const SIZED := "@"            # "cow_shed@3": the picture of a building at that size (see `sized`)

static var shipping := false   # making the pictures that go into the game (tools/bake_icons.tscn)
static var _shown: Node        # the maker (scripts/ui/icon_maker.gd), once started
static var _side := 0          # this screen's picture size, worked out once
static var _textures := {}    # item id -> ImageTexture (blank until made)
static var _waiting: Array[String] = []
static var _saving: Array[int] = []   # pictures being written to disk off the main thread (task ids)
static var _asked := {}       # item id -> the frame it was last asked for
static var _on_disk := {}     # item id -> its files in the cache (listed once a session)


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
	return bool(_shown.call(&"holds", item_id))


## Puts the renderer under `parent` (once).
static func start(parent: Node) -> void:
	if is_instance_valid(_shown):
		return
	_shown = (load(MAKER) as GDScript).new()
	parent.add_child(_shown)


## Where an item's picture is kept: its key changes with the item's data, its art (ArtVersion: so a picture is
## made again by itself, on every device, when the art changes) and the game's version.
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
		data = [data, BuildingSpec.spec(sized[0], int(sized[1]))]
	return hash([data, ArtVersion.of(sized[0]), ProjectSettings.get_setting("application/config/version", "")])


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


## Waits on the pictures being saved: those already written (`all` false), or every one (on quit). Every task the
## pool is given must be waited on, or it and the picture it holds are never let go.
static func _finish_saves(all: bool) -> void:
	for t in _saving.duplicate():
		if all or WorkerThreadPool.is_task_completed(t):
			WorkerThreadPool.wait_for_task_completion(t)
			_saving.erase(t)


## Pictures of `id` kept under an older key, to remove (the folder listed once a session, not per picture).
static func _forget_old(id: String) -> PackedStringArray:
	if _on_disk.is_empty():
		_on_disk = {"": true}
		for f in DirAccess.get_files_at(CACHE):
			var named := f.get_slice("-", 0)   # (an id has no "-": "-" begins its key)
			if not _on_disk.has(named):
				_on_disk[named] = PackedStringArray()
			(_on_disk[named] as PackedStringArray).append(CACHE + "/" + f)
	var old: PackedStringArray = _on_disk.get(id, PackedStringArray())
	_on_disk[id] = PackedStringArray([_file(id)])
	var out := PackedStringArray()
	for f in old:
		if f != _file(id):
			out.append(f)
	return out


## The item as the shop sells it (the maker's model; tests and tools ask for it here).
static func _model(id: String) -> Node3D:
	return (load(MAKER) as GDScript).call(&"model", id)


static func release_statics() -> void:
	_finish_saves(true)
	_textures.clear()
