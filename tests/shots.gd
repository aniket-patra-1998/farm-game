extends Node
## Renders screenshots of every building, at small and full size, for checking the art.
## CI runs it with a real renderer: xvfb-run godot --rendering-method gl_compatibility res://tests/shots.tscn
## Images land in ci_shots/ next to the project. Your real save is never touched.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _main: Node


func _ready() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	# A clean field, so every piece can be seen.
	Game.objects.clear()
	for i in Game.plots.size():
		Game.plots[i] = {"state": "grass"}
	# Midday, so the colours show without night tint.
	var t := Game.now()
	Game.debug_time_offset = (12 * 3600 - t % 86400 + 86400) % 86400
	Game.farm_size = 24
	Game.xp = Game.xp_for_level(20)
	var old := Game.now() - 3 * 86400
	_put("chicken_coop", 13, 0, 1, {"chicken": 8})
	_put("cow_shed", 13, 4, 1, {"cow": 5})
	_put("horse_stable", 13, 9, 1, {"horse": 4})
	_put("nursery_barn", 13, 14, 1, {"calf": 2})
	_put("beehive", 13, 19, 1, {"bee": 10}, {"queen": true})
	_put("pig_pen", 13, 21, 1, {"pig": 4})
	_put("chicken_coop", 18, 0, 3, {"chicken": 60})
	_put("cow_shed", 18, 4, 3, {"cow": 40})
	_put("horse_stable", 18, 9, 5, {"horse": 40})
	_put("nursery_barn", 18, 14, 3, {"calf": 20})
	_put("beehive", 18, 19, 1, {"bee": 200}, {"queen": true})
	_put("orchard", 8, 12, 1, {"apple_tree": 3})
	_put("orchard", 8, 18, 3, {"cherry_tree": 9})
	_put("garage", 2, 13, 1, {"tractor": 1})
	_put("tractor", 3, 17, 1, {})
	_put("harvester", 3, 18, 1, {})
	_put("seeder", 4, 17, 1, {})
	_put("combine", 4, 18, 1, {})
	_put("combine", 5, 17, 1, {}, {"construction": {}})
	_put("duck_pond", 2, 0, 1, {"duck": 8})
	_put("sheep_pen", 2, 3, 1, {"sheep": 10})
	_put("goat_pen", 2, 6, 1, {"goat": 6})
	_put("rabbit_hutch", 2, 9, 1, {"rabbit": 3})
	var decor := ["hay_bale", "haystack", "scarecrow", "flower_bed", "pink_flamingo", "bench", "pine_tree", "water_trough",
		"bonfire", "wheelbarrow", "oak_tree", "birdhouse", "stone_wall", "birdbath", "picnic_table", "water_well",
		"garden_gnome", "lamp_post", "maple_tree", "sundial", "arbor", "wooden_bridge", "willow_tree", "hedge",
		"wooden_fence", "white_picket_fence", "dirt_path", "brick_path", "stone_path", "mastery_sign"]
	for k in decor.size():
		_put(decor[k], 6 + int(k / 6.0), k % 6, 1, {}, {"crop": "wheat"} if decor[k] == "mastery_sign" else {})
	_put("small_pond", 6, 7, 1, {})
	_put("fountain", 9, 7, 1, {})
	_put("gazebo", 6, 9, 1, {})
	_put("log_cabin", 9, 9, 1, {})
	for o in Game.objects:
		o["t"] = old
	Game.rebuild_occupancy()
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	Game.objects_changed.emit()
	Game.farm_expanded.emit(Game.farm_size)
	await _frames(10)
	var dir := ProjectSettings.globalize_path("res://ci_shots")
	DirAccess.make_dir_recursive_absolute(dir)
	_shot(dir + "/farm.png")
	# Close-ups of each row of buildings.
	var grid: FarmGrid = _main.get("grid")
	var cam: Camera2D = _main.get("camera")
	var spots := [[3, 4, "homes"], [7, 2, "decor_left"], [8, 8, "decor_right"], [3, 16, "vehicles"],
		[8, 16, "orchards"], [13, 2, "small_left"], [13, 13, "small_mid"], [13, 21, "small_right"],
		[18, 2, "big_left"], [18, 13, "big_mid"], [18, 21, "big_right"]]
	for spot in spots:
		(cam as FarmCamera).snap(grid.to_global(grid.center_of(Game.index_of(int(spot[0]) + 1, int(spot[1])))), 0.9)
		await _frames(4)
		_shot(dir + "/%s.png" % spot[2])
	# Dragging a cow: the Dairy Farms light up (the full one amber), the one under the finger brightest.
	(cam as FarmCamera).snap(grid.to_global(grid.center_of(Game.index_of(16, 5))), 0.6)
	grid.start_placing("cow")
	grid.placing["row"] = 18
	grid.placing["col"] = 5
	grid.call("_hover_home", Vector2i(13, 5))
	await _frames(6)
	_shot(dir + "/homes_highlight.png")
	grid.cancel_placing()
	# Crafting buildings at 1, 3 and 5 stars, and the newer animals, on a fresh field.
	Game.objects.clear()
	_put("bakery", 2, 1, 1, {}, {"slots": []})
	_put("winery", 2, 6, 3, {}, {"slots": []})
	_put("spa", 2, 11, 5, {}, {"slots": []})
	var bakery_uid := int(Game.objects[0]["uid"])
	Game.objects[0]["slots"] = [{"r": "pumpkin_bread", "done": Game.now() + 7200}]
	var animals := ["brown_cow", "pink_cow", "jersey_cow", "longhorn", "hereford_cow", "gelbvieh_cow",
		"galician_blond_cow",
		"red_cow", "belted_cow", "hereford_calf", "pink_calf", "gray_horse", "black_pony", "mustang", "gray_foal",
		"black_sheep", "mouflon_sheep", "saddleback_pig", "boer_goat", "arapawa_goat", "ugly_duckling", "swan",
		"belted_duck", "baby_turkey", "wild_turkey", "cornish_chicken", "turtle"]
	for k in animals.size():
		_put(animals[k], 8 + 2 * int(k / 9.0), 1 + 2 * (k % 9), 1, {})
	for o in Game.objects:
		if not Game.crafting.is_crafting(o):
			o["t"] = Game.now()
	Game.rebuild_occupancy()
	Game.objects_changed.emit()
	(cam as FarmCamera).snap(grid.to_global(grid.center_of(Game.index_of(8, 9))), 0.62)
	await _frames(6)
	_shot(dir + "/crafting_and_animals.png")
	# Every animal family through its walk cycle (four phases), grazing or pecking, and flapping or
	# displaying: a sheet for checking the rigs and gaits frame by frame.
	await _animal_sheet(dir + "/animals_walk.png", ["cow", "bull", "horse", "sheep", "goat", "pig", "donkey",
		"alpaca", "calf", "chicken", "turkey", "duck", "goose", "rabbit", "turtle", "bee"])
	# Grown-ups beside their babies: every baby shares one look (and one temperament).
	await _animal_sheet(dir + "/animals_babies.png", ["cow", "calf", "horse", "foal", "sheep", "lamb", "pig",
		"piglet", "turkey", "baby_turkey", "duck", "ugly_duckling", "hereford_cow", "hereford_calf", "black_pony",
		"gray_foal"])
	# The same farm a moment later, so the animals are caught mid-stride.
	await _frames(40)
	_shot(dir + "/animals_moving.png")
	# How long a frame's game logic and drawing take with these animals walking about (printed for the log).
	var process_ms := 0.0
	for k in 120:
		await RenderingServer.frame_post_draw
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	print("PERF animals=%d process_ms_avg=%.2f" % [Game.objects.size(), process_ms / 120.0])
	# Where it goes: drawing one animal, timed directly; and the same farm with the animals hidden.
	var probe := Node2D.new()
	var draw_us := [0]
	probe.draw.connect(func() -> void:
		var t0 := Time.get_ticks_usec()
		for k in 100:
			AnimalArt.draw(probe, Vector2(100, 100), Game.item_data("cow"), false, null)
		draw_us[0] = Time.get_ticks_usec() - t0)
	add_child(probe)
	await _frames(3)
	print("PERF one_cow_draw_us=%.1f" % (draw_us[0] / 100.0))
	probe.queue_free()
	var objects_layer: Node = grid.get("pieces")
	var behaviour_us := 0
	for k in 30:
		var t1 := Time.get_ticks_usec()
		for v in (objects_layer.get("pieces") as Dictionary).values():
			var fp := v as FarmPiece
			if fp.animal != null:
				fp.animal.update(1.0 / 60.0)
		behaviour_us += Time.get_ticks_usec() - t1
	print("PERF behaviour_all_us=%.1f" % (behaviour_us / 30.0))
	objects_layer.process_mode = Node.PROCESS_MODE_DISABLED
	process_ms = 0.0
	for k in 60:
		await RenderingServer.frame_post_draw
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	print("PERF without_object_layer_process_ms_avg=%.2f" % (process_ms / 60.0))
	objects_layer.process_mode = Node.PROCESS_MODE_INHERIT
	# The Bakery's panel, mid-game.
	Game.crafting.bushels = {"pumpkins": 6, "wheat": 9, "strawberries": 2, "carrots": 3}
	Game.crafting.goods = {"pumpkin_bread": 2, "spicy_muffins": 1}
	Game.crafting.crafted = {"pumpkin_bread": 16, "spicy_muffins": 6}
	Game.objects[0]["level"] = 2
	(_main.get("hud") as FarmHud).show_building(bakery_uid)
	await _frames(6)
	_shot(dir + "/crafting_panel.png")
	(_main.get("hud") as FarmHud)._book.close_panel()
	# Times of day and weather, on a farm of crops (using whatever finished art is in art/final).
	Game.objects.clear()
	var art_crops := [
		"strawberries",
		"raspberries",
		"blueberries",
		"cranberries",
		"blackberries",
		"elderberries",
		"wheat",
		"corn"
	]
	var plots: Array[int] = []
	for r in range(3, 13):
		for c in range(3, 13):
			var i := Game.index_of(r, c)
			Game.plots[i] = {"state": "planted", "crop": art_crops[(r + c) % art_crops.size()], "planted_at": 0}
			plots.append(i)
	_put("farmhouse", 3, 14, 1, {})
	_put("lamp_post", 8, 14, 1, {})
	_put("bonfire", 10, 15, 1, {})
	_put("bakery", 12, 14, 1, {}, {"slots": []})
	_put("cow", 13, 4, 1, {})
	_put("sheep", 13, 7, 1, {})
	Game.rebuild_occupancy()
	(cam as FarmCamera).snap(grid.to_global(grid.center_of(Game.index_of(8, 10))), 0.75)
	var scenes := [["noon_clear", 12.5, "clear"], ["partly_cloudy", 11.0, "partly_cloudy"],
		["golden_hour", 18.3, "clear"], ["night", 22.0, "clear"], ["rain", 14.0, "rain"], ["storm", 16.0, "storm"],
		["fog", 6.8, "fog"], ["snow", 13.0, "snow"]]
	for scene in scenes:
		var wall := int(Time.get_unix_time_from_system())
		Game.debug_time_offset = (int(float(scene[1]) * 3600) - wall % 86400 + 86400) % 86400
		Game.weather_override = scene[2]
		for k in plots.size():
			var crop: Dictionary = Game.crops[Game.plots[plots[k]]["crop"]]
			var grow := int(crop["grow_seconds"])
			var stage: float = [0.2, 0.6, 1.05, 3.0][k % 4] # planted, growing, ripe, withered
			Game.plots[plots[k]]["planted_at"] = Game.now() - int(grow * stage) - (
				Game.ripe_window(crop) if stage > 2.0 else 0
			)
		Game.objects_changed.emit()
		Game.plot_changed.emit(-1)
		await _frames(30)
		_shot(dir + "/time_%s.png" % scene[0])
	Game.weather_override = ""
	# A brand-new farm, framed the way a new player first sees it.
	Game.debug_time_offset = (int(12.0 * 3600) - int(Time.get_unix_time_from_system()) % 86400 + 86400) % 86400
	Game.reset_game()
	Game.objects_changed.emit()
	Game.plot_changed.emit(-1)
	Game.farm_expanded.emit(Game.farm_size)
	await _frames(20)
	_shot(dir + "/start.png")
	await _shots_3d(dir)
	print("Screenshots saved to " + dir)
	get_tree().quit()


func _put(id: String, row: int, col: int, level: int, inside: Dictionary, extra := {}) -> void:
	var o := {"uid": Game.next_uid, "id": id, "row": row, "col": col, "t": Game.now(), "level": level, "inside": inside}
	o.merge(extra)
	Game.next_uid += 1
	Game.objects.append(o)


func _frames(n: int) -> void:
	for k in n:
		await RenderingServer.frame_post_draw


func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)


func _animal_sheet(path: String, ids: Array) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	var bg := ColorRect.new()
	bg.color = Color("#8fbf5a")
	bg.size = Vector2(1280, 720)
	layer.add_child(bg)
	var sheet := Node2D.new()
	sheet.draw.connect(func() -> void:
		for row in ids.size():
			var it := Game.item_data(ids[row])
			if it.is_empty():
				continue
			var col_x := 45.0 + (row % 2) * 630.0
			var y := 66.0 + int(row / 2.0) * 84.0
			for k in 7:
				var p := AnimalPose.new()
				p.time = 0.4 * k
				if k < 4:
					p.stride = 1.0
					p.gait = k * 0.25
				elif k == 4:
					p.head = 1.0
					p.jaw = 0.6
				elif k == 5:
					p.wing = 1.0
					p.display = 1.0
					p.hop = 1.0
				else:
					p.look = 1.0
					p.blink = 1.0
					p.tail = 0.4
				AnimalArt.draw(sheet, Vector2(col_x + 86.0 * k, y), it, k == 6, p))
	layer.add_child(sheet)
	add_child(layer)
	await _frames(4)
	_shot(path)
	layer.queue_free()
	await _frames(1)


## The same farm drawn in 3D (project setting farm/world/use_3d): a mixed farm at noon and at golden hour,
## a close-up of the buildings, and a brand-new farm.
func _shots_3d(dir: String) -> void:
	_main.queue_free()
	await _frames(2)
	ProjectSettings.set_setting(Farm3D.SETTING, true)
	Game.reset_game()
	# Noon, so the crops planted below are at the stages they're planted at when the close-ups are taken.
	Game.debug_time_offset = (int(12.5 * 3600) - int(Time.get_unix_time_from_system()) % 86400 + 86400) % 86400
	Game.farm_size = 24
	Game.xp = Game.xp_for_level(30)
	Game.objects.clear()
	for i in Game.plots.size():
		Game.plots[i] = {"state": "grass"}
	_put("chicken_coop", 2, 2, 1, {"chicken": 8})
	_put("cow_shed", 2, 7, 1, {"cow": 5})
	_put("horse_stable", 2, 13, 1, {"horse": 4})
	_put("barn", 2, 19, 1, {})
	_put("pig_pen", 8, 2, 1, {"pig": 4})
	_put("nursery_barn", 8, 7, 1, {"calf": 2})
	_put("beehive", 8, 13, 1, {"bee": 10})
	_put("duck_pond", 8, 17, 1, {"duck": 4})
	_put("bakery", 14, 2, 1, {}, {"slots": []})
	_put("winery", 14, 7, 1, {}, {"slots": []})
	_put("garage", 14, 12, 1, {})
	_put("orchard", 13, 20, 1, {"apple_tree": 3})
	_put("horse_stable", 18, 2, 1, {}, {"construction": {}})
	_put("garden_shed", 18, 8, 1, {})
	var loose: Array[String] = ["cow", "horse", "sheep", "pig", "goat", "calf", "foal", "chicken", "turkey",
		"duck", "brown_cow", "rabbit", "donkey", "lamb", "goose", "piglet"]
	for k in loose.size():
		_put(loose[k], 11 + int(k / 8.0), 2 + (k % 8) * 2, 1, {})
	var fruit_trees: Array[String] = ["apple_tree", "cherry_tree", "lemon_tree"]
	for k in 6:
		_put(fruit_trees[k % 3], 22 + int(k / 3.0), 2 + 2 * (k % 3), 1, {})
	# A field of every plant shape at every stage: seeds, sprouting, young, ripe, withered, plowed.
	var shapes: Array[String] = ["wheat", "corn", "strawberries", "tomatoes", "pumpkins", "carrots", "cabbage",
		"sunflowers", "lavender", "cotton"]
	var stages: Array[float] = [0.1, 0.3, 0.7, 1.05, 3.0, -1.0]
	for k in shapes.size():
		for s in stages.size():
			var i := Game.index_of(17 + s, 12 + k)
			if stages[s] < 0.0:
				Game.plots[i] = {"state": "plowed"}
				continue
			var grow := int(Game.crops[shapes[k]]["grow_seconds"])
			Game.plots[i] = {"state": "planted", "crop": shapes[k], "planted_at": Game.now() - int(grow * stages[s])
				- (Game.ripe_window(Game.crops[shapes[k]]) if stages[s] > 2.0 else 0)}
	Game.rebuild_occupancy()
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	Game.objects_changed.emit()
	Game.plot_changed.emit(-1)
	Game.farm_expanded.emit(Game.farm_size)
	for scene in [["noon", 12.5, "clear"], ["golden_hour", 17.9, "clear"], ["night", 22.5, "clear"]]:
		var wall := int(Time.get_unix_time_from_system())
		Game.debug_time_offset = (int(float(scene[1]) * 3600) - wall % 86400 + 86400) % 86400
		Game.weather_override = scene[2]
		await _frames(20)
		_shot(dir + "/world3d_%s.png" % scene[0])
	var grid: FarmGrid = _main.get("grid")
	var cam: FarmCamera = _main.get("camera")
	Game.debug_time_offset = (int(12.5 * 3600) - int(Time.get_unix_time_from_system()) % 86400 + 86400) % 86400
	cam.snap(grid.to_global(grid.center_of(Game.index_of(6, 8))), 1.1)
	await _frames(12)
	_shot(dir + "/world3d_closeup.png")
	# The animals out on the farm, close up, then again a moment later, mid-stride.
	cam.snap(grid.to_global(grid.center_of(Game.index_of(12, 7))), 1.5)
	await _frames(30)
	_shot(dir + "/world3d_animals.png")
	await _frames(45)
	_shot(dir + "/world3d_animals_later.png")
	cam.snap(grid.to_global(grid.center_of(Game.index_of(19, 16))), 1.7)
	await _frames(12)
	_shot(dir + "/world3d_crops.png")
	Game.weather_override = ""
	ProjectSettings.set_setting(Farm3D.SETTING, false)
