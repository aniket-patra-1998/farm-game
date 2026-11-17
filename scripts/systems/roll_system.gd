class_name RollSystem
extends GameSystem
## Every chance the game's rules roll for a reward goes through here (Game.rolls), by name: data/rolls.json says
## which ones active VIP raises, so what VIP touches is one list, never a wrapper remembered at each roll.

const DATA := "res://data/rolls.json"

var _rolls := {}   # id -> {"vip": bool, "what": String}


func load_data() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_rolls = (data as Dictionary).get("rolls", {}) if data is Dictionary else {}


## The chance of roll `id` now, from its `base`: raised by active VIP when the roll is listed for it.
func odds(id: String, base: float) -> float:
	if not _rolls.has(id):
		push_error("RollSystem: no roll '%s' in %s" % [id, DATA])
		return base
	return game.vip.chance(base) if bool(_rolls[id].get("vip", false)) else base


## Rolls `id` once at its odds from `base`: true when it comes up.
func roll(id: String, base: float) -> bool:
	return game.rng.randf() < odds(id, base)


## Every roll's id (for the test that holds code and data together).
func ids() -> Array:
	return _rolls.keys()
