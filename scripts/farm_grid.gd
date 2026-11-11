class_name FarmGrid
extends Node2D
## Draws the isometric farm and turns taps and drags into farm actions.
## Rules live in the Game autoload; this script only decides what a tap means.

signal info(text: String)
signal object_tapped(uid: int)        # a building was tapped while not ready

signal placing_changed(text: String)  # "" when placement ends
signal object_poked(uid: int)         # something on the farm was tapped: it reacts (bounce, an animal looks round)
signal plants_popped(index: int, crop_id: String)  # a plot was harvested: its plants pop off
signal collected(uid: int)                         # a building or animal was collected from


const MAX := GameState.MAX_SIZE # plots are indexed on the full-size grid
const TILE_W := 128.0
const TILE_H := 64.0
const EDGE_DEPTH := 28.0
const HEADROOM := 230.0 # room above the back corner for tall things (the farmhouse sits there)
const MEADOW_MARGIN := 40  # tiles of countryside drawn around the farm
const COLOR_COINS := Color("#ffd23f")
const COLOR_XP := Color("#9be7ff")
const COLOR_COST := Color("#ffb4a8")
const COLOR_FIND := Color("#ff9ad5")
const COLOR_GOLDEN := Color("#ffe066")
const COLOR_FERT := Color("#8fe36b")

const COLOR_PART := Color("#f4c27a")

# Vibration on phones, in milliseconds: a light tick for a tap, firmer for a reward or a landing.
const BUZZ_TAP := 8
const COINS_NEEDED := {"plow": "NOT_ENOUGH_COINS_TO_PLOW", "plant": "NOT_ENOUGH_COINS_FOR_SEEDS",
	"fertilize": "NOT_ENOUGH_COINS_FOR_FERTILIZER"}  # what to say when a job can't be afforded
const SELL_CONFIRM_MS := 3000    # a second tap within this long confirms a sale or a clear
const BUZZ_HARVEST := 16
const BUZZ_PLACE := 24
const BUZZ_ERROR := 40

# Tap versus drag: a press only acts if the finger lifts without moving far.
# Anything further is a drag, which moves the camera (main.gd) instead of farming.
const DRAG_THRESHOLD := 14.0 # screen pixels

## Trees around the farm, in tile coordinates outside your land: [row, col, decoration id] (see scenery()).
static var _scenery: Array = []


var tool := "plow"       # "plow", "plant", "fertilize", "hand", "move", "store", "sell", "rotate" or "vehicle"
var selected_crop := ""  # crop id when tool == "plant", vehicle id when tool == "vehicle"
var last_crop := ""      # the last seed picked; the Seeder and Combine plant it

## While placing: {"item": id, "uid": -1 for a new purchase or the uid being moved,
## "row", "col"} for the footprint's back corner; row is -1 until the first touch.
var placing := {}



## The farm is drawn in layers, back to front: ground, shadows, the depth-sorted pieces, then the overlay.
## Floating texts and sparkles are added on top as they happen.
var ground: GroundLayer
var shadows: ShadowLayer
var pieces: ObjectLayer
var overlay: OverlayLayer
var world_fx: WorldFx    # bursts and pops on the farm
var life: FarmLife       # the animals' minds, read by the 2D and 3D worlds
## In 3D, finds what's drawn under a screen point (Farm3D.pick): the uid of the object, or -1. Taps go to
## what the player sees, even an animal that has wandered off its tile.
var picker := Callable()

var fx: FxLayer          # rewards flying to the top bar (set by main)



var _sell_pending := -1  # uid tapped once with the Sell tool; a second tap sells it
var _sell_pending_until := 0

var _vehicle_flash := {} # the area a vehicle just worked: {"row", "col", "w", "h", "until"}

var _press_pos := Vector2.ZERO
var _pressing := false
var _dragged := false

var _press_on_farm := false



func _ready() -> void:
	Game.player.action_done.connect(_on_action_done)
	Game.player.queue_changed.connect(queue_redraw)
	life = FarmLife.new()
	add_child(life)
	ground = GroundLayer.new()
	ground.grid = self
	ground.z_index = -3000
	add_child(ground)
	shadows = ShadowLayer.new()
	shadows.grid = self
	shadows.z_index = -2600
	add_child(shadows)
	pieces = ObjectLayer.new()
	pieces.grid = self
	add_child(pieces)
	overlay = OverlayLayer.new()
	overlay.grid = self
	overlay.objects = pieces
	overlay.z_index = 5
	add_child(overlay)
	world_fx = WorldFx.new()
	world_fx.grid = self
	world_fx.z_index = 4
	add_child(world_fx)
	Game.plot_changed.connect(pieces.on_plot)
	Game.objects_changed.connect(_on_objects_changed)
	Game.farm_expanded.connect(func(_n: int) -> void:
		ground.queue_redraw()
		pieces.queue_sync())
	placing_changed.connect(func(_t: String) -> void: _on_objects_changed())
	pieces.sync()
	Game.building_upgraded.connect(_on_building_upgraded)
	# Finds while farming (fuel, collectibles, Perfect Bunches) float up from their plot.
	Game.found.connect(
		func(i: int, text: String) -> void: _float(center_of(i) + Vector2(0, -90), text, COLOR_PART, 1.8)
	)




## A farm position on screen (for rewards that fly to the top bar).
func to_screen(at: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * at




## Coins and XP fly from a farm position up to their counters.
func _reward(at: Vector2, coins: int, xp: int) -> void:
	if fx == null:
		return
	var from := to_screen(at)
	if coins > 0:
		fx.coins(from, coins)
	if xp > 0:  # collecting animals and trees gives none (FarmVille), so nothing flies
		fx.xp(from, xp)




func _on_objects_changed() -> void:
	_refresh_homes()  # a home may have filled up, or gone
	pieces.queue_sync()
	shadows.queue_redraw()




## Everything redrawn from scratch, e.g. after new art was loaded.
func redraw_world() -> void:
	ground.queue_redraw()
	shadows.queue_redraw()
	pieces.redraw_all()




func set_tool(tool_name: String, crop_id: String) -> void:
	tool = tool_name
	selected_crop = crop_id
	if tool_name == "plant":
		last_crop = crop_id
	elif tool_name == "vehicle":
		var area := Game.vehicles.vehicle_area(crop_id)
		var job: String = Game.item_data(crop_id).get("job", "")
		var hint := tr("TAP_THE_FIELD_THE_WORKS_X") % [Game.item_data(crop_id)["name"], area.x, area.y]
		if job == "plant" or job == "all":
			hint += (
				tr("PLANTING") % Game.crops[last_crop]["name"].to_lower()
			) if last_crop != "" else tr("PICK_A_SEED_FIRST_TO_PLANT")
		info.emit(hint)




func get_bounds() -> Rect2:
	return Rect2(
		Vector2(-Game.farm_size * TILE_W / 2.0, -HEADROOM),
		Vector2(Game.farm_size * TILE_W, Game.farm_size * TILE_H + EDGE_DEPTH + HEADROOM))




# ---------------------------------------------------------------- geometry


## Screen position of a plot's top corner, in this node's local space.
func top_of(row: int, col: int) -> Vector2:
	return Vector2((col - row) * TILE_W / 2.0, (col + row) * TILE_H / 2.0)




## Same as top_of, for fractional rows and columns (used by things that drift, like fireflies).
func top_of_f(row: float, col: float) -> Vector2:
	return Vector2((col - row) * TILE_W / 2.0, (col + row) * TILE_H / 2.0)




func center_of(i: int) -> Vector2:
	return top_of(_row(i), _col(i)) + Vector2(0, TILE_H / 2.0)




func index_at(local_pos: Vector2) -> int:
	var dx := local_pos.x / (TILE_W / 2.0)
	var dy := local_pos.y / (TILE_H / 2.0)
	var col := int(floor((dy + dx) / 2.0))
	var row := int(floor((dy - dx) / 2.0))
	if not Game.in_farm(row, col):
		return -1
	return Game.index_of(row, col)




func _row(i: int) -> int:
	return int(float(i) / MAX)




func _col(i: int) -> int:
	return i % MAX




# ---------------------------------------------------------------- drawing


# ---------------------------------------------------------------- drawing (called by the layers)


## Ground layer: countryside, trees around the farm, the next expansion and your grass.
func draw_ground_on(ci: CanvasItem) -> void:
	var n := Game.farm_size
	PlaceholderArt.draw_meadow(ci, n, TILE_W, TILE_H, MEADOW_MARGIN)
	_draw_scenery(ci, n)
	_draw_next_expansion(ci)
	PlaceholderArt.draw_field(ci, n, TILE_W, TILE_H)
	PlaceholderArt.draw_farm_border(ci, n, TILE_W, TILE_H)




## Overlay: vehicle area, count signs, twinkles and hearts, and the ghost of what's being placed.
func draw_overlay_on(ci: CanvasItem, ready: Array) -> void:
	if not _vehicle_flash.is_empty() and Time.get_ticks_msec() < int(_vehicle_flash["until"]):
		PlaceholderArt.draw_footprint(ci, corners_of(int(_vehicle_flash["row"]), int(_vehicle_flash["col"]),
			int(_vehicle_flash["w"]), int(_vehicle_flash["h"])), true)
	# Plots waiting for the farmer.
	for i: int in Game.player.queued_plots():
		PlaceholderArt.draw_footprint(ci, corners_of(i / MAX, i % MAX, 1, 1), true)
	var lifted := int(placing.get("uid", -1))
	var t := Time.get_ticks_msec() / 1000.0
	# In 3D a building shows how full it is on itself; the numbers come up only while you're placing
	# something (deciding which home it goes in). So most frames only strays need a look at each object.
	var counts_shown := not pieces.three_d or not placing.is_empty()
	for o in Game.objects:
		if int(o["uid"]) == lifted or not (counts_shown or o.get("stray", false)):
			continue
		var fp := Game.footprint(o["id"])
		var g := corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
		if o.get("stray", false):
			var bob := sin(Time.get_ticks_msec() / 300.0) * 4.0
			PlaceholderArt.draw_stray_marker(ci, (g[0] + g[2]) / 2.0 + Vector2(0, -78 + bob))
		if Game.under_construction(o):
			continue
		var counts := Vector2i(-1, -1)
		if o["id"] == "barn" and not o.get("broken", false):
			counts = Vector2i(Game.storage.stored.size(), Game.storage.barn_capacity())
		elif Game.is_building(o):
			counts = Vector2i(Game.inside_total(o), Game.capacity(o))
		if counts.x >= 0 and counts_shown:
			PlaceholderArt.draw_count_sign(ci, g, counts.x, counts.y)
	# Twinkles: each on its own beat, so a ripe field shimmers instead of blinking.
	for p in ready:
		var piece := p as FarmPiece
		if piece.plot >= 0:
			var i := piece.plot
			var glow := 0.5 + 0.5 * sin(t * 2.6 + float(i % 7) * 0.9)
			var spot := top_of(_row(i), _col(i)) + Vector2(
				TILE_W * 0.12 * (1 if i % 2 == 0 else -1),
				TILE_H * 0.05 - PlaceholderArt.SLAB
			)
			PlaceholderArt.draw_twinkle(ci, spot, 9.0 + 5.0 * glow, glow)
		else:
			var o := Game.object_by_uid(piece.uid)
			if o.is_empty():
				continue
			if pieces.three_d and piece.is_animal():
				# The 3D animal has no bubble of its own: draw it over where the animal stands now.
				var rig := AnimalRig.of(Game.item_data(o["id"]))
				var tall := (rig.size("leg", 12.0) + rig.pair("body").y * 1.7) * Animal3D.PX * IsoProjection.HEIGHT_PX
				var mind := life.mind(piece.uid)
				var at := piece.base + (mind.offset if mind != null else Vector2.ZERO)
				AnimalArt.bubble(ci, at + Vector2(0, -tall - 26.0),
					AnimalArt.EGG if rig.family == "chicken" else rig.accent_color, t)
				continue
			var fp := Game.footprint(o["id"])
			var g := corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
			var glow := 0.5 + 0.5 * sin(t * 2.6 + float(piece.uid % 7))
			var high := -110.0 if Game.is_building(o) or Game.crafting.is_crafting(o) else -70.0
			PlaceholderArt.draw_twinkle(ci, (g[0] + g[2]) / 2.0 + Vector2(22, high), 11.0 + 6.0 * glow, glow)
	_draw_placing(ci)




## The land the next expansion would add, drawn as dim wild grass around the farm.
## Trees scattered along the back two sides of the farm (never in front, so nothing hides your land).
func _draw_scenery(ci: CanvasItem, n: int) -> void:
	for t in scenery():
		var r: float = t[0]
		var c: float = t[1]
		if r >= -1.0 and c >= -1.0:
			continue
		if r > n + 4 or c > n + 4:
			continue
		var id: String = t[2]
		var at := top_of_f(r + 0.5, c + 0.5) + Vector2(0, TILE_H / 2.0)
		if SpriteBank.has(id):
			SpriteBank.draw(ci, id, at)
		else:
			var g := PackedVector2Array(
				[top_of_f(r, c), top_of_f(r, c + 1), top_of_f(r + 1, c + 1), top_of_f(r + 1, c)]
			)
			PlaceholderArt.draw_object(ci, Game.item_data(id), g, false, 1, 0, 0)




## The trees scattered along the back two sides of the farm: the same every time (a fixed seed), sorted
## back to front. Shared by the 2D and 3D worlds.
static func scenery() -> Array:
	if _scenery.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 909
		var kinds := ["oak_tree", "pine_tree", "maple_tree", "oak_tree", "pine_tree", "willow_tree"]
		for k in 70:
			var along := rng.randf_range(-6.0, 34.0)
			var out := rng.randf_range(1.6, 9.0)
			_scenery.append(
				[-out, along, kinds[k % kinds.size()]] if k % 2 == 0 else [along, -out, kinds[k % kinds.size()]]
			)
		_scenery.sort_custom(func(a, b): return float(a[0]) + float(a[1]) < float(b[0]) + float(b[1]))
	return _scenery


func _draw_next_expansion(ci: CanvasItem) -> void:
	var step := Game.land.next_expansion()
	if step.is_empty():
		return
	var size := int(step["size"])
	var outer := corners_of(0, 0, size, size)
	PlaceholderArt.draw_wild_land(ci, outer)




## The four ground corners (top, right, bottom, left) of a footprint.
func corners_of(row: int, col: int, w: int, h: int) -> PackedVector2Array:
	return PackedVector2Array([top_of(row, col), top_of(row, col + w), top_of(row + h, col + w), top_of(row + h, col)])




## One object (FarmPiece): its sprite or code drawing. Marks and twinkles are on the overlay.
func draw_object_on(ci: CanvasItem, o: Dictionary, handle_flip := true) -> void:
	var it := Game.item_data(o["id"])
	var fp := Game.footprint(o["id"])
	var corners := corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
	if Game.under_construction(o):
		if Game.kind_of(o) == "vehicle":
			PlaceholderArt.draw_chassis(ci, corners, it)
		else:
			PlaceholderArt.draw_frame(ci, corners, it)
		return
	var is_ready_now := Game.is_ready(o) or (Game.crafting.is_crafting(o) and Game.crafting.crafts_done(o) > 0)
	var building := Game.is_building(o)
	var inside := Game.inside_total(o) if building else 0
	var cap := Game.capacity(o) if building else 0
	if o["id"] == "barn":
		inside = Game.storage.stored.size()
		cap = Game.storage.barn_capacity()
	if o["id"] == "mastery_sign" and Game.mastery.colour_of(str(o.get("crop", ""))) != "":
		it = it.duplicate()
		it["color"] = Game.mastery.colour_of(str(o["crop"]))
	var flipped: bool = o.get("flip", false) and handle_flip  # pieces flip themselves
	if flipped:
		# Mirror around the object's own centre line.
		var cx := (corners[1].x + corners[3].x) / 2.0
		ci.draw_set_transform(Vector2(2.0 * cx, 0), 0.0, Vector2(-1, 1))
	var art := "" if o.get("broken", false) else Game.art_for(o)
	if art != "":
		SpriteBank.draw(ci, art, (corners[0] + corners[2]) / 2.0)
	else:
		PlaceholderArt.draw_object(ci, it, corners, is_ready_now, int(o.get("level", 1)),
			inside, cap, o.get("broken", false))
	if flipped:
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)




func _draw_placing(ci: CanvasItem) -> void:
	if placing.is_empty() or int(placing["row"]) < 0:
		return
	var it := Game.item_data(placing["item"])
	var fp := Game.footprint(placing["item"])
	var row := int(placing["row"])
	var col := int(placing["col"])
	var corners := corners_of(row, col, fp.x, fp.y)
	# Every home that takes it lights up; the one under the finger glows brightest.
	var t := Time.get_ticks_msec() / 1000.0
	var hovered := int(placing.get("home", -1))
	var homes: Dictionary = placing.get("homes", {})
	for uid in homes:
		var b := Game.object_by_uid(int(uid))
		if b.is_empty():
			continue
		var bfp := Game.footprint(b["id"])
		PlaceholderArt.draw_home_highlight(ci, corners_of(int(b["row"]), int(b["col"]), bfp.x, bfp.y),
			homes[uid] == HousingSystem.Fit.FITS, int(uid) == hovered, t)
	if hovered == -1:
		var ok := Game.can_place(placing["item"], row, col, int(placing["uid"]))
		PlaceholderArt.draw_footprint(ci, corners, ok)
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
		cap = Game.building_def(it["id"]).capacity(1)
	if not pieces.three_d:  # in 3D, Objects3D shows a see-through model instead
		PlaceholderArt.draw_object(ci, it, corners, false, level, inside, cap)




## A plot's raised bed (FarmPiece): always drawn by the game, so every plot lines up into one tidy field.
func draw_bed_on(ci: CanvasItem, i: int) -> void:
	var top := top_of(_row(i), _col(i))
	var ph := Game.field.phase(i)
	if ph == GameState.Phase.GRASS:
		return
	PlaceholderArt.draw_soil(ci, top, TILE_W, TILE_H, ph != GameState.Phase.PLOWED)
	if Game.field.is_fertilized(i):
		PlaceholderArt.draw_fertilizer(ci, top + Vector2(0, -PlaceholderArt.SLAB), TILE_W, TILE_H)




## The plants on a plot (CropPlants): painted art if there is some, otherwise the code drawing.
func draw_plants_on(ci: CanvasItem, i: int) -> void:
	var ph := Game.field.phase(i)
	if ph == GameState.Phase.GRASS or ph == GameState.Phase.PLOWED:
		return
	var at := center_of(i) + Vector2(0, -PlaceholderArt.SLAB)
	var art := Game.crop_art_for(i)
	if art != "":
		SpriteBank.draw(ci, art, at)
		return
	var stage := "growing"
	if ph == GameState.Phase.RIPE:
		stage = "ripe"
	elif ph == GameState.Phase.WITHERED:
		stage = "withered"
	PlaceholderArt.draw_crop(ci, at, TILE_W, TILE_H, Game.crops[Game.field.crop_at(i)], stage, Game.field.growth(i))




## Called when a second finger lands: that's a pinch, so the first finger's tap is off.
func cancel_paint() -> void:
	_dragged = true




## True once the current press has moved far enough to count as a drag on the farm.
func is_dragging() -> bool:
	return _pressing and _dragged and _press_on_farm




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
			_pressing = true
			_dragged = false
			_press_pos = touch.position
			_press_on_farm = _on_farm_area(touch.position)
		else:
			# A tap: act on the plot under the finger. A drag already moved the camera.
			if _pressing and not _dragged and _press_on_farm:
				_apply_at(touch.position)
			_pressing = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _pressing and drag.index == 0 and drag.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragged = true




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
	var hint := tr("DRAG_TO_MOVE_THE_THEN_LET") if uid != -1 else tr("DRAG_TO_PLACE_THE_THEN_LET")
	_refresh_homes()
	placing_changed.emit(hint % Game.item_data(item_id)["name"])
	queue_redraw()




## Where the thing being placed comes from, as HousingSystem expects it.
func _placing_source() -> Dictionary:
	if int(placing.get("uid", -1)) != -1:
		return {"uid": int(placing["uid"])}
	if int(placing.get("stored", -1)) >= 0:
		return {"stored": int(placing["stored"])}
	return {"buy": true}


## The homes that take what's being placed, with how each fits: worked out when placing starts and when
## the farm changes, so drawing them every frame costs nothing.
func _refresh_homes() -> void:
	if placing.is_empty():
		return
	var fits := {}
	for pair in Game.homes.homes_for(placing["item"], _placing_source()):
		fits[int(pair[0]["uid"])] = pair[1]
	placing["homes"] = fits
	if not fits.has(int(placing.get("home", -1))):
		placing["home"] = -1


## Under the finger, a home that takes what's being placed? Remembers it and says what a drop would do.
func _hover_home(tile: Vector2i) -> void:
	var home := -1
	var homes: Dictionary = placing.get("homes", {})
	if tile.x >= 0 and tile.x < Game.farm_size and tile.y >= 0 and tile.y < Game.farm_size:
		var b := Game.object_at(Game.index_of(tile.x, tile.y))
		if not b.is_empty() and homes.has(int(b["uid"])):
			home = int(b["uid"])
	if home == int(placing.get("home", -1)):
		return
	placing["home"] = home
	var thing := str(Game.item_data(placing["item"])["name"])
	if home == -1:
		placing_changed.emit((tr("DRAG_TO_MOVE_THE_THEN_LET") if int(placing["uid"]) != -1
			else tr("DRAG_TO_PLACE_THE_THEN_LET")) % thing)
		return
	var b := Game.object_by_uid(home)
	var why: HousingSystem.Fit = homes[home]
	placing_changed.emit(tr("DROP_TO_MOVE_INTO") % [thing, Game.item_data(b["id"])["name"]]
		if why == HousingSystem.Fit.FITS else Game.homes.refusal(b, placing["item"], why))


## Placing something taken back out of the barn (free; it keeps its timers reset).
func start_placing_stored(index: int) -> void:
	var o: Dictionary = Game.storage.stored[index]
	placing = {"item": o["id"], "uid": -1, "stored": index, "row": -1, "col": -1}
	_refresh_homes()
	placing_changed.emit(tr("DRAG_TO_PLACE_THE_THEN_LET") % Game.item_data(o["id"])["name"])
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
	_hover_home(tile)
	queue_redraw()
	if not released:
		return
	if int(placing.get("home", -1)) != -1:
		# Dropped on a home: in it goes (or a message says why not, and it stays in hand).
		var home := Game.object_by_uid(int(placing["home"]))
		var source := _placing_source()
		if Game.homes.put_in_home(int(placing["home"]), placing["item"], source):
			_feel("place", BUZZ_PLACE)
			if source.has("buy"):
				var hfp := Game.footprint(home["id"])
				_float(corners_of(int(home["row"]), int(home["col"]), hfp.x, hfp.y)[2],
					"-%d" % int(Game.item_data(placing["item"])["cost"]), COLOR_COST)
			cancel_placing()
		return
	var row := int(placing["row"])
	var col := int(placing["col"])
	var uid := int(placing["uid"])
	if not Game.can_place(placing["item"], row, col, uid):
		_feel("error", BUZZ_ERROR)
		info.emit(tr("IT_DOESN_T_FIT_THERE_TRY"))
		return
	var from_storage := int(placing.get("stored", -1))
	var ok: bool
	if from_storage >= 0:
		ok = Game.storage.place_from_storage(from_storage, row, col)
	elif uid != -1:
		ok = Game.move_object(uid, row, col)
	else:
		ok = Game.buy_and_place(placing["item"], row, col)
	if ok:
		# Something new drops onto the 3D farm, and thuds when it lands (Farm3D); a move settles at once.
		if uid != -1 or not pieces.three_d:
			_feel("place", BUZZ_PLACE)
		if uid == -1 and from_storage < 0:
			_float(
				corners_of(row, col, fp.x, fp.y)[2],
				"-%d" % int(Game.item_data(placing["item"])["cost"]),
				COLOR_COST
			)
		cancel_placing()




func _apply_at(screen_pos: Vector2) -> void:
	# Ignore touches on the top bar, the toolbar, or while a menu covers the farm.
	if not _on_farm_area(screen_pos):
		return
	if picker.is_valid() and tool != "vehicle":
		var uid: int = picker.call(screen_pos)
		var picked := Game.object_by_uid(uid)
		if not picked.is_empty():
			_act_on_object(picked, true)
			return
	var world := get_canvas_transform().affine_inverse() * screen_pos
	var i := index_at(to_local(world))
	if i < 0:
		return
	if tool == "vehicle" and Game.object_at(i).is_empty():
		_drive(i)
		return
	_act(i, true)




## Something on the farm reacts to a tap: it bounces, and an animal looks round at you.
func _poke(uid: int) -> void:
	pieces.bounce(uid)
	object_poked.emit(uid)
	var obj := Game.object_by_uid(uid)
	var kind := Game.kind_of(obj) if not obj.is_empty() else ""
	if kind == "animal":
		Sound.voice(AnimalRig.of(Game.item_data(obj["id"])).family)
	_feel("", BUZZ_TAP)




## A sound and a short vibration for something the player did (either may be left out).
func _feel(event: String, buzz_ms := 0) -> void:
	if event != "":
		Sound.play(event)
	if buzz_ms > 0:
		Sound.buzz(buzz_ms)




## A harvested plot's plants pop off: in 3D the 3D world shows it, in 2D the 2D effects layer.
func _pop_plants(i: int, crop_id: String, art: String) -> void:
	if pieces.three_d:
		plants_popped.emit(i, crop_id)
	else:
		world_fx.pop_plants(i, crop_id, art)


## Sends the chosen vehicle over the area around the tapped plot.
func _drive(i: int) -> void:
	var id := selected_crop
	var area := Game.vehicles.vehicle_area(id)
	var row := int(i / float(MAX)) - int((area.y - 1) / 2.0)
	var col := i % MAX - int((area.x - 1) / 2.0)
	var job: String = Game.item_data(id).get("job", "")
	var crop := last_crop if (job == "plant" or job == "all") else ""
	_vehicle_flash = {"row": row, "col": col, "w": area.x, "h": area.y, "until": Time.get_ticks_msec() + 500}
	queue_redraw()
	_queue({"kind": "vehicle", "item": id, "row": row, "col": col, "crop": crop})


## Queues a job for the farmer (they walk there and do it: PlayerSystem); tapping something already queued
## takes it back out.
func _queue(job: Dictionary) -> void:
	if Game.player.cancel(job):
		_feel("tap", BUZZ_TAP)
		return
	match Game.player.enqueue(job):
		PlayerSystem.Refused.NONE:
			_feel("tap", BUZZ_TAP)
		PlayerSystem.Refused.COINS:
			_feel("error", BUZZ_ERROR)
			info.emit(tr(COINS_NEEDED.get(job["kind"], "NOT_ENOUGH_COINS_TO_PLOW")).replace("%s",
				str(Game.crops.get(str(job.get("crop", "")), {}).get("name", ""))))
		PlayerSystem.Refused.SUPPLY:
			_feel("error", BUZZ_ERROR)
			object_tapped.emit(int(job["uid"]))
		PlayerSystem.Refused.FULL:
			_feel("error", BUZZ_ERROR)
			info.emit(tr("THE_FARMER_HAS_ENOUGH_TO_DO"))
		_:
			_feel("error", BUZZ_ERROR)


## The farmer got to a job and did it (or found nothing left to do: an empty result).
func _on_action_done(job: Dictionary, result: Dictionary) -> void:
	if result.is_empty():
		if job["kind"] != "vehicle":
			_feel("error", BUZZ_ERROR)
		return
	var i := int(job.get("plot", -1))
	match str(job["kind"]):
		"harvest":
			_show_harvest(i, job, result)
		"plow":
			_feel("plow", BUZZ_TAP)
			world_fx.burst("dirt", center_of(i))
			_float(center_of(i), "-%d" % GameState.PLOW_COST, COLOR_COST)
		"plant":
			_feel("plant", BUZZ_TAP)
			world_fx.burst("dirt", center_of(i) + Vector2(0, -PlaceholderArt.SLAB))
			_float(center_of(i), "-%d" % int(Game.crops[job["crop"]]["seed_cost"]), COLOR_COST)
		"fertilize":
			_feel("fertilize", BUZZ_TAP)
			_float(center_of(i), "-%d" % GameState.FERTILIZER_COST, COLOR_COST)
			_sparkle(center_of(i), COLOR_FERT)
		"collect":
			_show_collect(int(job["uid"]), result)
		"nurture":
			_show_nurture(job, result)
		"vehicle":
			_show_vehicle(job, result)


func _show_vehicle(job: Dictionary, r: Dictionary) -> void:
	var id := str(job["item"])
	var row := int(job["row"])
	var col := int(job["col"])
	var area := Game.vehicles.vehicle_area(id)
	var at := center_of(
		Game.index_of(clampi(row + int(area.y / 2.0), 0, MAX - 1), clampi(col + int(area.x / 2.0), 0, MAX - 1))
	)
	if int(r["plots"]) == 0:
		info.emit(tr("NOTHING_FOR_THE_TO_DO_THERE") % Game.item_data(id)["name"])
		return
	var coins_moved := int(r["coins"])
	if coins_moved != 0:
		_float(at, ("+%d" if coins_moved > 0 else "%d") % coins_moved, COLOR_COINS if coins_moved > 0 else COLOR_COST)
	if int(r["xp"]) > 0:
		_float(at + Vector2(0, -30), tr("XP") % int(r["xp"]), COLOR_XP)
	_float(at + Vector2(0, -60), tr("PLOTS_FUEL") % [int(r["plots"]), int(r["fuel"])], COLOR_PART, 1.4)
	var lift := -96
	for d in r["drops"]:
		_float(at + Vector2(0, lift), d, COLOR_GOLDEN, 1.6)
		lift -= 32




## A young one was given its supply: how far along it is, or what it grew into.
func _show_nurture(job: Dictionary, result: Dictionary) -> void:
	var grown := str(result["grown"])
	var o := Game.object_by_uid(int(job["uid"]))
	if result.get("regrown", false):
		if not o.is_empty():
			var at0 := center_of(Game.index_of(int(o["row"]), int(o["col"])))
			_feel("fertilize", BUZZ_TAP)
			_float(at0 + Vector2(0, -40), tr("REGROWN"), COLOR_FERT)
			_sparkle(at0, COLOR_FERT)
		return
	if grown == "":
		if o.is_empty():
			return
		var at := center_of(Game.index_of(int(o["row"]), int(o["col"])))
		_feel("fertilize", BUZZ_TAP)
		_float(at + Vector2(0, -40), "%d/%d" % [int(result["fed"]), int(result["needs"])], COLOR_FERT)
		return
	for g in Game.objects:
		if g["id"] == grown and int(g["uid"]) == Game.next_uid - 1:
			var at := center_of(Game.index_of(int(g["row"]), int(g["col"])))
			_feel("collect", BUZZ_HARVEST)
			_float(at + Vector2(0, -60), Game.item_data(grown)["name"] + "!", COLOR_GOLDEN, 1.8)
			_sparkle(at, COLOR_GOLDEN)
			_poke(int(g["uid"]))


func _show_harvest(i: int, job: Dictionary, result: Dictionary) -> void:
	var at := center_of(i)
	_feel("harvest", BUZZ_HARVEST)
	_pop_plants(i, job["crop"], job["art"])
	world_fx.burst("leaves", at + Vector2(0, -PlaceholderArt.SLAB))
	_reward(at, int(result["coins"]), int(result["xp"]))
	_float(at, "+%d" % result["coins"], COLOR_COINS)
	_float(at + Vector2(0, -30), tr("XP") % result["xp"], COLOR_XP)
	if result.get("part", "") != "":
		_float(at + Vector2(0, -128), "+1 " + GameState.part_names[result["part"]], COLOR_PART, 1.6)
	if result.get("bushel", "") != "":
		var nb := int(result.get("bushels", 1))
		_float(
			at + Vector2(0, -160),
			(tr("ONE_BUSHEL") if nb == 1 else tr("N_BUSHELS")) % [nb, Game.crops[result["bushel"]]["name"]],
			COLOR_PART,
			1.6
		)
	if result.get("bee", "") != "":
		_float(at + Vector2(0, -96), result["bee"], COLOR_GOLDEN, 1.6)
	if int(result.get("pollinated", 0)) > 0:
		_float(at + Vector2(0, -160), tr("POLLINATED_SEEDS") % int(result["pollinated"]), COLOR_FIND, 1.8)
		_sparkle(at, COLOR_FIND)
	if result["drop"] != "":
		var c := COLOR_GOLDEN if result["drop"] == "golden" else COLOR_FIND
		_float(at + Vector2(0, -64), result["drop_text"], c, 1.6)
		_sparkle(at, c)


func _show_collect(uid: int, result: Dictionary) -> void:
	var obj := Game.object_by_uid(uid)
	if obj.is_empty():
		return
	var fp := Game.footprint(obj["id"])
	var at := (
		corners_of(
			int(obj["row"]),
			int(obj["col"]),
			fp.x,
			fp.y
		)[0] + corners_of(int(obj["row"]), int(obj["col"]), fp.x, fp.y)[2]
	) / 2.0
	_poke(uid)
	collected.emit(uid)
	_feel("collect", BUZZ_HARVEST)
	world_fx.burst("sparkle", at + Vector2(0, -40))
	_reward(at + Vector2(0, -30), int(result["coins"]), int(result["xp"]))
	_float(at + Vector2(0, -20), "+%d" % result["coins"], COLOR_COINS)
	if int(result["xp"]) > 0:
		_float(at + Vector2(0, -50), tr("XP") % result["xp"], COLOR_XP)
	if result.get("part", "") != "":
		_float(at + Vector2(0, -118), "+1 " + GameState.part_names[result["part"]], COLOR_PART, 1.6)
	var lift := -150
	for extra in result.get("extras", []):
		_float(at + Vector2(0, lift), extra, COLOR_GOLDEN, 1.8)
		lift -= 32
	if not result.get("extras", []).is_empty():
		_sparkle(at, COLOR_GOLDEN)
	if result["drop"] != "":
		var c := COLOR_GOLDEN if result["drop"] == "golden" else COLOR_FIND
		_float(at + Vector2(0, -84), result["drop_text"], c, 1.6)
		_sparkle(at, c)


## first_touch is always true now that each tap acts on one plot; it stays so
## multi-plot tools (vehicles, later) can reuse _act without info popups.
func _act(i: int, first_touch: bool) -> void:
	var obj := Game.object_at(i)
	if not obj.is_empty():
		_act_on_object(obj, first_touch)
		return
	var ph := Game.field.phase(i)

	# The sell tool deletes plots (FarmVille's delete): even a ripe crop, after asking.
	if tool == "sell":
		if first_touch:
			_try_clear(i)
		return
	# A ripe crop is harvested by any tool: tapping ripe crops should always just work.
	if ph == GameState.Phase.RIPE:
		_queue({"kind": "harvest", "plot": i})
		return

	match tool:
		"plow":
			if ph == GameState.Phase.GRASS or ph == GameState.Phase.WITHERED:
				_queue({"kind": "plow", "plot": i})
			elif first_touch:
				_explain(i, ph)
		"plant":
			if ph == GameState.Phase.PLOWED and selected_crop != "":
				_queue({"kind": "plant", "plot": i, "crop": selected_crop})
			elif first_touch:
				_explain(i, ph)
		"fertilize":
			if ph == GameState.Phase.GROWING and not Game.field.is_fertilized(i):
				_queue({"kind": "fertilize", "plot": i})
			elif first_touch:
				if Game.field.is_fertilized(i):
					info.emit(tr("ALREADY_FERTILIZED_THIS_HARVEST_PAYS_MORE"))
				else:
					info.emit(tr("FERTILIZE_GROWING_CROPS_FOR_MORE_COINS"))
		"hand":
			if first_touch:
				_explain(i, ph)




func _act_on_object(obj: Dictionary, first_touch: bool) -> void:
	var uid := int(obj["uid"])
	var kind := Game.kind_of(obj)
	if tool == "sell" and first_touch:
		_try_sell(obj)
		return
	if tool == "rotate" and first_touch:
		Game.rotate_object(uid)
		return
	if tool == "store" and first_touch:
		if Game.storage.store_object(uid):
			var fps := Game.footprint(obj["id"])
			_float(corners_of(int(obj["row"]), int(obj["col"]), fps.x, fps.y)[2], tr("STORED"), COLOR_XP)
		return
	if kind == "barn" and tool != "move":
		if first_touch:
			_poke(uid)
			object_tapped.emit(uid)
		return
	if kind == "vehicle" and tool != "move":
		if first_touch:
			_poke(uid)
			if Game.under_construction(obj):
				object_tapped.emit(uid)
			else:
				info.emit(tr("PICK_THE_IN_THE_TOOLBAR_THEN") % Game.item_data(obj["id"])["name"])
		return
	if kind == "decor" and tool != "move":
		if first_touch:
			_poke(uid)
			info.emit(tr("YOUR") % Game.item_data(obj["id"])["name"].to_lower())
		return
	if obj.get("stray", false) and tool != "move":
		if first_touch:
			_poke(uid)
		if first_touch and Game.strays.adopt_stray(uid):
			var fp0 := Game.footprint(obj["id"])
			var c0 := corners_of(int(obj["row"]), int(obj["col"]), fp0.x, fp0.y)
			var at0 := (c0[0] + c0[2]) / 2.0
			_float(at0 + Vector2(0, -40), tr("ADOPTED_XP") % StraySystem.STRAY_ADOPT_XP, COLOR_FIND, 1.4)
			_sparkle(at0, COLOR_FIND)
		return
	if tool == "move":
		if first_touch:
			start_placing(obj["id"], uid)
		return
	var supply := Game.nurture.supply_for(obj)
	if supply != "":
		# A young one, or a withered bloom: given its supply by the farmer; with none to give, its card
		# shows what it needs and sells more.
		if first_touch:
			_poke(uid)
			if Game.player.is_queued({"kind": "nurture", "uid": uid}) or Game.nurture.free_supply(supply) > 0:
				_queue({"kind": "nurture", "uid": uid})
			else:
				object_tapped.emit(uid)
		return
	if Game.is_ready(obj):
		_queue({"kind": "collect", "uid": uid})
		return
	if not first_touch:
		return
	_poke(uid)
	if Game.is_building(obj) or Game.crafting.is_crafting(obj) or Game.kind_of(obj) == "bloom":
		object_tapped.emit(uid)
		return
	var it := Game.item_data(obj["id"])
	var what: String = it.get("product", tr("FRUIT"))
	info.emit(tr("READY_IN") % [it["name"], what, format_duration(Game.seconds_until_ready(obj))])




## Sell needs two taps on the same thing, so a stray tap can't sell a building.
func _try_sell(obj: Dictionary) -> void:
	var uid := int(obj["uid"])
	if not Game.can_sell(obj):
		info.emit(tr("THAT_CAN_T_BE_SOLD"))
		return
	var now_ms := Time.get_ticks_msec()
	if _sell_pending == uid and now_ms < _sell_pending_until:
		_sell_pending = -1
		var fp := Game.footprint(obj["id"])
		var at := corners_of(int(obj["row"]), int(obj["col"]), fp.x, fp.y)[2]
		var value := Game.sell_value(obj)
		if Game.sell_object(uid):
			_feel("coin", BUZZ_TAP)
			_float(at, "+%d" % value, COLOR_COINS)
		return
	_sell_pending = uid
	_sell_pending_until = now_ms + SELL_CONFIRM_MS
	var extra := tr("WHAT_S_INSIDE_MOVES_OUT") if Game.inside_total(obj) > 0 else ""
	info.emit(
		tr("TAP_AGAIN_TO_SELL_THE_FOR") % [Game.item_data(obj["id"])["name"], Game.sell_value(obj), extra]
	)




## Clears a plot back to grass: at once if it's bare soil, after a second tap if a crop would be lost.
func _try_clear(i: int) -> void:
	if not Game.field.can_clear_plot(i):
		info.emit(tr("NOTHING_TO_CLEAR_HERE"))
		return
	var crop_id := Game.field.crop_at(i)
	var now_ms := Time.get_ticks_msec()
	var key := -2 - i  # plots take negative keys, so they never match an object's uid
	if crop_id != "" and not (_sell_pending == key and now_ms < _sell_pending_until):
		_sell_pending = key
		_sell_pending_until = now_ms + SELL_CONFIRM_MS
		info.emit(tr("TAP_AGAIN_TO_CLEAR_THIS_PLOT") % Game.crops[crop_id]["name"])
		return
	_sell_pending = -1
	if Game.field.clear_plot(i):
		_feel("plow", BUZZ_TAP)
		world_fx.burst("dirt", center_of(i))


func _explain(i: int, ph: GameState.Phase) -> void:
	match ph:
		GameState.Phase.GRASS:
			info.emit(tr("PLOW_THIS_PLOT_FIRST"))
		GameState.Phase.PLOWED:
			info.emit(tr("PICK_A_SEED_TO_PLANT_HERE"))
		GameState.Phase.GROWING:
			var crop: Dictionary = Game.crops[Game.field.crop_at(i)]
			info.emit(tr("READY_IN_2") % [crop["name"], format_duration(Game.field.seconds_until_ripe(i))])
		GameState.Phase.WITHERED:
			info.emit(tr("THESE_CROPS_WITHERED_PLOW_TO_CLEAR"))




static func format_duration(seconds: int) -> String:
	if seconds < 60:
		return TranslationServer.translate("LESS_THAN_A_MINUTE")
	var d := int(seconds / 86400.0)
	var h := int((seconds % 86400) / 3600.0)
	var m := int((seconds % 3600) / 60.0)
	if d > 0:
		return "%dd %dh" % [d, h]
	if h > 0:
		return "%dh %dm" % [h, m]
	return "%dm" % m




## Celebrates an upgrade on the building itself: a big sparkle burst and a level popup.
func _on_building_upgraded(uid: int, level: int) -> void:
	var o := Game.object_by_uid(uid)
	if o.is_empty():
		return
	var fp := Game.footprint(o["id"])
	var g := corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
	var at := (g[0] + g[2]) / 2.0 + Vector2(0, -60)
	_float(at, (tr("BUILT") if level == 1 else "%s!" % Game.size_name(o)), COLOR_GOLDEN, 2.0)
	_float(at + Vector2(0, 34), tr("HOLDS") % Game.capacity(o), COLOR_XP, 2.0)
	for k in 3:
		_sparkle(at + Vector2(-50 + 50 * k, 20), COLOR_GOLDEN)




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
