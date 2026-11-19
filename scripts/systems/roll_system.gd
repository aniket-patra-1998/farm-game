class_name RollSystem
extends GameSystem
## Every chance the game's rules roll for a reward goes through here (Game.rolls), by name: data/rolls.json says
## which ones active VIP raises, so what VIP touches is one list, never a wrapper remembered at each roll.

const DATA := "res://data/rolls.json"

const DAY := 86400
const WEEK_DAYS := 7

var _rolls := {}   # id -> {"vip": bool, "what": String, "cap": {"per": "day" or "week", "most": int}}
var _taken := {}   # a capped roll's id -> [the day or week it counts in, how many came up in it]


func load_data() -> void:
	_rolls = DataFile.read(DATA).get("rolls", {})


## The chance of roll `id` now, from its `base`: raised by active VIP when the roll is listed for it.
func odds(id: String, base: float) -> float:
	if not _rolls.has(id):
		push_error("RollSystem: no roll '%s' in %s" % [id, DATA])
		return base
	return game.vip.chance(base) if bool(_rolls[id].get("vip", false)) else base


## Rolls `id` once at its odds from `base`: true when it comes up. A capped roll (its `cap` in data/rolls.json:
## at most `most` a day or a week, owner 19 Nov) never comes up again in that day or week once it has reached it.
func roll(id: String, base: float) -> bool:
	var cap: Dictionary = _rolls.get(id, {}).get("cap", {})
	if cap.is_empty():
		return game.rng.randf() < odds(id, base)
	var period := _period(str(cap.get("per", "day")))
	var had: Array = _taken.get(id, [period, 0])
	var n := int(had[1]) if int(had[0]) == period else 0
	if n >= int(cap.get("most", 0)):
		return false
	var came := game.rng.randf() < odds(id, base)
	if came:
		_taken[id] = [period, n + 1]
	return came


## How many of capped roll `id` came up in its day or week so far, and its most.
func taken(id: String) -> Vector2i:
	var cap: Dictionary = _rolls.get(id, {}).get("cap", {})
	if cap.is_empty():
		return Vector2i(0, -1)
	var had: Array = _taken.get(id, [-1, 0])
	var n := int(had[1]) if int(had[0]) == _period(str(cap.get("per", "day"))) else 0
	return Vector2i(n, int(cap.get("most", 0)))


## The day (local, from midnight) or week a capped roll counts in now.
func _period(per: String) -> int:
	var day := floori(float(game.now() + DayCycle.device_bias_minutes() * 60) / DAY)
	return floori(float(day) / WEEK_DAYS) if per == "week" else day


func reset() -> void:
	_taken.clear()


func save_to(data: Dictionary) -> void:
	data["rolls_taken"] = _taken.duplicate(true)


func load_from(data: Dictionary) -> void:
	_taken.clear()
	var kept: Variant = data.get("rolls_taken", {})
	if kept is Dictionary:
		for id: Variant in kept:
			var v: Variant = kept[id]
			if v is Array and v.size() == 2:
				_taken[str(id)] = [int(v[0]), int(v[1])]


## The index of one of `weights` picked by weight, from `rng`: a weight of 0 or less is never picked; -1 when
## none can be. Every weighted pick in the rules (prizes, finds, babies, strays, parts, neighbours' gifts) goes
## through here, so they share one rule.
static func weighted_index(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for w: Variant in weights:
		total += maxf(float(w), 0.0)
	if total <= 0.0:
		return -1
	var pick := rng.randf() * total
	var last := -1
	for k in weights.size():
		var w := float(weights[k])
		if w <= 0.0:
			continue
		last = k
		if pick < w:
			return k
		pick -= w
	return last


## Every roll's id (for the test that holds code and data together).
func ids() -> Array:
	return _rolls.keys()
