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

const COMPANY_TURN := -0.6   # how a vehicle of a store's company is turned where it stands, in radians
const SWIM_WITHIN := 0.9     # an animal this far out from a pond's middle (1: its shore) or less is on the water
const WAKE_EVERY := 0.35     # seconds between the looks at who leaves a ring on the water (each in its turn)..
const WAKE_TURNS := 3        # ..one swimmer in this many at each look
const WAKE := Vector3(0.12, 0.4, 1.5)   # a swimmer's ring: tiles across at first and at last, and the seconds it lasts
const DRINK_NEAR := 0.7      # an animal standing this near a water trough (tiles) goes to it to drink
const DRINK_SHORT := 0.2     # ..and stops this far short of its middle
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
const FILE_REACH := 0.3      # an animal made as a file: radius against its whole length (nose to tail)
const WANDER := 0.1           # tiles a resident strays from its place
const DOOR_OPEN := 1.75       # radians a door swings open
const DOOR_HOLD := 1.2        # seconds it stays open
const PRODUCE_STEPS := 6      # piles grow in this many steps as collection nears
const PRODUCE_SCALE := 1.5    # and are drawn this much bigger than life: they must read from across the farm
const PEEKERS := 4            # the most animals looking out of a home's windows at once
const PEEK_OUT := 0.1         # tiles a head sticks out past the wall
const PEEK_POP := 0.45        # seconds a head takes to pop up
const PEEK_NOD := 2.6         # seconds a head takes to nod once and back
const ANIMAL_SMALLEST := 0.85 # animals in a yard are drawn hardly smaller to fit more (SpaceFit.pack): fewer instead
const PEEK_FILL := 1.1        # the most of a window a file-made animal's head may fill (bigger: none looks out)..
const PEEK_LEAST := 0.6       # ..and the least of its own size it is drawn at to fit (smaller: none looks out)
const PEEK_SNOUT := 0.1       # ..its nose this share of the window past PEEK_OUT
const HEAD_SHARE := 0.3       # an animal's head: the front share of its length..
const HEAD_ABOVE := 0.45      # ..above this share of its height
const BIRD_HEAD_SHARE := 0.45  # a bird's head: the front share of its length..
const BIRD_HEAD_ABOVE := 0.62  # ..above this share of its height
const FULL_FLAG := Color("#d8402f")   # the pennant a full home flies
const PLANT_KINDS := ["tree", "bloom"]   # what grows in a garden-like building (shown by _show_plants)
const TREE_SIZE_JITTER := 0.08    # each tree of an orchard is made this much bigger or smaller, and turned at random
const PLANT_LOD_EVERY := 10       # frames between looks at the zoom for an orchard's far blobs
const TREE_FILL := 0.95           # an orchard tree's size against the space between trees (crowns touch, trunks show)
const ORCHARD_SMALLEST := 0.8    # an orchard tree is drawn between these sizes (against a lone tree at 1.0)
const ORCHARD_BIGGEST := 1.1     # (no bigger, or the crown reaches out of the field's border)
const ORCHARD_GAP_MOST := 0.8    # an orchard's trees stand no further apart than this (tiles): their crowns meet
const ORCHARD_VARIANTS := 3      # looks of each kind in an orchard (turned and sized: no clones)
const PLANT_BUDGET_MS := 12      # an orchard builds new kinds of tree for at most this long a frame
const TREE_CROWN := 0.3           # the crown radius an orchard tree is sized for; wider crowned kinds are drawn smaller
const FEED_CHECK_MSEC := 5000    # between looks at whether a home is hungry
const TROUGH := Vector3(0.15, 0.085, 0.055)   # a feed trough's half length, its height and half width, in tiles
const FEED_GOLD := Color("#dcb548")           # the feed in it
const EMPTY_DRESS := 0.12        # an empty yard's things (a trough, hay, a feed pan) are this big, in tiles
const EMPTY_TUFTS := 6            # and this many tufts of grass grow in it
const BLOOM_SIZE := 0.95          # a bloom in a Bloom Garden, against one on its own tile (1.6): a bed of them

static var planting := 0          # orchards still standing their trees, over frames
static var _head_meshes := {}  # animal id -> its head cut from its file (_head_mesh), or null

var uid := -1
var residents: Array[Animal3D] = []
var _idle_hidden := 0.0   # seconds since the residents hidden by the zoom last thought

var _id := ""
var _fp := Vector2i.ONE
var _spec := {}
var _who := ""                # who's inside, as last shown
var _who_peeking := ""
var _stage := ""              # how near ready, as last shown
var _produce: Node3D
var _peekers: Node3D           # heads looking out of the windows while the home is full
var _trough: Node3D            # the feed trough of a home that eats: full when fed, bare when hungry
var _feed := -2                # what the trough shows: -2 not asked yet, -1 eats nothing, 0 hungry, 1 fed
var _trough_feed := -2         # the feed state the trough was last built for
var _feed_msec := 0            # when that was last asked
var _empty_dress: Node3D       # what an empty yard holds instead of animals (a trough, hay, a feed pan, tufts)
var _windows: Array = []
var _flag: Node3D             # flown while the building is full
var _lod := -1                # 0 all, 1 half, 2 a few: how much of the yard is drawn at this zoom (-1: not set yet)
var _idle := 0.0               # time not yet given to the residents' minds
var _stock: Node3D               # a Garage's parked vehicles, a shed's pots, a barn's goods
var _stock_sig := ""
var _near_trees: Array[MultiMeshInstance3D] = []   # an orchard's trees, and the blobs drawn far out instead
var _far_trees: Array[MultiMeshInstance3D] = []
var _plants_far := false
var _planting := false
var _to_plant: Array = []        # kinds of tree an orchard still has to stand (a few each frame)
var _plant_stand := {}
var _plants_are_trees := false   # the plants are trees (planted once; their fruit grows by the clock)
var _plants_cycle: Array = []    # [when the cycle began, how long it lasts]: what the trees' fruit was last told
var _plant_detail := 1.0
var _plant_into: Node3D
var _plant_rng: RandomNumberGenerator
var _plants: Node3D               # the trees or blooms growing in an Orchard or Bloom Garden
var _doors: Array[Node3D] = []
var _own_ready := false        # the model has its own ready part (`when_fill_*`): no pile of produce beside it
var _company_look := -1        # the look the yard's company was last shown for (a store that keeps company)
var _props: Node3D             # ..and what of it stands still: its trees, its vehicle
var _water := {}               # the pond its animals swim on, here: {"at": its middle, "reach": its half sizes}
var _rings: WaterRings         # where its swimmers' rings go (Objects3D's)
var _wake_in := 0.0
var _wake_turn := 0


## The fill layer for building `o`, under its model `model` (which holds its doors).
static func create(o: Dictionary, model: Node3D) -> BuildingFill:
	var f := BuildingFill.new()
	f.uid = int(o.get("uid", 0))   # (a model shown outside a farm, a shop card's, has none)
	f._id = str(o["id"])
	f._fp = Game.footprint(f._id)
	f._spec = BuildingModel.spec(f._id, Game.look_level(o))
	f._own_ready = model.find_child(AssetRegistry.STATE + "fill_1", true, false) != null   # not-ui (a part's name)
	for c in model.get_children():
		if c.has_meta(BuildingModel.WINDOWS):
			f._windows = c.get_meta(BuildingModel.WINDOWS)
		if c.has_meta(BuildingModel.DOOR):
			f._doors.append(c)
			c.set_meta("rest_y", (c as Node3D).position.y)
	f.refresh(o)
	return f


## Where the yard's animals keep off (BuildingModel.taken): the building's block grown by the stone footing its
## walls stand on (BuildingModel.FOOT_OUT), which the block leaves out, so no animal's feet stand in it. (A
## building on stilts has none: there is room round its legs.)
static func kept_clear(s: Dictionary, fp: Vector2i) -> Array[Rect2]:
	var out := BuildingModel.taken(s, fp)
	var body: Dictionary = s["body"]
	var stilts := (s.get("features", []) as Array).any(func(f: Dictionary) -> bool: return f.get("type") == "stilts")
	if not out.is_empty() and float(body.get("w", 0.7)) > 0.0 and not stilts:
		out[0] = out[0].grow(BuildingModel.FOOT_OUT)
	return out


## Whether a building shows anything of what's inside it.
static func shows(o: Dictionary) -> bool:
	# (a home, or a store that shows its stock and keeps company in its yard: the Barn is its own kind)
	if Game.under_construction(o) or not Game.is_building_item(str(o["id"])):
		return false
	var def := Game.catalog.get_def(str(o["id"]))
	# Homes for named animals, or gardens for a kind (trees in an Orchard, blooms in a Bloom Garden).
	if not def is BuildingDef:
		return false
	return (not (def as BuildingDef).holds().is_empty()
		or str((def as BuildingDef).data.get("holds_kind", "")) in PLANT_KINDS
		or BuildingModel.fill_of(str(o["id"]), Game.look_level(o)).has("stock"))


## Brings what's shown up to date: who's in, how near ready. Rebuilds only what changed.
func refresh(o: Dictionary) -> void:
	var inside: Dictionary = o.get("inside", {})
	var share := ready_share(o)
	var step := int(floor(share * PRODUCE_STEPS))
	var who := "%d|%d" % [inside.hash(), Game.capacity(o)]   # (who's in, as a number: asked every second)
	# Hunger shown in the yard (our own touch): a feed trough, full while the animals are fed and empty when they
	# are hungry. Asked every few seconds (it turns on feed bought and on time passing), not at every look.
	var now := Time.get_ticks_msec()
	if _feed < -1 or now - _feed_msec >= FEED_CHECK_MSEC:
		# (each home on its own beat, by its uid: sixty homes asked in the same frame was a hitch every five seconds)
		_feed_msec = now if _feed >= -1 else now - posmod(uid * 977, FEED_CHECK_MSEC)
		_feed = -1 if not Game.feeds.is_feedable(o) else (0 if Game.feeds.is_hungry(o) else 1)
	var stage := "%d|%s|%d" % [step, Game.is_ready(o), _feed]
	var fill: Dictionary = _spec.get("fill", {})
	if fill.has("stock"):
		_show_stock(str(fill["stock"]), fill.get("at", [0.5, 0.95]), o)
		_show_company(fill.get("company", []), o)
		return
	if who == _who and stage == _stage and who == _who_peeking:
		return   # nothing it shows has changed since the last look (nearly every look: this is asked each second)
	if fill.has("plants"):
		# Trees and blooms are planted once: a tree's fruit grows on it and a bloom's heads open by the clock
		# (Objects3D.ripen), started over when the orchard or garden is harvested.
		if who != _who:
			_show_plants(o, int(fill["plants"]))
		_ripen_plants(o)
	elif who != _who:
		_show_residents(o)
		_dress_empty_yard(Game.inside_total(o) == 0)
	if stage != _stage and not _own_ready:
		_show_produce(str(fill.get("produce", "")), step, fill.get("at", [0.78, 0.9]), o)
	if not fill.has("plants") and (_feed != _trough_feed or who != _who):
		_show_trough(fill.get("at", [0.78, 0.9]))   # (only when fed or hungry turned, or who lives here did)
	_who = who
	_stage = stage
	var full := Game.capacity(o) > 0 and Game.inside_total(o) >= Game.capacity(o) and not fill.has("plants")
	_show_flag(full)
	if who != _who_peeking:
		_who_peeking = who
		_show_peekers(inside)   # (whoever lives here looks out of its windows, full or not)


## How near the building is to ready, 0..1 (0 when empty: nothing is being made).
static func ready_share(o: Dictionary) -> float:
	if Game.inside_total(o) == 0:
		return 0.0
	return clampf(1.0 - float(Game.seconds_until_ready(o)) / maxf(Game.cycle_of(o), 1.0), 0.0, 1.0)


## The most animals a building shows out in its yard at its size.
static func shown_cap(level: int, max_level: int) -> int:
	var along := float(level - 1) / maxf(max_level - 1, 1.0)
	return int(round(lerpf(SHOWN_FIRST, SHOWN_BIGGEST, clampf(along, 0.0, 1.0))))


## How many of `radii` (animals in the order they are shown) a home shows at `level`: as many as fit at full size
## (FarmVille's way: fewer animals, never shrunk ones) up to the level's cap, and never fewer than the level below.
static func shown_count(id: String, level: int, max_level: int, radii: Array[float], seed_value: int) -> int:
	var yard := SpaceFit.yard_room(Game.footprint(id))
	var most := 0
	for lv in range(1, level + 1):
		var taken := kept_clear(BuildingModel.spec(id, lv), Game.footprint(id))
		var lo := 0
		var hi := mini(shown_cap(lv, max_level), radii.size())
		while lo < hi:   # the most that fit readably: fitting only gets harder with more
			var mid := (lo + hi + 1) / 2
			var fit := SpaceFit.pack(yard, taken, radii.slice(0, mid), seed_value, ANIMAL_SMALLEST)
			if (fit["spots"] as Array).size() == mid:
				lo = mid
			else:
				hi = mid - 1
		most = maxi(most, lo)
	return clampi(most, mini(1, radii.size()), radii.size())


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
	var length := Animal3D.file_length(str(it.get("id", "")))
	if length > 0.0:
		return length * FILE_REACH + WANDER
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
	var picks := rarest(o.get("inside", {}), shown_cap(Game.level_of(o), Game.max_level(_id)))
	var radii: Array[float] = []
	for id in picks:
		radii.append(radius_of(Game.item_data(id)))
	radii = radii.slice(0, shown_count(_id, Game.level_of(o), Game.max_level(_id), radii, uid))
	var fit := SpaceFit.pack(SpaceFit.yard_room(_fp), kept_clear(_spec, _fp), radii, uid, ANIMAL_SMALLEST)
	_stand_residents(picks, fit["spots"], float(fit["size"]))


## The company a thriving store keeps in its yard (the Barn, data/building_models.json `fill.company`: our own
## touch): each of the list stands there from the look it names (`from`: for the Barn its VIP level), so a
## grander Barn looks a richer farm. Each stands at its own spot (`at`): an animal lives there as a home's
## does. They are for show: they belong to the Barn, are not counted or collected, and a broken Barn has none.
func _show_company(company: Array, o: Dictionary) -> void:
	var look := 0 if company.is_empty() or o.get("broken", false) else Game.look_level(o)
	if look == _company_look:
		return
	_company_look = look
	if _props != null:
		_props.queue_free()
	_props = Node3D.new()
	add_child(_props)
	var picks: Array = []
	var spots: Array = []
	for one: Dictionary in company:
		if int(one.get("from", 1)) > look:
			continue
		var it := Game.item_data(str(one["id"]))
		var spot := BuildingModel.yard_spot(one, _fp.x, _fp.y)
		match str(it.get("kind", "")):
			"animal":
				picks.append(str(one["id"]))
				spots.append(spot)
			"tree":
				var tree := Objects3D.tree_look(str(one["id"]), 0, _props.get_child_count())
				_keep_look(tree)
				tree.position = Vector3(spot.x - 0.5, 0, spot.y - 0.5)   # (a tree's look stands in its own tile)
				_props.add_child(tree)
			"vehicle":
				var pivot := Node3D.new()
				pivot.position = Vector3(spot.x, 0, spot.y)
				pivot.rotation.y = COMPANY_TURN
				var car := VehicleModel.build(it)
				car.position = Vector3(-0.5, 0, -0.5)                    # (turned about its own middle)
				pivot.add_child(car)
				_props.add_child(pivot)
	_stand_residents(picks, spots, 1.0)


## Where an animal standing at `at` goes to drink, from there, in the farm grid's px (AnimalBehaviour.drink_at):
## just short of the nearest water trough of its yard, when one is near; Vector2.INF when none is.
func _drink_from(at: Vector2) -> Vector2:
	var best := Vector2.INF
	for trough: Vector2 in BuildingModel.troughs(_spec, _fp):
		var way := trough - at
		if way.length() <= DRINK_NEAR and (not best.is_finite() or way.length() < best.length()):
			best = way.limit_length(maxf(way.length() - DRINK_SHORT, 0.0))
	return IsoProjection.grid_of(Vector3(best.x, 0, best.y)) if best.is_finite() else Vector2.INF


## Makes the look a model from a file shows now the only one it has: its other looks go, and the one shown is
## no longer a state part. (What stands in a building's yard is under the building's own model, whose states
## are switched through everything under it: a tree there would lose its look to the Barn's.)
static func _keep_look(model: Node) -> void:
	for c in model.get_children():
		if not String(c.name).begins_with(AssetRegistry.STATE):
			continue
		if c is Node3D and (c as Node3D).visible:
			c.name = "look"   # not-ui (a part's name)
		else:
			model.remove_child(c)
			c.free()


## Stands `picks` (animal ids) in the yard, the first of them at each of `spots`, drawn at `size`.
func _stand_residents(picks: Array, spots: Array, size: float) -> void:
	for a in residents:
		a.queue_free()
	residents.clear()
	_lod = -1  # (the new animals are shown or hidden for the zoom next frame)
	for k in spots.size():
		var it := Game.item_data(picks[k])
		if it.is_empty():
			continue
		var mind := AnimalBehaviour.new(AnimalRig.of(it), uid * 131 + k * 17,
			Vector2(WANDER * FarmGrid.TILE_W / 2.0, WANDER * FarmGrid.TILE_H / 2.0))
		var at := spots[k] as Vector2
		mind.drink_at = _drink_from(at)
		var a := Animal3D.create(it, mind, Vector3(at.x, 0.0, at.y), size)
		add_child(a)
		a.update(0.0)
		residents.append(a)


## An empty home's yard isn't bare dirt: a water trough, a pile of hay, a feed pan and a few tufts of grass stand
## in it, placed by SpaceFit like the animals would be, until the first animal moves in.
func _dress_empty_yard(empty: bool) -> void:
	if _empty_dress != null:
		_empty_dress.queue_free()
		_empty_dress = null
	if not empty:
		return
	_empty_dress = Node3D.new()
	var r := EMPTY_DRESS
	var fit := SpaceFit.pack(SpaceFit.yard_room(_fp), kept_clear(_spec, _fp), [r * 1.6, r, r] as Array[float],
		uid)
	var spots: Array = fit["spots"]
	var wood := Color("#8a5a32")
	if spots.size() > 0:   # the trough, brimming
		var at := Vector3((spots[0] as Vector2).x, 0.0, (spots[0] as Vector2).y)
		ModelKit.tub(_empty_dress, at + Vector3(-r * 1.4, 0, -r * 0.5), at + Vector3(r * 1.4, r * 0.7, r * 0.5), 0.02,
			ModelKit.surface(wood, "boards", 0.2), ModelKit.water())
	if spots.size() > 1:   # a pile of hay
		var at := Vector3((spots[1] as Vector2).x, 0.0, (spots[1] as Vector2).y)
		ModelKit.ball(_empty_dress, at, r, ModelKit.paint(Color("#e2c35a")), Vector3(1.2, 0.6, 1.0))
		ModelKit.ball(_empty_dress, at + Vector3(r * 0.6, 0, r * 0.3), r * 0.6, ModelKit.paint(Color("#d4b24a")),
			Vector3(1.2, 0.5, 1.0))
	if spots.size() > 2:   # a feed pan with grain in it
		var at := Vector3((spots[2] as Vector2).x, 0.0, (spots[2] as Vector2).y)
		ModelKit.cylinder(_empty_dress, at, r * 0.8, r * 0.3, ModelKit.paint(Color("#8a9096"), 0.4), r * 0.9, 12)
		ModelKit.cylinder(_empty_dress, at + Vector3(0, r * 0.3, 0), r * 0.75, 0.005, ModelKit.paint(Color("#d9b24a")),
			-1.0, 12)
	var room := SpaceFit.yard_room(_fp)
	var rng := RandomNumberGenerator.new()
	rng.seed = uid * 31 + 7
	for k in EMPTY_TUFTS:
		var at := Vector3(rng.randf_range(room.position.x, room.end.x), 0.0, rng.randf_range(room.position.y, room.end.y))
		for blade in 3:
			var b := ModelKit.cylinder(_empty_dress, at + Vector3(rng.randf_range(-0.02, 0.02), 0, 0), 0.008,
				rng.randf_range(0.05, 0.09), ModelKit.paint(Color("#5f8a3a").darkened(rng.randf() * 0.2)), 0.001, 4)
			b.rotation = Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
	_empty_dress = ModelKit.bake(_empty_dress)   # (a few draws for the lot; bake frees the parts)
	add_child(_empty_dress)


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
		var head: Node3D
		if AssetRegistry.has_model(picks[k]):
			head = _file_head(picks[k], float(w["size"]))
			if head == null:
				continue   # (its head is bigger than the window: nobody looks out of this one)
		else:
			head = _head(Color.html(str(it.get("color", "#ffffff"))), float(w["size"]))
		head.position = w["at"] as Vector3
		head.scale = Vector3.ZERO
		for part in head.find_children("*", "GeometryInstance3D", true, false) + [head]:  # not-ui
			if part is GeometryInstance3D:   # (a head at a window throws no shadow worth drawing it twice for)
				(part as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


## The animal's own head at a window, cut from its file, at the animal's own size (as it is in the yard), the nose
## just out past the wall (a little smaller to fit). Null when it has no file or its head is far too big for a
## window of `size`.
static func _file_head(id: String, size: float) -> Node3D:
	var head := _head_mesh(id)
	if head == null:
		return null
	var box := head.get_aabb()
	# Its own size, or a little smaller to fit the window; never so small it looks like a different animal.
	var s := minf(1.0, size * PEEK_FILL / maxf(maxf(box.size.y, box.size.z), 0.001))
	if s < PEEK_LEAST:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = head
	mi.scale = Vector3.ONE * s
	mi.position = Vector3(PEEK_OUT + size * PEEK_SNOUT - box.end.x * s, -box.get_center().y * s, -box.get_center().z * s)
	var root := Node3D.new()
	root.add_child(mi)
	return root


## An animal's head as a mesh of its own: the triangles of its file's front, upper part (HEAD_SHARE, HEAD_ABOVE),
## with their colours and materials; made once a kind and shared. Null when the animal has no file.
static func _head_mesh(id: String) -> ArrayMesh:
	if _head_meshes.has(id):
		return _head_meshes[id]
	var model := AssetRegistry.instance(id) if AssetRegistry.has_model(id) else null
	var mi := Animal3D._first_mesh(model) if model != null else null
	var out: ArrayMesh = null
	if mi != null and mi.mesh != null:
		var all := mi.get_aabb()
		var bird := AnimalRig.of(Game.item_data(id)).type == "bird"   # (a bird's head sits high on a breast)
		var front := all.end.x - all.size.x * (BIRD_HEAD_SHARE if bird else HEAD_SHARE)
		var above := all.position.y + all.size.y * (BIRD_HEAD_ABOVE if bird else HEAD_ABOVE)
		out = ArrayMesh.new()
		for k in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(k)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var kept := head_triangles(v, idx, front, above)
			if kept.is_empty():
				continue
			arrays[Mesh.ARRAY_INDEX] = kept
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, mi.get_active_material(k))
		if out.get_surface_count() == 0:
			out = null
	if model != null:
		model.free()
	_head_meshes[id] = out
	return out


## The triangles of `idx` (three vertex indices each) whose three corners are all in front of `front` and above
## `up`, in their order. Each corner is judged once (a corner is shared by several triangles) and the kept ones
## are written in place, not appended one by one: the same triangles, about twice as fast (14 heads cut while the
## showcase opens: 29 -> 13 ms of CPU here).
static func head_triangles(v: PackedVector3Array, idx: PackedInt32Array, front: float, up: float) -> PackedInt32Array:
	var near := PackedByteArray()
	near.resize(v.size())
	for k in v.size():
		var p := v[k]
		near[k] = 1 if p.x > front and p.y > up else 0
	var kept := PackedInt32Array()
	kept.resize(idx.size())
	var n := 0
	for t in range(0, idx.size(), 3):
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		if near[a] == 1 and near[b] == 1 and near[c] == 1:
			kept[n] = a
			kept[n + 1] = b
			kept[n + 2] = c
			n += 3
	kept.resize(n)
	return kept


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
## Starts the orchard's trees' fruit growing for the cycle it is in (nothing when they were told it already).
func _ripen_plants(o: Dictionary) -> void:
	var cycle := [float(o.get("t", 0)), float(Game.cycle_of(o))]
	if cycle == _plants_cycle:
		return
	_plants_cycle = cycle
	for tree in _near_trees:
		Objects3D.ripen(tree, cycle[0], cycle[1])
	if not _plants_are_trees and _plants != null:
		Objects3D.ripen(_plants, cycle[0], cycle[1])   # (blooms in a garden never wither)


func _show_plants(o: Dictionary, slots: int) -> void:
	_plants_cycle = [float(o.get("t", 0)), float(Game.cycle_of(o))]
	if _plants != null:
		_plants.queue_free()
	_near_trees.clear()
	_far_trees.clear()
	var holder := Node3D.new()
	var inside: Dictionary = o.get("inside", {})
	var first := ""
	for id: String in inside:
		if int(inside[id]) > 0:
			first = id
			break
	var trees := first == "" or Game.kind_of({"id": first}) == "tree"
	_plants_are_trees = trees
	# A grid in the field's own proportions, inside its tile's border with each crown kept in; trees are packed
	# tight, crowns just touching (FarmVille's orchards).
	var room := SpaceFit.tile_room(_fp)
	# (a shed stands along the back of the field: the plants start in front of it, `plants_from` of the way down)
	var from := float((_spec.get("fill", {}) as Dictionary).get("plants_from", 0.0)) * _fp.y
	if from > room.position.y:
		room = Rect2(room.position.x, from, room.size.x, room.end.y - from)
	# An orchard's grid is for the trees it holds now, standing together in the middle of the field (a few make a
	# clump of crowns, not a line along one fence); a garden's is for all its places, in beds.
	var count := maxi(mini(slots, Game.inside_total(o)), 1) if trees else slots
	var per_row := maxi(ceili(sqrt(count * _fp.x / maxf(_fp.y, 1.0))), 1)
	var rows := ceili(float(count) / per_row)
	var span := room.grow(-TREE_CROWN * 1.1).abs()
	var gap := minf(span.size.x / maxf(per_row - 1.0, 1.0), span.size.y / maxf(rows - 1.0, 1.0))
	if trees:
		gap = minf(gap, ORCHARD_GAP_MOST)
	# (A crown is TREE_CROWN wide each way at size 1: the size that makes crowns just meet across the gap.)
	var size := clampf(gap * TREE_FILL / (2.0 * TREE_CROWN), ORCHARD_SMALLEST, ORCHARD_BIGGEST)
	var total := Game.inside_total(o)
	# Every tree and bloom inside is there to see (FarmVille's orchards and gardens).
	var shown := mini(slots, total)
	var ids := grouped(pick_kinds(inside, shown, 99))  # a garden shows every different kind in it
	# A garden of blooms is one baked model kept on disk (ModelStore: shipped for the showcase, saved on the phone
	# the first time), so it opens without building its blooms again; the same model, so it looks the same.
	var key := ""
	if not trees and ids.all(func(i: String) -> bool: return Game.kind_of({"id": i}) == "bloom"):
		key = Instancer.key_of(["garden", uid, _fp, room, span, per_row, rows, BLOOM_SIZE, ",".join(ids),
			_crowd_detail(ids.size())])
		var kept := ModelStore.fetch(key)
		if kept != null:
			_stand_plants(kept)
			return
	if not trees:
		# Blooms grow in soil beds, one a row.
		for r in rows:
			var bz := span.position.y + span.size.y * r / maxf(rows - 1.0, 1.0) if rows > 1 else room.get_center().y
			ModelKit.box(holder, Vector3(room.position.x, 0, bz - 0.22), Vector3(room.end.x, 0.05, bz + 0.22),
				ModelKit.paint(Color("#6b4a2b")))
	# Row by row, each kind together in straight lines, as FarmVille's orchards had them.
	var places: Array[Vector2i] = []
	for k in per_row * rows:
		places.append(Vector2i(k % per_row, int(k / float(per_row))))
	# Dozens of the same model: each gets less detail, so a full orchard costs about what a few trees do.
	ModelKit.detail = _crowd_detail(ids.size())
	var stand := {}   # trees to stand: id -> {size, at: [where]}
	for k in ids.size():
		var z := span.position.y + span.size.y * places[k].y / maxf(rows - 1.0, 1.0) if rows > 1 \
			else room.get_center().y
		var x := span.position.x + span.size.x * places[k].x / maxf(per_row - 1.0, 1.0) if per_row > 1 \
			else room.get_center().x
		if trees:
			var in_row := mini(per_row, ids.size() - places[k].y * per_row)   # (a short last row stands in the middle)
			x = room.get_center().x + (places[k].x - (in_row - 1) / 2.0) * gap
			z = room.get_center().y + (places[k].y - (rows - 1) / 2.0) * gap
		var it := Game.item_data(ids[k])
		if str(it.get("kind", "")) == "bloom":
			var d := Game.catalog.get_def(ids[k]) as BloomDef
			BloomModel.build_at(holder, Vector3(x, 0.05, z), it, BLOOM_SIZE * ScaleGuide.factor(ids[k]), d.is_full(),
				uid + k)
		else:
			var fit := clampf(TREE_CROWN / float(TreeModel.shape_of(it).get("crown_r", TREE_CROWN)), 0.7, 1.1)
			var grown := size * fit * minf(ScaleGuide.factor(ids[k]), 1.0)
			if not stand.has(ids[k]):
				stand[ids[k]] = {"size": grown, "at": []}
			(stand[ids[k]]["at"] as Array).append(Vector3(x, 0, z))
	_plant_trees(holder, stand)
	ModelKit.detail = 1.0
	var plants := ModelKit.bake(holder) if holder.get_child_count() > 0 and stand.is_empty() else holder
	if key != "" and plants != holder:
		ModelStore.keep(key, plants)
	_stand_plants(plants)


## How much detail each of `count` trees or blooms in one orchard or garden is built with (ModelKit.detail).
static func _crowd_detail(count: int) -> float:
	return clampf(sqrt(CROWD_FULL_DETAIL / maxf(count, 1.0)), ModelKit.MIN_DETAIL, 1.0)


## Stands the orchard's or garden's plants, built or kept, and sets them growing for the cycle it is in.
func _stand_plants(plants: Node3D) -> void:
	_plants = plants
	add_child(_plants)
	if not _plants_are_trees:
		Objects3D.ripen(_plants, _plants_cycle[0], _plants_cycle[1])
	_apply_plant_lod()


## Stands the trees of an orchard: a few different trees of each kind (ORCHARD_VARIANTS, never more than there are
## trees of it) are built once and kept; every tree standing is a copy of one of them, turned and sized a little
## differently, drawn as one batch per variant (Instancer). Zoomed far out each is drawn as its far look instead
## (`TreeModel.far_from`, made from the near tree's own measurements, `_plant_lod`). Building new kinds takes
## at most PLANT_BUDGET_MS a frame: a big orchard stands over a few frames instead of freezing the game.
func _plant_trees(holder: Node3D, stand: Dictionary) -> void:
	_plant_rng = RandomNumberGenerator.new()
	_plant_rng.seed = uid
	_plant_stand = stand
	_plant_detail = ModelKit.detail
	_plant_into = holder
	_to_plant = stand.keys()
	_set_planting(not _to_plant.is_empty())
	_plant_some()


## Plants the next kinds of the orchard for at most PLANT_BUDGET_MS (at least one kind); the rest wait for the next
## frame (`_process`).
func _plant_some() -> void:
	var began := Time.get_ticks_msec()
	while not _to_plant.is_empty():
		if Time.get_ticks_msec() - began > PLANT_BUDGET_MS:
			return
		if not is_instance_valid(_plant_into):
			_to_plant.clear()
			break
		_plant_kind(str(_to_plant.pop_front()))
		_apply_plant_lod()
	_set_planting(false)


## Every tree of one kind in the orchard: its variants built (or reused), each a batch of copies, near and far.
func _plant_kind(id: String) -> void:
	var holder := _plant_into
	var detail := _plant_detail
	var size: float = _plant_stand[id]["size"]
	var spots: Array = _plant_stand[id]["at"]
	var it := Game.item_data(id)
	var variants := mini(ORCHARD_VARIANTS, spots.size())
	for v in variants:
		var here: Array[Transform3D] = []
		for k in range(v, spots.size(), variants):
			var scale := 1.0 + _plant_rng.randf_range(-TREE_SIZE_JITTER, TREE_SIZE_JITTER)
			here.append(Transform3D(Basis(Vector3.UP, _plant_rng.randf() * TAU).scaled(Vector3.ONE * scale), spots[k]))
		var key := Instancer.key_of(["orchard_tree", id, size, detail, v])
		var measured := {}   # what the near tree measured, for its far look
		var near := Instancer.place(holder, Instancer.parts_of(key, func() -> Node3D:
			var tree := Node3D.new()
			var was := ModelKit.detail
			ModelKit.detail = detail
			var built := TreeModel.build_at(tree, Vector3.ZERO, it, size, true, v * 977 + 1)
			ModelKit.detail = was
			measured["far"] = built.get_meta(TreeModel.META_FAR, [])
			return ModelKit.bake(tree)), here)
		for tree in near:
			Objects3D.ripen(tree, _plants_cycle[0], _plants_cycle[1])   # (their fruit grows by the orchard's cycle)
		_near_trees.append_array(near)
		var blob := Instancer.parts_of(Instancer.key_of([key, LOD_FAR_PPU]), func() -> Node3D:
			return TreeModel.far_from(measured.get("far", []), it, size, v * 977 + 1))
		var far := Instancer.place(holder, blob, here)
		for node in far:
			node.visible = false
		_far_trees.append_array(far)


## Counts this orchard in or out of those still planting (once each way, also if it is freed part-way).
func _set_planting(on: bool) -> void:
	if on != _planting:
		_planting = on
		planting += 1 if on else -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_set_planting(false)


## Zoomed far out the orchard's trees are blobs; in close, trees.
func _plant_lod(cam: Camera3D) -> void:
	var ppu := get_viewport().get_visible_rect().size.y / maxf(cam.size, 0.001)
	var far := ppu < LOD_FAR_PPU if not _plants_far else ppu < LOD_FAR_PPU * LOD_MARGIN
	if far == _plants_far:
		return
	_plants_far = far
	_apply_plant_lod()


func _apply_plant_lod() -> void:
	for n in _near_trees:
		if is_instance_valid(n):
			n.visible = not _plants_far
	for n in _far_trees:
		if is_instance_valid(n):
			n.visible = _plants_far


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
		if not hinge.has_meta(BuildingModel.SLIDE):
			continue
		if not hinge.has_meta("rest_y"):
			hinge.set_meta("rest_y", hinge.position.y)
		var y := float(hinge.get_meta("rest_y")) + (float(hinge.get_meta(BuildingModel.SLIDE)) if open else 0.0)
		if not is_inside_tree() or not is_visible_in_tree():
			hinge.position.y = y                         # not on screen yet: just be there
			continue
		var tw := create_tween()                          # owned by this node, so it ends with it
		tw.tween_property(hinge, "position:y", y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- produce


## The home's feed trough, across the gate from where its produce piles up (`at`): brimming with feed while the
## animals are fed, bare boards when they are hungry, and none for a home that eats nothing. Hungry animals look
## up from the grass and about (AnimalBehaviour.hungry), so hunger is seen in the yard, not only in a bubble.
func _show_trough(at: Array) -> void:
	_trough_feed = _feed
	if _trough != null:
		_trough.queue_free()
		_trough = null
	for a in residents:
		if a.behaviour != null:
			a.behaviour.hungry = _feed == 0
	if _feed < 0 or Game.inside_total(Game.object_by_uid(uid)) == 0:
		return
	var root := Node3D.new()
	var p := Vector3((1.0 - float(at[0])) * _fp.x, 0, float(at[1]) * _fp.y)
	ModelKit.tub(root, p + Vector3(-TROUGH.x, 0, -TROUGH.z), p + Vector3(TROUGH.x, TROUGH.y, TROUGH.z), 0.018,
		ModelKit.surface(BuildingModel.WOOD, "boards", 0.2), ModelKit.paint(FEED_GOLD) if _feed == 1 else null, 0.85)
	_trough = ModelKit.bake(root)
	_trough.visible = _lod <= 0   # (a detail of the near view, like the yard's far animals: _set_lod)
	add_child(_trough)


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
	if not _to_plant.is_empty():
		_plant_some()
	if not _far_trees.is_empty() and Engine.get_process_frames() % PLANT_LOD_EVERY == 0:
		var eye := get_viewport().get_camera_3d()
		if eye != null:
			_plant_lod(eye)
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
	# One hidden by the zoom (see _set_lod) thinks a few times a second, like a yard out of sight: nobody sees it.
	_idle_hidden += delta
	var think_hidden := (Engine.get_process_frames() + get_instance_id()) % OFFSCREEN_STRIDE == 0
	for a in residents:
		if a.visible:
			a.behaviour.update(_idle)
			a.animate(_idle, cam)
		elif think_hidden:
			a.behaviour.update(_idle_hidden)
	if think_hidden:
		_idle_hidden = 0.0
	_idle = 0.0
	if not _water.is_empty():
		_swim(delta)


## The pond in this yard (Objects3D found it in the model): the middle of its surface and its half sizes, in the
## yard's own space. Its animals swim on it; their rings go to `rings`.
func set_water(at: Vector3, reach: Vector2, rings: WaterRings) -> void:
	_water = {"at": at, "reach": reach}
	_rings = rings


## The animals over the pond's water float on it (Animal3D.afloat), unless it is frozen: then they stand on the
## ice. Each swimmer leaves a ring on the water now and then, a wider one while it dabbles.
func _swim(delta: float) -> void:
	var at: Vector3 = _water["at"]
	var reach: Vector2 = _water["reach"]
	var open := not PondLife.frozen()
	for a in residents:
		var out := Vector2((a.position.x - at.x) / reach.x, (a.position.z - at.z) / reach.y)
		a.afloat = open and out.length() <= SWIM_WITHIN
	_wake_in -= delta
	if _wake_in > 0.0 or _rings == null:
		return
	_wake_in = WAKE_EVERY
	_wake_turn += 1
	for k in residents.size():
		var a := residents[k]
		if (k + _wake_turn) % WAKE_TURNS != 0 or not a.visible or a.float_share < 0.5:
			continue
		var wide := WAKE.y * (1.5 if a.behaviour.state == AnimalBehaviour.State.GRAZE else 1.0)
		_rings.ring(to_global(Vector3(a.position.x, at.y, a.position.z)) + Vector3(0, 0.004, 0), WAKE.x, wide, WAKE.z)


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
	if _trough != null:
		_trough.visible = tier <= 0
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
		if hinge.has_meta(BuildingModel.SLIDE):
			var up := float(hinge.get_meta(BuildingModel.SLIDE))
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
		if hinge.has_meta(BuildingModel.SLIDE) and hinge.position.y > float(hinge.get_meta("rest_y", 0.0)) + 0.05:
			return true
	return false


## Lets go of the looks kept in statics (Game, on quit), so none is still held when the engine shuts down.
static func release_statics() -> void:
	_head_meshes.clear()
