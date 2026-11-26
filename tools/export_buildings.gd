class_name ExportBuildings
extends Node
## Exports the buildings that follow the building rules (CLAUDE.md) to glTF files (docs/ASSETS.md §1: art is
## made ahead of time as files, in the interchange format, and asked for by name through AssetRegistry), from
## the code builder that authors them
## (BuildingModel, BuildingDress). Godot's importer then gives each its lower-detail levels and shadow mesh.
##   art/models/buildings/<id>_<level>.glb        the building at that level, a file for each level
##   art/models/buildings/<id>_site_<stage>.glb   the building going up, a file for each stage
## What a file holds: meshes with plain materials named for what they are (ModelKit.FILE_PAINT, FILE_WALL and
## the LIVE names; each part's colour and finish ride in its vertex colours), states as parts named
## `when_working_true`, `when_fill_2`..., and named parts with nothing in them where the game starts an effect
## or turns something (`smoke_3`, `spin_55_2`: DecorMotion.start). A building animals live in also has
## its doors as parts named `door_<n>` (`door_<n>_left` swings the other way, `door_<n>_roll_<rise>` rolls up)
## and a part named `window_<n>` at each window a head can look out of, sized by its scale
## (Objects3D.mark_parts).
## Lists them in data/assets.json. Run: godot --headless --path . res://tools/export_buildings.tscn

const BUILDINGS := "res://art/models/buildings/"
const KINDS: Array[String] = ["crafting"]   # the kinds of building made as files so far..
const TYPES: Array[String] = ["harvesting", "storing"]   # ..and the types (Game.building_type)

const WINDOW := "window"   # not-ui (a part's name)
const MOVED_WHOLE := [DecorMotion.SPIN, DecorMotion.ORBIT]   # named parts that keep what is under them

static var _plain: Dictionary = {}   # the plain material written for each name


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BUILDINGS))
	var listed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AssetRegistry.DATA))
	var assets: Dictionary = listed["assets"]
	var n := 0
	for id: String in Game.item_order:
		if not exported(id):
			continue
		for level in range(1, Game.look_levels(id) + 1):
			_write(building(id, level), "%s%s_%d.glb" % [BUILDINGS, id, level])
			n += 1
		for stage in Objects3D.BUILD_STAGES:
			_write(site(id, stage), "%s%s_site_%d.glb" % [BUILDINGS, id, stage])
			n += 1
		assets[id] = {"model": "%s%s_%s.glb" % [BUILDINGS, id, AssetRegistry.LEVEL],
			"site": "%s%s_site_%s.glb" % [BUILDINGS, id, AssetRegistry.STAGE], "budget": "building"}
		if Game.building_def(id).can_break():
			_write(broken(id), "%s%s_broken.glb" % [BUILDINGS, id])
			assets[id]["broken"] = "%s%s_broken.glb" % [BUILDINGS, id]
			n += 1
	FileAccess.open(AssetRegistry.DATA, FileAccess.WRITE).store_string(JSON.stringify(listed, "  ", false) + "\n")
	print("exported %d building files" % n)   # not-ui (a tool's log)
	# The files are now what the builders make: record it (tools/make_art_versions.py).
	OS.execute("python3", [ProjectSettings.globalize_path("res://tools/make_art_versions.py"), "--exported",
		"buildings"])
	get_tree().quit()


## Whether building `id` is made as files.
static func exported(id: String) -> bool:
	return str(Game.items[id].get("kind", "")) in KINDS or Game.building_type(id) in TYPES


## Building `id` at `level` as its file holds it: every state, plain named materials, named parts left empty.
static func building(id: String, level: int) -> Node3D:
	var built := ModelKit.bake(BuildingModel.build(Game.item_data(id), Game.footprint(id), level, false))
	built.name = "%s_%d" % [id, level]
	_name_fill_parts(built)
	return _filed(built)


## Building `id` standing broken (the starter Barn before its repair), as its file holds it.
static func broken(id: String) -> Node3D:
	var built := ModelKit.bake(BuildingModel.build(Game.item_data(id), Game.footprint(id), 1, false, true))
	built.name = "%s_broken" % id
	return _filed(built)


## Building `id` going up, at `stage` of Objects3D.BUILD_STAGES, as its file holds it.
static func site(id: String, stage: int) -> Node3D:
	var built := ModelKit.bake(BuildingModel.build_site(Game.item_data(id), Game.footprint(id),
		stage / float(Objects3D.BUILD_STAGES)))
	built.name = "%s_site_%d" % [id, stage]
	return _filed(built)


## Names what the yard's life needs of a building (BuildingFill, through Objects3D.mark_parts): its doors, and a
## part at each window.
static func _name_fill_parts(built: Node3D) -> void:
	for c in built.get_children():
		if c.has_meta(BuildingModel.DOOR):
			c.name = "door_%d%s" % [c.get_index(), "_left" if float(c.get_meta(BuildingModel.DOOR)) < 0.0 else ""]
			if c.has_meta(BuildingModel.SLIDE):
				# (a shutter that rolls up: how far, in hundredths of a tile)
				c.name = "door_%d%s%d" % [c.get_index(), Objects3D.ROLL, roundi(float(c.get_meta(BuildingModel.SLIDE))
					* 100.0)]
		if c.has_meta(BuildingModel.WINDOWS):
			var spots: Array = c.get_meta(BuildingModel.WINDOWS)
			for k in spots.size():
				var part := Node3D.new()
				part.name = "window_%d" % k
				part.position = ((c as Node3D).transform * (spots[k]["at"] as Vector3))
				part.scale = Vector3.ONE * (float(spots[k]["size"]) / Objects3D.WINDOW_SIZE)
				built.add_child(part)


static func _filed(built: Node3D) -> Node3D:
	_for_file(built)
	_one_body(built)
	_name_parts(built)
	_own(built, built)
	return built


static func _write(root: Node3D, path: String) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_scene(root, state) != OK or doc.write_to_filesystem(state, path) != OK:
		push_error("could not write " + path)
	root.free()


## Joins the solid meshes that stand side by side under `n` (and under each state part) into one, a surface
## for each kind of material: the builder keeps them apart for reasons a file does not carry (which cast a
## shadow), and apart they are a draw each.
static func _one_body(n: Node) -> void:
	var solid: Array[String] = [ModelKit.FILE_PAINT, ModelKit.FILE_WALL, ModelKit.LIVE_GLASS, ModelKit.LIVE_YARD]
	var tools := {}
	var first: MeshInstance3D = null
	for c in n.get_children():
		if not c is MeshInstance3D or c.get_child_count() > 0:
			if not DecorMotion.is_part(c):
				_one_body(c)
			continue
		var mi := c as MeshInstance3D
		var joins := true
		for k in mi.mesh.get_surface_count():
			joins = joins and str(mi.mesh.surface_get_material(k).resource_name) in solid
		if not joins:
			continue
		for k in mi.mesh.get_surface_count():
			var named := str(mi.mesh.surface_get_material(k).resource_name)
			if not tools.has(named):
				tools[named] = SurfaceTool.new()
				(tools[named] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
			(tools[named] as SurfaceTool).append_from(mi.mesh, k, mi.transform)
		if first == null:
			first = mi
		else:
			n.remove_child(mi)
			mi.free()
	if first == null:
		return
	var mesh := ArrayMesh.new()
	for named: String in solid:
		if tools.has(named):
			(tools[named] as SurfaceTool).index()
			(tools[named] as SurfaceTool).commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _plain_for(named))
	first.transform = Transform3D.IDENTITY
	first.mesh = mesh
	first.name = "body"


## Makes `n` and all under it what a glTF file can carry: a named part keeps its name and place and loses the
## effect running under it; every mesh gets plain materials named for the ones it was drawn with.
static func _for_file(n: Node) -> void:
	for c in n.get_children():
		if c is Spinner or (DecorMotion.is_part(n) and not String(n.name).split("_")[0] in MOVED_WHOLE):
			n.remove_child(c)
			c.free()
			continue
		_for_file(c)
		# (a part with nothing in it and no name the game knows carries nothing: a marker only the builder reads)
		if c.get_child_count() == 0 and not c is MeshInstance3D and not DecorMotion.is_part(c) \
				and not String(c.name).begins_with(AssetRegistry.STATE) \
				and not String(c.name).begins_with(WINDOW):
			n.remove_child(c)
			c.free()
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		var mesh := ArrayMesh.new()
		for k in mi.mesh.get_surface_count():
			# (a part that goes round by its shader is carried as paint, its colours in its points: the game sets it
			# going again)
			var orbiting := String(n.get_parent().name).begins_with(DecorMotion.ORBIT + "_")
			var mat := mi.get_active_material(k)
			var named := ModelKit.FILE_PAINT if orbiting else ModelKit.file_name_of(mat)
			if named == "":
				push_error("a file cannot carry the material of %s under %s (surface %d: %s)" % [n.name,
					n.get_parent().name, k, (mat as ShaderMaterial).shader.resource_path if mat is ShaderMaterial
					else str(mat)])
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mi.mesh.surface_get_arrays(k))
			mesh.surface_set_material(k, _plain_for(named))
			mi.set_surface_override_material(k, null)
		mi.material_override = null
		mi.mesh = mesh


## Gives every part without a name of its own one a person can read (`mesh_2`), in the order they stand.
static func _name_parts(n: Node) -> void:
	for k in n.get_child_count():
		var c := n.get_child(k)
		if String(c.name).begins_with("@"):
			c.name = "%s_%d" % ["mesh" if c is MeshInstance3D else "part", k]
		_name_parts(c)


static func _plain_for(named: String) -> StandardMaterial3D:
	if not _plain.has(named):
		var m := StandardMaterial3D.new()
		m.resource_name = named
		m.vertex_color_use_as_albedo = true
		_plain[named] = m
	return _plain[named]


static func _own(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		_own(c, owner)
