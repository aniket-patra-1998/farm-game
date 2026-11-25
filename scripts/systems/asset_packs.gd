class_name AssetPacks
extends Node
## Asset files that are not in the app: brought to the device when first needed, and kept (docs/PACKS.md).
##
## A pack is a Godot pack file with the made files of a few items (a limited animal and its baby). The app is
## exported without them; the first time one is to be drawn (`want`, asked by AssetRegistry) its pack is fetched
## from the source, checked against the source's manifest (size and SHA-256), kept under `kept`, and loaded, and
## `arrived` says which files are now there (the farm draws them again). Until then the thing is drawn by its
## stand-in. Kept packs are loaded as the game starts, with no network. A fetch that fails is tried again later.
## With no source (data/packs.json `base_url` empty) nothing is fetched: every file is expected in the app.

## Files that were not in the app are there now (res:// paths).
signal arrived(paths: Array[String])
## A fetch failed (no network, or a pack that did not check out): it will be tried again.
signal waiting
## The device has no room for the next pack: it is tried again later (the player is asked to free some space).
signal no_room
## The source's packs need a newer app (manifest `_min_app_code` above `app_code`): nothing more is fetched.
signal update_needed

const CONFIG := "res://data/packs.json"
const KEPT := "user://packs"
const INDEX := "index.json"           # in `kept`: pack -> the file kept for it
const MANIFEST := "manifest.json"     # at the source: pack -> {"file", "bytes", "sha256"} (tools/make_packs)
const PART := ".part"                 # not-ui (a file still coming)
const RETRY := 30.0                   # seconds before a failed fetch is tried again..
const RETRY_MOST := 600.0             # ..doubling each time to at most this
# Each wait is up to this much shorter or longer at random, so phones that lost the network together do not
# all come back in the same second.
const JITTER := 0.5
const SPARE_BYTES := 20 * 1048576     # room left on the device besides a pack and its copy being checked
const MIN_APP := "_min_app_code"      # in the manifest: the oldest app (version code) its packs work with
const LEVEL_PACKS := "res://data/level_packs.json"   # the level packs (tools/make_level_packs.py)
const EXTRAS := 0                     # a level pack's level for the extras: fetched at the start
const REACH := ".reach"              # the list fetched by `reach` lands beside the kept one, never on it
const AHEAD := 1                      # level packs are fetched this many levels before they are needed

static var shared: AssetPacks         # the game's own (GameState makes it); null in tests that make none

var source: PackSource                # where packs come from; null: nothing is fetched
var kept := KEPT                      # the folder packs are kept in
var app_code := 0                     # this app's version code (data/packs.json `app_code`, as exported)
var spare_bytes := SPARE_BYTES        # room kept free besides a pack (tests ask for more than any device has)
var online_only := false              # the game plays only online (data/packs.json; OnlineGate asks `reach`)
var stopped := false                  # the source needs a newer app: nothing is fetched this session

var _levels := {}                     # level pack -> its level (EXTRAS for the extras)
var _files := {}                      # pack -> the res:// files it brings
var _pack_of := {}                    # res:// file -> its pack
var _manifest := {}                   # the source's list, read once a session
var _index := {}                      # pack -> the file kept for it
var _asked: Array[String] = []        # packs wanted and not here yet, in the order asked
var _busy := false
var _wait := RETRY
var _again: Timer


## The game's packs, made once: the limited animals' (each with its baby), from the address in data/packs.json.
static func begin(game: GameState) -> AssetPacks:
	var packs := AssetPacks.new()
	game.add_child(packs)
	for id: String in game.item_order:
		var d := game.catalog.get_def(id) as AnimalDef
		if d != null and d.is_limited() and not d.is_young():
			var files: Array[String] = []
			for item: String in [id, d.baby()]:
				var file := str(AssetRegistry.entry(item).get("model", ""))
				if file != "":
					files.append(file)
			packs.add_pack(id, files)
	var levelled: Dictionary = game.read_json(LEVEL_PACKS).get("packs", {})
	for pack: String in levelled:
		var files: Array[String] = []
		files.assign(levelled[pack]["files"])
		packs.add_pack(pack, files, int(levelled[pack]["level"]))
	var config: Dictionary = game.read_json(CONFIG)
	packs.source = source_for(str(config.get("base_url", "")), packs)
	packs.app_code = int(config.get("app_code", 0))
	packs.online_only = bool(config.get("online_only", false))
	packs.load_kept()
	shared = packs
	return packs


## The source for an address: the web for http(s), a folder otherwise, none for "".
static func source_for(address: String, host: Node) -> PackSource:
	if address == "":
		return null
	return HttpPackSource.new(address, host) if address.begins_with("http") else FolderPackSource.new(address)   # not-ui


## Pack `pack` brings `files` (res:// paths). A level pack (`level` above 0, or EXTRAS) holds models a new player
## does not need yet (data/level_packs.json): fetched by `fetch_ahead`, not by the Limited tab.
func add_pack(pack: String, files: Array[String], level := -1) -> void:
	_files[pack] = files
	if level >= 0:
		_levels[pack] = level
	for file in files:
		_pack_of[file] = pack


## Every pack and the files it brings (pack -> res:// paths): what tools/make_packs makes.
func packs() -> Dictionary:
	return _files


## Whether `file` is one a pack brings.
func has(file: String) -> bool:
	return _pack_of.has(file)


## Whether `file` comes in a pack that is not on this device yet.
func away(file: String) -> bool:
	return has(file) and not _index.has(_pack_of[file])


## `file` is needed and is not there: if a pack brings it and there is a source, its pack is fetched (once).
## Returns whether it is on its way (the caller draws the stand-in meanwhile and hears `arrived`). With `fetch`
## false nothing is fetched (a picture in the Market: only what the player owns is worth a download), and the
## answer is whether it could be.
func want(file: String, fetch := true) -> bool:
	if source == null or not away(file):
		return false   # (nowhere to fetch from, no pack brings it, or its pack is here and does not hold it)
	var pack: String = _pack_of[file]
	if fetch and not _asked.has(pack):
		_asked.append(pack)
		_next()
	return true


## Whether every pack is on this device (or there is no source: every file is in the app). The Market's Limited
## tab sells what needs a pack only then (owner, 20 Nov: "a download option in the limited tab... so that placing
## is seamless").
func downloaded() -> bool:
	return source == null or missing() == 0


## How many packs are not on this device yet.
func missing() -> int:
	var n := 0
	for pack: String in _files:
		if not _index.has(pack) and not _levels.has(pack):
			n += 1
	return n


## How many packs there are in all (the Limited tab's: level packs come by themselves).
func total() -> int:
	return _files.size() - _levels.size()


## Whether packs are being fetched now (or waiting to be tried again).
func downloading() -> bool:
	return not _asked.is_empty()


## Fetches every pack not on this device yet, one after another (the Limited tab's Download).
func fetch_all() -> void:
	if source == null:
		return
	for pack: String in _files:
		if not _index.has(pack) and not _asked.has(pack) and not _levels.has(pack):
			_asked.append(pack)
	_next()


## Whether the source answers: its list is fetched (and kept, when none is yet), then `done(ok)`. No source:
## every file is in the app, ok. OnlineGate asks it at the start (the game plays only online).
func reach(done: Callable) -> void:
	if source == null:
		done.call(true)
		return
	DirAccess.make_dir_recursive_absolute(kept)
	var to := kept.path_join(MANIFEST + REACH)
	source.fetch(MANIFEST, to, func(came: bool) -> void:
		var list := DataFile.read_optional(to) if came else {}
		DirAccess.remove_absolute(to)
		if not list.is_empty() and _manifest.is_empty() and int(list.get(MIN_APP, 0)) <= app_code:
			_manifest = list
		done.call(not list.is_empty()))


## Fetches the level packs a player at `level` may soon use (docs/PACKS.md, Online): every level up to the next
## one, lowest first, then the extras (what turns up unbought: strays, finds). A pack whose files the app
## already has (the debug and benchmark builds keep them all) is not fetched.
func fetch_ahead(level: int) -> void:
	if source == null:
		return
	var due: Array[String] = []
	for pack: String in _levels:
		var at := int(_levels[pack])
		if (at == EXTRAS or at <= level + AHEAD) and not _index.has(pack) and not _asked.has(pack) and not in_app(pack):
			due.append(pack)
	due.sort_custom(func(a: String, b: String) -> bool:
		return _order(a) < _order(b))
	_asked.append_array(due)
	_next()


## Whether item `id`'s file comes in a Limited-tab pack (not a level pack).
func limited(id: String) -> bool:
	var file := AssetRegistry.file_of(AssetRegistry.entry(id), {})
	return has(file) and limited_pack(_pack_of[file])


## Whether `pack` is a Limited-tab pack (not a level pack).
func limited_pack(pack: String) -> bool:
	return _files.has(pack) and not _levels.has(pack)


## Whether the app itself has pack `pack`'s files (a build that keeps them all).
func in_app(pack: String) -> bool:
	var files: Array = _files.get(pack, [])
	return not files.is_empty() and not _index.has(pack) and ResourceLoader.exists(str(files[0]))


func _order(pack: String) -> int:
	var at := int(_levels[pack])
	return 1000 if at == EXTRAS else at


## Loads every pack kept on the device (the game's start: no network needed).
func load_kept() -> void:
	_index = DataFile.read_optional(kept.path_join(INDEX))   # (none kept yet: empty)
	for pack: String in _index.keys():
		var path := kept.path_join(str(_index[pack]))
		if not FileAccess.file_exists(path) or not ProjectSettings.load_resource_pack(path):
			_index.erase(pack)   # (gone or broken: it is fetched again when wanted)


## How many packs are wanted and not here yet.
func pending() -> int:
	return _asked.size()


func _next() -> void:
	if _busy or _asked.is_empty() or source == null or stopped:
		return
	_busy = true
	DirAccess.make_dir_recursive_absolute(kept)
	if _manifest.is_empty():
		var to := kept.path_join(MANIFEST)
		source.fetch(MANIFEST, to, func(came: bool) -> void:
			var list := DataFile.read_optional(to) if came else {}
			if int(list.get(MIN_APP, 0)) > app_code:
				stopped = true   # (packs made for a newer app: the player is asked to update; no retrying)
				_busy = false
				update_needed.emit()
			elif not list.is_empty():
				_manifest = list
				_busy = false
				_next()
			else:
				_failed())
		return
	var pack := _asked[0]
	var entry: Dictionary = _manifest.get(pack, {})
	if entry.is_empty():
		_asked.erase(pack)   # (the source has no such pack: its stand-in stays)
		_busy = false
		_next()
		return
	var dir := DirAccess.open(kept)
	var room := dir.get_space_left() if dir != null else 0
	if room > 0 and room < int(entry.get("bytes", 0)) * 2 + spare_bytes:   # (0: the device does not say)
		_busy = false
		no_room.emit()
		_retry()
		return
	var part := kept.path_join(str(entry["file"]) + PART)
	source.fetch(str(entry["file"]), part, func(came: bool) -> void: _fetched(pack, entry, part, came))


## A pack came (or didn't): checked, kept, loaded and said; or left for another try.
func _fetched(pack: String, entry: Dictionary, part: String, came: bool) -> void:
	var path := part.trim_suffix(PART)
	var whole := came and FileAccess.file_exists(part) and FileAccess.get_sha256(part) == str(entry.get("sha256", "")) \
		and FileAccess.open(part, FileAccess.READ).get_length() == int(entry.get("bytes", -1))
	if not whole or DirAccess.rename_absolute(part, path) != OK or not ProjectSettings.load_resource_pack(path):
		DirAccess.remove_absolute(part)
		_failed()
		return
	var old := str(_index.get(pack, ""))
	if old != "" and old != str(entry["file"]):
		DirAccess.remove_absolute(kept.path_join(old))   # (an earlier make of this pack)
	_index[pack] = str(entry["file"])
	var index := FileAccess.open(kept.path_join(INDEX), FileAccess.WRITE)
	if index != null:
		index.store_string(JSON.stringify(_index))
	_asked.erase(pack)
	_wait = RETRY
	_busy = false
	arrived.emit(_files[pack])
	_next()


## A fetch failed: said once, and tried again after a wait that grows.
func _failed() -> void:
	_busy = false
	waiting.emit()
	_retry()


## Tries the wanted packs again after a wait that doubles each time (from RETRY to RETRY_MOST), made a little
## shorter or longer at random (JITTER).
func _retry() -> void:
	if _again == null:
		_again = Timer.new()
		_again.one_shot = true
		_again.timeout.connect(_next)
		add_child(_again)
	if is_inside_tree():
		_again.start(_wait * randf_range(1.0 - JITTER, 1.0 + JITTER))
	_wait = minf(_wait * 2.0, RETRY_MOST)
