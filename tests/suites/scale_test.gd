extends TestSuite
## The game keeps scaling (scaling report, fix 5): the fullest farm and menus of thousands of items
## stay inside fixed budgets, so the game can't quietly stop scaling again. Budgets are for a desktop CI runner
## (a mid-range phone is a few times slower); what is held is how the cost grows, so they are generous.

const OBJECTS := GameState.MAX_SIZE * GameState.MAX_SIZE   # every tile of the largest farm (900) filled
const IN_PLACE_MS := 0.2      # one thing changed where it stands (a tap's collect or feed), each
const WHOLE_MS := 40.0        # a change to what stands where (a move, a purchase) on the whole farm
const COLLECT_MS := 5.0       # a collect, the rule and its telling, on a full farm


## Every tile of the largest farm holding a thing (900; the scaling report's 2,000 can't stand on 30x30 tiles):
## a change to one costs one, not all (Game.object_changed), and a change to the whole farm stays within budget.
func test_372_a_farm_of_thousands_changes_one_thing_at_one_things_cost() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.objects.clear()
	Game.farm_size = GameState.MAX_SIZE
	var uid := 50000
	for k in OBJECTS:
		Game.objects.append({"uid": uid + k, "id": "hay_bale" if k % 2 == 0 else "cow",
			"row": GameState.row_of(k), "col": GameState.col_of(k), "t": Game.now()})
	Game.rebuild_occupancy()
	Game.objects_updated()   # (the farm as set up, told: what stands where is known)
	_eq(Game.objects.size(), OBJECTS, "the farm holds %d things" % OBJECTS)
	var told := [0]
	var count := func(_u: int) -> void: told[0] += 1
	Game.object_changed.connect(count)
	var each := _fastest_ms(func() -> void:
		for k in 200:
			Game.objects_updated(uid + k * 4)) / 200.0
	_eq(told[0], 200 * TIMING_TRIES, "each change in place is told for its thing alone")
	_check(each < IN_PLACE_MS, "a change in place costs %.3f ms on %d things" % [each, OBJECTS])
	var whole := _fastest_ms(func() -> void: Game.objects_updated())
	_check(whole < WHOLE_MS, "a change to the whole farm costs %.1f ms" % whole)
	var cow := Game.object_by_uid(uid + 1)
	var collect := INF
	for t in TIMING_TRIES:   # (timed one at a time: the cow is made ready again before each collect)
		cow["t"] = Game.now() - 999999
		collect = minf(collect, _fastest_ms(func() -> void: Game.collect(uid + 1), 1))
	_check(collect < COLLECT_MS, "collecting from one cow costs %.2f ms" % collect)
	Game.object_changed.disconnect(count)
	Game.reset_game()


func test_444_a_timing_budget_is_scaled_back_only_on_a_slower_machine() -> void:
	var raw := INF
	for t in TIMING_TRIES:
		var began := Time.get_ticks_usec()
		OS.delay_usec(3000)
		raw = minf(raw, (Time.get_ticks_usec() - began) / 1000.0)
	var measured := _fastest_ms(func() -> void: OS.delay_usec(3000))
	_check(measured <= raw * 1.1, "the measure is never more than the work's own time (%.2f, %.2f)" % [measured, raw])
	_check(measured >= 3.0 * YARDSTICK_MS / 8.0, "and scaled back no more than the yardstick ran slow (%.2f)" % measured)


## A thing placed on a farm full of others is built with what stands beside it, and nothing else is looked at again
## (a placing on a full farm looked at all 614 things: 104 ms on a PC, a second's freeze on the A05s; owner,
## 22 Nov: "fix all the issues"). The change says what it touched (Game.changed_uids), and selling it does the same.
func test_613_placing_one_thing_rebuilds_it_and_its_neighbours_not_the_whole_farm() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.objects.clear()
	Game.farm_size = 20
	for r in 20:
		for c in range(0, 20, 2):
			Game.objects.append({"uid": 70000 + r * 20 + c, "id": "hay_bale", "row": r, "col": c, "t": Game.now()})
	Game.rebuild_occupancy()
	Game.objects_updated()
	var objects := Objects3D.new()
	add_child(objects)
	Game.objects_changed.connect(objects.queue_sync)   # (as Farm3D wires it)
	var waited := 0
	while waited < 600 and not objects.settled():
		await get_tree().process_frame
		waited += 1
	await get_tree().process_frame
	var far := 70000 + 18 * 20 + 18
	var far_view := objects.view_of(far)
	_check(far_view != null, "the farm stands (a thing far away is drawn)")
	var told: Array = []
	var note := func() -> void: told.append(Game.changed_uids.duplicate())
	Game.objects_changed.connect(note)
	Game.coins += 100000
	var uid := Game.next_uid
	_check(Game.buy_and_place("hay_bale", 5, 1), "a hay bale is placed between two others")
	await get_tree().process_frame
	await get_tree().process_frame
	_eq(told, [[uid]], "the change says it touched the placed thing alone")
	_check(objects.view_of(uid) != null, "the placed thing is drawn")
	_check(objects.view_of(far) == far_view, "what stands far away is not built again")
	_check(Game.sell_object(uid), "and sold")
	await get_tree().process_frame
	await get_tree().process_frame
	_eq(told.size(), 2, "the sale is told once")
	_eq(told[-1], [uid], "for the sold thing alone")
	_check(objects.view_of(uid) == null, "its picture is taken away")
	_check(objects.view_of(far) == far_view, "and what stands far away still stands as it was")
	Game.objects_changed.disconnect(note)
	Game.objects_changed.disconnect(objects.queue_sync)
	objects.queue_free()


## A low-end phone starts on low (the A05s, Adreno 610, started on mid and ran at 3 to 4 frames a second until the
## game measured itself down); a phone of today starts on the phone default; data/quality.json says which.
func test_614_a_low_end_phone_starts_on_low_quality() -> void:
	_check(Quality.is_low_end("Adreno (TM) 610", 4000), "an Adreno 610 is low-end")
	_check(Quality.is_low_end("Mali-G52 MC2", 6000), "so is a Mali-G52")
	_check(Quality.is_low_end("Some GPU", 3000), "and a phone with 3 GB, whatever its chip")
	_check(not Quality.is_low_end("Adreno (TM) 830", 12000), "an Adreno 830 (the iQOO 15R's class) is not")
	_check(not Quality.is_low_end("Mali-G720", 8000), "nor a Mali-G720")
	_check(Quality.is_low_end("Adreno (TM) 618", 6000), "an Adreno 618 (mid-range of 2020) starts on low")
	_check(not Quality.is_low_end("Adreno (TM) 710", 8000), "an Adreno 710 does not")


## FrameClock says how long this frame's scripts took (the engine's TIME_PROCESS is the worst frame of each
## second: one stall read as a whole second of slow frames, in the phone benchmark and AutoQuality).
func test_615_the_frame_clock_times_this_frames_scripts() -> void:
	var busy := Node.new()
	var code := GDScript.new()
	code.source_code = "extends Node\nvar ms := 0.0\nfunc _process(_d: float) -> void:\n" \
		+ "\tvar t := Time.get_ticks_usec()\n\twhile Time.get_ticks_usec() - t < ms * 1000.0:\n\t\tpass\n"
	code.reload()
	busy.set_script(code)
	add_child(busy)
	var was_running := FrameClock._running
	FrameClock.start_in(self)
	busy.set("ms", 6.0)
	for k in 3:
		await get_tree().process_frame
	_check(FrameClock.process_ms() >= 6.0, "a frame whose scripts take 6 ms reads at least that (%.1f)"
		% FrameClock.process_ms())
	busy.set("ms", 0.0)
	for k in 3:
		await get_tree().process_frame
	_check(FrameClock.process_ms() < 6.0, "and the next quiet frame reads less (%.1f)" % FrameClock.process_ms())
	# Work deferred to the end of the frame (a change's Objects3D sync is) is counted too.
	var spin := func() -> void:
		var t := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t < 6000:
			pass
	for k in 3:
		spin.call_deferred()
		await get_tree().process_frame
	_check(FrameClock.process_ms() >= 6.0, "deferred work of 6 ms reads at least that (%.1f)" % FrameClock.process_ms())
	busy.queue_free()
	if not was_running:
		for n in get_children():
			if n is FrameClock:
				n.queue_free()   # (its tree_exiting lets go of the frame's signal)


## A scene's frames as ScenePlayer tells them: percentiles, the longest, hitches (over twice the median) and frames
## over 50 ms; and the ground's GPU time is told part by part (LoadBenchmark.owner_of).
func test_616_a_scenes_frames_are_told_by_percentile_and_hitch() -> void:
	var times: Array[float] = []
	for k in 99:
		times.append(10.0)
	times.append(120.0)
	var s := ScenePlayer.stats(times)
	_eq(s["frames"], 100, "every frame counted")
	_eq(s["p50"], 10.0, "the median")
	_eq(s["max"], 120.0, "the longest")
	_eq(s["hitches"], 1, "one frame over twice the median is a hitch")
	_eq(s["over_ms"], 1, "and over 50 ms")
	_eq(s["worst_at"], 99, "where the longest fell")
	var ground := Ground3D.new()
	add_child(ground)
	_eq(LoadBenchmark.owner_of(ground.get_node("Tufts")), "Ground3D/Tufts", "the ground's tufts timed apart")
	_eq(LoadBenchmark.owner_of(ground.get_node("Meadow")), "Ground3D/Meadow", "and its meadow")
	ground.queue_free()


## Every sound is made or loaded on a worker at start (one a frame on the main thread stalled a new farm's first
## seconds, up to 100 ms a frame): within a few seconds every recipe's sound is ready and the worker has finished.
func test_617_sounds_are_made_off_the_main_thread_at_start() -> void:
	var waited := 0
	while Sound._warm_task >= 0 and waited < 600:
		await get_tree().process_frame
		waited += 1
	_eq(Sound._warm_task, -1, "the worker has finished")
	await get_tree().process_frame
	var missing := 0
	for event: String in Sound._recipes:
		if not Sound._cache.has(event):
			missing += 1
	_eq(missing, 0, "every recipe's sound is ready in the cache")


## Sets up a farm of `size` holding `things` ([id, row, col]) drawn by an Objects3D wired as Farm3D wires it,
## waits until it stands, and returns the Objects3D (the caller frees it and disconnects queue_sync).
func _drawn_farm(size: int, things: Array) -> Objects3D:
	Game.saving_enabled = false
	Game.reset_game()
	Game.objects.clear()
	Game.farm_size = size
	var uid := 80000
	for t: Array in things:
		Game.objects.append({"uid": uid, "id": t[0], "row": t[1], "col": t[2], "t": Game.now()})
		uid += 1
	Game.rebuild_occupancy()
	Game.objects_updated()
	var objects := Objects3D.new()
	add_child(objects)
	Game.objects_changed.connect(objects.queue_sync)
	var waited := 0
	while waited < 600 and not objects.settled():
		await get_tree().process_frame
		waited += 1
	await get_tree().process_frame
	return objects


## A thing moved: the things that stood beside it where it was, and beside it where it is, are drawn again (their
## looks join with their neighbours': Crowding), and nothing else; a thing taken off the list without a word is
## found by the timer's look of everything (FULL_EVERY) and its picture taken away.
func test_618_a_moved_thing_redraws_its_old_and_new_neighbours_and_an_unannounced_one_is_found() -> void:
	var objects: Objects3D = await _drawn_farm(12, [["apple_tree", 2, 2], ["apple_tree", 2, 3],
		["apple_tree", 2, 4], ["apple_tree", 9, 9], ["apple_tree", 6, 0]])
	var left := objects.view_of(80000)
	var right := objects.view_of(80002)
	var far := objects.view_of(80003)
	_check(Game.move_object(80001, 6, 1), "the middle tree moves beside another")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(objects.view_of(80000) != left and objects.view_of(80002) != right,
		"the trees that stood beside it are drawn again (they stand alone now)")
	_check(objects.view_of(80003) == far, "a tree far from both places is not")
	var gone := Game.object_by_uid(80003)
	Game.objects.erase(gone)   # (no word said: a rule that forgot to tell the farm)
	for k in Objects3D.FULL_EVERY:
		objects._on_tick()
		for f in 30:
			await get_tree().process_frame
	_check(objects.view_of(80003) == null, "a thing gone without a word is found and its picture taken away")
	Game.objects_changed.disconnect(objects.queue_sync)
	objects.queue_free()


## The narrow paths a change takes elsewhere: wear knows a building placed and one sold (only those are looked
## at), and the grass a placing frees or wears is laid as a ground built afresh lays it.
func test_619_wear_and_the_grass_follow_a_narrow_change_as_a_whole_one_would() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	var shed := ""
	for id: String in Game.item_order:
		var o := {"id": id}
		if Game.kind_of(o) == "building" and Game.wear.wears(o) and not Game.item_data(id).has("build_materials"):
			shed = id
			break
	var uid := Game.next_uid
	Game.next_uid += 1
	var b := {"uid": uid, "id": shed, "row": 4, "col": 4, "t": Game.now(), "level": 1, "inside": {}}
	Game.add_object(b)   # (as the shop places a building: then the farm is told of it alone)
	Game.objects_updated(uid)
	_check(Game.wear.buildings.has(str(uid)), "wear knows a building placed (%s)" % shed)
	Game.remove_object(b)
	Game.objects_updated(uid)
	_check(not Game.wear.buildings.has(str(uid)), "and lets it go when it is taken away")
	var ground := Ground3D.new()
	add_child(ground)
	Game.objects_changed.connect(ground.queue_rebuild)
	var cow := Game.next_uid
	Game.next_uid += 1
	Game.add_object({"uid": cow, "id": "cow", "row": 6, "col": 6, "t": Game.now()})
	Game.objects_updated(cow)   # (a cow wears the grass round it)
	for k in 4:
		await get_tree().process_frame
	var fresh := Ground3D.new()
	add_child(fresh)
	_eq(ground.farm_tuft_count(), fresh.farm_tuft_count(), "the grass laid again near it matches a fresh ground's")
	Game.objects_changed.disconnect(ground.queue_rebuild)
	ground.queue_free()
	fresh.queue_free()


## However many animals are on screen, a frame poses at most POSES_MOST and every animal is posed within a stride
## (a cap alone, with the stride held at MAX_STRIDE, left the end of a herd of more than 128 never posed).
func test_620_every_animal_of_a_big_herd_is_posed_and_no_frame_poses_too_many() -> void:
	for seen in [1, 16, 40, 128, 200, 500, 1500]:
		var stride := Animal3D.stride_for(seen)
		_check(ceili(float(seen) / stride) <= Animal3D.POSES_MOST or stride == Animal3D.SLOTS,
			"%d on screen: %d posed a frame at most (stride %d)" % [seen, ceili(float(seen) / stride), stride])
		_check(stride <= Animal3D.SLOTS, "and each is posed every %d frames at most" % stride)
	_eq(Animal3D.stride_for(10), 1, "a few on screen are posed every frame")
	_eq(Animal3D.stride_for(100), Animal3D.MAX_STRIDE, "up to 128, as before (every 4th frame at most)")


## A stray that wanders off and one that turns up in the same look are both told, as what changed.
func test_621_a_stray_leaving_and_one_arriving_are_told_as_what_changed() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.strays._spawn_stray()
	var old: Dictionary = Game.objects[-1]
	old["t"] = Game.now() - Balance.i("strays.stray_stays") - 10
	Game.strays.next_stray_at = Game.now() - 1
	Game.strays.arrived.clear()
	var told: Array = []
	var note := func() -> void: told.append(Game.changed_uids.duplicate())
	Game.objects_changed.connect(note)
	Game.strays.check_strays()
	Game.objects_changed.disconnect(note)
	_eq(told.size(), 1, "told once")
	var new_uid := int(Game.objects[-1]["uid"]) if Game.objects[-1].get("stray", false) else -1
	_check(told.size() == 1 and (told[0] as Array).has(int(old["uid"])), "the one that left is in what changed")
	_check(new_uid < 0 or (told[0] as Array).has(new_uid), "and the one that arrived")
