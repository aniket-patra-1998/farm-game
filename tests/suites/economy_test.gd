extends TestSuite
## Prices, payouts, selling, the barn and storage, building materials and the daily bonus.


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
		_check(g.collectibles.collection_of_crop.has(id), "%s can drop collectibles" % id)
	_done(g)






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
	for p in GameState.part_ids:
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
	g.daily.check_daily_gift()
	_eq(g.ribbons.stat("parts_found"), 0, "no gift on the first day")
	_skip(g, 86400)
	g.daily.check_daily_gift()
	_eq(g.ribbons.stat("parts_found"), DailySystem.DAILY_PARTS, "gift the next day")
	g.daily.check_daily_gift()
	_eq(g.ribbons.stat("parts_found"), DailySystem.DAILY_PARTS, "only once that day")
	_skip(g, 3 * 86400)
	g.daily.check_daily_gift()
	_eq(g.ribbons.stat("parts_found"), 2 * DailySystem.DAILY_PARTS, "one gift after a long break, not a pile")
	_done(g)






func test_29_barn_repair_needs_every_part() -> void:
	var g := _farm()
	_check(not g.storage.can_repair_barn(), "can't repair with no parts")
	_check(not g.storage.repair_barn(), "repair refused")
	var need := g.storage.repair_needs()
	g.parts["bricks"] = int(need["bricks"])
	g.parts["nails"] = int(need["nails"])
	g.parts["boards"] = int(need["boards"]) - 1
	_check(not g.storage.can_repair_barn(), "one board short")
	g.parts["boards"] = int(need["boards"]) + 2
	g.xp = g.xp_for_level(10) # keep the reward XP from triggering a level-up reward
	var coins := g.coins
	_check(g.storage.repair_barn(), "repair with enough parts")
	_check(g.storage.barn_repaired(), "barn is fixed")
	_eq(g.coins, coins + int(g.item_data("barn")["repair_coins"]), "repair reward coins")
	_eq(int(g.parts["boards"]), 2, "spare boards kept")
	_eq(int(g.parts["bricks"]), 0, "bricks used up")
	_check(not g.storage.repair_barn(), "can't repair twice")
	_done(g)






func test_30_storage_put_away_and_bring_back() -> void:
	var g := _farm()
	var chicken := g.object_at(g.index_of(9, 2))
	_eq(chicken.get("id", ""), "chicken", "starter chicken in place")
	_check(not g.storage.store_object(int(chicken["uid"])), "can't store while the barn is broken")
	g.storage.barn().erase("broken")
	_check(not g.storage.store_object(int(g.storage.barn()["uid"])), "the barn can't store itself")
	_check(g.storage.store_object(int(chicken["uid"])), "store the chicken")
	_check(g.object_at(g.index_of(9, 2)).is_empty(), "its tile is free")
	_eq(g.storage.stored.size(), 1, "one item stored")
	_check(not g.storage.place_from_storage(0, 1, 1), "can't place it on the farmhouse")
	_check(g.storage.place_from_storage(0, 11, 11), "place it back out")
	_eq(g.storage.stored.size(), 0, "storage empty again")
	_eq(g.object_at(g.index_of(11, 11)).get("id", ""), "chicken", "chicken is back")
	_check(not g.is_ready(g.object_at(g.index_of(11, 11))), "its timer restarted")
	_done(g)






func test_31_storage_limits() -> void:
	var g := _farm()
	g.storage.barn().erase("broken")
	g.coins = 1000000
	g.add_xp(g.xp_for_level(4))
	_check(g.buy_and_place("chicken_coop", 8, 8), "coop placed")
	_check(not g.storage.store_object(int(g.object_at(g.index_of(8, 8))["uid"])), "shelters can't be stored")
	g.strays.next_stray_at = 0
	g.strays.check_strays()
	var strays := 0
	for o in g.objects:
		if o.get("stray", false):
			strays += 1
			_check(not g.storage.store_object(int(o["uid"])), "strays can't be stored")
	_eq(strays, 1, "a stray arrived to test with")
	for k in g.storage.barn_capacity():
		g.storage.stored.append({"uid": 9000 + k, "id": "chicken", "t": 0})
	var kept_id := str(g.object_at(g.index_of(9, 3))["id"])
	_check(g.storage.store_object(int(g.object_at(g.index_of(9, 3))["uid"])),
		"past the barn's space it goes to the gift box")
	_eq(g.storage.in_gift_box(), 1, "one thing in the gift box")
	while g.storage.stored.size() < g.storage.total_limit():
		g.storage.stored.append({"uid": 90000 + g.storage.stored.size(), "id": "chicken", "t": 0})
	_check(g.buy_and_place(kept_id, 9, 6), "another one to try")
	_check(not g.storage.store_object(int(g.object_at(g.index_of(9, 6))["uid"])),
		"barn and gift box both full refuses more")
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
	_eq(g.ribbons.stat("decor_bought"), 1, "decorations counted for the Decorator ribbon")
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
	_check(not g.sell_object(int(g.storage.barn()["uid"])), "the barn can't be sold")
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
	g.homes.fill_building(int(coop["uid"]))
	_eq(g.inside_total(coop), before + 1, "every loose chicken (and the brown one) moved into the coop")
	_check(g.sell_object(int(coop["uid"])), "sell the coop")
	_eq(_count(g, "chicken"), before, "the chickens are back on the farm")
	_eq(_count(g, "chicken_coop"), 0, "the coop is gone")
	_eq(g.ribbons.stat("items_sold"), 2, "sales counted")
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
	# Buildings first, so the animals placed below can't land on their spots.
	_check(g.buy_and_place("sheep_pen", 0, 4), "Sheep Pen")
	var pen := g.object_at(g.index_of(0, 4))
	_check(g.buy_and_place("pig_pen", 8, 8), "Pig Pen")
	var pigs := g.object_at(g.index_of(8, 8))
	g.buy_and_place("nursery_barn", 3, 6)
	var nursery := g.object_at(g.index_of(3, 6))
	for id in ["sheep", "sheep", "llama", "alpaca", "ram"]:
		g.place_somewhere(id)
	_eq(g.homes.fill_building(int(pen["uid"])), 5, "sheep, llama, alpaca and the ram move in")
	_eq(g.inside_total(pen), 4, "the ram takes no space")
	for d in 40:
		_skip(g, 86400)
		g.collect(int(pen["uid"]))
	_check(_count(g, "lamb") > 0, "lambs were born (%d)" % _count(g, "lamb"))
	pigs.erase("construction")
	g.place_somewhere("pig")
	g.place_somewhere("boar")
	g.homes.fill_building(int(pigs["uid"]))
	_check(g.has_inside(pigs, "boar"), "the boar lives in the pig pen")
	pigs["t"] = g.now()
	for d in 40:
		_skip(g, 86400)
		g.collect(int(pigs["uid"]))
	_check(_count(g, "piglet") > 0, "piglets were born (%d)" % _count(g, "piglet"))
	# The nursery raises them.
	nursery.erase("construction")
	var sheep := _count(g, "sheep")
	g.homes.fill_building(int(nursery["uid"]))
	for d in 4:
		_skip(g, 86400)
		g.collect(int(nursery["uid"]))
	_check(_count(g, "sheep") > sheep, "lambs grew into sheep")
	_check(g.ribbons.stat("babies_raised") > 0, "babies counted for the Nanny ribbon")
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
		if g.strays._spawn_stray():
			seen[g.objects[-1]["id"]] = true
			g.objects.pop_back()
			g.rebuild_occupancy()
	_check(not seen.has("ram") and not seen.has("boar"), "no ram or boar without their homes")
	g.coins = 10000000
	g.buy_and_place("sheep_pen", 0, 4)
	seen = {}
	for k in 300:
		if g.strays._spawn_stray():
			seen[g.objects[-1]["id"]] = true
			g.objects.pop_back()
			g.rebuild_occupancy()
	_check(seen.has("ram"), "a ram wanders in once you have a Sheep Pen")
	_check(not seen.has("boar"), "still no boar")
	_done(g)






func test_66_daily_bonus_streak() -> void:
	var g := _farm()
	g.ribbons.ribbon_tiers["regular"] = 4 # isolate the bonus from the ribbon's own reward
	g.daily.last_daily_day = g.day_number() - 1
	var expected := [100, 250, 500, 750, 1000, 1000]
	for d in 6:
		var coins := g.coins
		var gems := g.gems
		g.daily.check_daily_gift()
		_eq(g.daily.daily_streak, d + 1, "day %d of the streak" % (d + 1))
		_eq(g.coins - coins, expected[d], "day %d pays %d coins" % [d + 1, expected[d]])
		if d >= 4:
			_eq(g.gems - gems, 1, "day 5 and on add a gem")
		g.daily.check_daily_gift()
		_eq(g.daily.daily_streak, d + 1, "only once a day")
		_skip(g, 86400)
	_skip(g, 86400) # miss a day
	g.daily.check_daily_gift()
	_eq(g.daily.daily_streak, 1, "missing a day starts the streak again")
	_check(g.ribbons.stat("daily_bonuses") >= 7, "bonuses counted for the Regular ribbon")
	_done(g)






func test_67_mastery_sign_collections_and_ribbons() -> void:
	var g := _farm()
	g.mastery.award_star("wheat", 3)
	var signs := g.objects.filter(func(o): return o["id"] == "mastery_sign")
	_eq(signs.size(), 1, "mastering a crop puts a mastery sign on the farm")
	_eq(signs[0].get("crop", ""), "wheat", "the sign is for wheat")
	_check(g.can_sell(signs[0]) and g.can_rotate(signs[0]), "it can be sold or turned like any decoration")
	var crop_sets := 0
	var seen := {}
	for coll in g.collectibles.collections:
		if not coll.get("crops", []).is_empty():
			crop_sets += 1
		for crop_id in coll.get("crops", []):
			_check(not seen.has(crop_id), "%s is in only one collection" % crop_id)
			seen[crop_id] = true
	_check(crop_sets >= 10, "at least 10 crop collections (%d)" % crop_sets)
	_check((g.ribbons.ribbon_data["ribbons"] as Array).size() >= 20, "at least 20 ribbons")
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






func test_69_art_manifest_is_complete() -> void:
	var g := _farm()
	var m = JSON.parse_string(FileAccess.get_file_as_string("res://art/manifest.json"))
	_check(typeof(m) == TYPE_DICTIONARY, "art/manifest.json parses")
	_check((m["styles"] as Dictionary).has("painterly"), "painterly is the style")
	var in_manifest := {}
	for entry in m["items"]:
		in_manifest[entry["id"]] = entry
		_check(float(entry["fill"]) > 0.0 and float(entry["fill"]) <= 1.0, "%s has a sensible width" % entry["id"])
		_check(str(entry["subject"]) != "", "%s says what to draw" % entry["id"])
		_check(
			entry["class"] in ["Ground", "Icon", "Avatar"] or g.catalog.get_def(entry["item"]) != null,
			"%s belongs to a real item" % entry["id"]
		)
	# The template: every in-game item has art for every stage of its lifecycle, named the same way
	# by the game (GDScript) and the generator (Python).
	for id in g.catalog.order:
		for art in g.catalog.art_ids_of(id):
			_check(in_manifest.has(art), "%s has its art entry %s" % [id, art])
	_eq(
		g.catalog.art_ids_of("strawberries"),
		[
			"crop_strawberries_planted",
			"crop_strawberries_growing",
			"crop_strawberries_ripe",
			"crop_strawberries_withered"
		],
		"crops: planted, growing, ripe, withered"
	)
	_eq(
		g.catalog.art_ids_of("apple_tree"),
		["apple_tree_harvested", "apple_tree_fruiting", "apple_tree_ready"],
		"trees: harvested, fruiting, ready"
	)
	_eq(
		g.catalog.art_ids_of("chicken_coop"),
		["chicken_coop_size1", "chicken_coop_size2", "chicken_coop_size3"],
		"buildings: one per size"
	)
	_eq(g.catalog.art_ids_of("cow"), ["cow"], "animals: one look")
	_eq(
		g.catalog.art_ids_of("bakery"),
		["bakery_size1", "bakery_size2", "bakery_size3", "bakery_size4", "bakery_size5"],
		"crafting: one per star"
	)
	_eq(g.catalog.art_ids_of("pumpkin_bread"), ["good_pumpkin_bread"], "goods: one icon")
	_check(
		in_manifest.has("avatar_farmer_m_hoe_back") and in_manifest.has("icon_coins")
			and in_manifest.has("icon_egg_cornish"),
		"the farmer and the menu icons are in the art run"
	)
	_check(not SpriteBank.has("no_such_item"), "missing art falls back to drawings")
	_done(g)






## A throwaway art folder holding only these ids, so tests don't depend on what's been generated.
func _art_dir(ids: Array) -> String:
	var dir := "user://test_art"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var meta := {}
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for id in ids:
		img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [dir, id]))
		meta[id] = {"anchor": [4, 8], "scale": 0.5}
	var f := FileAccess.open(dir + "/sprites.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	f.close()
	return dir






func test_72_art_follows_the_lifecycle() -> void:
	var g := _farm()
	SpriteBank.use_dir(_art_dir(["crop_strawberries_growing", "crop_strawberries_ripe", "chicken_coop"]))
	# Strawberries: no art for planted, art for growing and ripe.
	var i := _free(g)
	g.field.plow(i)
	g.field.plant(i, "strawberries")
	_eq(g.crop_art_for(i), "", "no planted art: the code drawing is used")
	_skip(g, int(int(g.crops["strawberries"]["grow_seconds"]) * 0.6))
	_eq(g.crop_art_for(i), "crop_strawberries_growing", "half grown picks the growing art")
	_skip(g, int(g.crops["strawberries"]["grow_seconds"]))
	_eq(g.crop_art_for(i), "crop_strawberries_ripe", "ripe picks the ripe art")
	# Buildings fall back from their size to the plain id.
	g.coins = 1000000
	g.xp = g.xp_for_level(15) # the tractor unlocks at 12
	g.objects = g.objects.filter(func(o): return g.kind_of(o) != "animal") # starter animals wander anywhere
	g.rebuild_occupancy()
	g.buy_and_place("chicken_coop", 0, 4)
	_eq(g.art_for(g.object_at(g.index_of(0, 4))), "chicken_coop", "the coop uses its art until size art exists")
	_check(g.buy_and_place("tractor", 8, 8), "tractor placed")
	_eq(g.art_for(g.object_at(g.index_of(8, 8))), "", "no tractor art: drawn in code")
	SpriteBank.use_default()
	_check(not SpriteBank.has("cow"), "painted art is off by default: everything is drawn (and animated) in code")
	_done(g)
