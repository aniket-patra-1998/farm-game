extends Node
## Automated tests for the game rules.
##
## In Godot: open tests/run_tests.tscn and press F6 (Run Current Scene). Results print in the Output panel.
## From a terminal or CI: godot --headless --path . res://tests/run_tests.tscn   (exit code 1 if anything fails)
##
## Every test builds its own throwaway farm with saving turned off, so your real save is never touched.

var _failures: Array[String] = []
var _current := ""
var _checks := 0


func _ready() -> void:
	var names: Array[String] = []
	for m in get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_"):
			names.append(n)
	names.sort()
	var failed_tests := 0
	for n in names:
		_current = n
		var before := _failures.size()
		call(n)
		var ok := _failures.size() == before
		if not ok:
			failed_tests += 1
		print("%s  %s" % ["PASS" if ok else "FAIL", n])
	# Tests that need real frames (input, rendering) run after, one at a time.
	_current = "test_37_tap_farms_and_drag_moves_the_view"
	var before_async := _failures.size()
	await _frames_test_tap_and_drag()
	var ok_async := _failures.size() == before_async
	if not ok_async:
		failed_tests += 1
	print("%s  %s" % ["PASS" if ok_async else "FAIL", _current])
	names.append(_current)
	print("")
	for f in _failures:
		print("  - " + f)
	print("%d tests, %d checks, %d failed" % [names.size(), _checks, failed_tests])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if failed_tests > 0 else 0)


# ---------------------------------------------------------------- helpers

func _check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_current, what])


func _eq(actual: Variant, expected: Variant, what: String) -> void:
	_check(actual == expected, "%s (expected %s, got %s)" % [what, str(expected), str(actual)])


## A fresh farm: saving off, drops off, fixed random seed.
func _farm(drops := false) -> GameState:
	var g := GameState.new()
	g.saving_enabled = false
	add_child(g)
	g.drops_enabled = drops
	g.rng.seed = 12345
	return g


func _done(g: GameState) -> void:
	g.queue_free()


## A tile that is open grass on a new farm (the farmhouse and barn sit along the back edge).
func _free(g: GameState) -> int:
	return g.index_of(11, 11)


func _skip(g: GameState, seconds: int) -> void:
	g.debug_time_offset += seconds


## Plows (if needed), plants and fast-forwards one crop to ripe, then harvests it.
func _grow_and_harvest(g: GameState, i: int, crop_id: String) -> Dictionary:
	if g.phase(i) != GameState.Phase.PLOWED:
		g.plow(i)
	g.plant(i, crop_id)
	_skip(g, int(g.crops[crop_id]["grow_seconds"]))
	return g.harvest(i)


# ---------------------------------------------------------------- core farming

func test_01_new_farm_starts_like_the_classic_opening() -> void:
	var g := _farm()
	_eq(g.coins, GameState.START_COINS, "starting coins")
	_eq(g.gems, GameState.START_GEMS, "starting gems")
	_eq(g.farm_size, GameState.START_SIZE, "starting size")
	_eq(g.phase(g.index_of(5, 4)), GameState.Phase.RIPE, "starter strawberries ripe")
	_eq(g.phase(g.index_of(5, 5)), GameState.Phase.RIPE, "starter wheat ripe")
	_eq(g.phase(g.index_of(6, 4)), GameState.Phase.GROWING, "half-grown plot growing")
	_eq(g.phase(g.index_of(7, 4)), GameState.Phase.PLOWED, "plowed starter plot")
	_eq(g.tutorial_step, GameState.Tutorial.HARVEST, "tutorial starts at harvest")
	var ids: Array = g.objects.map(func(o): return o["id"])
	for want in ["farmhouse", "barn", "mailbox", "farm_stand", "cow"]:
		_check(ids.has(want), "starter farm has a %s" % want)
	_eq(ids.count("chicken"), 2, "two starter chickens")
	_check(g.barn().get("broken", false), "the barn starts broken")
	_check(not g.is_occupied(g.index_of(5, 4)), "no object on the starter crops")
	_done(g)


func test_02_plow_plant_grow_wither() -> void:
	var g := _farm()
	var i := _free(g)
	_check(g.plow(i), "plow grass")
	_eq(g.coins, GameState.START_COINS - GameState.PLOW_COST, "plow cost")
	_check(not g.plow(i), "can't plow twice")
	_check(not g.plant(i, "cotton"), "locked crop refused at level 1")
	_check(g.plant(i, "strawberries"), "plant strawberries")
	_eq(g.phase(i), GameState.Phase.GROWING, "growing after planting")
	_skip(g, 4 * 3600)
	_eq(g.phase(i), GameState.Phase.RIPE, "ripe after 4 h")
	_skip(g, 4 * 3600)
	_eq(g.phase(i), GameState.Phase.WITHERED, "withered after the ripe window")
	_check(g.harvest(i).is_empty(), "withered crops can't be harvested")
	_done(g)


func test_03_harvest_pays_and_counts_mastery() -> void:
	var g := _farm()
	var i := _free(g)
	var before := g.coins
	var result := _grow_and_harvest(g, i, "strawberries")
	_eq(result["coins"], 35, "strawberry harvest coins")
	_eq(g.coins, before - GameState.PLOW_COST - 10 + 35, "coin balance after the cycle")
	_eq(g.phase(i), GameState.Phase.PLOWED, "plot is plowed again after harvest")
	_eq(int(g.mastery.get("strawberries", 0)), 1, "mastery count")
	_done(g)


func test_04_fertilizer_adds_twenty_percent_and_double_mastery() -> void:
	var g := _farm()
	var i := _free(g)
	g.plow(i)
	_check(not g.fertilize(i), "can't fertilize an empty plot")
	g.plant(i, "strawberries")
	_check(g.fertilize(i), "fertilize a growing crop")
	_check(not g.fertilize(i), "can't fertilize twice")
	_skip(g, 4 * 3600)
	var result := g.harvest(i)
	_eq(result["coins"], 42, "35 coins + 20%")
	_eq(int(g.mastery.get("strawberries", 0)), 2, "fertilized harvest counts double")
	_done(g)


func test_05_unwither_revives_withered_crops() -> void:
	var g := _farm()
	var i := _free(g)
	g.plow(i)
	g.plant(i, "strawberries")
	_skip(g, 9 * 3600)
	_eq(g.phase(i), GameState.Phase.WITHERED, "withered")
	var held := g.unwithers
	_check(g.use_unwither(), "use unwither")
	_eq(g.phase(i), GameState.Phase.RIPE, "ripe again")
	_eq(g.unwithers, held - 1, "one unwither used")
	_done(g)


# ---------------------------------------------------------------- progression

func test_06_level_up_pays_coins_and_a_gem() -> void:
	var g := _farm()
	var coins := g.coins
	var gems := g.gems
	g.add_xp(g.xp_for_level(2))
	_eq(g.level(), 2, "reached level 2")
	_eq(g.coins, coins + g.level_reward(2), "level reward coins")
	_eq(g.gems, gems + GameState.GEMS_PER_LEVEL, "level reward gem")
	_done(g)


func test_07_ribbons_award_tiers() -> void:
	var g := _farm()
	g.coins = 10000
	for r in range(8, 12):
		for c in range(7, 12):
			g.plow(g.index_of(r, c))
	_eq(g.stat("plowed"), 20, "plowed counter")
	_eq(int(g.ribbon_tiers.get("plow_pro", 0)), 1, "Plow Pro yellow ribbon at 20 plots")
	_done(g)


# ---------------------------------------------------------------- surprises and collections

func test_08_pity_guarantees_a_collectible_within_30_harvests() -> void:
	var g := _farm(true)
	g.coins = 100000
	var found := 0
	var i := _free(g)
	for k in GameState.COLLECTIBLE_PITY:
		var r := _grow_and_harvest(g, i, "strawberries")
		if r.get("drop", "") == "collectible":
			found += 1
	_check(found >= 1, "at least one collectible in %d harvests" % GameState.COLLECTIBLE_PITY)
	_done(g)


func test_09_collection_trade_in() -> void:
	var g := _farm()
	var coll: Dictionary = g.collections[0]
	_check(not g.can_trade_in(coll), "empty set can't be traded")
	for it in coll["items"]:
		g.owned[it["id"]] = 1
	# Isolate the trade-in: no first-ribbon reward, and no level-up from its XP.
	g.ribbon_tiers["collector"] = 4
	g.xp = g.xp_for_level(10)
	var coins := g.coins
	var unwithers := g.unwithers
	_check(g.trade_in(coll["id"]), "full set trades in")
	_eq(g.coins, coins + int(coll["reward_coins"]), "trade-in coins")
	_eq(g.unwithers, unwithers + 1, "trade-in gives an unwither")
	_eq(int(g.owned[coll["items"][0]["id"]]), 0, "items used up")
	_done(g)


# ---------------------------------------------------------------- placement and buildings

func test_10_place_and_move_objects() -> void:
	var g := _farm()
	_check(g.buy_and_place("chicken", 8, 8), "buy a chicken")
	_eq(g.coins, GameState.START_COINS - 120, "chicken price")
	_check(not g.can_place("chicken", 8, 8), "can't stack on another object")
	_check(not g.can_place("chicken", 1, 1), "can't place on the farmhouse")
	_check(not g.can_place("chicken", 5, 4), "can't place on planted crops")
	_check(not g.can_place("chicken", 12, 0), "can't place off the farm")
	var uid := int(g.object_at(g.index_of(8, 8))["uid"])
	_check(g.move_object(uid, 11, 11), "move it")
	_check(g.object_at(g.index_of(8, 8)).is_empty(), "old tile is free")
	_eq(int(g.object_at(g.index_of(11, 11))["uid"]), uid, "new tile holds it")
	_check(not g.plow(g.index_of(11, 11)), "can't plow under an object")
	_done(g)


func test_11_shelter_fill_collect_upgrade() -> void:
	var g := _farm()
	g.coins = 100000
	_check(not g.buy_and_place("chicken_coop", 8, 8), "coop locked at level 1")
	g.add_xp(g.xp_for_level(4))
	_check(g.buy_and_place("chicken_coop", 8, 8), "buy coop at level 4")
	for c in 3:
		_check(g.buy_and_place("chicken", 11, c), "buy chicken %d" % c)
	var coop := g.object_at(g.index_of(8, 8))
	var uid := int(coop["uid"])
	_eq(g.fill_building(uid), 5, "3 bought + 2 starter chickens move in")
	_eq(g.inside_total(coop), 5, "coop holds five")
	_eq(g.loose_matching(coop), 0, "no loose chickens left")
	_check(g.collect(uid).is_empty(), "not ready straight away")
	_skip(g, 86400)
	_eq(g.collect(uid)["coins"], 200, "5 chickens x 40 coins")
	_check(not g.upgrade_building(uid), "can't expand without materials")
	for m in GameState.BASIC_PARTS:
		g.parts[m] = 10
	_check(g.upgrade_building(uid), "expand with 10 bricks, nails and boards")
	_eq(g.capacity(coop), 40, "Big Chicken Coop holds 40")
	_eq(g.size_name(coop), "Big Chicken Coop", "named like FarmVille")
	_eq(int(g.parts["bricks"]), 0, "materials used up")
	_done(g)


# ---------------------------------------------------------------- land

func test_12_expand_with_coins_needs_level_gems_do_not() -> void:
	var g := _farm()
	g.coins = 100000
	_check(not g.expand(false), "coins need level 5")
	g.gems = 20
	_check(g.expand(true), "gems expand at level 1")
	_eq(g.farm_size, 14, "farm grew to 14")
	_eq(g.gems, 10, "10 gems spent")
	_check(g.can_place("chicken", 13, 13), "new land is usable")
	_done(g)


func test_13_old_12x12_saves_migrate() -> void:
	var g := _farm()
	var old: Array = []
	for k in 144:
		old.append({"state": "grass"})
	old[5 * 12 + 7] = {"state": "plowed"}
	var wide := g._widen_old_grid(old)
	_eq(wide.size(), GameState.MAX_SIZE * GameState.MAX_SIZE, "widened size")
	_eq(wide[g.index_of(5, 7)]["state"], "plowed", "plot keeps its row and column")
	_done(g)


# ---------------------------------------------------------------- bees and strays

func test_14_bees_only_join_a_hive_with_a_queen() -> void:
	var g := _farm(true)
	var hive := _built_hive(g)
	g.queen_bees = 0
	var queens_found := 0
	for k in 200:
		if g._flower_harvest_bees() == "A Queen Bee!":
			queens_found += 1
			g.queen_bees = 0 # keep her out of the hive for this part
	_eq(g.inside_total(hive), 0, "no bees join a hive without a queen")
	_check(queens_found <= 6, "Queen Bees are rare (%d in 200 flower harvests)" % queens_found)
	g.queen_bees = 1
	_check(g.add_queen(int(hive["uid"])), "the queen moves in")
	_eq(g.queen_bees, 0, "the held queen was used")
	for k in 200:
		g._flower_harvest_bees()
	var bees := g.inside_total(hive)
	_check(bees >= 30 and bees <= 70, "about a quarter of flower harvests bring a bee (%d of 200)" % bees)
	_skip(g, 86400)
	var drops := g.drops_enabled
	g.drops_enabled = false
	_eq(int(g.collect(int(hive["uid"]))["coins"]), 6 * bees, "honey pays 6 coins a bee")
	g.drops_enabled = drops
	# Real flower harvests report the bee.
	g.xp = maxi(g.xp, g.xp_for_level(4))
	var seen := false
	for k in 30:
		var r := _grow_and_harvest(g, _free(g), "lilac")
		if str(r.get("bee", "")) != "":
			seen = true
	_check(seen, "a lilac harvest brought a bee")
	_done(g)


func test_15_strays_arrive_get_adopted_or_leave() -> void:
	var g := _farm()
	g.next_stray_at = 0
	g.check_strays()
	var strays := g.objects.filter(func(o): return o.get("stray", false))
	_eq(strays.size(), 1, "one stray arrives")
	var s: Dictionary = strays[0]
	_check(not g.is_ready(s), "strays don't produce")
	g.ribbon_tiers["animal_lover"] = 4 # isolate the adoption XP from the first-ribbon reward
	var xp := g.xp
	_check(g.adopt_stray(int(s["uid"])), "adopt")
	_check(not s.get("stray", false), "no longer a stray")
	_eq(g.xp, xp + GameState.STRAY_ADOPT_XP, "adoption XP")

	g.next_stray_at = 0
	g.check_strays()
	_eq(g.objects.filter(func(o): return o.get("stray", false)).size(), 1, "another stray")
	g.next_stray_at = g.now() + 999999 # stop new arrivals
	_skip(g, GameState.STRAY_STAYS + 1)
	g.check_strays()
	_eq(g.objects.filter(func(o): return o.get("stray", false)).size(), 0, "unadopted stray left")
	_done(g)


# ---------------------------------------------------------------- saving

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
	g.barn().erase("broken")
	g.store_object(int(g.object_at(g.index_of(4, 0))["uid"])) # the mailbox
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
	_check(h.barn_repaired(), "barn repair restored")
	_eq(h.stored.size(), 1, "stored items restored")
	_eq(h.stored[0]["id"], "mailbox", "the stored item is the mailbox")
	h.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------------------------------------------------------------- data files

func test_17_data_files_are_consistent() -> void:
	var g := _farm()
	_check(g.crops.size() >= 12, "crops loaded")
	_check(g.items.size() >= 16, "items loaded")
	for coll in g.collections:
		_eq(coll["items"].size(), 5, "%s has 5 items" % coll["name"])
		for crop_id in coll.get("crops", []):
			_check(g.crops.has(crop_id), "%s lists a real crop (%s)" % [coll["name"], crop_id])
	for id in g.items:
		var it: Dictionary = g.items[id]
		if it["kind"] == "building":
			_check(it.has("expand_materials") or (it["levels"] as Array).size() == 1, "%s says what expanding costs" % id)
			for m in it.get("expand_materials", {}):
				_check(GameState.PARTS.has(m), "%s expands with a real material (%s)" % [id, m])
			for m in it.get("build_materials", {}):
				_check(GameState.PARTS.has(m), "%s is built with a real material (%s)" % [id, m])
			for held in it.get("holds", []) + it.get("one_each", []):
				_check(g.items.has(held), "%s holds a real item (%s)" % [id, held])
	var last := GameState.START_SIZE
	for step in g.expansion_steps:
		_check(int(step["size"]) > last, "expansion sizes grow")
		last = int(step["size"])
	_eq(last, GameState.MAX_SIZE, "last expansion reaches the max size")
	_done(g)


func test_18_drops_are_off_in_exact_value_tests() -> void:
	var g := _farm(false)
	var i := _free(g)
	for k in 50:
		var r := _grow_and_harvest(g, i, "strawberries")
		_eq(r["drop"], "", "no drops when disabled")
		if r["drop"] != "":
			break
	_done(g)


# ---------------------------------------------------------------- economy and balance

func test_19_every_crop_makes_a_profit() -> void:
	var g := _farm()
	for id in g.crop_order:
		var c: Dictionary = g.crops[id]
		var profit := int(c["sell_price"]) - int(c["seed_cost"]) - GameState.PLOW_COST
		_check(profit > 0, "%s profits after the plow (got %d)" % [id, profit])
		_check(int(c["xp"]) >= 1, "%s gives XP" % id)
		_check(int(c["grow_seconds"]) > 0, "%s has a grow time" % id)
	_done(g)


func test_20_slower_crops_pay_more_per_harvest() -> void:
	# A crop that takes longer must earn more than a quicker crop at its level or below,
	# or nobody would plant it.
	var g := _farm()
	for a_id in g.crop_order:
		for b_id in g.crop_order:
			var a: Dictionary = g.crops[a_id]
			var b: Dictionary = g.crops[b_id]
			if int(a["grow_seconds"]) > int(b["grow_seconds"]) and int(a["unlock_level"]) >= int(b["unlock_level"]):
				var pa := int(a["sell_price"]) - int(a["seed_cost"])
				var pb := int(b["sell_price"]) - int(b["seed_cost"])
				_check(pa > pb, "%s (slower) pays more than %s" % [a_id, b_id])
	_done(g)


func test_21_every_level_to_20_unlocks_something() -> void:
	var g := _farm()
	for lvl in range(1, 21):
		_check(not g.unlocks_at(lvl).is_empty() or lvl == 1, "level %d unlocks something" % lvl)
	var level_one := 0
	for id in g.crop_order:
		if int(g.crops[id]["unlock_level"]) == 1:
			level_one += 1
	_check(level_one >= 2, "a new farmer has at least 2 crops to choose from")
	_done(g)


func test_22_level_curve_rises_and_paces_the_beta() -> void:
	var g := _farm()
	for lvl in range(2, 60):
		_check(g.xp_for_level(lvl + 1) > g.xp_for_level(lvl), "level %d needs more XP than %d" % [lvl + 1, lvl])
	# Rough pace check: 60 plots of a 1-day crop, 3 XP per plot per day (plow + harvest).
	var days := float(g.xp_for_level(20)) / (60.0 * 3.0)
	_check(days >= 8.0 and days <= 16.0, "level 20 takes about two weeks (estimated %.1f days)" % days)
	_done(g)


func test_23_every_crop_and_item_has_art() -> void:
	var g := _farm()
	var shapes := ["berry", "grain", "root", "stalk", "flower", "fruit", "gourd", "spike", "fluff", "leafy"]
	for id in g.crop_order:
		_check(shapes.has(g.crops[id].get("shape", "")), "%s has a known shape" % id)
		_check(Color.html_is_valid(str(g.crops[id].get("color", ""))), "%s has a valid colour" % id)
	for id in g.items:
		_check(Color.html_is_valid(str(g.items[id].get("color", ""))), "%s has a valid colour" % id)
	_done(g)


func test_24_every_crop_belongs_to_a_collection() -> void:
	var g := _farm()
	for id in g.crop_order:
		_check(g.collection_of_crop.has(id), "%s can drop collectibles" % id)
	_done(g)


# ---------------------------------------------------------------- starter scenery, parts, barn, storage

func test_25_scenery_and_barn_never_produce() -> void:
	var g := _farm()
	_skip(g, 30 * 86400)
	for o in g.objects:
		var k := g.kind_of(o)
		if k == "decor" or k == "barn":
			_check(not g.is_ready(o), "%s never becomes ready" % o["id"])
			_check(g.collect(int(o["uid"])).is_empty(), "%s can't be collected" % o["id"])
	_done(g)


func test_26_parts_drop_from_harvests() -> void:
	var g := _farm(true)
	g.coins = 100000
	var i := _free(g)
	var found := 0
	for k in 200:
		var r := _grow_and_harvest(g, i, "strawberries")
		if r.get("part", "") != "":
			found += 1
	var held := 0
	for p in GameState.PARTS:
		held += int(g.parts[p])
	_eq(held, found, "every reported part was added")
	# 8% of 200 harvests is 16; allow a wide margin for randomness.
	_check(found >= 5 and found <= 35, "part rate near 8%% (got %d of 200)" % found)
	_done(g)


func test_27_no_parts_when_drops_are_off() -> void:
	var g := _farm(false)
	var i := _free(g)
	for k in 30:
		_eq(_grow_and_harvest(g, i, "strawberries").get("part", ""), "", "no part")
	_done(g)


func test_28_daily_gift_once_per_day() -> void:
	var g := _farm()
	g.check_daily_gift()
	_eq(g.stat("parts_found"), 0, "no gift on the first day")
	_skip(g, 86400)
	g.check_daily_gift()
	_eq(g.stat("parts_found"), GameState.DAILY_PARTS, "gift the next day")
	g.check_daily_gift()
	_eq(g.stat("parts_found"), GameState.DAILY_PARTS, "only once that day")
	_skip(g, 3 * 86400)
	g.check_daily_gift()
	_eq(g.stat("parts_found"), 2 * GameState.DAILY_PARTS, "one gift after a long break, not a pile")
	_done(g)


func test_29_barn_repair_needs_every_part() -> void:
	var g := _farm()
	_check(not g.can_repair_barn(), "can't repair with no parts")
	_check(not g.repair_barn(), "repair refused")
	var need := g.repair_needs()
	g.parts["bricks"] = int(need["bricks"])
	g.parts["nails"] = int(need["nails"])
	g.parts["boards"] = int(need["boards"]) - 1
	_check(not g.can_repair_barn(), "one board short")
	g.parts["boards"] = int(need["boards"]) + 2
	g.xp = g.xp_for_level(10) # keep the reward XP from triggering a level-up reward
	var coins := g.coins
	_check(g.repair_barn(), "repair with enough parts")
	_check(g.barn_repaired(), "barn is fixed")
	_eq(g.coins, coins + int(g.item_data("barn")["repair_coins"]), "repair reward coins")
	_eq(int(g.parts["boards"]), 2, "spare boards kept")
	_eq(int(g.parts["bricks"]), 0, "bricks used up")
	_check(not g.repair_barn(), "can't repair twice")
	_done(g)


func test_30_storage_put_away_and_bring_back() -> void:
	var g := _farm()
	var chicken := g.object_at(g.index_of(9, 2))
	_eq(chicken.get("id", ""), "chicken", "starter chicken in place")
	_check(not g.store_object(int(chicken["uid"])), "can't store while the barn is broken")
	g.barn().erase("broken")
	_check(not g.store_object(int(g.barn()["uid"])), "the barn can't store itself")
	_check(g.store_object(int(chicken["uid"])), "store the chicken")
	_check(g.object_at(g.index_of(9, 2)).is_empty(), "its tile is free")
	_eq(g.stored.size(), 1, "one item stored")
	_check(not g.place_from_storage(0, 1, 1), "can't place it on the farmhouse")
	_check(g.place_from_storage(0, 11, 11), "place it back out")
	_eq(g.stored.size(), 0, "storage empty again")
	_eq(g.object_at(g.index_of(11, 11)).get("id", ""), "chicken", "chicken is back")
	_check(not g.is_ready(g.object_at(g.index_of(11, 11))), "its timer restarted")
	_done(g)


func test_31_storage_limits() -> void:
	var g := _farm()
	g.barn().erase("broken")
	g.coins = 1000000
	g.add_xp(g.xp_for_level(4))
	_check(g.buy_and_place("chicken_coop", 8, 8), "coop placed")
	_check(not g.store_object(int(g.object_at(g.index_of(8, 8))["uid"])), "shelters can't be stored")
	g.next_stray_at = 0
	g.check_strays()
	var strays := 0
	for o in g.objects:
		if o.get("stray", false):
			strays += 1
			_check(not g.store_object(int(o["uid"])), "strays can't be stored")
	_eq(strays, 1, "a stray arrived to test with")
	for k in g.barn_capacity():
		g.stored.append({"uid": 9000 + k, "id": "chicken", "t": 0})
	_check(not g.store_object(int(g.object_at(g.index_of(9, 3))["uid"])), "a full barn refuses more")
	_done(g)


func test_32_new_trees_animals_and_birds_work() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(20)
	var row := 8
	var col := 7
	for id in ["plum_tree", "duck", "goose", "turkey", "llama", "coconut_tree"]:
		_check(g.buy_and_place(id, row, col), "buy and place %s" % id)
		var o := g.object_at(g.index_of(row, col))
		_skip(g, int(g.item_data(id)["cycle_seconds"]))
		_eq(g.collect(int(o["uid"]))["coins"], int(g.item_data(id)["payout"]), "%s pays its payout" % id)
		col += 1
		if col > 11:
			col = 7
			row += 1
	_done(g)


# ---------------------------------------------------------------- day and night

func test_33_day_and_night_follow_the_clock() -> void:
	_eq(DayCycle.darkness(12.0), 0.0, "noon is full daylight")
	_eq(DayCycle.darkness(0.0), 1.0, "midnight is full night")
	_eq(DayCycle.darkness(23.0), 1.0, "11 pm is night")
	var dawn := DayCycle.darkness(DayCycle.SUNRISE)
	_check(dawn > 0.0 and dawn < 1.0, "sunrise is part-way (got %.2f)" % dawn)
	_eq(DayCycle.phase_name(12.0), "midday", "noon label")
	_eq(DayCycle.phase_name(2.0), "night", "2 am label")
	_eq(DayCycle.phase_name(6.0), "dawn", "6 am label")
	_check(DayCycle.sun_progress(12.0) > 0.0 and DayCycle.sun_progress(12.0) < 1.0, "sun is up at noon")
	_eq(DayCycle.sun_progress(23.0), -1.0, "sun is down at night")
	_check(DayCycle.moon_progress(23.0) >= 0.0, "moon is up at night")
	_eq(DayCycle.moon_progress(12.0), -1.0, "moon is down at noon")


func test_34_day_colours_change_smoothly_and_wrap_at_midnight() -> void:
	var before := DayCycle.sample(23.99)
	var after := DayCycle.sample(0.0)
	_check((before["top"] as Color).is_equal_approx(after["top"]), "sky matches across midnight")
	# No jumps: a minute apart the light changes by only a little, all day long.
	var worst := 0.0
	for m in range(0, 24 * 60, 5):
		var a: Color = DayCycle.sample(m / 60.0)["light"]
		var b: Color = DayCycle.sample((m + 1) / 60.0)["light"]
		worst = maxf(worst, absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b))
	_check(worst < 0.05, "light never jumps between minutes (worst %.3f)" % worst)
	var noon: Color = DayCycle.sample(12.0)["light"]
	var night: Color = DayCycle.sample(1.0)["light"]
	_check(noon.get_luminance() > night.get_luminance() + 0.2, "noon is clearly brighter than night")


func test_35_local_time_and_clock_text() -> void:
	_eq(DayCycle.local_hour(0, 0), 0.0, "unix 0 is midnight UTC")
	_eq(DayCycle.local_hour(0, 330), 5.5, "India is 5 h 30 m ahead")
	_eq(DayCycle.local_hour(3600, -300), 20.0, "behind UTC wraps to the previous evening")
	_eq(DayCycle.clock_text(19.7), "7:42 pm", "evening clock")
	_eq(DayCycle.clock_text(0.25), "12:15 am", "just after midnight")
	_eq(DayCycle.clock_text(12.0), "12:00 pm", "noon")


func test_36_the_whole_game_scene_loads() -> void:
	# Catches broken scripts anywhere in the game, not just the rules.
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		return
	var main := packed.instantiate()
	_check(main != null, "main scene instantiates")
	if main == null:
		return
	add_child(main)
	_check(main.get("grid") != null, "farm grid created")
	_check(main.get("hud") != null, "HUD created")
	_check(main.get("sky") != null, "sky created")
	main.free() # free now, so the next test doesn't share the screen with this one



# ---------------------------------------------------------------- touch input

## The farm grid and the main scene (camera), in the order Godot delivers input to them.
var _input_targets: Array = []


## Hands a touch straight to the farm and camera handlers. (Faking touches through the
## OS layer on a screenless test machine adds emulated mouse moves a phone never sends.)
func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos
	ev.pressed = pressed
	for t in _input_targets:
		t._unhandled_input(ev)
	await get_tree().process_frame


func _drag(pos: Vector2, relative: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = pos
	ev.relative = relative
	for t in _input_targets:
		t._unhandled_input(ev)
	await get_tree().process_frame


func _screen_pos(grid: FarmGrid, i: int) -> Vector2:
	return get_viewport().get_canvas_transform() * grid.to_global(grid.center_of(i))


## Runs after the plain tests (see _ready): it needs real frames for input to arrive.
func _frames_test_tap_and_drag() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam: Camera2D = main.get("camera")
	var grid: FarmGrid = main.get("grid")
	_input_targets = [grid, main] # children get input before their parent
	cam.force_update_scroll()
	var view := get_viewport().get_visible_rect().size

	# A tap on grass plows it.
	var i := Game.index_of(11, 11)
	_eq(Game.phase(i), GameState.Phase.GRASS, "tile starts as grass")
	var tap_at := _screen_pos(grid, i)
	_check(grid._on_farm_area(tap_at), "the tile is on screen (view %s, tile at %s)" % [str(view), str(tap_at)])
	await _touch(tap_at, true)
	await _touch(tap_at, false)
	_eq(Game.phase(i), GameState.Phase.PLOWED, "a tap plows")

	# A drag moves the view and leaves the plot under the finger alone.
	main.call("_zoom_at", view / 2.0, 2.0)
	await get_tree().process_frame
	cam.force_update_scroll()
	var start := view / 2.0
	var under := grid.index_at(grid.to_local(get_viewport().get_canvas_transform().affine_inverse() * start))
	var before_plot: Dictionary = Game.plots[under].duplicate() if under >= 0 else {}
	var objects_before := Game.objects.size()
	var cam_before := cam.position
	await _touch(start, true)
	for k in range(1, 11):
		await _drag(start + Vector2(20 * k, 0), Vector2(20, 0))
	await _touch(start + Vector2(200, 0), false)
	if under >= 0:
		_eq(Game.plots[under], before_plot, "the plot under the drag is unchanged")
	_eq(Game.objects.size(), objects_before, "nothing placed or removed by a drag")
	_check(not cam.position.is_equal_approx(cam_before), "the drag moved the view")

	# A tiny wobble while tapping still counts as a tap.
	var k2 := Game.index_of(11, 10)
	cam.position = cam_before
	main.call("_fit_camera")
	await get_tree().process_frame
	cam.force_update_scroll()
	var wobble_at := _screen_pos(grid, k2)
	await _touch(wobble_at, true)
	await _drag(wobble_at + Vector2(4, 3), Vector2(4, 3))
	await _touch(wobble_at + Vector2(4, 3), false)
	_eq(Game.phase(k2), GameState.Phase.PLOWED, "a slightly shaky tap still plows")
	main.free()




# ---------------------------------------------------------------- buildings, the FarmVille way

func _count(g: GameState, item_id: String) -> int:
	var n := 0
	for o in g.objects:
		if o["id"] == item_id and not o.get("stray", false):
			n += 1
	return n


func _all_materials(g: GameState, n: int) -> void:
	for m in GameState.PARTS:
		g.parts[m] = n


func test_38_stable_is_built_from_a_frame_with_materials() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(12)
	_check(g.buy_and_place("horse_stable", 8, 8), "stable frame placed")
	var st := g.object_at(g.index_of(8, 8))
	var uid := int(st["uid"])
	_check(g.under_construction(st), "it arrives as a frame")
	_check(not g.is_ready(st), "a frame never produces")
	g.place_somewhere("horse")
	_eq(g.fill_building(uid), 0, "can't move horses into a frame")
	_eq(g.add_materials(uid), 0, "nothing to add with no materials")
	g.parts["bricks"] = 4
	_eq(g.add_materials(uid), 4, "adds the 4 bricks held")
	_eq(int(g.construction_needs(st)["bricks"]), 6, "6 bricks still missing")
	_all_materials(g, 10)
	g.add_materials(uid)
	_check(not g.under_construction(st), "finished once every material is in")
	_eq(int(g.parts["harnesses"]), 0, "harnesses used")
	_eq(int(g.parts["bricks"]), 4, "spare bricks kept (4 were already in)")
	_eq(g.fill_building(uid), 1, "the horse moves in")
	_done(g)


func test_39_stable_horses_daily_stallion_brings_foals() -> void:
	var g := _farm(true)
	g.coins = 1000000
	g.xp = g.xp_for_level(12)
	g.buy_and_place("horse_stable", 8, 8)
	var st := g.object_at(g.index_of(8, 8))
	var uid := int(st["uid"])
	_all_materials(g, 10)
	g.add_materials(uid)
	for k in 4:
		g.place_somewhere("horse")
	_eq(g.cycle_of(g.objects.filter(func(o): return o["id"] == "horse")[0]), 3 * 86400, "a loose horse takes 3 days")
	_eq(g.cycle_of(st), 86400, "horses in the stable are ready daily")
	g.fill_building(uid)
	# No stallion: no foals, ever.
	for d in 20:
		_skip(g, 86400)
		g.collect(uid)
	_eq(_count(g, "foal"), 0, "no stallion, no foals")
	# With a stallion: foals arrive, and he takes no space.
	g.place_somewhere("stallion")
	var inside_before := g.inside_total(st)
	g.fill_building(uid)
	_check(g.has_inside(st, "stallion"), "stallion moved in")
	_eq(g.inside_total(st), inside_before, "the stallion doesn't take a space")
	g.place_somewhere("stallion")
	g.fill_building(uid)
	_eq(int(st["inside"]["stallion"]), 1, "only one stallion lives inside")
	for d in 40:
		_skip(g, 86400)
		g.collect(uid)
	_check(_count(g, "foal") > 0, "foals were born (%d)" % _count(g, "foal"))
	_check(g.farmhands + g.arborists > 0, "harvests gave farmhands or arborists")
	_done(g)


func test_40_dairy_bull_brings_calves_and_fertilizer() -> void:
	var g := _farm(true)
	g.coins = 1000000
	g.xp = g.xp_for_level(6)
	_check(g.buy_and_place("cow_shed", 8, 8), "Dairy Farm bought outright, no frame")
	var dairy := g.object_at(g.index_of(8, 8))
	var uid := int(dairy["uid"])
	_check(not g.under_construction(dairy), "no construction needed")
	for k in 3:
		g.place_somewhere("cow")
	g.place_somewhere("bull")
	g.fill_building(uid)
	_check(g.has_inside(dairy, "bull"), "the bull lives inside")
	_eq(g.inside_total(dairy), 4, "4 cows take spaces; the bull doesn't")
	for d in 40:
		_skip(g, 86400)
		g.collect(uid)
	_check(_count(g, "calf") > 0, "calves were born (%d)" % _count(g, "calf"))
	_check(g.fertilizer_bags > 0, "harvests left fertilizer")
	# A fertilizer bag is used before coins.
	var i := _free(g)
	if g.is_occupied(i):
		i = g.index_of(7, 4)
	if g.phase(i) != GameState.Phase.PLOWED:
		g.plow(i)
	g.plant(i, "strawberries")
	var coins := g.coins
	var bags := g.fertilizer_bags
	_check(g.fertilize(i), "fertilize")
	_eq(g.coins, coins, "no coins spent while a bag is held")
	_eq(g.fertilizer_bags, bags - 1, "a bag was used")
	_done(g)


func test_41_nursery_raises_babies_into_adults() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(8)
	_check(g.buy_and_place("nursery_barn", 8, 8), "nursery frame placed")
	var n := g.object_at(g.index_of(8, 8))
	var uid := int(n["uid"])
	_all_materials(g, 10)
	g.add_materials(uid)
	_check(not g.under_construction(n), "nursery finished")
	g.place_somewhere("calf")
	g.place_somewhere("foal")
	_eq(g.fill_building(uid), 2, "a calf and a foal move in")
	var cows := _count(g, "cow")
	var horses := _count(g, "horse")
	for d in 3:
		_skip(g, 86400)
		g.collect(uid)
	_eq(_count(g, "cow"), cows, "not grown after 3 days")
	_skip(g, 86400)
	g.collect(uid)
	_eq(_count(g, "cow"), cows + 1, "the calf grew into a cow")
	_eq(_count(g, "horse"), horses + 1, "the foal grew into a horse")
	_eq(g.inside_total(n), 0, "the babies left the nursery")
	# Outside the nursery, babies never grow.
	g.place_somewhere("calf")
	for d in 10:
		_skip(g, 86400)
	_eq(_count(g, "calf"), 1, "a calf outside stays a calf")
	_done(g)


func test_42_coop_mystery_eggs_follow_breeds() -> void:
	var g := _farm(true)
	g.coins = 1000000
	g.xp = g.xp_for_level(4)
	g.buy_and_place("chicken_coop", 8, 8)
	var coop := g.object_at(g.index_of(8, 8))
	var uid := int(coop["uid"])
	coop["level"] = 3
	coop["inside"] = {"chicken": 40, "brown_chicken": 20}
	coop["t"] = g.now()
	for d in 40:
		_skip(g, 86400)
		g.collect(uid)
	var total := 0
	for colour in g.mystery_eggs:
		total += int(g.mystery_eggs[colour])
		_check(colour == "white" or colour == "brown", "egg colours match the breeds (got %s)" % colour)
	_check(total >= 4, "60 chickens find eggs regularly (%d in 40 days)" % total)
	var colour: String = "white" if int(g.mystery_eggs.get("white", 0)) > 0 else "brown"
	var before := int(g.mystery_eggs[colour])
	var prize := g.open_mystery_egg(colour)
	_check(prize != "", "opening an egg gives a prize (%s)" % prize)
	_eq(int(g.mystery_eggs[colour]), before - 1, "the egg is used up")
	_eq(g.open_mystery_egg("golden"), "", "can't open an egg you don't have")
	_done(g)


func test_43_expansions_cost_materials_and_follow_farmville_sizes() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(12)
	g.buy_and_place("horse_stable", 8, 8)
	var st := g.object_at(g.index_of(8, 8))
	var uid := int(st["uid"])
	_all_materials(g, 1000)
	g.add_materials(uid)
	var sizes: Array[int] = [g.capacity(st)]
	while g.upgrade_building(uid):
		sizes.append(g.capacity(st))
	_eq(sizes, [20, 25, 30, 35, 40] as Array[int], "stable grows 20 to 40 in steps of 5")
	_check(not g.can_expand(st), "no expansion past full size")
	_eq(g.cycle_of(st), 86400, "expanding doesn't change timing")
	var coop_sizes: Array = (g.item_data("chicken_coop")["levels"] as Array).map(func(v): return int(v))
	_eq(coop_sizes, [20, 40, 60], "Chicken Coop, Big, Huge: 20, 40, 60")
	_done(g)


func test_44_specific_materials_only_drop_for_buildings_you_own() -> void:
	var g := _farm()
	var pool := g.wanted_parts()
	_check(not pool.has("harnesses"), "no harnesses before owning a stable")
	_check(not pool.has("bottles"), "no bottles before owning a nursery")
	g.coins = 1000000
	g.xp = g.xp_for_level(12)
	g.buy_and_place("horse_stable", 8, 8)
	pool = g.wanted_parts()
	_check(pool.has("harnesses") and pool.has("horseshoes"), "stable materials drop once you own the frame")
	_check(not pool.has("smokers"), "beehive materials still don't")
	_done(g)


func test_45_gem_breeds_and_helpers() -> void:
	var g := _farm()
	g.xp = g.xp_for_level(5)
	var coins := g.coins
	g.gems = 5
	_check(g.buy_and_place("brown_chicken", 8, 8), "brown chicken bought with gems")
	_eq(g.gems, 0, "5 gems spent")
	_eq(g.coins, coins, "no coins spent")
	_check(not g.buy_and_place("brown_chicken", 8, 9), "no gems left for another")
	# A farmhand collects every ready animal at once.
	_skip(g, 86400)
	g.farmhands = 1
	var collected := g.use_helper("animal")
	_check(collected >= 4, "farmhand collected every animal (%d)" % collected)
	_eq(g.farmhands, 0, "farmhand used")
	for o in g.objects:
		if g.kind_of(o) == "animal":
			_check(not g.is_ready(o), "%s collected" % o["id"])
	_done(g)


func test_46_bull_and_stallion_only_wander_in_with_their_building() -> void:
	var g := _farm()
	g.xp = g.xp_for_level(20)
	var seen := {}
	for k in 300:
		if g._spawn_stray():
			var s: Dictionary = g.objects[-1]
			seen[s["id"]] = true
			g.objects.pop_back()
			g._rebuild_occupancy()
	_check(not seen.has("bull") and not seen.has("stallion"), "no bull or stallion without their buildings")
	g.coins = 10000000
	g.buy_and_place("cow_shed", 8, 8)
	seen = {}
	for k in 300:
		if g._spawn_stray():
			seen[g.objects[-1]["id"]] = true
			g.objects.pop_back()
			g._rebuild_occupancy()
	_check(seen.has("bull"), "a lonely bull can wander in once you own a Dairy Farm")
	_check(not seen.has("stallion"), "still no stallion without a stable")
	_done(g)


# ---------------------------------------------------------------- beehive, pig pen, orchard

## A finished Beehive at 8,8 (frame placed, materials added).
func _built_hive(g: GameState) -> Dictionary:
	g.coins = 1000000
	g.xp = maxi(g.xp, g.xp_for_level(3))
	g.buy_and_place("beehive", 8, 8)
	var hive := g.object_at(g.index_of(8, 8))
	_all_materials(g, 10)
	g.add_materials(int(hive["uid"]))
	return hive


func test_47_beehive_frame_and_queen_bee() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(3)
	_check(g.buy_and_place("beehive", 8, 8), "hive frame placed")
	var hive := g.object_at(g.index_of(8, 8))
	var uid := int(hive["uid"])
	_check(g.under_construction(hive), "the Beehive is built from a frame")
	g.gems = 100
	_check(not g.add_queen(uid, true), "no queen in an unfinished frame")
	_all_materials(g, 10)
	g.add_materials(uid)
	_check(not g.under_construction(hive), "frame finished with smokers, beeswax and the basics")
	_eq(int(g.parts["smokers"]), 0, "smokers used")
	_eq(g.capacity(hive), 200, "holds up to 200 bees")
	_check(g.expansion_needs(hive).is_empty(), "a hive isn't expanded: it grows as bees join")
	g.queen_bees = 0
	_check(not g.add_queen(uid), "no queen held")
	g.gems = GameState.QUEEN_GEM_COST
	_check(g.add_queen(uid, true), "queen bought with gems")
	_eq(g.gems, 0, "%d gems spent" % GameState.QUEEN_GEM_COST)
	_check(g.has_queen(hive), "the hive has its queen")
	g.queen_bees = 1
	_check(not g.add_queen(uid), "only one queen per hive")
	_eq(g.queen_bees, 1, "the spare queen is kept")
	_check(g.wanted_parts().has("smokers"), "smokers drop once you own a hive")
	_done(g)


func test_48_bees_pollinate_fertilized_crops() -> void:
	var g := _farm(true)
	_eq(g.pollination_chance(), 0.0, "no bees, no pollination")
	var none := 0
	for k in 100:
		none += g._pollinate("strawberries")
	_eq(none, 0, "nothing pollinated without bees")
	var hive := _built_hive(g)
	hive["queen"] = true
	hive["inside"] = {"bee": 100}
	_eq(g.pollination_chance(), 0.25, "100 bees: 25%")
	hive["inside"] = {"bee": 200}
	_eq(g.pollination_chance(), 0.5, "200 bees: 50%, the most")
	# Harvesting fertilized crops gives pollinated seeds; unfertilized ones never do.
	var i := _free(g)
	var from_plain := 0
	for k in 20:
		from_plain += int(_grow_and_harvest(g, i, "strawberries").get("pollinated", 0))
	_eq(from_plain, 0, "unfertilized crops aren't pollinated")
	var got := 0
	for k in 20:
		g.plow(i)
		g.pollinated.clear()
		g.plant(i, "strawberries")
		g.fertilize(i)
		_skip(g, int(g.crops["strawberries"]["grow_seconds"]))
		got += int(g.harvest(i).get("pollinated", 0))
	_check(got >= 25, "about half of fertilized harvests were pollinated (%d seeds)" % got)
	# Planting pollinated seeds: free, and the crop stays ripe twice as long.
	g.pollinated = {"strawberries": [2, g.now() + GameState.POLLINATED_LIFETIME]}
	var j := g.index_of(10, 10)
	g.plow(i)
	g.plow(j)
	var coins := g.coins
	_check(g.plant(i, "strawberries"), "plant a pollinated seed")
	_eq(g.coins, coins, "pollinated seeds are free")
	_eq(g.pollinated_seeds("strawberries"), 1, "one pollinated seed left")
	_check(g.plots[i].get("pol", false), "the plot is pollinated")
	g.pollinated.clear()
	g.plant(j, "strawberries")
	_check(not g.plots[j].get("pol", false), "an ordinary seed")
	var grow := int(g.crops["strawberries"]["grow_seconds"])
	var window := g.ripe_window(g.crops["strawberries"])
	_skip(g, grow + window + 3600)
	_eq(g.phase(j), GameState.Phase.WITHERED, "the ordinary crop withered")
	_eq(g.phase(i), GameState.Phase.RIPE, "the pollinated crop is still ripe")
	_skip(g, window)
	_eq(g.phase(i), GameState.Phase.WITHERED, "but not forever")
	# Pollinated seeds expire after 2 days.
	g.pollinated = {"wheat": [5, g.now() + GameState.POLLINATED_LIFETIME]}
	_eq(g.pollinated_seeds("wheat"), 5, "5 pollinated wheat seeds")
	_skip(g, GameState.POLLINATED_LIFETIME)
	_eq(g.pollinated_seeds("wheat"), 0, "expired after 2 days")
	_done(g)


func test_49_pollinated_crops_super_harvest_three_times_as_often() -> void:
	var g := _farm(true)
	var plain := 0
	var boosted := 0
	g.pity = {"golden": 0, "collectible": 0}
	for k in 6000:
		if str(g._roll_drop("", 0).get("type", "")) == "super_harvest":
			plain += 1
		if str(g._roll_drop("", 0, GameState.POLLINATED_SUPER_MULT).get("type", "")) == "super_harvest":
			boosted += 1
	var ratio := float(boosted) / maxf(1.0, plain)
	_check(ratio > 2.3 and ratio < 3.7, "about 3x the super harvests (%d vs %d)" % [boosted, plain])
	_done(g)


func test_50_fertilize_all_from_the_hive() -> void:
	var g := _farm(true)
	var hive := _built_hive(g)
	hive["queen"] = true
	hive["inside"] = {"bee": 50}
	hive["t"] = g.now()
	for d in 60:
		_skip(g, 86400)
		g.collect(int(hive["uid"]))
	_check(g.fertilize_alls > 0, "collecting honey left a Fertilize All (%d in 60 days)" % g.fertilize_alls)
	# Using it fertilizes every growing crop for free.
	g.drops_enabled = false
	var spots := [g.index_of(9, 0), g.index_of(9, 1), g.index_of(10, 0)]
	for i in spots:
		if g.phase(i) != GameState.Phase.PLOWED:
			g.plow(i)
		g.plant(i, "wheat")
	g.fertilize_alls = 1
	g.fertilizer_bags = 0
	var coins := g.coins
	_check(g.use_fertilize_all() >= 3, "every growing crop fertilized")
	for i in spots:
		_check(g.is_fertilized(i), "plot %d fertilized" % i)
	_eq(g.coins, coins, "no coins spent")
	_eq(g.fertilize_alls, 0, "used up")
	_eq(g.use_fertilize_all(), 0, "none left")
	_done(g)


func test_51_bees_leave_when_you_stay_away() -> void:
	var g := _farm()
	var hive := _built_hive(g)
	hive["queen"] = true
	hive["inside"] = {"bee": 100}
	_eq(g.apply_absence(2 * 86400), "", "2 days away: nothing happens")
	_eq(g.inside_total(hive), 100, "all bees stay")
	var note := g.apply_absence(5 * 86400)
	_eq(g.inside_total(hive), 70, "5 days away: 2 days past the limit, 30% leave")
	_check(note.contains("30 bees"), "the player is told (%s)" % note)
	_check(g.has_queen(hive), "the queen stays two weeks")
	g.apply_absence(15 * 86400)
	_eq(g.inside_total(hive), 0, "15 days away: every bee is gone")
	_check(not g.has_queen(hive), "and the queen flew off")
	_done(g)


func test_52_pig_pen_truffles_and_rare_breeds() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(15)
	_check(not g.buy_and_place("pig_pen", 8, 8), "Pig Pen unlocks at level 16")
	g.xp = g.xp_for_level(16)
	_check(g.buy_and_place("pig_pen", 8, 8), "pig pen frame placed")
	var pen := g.object_at(g.index_of(8, 8))
	var uid := int(pen["uid"])
	_check(g.under_construction(pen), "built from a frame")
	_all_materials(g, 8)
	g.add_materials(uid)
	_check(not g.under_construction(pen), "boards, bricks and nails finish it")
	_check(not g.feed_slop(uid), "no slop without pigs")
	for k in 12:
		g.place_somewhere("pig")
	_eq(g.fill_building(uid), 12, "12 pigs move in")
	var coins := g.coins
	_check(g.feed_slop(uid), "feed slop")
	_eq(g.coins, coins - GameState.SLOP_COST, "slop costs %d coins" % GameState.SLOP_COST)
	_check(not g.feed_slop(uid), "already foraging")
	_eq(g.collect_truffles(uid), 0, "nothing until foraging is over")
	_skip(g, GameState.FORAGE_SECONDS)
	_eq(g.collect_truffles(uid), 2, "12 pigs find 2 truffles")
	_eq(g.truffles, 2, "truffles held")
	_eq(g.collect_truffles(uid), 0, "collected once")
	# Truffles buy rare breeds; rare breeds aren't in the market.
	_check(not g.trade_truffles("berkshire_pig"), "10 truffles needed")
	g.truffles = 10
	_check(not g.trade_truffles("pig"), "only rare breeds")
	_check(g.trade_truffles("berkshire_pig"), "trade for a Berkshire")
	_eq(g.truffles, 0, "10 truffles spent")
	_eq(_count(g, "berkshire_pig"), 1, "the Berkshire is on the farm")
	_eq(g.fill_building(uid), 1, "and moves into the pen")
	_eq(g.rare_pigs().size(), 4, "4 rare breeds")
	for id in g.rare_pigs():
		_check(int(g.item_data(id)["payout"]) > int(g.item_data("pig")["payout"]), "%s pays more than a pig" % id)
		_eq(int(g.item_data(id)["unlock_level"]), 99, "%s can't be bought" % id)
	# A pen with a single pig still finds one truffle.
	pen["inside"] = {"pig": 1}
	g.feed_slop(uid)
	_skip(g, GameState.FORAGE_SECONDS)
	_eq(g.collect_truffles(uid), 1, "one pig finds one truffle")
	_done(g)


func test_53_orchard_sprouts_rare_saplings() -> void:
	var g := _farm(true)
	g.coins = 1000000
	g.xp = g.xp_for_level(8)
	_check(g.buy_and_place("orchard", 8, 8), "orchard bought")
	var orch := g.object_at(g.index_of(8, 8))
	orch["inside"] = {"cherry_tree": 10}
	orch["t"] = g.now()
	for k in 60:
		_skip(g, g.cycle_of(orch))
		g.collect(int(orch["uid"]))
	var rare := _count(g, "rainier_cherry_tree")
	_check(rare >= 2 and rare <= 14, "about 1 in 10 harvests sprouts a Rainier Cherry (%d in 60)" % rare)
	_eq(_count(g, "honeycrisp_apple_tree"), 0, "only rare kinds of the trees inside")
	_check(g.building_accepts(orch, "rainier_cherry_tree"), "rare trees can live in the orchard")
	for id in g.item_order:
		var it: Dictionary = g.items[id]
		if it.has("rare_sapling"):
			var r := g.item_data(it["rare_sapling"])
			_check(not r.is_empty(), "%s has its rare variety" % id)
			_eq(r.get("rare_of", ""), id, "%s links back" % r.get("id", "?"))
			_check(int(r["payout"]) > int(it["payout"]), "%s pays more" % r.get("id", "?"))
			_eq(int(r["unlock_level"]), 99, "%s can't be bought" % r.get("id", "?"))
	_done(g)


func test_54_new_building_state_survives_a_save() -> void:
	var path := "user://test_save_buildings.json"
	var g := _farm()
	g.save_path = path
	var hive := _built_hive(g)
	hive["queen"] = true
	hive["inside"] = {"bee": 42}
	g.queen_bees = 1
	g.fertilize_alls = 2
	g.truffles = 7
	g.pollinated = {"wheat": [3, g.now() + 3600]}
	g.xp = g.xp_for_level(16)
	g.buy_and_place("pig_pen", 0, 4)
	var pen := g.object_at(g.index_of(0, 4))
	pen.erase("construction")
	pen["inside"] = {"pig": 5}
	g.feed_slop(int(pen["uid"]))
	g.saving_enabled = true
	g.save_game()
	g.saving_enabled = false
	_done(g)

	var h := GameState.new()
	h.save_path = path
	add_child(h)
	h.saving_enabled = false
	var hive2 := h.object_at(h.index_of(8, 8))
	_check(h.has_queen(hive2), "queen restored")
	_eq(h.inside_total(hive2), 42, "bees restored")
	_eq(h.queen_bees, 1, "held queen restored")
	_eq(h.fertilize_alls, 2, "Fertilize All restored")
	_eq(h.truffles, 7, "truffles restored")
	_eq(h.pollinated_seeds("wheat"), 3, "pollinated seeds restored")
	var pen2 := h.object_at(h.index_of(0, 4))
	_check(h.is_foraging(pen2), "foraging restored")
	_check(h.forage_seconds_left(pen2) > 0, "foraging time restored")
	h.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------------------------------------------------------------- vehicles, fuel and the garage

func _all_plots(g: GameState, r0: int, c0: int, w: int, h: int, ph: GameState.Phase) -> bool:
	for r in range(r0, r0 + h):
		for c in range(c0, c0 + w):
			if g.phase(g.index_of(r, c)) != ph:
				return false
	return true


func test_55_tractor_plows_two_by_two_with_fuel() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(11)
	_check(not g.buy_and_place("tractor", 11, 0), "Tractor unlocks at level 12")
	_check(not g.fuel_unlocked, "no fuel before a vehicle")
	g.xp = g.xp_for_level(12)
	_check(g.buy_and_place("tractor", 11, 0), "Tractor bought for 5,000 coins")
	_check(g.fuel_unlocked, "the first vehicle unlocks the fuel tank")
	_eq(g.fuel_now(), GameState.FUEL_TANK, "it starts full: 150")
	_eq(g.vehicle_area("tractor"), Vector2i(2, 2), "a new tractor works 2x2")
	_check(g.use_vehicle("seeder", 8, 8, "wheat").is_empty(), "can't drive a vehicle you don't own")
	var coins := g.coins
	var r := g.use_vehicle("tractor", 8, 8)
	_eq(int(r["plots"]), 4, "one tap plows 4 plots")
	_eq(int(r["fuel"]), 4, "1 fuel a plot")
	_eq(g.fuel_now(), GameState.FUEL_TANK - 4, "fuel left")
	_eq(g.coins, coins - 4 * GameState.PLOW_COST, "plowing still costs coins")
	_check(_all_plots(g, 8, 8, 2, 2, GameState.Phase.PLOWED), "all 4 plowed")
	_eq(int(g.use_vehicle("tractor", 8, 8)["plots"]), 0, "nothing left to plow there")
	_eq(g.fuel_now(), GameState.FUEL_TANK - 4, "no fuel used when there's no work")
	# Objects in the way are skipped, without using fuel.
	g.buy_and_place("chicken", 9, 10)
	r = g.use_vehicle("tractor", 8, 10)
	_eq(int(r["plots"]), 3, "the plot under the chicken is skipped")
	_eq(int(r["fuel"]), 3, "and costs no fuel")
	_done(g)


func test_56_seeder_plants_and_harvester_harvests() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(14)
	for v in ["tractor", "seeder", "harvester"]:
		_check(g.buy_and_place(v, 11, ["tractor", "seeder", "harvester"].find(v)), "%s bought" % v)
	g.use_vehicle("tractor", 8, 8)
	_check(g.use_vehicle("seeder", 8, 8, "").is_empty(), "the seeder needs a seed")
	var coins := g.coins
	_eq(int(g.use_vehicle("seeder", 8, 8, "wheat")["plots"]), 4, "seeder plants 4 plots")
	_eq(g.coins, coins - 4 * int(g.crops["wheat"]["seed_cost"]), "seeds are paid for")
	_check(_all_plots(g, 8, 8, 2, 2, GameState.Phase.GROWING), "all 4 growing")
	_eq(int(g.use_vehicle("harvester", 8, 8)["plots"]), 0, "nothing ripe yet")
	_skip(g, int(g.crops["wheat"]["grow_seconds"]))
	var before := g.stat("harvests")
	var r := g.use_vehicle("harvester", 8, 8)
	_eq(int(r["plots"]), 4, "harvester harvests 4 plots")
	_check(int(r["coins"]) > 0 and int(r["xp"]) > 0, "harvests pay coins and XP")
	_eq(g.stat("harvests") - before, 4, "they count as harvests")
	_check(_all_plots(g, 8, 8, 2, 2, GameState.Phase.PLOWED), "plots left plowed")
	_done(g)


func test_57_fuel_refills_slowly_and_spare_tanks() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(12)
	g.buy_and_place("tractor", 11, 0)
	g.fuel = 0
	g.fuel_t = g.now()
	_check(g.use_vehicle("tractor", 8, 8).is_empty(), "nothing runs on an empty tank")
	_skip(g, 10 * GameState.FUEL_REGEN_SECONDS)
	_eq(g.fuel_now(), 10, "1 fuel every 10 minutes")
	_skip(g, 1000 * GameState.FUEL_REGEN_SECONDS)
	_eq(g.fuel_now(), GameState.FUEL_TANK, "never more than a full tank")
	g.fuel = 2
	g.fuel_t = g.now()
	g.fuel_tanks = 1
	var r := g.use_vehicle("tractor", 8, 8)
	_eq(int(r["plots"]), 4, "a spare tank is opened when the tank runs dry")
	_eq(g.fuel_tanks, 0, "spare tank used")
	_eq(g.fuel_now(), GameState.FUEL_TANK - 2, "the tank was refilled")
	g.gems = GameState.FUEL_TANK_GEM_COST
	_check(g.buy_fuel_tank(), "buy a tank for %d gems" % GameState.FUEL_TANK_GEM_COST)
	_eq(g.fuel_tanks, 1, "a spare tank held")
	_check(not g.buy_fuel_tank(), "no gems left")
	_done(g)


func test_58_garage_upgrades_vehicles_with_parts() -> void:
	var g := _farm()
	g.coins = 10000000
	g.xp = g.xp_for_level(22)
	g.buy_and_place("tractor", 11, 0)
	_check(not g.wanted_parts().has("vehicle_parts"), "no Vehicle Parts drop before a Garage")
	g.parts["vehicle_parts"] = 100
	_check(not g.upgrade_vehicle("tractor"), "no upgrades without a Garage")
	_check(g.buy_and_place("garage", 0, 4), "Garage frame placed")
	var garage := g.object_at(g.index_of(0, 4))
	_check(g.under_construction(garage), "the Garage is built from a frame")
	_check(g.wanted_parts().has("vehicle_parts"), "Vehicle Parts drop once you own a Garage")
	_check(not g.upgrade_vehicle("tractor"), "not until it's finished")
	for m in ["bricks", "nails", "boards"]:
		g.parts[m] = 10
	g.add_materials(int(garage["uid"]))
	_check(not g.under_construction(garage), "10 bricks, nails and boards finish it")
	var sizes: Array = [g.vehicle_area("tractor")]
	_check(g.upgrade_vehicle("tractor"), "upgrade 1")
	sizes.append(g.vehicle_area("tractor"))
	_check(g.upgrade_vehicle("tractor"), "upgrade 2")
	sizes.append(g.vehicle_area("tractor"))
	_eq(int(g.parts["vehicle_parts"]), 100 - 2 - 5, "2 then 5 parts")
	_check(not g.upgrade_vehicle("tractor"), "upgrade 3 needs level 26")
	g.xp = g.xp_for_level(26)
	_check(g.upgrade_vehicle("tractor"), "upgrade 3")
	sizes.append(g.vehicle_area("tractor"))
	_check(g.upgrade_vehicle("tractor"), "upgrade 4")
	sizes.append(g.vehicle_area("tractor"))
	_check(not g.upgrade_vehicle("tractor"), "fully upgraded")
	_eq(sizes, [Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 4)], "2x2 up to 4x4, FarmVille's sizes")
	_eq(int(g.parts["vehicle_parts"]), 100 - 32, "32 parts in all")
	_eq(g.stat("vehicle_upgrades"), 4, "upgrades counted for the Gearhead ribbon")
	_check(int(g.ribbon_tiers.get("gearhead", 0)) >= 2, "Gearhead ribbon earned")
	var r := g.use_vehicle("tractor", 8, 8)
	_eq(int(r["plots"]), 16, "a 4x4 tractor plows 16 plots in one tap")
	_done(g)


func test_59_combine_chassis_and_all_in_one() -> void:
	var g := _farm()
	g.coins = 10000000
	g.xp = g.xp_for_level(30)
	_check(not g.buy_and_place("combine", 11, 0), "Combine unlocks at level 31")
	g.xp = g.xp_for_level(31)
	_check(g.buy_and_place("combine", 11, 0), "Combine chassis bought")
	var combine := g.object_at(g.index_of(11, 0))
	_check(g.under_construction(combine), "it arrives as a chassis")
	_check(g.use_vehicle("combine", 8, 8, "wheat").is_empty(), "a chassis can't drive")
	_check(g.wanted_parts().has("vehicle_parts"), "Vehicle Parts drop for the chassis")
	g.parts["vehicle_parts"] = 40
	var xp_before := g.xp
	g.add_materials(int(combine["uid"]))
	_check(not g.under_construction(combine), "40 Vehicle Parts finish it")
	_check(g.xp - xp_before >= 5000, "finishing it gives 5,000 XP")
	var r := g.use_vehicle("combine", 8, 8, "wheat")
	_eq(int(r["plots"]), 4, "plows and plants 4 plots in one tap")
	_eq(int(r["fuel"]), 12, "3 fuel a plot")
	_check(_all_plots(g, 8, 8, 2, 2, GameState.Phase.GROWING), "planted")
	_skip(g, int(g.crops["wheat"]["grow_seconds"]))
	var before := g.stat("harvests")
	r = g.use_vehicle("combine", 8, 8, "wheat")
	_eq(g.stat("harvests") - before, 4, "harvested")
	_check(_all_plots(g, 8, 8, 2, 2, GameState.Phase.GROWING), "and planted again, in the same tap")
	_done(g)


func test_60_garage_parks_vehicles_and_state_saves() -> void:
	var path := "user://test_save_vehicles.json"
	var g := _farm()
	g.save_path = path
	g.coins = 10000000
	g.xp = g.xp_for_level(31)
	g.buy_and_place("garage", 0, 4)
	var garage := g.object_at(g.index_of(0, 4))
	garage.erase("construction")
	g.buy_and_place("tractor", 11, 0)
	g.buy_and_place("combine", 11, 2)
	_eq(g.fill_building(int(garage["uid"])), 1, "the tractor parks; the unfinished combine doesn't")
	_check(g.object_at(g.index_of(11, 0)).is_empty(), "the tractor left the field")
	_check(g.owned_vehicles().has("tractor"), "a parked tractor still counts")
	_eq(int(g.use_vehicle("tractor", 8, 8)["plots"]), 4, "and still works from the toolbar")
	_skip(g, 30 * 86400)
	_check(not g.is_ready(garage), "a garage never needs collecting")
	_check(g.collect(int(garage["uid"])).is_empty(), "nothing to collect")
	g.vehicle_levels["tractor"] = 2
	g.fuel = 77
	g.fuel_t = g.now()
	g.fuel_tanks = 3
	g.saving_enabled = true
	g.save_game()
	g.saving_enabled = false
	_done(g)

	var h := GameState.new()
	h.save_path = path
	add_child(h)
	h.saving_enabled = false
	_check(h.fuel_unlocked, "fuel tank restored")
	_eq(h.fuel_now(), 77, "fuel restored")
	_eq(h.fuel_tanks, 3, "spare tanks restored")
	_eq(h.vehicle_area("tractor"), Vector2i(3, 3), "upgrades restored")
	_check(h.owned_vehicles().has("tractor"), "the parked tractor is still there")
	h.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------------------------------------------------------------- gap pass: decorations, selling, homes, daily bonus

func test_61_decorations_give_xp_like_farmville() -> void:
	var g := _farm()
	g.coins = 10000000
	_eq(g.buy_xp("hay_bale"), 5, "a 100-coin hay bale gives 5 XP")
	_eq(g.buy_xp("white_picket_fence"), 5, "a 300-coin fence gives 5 XP")
	_eq(g.buy_xp("log_cabin"), 2500, "a 250,000-coin Log Cabin gives 2,500 XP")
	_eq(g.buy_xp("tractor"), 50, "other buys give 1 XP per 100 coins")
	_eq(g.buy_xp("brown_chicken"), 0, "gem buys give none")
	var xp := g.xp
	_check(g.buy_and_place("hay_bale", 8, 8), "buy a hay bale")
	_eq(g.xp - xp, 5, "5 XP for it")
	_eq(g.stat("decor_bought"), 1, "decorations counted for the Decorator ribbon")
	var count := 0
	for id in g.item_order:
		var it: Dictionary = g.items[id]
		if it["kind"] == "decor" and int(it["unlock_level"]) < 99:
			count += 1
	_check(count >= 30, "at least 30 decorations in the Market (%d)" % count)
	_done(g)


func test_62_sell_anything_for_five_percent() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(10)
	g.buy_and_place("hay_bale", 8, 8)
	var bale := g.object_at(g.index_of(8, 8))
	var coins := g.coins
	_eq(g.sell_value(bale), 5, "a hay bale sells for 5")
	_check(g.sell_object(int(bale["uid"])), "sold")
	_eq(g.coins, coins + 5, "5 coins back")
	_check(g.object_at(g.index_of(8, 8)).is_empty(), "it's gone")
	_check(not g.sell_object(int(g.barn()["uid"])), "the barn can't be sold")
	_check(not g.can_sell(g.object_at(g.index_of(0, 0))), "nor the farmhouse")
	g.gems = 10
	g.buy_and_place("brown_chicken", 8, 9)
	_eq(g.sell_value(g.object_at(g.index_of(8, 9))), 5 * GameState.SELL_COINS_PER_GEM, "gem items sell for coins")
	# A building's animals move back out when it's sold.
	g.buy_and_place("chicken_coop", 0, 4)
	var coop := g.object_at(g.index_of(0, 4))
	for k in 5:
		g.place_somewhere("chicken")
	var before := _count(g, "chicken")
	g.fill_building(int(coop["uid"]))
	_eq(_count(g, "chicken"), before - 5, "5 chickens in the coop")
	_check(g.sell_object(int(coop["uid"])), "sell the coop")
	_eq(_count(g, "chicken"), before, "the chickens are back on the farm")
	_eq(_count(g, "chicken_coop"), 0, "the coop is gone")
	_eq(g.stat("items_sold"), 2, "sales counted")
	_done(g)


func test_63_rotate_decorations() -> void:
	var g := _farm()
	g.coins = 1000000
	g.xp = g.xp_for_level(10)
	g.buy_and_place("wooden_fence", 8, 8)
	var fence := g.object_at(g.index_of(8, 8))
	_check(g.rotate_object(int(fence["uid"])), "a fence turns")
	_check(fence.get("flip", false), "it faces the other way")
	g.rotate_object(int(fence["uid"]))
	_check(not fence.get("flip", false), "and back")
	g.buy_and_place("chicken_coop", 0, 4)
	_check(not g.rotate_object(int(g.object_at(g.index_of(0, 4))["uid"])), "buildings don't turn")
	_done(g)


func test_64_new_homes_rams_boars_lambs_piglets() -> void:
	var g := _farm(true)
	g.coins = 10000000
	g.xp = g.xp_for_level(20)
	_check(g.buy_and_place("sheep_pen", 0, 4), "Sheep Pen")
	var pen := g.object_at(g.index_of(0, 4))
	for id in ["sheep", "sheep", "llama", "alpaca", "ram"]:
		g.place_somewhere(id)
	_eq(g.fill_building(int(pen["uid"])), 5, "sheep, llama, alpaca and the ram move in")
	_eq(g.inside_total(pen), 4, "the ram takes no space")
	for d in 40:
		_skip(g, 86400)
		g.collect(int(pen["uid"]))
	_check(_count(g, "lamb") > 0, "lambs were born (%d)" % _count(g, "lamb"))
	_check(g.buy_and_place("pig_pen", 8, 8), "Pig Pen")
	var pigs := g.object_at(g.index_of(8, 8))
	pigs.erase("construction")
	g.place_somewhere("pig")
	g.place_somewhere("boar")
	g.fill_building(int(pigs["uid"]))
	_check(g.has_inside(pigs, "boar"), "the boar lives in the pig pen")
	pigs["t"] = g.now()
	for d in 40:
		_skip(g, 86400)
		g.collect(int(pigs["uid"]))
	_check(_count(g, "piglet") > 0, "piglets were born (%d)" % _count(g, "piglet"))
	# The nursery raises them.
	g.buy_and_place("nursery_barn", 3, 6)
	var nursery := g.object_at(g.index_of(3, 6))
	nursery.erase("construction")
	var sheep := _count(g, "sheep")
	g.fill_building(int(nursery["uid"]))
	for d in 4:
		_skip(g, 86400)
		g.collect(int(nursery["uid"]))
	_check(_count(g, "sheep") > sheep, "lambs grew into sheep")
	_check(g.stat("babies_raised") > 0, "babies counted for the Nanny ribbon")
	# The other homes.
	for pair in [["duck_pond", "duck"], ["duck_pond", "goose"], ["goat_pen", "goat"], ["rabbit_hutch", "rabbit"],
			["horse_stable", "pony"], ["horse_stable", "donkey"], ["cow_shed", "ox"], ["chicken_coop", "turkey"]]:
		_check(g.building_accepts({"id": pair[0]}, pair[1]), "%s holds %s" % pair)
	_done(g)


func test_65_rams_and_boars_wander_in_only_with_their_home() -> void:
	var g := _farm()
	g.xp = g.xp_for_level(20)
	var seen := {}
	for k in 300:
		if g._spawn_stray():
			seen[g.objects[-1]["id"]] = true
			g.objects.pop_back()
			g._rebuild_occupancy()
	_check(not seen.has("ram") and not seen.has("boar"), "no ram or boar without their homes")
	g.coins = 10000000
	g.buy_and_place("sheep_pen", 0, 4)
	seen = {}
	for k in 300:
		if g._spawn_stray():
			seen[g.objects[-1]["id"]] = true
			g.objects.pop_back()
			g._rebuild_occupancy()
	_check(seen.has("ram"), "a ram wanders in once you have a Sheep Pen")
	_check(not seen.has("boar"), "still no boar")
	_done(g)


func test_66_daily_bonus_streak() -> void:
	var g := _farm()
	g.last_daily_day = g.day_number() - 1
	var expected := [100, 250, 500, 750, 1000, 1000]
	for d in 6:
		var coins := g.coins
		var gems := g.gems
		g.check_daily_gift()
		_eq(g.daily_streak, d + 1, "day %d of the streak" % (d + 1))
		_eq(g.coins - coins, expected[d], "day %d pays %d coins" % [d + 1, expected[d]])
		if d >= 4:
			_eq(g.gems - gems, 1, "day 5 and on add a gem")
		g.check_daily_gift()
		_eq(g.daily_streak, d + 1, "only once a day")
		_skip(g, 86400)
	_skip(g, 86400) # miss a day
	g.check_daily_gift()
	_eq(g.daily_streak, 1, "missing a day starts the streak again")
	_check(g.stat("daily_bonuses") >= 7, "bonuses counted for the Regular ribbon")
	_done(g)


func test_67_mastery_sign_collections_and_ribbons() -> void:
	var g := _farm()
	g._award_mastery_star("wheat", 3)
	var signs := g.objects.filter(func(o): return o["id"] == "mastery_sign")
	_eq(signs.size(), 1, "mastering a crop puts a mastery sign on the farm")
	_eq(signs[0].get("crop", ""), "wheat", "the sign is for wheat")
	_check(g.can_sell(signs[0]) and g.can_rotate(signs[0]), "it can be sold or turned like any decoration")
	var crop_sets := 0
	var seen := {}
	for coll in g.collections:
		if not coll.get("crops", []).is_empty():
			crop_sets += 1
		for crop_id in coll.get("crops", []):
			_check(not seen.has(crop_id), "%s is in only one collection" % crop_id)
			seen[crop_id] = true
	_check(crop_sets >= 10, "at least 10 crop collections (%d)" % crop_sets)
	_check((g.ribbon_data["ribbons"] as Array).size() >= 20, "at least 20 ribbons")
	_done(g)


func test_68_every_decoration_has_art() -> void:
	var g := _farm()
	var shapes := ["path", "fence", "hedge", "wall", "haybale", "haystack", "scarecrow", "flowerbed", "flamingo", "bench",
		"shadetree", "trough", "bonfire", "wheelbarrow", "birdhouse", "birdbath", "picnic", "well", "gnome", "lamp",
		"sundial", "pond", "arbor", "bridge", "fountain", "gazebo", "cabin", "mastery"]
	for id in g.item_order:
		var it: Dictionary = g.items[id]
		if it["kind"] == "decor" and not ["farmhouse", "mailbox", "farm_stand"].has(id):
			_check(shapes.has(it.get("shape", "")), "%s has a drawn shape" % id)
	_done(g)
