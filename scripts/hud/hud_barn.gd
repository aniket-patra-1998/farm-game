class_name HudBarn
extends RefCounted
## The Barn, the Garden Shed's bloom list and the nursery's young list: repair, storage and grouped lists.
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

const VIP_PACK_GEMS := 10   # the gems of the smaller VIP points purchase
## The chances the VIP page shows: [the name's key, the Balance number].
const VIP_ODDS := [["VIP_ODD_FERTILIZER", "specials.fertilizer_chance"], ["VIP_ODD_CALF", "specials.calf_chance"],
	["VIP_ODD_FOAL", "specials.foal_chance"], ["VIP_ODD_LAMB", "specials.lamb_chance"],
	["VIP_ODD_PIGLET", "specials.piglet_chance"], ["VIP_ODD_SAPLING", "nurture.rare_chance"]]

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner



## The boosts you have, used from here as FarmVille's were from the gift box: Fertilize All, Unwither and the
## helpers (each works the whole farm at once), and the fuel for the vehicles once you have one.
func add_boosts(content: VBoxContainer) -> void:
	content.add_child(BookPanel.heading(tr("BOOSTS")))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap")))
	row.add_theme_constant_override("v_separation", int(UiTheme.size("hud_gap")))
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
			Game.vehicles.fuel_tanks], true, func() -> void:
				hud.sheet.show_page("SHEET_TAB_FUEL")])   # (the Barn's own Fuel page)
	for entry: Array in boosts:
		var use := hud.panel_button(str(entry[0]))
		use.disabled = not bool(entry[1])
		use.pressed.connect(entry[2])
		row.add_child(use)


func build_barn_repair(content: VBoxContainer) -> void:
	var it := Game.item_data("barn")
	content.add_child(BookPanel.info(
		tr("THIS_OLD_BARN_NEEDS_FIXING_COLLECT"), tr("THIS_OLD_BARN_NEEDS_FIXING_COLLECT_INFO"),
		UiTheme.HEADING, BookPanel.SOFT))
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
	var need := Game.storage.repair_needs()
	for p in GameState.part_ids:
		var want := int(need.get(p, 0))
		if want <= 0:
			continue          # (not needed for this repair)
		var have := int(Game.parts.get(p, 0))
		card.add_child(BookPanel.text(tr("OF_2") % [GameState.part_names[p], mini(have, want), want], UiTheme.BODY))
		var bar := UiKit.thin_bar(mini(have, want), want)
		card.add_child(bar)
	card.add_child(
		BookPanel.text(
			tr("REWARD_COINS_XP_AND_A_BARN") % [
				int(it.get("repair_coins", 0)),
				int(it.get("repair_xp", 0))
			],
			UiTheme.HEADING
		)
	)
	content.add_child(BookPanel.card_frame(card))
	var fix := hud.panel_button(tr("REPAIR_THE_BARN") if Game.storage.can_repair_barn() else tr("NOT_ENOUGH_PARTS_YET"))
	fix.disabled = not Game.storage.can_repair_barn()
	fix.pressed.connect(func() -> void: Game.storage.repair_barn())
	content.add_child(fix)


## The Barn's VIP page (docs/VIP.md): the level, the points to the next, whether VIP is active and for how long,
## what it multiplies by, the buttons to buy time and points, and the chances as they stand.
func build_vip(content: VBoxContainer) -> void:
	var vip := Game.vip
	var at := vip.level()
	content.add_child(BookPanel.heading(tr("VIP_HEADING") % [at, vip.max_level()]))
	content.add_child(BookPanel.info(tr("VIP_WHAT"), tr("VIP_WHAT_INFO"), UiTheme.HEADING, BookPanel.SOFT))
	var next := vip.next_level_points()
	content.add_child(BookPanel.text(tr("VIP_POINTS_TOP") % vip.points if next < 0
		else tr("VIP_POINTS_NEXT") % [vip.points, next, at + 1], UiTheme.HEADING))
	content.add_child(BookPanel.text(tr("VIP_STREAK_LINE") % vip.streak_points(Balance.i("vip.streak_days")),
		UiTheme.HEADING, BookPanel.SOFT))
	if at <= 0:
		content.add_child(BookPanel.text(tr("VIP_NONE_YET"), UiTheme.HEADING, BookPanel.SOFT))
	else:
		var top_boost := lerpf(1.0, Balance.f("vip.top_boost"), float(at) / vip.max_level())
		if vip.active():
			content.add_child(BookPanel.text(tr("VIP_ACTIVE_FOR") % FarmGrid.format_duration(vip.seconds_left()),
				UiTheme.HEADING, BookPanel.GOOD))
			content.add_child(BookPanel.text(tr("VIP_BOOST_NOW") % vip.boost(), UiTheme.HEADING))
		else:
			content.add_child(BookPanel.text(tr("VIP_LAPSED"), UiTheme.HEADING))
			content.add_child(BookPanel.text(tr("VIP_BOOST_WHEN_ACTIVE") % top_boost, UiTheme.HEADING, BookPanel.SOFT))
		var week := hud.panel_button(tr("VIP_BUY_WEEK") % [Balance.i("vip.week_days"), vip.week_cost()])
		week.disabled = Game.gems < vip.week_cost()
		week.pressed.connect(func() -> void:
			Game.vip.buy_week()
			hud.refresh_panels())
		content.add_child(week)
	if next >= 0:
		var pack := Balance.i("vip.points_per_gem") * VIP_PACK_GEMS
		var some := hud.panel_button(tr("VIP_BUY_POINTS") % [pack, VIP_PACK_GEMS])
		some.disabled = Game.gems < VIP_PACK_GEMS
		some.pressed.connect(func() -> void:
			Game.vip.buy_points(VIP_PACK_GEMS)
			hud.refresh_panels())
		content.add_child(some)
		var whole := hud.panel_button(tr("VIP_BUY_LEVEL") % vip.gems_to_next_level())
		whole.disabled = Game.gems < vip.gems_to_next_level()
		whole.pressed.connect(func() -> void:
			Game.vip.buy_points(Game.vip.gems_to_next_level())
			hud.refresh_panels())
		content.add_child(whole)
	# The chances as they stand, with VIP and without (gems can raise them: they are shown).
	content.add_child(BookPanel.text(tr("VIP_ODDS_HEADING"), UiTheme.HEADING, BookPanel.SOFT))
	for odd: Array in VIP_ODDS:
		var base := Balance.f(str(odd[1]))
		content.add_child(BookPanel.text(tr("VIP_ODDS_ROW") % [tr(str(odd[0])), vip.chance(base) * 100.0, base * 100.0],
			UiTheme.HEADING, BookPanel.SOFT))


func build_barn_storage(content: VBoxContainer) -> void:
	var cap := Game.storage.barn_capacity()
	var held := Game.storage.stored.size()
	content.add_child(BookPanel.info(tr("HOLDS_OF_USE_THE_STORE_TOOL") % [held, cap],
		tr("HOLDS_OF_USE_THE_STORE_TOOL_INFO") % [held, cap], UiTheme.HEADING, BookPanel.SOFT))
	# What is stored first (it is what the Barn is opened for), then its parts, its next size and the feed.
	if not Game.storage.stored.is_empty():   # (nothing stored: no empty box saying so)
		add_grouped(content, 0, held)
	var parts: Array = []
	for p: String in GameState.part_ids:
		parts.append([p, "×%d" % int(Game.parts.get(p, 0))])
	content.add_child(BookPanel.text(tr("PARTS_HEADING"), UiTheme.HEADING, BookPanel.SOFT))
	content.add_child(UiKit.count_row(parts))
	var barn := Game.storage.barn()
	if not barn.is_empty():
		hud.buildings.add_expansion_card(content, barn, int(barn["uid"]))
	hud.feed.add_barn_stock(content)


## One card per kind among the stored things from index `from` up to `to` (as FarmVille's storage: the picture,
## how many, tap to place the first of that kind), on a CardList (a full barn is hundreds, the gift box thousands).
func add_grouped(content: VBoxContainer, from: int, to: int) -> void:
	var first := {}
	var count := {}
	for k in range(from, to):
		var id := str(Game.storage.stored[k]["id"])
		if not first.has(id):
			first[id] = k
		count[id] = int(count.get(id, 0)) + 1
	var kinds: Array[String] = []
	kinds.assign(first.keys())
	var face := func(id: String) -> Dictionary:
		return {"name": Game.name_of(id), "count": tr("TIMES_N") % count[id], "badge": ["", tr("PLACE_2")]}
	var stored := CardList.make(kinds, face, func(id: String) -> void:
		hud.close_panels()
		hud.place_stored_requested.emit(int(first[id])), hud.get_viewport().get_visible_rect().size.x)
	stored.search_menu = "barn"
	content.add_child(stored)


## A bloom's card: when it's ready, whether it has withered (and regrowing it with Flower Food), and for a
## Single Bloom, upgrading it to a Full Bloom that never withers.
func build_bloom(content: VBoxContainer) -> void:
	var o := Game.object_by_uid(hud.building_uid)
	var d := Game.catalog.get_def(str(o.get("id", ""))) as BloomDef
	if d == null:
		return
	var uid := hud.building_uid
	if Game.is_withered(o):
		content.add_child(BookPanel.text(tr("THIS_BLOOM_HAS_WITHERED"), UiTheme.BODY, BookPanel.SOFT))
		content.add_child(BookPanel.text(tr("YOU_HAVE_N") % [Game.nurture.has_supply("flower_food"),
			Game.nurture.supply_name("flower_food")], UiTheme.HEADING, BookPanel.SOFT))
		var regrow := hud.panel_button(tr("REGROW_IT"))
		regrow.disabled = Game.nurture.free_supply("flower_food") <= 0
		regrow.pressed.connect(func() -> void:
			Game.player.enqueue({"kind": "nurture", "uid": uid})
			hud.close_panels())
		content.add_child(regrow)
		var buy := hud.panel_button(tr("BUY_ONE_FOR_GEMS") % [Game.nurture.supply_name("flower_food"),
			NurtureSystem.gem_cost("flower_food")])
		buy.disabled = Game.gems < NurtureSystem.gem_cost("flower_food")
		buy.pressed.connect(func() -> void:
			if Game.nurture.buy_supply("flower_food", 1):
				hud.show_building(uid))
		content.add_child(buy)
	else:
		content.add_child(BookPanel.text(tr("READY_IN") % [d.data["name"], tr("FLOWERS"),
			FarmGrid.format_duration(Game.seconds_until_ready(o))], UiTheme.HEADING, BookPanel.SOFT))
	if d.withers():
		var stands := FarmGrid.format_duration(Balance.i("blooms.wither_after"))
		content.add_child(BookPanel.info(tr("A_SINGLE_BLOOM_WITHERS") % stands,
			tr("A_SINGLE_BLOOM_WITHERS_INFO") % stands, UiTheme.HEADING, BookPanel.SOFT))
		var up := hud.panel_button(tr("UPGRADE_TO_A_FULL_BLOOM_GEMS") % d.upgrade_gems())
		up.disabled = Game.gems < d.upgrade_gems()
		up.pressed.connect(func() -> void:
			if Game.nurture.upgrade_bloom(uid):
				hud.show_building(uid))
		content.add_child(up)


## A mystery young's card: how far it has grown, the supply it needs and how many you have, and more for gems.
func build_young(content: VBoxContainer) -> void:
	var o := Game.object_by_uid(hud.building_uid)
	if not Game.nurture.is_young(o):
		return
	var supply := Game.nurture.supply_of(o)
	var name := Game.nurture.supply_name(supply)
	content.add_child(BookPanel.text(tr("GIVE_IT_TO_SEE_WHAT_IT_GROWS_INTO") % [Game.nurture.needs(o), name], UiTheme.BODY,
		BookPanel.SOFT))
	var card := BookPanel.card()
	card.add_child(BookPanel.text(tr("OF_2") % [name, Game.nurture.fed(o), Game.nurture.needs(o)], UiTheme.BODY))
	var bar := UiKit.thin_bar(Game.nurture.fed(o), Game.nurture.needs(o))
	card.add_child(bar)
	card.add_child(BookPanel.text(tr("YOU_HAVE_N") % [Game.nurture.has_supply(supply), name], UiTheme.HEADING))
	content.add_child(BookPanel.card_frame(card))
	var uid := hud.building_uid
	var give := hud.panel_button(tr("GIVE_ONE"))
	give.disabled = Game.nurture.free_supply(supply) <= 0
	give.pressed.connect(func() -> void:
		Game.player.enqueue({"kind": "nurture", "uid": uid})
		hud.close_panels())
	content.add_child(give)
	var gems := NurtureSystem.gem_cost(supply)
	var buy := hud.panel_button(tr("BUY_ONE_FOR_GEMS") % [name, gems])
	buy.disabled = Game.gems < gems
	buy.pressed.connect(func() -> void:
		if Game.nurture.buy_supply(supply, 1):
			hud.show_building(uid))
	content.add_child(buy)
