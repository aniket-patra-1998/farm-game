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
	_eq(h.systems.size(), 14, "all subsystems are registered")
	h.queue_free()
	_done(g)
