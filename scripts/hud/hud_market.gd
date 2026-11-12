class_name HudMarket
extends RefCounted
## The Market panel: the shop rows, the land card and the mystery box.
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner


func build_market(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text(tr("LAND"), 26, BookPanel.SUN))
	content.add_child(land_card())
	content.add_child(mystery_box_card())
	content.add_child(BookPanel.text(
		tr("BUY_THEN_DRAG_ONTO_AN_OPEN"), 20, BookPanel.CREAM))
	for section in [
		["tree", tr("TREES")],
		["bloom", tr("BLOOMS")],
		["animal", tr("ANIMALS")],
		["building", tr("BUILDINGS")],
		["crafting", tr("CRAFTING")],
		["vehicle", tr("VEHICLES")],
		["decor", tr("DECORATIONS")]
	]:
		content.add_child(BookPanel.text(section[1], 26, BookPanel.SUN))
		for id in Game.item_order:
			var it := Game.item_data(id)
			if it["kind"] != section[0] or int(it["unlock_level"]) >= 99:
				continue
			content.add_child(market_row(id, it))


func land_card() -> Control:
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	var step := Game.land.next_expansion()
	var size := Game.farm_size
	if step.is_empty():
		inner.add_child(BookPanel.text(tr("YOUR_FARM_IS_FULL_SIZE_X") % [size, size], 22))
		return BookPanel.card_frame(inner)
	var next := int(step["size"])
	inner.add_child(BookPanel.text(tr("EXPAND_FROM_X_TO_X") % [size, size, next, next], 22))
	inner.add_child(BookPanel.text(
		tr("ADDS_PLOTS_THE_DASHED_AREA_ON") % (next * next - size * size), 17))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 12)
	var with_coins := hud._panel_button("")
	if Game.level() < int(step["level"]):
		with_coins.text = tr("COINS_REACH_LEVEL") % int(step["level"])
		with_coins.disabled = true
	else:
		with_coins.text = tr("EXPAND_COINS") % FarmHud._thousands(int(step["coins"]))
		with_coins.disabled = Game.coins < int(step["coins"])
	with_coins.pressed.connect(func() -> void: Game.land.expand(false))
	row.add_child(with_coins)
	var with_gems := hud._panel_button(tr("EXPAND_NOW_GEMS") % int(step["gems"]))
	with_gems.disabled = Game.gems < int(step["gems"])
	with_gems.pressed.connect(func() -> void: Game.land.expand(true))
	row.add_child(with_gems)
	inner.add_child(row)
	return BookPanel.card_frame(inner)


func market_row(id: String, it: Dictionary) -> Control:
	var locked := Game.level() < int(it["unlock_level"])
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(BookPanel.text(it["name"], 22))
	var detail: String
	match it["kind"]:
		"building":
			var holds: String
			if it.has("holds_kind"):
				holds = tr("HOLDS_VEHICLES") if it["holds_kind"] == "vehicle" else tr("FRUIT_TREES")
			else:
				var names: Array[String] = []
				for a in it["holds"]:
					names.append(Game.item_data(a)["name"].to_lower() + "s")
				holds = ", ".join(PackedStringArray(names))
			var fp := Game.footprint(id)
			var def := Game.building_def(id)
			detail = tr("HOLDS_X_TILES_UPGRADES_TO") % [def.capacity(1), holds, fp.x, fp.y, def.capacity(def.max_level())]
		"crafting":
			detail = tr("CRAFTING_RECIPES_OVER_STARS_PER_CRAFT") % FarmGrid.format_duration(int(it.get("craft_seconds", 21600)))
		"vehicle":
			var verbs := {
				"plow": tr("PLOWS"),
				"plant": tr("PLANTS"),
				"harvest": tr("HARVESTS"),
				"all": tr("HARVESTS_PLOWS_AND_PLANTS")
			}
			detail = tr("X_PLOTS_A_TAP_FUEL_A") % [
				verbs.get(it["job"], ""),
				int(it.get("fuel_per_plot", 1))
			]
			if it.has("build_materials"):
				detail += tr("CHASSIS_FINISHED_WITH_VEHICLE_PARTS") % int(it["build_materials"]["vehicle_parts"])
		"decor":
			var fpd := Game.footprint(id)
			detail = tr("DECORATION_XP_X_SELLS_FOR") % [
				Game.buy_xp(id),
				fpd.x,
				fpd.y,
				int(round(int(it["cost"]) * GameState.SELL_SHARE))
			]
		_:
			var what: String = it.get("product", tr("FRUIT"))
			detail = tr("EVERY_COINS_XP") % [
				what, FarmGrid.format_duration(int(it["cycle_seconds"])), int(it["payout"]), int(it["xp"])]
	info.add_child(BookPanel.text(detail, 17))
	for need in Requirements.list(Game, id):
		# What it needs, and how far along: a tick when met, and where to get what's missing.
		var line := ("✓ " if need["ok"] else "• ") + str(need["text"])
		if not need["ok"]:
			line += " — " + str(need["hint"])
		info.add_child(BookPanel.text(line, 16, BookPanel.CREAM))
	inner.add_child(info)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(150, 52)
	buy.focus_mode = Control.FOCUS_NONE
	var verdict := Game.buildings.can_buy(id)
	if locked or verdict.why in [BuildingSystem.Why.LIMIT, BuildingSystem.Why.GROUP_LIMIT, BuildingSystem.Why.REQUIRES]:
		# Not yet, or the farm has as many as it may: say which, on the button.
		buy.text = verdict.short
		buy.tooltip_text = verdict.text
		buy.disabled = true
	else:
		if it["kind"] == "crafting":
			var price := Game.crafting.crafting_price(id)
			buy.text = ("%d gems" % int(price["gems"])) if price.has("gems") \
				else "%s coins" % FarmHud._thousands(int(price["coins"]))
		else:
			buy.text = ("%d gems" % int(it["gem_cost"])) if it.has("gem_cost") else (
				"%s coins" % FarmHud._thousands(int(it["cost"])) if int(it["cost"]) > 0 else tr("FREE_FRAME")
			)
		buy.disabled = not Game.can_afford_item(id)
		buy.pressed.connect(func() -> void:
			hud._book.close_panel()
			hud.place_requested.emit(id))
	inner.add_child(buy)
	return BookPanel.card_frame(inner)


## FarmVille's Mystery Box: one random prize, and the only way to get a Donkey.
func mystery_box_card() -> Control:
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	inner.add_child(BookPanel.text(tr("MYSTERY_BOX"), 22))
	inner.add_child(
		BookPanel.text(
			tr("ONE_SURPRISE_INSIDE_A_RARE_DECORATION"),
			17
		)
	)
	var cost := int(Game.mystery.box_data.get("gem_cost", MysterySystem.MYSTERY_BOX_GEM_COST))
	var buy := hud._panel_button(tr("OPEN_ONE_GEMS") % cost)
	buy.disabled = Game.gems < cost
	buy.pressed.connect(func() -> void:
		var prize := Game.mystery.buy_mystery_box()
		if prize != "":
			hud.show_message(tr("YOU_GOT") + prize)
			hud._book.refresh())
	inner.add_child(buy)
	return BookPanel.card_frame(inner)
