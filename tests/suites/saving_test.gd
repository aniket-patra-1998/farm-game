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
	_eq(h.systems.size(), 19, "all subsystems are registered")
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
	_check(h._save_due_msec >= 0, "a change waits to be saved")
	h.save_game()
	_eq(h._save_due_msec, -1, "and one save covers all of them")
	h.saving_enabled = false
	h.queue_free()
	for suffix in ["", GameState.BACKUP_SUFFIX, GameState.TEMP_SUFFIX]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
