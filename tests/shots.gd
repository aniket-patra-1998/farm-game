extends Node
## Renders screenshots of every building, at small and full size, for checking the art.
## CI runs it with a real renderer: xvfb-run godot --rendering-method gl_compatibility res://tests/shots.tscn
## Images land in ci_shots/ next to the project. Your real save is never touched.

var _main: Node


func _ready() -> void:
	Game.saving_enabled = false
	Game.reset_game()
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
	for o in Game.objects:
		o["t"] = old
	Game._rebuild_occupancy()
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
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
	for spot in [[8, 16, "orchards"], [13, 2, "small_left"], [13, 13, "small_mid"], [13, 21, "small_right"],
			[18, 2, "big_left"], [18, 13, "big_mid"], [18, 21, "big_right"]]:
		cam.zoom = Vector2(0.9, 0.9)
		cam.position = grid.to_global(grid.center_of(Game.index_of(int(spot[0]) + 1, int(spot[1]))))
		await _frames(4)
		_shot(dir + "/%s.png" % spot[2])
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
