extends Node
## Harvest juice in motion (the wow build): a row of ripe plots on a fresh farm is harvested by the farmer, and
## a frame is written every --every=<frames> into --out=<dir> (default ci_shots/juice), from the first harvest
## to a moment after the sweep's end (run with --fixed-fps 30, so a frame is 1/30 s however slow the render).
## --produce=<json> tries a variant of Balance feel.produce. --hour=<h> as look_shot (12.5 noon, 18.5 dusk);
## --crop=<id>; --plots=<n>. --collect: a round of collecting instead (up to --plots= of the farm's animals and
## trees made ready, the farmer collecting from each; their own pictures fly). --pet: the farm's first grown
## animal tapped for itself, its heart rising (--heart=<json> tries a variant of Balance feel.heart).
## Needs a renderer:
##   xvfb-run godot --rendering-method gl_compatibility --fixed-fps 30 --path . res://tools/juice_shot.tscn

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _ready() -> void:
	var out := "res://ci_shots/juice"
	var hour := 12.5
	var crop := "strawberries"
	var plots := 8
	var every := 6
	var collect := false
	var pet := false
	for a in OS.get_cmdline_user_args():
		if a == "--collect":
			collect = true
		if a == "--pet":
			pet = true
		if a.begins_with("--heart="):   # a variant of Balance feel.heart, as JSON merged over it
			var heart := Balance.d("feel.heart").duplicate()
			heart.merge(JSON.parse_string(a.substr(8)), true)
			Balance.override("feel.heart", heart)
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--hour="):
			hour = float(a.substr(7))
		elif a.begins_with("--crop="):
			crop = a.substr(7)
		elif a.begins_with("--plots="):
			plots = int(a.substr(8))
		elif a.begins_with("--every="):
			every = int(a.substr(8))
		elif a.begins_with("--produce="):   # a variant of Balance feel.produce, as JSON merged over it
			var look := Balance.d("feel.produce").duplicate()
			look.merge(JSON.parse_string(a.substr(10)), true)
			Balance.override("feel.produce", look)
	# (the streak is timed on the wall clock, and a slow render with --fixed-fps stretches it: hold it open)
	Balance.override("feel.streak_gap_seconds", 3600.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	Game.saving_enabled = false
	Game.reset_game()
	Game.coins = 100000
	Game.xp = Game.xp_for_level(20) + 10   # (past the first level-ups, the guide and its hellos)
	Game.tutorial_step = GameState.Tutorial.DONE
	ProjectSettings.set_setting(Farm3D.SETTING, true)
	get_window().size = Vector2i(1200, 540)   # 20:9 at 1x
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var local_now := int(Time.get_unix_time_from_system()) + DayCycle.device_bias_minutes() * 60
	Game.debug_time_offset = posmod(int(hour * 3600) - local_now, 86400)
	Game.weather_override = "clear"
	var grid: FarmGrid = main.get("grid")
	var cam: FarmCamera = main.get("camera")
	if pet:
		await _pet(grid, cam, every, out)
		return
	if collect:
		await _collect_round(grid, cam, plots, every, out)
		return
	var row: Array[int] = []
	for i in Game.plots.size():   # a row of free grass, side by side
		if row.size() == plots:
			break
		if Game.on_farm(i) and not Game.is_occupied(i) and Game.field.phase(i) == GameState.Phase.GRASS \
				and (row.is_empty() or (i == row[-1] + 1 and GameState.row_of(i) == GameState.row_of(row[0]))):
			row.append(i)
		elif not row.is_empty() and row.size() < plots:
			row.clear()
	for i in row:
		Game.field.plow(i)
		Game.field.plant(i, crop)
		Game.plots[i]["planted_at"] = Game.now() - int(Game.crops[crop]["grow_seconds"]) - 5
		Game.plot_changed.emit(i)
	ItemIcons.of(crop)
	for k in 240:   # (the crop's picture is made a few frames after the first screen)
		await RenderingServer.frame_post_draw
		if ItemIcons.is_made(crop) and k > 60:
			break
	cam.snap(grid.to_global(grid.center_of(row[row.size() / 2])), 1.35)
	for k in 12:
		await RenderingServer.frame_post_draw
	for i in row:
		grid.call("_queue", grid.job_for(i), false)
	var shot := 0
	var quiet := 0
	while quiet < 50 and shot < 400:
		for k in every:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/f%03d.png" % shot))
		shot += 1
		quiet = quiet + every if Game.player.queue.is_empty() else 0
	print("juice_shot: %d frames, %d plots of %s, picture made %s" % [shot, row.size(), crop, ItemIcons.is_made(crop)])
	get_tree().quit()


## A round of collecting from the farm's own animals and trees, made ready, frames written as for a sweep.
func _collect_round(grid: FarmGrid, cam: FarmCamera, most: int, every: int, out: String) -> void:
	var uids: Array[int] = []
	for obj: Dictionary in Game.objects:
		if uids.size() < most and ["animal", "tree"].has(Game.kind_of(obj)):
			obj["t"] = Game.now() - 10000000
			Game.objects_updated(int(obj["uid"]))
			ItemIcons.of(str(obj["id"]))
			uids.append(int(obj["uid"]))
	for k in 240:   # (the pictures are made a few frames after the first screen)
		await RenderingServer.frame_post_draw
		if k > 60 and uids.all(func(u: int) -> bool: return ItemIcons.is_made(str(Game.object_by_uid(u)["id"]))):
			break
	var first := Game.object_by_uid(uids[0])
	cam.snap(grid.to_global(grid.center_of(Game.index_of(int(first["row"]), int(first["col"])))), 1.2)
	for k in 12:
		await RenderingServer.frame_post_draw
	for u in uids:
		grid.call("_queue", {"kind": "collect", "uid": u}, false)
	var shot := 0
	var quiet := 0
	while quiet < 50 and shot < 400:
		for k in every:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/f%03d.png" % shot))
		shot += 1
		quiet = quiet + every if Game.player.queue.is_empty() else 0
	print("juice_shot: %d frames, a round of %d collects" % [shot, uids.size()])
	get_tree().quit()


## The farm's first grown animal tapped for itself (nothing to collect), frames written from the tap until its
## heart has gone.
func _pet(grid: FarmGrid, cam: FarmCamera, every: int, out: String) -> void:
	var animal := {}
	for obj: Dictionary in Game.objects:
		if Game.kind_of(obj) == "animal" and Game.nurture.supply_for(obj) == "":
			animal = obj
			break
	animal["t"] = Game.now()
	cam.snap(grid.to_global(grid.center_of(Game.index_of(int(animal["row"]), int(animal["col"])))), 1.6)
	for k in 90:
		await RenderingServer.frame_post_draw
	grid.call("_act_on_object", animal, true)
	for shot in 12:
		for k in every:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/f%03d.png" % shot))
	print("juice_shot: an animal petted, %s" % str(animal["id"]))
	get_tree().quit()
