class_name HudBooks
extends RefCounted
## The Collections and Ribbons books.
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner


func build_collections(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text(
		tr("ITEMS_TURN_UP_WHILE_YOU_FARM"), 20, BookPanel.CREAM))
	for coll in Game.collectibles.collections:
		var inner := BookPanel.card()
		inner.add_theme_constant_override("separation", 10)

		var crop_names: Array[String] = []
		for crop_id in coll.get("crops", []):
			crop_names.append(Game.crops[crop_id]["name"])
		var head := HBoxContainer.new()
		var title := BookPanel.text(coll["name"], 26)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var trade := Button.new()
		trade.text = tr("TRADE_IN")
		trade.custom_minimum_size = Vector2(140, 48)
		trade.focus_mode = Control.FOCUS_NONE
		trade.disabled = not Game.collectibles.can_trade_in(coll)
		var coll_id: String = coll["id"]
		trade.pressed.connect(func() -> void: Game.collectibles.trade_in(coll_id))
		head.add_child(trade)
		inner.add_child(head)

		if coll.get("birds", false):
			inner.add_child(BookPanel.text(tr("BIRDS_CAN_LAND_DURING_ANY_HARVEST"), 18))
		elif coll.get("source", "") == "trees":
			inner.add_child(BookPanel.text(tr("FOUND_WHILE_HARVESTING_TREES"), 18))
		elif coll.get("source", "") == "animals":
			inner.add_child(BookPanel.text(tr("FOUND_WHILE_COLLECTING_FROM_ANIMALS_AND"), 18))
		else:
			inner.add_child(BookPanel.text(tr("FOUND_WHILE_HARVESTING").join(PackedStringArray(crop_names)), 18))

		var items := HFlowContainer.new()
		items.add_theme_constant_override("h_separation", 8)
		items.add_theme_constant_override("v_separation", 8)
		var need := Game.collectibles.coll_need(coll)
		for item in coll["items"]:
			var count := int(Game.collectibles.owned.get(item["id"], 0))
			var rarity: String = item.get("rarity", "common")
			var label: String = "%s  %d/%d%s" % [
				item["name"],
				count,
				int(need[item["id"]]),
				"" if rarity == "common" else "  (" + rarity + ")"
			]
			items.add_child(BookPanel.chip(label, count >= int(need[item["id"]])))
		inner.add_child(items)

		var reward := Game.collectibles.coll_reward(coll)
		inner.add_child(
			BookPanel.text(
				tr("LEVEL_REWARD_COINS_XP_AND") % [
					Game.collectibles.coll_level(coll) + 1,
					int(reward["coins"]),
					int(reward["xp"]),
					prize_text(reward["prize"])
				],
				18
			)
		)
		content.add_child(BookPanel.card_frame(inner))


## A prize ([kind, amount or item]) in words, for reward lines.
func prize_text(prize: Array) -> String:
	match str(prize[0]):
		"item":
			return "a " + str(Game.item_data(str(prize[1])).get("name", prize[1]))
		"fertilize_all":
			return tr("FERTILIZE_ALL") % int(prize[1])
		"unwither":
			return tr("UNWITHER") % int(prize[1])
		"fuel":
			return "%d fuel" % int(prize[1])
	return "%d %s" % [int(prize[1]), str(prize[0]).capitalize()]


func build_ribbons(content: VBoxContainer) -> void:
	var data: Dictionary = Game.ribbons.ribbon_data
	var tier_names: Array = data.get("tiers", [])
	content.add_child(BookPanel.text(
		tr("EACH_RIBBON_HAS_FOUR_TIERS_YELLOW"), 20, BookPanel.CREAM))
	for r in data.get("ribbons", []):
		var earned := int(Game.ribbons.ribbon_tiers.get(r["id"], 0))
		var thresholds: Array = r["thresholds"]
		var value := Game.ribbons.stat(r["stat"])

		var inner := BookPanel.card()
		inner.add_theme_constant_override("separation", 8)
		var head := HBoxContainer.new()
		var title := BookPanel.text(r["name"], 26)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var tiers := HBoxContainer.new()
		tiers.add_theme_constant_override("separation", 6)
		for k in tier_names.size():
			tiers.add_child(BookPanel.chip(tier_names[k], k < earned))
		head.add_child(tiers)
		inner.add_child(head)

		var line: String
		if earned >= thresholds.size():
			line = tr("COMPLETE") % [value, r["what"]]
		else:
			var goal := int(thresholds[earned])
			line = tr("FOR") % [mini(value, goal), goal, r["what"], tier_names[earned]]
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size.y = 18
			bar.max_value = goal
			bar.value = mini(value, goal)
			inner.add_child(BookPanel.text(line, 18))
			inner.add_child(bar)
			content.add_child(BookPanel.card_frame(inner))
			continue
		inner.add_child(BookPanel.text(line, 18))
		content.add_child(BookPanel.card_frame(inner))
