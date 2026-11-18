class_name BarnStorage
extends GameSystem
## The barn: repairing it, and storing objects away.
## Part of the game state: reached as `Game.storage`; shared state is on `game`.

const BARN := "barn"     # not-ui (welcome: where a new thing went)
const INBOX := "inbox"   # not-ui

var stored: Array = []             # objects put away in the barn (no row or col)


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
	stored = []


func save_to(data: Dictionary) -> void:
	data["stored"] = stored


func load_from(data: Dictionary) -> void:
	stored = []
	for o in data.get("stored", []):
		if game.items.has(o.get("id", "")):
			o["uid"] = int(o["uid"])
			o["t"] = int(o.get("t", 0))
			stored.append(o)


func barn() -> Dictionary:
	for o in game.objects:
		if is_barn(o):
			return o
	return {}


## Whether `o` is the Barn: by its catalog class (a BarnDef), never by its id.
func is_barn(o: Dictionary) -> bool:
	return not o.is_empty() and game.catalog.get_def(str(o["id"])) is BarnDef


func barn_repaired() -> bool:
	var b := barn()
	return not b.is_empty() and not b.get("broken", false)


func repair_needs() -> Dictionary:
	return game.item_data("barn").get("repair_parts", {})


func can_repair_barn() -> bool:
	var b := barn()
	if b.is_empty() or not b.get("broken", false):
		return false
	var need := repair_needs()
	for p in need:
		if int(game.parts.get(p, 0)) < int(need[p]):
			return false
	return true


func repair_barn() -> bool:
	if not can_repair_barn():
		return false
	var need := repair_needs()
	for p in need:
		game.parts[p] = int(game.parts[p]) - int(need[p])
	var b := barn()
	b.erase("broken")
	var it := game.item_data("barn")
	game.add_coins(int(it.get("repair_coins", 0)))
	game.add_xp(int(it.get("repair_xp", 0)))
	game.message.emit(tr("THE_BARN_IS_FIXED_USE_THE"))
	game.ribbons.bump("buildings_repaired", 1)
	game.inventory_changed.emit()
	game.objects_updated()
	return true


func barn_capacity() -> int:
	var b := barn()
	return game.capacity(b) if not b.is_empty() else game.building_def("barn").capacity(1)


## Trees, animals and scenery can be stored; shelters, the barn and strays can't.
func storable_kind(obj: Dictionary) -> bool:
	if obj.is_empty() or obj.get("stray", false):
		return false
	var k := game.kind_of(obj)
	return k == "tree" or k == "animal" or k == "decor"


func store_object(uid: int) -> bool:
	var o := game.object_by_uid(uid)
	var verdict := game.buildings.can_store(o)
	if not verdict.ok():
		game.message.emit(verdict.text)
		return false
	game.remove_object(o)
	o.erase("row")
	o.erase("col")
	if has_room():
		stored.append(o)
		game.message.emit(tr("STORED_IN_THE_BARN") % game.item_data(o["id"])["name"])
	else:   # (the Barn full: it waits in the inbox, FarmVille's Gift Box, as it was)
		_send_on(o)
		game.message.emit(tr("SENT_TO_THE_GIFT_BOX") % game.item_data(o["id"])["name"])
	game.inventory_changed.emit()
	game.objects_updated()
	return true


## Where a new thing arrives (a baby born, a prize won, a breed traded for): the Barn while it is repaired and its
## own space has room, else the inbox (FarmVille's Gift Box, from the farm), never dropped on the farm or into a
## home. `keep`: its own fields, kept on the way (a young one's "becomes"). Returns where it went: BARN or INBOX.
func welcome(item_id: String, keep := {}) -> String:
	if barn_repaired() and receive(item_id, keep):
		return BARN
	game.social.deliver({"what": InboxItem.ITEM, "id": item_id, "n": 1, "keep": keep})
	return INBOX


## Sends a thing on to the inbox with its own fields (what isn't its place or its uid).
func _send_on(o: Dictionary) -> void:
	var keep := o.duplicate(true)
	for f in ["uid", "id", "t", "row", "col"]:
		keep.erase(f)
	game.social.deliver({"what": InboxItem.ITEM, "id": str(o["id"]), "n": 1, "keep": keep})


## After a load: what an older save kept past the Barn's space (it once had an overflow of its own) goes to the
## inbox, the one Gift Box, newest first out. Returns how many moved.
func spill_over() -> int:
	var moved := 0
	while stored.size() > barn_capacity():
		_send_on(stored.pop_back())
		moved += 1
	return moved


## The message for `item_id` arriving at `went` (welcome): "A calf was born! It's in the Barn." with `key` the
## news ("A_WAS_BORN") and the place after it.
func welcome_words(key: String, item_id: String, went: String) -> String:
	return tr(key) % str(game.item_data(item_id)["name"]) + " " + tr("ARRIVED_IN_BARN" if went == BARN
		else "ARRIVED_IN_INBOX")


## Whether `n` more things fit in the Barn's own space (past it, things wait in the inbox).
func has_room(n := 1) -> bool:
	return stored.size() + n <= barn_capacity()


## Takes in a new `item_id` straight to the Barn (a grown baby, a gift), with its own fields `keep`. Returns false
## when the Barn is full. `to_hand`: it is taken out at once to be placed, so it may go one past the space (the
## hand slot; given back by `spill_over` if the hand is emptied).
func receive(item_id: String, keep := {}, to_hand := false) -> bool:
	if not has_room(0 if to_hand else 1):
		return false
	var o := keep.duplicate(true)
	o.merge({"uid": game.next_uid, "id": item_id, "t": game.now()}, true)
	stored.append(o)
	game.next_uid += 1
	game.inventory_changed.emit()
	return true


## Takes one stored thing out of the Barn to go straight into a home (it must be the item expected).
func take_out(index: int, item_id: String) -> bool:
	if index < 0 or index >= stored.size() or stored[index]["id"] != item_id:
		return false
	stored.remove_at(index)
	return true


func place_from_storage(index: int, row: int, col: int) -> bool:
	if index < 0 or index >= stored.size():
		return false
	var o: Dictionary = stored[index]
	if not game.can_place(o["id"], row, col):
		return false
	stored.remove_at(index)
	o["row"] = row
	o["col"] = col
	o["t"] = game.now() # production restarts when it comes back out
	if o.get("bunch", false) and not o.has("expires"):
		o["expires"] = game.now() + Balance.i("barn.bunch_days") * 86400
	game.grass_over(o["id"], row, col)
	game.add_object(o)
	game.inventory_changed.emit()
	game.objects_updated()
	return true
