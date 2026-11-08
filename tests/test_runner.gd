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
	_check(g.upgrade_building(uid), "upgrade")
	_eq(g.capacity(coop), 30, "level 2 holds 30")
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

func test_14_bees_wait_then_move_into_a_hive() -> void:
	var g := _farm()
	g.coins = 100000
	g._add_bee()
	_eq(g.waiting_bees, 1, "bee waits without a hive")
	g.add_xp(g.xp_for_level(3))
	_check(g.buy_and_place("beehive", 8, 8), "buy beehive")
	_eq(g.waiting_bees, 0, "waiting bee moved in")
	var hive := g.object_at(g.index_of(8, 8))
	_eq(g.inside_total(hive), 1, "hive holds the bee")
	_skip(g, 86400)
	_eq(g.collect(int(hive["uid"]))["coins"], 30, "one bee makes 30 coins of honey")
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
			_eq((it["upgrade_costs"] as Array).size(), (it["levels"] as Array).size() - 1, "%s upgrade costs match its levels" % id)
			for held in it.get("holds", []):
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

## Sends input the way the OS does, then lets a frame run so it's delivered.
func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await get_tree().process_frame


func _drag(pos: Vector2, relative: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = pos
	ev.relative = relative
	Input.parse_input_event(ev)
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
