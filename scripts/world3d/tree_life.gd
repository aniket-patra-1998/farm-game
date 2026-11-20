class_name TreeLife
extends Node3D
## The small life of the farm's trees (owner, 20 Nov): a leaf drifts down from one now and then; a gust bends them
## all and blows leaves off their crowns; a ripe tree drops a fruit; a harvested one shakes, its fruit leaps off
## and leaves fall. A limited tree has more: a hummingbird calls at one now and then (Hummingbird), and a Cotton
## Candy tree shivers and lets a few petals go, as a Cotton Candy animal shakes its coat. All of it is for show:
## nothing is picked up, and nothing here changes the game. Farm3D adds one, hands it the weather's wind (`calm`)
## and tells it of harvests (`harvested`).

const LEAF_EVERY := Vector2(1.5, 4.0)    # seconds between one idle leaf and the next, somewhere on the farm
const DROP_EVERY := Vector2(9.0, 20.0)   # ..and between one ripe tree dropping a fruit and the next
const GUST_EVERY := Vector2(25.0, 50.0)  # ..and between gusts
const GUST_TIME := 3.6        # seconds a gust lasts, rising and falling away
const GUST_WIND := 2.4        # the wind a gust adds at its height (the weather's own is about 0.6)
const GUST_LEAF_EVERY := 0.3  # seconds between leaves blown off one tree at a gust's height..
const GUST_TREES := 12        # ..from this many trees at most
const GUST_PUSH := 1.9        # how fast a gust carries a leaf (tiles a second)
const BLOWS := Vector3(0.7071, 0, -0.7071)   # the way the wind blows: across the screen
const CROWN_AT := 0.68        # where a tree's crown is, of its height..
const CROWN_R := 0.5          # ..and how far out its leaves reach (tiles)
const LEAF_SIZE := Vector2(0.045, 0.07)   # a falling leaf's radius (tiles)
const LEAF_VARY := 0.12       # how much lighter or darker one fallen leaf is than the next
const FRUIT_SIZE := 0.085     # ..and a dropped fruit's
const SHAKE_LEAVES := 12      # leaves that fall when a tree is harvested..
const SHAKE_FRUIT := 6        # ..and fruit that leap off it
const SHAKE_PUSH := 0.9       # how fast they leave the crown (tiles a second)
const LEAP := 2.3             # how fast a harvested fruit leaps up
const BIRD_EVERY := Vector2(14.0, 30.0)   # seconds from a hummingbird leaving to its next call at a limited tree
const SHIVER_EVERY := Vector2(7.0, 15.0)  # ..and between one Cotton Candy tree's shiver and the next
const SHIVER_PETALS := 5      # petals a shiver lets go
const SHIVER_PUSH := 0.5      # ..and how fast they leave the crown (tiles a second)
const SHAKES := "shake"       # the touch of a variety that shivers (data/varieties.json)   # not-ui

var objects: Objects3D        # the farm's things (a harvested tree shakes there)
var winds: Array = []         # what takes the wind (the ground, the crops: anything with `wind`)
var calm := 0.6: set = _set_calm   # the weather's own wind
var gust := 0.0               # how much of a gust is blowing now (0..1)
var leaves := FallingBits.new()
var fruit := FallingBits.new(true)
var bird := Hummingbird.new()

var _rng := RandomNumberGenerator.new()
var _trees: Array = []        # the farm's lone trees, kept until the farm changes
var _stale := true
var _leaf_in := 2.0
var _drop_in := 6.0
var _gust_in := 12.0
var _gust_age := -1.0         # seconds into the gust blowing now (-1: none)
var _blown := 0.0
var _bird_in := 8.0
var _shiver_in := 5.0


func _ready() -> void:
	add_child(leaves)
	add_child(fruit)
	add_child(bird)
	Game.objects_changed.connect(func() -> void: _stale = true)
	Game.farm_opened.connect(func() -> void:
		_stale = true
		bird.leave())
	_rng.randomize()


func _process(delta: float) -> void:
	tick(delta)


## One step of `delta` seconds (the frame's own; tests step it).
func tick(delta: float) -> void:
	var trees := trees()
	if trees.is_empty():
		return
	_leaf_in -= delta
	if _leaf_in <= 0.0:
		_leaf_in = _rng.randf_range(LEAF_EVERY.x, LEAF_EVERY.y)
		shed(trees[_rng.randi() % trees.size()])
	_drop_in -= delta
	if _drop_in <= 0.0:
		_drop_in = _rng.randf_range(DROP_EVERY.x, DROP_EVERY.y)
		var ripe := trees.filter(func(o: Dictionary) -> bool: return Game.is_ready(o))
		if not ripe.is_empty():
			drop_fruit(ripe[_rng.randi() % ripe.size()])
	_gust_in -= delta
	if _gust_in <= 0.0 and _gust_age < 0.0:
		blow()
	if _gust_age >= 0.0:
		_blow_on(delta, trees)
	_limited(delta, trees)


## The farm's lone trees (an Orchard's are its own).
func trees() -> Array:
	if _stale:
		_stale = false
		_trees = Game.objects.filter(func(o: Dictionary) -> bool: return Game.kind_of(o) == "tree")
		for o: Dictionary in _trees:   # (each kind's height measured now, once, not when its first leaf falls)
			ScaleGuide.height_of(str(o["id"]))
	return _trees


## A leaf leaves tree `o`'s crown: let go (`push`), or carried off by the wind (`blown`).
func shed(o: Dictionary, push := 0.0, blown := 0.0) -> void:
	var a := _rng.randf() * TAU
	var out := Vector3(cos(a), 0, sin(a))
	var crown := crown_of(o)
	var at := crown + out * CROWN_R * _rng.randf_range(0.55, 1.0) + Vector3(0, _rng.randf_range(-0.12, 0.15), 0)
	leaves.drop(at, out * push * _rng.randf_range(0.4, 1.0) + Vector3(0, push * 0.5, 0) + BLOWS * blown,
		leaf_colour(o), _rng.randf_range(LEAF_SIZE.x, LEAF_SIZE.y), _rng.randf() * TAU)


## A ripe tree lets one fruit fall: it bounces, rolls a little and is gone.
func drop_fruit(o: Dictionary) -> void:
	var a := _rng.randf() * TAU
	var out := Vector3(cos(a), 0, sin(a))
	fruit.drop(crown_of(o) + out * CROWN_R * 0.8 + Vector3(0, -0.2, 0), out * 0.35, fruit_colour(o), FRUIT_SIZE)
	shed(o)


## Tree `uid` was harvested: it shakes, its fruit leaps off and leaves fall.
func harvested(uid: int) -> void:
	var o := Game.object_by_uid(uid)
	if o.is_empty() or Game.kind_of(o) != "tree":
		return
	if objects != null:
		objects.shake(uid)
	for i in SHAKE_LEAVES:
		shed(o, SHAKE_PUSH)
	var crown := crown_of(o)
	for i in SHAKE_FRUIT:
		var a := TAU * i / SHAKE_FRUIT + 0.3
		var out := Vector3(cos(a), 0, sin(a))
		fruit.drop(crown + out * CROWN_R * 0.85, out * 0.5 + Vector3(0, LEAP, 0), fruit_colour(o), FRUIT_SIZE)


## A hummingbird calls at limited tree `o`: round its crown, in among the leaves, out and away.
func call_at(o: Dictionary) -> void:
	var stay := Hummingbird.NEST_TIME
	bird.visit(crown_of(o), CROWN_R, _rng.randf() * TAU, _rng.randf_range(stay.x, stay.y))


## Tree `o` shivers and lets a few petals go (a Cotton Candy tree's own touch).
func shiver(o: Dictionary) -> void:
	if objects != null:
		objects.shake(int(o["uid"]))
	for i in SHIVER_PETALS:
		shed(o, SHIVER_PUSH)


## A gust begins: the wind rises and falls away over GUST_TIME, and leaves are blown off the trees.
func blow() -> void:
	_gust_age = 0.0
	_blown = 0.0
	_gust_in = _rng.randf_range(GUST_EVERY.x, GUST_EVERY.y)


## Where tree `o`'s crown is, in the farm's space.
func crown_of(o: Dictionary) -> Vector3:
	var fp := Game.footprint(str(o["id"]))
	return Vector3(int(o["col"]) + fp.x * 0.5, ScaleGuide.height_of(str(o["id"])) * CROWN_AT, int(o["row"]) + fp.y * 0.5)


## The colour of tree `o`'s fruit: this tree's own (a kind may have several: TreeModel.picks).
func fruit_colour(o: Dictionary) -> Color:
	return _picks(o)[1]


## ..and of its leaves, each a shade of its own (a limited tree's: one of its variety's colours).
func leaf_colour(o: Dictionary) -> Color:
	var variety := str(Game.item_data(str(o["id"])).get("variety", ""))
	var hues := Varieties.leaves(variety)
	var toned: Color
	if hues.is_empty():
		toned = TreeSpec.builder().call(&"tone", _picks(o)[0])
	else:
		toned = hues[_rng.randi() % hues.size()].darkened(float(Varieties.of(variety).get("darken", 0.0)))
	return toned.lightened(_rng.randf_range(-LEAF_VARY, LEAF_VARY))


func _picks(o: Dictionary) -> Array:
	var it := Game.item_data(str(o["id"]))
	var look := Instancer.variant(int(o["row"]), int(o["col"])) % Objects3D.TREE_LOOKS
	return TreeSpec.builder().call(&"picks", it, TreeSpec.shape_of(it), look)


## The limited trees' own life: the hummingbird's calls and the Cotton Candy trees' shivers.
func _limited(delta: float, trees: Array) -> void:
	bird.tick(delta)
	_bird_in -= delta if bird.away() else 0.0   # (the wait for the next call starts when the bird has left)
	if _bird_in <= 0.0 and bird.away():
		_bird_in = _rng.randf_range(BIRD_EVERY.x, BIRD_EVERY.y)
		var limited := trees.filter(func(o: Dictionary) -> bool: return Game.limited.is_limited(str(o["id"])))
		if not limited.is_empty():
			call_at(limited[_rng.randi() % limited.size()])
	_shiver_in -= delta
	if _shiver_in <= 0.0:
		_shiver_in = _rng.randf_range(SHIVER_EVERY.x, SHIVER_EVERY.y)
		var shy := trees.filter(func(o: Dictionary) -> bool:
			return str(Game.item_data(str(o["id"])).get("touch", "")) == SHAKES)
		if not shy.is_empty():
			shiver(shy[_rng.randi() % shy.size()])


func _blow_on(delta: float, trees: Array) -> void:
	_gust_age += delta
	var u := _gust_age / GUST_TIME
	gust = sin(PI * clampf(u, 0.0, 1.0))
	if u >= 1.0:
		gust = 0.0
		_gust_age = -1.0
	_wind()
	_blown += delta * gust
	if _blown >= GUST_LEAF_EVERY:
		_blown = 0.0
		for k in mini(trees.size(), GUST_TREES):
			shed(trees[(k * 7 + int(_gust_age * 10.0)) % trees.size()], 0.0, GUST_PUSH * gust)


func _set_calm(v: float) -> void:
	calm = v
	_wind()


func _wind() -> void:
	for w: Object in winds:
		w.set("wind", calm + GUST_WIND * gust)
