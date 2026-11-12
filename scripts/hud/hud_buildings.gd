class_name HudBuildings
extends RefCounted
## The panel of a tapped building: its state, upgrades and its own extras (Garage, hives, pig pen, shed).
## Moved out of FarmHud: builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner


func build_building(content: VBoxContainer) -> void:
	var o := Game.object_by_uid(hud._building_uid)
	if o.is_empty():
		hud._book.close_panel()
		return
	var uid := hud._building_uid
	if Game.under_construction(o):
		build_construction(content, o, uid)
		return
	if str(Game.item_data(o["id"]).get("special", "")) == "finds_home":
		build_finds_home(content, o)
		return
	var total := Game.inside_total(o)
	var cap := Game.capacity(o)
	var pay := Game.object_payout(o)

	var status := BookPanel.card()
	status.add_theme_constant_override("separation", 8)
	status.add_child(BookPanel.text(tr("OF_SPACES_USED") % [Game.size_name(o), total, cap], 22))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 18
	bar.max_value = cap
	bar.value = total
	status.add_child(bar)
	var inside: Dictionary = o["inside"]
	if inside.is_empty():
		status.add_child(BookPanel.text(tr("EMPTY_MOVE_ANIMALS_IN_TO_START"), 18))
	else:
		var names: Array[String] = []
		for id in inside:
			names.append("%d %s" % [int(inside[id]), Game.item_data(id)["name"]])
		status.add_child(BookPanel.text(tr("INSIDE").join(PackedStringArray(names)), 18))
		if total > 0 and pay != Vector2i.ZERO:
			var when := tr("READY_TO_COLLECT") if Game.is_ready(o) \
				else tr("READY_IN_4") + FarmGrid.format_duration(Game.seconds_until_ready(o))
			status.add_child(BookPanel.text(tr("PAYS_COINS_XP") % [when, pay.x, pay.y], 18))
	var layout := hud.feed.layout_line(o)
	if layout != "":
		status.add_child(BookPanel.text(layout, 18))
	var boost := hud.feed.boost_line(o)
	if boost != "":
		status.add_child(BookPanel.text(boost, 18))
	content.add_child(BookPanel.card_frame(status))

	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 12)
	actions.add_theme_constant_override("v_separation", 12)
	if Game.is_ready(o):
		var collect := hud._panel_button(tr("COLLECT"))
		collect.pressed.connect(func() -> void:
			var r := Game.collect(uid)
			if not r.is_empty():
				hud.show_message(tr("COINS_XP") % [r["coins"], r["xp"]]))
		actions.add_child(collect)
	if o["id"] != "beehive":
		var loose := Game.homes.loose_matching(o)
		var fill := hud._panel_button(tr("MOVE_IN") % loose if loose > 0 else tr("NONE_ON_FARM"))
		fill.disabled = loose == 0
		fill.pressed.connect(func() -> void: Game.homes.fill_building(uid))
		actions.add_child(fill)
	content.add_child(actions)

	hud.feed.add_feed_card(content, o)
	add_building_special_info(content, o)
	add_expansion_card(content, o, uid)


## A home for what's found while farming (the Gopher Garden): each kind with how many you have (a question
## mark for the ones not found yet) and what it takes to grow.
func build_finds_home(content: VBoxContainer, o: Dictionary) -> void:
	var family := str(Game.item_data(o["id"]).get("home_of", ""))
	var fam: Dictionary = Game.finds.families.get(family, {})
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	card.add_child(BookPanel.text(Game.size_name(o), 22))
	card.add_child(BookPanel.text(tr("FINDS_HOME_FOUND") % [fam.get("name", family), Game.finds.total(family),
		Game.finds.distinct(family), (fam.get("kinds", []) as Array).size()], 18))
	for kind: Dictionary in fam.get("kinds", []):
		var n := Game.finds.count(str(kind["id"]))
		card.add_child(BookPanel.text("%s  ×%d  (%s)" % [kind["name"], n, kind["rarity"]] if n > 0
			else "?  (%s)" % kind["rarity"], 17, BookPanel.CREAM))
	var tiers: Array = fam.get("tiers", [])
	var next_at := 0
	for t in tiers:
		if Game.finds.total(family) < int(t):
			next_at = int(t)
			break
	if next_at > 0:
		card.add_child(BookPanel.text(tr("FINDS_HOME_NEXT") % next_at, 17, BookPanel.CREAM))
	for target: String in fam.get("helps", {}):
		card.add_child(BookPanel.text(tr("FINDS_HELPS") % [roundi(float(fam["helps"][target]) * 100.0),
			str(Game.finds.families.get(target, {}).get("name", target)).to_lower()], 17, BookPanel.SUN))
	content.add_child(BookPanel.card_frame(card))


## Frame being built: what's in, what's missing, and a button to add held materials.
func build_construction(content: VBoxContainer, o: Dictionary, uid: int) -> void:
	var it := Game.item_data(o["id"])
	content.add_child(
		BookPanel.text(
			tr("THIS_IS_A_BUILDING_FRAME_FINISH"),
			19,
			BookPanel.CREAM
		)
	)
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	var need: Dictionary = it.get("build_materials", {})
	var have: Dictionary = o["construction"]
	for m in need:
		var got := int(have.get(m, 0))
		var want := int(need[m])
		card.add_child(
			BookPanel.text(
				tr("OF_YOU_HOLD") % [GameState.part_names[m], got, want, int(Game.parts.get(m, 0))],
				19
			)
		)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 14
		bar.max_value = want
		bar.value = got
		card.add_child(bar)
	content.add_child(BookPanel.card_frame(card))
	var add := hud._panel_button(tr("ADD_MY_MATERIALS"))
	add.pressed.connect(func() -> void: Game.land.add_materials(uid))
	content.add_child(add)
	add_buy_missing(content, Game.land.construction_needs(o), func() -> void: Game.land.add_materials(uid))


## FarmVille sold building materials for Farm Cash: a button to buy what's still missing with gems, then
## use them (`then`). Nothing when nothing is missing.
func add_buy_missing(content: Control, need: Dictionary, then: Callable) -> void:
	var gems := Game.buildings.gems_for(need)
	if gems <= 0:
		return
	var buy := hud._panel_button(tr("BUY_MISSING_FOR_GEMS") % gems)
	buy.disabled = Game.gems < gems
	buy.pressed.connect(func() -> void:
		if Game.buildings.buy_missing(need):
			then.call()
		hud._book.refresh())
	content.add_child(buy)


## What makes this building special, the FarmVille way.
func add_building_special_info(content: VBoxContainer, o: Dictionary) -> void:
	var it := Game.item_data(o["id"])
	match it.get("special", ""):
		"mystery_eggs":
			content.add_child(
				BookPanel.text(
					tr("HARVESTING_CAN_TURN_UP_MYSTERY_EGGS"),
					17,
					BookPanel.CREAM
				)
			)
			var eggs := HFlowContainer.new()
			eggs.add_theme_constant_override("h_separation", 10)
			eggs.add_theme_constant_override("v_separation", 10)
			for colour in Game.mystery.egg_data.get("colours", {}):
				var n := int(Game.mystery.mystery_eggs.get(colour, 0))
				if n <= 0:
					continue
				var b := hud._panel_button(tr("OPEN") % [Game.mystery.egg_data["colours"][colour]["name"], n])
				var c: String = colour
				b.pressed.connect(func() -> void:
					var prize := Game.mystery.open_mystery_egg(c)
					if prize != "":
						hud.show_message(tr("YOU_GOT") + prize))
				eggs.add_child(b)
			if eggs.get_child_count() > 0:
				content.add_child(eggs)
		"calves":
			var bull := tr("A_BULL_LIVES_HERE_HARVESTS_CAN") if Game.has_inside(o, "bull") else tr("NO_BULL_YET_A_LONELY_BULL")
			content.add_child(
				BookPanel.text(bull + tr("HARVESTS_SOMETIMES_LEAVE_A_BAG_OF"), 17, BookPanel.CREAM)
			)
		"foals":
			var st := tr("A_STALLION_LIVES_HERE_HARVESTS_CAN") if Game.has_inside(o, "stallion") \
				else tr("NO_STALLION_YET_A_WANDERING_STALLION")
			content.add_child(
				BookPanel.text(
					tr("HORSES_HERE_ARE_READY_EVERY_DAY") + st + tr("HARVESTS_CAN_ALSO_GIVE_FARMHANDS_AND"),
					17,
					BookPanel.CREAM
				)
			)
		"nursery":
			var grow := int(it.get("grow_days", 4))
			var lines: Array[String] = []
			for baby in o.get("growing", []):
				lines.append(tr("OF_DAYS") % [Game.item_data(baby[0])["name"], int(baby[1]), grow])
			var txt := tr("CALVES_AND_FOALS_GROW_UP_HERE") % grow
			if not lines.is_empty():
				txt += "\n\n".join(PackedStringArray(lines))
			content.add_child(BookPanel.text(txt, 17, BookPanel.CREAM))
		"beehive":
			add_hive_info(content, o)
		"truffles":
			add_pig_pen_info(content, o)
		"garage":
			add_garage_info(content)
		"garden_shed":
			add_shed_info(content)
		"saplings":
			content.add_child(
				BookPanel.text(
					tr("HARVESTS_GIVE_A_MYSTERY_SEEDLING_OR"),
					17,
					BookPanel.CREAM
				)
			)


## The Garden Shed: Perfect Bunches found while harvesting flowers, ready to place for 14 days.
func add_shed_info(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text(tr("PERFECT_BUNCHES_OF_HARVESTING_FLOWERS_SOMETIMES") % [
		Game.shed.bunches.size(), Game.shed.bunch_cap(), Balance.i("barn.bunch_days")], 17, BookPanel.CREAM))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	for k in Game.shed.bunches.size():
		var flower: String = Game.shed.bunches[k]
		var b := hud._panel_button(tr("PLACE") % Game.crops[flower]["name"])
		var idx := k
		b.pressed.connect(func() -> void:
			var at := Game.shed.unpack_bunch(idx)
			if at >= 0:
				hud._book.close_panel()
				hud.place_stored_requested.emit(at))
		flow.add_child(b)
	content.add_child(flow)


func add_garage_info(content: VBoxContainer) -> void:
	content.add_child(
		BookPanel.text(
			tr("VEHICLE_PARTS_HELD_THEY_TURN_UP") % int(Game.parts.get("vehicle_parts", 0)),
			17,
			BookPanel.CREAM
		)
	)
	var owned := Game.vehicles.usable_vehicles()
	var outside := Game.vehicles.loose_vehicles()
	if outside > 0:
		content.add_child(BookPanel.text(tr("X_VEHICLES_OUTSIDE") % outside, 17, BookPanel.CREAM))
	if owned.is_empty():
		content.add_child(
			BookPanel.text(tr("NO_VEHICLES_YET_BUY_A_TRACTOR"), 18, BookPanel.CREAM)
		)
		return
	content.add_child(BookPanel.text(tr("VEHICLES_ARE_PARKED_HERE"), 17, BookPanel.CREAM))
	for id in owned:
		var it := Game.item_data(id)
		var area := Game.vehicles.vehicle_area(id)
		var card := BookPanel.card()
		card.add_theme_constant_override("separation", 6)
		card.add_child(
			BookPanel.text(
				tr("WORKS_X_PLOTS_UPGRADE_OF") % [
					it["name"],
					area.x,
					area.y,
					Game.vehicles.vehicle_level(id)
				],
				21
			)
		)
		var cost := Game.vehicles.vehicle_upgrade_cost(id)
		var vid: String = id
		var drive := hud._panel_button(tr("USE_VEHICLE"))
		drive.pressed.connect(func() -> void:
			hud._book.close_panel()
			hud.tool_selected.emit("vehicle", vid))
		card.add_child(drive)
		if cost < 0:
			card.add_child(BookPanel.text(tr("FULLY_UPGRADED"), 18))
		else:
			var next: Vector2i = GameState.VEHICLE_SIZES[Game.vehicles.vehicle_level(id) + 1]
			var need_lvl := Game.vehicles.vehicle_upgrade_level_needed(id)
			var line := tr("NEXT_X_FOR_VEHICLE_PARTS") % [next.x, next.y, cost]
			if need_lvl > Game.level():
				line += tr("LEVEL_3") % need_lvl
			card.add_child(BookPanel.text(line, 18))
			var up := hud._panel_button(tr("UPGRADE"))
			up.disabled = not Game.vehicles.can_upgrade_vehicle(id)
			up.pressed.connect(func() -> void: Game.vehicles.upgrade_vehicle(vid))
			card.add_child(up)
		content.add_child(BookPanel.card_frame(card))


func build_fuel(content: VBoxContainer) -> void:
	var fuel := Game.vehicles.fuel_now()
	content.add_child(
		BookPanel.text(
			tr("ALL_VEHICLES_SHARE_ONE_TANK_OF") % [
				Balance.i("vehicles.fuel_tank"),
				int(Balance.i("vehicles.fuel_regen_seconds") / 60.0)
			],
			18,
			BookPanel.CREAM
		)
	)
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	card.add_child(
		BookPanel.text(
			tr("TANK_OF_SPARE_TANKS") % [fuel, Balance.i("vehicles.fuel_tank"), Game.vehicles.fuel_tanks],
			21
		)
	)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 18
	bar.max_value = Balance.i("vehicles.fuel_tank")
	bar.value = fuel
	card.add_child(bar)
	var buy := hud._panel_button(tr("BUY_A_FULL_TANK_GEMS") % Balance.i("vehicles.fuel_tank_gem_cost"))
	buy.disabled = Game.gems < Balance.i("vehicles.fuel_tank_gem_cost")
	buy.pressed.connect(func() -> void: Game.vehicles.buy_fuel_tank())
	card.add_child(buy)
	content.add_child(BookPanel.card_frame(card))


func add_hive_info(content: VBoxContainer, o: Dictionary) -> void:
	var uid := int(o["uid"])
	if Game.bees.has_queen(o):
		content.add_child(BookPanel.text(tr("THE_QUEEN_BEE_LIVES_HERE_WORKER") % Game.capacity(o), 17, BookPanel.CREAM))
	else:
		content.add_child(
			BookPanel.text(
				tr("THIS_HIVE_NEEDS_A_QUEEN_BEE"),
				17,
				BookPanel.CREAM
			)
		)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 12)
		var put := hud._panel_button(tr("ADD_QUEEN_BEE_HELD") % Game.bees.queen_bees)
		put.disabled = Game.bees.queen_bees <= 0
		put.pressed.connect(func() -> void: Game.bees.add_queen(uid))
		row.add_child(put)
		var buy := hud._panel_button(tr("BUY_QUEEN_BEE_GEMS") % Balance.i("bees.queen_gem_cost"))
		buy.disabled = Game.gems < Balance.i("bees.queen_gem_cost")
		buy.pressed.connect(func() -> void: Game.bees.add_queen(uid, true))
		row.add_child(buy)
		content.add_child(row)
	content.add_child(
		BookPanel.text(
			tr("POLLINATION_HARVESTING_A_FERTILIZED_CROP_HAS") % [
				int(round(Game.bees.pollination_chance() * 100)),
				Balance.i("bees.bees_stay_days")
			],
			17,
			BookPanel.CREAM
		)
	)


func add_pig_pen_info(content: VBoxContainer, o: Dictionary) -> void:
	var uid := int(o["uid"])
	var pigs := Game.inside_total(o)
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	card.add_child(BookPanel.text(tr("TRUFFLES_HELD") % Game.pigpen.truffles, 21))
	if not Game.pigpen.is_foraging(o):
		card.add_child(BookPanel.text(tr("FEED_THE_PIGS_SLOP_AND_THEY") % Balance.i("pigpen.pigs_per_truffle"), 17))
		var feed := hud._panel_button(tr("FEED_SLOP_COINS") % Balance.i("pigpen.slop_cost"))
		feed.disabled = pigs == 0 or Game.coins < Balance.i("pigpen.slop_cost")
		feed.pressed.connect(func() -> void: Game.pigpen.feed_slop(uid))
		card.add_child(feed)
	elif Game.pigpen.forage_seconds_left(o) > 0:
		card.add_child(
			BookPanel.text(tr("FORAGING_BACK_IN") + FarmGrid.format_duration(Game.pigpen.forage_seconds_left(o)), 18)
		)
	else:
		var dig := hud._panel_button(tr("COLLECT_TRUFFLES"))
		dig.pressed.connect(func() -> void:
			var n := Game.pigpen.collect_truffles(uid)
			if n > 0:
				hud.show_message(tr("TRUFFLES") % n))
		card.add_child(dig)
	card.add_child(BookPanel.text(tr("TRADE_TRUFFLES_FOR_A_RARE_PIG") % Balance.i("pigpen.truffles_per_pig"), 18))
	var breeds := HFlowContainer.new()
	breeds.add_theme_constant_override("h_separation", 10)
	breeds.add_theme_constant_override("v_separation", 10)
	for id in Game.pigpen.rare_pigs():
		var b := hud._panel_button(Game.item_data(id)["name"])
		b.disabled = Game.pigpen.truffles < Balance.i("pigpen.truffles_per_pig")
		var breed: String = id
		b.pressed.connect(func() -> void: Game.pigpen.trade_truffles(breed))
		breeds.add_child(b)
	card.add_child(breeds)
	content.add_child(BookPanel.card_frame(card))


## Next size and its material cost.
func add_expansion_card(content: VBoxContainer, o: Dictionary, uid: int) -> void:
	var need := Game.land.expansion_needs(o)
	if need.is_empty():
		content.add_child(BookPanel.text(tr("FULLY_EXPANDED"), 18, BookPanel.CREAM))
		return
	var next := Game.building_def(o["id"]).size(Game.level_of(o) + 1)
	var next_name := str(next.get("name", tr("NEXT_SIZE")))
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 6)
	card.add_child(BookPanel.text(tr("EXPAND_TO_HOLDS") % [next_name, int(next["capacity"])], 21))
	for m in need:
		card.add_child(
			BookPanel.text(
				tr("OF") % [
					GameState.part_names[m],
					mini(int(Game.parts.get(m, 0)), int(need[m])),
					int(need[m])
				],
				18
			)
		)
	var up := hud._panel_button(tr("EXPAND"))
	up.disabled = not Game.land.can_expand(o)
	up.pressed.connect(func() -> void: Game.land.upgrade_building(uid))
	card.add_child(up)
	add_buy_missing(card, need, func() -> void: Game.land.upgrade_building(uid))
	content.add_child(BookPanel.card_frame(card))
