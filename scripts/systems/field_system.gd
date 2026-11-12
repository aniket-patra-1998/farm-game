class_name FieldSystem
extends GameSystem
## The crop fields: plowing, planting, fertilizing and harvesting a plot, and what a plot is at this moment
## (grass, plowed, growing, ripe, withered). Part of the game state: reached as `Game.field`. The plots
## themselves, the farm's size and the placed objects stay on `game`; the farmer queues this work
## (PlayerSystem) and does it by calling in here.


func _init(owner: GameState) -> void:
	super(owner)


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
			var window := ripe_window(crop) * (Balance.i("economy.pollinated_ripe_mult") if p.get("pol", false) else 1)
			if age < grow + window:
				return GameState.Phase.RIPE
			return GameState.Phase.WITHERED
	return GameState.Phase.GRASS


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
	game.ribbons.bump("plowed", 1)
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
	var in_bounds := game.in_farm(i / GameState.MAX_SIZE, i % GameState.MAX_SIZE)
	return in_bounds and phase(i) != GameState.Phase.GRASS and not game.is_occupied(i)


func clear_plot(i: int) -> bool:
	if not can_clear_plot(i):
		return false
	game.plots[i] = {"state": "grass"}
	game.ribbons.bump("plots_cleared", 1)
	game.plot_updated(i)
	return true


func plant(i: int, crop_id: String) -> bool:
	if phase(i) != GameState.Phase.PLOWED or not game.crops.has(crop_id):
		return false
	var crop: Dictionary = game.crops[crop_id]
	if game.level() < int(crop["unlock_level"]):
		game.message.emit(tr("UNLOCKS_AT_LEVEL") % [crop["name"], int(crop["unlock_level"])])
		return false
	# Pollinated seeds are planted first, for free.
	var use_pollinated := game.bees.take_pollinated_seed(crop_id)
	if not use_pollinated and not game.spend(int(crop["seed_cost"])):
		game.message.emit(tr("NOT_ENOUGH_COINS_FOR_SEEDS") % crop["name"])
		return false
	game.plots[i] = {"state": "planted", "crop": crop_id, "planted_at": game.now()}
	if use_pollinated:
		game.plots[i]["pol"] = true
	game.collectibles.roll_collectible(game.collectibles.collection_of_crop.get(crop_id, {}),
		Balance.f("economy.collectible_action_chance"), i)
	game.advance_tutorial(GameState.Tutorial.PLANT)
	game.plot_updated(i)
	return true


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
	game.ribbons.bump("fertilized", 1)
	game.collectibles.roll_collectible(
		game.collectibles.collection_of_crop.get(str(game.plots[i]["crop"]), {}),
		Balance.f("economy.collectible_action_chance"),
		i
	)
	game.plot_updated(i)
	return true


## Returns {"coins", "xp", "crop", "drop", "drop_text"} or {} if nothing was harvested.
## "drop" is "", "golden", "bird", "collectible", "super_harvest" or "bonus_xp".
func harvest(i: int) -> Dictionary:
	if phase(i) != GameState.Phase.RIPE:
		return {}
	var crop_id: String = game.plots[i]["crop"]
	var crop: Dictionary = game.crops[crop_id]
	var stars_before := game.mastery.stars(crop_id)
	var fertilized: bool = game.plots[i].get("fert", false)
	var bonus := Balance.f("economy.mastery_price_bonus") * stars_before + (
		Balance.f("economy.fertilizer_bonus") if fertilized else 0.0
	)
	var earned := int(round(float(crop["sell_price"]) * (1.0 + bonus)))
	var gained := int(crop["xp"])

	var was_pollinated: bool = game.plots[i].get("pol", false)
	var drop := game.drops.roll_drop(
		crop_id,
		stars_before,
		Balance.i("economy.pollinated_super_mult") if was_pollinated else 1
	)
	match drop.get("type", ""):
		"golden":
			earned *= Balance.i("economy.golden_coin_multiplier")
			gained += Balance.i("economy.golden_xp")
		"super_harvest":
			earned *= 2
		"bonus_xp":
			gained += Balance.i("economy.bonus_xp")

	game.plots[i] = {"state": "plowed"}
	game.add_coins(earned)
	game.add_xp(gained)
	game.ribbons.bump("harvests", 1)
	if drop.get("type", "") == "golden":
		game.ribbons.bump("golden_finds", 1)
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
	var found := game.finds.roll("harvest", stars_before)
	var rich: bool = drop.get("type", "") in ["golden", "super_harvest"] or was_pollinated
	var feed_found := game.feeds.roll_harvest(crop_id, stars_before, rich)
	var bee_news := ""
	if crop.get("flower", false):
		bee_news = game.bees.flower_harvest_bees()
	var seeds := game.bees.pollinate(crop_id) if fertilized else 0
	# A fertilized harvest counts double toward mastery (stars are awarded as they're reached).
	game.mastery.add(crop_id, 2 if fertilized else 1)
	if game.tutorial_step == GameState.Tutorial.HARVEST and not game.any_plot_in(GameState.Phase.RIPE):
		game.advance_tutorial(GameState.Tutorial.HARVEST)
	game.plot_updated(i)
	return {"coins": earned, "xp": gained, "crop": crop_id, "bee": bee_news,
		"pollinated": seeds, "drop": drop.get("type", ""), "drop_text": drop.get("text", ""), "part": part, "bushel": bushel,
		"bushels": (1 + game.mastery.stars(crop_id)) if bushel != "" else 0, "bunch": bunch, "found": found,
		"feed": feed_found, "feed_rich": rich}
