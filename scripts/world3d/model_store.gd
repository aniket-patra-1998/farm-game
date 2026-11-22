class_name ModelStore
extends RefCounted
## Built models kept on disk, so a farm opens without building them again (our own engineering: every model is
## made in code, which costs seconds on a phone for a big farm). A look is built once, saved as a scene and
## loaded next time: the ones the showcase farm uses come in the game itself (res://baked, made by CI with
## tools/bake_models.tscn before the phone build), the rest are saved on the phone the first time they are
## built (user://models). Both are keyed by the build's stamp (res://baked/stamp.txt, the commit it was built
## from), so a new version never shows an old model. Without a stamp (running from the editor, tests) nothing
## is kept: models are always built fresh. Used by Instancer, which every repeated model goes through.
##
## Materials: a loaded model's materials are matched to the ones already in use with the same shader and
## settings (`_shared`), so models loaded from disk share materials as built ones do.

const SHIPPED := "res://baked"
const STAMP_FILE := "res://baked/stamp.txt"
const KEPT := "user://models"

static var stamp := ""            # the build's stamp; "" turns the store off
static var target := ""           # where new models are saved ("" = the phone's own store)
static var loaded := 0            # models loaded this session (for the probes)
static var saved := 0
static var _ready := false
static var _shared := {}          # material signature -> the material in use


## The model for `key`: loaded when kept, else built by `build` (a Node3D, never in the tree) and kept.
static func cached(key: String, build: Callable) -> Node3D:
	var kept := fetch(key)
	if kept != null:
		return kept
	var built: Node3D = build.call()
	if built != null:
		keep(key, built)
	return built


## The model kept for `key`, or null (none kept, or the store is off). For things built over several frames
## (the woods): ask first, build when null, then `keep` what was built.
## Whether a model is kept for `key` (in the game or on the phone), without loading it.
static func has(key: String) -> bool:
	_start()
	if stamp == "":
		return false
	var file := key.md5_text() + ".scn"
	for dir: String in [SHIPPED, _own_dir()]:
		if FileAccess.file_exists(dir + "/" + file) or ResourceLoader.exists(dir + "/" + file):
			return true
	return false


static func fetch(key: String) -> Node3D:
	_start()
	if stamp == "":
		return null
	var file := key.md5_text() + ".scn"
	for dir: String in [SHIPPED, _own_dir()]:
		var path := dir + "/" + file
		if FileAccess.file_exists(path) or ResourceLoader.exists(path):
			var scene := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			if scene != null:
				var node := scene.instantiate() as Node3D
				if node != null:
					_relink(node)
					loaded += 1
					return node
	return null


## Keeps `node` (built, not in the tree yet) for `key`; does nothing while the store is off.
static func keep(key: String, node: Node3D) -> void:
	_start()
	if stamp != "":
		_keep(node, (target if target != "" else _own_dir()) + "/" + key.md5_text() + ".scn")


## Reads the build's stamp once and clears models kept under another one.
static func _start() -> void:
	if _ready:
		return
	_ready = true
	if stamp == "" and FileAccess.file_exists(STAMP_FILE):
		stamp = FileAccess.get_file_as_string(STAMP_FILE).strip_edges()
	if stamp == "" or target != "":
		return
	DirAccess.make_dir_recursive_absolute(_own_dir())
	for old in DirAccess.get_directories_at(KEPT):
		if old != stamp:
			_remove_tree(KEPT + "/" + old)


static func _own_dir() -> String:
	return KEPT + "/" + stamp


static func _keep(node: Node3D, path: String) -> void:
	_own_all(node, node)
	var scene := PackedScene.new()
	if scene.pack(node) != OK:
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) == OK:
		saved += 1


static func _own_all(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own_all(c, owner)


## Points every material of a loaded model at the one in use with the same settings.
static func _relink(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for k in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(k)
			if m != null:
				mi.set_surface_override_material(k, _one_of(m))
		if mi.material_override != null:
			mi.material_override = _one_of(mi.material_override)
	for c in node.get_children():
		_relink(c)


static func _one_of(m: Material) -> Material:
	var sig := signature(m)
	if sig == "":
		return m
	if not _shared.has(sig):
		_shared[sig] = m
	return _shared[sig]


## What makes a material look as it does, or "" when it can't be told by its settings (a picture made at run
## time: such a material is kept as loaded).
static func signature(m: Material) -> String:
	var parts := PackedStringArray([m.get_class()])
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		if sm.shader == null or sm.shader.resource_path == "":
			return ""
		parts.append(sm.shader.resource_path)
		for u in sm.shader.get_shader_uniform_list():
			var v: Variant = sm.get_shader_parameter(u["name"])
			if v is Texture and (v as Texture).resource_path == "":
				return ""
			parts.append("%s=%s" % [u["name"], (v as Resource).resource_path if v is Resource else str(v)])
		return "|".join(parts)
	for p in m.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var v: Variant = m.get(p["name"])
		if v is Texture and (v as Texture).resource_path == "":
			return ""
		parts.append("%s=%s" % [p["name"], (v as Resource).resource_path if v is Resource else str(v)])
	return "|".join(parts)


static func _remove_tree(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_remove_tree(dir + "/" + d)
	DirAccess.remove_absolute(dir)
