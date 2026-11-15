extends SceneTree
## Writes tests/fixtures/asset_fixture.glb: a small building made as a glTF file, with a state part, a door and a
## window, so the tests go through Godot's real import (levels of detail, shadow meshes) and the registry's
## rules. Run once when the fixture's shape needs to change:
##   godot --headless --path . -s tools/make_asset_fixture.gd

const OUT := "res://tests/fixtures/asset_fixture.glb"


func _init() -> void:
	var root := Node3D.new()
	root.name = "asset_fixture"
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.8, 0.3, 0.25)
	var body := ModelKit.box(root, Vector3(-0.8, 0, -0.8), Vector3(0.8, 1.0, 0.8), paint)
	body.name = "body"
	var ready := Node3D.new()
	ready.name = "when_ready_true"
	root.add_child(ready)
	var flag := StandardMaterial3D.new()
	flag.albedo_color = Color(0.95, 0.85, 0.2)
	ModelKit.box(ready, Vector3(-0.1, 1.0, -0.1), Vector3(0.1, 1.4, 0.1), flag).name = "flag"
	var door := MeshInstance3D.new()
	door.name = "door"
	door.mesh = BoxMesh.new()
	door.scale = Vector3(0.4, 0.6, 0.05)
	door.position = Vector3(0, 0.3, 0.82)
	root.add_child(door)
	var window := Node3D.new()
	window.name = "window_1"
	window.position = Vector3(0.4, 0.7, 0.81)
	root.add_child(window)
	for c in root.get_children():
		_own(c, root)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_scene(root, state) == OK and doc.write_to_filesystem(state, OUT) == OK:
		print("wrote " + OUT)
	root.free()
	quit()


func _own(n: Node, owner: Node) -> void:
	n.owner = owner
	for c in n.get_children():
		_own(c, owner)
