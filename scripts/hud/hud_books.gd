class_name HudBooks
extends RefCounted
## The Collections and Ribbons books.
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

const RARITY_KEYS := {"common": "RARITY_COMMON", "uncommon": "RARITY_UNCOMMON", "rare": "RARITY_RARE"}

const RING_SHARE := 0.55   # a set card's ring against the card

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner


## Collections as a grid of sets, each a card with a ring for how much of it you have ("3/5") and Ready once it
## can be traded in; a tap opens the set (its items, Trade in and its prize: `build_collection`).
func build_collections(content: VBoxContainer) -> void:
	content.add_child(BookPanel.info(
		tr("ITEMS_TURN_UP_WHILE_YOU_FARM"), tr("ITEMS_TURN_UP_WHILE_YOU_FARM_INFO"), 20, BookPanel.SOFT))
	var ids: Array[String] = []
	for coll in Game.collectibles.collections:
		ids.append(str(coll["id"]))
	var list := CardList.make(ids, set_face, func(coll_id: String) -> void:
		hud._book.open_panel(str(_set_of(coll_id)["name"]), func(c: VBoxContainer) -> void: build_collection(c, coll_id)),
		hud.get_viewport().get_visible_rect().size.x)
	content.add_child(list)
	BookPanel.set_live(content, list.refresh)


## One set's card face: a ring (items held of the set's items) with the count in it, its name, and Ready once it
## can be traded in.
func set_face(coll_id: String) -> Dictionary:
	var coll := _set_of(coll_id)
	var items: Array = coll["items"]
	var held := 0
	for item: Dictionary in items:
		held += 1 if int(Game.collectibles.owned.get(item["id"], 0)) > 0 else 0
	return {
		"name": str(coll["name"]),
		"ring": [float(held) / maxf(items.size(), 1.0), "%d/%d" % [held, items.size()]],   # not-ui
		"line": tr("SLOT_READY") if Game.collectibles.can_trade_in(coll) else "",
		"line_colour": BookPanel.GOOD,
	}


func _set_of(coll_id: String) -> Dictionary:
	for coll in Game.collectibles.collections:
		if str(coll["id"]) == coll_id:
			return coll
	return {}


## One set opened: its items with how many you hold of how many a trade needs, Trade in once it can be, and its
## prize; a Back to the grid.
func build_collection(content: VBoxContainer, coll_id: String) -> void:
	var back := hud._panel_button(tr("BACK"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(hud._show_collections)
	content.add_child(back)
	for coll in Game.collectibles.collections:
		if str(coll["id"]) != coll_id:
			continue
		var inner := BookPanel.card()
		inner.add_theme_constant_override("separation", 10)

		var head := HBoxContainer.new()   # (the set's name is the panel's title)
		head.alignment = BoxContainer.ALIGNMENT_END
		var trade := Button.new()
		trade.text = tr("TRADE_IN")
		trade.custom_minimum_size = Vector2(140, 48)
		trade.focus_mode = Control.FOCUS_NONE
		trade.visible = Game.collectibles.can_trade_in(coll)   # (there only when a set is complete)
		trade.pressed.connect(func() -> void: Game.collectibles.trade_in(coll_id))
		head.add_child(trade)
		inner.add_child(head)

		# Each item as its picture with how many you have of how many the next trade needs (red while short), its
		# name under it; uncommon and rare ones on their own tile colours.
		var items := HFlowContainer.new()
		items.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap") * 0.5))
		items.add_theme_constant_override("v_separation", int(UiTheme.size("hud_gap") * 0.5))
		var need := Game.collectibles.coll_need(coll)
		for item: Dictionary in coll["items"]:
			var count := int(Game.collectibles.owned.get(item["id"], 0))
			var wanted := int(need[item["id"]])
			var rarity := str(item.get("rarity", "common"))
			var pic := ThingIcon.of(item.get("look", []), UiTheme.size("count_tile"))
			pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var tile := UiKit.count_tile(pic, "%d/%d" % [count, wanted], str(item["name"]), count < wanted,
				"count_tile" if rarity == "common" else "count_tile_" + rarity)
			tile.tooltip_text = "%s (%s)" % [item["name"], tr(RARITY_KEYS.get(rarity, "RARITY_COMMON"))]
			items.add_child(tile)
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


## Each ribbon as one card: the medal of the tier being worked toward (or the last one won), its name, and a bar
## for how far along it is ("12 / 25"). No legend of the four tiers and no intro: the medal's colour is the tier.
func build_ribbons(content: VBoxContainer) -> void:
	var ids: Array[String] = []
	for r in Game.ribbons.ribbon_data.get("ribbons", []):
		ids.append(str(r["id"]))
	var list := CardList.make(ids, ribbon_face, func(_id: String) -> void: pass,
		hud.get_viewport().get_visible_rect().size.x)
	content.add_child(list)
	BookPanel.set_live(content, list.refresh)


## One ribbon's card face: the medal of the tier being worked toward (or the last one won, faded while still to
## win), its name, and a bar for how far along it is ("12 / 25"); none before it is started.
func ribbon_face(ribbon_id: String) -> Dictionary:
	var data: Dictionary = Game.ribbons.ribbon_data
	var tier_names: Array = data.get("tiers", [])
	for r in data.get("ribbons", []):
		if str(r["id"]) != ribbon_id:
			continue
		var earned := int(Game.ribbons.ribbon_tiers.get(r["id"], 0))
		var thresholds: Array = r["thresholds"]
		var value := Game.ribbons.stat(r["stat"])
		var done := earned >= thresholds.size()
		var shown := mini(earned, tier_names.size() - 1) if done else earned
		var face := {"name": str(r["name"]), "icon": ["ribbon", UiTheme.color("ribbon_tier_%d" % shown), not done],
			"long": "%s: %s" % [r["name"], r["what"]]}
		if done:
			face["bar"] = [1.0, tr("RIBBON_DONE")]
			face["long"] = tr("COMPLETE") % [value, r["what"]]
		elif value > 0:   # (not started: the medal and its name only, no "0 / 25")
			var goal := int(thresholds[earned])
			face["bar"] = [float(mini(value, goal)) / goal, "%d / %d" % [mini(value, goal), goal]]   # not-ui
		return face
	return {}
