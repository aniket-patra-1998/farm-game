class_name Crops3D
extends Node3D
## Every crop on the farm in 3D: nine plants to a plot, in three rows, on top of its bed, drawn as one MultiMesh per
## plant shape and growth stage (so a whole field costs a handful of draws). Young plants grow in size as
## they ripen; produce takes its crop's colour. Updated plot by plot when plots change (`update`), and every few
## seconds as crops grow. Growth is the shader's: a growing plant carries when its stage starts and how long it
## lasts, and the shader sizes it from the farm's clock every frame, so a plant swells smoothly, not in steps.

const ROW_GAP := 0.31   # between plants in a plot's rows and columns: three rows of three, like a planted field
const SPOTS := [Vector2(-ROW_GAP, -ROW_GAP), Vector2(0, -ROW_GAP), Vector2(ROW_GAP, -ROW_GAP),
	Vector2(-ROW_GAP, 0), Vector2(0, 0), Vector2(ROW_GAP, 0),
	Vector2(-ROW_GAP, ROW_GAP), Vector2(0, ROW_GAP), Vector2(ROW_GAP, ROW_GAP)]
const GROW_REFRESH := 3.0   # seconds between looks at whether growth has moved a plant on
const SPROUT_FROM := 0.2    # of the growing time: the seeds have sprouted
const YOUNG_FROM := 0.45    # and the sprouts are young plants
const SIZE_FROM := 0.55     # the size a plant starts a growing stage at, of its full size
const POP_HEIGHT := 0.5    # how high harvested plants spring before vanishing
const POP_TIME := 0.42
const FERTILIZED_SIZE := 1.18     # fertilised plants grow bigger (the shader applies it)
const VARY_LEAN := 0.16    # radians a plant may lean
const PLANT_SCALE := 3.1    # plants are modelled at about a fifth of a tile; on the farm they fill their bed
const PLANT_FLOATS := 20    # a plant in the MultiMesh buffer: transform (12), colour (4), data (4)

var wind := 0.6: set = _set_wind

var _layers := {}   # "shape|stage|colour" -> MultiMeshInstance3D
var _material: ShaderMaterial
var _materials := {}   # colour -> that colour's material (material_for)
var _base := 0.0    # the farm clock's zero: seconds count from here, so a shader's floats stay precise
var _plot_look := {}   # plot index -> [group key, packed data]: what its plants look like now
var _plot_chunk := {}  # plot index -> its plants as MultiMesh buffer data (_chunk), kept ready
var _members := {}     # group key -> {plot index: true}: the plots each group draws


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/crop3d.gdshader")
	_material.set_shader_parameter("size_from", SIZE_FROM)
	_material.set_shader_parameter("rich_size", FERTILIZED_SIZE)
	_base = floorf(_now())
	var timer := Timer.new()
	timer.wait_time = GROW_REFRESH
	timer.autostart = true
	timer.timeout.connect(rebuild)
	add_child(timer)
	Quality.notifier.emitted.connect(_apply_shadows)
	rebuild()


## Crops cast shadows only on the high level (data/quality.json `crop_shadows`): hundreds of small plants
## are most of a big farm's shadow triangles and, seen from above, their shadows hardly show.
func _apply_shadows() -> void:
	for mmi in _layers.values():
		(mmi as MultiMeshInstance3D).cast_shadow = _shadow_setting()


static func _shadow_setting() -> GeometryInstance3D.ShadowCastingSetting:
	return (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(Quality.value("crop_shadows"))
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func _process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set(&"crop_clock", _now() - _base)  # every frame: see ShaderGlobals


## The game's time as a float (whole seconds are too coarse for a plant to swell by).
static func _now() -> float:
	return Time.get_unix_time_from_system() + Game.debug_time_offset


## What an instance carries for the shader: when its growing stage began and how long that stage lasts (0: fully
## grown), in minutes on the farm clock (small numbers: the compatibility renderer keeps instance data as 16-bit
## floats), and whether it is fertilised. Its crop's colour is in the material (`material_for`).
static func pack(started: float, length: float, rich: bool) -> Color:
	return Color(started / 60.0, length / 60.0, 1.0 if rich else 0.0, 0.0)


## The material for a crop colour: the shared one with that colour set, made once.
func material_for(col: Color) -> ShaderMaterial:
	var key := col.to_html(false)
	if not _materials.has(key):
		var m := _material.duplicate() as ShaderMaterial
		m.set_shader_parameter("produce_colour", col)
		_materials[key] = m
	return _materials[key]


func _set_wind(v: float) -> void:
	wind = v
	ShaderGlobals.set_value(&"wind", v)  # crops read the one global wind


## The stage a plot's plants are drawn at, and the stretch of time (unix seconds) the stage's growing spans:
## [stage, from, length], with a length of 0 for a stage that is done growing.
static func stage_of(i: int) -> Array:
	match Game.field.phase(i):
		GameState.Phase.RIPE:
			return ["ripe", 0.0, 0.0]
		GameState.Phase.WITHERED:
			return ["withered", 0.0, 0.0]
		GameState.Phase.GROWING:
			var plot: Dictionary = Game.plots[i]
			var planted := float(plot["planted_at"])
			var grow := float(Game.crops[plot["crop"]]["grow_seconds"])
			var g := Game.field.growth(i)
			if g < SPROUT_FROM:
				return ["seeds", 0.0, 0.0]
			if g < YOUNG_FROM:
				return ["sprout", planted + SPROUT_FROM * grow, (YOUNG_FROM - SPROUT_FROM) * grow]
			return ["young", planted + YOUNG_FROM * grow, (1.0 - YOUNG_FROM) * grow]
	return ["", 0.0, 0.0]


## Brings the plants of plots `indices` up to date (all of them when empty): a plot whose look (form, stage,
## colour, growth timing, richness) is unchanged is skipped, and only the groups a plot left or joined are laid
## out again, from per-plot pieces kept ready. So plowing, planting or harvesting one plot touches one or two
## groups, not the whole field, and the timer's look at growth rebuilds only plants that moved on a stage.
func update(indices: Array = []) -> void:
	if indices.is_empty():
		# The whole field, and any plot still drawn from a bigger farm (a load or reset can shrink it).
		indices = _all_plots()
		var on_farm := {}
		for i: int in indices:
			on_farm[i] = true
		for i: int in _plot_look:
			if not on_farm.has(i):
				indices.append(i)
	var dirty := {}
	for i: int in indices:
		var now := _look_of(i) if _on_farm(i) else []
		var was: Array = _plot_look.get(i, [])
		if was == now:
			continue
		if not was.is_empty():
			(_members[was[0]] as Dictionary).erase(i)
			dirty[was[0]] = true
			_plot_look.erase(i)
			_plot_chunk.erase(i)
		if not now.is_empty():
			_plot_look[i] = now
			_plot_chunk[i] = _chunk(i, now[1])
			(_members.get_or_add(now[0], {}) as Dictionary)[i] = true
			dirty[now[0]] = true
	for key: String in dirty:
		_lay_out(key)


## Whether plot `i` lies on the farm as it is now.
static func _on_farm(i: int) -> bool:
	return int(i / float(GameState.MAX_SIZE)) < Game.farm_size and i % GameState.MAX_SIZE < Game.farm_size


## Every plot of the farm, by index.
static func _all_plots() -> Array:
	var out := []
	var n := Game.farm_size
	for r in n:
		for c in n:
			out.append(Game.index_of(r, c))
	return out


## What plot `i`'s plants look like: [group key, packed instance data], or [] for none.
func _look_of(i: int) -> Array:
	var crop_id := Game.field.crop_at(i)
	if crop_id == "" or not Game.crops.has(crop_id):
		return []
	var st := stage_of(i)
	if st[0] == "":
		return []
	var crop: Dictionary = Game.crops[crop_id]
	var col := Color.html(str(crop.get("color", "#e2453c")))
	var key := "%s|%s|%s" % [CropForms.form_of(crop_id, str(crop.get("shape", "berry"))), st[0], col.to_html(false)]
	return [key, pack(float(st[1]) - _base, float(st[2]), Game.field.is_fertilized(i))]


## Plot `i`'s plants as MultiMesh buffer data: for each, its transform (3 rows of 4), its colour, its data.
static func _chunk(i: int, data: Color) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var r := int(i / float(GameState.MAX_SIZE))
	var c := i % GameState.MAX_SIZE
	for k in SPOTS.size():
		var spot: Vector2 = SPOTS[k]
		var turn := float((i * 7 + k * 13) % 17) / 17.0 * TAU
		var b := _plant_basis(turn, PLANT_SCALE, i * 5 + k)
		var at := Vector3(c + 0.5 + spot.x, Plots3D.HEIGHT, r + 0.5 + spot.y)
		out.append_array([b.x.x, b.y.x, b.z.x, at.x, b.x.y, b.y.y, b.z.y, at.y, b.x.z, b.y.z, b.z.z, at.z,
			1.0, 1.0, 1.0, 1.0, data.r, data.g, data.b, data.a])
	return out


## Lays out one group's plants again from its plots' pieces (or removes the group when it has none).
func _lay_out(key: String) -> void:
	var members: Dictionary = _members.get(key, {})
	if members.is_empty():
		_members.erase(key)
		if _layers.has(key):
			(_layers[key] as MultiMeshInstance3D).queue_free()
			_layers.erase(key)
		return
	var mmi: MultiMeshInstance3D = _layers.get(key)
	var parts := key.split("|")
	if mmi == null:
		mmi = MultiMeshInstance3D.new()
		mmi.material_override = material_for(Color.html(str(parts[2])))
		mmi.cast_shadow = _shadow_setting()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true   # the compatibility renderer reads an unset instance colour as black
		mm.mesh = CropModels.mesh(parts[0], parts[1])
		mmi.multimesh = mm
		add_child(mmi)
		_layers[key] = mmi
	var buffer := PackedFloat32Array()
	for i: int in members:
		buffer.append_array(_plot_chunk[i])
	mmi.multimesh.instance_count = buffer.size() / PLANT_FLOATS
	mmi.multimesh.buffer = buffer   # one copy into the engine, not three calls a plant


## Brings every plot's plants up to date (the timer's look at growth; a change to the whole farm).
func rebuild() -> void:
	update()


## How many plants are drawn (for tests and the perf probe).
func plant_count() -> int:
	var n := 0
	for mmi: MultiMeshInstance3D in _layers.values():
		n += mmi.multimesh.instance_count
	return n


## One plant's pose: turned, a little taller or shorter, fatter or slimmer and leaning, the same every time for
## the same plot and spot, so a field looks grown and not stamped.
static func _plant_basis(turn: float, size: float, seed_value: int) -> Basis:
	var h := float((seed_value * 37) % 29) / 28.0
	var w := float((seed_value * 53) % 31) / 30.0
	var lean := float((seed_value * 71) % 23) / 22.0 - 0.5
	var tilt := Basis(Vector3.RIGHT, lean * VARY_LEAN) * Basis(Vector3.FORWARD, (h - 0.5) * VARY_LEAN)
	var stretch := Vector3(lerpf(0.9, 1.12, w), lerpf(0.82, 1.2, h), lerpf(0.9, 1.12, w))
	return (Basis(Vector3.UP, turn) * tilt).scaled(stretch * size)


## A harvested plot's plants pop: they spring up out of the bed, spin a little and shrink away.
func pop(i: int, crop_id: String) -> void:
	if not Game.crops.has(crop_id):
		return
	var crop: Dictionary = Game.crops[crop_id]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true   # (as above: an unset instance colour is black in the compatibility renderer)
	mm.mesh = CropModels.mesh(CropForms.form_of(crop_id, str(crop.get("shape", "berry"))), "ripe")
	mm.instance_count = SPOTS.size()
	for k in SPOTS.size():
		var spot: Vector2 = SPOTS[k]
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * PLANT_SCALE), Vector3(spot.x, 0, spot.y)))
		mm.set_instance_custom_data(k, pack(0.0, 0.0, false))
		mm.set_instance_color(k, Color.WHITE)
	var ghost := MultiMeshInstance3D.new()
	ghost.multimesh = mm
	ghost.material_override = material_for(Color.html(str(crop.get("color", "#e2453c"))))
	var r := int(i / float(GameState.MAX_SIZE))
	var c := i % GameState.MAX_SIZE
	ghost.position = Vector3(c + 0.5, Plots3D.HEIGHT, r + 0.5)
	add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "scale", Vector3(1.2, 0.75, 1.2), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector3(0.9, 1.25, 0.9), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(ghost, "position:y", Plots3D.HEIGHT + POP_HEIGHT, POP_TIME).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "rotation:y", 0.8, POP_TIME)
	tw.tween_property(ghost, "scale", Vector3.ONE * 0.05, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ghost.queue_free)
