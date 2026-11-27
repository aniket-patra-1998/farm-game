extends TestSuite
## The landmarks (the prestige decorations: a balloon, a clock tower, a castle): where the Market sells them, how
## its Limited shelf is laid out round them, and what their models are made of.


func test_656_the_limited_shelf_opens_short_landmarks_then_a_card_a_kind() -> void:
	var market := HudMarket.new(null)
	var marks := market.landmarks()
	_eq(marks, ["hot_air_balloon", "clock_tower", "stone_castle"] as Array[String], "the landmarks, in catalog order")
	for id in marks:
		_check(not id in market.shelf_items("decor"), "%s is not among the decorations" % id)
		_eq(market.tab_for(id), market.tab_for("galaxy_cow"), "%s is on the Limited tab" % id)
		_check((Game.catalog.get_def(id) as DecorationDef).is_landmark(), "its catalog entry says so")
	_check(not (Game.catalog.get_def("bench") as DecorationDef).is_landmark(), "a bench is no landmark")
	# The shelf's front: a card for each kind, not every variety (owner, 27 Nov: "too clunky and messy").
	var kinds := market.limited_kinds("animal")
	var varieties := market.limited_section("animal")
	_check(kinds.size() >= 8 and kinds.size() * 3 <= varieties.size(),
		"a card a kind (%d), far fewer than their varieties (%d)" % [kinds.size(), varieties.size()])
	var seen := {}
	var under := 0
	for first in kinds:
		var plain := market._plain_kind(first)
		_check(not seen.has(plain), "one card for %s" % plain)
		seen[plain] = true
		_eq(market.limited_of_kind(plain)[0], first, "it wears its first variety's picture")
		under += market.limited_of_kind(plain).size()
	_eq(under, varieties.size(), "and every variety is under one of the cards")
	var cows := market.limited_of_kind("cow")
	_check("galaxy_cow" in cows and not "galaxy_apple_tree" in cows, "a kind's card opens only that kind's")
	var face := market.kind_face(cows[0])
	_eq(face["name"], Game.name_of("cow"), "the card is named for the plain kind")
	_check(str((face["badge"] as Array)[1]).contains(str(cows.size())), "and says how many kinds it has")
	_check(not market.limited_kinds("tree").is_empty(), "trees have their cards too")
	# Sent to a limited thing (a search result, a goal), the shelf opens on its kind.
	market.tab_for("galaxy_cow")
	_eq(market._limited_kind, "cow", "the shelf opens on the kind of the thing asked for")


func test_657_a_landmark_is_built_grand_and_its_parts_live() -> void:
	_eq(Game.footprint("stone_castle"), Vector2i(5, 5), "the castle's land takes its moat")
	_eq(Game.footprint("clock_tower"), Vector2i(3, 3), "the tower stands on a square")
	var tower := _built("clock_tower")
	var faces := tower.find_children(DecorMotion.CLOCK + "_*", "Node3D", true, false)
	_eq(faces.size(), 4, "a clock face to each side")
	var clock: ClockHands = null
	var hands: Array[Node3D] = []
	for c in faces[0].get_children():
		if c is ClockHands:
			clock = c
		elif c is Node3D:
			hands.append(c as Node3D)
	_check(clock != null and hands.size() == 2, "each with two hands and what turns them")
	if clock != null and hands.size() == 2:
		clock.show_hour(15.5)
		_check(absf(hands[0].rotation.z + TAU * 3.5 / ClockHands.HOURS_ROUND) < 0.001, "the hour hand at half past three")
		_check(absf(hands[1].rotation.z + PI) < 0.001, "the minute hand at the half hour")
		clock.show_hour(0.0)
		_check(absf(hands[0].rotation.z) < 0.001 and absf(hands[1].rotation.z) < 0.001, "both up at midnight")
	_check(_tall(tower) > 4.5, "it towers (%.1f tiles)" % _tall(tower))
	tower.free()
	var balloon := _built("hot_air_balloon")
	var craft := balloon.find_children(DecorMotion.SWAY + "_*", "Node3D", true, false)
	_eq(craft.size(), 1, "the balloon and its basket are one floating part")
	_check(craft.size() == 1 and craft[0].get_children().any(func(c: Node) -> bool: return c is Swayer),
		"that rides the air")
	balloon.free()
	var castle := _built("stone_castle")
	var wide := _box(castle).size.x
	_check(wide > 4.6, "the castle's moat reaches the edge of its land (%.1f tiles)" % wide)
	castle.free()
	# A landmark's parts move by script, so it is drawn as a model of its own, not in a batch.
	_check(Objects3D.stands_alone("clock_tower") and not Objects3D.stands_alone("bench"),
		"a landmark stands alone; a bench is batched")
	# Fine stonework is a surface of its own.
	var fine := ModelKit.surface(PrestigeModel.STONE, "stone", 0.35, PrestigeModel.FINE)
	_check(fine != ModelKit.surface(PrestigeModel.STONE, "stone", 0.35), "fine courses are their own surface")
	_eq(fine.get_shader_parameter("scale"), PrestigeModel.FINE, "drawn at their size")


## The landmark `id` as the farm builds it.
func _built(id: String) -> Node3D:
	return DecorModel.build(Game.item_data(id), Game.footprint(id), {"uid": 1, "id": id, "row": 3, "col": 3})


## How tall a built model stands, in tiles.
func _tall(model: Node3D) -> float:
	return _box(model).end.y


## The box round everything a built model draws, in the model's own space.
func _box(model: Node3D) -> AABB:
	var all := AABB()
	var any := false
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var at := mi.transform
		var up: Node = mi.get_parent()
		while up != null and up != model and up is Node3D:
			at = (up as Node3D).transform * at
			up = up.get_parent()
		var box := at * mi.get_aabb()
		all = box if not any else all.merge(box)
		any = true
	return all
