class_name HudMarket
extends RefCounted
## The Market: shelves of item cards by kind (tabs), the seeds, the land card and the mystery box.
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

## [kind, title key] of the Market's shelves, in order.
const SHELVES := [["tree", "TREES"], ["bloom", "BLOOMS"], ["animal", "ANIMALS"], ["building", "BUILDINGS"],
	["vehicle", "VEHICLES"], ["decor", "DECORATIONS"]]
## The Buildings shelf in FarmVille's sections, by each building's `tab` (BuildingDef.tab), crafting buildings
## among them.
const BUILDING_TABS := [["animal", "ANIMAL_BUILDINGS"], ["storage", "STORAGE_BUILDINGS"],
	["crafting", "CRAFTING"], ["decor", "DECORATIVE_BUILDINGS"]]
const BUILDING_KINDS := ["building", "barn", "crafting"]

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner


## The Market's shelves, FarmVille's way: Seeds, then one shelf per kind of item as a grid of cards, then
## Specials (land and the Mystery Box). Each shelf is a tab of the book.
func tabs() -> Array:
	var out: Array = [[tr("SEED_LIST"), hud.seeds.build_seeds]]
	for shelf: Array in SHELVES:
		var kind := str(shelf[0])
		out.append([tr(str(shelf[1])), func(content: VBoxContainer) -> void: build_shelf(content, kind)])
	out.append([tr("SPECIALS"), build_specials])
	return out


## Everything of one kind for sale, as a grid of cards (its picture, name, a line about it, its price), under a
## strip that tells all about a card that can't be bought yet when it is tapped (a phone has no tooltips).
func build_shelf(content: VBoxContainer, kind: String) -> void:
	content.add_child(BookPanel.text(tr("BUY_THEN_DRAG_ONTO_AN_OPEN"), 18, BookPanel.CREAM))
	var about := VBoxContainer.new()
	var strip := BookPanel.card_frame(about)
	strip.visible = false
	strip.set_meta(&"about", true)
	content.add_child(strip)
	var tell := func(id: String, it: Dictionary, why: String) -> void: show_about(strip, about, id, it, why)
	if kind != "building":
		_add_grid(content, shelf_items(kind, ""), tell)
		return
	for section: Array in BUILDING_TABS:
		var ids := shelf_items(kind, str(section[0]))
		if ids.is_empty():
			continue
		content.add_child(BookPanel.text(tr(str(section[1])), 22, BookPanel.SUN))
		_add_grid(content, ids, tell)


## The items on a shelf, in catalog order (`tab`: only buildings of that section; "" for any).
func shelf_items(kind: String, tab: String) -> Array[String]:
	var out: Array[String] = []
	for id in Game.item_order:
		var it := Game.item_data(id)
		if int(it["unlock_level"]) >= 99:
			continue
		if kind == "building":
			if str(it["kind"]) in BUILDING_KINDS and Game.building_def(id).tab() == tab:
				out.append(id)
		elif it["kind"] == kind:
			out.append(id)
	return out


func _add_grid(content: VBoxContainer, ids: Array[String], tell: Callable) -> void:
	var grid := UiKit.card_grid(hud.get_viewport().get_visible_rect().size.x)
	content.add_child(grid)
	for id in ids:
		var it := Game.item_data(id)
		grid.add_child(item_card(id, it, func(why: String) -> void: tell.call(id, it, why)))


## Fills the strip at the top of a shelf with all about one item: its picture and name, why it can't be bought
## now, what it gives, and each thing it needs with where to get it.
func show_about(strip: PanelContainer, about: VBoxContainer, id: String, it: Dictionary, why: String) -> void:
	for c in about.get_children():
		c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
	about.add_child(row)
	var pic := TextureRect.new()
	pic.texture = ItemIcons.of(id)
	pic.custom_minimum_size = Vector2.ONE * UiTheme.size("card_icon")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(pic)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(BookPanel.text(str(it["name"]), 22))
	if why != "":
		words.add_child(BookPanel.text(why, 18, UiTheme.color("price_short")))
	words.add_child(BookPanel.text(detail_of(id, it), 17))
	strip.visible = true
	hud._book.scroll_to_top()


## One item's card: tapping it buys it (and puts it in hand to place), or, when it can't be bought now, shows
## all about it in the shelf's strip (`tell`, given why).
func item_card(id: String, it: Dictionary, tell: Callable) -> Button:
	var locked := Game.level() < int(it["unlock_level"])
	var verdict := Game.buildings.can_buy(id)
	var blocked := locked or verdict.why in [BuildingSystem.Why.LIMIT, BuildingSystem.Why.GROUP_LIMIT,
		BuildingSystem.Why.REQUIRES]
	var affordable := Game.can_afford_item(id)
	var unmet := 0
	for need in Requirements.list(Game, id):
		if not need["ok"]:
			unmet += 1
	var badge: Control
	if locked:
		badge = UiKit.price_badge("lock", tr("UNLOCKS_LEVEL") % int(it["unlock_level"]))
	elif blocked:
		badge = UiKit.price_badge("", verdict.short)
	else:
		var price := price_of(id, it)
		badge = UiKit.price_badge(price[0], price[1], not affordable)
	var line := tr("NEEDS_N_FIRST") % unmet if unmet > 0 and not locked else short_detail(id, it)
	var card := UiKit.item_card(ItemIcons.of(id), str(it["name"]), line, badge, blocked)
	var buyable := not blocked and affordable and unmet == 0
	card.set_meta(&"buyable", buyable)
	card.pressed.connect(func() -> void:
		if buyable:
			hud._book.close_panel()
			hud.place_requested.emit(id)
		elif locked:
			tell.call(tr("UNLOCKS_AT_LEVEL") % [it["name"], int(it["unlock_level"])])
		elif blocked:
			tell.call(verdict.text)
		elif not affordable:
			tell.call(tr("NOT_ENOUGH_TO_BUY") % it["name"])
		else:
			tell.call(""))
	return card


## Land and the Mystery Box.
func build_specials(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text(tr("LAND"), 26, BookPanel.SUN))
	content.add_child(land_card())
	content.add_child(mystery_box_card())


## What an item costs, as [badge icon, words]: coins, gems, or free.
func price_of(id: String, it: Dictionary) -> Array:
	if it["kind"] == "crafting":
		var price := Game.crafting.crafting_price(id)
		return ["gem", str(int(price["gems"]))] if price.has("gems") \
			else ["coin", FarmHud._thousands(int(price["coins"]))]
	if it.has("gem_cost"):
		return ["gem", str(int(it["gem_cost"]))]
	if int(it["cost"]) > 0:
		return ["coin", FarmHud._thousands(int(it["cost"]))]
	return ["", tr("FREE_FRAME")]


## A short line for a card: what the item gives and how often, or what it holds.
func short_detail(id: String, it: Dictionary) -> String:
	match str(it["kind"]):
		"building":
			return tr("HOLDS_N") % Game.building_def(id).capacity(1) if it.has("holds") or it.has("holds_kind") else ""
		"decor":
			return tr("PLUS_XP") % Game.buy_xp(id)
		"vehicle", "crafting":
			return ""
		_:
			if it.has("cycle_seconds") and it.has("payout"):
				return tr("EVERY_PAYS") % [FarmGrid.format_duration(int(it["cycle_seconds"])), int(it["payout"])]
	return ""


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


## All about an item (the strip at the top of its shelf): what it holds or gives, and what it needs, with where
## to get what's missing.
func detail_of(id: String, it: Dictionary) -> String:
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
				int(round(int(it["cost"]) * Balance.f("market.sell_share")))
			]
		_:
			var what: String = it.get("product", tr("FRUIT"))
			detail = tr("EVERY_COINS_XP") % [
				what, FarmGrid.format_duration(int(it["cycle_seconds"])), int(it["payout"]), int(it["xp"])]
	for need in Requirements.list(Game, id):
		detail += "\n" + ("✓ " if need["ok"] else "• ") + str(need["text"])
		if not need["ok"] and str(need.get("hint", "")) != "":
			detail += " — " + str(need["hint"])
	return detail


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
	var cost := int(Game.mystery.box_data.get("gem_cost", Balance.i("mystery.mystery_box_gem_cost")))
	var buy := hud._panel_button(tr("OPEN_ONE_GEMS") % cost)
	buy.disabled = Game.gems < cost
	buy.pressed.connect(func() -> void:
		var prize := Game.mystery.buy_mystery_box()
		if prize != "":
			hud.show_message(tr("YOU_GOT") + prize)
			hud._book.refresh())
	inner.add_child(buy)
	return BookPanel.card_frame(inner)
