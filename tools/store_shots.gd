extends Node
## The raw pictures for the Play Store's screenshots (docs/STORE.md): fixed views of the showcase farm with the
## interface hidden, and the Market open, written to the folder given by --out=<dir> (default ci_shots/store).
## tools/make_store_art.py puts each under its caption band. --hour=<h> and --weather=<state> as look_shot;
## --views=<a,b,...> takes only the named pictures; --suffix=<s> is added to each picture's name (a second run at
## night: --hour=20.5 --views=landmarks --suffix=_night). Needs a renderer:
##   xvfb-run godot --rendering-method gl_compatibility --path . res://tools/store_shots.tscn -- --hour=16

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SETTLE_SECONDS := 300.0   # how long a held weather has lasted when the pictures are taken
const SETTLE_FRAMES := 24
const PANEL_FRAMES := 120       # (the Market's pictures are drawn a few a frame)
## [name, row, col, zoom] of the fixed views; the others are aimed at things on the farm (`_views`).
const VIEWS := [["farm", 14, 14, 0.8], ["animals", 20, 12, 1.15], ["crops", 26, 16, 1.3]]
const MARKET_OPENS_ON := "cow"   # not-ui (the Market picture shows the shelf that sells this)


func _ready() -> void:
	var out := "res://ci_shots/store"
	var hour := 16.0
	var weather := "clear"
	var only: Array[String] = []
	var suffix := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--hour="):
			hour = a.trim_prefix("--hour=").to_float()
		elif a.begins_with("--weather="):
			weather = a.trim_prefix("--weather=")
		elif a.begins_with("--suffix="):
			suffix = a.trim_prefix("--suffix=")
		elif a.begins_with("--views="):
			only.assign(a.trim_prefix("--views=").split(","))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	Game.saving_enabled = false
	Game.reset_game()
	ProjectSettings.set_setting(Farm3D.SETTING, true)
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	Game.open_showcase()
	var local_now := int(Time.get_unix_time_from_system()) + DayCycle.device_bias_minutes() * 60
	Game.debug_time_offset = posmod(int(hour * 3600) - local_now, 86400)
	Game.weather_override = weather
	for sw: Node in get_tree().root.find_children("*", "SurfaceWeather", true, false):   # not-ui
		(sw as SurfaceWeather).advance(Game.weather(), SETTLE_SECONDS)
	Game.goals.showcase()
	await Objects3D.until_settled(get_tree())
	var cam: FarmCamera = main.get("camera")
	var grid: FarmGrid = main.get("grid")
	var hud := main.get("hud") as FarmHud
	hud.visible = false
	for v: Array in _views():
		if not (only.is_empty() or only.has(str(v[0]))):
			continue
		cam.snap(grid.to_global(grid.center_of(Game.index_of(int(v[1]), int(v[2])))), float(v[3]))
		for k in SETTLE_FRAMES:
			await RenderingServer.frame_post_draw
		_save(out, str(v[0]) + suffix)
	if only.is_empty() or only.has("market"):
		hud.visible = true
		hud.show_market_for(MARKET_OPENS_ON)
		for k in PANEL_FRAMES:
			await RenderingServer.frame_post_draw
		_save(out, "market" + suffix)
	get_tree().quit()


## The fixed views and one aimed at each thing worth a picture that stands on the showcase farm.
func _views() -> Array:
	var views: Array = VIEWS.duplicate()
	var aims := [["landmarks", func(o: Dictionary) -> bool: return Objects3D.stands_alone(str(o["id"])), 0.95],
		["orchard", func(o: Dictionary) -> bool: return str(o["id"]) in ["orchard", "bloom_garden"], 1.25],
		["homes", func(o: Dictionary) -> bool: return Game.is_home(o), 1.4]]
	for aim: Array in aims:
		var at := _centre_of(aim[1])
		if at.x >= 0:
			views.append([aim[0], at.x, at.y, aim[2]])
	return views


func _save(out: String, name_: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/" + name_ + ".png"))


## The middle of the things `wanted` picks, as (row, col); (-1, -1) when there are none.
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
