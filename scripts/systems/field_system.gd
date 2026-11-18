class_name FieldSystem
extends GameSystem
## The crop fields: plowing, planting, fertilizing and harvesting a plot, and what a plot is at this moment
## (grass, plowed, growing, ripe, withered). Part of the game state: reached as `Game.field`. The plots
## themselves, the farm's size and the placed objects stay on `game`; the farmer queues this work
## (PlayerSystem) and does it by calling in here.

const CENSUS_FAR := 30 * 86400   # seconds: "nothing will ripen or wither" is this far off (ripe_census)


func _init(owner: GameState) -> void:
	super(owner)


## How many open plots are ripe now ("count"), and when that number next changes by itself ("next", unix seconds:
## a crop ripens or withers; far off when none will). For a count that is kept and only made again when it can
## have changed (the Next ready button), instead of asking every tile every time.
func ripe_census() -> Dictionary:
	var now := game.now()
	var count := 0
	var next := now + CENSUS_FAR
	for i in game.plots.size():
		var p: Dictionary = game.plots[i]
		if p.get("state") != "planted":
			continue
		var crop: Dictionary = game.crops[p["crop"]]
		var ripe_at := int(p["planted_at"]) + int(crop["grow_seconds"])
		var wither_at := ripe_at + window_of(p, crop)
		if now < ripe_at:
			next = mini(next, ripe_at)
		elif now < wither_at and not game.is_occupied(i):
			count += 1
			next = mini(next, wither_at)
	return {"count": count, "next": next}


func phase(i: int) -> GameState.Phase:
	var p: Dictionary = game.plots[i]
	match p.get("state", "grass"):
		"plowed":
			return GameState.Phase.PLOWED
		"planted":
			var crop: Dictionary = game.crops[p["crop"]]
			var age := game.now() - int(p["planted_at"])
			var grow := int(crop["grow_seconds"])
			if age < grow:
				return GameState.Phase.GROWING
			var window := window_of(p, crop)
			if age < grow + window:
				return GameState.Phase.RIPE
			return GameState.Phase.WITHERED
	return GameState.Phase.GRASS


## When plot `i`'s phase next changes on its own (growing to ripe, ripe to withered), or -1 when it won't.
func next_phase_at(i: int) -> int:
	var p: Dictionary = game.plots[i]
	if p.get("state") != "planted":
		return -1
	var crop: Dictionary = game.crops[p["crop"]]
	var ripe := int(p["planted_at"]) + int(crop["grow_seconds"])
	if game.now() < ripe:
		return ripe
	var window := window_of(p, crop)
	return ripe + window if game.now() < ripe + window else -1


## How long plot `p`'s crop stays ripe before it withers: the crop's own time, longer for pollinated seeds,
## shorter for a crop planted off-season (`off`, set when it was planted: Season, Balance `seasons.*`).
func window_of(p: Dictionary, crop: Dictionary) -> int:
	var window := ripe_window(crop) * (Balance.i("economy.pollinated_ripe_mult") if p.get("pol", false) else 1)
	if p.get("off", false):
		window = maxi(int(window * Balance.f("seasons.off_window_mult")), 1)
	return window


func ripe_window(crop: Dictionary) -> int:
	return (game.catalog.get_def(crop["id"]) as CropDef).ripe_window()


## 0.0 just planted .. 1.0 ripe.
func growth(i: int) -> float:
	var p: Dictionary = game.plots[i]
	if p.get("state") != "planted":
		return 0.0
	var grow := float(game.crops[p["crop"]]["grow_seconds"])
	return clampf(float(game.now() - int(p["planted_at"])) / grow, 0.0, 1.0)


func seconds_until_ripe(i: int) -> int:
	var p: Dictionary = game.plots[i]
	if p.get("state") != "planted":
		return 0
	var grow := int(game.crops[p["crop"]]["grow_seconds"])
	return maxi(0, int(p["planted_at"]) + grow - game.now())


func crop_at(i: int) -> String:
	return game.plots[i].get("crop", "")


func plow(i: int) -> bool:
	var ph := phase(i)
	if ph != GameState.Phase.GRASS and ph != GameState.Phase.WITHERED:
		return false
	if game.is_occupied(i):
		return false
	if not game.spend(Balance.i("economy.plow_cost")):
		game.message.emit(tr("NOT_ENOUGH_COINS_TO_PLOW"))
		return false
	var old_crop := str(game.plots[i].get("crop", ""))
	game.plots[i] = {"state": "plowed"}
	game.add_xp(Balance.i("economy.plow_xp"))
	game.record("plow", "")
	game.vehicles.roll_fuel_find(i)
	game.collectibles.roll_collectible(
		game.collectibles.plow_collection(old_crop),
		Balance.f("economy.collectible_action_chance"),
		i
	)
	if game.coins < game.cheapest_seed_cost():
		game.message.emit(tr("CAREFUL_KEEP_SOME_COINS_FOR_SEEDS"))
	game.advance_tutorial(GameState.Tutorial.PLOW)
	game.plot_updated(i)
	game.check_rescue()
	return true


## FarmVille's delete tool: any plot back to grass, free; a crop on it (growing, ripe or withered) is lost,
## so the caller asks first. Nothing standing on it, and grass is already grass.
func can_clear_plot(i: int) -> bool:
	var in_bounds := game.on_farm(i)
	return in_bounds and phase(i) != GameState.Phase.GRASS and not game.is_occupied(i)


func clear_plot(i: int) -> bool:
	if not can_clear_plot(i):
		return false
	game.plots[i] = {"state": "grass"}
	game.record("clear_plot", "")
	game.plot_updated(i)
	return true


func plant(i: int, crop_id: String) -> bool:
	if phase(i) != GameState.Phase.PLOWED or not game.crops.has(crop_id):
		return false
	var crop: Dictionary = game.crops[crop_id]
	if not game.can_plant(crop_id):
		game.message.emit(tr("UNLOCKS_AT_LEVEL") % [crop["name"], int(crop["unlock_level"])])
		return false
	# Pollinated seeds are planted first, for free.
	var gift := game.goals.take_seed(crop_id)   # (Starter Seeds: a goal's gift, free)
	var use_pollinated := not gift and game.bees.take_pollinated_seed(crop_id)
	if not gift and not use_pollinated and not game.spend(int(crop["seed_cost"])):
		game.message.emit(tr("NOT_ENOUGH_COINS_FOR_SEEDS") % crop["name"])
		return false
	game.plots[i] = {"state": "planted", "crop": crop_id, "planted_at": game.now()}
	game.record("plant", crop_id)
	if game.off_season(crop_id):
		game.plots[i]["off"] = true   # planted out of its seasons: sells for more, withers sooner (kept with the plot)
	if use_pollinated:
		game.plots[i]["pol"] = true
	_hold_luck(i, crop_id, use_pollinated)
	game.collectibles.roll_collectible(game.collectibles.collection_of_crop.get(crop_id, {}),
		Balance.f("economy.collectible_action_chance"), i)
	game.advance_tutorial(GameState.Tutorial.PLANT)
	game.plot_updated(i)
	return true


## Decides, as a crop is planted, what its harvest will turn up, and keeps it with the plot (`held`): the drop
## (a golden harvest, a bird, a collectible...) and the finds (a gopher, a dog, a Queen Bee among flowers). So
## a ripe plot that holds something can glint before it is harvested (`held_rarity`): luck to look forward to,
## not a note after the fact. The luck is the same as before, only spent a crop's growing time earlier; a crop
## left to wither loses what it held. A plot planted before this (an old save) has no `held` and is rolled at
## its harvest, as it always was.
func _hold_luck(i: int, crop_id: String, pollinated: bool) -> void:
	if not game.drops_enabled:
		return
	var stars := game.mastery.stars(crop_id)
	var held := {}
	var drop := game.drops.decide_drop(crop_id, stars,
		Balance.i("economy.pollinated_super_mult") if pollinated else 1)
	if not drop.is_empty():
		held["drop"] = drop
	var finds := game.finds.decide("harvest", stars)
	if game.crops[crop_id].get("flower", false):
		finds.append_array(game.finds.decide("flower_harvest"))
	if not finds.is_empty():
		held["finds"] = finds
	game.plots[i]["held"] = held


## How rare what plot `i` holds is ("" when it holds nothing worth a glint): the rarest of its drop and its
## finds. Only a find glints (a golden harvest, a bird, a collectible, a creature); the small bonuses stay a
## surprise.
func held_rarity(i: int) -> String:
	var held: Variant = game.plots[i].get("held")
	if not held is Dictionary or (held as Dictionary).is_empty():
		return ""
	var best := game.finds.rarest(held.get("finds", []))
	var drop: Dictionary = held.get("drop", {})
	if HarvestDrops.glints(drop):
		var rarity := game.drops.rarity_of(drop)
		if best == "" or FindsSystem.RARITIES.find(rarity) > FindsSystem.RARITIES.find(best):
			best = rarity
	return best


func is_fertilized(i: int) -> bool:
	return game.plots[i].get("fert", false)


## Fertilizer goes on a planted crop that isn't ripe or withered yet.
func fertilize(i: int) -> bool:
	if phase(i) != GameState.Phase.GROWING or is_fertilized(i):
		return false
	if game.fertilizer_bags > 0:
		game.fertilizer_bags -= 1
		game.inventory_changed.emit()
	elif not game.spend(Balance.i("economy.fertilizer_cost")):
		game.message.emit(tr("NOT_ENOUGH_COINS_FOR_FERTILIZER"))
		return false
	game.plots[i]["fert"] = true
	game.record("fertilize", str(game.plots[i].get("crop", "")))
	game.collectibles.roll_collectible(
		game.collectibles.collection_of_crop.get(str(game.plots[i]["crop"]), {}),
		Balance.f("economy.collectible_action_chance"),
		i
	)
	game.plot_updated(i)
	return true


## Returns {"coins", "xp", "crop", "drop", "drop_text"} or {} if nothing was harvested.
## What a harvest of `crop_id` sells for before its drop: the price, raised by its mastery stars and by `bonus`
## (fertilizer, rain), times the off-season price when `off`. The seed shelf shows this, so it says what is paid.
func sells_for(crop_id: String, off: bool, bonus := 0.0) -> int:
	var mastery := Balance.f("economy.mastery_price_bonus") * game.mastery.stars(crop_id)
	return roundi(float(game.crops[crop_id]["sell_price"]) * (1.0 + mastery + bonus)
		* (Balance.f("seasons.off_price_mult") if off else 1.0))


## "drop" is "", "golden", "bird", "collectible", "super_harvest" or "bonus_xp".
func harvest(i: int) -> Dictionary:
	if phase(i) != GameState.Phase.RIPE:
		return {}
	var crop_id: String = game.plots[i]["crop"]
	var crop: Dictionary = game.crops[crop_id]
	var stars_before := game.mastery.stars(crop_id)
	var fertilized: bool = game.plots[i].get("fert", false)
	var bonus := Balance.f("economy.fertilizer_bonus") if fertilized else 0.0
	# The seasons (our own touch): rain while it grew watered it, and an off-season crop sells for more.
	var planted_at := int(game.plots[i]["planted_at"])
	var rained := game.rained_between(planted_at, planted_at + int(crop["grow_seconds"]))
	if rained:
		bonus += Balance.f("seasons.rain_bonus")
	var off: bool = game.plots[i].get("off", false)
	var earned := sells_for(crop_id, off, bonus)
	var gained := int(crop["xp"])

	var was_pollinated: bool = game.plots[i].get("pol", false)
	# What the plot held since it was planted (`_hold_luck`) is given now; a plot planted before luck was held
	# (an old save) is rolled here, as it always was.
	var held: Variant = game.plots[i].get("held")
	var drop: Dictionary = game.drops.give_drop(held.get("drop", {})) if held is Dictionary else game.drops.roll_drop(
		crop_id,
		stars_before,
		Balance.i("economy.pollinated_super_mult") if was_pollinated else 1
	)
	match drop.get("type", ""):
		"golden":
			earned *= Balance.i("economy.golden_coin_multiplier")
			gained += Balance.i("economy.golden_xp")
		"super_harvest":
			earned *= Balance.i("economy.super_harvest_multiplier")
		"bonus_xp":
			gained += Balance.i("economy.bonus_xp")

	game.plots[i] = {"state": "plowed"}
	game.add_coins(earned)
	game.rescued = false   # earned by farming: a later stuck farm may be rescued again
	game.add_xp(gained)
	game.record("harvest", crop_id)
	if drop.get("type", "") == "golden":
		game.record("golden_find", crop_id)
		game.message.emit(
			tr("GOLDEN_HARVEST_PAID_X_COINS") % [crop["name"], Balance.i("economy.golden_coin_multiplier")]
		)
	elif drop.get("type", "") == "collectible":
		game.message.emit(tr("YOU_FOUND_A_COLLECTION") % [drop["name"], drop["collection"]])
	elif drop.get("type", "") == "bird":
		game.message.emit(tr("A_LANDED_ON_YOUR_FARM_COLLECTION") % [drop["name"].to_lower(), drop["collection"]])
	var part := game.daily.roll_part()
	var bushel := game.crafting.roll_bushel(crop_id)
	var bunch := game.shed.roll_bunch(crop_id, i)
	var found: Array[Dictionary] = game.finds.give(held.get("finds", [])) if held is Dictionary \
		else game.finds.roll("harvest", stars_before)
	var rich: bool = drop.get("type", "") in ["golden", "super_harvest"] or was_pollinated
	var feed_found := game.feeds.roll_harvest(crop_id, stars_before, rich)
	var bee_news := ""
	if crop.get("flower", false):
		bee_news = game.bees.flower_harvest_bees(not held is Dictionary)
	# Every find is said where it was made, in its rarity's colours (FarmGrid's one burst for all finds).
	if not drop.is_empty():
		game.found.emit(i, str(drop["text"]), str(drop["rarity"]))
	for f: Dictionary in found:
		game.found.emit(i, tr("FOUND") + str(f["name"]), str(f["rarity"]))
	if bee_news != "":
		game.found.emit(i, bee_news, "rare" if bee_news == tr("A_QUEEN_BEE") else "uncommon")
	var seeds := game.bees.pollinate(crop_id) if fertilized else 0
	# A fertilized harvest counts double toward mastery (stars are awarded as they're reached).
	game.mastery.add(crop_id, 2 if fertilized else 1)
	if game.tutorial_step == GameState.Tutorial.HARVEST and not game.any_plot_in(GameState.Phase.RIPE):
		game.advance_tutorial(GameState.Tutorial.HARVEST)
	game.plot_updated(i)
	return {"coins": earned, "xp": gained, "crop": crop_id, "bee": bee_news,
		"pollinated": seeds, "drop": drop.get("type", ""), "drop_text": drop.get("text", ""), "part": part, "bushel": bushel,
		"bushels": (1 + game.mastery.stars(crop_id)) if bushel != "" else 0, "bunch": bunch, "found": found,
		"feed": feed_found, "feed_rich": rich, "rain": rained, "off": off}
