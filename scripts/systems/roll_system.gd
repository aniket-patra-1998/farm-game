class_name RollSystem
extends GameSystem
## Every chance the game's rules roll for a reward goes through here (Game.rolls), by name: data/rolls.json says
## which ones active VIP raises, so what VIP touches is one list, never a wrapper remembered at each roll.

const DATA := "res://data/rolls.json"

var _rolls := {}   # id -> {"vip": bool, "what": String}


func load_data() -> void:
	_rolls = DataFile.read(DATA).get("rolls", {})


## The chance of roll `id` now, from its `base`: raised by active VIP when the roll is listed for it.
func odds(id: String, base: float) -> float:
	if not _rolls.has(id):
		push_error("RollSystem: no roll '%s' in %s" % [id, DATA])
		return base
	return game.vip.chance(base) if bool(_rolls[id].get("vip", false)) else base


## Rolls `id` once at its odds from `base`: true when it comes up.
func roll(id: String, base: float) -> bool:
	return game.rng.randf() < odds(id, base)


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
