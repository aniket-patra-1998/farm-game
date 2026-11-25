extends TestSuite
## The world's rules (docs/WORLD.md; owner, 25 Nov): every thing of a kind answers the weather, the night and its
## own weight the same way, through values the whole farm shares, never piece by piece.

const RAIN := "global uniform float rain"
const WIND := "global uniform float wind"
const DARK := "global uniform float dark"


func test_627_an_open_fire_answers_the_rain_and_the_wind() -> void:
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


func test_628_smoke_answers_the_weather_and_water_does_not() -> void:
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


func test_629_a_lamp_is_lit_as_night_falls() -> void:
	var g := _farm()
	var post := DecorModel.build(g.item_data("lamp_post"), g.footprint("lamp_post"), {"id": "lamp_post", "uid": 1})
	var lights := _with_shader(post, "lamp3d")
	_check(lights.size() == 1 and _number(lights[0], "fire") == 0.0, "the lamp post's light is a lamp's")
	_check((lights[0].shader as Shader).code.contains(DARK), "lit by how dark the farm is, not always on")
	_check(lights[0] == DecorModel._glow(Color(lights[0].get_shader_parameter("colour"))),
		"every lamp of a colour shares one material (a draw for them all)")
	post.free()


func test_630_a_things_shade_on_the_ground_reads_at_night() -> void:
	var shade := load("res://shaders/contact3d.gdshader") as Shader
	_check(shade.code.contains(DARK),
		"the shade under a thing is drawn stronger at night, when no cast shadow holds it down")
	var batch := ContactShades.new()
	_eq((batch.material_override as ShaderMaterial).shader, shade, "every animal's shade is that one")
	batch.free()


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
