class_name LookModels
extends RefCounted
## The models the look tools draw (contact sheets, state sheets, the look test): every item as the farm shows it, in
## each state it can be seen in. One place, so the tools can't drift apart from each other or from the game.

const ANIMAL_ZOOM := 3.0   # animals and vehicles are small: shown bigger
const CROP_ZOOM := 2.2     # crops are small too
const BUILDING_STATES: Array[String] = ["frame", "empty", "half", "full"]


## Every case worth looking at: [{"id", "state"}]. Buildings in each of their states, crops as a young, ripe and
## withered row, everything else once.
static func cases() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in Game.item_order:
		var kind := str(Game.items[id].get("kind", ""))
		if kind in ["building", "barn", "crafting"]:
			for state in BUILDING_STATES:
				if state != "frame" or Game.items[id].has("build_materials"):
					out.append({"id": id, "state": state})
		else:
			out.append({"id": id, "state": "default"})
	for id: String in Game.crops:
		out.append({"id": id, "state": "row"})
	return out


static func is_crop(id: String) -> bool:
	return Game.crops.has(id) and not Game.items.has(id)


## How big a case is drawn so it fills its cell: big buildings shrink to fit, small things are zoomed.
static func fit_scale(id: String) -> float:
	if is_crop(id):
		return CROP_ZOOM
	var kind := str(Game.items[id].get("kind", ""))
	if kind in ["animal", "vehicle"]:
		return ANIMAL_ZOOM
	var fp := Game.footprint(id)
	return minf(3.0 / maxf(maxf(fp.x, fp.y), 1.0), 1.6)


## The model of a case with its feet at the origin's footprint corner (callers place it with `foot`).
static func model(id: String, state := "default", uid := 7) -> Node3D:
	if is_crop(id):
		return crop_row(id)
	var it := Game.item_data(id)
	var fp := Game.footprint(id)
	match str(it.get("kind", "")):
		"animal":
			var a := Animal3D.create(it, null, Vector3(fp.x / 2.0, 0, fp.y / 2.0))
			a.update(0.016)
			var wrap := Node3D.new()
			wrap.add_child(a)
			return wrap
		"tree":
			var t := Node3D.new()
			TreeModel.build_at(t, Vector3(fp.x / 2.0, 0, fp.y / 2.0), it, ScaleGuide.factor(id), true, 7 + hash(id) % 50)
			return ModelKit.bake(t)
		"vehicle":
			return VehicleModel.build(it, false)
		"decor":
			return DecorModel.build(it, fp, {"id": id, "uid": uid})
		"bloom":
			return BloomModel.build(it, {"id": id, "uid": uid, "t": Game.now() - int(it.get("cycle_seconds", 86400)) - 1})
		"young":
			return DecorModel.build_young(it, {"id": id, "uid": uid, "fed": 4}, 0.5)
	return building(id, state, uid)


## A building in a state, as the farm draws it (model and what fills it): a frame half built, empty, half
## full (part way through its cycle), or full and ready. Null for a frame of something that has none.
## What fills it is put on the farm (`Game.set_objects([])` clears it between pages).
static func building(id: String, state: String, uid: int) -> Node3D:
	var it := Game.item_data(id)
	var fp := Game.footprint(id)
	var level := Game.max_level(id)
	if state == "frame":
		if not it.has("build_materials"):
			return null
		return ModelKit.bake(BuildingModel.build_site(it, fp, 0.5))
	var cycle := Game.cycle_of({"id": id})
	var o := {"id": id, "uid": 9000 + uid, "row": 0, "col": 0, "level": level, "inside": {}}
	o["t"] = Game.now() - (cycle + 1 if state == "full" else cycle / 2 if state == "half" else 0)
	if state != "empty" and state != "default":
		var cap := Game.capacity(o) if Game.is_building(o) else 0
		var want := cap if state == "full" else cap / 2
		var takes: Array[String] = []
		for k in Game.item_order:
			if Game.building_accepts(o, k) and not Game.items[k].has("rare_of") and not Game.items[k].has("single_of"):
				takes.append(k)
		var n := 0
		while n < want and not takes.is_empty():
			var k: String = takes[n % mini(takes.size(), 3)]
			o["inside"][k] = int(o["inside"].get(k, 0)) + 1
			n += 1
	Game.add_object(o)
	var node := ModelKit.bake(BuildingModel.build(it, fp, level))
	if BuildingFill.shows(o):
		node.add_child(BuildingFill.create(o, node))
	return node


## A crop at young, ripe and withered side by side, as the field draws it (crop material, produce coloured).
static func crop_row(id: String) -> Node3D:
	var crop: Dictionary = Game.crops[id]
	var form := CropForms.form_of(id, str(crop.get("shape", "berry")))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/crop3d.gdshader")
	var row := Node3D.new()
	for k in 3:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = CropModels.mesh(form, ["young", "ripe", "withered"][k])
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ONE * Crops3D.PLANT_SCALE), Vector3(k * 1.0, 0, 0)))
		mm.set_instance_custom_data(0, Color.html(str(crop.get("color", "#e2453c"))))
		mmi.multimesh = mm
		mmi.material_override = mat
		row.add_child(mmi)
	return row
