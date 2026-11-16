class_name Crops3D
extends Node3D
## Every crop on the farm in 3D: nine plants to a plot, in three rows, on top of its bed, drawn as one MultiMesh per
## plant shape and growth stage (so a whole field costs a handful of draws). Young plants grow in size as
## they ripen; produce takes its crop's colour. Updated plot by plot when plots change (`update`), and every few
## seconds as crops grow. Growth is the shader's: a growing plant carries when its stage starts and how long it
## lasts, and the shader sizes it from the farm's clock every frame, so a plant swells smoothly, not in steps.

const CROP_SHADER := preload("res://shaders/crop3d.gdshader")
const ROW_GAP := 0.26   # between plants in a plot's rows and columns: three rows of three, like a planted field,
# standing inside the plot's edge (with CropForms.look("reach")) so each plot is its own patch
const SPOTS := [Vector2(-ROW_GAP, -ROW_GAP), Vector2(0, -ROW_GAP), Vector2(ROW_GAP, -ROW_GAP),
	Vector2(-ROW_GAP, 0), Vector2(0, 0), Vector2(ROW_GAP, 0),
	Vector2(-ROW_GAP, ROW_GAP), Vector2(0, ROW_GAP), Vector2(ROW_GAP, ROW_GAP)]
const ONE_SPOT := [Vector2.ZERO]
const GROW_CHECK := 1.0     # seconds between checks of the clock against the next plot due to change look
const SPROUT_FROM := 0.2    # of the growing time: the seeds have sprouted
const YOUNG_FROM := 0.45    # and the sprouts are young plants
const RIPEN_FROM := 0.75    # and the plant is the ripe one, still growing, its fruit green and colouring up
const SPROUT_START := 0.3   # the size a sprout comes up at, of its full size
const WILT_SHARE := 0.4     # the last part of a ripe crop's time over which it wilts before it withers
const FROM_LEAST := 0.3     # a stage never starts smaller than this of its full size..
const FROM_MOST := 0.95     # ..nor bigger (it must still have growing to do)
const POP_HEIGHT := 0.5    # how high harvested plants spring before vanishing
const POP_TIME := 0.42
const FERTILIZED_SIZE := 1.18     # fertilised plants grow bigger (the shader applies it)
const VARY_LEAN := 0.16    # radians a plant may lean
const PLANT_SCALE := 3.1    # plants are modelled at about a fifth of a tile; on the farm they fill their bed
const PLANT_FLOATS := 20    # a plant in the MultiMesh buffer: transform (12), colour (4), data (4)

static var _start := {}   # form|stage -> the size that stage starts at (start_size), measured once

var wind := 0.6: set = _set_wind
var _due := -1   # the soonest time (Game.now) any plot's plants change look on their own; -1: none will

var _mastered := {}   # crop id -> how far it is mastered, for the plots of one laying (update)
var _layers := {}   # "shape|stage|colour" -> MultiMeshInstance3D
var _material: ShaderMaterial
var _materials := {}   # colour -> that colour's material (material_for)
var _base := 0.0    # the farm clock's zero: seconds count from here, so a shader's floats stay precise
var _plot_look := {}   # plot index -> [group key, packed data]: what its plants look like now
var _plot_chunk := {}  # plot index -> its plants as MultiMesh buffer data (_chunk), kept ready
var _members := {}     # group key -> {plot index: true}: the plots each group draws
var _size := -1        # the farm size last drawn (a smaller one drops the plants past its edge)


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = CROP_SHADER
	_material.set_shader_parameter("rich_size", FERTILIZED_SIZE)
	_base = floorf(_now())
	var timer := Timer.new()
	timer.wait_time = GROW_CHECK
	timer.autostart = true
	timer.timeout.connect(_on_clock)
	add_child(timer)
	Quality.notifier.emitted.connect(_apply_shadows)
	rebuild()


## Each GROW_CHECK: nothing but a comparison until the soonest plot is due to change look (a stage, ripeness,
## withering); then the field is looked at again (only plots whose look moved are laid out) and the next due
## time worked out. A plot that changes in between is updated by Farm3D and moves the due time itself.
func _on_clock() -> void:
	if _due >= 0 and Game.now() >= _due:
		update()


## When plot `i`'s plants next change look on their own, or -1: a growing crop's next stage (sprout, young,
## ripe), a ripe one's withering.
static func next_change(i: int) -> int:
	var at := Game.field.next_phase_at(i)
	if Game.field.phase(i) == GameState.Phase.GROWING:
		var plot: Dictionary = Game.plots[i]
		var grow := float(Game.crops[plot["crop"]]["grow_seconds"])
		for share: float in [SPROUT_FROM, YOUNG_FROM, RIPEN_FROM]:
			var t := int(plot["planted_at"]) + ceili(share * grow)
			if t > Game.now():
				return t
	return at


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
## A plant's instance data for the shader (crop3d): when its stretch began and how long it lasts (seconds on the
## farm clock; a negative length is wilting), whether it is fertilised, how far its crop is mastered (0..1), the
## size it grows from (of full size, under 1) and whether its fruit is ripening (taking its colour as it grows).
static func pack(started: float, length: float, rich: bool, mastered := 0.0, from := 0.0, ripening := false) -> Color:
	return Color(started / 60.0, length / 60.0, (1.0 if rich else 0.0) + clampf(from, 0.0, FROM_MOST),
		(1.0 if ripening else 0.0) + clampf(mastered, 0.0, 1.0) * 0.9)


## How far mastered the crop of a packed plant is (0..1), read back from `pack`'s data.
static func mastered_in(data: Color) -> float:
	return fposmod(data.a, 1.0) / 0.9


## The size a stage of a crop's form starts at, of its full size: the height the stage before it ended at, so
## the plant never jumps as its model changes (a young plant comes up as tall as the sprout it grew from, the
## ripe plant as tall as the young one). Measured once per form from the models themselves.
static func start_size(form: String, stage: String) -> float:
	var key := form + "|" + stage
	if not _start.has(key):
		var before := "sprout" if stage == "young" else "young"
		var was := CropModels.mesh(form, before).get_aabb().size.y
		var now := CropModels.mesh(form, stage).get_aabb().size.y
		_start[key] = clampf(was / now if now > 0.0 else 1.0, FROM_LEAST, FROM_MOST)
	return _start[key]


## How far a crop is mastered, 0..1 (its stars of all it can earn): its plants stand fuller and take a golden
## cast in the field (the shader's), so mastery shows on the farm.
static func mastered(crop_id: String) -> float:
	var most := Game.mastery.thresholds(crop_id).size()
	return float(Game.mastery.stars(crop_id)) / most if most > 0 else 0.0


## The material for a crop colour: the shared one with that colour set, made once.
## A crop as its picture shows it (ItemIcons, the seed shelf): one ripe bed of it, as the farm draws it.
static func picture_model(id: String) -> Node3D:
	var crop: Dictionary = Game.crops.get(id, {})
	if crop.is_empty():
		return null
	var root := Node3D.new()
	var bed := MeshInstance3D.new()
	bed.mesh = Plots3D.bed_mesh()
	bed.material_override = Plots3D.soil_material()
	bed.position = Vector3(0.5, 0, 0.5)
	root.add_child(bed)
	var mat := ShaderMaterial.new()
	mat.shader = CROP_SHADER
	mat.set_shader_parameter("produce_colour", Color.html(str(crop.get("color", "#e2453c"))))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = CropModels.mesh(CropForms.form_of(id, str(crop.get("shape", "berry"))), "ripe")
	var spots := spots_of(id)
	mm.instance_count = spots.size()
	for k in spots.size():
		var spot: Vector2 = spots[k]
		mm.set_instance_transform(k, Transform3D(_basis_for(spots.size(), float(k * 13 % 17) / 17.0 * TAU, k),
			Vector3(0.5 + spot.x, Plots3D.HEIGHT, 0.5 + spot.y)))
		mm.set_instance_custom_data(k, pack(0.0, 0.0, false))
	var plants := MultiMeshInstance3D.new()
	plants.multimesh = mm
	plants.material_override = mat
	root.add_child(plants)
	return root


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


## Where a plot's plants stand, from its middle: three rows of three, or once in the middle for a crop drawn a
## plot at a time (CropForms.is_plot: its form lays out the whole plot).
static func spots_of(crop_id: String) -> Array:
	return ONE_SPOT if CropForms.is_plot(CropForms.form_of(crop_id, "")) else SPOTS


## A plant's turn, size and lean, each its own; a crop drawn a plot at a time (`count` 1) stands square and true,
## turned by quarters, so its plots join edge to edge.
static func _basis_for(count: int, turn: float, seed_value: int) -> Basis:
	if count > 1:
		return _plant_basis(turn, PLANT_SCALE, seed_value)
	return Basis(Vector3.UP, floorf(turn / (PI / 2.0)) * PI / 2.0).scaled(Vector3.ONE * PLANT_SCALE)


## What a plot's plants are drawn as, and the stretch of time they are changing over:
## [model, from, length, start size, ripening]. `model` is the stage whose model is drawn ("seeds", "sprout",
## "young", "ripe", "withered"; "" none). `from` and `length` (unix seconds) are the stretch: a positive length is
## growing (from `start size` of full size to full), a negative one is a ripe crop wilting towards withering,
## 0 neither. `ripening`: the ripe plant drawn while still growing, its fruit colouring up. So a crop's life is
## one smooth change: seeds, a sprout coming up, a young plant taking over at the sprout's height, the ripe plant
## taking over at the young one's with green fruit that colours as it ripens, then (left too long) a slow wilt.
static func stage_of(i: int) -> Array:
	var plot: Dictionary = Game.plots[i]
	match Game.field.phase(i):
		GameState.Phase.RIPE:
			var crop: Dictionary = Game.crops[plot["crop"]]
			var window := float(Game.field.window_of(plot, crop))
			var wither_at := float(plot["planted_at"]) + float(crop["grow_seconds"]) + window
			return ["ripe", wither_at - WILT_SHARE * window, -WILT_SHARE * window, 0.0, false]
		GameState.Phase.WITHERED:
			return ["withered", 0.0, 0.0, 0.0, false]
		GameState.Phase.GROWING:
			var planted := float(plot["planted_at"])
			var crop_id := str(plot["crop"])
			var grow := float(Game.crops[crop_id]["grow_seconds"])
			var g := Game.field.growth(i)
			if g < SPROUT_FROM:
				return ["seeds", 0.0, 0.0, 0.0, false]
			if g < YOUNG_FROM:
				return ["sprout", planted + SPROUT_FROM * grow, (YOUNG_FROM - SPROUT_FROM) * grow, SPROUT_START, false]
			var form := CropForms.form_of(crop_id, str(Game.crops[crop_id].get("shape", "berry")))
			if g < RIPEN_FROM:
				return ["young", planted + YOUNG_FROM * grow, (RIPEN_FROM - YOUNG_FROM) * grow,
					start_size(form, "young"), false]
			return ["ripe", planted + RIPEN_FROM * grow, (1.0 - RIPEN_FROM) * grow, start_size(form, "ripe"), true]
	return ["", 0.0, 0.0, 0.0, false]


## Brings the plants of plots `indices` up to date (all of them when empty): a plot whose look (form, stage,
## colour, growth timing, richness) is unchanged is skipped, and only the groups a plot left or joined are laid
## out again, from per-plot pieces kept ready. So plowing, planting or harvesting one plot touches one or two
## groups, not the whole field, and the clock looks again only when the soonest plot is due (`_on_clock`).
func update(indices: Array = []) -> void:
	_mastered.clear()
	var whole := indices.is_empty()
	if whole:
		indices = _all_plots()
		_due = -1   # (worked out again below from every plot)
	if _size != Game.farm_size:
		# A smaller farm (after a reset or load): what was drawn past its new edge goes too.
		_size = Game.farm_size
		indices = indices.duplicate()
		for i: int in _plot_look:
			if not Game.on_farm(i):
				indices.append(i)
	var dirty := {}
	for i: int in indices:
		var now := _look_of(i) if Game.on_farm(i) else []
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
	for i: int in indices:
		var t := next_change(i) if Game.on_farm(i) else -1
		if t >= 0 and (_due < 0 or t < _due):
			_due = t


## The soonest time (Game.now) a plot's plants change look on their own, or -1 (for tests).
func due() -> int:
	return _due


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
	if not _mastered.has(crop_id):   # (asked once per crop per laying, not once per plot)
		_mastered[crop_id] = mastered(crop_id)
	return [key, pack(float(st[1]) - _base, float(st[2]), Game.field.is_fertilized(i), _mastered[crop_id],
		float(st[3]), bool(st[4]))]


## Plot `i`'s plants as MultiMesh buffer data: for each, its transform (3 rows of 4), its colour, its data.
static func _chunk(i: int, data: Color) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var r := GameState.row_of(i)
	var c := GameState.col_of(i)
	var spots := spots_of(str((Game.plots[i] as Dictionary).get("crop", "")))
	for k in spots.size():
		var spot: Vector2 = spots[k]
		var turn := float((i * 7 + k * 13) % 17) / 17.0 * TAU
		var b := _basis_for(spots.size(), turn, i * 5 + k)
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
	var spots := spots_of(crop_id)
	mm.instance_count = spots.size()
	for k in spots.size():
		var spot: Vector2 = spots[k]
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * PLANT_SCALE), Vector3(spot.x, 0, spot.y)))
		mm.set_instance_custom_data(k, pack(0.0, 0.0, false))
		mm.set_instance_color(k, Color.WHITE)
	var ghost := MultiMeshInstance3D.new()
	ghost.multimesh = mm
	ghost.material_override = material_for(Color.html(str(crop.get("color", "#e2453c"))))
	var r := GameState.row_of(i)
	var c := GameState.col_of(i)
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
