class_name FarmGrid
extends Node2D
## Draws the isometric farm and turns taps and drags into farm actions.
## Rules live in the Game autoload; this script only decides what a tap means.

signal info(text: String)   ## a word about what was just tapped: shown in a bubble where the finger was
signal object_tapped(uid: int)        # a building was tapped while not ready
signal panel_requested(panel: String)   # a thing that opens a panel was tapped (the mailbox: "inbox")
## Something tapped tells about itself in a small bubble above it (FarmVille's way, not a panel): `at` is where
## (this grid's space), `uid` the thing tapped (-1 for a plot), so its bubble can offer its panel.
signal tapped_info(at: Vector2, title: String, line: String, uid: int)
signal tapped_rust(at: Vector2, id: String)   # a rusty vehicle's sign was tapped (`at` in the grid's space)

signal placing_changed(text: String)  # "" when placement ends
signal tool_changed(tool: String)     # the tool in hand changed here, not from the tool panel (a vehicle tapped)
signal object_poked(uid: int)         # something on the farm was tapped: it reacts (bounce, an animal looks round)
signal plants_popped(index: int, crop_id: String)  # a plot was harvested: its plants pop off
signal collected(uid: int)                         # a building or animal was collected from


const ITEM_SPOT := "item:"   # not-ui (spots_of: the things of one id)
const MAX := GameState.MAX_SIZE # plots are indexed on the full-size grid
const TILE_W := 128.0
const TILE_H := 64.0
const EDGE_DEPTH := 28.0
const HEADROOM := 230.0 # room above the back corner for tall things (the farmhouse sits there)
const MEADOW_MARGIN := 40  # tiles of countryside drawn around the farm


# Vibration on phones, in milliseconds: a light tick for a tap, firmer for a reward or a landing.
const COINS_NEEDED := {"plow": "NOT_ENOUGH_COINS_TO_PLOW", "plant": "NOT_ENOUGH_COINS_FOR_SEEDS",
	"fertilize": "NOT_ENOUGH_COINS_FOR_FERTILIZER"}  # what to say when a job can't be afforded
const SELL_CONFIRM_MS := 3000    # a second tap within this long confirms a sale or a clear

# Tap versus drag: a press only acts if the finger lifts without moving far.
# Anything further is a drag, which moves the camera (main.gd) instead of farming.
const DRAG_THRESHOLD := 14.0 # screen pixels
const FIND_STACK_MSEC := 500   # finds said at one place within this long of each other rise one above the other
const FIND_BEAT := 0.28        # seconds between them (each chimes on its own beat)
const FIND_RISE := 40.0        # pixels between them
const RAIN_BLUE := Color("#8fd0ff")   # the words of a rain-watered harvest
const COUNT_TAG := "x%d"     # not-ui: a count (a swipe's plots, a streak), the same in every language
const SWIPE_STEP_MIN := 4.0  # screen pixels: the finest step a swipe's path is walked in
## Tools a one-finger drag farms with, plot after plot (swipe to farm); with any other tool a drag moves the view.
const BUBBLE_LIFT := 46.0          # a tapped thing's bubble floats this far (px) above its footprint's middle..
const BUBBLE_LIFT_PER_TILE := 34.0 # ..and this much more per tile of its size (a barn is taller than a hen)
const HOLD_TO_LIFT := 0.45   # seconds a finger rests on something before it is picked up (by the clock, so a
							# slow frame can never turn a quick tap into a hold)

## Trees around the farm, in tile coordinates outside your land: [row, col, decoration id] (see scenery()).
static var _scenery: Array = []


var tool := "hand"   # plow, plant, fertilize, hand, harvest, move, store, sell, rotate or vehicle
var selected_crop := ""  # crop id when tool == "plant", vehicle id when tool == "vehicle"
var last_crop := ""      # the last seed picked; the Seeder and Combine plant it

## Putting things on the farm (see Placement).
var placement: Placement
var placing: Dictionary:     # what is in hand while placing (see Placement.state)
	get:
		return placement.state
	set(value):
		placement.state = value



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
var rust_picker := Callable()   # the rusty vehicle whose sign is under a screen point ("" if none)
var fireworks := Callable()     # fireworks over a building that has just grown, by its uid (the 3D world's)
## uid -> the outline of that building on screen (grid space), set by the 3D world; unset in the 2D fallback.
var outliner := Callable()
var hatcher := Callable()        # (young uid, grown uid, then): the 3D world shakes a mystery open, then calls `then`
var ready_things := Callable()   # () -> int: how many things wear a ready sign now (the 3D world's; else counted)

var fx: FxLayer          # rewards flying to the top bar (set by main)



var last_tap_at := Vector2.ZERO   # where the finger last came down (this grid's space): where `info` is shown
var last_tap_msec := -100000      # and when
var _sell_pending := -1  # uid tapped once with the Sell tool; a second tap sells it
var _sell_pending_until := 0

var _vehicle_flash := {} # the area a vehicle just worked: {"row", "col", "w", "h", "until"}

var _press_pos := Vector2.ZERO
var _press_msec := 0         # when the finger went down
var _hold_spent := false     # this press has already tried to lift something
var _pressing := false
var _swiping := false        # this press farms every plot the finger crosses (a swipe tool, Balance `input.*`)
var _swiped := {}            # plots this swipe has already worked (index -> true)
var _swipe_at := Vector2.ZERO   # where the swipe's finger was last seen (the path since is walked, no plot skipped)
var _find_at := Vector2.INF  # where the last find was said, when, and how many were said there together
var _find_msec := 0
var _find_stack := 0
var _ripe := -1              # how many plots are ripe, kept: counted again only when it can have changed..
var _ripe_until := 0         # ..a plot changed (-1 above), or the clock reached this (a crop ripens or withers)
var _ready_seen := {}        # ready things the Next ready button has already shown this round (spot key -> true)
var _swipe_count := 0        # plots this swipe has given the farmer (each plays a note higher; shown as "x7")
var _combo: Label            # that count, over the plot last added (made when first needed, then kept)
var _combo_tween: Tween
var _streak_kind := ""       # the kind of job the farmer last finished, how many of it in a row, and when
var _streak := 0
var _streak_msec := 0
var _swipe_spent := false    # a swipe stopped working plots: something was refused, and said once
var _touch_tile := -1        # the plot under a finger that has just landed, lit at once (-1 none)
var _dragged := false

var _press_on_farm := false



func _ready() -> void:
	placement = Placement.new(self)
	Game.player.action_done.connect(_on_action_done)
	Game.vehicles.run_finished.connect(_show_vehicle)
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
	Game.plot_changed.connect(func(_i: int) -> void: _ripe = -1)   # (the kept ripe count is made again when asked)
	Game.objects_changed.connect(_on_objects_changed)
	Game.object_changed.connect(_on_object_changed)
	Game.farm_expanded.connect(func(_n: int) -> void:
		ground.queue_redraw()
		pieces.queue_sync())
	placing_changed.connect(func(_t: String) -> void: _on_objects_changed())
	pieces.sync()
	Game.building_upgraded.connect(_on_building_upgraded)
	Game.vip_level_reached.connect(_on_vip_level_reached)
	# Finds while farming (fuel, collectibles, Perfect Bunches) float up from their plot.
	# Every find, wherever it was made, is said the same way in its rarity's colours (show_find).
	Game.found.connect(func(i: int, text: String, rarity: String) -> void: show_find(center_of(i), text, rarity))
	Game.found_on.connect(func(uid: int, text: String, rarity: String) -> void:
		var o := Game.object_by_uid(uid)
		if not o.is_empty() and o.has("row"):
			var fp := Game.footprint(o["id"])
			var box := corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
			show_find((box[0] + box[2]) / 2.0, text, rarity))




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
	var pt := PerfReadout.start()
	_on_objects_changed_timed()
	PerfReadout.stop("grid_objects", pt)


func _on_objects_changed_timed() -> void:
	placement.refresh_homes()  # a home may have filled up, or gone
	pieces.queue_sync()
	shadows.queue_redraw()


## One thing changed where it stands: its piece only (and a home being offered may have filled up).
func _on_object_changed(uid: int) -> void:
	placement.refresh_homes()
	pieces.refresh_one(uid)




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
		Game.message.emit(hint)   # (from choosing a vehicle, not a tap on the farm: said at the top)




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
	return GameState.row_of(i)




func _col(i: int) -> int:
	return GameState.col_of(i)




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
	# Plots waiting for the farmer, and the one a finger has just landed on.
	for i: int in Game.player.queued_plots():
		PlaceholderArt.draw_footprint(ci, corners_of(_row(i), _col(i), 1, 1), true)
	if touched_plot() >= 0:
		PlaceholderArt.draw_footprint(ci, corners_of(_row(_touch_tile), _col(_touch_tile), 1, 1), true)
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
		if Game.storage.is_barn(o) and not o.get("broken", false):
			counts = Vector2i(mini(Game.storage.stored.size(), Game.storage.barn_capacity()), Game.storage.barn_capacity())
		elif Game.is_home(o):
			counts = Vector2i(Game.inside_total(o), Game.capacity(o))
		if counts.x >= 0 and counts_shown:
			PlaceholderArt.draw_count_sign(ci, g, counts.x, counts.y)
	# FarmVille's one ready sign: a soft pink triangle bobbing over each thing with something to collect (the
	# same for buildings, trees and animals; crops show it by how they look). In 3D it is ReadyMarks'; here it is
	# only for the 2D world.
	if not pieces.three_d:
		for p in ready:
			var piece := p as FarmPiece
			if piece.plot >= 0 or piece.is_animal():
				continue   # (crops show it by how they look; an animal's sign is drawn with it, as it walks)
			var o := Game.object_by_uid(piece.uid)
			if o.is_empty():
				continue
			var fp := Game.footprint(o["id"])
			var g := corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
			var high := -110.0 if Game.is_home(o) or Game.crafting.is_crafting(o) else -70.0
			PlaceholderArt.draw_ready_marker(ci, (g[0] + g[2]) / 2.0 + Vector2(0, high), t + float(piece.uid % 7))
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
	var is_ready_now := Game.has_ready(o)
	var building := Game.is_home(o)
	var inside := Game.inside_total(o) if building else 0
	var cap := Game.capacity(o) if building else 0
	if Game.storage.is_barn(o):
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
			inside, cap, o.get("broken", false), Game.links.mask(o))
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
		if homes[uid] != HousingSystem.Fit.FITS:
			continue  # a home that can't take it yet (unbuilt, broken, full) is not marked at all
		var b := Game.object_by_uid(int(uid))
		if b.is_empty():
			continue
		var hull: PackedVector2Array = outliner.call(int(uid)) if outliner.is_valid() else PackedVector2Array()
		if hull.size() >= 4:
			PlaceholderArt.draw_home_outline(ci, hull, int(uid) == hovered, t)
		else:
			var bfp := Game.footprint(b["id"])
			PlaceholderArt.draw_home_highlight(ci, corners_of(int(b["row"]), int(b["col"]), bfp.x, bfp.y), true,
				int(uid) == hovered, t)
	if hovered == -1 and int(placing.get("refused", -1)) == -1:
		var ok := Game.can_place(placing["item"], row, col, int(placing["uid"]))
		PlaceholderArt.draw_footprint(ci, corners, ok)
		if ok:
			_draw_layout_bonus(ci, corners, row, col, t)
	var level := 1
	var inside := 0
	var cap := 0
	if int(placing["uid"]) != -1:
		var o := Game.object_by_uid(int(placing["uid"]))
		level = int(o.get("level", 1))
		if Game.is_home(o):
			inside = Game.inside_total(o)
			cap = Game.capacity(o)
	elif it.get("kind", "") == "building":
		cap = Game.building_def(it["id"]).capacity(1)
	if not pieces.three_d:  # in 3D, Objects3D shows a see-through model instead
		PlaceholderArt.draw_object(ci, it, corners, false, level, inside, cap)




## What dropping the piece here would earn from the layout (our own touch): the pieces it would touch glow
## and the ghost carries the bonus, so you can see the set before you build it.
func _draw_layout_bonus(ci: CanvasItem, corners: PackedVector2Array, row: int, col: int, t: float) -> void:
	var item: String = placing["item"]
	var lifted := int(placing["uid"])
	var touching := Game.adjacency.neighbours_at(item, row, col, lifted)
	if touching.is_empty():
		return
	for uid in touching:
		var n := Game.object_by_uid(uid)
		var nfp := Game.footprint(n["id"])
		PlaceholderArt.draw_home_highlight(ci, corners_of(int(n["row"]), int(n["col"]), nfp.x, nfp.y), true, false, t)
	var pct := roundi(Game.adjacency.bonus_for(item, Game.adjacency.count_at(item, row, col, lifted)) * 100.0)
	PlaceholderArt.draw_bonus_tag(ci, (corners[0] + corners[2]) / 2.0 + Vector2(0, -60), tr("SYNERGY_TAG") % pct)


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
	_swiping = false
	_touch_tile = -1




## True once the current press has moved far enough to count as a drag on the farm.
func is_dragging() -> bool:
	return _pressing and _dragged and _press_on_farm and not _swiping


## Whether the current press is farming plot after plot (the view stays put).
func is_swiping() -> bool:
	return _pressing and _swiping




# ---------------------------------------------------------------- input


func _unhandled_input(event: InputEvent) -> void:
	if not placing.is_empty():
		placement.input(event)
		return
	# Mouse is emulated as touch (project setting), so this one path covers both.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index != 0:
			return
		if touch.pressed:
			_pressing = true
			_dragged = false
			_press_msec = Time.get_ticks_msec()
			_hold_spent = false
			_press_pos = touch.position
			last_tap_at = to_local(get_canvas_transform().affine_inverse() * touch.position)
			last_tap_msec = Time.get_ticks_msec()
			_press_on_farm = on_farm_area(touch.position)
			# The plot under the finger lights the moment it lands, so a tap feels instant (a farming tool on an
			# open plot: a press on a building or tree picks that, so nothing under it lights).
			_touch_tile = swipe_start(touch.position, tool) if _press_on_farm else -1
			# Swipe to farm (our own touch, Balance `input.swipe_farm`): only from a plot the tool would work, so a
			# drag anywhere else still pans.
			_swiping = _touch_tile >= 0 and Balance.i("input.swipe_farm") == 1 and would_act(_touch_tile)
			_swiped.clear()
			_swipe_count = 0
			_swipe_spent = false
			_swipe_at = touch.position
		else:
			last_tap_msec = Time.get_ticks_msec()   # (a tap acts as the finger lifts: its words follow then)
			# A tap: act on the plot under the finger. A drag already moved the camera (or farmed as it went).
			if _pressing and not _dragged and _press_on_farm:
				_apply_at(touch.position)
			_pressing = false
			_swiping = false
			_touch_tile = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _pressing and drag.index == 0 and drag.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			if not _dragged and _swiping:
				_swipe_over(_press_pos)   # (the plot it started on counts too)
			_dragged = true
			_touch_tile = -1
		if _pressing and _swiping and _dragged and drag.index == 0:
			_swipe_along(_swipe_at, drag.position)
			_swipe_at = drag.position


## Swipe to farm (our own touch): every plot on the path from `from` to `to` on screen, walked in steps of
## under half a tile, so a fast flick between two touch events skips none.
func _swipe_along(from: Vector2, to: Vector2) -> void:
	var step := maxf(SWIPE_STEP_MIN, TILE_H * get_canvas_transform().get_scale().y * 0.4)
	var n := ceili(from.distance_to(to) / step)
	for k in range(1, n + 1):
		_swipe_over(from.lerp(to, k / float(n)))
	if n == 0:
		_swipe_over(to)


## Swipe to farm: the plot under `screen_pos` is worked with the tool in hand, once per swipe, quietly (no
## "can't plow that" for each plot crossed; things standing on the farm are passed over). Work already queued
## stays queued (a swipe only adds), and the first refusal (coins, a full queue) is said once and ends the work.
func _swipe_over(screen_pos: Vector2) -> void:
	if _swipe_spent:
		return
	var i := plot_under(screen_pos)
	if i < 0 or _swiped.has(i) or not Game.object_at(i).is_empty():
		return
	_swiped[i] = true
	_act(i, false)


## Where things of one `kind` are right now, as {key, at, uid}: "ripe" and "withered" plots, "ready" things (the ones
## that wear a ready sign), "hungry" ones and a "stray". `at` is its middle on the ground (this node's
## coordinates), `uid` -1 for a plot. For the Next ready button and the away card's rows.
func spots_of(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if kind == "ripe" or kind == "withered":
		var phase := GameState.Phase.RIPE if kind == "ripe" else GameState.Phase.WITHERED
		var n := Game.farm_size
		for r in n:
			for c in n:
				var i := Game.index_of(r, c)
				if not Game.is_occupied(i) and Game.field.phase(i) == phase:
					out.append({"key": "p%d" % i, "at": center_of(i), "uid": -1})   # not-ui
		return out
	for o in Game.objects:
		var is_it := false
		match kind:
			"ready":
				is_it = not GameState.NEVER_READY.has(Game.kind_of(o)) and Game.has_ready(o)
			"hungry":
				is_it = Game.feeds.enabled() and Game.feeds.is_hungry(o)
			"stray":
				is_it = o.get("stray", false)
			_:   # ("item:<id>": the things of one id, and the homes they live in: search's Show on farm)
				var id := kind.trim_prefix(ITEM_SPOT)
				is_it = kind.begins_with(ITEM_SPOT) and (str(o["id"]) == id
					or (o.get("inside", {}) as Dictionary).has(id))
		if is_it:
			var fp := Game.footprint(o["id"])
			var box := corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
			out.append({"key": "o%d" % int(o["uid"]), "at": (box[0] + box[2]) / 2.0, "uid": int(o["uid"])})   # not-ui
	return out


## Everything with something to take right now: each ripe plot and each ready thing.
func ready_spots() -> Array[Dictionary]:
	var out := spots_of("ripe")
	out.append_array(spots_of("ready"))
	return out


## The one of `spots` nearest `from` (this node's coordinates), or {} when there are none.
static func nearest_spot(spots: Array[Dictionary], from: Vector2) -> Dictionary:
	var best := {}
	for s: Dictionary in spots:
		if best.is_empty() or from.distance_squared_to(s["at"]) < from.distance_squared_to(best["at"]):
			best = s
	return best


## Points a spot out when the view goes to it: a thing hops, a plot sparkles.
func point_out(spot: Dictionary) -> void:
	if int(spot["uid"]) >= 0:
		_poke(int(spot["uid"]))
	else:
		_sparkle(spot["at"], "golden")
		Feedback.moment("touch")


## How many things are ready (`ready_spots`, without listing them: this is asked every couple of seconds, and on a
## big farm asking every tile and every thing each time was 2.5 ms). The ripe plots are a kept count, made again
## only when a plot changed or a crop was due to ripen or wither; the ready things are the ready signs the 3D
## world is already showing (`ready_things`), counted the long way only where nothing says.
func ready_count() -> int:
	if _ripe < 0 or Game.now() >= _ripe_until:
		var census := Game.field.ripe_census()
		_ripe = int(census["count"])
		_ripe_until = int(census["next"])
	if ready_things.is_valid():
		return _ripe + int(ready_things.call())
	return _ripe + spots_of("ready").size()


## The ready thing the Next ready button goes to from `from` (the middle of the view, this node's coordinates):
## the nearest one it has not shown yet this round; when every one has been shown the round starts again. It is
## pointed out (a ready thing hops, a ripe plot sparkles). {} when nothing is ready.
func next_ready(from: Vector2) -> Dictionary:
	var spots := ready_spots()
	if spots.is_empty():
		_ready_seen.clear()
		return {}
	var fresh: Array[Dictionary] = spots.filter(func(s: Dictionary) -> bool: return not _ready_seen.has(s["key"]))
	if fresh.is_empty():
		_ready_seen.clear()
		fresh = spots
	var best := nearest_spot(fresh, from)
	_ready_seen[best["key"]] = true
	point_out(best)
	return best


## The plot a press at `screen_pos` with `with_tool` lights and may swipe from: an open plot (nothing picked
## there, in 3D a roof or crown standing over it counts) when the tool is a swipe tool, or -1.
func swipe_start(screen_pos: Vector2, with_tool: String) -> int:
	if not Balance.a("input.swipe_tools").has(with_tool):
		return -1
	if picker.is_valid() and int(picker.call(screen_pos)) >= 0:
		return -1
	var i := plot_under(screen_pos)
	if i < 0 or not Game.object_at(i).is_empty():
		return -1
	return i


## Whether the tool in hand would do something on plot `i` (`job_for`, the same rules a tap follows).
func would_act(i: int) -> bool:
	if i < 0 or not Game.object_at(i).is_empty() or tool == "sell":
		return false
	return not job_for(i).is_empty()


## The plot lit under a finger that has just landed (-1 none).
func touched_plot() -> int:
	return _touch_tile if _pressing else -1


## The plot under a point on the screen, or -1 off the farm.
func plot_under(screen_pos: Vector2) -> int:
	var world := get_canvas_transform().affine_inverse() * screen_pos
	return index_at(to_local(world))




## Press and hold on anything on the farm to pick it up (the Move tool's drag, without choosing the tool):
## it lifts off, follows the finger, and lets go where you release: onto the grass, into a home that takes it
## (a vehicle into the Garage, an animal into its pen), or the Barn. Release it where it was to put it back.
func _process(_delta: float) -> void:
	if not _pressing or _dragged or _hold_spent or not _press_on_farm or not placing.is_empty():
		return
	if Time.get_ticks_msec() - _press_msec < int(HOLD_TO_LIFT * 1000.0):
		return
	_hold_spent = true
	var uid := -1
	if picker.is_valid():
		uid = picker.call(_press_pos)
	else:
		var world := get_canvas_transform().affine_inverse() * _press_pos
		var i := index_at(to_local(world))
		uid = int(Game.object_at(i).get("uid", -1)) if i >= 0 else -1
	var obj := Game.object_by_uid(uid)
	if obj.is_empty():
		return  # nothing here to lift: the press carries on as a tap or a drag
	_pressing = false  # it is picked up now (or refused, with its reason), so this press is not a tap
	if start_placing(str(obj["id"]), uid):
		Feedback.moment("place")
		_poke(uid)
	else:
		Feedback.moment("error")


## Whether a touch at `screen_pos` is the farm's: the HUD floats over the farm and its buttons take their own taps
## first (this is unhandled input), so everywhere else is the farm unless a panel is open.
func on_farm_area(_screen_pos: Vector2) -> bool:
	return not Game.modal_open




## Tile (row, col) under a screen point, even outside the farm.
func tile_at_screen(screen_pos: Vector2) -> Vector2i:
	var local := to_local(get_canvas_transform().affine_inverse() * screen_pos)
	var dx := local.x / (TILE_W / 2.0)
	var dy := local.y / (TILE_H / 2.0)
	return Vector2i(int(floor((dy - dx) / 2.0)), int(floor((dy + dx) / 2.0)))




# ---------------------------------------------------------------- placing and moving


## Picks up something to place: a new item (`uid` -1), or one on the farm, which goes only if the rules let it
## move (Game.buildings.can_move); otherwise the reason is shown. Every way of moving (the Move tool, holding
## to lift, a building's panel) comes through here.
func start_placing(item_id: String, uid := -1) -> bool:
	if uid != -1:
		var verdict := Game.buildings.can_move(Game.object_by_uid(uid))
		if not verdict.ok():
			info.emit(verdict.text)
			return false
	placement.start(item_id, uid)
	return true


## Placing something taken back out of the barn (free; it keeps its timers reset).
func start_placing_stored(index: int) -> void:
	placement.start_stored(index)


func cancel_placing() -> void:
	placement.cancel()


func _apply_at(screen_pos: Vector2) -> void:
	# Ignore touches on the top bar, the toolbar, or while a menu covers the farm.
	if not on_farm_area(screen_pos):
		return
	var world := get_canvas_transform().affine_inverse() * screen_pos
	if rust_picker.is_valid() and tool != "vehicle":
		var rusty := str(rust_picker.call(screen_pos))
		if rusty != "":   # (its rust sign: only its repair is offered, not what a tap on the vehicle says)
			tapped_rust.emit(to_local(world), rusty)
			return
	if picker.is_valid() and tool != "vehicle":
		var uid: int = picker.call(screen_pos)
		var picked := Game.object_by_uid(uid)
		if not picked.is_empty():
			_act_on_object(picked, true)
			return
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
		var rig := AnimalRig.of(Game.item_data(obj["id"]))
		Sound.voice(rig.family, rig.young, str(obj["id"]))
	Feedback.moment("touch")




## A sound and a short vibration for something the player did (either may be left out).


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
	var row := _row(i) - int((area.y - 1) / 2.0)
	var col := _col(i) - int((area.x - 1) / 2.0)
	var job: String = Game.item_data(id).get("job", "")
	var crop := last_crop if (job == "plant" or job == "all") else ""
	_vehicle_flash = {"row": row, "col": col, "w": area.x, "h": area.y, "until": Time.get_ticks_msec() + 500}
	queue_redraw()
	_queue({"kind": "vehicle", "item": id, "row": row, "col": col, "crop": crop})


## Queues a job for the farmer (they walk there and do it: PlayerSystem); tapping something already queued
## takes it back out. A swipe (`loud` false) only adds: what is queued stays, and the first refusal is said
## once and ends the swipe's work.
func _queue(job: Dictionary, loud := true) -> void:
	if loud and Game.player.cancel(job):
		Feedback.moment("tap")
		return
	var refused := Game.player.enqueue(job)
	if not loud:
		if refused == PlayerSystem.Refused.QUEUED or refused == PlayerSystem.Refused.NOTHING_TO_DO:
			return
		if refused != PlayerSystem.Refused.NONE:
			_swipe_spent = true
	match refused:
		PlayerSystem.Refused.NONE:
			if loud:
				Feedback.moment("tap")
			else:
				# A swipe's plots climb a scale and count up over the finger: forty plots in one sweep feel like one.
				_swipe_count += 1
				Feedback.moment("tap", _swipe_count - 1)
				_show_combo(int(job.get("plot", -1)))
		PlayerSystem.Refused.COINS:
			Feedback.moment("error")
			info.emit(tr(COINS_NEEDED.get(job["kind"], "NOT_ENOUGH_COINS_TO_PLOW")).replace("%s",
				str(Game.crops.get(str(job.get("crop", "")), {}).get("name", ""))))
		PlayerSystem.Refused.SUPPLY:
			Feedback.moment("error")
			object_tapped.emit(int(job["uid"]))
		PlayerSystem.Refused.FULL:
			Feedback.moment("error")
			info.emit(tr("THE_FARMER_HAS_ENOUGH_TO_DO") % PlayerSystem.queue_max())
		_:
			Feedback.moment("error")


## The count of a swipe's plots so far ("x7"), popping over plot `i` (the one just added) and fading when the
## swipe stops adding. One label, kept: a long swipe moves it, it makes none.
func _show_combo(i: int) -> void:
	if _swipe_count < 2 or i < 0:
		return
	if _combo == null:
		_combo = Label.new()
		_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_combo.size = Vector2(160, 44)
		_combo.pivot_offset = _combo.size / 2.0
		_combo.z_index = 11
		_combo.add_theme_font_size_override("font_size", 34)
		_combo.add_theme_color_override("font_color", Feedback.color("golden"))
		_combo.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.05))
		_combo.add_theme_constant_override("outline_size", 9)
		add_child(_combo)
	_combo.text = COUNT_TAG % _swipe_count
	_combo.position = center_of(i) - Vector2(80, 96)
	_combo.modulate.a = 1.0
	_combo.scale = Vector2(1.35, 1.35)
	if _combo_tween != null:
		_combo_tween.kill()
	_combo_tween = _combo.create_tween()
	_combo_tween.tween_property(_combo, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT)
	_combo_tween.tween_property(_combo, "modulate:a", 0.0, 0.5).set_delay(0.6)


## How far into a streak the farmer's job on plot `i` is (0 for the first): the same kind of job as the last,
## done soon after it (Balance `feel.streak_gap_seconds`), is one step further, and plays a note higher
## (Feedback.moment). Every few in a row the streak says its count over the plot. Feel only: it pays nothing.
func _run(kind: String, i: int) -> int:
	var now := Time.get_ticks_msec()
	if kind == _streak_kind and now - _streak_msec <= int(Balance.f("feel.streak_gap_seconds") * 1000.0):
		_streak += 1
	else:
		_streak = 1
	_streak_kind = kind
	_streak_msec = now
	var every := Balance.i("feel.streak_shout_every")
	if every > 0 and _streak % every == 0:
		float_words(center_of(i) + Vector2(0, -64), COUNT_TAG % _streak, "golden", 1.3)
	return _streak - 1


## The farmer got to a job and did it (or found nothing left to do: an empty result).
func _on_action_done(job: Dictionary, result: Dictionary) -> void:
	var pt := PerfReadout.start()
	_on_action_done_timed(job, result)
	PerfReadout.stop("farm_action_done", pt)


func _on_action_done_timed(job: Dictionary, result: Dictionary) -> void:
	if result.is_empty():
		if job["kind"] != "vehicle":
			Feedback.moment("error")
		return
	var i := int(job.get("plot", -1))
	match str(job["kind"]):
		"harvest":
			_show_harvest(i, job, result)
		"plow":
			Feedback.moment("plow", _run("plow", i))
			world_fx.burst("dirt", center_of(i))
			float_words(center_of(i), "-%d" % Balance.i("economy.plow_cost"), "cost")
		"plant":
			Feedback.moment("plant", _run("plant", i))
			world_fx.burst("dirt", center_of(i) + Vector2(0, -PlaceholderArt.SLAB))
			float_words(center_of(i), "-%d" % int(Game.crops[job["crop"]]["seed_cost"]), "cost")
		"fertilize":
			Feedback.moment("fertilize", _run("fertilize", i))
			float_words(center_of(i), "-%d" % Balance.i("economy.fertilizer_cost"), "cost")
			_sparkle(center_of(i), "fert")
		"collect":
			_show_collect(int(job["uid"]), result)
		"nurture":
			_show_nurture(job, result)
		"feed":
			_show_fed(int(job["uid"]), result)
		"vehicle":
			Feedback.moment("tap")   # it sets off; what it did is shown when it finishes (_show_vehicle)


## A vehicle finished its run: what it did, floating up where it worked.
func _show_vehicle(run: VehicleWork) -> void:
	var r := run.result
	var row := run.row
	var col := run.col
	var area := run.area
	var at := center_of(
		Game.index_of(clampi(row + int(area.y / 2.0), 0, MAX - 1), clampi(col + int(area.x / 2.0), 0, MAX - 1))
	)
	var coins_moved := int(r["coins"])
	if coins_moved != 0:
		float_words(at, ("+%d" if coins_moved > 0 else "%d") % coins_moved, "coins" if coins_moved > 0 else "cost")
	if int(r["xp"]) > 0:
		float_words(at + Vector2(0, -30), tr("XP") % int(r["xp"]), "xp")
	float_words(at + Vector2(0, -60), tr("PLOTS_FUEL") % [int(r["plots"]), int(r["fuel"])], "part", 1.4)
	var lift := -96
	for d in r["drops"]:
		float_words(at + Vector2(0, lift), d, "golden", 1.6)
		lift -= 32




## A find, said where it was made, the same way for every kind of find (a gopher, a collectible, a bird, a golden
## harvest, a baby born, a stray, what a mystery opens to): its words rise in the colour of how rare it is,
## sparks fly, and it chimes: one note for a common find up to a full run for a legendary one (Feedback.rarity,
## data/feedback.json). So a colour and a sound always mean the same luck. Finds made at one place at one time
## (a harvest that turns up two things) rise one above the other, a beat apart.
func show_find(at: Vector2, text: String, rarity: String) -> void:
	var now := Time.get_ticks_msec()
	if at.distance_squared_to(_find_at) > 4.0 or now - _find_msec > FIND_STACK_MSEC:
		_find_stack = 0
	_find_at = at
	_find_msec = now
	var nth := _find_stack
	_find_stack += 1
	if nth == 0:
		_burst_find(at, text, rarity, 0)
	else:
		get_tree().create_timer(FIND_BEAT * nth).timeout.connect(_burst_find.bind(at, text, rarity, nth))


func _burst_find(at: Vector2, text: String, rarity: String, nth: int) -> void:
	var look := Feedback.rarity(rarity)
	var color: Color = look["color"]
	Feedback.moment(str(look["moment"]))
	# The words: in the rarity's colour and size, popping in, then rising and fading.
	var label := Label.new()
	label.text = UiTheme.tidy(text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(520, 48)
	label.pivot_offset = label.size / 2.0
	label.position = at + Vector2(-260, -96 - FIND_RISE * nth)
	label.z_index = 12
	label.add_theme_font_size_override("font_size", int(look["words"]))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.16, 0.1, 0.05))
	label.add_theme_constant_override("outline_size", 9)
	label.scale = Vector2(0.4, 0.4)
	add_child(label)
	var hold := float(look["hold"])
	var tw := label.create_tween()
	tw.tween_property(label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position:y", label.position.y - 46.0, hold).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, hold * 0.4).set_delay(hold * 0.6)
	tw.tween_callback(label.queue_free)
	# The sparks: four-pointed stars flying out, more of them, bigger and further the rarer the find.
	var sparks := int(look["sparks"])
	var star := PackedVector2Array()
	for j in 8:
		star.append(Vector2.from_angle(TAU * j / 8.0) * (7.0 if j % 2 == 0 else 2.4) * float(look["size"]))
	for k in sparks:
		var dot := Polygon2D.new()
		dot.polygon = star
		dot.color = color.lerp(Color.WHITE, 0.35 if k % 3 == 0 else 0.0)
		dot.position = at + Vector2(0, -30)
		dot.z_index = 11
		add_child(dot)
		var dir := Vector2.from_angle(TAU * (k + randf() * 0.6) / sparks) * float(look["reach"]) * randf_range(0.55, 1.0)
		var fly := dot.create_tween().set_parallel(true)
		fly.tween_property(dot, "position", dot.position + dir * Vector2(1.0, 0.7), 0.6).set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_CUBIC)
		fly.tween_property(dot, "rotation", randf_range(-2.0, 2.0), 0.6)
		fly.tween_property(dot, "scale", Vector2(0.2, 0.2), 0.6).set_ease(Tween.EASE_IN)
		fly.tween_property(dot, "modulate:a", 0.0, 0.25).set_delay(0.35)
		fly.chain().tween_callback(dot.queue_free)


## A young one was given its supply: how far along it is, or what it grew into.
func _show_nurture(job: Dictionary, result: Dictionary) -> void:
	var grown := str(result["grown"])
	var o := Game.object_by_uid(int(job["uid"]))
	if result.get("regrown", false):
		if not o.is_empty():
			var at0 := center_of(Game.index_of(int(o["row"]), int(o["col"])))
			Feedback.moment("fertilize")
			float_words(at0 + Vector2(0, -40), tr("REGROWN"), "fert")
			_sparkle(at0, "fert")
		return
	if grown == "":
		if o.is_empty():
			return
		var at := center_of(Game.index_of(int(o["row"]), int(o["col"])))
		Feedback.moment("fertilize")
		float_words(at + Vector2(0, -40), "%d/%d" % [int(result["fed"]), int(result["needs"])], "fert")
		return
	# The reveal: the mystery shakes, opens, and what it was all along stands there, named in the colours of how
	# rare it is. The 3D world plays the shaking and the opening (`hatcher`); without it, it opens at once.
	var at := center_of(Game.index_of(int(result["row"]), int(result["col"])))
	var grown_uid := int(result.get("grown_uid", -1))
	var opened := func() -> void:
		Feedback.moment("reveal_open")
		world_fx.burst("sparkle", at + Vector2(0, -40))
		show_find(at, tr("ITS_A") % str(Game.item_data(grown)["name"]), Game.rarity_of_item(grown))
	if hatcher.is_valid():
		hatcher.call(int(result.get("young", -1)), grown_uid, opened)
	else:
		opened.call()


func _show_harvest(i: int, job: Dictionary, result: Dictionary) -> void:
	var at := center_of(i)
	Feedback.moment("harvest", _run("harvest", i))
	_pop_plants(i, job["crop"], job["art"])
	world_fx.burst("leaves", at + Vector2(0, -PlaceholderArt.SLAB))
	_reward(at, int(result["coins"]), int(result["xp"]))
	float_words(at, "+%d" % result["coins"], "coins")
	float_words(at + Vector2(0, -30), tr("XP") % result["xp"], "xp")
	if result.get("rain", false):   # (the rain that watered it, said where the coins are)
		float_words(at + Vector2(0, 26), tr("RAINED_ON") % roundi(Balance.f("seasons.rain_bonus") * 100.0), RAIN_BLUE, 1.4)
	if result.get("part", "") != "":
		float_words(at + Vector2(0, -128), "+1 " + GameState.part_names[result["part"]], "part", 1.6)
	if result.get("bushel", "") != "":
		var nb := int(result.get("bushels", 1))
		float_words(
			at + Vector2(0, -160),
			(tr("ONE_BUSHEL") if nb == 1 else tr("N_BUSHELS")) % [nb, Game.crops[result["bushel"]]["name"]],
			"part",
			1.6
		)
	if result.get("feed", "") != "":
		float_words(at + Vector2(0, -192), tr("FOUND_FEED") % Game.feeds.feed_name(result["feed"], bool(result["feed_rich"])),
			Game.feeds.feed_color(result["feed"]), 1.6)
	if int(result.get("pollinated", 0)) > 0:
		float_words(at + Vector2(0, -160), tr("POLLINATED_SEEDS") % int(result["pollinated"]), "find", 1.8)
		_sparkle(at, "find")
	# (what it turned up, a drop, a creature, a bee, was said as it was found: Game.found -> show_find)


## Fed (our own touch): the home hops, a heart and what the feed will do float up.
func _show_fed(uid: int, result: Dictionary) -> void:
	var o := Game.object_by_uid(uid)
	if o.is_empty():
		return
	var fp := Game.footprint(o["id"])
	var g := corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
	var at := (g[0] + g[2]) / 2.0
	Feedback.moment("collect_soft")
	_poke(uid)
	var line := tr("FED_FX_" + str(result["effect"]).to_upper())
	float_words(at + Vector2(0, -96), line, Game.feeds.feed_color(str(result["feed"])), 1.6)
	_sparkle(at, "find")


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
	Feedback.moment("collect")
	world_fx.burst("sparkle", at + Vector2(0, -40))
	_reward(at + Vector2(0, -30), int(result["coins"]), int(result["xp"]))
	float_words(at + Vector2(0, -20), "+%d" % result["coins"], "coins")
	if int(result["xp"]) > 0:
		float_words(at + Vector2(0, -50), tr("XP") % result["xp"], "xp")
	if result.get("part", "") != "":
		float_words(at + Vector2(0, -118), "+1 " + GameState.part_names[result["part"]], "part", 1.6)
	var lift := -150
	for extra in result.get("extras", []):
		float_words(at + Vector2(0, lift), extra, "golden", 1.8)
		lift -= 32
	if not result.get("extras", []).is_empty():
		_sparkle(at, "golden")
	# (a drop, a collectible, a baby born: said as it was found, Game.found_on -> show_find)


## Works plot `i` (or what stands on it) with the tool in hand. `loud`: a tap, which says why when nothing can be
## done and takes back what is already queued; a swipe passes `false`, so it only adds work and says nothing
## for each plot it crosses.
func _act(i: int, loud: bool) -> void:
	var obj := Game.object_at(i)
	if not obj.is_empty():
		_act_on_object(obj, loud)
		return
	# The sell tool deletes plots (FarmVille's delete): even a ripe crop, after asking.
	if tool == "sell":
		if loud:
			_try_clear(i)
		return
	var job := job_for(i)
	if not job.is_empty():
		_queue(job, loud)
	elif loud:
		if tool == "fertilize" and Game.field.phase(i) == GameState.Phase.GROWING:
			info.emit(tr("ALREADY_FERTILIZED_THIS_HARVEST_PAYS_MORE"))
		elif tool == "fertilize":
			info.emit(tr("FERTILIZE_GROWING_CROPS_FOR_MORE_COINS"))
		else:
			_explain(i, Game.field.phase(i))


## The job the tool in hand would give the farmer on open plot `i`, or {} for none: the one table of what each
## tool does to each kind of plot, which a tap (`_act`) and a swipe (`would_act`) both follow. A ripe crop is
## harvested by any tool (tapping ripe crops should always just work).
func job_for(i: int) -> Dictionary:
	var ph := Game.field.phase(i)
	if ph == GameState.Phase.RIPE:
		return {"kind": "harvest", "plot": i}
	match tool:
		"plow":
			if ph == GameState.Phase.GRASS or ph == GameState.Phase.WITHERED:
				return {"kind": "plow", "plot": i}
		"plant":
			if ph == GameState.Phase.PLOWED and selected_crop != "":
				return {"kind": "plant", "plot": i, "crop": selected_crop}
		"fertilize":
			if ph == GameState.Phase.GROWING and not Game.field.is_fertilized(i):
				return {"kind": "fertilize", "plot": i}
	return {}


func _act_on_object(obj: Dictionary, loud: bool) -> void:
	var uid := int(obj["uid"])
	var kind := Game.kind_of(obj)
	if tool == "sell" and loud:
		_try_sell(obj)
		return
	if tool == "rotate" and loud:
		Game.rotate_object(uid)
		return
	if tool == "store" and loud:
		if Game.storage.store_object(uid):
			var fps := Game.footprint(obj["id"])
			float_words(corners_of(int(obj["row"]), int(obj["col"]), fps.x, fps.y)[2], tr("STORED"), "xp")
		return
	if kind == "barn" and tool != "move":
		if loud:
			_poke(uid)
			object_tapped.emit(uid)
		return
	if kind == "vehicle" and tool != "move":
		# Tapping a vehicle takes it in hand to work the fields (FarmVille's way); with no fuel, the fuel panel.
		if loud:
			_poke(uid)
			if Game.under_construction(obj) or Game.vehicles.fuel_now() <= 0:
				_tell(obj)
			else:
				set_tool("vehicle", str(obj["id"]))
				tool_changed.emit("vehicle")
		return
	if kind == "decor" and tool != "move":
		if loud:
			_poke(uid)
			var def := Game.catalog.get_def(str(obj["id"]))
			var panel: String = (def as DecorationDef).opens() if def is DecorationDef else ""
			if panel != "":
				panel_requested.emit(panel)
			else:
				_tell(obj)
		return
	if obj.get("stray", false) and tool != "move":
		if loud:
			_poke(uid)
		if loud and Game.strays.adopt_stray(uid):
			var fp0 := Game.footprint(obj["id"])
			var c0 := corners_of(int(obj["row"]), int(obj["col"]), fp0.x, fp0.y)
			var at0 := (c0[0] + c0[2]) / 2.0
			float_words(at0 + Vector2(0, -40), tr("ADOPTED_XP") % Balance.i("strays.stray_adopt_xp"), "find", 1.4)
			_sparkle(at0, "find")
		return
	if tool == "move":
		if loud:
			start_placing(obj["id"], uid)
		return
	var supply := Game.nurture.supply_for(obj)
	if supply != "":
		# A young one, or a withered bloom: given its supply by the farmer; with none to give, its card
		# shows what it needs and sells more.
		if loud:
			_poke(uid)
			if Game.player.is_queued({"kind": "nurture", "uid": uid}) or Game.nurture.free_supply(supply) > 0:
				_queue({"kind": "nurture", "uid": uid})
			else:
				_tell(obj)
		return
	if Game.is_ready(obj):
		_queue({"kind": "collect", "uid": uid})
		return
	if not loud:
		return
	_poke(uid)
	_tell(obj)   # (its name and when it will be ready, above it; its panel, if it has one, from the bubble)




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
			Feedback.moment("sell")
			float_words(at, "+%d" % value, "coins")
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
		Feedback.moment("plow")
		world_fx.burst("dirt", center_of(i))


func _explain(i: int, ph: GameState.Phase) -> void:
	match ph:
		GameState.Phase.GRASS:
			info.emit(tr("PLOW_THIS_PLOT_FIRST"))
		GameState.Phase.PLOWED:
			info.emit(tr("PICK_A_SEED_TO_PLANT_HERE"))
		GameState.Phase.GROWING:
			var crop: Dictionary = Game.crops[Game.field.crop_at(i)]
			tapped_info.emit(center_of(i) + Vector2(0, -BUBBLE_LIFT), str(crop["name"]),
				tr("BUBBLE_READY_IN") % format_duration(Game.field.seconds_until_ripe(i)), -1)
		GameState.Phase.WITHERED:
			tapped_info.emit(center_of(i) + Vector2(0, -BUBBLE_LIFT), str(Game.crops[Game.field.crop_at(i)]["name"]),
				tr("BUBBLE_WITHERED"), -1)




## Shows what `obj` is and how it is doing in a bubble above it (FarmVille's way): its name, and a line: ready in
## how long, withered, being built, or what it needs.
func _tell(obj: Dictionary) -> void:
	var fp := Game.footprint(obj["id"])
	var c := corners_of(int(obj["row"]), int(obj["col"]), fp.x, fp.y)
	var lift := BUBBLE_LIFT + BUBBLE_LIFT_PER_TILE * maxi(fp.x, fp.y)
	tapped_info.emit((c[0] + c[2]) / 2.0 + Vector2(0, -lift), str(Game.item_data(obj["id"])["name"]), status_of(obj),
		int(obj["uid"]))


## One short line on how a placed thing is doing ("" when there is nothing to say: a decoration).
static func status_of(obj: Dictionary) -> String:
	if Game.under_construction(obj):
		return TranslationServer.translate("BUBBLE_BUILDING")
	if Game.is_withered(obj):
		return TranslationServer.translate("BUBBLE_WITHERED_THING")
	var supply := Game.nurture.supply_for(obj)
	if supply != "":
		return TranslationServer.translate("BUBBLE_NEEDS") % Game.nurture.supply_name(supply)
	if Game.kind_of(obj) == "decor":
		return ""
	var line := ""
	if Game.is_ready(obj):
		line = TranslationServer.translate("BUBBLE_READY")
	else:
		var wait := Game.seconds_until_ready(obj)
		line = TranslationServer.translate("BUBBLE_READY_IN") % format_duration(wait) if wait > 0 else ""
	if Game.is_home(obj) and Game.capacity(obj) > 0:
		# How full a home is, then when it's ready: "6/10 · Ready in 3h".
		var held := 0
		for n in (obj.get("inside", {}) as Dictionary).values():
			held += int(n)
		var full := "%d/%d" % [held, Game.capacity(obj)]
		line = full if line == "" else full + "  ·  " + line
	return line


static func format_duration(seconds: int) -> String:
	if seconds < 60:
		return TranslationServer.translate("LESS_THAN_A_MINUTE")
	var d := int(seconds / 86400.0)
	var h := int((seconds % 86400) / 3600.0)
	var m := int((seconds % 3600) / 60.0)
	# Never a zero part: "4h", "1d", "12h 30m", "1d 6h" (not "4h 0m" or "1d 0h").
	if d > 0:
		return "%dd %dh" % [d, h] if h > 0 else "%dd" % d   # not-ui
	if h > 0:
		return "%dh %dm" % [h, m] if m > 0 else "%dh" % h   # not-ui
	return "%dm" % m   # not-ui




## Celebrates an upgrade on the building itself: fireworks over it (the 3D world's: `fireworks`; a burst of
## sparkles without it) and a level popup.
func _on_building_upgraded(uid: int, level: int) -> void:
	var o := Game.object_by_uid(uid)
	if o.is_empty():
		return
	var fp := Game.footprint(o["id"])
	var g := corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
	var at := (g[0] + g[2]) / 2.0 + Vector2(0, -60)
	float_words(at, (tr("BUILT") if level == 1 else "%s!" % Game.size_name(o)), "golden", 2.0)
	float_words(at + Vector2(0, 34), tr("HOLDS") % Game.capacity(o), "xp", 2.0)
	if fireworks.is_valid():
		fireworks.call(uid)
		return
	for k in 3:
		_sparkle(at + Vector2(-50 + 50 * k, 20), "golden")


## A new VIP level gives the Barn a new look: its fireworks go up.
func _on_vip_level_reached(_level: int) -> void:
	for o in Game.objects:
		if fireworks.is_valid() and Game.is_building_item(str(o["id"])) and Game.building_def(str(o["id"])).shows_vip():
			fireworks.call(int(o["uid"]))




## A short burst of dots for surprise drops, so a find feels like an event.
func _sparkle(pos: Vector2, look: Variant) -> void:
	var color: Color = look if look is Color else Feedback.color(str(look))
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




func float_words(pos: Vector2, text: String, look: Variant, duration := 1.0) -> void:
	var color: Color = look if look is Color else Feedback.color(str(look))  # a Color, or a Feedback float style
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
