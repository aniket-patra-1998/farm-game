extends TestSuite
## The Feed Mill (our own touch): a crafting building whose recipes turn bushels into rich feed for the Barn.


func _mill_farm() -> Array:
	var g := _farm()
	g.feeds.active = true
	g.coins = 10000000
	g.xp = g.xp_for_level(60)   # the mill unlocks past the FarmVille cottages
	g.objects = g.objects.filter(func(o): return g.kind_of(o) != "animal")
	g.rebuild_occupancy()
	_check(g.buy_and_place("feed_mill", 8, 8), "the mill is placed")
	return [g, int(g.object_at(g.index_of(8, 8))["uid"])]


func test_179_every_feed_recipe_is_made_of_real_crops_and_feeds() -> void:
	var g := _farm()
	var seen := 0
	for r in g.crafting.recipes_of("feed_mill"):
		seen += 1
		_check(r.makes_feed(), "%s makes feed" % r.id)
		_check(g.feeds.feed_ids().has(str(r.feed()["type"])), "%s: a real feed" % r.id)
		_check(int(r.feed()["units"]) > 0, "%s: at least a unit" % r.id)
		for c in r.inputs():
			_check(g.crops.has(c), "%s: %s is a crop" % [r.id, c])
	_check(seen >= 5, "the mill has recipes at several stars")
	for id in g.feeds.feed_ids():
		var made := false
		for r in g.crafting.recipes_of("feed_mill"):
			made = made or str(r.feed()["type"]) == id
		_check(made, "%s can be milled" % id)


func test_180_a_finished_batch_lands_in_the_barn_as_rich_feed_not_as_a_good() -> void:
	var m := _mill_farm()
	var g: GameState = m[0]
	var uid: int = m[1]
	g.crafting.bushels = {"wheat": 3, "corn": 3}
	_check(g.crafting.start_craft(uid, "rich_grain_mix"), "started")
	g.debug_time_offset += 7 * 86400
	_check(g.crafting.finish_crafts(uid) == 1, "finished")
	_eq(g.feeds.count("grain", true), 3, "three units of rich grain")
	_check(g.crafting.goods.is_empty(), "no good is made")
	_eq(int(g.crafting.crafted.get("rich_grain_mix", 0)), 1, "it still counts towards the recipe's mastery")


func test_181_feed_past_the_barn_cap_is_sold_not_lost() -> void:
	var m := _mill_farm()
	var g: GameState = m[0]
	var uid: int = m[1]
	g.feeds.stock = {"grain": g.feeds.cap() - 1}
	g.crafting.bushels = {"wheat": 3, "corn": 3}
	var before := g.coins
	g.crafting.start_craft(uid, "rich_grain_mix")
	g.debug_time_offset += 7 * 86400
	g.crafting.finish_crafts(uid)
	_eq(g.feeds.total("grain"), g.feeds.cap(), "the Barn is full")
	_eq(g.coins - before, 2 * Balance.i("feeds.overflow_coins"), "the two that didn't fit were sold")
