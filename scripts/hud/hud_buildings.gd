class_name HudBuildings
extends RefCounted
## Pieces of a tapped building's sheet (BuildingSheet): its next size, its own extras (Garage, hives, pig pen,
## shed, nursery), a site's materials, a Dog House's finds, the vehicles' fuel. Each builds into the page or part
## it is given; shared helpers (buttons, messages) are on `hud`.


var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner



## The fill button's words: how many would move in, else why none would (the home is full, or none are loose).
static func fill_words(o: Dictionary, room: int) -> String:
	if room > 0:
		return move_in_words(o, room)
	return TranslationServer.translate("FILL_FULL" if Game.homes.loose_matching(o) > 0 else "NONE_ON_FARM")


## The words on a home's fill button: "Add 10 animals" for an animal home, "Add 3" for one that holds vehicles,
## trees or blooms (the home's picture says what).
static func move_in_words(o: Dictionary, n: int) -> String:
	var holds := str(Game.item_data(str(o.get("id", ""))).get("holds_kind", ""))
	return TranslationServer.translate("MOVE_IN_ANIMALS" if holds == "" else "MOVE_IN") % n




## A building's state in a few words: a frame and how far along, broken, ready, or how long until it is.
func state_line(o: Dictionary) -> String:
	if Game.under_construction(o):
		return tr("STATE_FRAME") % roundi(Game.land.construction_progress(o) * 100.0)
	if o.get("broken", false):
		return tr("STATE_BROKEN")
	if Game.is_ready(o):
		return tr("READY_TO_COLLECT")
	if not Game.is_home(o):
		return ""
	if Game.inside_total(o) > 0 and Game.object_payout(o) != Vector2i.ZERO:
		return tr("STATE_READY_IN") % FarmGrid.format_duration(Game.seconds_until_ready(o))
	return tr("STATE_STANDING") % [Game.inside_total(o), Game.capacity(o)]


## A home for what's found while farming (the Gopher Garden): each kind with how many you have (a question
## mark for the ones not found yet) and what it takes to grow.
func build_finds_home(content: VBoxContainer, o: Dictionary) -> void:
	var family := str(Game.item_data(o["id"]).get("home_of", ""))
	var fam: Dictionary = Game.finds.families.get(family, {})
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	card.add_child(BookPanel.text(Game.size_name(o), UiTheme.HEADING))
	card.add_child(BookPanel.text(tr("FINDS_HOME_FOUND") % [fam.get("name", family), Game.finds.total(family),
		Game.finds.distinct(family), (fam.get("kinds", []) as Array).size()], 18))
	for kind: Dictionary in fam.get("kinds", []):
		var n := Game.finds.count(str(kind["id"]))
		card.add_child(BookPanel.text("%s  ×%d  (%s)" % [kind["name"], n, kind["rarity"]] if n > 0
			else "?  (%s)" % kind["rarity"], 17, BookPanel.SOFT))
	var tiers: Array = fam.get("tiers", [])
	var next_at := 0
	for t in tiers:
		if Game.finds.total(family) < int(t):
			next_at = int(t)
			break
	if next_at > 0:
		card.add_child(BookPanel.text(tr("FINDS_HOME_NEXT") % next_at, 17, BookPanel.SOFT))
	for target: String in fam.get("helps", {}):
		card.add_child(BookPanel.text(tr("FINDS_HELPS") % [roundi(float(fam["helps"][target]) * 100.0),
			str(Game.finds.families.get(target, {}).get("name", target)).to_lower()], 17, BookPanel.HEAD))
	content.add_child(BookPanel.card_frame(card))



## FarmVille sold building materials for Farm Cash: a button to buy what's still missing with gems, then
## use them (`then`). Nothing when nothing is missing.
func add_buy_missing(content: Control, need: Dictionary, then: Callable) -> void:
	var gems := Game.buildings.gems_for(need)
	if gems <= 0:
		return
	var buy := hud.panel_button(tr("BUY_MISSING_FOR_GEMS") % gems)
	buy.disabled = Game.gems < gems
	buy.pressed.connect(func() -> void:
		if Game.buildings.buy_missing(need):
			then.call()
		hud.refresh_panels())
	content.add_child(buy)


## What makes this building special, the FarmVille way.
func add_building_special_info(content: VBoxContainer, o: Dictionary) -> void:
	var it := Game.item_data(o["id"])
	match it.get("special", ""):
		"mystery_eggs":
			content.add_child(
				BookPanel.info(
					tr("HARVESTING_CAN_TURN_UP_MYSTERY_EGGS"), tr("HARVESTING_CAN_TURN_UP_MYSTERY_EGGS_INFO"),
					17,
					BookPanel.SOFT
				)
			)
			var eggs := HFlowContainer.new()
			eggs.add_theme_constant_override("h_separation", 10)
			eggs.add_theme_constant_override("v_separation", 10)
			for colour in Game.mystery.egg_data.get("colours", {}):
				var n := int(Game.mystery.mystery_eggs.get(colour, 0))
				if n <= 0:
					continue
				var b := hud.panel_button(tr("OPEN") % [Game.mystery.egg_data["colours"][colour]["name"], n])
				var c: String = colour
				b.pressed.connect(func() -> void:
					var prize := Game.mystery.open_mystery_egg(c)
					if prize != "":
						hud.reveal(c, str(Game.mystery.egg_data["colours"][c]["name"]), prize, Game.mystery.last_rarity)
						hud.refresh_panels())
				eggs.add_child(b)
			if eggs.get_child_count() > 0:
				content.add_child(eggs)
			else:
				eggs.free()   # (no eggs: the row was never shown; one left out of the tree is never freed)
		"calves":
			var bull := tr("A_BULL_LIVES_HERE_HARVESTS_CAN") if Game.has_inside(o, "bull") else tr("NO_BULL_YET_A_LONELY_BULL")
			content.add_child(
				BookPanel.text(bull + tr("HARVESTS_SOMETIMES_LEAVE_A_BAG_OF"), 17, BookPanel.SOFT)
			)
		"foals":
			var st := tr("A_STALLION_LIVES_HERE_HARVESTS_CAN") if Game.has_inside(o, "stallion") \
				else tr("NO_STALLION_YET_A_WANDERING_STALLION")
			content.add_child(
				BookPanel.text(
					tr("HORSES_HERE_ARE_READY_EVERY_DAY") % [FarmGrid.format_duration(Game.cycle_of(o)),
						FarmGrid.format_duration(int(Game.item_data("horse").get("cycle_seconds", 0)))]
						+ st + tr("HARVESTS_CAN_ALSO_GIVE_FARMHANDS_AND"),
					17,
					BookPanel.SOFT
				)
			)
		"nursery":
			add_nursery_info(content, o)
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
				BookPanel.info(
					tr("HARVESTS_GIVE_A_MYSTERY_SEEDLING_OR"), tr("HARVESTS_GIVE_A_MYSTERY_SEEDLING_OR_INFO")
						% (Game.catalog.get_def("mystery_seedling") as YoungDef).needs(),
					17,
					BookPanel.SOFT
				)
			)


## The Garden Shed: Perfect Bunches found while harvesting flowers, ready to place for 14 days.
func add_shed_info(content: VBoxContainer) -> void:
	content.add_child(BookPanel.info(tr("PERFECT_BUNCHES_OF_HARVESTING_FLOWERS_SOMETIMES") % [
		Game.shed.bunches.size(), Game.shed.bunch_cap()], tr("PERFECT_BUNCHES_OF_HARVESTING_FLOWERS_SOMETIMES_INFO") % [
		Game.shed.bunches.size(), Game.shed.bunch_cap(), Balance.i("barn.bunch_days")], 17, BookPanel.SOFT))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	for k in Game.shed.bunches.size():
		var flower: String = Game.shed.bunches[k]
		var b := hud.panel_button(tr("PLACE") % Game.crops[flower]["name"])
		var idx := k
		b.pressed.connect(func() -> void:
			var at := Game.shed.unpack_bunch(idx)
			if at >= 0:
				hud.close_panels()
				hud.place_stored_requested.emit(at))
		flow.add_child(b)
	content.add_child(flow)


func add_garage_info(content: VBoxContainer) -> void:
	content.add_child(
		BookPanel.info(
			tr("VEHICLE_PARTS_HELD_THEY_TURN_UP") % int(Game.parts.get("vehicle_parts", 0)),
			tr("VEHICLE_PARTS_HELD_THEY_TURN_UP_INFO") % int(Game.parts.get("vehicle_parts", 0)),
			17,
			BookPanel.SOFT
		)
	)
	var owned := Game.vehicles.usable_vehicles()
	var outside := Game.vehicles.loose_vehicles()
	if outside > 0:
		content.add_child(BookPanel.text(tr("X_VEHICLES_OUTSIDE") % outside, 17, BookPanel.SOFT))
	if owned.is_empty():
		content.add_child(
			BookPanel.text(tr("NO_VEHICLES_YET_BUY_A_TRACTOR"), 18, BookPanel.SOFT)
		)
		return
	content.add_child(BookPanel.text(tr("VEHICLES_ARE_PARKED_HERE"), 17, BookPanel.SOFT))
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
		var drive := hud.panel_button(tr("USE_VEHICLE"))
		drive.pressed.connect(func() -> void:
			hud.close_panels()
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
			var up := hud.panel_button(tr("UPGRADE"))
			up.disabled = not Game.vehicles.can_upgrade_vehicle(id)
			up.pressed.connect(func() -> void: Game.vehicles.upgrade_vehicle(vid))
			card.add_child(up)
		add_rust_lines(card, id)
		content.add_child(BookPanel.card_frame(card))


## A vehicle's rust as a card of its own (the sheet of one standing on the farm).
func add_rust_card(content: VBoxContainer, id: String) -> void:
	if id == "" or not Game.rust.is_on():
		return
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 6)
	add_rust_lines(card, id)
	content.add_child(BookPanel.card_frame(card))


## A vehicle's rust (docs/RUST.md): its level and what that costs, where it stands, and its repair.
func add_rust_lines(card: Container, id: String) -> void:
	var rust := Game.rust
	if not rust.is_on():
		return
	var at := rust.level(id)
	if rust.repairing(id):
		card.add_child(BookPanel.text(tr("RUST_REPAIR_LEFT") % FarmGrid.format_duration(rust.repair_left(id)), 18))
	elif at <= 0:
		card.add_child(BookPanel.text(tr("RUST_NONE"), 18, BookPanel.SOFT))
	elif rust.seized(id):
		card.add_child(BookPanel.text(tr("RUST_SEIZED_LINE") % at, 18))
	else:
		card.add_child(BookPanel.text(tr("RUST_LEVEL_LINE") % [at, rust.max_level(),
			roundi(Balance.f("rust.fuel_more") * at * 100.0), roundi(Balance.f("rust.area_less") * at * 100.0)], 18))
	if rust.stands_outside(id):
		card.add_child(BookPanel.text(tr("RUST_OUTSIDE_LINE"), 16, BookPanel.SOFT))
	var cost := rust.repair_cost(id)
	if not cost.is_empty() and not rust.repairing(id):
		var fix := hud.panel_button(tr("RUST_REPAIR_BUTTON") % [int(cost["coins"]),
			FarmGrid.format_duration(int(cost["seconds"]))])
		fix.disabled = not rust.can_repair(id)
		fix.pressed.connect(func() -> void:
			Game.rust.repair(id)
			hud.refresh_panels())
		card.add_child(fix)


func build_fuel(content: VBoxContainer) -> void:
	var fuel := Game.vehicles.fuel_now()
	content.add_child(
		BookPanel.info(
			tr("ALL_VEHICLES_SHARE_ONE_TANK_OF") % Balance.i("vehicles.fuel_tank"),
			tr("ALL_VEHICLES_SHARE_ONE_TANK_OF_INFO") % [
				Balance.i("vehicles.fuel_tank"),
				int(Balance.i("vehicles.fuel_regen_seconds") / 60.0)
			],
			18,
			BookPanel.SOFT
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
	var buy := hud.panel_button(tr("BUY_A_FULL_TANK_GEMS") % Balance.i("vehicles.fuel_tank_gem_cost"))
	buy.disabled = Game.gems < Balance.i("vehicles.fuel_tank_gem_cost")
	buy.pressed.connect(func() -> void: Game.vehicles.buy_fuel_tank())
	card.add_child(buy)
	content.add_child(BookPanel.card_frame(card))


## A nursery (RaisingSystem): its babies in line, oldest first, and its trough: how full, how far the first baby
## is from growing up, and a button that pours in the Animal Feed it can take (or says why not).
func add_nursery_info(content: VBoxContainer, o: Dictionary) -> void:
	var uid := int(o["uid"])
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	var line := Game.raising.babies(o)
	var need := Game.raising.need_each()
	card.add_child(BookPanel.text(tr("TROUGH_OF") % [Game.raising.trough(o), line.size() * need], UiTheme.BODY))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 14
	bar.max_value = maxf(line.size() * need, 1.0)
	bar.value = Game.raising.trough(o)
	card.add_child(bar)
	if line.is_empty():
		card.add_child(BookPanel.text(tr("NURSERY_EMPTY"), 17))
	else:
		var queue: Array = []
		for k in line.size():   # each baby with the feed it has towards growing up
			var has := clampi(Game.raising.trough(o) - k * need, 0, need)
			queue.append([line[k], "%d/%d" % [has, need]])
		card.add_child(UiKit.count_row(queue))
		card.add_child(BookPanel.info(tr("NURSERY_HOW") % need, tr("NURSERY_HOW_INFO") % need, 17))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	var have := Game.nurture.has_supply("animal_feed")
	var pours := Game.raising.can_pour(o)
	var pour := hud.panel_button(tr("POUR_FEED") % pours if pours > 0 else (tr("TROUGH_FULL")
		if Game.raising.room(o) == 0 and not line.is_empty() else tr("NO_ANIMAL_FEED")))
	pour.disabled = pours <= 0
	pour.pressed.connect(func() -> void:
		var grown := Game.raising.pour(uid)
		if not grown.is_empty():
			Feedback.moment("level_up_soft")
		hud.refresh_panels())
	row.add_child(pour)
	card.add_child(row)
	card.add_child(BookPanel.text(tr("ANIMAL_FEED_HAVE") % have, 16, BookPanel.SOFT))
	content.add_child(BookPanel.card_frame(card))


func add_hive_info(content: VBoxContainer, o: Dictionary) -> void:
	var uid := int(o["uid"])
	if Game.bees.has_queen(o):
		content.add_child(BookPanel.info(tr("THE_QUEEN_BEE_LIVES_HERE_WORKER") % Game.capacity(o),
			tr("THE_QUEEN_BEE_LIVES_HERE_WORKER_INFO") % Game.capacity(o), 17, BookPanel.SOFT))
	else:
		content.add_child(
			BookPanel.info(
				tr("THIS_HIVE_NEEDS_A_QUEEN_BEE"), tr("THIS_HIVE_NEEDS_A_QUEEN_BEE_INFO"),
				17,
				BookPanel.SOFT
			)
		)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 12)
		var put := hud.panel_button(tr("ADD_QUEEN_BEE_HELD") % Game.bees.queen_bees)
		put.disabled = Game.bees.queen_bees <= 0
		put.pressed.connect(func() -> void: Game.bees.add_queen(uid))
		row.add_child(put)
		var buy := hud.panel_button(tr("BUY_QUEEN_BEE_GEMS") % Balance.i("bees.queen_gem_cost"))
		buy.disabled = Game.gems < Balance.i("bees.queen_gem_cost")
		buy.pressed.connect(func() -> void: Game.bees.add_queen(uid, true))
		row.add_child(buy)
		content.add_child(row)
	content.add_child(
		BookPanel.info(
			tr("POLLINATION_HARVESTING_A_FERTILIZED_CROP_HAS"),
			tr("POLLINATION_HARVESTING_A_FERTILIZED_CROP_HAS_INFO") % [
				int(round(Game.bees.pollination_chance() * 100)),
				Balance.i("bees.bees_stay_days")
			],
			17,
			BookPanel.SOFT
		)
	)


func add_pig_pen_info(content: VBoxContainer, o: Dictionary) -> void:
	var uid := int(o["uid"])
	var pigs := Game.inside_total(o)
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	card.add_child(BookPanel.text(tr("TRUFFLES_HELD") % Game.pigpen.truffles, UiTheme.BODY))
	if not Game.pigpen.is_foraging(o):
		card.add_child(BookPanel.text(tr("FEED_THE_PIGS_SLOP_AND_THEY") % Balance.i("pigpen.pigs_per_truffle"), 17))
		var feed := hud.panel_button(tr("FEED_SLOP_COINS") % Balance.i("pigpen.slop_cost"))
		feed.disabled = pigs == 0 or Game.coins < Balance.i("pigpen.slop_cost")
		feed.pressed.connect(func() -> void: Game.pigpen.feed_slop(uid))
		card.add_child(feed)
	elif Game.pigpen.forage_seconds_left(o) > 0:
		card.add_child(
			BookPanel.text(tr("FORAGING_BACK_IN") + FarmGrid.format_duration(Game.pigpen.forage_seconds_left(o)), 18)
		)
	else:
		var dig := hud.panel_button(tr("COLLECT_TRUFFLES"))
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
		var b := hud.panel_button(Game.item_data(id)["name"])
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
		content.add_child(BookPanel.text(tr("FULLY_EXPANDED"), 18, BookPanel.SOFT))
		return
	var next := Game.building_def(o["id"]).size(Game.level_of(o) + 1)
	var next_name := str(next.get("name", tr("NEXT_SIZE")))
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 6)
	card.add_child(BookPanel.text(tr("EXPAND_TO_HOLDS") % [next_name, int(next["capacity"])], UiTheme.BODY))
	for m in need:
		var have := int(Game.parts.get(m, 0))
		var done := have >= int(need[m])
		card.add_child(BookPanel.text(tr("CHECK_DONE" if done else "CHECK_TODO") % (tr("OF") % [
			GameState.part_names[m], mini(have, int(need[m])), int(need[m])]), 18,
			UiTheme.color("done") if done else BookPanel.INK))
	var verdict := Game.buildings.can_expand(o)
	if not verdict.ok() and verdict.text != "":
		card.add_child(BookPanel.text(verdict.text, 16, UiTheme.color("price_short")))
	var up := hud.panel_button(tr("EXPAND"))
	up.disabled = not verdict.ok()
	up.pressed.connect(func() -> void: Game.land.upgrade_building(uid))
	card.add_child(up)
	add_buy_missing(card, need, func() -> void: Game.land.upgrade_building(uid))
	content.add_child(BookPanel.card_frame(card))
