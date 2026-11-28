class_name HudMarket
extends RefCounted
## The Market: shelves of item cards by kind (tabs), the seeds, the land card and the mystery box.
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

## [kind, title key] of the Market's shelves, in order.
const SHELVES := [["tree", "TREES"], ["bloom", "BLOOMS"], ["animal", "ANIMALS"], ["building", "BUILDINGS"],
	["vehicle", "VEHICLES"], ["decor", "DECORATIONS"], [LIMITED, "LIMITED"]]
## The Limited shelf is not a kind of item: the limited animals and trees (LimitedSystem) have it to themselves,
## last (owner, 20 Nov), and are not on their kinds' own shelves.
const LIMITED := "limited"   # not-ui
const LIMITED_KINDS := [["animal", "ANIMALS"], ["tree", "TREES"]]   # the Limited shelf's sections, in order
## The Gems page's pack names, by data/store.json's product ids.
const PACK_NAMES := {"starter_pack": "STORE_STARTER_PACK", "gems_small": "STORE_GEMS_SMALL",
	"gems_medium": "STORE_GEMS_MEDIUM", "gems_large": "STORE_GEMS_LARGE"}   # (data/store.json's products)
## The Buildings shelf in FarmVille's sections, by each building's `tab` (BuildingDef.tab), crafting buildings
## among them.
const BUILDING_TABS := [["animal", "ANIMAL_BUILDINGS"], ["storage", "STORAGE_BUILDINGS"],
	["crafting", "CRAFTING"], ["decor", "DECORATIVE_BUILDINGS"]]

var hud: FarmHud
var _shelves := {}    # kind -> the ids for sale on that shelf, worked out once at load (the catalog doesn't change)
var _sections := {}   # building tab -> its ids
var _shelf_names := {}   # id -> the shelf it is on (a search result says it)
var _limited_kind := ""  # the plain kind whose varieties the Limited shelf shows ("": its front, a card a kind)


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
			var kind := LIMITED if on_limited_shelf(id) else str(Game.item_data(id)["kind"])
			if not _shelves.has(kind):
				_shelves[kind] = [] as Array[String]
			(_shelves[kind] as Array[String]).append(id)


## The Market's shelves, FarmVille's way: Seeds, then one shelf per kind of item as a grid of cards. The Mystery
## Box opens the Decorations shelf and more land closes the Buildings shelf (no Specials tab of its own). Each
## shelf is a tab of the book.
func tabs() -> Array:
	_limited_kind = ""   # (the Market opens with the Limited shelf at its front)
	var out: Array = [[tr("SEED_LIST"), hud.seeds.build_seeds]]
	for shelf: Array in SHELVES:
		var kind := str(shelf[0])
		if kind == LIMITED and shelf_items(kind).is_empty():
			continue   # (a release without limited things has no such tab)
		out.append([tr(str(shelf[1])), func(content: VBoxContainer) -> void: build_shelf(content, kind)])
	out.append([tr("GEM_SHOP"), build_gems])   # (last: the gem meter's + opens it, docs/PURCHASES.md)
	return out


## The Gems page: the starter pack (until bought) and the three gem packs, each with what it gives and Play's own
## price; where the store can't sell (not a Play build, offline, Play not answered yet) it says so.
func build_gems(content: VBoxContainer) -> void:
	var store := Game.purchases
	if not store.open():
		content.add_child(BookPanel.info(tr("GEM_SHOP"), tr("STORE_UNAVAILABLE"), UiTheme.HEADING, BookPanel.SOFT))
		return
	for id: String in store.on_sale():
		var box := VBoxContainer.new()
		box.add_child(BookPanel.text(tr(str(PACK_NAMES.get(id, "GEM_SHOP"))), int(UiTheme.design("font_count_name")),
			BookPanel.HEAD))
		box.add_child(BookPanel.text(UiTheme.tidy(store.words(id)), int(UiTheme.design("font_card")), BookPanel.INK))
		var buy := UiKit.primary(hud.panel_button(str(store.prices.get(id, ""))))
		buy.pressed.connect(store.buy.bind(id))
		box.add_child(buy)
		content.add_child(BookPanel.card_frame(box))


## The tab that sells `id` (an item, or a kind of item): Seeds is tab 0 and the shelves follow; the first shelf for
## anything else.
func tab_for(id: String) -> int:
	var d := Game.catalog.get_def(id)
	var kind := LIMITED if on_limited_shelf(id) else (d.kind if d != null else id)
	if Game.limited.is_limited(id):
		_limited_kind = _plain_kind(id)   # (the shelf opens on that kind's varieties)
	var tab := 0
	for shelf: Array in SHELVES:
		if str(shelf[0]) == LIMITED and shelf_items(LIMITED).is_empty():
			continue
		tab += 1
		if str(shelf[0]) == kind:
			return tab
	return 1


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
	if kind == LIMITED:
		if AssetPacks.shared != null and AssetPacks.shared.total() > 0 and not AssetPacks.shared.downloaded():
			singles.append([_single(content), download_card])   # (first: the download that makes them buyable)
		lists.append_array(_build_limited(content, tell))
	elif kind != "building":
		lists.append(_add_list(content, shelf_items(kind), tell))
	else:
		for section: Array in BUILDING_TABS:
			var ids := building_section(str(section[0]))
			if ids.is_empty():
				continue
			content.add_child(BookPanel.text(tr(str(section[1])), int(UiTheme.design("font_section")), BookPanel.HEAD))
			lists.append(_add_list(content, ids, tell))
		# More land, after the buildings: it is a farm's biggest building job.
		content.add_child(BookPanel.text(tr("LAND"), int(UiTheme.design("font_section")), BookPanel.HEAD))
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


## The Limited shelf (owner, 27 Nov: "too clunky and messy"; it was every variety at once, a heading and a
## half-empty row a kind, nineteen screens of them). Its front is short: the landmarks (the showpieces to save
## for), then one card for each kind that has limited varieties, animals and then trees; a tap on a kind's card
## shows only that kind's varieties, with a way back. Returns the card lists it made.
func _build_limited(content: VBoxContainer, tell: Callable) -> Array[CardList]:
	var lists: Array[CardList] = []
	var section := int(UiTheme.design("font_section"))
	if _limited_kind != "":
		var back := UiKit.quiet_button("‹ " + tr("LIMITED"), section)
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		back.pressed.connect(func() -> void: _show_limited(content, ""))
		content.add_child(back)
		content.add_child(BookPanel.text(UiTheme.tidy(Game.name_of(_limited_kind) if Game.items.has(_limited_kind)
			else _limited_kind), section, BookPanel.HEAD))
		lists.append(_add_list(content, limited_of_kind(_limited_kind), tell))
		return lists
	if not landmarks().is_empty():
		content.add_child(BookPanel.text(tr("LANDMARKS"), section, BookPanel.HEAD))
		lists.append(_add_list(content, landmarks(), tell))
	for part: Array in LIMITED_KINDS:
		var kinds := limited_kinds(str(part[0]))
		if kinds.is_empty():
			continue
		content.add_child(BookPanel.text(tr(str(part[1])), section, BookPanel.HEAD))
		var list := CardList.make(kinds, kind_face, func(first: String) -> void: _show_limited(content, _plain_kind(first)),
			hud.get_viewport().get_visible_rect().size.x)
		list.search_menu = ""   # (the landmarks' list, or none, searches: a kind's card is not a thing for sale)
		content.add_child(list)
		lists.append(list)
	return lists


## Turns the Limited shelf to one kind's varieties (`kind` a plain kind's id), or back to its front (""), from the
## top.
func _show_limited(content: VBoxContainer, kind: String) -> void:
	_limited_kind = kind
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	build_shelf(content, LIMITED)
	var scroll := content.get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	if scroll != null:
		(scroll as ScrollContainer).scroll_vertical = 0


## A kind's card on the Limited shelf's front, by the first of its varieties (whose picture it wears): the plain
## kind's name and how many varieties it has.
func kind_face(first: String) -> Dictionary:
	var plain := _plain_kind(first)
	return {
		"name": Game.name_of(plain) if Game.items.has(plain) else plain,
		"line": "",
		"badge": ["", tr("N_VARIETIES") % UiTheme.number(limited_of_kind(plain).size())],
		"locked": false,
		"stars": [],
		"long": "",
		"buyable": true,
		"why": "",
	}


## The Limited tab's download (owner, 20 Nov: "a download option in the limited tab, when a player clicks it, it
## first downloads everything so that placing is seamless; other games like BGMI do it"): the limited animals'
## files, once, before they can be bought. Shows how far it has got; once all are here it is gone.
func download_card() -> Control:
	var packs := AssetPacks.shared
	var box := VBoxContainer.new()
	var frame := BookPanel.card_frame(box)
	if packs == null or packs.downloaded():
		frame.visible = false
		return frame
	box.add_child(BookPanel.text(tr("LIMITED_DOWNLOAD_TITLE"), int(UiTheme.design("font_count_name")), BookPanel.HEAD))
	var done := packs.total() - packs.missing()
	if packs.downloading():
		box.add_child(BookPanel.text(UiTheme.tidy(tr("LIMITED_DOWNLOADING") % [UiTheme.number(done),
			UiTheme.number(packs.total())]), int(UiTheme.design("font_card")), BookPanel.INK))
		box.add_child(UiKit.thin_bar(done, packs.total()))
	else:
		box.add_child(BookPanel.text(UiTheme.tidy(tr("LIMITED_DOWNLOAD_WHY") % UiTheme.number(packs.total())),
			int(UiTheme.design("font_card")), BookPanel.INK))
		var go := UiKit.primary(hud.panel_button(tr("LIMITED_DOWNLOAD")))
		go.pressed.connect(func() -> void:
			packs.fetch_all()
			hud.book.refresh())
		box.add_child(go)
	if not packs.arrived.is_connected(_on_pack):
		packs.arrived.connect(_on_pack)   # (each pack that comes moves the bar on; the last makes them buyable)
	return frame


func _on_pack(_paths: Array[String]) -> void:
	if hud != null and hud.book != null and hud.book.is_open():
		hud.book.refresh()


## A place on the page for one card that is built again on a refresh.
func _single(content: VBoxContainer) -> VBoxContainer:
	var holder := VBoxContainer.new()
	content.add_child(holder)
	return holder


## A card found by the Market's search: its own face (a seed's or the Market's), saying which shelf it is on.
func search_face(id: String) -> Dictionary:
	var face: Dictionary = hud.seeds.seed_face(id) if Game.crops.has(id) else card_face(id)
	if str(face.get("line", "")) == "":
		face["line"] = _shelf_names.get(id, "")
	return face


## Everything for sale, every shelf (seeds first), in shelf order (what the Market's search looks among).
func all_for_sale() -> Array[String]:
	var out: Array[String] = hud.seeds.ids().duplicate()
	var naming := _shelf_names.is_empty()
	for id in out:
		_shelf_names[id] = tr("SEED_LIST")
	for shelf: Array in SHELVES:
		var ids := _shelf_ids(str(shelf[0]))
		out.append_array(ids)
		if naming:
			for id in ids:
				_shelf_names[id] = tr(str(shelf[1]))
	return out


## The ids on shelf `kind` (the Buildings shelf's sections one after another).
func _shelf_ids(kind: String) -> Array[String]:
	if kind != "building":
		return shelf_items(kind)
	var out: Array[String] = []
	for section: Array in BUILDING_TABS:
		out.append_array(building_section(str(section[0])))
	return out


## The items of one kind for sale, in catalog order (buildings have their own sections: building_section).
func shelf_items(kind: String) -> Array[String]:
	return _shelves.get(kind, [] as Array[String])


## The limited things of one kind (animal, tree) for sale, in catalog order: a section of the Limited shelf.
## Limited things `ids` by the plain kind each is a variety of, in order: [[that kind's name, its varieties]].
func limited_groups(ids: Array[String]) -> Array:
	var order: Array[String] = []
	var by := {}
	for id in ids:
		var plain := _plain_kind(id)
		if not by.has(plain):
			order.append(plain)
			by[plain] = [] as Array[String]
		(by[plain] as Array[String]).append(id)
	var out := []
	for plain in order:
		out.append([Game.name_of(plain) if Game.items.has(plain) else plain, by[plain]])
	return out


## The plain kind limited `id` is a variety of: a tree names it; an animal's is the first grown, plain animal of
## its family in the catalog.
func _plain_kind(id: String) -> String:
	var it := Game.item_data(id)
	var of := str(it.get("limited_of", ""))
	if of != "":
		return of
	var family := str(it.get("family", ""))
	for other: String in Game.item_order:
		var o := Game.item_data(other)
		if str(o.get("family", "")) == family and str(o.get("kind", "")) == str(it.get("kind", "")) \
				and not Game.limited.is_limited(other) and not bool(o.get("young", false)):
			return other
	return family


## Whether `id` is sold on the Limited shelf: a limited animal or tree, or a landmark.
func on_limited_shelf(id: String) -> bool:
	if Game.limited.is_limited(id):
		return true
	var d := Game.catalog.get_def(id) as DecorationDef
	return d != null and d.is_landmark()


## The landmarks for sale (the showpieces to save for), in catalog order.
func landmarks() -> Array[String]:
	return shelf_items(LIMITED).filter(func(id: String) -> bool: return not Game.limited.is_limited(id))


## The first variety of each plain kind that has limited ones of `kind` (animal, tree), in order: the kinds'
## cards on the Limited shelf's front.
func limited_kinds(kind: String) -> Array[String]:
	var out: Array[String] = []
	for group: Array in limited_groups(limited_section(kind)):
		out.append(str((group[1] as Array[String])[0]))
	return out


## The limited varieties of one plain kind (its id) for sale, in catalog order.
func limited_of_kind(plain: String) -> Array[String]:
	return shelf_items(LIMITED).filter(func(id: String) -> bool:
		return Game.limited.is_limited(id) and _plain_kind(id) == plain)


func limited_section(kind: String) -> Array[String]:
	return shelf_items(LIMITED).filter(func(id: String) -> bool: return str(Game.item_data(id)["kind"]) == kind)


## The buildings for sale in one section of the Buildings shelf (their catalog `tab`), in catalog order.
func building_section(tab: String) -> Array[String]:
	return _sections.get(tab, [] as Array[String])


static func _for_sale(id: String) -> bool:
	return int(Game.item_data(id)["unlock_level"]) < 99 and Release.has(id)


func _add_list(content: VBoxContainer, ids: Array[String], tell: Callable) -> CardList:
	var list := CardList.make(ids, card_face, func(id: String) -> void: tap(id, tell),
		hud.get_viewport().get_visible_rect().size.x)
	# Search: the first list of a shelf searches the whole Market (every shelf), the others leave it to that one.
	var first := content.find_children("*", "CardList", false, false).is_empty()   # not-ui (a class)
	list.search_menu = "market" if first else ""
	if first:   # (seeds too, and every result says its shelf)
		list.search_pool = all_for_sale()
		list.search_face_of = search_face
		list.search_on_tap = func(id: String) -> void:
			if Game.crops.has(id):
				if Game.is_unlocked(id):
					hud.choose_seed(id)
			else:
				tap(id, tell)
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
	words.add_child(BookPanel.text(str(it["name"]), UiTheme.HEADING, BookPanel.SOFT))
	if why != "":
		words.add_child(BookPanel.text(why, UiTheme.HEADING, UiTheme.color("note")))
	words.add_child(BookPanel.text(detail_of(id, it), UiTheme.HEADING, BookPanel.SOFT))
	# Short of coins for it: an ad for what is missing, beside the reason (owner's pick 3, 28 Nov).
	var price := int(Game.buildings.price_of(id).get("coins", 0))
	var offer := Game.offers.coins_offer(price - Game.coins) if price > Game.coins else 0
	if offer > 0:
		var watch := hud.panel_button(tr("AD_FOR_COINS") % UiTheme.number(offer))
		watch.name = "WatchForCoins"   # not-ui (a node's name)
		watch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		watch.pressed.connect(func() -> void: Game.offers.watch_coins(offer))
		words.add_child(watch)
	strip.visible = true
	UiFx.crossfade(strip)   # (what was tapped fades in at the top of the shelf)
	hud.book.scroll_to_top()


## One item's card face (CardFace): its picture, name, a line, its price, and whether it can be bought now and if
## not why (`why`, shown in the shelf's strip when tapped).
func card_face(id: String) -> Dictionary:
	var it := Game.item_data(id)
	var locked := Game.level() < int(it["unlock_level"])
	var verdict := Game.buildings.can_buy(id)
	var blocked := locked or verdict.why in [BuildingSystem.Why.LIMIT, BuildingSystem.Why.GROUP_LIMIT,
		BuildingSystem.Why.REQUIRES, BuildingSystem.Why.DOWNLOAD]
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
		hud.book.close_panel()
		hud.place_requested.emit(id)
	else:
		tell.call(id, Game.item_data(id), str(face["why"]))


## Land and the Mystery Box.
## What an item costs, as [badge icon, words]: coins, gems, or free.
func price_of(id: String, it: Dictionary) -> Array:
	if it["kind"] == "crafting":
		var price := Game.crafting.crafting_price(id)
		return ["gem", UiTheme.number(int(price["gems"]))] if price.has("gems") \
			else ["coin", UiTheme.number(int(price["coins"]))]
	if it.has("gem_cost"):
		return ["gem", UiTheme.number(int(it["gem_cost"]))]
	var coins := int(Game.buildings.price_of(id).get("coins", 0))   # (today's deal included: BuildingSystem)
	if coins > 0:
		return ["coin", tr("DEAL_PRICE") % UiTheme.number(coins) if id == Game.buildings.deal_id()
			else UiTheme.number(coins)]
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
	inner.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
	var step := Game.land.next_expansion()
	var size := Game.farm_size
	if step.is_empty():
		inner.add_child(BookPanel.text(tr("YOUR_FARM_IS_FULL_SIZE_X") % [size, size], UiTheme.BODY))
		return BookPanel.card_frame(inner)
	var next := int(step["size"])
	inner.add_child(BookPanel.text(tr("EXPAND_FROM_X_TO_X") % [size, size, next, next], UiTheme.BODY))
	inner.add_child(BookPanel.text(
		tr("ADDS_PLOTS_THE_DASHED_AREA_ON") % (next * next - size * size), UiTheme.HEADING))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", int(UiTheme.size("row_gap")))
	row.add_theme_constant_override("v_separation", int(UiTheme.size("row_gap")))
	if Game.level() < int(step["level"]):   # (coins or gems, every step needs its level: LandSystem.expand)
		var wait := hud.panel_button(tr("REACH_LEVEL_TO_EXPAND") % int(step["level"]))
		wait.disabled = true
		row.add_child(wait)
	else:
		var with_coins := hud.panel_button(tr("EXPAND_COINS") % UiTheme.number(int(step["coins"])))
		with_coins.disabled = Game.coins < int(step["coins"])
		with_coins.pressed.connect(func() -> void: Game.land.expand(false))
		row.add_child(with_coins)
		var with_gems := hud.panel_button(tr("EXPAND_NOW_GEMS") % int(step["gems"]))
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
			var hours := Balance.a("crafting.craft_hours_by_star")
			detail = tr("CRAFTING_RECIPES_OVER_STARS_PER_CRAFT") % [FarmGrid.format_duration(int(float(hours[0]) * 3600.0)),
				FarmGrid.format_duration(int(float(hours[-1]) * 3600.0))]
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
	inner.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
	inner.add_child(BookPanel.text(tr("MYSTERY_BOX"), UiTheme.BODY))
	inner.add_child(
		BookPanel.info(
			tr("ONE_SURPRISE_INSIDE_A_RARE_DECORATION"), tr("ONE_SURPRISE_INSIDE_A_RARE_DECORATION_INFO"),
			UiTheme.HEADING
		)
	)
	var cost := int(Game.mystery.box_data.get("gem_cost", Balance.i("mystery.mystery_box_gem_cost")))
	var buy := hud.panel_button(tr("OPEN_ONE_GEMS") % cost)
	buy.disabled = Game.gems < cost
	buy.pressed.connect(func() -> void:
		var prize := Game.mystery.buy_mystery_box()
		if prize != "":
			hud.reveal(RevealCard.BOX, tr("MYSTERY_BOX"), prize, Game.mystery.last_rarity)
			hud.book.refresh())
	inner.add_child(buy)
	return BookPanel.card_frame(inner)
