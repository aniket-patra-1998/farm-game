class_name AssetRegistry
extends RefCounted
## The one way the game asks for an asset made as a file (docs/ASSETS.md §5): an item's id -> its model, from
## data/assets.json. `instance` gives a ready node, or null when the item has no file yet (or the file is
## missing or broken: said once), and the caller draws its code-built stand-in, so art can move to files one
## item at a time and nothing ever breaks. Nothing else knows an asset's path.
##
## Rules applied to every file as it is drawn: every plain material becomes an instance of the master
## material (shaders/master_solid.gdshader) with the same colour and texture, so every asset matches and takes
## the weather and night; a material the artist chose on purpose (a ShaderMaterial: water, glass, foliage) is
## kept. Godot's importer has already made the levels of detail and shadow meshes (its defaults).
##
## States (docs/ASSETS.md §10.4): a part named `when_<state>_<value>` (`when_level_2`, `when_ready_true`,
## `when_stage_1`) shows only while the thing is in that state; everything else always shows.

const DATA := "res://data/assets.json"
const MASTER := preload("res://shaders/master_solid.gdshader")
const STATE := "when_"

static var _data := {}
static var _read := false
static var _scenes := {}     # path -> PackedScene, its materials already made masters
static var _masters := {}    # colour and texture -> the master material instance for them
static var _said := {}       # paths already reported missing or broken
static var _extra := {}      # entries added at run time (tests)


## Item `id`'s entry ({"model": path, "budget": kind...}), or {} when it is drawn by its stand-in.
static func entry(id: String) -> Dictionary:
	_load()
	if _extra.has(id):
		return _extra[id]
	return (_data.get("assets", {}) as Dictionary).get(id, {})


## Whether item `id` is drawn from a file now (listed and loadable).
static func has_model(id: String) -> bool:
	var e := entry(id)
	return not e.is_empty() and _scene(str(e.get("model", ""))) != null


## A new node of item `id`'s model in `state` ({"level": 2, "ready": true}...), or null (draw the stand-in).
static func instance(id: String, state := {}) -> Node3D:
	var e := entry(id)
	if e.is_empty():
		return null
	var scene := _scene(str(e.get("model", "")))
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	if node == null:
		_say(str(e["model"]), "is not a 3D scene")   # not-ui (a log line)
		return null
	_to_masters(node)   # (a mesh's own materials change once, as the mesh is shared; a node's overrides each time)
	apply_state(node, state)
	return node


## Shows the parts of `node` made for `state` and hides the ones made for another value of the same state.
static func apply_state(node: Node, state: Dictionary) -> void:
	for c in node.get_children():
		var n := String(c.name)
		if n.begins_with(STATE) and c is Node3D:
			var parts := n.trim_prefix(STATE).rsplit("_", true, 1)
			if parts.size() == 2:
				var key := parts[0]
				(c as Node3D).visible = state.has(key) and str(state[key]).to_lower() == parts[1].to_lower()
		apply_state(c, state)


## The triangle budget for item `id` (its entry's `budget` kind in data/assets.json), 0 when it has none.
static func budget_of(id: String) -> int:
	_load()
	var kind := str(entry(id).get("budget", ""))
	return int(((_data.get("budgets", {}) as Dictionary).get(kind, {}) as Dictionary).get("triangles", 0))


## Triangles drawn at the nearest level of detail under `node`.
static func triangles(node: Node) -> int:
	var n := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var index: Variant = arrays[Mesh.ARRAY_INDEX]
			n += (index as PackedInt32Array).size() / 3 if index != null \
				else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	for c in node.get_children():
		n += triangles(c)
	return n


## Lists an entry while the game runs (tests and tools); `{}` removes it.
static func add(id: String, e: Dictionary) -> void:
	if e.is_empty():
		_extra.erase(id)
	else:
		_extra[id] = e


## Lets loaded files go (tests, and a file changed while running).
static func forget() -> void:
	_scenes.clear()
	_said.clear()


static func _load() -> void:
	if _read:
		return
	_read = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if parsed is Dictionary:
		_data = parsed
	else:
		push_error(DATA + " is missing or not valid JSON")


## The file at `path`, loaded once; null (said once) when it can't be loaded.
static func _scene(path: String) -> PackedScene:
	if _scenes.has(path):
		return _scenes[path]
	if path == "" or not ResourceLoader.exists(path):
		_say(path, "is missing")   # not-ui (a log line)
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		_say(path, "is not a scene")   # not-ui (a log line)
		return null
	_scenes[path] = scene
	return scene


static func _to_masters(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m is BaseMaterial3D:
				mi.mesh.surface_set_material(s, master_for(m as BaseMaterial3D))
			var o := mi.get_surface_override_material(s)
			if o is BaseMaterial3D:
				mi.set_surface_override_material(s, master_for(o as BaseMaterial3D))
		if mi.material_override is BaseMaterial3D:
			mi.material_override = master_for(mi.material_override as BaseMaterial3D)
	for c in node.get_children():
		_to_masters(c)


## The master material with `m`'s colour and texture (shared by everything with the same two).
static func master_for(m: BaseMaterial3D) -> ShaderMaterial:
	var tex := m.albedo_texture
	var key := "%s|%s" % [m.albedo_color.to_html(), tex.get_rid() if tex != null else ""]
	if not _masters.has(key):
		var sm := ShaderMaterial.new()
		sm.shader = MASTER
		sm.set_shader_parameter("albedo", Color(m.albedo_color.r, m.albedo_color.g, m.albedo_color.b))
		if tex != null:
			sm.set_shader_parameter("albedo_texture", tex)
			sm.set_shader_parameter("use_texture", true)
		_masters[key] = sm
	return _masters[key]


static func _say(path: String, what: String) -> void:
	if _said.has(path):
		return
	_said[path] = true
	push_warning("asset %s %s: drawing its stand-in" % [path, what])
