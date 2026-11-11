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

const RESIDENTS := 6          # the most animals out in a yard at once (a full building)
const SPOT_GAP := 0.4         # tiles between places an animal can stand
const EDGE := 0.28            # and how far those keep from the footprint's edge (inside the fence)
const KEEP_CLEAR := 0.16      # and from walls and the like
const WANDER := 0.1           # tiles a resident strays from its place
const DOOR_OPEN := 1.75       # radians a door swings open
const DOOR_HOLD := 1.2        # seconds it stays open
const PRODUCE_STEPS := 6      # piles grow in this many steps as collection nears

var uid := -1
var residents: Array[Animal3D] = []

var _id := ""
var _fp := Vector2i.ONE
var _spec := {}
var _spots: Array[Vector3] = []
var _who := ""                # who's inside, as last shown
var _stage := ""              # how near ready, as last shown
var _produce: Node3D
const PLANT_KINDS := ["tree", "bloom"]   # what grows in a garden-like building (shown by _show_plants)
const TREE_FILL := 1.3            # an orchard tree's size, against the space between trees (crowns touch)
const BLOOM_SIZE := 1.5           # a bloom in a Bloom Garden, against one on its own tile (1.6)
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
	return def is BuildingDef and (not (def as BuildingDef).holds().is_empty()
		or str((def as BuildingDef).data.get("holds_kind", "")) in PLANT_KINDS)


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
	if fill.has("plants"):
		if who != _who or stage != _stage:
			_show_plants(o, int(fill["plants"]))  # trees fruit, blooms open, when ready
	elif who != _who:
		_show_residents(inside, Game.inside_total(o), Game.capacity(o))
	if stage != _stage:
		_show_produce(str(fill.get("produce", "")), step, fill.get("at", [0.78, 0.9]), o)
	_who = who
	_stage = stage


## How near the building is to ready, 0..1 (0 when empty: nothing is being made).
static func ready_share(o: Dictionary) -> float:
	if Game.inside_total(o) == 0:
		return 0.0
	return clampf(1.0 - float(Game.seconds_until_ready(o)) / maxf(Game.cycle_of(o), 1.0), 0.0, 1.0)


## How many animals to show out in the yard: none when empty, one for the first, then in proportion to
## how full it is, up to RESIDENTS (and never more than there are places, or animals).
static func shown_count(inside_total: int, capacity: int, spots: int) -> int:
	if inside_total <= 0:
		return 0
	var share := float(inside_total) / maxf(capacity, 1.0)
	return mini(mini(maxi(1, int(ceil(share * RESIDENTS))), spots), inside_total)


func _show_residents(inside: Dictionary, total: int, capacity: int) -> void:
	for a in residents:
		a.queue_free()
	residents.clear()
	var n := shown_count(total, capacity, _spots.size())
	# Which kinds: in proportion to how many of each are inside, the commonest first.
	var kinds := inside.keys().filter(func(id: String) -> bool: return int(inside[id]) > 0)
	kinds.sort_custom(func(a: String, b: String) -> bool: return int(inside[a]) > int(inside[b]))
	var picks: Array[String] = []
	for id: String in kinds:
		var share := int(round(float(inside[id]) / maxf(total, 1.0) * n))
		for k in maxi(share, 1 if picks.size() < n else 0):
			if picks.size() < n:
				picks.append(id)
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


## The trees or blooms living in an Orchard or Bloom Garden, in rows of three, fruiting or open when ready.
func _show_plants(o: Dictionary, slots: int) -> void:
	if _plants != null:
		_plants.queue_free()
	var holder := Node3D.new()
	var inside: Dictionary = o.get("inside", {})
	var ids: Array[String] = []
	for id: String in inside:
		for k in int(inside[id]):
			ids.append(id)
	var ready := Game.is_ready(o)
	var trees := ids.is_empty() or Game.kind_of({"id": ids[0]}) == "tree"
	# A grid in the field's own proportions; trees are packed tight, crowns just touching (FarmVille's orchards).
	var per_row := maxi(ceili(sqrt(slots * _fp.x / maxf(_fp.y, 1.0))), 1) if trees else 5
	var rows := ceili(float(slots) / per_row)
	var gap := minf(_fp.x * 0.8 / maxf(per_row - 1.0, 1.0), _fp.y * 0.8 / maxf(rows - 1.0, 1.0))
	var size := clampf(gap * TREE_FILL, 0.4, 1.0)
	if not trees:
		# Blooms grow in soil beds, one a row.
		for r in rows:
			var bz := _fp.y * (0.15 + 0.7 * r / maxf(rows - 1.0, 1.0)) if rows > 1 else _fp.y * 0.5
			ModelKit.box(holder, Vector3(_fp.x * 0.12, 0, bz - 0.22), Vector3(_fp.x * 0.88, 0.05, bz + 0.22),
				ModelKit.paint(Color("#6b4a2b")))
	for k in mini(ids.size(), slots):
		var row := int(k / float(per_row))
		var z := _fp.y * (0.15 + 0.7 * row / maxf(rows - 1.0, 1.0)) if rows > 1 else _fp.y * 0.5
		var x := _fp.x * (0.1 + 0.8 * (k % per_row) / maxf(per_row - 1.0, 1.0))
		var it := Game.item_data(ids[k])
		if str(it.get("kind", "")) == "bloom":
			var d := Game.catalog.get_def(ids[k]) as BloomDef
			BloomModel.build_at(holder, Vector3(x, 0.05, z), it, BLOOM_SIZE, ready, false, d.is_full(), uid + k)
		else:
			TreeModel.build_at(holder, Vector3(x, 0, z), it, size, ready, uid + k)
	_plants = ModelKit.bake(holder)
	add_child(_plants)


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


# ---------------------------------------------------------------- moving


func _process(delta: float) -> void:
	if residents.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	for a in residents:
		a.behaviour.update(delta)
		a.animate(delta, cam)


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
