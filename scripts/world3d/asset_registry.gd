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
const LEVEL := "{level}"   # not-ui (in a model path: the level's number goes here, a file for each level)
const STAGE := "{stage}"   # not-ui (in a site's path: the construction stage's number)
## The master's parameters for the materials a builder's file names (ModelKit.FILE_PAINT, FILE_WALL): painted
## parts carry their shine in their vertex alpha and are lit as the builders' paint is; patterned surfaces carry
## their pattern there.
const NAMED := {
	"paint": {"alpha_holds": 1, "ground_ao": 0.32, "edge": 0.4},
	"wall": {"alpha_holds": 2},
}

## Whether files load on worker threads (preload_files). Not without a screen (tests, tools): the stand-in renderer
## there keeps its meshes unsafely for threads, and meshes made on two threads at once broke each other (engine
## errors in about one precheck in two). Test 453 turns it on for its own few files.
static var threaded := DisplayServer.get_name() != "headless"   # not-ui (a display server's name)
static var fetches := true   # whether a file left out of the app has its pack fetched when asked for (IconMaker)
static var _data := {}
static var _read := false
static var _scenes := {}     # path -> PackedScene, its materials already made masters
static var _masters := {}    # colour and texture -> the master material instance for them
static var _said := {}       # paths already reported missing or broken
static var _extra := {}      # entries added at run time (tests)
static var _loading := {}    # paths asked of the loader's threads (preload_files), not yet taken


## Item `id`'s entry ({"model": path, "budget": kind...}), or {} when it is drawn by its stand-in.
static func entry(id: String) -> Dictionary:
	_load()
	if _extra.has(id):
		return _extra[id]
	return (_data.get("assets", {}) as Dictionary).get(id, {})


## Every item id listed (data/assets.json), in its order.
static func ids() -> Array:
	_load()
	return (_data.get("assets", {}) as Dictionary).keys()


## Whether item `id` is drawn from a file now (listed and loadable).
static func has_model(id: String) -> bool:
	var e := entry(id)
	return not e.is_empty() and _scene(file_of(e, {})) != null


## A new node of item `id`'s model in `state` ({"level": 2, "ready": true}...), or null (draw the stand-in).
static func instance(id: String, state := {}) -> Node3D:
	var e := entry(id)
	if e.is_empty():
		return null
	var scene := _scene(file_of(e, state))
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	if node == null:
		_say(file_of(e, state), "is not a 3D scene")   # not-ui (a log line)
		return null
	ModelKit.adopt(node)   # (the kit's own glass, light pools, shade and water, by the names the file gives them)
	_to_masters(node)   # (a mesh's own materials change once, as the mesh is shared; a node's overrides each time)
	DecorMotion.dress(node)   # (named parts: smoke rises, sails turn)
	for c in node.get_children():
		if String(c.name).begins_with(STATE + "fill"):
			ModelKit.no_shadows(c)   # (a storage look is small things: no shadow pass of its own)
	apply_state(node, state)
	return node


## The file entry `e` is drawn from in `state`. A model path with `{level}` in it is a file for each level
## (a building: only the level that stands is loaded).
static func file_of(e: Dictionary, state: Dictionary) -> String:
	if state.has("stage") and e.has("site"):
		return str(e["site"]).replace(STAGE, str(int(state["stage"])))   # (going up: a file for each stage)
	if bool(state.get("broken", false)) and e.has("broken"):
		return str(e["broken"])   # (standing broken: the starter Barn before it is repaired)
	return str(e.get("model", "")).replace(LEVEL, str(int(state.get("level", 1))))


## Whether `id`'s file is left out of the app and its pack is not on this device yet: what is drawn for it until
## then is its stand-in.
static func away(id: String) -> bool:
	var file := file_of(entry(id), {})
	return AssetPacks.shared != null and not ResourceLoader.exists(file) and AssetPacks.shared.away(file)


## Whether item `id` going up is drawn from files too (its entry's `site`).
static func has_site(id: String) -> bool:
	var e := entry(id)
	return e.has("site") and _scene(file_of(e, {"stage": 0})) != null


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


## Item `id`'s budget for `what` ("triangles" at the nearest level, or "draws": surfaces drawn), from its
## entry's `budget` kind in data/assets.json; 0 when it has none.
static func budget_of(id: String, what := "triangles") -> int:
	_load()
	var kind := str(entry(id).get("budget", ""))
	return int(((_data.get("budgets", {}) as Dictionary).get(kind, {}) as Dictionary).get(what, 0))


## Surfaces drawn under `node` (a draw each, before shadows).
static func draws(node: Node) -> int:
	if node is Node3D and not (node as Node3D).visible:
		return 0   # (a part for another state)
	var n := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as MeshInstance3D).visible:
		n += (node as MeshInstance3D).mesh.get_surface_count()
	for c in node.get_children():
		n += draws(c)
	return n


## Triangles drawn at the nearest level of detail under `node`.
static func triangles(node: Node) -> int:
	if node is Node3D and not (node as Node3D).visible:
		return 0   # (a part for another state)
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
	for path: String in _loading:
		ResourceLoader.load_threaded_get(path)   # (taken, so the loader lets it go)
	_loading.clear()
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


## Starts loading the files at `paths` on the engine's worker threads, all at once, so a farm opening with many
## kinds reads and unpacks them side by side instead of one after another as each is first built (`_scene` then
## takes each as it is done, waiting only if it is not yet). Paths already loaded, asked or missing are skipped.
## Only when `threaded`.
static func preload_files(paths: Array) -> void:
	if not threaded:
		return   # (each file is then loaded where it is first built, as before threaded loading)
	for path: String in paths:
		if path == "" or _scenes.has(path) or _loading.has(path) or not ResourceLoader.exists(path):
			continue
		if ResourceLoader.load_threaded_request(path, "PackedScene", true) == OK:   # not-ui (a type name)
			_loading[path] = true


## Whether item `id`'s file is read and ready to build from, at once (always, without threads or a file of its
## own). When not, it is asked of a worker thread: ask again each frame until it is (FarmGrid.start_placing does,
## so a thing picked in the Market is carried once its file is read, and the game never stops to read it; owner,
## 20 Nov: "whenever I place a limited animal on the farm the game lags").
static func file_ready(id: String) -> bool:
	var e := entry(id)
	if not threaded or e.is_empty():
		return true
	var path := file_of(e, {})
	if _scenes.has(path) or not ResourceLoader.exists(path):
		return true
	if not _loading.has(path):
		if ResourceLoader.load_threaded_request(path, "PackedScene", true) != OK:   # not-ui (a type name)
			return true
		_loading[path] = true
	return ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS


## The file at `path`, loaded once; null (said once) when it can't be loaded.
static func _scene(path: String) -> PackedScene:
	if _scenes.has(path):
		return _scenes[path]
	if path == "" or not ResourceLoader.exists(path):
		if AssetPacks.shared != null and AssetPacks.shared.want(path, fetches):
			return null   # (not in the app: its pack is on its way, and the stand-in is drawn until it arrives)
		_say(path, "is missing")   # not-ui (a log line)
		return null
	var scene: PackedScene = (ResourceLoader.load_threaded_get(path) if _loading.has(path) else load(path)) as PackedScene
	_loading.erase(path)
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
			if is_plain(m):
				mi.mesh.surface_set_material(s, master_for(m as BaseMaterial3D))
			var o := mi.get_surface_override_material(s)
			if is_plain(o):
				mi.set_surface_override_material(s, master_for(o as BaseMaterial3D))
		if is_plain(mi.material_override):
			mi.material_override = master_for(mi.material_override as BaseMaterial3D)
	for c in node.get_children():
		_to_masters(c)


## Whether `m` is a plain painted material the master material draws the same (opaque, lit, culled, no glow, no
## maps but its colour texture). Anything else the artist set on purpose (see-through, cut-out, two-sided,
## glowing, normal-mapped) is kept as it is.
static func is_plain(m: Material) -> bool:
	if not m is BaseMaterial3D:
		return false
	var b := m as BaseMaterial3D
	return (b.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and b.cull_mode == BaseMaterial3D.CULL_BACK
		and b.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and not b.emission_enabled
		and not b.normal_enabled and b.albedo_color.a >= 1.0)


## The master material with plain `m`'s colour, texture, roughness and metal (shared by everything with the same).
static func master_for(m: BaseMaterial3D) -> ShaderMaterial:
	var tex := m.albedo_texture
	var named := str(m.resource_name)
	var key := "%s|%s|%.2f|%.2f|%s" % [m.albedo_color.to_html(), tex.get_rid() if tex != null else "", m.roughness,
		m.metallic, named if NAMED.has(named) else ""]
	if not _masters.has(key):
		var sm := ShaderMaterial.new()
		sm.shader = MASTER
		sm.set_shader_parameter("albedo", Color(m.albedo_color.r, m.albedo_color.g, m.albedo_color.b))
		sm.set_shader_parameter("roughness", m.roughness)
		sm.set_shader_parameter("specular", lerpf(0.15, 0.5, m.metallic))
		if tex != null:
			sm.set_shader_parameter("albedo_texture", tex)
			sm.set_shader_parameter("use_texture", true)
		for param: String in (NAMED.get(named, {}) as Dictionary):
			sm.set_shader_parameter(param, NAMED[named][param])
		_masters[key] = sm
	return _masters[key]


static func _say(path: String, what: String) -> void:
	if _said.has(path):
		return
	_said[path] = true
	push_warning("asset %s %s: drawing its stand-in" % [path, what])
