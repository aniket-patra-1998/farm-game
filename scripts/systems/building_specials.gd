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


## Which baby a Dairy Farm or Horse Stable brings: a breed's own baby, likelier for the breeds it holds more of.
func _pick_baby(b: Dictionary, plain: String) -> String:
	var inside: Dictionary = b.get("inside", {})
	var total := 0
	for id in inside:
		var d := game.catalog.get_def(id)
		if d is AnimalDef and not (d as AnimalDef).is_stray_only() and not (d as AnimalDef).is_young():
			total += int(inside[id])
	if total == 0:
		return plain
	var pick := game.rng.randi_range(1, total)
	for id in inside:
		var d := game.catalog.get_def(id)
		if d is AnimalDef and not (d as AnimalDef).is_stray_only() and not (d as AnimalDef).is_young():
			pick -= int(inside[id])
			if pick <= 0:
				var baby := (d as AnimalDef).baby()
				return baby if baby != "" else plain
	return plain


## Extra results of collecting a building, as short popup texts.
func building_specials(b: Dictionary) -> Array[String]:
	var out: Array[String] = []
	match game.item_data(b["id"]).get("special", ""):
		"mystery_eggs":
			var colour := game.mystery.roll_mystery_egg(b)
			if colour != "":
				game.mystery.mystery_eggs[colour] = int(game.mystery.mystery_eggs.get(colour, 0)) + 1
				var egg_name: String = game.mystery.egg_data["colours"][colour]["name"]
				game.message.emit(tr("YOU_FOUND_A_OPEN_IT_FROM") % egg_name)
				out.append(egg_name + "!")
		"calves":
			if game.drops_enabled and game.rng.randf() < Balance.f("specials.fertilizer_chance"):
				game.fertilizer_bags += 1
				out.append(tr("FERTILIZER"))
			if game.has_inside(b, "bull") and game.drops_enabled and game.rng.randf() < Balance.f("specials.calf_chance"):
				var calf := _pick_baby(b, "calf")
				if game.place_somewhere(calf):
					game.message.emit(
						tr("A_WAS_BORN_RAISE_IT_IN") % game.item_data(calf)["name"].to_lower()
					)
					out.append("A %s!" % game.item_data(calf)["name"].to_lower())
		"foals":
			var with_stallion := game.has_inside(b, "stallion")
			if game.drops_enabled and with_stallion and game.rng.randf() < Balance.f("specials.foal_chance"):
				var foal := _pick_baby(b, "foal")
				if game.place_somewhere(foal):
					game.message.emit(
						tr("A_WAS_BORN_RAISE_IT_IN") % game.item_data(foal)["name"].to_lower()
					)
					out.append("A %s!" % game.item_data(foal)["name"].to_lower())
			if game.drops_enabled and game.rng.randf() < Balance.f("specials.stable_helper_chance"):
				game.farmhands += 1
				out.append(tr("FARMHAND"))
			if game.drops_enabled and game.rng.randf() < Balance.f("specials.stable_helper_chance"):
				game.arborists += 1
				out.append(tr("ARBORIST"))
			if game.drops_enabled and with_stallion and game.rng.randf() < Balance.f("specials.stable_xp_chance"):
				game.add_xp(Balance.i("specials.stable_xp"))
				out.append(tr("XP") % Balance.i("specials.stable_xp"))
		"nursery":
			out.append_array(_grow_babies(b))
		"lambs":
			if game.has_inside(b, "ram") and game.drops_enabled and game.rng.randf() < Balance.f("specials.lamb_chance"):
				if game.place_somewhere("lamb"):
					game.message.emit(tr("A_LAMB_WAS_BORN_RAISE_IT"))
					out.append(tr("A_LAMB"))
		"truffles":
			if game.has_inside(b, "boar") and game.drops_enabled and game.rng.randf() < Balance.f("specials.piglet_chance"):
				if game.place_somewhere("piglet"):
					game.message.emit(tr("A_PIGLET_WAS_BORN_RAISE_IT"))
					out.append(tr("A_PIGLET"))
		"beehive":
			if game.drops_enabled and game.rng.randf() < Balance.f("specials.fertilize_all_chance"):
				game.fertilize_alls += 1
				game.message.emit(tr("THE_BEES_LEFT_A_FERTILIZE_ALL"))
				out.append(tr("FERTILIZE_ALL_2"))
		"saplings":
			out.append_array(game.nurture.from_orchard(b))
		"blooms":
			out.append_array(game.nurture.from_garden(b))
	# Any home with animals in it: a Mystery Baby now and then, and Animal Feed (NurtureSystem).
	if not str(game.item_data(b["id"]).get("special", "")) in ["saplings", "blooms"]:
		out.append_array(game.nurture.from_home(b))
	if not out.is_empty():
		game.inventory_changed.emit()
	return out


## Nursery Barn: each baby grows a day per collection; grown ones move out as adults.
func _grow_babies(nursery: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var it := game.item_data(nursery["id"])
	var grow_days := int(it.get("grow_days", 4))
	var into: Dictionary = it.get("grows_into", {})
	var still: Array = []
	var inside: Dictionary = nursery["inside"]
	for baby in nursery.get("growing", []):
		baby[1] = int(baby[1]) + 1
		if int(baby[1]) >= grow_days and game.place_somewhere(into.get(baby[0], baby[0])):
			inside[baby[0]] = int(inside.get(baby[0], 0)) - 1
			if int(inside[baby[0]]) <= 0:
				inside.erase(baby[0])
			game.add_xp(Balance.i("specials.nursery_spare_xp"))
			game.ribbons.bump("babies_raised", 1)
			var adult_name: String = game.item_data(into.get(baby[0], baby[0]))["name"]
			game.message.emit(
				tr("YOUR_GREW_UP_INTO_A") % [game.item_data(baby[0])["name"].to_lower(), adult_name.to_lower()]
			)
			out.append(tr("A_GREW_UP") % adult_name.to_lower())
		else:
			still.append(baby)
	nursery["growing"] = still
	return out


