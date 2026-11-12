class_name HomeBoostSystem
extends GameSystem
## What stocked homes give back to the farm (our own touch, not FarmVille 2009; Balance `synergy.home_boosts`
## 0 turns it off). data/home_boosts.json says which homes add how much to which boost, with a cap each.
## Nothing is saved: it is worked out from what stands on the farm, like LinksSystem and AdjacencySystem.

const DATA := "res://data/home_boosts.json"

var _boosts := {}   # boost id -> {"cap", "homes": {item id -> amount}}


func load_data() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var d: Dictionary = parsed if parsed is Dictionary else {}
	_boosts = d.get("boosts", {})


func is_on() -> bool:
	return Balance.i("synergy.home_boosts") != 0


func boost_ids() -> Array:
	return _boosts.keys()


## What one home adds to a boost (0 when it isn't listed there, or holds nothing yet).
func share_of(o: Dictionary, boost: String) -> float:
	if not game.is_building(o) or game.under_construction(o) or game.inside_total(o) <= 0:
		return 0.0
	return float(_boosts.get(boost, {}).get("homes", {}).get(str(o["id"]), 0.0))


## The farm's total for a boost, capped.
func total(boost: String) -> float:
	if not is_on() or not _boosts.has(boost):
		return 0.0
	var sum := 0.0
	for o in game.objects:
		sum += share_of(o, boost)
	return minf(sum, float(_boosts[boost]["cap"]))


## The boosts one home gives right now, as {boost id: share}.
func given_by(o: Dictionary) -> Dictionary:
	var out := {}
	if not is_on():
		return out
	for b: String in _boosts:
		var s := share_of(o, b)
		if s > 0.0:
			out[b] = s
	return out
