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
		tr("ITEMS_TURN_UP_WHILE_YOU_FARM"), tr("ITEMS_TURN_UP_WHILE_YOU_FARM_INFO"), 20, BookPanel.CREAM))
	var grid := UiKit.card_grid(hud.get_viewport().get_visible_rect().size.x)
	for coll in Game.collectibles.collections:
		grid.add_child(set_card(coll))
	content.add_child(grid)


## One set's card in the grid: a ring (items held of the set's items) with the count in it, and its name.
func set_card(coll: Dictionary) -> Button:
	var items: Array = coll["items"]
	var held := 0
	for item: Dictionary in items:
		held += 1 if int(Game.collectibles.owned.get(item["id"], 0)) > 0 else 0
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(UiTheme.size("card_width"), UiTheme.size("card_width"))
	card.add_theme_stylebox_override("normal", UiKit.card_box())
	card.add_theme_stylebox_override("hover", UiKit.card_box())
	card.add_theme_stylebox_override("pressed", UiKit.card_box())
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var ring := BuildingSheet.Ring.new()
	ring.custom_minimum_size = Vector2.ONE * UiTheme.size("card_width") * RING_SHARE
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.share = float(held) / maxf(items.size(), 1.0)
	ring.words = "%d/%d" % [held, items.size()]   # not-ui
	col.add_child(ring)
	var name := BookPanel.text(str(coll["name"]), 18)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name)
	if Game.collectibles.can_trade_in(coll):
		var ready := BookPanel.text(tr("SLOT_READY"), 16, BookPanel.GOOD)
		ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ready.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(ready)
	var coll_id := str(coll["id"])
	card.pressed.connect(func() -> void:
		hud._book.open_panel(str(coll["name"]), func(c: VBoxContainer) -> void: build_collection(c, coll_id)))
	UiFx.press_bounce(card)
	return card


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
	var data: Dictionary = Game.ribbons.ribbon_data
	var tier_names: Array = data.get("tiers", [])
	for r in data.get("ribbons", []):
		var earned := int(Game.ribbons.ribbon_tiers.get(r["id"], 0))
		var thresholds: Array = r["thresholds"]
		var value := Game.ribbons.stat(r["stat"])
		var done := earned >= thresholds.size()
		var shown := mini(earned, tier_names.size() - 1) if done else earned

		var inner := BookPanel.card()
		inner.add_theme_constant_override("separation", 8)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		var medal := UiIcon.make("ribbon", UiTheme.size("ribbon_icon"), UiTheme.color("ribbon_tier_%d" % shown))
		if not done:
			medal.modulate = Color(1, 1, 1, 0.55)   # (still to win)
		head.add_child(medal)
		var title := BookPanel.text(r["name"], 26)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		inner.add_child(head)
		if done:
			inner.add_child(BookPanel.text(tr("COMPLETE") % [value, r["what"]], 18))
		elif value > 0:   # (not started: the medal and its name only, no "0 / 25")
			var goal := int(thresholds[earned])
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size.y = 18
			bar.max_value = goal
			bar.value = mini(value, goal)
			inner.add_child(bar)
			inner.add_child(BookPanel.text("%d / %d" % [mini(value, goal), goal], 18))   # not-ui
		content.add_child(BookPanel.card_frame(inner))
