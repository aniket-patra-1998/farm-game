class_name HudBarn
extends RefCounted
## The Barn, the Garden Shed's bloom list and the nursery's young list: repair, storage and grouped lists.
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner


func build_barn(content: VBoxContainer) -> void:
	var b := Game.storage.barn()
	if b.is_empty():
		hud._book.close_panel()
		return
	add_boosts(content)
	if b.get("broken", false):
		build_barn_repair(content)
	else:
		build_barn_storage(content)


## The boosts you have, used from here as FarmVille's were from the gift box: Fertilize All, Unwither and the
## helpers (each works the whole farm at once), and the fuel for the vehicles once you have one.
func add_boosts(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text(tr("BOOSTS"), 26, BookPanel.SUN))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	content.add_child(row)
	var boosts := [
		[tr("FERTILIZE_ALL_LEFT") % Game.fertilize_alls, Game.fertilize_alls > 0,
			func() -> void: Game.bees.use_fertilize_all()],
		[tr("UNWITHER_LEFT") % Game.unwithers if Game.unwithers > 0
			else tr("UNWITHER_GEMS") % Balance.i("economy.unwither_gem_cost"), true, Game.use_unwither],
		[tr("FARMHAND_LEFT") % Game.farmhands, Game.farmhands > 0, func() -> void: Game.use_helper("animal")],
		[tr("ARBORIST_LEFT") % Game.arborists, Game.arborists > 0, func() -> void: Game.use_helper("tree")],
		[tr("GARDENER_LEFT") % Game.gardeners, Game.gardeners > 0, func() -> void: Game.use_helper("bloom")],
	]
	if Game.vehicles.fuel_unlocked:
		boosts.append([tr("FUEL_TANKS") % [Game.vehicles.fuel_now(), Balance.i("vehicles.fuel_tank"),
			Game.vehicles.fuel_tanks], true, func() -> void: hud._book.open_panel(tr("FUEL"), hud.buildings.build_fuel)])
	for entry: Array in boosts:
		var use := hud._panel_button(str(entry[0]))
		use.disabled = not bool(entry[1])
		use.pressed.connect(entry[2])
		row.add_child(use)


func build_barn_repair(content: VBoxContainer) -> void:
	var it := Game.item_data("barn")
	content.add_child(BookPanel.text(
		tr("THIS_OLD_BARN_NEEDS_FIXING_COLLECT"), 20, BookPanel.CREAM))
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 10)
	var need := Game.storage.repair_needs()
	for p in GameState.part_ids:
		var want := int(need.get(p, 0))
		if want <= 0:
			continue          # (not needed for this repair)
		var have := int(Game.parts.get(p, 0))
		card.add_child(BookPanel.text(tr("OF_2") % [GameState.part_names[p], mini(have, want), want], 20))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 16
		bar.max_value = want
		bar.value = mini(have, want)
		card.add_child(bar)
	card.add_child(
		BookPanel.text(
			tr("REWARD_COINS_XP_AND_A_BARN") % [
				int(it.get("repair_coins", 0)),
				int(it.get("repair_xp", 0))
			],
			17
		)
	)
	content.add_child(BookPanel.card_frame(card))
	var fix := hud._panel_button(tr("REPAIR_THE_BARN") if Game.storage.can_repair_barn() else tr("NOT_ENOUGH_PARTS_YET"))
	fix.disabled = not Game.storage.can_repair_barn()
	fix.pressed.connect(func() -> void: Game.storage.repair_barn())
	content.add_child(fix)


func build_barn_storage(content: VBoxContainer) -> void:
	var cap := Game.storage.barn_capacity()
	content.add_child(BookPanel.text(
		tr("HOLDS_OF_USE_THE_STORE_TOOL") % [Game.storage.stored.size(), cap], 20, BookPanel.CREAM))
	# What is stored first (it is what the Barn is opened for), then its parts, its next size and the feed.
	if Game.storage.stored.is_empty():
		content.add_child(BookPanel.card_frame(BookPanel.text(tr("NOTHING_STORED_YET"), 20)))
	else:
		add_grouped(content, 0, mini(Game.storage.stored.size(), cap))
		add_gift_box(content, cap)
	var parts_line: Array[String] = []
	for p in GameState.part_ids:
		parts_line.append("%s %d" % [GameState.part_names[p], int(Game.parts.get(p, 0))])
	content.add_child(BookPanel.text(tr("PARTS") % ", ".join(PackedStringArray(parts_line)), 17, BookPanel.CREAM))
	var barn := Game.storage.barn()
	if not barn.is_empty():
		hud.buildings.add_expansion_card(content, barn, int(barn["uid"]))
	hud.feed.add_barn_stock(content)


## What has spilled past the barn, grouped by kind (there can be thousands: one row each would be a wall).
func add_gift_box(content: VBoxContainer, cap: int) -> void:
	var extra := Game.storage.in_gift_box()
	if extra <= 0:
		return
	content.add_child(BookPanel.text(tr("GIFT_BOX_HOLDS") % [extra, BarnStorage.GIFT_BOX_LIMIT], 18, BookPanel.CREAM))
	add_grouped(content, cap, Game.storage.stored.size())


## One row per kind among the stored things from index `from` up to `to` (a full barn is hundreds, the gift box
## thousands: a row each would be a wall of nodes), with how many there are; Place takes the first of that kind.
func add_grouped(content: VBoxContainer, from: int, to: int) -> void:
	var first := {}
	var count := {}
	for k in range(from, to):
		var id := str(Game.storage.stored[k]["id"])
		if not first.has(id):
			first[id] = k
		count[id] = int(count.get(id, 0)) + 1
	add_group_rows(content, first.keys(), first, count, 0)


## Group rows a page at a time: a store with hundreds of different kinds would otherwise build hundreds of
## rows at once. The button at the end adds the next page.
func add_group_rows(content: VBoxContainer, ids: Array, first: Dictionary, count: Dictionary, from: int) -> void:
	var grid := UiKit.card_grid(hud.get_viewport().get_visible_rect().size.x)
	content.add_child(grid)
	add_group_cards(grid, content, ids, first, count, from)


## One card per kind, a page at a time (as FarmVille's storage: the picture, how many, tap to place one).
func add_group_cards(grid: GridContainer, content: VBoxContainer, ids: Array, first: Dictionary, count: Dictionary,
		from: int) -> void:
	var to := mini(from + FarmHud.GROUP_PAGE, ids.size())
	for i in range(from, to):
		var id: String = ids[i]
		var card := UiKit.item_card(ItemIcons.of(id), str(Game.item_data(id)["name"]), tr("TIMES_N") % count[id],
			UiKit.price_badge("", tr("PLACE_2")), false)
		var index: int = first[id]
		card.pressed.connect(func() -> void:
			hud._book.close_panel()
			hud.place_stored_requested.emit(index))
		grid.add_child(card)
	if to < ids.size():
		var more := hud._panel_button(tr("SHOW_MORE_KINDS") % (ids.size() - to))
		more.pressed.connect(func() -> void:
			more.queue_free()
			add_group_cards(grid, content, ids, first, count, to))
		content.add_child(more)
		content.move_child(more, grid.get_index() + 1)   # (right under the grid it extends)


## A bloom's card: when it's ready, whether it has withered (and regrowing it with Flower Food), and for a
## Single Bloom, upgrading it to a Full Bloom that never withers.
func build_bloom(content: VBoxContainer) -> void:
	var o := Game.object_by_uid(hud._building_uid)
	var d := Game.catalog.get_def(str(o.get("id", ""))) as BloomDef
	if d == null:
		return
	var uid := hud._building_uid
	if Game.is_withered(o):
		content.add_child(BookPanel.text(tr("THIS_BLOOM_HAS_WITHERED"), 20, BookPanel.CREAM))
		content.add_child(BookPanel.text(tr("YOU_HAVE_N") % [Game.nurture.has_supply("flower_food"),
			Game.nurture.supply_name("flower_food")], 18, BookPanel.CREAM))
		var regrow := hud._panel_button(tr("REGROW_IT"))
		regrow.disabled = Game.nurture.free_supply("flower_food") <= 0
		regrow.pressed.connect(func() -> void:
			Game.player.enqueue({"kind": "nurture", "uid": uid})
			hud._book.close_panel())
		content.add_child(regrow)
		var buy := hud._panel_button(tr("BUY_ONE_FOR_GEMS") % [Game.nurture.supply_name("flower_food"),
			int(NurtureSystem.SUPPLIES["flower_food"]["gem_cost"])])
		buy.disabled = Game.gems < int(NurtureSystem.SUPPLIES["flower_food"]["gem_cost"])
		buy.pressed.connect(func() -> void:
			if Game.nurture.buy_supply("flower_food", 1):
				hud.show_building(uid))
		content.add_child(buy)
	else:
		content.add_child(BookPanel.text(tr("READY_IN") % [d.data["name"], tr("FLOWERS"),
			FarmGrid.format_duration(Game.seconds_until_ready(o))], 20, BookPanel.CREAM))
	if d.withers():
		content.add_child(BookPanel.text(tr("A_SINGLE_BLOOM_WITHERS"), 17, BookPanel.CREAM))
		var up := hud._panel_button(tr("UPGRADE_TO_A_FULL_BLOOM_GEMS") % d.upgrade_gems())
		up.disabled = Game.gems < d.upgrade_gems()
		up.pressed.connect(func() -> void:
			if Game.nurture.upgrade_bloom(uid):
				hud.show_building(uid))
		content.add_child(up)


## A mystery young's card: how far it has grown, the supply it needs and how many you have, and more for gems.
func build_young(content: VBoxContainer) -> void:
	var o := Game.object_by_uid(hud._building_uid)
	if not Game.nurture.is_young(o):
		return
	var supply := Game.nurture.supply_of(o)
	var name := Game.nurture.supply_name(supply)
	content.add_child(BookPanel.text(tr("GIVE_IT_TO_SEE_WHAT_IT_GROWS_INTO") % [Game.nurture.needs(o), name], 20,
		BookPanel.CREAM))
	var card := BookPanel.card()
	card.add_child(BookPanel.text(tr("OF_2") % [name, Game.nurture.fed(o), Game.nurture.needs(o)], 20))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 16
	bar.max_value = Game.nurture.needs(o)
	bar.value = Game.nurture.fed(o)
	card.add_child(bar)
	card.add_child(BookPanel.text(tr("YOU_HAVE_N") % [Game.nurture.has_supply(supply), name], 18))
	content.add_child(BookPanel.card_frame(card))
	var uid := hud._building_uid
	var give := hud._panel_button(tr("GIVE_ONE"))
	give.disabled = Game.nurture.free_supply(supply) <= 0
	give.pressed.connect(func() -> void:
		Game.player.enqueue({"kind": "nurture", "uid": uid})
		hud._book.close_panel())
	content.add_child(give)
	var gems := int(NurtureSystem.SUPPLIES[supply]["gem_cost"])
	var buy := hud._panel_button(tr("BUY_ONE_FOR_GEMS") % [name, gems])
	buy.disabled = Game.gems < gems
	buy.pressed.connect(func() -> void:
		if Game.nurture.buy_supply(supply, 1):
			hud.show_building(uid))
	content.add_child(buy)
