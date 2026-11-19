class_name BuildingSpecials
extends GameSystem
## What buildings do when collected: babies, helpers, fertilizer, rare saplings, grow-ups.
## Part of the game state: reached as `Game.specials`; shared state is on `game`.


# Building specials, the FarmVille way.



func _init(owner: GameState) -> void:
	super(owner)


## FarmVille's Baby Turkey and Ugly Duckling grow up after their first collection.
func grows_into(item_id: String) -> String:
	var d := game.catalog.get_def(item_id)
	return (d as AnimalDef).grows_into() if d is AnimalDef else ""


## What a young animal grows up into: its own (Baby Turkey, Ugly Duckling) or the Nursery Barn's map
## (calves, foals, lambs, piglets); "" for an adult.
func adult_of(item_id: String) -> String:
	var own := grows_into(item_id)
	if own != "":
		return own
	for id in game.item_order:
		var it: Dictionary = game.items[id]
		if str(it.get("special", "")) == "nursery":
			return str(it.get("grows_into", {}).get(item_id, ""))
	return ""


func grow_up_inside(b: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var inside: Dictionary = b.get("inside", {})
	for id in inside.keys():
		var adult := grows_into(id)
		if adult == "" or int(inside[id]) <= 0:
			continue
		inside[adult] = int(inside.get(adult, 0)) + int(inside[id])
		out.append(tr("GREW_UP_2") % [int(inside[id]), game.item_data(id)["name"]])
		inside.erase(id)
	return out


## Which baby a Dairy Farm or Horse Stable brings: a breed's own baby, likelier for the breeds it holds more of
## (never a limited one's: that comes only by its own chance, `_welcome_baby`).
func _pick_baby(b: Dictionary, plain: String) -> String:
	var inside := game.limited.ordinary(b)
	var breeds: Array[AnimalDef] = []
	var counts := []
	for id in inside:
		var d := game.catalog.get_def(id)
		if d is AnimalDef and not (d as AnimalDef).is_stray_only() and not (d as AnimalDef).is_young():
			breeds.append(d as AnimalDef)
			counts.append(int(inside[id]))
	var k := RollSystem.weighted_index(game.rng, counts)
	if k < 0:
		return plain
	var baby := breeds[k].baby()
	return baby if baby != "" else plain


## A baby born at a home: said on the home as a find. A breed's own baby (a Pink Calf, not the plain one) is rare.
func _born(b: Dictionary, baby: String) -> void:
	var plain := baby in ["calf", "foal", "lamb", "piglet", "kid"]
	var rarity := "legendary" if game.limited.is_limited(baby) else ("uncommon" if plain else "rare")   # not-ui
	game.found_on.emit(int(b["uid"]), tr("BORN") % str(game.item_data(baby)["name"]), rarity)


## A baby born at home `b`: it goes to the Barn, or the inbox when the Barn is full (`BarnStorage.welcome`),
## never into the home it was born in nor onto the farm; said, and shown on the home as a find. Now and then it
## is the baby of a limited animal living there (LimitedSystem.born_at).
func _welcome_baby(b: Dictionary, baby: String) -> void:
	var limited := game.limited.born_at(b)
	if limited != "":
		baby = limited
	var went := game.storage.welcome(baby)
	game.message.emit(game.storage.welcome_words("A_WAS_BORN", baby, went))
	_born(b, baby)


## Extra results of collecting a building, as short popup texts.
func building_specials(b: Dictionary) -> Array[String]:
	var out: Array[String] = []
	match game.special_of(b):
		"mystery_eggs":
			var colour := game.mystery.find_egg(b)
			if colour != "":
				var egg_name: String = game.mystery.egg_data["colours"][colour]["name"]
				game.message.emit(tr("YOU_FOUND_A_OPEN_IT_FROM") % egg_name)
				game.found_on.emit(int(b["uid"]), tr("FOUND") + egg_name, "rare")
		"calves":
			if game.drops_enabled and game.rolls.roll("fertilizer", Balance.f("specials.fertilizer_chance")):
				game.fertilizer_bags += 1
				out.append(tr("FERTILIZER"))
			if game.has_inside(b, "bull") and game.drops_enabled and \
					game.rolls.roll("calf", Balance.f("specials.calf_chance")):
				_welcome_baby(b, _pick_baby(b, "calf"))
		"foals":
			var with_stallion := game.has_inside(b, "stallion")
			if game.drops_enabled and with_stallion and game.rolls.roll("foal", Balance.f("specials.foal_chance")):
				_welcome_baby(b, _pick_baby(b, "foal"))
			if game.drops_enabled and game.rolls.roll("stable_farmhand", Balance.f("specials.stable_helper_chance")):
				game.farmhands += 1
				out.append(tr("FARMHAND"))
			if game.drops_enabled and game.rolls.roll("stable_arborist", Balance.f("specials.stable_helper_chance")):
				game.arborists += 1
				out.append(tr("ARBORIST"))
			if game.drops_enabled and with_stallion and \
					game.rolls.roll("stable_xp", Balance.f("specials.stable_xp_chance")):
				game.add_xp(Balance.i("specials.stable_xp"))
				out.append(tr("XP") % Balance.i("specials.stable_xp"))
		"nursery":
			pass   # (babies grow on Animal Feed in the trough, RaisingSystem; the harvest gives feed: from_home)
		"lambs":
			if game.has_inside(b, "ram") and game.drops_enabled and \
					game.rolls.roll("lamb", Balance.f("specials.lamb_chance")):
				_welcome_baby(b, "lamb")
		"truffles":
			if game.has_inside(b, "boar") and game.drops_enabled and \
					game.rolls.roll("piglet", Balance.f("specials.piglet_chance")):
				_welcome_baby(b, "piglet")
		"beehive":
			if game.drops_enabled and game.rolls.roll("fertilize_all", Balance.f("specials.fertilize_all_chance")):
				game.fertilize_alls += 1
				game.message.emit(tr("THE_BEES_LEFT_A_FERTILIZE_ALL"))
				out.append(tr("FERTILIZE_ALL_2"))
		"saplings":
			out.append_array(game.nurture.from_orchard(b))
		"blooms":
			out.append_array(game.nurture.from_garden(b))
	# Any home with animals in it: a Mystery Baby now and then, and Animal Feed (NurtureSystem).
	if not game.special_of(b) in ["saplings", "blooms"]:
		out.append_array(game.nurture.from_home(b))
	if not out.is_empty():
		game.inventory_changed.emit()
	return out


