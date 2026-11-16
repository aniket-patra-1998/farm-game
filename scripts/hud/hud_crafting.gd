class_name HudCrafting
extends RefCounted
## The crafting buildings' menu, as tabs of the building's sheet (BuildingSheet), built from the menus' shared
## pieces (CardList cards on the paper, a strip that tells about the card picked, UiKit.count_row, buttons):
## - Make: what is cooking in each slot (a card with the good's picture and a bar filling with the time left),
##   the recipe picked (what it sells for and gives, how long it takes, each ingredient as have of need, and
##   Make or the missing ingredients for gems), every recipe as a card (tap one to pick it), the next star;
## - Goods: what has been made, as cards: pick one to sell it for coins or use it for fuel, or sell everything
##   (a feed building makes none: its rich feed goes to the Barn);
## - Pantry: the bushels and produce held, and the Farmers Market's offer for today (tap a card to buy one).
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

const BIGGEST := 5      # a crafting building's most stars (sizes)
const STAR_SIZE := 1.6   # its stars against a mastery star
const TICK := 1.0        # the slots' bars and times are brought up to date this often, in seconds
const SLOT := "slot:"    # not-ui (a slot's card id: "slot:<index>" a craft under way, FREE, NEXT)
const FREE := "free:"    # not-ui
const NEXT := "next"     # not-ui (the slot the next star adds)

var hud: FarmHud
var _recipe := ""        # the recipe picked on Make..
var _good := ""          # ..and the good picked on Goods


func _init(owner: FarmHud) -> void:
	hud = owner


## The panel's tabs for building `o`: [[name, builder]] (BookPanel.open_tabs).
func tabs(o: Dictionary) -> Array:
	var out: Array = [[tr("CRAFT_TAB_MAKE"), build_make]]
	if makes_goods(o):
		out.append([tr("CRAFT_TAB_GOODS"), build_goods])
	out.append([tr("CRAFT_TAB_PANTRY"), build_pantry])
	return out


## Whether building `o` makes goods to sell (a feed building makes none).
static func makes_goods(o: Dictionary) -> bool:
	for r in Game.crafting.recipes_of(str(o["id"])):
		if not r.makes_feed():
			return true
	return false


## The building this panel is about, or {} once it is gone (the panel then closes).
func _building() -> Dictionary:
	var o := Game.object_by_uid(hud.building_uid)
	if o.is_empty():
		hud.close_panels()
	return o


func _view_width() -> float:
	return hud.get_viewport().get_visible_rect().size.x


## A strip that tells about the card picked: flat on the paper, filled by `fill` (the VBox to fill).
static func _strip(content: VBoxContainer) -> VBoxContainer:
	var about := BookPanel.card()
	about.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
	content.add_child(BookPanel.card_frame(about))
	return about


## The top of a strip: the thing's picture beside its `lines` ([[words, size, colour]]).
static func _about(about: VBoxContainer, id: String, lines: Array) -> void:
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
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	for line: Array in lines:
		words.add_child(BookPanel.text(str(line[0]), int(line[1]), line[2]))


## Make: the slots, the recipe picked, the recipes, the next star.
func build_make(content: VBoxContainer) -> void:
	var o := _building()
	if o.is_empty():
		return
	var uid := hud.building_uid
	content.add_child(star_row(Game.level_of(o), Game.crafting.building_recipe_stars(o["id"])))
	_add_slots(content, uid, o)
	var ids: Array[String] = []
	for r in Game.crafting.recipes_of(o["id"]):
		ids.append(r.id)
	if not ids.has(_recipe):
		_recipe = first_to_make(o)
	var about := _strip(content)
	show_recipe(about, uid, o)
	content.add_child(BookPanel.text(tr("RECIPES"), 26, BookPanel.HEAD))
	content.add_child(CardList.make(ids, func(id: String) -> Dictionary: return recipe_face(o, id),
		func(id: String) -> void:
			_recipe = id
			show_recipe(about, uid, o)
			hud.scroll_panels_to_top(), _view_width()))
	var cost := Game.crafting.star_cost(o)
	if cost.is_empty():
		return
	var up := BookPanel.card()
	up.add_child(BookPanel.text(tr("NEXT_STAR_COINS_AND_RECIPE_MASTERY") % [FarmHud._thousands(int(cost["coins"])),
		int(cost["recipe_stars"]), Game.crafting.building_recipe_stars(o["id"]), int(cost["gems"])], 18))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap")))
	for with_gems: bool in [false, true]:
		var b := hud.panel_button(tr("UPGRADE_GEMS") % int(cost["gems"]) if with_gems else tr("UPGRADE_WITH_COINS"))
		b.disabled = not Game.crafting.can_add_star(uid, with_gems)
		b.pressed.connect(func() -> void:
			Game.crafting.add_star(uid, with_gems)
			hud.refresh_panels())   # (a new star: its slots and recipes)
		row.add_child(b)
	up.add_child(row)
	content.add_child(BookPanel.card_frame(up))


## The recipe to show first: one there are the ingredients for, else the first one unlocked.
func first_to_make(o: Dictionary) -> String:
	var first := ""
	for r in Game.crafting.recipes_of(o["id"]):
		if not Game.crafting.recipe_unlocked(o, r.id):
			continue
		if Game.crafting.missing_bushels(r.id).is_empty():
			return r.id
		if first == "":
			first = r.id
	return first


## The building's slots as a row of cards, kept up to date while the panel is open: each craft under way (the
## good's picture, its name, a bar filling with the time left), each free slot, and the slot the next star adds.
## A craft that finishes with the panel open lands in Goods and frees its slot.
func _add_slots(content: VBoxContainer, uid: int, o: Dictionary) -> void:
	var ids: Array[String] = []
	for k in (o.get("slots", []) as Array).size():
		ids.append(SLOT + str(k))
	for k in Game.crafting.free_slots(o):
		ids.append(FREE + str(k))
	if Game.level_of(o) < BIGGEST:
		ids.append(NEXT)
	var list := CardList.make(ids, func(id: String) -> Dictionary: return slot_face(o, id),
		func(id: String) -> void:
			if id.begins_with(SLOT):
				_recipe = str(_slot(o, id).get("r", _recipe))
				hud.refresh_panels(),
		_view_width(), func(id: String) -> Texture2D:
			return ItemIcons.of(str(_slot(o, id)["r"])) if id.begins_with(SLOT) and not _slot(o, id).is_empty() else null)
	content.add_child(list)
	if (o.get("slots", []) as Array).is_empty():
		return
	var timer := Timer.new()
	timer.wait_time = TICK
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		var done := false
		for slot: Dictionary in o.get("slots", []):
			done = done or Game.now() >= int(slot["done"])
		if done and Game.crafting.finish_crafts(uid) > 0:
			hud.refresh_panels()
		else:
			list.refresh())
	list.add_child(timer)


## The craft in the slot a slot card `id` stands for ({} when it is gone).
static func _slot(o: Dictionary, id: String) -> Dictionary:
	var slots: Array = o.get("slots", [])
	var k := int(id.trim_prefix(SLOT))
	return slots[k] if id.begins_with(SLOT) and k < slots.size() else {}


## A slot's card (CardFace): a craft under way with its bar, a free slot, or the next star's.
func slot_face(o: Dictionary, id: String) -> Dictionary:
	if id == NEXT:
		return {"name": tr("CRAFT_SLOT_AT_STARS") % (Game.level_of(o) + 1), "locked": true,
			"icon": ["lock", Color(0, 0, 0, 0), true]}
	var slot := _slot(o, id)
	if slot.is_empty():
		return {"name": tr("CRAFT_FREE_SLOT"), "icon": ["basket", Color(0, 0, 0, 0), true]}
	var left := int(slot["done"]) - Game.now()
	return {"name": Game.name_of(str(slot["r"])), "bar": [1.0 - float(left) / maxf(float(slot.get("took", left)), 1.0),
		tr("SLOT_READY") if left <= 0 else FarmGrid.format_duration(left)]}


## A recipe's card (CardFace): the good's picture and name, what it sells for (a feed recipe: how long it takes),
## and one line: the star it unlocks at, how many ingredients it is short of, or its mastery.
func recipe_face(o: Dictionary, id: String) -> Dictionary:
	var r := Game.catalog.get_def(id) as RecipeDef
	var unlocked := Game.crafting.recipe_unlocked(o, id)
	var short := 0
	for c in Game.crafting.missing_bushels(id).values():
		short += int(c)
	var line := tr("CRAFT_MASTERY") % Game.crafting.recipe_stars(id)
	var colour := "tool_label"
	if not unlocked:
		line = tr("UNLOCKS_AT_STARS") % r.star()
	elif short > 0:
		line = tr("CRAFT_NEEDS_MORE") % short
		colour = "price_short"
	return {"name": r.name, "line": line, "line_colour": colour, "locked": not unlocked,
		"badge": ["", FarmGrid.format_duration(r.craft_seconds())] if r.makes_feed()
			else ["coin", FarmHud._thousands(Game.crafting.good_price(id))],
		"long": gives(r), "can_make": unlocked and short == 0}


## What a recipe gives, in a line: what it sells for (or the feed it makes), its time, fuel and XP.
func gives(r: RecipeDef) -> String:
	var time := FarmGrid.format_duration(r.craft_seconds())
	if r.makes_feed():
		return tr("CRAFT_GIVES_FEED") % [int(r.feed()["units"]), Game.crafting.feed_product_name(r), time, r.xp()]
	return tr("CRAFT_GIVES") % [FarmHud._thousands(Game.crafting.good_price(r.id)), time, Game.crafting.good_fuel(r.id),
		r.xp()]


## Fills the Make tab's strip with the recipe picked: its picture, name and mastery, what it gives, each
## ingredient as have of need (red while short), and its button: Make, the missing ingredients for gems, or why
## it can't be made.
func show_recipe(about: VBoxContainer, uid: int, o: Dictionary) -> void:
	for c in about.get_children():
		c.queue_free()
	var r := Game.catalog.get_def(_recipe) as RecipeDef
	if r == null:
		return
	_about(about, r.id, [[r.name, 22, BookPanel.HEAD], [gives(r), 17, BookPanel.INK],
		[tr("CRAFT_MASTERY_MADE") % [Game.crafting.recipe_stars(r.id), int(Game.crafting.crafted.get(r.id, 0))], 17,
			BookPanel.SOFT]])
	var need: Array = []
	for c: String in r.inputs():
		var have := int(Game.crafting.bushels.get(c, 0))
		need.append([c, "%d/%d" % [have, int(r.inputs()[c])], have < int(r.inputs()[c])])   # not-ui (have of need)
	about.add_child(UiKit.count_row(need))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap")))
	about.add_child(row)
	var rid := r.id
	var problem := Game.crafting.craft_problem(uid, rid)
	var make := UiKit.primary(hud.panel_button(tr("MAKE_IT")))
	make.disabled = problem != ""
	make.pressed.connect(func() -> void:
		Game.crafting.start_craft(uid, rid)
		hud.refresh_panels())
	row.add_child(make)
	var missing := Game.crafting.missing_bushels(rid)
	if Game.crafting.recipe_unlocked(o, rid) and not missing.is_empty() and Game.crafting.free_slots(o) > 0:
		var n := 0
		for c in missing:
			n += int(missing[c])
		var buy := hud.panel_button(tr("BUY_MISSING_GEMS") % (n * Balance.i("crafting.bushel_gem_cost")))
		buy.disabled = Game.gems < n * Balance.i("crafting.bushel_gem_cost")
		buy.pressed.connect(func() -> void:
			Game.crafting.buy_missing_and_craft(uid, rid)
			hud.refresh_panels())
		row.add_child(buy)
	elif problem != "":
		about.add_child(BookPanel.text(problem, 17, UiTheme.color("note")))   # (locked, or every slot is busy)


## Goods: everything made here as cards; the one picked can be sold for coins or used for fuel, and all of them
## sold at once.
func build_goods(content: VBoxContainer) -> void:
	var o := _building()
	if o.is_empty():
		return
	var ids: Array[String] = []
	var worth := 0
	for r in Game.crafting.recipes_of(o["id"]):
		var n := int(Game.crafting.goods.get(r.id, 0))
		if n > 0:
			ids.append(r.id)
			worth += n * Game.crafting.good_price(r.id)
	content.add_child(BookPanel.text(tr("YOUR_GOODS"), 26, BookPanel.HEAD))
	if ids.is_empty():
		content.add_child(BookPanel.text(tr("NOTHING_YET_FINISHED_CRAFTS_LAND_HERE"), 17, BookPanel.SOFT))
		return
	if not ids.has(_good):
		_good = ids[0]
	var about := _strip(content)
	show_good(about)
	content.add_child(CardList.make(ids, good_face, func(id: String) -> void:
		_good = id
		show_good(about)
		hud.scroll_panels_to_top(), _view_width()))
	var all := hud.panel_button(tr("SELL_ALL_GOODS") % FarmHud._thousands(worth))
	all.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	all.pressed.connect(func() -> void:
		for id in ids:
			while Game.crafting.sell_good(id) > 0:
				pass
		hud.refresh_panels())
	content.add_child(all)


## A good's card (CardFace): its picture and name, how many there are and what one sells for.
func good_face(id: String) -> Dictionary:
	return {"name": Game.name_of(id), "line": tr("TIMES_N") % int(Game.crafting.goods.get(id, 0)),
		"badge": ["coin", FarmHud._thousands(Game.crafting.good_price(id))]}


## Fills the Goods tab's strip with the good picked: its picture, name and how many, and its buttons: sell one
## for coins, use one for fuel.
func show_good(about: VBoxContainer) -> void:
	for c in about.get_children():
		c.queue_free()
	var rid := _good
	_about(about, rid, [[Game.name_of(rid), 22, BookPanel.HEAD],
		[tr("CRAFT_GOOD_COUNT") % int(Game.crafting.goods.get(rid, 0)), 17, BookPanel.SOFT]])
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap")))
	about.add_child(row)
	var sell := UiKit.primary(hud.panel_button(tr("SELL_COINS") % FarmHud._thousands(Game.crafting.good_price(rid))))
	sell.pressed.connect(func() -> void:
		Game.crafting.sell_good(rid)
		hud.refresh_panels())
	row.add_child(sell)
	var use := hud.panel_button(tr("USE_FUEL") % Game.crafting.good_fuel(rid))
	use.pressed.connect(func() -> void:
		hud.show_message(tr("FUEL_2") % Game.crafting.use_good(rid))
		hud.refresh_panels())
	row.add_child(use)


## Pantry: the bushels and produce held, and the Farmers Market's offer for today as cards (tap one to buy one).
func build_pantry(content: VBoxContainer) -> void:
	if _building().is_empty():
		return
	var cap := Balance.i("crafting.bushel_cap")
	content.add_child(BookPanel.text(tr("BUSHELS_OF") % [Game.crafting.total_bushels(), cap], 26, BookPanel.HEAD))
	var held: Array = []
	for c: String in Game.crafting.bushels:
		held.append([c, tr("TIMES_N") % int(Game.crafting.bushels[c])])
	held.sort_custom(func(a: Array, b: Array) -> bool: return Game.name_of(str(a[0])) < Game.name_of(str(b[0])))
	if held.is_empty():
		content.add_child(BookPanel.text(tr("NONE_YET_HARVESTS_DROP_BUSHELS_OF"), 17, BookPanel.SOFT))
	else:
		content.add_child(UiKit.count_row(held))
	content.add_child(BookPanel.text(tr("FARMERS_MARKET_TODAY"), 26, BookPanel.HEAD))
	if Game.crafting.total_bushels() >= cap:
		content.add_child(BookPanel.text(tr("PANTRY_FULL"), 17, UiTheme.color("note")))
	var ids: Array[String] = []
	ids.assign(Game.crafting.market_stall().keys())
	content.add_child(CardList.make(ids, stall_face, func(id: String) -> void:
		if not Game.crafting.buy_bushel(id):
			hud.show_message(tr("MARKET_CANT_BUY"))
		hud.refresh_panels(), _view_width()))


## A Farmers Market card (CardFace): the ingredient, how many are left today and what one costs (red when it is
## more than the coins held; greyed when sold out or the pantry is full).
func stall_face(id: String) -> Dictionary:
	var left := int(Game.crafting.market_stall().get(id, 0))
	var price := Game.crafting.bushel_price(id)
	var full := Game.crafting.total_bushels() >= Balance.i("crafting.bushel_cap")
	return {"name": Game.name_of(id), "line": tr("MARKET_LEFT") % left, "locked": left <= 0 or full,
		"badge": ["coin", FarmHud._thousands(price), Game.coins < price],
		"buyable": left > 0 and not full and Game.coins >= price}


## A building's star row: its size in stars (lit up to `size`), how many slots that is (one crafting slot per
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
