class_name FarmGrid
extends Node2D
## Draws the isometric farm and turns taps and drags into farm actions.
## Rules live in the Game autoload; this script only decides what a tap means.

signal info(text: String)
signal object_tapped(uid: int)        # a building was tapped while not ready
signal placing_changed(text: String)  # "" when placement ends

const N := GameState.GRID_SIZE
const TILE_W := 128.0
const TILE_H := 64.0
const EDGE_DEPTH := 28.0
const HEADROOM := 48.0 # space above the back row for tall crops

const COLOR_COINS := Color("#ffd23f")
const COLOR_XP := Color("#9be7ff")
const COLOR_COST := Color("#ffb4a8")
const COLOR_FIND := Color("#ff9ad5")
const COLOR_GOLDEN := Color("#ffe066")
const COLOR_FERT := Color("#8fe36b")

var tool := "plow"       # "plow", "plant", "fertilize", "hand" or "move"
var selected_crop := ""  # crop id when tool == "plant"

var _painting := false
var _last_index := -1

## While placing: {"item": id, "uid": -1 for a new purchase or the uid being moved,
## "row", "col"} for the footprint's back corner; row is -1 until the first touch.
var placing := {}


func _ready() -> void:
	Game.plot_changed.connect(func(_i: int) -> void: queue_redraw())
	# Crops change growth stage over time and ripe crops twinkle; redraw ten times a second.
	var timer := Timer.new()
	timer.wait_time = 0.1
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
	# Each object is drawn right after its front tile, so depth order stays right.
	var after_tile := {}
	var lifted := int(placing.get("uid", -1))
	for o in Game.objects:
		if int(o["uid"]) == lifted:
			continue
		var fp := Game.footprint(o["id"])
		var front := Game.index_of(int(o["row"]) + fp.y - 1, int(o["col"]) + fp.x - 1)
		if not after_tile.has(front):
			after_tile[front] = []
		after_tile[front].append(o)
	# Back to front, so taller crops overlap the plots behind them.
	for diag in range(2 * N - 1):
		for row in range(N):
			var col := diag - row
			if col < 0 or col >= N:
				continue
			var i := Game.index_of(row, col)
			_draw_plot(i, row, col)
			for o in after_tile.get(i, []):
				_draw_object(o)
	_draw_placing()


## The four ground corners (top, right, bottom, left) of a footprint.
func corners_of(row: int, col: int, w: int, h: int) -> PackedVector2Array:
	return PackedVector2Array([top_of(row, col), top_of(row, col + w), top_of(row + h, col + w), top_of(row + h, col)])


func _draw_object(o: Dictionary) -> void:
	var it := Game.item_data(o["id"])
	var fp := Game.footprint(o["id"])
	var corners := corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
	var is_ready_now := Game.is_ready(o)
	var building := Game.is_building(o)
	PlaceholderArt.draw_object(self, it, corners, is_ready_now, int(o.get("level", 1)),
		Game.inside_total(o) if building else 0, Game.capacity(o) if building else 0)
	if is_ready_now:
		var t := Time.get_ticks_msec() / 1000.0
		var glow := 0.5 + 0.5 * sin(t * 2.6 + float(int(o["uid"]) % 7))
		var c := (corners[0] + corners[2]) / 2.0
		PlaceholderArt.draw_twinkle(self, c + Vector2(22, -70 if not building else -110), 11.0 + 6.0 * glow, glow)


func _draw_placing() -> void:
	if placing.is_empty() or int(placing["row"]) < 0:
		return
	var it := Game.item_data(placing["item"])
	var fp := Game.footprint(placing["item"])
	var row := int(placing["row"])
	var col := int(placing["col"])
	var corners := corners_of(row, col, fp.x, fp.y)
	var ok := Game.can_place(placing["item"], row, col, int(placing["uid"]))
	PlaceholderArt.draw_footprint(self, corners, ok)
	var level := 1
	var inside := 0
	var cap := 0
	if int(placing["uid"]) != -1:
		var o := Game.object_by_uid(int(placing["uid"]))
		level = int(o.get("level", 1))
		if Game.is_building(o):
			inside = Game.inside_total(o)
			cap = Game.capacity(o)
	elif it.get("kind", "") == "building":
		cap = int(it["levels"][0])
	PlaceholderArt.draw_object(self, it, corners, false, level, inside, cap)


func _draw_plot(i: int, row: int, col: int) -> void:
	var top := top_of(row, col)
	var ph := Game.phase(i)
	if ph == GameState.Phase.GRASS or Game.is_occupied(i):
		PlaceholderArt.draw_grass(self, top, TILE_W, TILE_H, i * 7919, (row + col) % 2 == 0)
		return
	PlaceholderArt.draw_soil(self, top, TILE_W, TILE_H, ph != GameState.Phase.PLOWED)
	if Game.is_fertilized(i):
		PlaceholderArt.draw_fertilizer(self, top, TILE_W, TILE_H)
	if ph == GameState.Phase.PLOWED:
		return
	var crop: Dictionary = Game.crops[Game.crop_at(i)]
	var stage := "growing"
	if ph == GameState.Phase.RIPE:
		stage = "ripe"
	elif ph == GameState.Phase.WITHERED:
		stage = "withered"
	PlaceholderArt.draw_crop(self, top + Vector2(0, TILE_H / 2.0), TILE_W, TILE_H, crop, stage, Game.growth(i))
	if stage == "ripe":
		# Each plot twinkles on its own beat, so a ripe field shimmers instead of blinking.
		var t := Time.get_ticks_msec() / 1000.0
		var phase_offset := float(i % 7) * 0.9
		var glow := 0.5 + 0.5 * sin(t * 2.6 + phase_offset)
		var spot := top + Vector2(TILE_W * 0.12 * (1 if i % 2 == 0 else -1), TILE_H * 0.05)
		PlaceholderArt.draw_twinkle(self, spot, 9.0 + 5.0 * glow, glow)


func cancel_paint() -> void:
	_painting = false


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not placing.is_empty():
		_placing_input(event)
		return
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
		# With the Hand tool a drag moves the camera (main.gd), so it never farms.
		if _painting and drag.index == 0 and tool != "hand" and tool != "move":
			_apply_at(drag.position, false)


func _on_farm_area(screen_pos: Vector2) -> bool:
	var view_h := get_viewport().get_visible_rect().size.y
	return not Game.modal_open and screen_pos.y >= FarmHud.TOP_H and screen_pos.y <= view_h - FarmHud.BOTTOM_H


## Tile (row, col) under a screen point, even outside the farm.
func _tile_at_screen(screen_pos: Vector2) -> Vector2i:
	var local := to_local(get_canvas_transform().affine_inverse() * screen_pos)
	var dx := local.x / (TILE_W / 2.0)
	var dy := local.y / (TILE_H / 2.0)
	return Vector2i(int(floor((dy - dx) / 2.0)), int(floor((dy + dx) / 2.0)))


# ---------------------------------------------------------------- placing and moving

func start_placing(item_id: String, uid := -1) -> void:
	placing = {"item": item_id, "uid": uid, "row": -1, "col": -1}
	if uid != -1:
		var o := Game.object_by_uid(uid)
		placing["row"] = int(o["row"])
		placing["col"] = int(o["col"])
	var verb := "move" if uid != -1 else "place"
	placing_changed.emit("Drag to %s the %s, then let go" % [verb, Game.item_data(item_id)["name"]])
	queue_redraw()


func cancel_placing() -> void:
	placing = {}
	placing_changed.emit("")
	queue_redraw()


## Press or drag shows where the object will go; letting go places it if it fits.
func _placing_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var released := false
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.index != 0:
			return
		pos = t.position
		released = not t.pressed
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index != 0:
			return
		pos = d.position
	else:
		return
	if not _on_farm_area(pos):
		return
	var fp := Game.footprint(placing["item"])
	var tile := _tile_at_screen(pos)
	# Centre the footprint under the finger.
	placing["row"] = tile.x - int(fp.y / 2.0)
	placing["col"] = tile.y - int(fp.x / 2.0)
	queue_redraw()
	if not released:
		return
	var row := int(placing["row"])
	var col := int(placing["col"])
	var uid := int(placing["uid"])
	if not Game.can_place(placing["item"], row, col, uid):
		info.emit("It doesn't fit there. Try an open grassy spot.")
		return
	var ok := Game.move_object(uid, row, col) if uid != -1 else Game.buy_and_place(placing["item"], row, col)
	if ok:
		if uid == -1:
			_float(corners_of(row, col, fp.x, fp.y)[2], "-%d" % int(Game.item_data(placing["item"])["cost"]), COLOR_COST)
		cancel_placing()


func _apply_at(screen_pos: Vector2, first_touch: bool) -> void:
	# Ignore touches on the top bar, the toolbar, or while a menu covers the farm.
	if not _on_farm_area(screen_pos):
		return
	var world := get_canvas_transform().affine_inverse() * screen_pos
	var i := index_at(to_local(world))
	if i < 0 or i == _last_index:
		return
	_last_index = i
	_act(i, first_touch)


## first_touch is true for the plot under the finger when it went down;
## dragging across plots repeats the action without info popups.
func _act(i: int, first_touch: bool) -> void:
	var obj := Game.object_at(i)
	if not obj.is_empty():
		_act_on_object(obj, first_touch)
		return
	var ph := Game.phase(i)
	var at := center_of(i)

	# A ripe crop is harvested by any tool: tapping ripe crops should always just work.
	if ph == GameState.Phase.RIPE:
		var result := Game.harvest(i)
		if not result.is_empty():
			_float(at, "+%d" % result["coins"], COLOR_COINS)
			_float(at + Vector2(0, -30), "+%d XP" % result["xp"], COLOR_XP)
			if result["drop"] != "":
				var c := COLOR_GOLDEN if result["drop"] == "golden" else COLOR_FIND
				_float(at + Vector2(0, -64), result["drop_text"], c, 1.6)
				_sparkle(at, c)
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
		"fertilize":
			if ph == GameState.Phase.GROWING and not Game.is_fertilized(i):
				if Game.fertilize(i):
					_float(at, "-%d" % GameState.FERTILIZER_COST, COLOR_COST)
					_sparkle(at, COLOR_FERT)
			elif first_touch:
				if Game.is_fertilized(i):
					info.emit("Already fertilized: this harvest pays 20% more")
				else:
					info.emit("Fertilize growing crops for 20% more coins at harvest")
		"hand":
			if first_touch:
				_explain(i, ph)


func _act_on_object(obj: Dictionary, first_touch: bool) -> void:
	var uid := int(obj["uid"])
	if tool == "move":
		if first_touch:
			start_placing(obj["id"], uid)
		return
	var fp := Game.footprint(obj["id"])
	var at := (corners_of(int(obj["row"]), int(obj["col"]), fp.x, fp.y)[0] + corners_of(int(obj["row"]), int(obj["col"]), fp.x, fp.y)[2]) / 2.0
	if Game.is_ready(obj):
		var result := Game.collect(uid)
		if not result.is_empty():
			_float(at + Vector2(0, -20), "+%d" % result["coins"], COLOR_COINS)
			_float(at + Vector2(0, -50), "+%d XP" % result["xp"], COLOR_XP)
			if result["drop"] != "":
				var c := COLOR_GOLDEN if result["drop"] == "golden" else COLOR_FIND
				_float(at + Vector2(0, -84), result["drop_text"], c, 1.6)
				_sparkle(at, c)
		return
	if not first_touch:
		return
	if Game.is_building(obj):
		object_tapped.emit(uid)
		return
	var it := Game.item_data(obj["id"])
	var what: String = it.get("product", "Fruit")
	info.emit("%s: %s ready in %s" % [it["name"], what, format_duration(Game.seconds_until_ready(obj))])


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


## A short burst of dots for surprise drops, so a find feels like an event.
func _sparkle(pos: Vector2, color: Color) -> void:
	for k in 10:
		var dot := Polygon2D.new()
		var pts := PackedVector2Array()
		for j in 4:
			var a := TAU * j / 4.0 + PI / 4.0
			pts.append(Vector2(cos(a), sin(a)) * (6.0 if j % 2 == 0 else 3.0))
		dot.polygon = pts
		dot.color = color
		dot.position = pos + Vector2(0, -20)
		dot.z_index = 11
		add_child(dot)
		var dir := Vector2.from_angle(TAU * k / 10.0) * randf_range(50.0, 90.0)
		var tween := dot.create_tween().set_parallel(true)
		tween.tween_property(dot, "position", dot.position + dir, 0.7).set_ease(Tween.EASE_OUT)
		tween.tween_property(dot, "rotation", PI, 0.7)
		tween.tween_property(dot, "modulate:a", 0.0, 0.7).set_delay(0.2)
		tween.chain().tween_callback(dot.queue_free)


func _float(pos: Vector2, text: String, color: Color, duration := 1.0) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(320, 40)
	label.position = pos - Vector2(160, 30)
	label.z_index = 10
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.05))
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration).set_delay(0.3 * duration)
	tween.chain().tween_callback(label.queue_free)
