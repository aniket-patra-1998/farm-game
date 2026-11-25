extends TestSuite
## The world's rules (docs/WORLD.md; owner, 25 Nov): every thing of a kind answers the weather, the night and its
## own weight the same way, through values the whole farm shares, never piece by piece.

const RAIN := "global uniform float rain"
const WIND := "global uniform float wind"
const DARK := "global uniform float dark"


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
		_check((top.get("upper", {}) as Dictionary).is_empty(), "%s: not by a storey stacked on it" % id)
		var huts: Array = (top["features"] as Array).filter(func(f: Dictionary) -> bool: return f.get("type") == "hut")
		_eq(huts.size(), 1, "%s: one little house of its kind has joined it" % id)
		var fp := Game.footprint(id)
		_check(float(huts[0]["w"]) < float(top["body"]["w"]) * fp.x and float(huts[0]["h"]) < float(top["body"]["h"]),
			"%s: smaller than the lead" % id)
		_check(((first["features"] as Array).filter(func(f: Dictionary) -> bool: return f.get("type") == "hut")).is_empty(),
			"%s: a new one stands alone" % id)


func test_107_buildings_are_compact_and_tall_like_farmville_s() -> void:
	# FarmVille drew its buildings as compact blocks, never long low sheds, and grew them upward. Its animal homes
	# were one low storey, a couple of animals tall, so the animals in the yard read against them; the others
	# (barns, workshops) stand about as tall as they're deep.
	# Two homes are known by their own outline instead (docs/WORLD.md, the owner's pick of 25 Nov): the Chicken
	# Coop is an A-frame, tall by its roof over low walls; the Rabbit Hutch is a long low hutch.
	var by_roof := ["chicken_coop"]
	var long_ones := ["rabbit_hutch"]
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
			_check(long_side / short_side <= (2.2 if long_ones.has(id) else 1.4),
				"%s size %d is not a long shed (%.2f x %.2f)" % [id, level, bw, bd])
			_check(h >= short_side * 0.5, "%s size %d stands tall for its size (%.2f high, %.2f deep)"
				% [id, level, h, short_side])
			_check(h >= last_h, "%s size %d is no lower than the size before" % [id, level])
			last_h = h
	_done(g)


func _skeps(spec: Dictionary) -> Array:
	return (spec.get("features", []) as Array).filter(func(f: Dictionary) -> bool: return f.get("type") == "skep")


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
