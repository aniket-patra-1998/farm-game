class_name BeehiveSystem
extends GameSystem
## Beehives: the Queen Bee, worker bees, pollination, and bees leaving while you're away.
## Part of the game state: reached as `Game.bees`; shared state is on `game`.

# Beehive, as in FarmVille: a Queen Bee makes the hive work, worker bees join it,
# and the bees pollinate fertilized crops nearby.
const QUEEN_CHANCE := 0.008        # a Queen Bee found on a flower harvest
const QUEEN_GEM_COST := 10
const BEE_CHANCE := 0.25           # per flower harvest, only into a hive with a queen
const POLLINATION_PER_BEE := 1.0 / 400.0
const MAX_POLLINATION := 0.5
const POLLINATED_SEEDS := 5        # given per pollination
const POLLINATED_LIFETIME := 2 * 86400
const BEES_STAY_DAYS := 3          # away longer than this, bees start to leave
const BEES_LEAVE_PER_DAY := 0.15
const QUEEN_STAYS_DAYS := 14

var queen_bees := 0                # Queen Bees held, waiting for a hive
var pollinated := {}               # crop id -> [seed count, expires at]


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
	queen_bees = 0
	pollinated = {}


func save_to(data: Dictionary) -> void:
	data["queen_bees"] = queen_bees
	data["pollinated"] = pollinated


func load_from(data: Dictionary) -> void:
	queen_bees = int(data.get("queen_bees", 0))
	pollinated = {}
	var saved: Dictionary = data.get("pollinated", {})
	for c in saved:
		var e: Array = saved[c]
		if game.crops.has(c) and e.size() == 2:
			pollinated[c] = [int(e[0]), int(e[1])]


func hives() -> Array:
	var out: Array = []
	for o in game.objects:
		if o["id"] == "beehive" and not game.under_construction(o):
			out.append(o)
	return out


func bee_count() -> int:
	var n := 0
	for h in hives():
		n += game.inside_total(h)
	return n


func has_queen(hive: Dictionary) -> bool:
	return hive.get("queen", false)


## Chance that harvesting a fertilized crop gives pollinated seeds.
func pollination_chance() -> float:
	return minf(MAX_POLLINATION, bee_count() * POLLINATION_PER_BEE)


## Puts a Queen Bee in a finished hive: one you hold, or one bought for gems.
func add_queen(uid: int, buy := false) -> bool:
	var hive := game.object_by_uid(uid)
	if hive.is_empty() or hive["id"] != "beehive" or game.under_construction(hive) or has_queen(hive):
		return false
	if not buy and queen_bees > 0:
		queen_bees -= 1
	elif buy:
		if not game.spend_gems(QUEEN_GEM_COST):
			game.message.emit(tr("NOT_ENOUGH_GEMS_FOR_A_QUEEN"))
			return false
	else:
		game.message.emit(tr("NO_QUEEN_BEE_YET_ONE_MAY"))
		return false
	hive["queen"] = true
	game.message.emit(tr("THE_QUEEN_BEE_MOVED_IN_WORKER"))
	game.inventory_changed.emit()
	game.objects_updated()
	return true


## Flower harvests: a rare Queen Bee, or a worker bee joining a hive that has a queen.
func flower_harvest_bees() -> String:
	if not game.drops_enabled:
		return ""
	var all := hives()
	var queenless := all.filter(func(h: Dictionary) -> bool: return not has_queen(h))
	if (all.is_empty() or not queenless.is_empty()) and queen_bees == 0 and game.rng.randf() < QUEEN_CHANCE:
		queen_bees += 1
		game.ribbons.bump("queens_found", 1)
		game.message.emit(tr("YOU_FOUND_A_QUEEN_BEE_PUT"))
		game.inventory_changed.emit()
		return tr("A_QUEEN_BEE")
	for h in all:
		if has_queen(h) and game.inside_total(h) < game.capacity(h):
			if game.rng.randf() >= BEE_CHANCE:
				return ""
			put_bee_in(h)
			game.ribbons.bump("bees_found", 1)
			game.objects_updated()
			return tr("A_BEE_JOINED")
	return ""


func put_bee_in(hive: Dictionary) -> void:
	var inside: Dictionary = hive["inside"]
	if game.inside_total(hive) == 0:
		hive["t"] = game.now() # honey starts once the first bee moves in
	inside["bee"] = int(inside.get("bee", 0)) + 1


## Uses one pollinated seed of this crop, if any are held (they're planted first, for free).
func take_pollinated_seed(crop_id: String) -> bool:
	if pollinated_seeds(crop_id) <= 0:
		return false
	var entry: Array = pollinated[crop_id]
	entry[0] = int(entry[0]) - 1
	if int(entry[0]) <= 0:
		pollinated.erase(crop_id)
	game.inventory_changed.emit()
	return true


## Bees pollinate a fertilized crop as it's harvested: pollinated seeds of that crop.
func pollinate(crop_id: String) -> int:
	if not game.drops_enabled or game.rng.randf() >= pollination_chance():
		return 0
	var n := pollinated_seeds(crop_id) + POLLINATED_SEEDS
	pollinated[crop_id] = [n, game.now() + POLLINATED_LIFETIME]
	game.ribbons.bump("pollinated", 1)
	game.message.emit(
		tr("YOUR_BEES_POLLINATED_THE_POLLINATED_SEEDS") % [game.crops[crop_id]["name"].to_lower(), n]
	)
	game.inventory_changed.emit()
	return POLLINATED_SEEDS


## Pollinated seeds held for a crop, dropping any that expired.
func pollinated_seeds(crop_id: String) -> int:
	if not pollinated.has(crop_id):
		return 0
	var entry: Array = pollinated[crop_id]
	if game.now() >= int(entry[1]):
		pollinated.erase(crop_id)
		return 0
	return int(entry[0])


## Fertilizes every growing crop for free.
func use_fertilize_all() -> int:
	if game.fertilize_alls <= 0:
		game.message.emit(tr("NO_FERTILIZE_ALL_LEFT"))
		return 0
	var done := 0
	for r in game.farm_size:
		for c in game.farm_size:
			var i := game.index_of(r, c)
			if game.phase(i) == GameState.Phase.GROWING and not game.is_fertilized(i):
				game.plots[i]["fert"] = true
				done += 1
	if done == 0:
		game.message.emit(tr("NOTHING_GROWING_TO_FERTILIZE"))
		return 0
	game.fertilize_alls -= 1
	game.ribbons.bump("fertilized", done)
	game.message.emit(tr("FERTILIZED_CROPS") % done)
	game.inventory_changed.emit()
	game.plot_changed.emit(-1)
	game.queue_save()
	return done


## FarmVille's bees left when nobody came for days, and the queen after weeks.
## Returns a note for the player, or "".
func apply_absence(seconds_away: int) -> String:
	var days := seconds_away / 86400.0
	if days <= BEES_STAY_DAYS:
		return ""
	var notes: Array[String] = []
	var share := minf(1.0, (days - BEES_STAY_DAYS) * BEES_LEAVE_PER_DAY)
	for h in hives():
		var count := game.inside_total(h)
		var gone := mini(count, int(ceil(count * share)))
		if gone > 0:
			var inside: Dictionary = h["inside"]
			inside["bee"] = count - gone
			if int(inside["bee"]) <= 0:
				inside.erase("bee")
			notes.append("%d bees left the hive while you were away" % gone)
		if days > QUEEN_STAYS_DAYS and has_queen(h):
			h.erase("queen")
			notes.append(tr("THE_QUEEN_BEE_FLEW_OFF"))
	return "; ".join(PackedStringArray(notes))
