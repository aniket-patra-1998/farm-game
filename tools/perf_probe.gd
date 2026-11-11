extends Node
## Performance probe: opens the showcase farm in the real main scene and reports what a frame costs
## (script time, draw calls, objects, nodes) and how long opening took. Run with a renderer for draw calls:
##   xvfb-run godot --rendering-method gl_compatibility --path . res://tools/perf_probe.tscn
## Headless (godot --headless ...), wall time per frame is the CPU cost; draw calls need the renderer.

const WARM_FRAMES := 30

const SAMPLE_FRAMES := 120
const HEAVY_TRIS := 25000     # an object this heavy is listed by name




func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	Game.open_showcase()
	var t_build := Time.get_ticks_usec() - t0
	var stress := "--stress" in OS.get_cmdline_user_args()
	if stress:
		print("PERF stress: %d things in storage" % ShowcaseFarm.fill_storage(Game))
		_storage_costs()
	await get_tree().process_frame
	var t_first := Time.get_ticks_usec() - t0
	for i in WARM_FRAMES:
		await get_tree().process_frame
	var draws := 0
	var objs := 0
	var prims := 0
	var last := Time.get_ticks_usec()
	var frame_worst := 0
	var t_sample := last
	for i in SAMPLE_FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame_worst = maxi(frame_worst, now - last)
		last = now
		draws = maxi(draws, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		objs = maxi(objs, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		prims = maxi(prims, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var meshes := 0
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D or n is MultiMeshInstance3D:
			meshes += 1
		stack.append_array(n.get_children())
	print("PERF objects_on_farm=%d build_ms=%.0f first_frame_ms=%.0f"
		% [Game.objects.size(), t_build / 1000.0, t_first / 1000.0])
	print("PERF frame_ms avg=%.2f worst=%.1f (headless: wall time per frame = CPU cost)"
		% [(last - t_sample) / 1000.0 / SAMPLE_FRAMES, frame_worst / 1000.0])
	print("PERF draw_calls=%d render_objects=%d primitives=%d mesh_nodes=%d nodes=%d" % [draws, objs, prims, meshes,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	_breakdown()
	await _processing()
	get_tree().quit()




## What a full barn and gift box cost to save, load and list.
func _storage_costs() -> void:
	var t := Time.get_ticks_usec()
	Game.save_game()
	print("PERF   save_game: %.1fms (%d bytes)" % [(Time.get_ticks_usec() - t) / 1000.0,
		FileAccess.get_file_as_bytes(Game.save_path).size()])
	t = Time.get_ticks_usec()
	Game.load_game()
	print("PERF   load_game: %.1fms" % [(Time.get_ticks_usec() - t) / 1000.0])
	var hud := _find(get_tree().root, "FarmHud")
	if hud != null:
		var box := VBoxContainer.new()
		add_child(box)
		t = Time.get_ticks_usec()
		hud._build_barn_storage(box)
		print("PERF   barn panel build: %.1fms, %d nodes" % [(Time.get_ticks_usec() - t) / 1000.0, _count(box).z])
		box.queue_free()


## Mesh nodes and triangles under each part of the 3D farm, and under each kind of object.
func _breakdown() -> void:
	var farm := _find(get_tree().root, "Farm3D")
	if farm == null:
		return
	for part in farm.get_children():
		var c := _count(part)
		print("PERF part %s %s: mesh_nodes=%d tris=%d nodes=%d" % [part.name, part.get_class(), c.x, c.y, c.z])
		if "_views" in part:
			var kinds := {}
			for uid in part._views:
				var o := Game.object_by_uid(uid)
				var k := Game.kind_of(o)
				var cc := _count(part._views[uid]["node"])
				var cur: Vector4i = kinds.get(k, Vector4i.ZERO)
				kinds[k] = cur + Vector4i(cc.x, cc.y, cc.z, 1)
				if cc.y >= HEAVY_TRIS:
					print("PERF    heavy %s: surfaces=%d tris=%d nodes=%d" % [o["id"], cc.x, cc.y, cc.z])
			for k in kinds:
				print("PERF    kind %s (surfaces, tris, nodes, count) = %s" % [k, kinds[k]])




func _find(n: Node, cls: String) -> Node:
	if n.get_script() != null and (n.get_script() as Script).get_global_name() == cls:
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f != null:
			return f
	return null




func _count(n: Node) -> Vector3i:
	var out := Vector3i.ZERO
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var m: Node = stack.pop_back()
		out.z += 1
		if m is MeshInstance3D and (m as MeshInstance3D).mesh != null:
			var mesh: Mesh = (m as MeshInstance3D).mesh
			out.x += mesh.get_surface_count()
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s)
				var idx = arr[Mesh.ARRAY_INDEX]
				out.y += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		elif m is MultiMeshInstance3D and (m as MultiMeshInstance3D).multimesh != null:
			out.x += 1
		stack.append_array(m.get_children())
	return out




## Which scripts run every frame and what each costs; then the jobs that run every few seconds.
func _processing() -> void:
	var by := {}
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if (n.is_processing() or n.is_physics_processing()) and n.get_script() != null:
			var path := (n.get_script() as Script).resource_path.get_file()
			var list: Array = by.get(path, [])
			list.append(n)
			by[path] = list
		stack.append_array(n.get_children())
	const RUNS := 30
	for path in by:
		var t := Time.get_ticks_usec()
		for r in RUNS:
			for n in by[path]:
				if n.has_method("_process"):
					n._process(1.0 / 60.0)
		print("PERF   %s x%d: %.2fms a frame" % [path, by[path].size(), (Time.get_ticks_usec() - t) / 1000.0 / RUNS])
	for pair in [["ObjectLayer", "refresh_all"], ["Crops3D", "rebuild"], ["Plots3D", "rebuild"], ["Ground3D", "rebuild"]]:
		var n := _find(get_tree().root, pair[0])
		if n != null:
			var t := Time.get_ticks_usec()
			for r in 3:
				n.call(pair[1])
			print("PERF   %s.%s: %.2fms" % [pair[0], pair[1], (Time.get_ticks_usec() - t) / 1000.0 / 3])
	var o := _find(get_tree().root, "Objects3D")
	if o != null:
		var t := Time.get_ticks_usec()
		for r in 5:
			o.sync()
		print("PERF   Objects3D.sync (every second): %.2fms" % ((Time.get_ticks_usec() - t) / 1000.0 / 5))
