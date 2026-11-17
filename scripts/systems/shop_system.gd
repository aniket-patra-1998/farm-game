class_name ShopSystem
extends GameSystem
## Buying and selling what stands on the farm: paying for an item (its level, limit and price come from
## BuildingSystem's verdicts), placing what is bought (a frame or chassis, a home's first size), and selling at
## FarmVille's 5% with what lived inside moved back onto the farm. Reached as `Game.shop`; `Game.buy_item`,
## `buy_and_place`, `sell_value` and `sell_object` ask it.


## Buys one of an item, wherever it's going (onto the farm or straight into a home): checks its level,
## takes its price (coins, gems, or a crafting building's rising price), and applies what buying it does
## (its XP, the decorating ribbon, a first vehicle filling the fuel tank). False, with a message, if it
## can't be bought.
func buy_item(item_id: String) -> bool:
	var it := game.item_data(item_id)
	var verdict := game.buildings.can_buy(item_id)  # its game.level, the farm's limit, its price
	if not verdict.ok():
		if verdict.text != "":
			game.message.emit(verdict.text)
		return false
	var price := game.buildings.price_of(item_id)
	if not (game.spend_gems(int(price["gems"])) if price.has("gems") else game.spend(int(price.get("coins", 0)))):
		return false
	var bought_xp := game.buy_xp(item_id)
	if bought_xp > 0:
		game.add_xp(bought_xp)
	if it["kind"] == "decor":
		game.ribbons.bump("decor_bought", 1)
	if it["kind"] == "vehicle":
		game.vehicles.on_vehicle_bought()
		game.rust.bought(item_id)   # (a new one starts clean: docs/RUST.md)
	return true


func buy_and_place(item_id: String, row: int, col: int) -> bool:
	var it := game.item_data(item_id)
	if it.is_empty() or not game.can_place(item_id, row, col) or not game.buy_item(item_id):
		return false
	var obj := {"uid": game.next_uid, "id": item_id, "row": row, "col": col, "t": game.now()}
	if game.special_of(obj) == "garden_shed":
		game.shed.on_shed_built()
	if it["kind"] == "crafting":
		game.crafting.on_crafting_built(obj)
	if it["kind"] == "building":
		obj["level"] = maxi(1, game.finds.tier(str(it.get("home_of", ""))))
		obj["inside"] = {}
		if it.has("build_materials"):
			obj["construction"] = {} # a frame: finished with materials, like FarmVille
			game.message.emit(tr("FRAME_PLACED_TAP_IT_TO_ADD") % it["name"])
		else:
			game.message.emit(tr("BUILT_OPEN_IT_TO_MOVE_ANIMALS") % it["name"])
	elif it["kind"] == "vehicle":
		if it.has("build_materials"):
			obj["construction"] = {} # the Combine's chassis, finished with Vehicle Parts
			game.message.emit(tr("CHASSIS_PLACED_TAP_IT_TO_ADD") % it["name"])
		else:
			game.message.emit(tr("BOUGHT_PICK_IT_IN_THE_TOOLBAR") % it["name"])
	game.next_uid += 1
	game.grass_over(item_id, row, col)
	game.add_object(obj)
	game.objects_updated()
	return true


## What selling an object returns: 5% of its price, as in FarmVille.
func sell_value(obj: Dictionary) -> int:
	var d := game.catalog.get_def(obj["id"])
	return (d as PlaceableDef).sell_value() if d is PlaceableDef else 0


## Sells an object. Animals, trees or vehicles inside a building move back onto the farm first.
func sell_object(uid: int) -> bool:
	var o := game.object_by_uid(uid)
	var verdict := game.buildings.can_sell(o)
	if not verdict.ok():
		game.message.emit(verdict.text)
		return false
	var held: Array[String] = []
	for id in o.get("inside", {}):
		for k in int(o["inside"][id]):
			held.append(id)
	game.remove_object(o)
	if held.size() > 0:
		# Room check: the building's own tiles are free game.now that it's gone.
		var free := 0
		for r in game.farm_size:
			for c in game.farm_size:
				var i := game.index_of(r, c)
				if game.plots[i].get("state", "grass") == "grass" and not game.is_occupied(i):
					free += 1
		if free < held.size():
			game.add_object(o)
			game.message.emit(tr("NOT_ENOUGH_OPEN_GRASS_FOR_THE") % held.size())
			return false
		for id in held:
			game.place_somewhere(id)
	var value := game.sell_value(o)
	game.add_coins(value)
	game.ribbons.bump("items_sold", 1)
	var moved := (tr("MOVED_OUT_ONTO_THE_FARM") % held.size()) if held.size() > 0 else ""
	game.message.emit(tr("SOLD_THE_FOR_COINS") % [game.item_data(o["id"])["name"], value, moved])
	game.inventory_changed.emit()
	game.objects_updated()
	return true
