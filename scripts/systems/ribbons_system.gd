class_name RibbonsSystem
extends GameSystem
## Lifetime stats and the ribbons they earn.
## Part of the game state: reached as `Game.ribbons`; shared state is on `game`.

var ribbon_data := {}              # data/ribbons.json
var event_verbs := {}              # data/events.json: verb -> the rules that pick its counter
var stats := {}                    # lifetime counters for ribbons
var ribbon_tiers := {}             # ribbon id -> tiers earned (0..4)


func _init(owner: GameState) -> void:
	super(owner)


func reset() -> void:
	stats = {}
	ribbon_tiers = {}


func save_to(data: Dictionary) -> void:
	data["stats"] = stats
	data["ribbon_tiers"] = ribbon_tiers


func load_from(data: Dictionary) -> void:
	stats = int_map(data.get("stats", {}))
	ribbon_tiers = int_map(data.get("ribbon_tiers", {}))


func stat(stat_name: String) -> int:
	return int(stats.get(stat_name, 0))


## The showcase: the ribbons in turn at every tier, from none to Blue, their counters where those tiers are earned.
func showcase() -> void:
	if ribbon_data.is_empty():
		return
	var ribbons: Array = ribbon_data["ribbons"]
	for k in ribbons.size():
		var thresholds: Array = ribbons[k]["thresholds"]
		var tier := k % (thresholds.size() + 1)
		if tier > 0:
			stats[ribbons[k]["stat"]] = maxi(stat(ribbons[k]["stat"]), int(thresholds[tier - 1]))
	for r: Dictionary in ribbons:
		var have := stat(r["stat"])
		ribbon_tiers[r["id"]] = (r["thresholds"] as Array).filter(func(t: Variant) -> bool: return have >= int(t)).size()


## The counter an event adds to (data/events.json), or "" when it counts for no ribbon.
func stat_of(verb: String, subject: String) -> String:
	var kind := str(game.item_data(subject).get("kind", ""))
	for rule: Dictionary in event_verbs.get(verb, []):
		if not rule.has("kind") or str(rule["kind"]) == kind:
			return str(rule["stat"])
	return ""


## Adds an event to its ribbon counter (called by Game.record, which also tells the event).
func count(verb: String, subject: String, n: int) -> void:
	var stat_name := stat_of(verb, subject)
	if stat_name != "":
		bump(stat_name, n)


func bump(stat_name: String, amount: int) -> void:
	stats[stat_name] = stat(stat_name) + amount
	_check_ribbons(stat_name)


func _check_ribbons(stat_name: String) -> void:
	if ribbon_data.is_empty():
		return
	var tier_names: Array = ribbon_data["tiers"]
	for r in ribbon_data["ribbons"]:
		if r["stat"] != stat_name:
			continue
		var earned := int(ribbon_tiers.get(r["id"], 0))
		var thresholds: Array = r["thresholds"]
		while earned < thresholds.size() and stat(stat_name) >= int(thresholds[earned]):
			earned += 1
			ribbon_tiers[r["id"]] = earned
			# Rewards are paid without counting toward "coins earned", so ribbons can't chain.
			game.coins += int(ribbon_data["tier_reward_coins"][earned - 1])
			game.coins_changed.emit(game.coins)
			game.add_xp(int(ribbon_data["tier_reward_xp"][earned - 1]))
			game.message.emit(tr("RIBBON_COINS") % [
				tier_names[earned - 1], r["name"], int(ribbon_data["tier_reward_coins"][earned - 1])])
			game.ribbons_changed.emit()
	game.queue_save()


func load_data() -> void:
	ribbon_data = game.read_json("res://data/ribbons.json")
	event_verbs = game.read_json("res://data/events.json").get("verbs", {})
