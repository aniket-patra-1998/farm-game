extends TestSuite
## How a tree is drawn (scripts/world3d/tree_model.gd): its fruit, its leaves, a palm's fronds, a seedling's
## stages. The older rules of trees are in world3d_test.






func test_590_a_trees_fruit_sits_in_its_leaves_and_moves_with_them() -> void:
	# Few and big, in the crown (none hung under it on a stem), round from any distance, and riding the tree's
	# own bend in the wind (owner, 19 Nov: it looked stuck on, and stayed behind when the crown leant in a gust).
	var g := _farm()
	var holder := Node3D.new()
	add_child(holder)
	TreeModel.build_at(holder, Vector3.ZERO, g.item_data("apple_tree"), 1.0, true, 1)
	var fruit := holder.find_children("*", "MeshInstance3D", true, false).filter(
		func(n: Node) -> bool: return n.has_meta(ModelKit.FRUIT))
	_eq(fruit.size(), TreeModel.FRUIT_READY, "a full apple tree's fruit")
	var crown_low := INF
	for part in holder.find_children("*", "MeshInstance3D", true, false):
		var m := (part as MeshInstance3D).material_override as ShaderMaterial
		if m != null and m.shader != null and m.shader.resource_path == ModelKit.FOLIAGE_SHADER:
			crown_low = minf(crown_low, (part as MeshInstance3D).position.y)
	var lowest := INF
	for f: MeshInstance3D in fruit:
		lowest = minf(lowest, f.position.y)
	_check(lowest > crown_low - TreeModel.FRUIT_R, "none hangs under the crown (%.2f, the crown's masses from %.2f)"
		% [lowest, crown_low])
	ModelKit.sway_all(holder, TreeSpec.SWAY)
	for f: MeshInstance3D in fruit:
		_eq(float((f.material_override as ShaderMaterial).get_shader_parameter("sway")), TreeSpec.SWAY,
			"each fruit bends with its tree")
	var baked := ModelKit.bake(holder)
	var kept := 0
	for mi: MeshInstance3D in baked.find_children("*", "MeshInstance3D", true, false):
		for k in mi.mesh.get_surface_count():
			var sm := mi.get_surface_override_material(k) as ShaderMaterial
			var simpler: Array = RenderingServer.mesh_get_surface(mi.mesh.get_rid(), k).get("lods", [])
			if sm != null and sm.shader.resource_path == ModelKit.FRUIT_SHADER:
				kept += 1
				_eq(simpler.size(), 0, "the fruit is never made simpler (a ball of a few faces reads as a gem)")
			elif sm != null and sm.shader.resource_path == ModelKit.FOLIAGE_SHADER:
				_check(simpler.size() > 0, "while its leaves still are, seen from far")
	_check(kept > 0, "the baked tree has its fruit")
	baked.free()
	_done(g)






func test_591_a_seedling_grows_from_a_sprout_into_a_little_tree() -> void:
	var g := _farm()
	var it := g.item_data(NurtureSystem.SEEDLING)
	var tops: Array[float] = []
	for growth: float in [0.0, YoungModel.SPROUT_UNTIL, 0.6, 1.0]:
		var young := YoungModel.build(it, {"id": NurtureSystem.SEEDLING, "uid": 7}, growth)
		add_child(young)
		tops.append(ScaleGuide._top(young, Transform3D.IDENTITY))
		young.free()
	_check(tops[0] < 0.3, "new, it is a sprout in its mound (%.2f tall)" % tops[0])
	_check(tops[1] > tops[0] and tops[2] > tops[1] + 0.1 and tops[3] > tops[2] + 0.1,
		"then a little tree, taller with each can (%s)" % str(tops))
	_check(tops[3] < 1.0, "and still well short of a grown tree when it turns into one (%.2f)" % tops[3])
	_done(g)






func test_592_a_palms_fronds_and_a_bananas_leaves_are_real_leaves() -> void:
	# Feather fronds with leaflets, and broad paddles, in place of wire and flat blades (owner, 20 Nov). They bob
	# in the wind frond by frond, and stay whole from the farm's distance.
	var g := _farm()
	for id: String in ["coconut_tree", "date_tree", "banana_tree"]:
		var it := g.item_data(id)
		var sh := TreeModel.shape_of(it)
		var holder := Node3D.new()
		add_child(holder)
		TreeModel.build_at(holder, Vector3.ZERO, it, 1.0, false, 1)
		var leaves: Array[MeshInstance3D] = []
		for part: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
			var m := part.material_override as ShaderMaterial
			if m != null and m.shader.resource_path == ModelKit.FROND_SHADER:
				leaves.append(part)
		_eq(leaves.size(), 1, "%s: its leaves are one part" % id)
		var arrays := leaves[0].mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var per_leaf := int(sh["leaflets"]) * 9 if str(sh["form"]) == "palm" else FrondMesh.PADDLE_ROWS * 12
		_eq(points.size(), int(sh["clumps"]) * per_leaf, "%s: every frond has its leaflets" % id)
		var along := 0.0
		for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
			along = maxf(along, uv.x)
			_check(uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0, "%s: a point knows its place" % id)
		_eq(along, 1.0, "%s: a frond's tip is its far end (it bobs most there)" % id)
		ModelKit.sway_all(holder, TreeSpec.SWAY)
		_eq(float((leaves[0].material_override as ShaderMaterial).get_shader_parameter("sway")), TreeSpec.SWAY,
			"%s: its leaves bend with it" % id)
		var baked := ModelKit.bake(holder)
		for mi: MeshInstance3D in baked.find_children("*", "MeshInstance3D", true, false):
			for k in mi.mesh.get_surface_count():
				var sm := mi.get_surface_override_material(k) as ShaderMaterial
				if sm != null and sm.shader.resource_path == ModelKit.FROND_SHADER:
					_eq((RenderingServer.mesh_get_surface(mi.mesh.get_rid(), k).get("lods", []) as Array).size(), 0,
						"%s: its leaves are never made simpler" % id)
		baked.free()
	var palm := TreeModel.shape_of(g.item_data("coconut_tree"))
	var date := TreeModel.shape_of(g.item_data("date_tree"))
	_check(float(date["lean"]) < float(palm["lean"]) and float(date["tiers"][0][0]) > float(palm["tiers"][0][0]),
		"a date palm stands straighter and holds its fronds higher than a coconut palm")
	_done(g)
