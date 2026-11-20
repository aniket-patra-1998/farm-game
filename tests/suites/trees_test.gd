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






func test_593_leaves_flutter_down_and_fruit_bounces_then_both_are_gone() -> void:
	var leaves := FallingBits.new()
	var fruit := FallingBits.new(true)
	add_child(leaves)
	add_child(fruit)
	leaves.drop(Vector3(0, 1.0, 0), Vector3.ZERO, Color.GREEN, 0.05)
	fruit.drop(Vector3(0, 1.0, 0), Vector3(0.3, 0, 0), Color.RED, 0.08)
	_eq([leaves.live(), fruit.live()], [1, 1], "one of each in the air")
	var leaf_down := -1.0
	var fruit_hits := 0
	var high_again := false
	for step in 400:
		leaves.tick(0.02)
		fruit.tick(0.02)
		if leaf_down < 0.0 and leaves._down[0] >= 0.0:
			leaf_down = step * 0.02
		if fruit._hits[0] > fruit_hits:
			fruit_hits = fruit._hits[0]
		high_again = high_again or (fruit._hits[0] == 1 and fruit._pos[0].y > 0.12)
	_check(leaf_down > 1.5, "a leaf drifts down slowly (%.1f s from a tile up)" % leaf_down)
	_check(fruit_hits > FallingBits.BOUNCES and high_again, "a fruit bounces before it rolls to rest")
	_eq([leaves.live(), fruit.live()], [0, 0], "both fade and are gone")
	_check(not leaves.is_processing() and not fruit.is_processing(), "and nothing runs while nothing is falling")
	for i in FallingBits.CAPACITY + 5:
		leaves.drop(Vector3.ZERO, Vector3.ZERO, Color.GREEN, 0.05)
	_eq(leaves.live(), FallingBits.CAPACITY, "more than it holds: the oldest give way")
	leaves.free()
	fruit.free()






func test_594_the_trees_small_life_is_for_show() -> void:
	# A leaf now and then, a fruit from a ripe tree, a gust, a shake when harvested: none of it changes the game.
	Game.reset_game()
	Game.farm_size = 20
	Game.objects.clear()
	Game.next_uid = 1
	for k in 3:
		Game.objects.append({"uid": Game.next_uid, "id": "apple_tree", "row": 5, "col": 5 + k * 2, "t": Game.now()})
		Game.next_uid += 1
	Game.objects.append({"uid": Game.next_uid, "id": "cow", "row": 9, "col": 9, "t": Game.now()})
	Game.rebuild_occupancy()
	var life := TreeLife.new()
	add_child(life)
	var taker := Wind.new()
	life.winds = [taker]
	life.calm = 0.6
	_eq(taker.wind, 0.6, "it hands the weather's wind on")
	_eq(life.trees().size(), 3, "it knows the farm's lone trees (not its animals)")
	var before := [Game.coins, Game.xp, Game.objects.duplicate(true)]
	# No tree is ripe: leaves fall, no fruit does.
	for step in 600:
		life.tick(0.1)
	_check(life.leaves.live() > 0, "leaves drift down as time passes")
	_eq(life.fruit.live(), 0, "no fruit falls from a tree that is not ripe")
	# Ripe, one lets a fruit go now and then, in its own colour.
	for o: Dictionary in life.trees():
		o["t"] = Game.now() - 30 * 86400
	life.drop_fruit(life.trees()[0])
	_eq(life.fruit.live(), 1, "a ripe tree drops a fruit")
	_eq(life.fruit._tint[0], life.fruit_colour(life.trees()[0]), "in the colour of its own fruit")
	_check(life.fruit._pos[0].distance_to(life.crown_of(life.trees()[0])) < 1.0, "from its own crown")
	# A gust rises and dies away, and blows leaves across.
	var had := life.leaves.live()
	life.blow()
	var most := 0.0
	var windiest := 0.0
	for step in 50:
		life.tick(0.1)
		most = maxf(most, life.gust)
		windiest = maxf(windiest, taker.wind)
	_check(most > 0.9 and life.gust == 0.0, "a gust rises and is gone (%.2f at its height)" % most)
	_check(windiest > 0.6 + TreeLife.GUST_WIND * 0.9 and is_equal_approx(taker.wind, 0.6),
		"the wind rises with it and is the weather's again after (%.1f at most)" % windiest)
	_check(life.leaves.live() > had, "and carries leaves off the trees")
	# Harvested, a tree's fruit leaps off and its leaves fall; anything else is left alone.
	had = life.leaves.live()
	var fruit_had := life.fruit.live()
	life.harvested(int(Game.objects[3]["uid"]))
	_eq([life.leaves.live(), life.fruit.live()], [had, fruit_had], "a cow collected sheds nothing")
	life.harvested(int(Game.objects[0]["uid"]))
	_check(life.fruit.live() >= mini(fruit_had + TreeLife.SHAKE_FRUIT, FallingBits.CAPACITY)
		and life.leaves.live() > had, "a harvested tree's fruit leaps off and leaves fall")
	_eq([Game.coins, Game.xp], [before[0], before[1]], "none of it pays anything")
	for k in 4:
		_eq(Game.objects[k]["id"], (before[2] as Array)[k]["id"], "or moves anything")
	life.free()
	Game.reset_game()






func test_603_a_limited_tree_wears_its_variety() -> void:
	# The same tree in its variety's colours, with the variety's touch; a Galaxy tree has stars. None has a file:
	# there are five of every tree, so each is built on the device (tools/export_plants leaves them out).
	var plain := _tree("apple_tree")
	for variety: String in Varieties.of_trees():
		var id := variety + "_apple_tree"
		var it := Game.item_data(id)
		_check(not AssetRegistry.has_model(id) and AssetRegistry.has_model("apple_tree"), "%s is built, not a file" % id)
		var tree := _tree(id)
		var touch := int(ModelKit.LEAF_TOUCHES.get(str(it["touch"]), 0))
		var leafy := 0
		var stars := 0
		for part: MeshInstance3D in tree.find_children("*", "MeshInstance3D", true, false):
			for k in part.mesh.get_surface_count():
				var mat := part.get_active_material(k) as ShaderMaterial
				if mat == null:
					continue
				if mat.shader.resource_path == ModelKit.STAR_SHADER:
					stars += 1
				elif mat.shader.resource_path in ModelKit.LEAF_SHADERS:
					leafy += 1
					_eq(_touch(mat), touch, "%s's leaves have its touch" % id)
		_check(leafy > 0, "%s has leaves" % id)
		_eq(stars > 0, variety == "galaxy", "only a Galaxy tree has stars (%s)" % id)
		_check(absf(_height(tree) - _height(plain)) < 0.25, "%s is the size of its plain tree" % id)
		tree.free()
	# A plain tree is untouched.
	for part: MeshInstance3D in plain.find_children("*", "MeshInstance3D", true, false):
		for k in part.mesh.get_surface_count():
			var mat := part.get_active_material(k) as ShaderMaterial
			if mat != null and mat.shader.resource_path in ModelKit.LEAF_SHADERS:
				_eq(_touch(mat), 0, "a plain tree's leaves have no touch")
			_check(mat == null or mat.shader.resource_path != ModelKit.STAR_SHADER, "and no stars")
	plain.free()


func test_604_a_hummingbird_calls_at_a_limited_tree() -> void:
	# Owner, 20 Nov: it circles the tree and goes in as if its nest were there. One bird, at limited trees only.
	Game.reset_game()
	Game.farm_size = 20
	Game.objects.clear()
	Game.next_uid = 1
	for id: String in ["apple_tree", "lemon_tree"]:
		Game.objects.append({"uid": Game.next_uid, "id": id, "row": 5, "col": 3 + Game.next_uid * 2, "t": Game.now()})
		Game.next_uid += 1
	Game.rebuild_occupancy()
	var life := TreeLife.new()
	add_child(life)
	for step in 1500:
		life.tick(0.1)
		_check(life.bird.away() and not life.bird.visible, "no hummingbird comes to a farm of plain trees")
	Game.objects.append({"uid": Game.next_uid, "id": "galaxy_apple_tree", "row": 9, "col": 9, "t": Game.now()})
	Game.rebuild_occupancy()
	Game.objects_changed.emit()
	var before := [Game.coins, Game.xp, Game.objects.duplicate(true)]
	var tree: Dictionary = Game.objects[2]
	var crown := life.crown_of(tree)
	var came := false
	for step in 600:
		life.tick(0.1)
		came = came or not life.bird.away()
		if came:
			break
	_check(came, "one comes to a limited tree before long")
	_check(life.bird.position.distance_to(crown) > 3.0, "from far off")
	var seen := {}
	var nearest := INF
	var hid := false
	for step in 400:
		life.tick(0.05)
		seen[life.bird.phase] = true
		if life.bird.phase == Hummingbird.Phase.CIRCLE:
			var off := life.bird.position - crown
			_check(absf(Vector2(off.x, off.z).length() - TreeLife.CROWN_R * Hummingbird.CIRCLE_R) < 0.01
				and absf(off.y) <= Hummingbird.BOB + 0.001, "it circles the crown")
		if life.bird.phase == Hummingbird.Phase.NEST:
			hid = hid or not life.bird.visible
			nearest = minf(nearest, life.bird.position.distance_to(crown))
		elif not life.bird.away():
			_check(life.bird.visible, "it is seen whenever it is not inside")
		if life.bird.away():
			break
	for p: int in Hummingbird.Phase.values():
		_check(seen.has(p), "its call has every part (%s)" % Hummingbird.Phase.keys()[p])
	_check(hid and nearest < TreeLife.CROWN_R * 0.5, "it goes in among the leaves and is hidden there")
	_check(life.bird.away() and not life.bird.visible, "and is off again")
	_eq([Game.coins, Game.xp, Game.objects], before, "its call changes nothing")
	# One bird: a second call waits for the first to end, and it is gone when another farm is shown.
	life.call_at(tree)
	_check(not life.bird.away(), "called, it comes")
	Game.farm_opened.emit()
	_check(life.bird.away() and not life.bird.visible, "and is gone when the farm on screen changes")
	life.free()
	Game.reset_game()


func test_605_a_cotton_candy_tree_shivers_and_sheds_petals() -> void:
	Game.reset_game()
	Game.farm_size = 20
	Game.objects.clear()
	Game.next_uid = 1
	for id: String in ["apple_tree", "galaxy_apple_tree", "cotton_candy_apple_tree"]:
		Game.objects.append({"uid": Game.next_uid, "id": id, "row": 5, "col": 3 + Game.next_uid * 2, "t": Game.now()})
		Game.next_uid += 1
	Game.rebuild_occupancy()
	var life := TreeLife.new()
	add_child(life)
	var candy: Dictionary = Game.objects[2]
	life.shiver(candy)
	_eq(life.leaves.live(), TreeLife.SHIVER_PETALS, "a shiver lets a few petals go")
	var pale := Varieties.leaves("cotton_candy")
	for k in life.leaves.live():
		var near := false
		for hue in pale:
			near = near or _far(life.leaves._tint[k], hue) < TreeLife.LEAF_VARY * 2.0
		_check(near, "in its variety's colours")
		_check(life.leaves._pos[k].distance_to(life.crown_of(candy)) < 1.0, "from its own crown")
	# Left to itself, only the Cotton Candy tree shivers (the others shed a leaf now and then, as any tree).
	var shivers := [0]
	life.objects = null
	var deep := Varieties.leaves("galaxy")
	_check(_far(life.leaf_colour(Game.objects[1]), deep[0]) < 0.6, "a Galaxy tree's leaves fall dark")
	_eq(str(Game.item_data("galaxy_apple_tree")["touch"]) == TreeLife.SHAKES, false, "a Galaxy tree does not shiver")
	_eq(str(Game.item_data("cotton_candy_apple_tree")["touch"]), TreeLife.SHAKES, "a Cotton Candy tree does")
	shivers[0] = life.leaves.live()
	life._shiver_in = 0.0
	life._leaf_in = 100.0
	life._gust_in = 100.0
	life.tick(0.01)
	_eq(life.leaves.live() - shivers[0], TreeLife.SHIVER_PETALS, "now and then it shivers by itself")
	life.free()
	Game.reset_game()


## Tree `id` as the farm builds it (look 0, ripe).
func _tree(id: String) -> Node3D:
	var tree := Node3D.new()
	add_child(tree)
	TreeSpec.builder().build_at(tree, Vector3.ZERO, Game.item_data(id), ScaleGuide.factor(id), true, 0, true)
	return tree


## The touch a leaf material has on (0: none, never set).
func _touch(mat: ShaderMaterial) -> int:
	var touch: Variant = mat.get_shader_parameter("touch")
	return int(touch) if touch != null else 0


func _height(tree: Node3D) -> float:
	var top := 0.0
	for part: MeshInstance3D in tree.find_children("*", "MeshInstance3D", true, false):
		top = maxf(top, (part.global_transform * part.get_aabb()).end.y)
	return top


## How far apart two colours are.
func _far(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## Something that takes the wind (as the ground and the crops do).
class Wind:
	extends RefCounted
	var wind := 0.0
