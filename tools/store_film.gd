extends Node
## The moving pictures for the store's preview video (docs/STORE.md): slow passes over the showcase farm with the
## interface hidden, filmed by Godot's movie writer; tools/make_store_film.sh cuts them into scenes under their
## captions. Prints where each scene starts ("FILM <name> <first frame> <frames>"). --hour=<h> as look_shot;
## --scenes=<a,b,...> films only the named ones. Needs a renderer and the movie writer:
##   xvfb-run godot --rendering-method gl_compatibility --fixed-fps 30 --resolution 1280x720 \
##       --write-movie /tmp/film.avi --path . res://tools/store_film.tscn -- --hour=16

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SETTLE_SECONDS := 300.0
const SCENE_FRAMES := 105   # three and a half seconds at 30 frames a second
const LEAD_FRAMES := 20     # frames before a scene starts, for the view to fill in
const AIMED_FROM := Vector2(1.0, -1.5)   # an aimed scene's pass, from the middle of what it is aimed at (row, col)
const AIMED_TO := Vector2(1.0, 1.5)
## [name, from (row, col), to (row, col), zoom at the start, zoom at the end]. "landmarks" and "homes" are aimed
## at what stands on the farm (`_aimed`).
const SCENES := [["landmarks", Vector2(0, 0), Vector2(0, 0), 0.9, 1.05],
	["crops", Vector2(27, 12), Vector2(25, 18), 1.3, 1.3],
	["animals", Vector2(21, 10), Vector2(19, 14), 1.15, 1.15], ["homes", Vector2(0, 0), Vector2(0, 0), 1.3, 1.45]]


func _ready() -> void:
	var hour := 16.0
	var only: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hour="):
			hour = a.trim_prefix("--hour=").to_float()
		elif a.begins_with("--scenes="):
			only.assign(a.trim_prefix("--scenes=").split(","))
	Game.saving_enabled = false
	Game.reset_game()
	ProjectSettings.set_setting(Farm3D.SETTING, true)
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	Game.open_showcase()
	var local_now := int(Time.get_unix_time_from_system()) + DayCycle.device_bias_minutes() * 60
	Game.debug_time_offset = posmod(int(hour * 3600) - local_now, 86400)
	Game.weather_override = "clear"
	for sw: Node in get_tree().root.find_children("*", "SurfaceWeather", true, false):   # not-ui
		(sw as SurfaceWeather).advance(Game.weather(), SETTLE_SECONDS)
	Game.goals.showcase()
	await Objects3D.until_settled(get_tree())
	var cam: FarmCamera = main.get("camera")
	var grid: FarmGrid = main.get("grid")
	(main.get("hud") as FarmHud).visible = false
	for s: Array in SCENES:
		if not (only.is_empty() or only.has(str(s[0]))):
			continue
		var from: Vector2 = s[1]
		var to: Vector2 = s[2]
		if from == Vector2.ZERO:   # (a pass along the row in front of them: the things may stand on the farm's edge)
			var middle := _aimed(str(s[0]))
			from = middle + AIMED_FROM
			to = middle + AIMED_TO
		var a := grid.to_global(grid.center_of(Game.index_of(int(from.x), int(from.y))))
		var b := grid.to_global(grid.center_of(Game.index_of(int(to.x), int(to.y))))
		cam.snap(a, float(s[3]))
		for k in LEAD_FRAMES:
			await RenderingServer.frame_post_draw
		print("FILM %s %d %d" % [s[0], Engine.get_process_frames(), SCENE_FRAMES])
		for k in SCENE_FRAMES:
			var t := float(k) / (SCENE_FRAMES - 1)
			cam.snap(a.lerp(b, t), lerpf(float(s[3]), float(s[4]), t))
			await RenderingServer.frame_post_draw
	get_tree().quit()


## Where a scene aimed at things on the farm starts: the middle of those things, as (row, col).
func _aimed(scene: String) -> Vector2:
	var rows := 0.0
	var cols := 0.0
	var n := 0
	for o in Game.objects:
		var id := str(o["id"])
		if (scene == "landmarks" and Objects3D.stands_alone(id)) or (scene == "homes" and Game.is_home(o)):
			rows += float(o["row"])
			cols += float(o["col"])
			n += 1
	return Vector2(rows / maxi(n, 1), cols / maxi(n, 1))
