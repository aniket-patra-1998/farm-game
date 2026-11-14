class_name BuildingSystem
extends GameSystem
## The rules a building answers to, in one place, each answered with a Verdict: yes, or no and why.
##   can_buy      its level, its price, and how many one farm may have (FarmVille: 5 Dairy Farms, 3
##                crafting buildings in all, 1 of most others)
##   can_expand   the next size: not past the biggest, not while it's still a frame, materials in hand
##   can_sell     not the Barn or Farmhouse, not with anyone inside (they'd have nowhere to go)
## and the materials a frame or a size still needs can be bought with gems, as FarmVille sold them for
## Farm Cash. Who may move into a home is the housing system's (Game.homes.fit), which answers the same way.
## The UI asks here and shows the reason; it never repeats a rule. Reached as `Game.buildings`; it keeps
## no state of its own.

enum Why { OK, UNKNOWN, LEVEL, COINS, GEMS, LIMIT, GROUP_LIMIT, BIGGEST, FRAME, MATERIALS, SOMEONE_INSIDE, KEPT,
	REQUIRES, OFF_FARM, TAKEN, PLANTED, CROWDED, WRONG_KIND, FULL, NOT_BUILT, HAS_ONE, BARN_BROKEN, BUILD_FIRST,
	CANT_STORE, NOT_A_FRAME }

## How a home's fit (HousingSystem.Fit, what lights homes up while dragging) reads as a rule's answer.
const FIT_WHY := {
	HousingSystem.Fit.FITS: Why.OK,
	HousingSystem.Fit.WRONG_KIND: Why.WRONG_KIND,
	HousingSystem.Fit.FULL: Why.FULL,
	HousingSystem.Fit.NOT_BUILT: Why.NOT_BUILT,
	HousingSystem.Fit.HAS_ONE: Why.HAS_ONE,
	HousingSystem.Fit.BARN_BROKEN: Why.BARN_BROKEN,
	HousingSystem.Fit.BUILD_FIRST: Why.BUILD_FIRST,
}

## How many of one item a farm may hold, by kind (FarmVille capped these too). Buildings are BuildingDef.limit().
## Buildings that stay where they are: the starter Barn and the Farmhouse.
const KEPT := ["barn", "farmhouse"]


## Whether something can be done, and if not, why (with the message to show).
class Verdict:
	var why: BuildingSystem.Why
	var text: String     ## what to tell the player (empty when it's a yes)
	var short: String    ## a word or two for a button ("Level 12", "1 per farm")

	func _init(reason: BuildingSystem.Why, words := "", label := "") -> void:
		why = reason
		text = words
		short = label

	func ok() -> bool:
		return why == BuildingSystem.Why.OK


static func yes() -> Verdict:
	return Verdict.new(Why.OK)


## How many of an item the farm holds in all: standing on the farm (frames included: a frame is one of them,
## half-built), inside a home or Garage, or put away in the barn.
func owned(id: String) -> int:
	var n := 0
	for o in game.objects:
		if o["id"] == id:
			n += 1
		n += int((o.get("inside", {}) as Dictionary).get(id, 0))
	for o in game.storage.stored:
		if o["id"] == id:
			n += 1
	return n


## How many of an item one farm may have.
func limit_of(id: String) -> int:
	if game.is_building_item(id):
		return game.building_def(id).limit()
	match str(game.item_data(id).get("kind", "")):
		"vehicle":
			return Balance.i("buildings.limit_vehicle")
		"decor":
			return Balance.i("buildings.limit_decor")
	return Balance.i("buildings.limit_living")


## How many of a limit group's buildings are on the farm.
func group_owned(group: String) -> int:
	var n := 0
	for o in game.objects:
		var def := game.building_def(str(o["id"]))
		if def != null and def.limit_group() == group:
			n += 1
	return n


## Old saves could hold a vehicle both standing on the farm and in a Garage. Keeps one of each vehicle (the one
## in the Garage first), and gives the coins for the others back. Returns how many were taken away.
func trim_extra_vehicles() -> int:
	var removed := 0
	for id: String in game.item_order:
		if game.item_data(id).get("kind", "") != "vehicle":
			continue
		while owned(id) > Balance.i("buildings.limit_vehicle"):
			var loose: Dictionary = {}
			for o in game.objects:
				if o["id"] == id:
					loose = o
					break
			if not loose.is_empty():
				game.remove_object(loose)
			else:
				var found := false
				for o in game.objects:
					var inside: Dictionary = o.get("inside", {})
					if int(inside.get(id, 0)) > 0:
						inside[id] = int(inside[id]) - 1
						if int(inside[id]) <= 0:
							inside.erase(id)
						found = true
						break
				if not found:
					break
			game.coins += int(game.item_data(id).get("cost", 0))
			removed += 1
	return removed


## Can one be bought now? Its level, then how many the farm may have, then its price.
func can_buy(id: String) -> Verdict:
	var it := game.item_data(id)
	if it.is_empty():
		return Verdict.new(Why.UNKNOWN)
	var unlock := int(it.get("unlock_level", 1))
	if game.level() < unlock:
		return Verdict.new(Why.LEVEL, tr("UNLOCKS_AT_LEVEL") % [it["name"], unlock], tr("LEVEL") % unlock)
	var unmet := Requirements.first_unmet(game, id)
	if not unmet.is_empty():
		return Verdict.new(Why.REQUIRES, tr("NEEDS_X") % unmet["text"], tr("NEEDS_SHORT"))
	var limit := limit_of(id)
	if owned(id) >= limit:
		return Verdict.new(Why.LIMIT, tr("LIMIT_REACHED") % [limit, it["name"]], tr("LIMIT_SHORT") % limit)
	var def := game.building_def(id)
	if def != null:
		if def.limit_group() != "" and group_owned(def.limit_group()) >= def.group_limit():
			return Verdict.new(Why.GROUP_LIMIT, tr("GROUP_LIMIT_REACHED") % def.group_limit(),
				tr("LIMIT_SHORT") % def.group_limit())
	var price := price_of(id)
	if price.has("gems") and game.gems < int(price["gems"]):
		return Verdict.new(Why.GEMS, tr("NOT_ENOUGH_GEMS_FOR_A") % it["name"])
	if price.has("coins") and game.coins < int(price["coins"]):
		return Verdict.new(Why.COINS, tr("NOT_ENOUGH_COINS_FOR_A") % it["name"])
	return yes()


## What one costs now: {"coins": n} or {"gems": n} (a crafting building's price rises with each owned).
func price_of(id: String) -> Dictionary:
	var it := game.item_data(id)
	if it.get("kind", "") == "crafting":
		return game.crafting.crafting_price(id)
	if it.has("gem_cost"):
		return {"gems": int(it["gem_cost"])}
	return {"coins": int(it.get("cost", 0))}


## Can building `b` grow to its next size now?
func can_expand(b: Dictionary) -> Verdict:
	if b.is_empty() or not game.is_home(b):
		return Verdict.new(Why.UNKNOWN)
	if game.under_construction(b):
		return Verdict.new(Why.FRAME, tr("FINISH_IT_FIRST"))
	if game.building_def(str(b["id"])).grows_with_finds():
		return Verdict.new(Why.BIGGEST)  # it grows by itself, as more are found
	var need := game.land.expansion_needs(b)
	if need.is_empty():
		return Verdict.new(Why.BIGGEST, tr("FULLY_EXPANDED"))
	var short := missing(need)
	if not short.is_empty():
		return Verdict.new(Why.MATERIALS, tr("MATERIALS_SHORT") % describe(short))
	return yes()


## Can it be sold? Not the Barn or Farmhouse, nor a home with anyone inside.
func can_sell(o: Dictionary) -> Verdict:
	if o.is_empty() or o.get("stray", false):
		return Verdict.new(Why.UNKNOWN, tr("THAT_CAN_T_BE_SOLD"))
	if KEPT.has(str(o["id"])):
		return Verdict.new(Why.KEPT, tr("THAT_CAN_T_BE_SOLD"))
	return yes()


## Can `item_id` stand at row, col (its top-left tile)? On the farm, on grass or empty plowed plots, never on
## crops or other things (`ignore_uid`: the thing being moved). `strict` also keeps a tree and a building off
## each other's edges (a tree's crown overhangs its tile, so it is never planted hard against a wall); laying
## the farm back down after loading is not strict, so no save moves.
func can_place(item_id: String, row: int, col: int, ignore_uid := -1, strict := true) -> Verdict:
	var fp := game.footprint(item_id)
	var n := game.farm_size
	if row < 0 or col < 0 or row + fp.y > n or col + fp.x > n:
		return Verdict.new(Why.OFF_FARM, tr("PLACE_OFF_FARM"))
	for r in range(row, row + fp.y):
		for c in range(col, col + fp.x):
			var i := game.index_of(r, c)
			var holder := game.holder_at(i)
			if holder != -1 and holder != ignore_uid:
				return Verdict.new(Why.TAKEN, tr("PLACE_TAKEN") % game.item_data(game.object_by_uid(holder)["id"])["name"])
			if game.plots[i].get("state", "grass") == "planted":
				return Verdict.new(Why.PLANTED, tr("PLACE_PLANTED"))
	if strict and _crowds_neighbour(item_id, row, col, fp, ignore_uid):
		return Verdict.new(Why.CROWDED, tr("PLACE_CROWDED"))
	return yes()


## Whether a tree here would touch a building, or a building here a tree: something of the other kind on the ring
## of tiles around the footprint (diagonals too).
func _crowds_neighbour(item_id: String, row: int, col: int, fp: Vector2i, ignore_uid: int) -> bool:
	var kind: String = game.item_data(item_id).get("kind", "")
	if kind != "tree" and kind != "building":
		return false
	var other := "building" if kind == "tree" else "tree"
	var n := game.farm_size
	for r in range(row - 1, row + fp.y + 1):
		for c in range(col - 1, col + fp.x + 1):
			if r < 0 or c < 0 or r >= n or c >= n:
				continue
			if r >= row and r < row + fp.y and c >= col and c < col + fp.x:
				continue
			var uid := game.holder_at(game.index_of(r, c))
			if uid == -1 or uid == ignore_uid:
				continue
			if str(game.item_data(game.object_by_uid(uid).get("id", "")).get("kind", "")) == other:
				return true
	return false


## Can building `b` take one more `item_id` from `source` ({"uid"}, {"stored"}, {"buy"}: HousingSystem)?
func can_move_in(b: Dictionary, item_id: String, source := {}) -> Verdict:
	var fit := game.homes.fit(b, item_id, source)
	if fit == HousingSystem.Fit.FITS:
		return yes()
	return Verdict.new(FIT_WHY[fit], game.homes.refusal(b, item_id, fit))


## Can `o` be put away in the Barn? Trees, animals and scenery can; the Barn must be repaired and have room.
func can_store(o: Dictionary) -> Verdict:
	if not game.storage.can_store(o):
		return Verdict.new(Why.CANT_STORE, tr("THAT_CAN_T_GO_IN_THE"))
	if not game.storage.barn_repaired():
		return Verdict.new(Why.BARN_BROKEN, tr("FIX_THE_BARN_FIRST_TO_STORE"))
	if game.storage.stored.size() >= game.storage.total_limit():
		return Verdict.new(Why.FULL, tr("THE_BARN_IS_FULL"))
	return yes()


## Can frame `b` be finished now: is it a frame, and are all the materials it still needs in hand?
func can_finish(b: Dictionary) -> Verdict:
	if b.is_empty() or not game.under_construction(b):
		return Verdict.new(Why.NOT_A_FRAME)
	var short := missing(game.land.construction_needs(b))
	if not short.is_empty():
		return Verdict.new(Why.MATERIALS, tr("MATERIALS_SHORT") % describe(short))
	return yes()


## Can `o` be turned? Only square things turn (so nothing changes size), and a building only if its data says so.
func can_rotate(o: Dictionary) -> Verdict:
	if not game.can_rotate(o):
		return Verdict.new(Why.UNKNOWN, tr("BUILDINGS_AND_BIG_PIECES_CAN_T"))
	return yes()


## What's still missing of `need` from the materials held: {material: count}, empty when all are there.
func missing(need: Dictionary) -> Dictionary:
	var out := {}
	for m in need:
		var short := int(need[m]) - int(game.parts.get(m, 0))
		if short > 0:
			out[m] = short
	return out


## Gems to buy what's missing of `need`.
func gems_for(need: Dictionary) -> int:
	var n := 0
	for m in missing(need):
		n += int(missing(need)[m])
	return n * Balance.i("buildings.material_gems")


## Buys what's missing of `need` with gems (FarmVille sold materials for Farm Cash). False, with a
## message, if there's nothing to buy or not enough gems.
func buy_missing(need: Dictionary) -> bool:
	var short := missing(need)
	if short.is_empty():
		return false
	if not game.spend_gems(gems_for(need)):
		game.message.emit(tr("NOT_ENOUGH_GEMS_FOR_MATERIALS"))
		return false
	for m in short:
		game.parts[m] = int(game.parts.get(m, 0)) + int(short[m])
	game.inventory_changed.emit()
	game.queue_save()
	return true


## Materials as words: "3 Bricks, 2 Nails".
static func describe(materials: Dictionary) -> String:
	var parts: Array[String] = []
	for m in materials:
		parts.append("%d %s" % [int(materials[m]), GameState.part_names.get(m, m)])
	return ", ".join(PackedStringArray(parts))
