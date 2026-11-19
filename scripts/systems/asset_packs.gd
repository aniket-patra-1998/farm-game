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

const CONFIG := "res://data/packs.json"
const KEPT := "user://packs"
const INDEX := "index.json"           # in `kept`: pack -> the file kept for it
const MANIFEST := "manifest.json"     # at the source: pack -> {"file", "bytes", "sha256"} (tools/make_packs)
const PART := ".part"                 # not-ui (a file still coming)
const RETRY := 30.0                   # seconds before a failed fetch is tried again..
const RETRY_MOST := 600.0             # ..doubling each time to at most this

static var shared: AssetPacks         # the game's own (GameState makes it); null in tests that make none

var source: PackSource                # where packs come from; null: nothing is fetched
var kept := KEPT                      # the folder packs are kept in

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
	var config: Dictionary = game.read_json(CONFIG)
	packs.source = source_for(str(config.get("base_url", "")), packs)
	packs.load_kept()
	shared = packs
	return packs


## The source for an address: the web for http(s), a folder otherwise, none for "".
static func source_for(address: String, host: Node) -> PackSource:
	if address == "":
		return null
	return HttpPackSource.new(address, host) if address.begins_with("http") else FolderPackSource.new(address)   # not-ui


## Pack `pack` brings `files` (res:// paths).
func add_pack(pack: String, files: Array[String]) -> void:
	_files[pack] = files
	for file in files:
		_pack_of[file] = pack


## Every pack and the files it brings (pack -> res:// paths): what tools/make_packs makes.
func packs() -> Dictionary:
	return _files


## Whether `file` is one a pack brings.
func has(file: String) -> bool:
	return _pack_of.has(file)


## `file` is needed and is not there: if a pack brings it and there is a source, its pack is fetched (once).
## Returns whether it is on its way (the caller draws the stand-in meanwhile and hears `arrived`).
func want(file: String) -> bool:
	if source == null or not has(file):
		return false
	var pack: String = _pack_of[file]
	if _index.has(pack):
		return false   # (its pack is here and loaded: the file is there, or the pack does not hold it)
	if not _asked.has(pack):
		_asked.append(pack)
		_next()
	return true


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
	if _busy or _asked.is_empty() or source == null:
		return
	_busy = true
	DirAccess.make_dir_recursive_absolute(kept)
	if _manifest.is_empty():
		var to := kept.path_join(MANIFEST)
		source.fetch(MANIFEST, to, func(came: bool) -> void:
			var list := DataFile.read_optional(to) if came else {}
			if not list.is_empty():
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
	if _again == null:
		_again = Timer.new()
		_again.one_shot = true
		_again.timeout.connect(_next)
		add_child(_again)
	if is_inside_tree():
		_again.start(_wait)
	_wait = minf(_wait * 2.0, RETRY_MOST)
