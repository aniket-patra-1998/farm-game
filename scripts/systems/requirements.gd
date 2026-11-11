class_name Requirements
extends RefCounted
## What an item needs before it can be bought, beyond its level: declared in the catalog as `requires`, one
## entry per kind of need, so any item can ask for anything the game tracks:
##   {"finds": {"gopher": 1}}      own at least one of a family found while farming (Game.finds)
##   {"owned": {"beehive": 1}}     have a building on the farm
##   {"mastery": {"wheat": 2}}     earn stars on a crop
## list() gives every need with its progress (for the market's checklist); the first unmet one is what a
## purchase is refused with. A new kind of need is one branch in _progress and a string.


const SENTENCES := {"finds": "REQ_FINDS", "owned": "REQ_OWNED", "mastery": "REQ_MASTERY"}
const HINTS := {"finds": "REQ_HINT_FINDS", "owned": "REQ_HINT_OWNED", "mastery": "REQ_HINT_MASTERY"}


## Every need of `id`: [{text, ok, hint}] (empty when it needs nothing).
static func list(game: GameState, id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var req: Dictionary = game.item_data(id).get("requires", {})
	for kind: String in req:
		var wants: Dictionary = req[kind]
		for what: String in wants:
			var need := int(wants[what])
			var have := _progress(game, kind, what)
			out.append({
				"ok": have >= need,
				"text": TranslationServer.translate(SENTENCES[kind]) % _words(kind, need, _name_of(game, kind, what), have),
				"hint": TranslationServer.translate(HINTS[kind]),
			})
	return out


## The first need not yet met ({} if all are).
static func first_unmet(game: GameState, id: String) -> Dictionary:
	for r in list(game, id):
		if not r["ok"]:
			return r
	return {}


## The values a need's sentence is filled with (see strings REQ_*).
static func _words(kind: String, need: int, name: String, have: int) -> Array:
	match kind:
		"finds":
			return [need, name, mini(have, need), need]
		"mastery":
			return [need, name]
	return [name]


static func _progress(game: GameState, kind: String, what: String) -> int:
	match kind:
		"finds":
			return game.finds.total(what)
		"owned":
			return game.buildings.owned(what)
		"mastery":
			return game.mastery.stars(what)
	return 0


static func _name_of(game: GameState, kind: String, what: String) -> String:
	if kind == "finds":
		return str(game.finds.families.get(what, {}).get("name", what)).to_lower()
	return str(game.item_data(what).get("name", what))
