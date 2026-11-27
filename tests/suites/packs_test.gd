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


func test_629_remote_tuning_takes_only_numbers_the_file_knows_and_wins_over_it() -> void:
	var was := Balance.f("specials.stable_helper_chance")
	var taken := Balance.take_remote({"values": {"specials.stable_helper_chance": 0.5, "no.such_key": 3.0,
		"economy.level_xp": "not a list"}})
	_eq(taken, 1, "only a known key with the file's type is taken")
	_eq(Balance.f("specials.stable_helper_chance"), 0.5, "and it wins over data/balance.json")
	Balance.take_remote({})
	_eq(Balance.f("specials.stable_helper_chance"), was, "an empty tuning puts the file's number back")
	var shipped: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/remote/tuning.json"))
	for key: String in shipped.get("values", {}):
		_check(Balance.has(key), "the shipped tuning names a real number: %s" % key)
	_check(Balance.REMOTE.begins_with("user://") and AssetPacks.TUNING == "tuning.json", "fetched beside the packs")


func test_630_the_audit_of_27_nov_holds_a_floor_a_deal_scarce_helpers_and_no_late_decor_xp() -> void:
	Game.reset_game()
	# A new player keeps enough to plow and plant.
	var cheap := ""
	for id: String in Game.item_order:
		var it := Game.item_data(id)
		if str(it.get("kind", "")) == "decor" and int(it.get("unlock_level", 1)) <= 1 and not it.has("gem_cost") \
				and int(it.get("cost", 0)) > 0:
			cheap = id
			break
	_check(cheap != "", "a level-1 decoration to try")
	Game.coins = int(Game.item_data(cheap)["cost"]) + Balance.i("economy.keep_coins") - 1
	_eq(Game.buildings.can_buy(cheap).why, BuildingSystem.Why.COINS, "a buy leaving under the floor is held back")
	Game.coins += 1
	_check(Game.buildings.can_buy(cheap).ok(), "one that leaves the floor is not")
	# Today's deal: one item, cheaper, the same all day.
	Game.coins = 1000000
	Game.xp = int(Balance.a("economy.level_xp")[14])
	var deal := Game.buildings.deal_id()
	_check(deal != "" and deal == Game.buildings.deal_id(), "a deal, the same when asked again")
	if deal != "":
		var full := int(Game.item_data(deal)["cost"])
		_eq(int(Game.buildings.price_of(deal)["coins"]), roundi(full * (1.0 - Balance.f("market.deal_off"))),
			"the deal is market.deal_off cheaper")
		_check(full >= Balance.i("market.deal_min_cost") and not Game.limited.is_limited(deal), "and a fit item")
	# Decorations stop paying XP at economy.decor_xp_until_level.
	var d := Game.catalog.get_def(cheap)
	Game.xp = int(Balance.a("economy.level_xp")[Balance.i("economy.decor_xp_until_level") - 1])
	_eq(d.buy_xp(), 0, "no decoration XP from its level")
	Game.reset_game()
	# Helpers are scarce in play.
	_check(Balance.f("specials.stable_helper_chance") <= 0.06, "a Stable harvest rarely gives a helper")


func test_631_play_statistics_go_through_the_gameanalytics_sdk_only_with_keys_and_consent() -> void:
	var shipped: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Analytics.CONFIG))
	_check(str(shipped.get("game_key", "")) == "" or str(shipped.get("secret_key", "")) != "", "keys come in pairs")
	_check(FileAccess.file_exists("res://addons/GameAnalytics/GameAnalytics.gdextension"), "the official SDK is in")
	var sdk := FakeSdk.new()
	var a := Analytics.new()
	add_child(a)
	sdk.attach(a)
	a.config = {"game_key": "k", "secret_key": "s", "events": ["buy"]}
	var was: Variant = PlayerSettings.value(Analytics.SETTINGS[0], Analytics.SETTINGS[1], true)
	PlayerSettings.keep(Analytics.SETTINGS[0], {Analytics.SETTINGS[1]: false})
	a.start()
	a.design("buy:cow")
	_eq(sdk.calls.size(), 0, "opted out: the SDK is not even started")
	PlayerSettings.keep(Analytics.SETTINGS[0], {Analytics.SETTINGS[1]: true})
	a.start()
	_check(sdk.names().has("init"), "with keys and consent the SDK starts")
	a._did("buy", "cow", 1)
	a._did("harvest", "wheat", 1)
	_check(sdk.names().has("addDesignEvent") and sdk.last("addDesignEvent")[0] == "buy:cow",
		"listed verbs become design events")
	_eq(sdk.count("addDesignEvent"), 1, "others don't")
	PlayerSettings.keep(Analytics.SETTINGS[0], {Analytics.SETTINGS[1]: false})
	a.start()
	_eq(sdk.last("setEnabledEventSubmission")[0], false, "turned off in Settings: sending stops at once")
	PlayerSettings.keep(Analytics.SETTINGS[0], {Analytics.SETTINGS[1]: was})
	a.free()
	sdk.free_stand_in()


## Stands in for GameAnalytics' SDK: takes each call Analytics would make of it (Analytics.send).
class FakeSdk extends RefCounted:
	var calls: Array = []
	var stand_in := Object.new()   # (Analytics.sdk must be something; the calls come here instead)

	func take(method: String, args: Array) -> void:
		calls.append([method, args])

	func names() -> Array:
		return calls.map(func(c: Array) -> String: return c[0])

	func count(n: String) -> int:
		return names().count(n)

	func last(n: String) -> Array:
		for i in range(calls.size() - 1, -1, -1):
			if calls[i][0] == n:
				return calls[i][1]
		return []

	func attach(a: Analytics) -> void:
		a.sdk = stand_in
		a.send = take

	func free_stand_in() -> void:
		stand_in.free()


func test_633_a_purchase_is_given_once_by_its_token_and_the_starter_pack_only_once() -> void:
	Game.reset_game()
	var s := Game.purchases
	_check(PurchaseSystem.client == null and not s.open(), "no store away from a Play build")
	_eq(s.on_sale()[0], "starter_pack", "the starter pack first, while not bought")
	var gems := Game.gems
	var pack := {"purchase_token": "t1", "product_ids": ["gems_medium"], "purchase_state": PurchaseSystem.PURCHASED}
	s.take(pack)
	_eq(Game.gems, gems + 240, "a paid pack gives its gems")
	s.take(pack)
	_eq(Game.gems, gems + 240, "the same purchase handed back again (not yet consumed) is not given twice")
	s.take({"purchase_token": "t2", "product_ids": ["gems_small"], "purchase_state": PurchaseSystem.PENDING})
	_eq(Game.gems, gems + 240, "a pending one waits for its payment")
	var hands := Game.farmhands
	s.take({"purchase_token": "t3", "product_ids": ["starter_pack"], "purchase_state": PurchaseSystem.PURCHASED})
	_eq(Game.farmhands, hands + 2, "the starter pack's contents")
	_check(not s.on_sale().has("starter_pack"), "and it leaves the shop once bought")
	_check(s.words("starter_pack").contains("60") and s.words("gems_large").contains("520"), "each says what it gives")
	var saved := {}
	s.save_to(saved)
	s.reset()
	s.load_from(saved)
	_check(s.owned.has("starter_pack") and s.given.has("t1"), "owned and given are saved")
	var shop: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PurchaseSystem.CONFIG))
	for p: Dictionary in shop["products"]:
		_check(HudMarket.PACK_NAMES.has(p["id"]), "a name for %s" % p["id"])
	Game.reset_game()


func test_634_errors_purchases_and_ads_reach_the_statistics_and_the_review_is_asked_rarely() -> void:
	var sdk := FakeSdk.new()
	var a := Analytics.new()
	add_child(a)
	sdk.attach(a)
	a.config = {"game_key": "k", "secret_key": "s"}
	var was: Variant = PlayerSettings.value(Analytics.SETTINGS[0], Analytics.SETTINGS[1], true)
	PlayerSettings.keep(Analytics.SETTINGS[0], {Analytics.SETTINGS[1]: true})
	a.start()
	a.business("gems", "gems_medium", 44900, "INR")
	_eq(sdk.last("addBusinessEvent").slice(0, 4), ["INR", 44900, "gems", "gems_medium"], "a purchase with its price")
	a.ad("reward_received", "gift")
	_eq(sdk.last("addAdEvent").slice(0, 4), ["reward_received", "rewarded_video", "admob", "gift"], "an ad event")
	Analytics.ErrorTap.take()
	var tap := Analytics.ErrorTap.new()
	for k in Analytics.ERROR_REPEATS + 5:
		tap._log_error("f", "res://x.gd", 3, "", "the same error", false, Logger.ERROR_TYPE_ERROR, [])
	tap._log_error("f", "res://x.gd", 4, "", "a warning", false, Logger.ERROR_TYPE_WARNING, [])
	a._send_errors()
	_eq(sdk.count("addErrorEvent"), Analytics.ERROR_REPEATS, "one error message at most ERROR_REPEATS times; no warnings")
	var before := Balance.i("ads.per_day")
	a._on_configs(JSON.stringify({"tuning": JSON.stringify({"values": {"ads.per_day": before + 1}})}))
	_eq(Balance.i("ads.per_day"), before + 1, "a remote config named tuning tunes Balance")
	Balance.reload()
	PlayerSettings.keep(Analytics.SETTINGS[0], {Analytics.SETTINGS[1]: was})
	a.free()
	sdk.free_stand_in()
	var level: int = Balance.a("review.levels")[0]
	var many := Balance.i("review.least_sessions")
	_check(ReviewAsk.wanted(level, many, 100, 0), "asked after a listed level-up")
	_check(not ReviewAsk.wanted(level + 1, many, 100, 0), "not after any other")
	_check(not ReviewAsk.wanted(level, many - 1, 100, 0), "not in the first sessions")
	_check(not ReviewAsk.wanted(level, many, 100, 100 - Balance.i("review.gap_days") + 1), "not again too soon")


## Stands in for the ad player (rewarded_ads.gd): always loaded, and it notes which format each play asked for.
class FakeAdPlayer:
	extends Node
	var asked: Array = []

	func loaded() -> bool:
		return true

	func play(on_reward: Callable, short := false) -> void:
		asked.append(short)
		on_reward.call()
