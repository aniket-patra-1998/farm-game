class_name PigPenSystem
extends GameSystem
## The Pig Pen: slop, foraging, truffles and rare pigs.
## Part of the game state: reached as `Game.pigpen`; shared state is on `game`.

# Pig Pen: feed slop, the pigs forage, and truffles trade for rare breeds.
const SLOP_COST := 150
const FORAGE_SECONDS := 8 * 3600
const PIGS_PER_TRUFFLE := 5
const TRUFFLES_PER_PIG := 10

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
		game.message.emit("Move some pigs in first")
		return false
	if not game.spend(SLOP_COST):
		game.message.emit("Not enough coins for slop")
		return false
	pen["forage_until"] = game.now() + FORAGE_SECONDS
	game.message.emit("The pigs are out looking for truffles")
	game.objects_updated()
	return true


## Truffles found by the pigs once foraging is over: one per 5 pigs, at least one.
func collect_truffles(uid: int) -> int:
	var pen := game.object_by_uid(uid)
	if pen.is_empty() or not is_foraging(pen) or forage_seconds_left(pen) > 0:
		return 0
	var dug := maxi(1, int(game.inside_total(pen) / float(PIGS_PER_TRUFFLE)))
	pen.erase("forage_until")
	truffles += dug
	game.ribbons.bump("truffles", dug)
	game.message.emit("Your pigs found %d truffles!" % dug)
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
	if not game.item_data(breed).get("rare_pig", false) or truffles < TRUFFLES_PER_PIG:
		return false
	if not game.place_somewhere(breed):
		game.message.emit("No room on the farm for a new pig")
		return false
	truffles -= TRUFFLES_PER_PIG
	game.message.emit("A %s joined your farm!" % game.item_data(breed)["name"])
	game.inventory_changed.emit()
	game.objects_updated()
	return true
