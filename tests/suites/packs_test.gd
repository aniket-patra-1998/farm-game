extends TestSuite
## Asset packs (AssetPacks, docs/PACKS.md): files left out of the app are fetched when first needed, checked
## against the source's manifest, kept on the device and loaded; and the export agrees with the address set.

const GHOST := "res://art/models/limited_test/ghost.glb"   # a file no app has: only its pack brings it
const MADE := "user://test_packs_made"
const BROKEN := "user://test_packs_broken"
const KEPT := "user://test_packs_kept"
const PRESETS := "res://export_presets.cfg"
const KEPT_624 := "user://test_packs_kept_624"


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
	var levelled := 0
	for pack: String in packs.packs():
		if not packs.limited_pack(pack):
			levelled += (packs.packs()[pack] as Array).size()
	for id: String in Game.item_order:
		var d := Game.catalog.get_def(id) as AnimalDef
		var file := str(AssetRegistry.entry(id).get("model", ""))
		if d != null and d.is_limited():
			limited += 1
			_check(file.begins_with("res://art/models/limited/") and packs.has(file)
				and packs.limited(id), "%s's file is a Limited pack's" % id)
		elif not file.begins_with("res://art/models/limited/") and packs.has(file):
			_check(not packs.limited(id), "%s's file is a level pack's" % id)
			_check(Game.catalog.get_def(id).unlock_level > int(DataFile.read(AssetPacks.LEVEL_PACKS)["starter_level"]),
				"%s is past the starter levels" % id)
	var brought := 0
	for pack: String in packs.packs():
		if packs.limited_pack(pack):
			brought += (packs.packs()[pack] as Array).size()
	_eq(brought, limited, "every limited animal's file is in one Limited pack (its own, or its parent's)")
	_check(levelled > 0, "the models past the starter levels are in level packs")
	_eq(packs.total(), packs.packs().size() - DataFile.read(AssetPacks.LEVEL_PACKS)["packs"].size(),
		"the Limited tab counts only its own packs")
	# The Play Store build leaves the level packs' files out; the APKs keep them (the bench draws the same farm).
	var cfg := ConfigFile.new()
	cfg.load(PRESETS)
	var some_file := str((DataFile.read(AssetPacks.LEVEL_PACKS)["packs"].values()[0] as Dictionary)["files"][0])
	for n in 8:
		var section := "preset.%d" % n
		if not cfg.has_section(section):
			continue
		var out := str(cfg.get_value(section, "exclude_filter", "")).contains(some_file.trim_prefix("res://"))
		_eq(out, str(cfg.get_value(section, "name")).contains("AAB"), "%s leaves the level packs out" % section)
	# One switch: with an address, the export leaves those files out and may use the internet; with none, neither.
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AssetPacks.CONFIG))
	var address := str(config.get("base_url", ""))
	var presets := FileAccess.get_file_as_string(PRESETS)
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


func test_624_the_downloader_waits_its_turn_needs_room_heeds_the_app_and_packs_no_code() -> void:
	# (Its own kept folder: 583's kept pack is loaded for the rest of the run and must stay where it is.)
	for folder: String in [MADE, KEPT_624]:
		_wipe(folder)
	var model := str(AssetRegistry.entry("galaxy_cow")["model"])
	# A pack never carries code (Google Play forbids downloading it): every script ships in the app.
	_check(PackMaker.is_code("res://scripts/game.gd") and PackMaker.is_code("lib/x.so") and not PackMaker.is_code(GHOST),
		"code is told from art")
	_check(PackMaker.make("bad", {"res://limited_test/bad.gd": model}, MADE).is_empty(), "a pack with code is not made")
	var entry := PackMaker.make("ghost", {GHOST: model}, MADE)
	_check(not entry.is_empty(), "an art pack is made")
	var files: Array[String] = [GHOST]
	# Packs made for a newer app: nothing is fetched, the player is asked to update, and nothing is retried.
	_write(MADE.path_join(PackMaker.MANIFEST), {AssetPacks.MIN_APP: 5, "ghost": entry})
	var packs := AssetPacks.new()
	add_child(packs)
	packs.kept = KEPT_624
	packs.app_code = 4
	packs.add_pack("ghost", files)
	var said := {"update": 0, "room": 0, "wait": 0}
	packs.update_needed.connect(func() -> void: said["update"] += 1)
	packs.no_room.connect(func() -> void: said["room"] += 1)
	packs.waiting.connect(func() -> void: said["wait"] += 1)
	packs.source = FolderPackSource.new(MADE)
	packs.want(GHOST)
	_check(said["update"] == 1 and packs.stopped and said["wait"] == 0, "an older app asks for an update, once")
	_check(not FileAccess.file_exists(KEPT_624.path_join(str(entry["file"]))), "and fetches nothing")
	packs.fetch_all()
	_eq(said["update"], 1, "nor tries again this session")
	packs.free()
	# A device without room for the pack: said, nothing written, tried again later at a wait jittered around RETRY.
	packs = AssetPacks.new()
	add_child(packs)
	packs.kept = KEPT_624
	packs.app_code = 5
	packs.spare_bytes = 1 << 60   # (more room than any device has)
	packs.add_pack("ghost", files)
	packs.no_room.connect(func() -> void: said["room"] += 1)
	packs.source = FolderPackSource.new(MADE)
	packs.want(GHOST)
	_check(said["room"] == 1 and not FileAccess.file_exists(KEPT_624.path_join(str(entry["file"]) + AssetPacks.PART)),
		"no room: said, and nothing half-written")
	var again := packs.get("_again") as Timer
	_check(again != null and again.time_left > 0.0, "tried again later")
	if again != null:
		_check(again.wait_time >= AssetPacks.RETRY * (1.0 - AssetPacks.JITTER)
			and again.wait_time <= AssetPacks.RETRY * (1.0 + AssetPacks.JITTER), "after a jittered wait")
	packs.free()
	# The app's version code in data/packs.json is the one exported.
	var presets := ConfigFile.new()
	presets.load(PRESETS)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AssetPacks.CONFIG))
	for section: String in presets.get_sections():
		if section.ends_with(".options") and presets.has_section_key(section, "version/code"):
			_eq(int(presets.get_value(section, "version/code")), int(config.get("app_code", -1)),
				"%s exports the app_code the downloader compares" % section)
	_check(int(config.get("min_app_code", 0)) <= int(config.get("app_code", 0)), "this app takes its own packs")
	_wipe(MADE)


func test_625_level_packs_come_a_level_ahead_extras_last_and_never_what_the_app_has() -> void:
	var packs := AssetPacks.new()
	add_child(packs)
	packs.kept = KEPT_624
	var a: Array[String] = ["res://nowhere/a.glb"]
	var b: Array[String] = ["res://nowhere/b.glb"]
	var c: Array[String] = ["res://nowhere/c.glb"]
	var x: Array[String] = ["res://nowhere/x.glb"]
	var had: Array[String] = [str(AssetRegistry.entry("cow")["model"])]   # (a file this app has)
	packs.add_pack("extras", x, AssetPacks.EXTRAS)
	packs.add_pack("level_09", c, 9)
	packs.add_pack("level_07", b, 7)
	packs.add_pack("level_06", a, 6)
	packs.add_pack("level_05", had, 5)
	packs.add_pack("limited_one", c.duplicate())
	var silent := Silent.new()
	packs.source = silent
	packs.fetch_ahead(6)
	_eq(packs.get("_asked"), ["level_06", "level_07", "extras"] as Array[String],
		"up to the next level, lowest first, extras last; not later levels, not what the app has, not Limited packs")
	_check(packs.in_app("level_05") and not packs.in_app("level_06"), "the app's own files are told apart")
	_eq(packs.total(), 1, "the Limited tab counts only its own pack")
	_check(packs.limited_pack("limited_one") and not packs.limited_pack("level_06"), "a level pack is not Limited")
	packs.free()


func test_626_the_start_asks_the_source_and_only_a_phone_is_kept_offline() -> void:
	for folder: String in [MADE, KEPT_624]:
		_wipe(folder)
	_write(MADE.path_join(PackMaker.MANIFEST), {AssetPacks.MIN_APP: 1, "a": {"file": "a.pck", "bytes": 1, "sha256": "x"}})
	var packs := AssetPacks.new()
	add_child(packs)
	packs.kept = KEPT_624
	packs.app_code = 1
	var heard: Array = []
	packs.reach(func(ok: bool) -> void: heard.append(ok))
	packs.source = FolderPackSource.new(MADE)
	packs.reach(func(ok: bool) -> void: heard.append(ok))
	packs.source = Unreachable.new()
	packs.reach(func(ok: bool) -> void: heard.append(ok))
	_eq(heard, [true, true, false], "no source: every file is here; a source that answers; one that does not")
	_check((packs.get("_manifest") as Dictionary).has("a"), "the list that came is kept for the fetches")
	_check(not FileAccess.file_exists(KEPT_624.path_join(PackMaker.MANIFEST + AssetPacks.REACH)), "and not left over")
	packs.free()
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AssetPacks.CONFIG))
	_check(bool(config.get("online_only", false)), "the game plays only online (owner, 25 Nov)")
	OnlineGate.check(self)
	_eq(get_children().filter(func(c: Node) -> bool: return c is OnlineGate).size(), 0,
		"not on a desktop or in tests: the gate is a phone's")
	_wipe(MADE)


## A source that never answers yes (no network).
class Unreachable extends PackSource:
	func fetch(_name: String, _to: String, done: Callable) -> void:
		done.call(false)


func test_628_the_play_store_build_is_barnlight_and_the_test_builds_keep_their_ids() -> void:
	var presets := ConfigFile.new()
	presets.load(PRESETS)
	var ids := {}
	for section: String in presets.get_sections():
		if section.ends_with(".options") and presets.has_section_key(section, "package/unique_name"):
			ids[presets.get_value(section.trim_suffix(".options"), "name")] = presets.get_value(section, "package/unique_name")
	# (owner, 25 Nov: Barnlight. The id can never change after the first upload; the test builds keep theirs, so
	# a phone's farm in them stays where it is.)
	_eq(ids.get("Android (Play Store AAB)"), "com.aniketpatra.barnlight", "the Play Store id")
	_eq(ids.get("Android (debug APK)"), "com.example.farmgame.debug", "the test build's id is unchanged")
