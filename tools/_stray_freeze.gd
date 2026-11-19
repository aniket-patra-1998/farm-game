extends Node
const MAIN_SCENE := preload("res://scenes/main.tscn")
func _ready() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	ProjectSettings.set_setting(Farm3D.SETTING, true)
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	Game.xp = Game.xp_for_level(2) - 1
	await Objects3D.until_settled(get_tree())
	for k in 30:
		await RenderingServer.frame_post_draw
	var grid: FarmGrid = main.get("grid")
	for step in ["spawn", "adopt"]:
		var t0 := Time.get_ticks_msec()
		if step == "spawn":
			Game.strays._spawn_stray()
		else:
			var s: Dictionary = Game.objects.filter(func(o: Dictionary) -> bool: return o.get("stray", false))[0]
			grid._act_on_object(s, true)
		var t1 := Time.get_ticks_msec()
		var worst := 0
		var last := Time.get_ticks_msec()
		for k in 120:
			await RenderingServer.frame_post_draw
			var n := Time.get_ticks_msec()
			worst = maxi(worst, n - last)
			last = n
		print("level %d modal %s" % [Game.level(), Game.modal_open])
		print("%s: call %d ms, worst frame %d ms, 120 frames %d ms" % [step, t1 - t0, worst, last - t1])
	get_tree().quit()
