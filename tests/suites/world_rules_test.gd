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
