class_name BarnStorage
extends GameSystem
## The barn: repairing it, and storing objects away.
## Part of the game state: reached as `Game.storage`; shared state is on `game`.

const GIFT_BOX_LIMIT := 9999        # what spills past the barn waits in the gift box, up to this many
const BUNCH_DAYS := 14              # a placed Perfect Bunch lasts 14 days

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
		if o["id"] == "barn":
			return o
	return {}


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


## Everything that can be kept: the barn's own space and the gift box beyond it.
func total_limit() -> int:
	return barn_capacity() + GIFT_BOX_LIMIT


## How many things have spilled past the barn into the gift box.
func in_gift_box() -> int:
	return maxi(stored.size() - barn_capacity(), 0)


## Trees, animals and scenery can be stored; shelters, the barn and strays can't.
func can_store(obj: Dictionary) -> bool:
	if obj.is_empty() or obj.get("stray", false):
		return false
	var k := game.kind_of(obj)
	return k == "tree" or k == "animal" or k == "decor"


func store_object(uid: int) -> bool:
	var o := game.object_by_uid(uid)
	if not barn_repaired():
		game.message.emit(tr("FIX_THE_BARN_FIRST_TO_STORE"))
		return false
	if not can_store(o):
		game.message.emit(tr("THAT_CAN_T_GO_IN_THE"))
		return false
	if stored.size() >= total_limit():
		game.message.emit(tr("THE_BARN_IS_FULL"))
		return false
	game.remove_object(o)
	o.erase("row")
	o.erase("col")
	stored.append(o)
	game.message.emit(tr("STORED_IN_THE_BARN" if stored.size() <= barn_capacity() else "SENT_TO_THE_GIFT_BOX")
		% game.item_data(o["id"])["name"])
	game.inventory_changed.emit()
	game.objects_updated()
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
		o["expires"] = game.now() + BUNCH_DAYS * 86400
	game.grass_over(o["id"], row, col)
	game.add_object(o)
	game.inventory_changed.emit()
	game.objects_updated()
	return true
