class_name StraySystem
extends GameSystem
## Strays and lost animals that wander onto the farm to be adopted.
## Part of the game state: reached as `Game.strays`; shared state is on `game`.

const STRAY_MIN_GAP := 3 * 3600    # a new stray turns up 3 to 6 hours after the last
const STRAY_MAX_GAP := 6 * 3600
const STRAY_STAYS := 86400         # a stray nobody adopts wanders off after a day
const STRAY_ADOPT_XP := 5
const LOST_WEIGHT := 0.25           # each lost animal's share of the stray pool (a 100-coin animal is 1.0)

var next_stray_at := 0             # when the next stray may turn up


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
	next_stray_at = game.now() + STRAY_MIN_GAP


func save_to(data: Dictionary) -> void:
	data["next_stray_at"] = next_stray_at


func load_from(data: Dictionary) -> void:
	next_stray_at = int(data.get("next_stray_at", 0))


## Called on start, every 30 seconds, and after a debug time skip.
func check_strays() -> void:
	game.shed.expire_bunches()
	var t := game.now()
	var changed := false
	var keep: Array = []
	for o in game.objects:
		if o.get("stray", false) and t - int(o["t"]) > STRAY_STAYS:
			game.message.emit("The lonely %s wandered off." % game.item_data(o["id"])["name"].to_lower())
			changed = true
		else:
			keep.append(o)
	game.objects = keep
	if t >= next_stray_at and not _has_stray():
		if _spawn_stray():
			changed = true
		next_stray_at = t + game.rng.randi_range(STRAY_MIN_GAP, STRAY_MAX_GAP)
		game.queue_save()
	if changed:
		game.objects_updated()


func _has_stray() -> bool:
	for o in game.objects:
		if o.get("stray", false):
			return true
	return false


## Picks an animal near the player's level (cheaper ones more often) and an open grass tile.
func _spawn_stray() -> bool:
	var choices: Array[String] = []
	var weights: Array[float] = []
	var total := 0.0
	for id in game.item_order:
		var it: Dictionary = game.items[id]
		if it["kind"] != "animal":
			continue
		var w := 0.0
		if it.get("stray_only", false):
			# FarmVille's lonely bull, wandering stallion, ram and boar: only once you have their home.
			if _owns(str(it.get("home", ""))):
				w = 0.6
		elif it.get("lost", false):
			# FarmVille's lost animals (Pink Cow, Black Sheep, Ugly Duckling...): never sold, only adopted.
			w = LOST_WEIGHT
		elif int(it["unlock_level"]) <= game.level() + 2 and not it.has("gem_cost"):
			w = 1.0 / maxf(1.0, float(it["cost"]) / 100.0)
		if w > 0.0:
			choices.append(id)
			weights.append(w)
			total += w
	if choices.is_empty():
		return false
	var pick := game.rng.randf() * total
	var animal_id := choices[-1]
	for k in choices.size():
		pick -= weights[k]
		if pick <= 0.0:
			animal_id = choices[k]
			break
	var spots: Array[Vector2i] = []
	for r in game.farm_size:
		for c in game.farm_size:
			var i := game.index_of(r, c)
			if game.plots[i].get("state", "grass") == "grass" and not game.is_occupied(i):
				spots.append(Vector2i(r, c))
	if spots.is_empty():
		return false
	var spot := spots[game.rng.randi_range(0, spots.size() - 1)]
	game.objects.append(
		{"uid": game.next_uid, "id": animal_id, "row": spot.x, "col": spot.y, "t": game.now(), "stray": true}
	)
	game.next_uid += 1
	game.message.emit(
		"A lonely %s wandered onto your farm! Tap it to adopt." % game.item_data(animal_id)["name"].to_lower()
	)
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
	game.add_xp(STRAY_ADOPT_XP)
	game.ribbons.bump("strays_adopted", 1)
	game.message.emit("You adopted the %s! It's part of your farm now." % game.item_data(o["id"])["name"].to_lower())
	game.objects_updated()
	return true
