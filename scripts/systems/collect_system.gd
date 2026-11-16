class_name CollectSystem
extends GameSystem
## Collecting what is ready from an animal, tree, bloom or home (FarmVille's way: coins and mastery, never XP but
## a bonus drop's), with everything a collect sets off: its bonus drop, mastery for everyone inside, a bloom's
## bulbs, a home's specials and young growing up, a young one becoming an adult, the feed it was given used up,
## a tree's feed find and a collectible, and its produce for crafting (milk, eggs, apples, roses:
## CraftingSystem.roll_produce). A bonus drop and a collectible are said on the thing itself, in their rarity's
## colours (`Game.found_on`). Reached as `Game.collecting`; `Game.collect` asks it.


## Returns {"coins", "xp", "drop", "drop_text", "name"} or {} if nothing was ready.
func collect(uid: int) -> Dictionary:
	var obj := game.object_by_uid(uid)
	if obj.is_empty() or not game.is_ready(obj):
		return {}
	# FarmVille: collecting pays game.coins and game.mastery, never XP (an animal or tree gave its XP once, when bought);
	# only a bonus drop adds XP.
	# Fed or hungry, and touching its own kind.
	var earned := roundi(game.object_payout(obj).x * game.feeds.coin_multiplier(obj) * game.adjacency.coin_multiplier(obj))
	game.feeds.rare_boost = game.feeds.rare_multiplier(obj)
	var gained := 0
	var drop := game.drops.roll_drop("", 0)
	match drop.get("type", ""):
		"golden":
			earned *= Balance.i("economy.golden_coin_multiplier")
			gained += Balance.i("economy.golden_xp")
		"super_harvest":
			earned *= 2
		"bonus_xp":
			gained += Balance.i("economy.bonus_xp")
	if not drop.is_empty():
		game.found_on.emit(uid, str(drop["text"]), str(drop["rarity"]))   # (said on the thing, in its rarity's colours)
	obj["t"] = game.now()
	game.add_coins(earned)
	game.add_xp(gained)
	game.ribbons.bump("collected", 1)
	var part := game.daily.roll_part()
	var extras: Array[String] = []
	var name_before: String = game.item_data(obj["id"])["name"]
	# Every animal, tree or bloom harvested earns its own game.mastery, loose or living in a home.
	if game.is_home(obj):
		var inside: Dictionary = obj.get("inside", {})
		for id in inside:
			game.mastery.add_harvest(id, int(inside[id]))
	else:
		game.mastery.add_harvest(obj["id"], 1)
	var produce := game.crafting.roll_produce(obj)   # (milk, eggs, apples, roses... for crafting)
	for ingredient: String in produce:
		extras.append(tr("PRODUCE_FOUND") % [int(produce[ingredient]), game.name_of(ingredient)])
	if game.kind_of(obj) == "bloom":
		extras.append_array(game.nurture.from_bloom(obj))
	if game.is_home(obj):
		extras.append_array(game.specials.building_specials(obj))
		extras.append_array(game.specials.grow_up_inside(obj))
	else:
		var adult := game.specials.grows_into(obj["id"])
		if adult != "":
			obj["id"] = adult
			game.message.emit(tr("YOUR_GREW_UP_INTO_A") % [name_before.to_lower(), game.item_data(adult)["name"].to_lower()])
			extras.append(tr("GREW_UP"))
	obj.erase(FeedSystem.FED)   # what it was fed was for this cycle
	game.feeds.rare_boost = 1.0
	var coll_find := ""
	game.collectibles.last_found = ""
	if game.kind_of(obj) == "tree":
		var fruit := game.feeds.roll_tree()
		if fruit != "":
			extras.append(tr("FOUND_FEED") % game.feeds.feed_name(fruit))
		coll_find = game.collectibles.roll_collectible(
			game.collectibles.tree_collection,
			Balance.f("economy.animal_collectible_chance")
		)
	elif game.kind_of(obj) == "animal" or game.is_home(obj):
		coll_find = game.collectibles.roll_collectible(
			game.collectibles.animal_collection,
			Balance.f("economy.animal_collectible_chance")
		)
	if coll_find != "":
		game.found_on.emit(uid, tr("FOUND") + coll_find, game.collectibles.rarity_of(game.collectibles.last_found))
	if drop.get("type", "") == "golden":
		game.ribbons.bump("golden_finds", 1)
		game.message.emit(tr("GOLDEN_COLLECTION_X_COINS") % Balance.i("economy.golden_coin_multiplier"))
	elif drop.get("type", "") == "bird":
		game.message.emit(tr("A_LANDED_ON_YOUR_FARM_COLLECTION") % [drop["name"].to_lower(), drop["collection"]])
	game.objects_updated(uid)
	return {"coins": earned, "xp": gained, "drop": drop.get("type", ""),
		"drop_text": drop.get("text", ""), "name": name_before, "part": part, "extras": extras}
