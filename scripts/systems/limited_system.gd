class_name LimitedSystem
extends GameSystem
## Limited animals and trees: the varieties (catalog `limited`, `variety`; data/varieties.json), FarmVille's
## limited editions. What follows is said of animals and their homes; a limited tree and an Orchard's Mystery
## Seedlings go by the same rules.
## Part of the game state: reached as `Game.limited`; shared state is on `game`.
##
## They are bought in the Market with gems. Once one lives in a home, that home's finds can turn out to be another
## of it: a Mystery Baby, a Mystery Egg or a baby born there is, now and then, one of the limited animals already
## inside (likelier the more of it there are): `limited.find_chance` of the time for an ordinary find,
## `limited.rare_find_chance` for a rare one. A rare find is the same find, rarer (`limited.rare_share` of finds):
## a Rare Mystery Baby, a Rare Mystery Egg. Nothing else brings a limited animal: ordinary finds and births are
## drawn from the home's other animals (`ordinary`). Off in a release that leaves the feature out
## (data/v1.json `limited`): then no find is rare and none is limited.

const FEATURE := "limited"   # not-ui (the release's name for all of this)


func _init(owner: GameState) -> void:
	super(owner)


func on() -> bool:
	return Release.on(FEATURE)


## Whether `id` is a limited animal (or a limited animal's baby) or a limited tree.
func is_limited(id: String) -> bool:
	var d := game.catalog.get_def(id)
	return d is ProducerDef and (d as ProducerDef).is_limited()


## The limited animals among `inside` (a home's id -> how many) that this release has.
func held(inside: Dictionary) -> Dictionary:
	var out := {}
	for id: String in inside:
		if is_limited(id) and Release.has(id):
			out[id] = int(inside[id])
	return out


## What an ordinary find or birth at `home` is drawn from: its animals that are not limited. A home of limited
## animals only still gives ordinary finds: of their plain kinds (`plain_of`).
func ordinary(home: Dictionary) -> Dictionary:
	var out := {}
	var inside: Dictionary = home.get("inside", {})
	for id: String in inside:
		if not is_limited(id):
			out[id] = int(inside[id])
	if out.is_empty():
		for id: String in inside:
			var plain := plain_of(id, str(home.get("id", "")))
			if plain != "":
				out[plain] = int(out.get(plain, 0)) + int(inside[id])
	return out


## The plain animal that limited animal `id` is a coat of, among those home `home_id` takes: the first grown one
## of its family there (a Rainbow Goose's is the Goose, though it lives on the Duck Pond), else the first grown
## one of any. "" when the home takes none this release has.
func plain_of(id: String, home_id: String) -> String:
	var of := str(game.item_data(id).get("limited_of", ""))   # (a limited tree names its plain tree)
	if of != "":
		return of if Release.has(of) else ""
	var family := str(game.item_data(id).get("family", ""))
	var first := ""
	for held: String in game.item_data(home_id).get("holds", []):
		var it := game.item_data(held)
		if is_limited(held) or not Release.has(held) or bool(it.get("young", false)):
			continue
		if str(it.get("family", "")) == family:
			return held
		first = held if first == "" else first
	return first


## Whether a find is a rare one (a Rare Mystery Baby, a Rare Mystery Egg).
func rare_find() -> bool:
	return on() and game.rolls.roll("rare_find", Balance.f("limited.rare_share"))


## What a find at `home` is when it turns out limited: one of the limited animals living there (likelier the more
## of it), or "" (nearly always, and always where none lives). A rare find is likelier to.
func found_at(home: Dictionary, rare: bool) -> String:
	if not on():
		return ""
	var here := held(home.get("inside", {}))
	if here.is_empty():
		return ""
	var came := game.rolls.roll("limited_rare_find", Balance.f("limited.rare_find_chance")) if rare \
		else game.rolls.roll("limited_find", Balance.f("limited.find_chance"))
	if not came:
		return ""
	var k := RollSystem.weighted_index(game.rng, here.values())
	return str(here.keys()[k]) if k >= 0 else ""


## The baby a birth at `home` is when it turns out limited: a limited animal's own baby (the Nursery raises it into
## the limited animal), or "".
func born_at(home: Dictionary) -> String:
	var parent := found_at(home, false)
	return (game.catalog.get_def(parent) as AnimalDef).baby() if parent != "" else ""
