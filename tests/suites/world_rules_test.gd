extends TestSuite
## The world's rules (docs/WORLD.md; owner, 25 Nov): every thing of a kind answers the weather, the night and its
## own weight the same way, through values the whole farm shares, never piece by piece.

const RAIN := "global uniform float rain"
const WIND := "global uniform float wind"
const DARK := "global uniform float dark"

const FINISH := "res://shaders/finish.gdshaderinc"
const HOMES: Array[String] = ["beehive", "chicken_coop", "rabbit_hutch", "cow_shed", "sheep_pen", "goat_pen",
	"horse_stable", "pig_pen"]
const APART := 0.12       # how far apart two homes' roof colours are at least (as RGB, each 0 to 1)
const STOREY := 0.2       # how much taller a home's lead stands at its biggest, at least (tiles)
const LONG_HOME := 2.5   # how many times longer than deep a home known for its length may be (a hutch, a stable)


func test_629_an_open_fire_answers_the_rain_and_the_wind() -> void:
	var g := _farm()
	var fire := DecorModel.build(g.item_data("bonfire"), g.footprint("bonfire"), {"id": "bonfire", "uid": 1})
	var flames := _with_shader(fire, "flame3d")
	_check(flames.size() >= 2, "the bonfire burns with several flames")
	for m in flames:
		_eq(_number(m, "sheltered"), 0.0, "each open to the sky: the rain reaches it")
	var flame := load(DecorMotion.FLAME_SHADER) as Shader
	_check(flame.code.contains(RAIN) and flame.code.contains(WIND), "a flame reads the farm's own rain and wind")
	var answers: Array[float] = []
	for m in _with_shader(fire, "spray3d"):
		answers.append(_number(m, "weather"))
	_check(answers.has(DecorMotion.EMBERS_DIE), "its embers stop flying in the rain")
	_check(answers.has(DecorMotion.STEAM_IN_RAIN), "and steam hisses off it while the rain puts it out")
	var coals := _with_shader(fire, "lamp3d")
	_check(coals.size() == 1 and _number(coals[0], "fire") == 1.0,
		"its bed of coals glows as a fire's does, dulled by rain")
	fire.free()


func test_630_smoke_answers_the_weather_and_water_does_not() -> void:
	_eq(DecorMotion.SMOKE.get("weather"), DecorMotion.SMOKE_THINS, "smoke is thinned and beaten down by rain")
	_eq(DecorMotion.EFFECTS["smoke"], DecorMotion.SMOKE, "which every chimney's smoke is (a file's part or a built one)")
	for still: Dictionary in [DecorMotion.JET, DecorMotion.CASCADE, DecorMotion.POUR, DecorMotion.GRAIN_FALL,
			DecorMotion.STEAM, DecorMotion.SPARKLE]:
		_check(not still.has("weather"), "a fountain, a pour and a warm pool's steam go on as they were")
	var g := _farm()
	var house := DecorModel.build(g.item_data("farmhouse"), g.footprint("farmhouse"), {"id": "farmhouse", "uid": 1})
	var smokes := _with_shader(house, "spray3d")
	_check(smokes.size() == 1 and _number(smokes[0], "weather") == DecorMotion.SMOKE_THINS,
		"the farmhouse's chimney smoke answers the weather")
	house.free()
	var spray := load(DecorMotion.SPRAY_SHADER) as Shader
	_check(spray.code.contains(RAIN) and spray.code.contains(WIND), "a spray reads the farm's own rain and wind")


func test_631_a_lamp_is_lit_as_night_falls() -> void:
	var g := _farm()
	var post := DecorModel.build(g.item_data("lamp_post"), g.footprint("lamp_post"), {"id": "lamp_post", "uid": 1})
	var lights := _with_shader(post, "lamp3d")
	_check(lights.size() == 1 and _number(lights[0], "fire") == 0.0, "the lamp post's light is a lamp's")
	_check((lights[0].shader as Shader).code.contains(DARK), "lit by how dark the farm is, not always on")
	_check(lights[0] == DecorModel._glow(Color(lights[0].get_shader_parameter("colour"))),
		"every lamp of a colour shares one material (a draw for them all)")
	post.free()


func test_632_a_things_shade_on_the_ground_reads_at_night() -> void:
	var shade := load("res://shaders/contact3d.gdshader") as Shader
	_check(shade.code.contains(DARK),
		"the shade under a thing is drawn stronger at night, when no cast shadow holds it down")
	var batch := ContactShades.new()
	_eq((batch.material_override as ShaderMaterial).shader, shade, "every animal's shade is that one")
	batch.free()


func test_633_animals_are_sized_for_the_farm_and_smaller_in_a_yard() -> void:
	var g := _farm()
	var cow := ScaleGuide.animal_scale("cow")
	_check(cow < 1.0 and cow > 0.7, "an animal at large is drawn a little smaller than its file (%.2f)" % cow)
	_check(ScaleGuide.animal_scale("bee") < cow, "a bee much smaller: a speck by its hive, not a rabbit's size")
	var yard := ScaleGuide.yard_scale("cow")
	_check(yard < 0.8 and yard > 0.5,
		"in a yard an animal is drawn clearly smaller again (%.2f of its size at large)" % yard)
	var made := Animal3D.file_stride("cow")
	var at_large := Animal3D.create(g.item_data("cow"), null, Vector3.ZERO)
	var at_home := Animal3D.create(g.item_data("cow"), null, Vector3.ZERO, yard)
	_check(is_equal_approx(at_large.stride(), made * cow), "its stride is its size's: its feet still grip the ground")
	_check(is_equal_approx(at_home.stride(), made * cow * yard), "in a yard too")
	at_large.free()
	at_home.free()


func test_634_an_animal_shakes_the_rain_off_when_it_stops() -> void:
	var rain_was := AnimalBehaviour.rain
	var night_was := AnimalBehaviour.night
	AnimalBehaviour.night = false
	var mind := AnimalBehaviour.new(AnimalRig.of(Game.item_data("cow")), 7, Vector2(14, 7))
	_check(not mind.shakes, "a cow's coat has no shake of its own")
	AnimalBehaviour.rain = 1.0
	mind.update(0.1)
	_eq(mind.pose.shake, 0.0, "in the rain it stands and bears it")
	AnimalBehaviour.rain = 0.0
	var most := 0.0
	var by := 0.0
	for step in 400:
		mind.update(0.1)
		most = maxf(most, mind.pose.shake)
		if most > 0.0 and by == 0.0:
			by = step * 0.1
	_check(most > 0.5, "the rain over, it shakes it off (%.2f through at most)" % most)
	_check(by >= AnimalRig.weather("dry_from", 1.0) - 0.2, "in its own time, a moment after (%.1f s)" % by)
	_eq(mind.pose.shake, 0.0, "and is done")
	_check(is_zero_approx(Animal3D.shake_roll(0.0)) and absf(Animal3D.shake_roll(1.0)) < 0.001,
		"a short coat's shake is its body's roll: none as it starts and ends")
	var swing := 0.0
	for k in 40:
		swing = maxf(swing, absf(Animal3D.shake_roll(k / 40.0)))
	_check(swing > 0.1 and swing <= Animal3D.SHAKE_ROLL, "and a clear roll each way between (%.2f radians)" % swing)
	AnimalBehaviour.rain = rain_was
	AnimalBehaviour.night = night_was


func test_635_a_beehive_grows_by_its_lead_hive_growing_and_others_joining() -> void:
	# (The owner, 25 Nov: never one big clunky building; a bigger size is a grander yard round a lead that grew.)
	var first := _skeps(BuildingSpec.spec("beehive", 1))
	var top := _skeps(BuildingSpec.spec("beehive", Game.max_level("beehive")))
	_eq(first.size(), 1, "a new beehive is one small straw hive")
	_check(top.size() >= 3, "at its biggest it is a yard of them (%d)" % top.size())
	var sizes: Array[float] = []
	for f in top:
		sizes.append(float(f.get("scale", 1.0)))
	sizes.sort()
	_check(sizes[-1] > float(first[0].get("scale", 1.0)) * 1.25,
		"its lead hive has grown (%.2f times a first hive)" % sizes[-1])
	_check(sizes[0] < sizes[-1] * 0.7, "and the others are smaller: no row of clones (%s)" % [sizes])
	_eq(top.filter(func(f: Dictionary) -> bool: return bool(f.get("cap", false))).size(), 1, "one lead, under its hat")
	var g := _farm()
	var model: Node3D = BuildingSpec.model().build(g.item_data("beehive"), g.footprint("beehive"),
		Game.max_level("beehive"))
	var box := _box_of(model)
	var fp := g.footprint("beehive")
	_check(box.position.x >= -0.05 and box.position.z >= -0.05 and box.end.x <= fp.x + 0.05 and box.end.z <= fp.y + 0.12,
		"the whole yard stands on its footprint (%s)" % box)
	_check(box.end.y < 1.35, "and its lead is a hive still, not a tower (%.2f tiles to its star's tip)" % box.end.y)
	model.free()


func test_636_an_animal_with_a_home_goes_in_from_hard_rain_and_comes_out_after() -> void:
	var rain_was := AnimalBehaviour.rain
	var night_was := AnimalBehaviour.night
	AnimalBehaviour.night = false
	var mind := AnimalBehaviour.new(AnimalRig.of(Game.item_data("chicken")), 11, Vector2(14, 7))
	mind.stride_tiles = 0.2
	mind.shelter_at = Vector2(9, 4)
	AnimalBehaviour.rain = AnimalRig.weather("turn_from", 0.3)
	for step in 200:
		mind.update(0.1)
	_check(not mind.indoors, "in light rain it stays out (it only turns its tail to it)")
	AnimalBehaviour.rain = 1.0
	var took := 0.0
	for step in 600:
		mind.update(0.1)
		if mind.indoors:
			break
		took += 0.1
	_check(mind.indoors, "in hard rain it walks to its door and goes in (%.0f s)" % took)
	_check(mind.offset.distance_to(mind.shelter_at) <= AnimalBehaviour.ARRIVED + 0.01, "at the door, not where it stood")
	for step in 100:
		mind.update(0.1)
	_check(mind.indoors, "and waits the rain out indoors")
	AnimalBehaviour.rain = 0.0
	for step in 200:
		mind.update(0.1)
	_check(not mind.indoors, "the rain over, it comes out again")
	var loose := AnimalBehaviour.new(AnimalRig.of(Game.item_data("cow")), 3, Vector2(14, 7))
	AnimalBehaviour.rain = 1.0
	for step in 200:
		loose.update(0.1)
	_check(not loose.indoors, "an animal at large has no door: it bears the rain where it stands")
	AnimalBehaviour.rain = rain_was
	AnimalBehaviour.night = night_was


func test_637_the_coop_and_the_hutch_are_known_by_their_outlines_and_grow_by_a_lead() -> void:
	# (docs/WORLD.md: a home is a small unit with its own outline; a bigger size is its body grown and a little
	# one of its kind beside it, never the same cabin stacked higher.)
	var coop := BuildingSpec.spec("chicken_coop", 1)
	var hutch := BuildingSpec.spec("rabbit_hutch", 1)
	_check(float(coop["roof"]["pitch"]) >= 1.8 and str(coop["roof"]["type"]) == "gable",
		"the Chicken Coop is an A-frame: low walls under a steep roof")
	_eq(str(hutch["roof"]["type"]), "shed", "the Rabbit Hutch a long low box under a lid")
	_check(float(hutch["body"]["w"]) > float(hutch["body"]["d"]) * 1.5, "longer than it is deep")
	_check(str(coop["roof"]["color"]) != str(hutch["roof"]["color"]), "and each has a roof colour of its own")
	for id: String in ["chicken_coop", "rabbit_hutch"]:
		var first := BuildingSpec.spec(id, 1)
		var top := BuildingSpec.spec(id, Game.max_level(id))
		_check(float(top["body"]["w"]) > float(first["body"]["w"]) and float(top["body"]["h"]) > float(first["body"]["h"]),
			"%s: its body has grown at its biggest" % id)
		# (The owner, 26 Nov: the lead "should also get one more storey" at its biggest. An A-frame has none to
		# give; the hutch has a second tier of hutches now, on a lead that grew first.)
		_check(id != "chicken_coop" or (top.get("upper", {}) as Dictionary).is_empty(),
			"%s: an A-frame grows by its lead and its roof, with no storey stacked on it" % id)
		var huts: Array = (top["features"] as Array).filter(func(f: Dictionary) -> bool: return f.get("type") == "hut")
		_eq(huts.size(), 1, "%s: one little house of its kind has joined it" % id)
		var fp := Game.footprint(id)
		_check(float(huts[0]["w"]) < float(top["body"]["w"]) * fp.x and float(huts[0]["h"]) < float(top["body"]["h"]),
			"%s: smaller than the lead" % id)
		_check(((first["features"] as Array).filter(func(f: Dictionary) -> bool: return f.get("type") == "hut")).is_empty(),
			"%s: a new one stands alone" % id)


func test_638_a_building_at_its_biggest_marks_where_the_farm_s_star_floats() -> void:
	# (The owner, 25 Nov: "a floating rotating star with a light glow... the same for all buildings, just the
	# size will vary". No model carries a star of its own: it marks the place, and CrownStars draws them all.)
	var g := _farm()
	var kit := BuildingSpec.model()
	var top: Node3D = kit.build(g.item_data("chicken_coop"), g.footprint("chicken_coop"), Game.max_level("chicken_coop"))
	var first: Node3D = kit.build(g.item_data("chicken_coop"), g.footprint("chicken_coop"), 1)
	var barn: Node3D = kit.build(g.item_data("barn"), g.footprint("barn"), Game.max_level("barn"))
	var mark := CrownStars.mark_of(top)
	_eq(mark.size(), 2, "a Chicken Coop at its biggest marks its star")
	_check(CrownStars.mark_of(first).is_empty(), "a new one has none")
	_check(CrownStars.mark_of(barn).is_empty(), "nor the Barn, whose badge stands on its roof")
	if mark.size() == 2:
		var at := mark[0] as Node3D
		var box := _box_of(top)
		_check(float(mark[1]) > 0.05 and float(mark[1]) < 0.5, "the mark names the star's size (%.2f)" % float(mark[1]))
		_check(at.position.y > box.end.y * 0.6 and at.position.y <= box.end.y + 0.01,
			"and stands at the top of its roof (%.2f of %.2f)" % [at.position.y, box.end.y])
		_check(DecorMotion.is_part(at), "a part the game knows, so a model saved to a file keeps it")
		_check(at.get_child_count() == 0 and not (at is MeshInstance3D), "with nothing to draw: the model has no star")
	for model: Node3D in [top, first, barn]:
		model.free()
	_done(g)


func test_639_one_star_floats_over_every_marked_building_sized_to_each() -> void:
	var stars := CrownStars.new()
	add_child(stars)
	var tops: Array[Vector3] = [Vector3(1, 0.8, 2), Vector3(6, 2.1, 3)]
	var radii: Array[float] = [0.17, 0.3]
	_eq(stars.show_at(tops, radii), 2, "a star for each")
	_check(stars.visible and stars.multimesh.visible_instance_count == 2, "drawn together, as one batch")
	for k in 2:
		_check(is_equal_approx(stars.where(k).y, tops[k].y + radii[k] * CrownStars.FLOAT) and
			is_equal_approx(stars.where(k).x, tops[k].x), "star %d floats over its mark, clear of the roof" % k)
		_check(is_equal_approx(stars.radius(k), radii[k]), "star %d is the size its building asks for" % k)
	_check(absf(CrownStars.beat_of(0) - CrownStars.beat_of(1)) > 0.2, "no two side by side turn in step")
	var star_code := (stars.multimesh.mesh.surface_get_material(0) as ShaderMaterial).shader.code
	_check(star_code.contains(DARK) and star_code.contains("TIME"), "the star turns, and glows more as night falls")
	_eq(stars.find_children("*", "MultiMeshInstance3D", true, false).size(), 1, "its halo is the one other draw")
	var no_tops: Array[Vector3] = []
	var no_radii: Array[float] = []
	_eq(stars.show_at(no_tops, no_radii), 0, "none on a farm with nothing at its biggest")
	_check(not stars.visible, "and nothing drawn")
	stars.queue_free()


func test_645_every_solid_kind_of_thing_wears_the_one_finish() -> void:
	# (The owner's pick of 26 Nov, sheet option C: sun and shade, painted surfaces. One rule in one file, so a
	# cow, a coop, a fence and a tree are lit and painted alike.)
	var finish := FileAccess.get_file_as_string(FINISH)
	for part: String in ["void light()", "LIGHT_IS_DIRECTIONAL", "FINISH_SUN", "FINISH_SKY", "SPECULAR_LIGHT"]:
		_check(finish.contains(part), "the finish lights by sun and shade (%s)" % part)
	var painted := {"master_solid": 2, "paint3d": 1, "wall3d": 1}
	var leaning := ["crown3d", "frond3d"]
	for kind: String in painted.keys() + leaning + ["fruit3d"]:
		var code := FileAccess.get_file_as_string("res://shaders/%s.gdshader" % kind)
		_check(code.contains('#include "%s"' % FINISH), "%s wears the finish" % kind)
		_check(code.contains("AO = FINISH_AMBIENT;"), "%s has a shaded side (less all-round light)" % kind)
		_check(not code.contains("RIM = "), "%s leaves its light edge to the finish" % kind)
		if painted.has(kind):
			_eq(code.count("finish_painted("), painted[kind], "%s is painted wherever it sets a colour" % kind)
		if leaning.has(kind):
			_eq(code.count("finish_lean("), 1, "%s leans its own way (leaves keep their own pattern)" % kind)
	# (A thing's own number comes from where it stands: the same every frame, another for its neighbour.)
	_check(finish.contains("float finish_own(vec3 foot)"), "each thing has a number of its own from where it stands")
	var cow := AssetRegistry.instance("cow")
	_check(not _with_shader(cow, "master_solid").is_empty(), "an animal's file draws with a shader that wears it")
	cow.free()


func test_646_the_finish_s_patches_are_a_quality_s_to_give() -> void:
	# (Sun and shade and the lean are free; the patches are worked out for every pixel of every solid thing.)
	_check(not bool(Quality.value("finish_grain", "low")), "low goes without the brushy patches")
	for level: String in ["mid", "high", "ultra"]:
		_check(bool(Quality.value("finish_grain", level)), "%s has them" % level)
	_check(FileAccess.get_file_as_string(FINISH).contains("if (finish_grain > 0.0)"),
		"the shaders ask before working them out")
	_check(ProjectSettings.has_setting("shader_globals/finish_grain"), "the value is one every shader shares")
	var kept := Quality._level
	Quality._level = "low"
	Farm3D.apply_quality_finish()
	_eq(float(ShaderGlobals.value(&"finish_grain", -1.0)), 0.0, "the farm tells the shaders: off on low")
	Quality._level = "high"
	Farm3D.apply_quality_finish()
	_eq(float(ShaderGlobals.value(&"finish_grain", -1.0)), 1.0, "and on on high")
	Quality._level = kept
	Farm3D.apply_quality_finish()


func test_647_every_animal_home_is_known_by_its_own_outline_and_colour() -> void:
	# (The owner, 25 Nov: "many buildings look alike". Five were one house in five colours, each a storey taller
	# at its biggest. Now each has a roof no other home has, in a colour no other home has.)
	var roofs := {}
	var colours := {}
	for id: String in HOMES:
		var roof: Dictionary = BuildingSpec.spec(id, 1)["roof"]
		var stilted := not _of_type(BuildingSpec.spec(id, 1), "stilts").is_empty()
		var stalls := not _of_type(BuildingSpec.spec(id, 1), "stall_doors").is_empty()
		var body: Dictionary = BuildingSpec.spec(id, 1)["body"]
		var long := float(body.get("w", 0.0)) > float(body.get("d", 1.0)) * 1.6
		var outline := "%s%s%s%s" % [roof.get("type", "gable"), " on stilts" if stilted else "",
			" of stalls" if stalls else "", ", long" if long else ""]
		_check(not roofs.has(outline), "%s has an outline of its own (%s, as %s)" % [id, outline, roofs.get(outline, "")])
		roofs[outline] = id
		var colour := Color.html(str(roof.get("color", "#000000")))
		for other: String in colours:
			var far := Vector3(colour.r, colour.g, colour.b).distance_to(Vector3(colours[other].r, colours[other].g,
				colours[other].b))
			# (no nearer than the goat's orange is to the coop's red)
			_check(far > APART, "%s's roof is not %s's colour (%.2f apart)" % [id, other, far])
		colours[id] = colour
	_eq(str((BuildingSpec.spec("pig_pen", 1)["roof"] as Dictionary)["type"]), "barrel", "a pig ark has a round tin roof")
	var holder := Node3D.new()
	var white := ModelKit.paint(Color.WHITE)
	var top := ModelKit.roof(holder, "barrel", Vector3.ZERO, Vector3(1.0, 0.2, 0.6), 0.3, 0.0, white, white)
	_check(is_equal_approx(top, 0.5), "a round roof rises to its middle (%.2f)" % top)
	var box := _box_of(holder)
	_check(is_equal_approx(box.end.y, 0.5) and is_equal_approx(box.size.z, 0.6), "half a pipe over the block (%s)" % box)
	holder.free()


func test_648_a_home_at_its_biggest_has_a_taller_lead_and_something_beside_it() -> void:
	# (The owner, 25 and 26 Nov: the parts get bigger too; "the hero component in each building should also get
	# one more storey"; never just the same building again.)
	var beside := {"cow_shed": "silo", "sheep_pen": "lean_to", "goat_pen": "hut", "horse_stable": "cupola",
		"pig_pen": "hut"}
	var moving := {"cow_shed": "weathervane", "sheep_pen": "chimney", "goat_pen": "birds",
		"horse_stable": "weathervane", "pig_pen": "whirligig"}
	var g := _farm()
	for id: String in beside:
		var small := BuildingSpec.spec(id, 1)
		var big := BuildingSpec.spec(id, g.max_level(id))
		var tall_small := float((small["body"] as Dictionary)["h"])
		var tall_big := float((big["body"] as Dictionary)["h"])
		var above: Dictionary = big.get("upper", {})
		while not above.is_empty():   # (a storey on a storey: the grandest size goes up)
			tall_big += float(above.get("h", 0.0))
			above = above.get("upper", {})
		_check(tall_big >= tall_small + STOREY, "%s's lead stands a storey taller (%.2f, then %.2f)" % [id, tall_small,
			tall_big])
		_check(float((big["body"] as Dictionary)["w"]) > float((small["body"] as Dictionary)["w"]),
			"%s's lead is wider too" % id)
		_check(_of_type(small, beside[id]).is_empty() and not _of_type(big, beside[id]).is_empty(),
			"%s gains a %s" % [id, beside[id]])
		# (Light and alive: one thing of its own moves at its biggest, by the wind or on its own.)
		_check(_of_type(small, moving[id]).is_empty() and not _of_type(big, moving[id]).is_empty(),
			"%s's %s moves only at its biggest" % [id, moving[id]])
	# (A part that swings or circles by its shader is named for the way it goes, so a home's file carries it and
	# the game sets it going again: before, only spinning parts and effects came through a file.)
	var barn := AssetRegistry.instance("cow_shed", {"level": g.max_level("cow_shed")})
	var vanes := barn.find_children("%s_vane_*" % DecorMotion.ORBIT, "Node3D", true, false) if barn != null else []
	_eq(vanes.size(), 1, "a Dairy Farm's file has its weathervane")
	for vane: Node3D in vanes:
		_check(DecorMotion.is_part(vane), "a part the game knows")
		var turning := 0
		for part in vane.get_children():
			var drawn := (part as MeshInstance3D).material_override as ShaderMaterial
			turning += 1 if drawn != null and drawn.shader.resource_path == DecorMotion.ORBIT_SHADER else 0
		_check(turning > 0, "..swinging with the wind (%d of its meshes)" % turning)
	if barn != null:
		barn.free()
	_eq(DecorMotion.ORBITS.find_key(DecorMotion.CIRCLING), "circling", "a way of going is known by its name")
	# (The owner, 26 Nov: "at max level [they] don't look the part... not grand enough". A plot is what it is, so
	# the top size goes up: a third storey, a little tower, a silo.)
	for id: String in ["cow_shed", "sheep_pen", "goat_pen", "nursery_barn"]:
		var top: Dictionary = BuildingSpec.spec(id, g.max_level(id)).get("upper", {})
		_check(not (top.get("upper", {}) as Dictionary).is_empty(), "%s has a third storey at its biggest" % id)
	var ark: Node3D = BuildingSpec.model().build(g.item_data("pig_pen"), g.footprint("pig_pen"), g.max_level("pig_pen"))
	var spinning := ark.find_children(DecorMotion.SPIN + "_*", "Node3D", true, false)
	_eq(spinning.size(), 1, "the ark's tin vent is one spinning part")
	ark.free()
	_done(g)


func test_649_every_animal_home_hangs_its_animal_s_market_picture_at_its_gate() -> void:
	# (The owner, 26 Nov: "a signboard with the animal icon for each building... the same icons in the market".)
	var g := _farm()
	for id: String in HOMES:
		var signs := _of_type(BuildingSpec.spec(id, 1), "gate_sign")
		_eq(signs.size(), 1, "%s has a sign at its gate" % id)
		if signs.is_empty():
			continue
		var animal := str((signs[0] as Dictionary)["animal"])
		_check((g.item_data(id).get("holds", []) as Array).has(animal),
			"%s's sign shows an animal it holds (%s)" % [id, animal])
		for level: int in [1, g.max_level(id)]:
			var model: Node3D = BuildingSpec.model().build(g.item_data(id), g.footprint(id), level)
			var mark := model.find_child(GateSign.mark_name(animal), true, false) as Node3D
			_check(mark != null and DecorMotion.is_part(mark), "%s size %d marks where its board hangs" % [id, level])
			if mark != null:
				_check(mark.get_child_count() == 0, "..with no board in the model: a picture is made on the phone")
				var fp := g.footprint(id)
				_check(mark.position.x > 0.0 and mark.position.x < fp.x and mark.position.z > 0.0
					and mark.position.z < fp.y, "..inside its own footprint (%s)" % mark.position)
				var board := GateSign.hang(model)
				_check(board != null and board.get_parent() == mark and GateSign.hang(model) == board, "..hung once")
				var shown := board.material_override as ShaderMaterial
				_check(shown.get_shader_parameter("picture") == ItemIcons.of(animal), "..with the Market's own picture")
				_check(shown == GateSign.material(animal), "..on the one material all its kind share")
			model.free()
	var sign_code := FileAccess.get_file_as_string(GateSign.SHADER)
	_check(sign_code.contains(WIND) and sign_code.contains(FINISH),
		"a board sways in the shared wind and wears the finish")
	# (A home's file is the model alone, held to its budget of draws: the farm hangs the board, one draw more.)
	var made := AssetRegistry.instance("cow_shed")
	var made_mark := made.find_child(GateSign.mark_name("cow"), true, false) if made != null else null
	_check(made_mark != null and made_mark.get_child_count() == 0, "a Dairy Farm's file marks the place and no more")
	if made != null:
		made.free()
	var farm_code := FileAccess.get_file_as_string("res://scripts/world3d/objects_3d.gd")
	_eq(farm_code.count("GateSign.hang(node)"), 2, "the farm hangs it on a home from a file and on one built in its place")
	_done(g)


func test_650_a_pool_of_light_is_drawn_only_when_it_is_dark() -> void:
	# (By day every building's and lamp's pool of light was a draw of nothing at all: about one draw in thirty on
	# the showcase farm. They stand on a layer of their own, which the farm's camera looks at only at night.)
	_check(not ModelKit.pools_show(0.0) and ModelKit.pools_show(0.3), "no pools by day, pools once it darkens")
	var g := _farm()
	var built: Node3D = BuildingSpec.model().build(g.item_data("bakery"), g.footprint("bakery"), 1)
	var made := AssetRegistry.instance("bakery")
	for model: Node3D in [built, made]:
		var pools := 0
		var others := 0
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or mi.mesh.get_surface_count() == 0:
				continue
			if mi.get_active_material(0) == ModelKit.glow_material():
				pools += 1
				_eq(mi.layers, ModelKit.NIGHT_LAYER, "a pool of light is on the night's layer alone")
			else:
				others += 1 if mi.layers & ModelKit.NIGHT_LAYER != 0 else 0
		_check(pools > 0, "a Bakery throws light from its door and windows")
		_eq(others, 0, "and nothing else of it is on that layer")
		model.free()
	var farm := Farm3D.new()
	add_child(farm)
	farm.set_night(0.0)
	_eq(farm.camera.cull_mask & ModelKit.NIGHT_LAYER, 0, "by day the farm's camera does not look at them")
	farm.set_night(0.8)
	_eq(farm.camera.cull_mask & ModelKit.NIGHT_LAYER, ModelKit.NIGHT_LAYER, "at night it does")
	farm.queue_free()
	_done(g)


func test_107_buildings_are_compact_and_tall_like_farmville_s() -> void:
	# FarmVille drew its buildings as compact blocks, never long low sheds, and grew them upward. Its animal homes
	# were one low storey, a couple of animals tall, so the animals in the yard read against them; the others
	# (barns, workshops) stand about as tall as they're deep.
	# Some homes are known by their own outline instead (docs/WORLD.md, the owner's picks of 25 and 26 Nov): the
	# Chicken Coop is an A-frame, the Sheep Pen a low fold, the Pig Pen a round ark, the Dairy Farm a barn under
	# a two-pitch roof and the Goat Pen a hut on stilts, each tall by its roof over low walls; the Rabbit Hutch
	# is a long low hutch and the Stable a long row of stalls. The Winery is a cellar under a round roof.
	var by_roof := ["chicken_coop", "sheep_pen", "pig_pen", "cow_shed", "goat_pen", "winery"]
	var long_ones := ["rabbit_hutch", "horse_stable"]
	var g := _farm()
	for id in g.items:
		if not ["building", "crafting", "barn"].has(str(g.items[id].get("kind", ""))):
			continue
		var fp := g.footprint(id)
		var last_h := 0.0
		for level in range(1, g.max_level(id) + 1):
			var body: Dictionary = BuildingModel.spec(id, level)["body"]
			var bw := float(body.get("w", 0.0)) * fp.x
			var bd := float(body.get("d", 0.0)) * fp.y
			if bw <= 0.0 or bd <= 0.0:
				continue  # a yard with no building on it (a pond, an orchard, hives)
			# A second storey stands on the ground floor: the building is as tall as both.
			var upper: Dictionary = BuildingModel.spec(id, level).get("upper", {})
			var h := float(body.get("h", 0.0)) + float(upper.get("h", 0.0))
			var long_side := maxf(bw, bd)
			var short_side := minf(bw, bd)
			if by_roof.has(id):
				h += float((BuildingModel.spec(id, level)["roof"] as Dictionary).get("pitch", 0.0)) * short_side / 2.0
			_check(long_side / short_side <= (LONG_HOME if long_ones.has(id) else 1.4),
				"%s size %d is not a long shed (%.2f x %.2f)" % [id, level, bw, bd])
			_check(h >= short_side * 0.5, "%s size %d stands tall for its size (%.2f high, %.2f deep)"
				% [id, level, h, short_side])
			_check(h >= last_h, "%s size %d is no lower than the size before" % [id, level])
			last_h = h
	_done(g)


func _skeps(spec: Dictionary) -> Array:
	return _of_type(spec, "skep")


func _of_type(spec: Dictionary, type: String) -> Array:
	return (spec.get("features", []) as Array).filter(func(f: Dictionary) -> bool: return f.get("type") == type)


func _box_of(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.material_override == ModelKit.shade_material():
			continue
		var xf := mi.transform
		var up := mi.get_parent()
		while up != null and up != node and up is Node3D:
			xf = (up as Node3D).transform * xf
			up = up.get_parent()
		var b: AABB = xf * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _with_shader(node: Node, kind: String) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var all: Array = [mi.material_override]
		for s in (mi.mesh.get_surface_count() if mi.mesh != null else 0):
			all.append(mi.get_active_material(s))
		for m in all:
			var sm := m as ShaderMaterial
			if sm == null or sm.shader == null or out.has(sm):
				continue
			if sm.shader.resource_path.get_file().get_basename() == kind:
				out.append(sm)
	return out


func _number(m: ShaderMaterial, param: String) -> float:
	var v: Variant = m.get_shader_parameter(param)
	return float(v) if v != null else 0.0
