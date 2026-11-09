class_name ObjectLayer
extends Node2D
## Everything standing on the farm, one FarmPiece node each, drawn in correct depth order.
##
## Depth: on an isometric grid a 1x1 tile (r, c) is drawn by its diagonal r + c. A footprint of w x h
## tiles starting at (r, c) must come after every tile that overlaps it on screen from behind and before
## every tile in front; for footprints whose sides differ by at most one tile that is exactly "after the
## diagonal r + c + min(w, h) - 1". So plots get z = 2 * (r + c) and objects 2 * (r + c + min(w, h) - 1) + 1,
## which keeps tiles and objects correctly interleaved without any per-frame sorting.

const Z_BASE := -2000   # pieces sit below the overlay and effects (z >= 0) and above the ground

const WANDER := 0.22      # how far an animal strays from its tile centre, in tiles
const CULL_MARGIN := 120.0  # px around the screen within which animals keep redrawing
const FULL_RATE_ZOOM := 0.55  # zoomed out further than this, animals redraw every other frame
const IDLE_REDRAW := 1.0 / 20.0  # seconds between redraws of an animal standing still
const MIN_TURN_WIDTH := 0.06  # an animal mid-turn is never drawn at zero width

var grid: FarmGrid
var pieces := {}        # "p<index>" or "o<uid>" -> FarmPiece
var wind := 0.6           # from the weather: how hard plants and trees sway

var _sync_queued := false
var _settled := false   # after the first sync, new pieces arrive with an animation (not on loading)

var _ready_list: Array = []  # pieces showing something ready, kept fresh by refresh_all and sync



var _clock := 0.0
var _frame := 0




func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 1.0  # crops change stage and things become ready over time
	timer.autostart = true
	timer.timeout.connect(refresh_all)
	add_child(timer)




static func plot_z(row: int, col: int) -> int:
	return Z_BASE + 2 * (row + col)




static func object_z(row: int, col: int, fp: Vector2i) -> int:
	return Z_BASE + 2 * (row + col + mini(fp.x, fp.y) - 1) + 1




## Coalesces many change signals in one frame into a single sync.
func queue_sync() -> void:
	if not _sync_queued:
		_sync_queued = true
		call_deferred("sync")




## A single plot changed: add, drop or redraw just its piece.
func on_plot(i: int) -> void:
	if i < 0:
		queue_sync()
		return
	_sync_plot(i)




func sync() -> void:
	_sync_queued = false
	var want := {}
	var n := Game.farm_size
	for r in n:
		for c in n:
			var i := Game.index_of(r, c)
			if _wants_plot(i):
				want["p%d" % i] = true
	var lifted := int(grid.placing.get("uid", -1))
	for o in Game.objects:
		if int(o["uid"]) != lifted:
			want["o%d" % int(o["uid"])] = true
	for key in pieces.keys():
		if not want.has(key):
			(pieces[key] as FarmPiece).queue_free()
			pieces.erase(key)
	for key in want:
		var p: FarmPiece = pieces.get(key)
		if p == null:
			p = FarmPiece.new()
			p.grid = grid
			if str(key).begins_with("p"):
				p.plot = int(str(key).substr(1))
				p.plants = CropPlants.new()
				p.plants.piece = p
				p.plants.position = Vector2(0, -PlaceholderArt.SLAB)
				p.add_child(p.plants)
			else:
				p.uid = int(str(key).substr(1))
			p.phase = randf() * TAU
			pieces[key] = p
			add_child(p)
			_place(p)
			p.refresh()
			if _settled:
				if p.plot >= 0:
					p.rise()
				else:
					p.drop_in()
			continue
		var moved_from := p.base
		_place(p)
		p.refresh()
		if _settled and p.plot < 0 and moved_from != p.base:
			p.drop_in()  # moved: it lands in its new spot
	_ready_list = pieces.values().filter(func(p): return p.is_ready())
	_settled = true




## A tapped object squashes and springs back.
func bounce(uid: int) -> void:
	var p: FarmPiece = pieces.get("o%d" % uid)
	if p != null:
		p.bounce()




func refresh_all() -> void:
	wind = {
		"clear": 0.6,
		"partly_cloudy": 0.8,
		"cloudy": 1.0,
		"rain": 1.5,
		"storm": 2.4,
		"fog": 0.35,
		"snow": 0.9
	}.get(Game.weather()["state"], 0.6)
	for p in pieces.values():
		(p as FarmPiece).refresh()
	_ready_list = pieces.values().filter(func(p): return p.is_ready())




## Every piece redrawn (art arrived, day changed...).
func redraw_all() -> void:
	for p in pieces.values():
		(p as FarmPiece).force_redraw()




## Pieces showing something ready to collect (the overlay twinkles over them).
func ready_pieces() -> Array:
	return _ready_list.filter(func(p): return is_instance_valid(p) and p.is_ready())




func _wants_plot(i: int) -> bool:
	return Game.phase(i) != GameState.Phase.GRASS and not Game.is_occupied(i)




func _sync_plot(i: int) -> void:
	var key := "p%d" % i
	var has := pieces.has(key)
	if _wants_plot(i) != has:
		queue_sync()
	elif has:
		var p := pieces[key] as FarmPiece
		p.refresh()
		if p.is_ready() and not _ready_list.has(p):
			_ready_list.append(p)




func _place(p: FarmPiece) -> void:
	if p.plot >= 0:
		p.z_index = plot_z(int(p.plot / float(GameState.MAX_SIZE)), p.plot % GameState.MAX_SIZE)
		p.base = grid.center_of(p.plot)
	else:
		var o := Game.object_by_uid(p.uid)
		var fp := Game.footprint(o["id"])
		p.z_index = object_z(int(o["row"]), int(o["col"]), fp)
		var g := grid.corners_of(int(o["row"]), int(o["col"]), fp.x, fp.y)
		var new_base := (g[0] + g[2]) / 2.0
		var moved := new_base != p.base
		p.base = new_base
		p.motion = motion_of(o)
		if p.is_animal() and (moved or p.animal == null or p.animal.rig != AnimalRig.of(Game.item_data(o["id"]))):
			# A new animal, or one moved to a new spot: it starts afresh there, on its own beat.
			p.animal = AnimalBehaviour.new(AnimalRig.of(Game.item_data(o["id"])), int(o["uid"]) * 7919,
				Vector2(WANDER * FarmGrid.TILE_W / 2.0, WANDER * FarmGrid.TILE_H / 2.0))
		elif not p.is_animal():
			p.animal = null
		p.flip = -1.0 if o.get("flip", false) else 1.0
	p._apply_pose()




## How a thing moves: animals wander and breathe, birds also peck, trees sway; buildings stay put.
static func motion_of(o: Dictionary) -> String:
	if o.get("stray", false):
		return "animal"
	match Game.kind_of(o):
		"animal":
			var fam := str(Game.item_data(o["id"]).get("family", ""))
			return "bird" if fam in ["chicken", "duck", "goose", "turkey"] else "animal"
		"tree":
			return "tree"
	return ""




# ---------------------------------------------------------------- motion (FarmVille's farm was never still)


func _process(delta: float) -> void:
	_clock += delta
	_frame += 1
	var t := _clock
	var view := _visible_rect()
	var every_frame := get_global_transform_with_canvas().get_scale().x >= FULL_RATE_ZOOM
	for v in pieces.values():
		var p := v as FarmPiece
		if p.plants != null:
			# Plants sway from the stem; each plot on its own beat, harder in wind.
			p.plants.skew = sin(t * 1.7 + p.phase) * 0.05 * wind
			continue
		match p.motion:
			"tree":
				p.skew = sin(t * 0.8 + p.phase) * 0.018 * wind
			"animal", "bird":
				if p.animal != null:
					_animate_animal(p, delta, view, every_frame or (_frame + p.uid) % 2 == 0)


## Moves an animal by its behaviour and redraws it in its new pose. Off screen it keeps living (so it
## isn't frozen when scrolled to) but isn't redrawn; zoomed far out, it redraws on alternate frames.
func _animate_animal(p: FarmPiece, delta: float, view: Rect2, redraw: bool) -> void:
	var a := p.animal
	a.update(delta)
	p.position = p.base + a.offset - Vector2(0, p.lift)
	# Turning: the facing eases through zero, so the body narrows and widens the other way. Never quite
	# zero, which would make the node's transform impossible to invert.
	var face := a.shown_facing
	if absf(face) < MIN_TURN_WIDTH:
		face = MIN_TURN_WIDTH * (1.0 if a.facing > 0.0 else -1.0)
	p.scale = Vector2(face * p.flip, 1.0) * p.squash
	p.rotation = 0.0
	if not redraw or not view.has_point(p.position):
		return
	# Walking, the legs need every frame; standing, only blinks, ears and tails move: a lower rate does.
	var moving := a.pose.stride > 0.02 or a.pose.hop > 0.0 or a.pose.wing > 0.0
	p.redraw_wait -= delta
	if moving or p.redraw_wait <= 0.0:
		p.redraw_wait = IDLE_REDRAW
		p.queue_redraw()


## The part of this layer that's on screen, plus a margin.
func _visible_rect() -> Rect2:
	var to_screen := get_global_transform_with_canvas()
	var screen := get_viewport_rect()
	var r := to_screen.affine_inverse() * screen
	return r.grow(CULL_MARGIN / maxf(to_screen.get_scale().x, 0.01))
