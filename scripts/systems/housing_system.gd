class_name HousingSystem
extends GameSystem
## Homes, the FarmVille way: an animal (or tree, or vehicle) lives only in a building made for its kind
## (the catalog's `holds`: cows in the Dairy Farm, chickens and turkeys in the Coop, any baby in the
## Nursery Barn), and the Barn stores anything. Dragging one over the farm lights up the homes that take
## it; dropping it on one moves it in, whether it was standing on the farm, waiting in the Barn, or just
## bought from the market. Reached as `Game.homes`.

## Whether a building can take one more of something, and if not, why.
enum Fit { FITS, WRONG_KIND, FULL, NOT_BUILT, HAS_ONE, BARN_BROKEN }


func _init(owner: GameState) -> void:
	super(owner)


## Can this building (or the Barn) take one more of `item_id`? `uid` is the object being moved, if it's
## already on the farm (only the Barn takes things that are already placed and isn't a shop).
func fit(building: Dictionary, item_id: String, uid := -1) -> Fit:
	if building.is_empty():
		return Fit.WRONG_KIND
	if building["id"] == "barn":
		var o := game.object_by_uid(uid)
		if uid == -1 or not game.storage.can_store(o):
			return Fit.WRONG_KIND
		if not game.storage.barn_repaired():
			return Fit.BARN_BROKEN
		return Fit.FULL if game.storage.stored.size() >= game.storage.barn_capacity() else Fit.FITS
	if not game.is_building(building) or not game.building_accepts(building, item_id):
		return Fit.WRONG_KIND
	if game.under_construction(building):
		return Fit.NOT_BUILT
	if game.is_one_each(building, item_id):
		return Fit.HAS_ONE if game.has_inside(building, item_id) else Fit.FITS
	return Fit.FULL if game.inside_total(building) >= game.capacity(building) else Fit.FITS


## Every building on the farm that takes this kind of thing, full or not (to light up while dragging it).
func homes_for(item_id: String, uid := -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in game.objects:
		if int(b["uid"]) != uid and fit(b, item_id, uid) != Fit.WRONG_KIND:
			out.append(b)
	return out


## Why a drop on this building didn't work, for the message.
func refusal(building: Dictionary, item_id: String, why: Fit) -> String:
	var home := str(game.item_data(building["id"]).get("name", ""))
	var thing := str(game.item_data(item_id).get("name", ""))
	match why:
		Fit.FULL:
			return tr("HOME_IS_FULL") % home
		Fit.NOT_BUILT:
			return tr("HOME_NOT_BUILT") % home
		Fit.HAS_ONE:
			return tr("HOME_HAS_ONE") % [home, thing]
		Fit.BARN_BROKEN:
			return tr("FIX_THE_BARN_FIRST_TO_STORE")
	return tr("HOME_WRONG_KIND") % [thing, home]


## Drops something on a building: moves a placed object in (`source` {"uid": n}), takes one out of the
## Barn into it ({"stored": index}), or buys one straight into it ({}). Returns true if it moved in.
func put_in_home(building_uid: int, item_id: String, source: Dictionary) -> bool:
	var b := game.object_by_uid(building_uid)
	var uid := int(source.get("uid", -1))
	var why := fit(b, item_id, uid)
	if why != Fit.FITS:
		game.message.emit(refusal(b, item_id, why))
		return false
	if b["id"] == "barn":
		return game.storage.store_object(uid)
	if uid != -1:
		var o := game.object_by_uid(uid)
		if o.is_empty() or o["id"] != item_id or not can_move_in(b, o):
			return false
		game.objects.erase(o)
	elif source.has("stored"):
		if not game.storage.take_out(int(source["stored"]), item_id):
			return false
	elif not game.pay_for(item_id):
		return false
	house(b, item_id)
	game.message.emit(tr("MOVED_INTO_HOME") % [str(game.item_data(item_id)["name"]),
		str(game.item_data(b["id"])["name"])])
	game.inventory_changed.emit()
	game.objects_updated()
	return true


## Moves every loose animal or tree of the right type into the building, up to its capacity.
func fill_building(uid: int) -> int:
	var b := game.object_by_uid(uid)
	if b.is_empty() or not game.is_building(b) or game.under_construction(b):
		return 0
	var moved := 0
	var keep: Array = []
	for o in game.objects:
		if can_move_in(b, o) and fit(b, o["id"]) == Fit.FITS:
			house(b, o["id"])
			moved += 1
		else:
			keep.append(o)
	if moved == 0:
		return 0
	game.objects = keep
	game.message.emit(tr("MOVED_INTO_THE") % [moved, game.item_data(b["id"])["name"]])
	game.objects_updated()
	return moved


## How many loose animals or trees on the farm this building would take.
func loose_matching(building: Dictionary) -> int:
	var n := 0
	for o in game.objects:
		if can_move_in(building, o):
			n += 1
	return n


## A loose animal or tree on the farm that this building takes (not a building, a stray or a frame).
func can_move_in(building: Dictionary, o: Dictionary) -> bool:
	return not game.is_building(o) and not o.get("stray", false) and not game.under_construction(o) \
		and game.building_accepts(building, o["id"])


## Puts one into a building (the one step every way in shares). The building's first cycle starts when
## the first one moves in; a baby in the Nursery Barn starts growing up.
func house(b: Dictionary, item_id: String) -> void:
	var inside: Dictionary = b.get_or_add("inside", {})
	if game.inside_total(b) == 0:
		b["t"] = game.now()
	if game.is_one_each(b, item_id):
		inside[item_id] = 1  # the one bull or stallion
		return
	inside[item_id] = int(inside.get(item_id, 0)) + 1
	if b["id"] == "nursery_barn":
		(b.get_or_add("growing", []) as Array).append([item_id, 0])
