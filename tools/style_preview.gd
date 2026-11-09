extends Node
## Puts each pilot art style (art/pilot/<style>/) on a small farm and saves a screenshot per style
## to ci_shots/style_<style>.png, so styles can be judged in the game rather than on their own.

const STYLES := ["painterly", "toon3d", "semireal"]


func _ready() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.objects.clear()
	for i in Game.plots.size():
		Game.plots[i] = {"state": "grass"}
	var t := Game.now()
	Game.debug_time_offset = (12 * 3600 - t % 86400 + 86400) % 86400
	Game.farm_size = 12
	var now := Game.now()
	_put("farmhouse", 0, 0)
	_put("chicken_coop", 0, 5)
	_put("hay_bale", 0, 9)
	_put("hay_bale", 1, 9)
	for k in 4:
		_put("apple_tree", 4, 8 + k)
	for k in 3:
		_put("cow", 6 + k, 9 + (k % 2))
	# Strawberries: a row each of sprouting, growing and ripe.
	var grow := int(Game.crops["strawberries"]["grow_seconds"])
	for c in range(0, 6):
		for r in range(4, 9):
			var i := Game.index_of(r, c)
			var age: int = [int(grow * 0.1), int(grow * 0.6), grow + 60][(r - 4) % 3]
			Game.plots[i] = {"state": "planted", "crop": "strawberries", "planted_at": now - age}
	Game._rebuild_occupancy()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	Game.objects_changed.emit()
	var dir := ProjectSettings.globalize_path("res://ci_shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var cam: Camera2D = main.get("camera")
	var grid: FarmGrid = main.get("grid")
	for style in ["code"] + STYLES:
		SpriteBank.use_dir("res://art/pilot/" + style)
		grid.redraw_world()
		(cam as FarmCamera).snap(grid.to_global(grid.center_of(Game.index_of(4, 5))), 0.62)
		for k in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "/style_%s.png" % style)
		print("STYLE ", style)
	get_tree().quit()


func _put(id: String, row: int, col: int) -> void:
	Game.objects.append({"uid": Game.next_uid, "id": id, "row": row, "col": col, "t": Game.now() - 86400 * 3, "level": 1, "inside": {"chicken": 8} if id == "chicken_coop" else {}})
	Game.next_uid += 1
