extends TestSuite
## Asset packs (AssetPacks, docs/PACKS.md): files left out of the app are fetched when first needed, checked
## against the source's manifest, kept on the device and loaded; and the export agrees with the address set.

const GHOST := "res://art/models/limited_test/ghost.glb"   # a file no app has: only its pack brings it
const MADE := "user://test_packs_made"
const BROKEN := "user://test_packs_broken"
const KEPT := "user://test_packs_kept"


func _wipe(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))


func _write(path: String, what: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(what))
	file.close()


func test_583_a_file_left_out_of_the_app_is_fetched_when_first_needed() -> void:
	for folder: String in [MADE, BROKEN, KEPT]:
		_wipe(folder)
	# A pack that brings GHOST, made from what the importer made of a real animal's file.
	var entry := PackMaker.make("ghost", {GHOST: str(AssetRegistry.entry("galaxy_cow")["model"])}, MADE)
	_check(not entry.is_empty() and FileAccess.file_exists(MADE.path_join(str(entry.get("file", "")))),
		"a pack is made")
	_check(str(entry.get("file", "")).contains(str(entry.get("sha256", "-")).left(8)), "named by its own hash")
	_write(MADE.path_join(PackMaker.MANIFEST), {"ghost": entry})
	DirAccess.copy_absolute(MADE.path_join(str(entry["file"])), BROKEN.path_join(str(entry["file"])))
	_write(BROKEN.path_join(PackMaker.MANIFEST),
		{"ghost": {"file": entry["file"], "bytes": entry["bytes"], "sha256": "not it"}})
	var files: Array[String] = [GHOST]
	# With no source nothing is fetched; a pack that does not check out is not kept or loaded, and waits.
	var packs := AssetPacks.new()
	add_child(packs)
	packs.kept = KEPT
	packs.add_pack("ghost", files)
	_check(not packs.want(GHOST), "with nowhere to fetch from, nothing is on its way")
	var waits := [0]
	packs.waiting.connect(func() -> void: waits[0] += 1)
	packs.source = FolderPackSource.new(BROKEN)
	_check(packs.want(GHOST), "wanted: its pack is on its way")
	_check(waits[0] == 1 and packs.pending() == 1 and not ResourceLoader.exists(GHOST),
		"a pack that does not match its manifest is not loaded, and is tried again later")
	_check(not FileAccess.file_exists(KEPT.path_join(str(entry["file"]))), "nor kept")
	packs.free()
	# From a good source: fetched once, checked, kept, loaded, and said.
	packs = AssetPacks.new()
	add_child(packs)
	packs.kept = KEPT
	packs.add_pack("ghost", files)
	packs.source = FolderPackSource.new(MADE)
	var came: Array = []
	packs.arrived.connect(func(paths: Array[String]) -> void: came.append_array(paths))
	_check(packs.away(GHOST) and packs.want(GHOST, false) and came.is_empty() and not ResourceLoader.exists(GHOST),
		"asked about without fetching (a picture in the Market): it could come, and is not sent for")
	_check(packs.want(GHOST), "wanted")
	_check(not packs.want(GHOST), "(asked again once it is here: nothing more to fetch)")
	_eq(came, [GHOST], "its file arrives")
	_eq(packs.pending(), 0, "nothing is left on its way")
	_check(ResourceLoader.exists(GHOST) and load(GHOST) is PackedScene, "and is there to load")
	_check(FileAccess.file_exists(KEPT.path_join(str(entry["file"])))
		and FileAccess.file_exists(KEPT.path_join(AssetPacks.INDEX)), "the pack is kept on the device")
	# The registry asks for a missing file's pack itself, and draws the file once it is there.
	var games := AssetPacks.shared
	AssetPacks.shared = packs
	AssetRegistry._extra["ghost_cow"] = {"model": GHOST, "budget": "animal"}
	var model := AssetRegistry.instance("ghost_cow")
	_check(model != null, "the animal is drawn from its fetched file")
	if model != null:
		model.free()
	_check(not AssetRegistry.away("ghost_cow"), "(and is no longer away)")
	# A picture shown of its stand-in is made again once the file is there.
	ItemIcons._textures["ghost_cow"] = ImageTexture.new()
	(load(ItemIcons.MAKER) as GDScript).call(&"remake", files)
	_check(ItemIcons._waiting.has("ghost_cow"), "its picture is made again, of the file")
	ItemIcons._textures.erase("ghost_cow")
	ItemIcons._waiting.erase("ghost_cow")
	AssetRegistry._extra.erase("ghost_cow")
	AssetPacks.shared = games
	packs.free()
	# The next start loads what was kept, with no source.
	packs = AssetPacks.new()
	add_child(packs)
	packs.kept = KEPT
	packs.load_kept()
	_check((packs.get("_index") as Dictionary).has("ghost"), "a kept pack is loaded at the next start, with no network")
	packs.free()
	# (The kept pack stays where it is: it is loaded for the rest of this run, and holds a real animal's made file.)
	for folder: String in [MADE, BROKEN]:
		_wipe(folder)


func test_584_the_packs_are_the_limited_animals_and_the_export_agrees_with_the_address() -> void:
	var packs := AssetPacks.shared
	_check(packs != null, "the game has its packs")
	if packs == null:
		return
	var limited := 0
	for id: String in Game.item_order:
		var d := Game.catalog.get_def(id) as AnimalDef
		var file := str(AssetRegistry.entry(id).get("model", ""))
		if d != null and d.is_limited():
			limited += 1
			_check(file.begins_with("res://art/models/limited/") and packs.has(file), "%s's file is a pack's" % id)
		else:
			_check(not file.begins_with("res://art/models/limited/") and not packs.has(file), "%s's file is the app's" % id)
	var brought := 0
	for pack: String in packs.packs():
		brought += (packs.packs()[pack] as Array).size()
	_eq(brought, limited, "every limited animal's file is in one pack (its own, or its parent's)")
	# One switch: with an address, the export leaves those files out and may use the internet; with none, neither.
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AssetPacks.CONFIG))
	var address := str(config.get("base_url", ""))
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_eq(presets.contains("art/models/limited/*"), address != "",
		"the export leaves the limited files out exactly when there is an address to fetch them from")
	if address != "":
		_check(not presets.contains("permissions/internet=false"), "and the app may use the internet")
		_check(packs.source != null, "and the game has its source")


## A source that is asked and never answers (the Download's queue is what is checked; 583 fetches for real).
class Silent extends PackSource:
	var asked: Array[String] = []

	func fetch(name: String, _to: String, _done: Callable) -> void:
		asked.append(name)


func test_610_the_limited_tabs_download_fetches_every_pack() -> void:
	# Owner, 20 Nov: "a download option in the limited tab... it first downloads everything so that placing is
	# seamless". fetch_all sends for every pack not here (one after another); downloaded says when all are;
	# until then a limited animal whose file is away can't be bought (BuildingSystem.Why.DOWNLOAD).
	var packs := AssetPacks.new()
	add_child(packs)
	packs.kept = "user://test_packs_none"
	packs.add_pack("one", ["res://art/models/limited_test/one.glb"] as Array[String])
	packs.add_pack("two", ["res://art/models/limited_test/two.glb"] as Array[String])
	_check(packs.downloaded(), "with nowhere to fetch from, every file is in the app")
	var source := Silent.new()
	packs.source = source
	_check(not packs.downloaded() and packs.missing() == 2 and packs.total() == 2, "two packs to download")
	_check(not packs.downloading(), "nothing sent for yet")
	packs.fetch_all()
	_check(packs.downloading() and packs.pending() == 2, "the Download sends for both")
	_eq(source.asked, [PackMaker.MANIFEST] as Array[String], "the list of packs first, then each in turn")
	packs.fetch_all()
	_eq(packs.pending(), 2, "asked twice: nothing more")
	packs.free()
