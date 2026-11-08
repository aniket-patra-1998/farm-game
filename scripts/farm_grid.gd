class_name FarmGrid
extends Node2D
## Draws the isometric farm and turns taps and drags into farm actions.
## Rules live in the Game autoload; this script only decides what a tap means.

signal info(text: String)

const N := GameState.GRID_SIZE
const TILE_W := 128.0
const TILE_H := 64.0
const EDGE_DEPTH := 28.0
const HEADROOM := 48.0 # space above the back row for tall crops

const COLOR_COINS := Color("#ffd23f")
const COLOR_XP := Color("#9be7ff")
const COLOR_COST := Color("#ffb4a8")

var tool := "plow"       # "plow", "plant" or "harvest"
var selected_crop := ""  # crop id when tool == "plant"

var _painting := false
var _last_index := -1


func _ready() -> void:
	Game.plot_changed.connect(func(_i: int) -> void: queue_redraw())
	# Crops change growth stage over time; redraw once a second.
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(queue_redraw)
	add_child(timer)


func set_tool(tool_name: String, crop_id: String) -> void:
	tool = tool_name
	selected_crop = crop_id


func get_bounds() -> Rect2:
	return Rect2(
		Vector2(-N * TILE_W / 2.0, -HEADROOM),
		Vector2(N * TILE_W, N * TILE_H + EDGE_DEPTH + HEADROOM))


# ---------------------------------------------------------------- geometry

## Screen position of a plot's top corner, in this node's local space.
func top_of(row: int, col: int) -> Vector2:
	return Vector2((col - row) * TILE_W / 2.0, (col + row) * TILE_H / 2.0)


func center_of(i: int) -> Vector2:
	return top_of(_row(i), _col(i)) + Vector2(0, TILE_H / 2.0)


func index_at(local_pos: Vector2) -> int:
	var dx := local_pos.x / (TILE_W / 2.0)
	var dy := local_pos.y / (TILE_H / 2.0)
	var col := int(floor((dy + dx) / 2.0))
	var row := int(floor((dy - dx) / 2.0))
	if row < 0 or col < 0 or row >= N or col >= N:
		return -1
	return Game.index_of(row, col)


func _row(i: int) -> int:
	return int(float(i) / N)


func _col(i: int) -> int:
	return i % N


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	PlaceholderArt.draw_farm_edges(self, N, TILE_W, TILE_H, EDGE_DEPTH)
	# Back to front, so taller crops overlap the plots behind them.
	for diag in range(2 * N - 1):
		for row in range(N):
			var col := diag - row
			if col < 0 or col >= N:
				continue
			_draw_plot(Game.index_of(row, col), row, col)


func _draw_plot(i: int, row: int, col: int) -> void:
	var top := top_of(row, col)
	var ph := Game.phase(i)
	if ph == GameState.Phase.GRASS:
		PlaceholderArt.draw_grass(self, top, TILE_W, TILE_H, i * 7919, (row + col) % 2 == 0)
		return
	PlaceholderArt.draw_soil(self, top, TILE_W, TILE_H, ph != GameState.Phase.PLOWED)
	if ph == GameState.Phase.PLOWED:
		return
	var crop: Dictionary = Game.crops[Game.crop_at(i)]
	var stage := "growing"
	if ph == GameState.Phase.RIPE:
		stage = "ripe"
	elif ph == GameState.Phase.WITHERED:
		stage = "withered"
	PlaceholderArt.draw_crop(self, top + Vector2(0, TILE_H / 2.0), TILE_W, TILE_H, crop, stage, Game.growth(i))


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	# Mouse is emulated as touch (project setting), so this one path covers both.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index != 0:
			return
		if touch.pressed:
			_painting = true
			_last_index = -1
			_apply_at(touch.position, true)
		else:
			_painting = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _painting and drag.index == 0:
			_apply_at(drag.position, false)


func _apply_at(screen_pos: Vector2, first_touch: bool) -> void:
	var world := get_canvas_transform().affine_inverse() * screen_pos
	var i := index_at(to_local(world))
	if i < 0 or i == _last_index:
		return
	_last_index = i
	_act(i, first_touch)


## first_touch is true for the plot under the finger when it went down;
## dragging across plots repeats the action without info popups.
func _act(i: int, first_touch: bool) -> void:
	var ph := Game.phase(i)
	var at := center_of(i)

	# A ripe crop is harvested by any tool: tapping ripe crops should always just work.
	if ph == GameState.Phase.RIPE:
		var result := Game.harvest(i)
		if not result.is_empty():
			_float(at, "+%d" % result["coins"], COLOR_COINS)
			_float(at + Vector2(0, -30), "+%d XP" % result["xp"], COLOR_XP)
		return

	match tool:
		"plow":
			if ph == GameState.Phase.GRASS or ph == GameState.Phase.WITHERED:
				if Game.plow(i):
					_float(at, "-%d" % GameState.PLOW_COST, COLOR_COST)
			elif first_touch:
				_explain(i, ph)
		"plant":
			if ph == GameState.Phase.PLOWED and selected_crop != "":
				if Game.plant(i, selected_crop):
					_float(at, "-%d" % int(Game.crops[selected_crop]["seed_cost"]), COLOR_COST)
			elif first_touch:
				_explain(i, ph)
		"harvest":
			if first_touch:
				_explain(i, ph)


func _explain(i: int, ph: GameState.Phase) -> void:
	match ph:
		GameState.Phase.GRASS:
			info.emit("Plow this plot first")
		GameState.Phase.PLOWED:
			info.emit("Pick a seed to plant here")
		GameState.Phase.GROWING:
			var crop: Dictionary = Game.crops[Game.crop_at(i)]
			info.emit("%s: ready in %s" % [crop["name"], format_duration(Game.seconds_until_ripe(i))])
		GameState.Phase.WITHERED:
			info.emit("These crops withered. Plow to clear the plot.")


static func format_duration(seconds: int) -> String:
	if seconds < 60:
		return "less than a minute"
	var d := int(seconds / 86400.0)
	var h := int((seconds % 86400) / 3600.0)
	var m := int((seconds % 3600) / 60.0)
	if d > 0:
		return "%dd %dh" % [d, h]
	if h > 0:
		return "%dh %dm" % [h, m]
	return "%dm" % m


func _float(pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 40)
	label.position = pos - Vector2(80, 30)
	label.z_index = 10
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.05))
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60.0, 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
