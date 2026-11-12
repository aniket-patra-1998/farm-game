class_name GardenShedSystem
extends GameSystem
## Perfect Bunches from flower harvests, kept in the Garden Shed and placed as decorations.
## Part of the game state: reached as `Game.shed`; shared state is on `game`.


var bunches: Array = []            # Perfect Bunches held: flower crop ids


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
	bunches = []


func save_to(data: Dictionary) -> void:
	data["bunches"] = bunches


func load_from(data: Dictionary) -> void:
	bunches = (data.get("bunches", []) as Array).duplicate()


func bunch_cap() -> int:
	for o in game.objects:
		if o["id"] == "garden_shed":
			return game.capacity(o)
	return Balance.i("shed.bunch_cap_no_shed")


func add_bunch(flower: String) -> bool:
	if bunches.size() >= bunch_cap():
		return false
	bunches.append(flower)
	game.inventory_changed.emit()
	game.objects_changed.emit()  # the shed shows its pots
	return true


func roll_bunch(crop_id: String, i: int) -> String:
	var chance := Balance.f("shed.perfect_bunch_chance")
	if not game.drops_enabled or not game.crops[crop_id].get("flower", false) or game.rng.randf() >= chance:
		return ""
	if not add_bunch(crop_id):
		return ""
	game.ribbons.bump("perfect_bunches", 1)
	game.found.emit(i, tr("PERFECT_BUNCH_OF") % game.crops[crop_id]["name"])
	return crop_id


## Takes a bunch out of the shed, ready to place: it goes to the end of the storage list. Returns its index.
func unpack_bunch(k: int) -> int:
	if k < 0 or k >= bunches.size():
		return -1
	var flower: String = bunches[k]
	bunches.remove_at(k)
	game.storage.stored.append(
		{"uid": game.next_uid, "id": "perfect_bunch", "flower": flower, "t": game.now(), "bunch": true}
	)
	game.next_uid += 1
	game.inventory_changed.emit()
	game.objects_changed.emit()
	return game.storage.stored.size() - 1


## Placed bunches wilt away after BUNCH_DAYS days.
func expire_bunches() -> void:
	var before := game.objects.size()
	game.set_objects(game.objects.filter(
		func(o): return not (o["id"] == "perfect_bunch" and game.now() >= int(o.get("expires", game.now() + 1)))
	))
	if game.objects.size() != before:
		game.message.emit(tr("A_PERFECT_BUNCH_HAS_WILTED_AWAY"))
		game.objects_updated()


## The Garden Shed comes with free Perfect Bunches of flowers you've unlocked.
func on_shed_built() -> void:
	var flowers: Array[String] = []
	for c in game.crop_order:
		if game.crops[c].get("flower", false) and int(game.crops[c]["unlock_level"]) <= game.level():
			flowers.append(c)
	for k in Balance.i("shed.shed_free_bunches"):
		if not flowers.is_empty():
			bunches.append(flowers[game.rng.randi_range(0, flowers.size() - 1)])
	game.message.emit(tr("GARDEN_SHED_BUILT_IT_HOLDS_PERFECT") % Balance.i("shed.shed_free_bunches"))
