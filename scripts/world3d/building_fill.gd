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
const LOD_MID_PPU := 64.0     # screen pixels per world unit below which only half the yard's animals are drawn
const LOD_FAR_PPU := 40.0     # ...and below which only a few are (a cow is then a speck)
const LOD_FAR_SHOWN := 3
const LOD_MARGIN := 1.12      # hysteresis: zooming back in must pass the line by this much
const SHOWN_FIRST := 3        # the most animals out in the yard of a building's first size...
const SHOWN_BIGGEST := 8      # ...and of its biggest, in between by size (fewer if they do not fit the yard)
const BODY_REACH := 0.65      # an animal's ground space: radius against its body length (heads and tails overhang)
const MAX_KINDS := 5          # the most different kinds a home shows (FarmVille showed up to five)
const CROWD_FULL_DETAIL := 6.0   # members in one orchard or garden built at full detail; more share that budget
const WANDER := 0.1           # tiles a resident strays from its place
const DOOR_OPEN := 1.75       # radians a door swings open
const DOOR_HOLD := 1.2        # seconds it stays open
const PRODUCE_STEPS := 6      # piles grow in this many steps as collection nears
const PRODUCE_SCALE := 1.5    # and are drawn this much bigger than life: they must read from across the farm
const PEEKERS := 3            # the most animals looking out of windows at once (when the home is full)
const PEEK_OUT := 0.1         # tiles a head sticks out past the wall
const PEEK_POP := 0.45        # seconds a head takes to pop up
const PEEK_NOD := 2.6         # seconds a head takes to nod once and back
const FULL_FLAG := Color("#d8402f")   # the pennant a full home flies
const PLANT_KINDS := ["tree", "bloom"]   # what grows in a garden-like building (shown by _show_plants)
const TREE_VARIANTS := 3          # different trees built of each kind in an orchard; the rest are shared copies of them
const TREE_TURN := TAU            # each copy is turned at random...
const TREE_SIZE_JITTER := 0.08    # ...and made this much bigger or smaller, so copies do not look alike
const TREE_FILL := 0.95           # an orchard tree's size against the space between trees (crowns touch, trunks show)
const TREE_CROWN := 0.3           # the crown radius an orchard tree is sized for; wider crowned kinds are drawn smaller
const BLOOM_SIZE := 1.5           # a bloom in a Bloom Garden, against one on its own tile (1.6)

var uid := -1
static var _tree_cache := {}   # built orchard trees, by kind, size and detail (see _tree_variants)
var residents: Array[Animal3D] = []

var _id := ""
var _fp := Vector2i.ONE
var _spec := {}
var _who := ""                # who's inside, as last shown
var _who_peeking := ""
var _stage := ""              # how near ready, as last shown
var _produce: Node3D
var _peekers: Node3D           # heads looking out of the windows while the home is full
var _windows: Array = []
var _flag: Node3D             # flown while the building is full
var _lod := -1                # 0 all, 1 half, 2 a few: how much of the yard is drawn at this zoom (-1: not set yet)
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
	for c in model.get_children():
		if c.has_meta(BuildingModel.WINDOWS):
			f._windows = c.get_meta(BuildingModel.WINDOWS)
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
		or BuildingModel.fill_of(str(o["id"]), Game.level_of(o)).has("stock"))


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
		_show_residents(o)
	if stage != _stage:
		_show_produce(str(fill.get("produce", "")), step, fill.get("at", [0.78, 0.9]), o)
	_who = who
	_stage = stage
	var full := Game.capacity(o) > 0 and Game.inside_total(o) >= Game.capacity(o) and not fill.has("plants")
	_show_flag(full)
	if who != _who_peeking:
		_who_peeking = who
		_show_peekers(inside if full else {})


## How near the building is to ready, 0..1 (0 when empty: nothing is being made).
static func ready_share(o: Dictionary) -> float:
	if Game.inside_total(o) == 0:
		return 0.0
	return clampf(1.0 - float(Game.seconds_until_ready(o)) / maxf(Game.cycle_of(o), 1.0), 0.0, 1.0)


## The most animals a building shows out in its yard at its size.
static func shown_cap(level: int, max_level: int) -> int:
	var along := float(level - 1) / maxf(max_level - 1, 1.0)
	return int(round(lerpf(SHOWN_FIRST, SHOWN_BIGGEST, clampf(along, 0.0, 1.0))))


## `n` of what's inside, the rarest first (a higher unlock level, then a dearer price, is a rarer animal). Kinds
## as rare as each other take turns, so a yard shows a mix and not all of one.
static func rarest(inside: Dictionary, n: int) -> Array[String]:
	var kinds: Array = inside.keys().filter(func(id: String) -> bool: return int(inside[id]) > 0)
	kinds.sort_custom(func(a: String, b: String) -> bool:
		var ia := Game.item_data(a)
		var ib := Game.item_data(b)
		var la := int(ia.get("unlock_level", 1))
		var lb := int(ib.get("unlock_level", 1))
		if la != lb:
			return la > lb
		var ca := int(ia.get("cost", 0))
		var cb := int(ib.get("cost", 0))
		return ca > cb or ca == cb and a < b)
	var out: Array[String] = []
	var i := 0
	while i < kinds.size() and out.size() < n:
		var tier := int(Game.item_data(kinds[i]).get("unlock_level", 1))
		var same: Array = []
		while i < kinds.size() and int(Game.item_data(kinds[i]).get("unlock_level", 1)) == tier:
			same.append(kinds[i])
			i += 1
		var round_no := 0
		while out.size() < n:
			var gave := false
			for id: String in same:
				if int(inside[id]) > round_no and out.size() < n:
					out.append(id)
					gave = true
			if not gave:
				break
			round_no += 1
	return out


## How far an animal of this kind reaches from where it stands, in tiles, at full size, as far as the fence
## and walls are concerned.
static func radius_of(it: Dictionary) -> float:
	var rig := AnimalRig.of(it)
	var body: Array = rig.values.get("body", [20, 10])
	return float(body[0]) * BODY_REACH * rig.scale * Animal3D.PX + WANDER


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


## The same list with each kind together (in the order each first appears), so a grid reads as rows of one tree.
static func grouped(ids: Array[String]) -> Array[String]:
	var order: Array[String] = []
	for id in ids:
		if not order.has(id):
			order.append(id)
	var out: Array[String] = []
	for id in order:
		for other in ids:
			if other == id:
				out.append(id)
	return out


func _show_residents(o: Dictionary) -> void:
	for a in residents:
		a.queue_free()
	residents.clear()
	var picks := rarest(o.get("inside", {}), shown_cap(Game.level_of(o), Game.max_level(_id)))
	_lod = -1  # (the new animals are shown or hidden for the zoom next frame)
	var radii: Array[float] = []
	for id in picks:
		radii.append(radius_of(Game.item_data(id)))
	var fit := SpaceFit.pack(SpaceFit.yard_room(_fp), BuildingModel.taken(_spec, _fp), radii, uid)
	var spots: Array = fit["spots"]
	for k in spots.size():
		var it := Game.item_data(picks[k])
		if it.is_empty():
			continue
		var mind := AnimalBehaviour.new(AnimalRig.of(it), uid * 131 + k * 17,
			Vector2(WANDER * FarmGrid.TILE_W / 2.0, WANDER * FarmGrid.TILE_H / 2.0))
		var at := spots[k] as Vector2
		var a := Animal3D.create(it, mind, Vector3(at.x, 0.0, at.y), float(fit["size"]))
		add_child(a)
		a.update(0.0)
		residents.append(a)


## A full home has animals looking out of its windows (FarmVille's did): a head in up to PEEKERS windows,
## of the commonest kinds inside, popping up and nodding now and then. Nothing when it is not full.
func _show_peekers(inside: Dictionary) -> void:
	if _peekers != null:
		_peekers.queue_free()
		_peekers = null
	if inside.is_empty() or _windows.is_empty():
		return
	var picks := pick_kinds(inside, mini(PEEKERS, _windows.size()), PEEKERS)
	var holder := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = uid
	var order := range(_windows.size())
	for k in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t: int = order[k]
		order[k] = order[j]
		order[j] = t
	for k in picks.size():
		var it := Game.item_data(picks[k])
		if it.is_empty():
			continue
		var w: Dictionary = _windows[order[k]]
		var head := _head(Color.html(str(it.get("color", "#ffffff"))), float(w["size"]))
		head.position = w["at"] as Vector3
		head.scale = Vector3.ZERO
		holder.add_child(head)
		var tween := head.create_tween()
		tween.tween_interval(rng.randf_range(0.0, 1.5))
		tween.tween_property(head, "scale", Vector3.ONE, PEEK_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var nod := head.create_tween().set_loops()
		nod.tween_interval(rng.randf_range(0.5, 2.0))
		nod.tween_property(head, "rotation:x", 0.12, PEEK_NOD / 2.0).set_trans(Tween.TRANS_SINE)
		nod.tween_property(head, "rotation:x", -0.12, PEEK_NOD / 2.0).set_trans(Tween.TRANS_SINE)
	_peekers = holder
	add_child(_peekers)


## A head filling a window of size `size`, in `col`: a square head, a snout, ears and two eyes, facing +x.
static func _head(col: Color, size: float) -> Node3D:
	var root := Node3D.new()
	var s := size * 0.46
	var coat := ModelKit.paint(col)
	ModelKit.box(root, Vector3(0, -s, -s), Vector3(PEEK_OUT + s * 0.5, s, s), coat)
	ModelKit.box(root, Vector3(PEEK_OUT, -s * 0.55, -s * 0.5), Vector3(PEEK_OUT + s * 0.9, s * 0.15, s * 0.5),
		ModelKit.paint(col.lightened(0.3)))
	for side: float in [-1.0, 1.0]:
		ModelKit.box(root, Vector3(0.0, s * 0.9, side * s * 0.95 - s * 0.2),
			Vector3(s * 0.4, s * 1.7, side * s * 0.95 + s * 0.2), ModelKit.paint(col.darkened(0.15)))
		ModelKit.box(root, Vector3(PEEK_OUT + s * 0.5, s * 0.3, side * s * 0.5 - s * 0.12),
			Vector3(PEEK_OUT + s * 0.6, s * 0.55, side * s * 0.5 + s * 0.12), ModelKit.paint(Color("#1c1c1c")))
	return ModelKit.bake(root)


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
	# A grid in the field's own proportions, inside its tile's border with each crown kept in; trees are packed
	# tight, crowns just touching (FarmVille's orchards).
	var room := SpaceFit.tile_room(_fp)
	var per_row := maxi(ceili(sqrt(slots * _fp.x / maxf(_fp.y, 1.0))), 1)
	var rows := ceili(float(slots) / per_row)
	var span := room.grow(-TREE_CROWN * 1.1).abs()
	var gap := minf(span.size.x / maxf(per_row - 1.0, 1.0), span.size.y / maxf(rows - 1.0, 1.0))
	var size := clampf(gap * TREE_FILL, 0.55, 1.0)
	if not trees:
		# Blooms grow in soil beds, one a row.
		for r in rows:
			var bz := span.position.y + span.size.y * r / maxf(rows - 1.0, 1.0) if rows > 1 else room.get_center().y
			ModelKit.box(holder, Vector3(room.position.x, 0, bz - 0.22), Vector3(room.end.x, 0.05, bz + 0.22),
				ModelKit.paint(Color("#6b4a2b")))
	var total := Game.inside_total(o)
	# Every tree and bloom inside is there to see (FarmVille's orchards and gardens).
	var shown := mini(slots, total)
	var ids := grouped(pick_kinds(inside, shown, 99))  # a garden shows every different kind in it
	# Row by row, each kind together in straight lines, as FarmVille's orchards had them.
	var places: Array[Vector2i] = []
	for k in per_row * rows:
		places.append(Vector2i(k % per_row, int(k / float(per_row))))
	# Dozens of the same model: each gets less detail, so a full orchard costs about what a few trees do.
	ModelKit.detail = clampf(sqrt(CROWD_FULL_DETAIL / maxf(ids.size(), 1.0)), ModelKit.MIN_DETAIL, 1.0)
	var stand := {}   # trees to stand: id -> {size, at: [where]}
	for k in ids.size():
		var z := span.position.y + span.size.y * places[k].y / maxf(rows - 1.0, 1.0) if rows > 1 \
			else room.get_center().y
		var x := span.position.x + span.size.x * places[k].x / maxf(per_row - 1.0, 1.0) if per_row > 1 \
			else room.get_center().x
		var it := Game.item_data(ids[k])
		if str(it.get("kind", "")) == "bloom":
			var d := Game.catalog.get_def(ids[k]) as BloomDef
			BloomModel.build_at(holder, Vector3(x, 0.05, z), it, BLOOM_SIZE * ScaleGuide.factor(ids[k]), ready, false,
				d.is_full(), uid + k)
		else:
			var fit := clampf(TREE_CROWN / float(TreeModel.shape_of(it).get("crown_r", TREE_CROWN)), 0.7, 1.1)
			var grown := size * fit * minf(ScaleGuide.factor(ids[k]), 1.0)
			if not stand.has(ids[k]):
				stand[ids[k]] = {"size": grown, "at": []}
			(stand[ids[k]]["at"] as Array).append(Vector3(x, 0, z))
	_plant_trees(holder, stand, ready)
	ModelKit.detail = 1.0
	_plants = ModelKit.bake(holder) if holder.get_child_count() > 0 and stand.is_empty() else holder
	add_child(_plants)


## Stands the trees of an orchard: a few different trees of each kind (TREE_VARIANTS) are built, once, and kept;
## every tree standing is a copy of one of them, turned and sized a little differently, drawn as one batch per
## variant. A full orchard is built in a few milliseconds, not a hundred, and rebuilding it costs nothing.
func _plant_trees(holder: Node3D, stand: Dictionary, ready: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = uid
	for id: String in stand:
		var size: float = stand[id]["size"]
		var spots: Array = stand[id]["at"]
		var variants := _tree_variants(id, size, ready)
		for v in variants.size():
			var here: Array = []
			for k in range(v, spots.size(), variants.size()):
				here.append(spots[k])
			if here.is_empty():
				continue
			for part: Dictionary in variants[v]:
				var multi := MultiMesh.new()
				multi.transform_format = MultiMesh.TRANSFORM_3D
				multi.mesh = part["mesh"]
				multi.instance_count = here.size()
				for k in here.size():
					var scale := 1.0 + rng.randf_range(-TREE_SIZE_JITTER, TREE_SIZE_JITTER)
					var basis := Basis(Vector3.UP, rng.randf() * TREE_TURN).scaled(Vector3.ONE * scale)
					multi.set_instance_transform(k, Transform3D(basis, here[k]))
				var node := MultiMeshInstance3D.new()
				node.multimesh = multi
				node.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if part["shadow"]
					else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				holder.add_child(node)


## The trees built for a kind at a size, as lists of parts ({mesh, shadow}); built once, then reused.
static func _tree_variants(id: String, size: float, ready: bool) -> Array:
	var key := "%s|%s|%.2f|%.2f" % [id, ready, size, ModelKit.detail]
	if _tree_cache.has(key):
		return _tree_cache[key]
	var out: Array = []
	for v in TREE_VARIANTS:
		var holder := Node3D.new()
		TreeModel.build_at(holder, Vector3.ZERO, Game.item_data(id), size, ready, v * 977 + 1)
		var baked := ModelKit.bake(holder)
		var parts: Array = []
		for mi in baked.get_children():
			if mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null:
				var mesh := (mi as MeshInstance3D).mesh
				for k in mesh.get_surface_count():
					mesh.surface_set_material(k, (mi as MeshInstance3D).get_surface_override_material(k))
				parts.append({"mesh": mesh, "shadow": (mi as MeshInstance3D).cast_shadow
					!= GeometryInstance3D.SHADOW_CASTING_SETTING_OFF})
		baked.free()
		out.append(parts)
	if _tree_cache.size() > 64:
		_tree_cache.clear()
	_tree_cache[key] = out
	return out


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
	if kind == "vehicles":
		_open_shutter(not (o.get("inside", {}) as Dictionary).is_empty())


## A Garage with vehicles in it keeps its shutter rolled up, so they show; an empty one is shut.
func _open_shutter(open: bool) -> void:
	for hinge in _doors:
		if not hinge.has_meta("slide"):
			continue
		if not hinge.has_meta("rest_y"):
			hinge.set_meta("rest_y", hinge.position.y)
		var y := float(hinge.get_meta("rest_y")) + (float(hinge.get_meta("slide")) if open else 0.0)
		if not is_inside_tree() or not is_visible_in_tree():
			hinge.position.y = y                         # not on screen yet: just be there
			continue
		var tw := create_tween()                          # owned by this node, so it ends with it
		tw.tween_property(hinge, "position:y", y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
	if seen and cam != null:
		_set_lod(cam)
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
		if a.visible:
			a.animate(_idle, cam)
	_idle = 0.0


## Zoomed out, a yard's animals are specks and a full home would cost hundreds of draws: draw half of them,
## then only a few (the rest are hidden, not removed, so zooming in brings them back where they were).
func _set_lod(cam: Camera3D) -> void:
	var ppu := get_viewport().get_visible_rect().size.y / maxf(cam.size, 0.001)
	var tier := _lod
	if tier == -1:
		tier = 2 if ppu < LOD_FAR_PPU else (1 if ppu < LOD_MID_PPU else 0)
	else:
		# Going coarser at the line; going finer only once well past it.
		if ppu < LOD_FAR_PPU:
			tier = 2
		elif ppu < LOD_MID_PPU:
			tier = 1 if tier != 2 or ppu > LOD_FAR_PPU * LOD_MARGIN else 2
		else:
			tier = 0 if tier == 0 or ppu > LOD_MID_PPU * LOD_MARGIN else 1
	if tier == _lod:
		return
	_lod = tier
	var shown := residents.size()
	if tier == 1:
		shown = int(ceil(residents.size() / 2.0))
	elif tier == 2:
		shown = mini(residents.size(), LOD_FAR_SHOWN)
	for k in residents.size():
		residents[k].visible = k < shown


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
