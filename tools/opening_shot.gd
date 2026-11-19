extends Node
## The opening glide (OpeningGlide), frame by frame on the showcase farm: as the cover lifts, the view comes down
## onto the farm and the light warms in. Writes opening_<n>.png at even steps of the glide into --out=<dir>
## (default ci_shots/opening). --hour=<h> another local hour (18.5 dusk); --steps=<n> pictures (default 5).
## Render at a fixed rate so the steps are even:
##   xvfb-run godot --rendering-method gl_compatibility --fixed-fps 30 --path . \
##     res://tools/opening_shot.tscn -- --out=/tmp/opening --hour=18.5

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _ready() -> void:
	var out := "res://ci_shots/opening"
	var hour := 12.5
	var steps := 5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--hour="):
			hour = float(a.substr(7))
		elif a.begins_with("--steps="):
			steps = maxi(int(a.substr(8)), 2)
	get_window().size = Vector2i(1200, 540)   # 20:9 at 1x
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
	Game.weather_override = "clear"
	await Objects3D.until_settled(get_tree())
	main.call("_fit_camera")   # (the whole-farm view a farm opens on)
	for k in 12:
		await RenderingServer.frame_post_draw
	var cam: FarmCamera = main.get("camera")
	OpeningGlide.played = false
	OpeningGlide.play(main, cam, main.get("world_3d"))
	for n in steps:
		await _until(cam, float(n) / float(steps - 1))
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/opening_%d.png" % n))
	get_tree().quit()


## Waits for the frame at which the glide has come `t` of the way.
func _until(cam: FarmCamera, t: float) -> void:
	while cam.glide_progress() < t - 0.001 and cam.glide_progress() < 1.0:
		await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
