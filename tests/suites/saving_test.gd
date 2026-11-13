extends TestSuite
## Saving and loading: every field and every system survives a round trip.


func test_16_save_and_load_round_trip() -> void:
	var path := "user://test_save.json"
	var g := _farm()
	g.save_path = path
	g.saving_enabled = true
	g.coins = 4321
	g.gems = 9
	g.farm_size = 16
	g.add_unwithers(3)
	g.buy_and_place("chicken", 8, 8)
	g.parts["nails"] = 3
	g.storage.barn().erase("broken")
	g.storage.store_object(int(g.object_at(g.index_of(4, 0))["uid"])) # the mailbox
	g.save_game()
	var held := g.unwithers
	_done(g)

	var h := GameState.new()
	h.save_path = path
	add_child(h)
	h.saving_enabled = false # don't write the scratch file again after this test removes it
	_eq(h.coins, 4321 - 120, "coins restored")
	_eq(h.gems, 9, "gems restored")
	_eq(h.farm_size, 16, "farm size restored")
	_eq(h.unwithers, held, "unwithers restored")
	_eq(h.object_at(h.index_of(8, 8)).get("id", ""), "chicken", "objects restored")
	_eq(int(h.parts["nails"]), 3, "parts restored")
	_check(h.storage.barn_repaired(), "barn repair restored")
	_eq(h.storage.stored.size(), 1, "stored items restored")
	_eq(h.storage.stored[0]["id"], "mailbox", "the stored item is the mailbox")
	h.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))






func test_88_every_system_saves_and_loads_its_own_fields() -> void:
	var g := _farm(true)
	g.crafting.bushels = {"wheat": 3}
	g.vehicles.fuel_tanks = 2
	g.vehicles.vehicle_levels = {"tractor": 1}
	g.bees.queen_bees = 1
	g.pigpen.truffles = 7
	g.shed.bunches = ["lilac"]
	g.mystery.mystery_eggs = {"white": 2}
	g.collectibles.coll_levels = {"berries": 1}
	g.ribbons.stats = {"harvests": 12}
	g.mastery.points = {"wheat": 40, "cow": 9}
	g.nurture.supplies = {"watering_can": 3, "animal_feed": 5}
	var owners := {}
	var data := {}
	for system in g.systems:
		var mine := {}
		system.save_to(mine)
		for k in mine:
			_check(not owners.has(k), "save key %s is written by one system only" % k)
			owners[k] = system
		data.merge(mine)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(data))
	var h := GameState.new()
	h.saving_enabled = false
	add_child(h)
	for system in h.systems:
		system.load_from(saved)
	var again := {}
	for system in h.systems:
		system.save_to(again)
	_eq(JSON.stringify(again), JSON.stringify(data), "every system's state survives a save and load")
	_eq(h.crafting.bushels, {"wheat": 3}, "numbers come back as whole numbers")
	_eq(h.systems.size(), 26, "all subsystems are registered")
	h.queue_free()
	_done(g)


func test_111_an_old_save_settles_into_the_new_footprints() -> void:
	# Version 1 saves drew the Pig Pen 3x3; it's 3x4 now, so a chicken standing just below it is in the way.
	# Loading moves the chicken to the nearest free spot, says so, and nothing overlaps.
	var path := "user://test_save_v1.json"
	var g := _farm()
	g.save_path = path
	g.saving_enabled = true
	g.farm_size = GameState.MAX_SIZE
	g.save_game()
	_done(g)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data["version"] = 1
	var uid := int(data.get("next_uid", 1))
	data["objects"].append({"id": "pig_pen", "uid": uid, "row": 14, "col": 14, "t": 0})
	data["objects"].append({"id": "chicken", "uid": uid + 1, "row": 17, "col": 14, "t": 0})
	data["next_uid"] = uid + 2
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

	var h := GameState.new()
	h.save_path = path
	add_child(h)
	h.saving_enabled = false
	_eq(h.object_at(h.index_of(14, 14)).get("id", ""), "pig_pen", "the pig pen keeps its spot")
	_eq(h.object_at(h.index_of(17, 14)).get("id", ""), "pig_pen", "and now covers a fourth row")
	var chicken := h.object_by_uid(uid + 1)
	_eq(chicken.get("id", ""), "chicken", "the chicken is still on the farm")
	var moved := absi(int(chicken["row"]) - 17) + absi(int(chicken["col"]) - 14)
	_check(moved == 1, "it moved to the nearest free spot (%d tiles)" % moved)
	_eq(h.object_at(h.index_of(int(chicken["row"]), int(chicken["col"]))).get("uid", -1), uid + 1,
		"where nothing else stands")
	_eq(h.settle_objects(), 0, "after that, everything fits")
	h.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_124_a_damaged_save_falls_back_to_the_backup_and_saves_are_batched() -> void:
	var path := "user://test_save_backup.json"
	var g := _farm()
	g.save_path = path
	g.saving_enabled = true
	g.coins = 1111
	g.save_game()
	g.coins = 2222
	g.save_game()  # the first save is now the backup
	g.saving_enabled = false
	_check(FileAccess.file_exists(path + GameState.BACKUP_SUFFIX), "the last good save is kept")
	_check(not FileAccess.file_exists(path + GameState.TEMP_SUFFIX), "no half-written file is left")
	_done(g)

	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\"version\": 2, \"coins\": 33")  # a write cut short
	f.close()
	var h := GameState.new()
	h.save_path = path
	add_child(h)
	h.saving_enabled = false
	_eq(h.coins, 1111, "the farm comes back from the backup, not as a new game")

	h.saving_enabled = true
	h.queue_save()
	h.queue_save()
	_check(h.persistence.due_msec >= 0, "a change waits to be saved")
	h.save_game()
	_eq(h.persistence.due_msec, -1, "and one save covers all of them")
	h.saving_enabled = false
	h.queue_free()
	for suffix in ["", GameState.BACKUP_SUFFIX, GameState.TEMP_SUFFIX]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func test_142_a_queued_save_is_written_off_the_main_thread_and_is_the_whole_farm() -> void:
	var path := "user://test_save_thread.json"
	var g := _farm()
	g.save_path = path
	g.saving_enabled = true
	g.coins = 4321
	g.save_game(true)
	g.coins = 99                # changed while the thread may still be writing: the copy must not see it
	g.finish_saving()
	var h := _farm()
	h.save_path = path
	h.saving_enabled = false
	_check(h.load_game(), "the background save loads")
	_eq(h.coins, 4321, "it holds the farm as it was when the save began")
	g.save_game(true)           # a second one waits for the first, and a plain save waits too
	g.save_game()
	_check(not g.persistence.is_writing(), "nothing is left running")
	g.saving_enabled = false
	_done(h)
	_done(g)
	for suffix in ["", GameState.BACKUP_SUFFIX, GameState.TEMP_SUFFIX]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func test_143_a_damaged_save_is_mended_on_load_never_a_crash() -> void:
	var items := {"hay_bale": true, "cow_shed": true}
	var good := {"id": "hay_bale", "uid": 5, "row": 3, "col": 4, "t": 10}
	var data := {
		"coins": -50, "gems": "lots", "xp": NAN, "farmhands": 2.0,
		"next_uid": 1,
		"objects": [
			good.duplicate(),
			"not an object",
			{"id": "hay_bale", "uid": 6, "col": 1},                       # no row
			{"id": "gone_item", "uid": 7, "row": 1, "col": 1, "t": 0},    # item no longer exists
			{"id": "hay_bale", "uid": 5, "row": 9, "col": 9, "t": 0},     # same uid as the first
			{"id": "hay_bale", "uid": 8, "row": 99, "col": 1, "t": 0},    # off the grid
			{"id": "cow_shed", "uid": 9.0, "row": 2.0, "col": 2.0, "level": "high", "t": 1.0},
		],
		"plots": [{"state": "plowed"}, 7, {}],
	}
	var fixed := SaveCheck.clean(data, items, 30, {"state": "grass"})
	_check(fixed >= 8, "everything wrong was counted (%d)" % fixed)
	_eq((data["objects"] as Array).size(), 2, "only the two sound objects stay")
	_eq((data["objects"][0] as Dictionary)["uid"], 5, "the first of two sharing a uid stays")
	var cow: Dictionary = data["objects"][1]
	_eq(cow["uid"], 9, "float numbers become whole numbers")
	_check(not cow.has("level"), "an unreadable level is dropped")
	_eq(data["next_uid"], 10, "new things are numbered above every kept uid")
	_check(not data.has("coins") and not data.has("gems") and not data.has("xp"), "bad counts fall back to defaults")
	_eq(data["farmhands"], 2, "a good count is kept as a whole number")
	_eq(data["plots"][1], {"state": "grass"}, "a damaged plot becomes grass")
	_eq(data["plots"][2], {"state": "grass"}, "so does an empty one")
	_eq(SaveCheck.clean({"objects": [good.duplicate()], "plots": []}, items, 30, {"state": "grass"}), 0,
		"a sound save is left alone")

	var path := "user://test_save_damaged.json"
	var g := _farm()
	g.save_path = path
	g.saving_enabled = false
	var f := FileAccess.open(path, FileAccess.WRITE)
	var plots: Array = []
	for i in 900:
		plots.append({"state": "grass"})
	f.store_string(JSON.stringify({"version": 2, "coins": 77, "plots": plots, "next_uid": 0,
		"objects": [{"id": "hay_bale", "uid": 1}, 5, null, {"id": "hay_bale", "uid": 2, "row": 1, "col": 1, "t": 0}]}))
	f.close()
	_check(g.load_game(), "a save with broken objects still loads")
	_eq(g.coins, 77, "and keeps what was sound")
	_eq(g.objects.size(), 1, "only the whole object is on the farm")
	_check(g.next_uid > 2, "new things get fresh uids")
	_done(g)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_144_saves_from_other_versions_migrate_or_are_refused() -> void:
	var path := "user://test_save_versions.json"
	var g := _farm()
	g.save_path = path
	g.saving_enabled = true
	g.coins = 555
	g.save_game()
	_done(g)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_eq(int(data["version"]), GameState.SAVE_VERSION, "a save is written in the current version")
	# The oldest version we still read: fields added since are missing, and each gets its default.
	for key in ["tutorial_step", "farm_size", "clear_until", "unwithers", "parts", "farmhands", "next_uid"]:
		data.erase(key)
	data["version"] = GameState.OLDEST_SAVE_VERSION
	_write_json(path, data)
	var old := GameState.new()
	old.save_path = path
	add_child(old)
	old.saving_enabled = false
	_eq(old.coins, 555, "an old save keeps its coins")
	_eq(old.tutorial_step, GameState.Tutorial.DONE, "an old player has already done the tutorial")
	_eq(old.farm_size, GameState.START_SIZE, "missing fields take their defaults")
	_eq(old.unwithers, Balance.i("economy.start_unwithers"), "including starting gifts")
	_check(old.next_uid >= 1, "and new things can be numbered")
	old.queue_free()
	# A save from a newer game is not read (and not overwritten by a half-understood copy).
	data["version"] = GameState.SAVE_VERSION + 1
	_write_json(path, data)
	var future := GameState.new()
	future.save_path = path
	add_child(future)
	future.saving_enabled = false
	_eq(future.coins, Balance.i("economy.start_coins"), "a save from a newer game is not read: a new farm starts")
	var kept := "%s.v%d" % [path, GameState.SAVE_VERSION + 1]
	_check(FileAccess.file_exists(kept), "and kept aside, so the new farm doesn't overwrite it")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(kept))
	future.queue_free()
	# Two things never share a uid.
	var h := _farm()
	var before := h.objects.size()
	h.add_object({"uid": 7777, "id": "hay_bale", "row": 1, "col": 1, "t": 0})
	h.add_object({"uid": 7777, "id": "hay_bale", "row": 3, "col": 3, "t": 0})
	_eq(h.objects.size(), before + 1, "an object with a taken uid is not added")
	_done(h)
	for suffix in ["", GameState.BACKUP_SUFFIX, GameState.TEMP_SUFFIX]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func test_178_a_clock_set_back_does_not_leave_timers_in_the_future() -> void:
	var path := "user://test_save_clock.json"
	var g := _farm()
	g.save_path = path
	g.saving_enabled = true
	g.set_objects([])
	g.coins = 10000000
	g.xp = g.xp_for_level(60)
	_check(g.buy_and_place("chicken_coop", 1, 1), "coop bought")
	var coop := g.object_at(g.index_of(1, 1))
	g.plots[g.index_of(8, 8)] = {"state": "planted", "crop": "wheat", "planted_at": g.now()}
	var stamped := int(coop["t"])
	g.save_game()
	g.finish_saving()
	# The save says it was made an hour from now: the device clock has since been set back an hour.
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	saved["saved_at"] = int(saved["saved_at"]) + 3600
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(JSON.stringify(saved))
	out.close()
	var h := _farm()
	h.save_path = path
	h.saving_enabled = false
	_check(h.load_game(), "loads")
	var loaded := h.object_at(h.index_of(1, 1))
	_check(int(loaded["t"]) <= h.now(), "no timer is in the future")
	_check(absi(int(loaded["t"]) - (stamped - 3600)) <= 2, "each timer keeps its progress (shifted by the skew)")
	_check(int(h.plots[h.index_of(8, 8)]["planted_at"]) <= h.now(), "a planted plot too")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func test_188_saves_are_brought_up_one_version_at_a_time() -> void:
	var data := {"version": GameState.OLDEST_SAVE_VERSION, "plots": []}
	_check(SaveMigrations.upgrade(data), "the oldest version we read upgrades")
	_eq(int(data["version"]), GameState.SAVE_VERSION, "to the current one")
	for v in range(GameState.OLDEST_SAVE_VERSION, GameState.SAVE_VERSION):
		_check(SaveMigrations.STEPS.has(v), "there is a step recorded for version %d" % v)
	_check(not SaveMigrations.upgrade({"version": GameState.SAVE_VERSION + 1}), "a save from a newer game is left alone")
	_check(not SaveMigrations.upgrade({"version": 0}), "and one from before we read any")
	var old: Array = []
	for k in GameState.OLD_GRID_SIZE * GameState.OLD_GRID_SIZE:
		old.append({"state": "grass"})
	var wide := {"version": GameState.SAVE_VERSION, "plots": old}
	SaveMigrations.upgrade(wide)
	_eq((wide["plots"] as Array).size(), GameState.MAX_SIZE * GameState.MAX_SIZE, "a 12x12 grid is widened")


func test_189_the_level_is_remembered_until_the_xp_or_the_numbers_change() -> void:
	var g := _farm()
	g.xp = g.xp_for_level(7)
	_eq(g.level(), 7, "level 7 at its XP")
	g.xp = g.xp_for_level(7) - 1
	_eq(g.level(), 6, "one XP short")
	g.xp = g.xp_for_level(9)
	_eq(g.level(), 9, "and up again")
	var table: Array = Balance.a("economy.level_xp")
	Balance.override("economy.level_xp", table.map(func(v): return int(v) * 2))
	_check(g.level() < 9, "a change to the XP table is seen at once")
	Balance.reload()
	_eq(g.level(), 9, "and so is putting it back")


func test_190_the_farm_opens_with_what_happened_while_away() -> void:
	var g := _farm()
	g.set_objects([])
	for i in g.plots.size():
		g.plots[i] = {"state": "grass"}   # the start farm has fields of its own
	var wheat: String = "wheat"
	var grow := int(g.crops[wheat]["grow_seconds"])
	var window := g.field.ripe_window(g.crops[wheat])
	var now := g.now()
	# One ripened an hour ago (an hour after the save), and one withered ten minutes ago.
	g.plots[g.index_of(2, 2)] = {"state": "planted", "crop": wheat, "planted_at": now - grow - 3600}
	g.plots[g.index_of(2, 3)] = {"state": "planted", "crop": wheat, "planted_at": now - grow - window - 600}
	var from_t := now - 2 * 3600       # saved two hours ago
	var line := AbsenceReport.build(g, from_t, now)
	_check(line.contains("1 crops ripened"), "one crop ripened meanwhile (%s)" % line)
	_check(line.contains("1 crops withered"), "and one withered (%s)" % line)
	_eq(AbsenceReport.build(g, now - 60, now), "", "a minute away says nothing")
	g.plots[g.index_of(2, 2)] = {"state": "grass"}
	g.plots[g.index_of(2, 3)] = {"state": "grass"}
	_eq(AbsenceReport.build(g, from_t, now), "", "nothing to tell, nothing said")
