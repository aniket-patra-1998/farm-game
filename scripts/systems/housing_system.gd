class_name HousingSystem
extends GameSystem
## Homes, the FarmVille way: an animal (or tree, or vehicle) lives only in a building made for its kind
## (the catalog's `holds`: cows in the Dairy Farm, chickens and turkeys in the Coop, any baby in the
## Nursery Barn), and a storage building (the Barn) keeps anything that's already on the farm. Dragging
## one over the farm lights up the homes that take it; dropping it on one moves it in, whether it was
## standing on the farm, waiting in the Barn, or just bought from the market. Reached as `Game.homes`.
##
## Where a thing comes from is a `source`: {"uid": n} for one on the farm, {"stored": index} for one in
## the Barn, {"buy": true} for one being bought, or {} to ask about the kind of thing in general.

## Whether a building can take one more of something, and if not, why.
enum Fit { FITS, WRONG_KIND, FULL, NOT_BUILT, HAS_ONE, BARN_BROKEN, BUILD_FIRST }


## Can this building take one more `item_id` from `source`?
func fit(building: Dictionary, item_id: String, source := {}) -> Fit:
	if building.is_empty():
		return Fit.WRONG_KIND
	var def := game.catalog.get_def(building["id"]) as BuildingDef  # the Barn too
	if def == null:
		return Fit.WRONG_KIND
	if def.stores_anything():
		return _storage_fit(source)
	if not def.accepts(item_id, str(game.item_data(item_id).get("kind", ""))):
		return Fit.WRONG_KIND
	if source.get("buy", false) and not game.can_buy_into_home(item_id):
		return Fit.BUILD_FIRST
	if game.under_construction(game.object_by_uid(int(source.get("uid", -1)))):
		return Fit.BUILD_FIRST  # a frame or chassis is finished where it stands
	if game.under_construction(building):
		return Fit.NOT_BUILT
	if game.is_one_each(building, item_id):
		return Fit.HAS_ONE if game.has_inside(building, item_id) else Fit.FITS
	return Fit.FULL if game.inside_total(building) >= game.capacity(building) else Fit.FITS


## The Barn stores only what's already on the farm: nothing can be bought into it, nor moved from it to it.
func _storage_fit(source: Dictionary) -> Fit:
	var o := game.object_by_uid(int(source.get("uid", -1)))
	if o.is_empty() or not game.storage.can_store(o):
		return Fit.WRONG_KIND
	if not game.storage.barn_repaired():
		return Fit.BARN_BROKEN
	return Fit.FULL if game.storage.stored.size() >= game.storage.barn_capacity() else Fit.FITS


## Every building on the farm that takes this, full or not, with how it fits: [[building, Fit], ...].
## Worked out once when dragging starts (and again when the farm changes), not every frame.
func homes_for(item_id: String, source := {}) -> Array:
	var out := []
	var moving := int(source.get("uid", -1))
	for b in game.objects:
		if int(b["uid"]) == moving:
			continue
		var f := fit(b, item_id, source)
		if f != Fit.WRONG_KIND:
			out.append([b, f])
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
		Fit.BUILD_FIRST:
			return tr("HOME_BUILD_ON_FARM_FIRST") % thing
	return tr("HOME_WRONG_KIND") % [thing, home]


## Drops something from `source` on a building. Returns true if it moved in (or was stored).
func put_in_home(building_uid: int, item_id: String, source: Dictionary) -> bool:
	var b := game.object_by_uid(building_uid)
	var why := fit(b, item_id, source)
	if why != Fit.FITS:
		game.message.emit(refusal(b, item_id, why))
		return false
	var uid := int(source.get("uid", -1))
	if (game.catalog.get_def(b["id"]) as BuildingDef).stores_anything():
		return game.storage.store_object(uid)
	if uid != -1:
		var o := game.object_by_uid(uid)
		if o.is_empty() or o["id"] != item_id or not can_move_in(b, o):
			return false
		game.remove_object(o)
	elif source.has("stored"):
		if not game.storage.take_out(int(source["stored"]), item_id):
			return false
	elif not source.get("buy", false) or not game.buy_item(item_id):
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
		if can_move_in(b, o) and fit(b, o["id"], {"uid": int(o["uid"])}) == Fit.FITS:
			house(b, o["id"])
			moved += 1
		else:
			keep.append(o)
	if moved == 0:
		return 0
	game.set_objects(keep)
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


## A loose animal, tree or vehicle on the farm that this building houses (not a building, a stray, or a
## frame or chassis still being built).
func can_move_in(building: Dictionary, o: Dictionary) -> bool:
	return not game.is_building(o) and not o.get("stray", false) and not game.under_construction(o) \
		and game.building_accepts(building, o["id"])


## Puts one into a building (the one step every way in shares). The building's first cycle starts when
## the first one moves in; a baby in a nursery starts growing up.
func house(b: Dictionary, item_id: String) -> void:
	var inside: Dictionary = b.get_or_add("inside", {})
	if game.inside_total(b) == 0:
		b["t"] = game.now()
	if game.is_one_each(b, item_id):
		inside[item_id] = 1  # the one bull or stallion
		return
	inside[item_id] = int(inside.get(item_id, 0)) + 1
	if (game.catalog.get_def(b["id"]) as BuildingDef).grows_young():
		(b.get_or_add("growing", []) as Array).append([item_id, 0])
