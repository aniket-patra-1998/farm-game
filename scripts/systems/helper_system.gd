class_name HelperSystem
extends GameSystem
## The helpers (farmhands, arborists, gardeners): one used works every thing of its kind at once, doing what
## data/actions.json gives that kind (collect what is ready, feed what is hungry). How many are held stays on
## the game, saved with it. Reached as `Game.helpers`; `Game.use_helper` asks it.


## A helper does everything the action registry (data/actions.json) gives its kind: collects what is ready, then
## feeds what is hungry for the cycle ahead. One helper is used up whatever it did.
func use_helper(kind: String) -> int:
	var helper: Dictionary = GameState.HELPERS[kind]
	if game.helpers_held(kind) <= 0:
		game.message.emit(tr("NO_LEFT") % tr(helper["name"]))
		return 0
	var actions := Actions.for_helper(kind)
	var ready: Array = []
	if "collect" in actions:
		for o in game.objects:
			if game.kind_of(o) == kind and game.is_ready(o):
				ready.append(int(o["uid"]))
	var coins_total := 0
	for uid in ready:
		coins_total += int(game.collect(uid).get("coins", 0))
	var fed := game.feeds.feed_all(kind) if "feed" in actions else 0
	if ready.is_empty() and fed == 0:
		game.message.emit(tr("NOTHING_IS_READY_TO_COLLECT_YET"))
		return 0
	game.set(helper["field"], game.helpers_held(kind) - 1)
	if not ready.is_empty():
		game.message.emit(tr(helper["done"]) % [ready.size(), coins_total])
	if fed > 0:
		game.message.emit(tr("FED_ANIMALS") % fed)
	game.inventory_changed.emit()
	return ready.size() + fed
