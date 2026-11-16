class_name HudCrafting
extends RefCounted
## The crafting buildings' panel, as tabs of the book:
## - Make: what is cooking in each slot (its picture, a bar filling, the time left), every recipe as a card (the
##   good's picture, its mastery, what it sells for and gives, how long it takes, each ingredient as have of
##   need, and its Make button), and the building's next star;
## - Goods: what has been made, each with its picture: sell it for coins or use it for fuel (a feed building
##   makes none: its rich feed goes to the Barn);
## - Pantry: the bushels and produce held, and the Farmers Market's offer for today.
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

const BIGGEST := 5      # a crafting building's most stars (sizes)
const STAR_SIZE := 1.6   # its stars against a mastery star
const TICK := 1.0        # the slots' bars and times are brought up to date this often, in seconds

var hud: FarmHud


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
	var o := Game.object_by_uid(hud._building_uid)
	if o.is_empty():
		hud._book.close_panel()
	return o


## Make: the slots, the recipes, the next star.
func build_make(content: VBoxContainer) -> void:
	var o := _building()
	if o.is_empty():
		return
	var uid := hud._building_uid
	hud.buildings.add_building_bar(content, o)
	content.add_child(star_row(Game.level_of(o), Game.crafting.building_recipe_stars(o["id"])))
	content.add_child(_slots(uid, o))
	content.add_child(BookPanel.text(tr("RECIPES"), 26, BookPanel.HEAD))
	var grid := _grid("recipe_card_width")
	for r in Game.crafting.recipes_of(o["id"]):
		grid.add_child(recipe_card(uid, o, r))
	content.add_child(grid)
	var cost := Game.crafting.star_cost(o)
	if cost.is_empty():
		return
	var up := BookPanel.card()
	up.add_child(BookPanel.text(tr("NEXT_STAR_COINS_AND_RECIPE_MASTERY") % [FarmHud._thousands(int(cost["coins"])),
		int(cost["recipe_stars"]), Game.crafting.building_recipe_stars(o["id"]), int(cost["gems"])], 18))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap")))
	for with_gems: bool in [false, true]:
		var b := hud._panel_button(tr("UPGRADE_GEMS") % int(cost["gems"]) if with_gems else tr("UPGRADE_WITH_COINS"))
		b.disabled = not Game.crafting.can_add_star(uid, with_gems)
		b.pressed.connect(func() -> void:
			Game.crafting.add_star(uid, with_gems)
			hud._book.open_tabs(Game.size_name(Game.object_by_uid(uid)), tabs(Game.object_by_uid(uid))))
		row.add_child(b)
	up.add_child(row)
	content.add_child(BookPanel.card_frame(up))


## The building's slots in a row: each craft under way as a tile (the good's picture, its name, a bar filling
## and the time left, kept up to date while the panel is open), each free slot as an empty tile, and the slot the
## next star adds as a locked one.
func _slots(uid: int, o: Dictionary) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap")))
	row.add_theme_constant_override("v_separation", int(UiTheme.size("hud_gap")))
	var live: Array = []   # [slot, bar, time label] of each craft under way
	for slot: Dictionary in o.get("slots", []):
		var tile := _slot_tile(ItemIcons.of(str(slot["r"])), Game.name_of(str(slot["r"])), false)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.custom_minimum_size.y = UiTheme.size("progress_height")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for part: Array in [["background", "progress_back"], ["fill", "progress_fill"]]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = UiTheme.color(str(part[1]))
			sb.set_corner_radius_all(int(UiTheme.size("progress_height") / 2.0))
			bar.add_theme_stylebox_override(str(part[0]), sb)
		var time := BookPanel.text("", 16, BookPanel.SOFT)
		time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(tile.get_child(0) as VBoxContainer).add_child(bar)
		(tile.get_child(0) as VBoxContainer).add_child(time)
		live.append([slot, bar, time])
		row.add_child(tile)
	for k in Game.crafting.free_slots(o):
		row.add_child(_slot_tile(null, tr("CRAFT_FREE_SLOT"), false))
	if Game.level_of(o) < BIGGEST:
		row.add_child(_slot_tile(null, tr("CRAFT_SLOT_AT_STARS") % (Game.level_of(o) + 1), true))
	var update := func() -> void:
		var done := false
		for e: Array in live:
			var left := int(e[0]["done"]) - Game.now()
			(e[1] as ProgressBar).value = clampf(1.0 - float(left) / maxf(float(e[0].get("took", left)), 1.0), 0.0, 1.0)
			(e[2] as Label).text = tr("SLOT_READY") if left <= 0 else FarmGrid.format_duration(left)
			done = done or left <= 0
		if done and Game.crafting.finish_crafts(uid) > 0:
			hud._book.refresh()   # (it lands in Goods, and its slot is free again)
	update.call()
	if not live.is_empty():
		var timer := Timer.new()
		timer.wait_time = TICK
		timer.autostart = true
		timer.timeout.connect(update)
		row.add_child(timer)
	return row


## One slot's tile: a picture (none for an empty or a locked slot) over a line of words.
static func _slot_tile(picture: Texture2D, words: String, locked: bool) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", UiKit.card_box("card_locked" if locked else "card_face"))
	tile.custom_minimum_size.x = UiTheme.size("card_width")
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(UiTheme.size("hud_gap") * 0.5))
	tile.add_child(col)
	var pic := TextureRect.new()
	pic.texture = picture
	pic.custom_minimum_size = Vector2.ONE * UiTheme.size("count_tile")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pic)
	var label := BookPanel.text(words, 17, BookPanel.SOFT if picture == null else BookPanel.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
	return tile


## A grid for cards `width` wide (a theme size), as many columns as fit the panel.
func _grid(width: String) -> GridContainer:
	var grid := GridContainer.new()
	var room := BookPanel.width_for(hud.get_viewport().get_visible_rect().size.x) - 2.0 * UiTheme.size("book_margin") \
		- UiTheme.size("scroll_bar")
	grid.columns = maxi(1, floori(room / (UiTheme.size(width) + UiTheme.size("hud_gap"))))
	grid.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap")))
	grid.add_theme_constant_override("v_separation", int(UiTheme.size("hud_gap")))
	return grid


## A card: a framed column `width` wide (a theme size), greyed when `locked`.
static func _card(width: String, locked := false) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UiTheme.size("hud_gap") * 0.75))
	var frame := PanelContainer.new()
	var sb := UiKit.card_box("card_locked" if locked else "card_face")
	sb.set_content_margin_all(UiTheme.size("card_pad") * 2.0)
	frame.add_theme_stylebox_override("panel", sb)
	frame.custom_minimum_size.x = UiTheme.size(width)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(col)
	return col   # (add `col.get_parent()` to the grid)


## A good's or an ingredient's picture, `side` across (a theme size).
static func _picture(id: String, side: String, dim := false) -> TextureRect:
	var pic := TextureRect.new()
	pic.texture = ItemIcons.of(id)
	pic.custom_minimum_size = Vector2.ONE * UiTheme.size(side)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		pic.modulate = Color(1, 1, 1, 0.45)
	return pic


## A recipe's mastery: five small stars, the earned ones lit.
static func mastery_stars(stars: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for k in BIGGEST:
		var star := UiIcon.make("star", UiTheme.size("mastery_star"))
		if k >= stars:
			star.modulate = Color(1, 1, 1, 0.25)
		row.add_child(star)
	return row


## One recipe as a card: the good's picture beside its name, its mastery, what it sells for and gives and how
## long it takes; under them each ingredient as have of need (red while short); then its button: Make, the
## missing ingredients for gems, or the star it unlocks at.
func recipe_card(uid: int, o: Dictionary, r: RecipeDef) -> Control:
	var unlocked := Game.crafting.recipe_unlocked(o, r.id)
	var stars := Game.crafting.recipe_stars(r.id)
	var col := _card("recipe_card_width", not unlocked)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
	top.add_child(_picture(r.id, "card_icon", not unlocked))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	words.add_child(BookPanel.text(r.name, 20))
	words.add_child(mastery_stars(stars))
	if r.makes_feed():
		words.add_child(BookPanel.text(tr("RECIPE_MAKES_FEED") % [int(r.feed()["units"]),
			Game.crafting.feed_product_name(r)], 17, BookPanel.HEAD))
		words.add_child(BookPanel.text(tr("CRAFT_TAKES_XP") % [FarmGrid.format_duration(r.craft_seconds()), r.xp()], 15,
			BookPanel.SOFT))
	else:
		var price := UiKit.price_badge("coin", FarmHud._thousands(Game.crafting.good_price(r.id)))
		price.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		words.add_child(price)
		words.add_child(BookPanel.text(tr("CRAFT_GIVES") % [FarmGrid.format_duration(r.craft_seconds()),
			Game.crafting.good_fuel(r.id), r.xp()], 15, BookPanel.SOFT))
	top.add_child(words)
	col.add_child(top)
	var need: Array = []
	for c: String in r.inputs():
		var have := int(Game.crafting.bushels.get(c, 0))
		need.append([c, "%d/%d" % [have, int(r.inputs()[c])], have < int(r.inputs()[c])])   # not-ui (have of need)
	col.add_child(UiKit.count_row(need))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap")))
	if not unlocked:
		row.add_child(BookPanel.text(tr("UNLOCKS_AT_STARS") % r.star(), 17, BookPanel.SOFT))
	else:
		var rid := r.id
		var problem := Game.crafting.craft_problem(uid, rid)
		var make := UiKit.primary(hud._panel_button(tr("MAKE_IT")))
		make.disabled = problem != ""
		make.pressed.connect(func() -> void:
			Game.crafting.start_craft(uid, rid)
			hud._book.refresh())
		row.add_child(make)
		var missing := Game.crafting.missing_bushels(rid)
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
		elif problem != "":
			row.add_child(BookPanel.text(problem, 15, BookPanel.SOFT))   # (every slot is busy)
	col.add_child(row)
	return col.get_parent()


## Goods: everything made here, each as a card with its picture and how many: sell one for coins, or use one
## for fuel; and all of them sold at once.
func build_goods(content: VBoxContainer) -> void:
	var o := _building()
	if o.is_empty():
		return
	var held: Array[RecipeDef] = []
	var worth := 0
	for r in Game.crafting.recipes_of(o["id"]):
		var n := int(Game.crafting.goods.get(r.id, 0))
		if n > 0:
			held.append(r)
			worth += n * Game.crafting.good_price(r.id)
	content.add_child(BookPanel.text(tr("YOUR_GOODS"), 26, BookPanel.HEAD))
	if held.is_empty():
		content.add_child(BookPanel.text(tr("NOTHING_YET_FINISHED_CRAFTS_LAND_HERE"), 17, BookPanel.SOFT))
		return
	var grid := _grid("recipe_card_width")
	for r in held:
		var rid := r.id
		var col := _card("recipe_card_width")
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
		top.add_child(_picture(rid, "card_icon"))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(BookPanel.text(tr("CRAFT_GOOD_COUNT") % [int(Game.crafting.goods[rid]), r.name], 20))
		words.add_child(mastery_stars(Game.crafting.recipe_stars(rid)))
		top.add_child(words)
		col.add_child(top)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap")))
		var sell := UiKit.primary(hud._panel_button(tr("SELL_COINS") % FarmHud._thousands(Game.crafting.good_price(rid))))
		sell.pressed.connect(func() -> void:
			Game.crafting.sell_good(rid)
			hud._book.refresh())
		row.add_child(sell)
		var use := hud._panel_button(tr("USE_FUEL") % Game.crafting.good_fuel(rid))
		use.pressed.connect(func() -> void:
			hud.show_message(tr("FUEL_2") % Game.crafting.use_good(rid))
			hud._book.refresh())
		row.add_child(use)
		col.add_child(row)
		grid.add_child(col.get_parent())
	content.add_child(grid)
	var all := hud._panel_button(tr("SELL_ALL_GOODS") % FarmHud._thousands(worth))
	all.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	all.pressed.connect(func() -> void:
		for r in held:
			while Game.crafting.sell_good(r.id) > 0:
				pass
		hud._book.refresh())
	content.add_child(all)


## Pantry: the bushels and produce held, and the Farmers Market's offer for today.
func build_pantry(content: VBoxContainer) -> void:
	if _building().is_empty():
		return
	var cap := Balance.i("crafting.bushel_cap")
	content.add_child(BookPanel.text(tr("BUSHELS_OF") % [Game.crafting.total_bushels(), cap], 26, BookPanel.HEAD))
	var held: Array = []
	for c: String in Game.crafting.bushels:
		held.append([c, "×%d" % int(Game.crafting.bushels[c])])   # not-ui (a count)
	held.sort_custom(func(a: Array, b: Array) -> bool: return Game.name_of(str(a[0])) < Game.name_of(str(b[0])))
	if held.is_empty():
		content.add_child(BookPanel.text(tr("NONE_YET_HARVESTS_DROP_BUSHELS_OF"), 17, BookPanel.SOFT))
	else:
		content.add_child(UiKit.count_row(held))
	content.add_child(BookPanel.text(tr("FARMERS_MARKET_TODAY"), 26, BookPanel.HEAD))
	var stall := Game.crafting.market_stall()
	var full := Game.crafting.total_bushels() >= cap
	var grid := _grid("card_width")
	for c in stall:
		var id: String = c
		var price := Game.crafting.bushel_price(id)
		var sold_out := int(stall[c]) <= 0
		var col := _card("card_width", sold_out)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var pic := _picture(id, "count_tile", sold_out)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(pic)
		for words: Array in [[Game.name_of(id), 17, BookPanel.INK], [tr("MARKET_LEFT") % int(stall[c]), 15, BookPanel.SOFT]]:
			var l := BookPanel.text(str(words[0]), int(words[1]), words[2])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(l)
		var buy := Button.new()
		buy.focus_mode = Control.FOCUS_NONE
		buy.custom_minimum_size.y = UiTheme.size("panel_button_height")
		buy.text = tr("MARKET_BUY") % FarmHud._thousands(price)
		buy.disabled = sold_out or Game.coins < price or full
		UiFx.press_bounce(buy)
		buy.pressed.connect(func() -> void:
			Game.crafting.buy_bushel(id)
			hud._book.refresh())
		col.add_child(buy)
		grid.add_child(col.get_parent())
	content.add_child(grid)
	if full:
		content.add_child(BookPanel.text(tr("PANTRY_FULL"), 17, BookPanel.SOFT))


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
