extends Node
## Before and after: fixed views of the showcase farm, for comparing one change at a time. Writes nine pictures
## (all, buildings, trees_animals, crops, fences, orchard, orchard_far, garage, barn_broken, home_panel,
## crafting_panel, seeds_panel, collections_panel, ribbons_panel,
## inbox_panel) into the folder given
## by --out=<dir> (default ci_shots/look).
## --hour=<h> shows another local hour than noon (6 dawn, 18.5 dusk, 22 night).
## Needs a renderer:
##   xvfb-run godot --rendering-method gl_compatibility --path . res://tools/look_shot.tscn -- --out=/tmp/before
## tools/look_compare.py joins two such folders side by side.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const VIEWS := [["all", 15, 15, 0.55], ["buildings", 4, 8, 1.0], ["trees_animals", 20, 12, 1.0], ["crops", 27, 14, 1.3]]
const NOON := 12.5


func _ready() -> void:
	var out := "res://ci_shots/look"
	var level := ""
	var hour := NOON
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--hour="):   # the local hour to show (default noon), e.g. 6 dawn, 18.5 dusk, 22 night
			hour = float(a.substr(7))
		elif a.begins_with("--quality="):   # low, mid or high (default: this computer's choice)
			level = a.substr(10)
	var was_level := Quality.level()
	if level != "":
		Quality.choose(level)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	Game.saving_enabled = false
	Game.reset_game()
	ProjectSettings.set_setting(Farm3D.SETTING, true)
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	Game.open_showcase()
	# (after the showcase is built: building it starts a fresh farm, which clears the clock offset)
	var local_now := int(Time.get_unix_time_from_system()) + DayCycle.device_bias_minutes() * 60
	Game.debug_time_offset = posmod(int(hour * 3600) - local_now, 86400)
	await Objects3D.until_settled(get_tree())
	for k in 12:
		await RenderingServer.frame_post_draw
	var cam: FarmCamera = main.get("camera")
	var grid: FarmGrid = main.get("grid")
	var views: Array = VIEWS.duplicate()
	var run := _centre_of(func(o: Dictionary) -> bool: return ShowcaseFarm.RUN_IDS.has(str(o["id"])))
	if run.x >= 0:
		views.append(["fences", run.x, run.y, 1.4])
	var orchard := _centre_of(func(o: Dictionary) -> bool: return str(o["id"]) == "orchard")
	if orchard.x >= 0:
		views.append(["orchard", orchard.x, orchard.y, 1.5])
		views.append(["orchard_far", orchard.x, orchard.y, 0.3])   # far enough for its trees' far look
	var garage := _centre_of(func(o: Dictionary) -> bool: return str(o["id"]) == "garage")
	if garage.x >= 0:
		views.append(["garage", garage.x, garage.y, 1.8])
	var barn := Game.storage.barn()
	if not barn.is_empty():
		views.append(["barn_broken", int(barn["row"]) + 1, int(barn["col"]) + 1, 1.8])
	for v: Array in views:
		if str(v[0]) == "barn_broken":   # the starter Barn as it is before it is repaired
			barn["broken"] = true
			Game.objects_updated()
		cam.snap(grid.to_global(grid.center_of(Game.index_of(int(v[1]), int(v[2])))), float(v[3]))
		for k in 16:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/" + str(v[0]) + ".png"))
	if not barn.is_empty():
		barn.erase("broken")   # (the showcase's Barn is repaired; the shot only borrowed the broken look)
	# Panels: the fullest home, and a crafting building.
	var hud := main.get("hud") as FarmHud
	var homes := Game.objects.filter(func(o: Dictionary) -> bool: return Game.is_home(o))
	homes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["inside"].size() > b["inside"].size())
	var crafting := Game.objects.filter(func(o: Dictionary) -> bool: return str(o["id"]) == "bakery")
	for p: Array in [["home_panel", homes], ["crafting_panel", crafting]]:
		if (p[1] as Array).is_empty():
			continue
		hud.show_building(int(p[1][0]["uid"]))
		for k in 60:   # (the item pictures are drawn a few a frame)
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/" + str(p[0]) + ".png"))
		hud.book.close_panel()
	for p: Array in [["seeds_panel", hud.show_seeds], ["collections_panel", hud.show_collections],
			["ribbons_panel", hud.show_ribbons], ["inbox_panel", hud.show_inbox]]:
		(p[1] as Callable).call()
		for k in 90:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/" + str(p[0]) + ".png"))
		hud.book.close_panel()
	if level != "":
		Quality.choose(was_level)
	get_tree().quit()


## (row, col) in the middle of the showcase's objects that `wanted` picks, or (-1, -1) if there are none.
func _centre_of(wanted: Callable) -> Vector2i:
	var rows := 0
	var cols := 0
	var n := 0
	for o in Game.objects:
		if wanted.call(o):
			rows += int(o["row"])
			cols += int(o["col"])
			n += 1
	return Vector2i(rows / n, cols / n) if n > 0 else Vector2i(-1, -1)
