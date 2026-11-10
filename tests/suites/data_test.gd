extends TestSuite
## The data files and the catalog: every item well formed, every string in the strings file.


func test_17_data_files_are_consistent() -> void:
	var g := _farm()
	_check(g.crops.size() >= 12, "crops loaded")
	_check(g.items.size() >= 16, "items loaded")
	for coll in g.collectibles.collections:
		_eq(coll["items"].size(), 5, "%s has 5 items" % coll["name"])
		for crop_id in coll.get("crops", []):
			_check(g.crops.has(crop_id), "%s lists a real crop (%s)" % [coll["name"], crop_id])
	for id in g.items:
		var it: Dictionary = g.items[id]
		if it["kind"] == "building":
			var def := g.building_def(id)
			for k in range(2, def.max_level() + 1):
				_check(not def.size_materials(k).is_empty(), "%s says what growing to size %d costs" % [id, k])
				for m in def.size_materials(k):
					_check(GameState.part_ids.has(m), "%s grows with a real material (%s)" % [id, m])
			for m in it.get("build_materials", {}):
				_check(GameState.part_ids.has(m), "%s is built with a real material (%s)" % [id, m])
			for held in it.get("holds", []) + it.get("one_each", []):
				_check(g.items.has(held), "%s holds a real item (%s)" % [id, held])
	var last := GameState.START_SIZE
	for step in g.land.expansion_steps:
		_check(int(step["size"]) > last, "expansion sizes grow")
		last = int(step["size"])
	_eq(last, GameState.MAX_SIZE, "last expansion reaches the max size")
	_done(g)






func test_18_drops_are_off_in_exact_value_tests() -> void:
	var g := _farm(false)
	var i := _free(g)
	for k in 50:
		var r := _grow_and_harvest(g, i, "strawberries")
		_eq(r["drop"], "", "no drops when disabled")
		if r["drop"] != "":
			break
	_done(g)






func test_70_catalog_loads_with_no_problems() -> void:
	var g := _farm()
	_eq(g.catalog.errors, [], "every catalog entry passes its class's checks")
	_check(g.catalog.order.size() >= 150, "the catalog holds the whole game (%d items)" % g.catalog.order.size())
	_check(g.catalog.families.size() >= 70, "items are grouped into families (%d)" % g.catalog.families.size())
	_check(g.catalog.planned.size() > 0, "planned FarmVille items are catalogued")
	for id in g.catalog.planned:
		_check(not g.items.has(id) and not g.crops.has(id), "planned %s isn't loaded into the game" % id)
	# Every in-game item has the right class.
	var expect := {"crop": CropDef, "tree": TreeDef, "animal": AnimalDef, "building": BuildingDef, "barn": BarnDef,
		"vehicle": VehicleDef, "decor": DecorationDef, "material": MaterialDef}
	for id in g.catalog.order:
		var d := g.catalog.get_def(id)
		if expect.has(d.kind):
			_check(is_instance_of(d, expect[d.kind]), "%s is a %s" % [id, d.kind])
	_eq(g.catalog.get_def("cow").data["family"], "cow", "the cow is in the Cows family")
	_eq(g.catalog.get_def("bull").data["family"], "cow", "so is the bull")
	_eq(GameState.part_ids.size(), g.catalog.of_kind("material").size(), "materials come from the catalog")
	_check(GameState.basic_parts == ["bricks", "nails", "boards"], "the basic materials")
	_done(g)






func test_71_defaults_stack_and_classes_add_rules() -> void:
	var g := _farm()
	var c: Catalog = g.catalog
	# A new decoration needs only an id, a name, a price and a shape; the rest comes from defaults.
	var entry := c._build(
		"Decoration",
		{"unlock_level": 1},
		{},
		{"id": "test_gnome", "name": "Test Gnome", "cost": 300, "shape": "gnome"}
	)
	_eq(c._check_types("Decoration", entry), [], "a minimal decoration is valid")
	var d := DecorationDef.new()
	d.setup(entry)
	_eq(d.kind, "decor", "its kind comes from its class")
	_eq(d.footprint(), Vector2i(1, 1), "1x1 by default")
	_eq(d.buy_xp(), 5, "decorations give at least 5 XP (Decoration overrides Item)")
	_eq(d.sell_value(), 15, "sells for 5% (from Placeable)")
	# Family defaults sit between the file's and the entry's.
	var stacked := c._build(
		"Animal",
		{"cycle_seconds": 86400},
		{"product": "Milk", "cycle_seconds": 172800},
		{"id": "t", "name": "T", "payout": 5}
	)
	_eq(int(stacked["cycle_seconds"]), 172800, "family defaults beat file defaults")
	_eq(stacked["product"], "Milk", "variants inherit the family's product")
	# Mistakes are named.
	var bad := c._check_types(
		"Animal",
		{"id": "oops", "name": "Oops", "cycle_seconds": "daily", "payot": 5, "kind": "animal"}
	)
	_check(bad.any(func(e): return e.contains("cycle_seconds should be a number")), "a wrong type is reported")
	_check(bad.any(func(e): return e.contains("unknown field payot")), "a misspelt field is reported")
	# Class rules catch bad references.
	var tree := TreeDef.new()
	tree.setup(
		c._build("Tree", {}, {}, {"id": "odd_tree", "name": "Odd", "cycle_seconds": 100, "rare_sapling": "apple_tree"})
	)
	_check(tree.validate(c).any(func(e): return e.contains("doesn't link back")), "a rare variety must link both ways")
	var b := BuildingDef.new()
	b.setup(
		c._build(
			"Building",
			{},
			{},
			{"id": "odd_pen", "name": "Odd", "cost": 5, "holds": ["unicorn"], "limit": 0,
				"sizes": [{"capacity": 10, "materials": {"boards": 1}}, {"capacity": 5}]}
		)
	)
	var berr := b.validate(c)
	_check(berr.any(func(e): return e.contains("more than the last")), "sizes must grow")
	_check(berr.any(func(e): return e.contains("unknown item unicorn")), "it can only hold real items")
	_check(berr.any(func(e): return e.contains("first size can't cost")), "the first size is bought, not built up to")
	_check(berr.any(func(e): return e.contains("materials to reach it")), "every size up says what it takes")
	_check(berr.any(func(e): return e.contains("limit must be at least 1")), "a building can be had at least once")
	_check(c._sizes_problem([{"capacity": 1, "colour": "red"}]).contains("unknown key"), "a size has only known keys")
	_check(c._sizes_problem([]) != "", "a building has at least one size")
	_done(g)






func test_73_tool_scripts_compile() -> void:
	# The CI tools (reference and sprite renderers, previews) don't run in the game, so check they compile here.
	for path in [
		"res://tools/render_refs.gd",
		"res://tools/render_sprites.gd",
		"res://tools/style_preview.gd",
		"res://tests/shots.gd"
	]:
		var script := load(path) as GDScript
		_check(script != null and script.can_instantiate(), "%s compiles" % path)






func test_89_player_text_comes_from_the_strings_file() -> void:
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	_check(f != null, "locale/strings.csv is there")
	if f == null:
		return
	var header := f.get_csv_line()
	_eq(Array(header), ["keys", "en"], "keys, then English")
	var rows := 0
	var wrong: Array[String] = []
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 2 or row[0] == "":
			continue
		rows += 1
		if tr(row[0]) != row[1]:
			wrong.append(row[0])
	_check(rows > 300, "the strings file has the game's text (%d keys)" % rows)
	_eq(wrong.size(), 0, "every key reads back as its English text %s" % [wrong])
	var g := _farm(true)
	g.tutorial_step = GameState.Tutorial.PLOW
	_check(g.tutorial_text().begins_with("Choose Plow"), "tutorial hints are translated, not shown as keys")
	_done(g)
