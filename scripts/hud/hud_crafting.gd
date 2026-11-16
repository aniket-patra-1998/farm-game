class_name HudCrafting
extends RefCounted
## The crafting buildings' panel: recipes, what is cooking, what is ready.
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

const BIGGEST := 5      # a crafting building's most stars (sizes)
const STAR_SIZE := 1.6   # its stars against a mastery star

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
	hud.buildings.add_building_bar(content, o)
	var lvl := Game.level_of(o)
	# Slots
	var top := BookPanel.card()
	top.add_child(star_row(lvl, Game.crafting.building_recipe_stars(o["id"])))
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
	var recipes: Array[String] = []
	for r in Game.crafting.recipes_of(o["id"]):
		recipes.append(r.id)
	content.add_child(CardList.rows(recipes, func() -> Control: return MarginContainer.new(),
		func(row: Control, rid: String) -> void:
			CardList.refill(row, recipe_row(uid, o, Game.catalog.get_def(rid) as RecipeDef))))
	# Goods (a feed building makes none: its rich feed goes to the Barn)
	var makes_goods := false
	for r in Game.crafting.recipes_of(o["id"]):
		makes_goods = makes_goods or not r.makes_feed()
	if makes_goods:
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
			tr("BUSHELS_OF") % [Game.crafting.total_bushels(), Balance.i("crafting.bushel_cap")],
			26,
			BookPanel.SUN
		)
	)
	var held: Array = []
	for c: String in Game.crafting.bushels:
		held.append([c, "×%d" % int(Game.crafting.bushels[c])])
	if held.is_empty():
		content.add_child(BookPanel.text(tr("NONE_YET_HARVESTS_DROP_BUSHELS_OF"), 17, BookPanel.CREAM))
	else:
		content.add_child(UiKit.count_row(held))
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
		var full := Game.crafting.total_bushels() >= Balance.i("crafting.bushel_cap")
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
	inner.add_child(BookPanel.text(r.name + (tr("MASTERY_OF") % stars if stars > 0 else ""), 20, BookPanel.CREAM))
	var need: Array = []
	for c: String in r.inputs():
		var have := int(Game.crafting.bushels.get(c, 0))
		need.append([c, "%d/%d" % [have, int(r.inputs()[c])], have < int(r.inputs()[c])])
	inner.add_child(UiKit.count_row(need))   # each bushel: have of need, red while short
	if r.makes_feed():
		inner.add_child(BookPanel.text(
			tr("RECIPE_MAKES_FEED") % [int(r.feed()["units"]), Game.crafting.feed_product_name(r)], 17,
			BookPanel.SUN))
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
			var buy := hud._panel_button(tr("BUY_MISSING_GEMS") % (n * Balance.i("crafting.bushel_gem_cost")))
			buy.disabled = Game.gems < n * Balance.i("crafting.bushel_gem_cost")
			buy.pressed.connect(func() -> void:
				Game.crafting.buy_missing_and_craft(uid, rid)
				hud._book.refresh())
			row.add_child(buy)
	inner.add_child(row)
	return inner   # (flat on the panel: the list draws a thin line between recipes)


## A crafting building's size and skill in one row: its stars (filled up to its size; one star, one crafting
## slot) and, once it has any, its recipe mastery stars.
static func star_row(size: int, recipe_stars: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for k in BIGGEST:
		var star := UiIcon.make("star", UiTheme.size("mastery_star") * STAR_SIZE)
		if k >= size:
			star.modulate = Color(1, 1, 1, 0.3)
		row.add_child(star)
	for words in [TranslationServer.translate("CRAFT_SLOTS") % size,
			TranslationServer.translate("RECIPE_STARS") % recipe_stars if recipe_stars > 0 else ""]:
		if words == "":
			continue
		var l := BookPanel.text(words, 18)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF   # (a wrapping label in a row has no width of its own)
		row.add_child(l)
	return row
