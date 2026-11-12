class_name PigPenSystem
extends GameSystem
## The Pig Pen: slop, foraging, truffles and rare pigs.
## Part of the game state: reached as `Game.pigpen`; shared state is on `game`.

# Pig Pen: feed slop, the pigs forage, and truffles trade for rare breeds.

var truffles := 0


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
	truffles = 0


func save_to(data: Dictionary) -> void:
	data["truffles"] = truffles


func load_from(data: Dictionary) -> void:
	truffles = int(data.get("truffles", 0))


func is_foraging(pen: Dictionary) -> bool:
	return int(pen.get("forage_until", 0)) > 0


func forage_seconds_left(pen: Dictionary) -> int:
	return maxi(0, int(pen.get("forage_until", 0)) - game.now())


## Feeds slop to the pigs inside; they forage for truffles for 8 hours.
func feed_slop(uid: int) -> bool:
	var pen := game.object_by_uid(uid)
	if pen.is_empty() or pen["id"] != "pig_pen" or game.under_construction(pen) or is_foraging(pen):
		return false
	if game.inside_total(pen) == 0:
		game.message.emit(tr("MOVE_SOME_PIGS_IN_FIRST"))
		return false
	if not game.spend(Balance.i("pigpen.slop_cost")):
		game.message.emit(tr("NOT_ENOUGH_COINS_FOR_SLOP"))
		return false
	pen["forage_until"] = game.now() + Balance.i("pigpen.forage_seconds")
	game.message.emit(tr("THE_PIGS_ARE_OUT_LOOKING_FOR"))
	game.objects_updated()
	return true


## Truffles found by the pigs once foraging is over: one per 5 pigs, at least one.
func collect_truffles(uid: int) -> int:
	var pen := game.object_by_uid(uid)
	if pen.is_empty() or not is_foraging(pen) or forage_seconds_left(pen) > 0:
		return 0
	var dug := maxi(1, int(game.inside_total(pen) / float(Balance.i("pigpen.pigs_per_truffle"))))
	pen.erase("forage_until")
	truffles += dug
	game.ribbons.bump("truffles", dug)
	game.message.emit(tr("YOUR_PIGS_FOUND_TRUFFLES") % dug)
	game.inventory_changed.emit()
	game.objects_updated()
	return dug


func rare_pigs() -> Array[String]:
	var out: Array[String] = []
	for id in game.item_order:
		if game.items[id].get("rare_pig", false):
			out.append(id)
	return out


## Trades 10 truffles for a rare pig breed, placed on the farm.
func trade_truffles(breed: String) -> bool:
	if not game.item_data(breed).get("rare_pig", false) or truffles < Balance.i("pigpen.truffles_per_pig"):
		return false
	if not game.place_somewhere(breed):
		game.message.emit(tr("NO_ROOM_ON_THE_FARM_FOR"))
		return false
	truffles -= Balance.i("pigpen.truffles_per_pig")
	game.message.emit(tr("A_JOINED_YOUR_FARM") % game.item_data(breed)["name"])
	game.inventory_changed.emit()
	game.objects_updated()
	return true
