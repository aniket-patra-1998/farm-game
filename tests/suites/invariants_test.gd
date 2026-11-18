extends TestSuite
## Random play: a seeded run of buying, placing, moving, selling, collecting, planting, harvesting, expanding,
## crafting, feeding, storing, helpers, VIP, rust repairs, mystery prizes and the clock jumping (an hour, a day, a
## month on, a day back), with the farm's invariants checked after every step. It finds the cases nobody thought
## to write a test for; a failure names the seed and the step so it can be replayed. The push run stays small; the
## nightly workflow (.github/workflows/fuzz.yml) runs it long: `-- --fuzz-seeds=300 --fuzz-steps=2000`.

const SEEDS := [1, 7, 42, 2024, 99991]
const STEPS := 220
const ACTIONS := ["buy", "buy", "buy", "move", "move", "sell", "collect", "collect", "plow", "plant", "harvest",
	"expand", "wait", "wait", "craft", "feed", "store", "unstore", "helper", "vip", "repair", "mystery", "clock"]
const CLOCK_JUMPS := [3600, 86400, 30 * 86400, -86400]   # the device clock moved on an hour, a day, a month; back a day
const SIGNED := ["from", "to"]   # may be negative: an inbox item's sender and receiver (InboxItem.ME, .FARM)


## The seeds and steps to run: the push run's, or the nightly run's from the command line.
func _plan() -> Vector2i:
	var plan := Vector2i(SEEDS.size(), STEPS)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fuzz-seeds="):
			plan.x = int(arg.trim_prefix("--fuzz-seeds="))
		elif arg.begins_with("--fuzz-steps="):
			plan.y = int(arg.trim_prefix("--fuzz-steps="))
	return plan


func test_194_random_play_keeps_the_farm_consistent() -> void:
	var plan := _plan()
	var seeds: Array = SEEDS.duplicate()
	for k in range(seeds.size(), plan.x):
		seeds.append(k * 7919 + 13)
	for seed_value: int in seeds.slice(0, plan.x):
		var g := _farm(true)
		g.rng.seed = seed_value
		var dice := RandomNumberGenerator.new()
		dice.seed = seed_value
		var placeable: Array[String] = []
		for id: String in g.items:
			if not g.catalog.get_def(id) is CropDef:
				placeable.append(id)
		var crops: Array[String] = []
		for id: String in g.crops:
			crops.append(id)
		var bad := ""
		for step in plan.y:
			g.coins = maxi(g.coins, 2_000_000)
			g.gems = maxi(g.gems, 500)
			g.xp = maxi(g.xp, g.xp_for_level(40))
			var action: String = ACTIONS[dice.randi_range(0, ACTIONS.size() - 1)]
			_act(g, dice, action, placeable, crops)
			bad = _broken(g)
			if bad != "":
				_check(false, "seed %d step %d (%s): %s" % [seed_value, step, action, bad])
				break
		if bad == "":
			bad = _round_trip(g, seed_value)
			_check(bad == "", "seed %d: %s" % [seed_value, bad if bad != "" else "saved and loaded back whole"])
		_done(g)


func _act(g: GameState, dice: RandomNumberGenerator, action: String, placeable: Array[String],
		crops: Array[String]) -> void:
	var tile := Vector2i(dice.randi_range(-1, g.farm_size), dice.randi_range(-1, g.farm_size))
	var any: Dictionary = g.objects[dice.randi_range(0, g.objects.size() - 1)] if not g.objects.is_empty() else {}
	var plot := g.index_of(clampi(tile.x, 0, g.farm_size - 1), clampi(tile.y, 0, g.farm_size - 1))
	match action:
		"buy":
			g.buy_and_place(placeable[dice.randi_range(0, placeable.size() - 1)], tile.x, tile.y)
		"move":
			if not any.is_empty():
				g.move_object(int(any["uid"]), tile.x, tile.y)
		"sell":
			if not any.is_empty():
				g.sell_object(int(any["uid"]))
		"collect":
			if not any.is_empty():
				g.collect(int(any["uid"]))
		"plow":
			g.field.plow(plot)
		"plant":
			g.field.plant(plot, crops[dice.randi_range(0, crops.size() - 1)])
		"harvest":
			g.field.harvest(plot)
		"expand":
			g.land.expand(false)
		"wait":
			g.debug_time_offset += dice.randi_range(60, 3 * 86400)
		"clock":
			g.debug_time_offset += int(CLOCK_JUMPS[dice.randi_range(0, CLOCK_JUMPS.size() - 1)])
		_:
			_act_more(g, dice, action, any, tile)
	g.objects_updated()


## The systems beyond the field: crafting, feeding, storing, helpers, VIP, rust and mystery prizes.
func _act_more(g: GameState, dice: RandomNumberGenerator, action: String, any: Dictionary, tile: Vector2i) -> void:
	var uid := int(any.get("uid", -1))
	match action:
		"craft":
			if not any.is_empty():
				var recipes := g.crafting.recipes_of(str(any["id"]))
				if not recipes.is_empty():
					g.crafting.buy_missing_and_craft(uid, recipes[dice.randi_range(0, recipes.size() - 1)].id)
				g.crafting.finish_crafts(uid)
				g.crafting.add_star(uid, dice.randf() < 0.5)
		"feed":
			if not any.is_empty():
				g.nurture.feed(uid)
				g.nurture.help_young(uid)
				g.raising.pour(uid)
		"store":
			if not any.is_empty():
				g.storage.store_object(uid)
		"unstore":
			if not g.storage.stored.is_empty():
				g.storage.place_from_storage(dice.randi_range(0, g.storage.stored.size() - 1), tile.x, tile.y)
		"helper":
			g.farmhands = maxi(g.farmhands, 1)
			g.arborists = maxi(g.arborists, 1)
			g.gardeners = maxi(g.gardeners, 1)
			var kinds: Array = GameState.HELPERS.keys()
			g.helpers.use_helper(kinds[dice.randi_range(0, kinds.size() - 1)])
		"vip":
			if dice.randf() < 0.5:
				g.vip.buy_week()
			else:
				g.vip.buy_points(dice.randi_range(1, 20))
		"repair":
			if not any.is_empty():
				g.rust.repair(str(any["id"]))
		"mystery":
			if dice.randf() < 0.5:
				g.mystery.buy_mystery_box()
			else:
				var colours: Array = g.mystery.egg_data["colours"].keys()
				var colour: String = colours[dice.randi_range(0, colours.size() - 1)]
				g.mystery.mystery_eggs[colour] = int(g.mystery.mystery_eggs.get(colour, 0)) + 1
				g.mystery.open_mystery_egg(colour)


## What is wrong with the farm, or "" when nothing is.
func _broken(g: GameState) -> String:
	if g.coins < 0 or g.gems < 0 or g.xp < 0:
		return "negative coins, gems or xp (%d, %d, %d)" % [g.coins, g.gems, g.xp]
	if g.plots.size() != GameState.MAX_SIZE * GameState.MAX_SIZE:
		return "the plot list changed size (%d)" % g.plots.size()
	var seen := {}
	var tiles := {}
	for o in g.objects:
		var uid := int(o["uid"])
		if seen.has(uid):
			return "uid %d is on the farm twice" % uid
		seen[uid] = true
		var fp := g.footprint(o["id"])
		for r in range(int(o["row"]), int(o["row"]) + fp.y):
			for c in range(int(o["col"]), int(o["col"]) + fp.x):
				if not g.in_farm(r, c):
					return "%s (uid %d) stands outside the farm at %d,%d" % [o["id"], uid, r, c]
				var i := g.index_of(r, c)
				if tiles.has(i):
					return "%s (uid %d) overlaps uid %d at %d,%d" % [o["id"], uid, tiles[i], r, c]
				tiles[i] = uid
				if not g.is_occupied(i):
					return "%s (uid %d) stands on %d,%d which is not marked occupied" % [o["id"], uid, r, c]
				if g.plots[i].get("state", "grass") == "planted":
					return "%s (uid %d) stands on a planted plot at %d,%d" % [o["id"], uid, r, c]
	for r in g.farm_size:
		for c in g.farm_size:
			var i := g.index_of(r, c)
			if g.is_occupied(i) and not tiles.has(i):
				return "tile %d,%d is marked occupied but nothing stands there" % [r, c]
	for uid: int in seen:
		if g.next_uid <= uid:
			return "next_uid %d would repeat uid %d" % [g.next_uid, uid]
	for system in g.systems:   # no system holds a negative count (bushels, goods, feed, eggs, points, fuel...)
		var saved := {}
		system.save_to(saved)
		var negative := _negative(saved, system.get_script().get_global_name())
		if negative != "":
			return negative
	return ""


## The first negative number in a system's saved fields, or "". Times, clock offsets and SIGNED may be anything.
func _negative(value: Variant, path: String) -> String:
	if value is Dictionary or value is Array:
		for k: Variant in (value.keys() if value is Dictionary else range(value.size())):
			if str(k).ends_with("_at") or str(k).contains("until") or str(k).contains("offset") or str(k) in SIGNED:
				continue
			var found := _negative(value[k], "%s.%s" % [path, str(k)])
			if found != "":
				return found
	elif (value is int or value is float) and value < 0:
		return "%s is negative (%s)" % [path, str(value)]
	return ""


## Saves the farm and loads it into a new game: the same things must be standing in the same places.
func _round_trip(g: GameState, seed_value: int) -> String:
	var path := "user://test_fuzz_%d.json" % seed_value
	g.save_path = path
	g.saving_enabled = true
	g.save_game()
	g.saving_enabled = false
	var h := GameState.new()
	h.save_path = path
	add_child(h)
	h.saving_enabled = false
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + GameState.BACKUP_SUFFIX)
	var out := ""
	if h.coins != g.coins or h.gems != g.gems or h.xp != g.xp or h.farm_size != g.farm_size:
		out = "coins, gems, xp or farm size came back different"
	elif h.objects.size() != g.objects.size():
		out = "%d objects came back as %d" % [g.objects.size(), h.objects.size()]
	else:
		for o in g.objects:
			var back := h.object_by_uid(int(o["uid"]))
			if back.is_empty() or back["id"] != o["id"] or int(back["row"]) != int(o["row"]) \
					or int(back["col"]) != int(o["col"]):
				out = "uid %d (%s) came back changed or missing" % [int(o["uid"]), o["id"]]
				break
	if out == "":
		out = _broken(h)
	_done(h)
	return out
