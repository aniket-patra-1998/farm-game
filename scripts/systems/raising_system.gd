class_name RaisingSystem
extends GameSystem
## Raising young animals, FarmVille's way: babies don't grow up by being harvested, they grow on Animal Feed.
## Reached as `Game.raising`.
##
## A nursery (a building whose catalog `special` is "nursery": the Nursery Barn) keeps its babies in the order
## they came (`growing`) and a trough (`trough`, units of Animal Feed). The trough takes as much as the babies
## still need, `feed_per_baby` each, and no more (eight babies: eighty). Feed is poured from the farm's Animal
## Feed (NurtureSystem's supply); every time the trough holds what the oldest baby needs, that much is eaten and
## the baby grows up into its adult (the nursery's `grows_into`), which waits in the inbox to be placed (the one
## inbox is also FarmVille's Gift Box, where the grown Mystery Baby went), with XP and the ribbon count. Animal
## Feed comes from harvesting the nursery and any animal home now and then (NurtureSystem.from_home), the Feed
## Mill's sacks (recipes), and gems.
##
## Nothing of its own is saved: the trough and the order are fields of the nursery object, saved with it.

const BABIES := "growing"     # the nursery's babies in the order they came: [[baby id, 0], ...] (the 0 is unused)
const TROUGH := "trough"      # the Animal Feed in its trough


func _init(owner: GameState) -> void:
	super(owner)


## Whether `o` is a nursery.
func is_nursery(o: Dictionary) -> bool:
	var d := game.catalog.get_def(str(o.get("id", ""))) as BuildingDef
	return d != null and d.grows_young()


## The babies in nursery `o`, oldest first (item ids).
func babies(o: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for b: Array in o.get(BABIES, []):
		out.append(str(b[0]))
	return out


## The Animal Feed one baby eats to grow up.
func need_each() -> int:
	return Balance.i("raising.feed_per_baby")


## The Animal Feed in `o`'s trough.
func trough(o: Dictionary) -> int:
	return int(o.get(TROUGH, 0))


## How much the trough can take now: what its babies still need, less what is in it.
func room(o: Dictionary) -> int:
	return maxi(babies(o).size() * need_each() - trough(o), 0)


## How much a pour would put in now: as much as there is room for and Animal Feed to pour (none promised to
## young ones the farmer is on the way to feed).
func can_pour(o: Dictionary) -> int:
	return maxi(mini(room(o), game.nurture.free_supply("animal_feed")), 0)


## Pours up to `most` Animal Feed (all that fits, when -1) into nursery `uid`'s trough, then lets every baby that
## now has enough grow up. Returns the names of the adults that grew up.
func pour(uid: int, most := -1) -> Array[String]:
	var o := game.object_by_uid(uid)
	if o.is_empty() or not is_nursery(o):
		return []
	var n := can_pour(o) if most < 0 else mini(most, can_pour(o))
	if n <= 0:
		return []
	o[TROUGH] = trough(o) + game.nurture.take_supply("animal_feed", n)
	var grown := eat(o)
	game.inventory_changed.emit()
	game.objects_updated(uid)
	return grown


## While the trough holds what the oldest baby needs, it eats that and grows up. Returns the adults' names.
func eat(o: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var line: Array = o.get(BABIES, [])
	while not line.is_empty() and trough(o) >= need_each():
		var baby := str(line[0][0])
		var adult := adult_of(o, baby)
		var went := game.storage.welcome(adult)   # (the Barn, or the inbox when it is full)
		o[TROUGH] = trough(o) - need_each()
		line.pop_front()
		var inside: Dictionary = o.get("inside", {})
		inside[baby] = int(inside.get(baby, 0)) - 1
		if int(inside[baby]) <= 0:
			inside.erase(baby)
		game.add_xp(Balance.i("raising.grown_xp"))
		game.ribbons.bump("babies_raised", 1)
		var name := str(game.item_data(adult).get("name", adult))
		game.message.emit(tr("GREW_INTO") % [game.item_data(baby).get("name", baby), name] + " "
			+ tr("ARRIVED_IN_BARN" if went == BarnStorage.BARN else "ARRIVED_IN_INBOX"))
		out.append(name)
	return out


## What baby `baby` in nursery `o` grows into.
func adult_of(o: Dictionary, baby: String) -> String:
	return str(game.item_data(o["id"]).get("grows_into", {}).get(baby, baby))


## How far the oldest baby is from growing up (0..1), for the panel.
func next_share(o: Dictionary) -> float:
	if babies(o).is_empty():
		return 0.0
	return clampf(float(trough(o)) / need_each(), 0.0, 1.0)
