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

var hud: FarmHud
var _shelves := {}    # kind -> the ids for sale on that shelf, worked out once at load (the catalog doesn't change)
var _sections := {}   # building tab -> its ids


func _init(owner: FarmHud) -> void:
	hud = owner
	for id in Game.item_order:
		if not _for_sale(id):
			continue
		if Game.is_building_item(id):
			var tab := Game.building_def(id).tab()
			if not _sections.has(tab):
				_sections[tab] = [] as Array[String]
			(_sections[tab] as Array[String]).append(id)
		else:
			var kind := str(Game.item_data(id)["kind"])
			if not _shelves.has(kind):
				_shelves[kind] = [] as Array[String]
			(_shelves[kind] as Array[String]).append(id)


## The Market's shelves, FarmVille's way: Seeds, then one shelf per kind of item as a grid of cards. The Mystery
## Box opens the Decorations shelf and more land closes the Buildings shelf (no Specials tab of its own). Each
## shelf is a tab of the book.
func tabs() -> Array:
	var out: Array = [[tr("SEED_LIST"), hud.seeds.build_seeds]]
	for shelf: Array in SHELVES:
		var kind := str(shelf[0])
		out.append([tr(str(shelf[1])), func(content: VBoxContainer) -> void: build_shelf(content, kind)])
	return out


## Everything of one kind for sale, as a grid of cards (its picture, name, a line about it, its price), under a
## strip that tells all about a card that can't be bought yet when it is tapped (a phone has no tooltips). The
## page is live: a refresh (coins changed) updates the cards on screen and the land and box cards in place.
func build_shelf(content: VBoxContainer, kind: String) -> void:
	var lists: Array[CardList] = []
	var singles: Array = []   # [holder, builder] of the land card and the Mystery Box
	var about := VBoxContainer.new()
	var strip := BookPanel.card_frame(about)
	strip.visible = false
	strip.set_meta(&"about", true)
	content.add_child(strip)
	var tell := func(id: String, it: Dictionary, why: String) -> void: show_about(strip, about, id, it, why)
	if kind == "decor":
		singles.append([_single(content), mystery_box_card])   # (the Mystery Box first among the decorations)
	if kind != "building":
		lists.append(_add_list(content, shelf_items(kind), tell))
	else:
		for section: Array in BUILDING_TABS:
			var ids := building_section(str(section[0]))
			if ids.is_empty():
				continue
			content.add_child(BookPanel.text(tr(str(section[1])), int(UiTheme.design("font_section")), BookPanel.SUN))
			lists.append(_add_list(content, ids, tell))
		# More land, after the buildings: it is a farm's biggest building job.
		content.add_child(BookPanel.text(tr("LAND"), int(UiTheme.design("font_section")), BookPanel.SUN))
		singles.append([_single(content), land_card])
	var update := func() -> void:
		for list in lists:
			list.refresh()
		for one: Array in singles:
			var holder: Container = one[0]
			for c in holder.get_children():
				c.queue_free()
			holder.add_child((one[1] as Callable).call())
	update.call()
	BookPanel.set_live(content, update)


## A place on the page for one card that is built again on a refresh.
func _single(content: VBoxContainer) -> VBoxContainer:
	var holder := VBoxContainer.new()
	content.add_child(holder)
	return holder


## The items of one kind for sale, in catalog order (buildings have their own sections: building_section).
func shelf_items(kind: String) -> Array[String]:
	return _shelves.get(kind, [] as Array[String])


## The buildings for sale in one section of the Buildings shelf (their catalog `tab`), in catalog order.
func building_section(tab: String) -> Array[String]:
	return _sections.get(tab, [] as Array[String])


static func _for_sale(id: String) -> bool:
	return int(Game.item_data(id)["unlock_level"]) < 99 and Release.has(id)


func _add_list(content: VBoxContainer, ids: Array[String], tell: Callable) -> CardList:
	var list := CardList.make(ids, card_face, func(id: String) -> void: tap(id, tell),
		hud.get_viewport().get_visible_rect().size.x)
	content.add_child(list)
	return list


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


## One item's card face (CardFace): its picture, name, a line, its price, and whether it can be bought now and if
## not why (`why`, shown in the shelf's strip when tapped).
func card_face(id: String) -> Dictionary:
	var it := Game.item_data(id)
	var locked := Game.level() < int(it["unlock_level"])
	var verdict := Game.buildings.can_buy(id)
	var blocked := locked or verdict.why in [BuildingSystem.Why.LIMIT, BuildingSystem.Why.GROUP_LIMIT,
		BuildingSystem.Why.REQUIRES]
	var affordable := Game.can_afford_item(id)
	var unmet := 0
	for need in Requirements.list(Game, id):
		if not need["ok"]:
			unmet += 1
	var badge: Array
	var why := ""
	if locked:
		badge = ["lock", tr("UNLOCKS_LEVEL") % int(it["unlock_level"])]
		why = tr("UNLOCKS_AT_LEVEL") % [it["name"], int(it["unlock_level"])]
	elif blocked:
		badge = ["", verdict.short]
		why = verdict.text
	else:
		var price := price_of(id, it)
		badge = [price[0], price[1], not affordable]
		why = "" if affordable else tr("NOT_ENOUGH_TO_BUY") % it["name"]
	# Picture, name and price; what it earns and how fast on a long press (a card says only what's needed to pick).
	var detail := short_detail(id, it)
	return {
		"name": str(it["name"]),
		"line": tr("NEEDS_N_FIRST") % unmet if unmet > 0 and not locked else "",
		"badge": badge,
		"locked": blocked,
		"stars": MasteryStars.values(id),
		"long": "%s: %s" % [it["name"], detail] if detail != "" else "",
		"buyable": not blocked and affordable and unmet == 0,
		"why": why,
	}


## Tapping a card buys it (and puts it in hand to place), or, when it can't be bought now, shows all about it in
## the shelf's strip (`tell`, given why).
func tap(id: String, tell: Callable) -> void:
	var face := card_face(id)
	if face["buyable"]:
		hud._book.close_panel()
		hud.place_requested.emit(id)
	else:
		tell.call(id, Game.item_data(id), str(face["why"]))


## Land and the Mystery Box.
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
		BookPanel.info(
			tr("ONE_SURPRISE_INSIDE_A_RARE_DECORATION"), tr("ONE_SURPRISE_INSIDE_A_RARE_DECORATION_INFO"),
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
