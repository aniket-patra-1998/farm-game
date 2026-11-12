class_name CraftingSystem
extends GameSystem
## Crafting (Bakery, Winery, Spa): bushels, recipes, recipe mastery, goods and the Farmers Market.
## Part of the game state: reached as `Game.crafting`; shared state is on `game`.


var bushels := {}                  # crop id -> bushels held, for crafting
var goods := {}                    # recipe id -> crafted goods held
var crafted := {}                  # recipe id -> lifetime crafts (recipe mastery)
var stall := {}                    # crop id -> bushels for sale at the Farmers Market today
var stall_day := 0


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
	bushels = {}
	goods = {}
	crafted = {}
	stall = {}
	stall_day = 0


func save_to(data: Dictionary) -> void:
	data["bushels"] = bushels
	data["goods"] = goods
	data["crafted"] = crafted
	data["stall"] = stall
	data["stall_day"] = stall_day


func load_from(data: Dictionary) -> void:
	bushels = int_map(data.get("bushels", {}))
	goods = int_map(data.get("goods", {}))
	crafted = int_map(data.get("crafted", {}))
	stall = int_map(data.get("stall", {}))
	stall_day = int(data.get("stall_day", 0))


func is_crafting(obj: Dictionary) -> bool:
	return game.kind_of(obj) == "crafting"


func owns_crafting() -> bool:
	for o in game.objects:
		if is_crafting(o):
			return true
	return false


## FarmVille: your first crafting building costs coins; every one after that, premium currency.
func crafting_price(item_id: String) -> Dictionary:
	var it := game.item_data(item_id)
	if owns_crafting():
		return {"gems": int(it.get("extra_gem_cost", 80))}
	return {"coins": int(it.get("cost", 0))}


func _crafting_def(obj: Dictionary) -> CraftingDef:
	return game.catalog.get_def(obj["id"]) as CraftingDef


func _recipe(rid: String) -> RecipeDef:
	return game.catalog.get_def(rid) as RecipeDef


## Every recipe the building knows, unlocked or not, by star.
func recipes_of(building_id: String) -> Array[RecipeDef]:
	return game.catalog.recipes_of(building_id)


func recipe_unlocked(obj: Dictionary, rid: String) -> bool:
	var r := _recipe(rid)
	return r != null and r.building() == obj["id"] and r.star() <= game.level_of(obj)


func recipe_stars(rid: String) -> int:
	return CraftingDef.recipe_stars(int(crafted.get(rid, 0)))


## Recipe mastery stars across one building's recipes; going up a star needs enough of them.
func building_recipe_stars(building_id: String) -> int:
	var n := 0
	for r in recipes_of(building_id):
		n += recipe_stars(r.id)
	return n


func total_bushels() -> int:
	var n := 0
	for c in bushels:
		n += int(bushels[c])
	return n


func add_bushels(crop_id: String, n: int) -> int:
	var room := maxi(0, Balance.i("crafting.bushel_cap") - total_bushels())
	var got := mini(n, room)
	if got > 0:
		bushels[crop_id] = int(bushels.get(crop_id, 0)) + got
		game.inventory_changed.emit()
	return got


func roll_bushel(crop_id: String) -> String:
	if not game.drops_enabled or not owns_crafting() or game.rng.randf() >= Balance.f("crafting.bushel_chance"):
		return ""
	# FarmVille: each bushel found comes with one extra per mastery star on that crop.
	return crop_id if add_bushels(crop_id, 1 + game.mastery.stars(crop_id)) > 0 else ""


## Bushels still needed for one craft: crop id -> how many more.
func missing_bushels(rid: String) -> Dictionary:
	var out := {}
	var ins := _recipe(rid).inputs()
	for c in ins:
		var short := int(ins[c]) - int(bushels.get(c, 0))
		if short > 0:
			out[c] = short
	return out


func free_slots(obj: Dictionary) -> int:
	return _crafting_def(obj).slots(game.level_of(obj)) - (obj.get("slots", []) as Array).size()


## Why a craft can't start right now, or "" if it can.
func craft_problem(uid: int, rid: String) -> String:
	var obj := game.object_by_uid(uid)
	if obj.is_empty() or not is_crafting(obj):
		return tr("THAT_ISN_T_A_CRAFTING_BUILDING")
	if not recipe_unlocked(obj, rid):
		return tr("UNLOCKS_AT_STARS") % _recipe(rid).star() if _recipe(rid) else tr("UNKNOWN_RECIPE")
	if free_slots(obj) <= 0:
		return tr("EVERY_SLOT_IS_BUSY")
	if not missing_bushels(rid).is_empty():
		return tr("NOT_ENOUGH_BUSHELS")
	return ""


func start_craft(uid: int, rid: String) -> bool:
	if craft_problem(uid, rid) != "":
		return false
	var obj := game.object_by_uid(uid)
	var ins := _recipe(rid).inputs()
	for c in ins:
		bushels[c] = int(bushels[c]) - int(ins[c])
		if int(bushels[c]) <= 0:
			bushels.erase(c)
	(obj["slots"] as Array).append({"r": rid, "done": game.now() + _crafting_def(obj).craft_seconds()})
	game.ribbons.bump("crafts_started", 1)
	game.inventory_changed.emit()
	game.objects_updated()
	return true


## FarmVille's "Buy all ingredients": the missing bushels for gems, then start crafting.
func buy_missing_and_craft(uid: int, rid: String) -> bool:
	var missing := missing_bushels(rid)
	var n := 0
	for c in missing:
		n += int(missing[c])
	var obj := game.object_by_uid(uid)
	if obj.is_empty() or not recipe_unlocked(obj, rid) or free_slots(obj) <= 0:
		return false
	if n > 0 and not game.spend_gems(n * Balance.i("crafting.bushel_gem_cost")):
		game.message.emit(tr("NOT_ENOUGH_GEMS"))
		return false
	for c in missing:
		bushels[c] = int(bushels.get(c, 0)) + int(missing[c]) # may go past the cap: used straight away
	return start_craft(uid, rid)


func crafts_done(obj: Dictionary) -> int:
	var n := 0
	var goods_made := 0
	for slot in obj.get("slots", []):
		if game.now() >= int(slot["done"]):
			n += 1
	return n


## Moves finished crafts into goods. Returns how many finished.
func finish_crafts(uid: int) -> int:
	var obj := game.object_by_uid(uid)
	if obj.is_empty() or not is_crafting(obj):
		return 0
	var still: Array = []
	var n := 0
	var goods_made := 0
	for slot in obj.get("slots", []):
		if game.now() >= int(slot["done"]):
			var rid: String = slot["r"]
			var before := recipe_stars(rid)
			if _recipe(rid).makes_feed():
				_deliver_feed(_recipe(rid))
			else:
				goods[rid] = int(goods.get(rid, 0)) + 1
				goods_made += 1
			crafted[rid] = int(crafted.get(rid, 0)) + 1
			game.add_xp(Balance.i("crafting.craft_xp_per_star") * _recipe(rid).star())
			game.ribbons.bump("crafted", 1)
			if recipe_stars(rid) > before:
				game.message.emit(tr("MASTERY_STARS") % [_recipe(rid).name, recipe_stars(rid)])
			n += 1
		else:
			still.append(slot)
	obj["slots"] = still
	if goods_made > 0:
		game.message.emit((tr("FINISHED_ONE_GOOD") if goods_made == 1 else tr("FINISHED_GOODS")) % goods_made)
	if n > goods_made:
		game.message.emit(tr("FINISHED_FEED"))
	if n > 0:
		game.inventory_changed.emit()
		game.objects_updated()
	return n


## A feed recipe's units go to the Barn as rich feed (what doesn't fit is sold, as feed drops are).
func _deliver_feed(r: RecipeDef) -> void:
	var f := r.feed()
	for i in int(f["units"]):
		game.feeds.add(str(f["type"]), true)


func good_price(rid: String) -> int:
	return _recipe(rid).sell_price(game.crops, recipe_stars(rid))


func good_fuel(rid: String) -> int:
	return _recipe(rid).fuel(recipe_stars(rid))


func sell_good(rid: String) -> int:
	if int(goods.get(rid, 0)) <= 0:
		return 0
	var price := good_price(rid)
	_take_good(rid)
	game.add_coins(price)
	game.ribbons.bump("goods_sold", 1)
	return price


## FarmVille's "Use": a good becomes fuel. Fuel past a full tank fills spare tanks.
func use_good(rid: String) -> int:
	if int(goods.get(rid, 0)) <= 0:
		return 0
	var f := good_fuel(rid)
	_take_good(rid)
	game.vehicles.add_fuel(f)
	return f


func _take_good(rid: String) -> void:
	goods[rid] = int(goods[rid]) - 1
	if int(goods[rid]) <= 0:
		goods.erase(rid)
	game.inventory_changed.emit()
	game.queue_save()


func star_cost(obj: Dictionary) -> Dictionary:
	return _crafting_def(obj).star_cost(game.level_of(obj))


func can_add_star(uid: int, with_gems: bool) -> bool:
	var obj := game.object_by_uid(uid)
	if obj.is_empty() or not is_crafting(obj):
		return false
	var cost := star_cost(obj)
	if cost.is_empty():
		return false
	if with_gems:
		return game.gems >= int(cost["gems"])
	return game.coins >= int(cost["coins"]) and building_recipe_stars(obj["id"]) >= int(cost["recipe_stars"])


func add_star(uid: int, with_gems: bool) -> bool:
	if not can_add_star(uid, with_gems):
		return false
	var obj := game.object_by_uid(uid)
	var cost := star_cost(obj)
	if with_gems:
		game.spend_gems(int(cost["gems"]))
	else:
		game.spend(int(cost["coins"]))
	obj["level"] = game.level_of(obj) + 1
	game.message.emit(
		tr("YOUR_NOW_HAS_STARS_A_NEW") % [
			game.item_data(obj["id"])["name"],
			game.level_of(obj)
		]
	)
	game.objects_updated()
	return true


## The Farmers Market: a few crops' bushels for coins, new each day (standing in for neighbours' stalls).
func _refresh_stall() -> void:
	var today := game.day_number()
	if stall_day == today:
		return
	stall_day = today
	stall = {}
	var pool: Array[String] = []
	for b in game.objects:
		if is_crafting(b):
			for r in recipes_of(b["id"]):
				for c in r.inputs():
					if not pool.has(str(c)):
						pool.append(str(c))
	for k in mini(Balance.i("crafting.stall_crops"), pool.size()):
		var c := pool[game.rng.randi_range(0, pool.size() - 1)]
		pool.erase(c)
		stall[c] = Balance.i("crafting.stall_each")


func market_stall() -> Dictionary:
	_refresh_stall()
	return stall


func bushel_price(crop_id: String) -> int:
	return int(game.crops[crop_id]["sell_price"])


func buy_bushel(crop_id: String) -> bool:
	_refresh_stall()
	if int(stall.get(crop_id, 0)) <= 0 or total_bushels() >= Balance.i("crafting.bushel_cap"):
		return false
	if not game.spend(bushel_price(crop_id)):
		return false
	stall[crop_id] = int(stall[crop_id]) - 1
	add_bushels(crop_id, 1)
	game.queue_save()
	return true


## A new crafting building starts empty at one star.
func on_crafting_built(obj: Dictionary) -> void:
	obj["level"] = 1
	obj["slots"] = []
	stall_day = 0 # restock the Farmers Market with this building's crops
	game.message.emit(tr("BUILT_HARVESTS_NOW_DROP_BUSHELS_TAP") % game.item_data(obj["id"])["name"])
