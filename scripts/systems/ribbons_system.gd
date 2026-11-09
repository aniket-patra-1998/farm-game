class_name RibbonsSystem
extends GameSystem
## Lifetime stats and the ribbons they earn.
## Part of the game state: reached as `Game.ribbons`; shared state is on `game`.

var ribbon_data := {}              # data/ribbons.json
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
	stats = data.get("stats", {})
	ribbon_tiers = data.get("ribbon_tiers", {})


func stat(stat_name: String) -> int:
	return int(stats.get(stat_name, 0))


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
			game.message.emit("%s ribbon: %s! +%d coins" % [
				tier_names[earned - 1], r["name"], int(ribbon_data["tier_reward_coins"][earned - 1])])
			game.ribbons_changed.emit()
	game.queue_save()


func load_data() -> void:
	ribbon_data = game.read_json("res://data/ribbons.json")
