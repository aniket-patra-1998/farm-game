class_name HudCrafting
extends RefCounted
## The crafting buildings' panel: recipes, what is cooking, what is ready.
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner


## A crafting building: slots in use, recipes by star, goods made, bushels and the Farmers Market.
func build_crafting(content: VBoxContainer) -> void:
	var o := Game.object_by_uid(hud._building_uid)
	if o.is_empty():
		hud._book.close_panel()
		return
	var uid := hud._building_uid
	var lvl := Game.level_of(o)
	# Slots
	var top := BookPanel.card()
	top.add_child(
		BookPanel.text(
			tr("OF_STARS_CRAFTING_SLOTS_RECIPE_MASTERY") % [
				lvl,
				lvl,
				Game.crafting.building_recipe_stars(o["id"])
			],
			20
		)
	)
	for slot in o.get("slots", []):
		var left := int(slot["done"]) - Game.now()
		var what := tr("SLOT_READY") if left <= 0 else tr("READY_IN_3") + FarmGrid.format_duration(left)
		top.add_child(BookPanel.text("%s: %s" % [Game.catalog.get_def(slot["r"]).name, what], 18))
	if Game.crafting.free_slots(o) > 0:
		top.add_child(
			BookPanel.text(
				(tr("ONE_FREE_SLOT_PICK_A_RECIPE") if Game.crafting.free_slots(o) == 1
					else tr("FREE_SLOTS_PICK_A_RECIPE_BELOW")) % Game.crafting.free_slots(o),
				18,
				BookPanel.CREAM
			)
		)
	content.add_child(BookPanel.card_frame(top))
	# Recipes
	content.add_child(BookPanel.text(tr("RECIPES"), 26, BookPanel.SUN))
	for r in Game.crafting.recipes_of(o["id"]):
		content.add_child(recipe_row(uid, o, r))
	# Goods
	content.add_child(BookPanel.text(tr("YOUR_GOODS"), 26, BookPanel.SUN))
	var any_goods := false
	for r in Game.crafting.recipes_of(o["id"]):
		var n := int(Game.crafting.goods.get(r.id, 0))
		if n <= 0:
			continue
		any_goods = true
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 10)
		row.add_child(BookPanel.text("%d %s" % [n, r.name], 20))
		var rid := r.id
		var sell := hud._panel_button(tr("SELL_COINS") % FarmHud._thousands(Game.crafting.good_price(rid)))
		sell.pressed.connect(func() -> void:
			Game.crafting.sell_good(rid)
			hud._book.refresh())
		row.add_child(sell)
		var use := hud._panel_button(tr("USE_FUEL") % Game.crafting.good_fuel(rid))
		use.pressed.connect(func() -> void:
			hud.show_message(tr("FUEL_2") % Game.crafting.use_good(rid))
			hud._book.refresh())
		row.add_child(use)
		content.add_child(BookPanel.card_frame(row))
	if not any_goods:
		content.add_child(
			BookPanel.text(
				tr("NOTHING_YET_FINISHED_CRAFTS_LAND_HERE"),
				17,
				BookPanel.CREAM
			)
		)
	# Stars
	var cost := Game.crafting.star_cost(o)
	if not cost.is_empty():
		var up := BookPanel.card()
		var have := Game.crafting.building_recipe_stars(o["id"])
		up.add_child(BookPanel.text(tr("NEXT_STAR_COINS_AND_RECIPE_MASTERY") % [
			FarmHud._thousands(int(cost["coins"])), int(cost["recipe_stars"]), have, int(cost["gems"])], 18))
		var row2 := HFlowContainer.new()
		row2.add_theme_constant_override("h_separation", 10)
		var with_coins := hud._panel_button(tr("UPGRADE_WITH_COINS"))
		with_coins.disabled = not Game.crafting.can_add_star(uid, false)
		with_coins.pressed.connect(func() -> void:
			Game.crafting.add_star(uid, false)
			hud._book.refresh())
		row2.add_child(with_coins)
		var with_gems := hud._panel_button(tr("UPGRADE_GEMS") % int(cost["gems"]))
		with_gems.disabled = not Game.crafting.can_add_star(uid, true)
		with_gems.pressed.connect(func() -> void:
			Game.crafting.add_star(uid, true)
			hud._book.refresh())
		row2.add_child(with_gems)
		up.add_child(row2)
		content.add_child(BookPanel.card_frame(up))
	# Bushels and the Farmers Market
	content.add_child(
		BookPanel.text(
			tr("BUSHELS_OF") % [Game.crafting.total_bushels(), CraftingSystem.BUSHEL_CAP],
			26,
			BookPanel.SUN
		)
	)
	var held: Array[String] = []
	for c in Game.crafting.bushels:
		held.append("%d %s" % [int(Game.crafting.bushels[c]), Game.crops[c]["name"]])
	content.add_child(
		BookPanel.text(
			", ".join(PackedStringArray(held)) if not held.is_empty() else tr("NONE_YET_HARVESTS_DROP_BUSHELS_OF"),
			17,
			BookPanel.CREAM
		)
	)
	content.add_child(BookPanel.text(tr("FARMERS_MARKET_TODAY"), 22, BookPanel.SUN))
	var stall := Game.crafting.market_stall()
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	for c in stall:
		var crop_id: String = c
		var b := hud._panel_button(
			tr("LEFT_COINS") % [Game.crops[crop_id]["name"], int(stall[c]), Game.crafting.bushel_price(crop_id)]
		)
		var full := Game.crafting.total_bushels() >= CraftingSystem.BUSHEL_CAP
		b.disabled = int(stall[c]) <= 0 or Game.coins < Game.crafting.bushel_price(crop_id) or full
		b.pressed.connect(func() -> void:
			Game.crafting.buy_bushel(crop_id)
			hud._book.refresh())
		flow.add_child(b)
	content.add_child(flow)


func recipe_row(uid: int, o: Dictionary, r: RecipeDef) -> Control:
	var inner := VBoxContainer.new()
	var unlocked := Game.crafting.recipe_unlocked(o, r.id)
	var stars := Game.crafting.recipe_stars(r.id)
	inner.add_child(BookPanel.text(r.name + (tr("MASTERY_OF") % stars if stars > 0 else ""), 20))
	var need: Array[String] = []
	for c in r.inputs():
		need.append("%d/%d %s" % [int(Game.crafting.bushels.get(c, 0)), int(r.inputs()[c]), Game.crops[c]["name"]])
	inner.add_child(BookPanel.text(", ".join(PackedStringArray(need)), 17))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	if not unlocked:
		row.add_child(BookPanel.text(tr("UNLOCKS_AT_STARS") % r.star(), 17, BookPanel.CREAM))
	else:
		var make := hud._panel_button(tr("MAKE_IT"))
		make.disabled = Game.crafting.craft_problem(uid, r.id) != ""
		var rid := r.id
		make.pressed.connect(func() -> void:
			Game.crafting.start_craft(uid, rid)
			hud._book.refresh())
		row.add_child(make)
		var missing := Game.crafting.missing_bushels(r.id)
		if not missing.is_empty() and Game.crafting.free_slots(o) > 0:
			var n := 0
			for c in missing:
				n += int(missing[c])
			var buy := hud._panel_button(tr("BUY_MISSING_GEMS") % (n * CraftingSystem.BUSHEL_GEM_COST))
			buy.disabled = Game.gems < n * CraftingSystem.BUSHEL_GEM_COST
			buy.pressed.connect(func() -> void:
				Game.crafting.buy_missing_and_craft(uid, rid)
				hud._book.refresh())
			row.add_child(buy)
	inner.add_child(row)
	return BookPanel.card_frame(inner)
