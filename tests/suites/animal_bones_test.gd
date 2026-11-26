extends TestSuite
## An animal file's bones and moves (AnimalBones; tools/animal_art export.py): a move is where each bone goes,
## never a second copy of the mesh, and the game adds the moves it wants bone by bone.


func test_640_an_animal_file_keeps_its_moves_as_bones_not_copies_of_its_mesh() -> void:
	# (17 stored copies were nine tenths of every animal's file: 164 MB of the game's 205 MB of models.)
	var heavy: Array[String] = []
	var bare: Array[String] = []
	var shaking := 0
	for id in Animal3D.stride_kinds():
		var model := AssetRegistry.instance(id)
		var mi := Animal3D._first_mesh(model)
		var moves := AnimalBones.moves_of(mi)
		var copies: Array[String] = []
		for k in mi.mesh.get_blend_shape_count():
			copies.append(String(mi.mesh.get_blend_shape_name(k)))
		# (Only a long coat's shake is a move no bone can make: its two halves stay as copies.)
		if not (copies.is_empty() or copies == [CoatTouch.SHAKE_A, CoatTouch.SHAKE_B]):
			heavy.append(id)
		shaking += 1 if not copies.is_empty() else 0
		var walks := moves != null and moves.names.has(Animal3D.walk_move(0))
		if not walks or moves.bones() < 4 or not moves.names.has("blink"):
			bare.append(id)
		model.free()
	_check(heavy.is_empty(), "no animal file stores a move as a copy of its mesh, a coat's shake apart: %s" % [heavy])
	_check(bare.is_empty(), "every animal file has bones, a walk and a blink: %s" % [bare])
	_check(shaking > 0, "and the long coats still shake (%d of them)" % shaking)


func test_641_the_moves_an_animal_wants_add_up_bone_by_bone() -> void:
	var model := AssetRegistry.instance("cow")
	var mi := Animal3D._first_mesh(model)
	var bones := AnimalBones.of(mi)
	_check(bones != null and mi.skin == null and mi.skeleton.is_empty(),
		"the cow follows its own bones, not the file's node")
	var moves := bones.moves
	_eq(bones.places(), moves.rest, "asked for nothing, every bone is where it rests")
	var head := bones.index("head")
	var tail := bones.index("tail")
	_check(head >= 0 and tail >= 0 and bones.index("no such move") == -1, "a move is found by its name")
	bones.want(head, 0.5)
	bones.want(tail, 1.0)
	var at := bones.places()
	var wanted := moves.rest.duplicate()
	for pair: Array in [[head, 0.5], [tail, 1.0]]:
		var carried: PackedInt32Array = moves.where[pair[0]]
		var far: PackedVector3Array = moves.change[pair[0]]
		for j in carried.size():
			for axis in AnimalBones.AXES:
				wanted[carried[j] + axis] += far[j * AnimalBones.AXES + axis] * float(pair[1])
	var off := 0.0
	for k in at.size():
		off = maxf(off, (at[k] - wanted[k]).length())
	_check(off < 0.00001, "each bone is its rest and each wanted move's change by its strength (%.6f off)" % off)
	_check(moves.where[tail].size() < moves.bones(), "a move names only the bones it carries (the tail's: %d of %d)"
		% [moves.where[tail].size(), moves.bones()])
	var other := bones.another()
	_eq(other.places(), moves.rest, "another cow shares the moves, never the pose")
	bones.pose(mi)   # (the bones go to the renderer without a Skeleton3D's turn-and-size poses)
	_check(AnimalBones.box_of(mi).size.x > 0.9, "its box is of the cow as it stands (%s)" % AnimalBones.box_of(mi))
	model.free()


func test_642_an_animal_is_posed_through_its_file_s_bones() -> void:
	var g := _farm()
	var cow := Animal3D.create(g.item_data("cow"), null, Vector3.ZERO)
	add_child(cow)
	_check(cow._file_bones != null and cow._walk_frames == 8, "a cow has its file's bones and its eight walk frames")
	var pose := AnimalPose.new()
	pose.gait = 0.3
	pose.stride = 1.0
	cow._pose_file(pose)
	var walking := cow._file_bones.places()
	pose.stride = 0.0
	cow._pose_file(pose)
	_check(walking != cow._file_bones.moves.rest, "walking moves its bones")
	_eq(cow._file_bones.places(), cow._file_bones.moves.rest, "and standing again they are back at rest")
	var twin := Animal3D.create(g.item_data("cow"), null, Vector3.ZERO)
	add_child(twin)
	pose.head = 1.0
	twin._pose_file(pose)
	_check(twin._file_bones != cow._file_bones and twin._file_bones.moves == cow._file_bones.moves,
		"two cows share one kind's moves and each has its own bones")
	_eq(cow._file_bones.places(), cow._file_bones.moves.rest, "one grazing does not move the other")
	_check(Animal3D.measure_stride("cow") > 0.1, "its stride is measured from its bones' walk (%.2f tiles)"
		% Animal3D.measure_stride("cow"))
	cow.queue_free()
	twin.queue_free()
	_done(g)


func test_643_the_farmer_s_file_keeps_its_moves_as_bones_too() -> void:
	for body: String in ["a", "b"]:
		var model := AssetRegistry.instance("%s%s_%s" % [Farmer3D.FILE, body, "short"])
		var mi := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var moves := AnimalBones.moves_of(mi)
		_eq(mi.mesh.get_blend_shape_count(), 0, "farmer %s: no move is a copy of the mesh" % body)
		for move: String in ["leg_l_f", "leg_r_b", "arm_l_b", "arm_r_f1", "arm_r_f2", "blink"]:
			_check(moves != null and moves.names.has(move), "farmer %s has the move %s" % [body, move])
		model.free()
	var g := _farm()
	var farmer := Farmer3D.new()
	add_child(farmer)
	_check(farmer._file_bones != null, "the farmer on the farm is posed through its file's bones")
	farmer._move("arm_l_f2", 1.0)
	_check(farmer._file_bones.places() != farmer._file_bones.moves.rest, "raising an arm moves them")
	farmer.queue_free()
	_done(g)


func test_644_no_build_carries_art_the_game_never_draws() -> void:
	# (art/pilot and art/style are the first style trials: 10 MB in every build, drawn by a tool alone.)
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var builds := 0
	for line in presets.split("\n"):
		if not line.begins_with("exclude_filter="):
			continue
		builds += 1
		for left_out: String in ["art/pilot/*", "art/style/*", "tests/*", "tools/*"]:
			_check(line.contains(left_out), "build %d leaves out %s" % [builds, left_out])
	_check(builds >= 3, "every build says what it leaves out (%d)" % builds)
