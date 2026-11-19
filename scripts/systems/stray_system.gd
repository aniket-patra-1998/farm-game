class_name StraySystem
extends GameSystem
## Strays and lost animals that wander onto the farm to be adopted.
## Part of the game state: reached as `Game.strays`; shared state is on `game`.


var next_stray_at := 0             # when the next stray may turn up
var arrived: Array[int] = []       # when each stray of the last week turned up (the weekly cap counts these)

const WEEK := 7 * 86400


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
	next_stray_at = game.now() + Balance.i("strays.stray_min_gap")


func save_to(data: Dictionary) -> void:
	data["next_stray_at"] = next_stray_at
	data["strays_arrived"] = arrived.duplicate()


func load_from(data: Dictionary) -> void:
	next_stray_at = int(data.get("next_stray_at", 0))
	arrived.clear()
	for t: Variant in data.get("strays_arrived", []):
		if t is float or t is int:
			arrived.append(int(t))


func shift_clock(seconds: int) -> void:
	next_stray_at -= seconds
	for k in arrived.size():
		arrived[k] -= seconds


## Strays that turned up in the last week (at most `strays.week_most` do, owner 19 Nov).
func this_week() -> int:
	var t := game.now()
	arrived = arrived.filter(func(a: int) -> bool: return t - a < WEEK and a <= t)
	return arrived.size()


## Called on start, every 30 seconds, and after a debug time skip.
func check_strays() -> void:
	game.shed.expire_bunches()
	var t := game.now()
	var changed := false
	var keep: Array = []
	for o in game.objects:
		if o.get("stray", false) and t - int(o["t"]) > Balance.i("strays.stray_stays"):
			game.message.emit(tr("THE_LONELY_WANDERED_OFF") % game.item_data(o["id"])["name"].to_lower())
			changed = true
		else:
			keep.append(o)
	game.set_objects(keep)
	if t >= next_stray_at and not _has_stray():
		if this_week() < Balance.i("strays.week_most") and _spawn_stray():
			arrived.append(t)
			changed = true
		next_stray_at = t + game.rng.randi_range(Balance.i("strays.stray_min_gap"), Balance.i("strays.stray_max_gap"))
		game.queue_save()
	if changed:
		game.objects_updated()


func _has_stray() -> bool:
	for o in game.objects:
		if o.get("stray", false):
			return true
	return false


## The showcase: a stray waiting on the farm to be adopted.
func showcase() -> void:
	if not _has_stray():
		_spawn_stray()


## Picks an animal near the player's level (cheaper ones more often) and an open grass tile.
func _spawn_stray() -> bool:
	if not Release.on("strays"):
		return false
	var choices: Array[String] = []
	var weights: Array[float] = []
	for id in game.item_order:
		var it: Dictionary = game.items[id]
		if it["kind"] != "animal" or not Release.has(id):
			continue
		var w := 0.0
		if it.get("stray_only", false):
			# FarmVille's lonely bull, wandering stallion, ram and boar: only once you have their home.
			if _owns(str(it.get("home", ""))):
				w = 0.6
		elif it.get("lost", false):
			# FarmVille's lost animals (Pink Cow, Black Sheep, Ugly Duckling...): never sold, only adopted.
			w = Balance.f("strays.lost_weight")
		elif int(it["unlock_level"]) <= game.level() + 2 and not it.has("gem_cost"):
			w = 1.0 / maxf(1.0, float(it["cost"]) / 100.0)
		if w > 0.0:
			choices.append(id)
			weights.append(w)
	if choices.is_empty():
		return false
	var animal_id := choices[RollSystem.weighted_index(game.rng, weights)]
	var spot := game.free_spot_for(animal_id)
	if spot.x < 0:
		return false
	game.add_object(
		{"uid": game.next_uid, "id": animal_id, "row": spot.x, "col": spot.y, "t": game.now(), "stray": true}
	)
	game.next_uid += 1
	game.message.emit(
		tr("A_LONELY_WANDERED_ONTO_YOUR_FARM") % game.item_data(animal_id)["name"].to_lower()
	)
	# Said where it stands, like every find: a lost animal (never sold, only adopted) is rare.
	var lost: bool = game.items[animal_id].get("lost", false) or game.items[animal_id].get("stray_only", false)
	game.found_on.emit(game.next_uid - 1, tr("STRAY_HERE") % str(game.item_data(animal_id)["name"]),
		"rare" if lost else "uncommon")
	return true


func _owns(item_id: String) -> bool:
	for o in game.objects:
		if o["id"] == item_id:
			return true
	return false


func adopt_stray(uid: int) -> bool:
	var o := game.object_by_uid(uid)
	if o.is_empty() or not o.get("stray", false):
		return false
	o.erase("stray")
	o["t"] = game.now() # starts producing from today
	game.add_xp(Balance.i("strays.stray_adopt_xp"))
	game.record("adopt", str(o["id"]))
	game.message.emit(tr("YOU_ADOPTED_THE_IT_S_PART") % game.item_data(o["id"])["name"].to_lower())
	game.objects_updated(uid)
	return true
