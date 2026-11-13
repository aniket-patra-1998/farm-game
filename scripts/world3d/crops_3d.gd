class_name Crops3D
extends Node3D
## Every crop on the farm in 3D: nine plants to a plot, in three rows, on top of its bed, drawn as one MultiMesh per
## plant shape and growth stage (so a whole field costs a handful of draws). Young plants grow in size as
## they ripen; produce takes its crop's colour. Rebuilt when plots change, and every few seconds as crops
## grow. Growth is the shader's: a growing plant carries when its stage starts and how long it lasts, and the
## shader sizes it from the farm's clock every frame, so a plant swells smoothly instead of in steps.

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

var wind := 0.6: set = _set_wind

var _layers := {}   # "shape|stage" -> MultiMeshInstance3D
var _material: ShaderMaterial
var _base := 0.0    # the farm clock's zero: seconds count from here, so a shader's floats stay precise
var _drawn := -1    # a fingerprint of what was last built: the same again means there is nothing to rebuild


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
	rebuild()


func _process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set(&"crop_clock", _now() - _base)


## The game's time as a float (whole seconds are too coarse for a plant to swell by).
static func _now() -> float:
	return Time.get_unix_time_from_system() + Game.debug_time_offset


## What an instance carries for the shader: its colour (three bytes in one float, which a float holds exactly),
## when its growing stage began (seconds on the farm clock), how long that stage lasts (0: fully grown) and
## whether it is fertilised.
static func pack(col: Color, started: float, length: float, rich: bool) -> Color:
	var bytes := (int(col.r8) << 16) | (int(col.g8) << 8) | int(col.b8)
	return Color(float(bytes), started, length, 1.0 if rich else 0.0)


func _set_wind(v: float) -> void:
	wind = v
	RenderingServer.global_shader_parameter_set(&"wind", v)  # crops read the one global wind


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


## What the farm's crops look like right now, as one number: crop, stage and richness of every plot.
func _fingerprint() -> int:
	var h := Game.farm_size
	for i in Game.farm_size * Game.farm_size:
		var crop_id := Game.field.crop_at(Game.index_of(i / Game.farm_size, i % Game.farm_size))
		if crop_id == "":
			continue
		var idx := Game.index_of(i / Game.farm_size, i % Game.farm_size)
		var st := stage_of(idx)
		h = hash([h, idx, crop_id, st[0], Game.field.is_fertilized(idx)])
	return h


## Builds the plants again, unless nothing about them has changed since the last build (the timer finds that out
## for a few cheap lookups instead of a new MultiMesh per group).
func rebuild() -> void:
	var print_now := _fingerprint()
	if print_now == _drawn:
		return
	_drawn = print_now
	var groups := {}  # key -> Array of [Transform3D, packed instance data]
	var n := Game.farm_size
	for r in n:
		for c in n:
			var i := Game.index_of(r, c)
			var crop_id := Game.field.crop_at(i)
			if crop_id == "" or not Game.crops.has(crop_id):
				continue
			var st := stage_of(i)
			if st[0] == "":
				continue
			var crop: Dictionary = Game.crops[crop_id]
			var key := "%s|%s" % [CropForms.form_of(crop_id, str(crop.get("shape", "berry"))), st[0]]
			var col := Color.html(str(crop.get("color", "#e2453c")))
			var rich := Game.field.is_fertilized(i)
			var data := pack(col, float(st[1]) - _base, float(st[2]), rich)
			var list: Array = groups.get_or_add(key, [])
			for k in SPOTS.size():
				var spot: Vector2 = SPOTS[k]
				var turn := float((i * 7 + k * 13) % 17) / 17.0 * TAU
				var at := Vector3(c + 0.5 + spot.x, Plots3D.HEIGHT, r + 0.5 + spot.y)
				list.append([Transform3D(_plant_basis(turn, PLANT_SCALE, i * 5 + k), at), data])
	for key in _layers.keys():
		if not groups.has(key):
			(_layers[key] as MultiMeshInstance3D).queue_free()
			_layers.erase(key)
	for key in groups:
		var mmi: MultiMeshInstance3D = _layers.get(key)
		if mmi == null:
			mmi = MultiMeshInstance3D.new()
			mmi.material_override = _material
			add_child(mmi)
			_layers[key] = mmi
		var parts := str(key).split("|")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true   # the compatibility renderer reads an unset instance colour as black
		mm.mesh = CropModels.mesh(parts[0], parts[1])
		var list: Array = groups[key]
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k][0])
			mm.set_instance_custom_data(k, list[k][1])
			mm.set_instance_color(k, Color.WHITE)
		mmi.multimesh = mm


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
	mm.mesh = CropModels.mesh(CropForms.form_of(crop_id, str(crop.get("shape", "berry"))), "ripe")
	mm.instance_count = SPOTS.size()
	for k in SPOTS.size():
		var spot: Vector2 = SPOTS[k]
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * PLANT_SCALE), Vector3(spot.x, 0, spot.y)))
		mm.set_instance_custom_data(k, pack(Color.html(str(crop.get("color", "#e2453c"))), 0.0, 0.0, false))
	var ghost := MultiMeshInstance3D.new()
	ghost.multimesh = mm
	ghost.material_override = _material
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
