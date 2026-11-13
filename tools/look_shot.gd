extends Node
## Before and after: fixed views of the showcase farm, for comparing one change at a time. Writes five pictures
## (all, buildings, trees_animals, crops, fences) into the folder given by --out=<dir> (default ci_shots/look).
## Needs a renderer:
##   xvfb-run godot --rendering-method gl_compatibility --path . res://tools/look_shot.tscn -- --out=/tmp/before
## tools/look_compare.py joins two such folders side by side.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const VIEWS := [["all", 15, 15, 0.55], ["buildings", 4, 8, 1.0], ["trees_animals", 20, 12, 1.0], ["crops", 27, 14, 1.3]]
const NOON := 12.5


func _ready() -> void:
	var out := "res://ci_shots/look"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	Game.saving_enabled = false
	Game.reset_game()
	ProjectSettings.set_setting(Farm3D.SETTING, true)
	Game.debug_time_offset = (int(NOON * 3600) - int(Time.get_unix_time_from_system()) % 86400 + 86400) % 86400
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	Game.open_showcase()
	for k in 12:
		await RenderingServer.frame_post_draw
	var cam: FarmCamera = main.get("camera")
	var grid: FarmGrid = main.get("grid")
	var views: Array = VIEWS.duplicate()
	var run := _link_run_centre()
	if run.x >= 0:
		views.append(["fences", run.x, run.y, 1.4])
	for v: Array in views:
		cam.snap(grid.to_global(grid.center_of(Game.index_of(int(v[1]), int(v[2])))), float(v[3]))
		for k in 16:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/" + str(v[0]) + ".png"))
	get_tree().quit()


## (row, col) in the middle of the showcase's straight runs of fence, hedge and wall, or (-1, -1) if it has none.
func _link_run_centre() -> Vector2i:
	var rows := 0
	var cols := 0
	var n := 0
	for o in Game.objects:
		if ShowcaseFarm.RUN_IDS.has(str(o["id"])):
			rows += int(o["row"])
			cols += int(o["col"])
			n += 1
	return Vector2i(rows / n, cols / n) if n > 0 else Vector2i(-1, -1)
