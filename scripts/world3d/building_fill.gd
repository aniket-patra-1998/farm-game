class_name BuildingFill
extends Node3D
## How full a building is and how close to ready, shown on the building itself, as FarmVille did it (not
## with a number): some of the animals living there are out in its yard, more as it fills; what they make
## piles up by the door as collection nears (eggs in a basket, milk churns, wool bales, honey jars...); an
## orchard shows the very trees it holds, fruiting when they're ready. When you collect, the doors swing
## open, the produce pops off and the animals start.
##
## Lives under a building's model (the footprint's back corner is its origin), so it turns with it. What
## to show comes from the building's description (data/building_models.json "fill").

const OFFSCREEN_STRIDE := 6      # a yard out of sight thinks one frame in this many
const RESIDENTS := 14         # the most animals out in a yard at once (a full building)
const MAX_KINDS := 5          # the most different kinds a home shows (FarmVille showed up to five)
const SPOT_GAP := 0.34        # tiles between places an animal can stand
const EDGE := 0.28            # and how far those keep from the footprint's edge (inside the fence)
const KEEP_CLEAR := 0.16      # and from walls and the like
const WANDER := 0.1           # tiles a resident strays from its place
const DOOR_OPEN := 1.75       # radians a door swings open
const DOOR_HOLD := 1.2        # seconds it stays open
const PRODUCE_STEPS := 6      # piles grow in this many steps as collection nears
const PRODUCE_SCALE := 1.5    # and are drawn this much bigger than life: they must read from across the farm
const FULL_FLAG := Color("#d8402f")   # the pennant a full home flies
const PLANT_KINDS := ["tree", "bloom"]   # what grows in a garden-like building (shown by _show_plants)
const TREE_FILL := 1.3            # an orchard tree's size, against the space between trees (crowns touch)
const BLOOM_SIZE := 1.5           # a bloom in a Bloom Garden, against one on its own tile (1.6)

var uid := -1
var residents: Array[Animal3D] = []

var _id := ""
var _fp := Vector2i.ONE
var _spec := {}
var _spots: Array[Vector3] = []
var _who := ""                # who's inside, as last shown
var _stage := ""              # how near ready, as last shown
var _produce: Node3D
var _flag: Node3D             # flown while the building is full
var _idle := 0.0               # time not yet given to the residents' minds
var _stock: Node3D               # a Garage's parked vehicles, a shed's pots, a barn's goods
var _stock_sig := ""
var _plants: Node3D               # the trees or blooms growing in an Orchard or Bloom Garden
var _doors: Array[Node3D] = []


## The fill layer for building `o`, under its model `model` (which holds its doors).
static func create(o: Dictionary, model: Node3D) -> BuildingFill:
	var f := BuildingFill.new()
	f.uid = int(o["uid"])
	f._id = str(o["id"])
	f._fp = Game.footprint(f._id)
	f._spec = BuildingModel.spec(f._id, Game.level_of(o))
	f._spots = open_spots(f._spec, f._fp, int(o["uid"]))
	for c in model.get_children():
		if c.has_meta(BuildingModel.DOOR):
			f._doors.append(c)
			c.set_meta("rest_y", (c as Node3D).position.y)
	f.refresh(o)
	return f


## Whether a building shows anything of what's inside it.
static func shows(o: Dictionary) -> bool:
	if Game.under_construction(o) or not Game.is_building(o):
		return false
	var def := Game.catalog.get_def(str(o["id"]))
	# Homes for named animals, or gardens for a kind (trees in an Orchard, blooms in a Bloom Garden).
	if not def is BuildingDef:
		return false
	return (not (def as BuildingDef).holds().is_empty()
		or str((def as BuildingDef).data.get("holds_kind", "")) in PLANT_KINDS
		or BuildingModel.spec(str(o["id"]), Game.level_of(o)).get("fill", {}).has("stock"))


## Places in the yard where an animal (or a tree) can stand: a grid over the footprint, inside the fence,
## clear of the building, its annexes and what stands beside it. Shuffled by the building's own seed, so
## the first few are spread about, not in a row.
static func open_spots(spec: Dictionary, fp: Vector2i, seed_value: int) -> Array[Vector3]:
	var blocked := BuildingModel.taken(spec, fp)
	var out: Array[Vector3] = []
	var nx := maxi(1, int((fp.x - EDGE * 2.0) / SPOT_GAP) + 1)
	var nz := maxi(1, int((fp.y - EDGE * 2.0) / SPOT_GAP) + 1)
	for i in nx:
		for j in nz:
			var p := Vector2(lerpf(EDGE, fp.x - EDGE, i / maxf(nx - 1.0, 1.0)),
				lerpf(EDGE, fp.y - EDGE, j / maxf(nz - 1.0, 1.0)))
			var clear := true
			for r: Rect2 in blocked:
				if r.grow(KEEP_CLEAR).has_point(p):
					clear = false
					break
			if clear:
				out.append(Vector3(p.x, 0, p.y))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k in range(out.size() - 1, 0, -1):
		var swap := rng.randi_range(0, k)
		var t := out[k]
		out[k] = out[swap]
		out[swap] = t
	return out


## Brings what's shown up to date: who's in, how near ready. Rebuilds only what changed.
func refresh(o: Dictionary) -> void:
	var inside: Dictionary = o.get("inside", {})
	var share := ready_share(o)
	var step := int(floor(share * PRODUCE_STEPS))
	var who := JSON.stringify(inside) + "|" + str(Game.capacity(o))
	var stage := "%d|%s" % [step, Game.is_ready(o)]
	var fill: Dictionary = _spec.get("fill", {})
	if fill.has("stock"):
		_show_stock(str(fill["stock"]), fill.get("at", [0.5, 0.95]), o)
		return
	if fill.has("plants"):
		if who != _who or stage != _stage:
			_show_plants(o, int(fill["plants"]))  # trees fruit, blooms open, when ready
	elif who != _who:
		_show_residents(inside, Game.inside_total(o), Game.capacity(o))
	if stage != _stage:
		_show_produce(str(fill.get("produce", "")), step, fill.get("at", [0.78, 0.9]), o)
	_who = who
	_stage = stage
	_show_flag(Game.capacity(o) > 0 and Game.inside_total(o) >= Game.capacity(o) and not fill.has("plants"))


## How near the building is to ready, 0..1 (0 when empty: nothing is being made).
static func ready_share(o: Dictionary) -> float:
	if Game.inside_total(o) == 0:
		return 0.0
	return clampf(1.0 - float(Game.seconds_until_ready(o)) / maxf(Game.cycle_of(o), 1.0), 0.0, 1.0)


## How many animals to show out in the yard: none when empty, one for the first, then in proportion to
## how full it is, up to RESIDENTS (and never more than there are places, or animals).
static func shown_count(inside_total: int, capacity: int, spots: int, kinds := 1) -> int:
	if inside_total <= 0:
		return 0
	var share := float(inside_total) / maxf(capacity, 1.0)
	# At least one of each kind inside (up to MAX_KINDS), so every different one can be seen.
	var want := maxi(maxi(1, int(ceil(share * RESIDENTS))), mini(kinds, MAX_KINDS))
	return mini(mini(want, spots), inside_total)


## How many different kinds are inside (the ones that count).
static func distinct_kinds(inside: Dictionary) -> int:
	var n := 0
	for id: String in inside:
		if int(inside[id]) > 0:
			n += 1
	return n


## `n` things to show out of what's inside, so that each different kind (the MAX_KINDS commonest) is there at
## least once and the rest are in proportion to how many of each there are. Mixed, not in blocks of a kind.
static func pick_kinds(inside: Dictionary, n: int, max_kinds := MAX_KINDS) -> Array[String]:
	var kinds: Array = inside.keys().filter(func(id: String) -> bool: return int(inside[id]) > 0)
	kinds.sort_custom(func(a: String, b: String) -> bool: return int(inside[a]) > int(inside[b]))
	kinds = kinds.slice(0, max_kinds)
	var out: Array[String] = []
	if kinds.is_empty() or n <= 0:
		return out
	var total := 0
	for id: String in kinds:
		total += int(inside[id])
	var want := {}
	var given := 0
	for id: String in kinds:
		want[id] = maxi(1, int(round(float(inside[id]) / maxf(total, 1.0) * n)))
		given += int(want[id])
	while given > n:  # rounding gave too many: take from whichever has most
		var most: String = kinds[0]
		for id: String in kinds:
			if int(want[id]) > int(want[most]):
				most = id
		if int(want[most]) <= 1:
			break
		want[most] = int(want[most]) - 1
		given -= 1
	while given < n:  # too few: give to whichever is furthest below its share
		var needy: String = kinds[0]
		for id: String in kinds:
			if float(inside[id]) / maxf(float(want[id]), 1.0) > float(inside[needy]) / maxf(float(want[needy]), 1.0):
				needy = id
		want[needy] = int(want[needy]) + 1
		given += 1
	# Dealt out one of each in turn, so kinds are mixed through the list.
	while out.size() < n:
		var dealt := false
		for id: String in kinds:
			if int(want[id]) > 0 and out.size() < n:
				out.append(id)
				want[id] = int(want[id]) - 1
				dealt = true
		if not dealt:
			break
	return out


func _show_residents(inside: Dictionary, total: int, capacity: int) -> void:
	for a in residents:
		a.queue_free()
	residents.clear()
	var n := shown_count(total, capacity, _spots.size(), distinct_kinds(inside))
	var picks := pick_kinds(inside, n)
	for k in picks.size():
		var it := Game.item_data(picks[k])
		if it.is_empty():
			continue
		var mind := AnimalBehaviour.new(AnimalRig.of(it), uid * 131 + k * 17,
			Vector2(WANDER * FarmGrid.TILE_W / 2.0, WANDER * FarmGrid.TILE_H / 2.0))
		var a := Animal3D.create(it, mind, _spots[k])
		add_child(a)
		a.update(0.0)
		residents.append(a)


## The trees or blooms living in an Orchard or Bloom Garden, packed in a grid from the middle out: more as it
## fills, each different kind inside shown (up to MAX_KINDS), fruiting or open when ready.
func _show_plants(o: Dictionary, slots: int) -> void:
	if _plants != null:
		_plants.queue_free()
	var holder := Node3D.new()
	var inside: Dictionary = o.get("inside", {})
	var ready := Game.is_ready(o)
	var first := ""
	for id: String in inside:
		if int(inside[id]) > 0:
			first = id
			break
	var trees := first == "" or Game.kind_of({"id": first}) == "tree"
	# A grid in the field's own proportions; trees are packed tight, crowns just touching (FarmVille's orchards).
	var per_row := maxi(ceili(sqrt(slots * _fp.x / maxf(_fp.y, 1.0))), 1)
	var rows := ceili(float(slots) / per_row)
	var gap := minf(_fp.x * 0.8 / maxf(per_row - 1.0, 1.0), _fp.y * 0.8 / maxf(rows - 1.0, 1.0))
	var size := clampf(gap * TREE_FILL, 0.4, 1.0)
	if not trees:
		# Blooms grow in soil beds, one a row.
		for r in rows:
			var bz := _fp.y * (0.15 + 0.7 * r / maxf(rows - 1.0, 1.0)) if rows > 1 else _fp.y * 0.5
			ModelKit.box(holder, Vector3(_fp.x * 0.12, 0, bz - 0.22), Vector3(_fp.x * 0.88, 0.05, bz + 0.22),
				ModelKit.paint(Color("#6b4a2b")))
	var total := Game.inside_total(o)
	# Every tree and bloom inside is there to see (FarmVille's orchards and gardens).
	var shown := mini(slots, total)
	var ids := pick_kinds(inside, shown, 99)  # a garden shows every different kind in it
	# Which grid places, middle first: a young orchard is a clump in the middle, not a corner.
	var places: Array[Vector2i] = []
	for k in per_row * rows:
		places.append(Vector2i(k % per_row, int(k / float(per_row))))
	var mid := Vector2((per_row - 1) / 2.0, (rows - 1) / 2.0)
	places.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_to(mid) < Vector2(b).distance_to(mid))
	for k in ids.size():
		var z := _fp.y * (0.15 + 0.7 * places[k].y / maxf(rows - 1.0, 1.0)) if rows > 1 else _fp.y * 0.5
		var x := _fp.x * (0.1 + 0.8 * places[k].x / maxf(per_row - 1.0, 1.0))
		var it := Game.item_data(ids[k])
		if str(it.get("kind", "")) == "bloom":
			var d := Game.catalog.get_def(ids[k]) as BloomDef
			BloomModel.build_at(holder, Vector3(x, 0.05, z), it, BLOOM_SIZE * ScaleGuide.factor(ids[k]), ready, false,
				d.is_full(), uid + k)
		else:
			TreeModel.build_at(holder, Vector3(x, 0, z), it, size * ScaleGuide.factor(ids[k]), ready, uid + k)
	_plants = ModelKit.bake(holder)
	add_child(_plants)


## Whatever a Garage, shed or barn keeps (BuildingStock), rebuilt only when it changes.
func _show_stock(kind: String, at: Array, o: Dictionary) -> void:
	var sig := BuildingStock.signature(kind, o)
	if sig == _stock_sig and _stock != null:
		return
	_stock_sig = sig
	if _stock != null:
		_stock.queue_free()
	_stock = BuildingStock.build(kind, o, _fp, at)
	add_child(_stock)


# ---------------------------------------------------------------- produce


func _show_produce(kind: String, step: int, at: Array, o: Dictionary) -> void:
	if _produce != null:
		_produce.queue_free()
		_produce = null
	if kind == "" or step <= 0:
		return
	var root := Node3D.new()
	var p := Vector3(float(at[0]) * _fp.x, 0, float(at[1]) * _fp.y)
	var n := step
	match kind:
		"eggs":
			_basket(root, p, Color("#f6ecd2"), n * 2, 0.022, Vector3(1, 1.3, 1))
		"crates":
			# Crates of fruit stacking up by the gate.
			for k in mini(n, 4):
				var c := p + Vector3((k % 2) * 0.14 - 0.07, int(k / 2.0) * 0.09, 0)
				ModelKit.box(root, c + Vector3(-0.06, 0, -0.05), c + Vector3(0.06, 0.08, 0.05),
					ModelKit.surface(BuildingModel.WOOD, "boards", 0.2))
				ModelKit.ball(root, c + Vector3(0, 0.08, 0), 0.05, ModelKit.paint(Color("#d93b30")), Vector3(1, 0.35, 0.8))
		"baskets":
			# Baskets of cut flowers.
			for k in mini(n, 3):
				var c := p + Vector3(k * 0.13 - 0.13, 0, (k % 2) * 0.04)
				ModelKit.cylinder(root, c, 0.05, 0.06, ModelKit.paint(Color("#b8894f")), 0.06, 10)
				for f in 4:
					var fa := TAU * f / 4.0
					ModelKit.ball(root, c + Vector3(cos(fa) * 0.025, 0.075, sin(fa) * 0.025), 0.022,
						ModelKit.paint([Color("#d6304a"), Color("#f5c518"), Color("#f7b5c8")][(k + f) % 3]))
		"truffles":
			_basket(root, p, Color("#4a3426"), n * 2, 0.02, Vector3(1, 0.85, 1))
		"milk":
			for k in mini(n, 4):
				var c := p + Vector3(k * 0.1 - 0.15, 0, (k % 2) * 0.05)
				ModelKit.cylinder(root, c, 0.04, 0.13, ModelKit.paint(Color("#c9ced2"), 0.6), 0.03, 10)
				ModelKit.cylinder(root, c + Vector3(0, 0.13, 0), 0.022, 0.03, ModelKit.paint(Color("#9aa2a8"), 0.6), -1.0, 8)
		"wool":
			for k in n:
				var c := p + Vector3((k % 3) * 0.1 - 0.1, int(k / 3.0) * 0.07, int(k / 3.0) * 0.03)
				ModelKit.ball(root, c + Vector3(0, 0.04, 0), 0.05, ModelKit.paint(Color("#f4f1ea")), Vector3(1.2, 0.8, 1))
		"honey":
			var shelf := ModelKit.paint(BuildingModel.WOOD)
			ModelKit.box(root, p + Vector3(-0.18, 0.08, -0.05), p + Vector3(0.18, 0.1, 0.05), shelf)
			for x: float in [-0.15, 0.15]:
				ModelKit.box(root, p + Vector3(x - 0.015, 0, -0.04), p + Vector3(x + 0.015, 0.08, 0.04), shelf)
			for k in mini(n, 5):
				var c := p + Vector3(-0.13 + k * 0.065, 0.1, 0)
				ModelKit.cylinder(root, c, 0.022, 0.05, ModelKit.paint(Color("#e8a822"), 0.7), -1.0, 8)
				ModelKit.cylinder(root, c + Vector3(0, 0.05, 0), 0.024, 0.012, ModelKit.paint(Color("#f1ece0")), -1.0, 8)
		"hay":
			for k in mini(n, 4):
				var c := p + Vector3((k % 2) * 0.2 - 0.1, int(k / 2.0) * 0.12, 0)
				ModelKit.box(root, c + Vector3(-0.09, 0, -0.07), c + Vector3(0.09, 0.12, 0.07), ModelKit.paint(BuildingModel.HAY))
		_:
			# Crates of whatever it makes, stacked, in the colour of who makes it.
			var inside: Dictionary = o.get("inside", {})
			var first := str(inside.keys().front()) if not inside.is_empty() else ""
			var col := Color.html(str(Game.item_data(first).get("color", "#c0392b")))
			for k in mini(n, 4):
				var c := p + Vector3((k % 2) * 0.17 - 0.08, int(k / 2.0) * 0.1, 0)
				ModelKit.box(root, c + Vector3(-0.075, 0, -0.06), c + Vector3(0.075, 0.1, 0.06),
					ModelKit.surface(Color("#b07a4c"), "boards", 0.2))
				ModelKit.ball(root, c + Vector3(0, 0.1, 0), 0.05, ModelKit.paint(col, 0.3), Vector3(1.3, 0.5, 1))
	_produce = ModelKit.bake(root)
	_produce.scale = Vector3.ONE * PRODUCE_SCALE
	_produce.position = p * (1.0 - PRODUCE_SCALE)
	add_child(_produce)


## A wicker basket heaped with `count` round things.
static func _basket(root: Node3D, p: Vector3, col: Color, count: int, r: float, shape: Vector3) -> void:
	ModelKit.cylinder(root, p, 0.08, 0.06, ModelKit.surface(Color("#b8894e"), "logs", 0.0), 0.095, 12)
	var rng := RandomNumberGenerator.new()
	rng.seed = count
	for k in count:
		var a := k * 2.4
		var ring := 0.05 * sqrt(float(k % 6) / 6.0)
		var c := p + Vector3(cos(a) * ring, 0.06 + r + int(k / 6.0) * r * 1.4, sin(a) * ring)
		ModelKit.ball(root, c, r * rng.randf_range(0.9, 1.1), ModelKit.paint(col.darkened(rng.randf_range(0.0, 0.1)), 0.3),
			shape)


## A pennant on a pole at the yard's front corner while the building is full (FarmVille's "full" had to be
## read from the numbers; here it's on the building).
func _show_flag(full: bool) -> void:
	if (_flag != null) == full:
		return
	if _flag != null:
		_flag.queue_free()
		_flag = null
		return
	var root := Node3D.new()
	var at := Vector3(_fp.x - 0.14, 0, _fp.y - 0.14)
	ModelKit.box(root, at - Vector3(0.012, 0, 0.012), at + Vector3(0.012, 0.62, 0.012), ModelKit.paint(Color("#4a4a4a")))
	# The pennant streams out from the pole and flutters in the wind (swung by the GPU, like a weathervane).
	var pennant := Node3D.new()
	ModelKit.box(pennant, Vector3(-0.006, -0.17, -0.3), Vector3(0.006, 0.0, 0.0), ModelKit.paint(FULL_FLAG))
	DecorMotion.orbit(root, at + Vector3(0, 0.62, 0), pennant, DecorMotion.FLUTTER)
	_flag = ModelKit.bake(root)
	add_child(_flag)


# ---------------------------------------------------------------- moving


func _process(delta: float) -> void:
	if residents.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	# Out of sight, the yard's minds think a few times a second, not every frame (nobody sees it).
	var seen := cam == null or _yard_in_view(cam)
	_idle += delta
	if not seen:
		if (Engine.get_process_frames() + get_instance_id()) % OFFSCREEN_STRIDE != 0:
			return
		for a in residents:
			a.behaviour.update(_idle)
		_idle = 0.0
		return
	for a in residents:
		a.behaviour.update(_idle)
		a.animate(_idle, cam)
	_idle = 0.0


## Whether any part of the yard (its middle or a corner) is in the camera's view.
func _yard_in_view(cam: Camera3D) -> bool:
	for u in [Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		if cam.is_position_in_frustum(global_position + Vector3(u.x * _fp.x, 0.4, u.y * _fp.y)):
			return true
	return false


## Collected: the doors swing open (or the shutter rolls up) and close again, the produce springs off,
## and everyone out in the yard looks up.
func celebrate() -> void:
	for hinge in _doors:
		var swing := float(hinge.get_meta(BuildingModel.DOOR))
		var tw := hinge.create_tween()
		if hinge.has_meta("slide"):
			var up := float(hinge.get_meta("slide"))
			tw.tween_property(hinge, "position:y", hinge.position.y + up, 0.3).set_trans(Tween.TRANS_QUAD) \
				.set_ease(Tween.EASE_OUT)
			tw.tween_interval(DOOR_HOLD)
			tw.tween_property(hinge, "position:y", hinge.position.y, 0.4).set_trans(Tween.TRANS_BOUNCE) \
				.set_ease(Tween.EASE_OUT)
		else:
			tw.tween_property(hinge, "rotation:y", swing * DOOR_OPEN, 0.32).set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT)
			tw.tween_interval(DOOR_HOLD)
			tw.tween_property(hinge, "rotation:y", 0.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if _produce != null:
		var pile := _produce
		_produce = null
		var tw := pile.create_tween().set_parallel(true)
		tw.tween_property(pile, "position:y", 0.5, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(pile, "scale", Vector3.ONE * 0.05, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(pile.queue_free)
	for a in residents:
		a.behaviour.poke()
	_stage = ""  # the pile is redrawn from the building as it is after collecting


## Whether any door is open right now (tests).
func doors_open() -> bool:
	for hinge in _doors:
		if absf(hinge.rotation.y) > 0.3:
			return true
		if hinge.has_meta("slide") and hinge.position.y > float(hinge.get_meta("rest_y", 0.0)) + 0.05:
			return true
	return false
