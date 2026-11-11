class_name Crops3D
extends Node3D
## Every crop on the farm in 3D: four plants to a plot, on top of its bed, drawn as one MultiMesh per
## plant shape and growth stage (so a whole field costs a handful of draws). Young plants grow in size as
## they ripen; produce takes its crop's colour. Rebuilt when plots change, and every few seconds as crops
## grow.

const SPOTS := [Vector2(-0.24, -0.24), Vector2(0.24, -0.24), Vector2(-0.24, 0.24), Vector2(0.24, 0.24),
	Vector2(0, 0)]
const GROW_REFRESH := 3.0   # seconds between growth updates
const POP_HEIGHT := 0.5    # how high harvested plants spring before vanishing
const POP_TIME := 0.42
const PLANT_SCALE := 2.5    # plants are modelled at about a fifth of a tile; on the farm they fill their bed

var wind := 0.6: set = _set_wind

var _layers := {}   # "shape|stage" -> MultiMeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/crop3d.gdshader")
	var timer := Timer.new()
	timer.wait_time = GROW_REFRESH
	timer.autostart = true
	timer.timeout.connect(rebuild)
	add_child(timer)
	rebuild()


func _set_wind(v: float) -> void:
	wind = v
	RenderingServer.global_shader_parameter_set(&"wind", v)  # crops read the one global wind


## The stage a plot's plants are drawn at, and how grown they look within it (0..1).
static func stage_of(i: int) -> Array:
	match Game.field.phase(i):
		GameState.Phase.RIPE:
			return ["ripe", 1.0]
		GameState.Phase.WITHERED:
			return ["withered", 1.0]
		GameState.Phase.GROWING:
			var g := Game.field.growth(i)
			if g < 0.2:
				return ["seeds", 1.0]
			if g < 0.45:
				return ["sprout", (g - 0.2) / 0.25]
			return ["young", (g - 0.45) / 0.55]
	return ["", 0.0]


func rebuild() -> void:
	var groups := {}  # key -> Array of [Transform3D, Color]
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
			var key := "%s|%s" % [str(crop.get("shape", "berry")), st[0]]
			var col := Color.html(str(crop.get("color", "#e2453c")))
			var size := PLANT_SCALE * (lerpf(0.55, 1.0, float(st[1])) if st[0] in ["sprout", "young"] else 1.0)
			var list: Array = groups.get_or_add(key, [])
			for k in SPOTS.size():
				var spot: Vector2 = SPOTS[k]
				var turn := float((i * 7 + k * 13) % 17) / 17.0 * TAU
				var at := Vector3(c + 0.5 + spot.x, Plots3D.HEIGHT, r + 0.5 + spot.y)
				list.append([Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * size), at), col])
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
		mm.mesh = CropModels.mesh(parts[0], parts[1])
		var list: Array = groups[key]
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k][0])
			mm.set_instance_custom_data(k, list[k][1])
		mmi.multimesh = mm


## A harvested plot's plants pop: they spring up out of the bed, spin a little and shrink away.
func pop(i: int, crop_id: String) -> void:
	if not Game.crops.has(crop_id):
		return
	var crop: Dictionary = Game.crops[crop_id]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = CropModels.mesh(str(crop.get("shape", "berry")), "ripe")
	mm.instance_count = SPOTS.size()
	for k in SPOTS.size():
		var spot: Vector2 = SPOTS[k]
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * PLANT_SCALE), Vector3(spot.x, 0, spot.y)))
		mm.set_instance_custom_data(k, Color.html(str(crop.get("color", "#e2453c"))))
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
