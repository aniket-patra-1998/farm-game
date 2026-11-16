class_name CropForms
extends RefCounted
## What each crop looks like in 3D: a form per kind of plant (wheat, rice, corn, tomato on its stake, sunflower,
## pumpkin, cabbage...) drawn into a MeshBuilder at a growth stage. Which crop is which form, and each form's
## numbers, are in data/crop_forms.json; a crop without one falls back to its catalog shape (CropModels).
## Produce (a head, a fruit, a bloom) is marked with vertex alpha 0 and takes the crop's colour at draw time.

const PATH := "res://data/crop_forms.json"
const PLOT := 0.163   # half a plot, in plant units (Crops3D.PLANT_SCALE to a tile), a hair over so plots join
const TUFTS := 5       # tufts of leaves across a plot's carpet..
const TUFTS_YOUNG := 3  # ..and across a growing plot, where soil still shows between them
const STEM := Color("#5c8a2e")
const BARK := Color("#6b4a26")
const STAKE := Color("#7a5a30")
const STRAW := Color("#d8b85a")
const WHITE := Color(0.95, 0.94, 0.88)

## How many pieces a crop's harvest picture gathers, by its form's "plot" (big produce fewer, small more).
const HARVEST_PIECES := {"melons": 3, "heads": 1, "peppers": 3, "stakes": 1, "default": 5}
const HARVEST_SPREAD := 0.06   # how far a harvest's pieces sit from its middle (a melon's own size sets its own)
const HARVEST_BUNCHED := ["flowers", "spikes", "ears", "roots"]   # held up as a bunch, not heaped (`_bunch`)
const HARVEST_FAN := deg_to_rad(20.0)   # between one stem of a bunch and the next, across the picture
const HARVEST_LEAN := deg_to_rad(0.0)   # how far a bunch leans toward the viewer (the pictures already look down)..
const HARVEST_FLOWER_LEAN := deg_to_rad(50.0)   # ..but flowers face the viewer, their heads tipped to the camera
const PULLED_ROOT := 1.8   # a pulled root against the size it shows in the field..
const PULLED_TOPS := 2.5   # ..and its tops' leaves broader, so they read green at a picture's size
const TOWARD_VIEW := Vector3(0.7071, 0.0, 0.7071)   # the pictures look from +x +z (ItemIcons)..
const ACROSS := Vector3(0.7071, 0.0, -0.7071)       # ..and this runs across them

static var _data := {}


static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"forms": {}, "crops": {}}
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(PATH + " is missing or not valid JSON")


## The form a crop is drawn as: its own, or its catalog shape when it has none.
static func form_of(crop_id: String, shape: String) -> String:
	_load()
	return str((_data["crops"] as Dictionary).get(crop_id, shape))


## A number of the look every crop shares (data/crop_forms.json "look"): how tall a crop may stand, how much
## its produce is enlarged.
static func look(key: String, fallback: float) -> float:
	_load()
	return float((_data.get("look", {}) as Dictionary).get(key, fallback))


## Whether `form` is drawn a plot at a time (it has a "plot": a carpet of leaves and a few big pieces of produce
## laid out over the whole plot) and not as a plant repeated in rows.
static func is_plot(form: String) -> bool:
	return spec(form).has("plot")


static func spec(form: String) -> Dictionary:
	_load()
	return (_data["forms"] as Dictionary).get(form, {})


static func forms() -> Array:
	_load()
	return (_data["forms"] as Dictionary).keys()


static func crops() -> Dictionary:
	_load()
	return _data["crops"]


## Draws `form` at a stage (`ripe` or growing, `k` how grown 0..1) into `mb`. False if there is no such form.
static func build(mb: MeshBuilder, form: String, rng: RandomNumberGenerator, k: float, ripe: bool) -> bool:
	var s := spec(form)
	if s.is_empty():
		return false
	mb.produce_scale = float(s.get("produce", look("produce", 1.0)))   # (a form may set its own)
	mb.produce_small = look("produce_small", mb.produce_small)
	mb.produce_big = look("produce_big", mb.produce_big)
	if s.has("plot"):
		mb.produce_scale = 1.0   # (its pieces are sized by its own numbers)
		_plot(mb, rng, s, k, ripe)
		return true
	match str(s["kind"]):
		"cereal": _cereal(mb, rng, s, k, ripe)
		"bean": _bean(mb, rng, s, k, ripe)
		"corn": _corn(mb, rng, s, k, ripe)
		"cane": _cane(mb, rng, s, k, ripe)
		"spikes": _spikes(mb, rng, s, k, ripe)
		"spears": _spears(mb, rng, s, k, ripe)
		"aloe": _aloe(mb, rng, s, k, ripe)
		"potato": _potato(mb, rng, s, k, ripe)
		"carrot": _carrot(mb, rng, s, k, ripe)
		"onion": _onion(mb, rng, s, k, ripe)
		"ginger": _ginger(mb, rng, s, k, ripe)
		"vine": _vine(mb, rng, s, k, ripe)
		"bush_fruit": _bush_fruit(mb, rng, s, k, ripe)
		"strawberry": _strawberry(mb, rng, s, k, ripe)
		"cane_berry": _cane_berry(mb, rng, s, k, ripe)
		"shrub_berry": _shrub_berry(mb, rng, s, k, ripe)
		"coffee": _coffee(mb, rng, s, k, ripe)
		"grape": _grape(mb, rng, s, k, ripe)
		"bloom": _bloom(mb, rng, s, k, ripe)
		"gourd": _gourd(mb, rng, s, k, ripe)
		"pineapple": _pineapple(mb, rng, s, k, ripe)
		"leaves": _leaves(mb, rng, s, k, ripe)
		"cabbage": _cabbage(mb, rng, s, k, ripe)
		"broccoli": _broccoli(mb, rng, s, k, ripe)
		"artichoke": _artichoke(mb, rng, s, k, ripe)
		"tea": _tea(mb, rng, s, k, ripe)
		"clover": _clover(mb, rng, s, k, ripe)
		"cotton": _cotton(mb, rng, s, k, ripe)
		_:
			return false
	return true


# ---------------------------------------------------------------- whole plots


## A crop drawn a plot at a time, as the fields that read best are: a low carpet of dark leaves from edge to edge,
## so plots of one crop join into one field, and on it a few big pieces of produce, each plain to see ("plot"
## names the kind of piece, "count" how many; the rest of the form's numbers shape them). The produce is small
## and green until ripe, and a growing plot is tufts of leaves that have not yet closed over the soil.
static func _plot(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#3f8a32")
	_carpet(mb, rng, s, leaf, ripe)
	for at: Vector3 in _plot_spots(rng, int(s.get("count", 4)), 1.0 if ripe else 0.92):
		_piece(mb, rng, s, at, k, ripe, leaf)


## Upright produce (flowers, spikes, ears, roots) as a bunch: `n` pieces built upright one by one, fanned out
## across the picture from one foot (HARVEST_FAN apart) and leant toward the viewer (HARVEST_LEAN), so every head
## shows and none hides behind another, as a bunch is held up to be seen.
static func _bunch(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, n: int, leaf: Color) -> void:
	var lean := Basis(ACROSS, HARVEST_FLOWER_LEAN if str(s["plot"]) == "flowers" else HARVEST_LEAN)
	for i in n:
		var one := MeshBuilder.new()
		one.produce_scale = mb.produce_scale
		if str(s["plot"]) == "roots":
			_pulled(one, rng, s, leaf)
		else:
			_piece(one, rng, s, Vector3.ZERO, 1.0, true, leaf)
		var fan := Basis(TOWARD_VIEW, (i - (n - 1) / 2.0) * HARVEST_FAN)
		mb.add(one, Transform3D(lean * fan, Vector3.ZERO))


## A root crop pulled up, for its picture: the root itself below its tops, long and pointed when the form is tall
## (a carrot), round when not (an onion), PULLED_ROOT times the size it shows in the field (mostly underground).
static func _pulled(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, leaf: Color) -> void:
	# (all of it above the ground line: the crop shader shades whatever is below it as soil)
	var r := float(s.get("size", 0.024)) * PULLED_ROOT
	var tall := float(s.get("tall", 1.0))
	var root := r * tall * 3.0 if tall > 1.1 else r * tall * 2.0
	if tall > 1.1:
		mb.cone(Vector3.ZERO, 0.002, r, root, _p(rng.randf_range(0.85, 1.0)), 8)
		mb.ellipsoid(_up(root), Vector3(r, r * 0.35, r), _p(0.95), 8, 3)   # (its shoulder: the cone is open above)
	else:
		mb.ellipsoid(_up(root * 0.5), Vector3(r, r * tall, r), _p(rng.randf_range(0.85, 1.0)), 8, 5)
	for j in int(s.get("tops", 6)):
		var a := TAU * j / float(s.get("tops", 6)) + rng.randf() * 0.4
		var top := _ring(a, 0.03) + _up(root + float(s.get("top_h", 0.1)))
		mb.blade(_up(root), top, float(s.get("top_w", 0.014)) * PULLED_TOPS, leaf.darkened(0.15), leaf.lightened(0.2),
			_ring(a, 0.01))


## One piece of a plot's produce at `at` (a melon, a berry, an ear of grain, a flower...), by the form's "plot".
static func _piece(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, at: Vector3, k: float, ripe: bool,
		leaf: Color) -> void:
	match str(s["plot"]):
		"melons": _melon(mb, rng, s, at, ripe, leaf)
		"berries": _berry(mb, rng, at, ripe, leaf)
		"peppers": _pepper(mb, rng, at, ripe, leaf)
		"heads": _head(mb, rng, s, at, ripe, leaf)
		"stakes": _staked(mb, rng, at, k, ripe, leaf)
		"balls": _balls(mb, rng, s, at, ripe, leaf)
		"roots": _rooted(mb, rng, s, at, ripe, leaf)
		"ears": _ears(mb, rng, s, at, ripe, leaf)
		"spikes": _spike_tuft(mb, rng, s, at, ripe, leaf)
		"flowers": _flower(mb, rng, s, at, ripe, leaf)
		_: _leafy(mb, rng, at, ripe, leaf)


## A crop as its picture shows it (the market, the Barn, a recipe): its harvest, a few pieces of its ripe produce
## gathered close (HARVEST_PIECES: a triangle of three, or one in a ring of four), with no carpet of leaves and no
## soil under them, so a pumpkin reads as pumpkins and wheat as ears of wheat. False for a form that is not a plot.
static func harvest(mb: MeshBuilder, form: String, rng: RandomNumberGenerator) -> bool:
	var s := spec(form)
	if s.is_empty() or not s.has("plot"):
		return false
	mb.produce_scale = 1.0
	var leaf := _col(s, "leaf", "#3f8a32")
	var n := int(HARVEST_PIECES.get(str(s["plot"]), HARVEST_PIECES["default"]))
	if str(s["plot"]) in HARVEST_BUNCHED:
		_bunch(mb, rng, s, n, leaf)
		return true
	var size: Variant = s.get("size", 0.0)   # (a melon's is [x, y, z]; some forms give one number)
	var spread := float(size[0]) * 1.4 if size is Array and not (size as Array).is_empty() else HARVEST_SPREAD
	for i in n:
		var ring := n if n < 5 else 4   # (five: one in the middle of a ring of four)
		var at := Vector3.ZERO if (n == 5 and i == 0) else _ring(TAU * i / float(ring) + 0.5, spread)
		_piece(mb, rng, s, at, 1.0, true, leaf)
	return true


## The carpet: a dark floor (no soil shows through) and tufts of leaves all over it, a little past the plot's edge;
## while growing, fewer tufts and no floor. Its leaves are the form's ("leaf_w" wide, "leaf_len" long, "leaf_h"
## high: broad and flat for melons, thin and upright for grain, which turns to its "straw" when ripe).
static func _carpet(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, leaf: Color, ripe: bool) -> void:
	var col := _col(s, "straw", "#d8b85a") if ripe and s.has("straw") else leaf
	var w := float(s.get("leaf_w", 0.045))
	var reach := float(s.get("leaf_len", 0.05)) * (1.0 if ripe else 1.2)
	var h := float(s.get("leaf_h", 0.045))
	var n := TUFTS if ripe else TUFTS_YOUNG
	if ripe:
		mb.box(Transform3D(Basis().scaled(Vector3(PLOT * 2.0, 0.012, PLOT * 2.0)), _up(0.006)), col.darkened(0.5))
	for i in n:
		for j in n:
			var c := Vector3((i + 0.5) / n * 2.0 - 1.0, 0.0, (j + 0.5) / n * 2.0 - 1.0) * PLOT
			c += _ring(rng.randf() * TAU, 0.01)
			for l in 5:
				var a := TAU * l / 5.0 + rng.randf()
				mb.blade(c + _up(0.008), c + _ring(a, reach) + _up(h * rng.randf_range(0.5, 1.0)), w,
					col.darkened(0.3), col.lightened(0.06), _up(0.012))


## Where `n` pieces of produce sit on a plot: three or fewer in a ring, more on a loose grid.
static func _plot_spots(rng: RandomNumberGenerator, n: int, k: float) -> Array:
	var out := []
	if n <= 3:
		var turn := rng.randf() * TAU
		for i in n:
			out.append(_ring(turn + TAU * i / n, PLOT * 0.5 * k))
		return out
	var side := ceili(sqrt(float(n)))
	for i in n:
		var cell := (i * 7 + 3) % (side * side)   # (spread over the grid, the same every time)
		var c := Vector3((cell % side + 0.5) / side * 2.0 - 1.0, 0.0, (cell / side + 0.5) / side * 2.0 - 1.0)
		out.append(c * PLOT * 0.84 * k + _ring(rng.randf() * TAU, 0.012))
	return out


static func _v3(s: Dictionary, key: String, fallback: Vector3) -> Vector3:
	var a: Array = s.get(key, [])
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a.size() == 3 else fallback


## Something big lying on the leaves, along one way or the other ("size": long, high, wide): a striped melon
## ("bands"), a ribbed pumpkin ("ribs": lobes round a stalk), a marrow, a lump of potato.
static func _melon(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, at: Vector3, ripe: bool,
		leaf: Color) -> void:
	var along := rng.randf() < 0.5
	var size := _v3(s, "size", Vector3(0.074, 0.05, 0.052)) * (1.0 if ripe else 0.45)
	var r := size if along else Vector3(size.z, size.y, size.x)
	var c := at + _up(r.y * 0.85 + 0.012)
	var ribs := int(s.get("ribs", 0))
	for j in ribs:
		mb.ellipsoid(c + _ring(TAU * j / ribs, r.x * 0.42), Vector3(r.x * 0.62, r.y, r.z * 0.62),
			_p(0.92 - 0.06 * (j % 2)) if ripe else leaf.lightened(0.3), 7, 4)
	if ribs > 0:
		mb.cone(c + _up(r.y * 0.85), 0.011, 0.006, 0.03 if ripe else 0.012, BARK, 5)
		return
	mb.ellipsoid(c, r, _p(0.9) if ripe else leaf.lightened(0.3), 10, 6)
	var bands := int(s.get("bands", 3))
	for j in bands:
		var off := (j - (bands - 1) / 2.0) * 0.42
		var thin := 0.012 if ripe else 0.006
		var band := Vector3(thin if along else r.x * 1.03, r.y * 1.03, r.z * 1.03 if along else thin)
		mb.ellipsoid(c + Vector3(r.x * off if along else 0.0, 0.0, 0.0 if along else r.z * off), band,
			_p(0.5) if ripe else leaf, 8, 4)


## A fat berry sitting up on the leaves, point down, under its green cap.
static func _berry(mb: MeshBuilder, rng: RandomNumberGenerator, at: Vector3, ripe: bool, leaf: Color) -> void:
	var size := (1.0 if ripe else 0.5) * rng.randf_range(0.9, 1.1)
	var foot := at + _up(0.022)
	var pale := WHITE.lerp(leaf, 0.4)
	mb.cone(foot, 0.006 * size, 0.027 * size, 0.05 * size, _p(rng.randf_range(0.8, 1.0)) if ripe else pale, 7)
	mb.ellipsoid(foot + _up(0.05 * size), Vector3(0.027, 0.014, 0.027) * size, _p(0.85) if ripe else pale, 7, 3)
	for j in 4:
		var a := TAU * j / 4.0 + rng.randf()
		mb.blade(foot + _up(0.058 * size), foot + _ring(a, 0.024 * size) + _up(0.054 * size), 0.016, leaf,
			leaf.lightened(0.2))


## A blocky pepper standing among a few taller leaves, its stem on top.
static func _pepper(mb: MeshBuilder, rng: RandomNumberGenerator, at: Vector3, ripe: bool, leaf: Color) -> void:
	var size := (1.0 if ripe else 0.5) * rng.randf_range(0.9, 1.1)
	for j in 3:
		var a := TAU * j / 3.0 + rng.randf()
		mb.blade(at + _up(0.01), at + _ring(a, 0.05) + _up(0.085), 0.05, leaf.darkened(0.2), leaf.lightened(0.12), _up(0.01))
	var c := at + _up(0.03 + 0.036 * size)
	var col := _p(rng.randf_range(0.82, 1.0)) if ripe else leaf.lightened(0.3)
	mb.ellipsoid(c, Vector3(0.027, 0.038, 0.027) * size, col, 8, 5)
	for j in 3:
		mb.ellipsoid(c + _ring(TAU * j / 3.0, 0.012 * size) + _up(0.012 * size), Vector3(0.019, 0.03, 0.019) * size,
			col, 6, 4)
	mb.cone(c + _up(0.034 * size), 0.007, 0.004, 0.02 * size, STEM, 5)


## A big head in a cup of outer leaves ("size" across, "tall" for its height): round and wrapped (a cabbage),
## lumpy ("lumps": broccoli), or with a tuft on top ("crown": a pineapple).
static func _head(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, at: Vector3, ripe: bool,
		leaf: Color) -> void:
	for j in int(s.get("cup", 7)):
		var a := TAU * j / float(s.get("cup", 7)) + rng.randf() * 0.4
		mb.blade(at + _up(0.01), at + _ring(a, 0.08) + _up(0.045), 0.085, leaf.darkened(0.25), leaf.lightened(0.05),
			_up(0.03))
	var r := float(s.get("size", 0.056)) * (1.0 if ripe else 0.45)
	var tall := float(s.get("tall", 0.92))
	var c := at + _up(r * tall * 0.95 + 0.012)
	mb.ellipsoid(c, Vector3(r, r * tall, r), _p(0.95) if ripe else leaf.lightened(0.25), 10, 6)
	var lumps := int(s.get("lumps", 0))
	if ripe:
		for j in lumps:
			mb.ellipsoid(c + _ring(TAU * j / lumps, r * 0.6) + _up(r * 0.25), Vector3.ONE * r * 0.55,
				_p(0.78 + 0.14 * (j % 2)), 6, 4)
		for j in (2 if lumps == 0 else 0):   # the wrapped leaves of the head, a shade apart
			mb.ellipsoid(c + _ring(j * PI + 0.6, r * 0.22), Vector3(r * 0.9, r * tall * 1.01, r * 0.9), _p(0.78), 8, 5)
	for j in int(s.get("crown", 0)):
		mb.blade(c + _up(r * tall * 0.8), c + _ring(TAU * j / float(s["crown"]), r * 0.6) + _up(r * tall + 0.05), 0.022,
			leaf, leaf.lightened(0.2))


## A staked plant hung with big round fruit.
static func _staked(mb: MeshBuilder, rng: RandomNumberGenerator, at: Vector3, k: float, ripe: bool,
	leaf: Color) -> void:
	var h := 0.15 * k
	mb.cone(at, 0.006, 0.004, h, STAKE, 4)
	for j in 6:
		var a := j * 2.4 + rng.randf()
		var y := h * (0.25 + 0.12 * j)
		mb.blade(at + _up(y), at + _ring(a, 0.06) + _up(y + 0.02), 0.05, leaf.darkened(0.25), leaf.lightened(0.1),
			_up(-0.015))
	for j in 3:
		var c := at + _ring(TAU * j / 3.0 + rng.randf() * 0.5, 0.036) + _up(h * (0.3 + 0.25 * j))
		var r := (0.031 if ripe else 0.014) * rng.randf_range(0.9, 1.1)
		var col := _p(rng.randf_range(0.85, 1.0)) if ripe else leaf.lightened(0.3)
		mb.ellipsoid(c, Vector3(r, r * 0.92, r), col, 8, 5)
		mb.ellipsoid(c + _up(r * 0.9), Vector3(r * 0.5, r * 0.18, r * 0.5), leaf, 5, 3)


## A little bush: a few taller leaves, a stake if it climbs ("stake"), and its fruit in a cluster ("cluster" of
## them, each "size", "lift" up and "spread" out; a "bunch" hangs wide at the top and narrow below, as grapes do).
static func _balls(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, at: Vector3, ripe: bool,
		leaf: Color) -> void:
	var size := _v3(s, "size", Vector3.ONE * 0.02)
	var cluster := int(s.get("cluster", 4))
	var lift := float(s.get("lift", 0.06))
	var spread := float(s.get("spread", 0.03))
	var stake := float(s.get("stake", 0.0))
	if stake > 0.0:
		mb.cone(at, 0.006, 0.004, stake, STAKE, 4)
	for j in 4:
		var a := TAU * j / 4.0 + rng.randf()
		mb.blade(at + _up(0.01), at + _ring(a, 0.055) + _up(lift + 0.025), 0.05, leaf.darkened(0.2), leaf.lightened(0.12),
			_up(0.01))
	for j in cluster:
		var share := float(j) / cluster
		var c := at + _ring(TAU * share + rng.randf() * 0.5, spread) + _up(lift * rng.randf_range(0.7, 1.1))
		if bool(s.get("bunch", false)) or stake > 0.0:
			c = at + _ring(j * 2.4, spread * (0.3 + 0.7 * share)) + _up(lift * (0.35 + 0.65 * share))
		var col := _p(rng.randf_range(0.82, 1.0)) if ripe else leaf.lightened(0.3)
		mb.ellipsoid(c, size * (1.0 if ripe else 0.5) * rng.randf_range(0.9, 1.1), col, 7, 4)


## A root showing its shoulder in the soil under a tuft of tops (a carrot, an onion).
static func _rooted(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, at: Vector3, ripe: bool,
		leaf: Color) -> void:
	var r := float(s.get("size", 0.024)) * (1.0 if ripe else 0.5)
	mb.ellipsoid(at + _up(0.022 + r * 0.5), Vector3(r, r * float(s.get("tall", 1.0)), r),
		_p(rng.randf_range(0.85, 1.0)) if ripe else leaf.lightened(0.3), 8, 5)
	for j in int(s.get("tops", 6)):
		var a := TAU * j / float(s.get("tops", 6)) + rng.randf() * 0.4
		mb.blade(at + _up(0.02 + r), at + _ring(a, 0.03) + _up(float(s.get("top_h", 0.1))), float(s.get("top_w", 0.014)),
			leaf.darkened(0.15), leaf.lightened(0.2), _ring(a, 0.01))


## A tuft of grain: stalks ("tall", leaning by "droop"), each with a plump ear.
static func _ears(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, at: Vector3, ripe: bool,
		leaf: Color) -> void:
	var col := _col(s, "straw", "#d8b85a") if ripe else leaf
	var droop := float(s.get("droop", 0.0))
	for j in 5:
		var a := TAU * j / 5.0 + rng.randf()
		var foot := at + _ring(a, 0.02)
		var tip := foot + _ring(a, 0.02 + droop) + _up(float(s.get("tall", 0.12)) * rng.randf_range(0.85, 1.0))
		mb.blade(foot, tip, 0.012, col.darkened(0.25), col, _ring(a, droop * 0.5))
		var r := 0.014 if ripe else 0.008
		mb.ellipsoid(tip + _up(0.02), Vector3(r, r * 2.3, r),
			_p(0.85 + 0.1 * (j % 2)) if ripe else leaf.lightened(0.15), 6, 4)


## A tuft of upright stems ("stems" of them, "tall"), each a spike of buds at its top ("buds", each "bud" across:
## lavender, a corn stalk and its cobs), or a "cane" that is produce from foot to tip (sugarcane, asparagus).
static func _spike_tuft(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, at: Vector3, ripe: bool,
		leaf: Color) -> void:
	var stems := int(s.get("stems", 3))
	var buds := int(s.get("buds", 4))
	var bud := float(s.get("bud", 0.016))
	var cane := bool(s.get("cane", false))
	for j in stems:
		var foot := at + _ring(TAU * j / stems + rng.randf(), 0.025 if stems > 1 else 0.0)
		var h := float(s.get("tall", 0.13)) * rng.randf_range(0.85, 1.0)
		if not cane:
			mb.cone(foot, 0.007, 0.004, h, STEM, 4)
		for b in buds:
			var y := h * (b + 0.5) / buds if cane else h - b * bud * 1.5
			var r := bud if cane else bud * (0.65 + 0.12 * b)
			var col := _p(0.95 - 0.12 * (b % 2)) if ripe else leaf.lightened(0.15)
			mb.ellipsoid(foot + _up(y), Vector3(r, h / buds * 0.52 if cane else r * 1.15, r), col, 6, 4)
		for l in (3 if cane else 0):
			var a := TAU * l / 3.0 + rng.randf()
			mb.blade(foot + _up(h), foot + _ring(a, 0.05) + _up(h + 0.01), 0.02, leaf, leaf.lightened(0.2), _up(-0.02))


## A big flower on a short stem, open to the sky: petals round a disc, a cup (a tulip) or a rose's layers, by the
## form's "style" and petal numbers; "big" is how much larger than those numbers it is drawn.
static func _flower(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, at: Vector3, ripe: bool,
		leaf: Color) -> void:
	var h := float(s.get("tall", 0.08)) * rng.randf_range(0.85, 1.0)
	var top := at + _up(h)
	var big := float(s.get("big", 1.5))
	mb.cone(at, 0.007, 0.005, h, STEM, 4)
	if not ripe:
		mb.ellipsoid(top, Vector3(0.015, 0.025, 0.015), leaf.lightened(0.1), 5, 3)
		return
	match str(s.get("style", "radial")):
		"cup":
			for j in 3:
				mb.ellipsoid(top + _ring(TAU * j / 3.0, 0.012 * big) + _up(0.02 * big), Vector3(0.018, 0.035, 0.014) * big,
					_p(0.95 - 0.05 * j), 6, 4)
		"rose":
			for l in 3:
				mb.ellipsoid(top + _up(0.01 * l * big), Vector3(0.03 - 0.008 * l, 0.02, 0.03 - 0.008 * l) * big,
					_p(0.7 + 0.12 * l), 7, 4)
			for j in 5:
				mb.ellipsoid(top + _ring(TAU * j / 5.0, 0.025 * big) + _up(0.004), Vector3.ONE * 0.013 * big, _p(0.8), 5, 3)
		_:
			var n := int(s.get("petals", 10))
			var disc := float(s.get("disc", 0.018)) * big
			for j in n:
				var out := _ring(TAU * j / n + rng.randf() * 0.1, 1.0)
				mb.blade(top + out * disc * 0.6, top + out * (disc + float(s.get("petal_len", 0.04)) * big) + _up(0.012),
					float(s.get("petal_w", 0.014)) * big, _p(0.95), _p(0.82))
			mb.ellipsoid(top + _up(0.006), Vector3(disc, disc * 0.45, disc), _col(s, "disc_col", "#f2c230"), 7, 4)


## A crop that is its leaves (spinach, tea, clover): a full tuft of them, the crop's colour when grown.
static func _leafy(mb: MeshBuilder, rng: RandomNumberGenerator, at: Vector3, ripe: bool, leaf: Color) -> void:
	for j in 8:
		var a := TAU * j / 8.0 + rng.randf() * 0.4
		var shade := 0.7 + 0.3 * (j % 3) / 2.0
		var col := _p(shade) if ripe else leaf.lerp(leaf.lightened(0.3), (j % 3) / 2.0)
		mb.blade(at + _up(0.01), at + _ring(a, 0.03 + 0.02 * (j % 2)) + _up(0.06 + 0.02 * (j % 3)), 0.055, col, col,
			_up(0.02))


# ---------------------------------------------------------------- helpers


static func _p(shade: float) -> Color:
	return Color(shade, shade, shade, 0.0)


static func _col(s: Dictionary, key: String, fallback: String) -> Color:
	return Color.html(str(s.get(key, fallback)))


static func _span(s: Dictionary, rng: RandomNumberGenerator, key: String, k: float) -> float:
	var r: Array = s.get(key, [0.2, 0.3])
	return rng.randf_range(float(r[0]), float(r[1])) * k


static func _ring(a: float, r: float) -> Vector3:
	return Vector3(cos(a), 0.0, sin(a)) * r


static func _up(y: float) -> Vector3:
	return Vector3(0.0, y, 0.0)


# ---------------------------------------------------------------- grains and canes


## Wheat, rye, rice, oats: slender stalks, straw-coloured when grown, each with a head (awned, drooping or hung
## with grains by the numbers in the data).
static func _cereal(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#6f9a3a")
	var straw := _col(s, "straw", "#d8b85a")
	var count := int(s.get("count", 9))
	var head := float(s.get("head", 0.04))
	var droop := float(s.get("droop", 0.0))
	var hang := int(s.get("hang", 0))
	var awn := int(s.get("awn", 0))
	for i in count:
		var a := TAU * i / count + rng.randf() * 0.5
		var out := _ring(a, 1.0)
		var base := out * rng.randf_range(0.0, 0.035)
		var h := _span(s, rng, "height", k)
		var tip := base + out * (0.03 + droop) * k + _up(h)
		var low := leaf.darkened(0.25) if not ripe else straw.darkened(0.25)
		var high := leaf.lightened(0.2) if not ripe else straw
		mb.blade(base, tip, 0.012, low, high, out * droop * 0.5)
		mb.blade(base + _up(h * 0.2), base + out * 0.08 * k + _up(h * 0.62), 0.02, low, leaf if not ripe else straw,
			out * 0.02)
		if not ripe:
			mb.ellipsoid(tip + _up(0.012), Vector3(0.007, 0.02, 0.007), leaf.lightened(0.15), 4, 3)
			continue
		if hang > 0:
			for j in hang:
				mb.ellipsoid(tip + out * 0.012 * (j + 1) + _up(0.01 - 0.014 * j), Vector3(0.01, 0.015, 0.01),
					_p(0.9), 5, 3)
		else:
			mb.ellipsoid(tip + _up(head * 0.5), Vector3(0.011, head * 0.5, 0.011), _p(0.85), 5, 3)
		for j in awn:
			var b := TAU * j / awn + a
			mb.blade(tip + _up(head * 0.9), tip + _ring(b, 0.014) + _up(head * 1.9), 0.004, straw, straw)


static func _bean(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#4f9a36")
	mb.cone(Vector3.ZERO, 0.012, 0.006, 0.2 * k, STEM, 5)
	for i in 5:
		var a := i * 2.4 + rng.randf() * 0.3
		var y := (0.05 + 0.035 * i) * k
		var at := _ring(a, 0.055 * k) + _up(y)
		mb.blade(_up(y * 0.9), at, 0.008, STEM, STEM, _up(0.01))
		for j in 3:
			mb.ellipsoid(at + _ring(a + (j - 1) * 0.55, 0.026) + _up(0.004 * j), Vector3(0.03, 0.008, 0.022),
				leaf.lerp(leaf.lightened(0.25), j / 3.0), 6, 3)
		if ripe:
			for j in 2:
				mb.ellipsoid(at + _ring(a + j * 1.4, 0.015) + _up(-0.03), Vector3(0.008, 0.03, 0.008), _p(0.85), 5, 3)


## Tall stalk, long arching leaves, ripe cobs in their husks and a tassel on top.
static func _corn(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#4f9a36")
	var h := 0.55 * k
	mb.cone(Vector3.ZERO, 0.016, 0.008, h, STEM, 6)
	for i in 7:
		var a := i * 2.4 + rng.randf() * 0.3
		var y := h * (0.16 + 0.1 * i)
		mb.blade(_up(y), _ring(a, (0.2 - 0.012 * i) * k) + _up(y + 0.04), 0.045, leaf.darkened(0.3),
			leaf.lightened(0.2), _up(-0.07))
	if ripe:
		for i in 2:
			var a := PI * i + 0.8
			var y := h * (0.46 + 0.1 * i)
			mb.ellipsoid(_ring(a, 0.03) + _up(y + 0.05), Vector3(0.018, 0.06, 0.018), _p(0.9), 6, 3)
			for j in 3:
				mb.blade(_ring(a, 0.022) + _up(y), _ring(a + 0.5 + j * 0.4, 0.035) + _up(y + 0.11), 0.03,
					leaf.darkened(0.1), leaf.lightened(0.15))
	for j in 5:
		mb.blade(_up(h), _ring(TAU * j / 5.0, 0.05 * k) + _up(h + 0.1), 0.008, STRAW, STRAW, _up(0.02))


## Jointed canes (sugarcane, bamboo) with a crown of arching leaves; ripe canes take the crop's colour.
static func _cane(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#6fa83a")
	var count := int(s.get("count", 4))
	var nodes := int(s.get("nodes", 6))
	var w := float(s.get("width", 0.015))
	for i in count:
		var a := TAU * i / count + rng.randf() * 0.5
		var off := _ring(a, 0.03)
		var lean := _ring(a, 0.03)
		var h := _span(s, rng, "height", k)
		var seg := h / nodes
		for n in nodes:
			var shade := 0.82 if n % 2 == 0 else 0.7
			var col := _p(shade) if ripe else STEM.lerp(leaf, 0.4 + 0.1 * (n % 2))
			var p0 := off + lean * (float(n) / nodes) + _up(n * seg)
			mb.cone(p0, w, w * 0.95, seg * 0.94, col, 6)
			mb.ellipsoid(p0 + _up(seg * 0.97), Vector3(w * 1.3, w * 0.45, w * 1.3), col.darkened(0.25), 5, 3)
		var top := off + lean + _up(h)
		for j in int(s.get("leaves", 6)):
			var b := TAU * j / float(s.get("leaves", 6)) + rng.randf() * 0.4
			mb.blade(top, top + _ring(b, 0.13 * k) + _up(0.05 * k), 0.028, leaf.darkened(0.25), leaf.lightened(0.2),
				_up(-0.06))


# ---------------------------------------------------------------- spikes, roots


## Lavender, lilac, gladiolus, amaranth: stems topped with a column of buds that open when ripe.
static func _spikes(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#4f8a36")
	var count := int(s.get("count", 4))
	var bud_len := float(s.get("bud_len", 0.08))
	var bud_r := float(s.get("bud_r", 0.014))
	var droop := float(s.get("droop", 0.0))
	var sword := bool(s.get("sword", false))
	for j in 6:
		var b := TAU * j / 6.0 + rng.randf() * 0.4
		var reach := 0.1 if sword else 0.07
		mb.blade(_ring(b, 0.012), _ring(b, reach * k) + _up((0.18 if sword else 0.12) * k),
			0.034 if sword else 0.012, leaf.darkened(0.25), leaf.lightened(0.15), _ring(b, 0.012))
	for i in count:
		var a := TAU * i / count + rng.randf() * 0.5
		var off := _ring(a, 0.03)
		var h := _span(s, rng, "height", k)
		mb.cone(off, 0.006, 0.004, h, STEM, 4)
		var nb := maxi(int(bud_len / (bud_r * 1.8)), 3)
		for j in nb:
			var u := float(j) / nb
			var at := off + _ring(a + j * 2.1, bud_r * 0.8) + _ring(a, droop * u * u * 3.0) + _up(h - u * bud_len)
			var r := bud_r * (1.0 - 0.45 * u)
			if ripe:
				mb.ellipsoid(at, Vector3(r, r * 0.9, r), _p(0.95 - 0.04 * j), 5, 3)
			else:
				mb.ellipsoid(at, Vector3(r * 0.6, r * 0.8, r * 0.6), leaf.lightened(0.1), 4, 3)


## Asparagus: spears with scaly tips when ripe, a feathery fern when still growing.
static func _spears(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#6fa83a")
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.5
		var off := _ring(a, 0.04)
		var h := rng.randf_range(0.12, 0.2) * k
		if ripe:
			mb.cone(off, 0.009, 0.007, h, _p(0.7), 5)
			mb.cone(off + _up(h), 0.009, 0.0, 0.03, _p(0.88), 5)
		else:
			mb.cone(off, 0.006, 0.004, h, leaf, 4)
			for j in 6:
				var b := TAU * j / 6.0
				mb.blade(off + _up(h * 0.5), off + _ring(b, 0.05) + _up(h * 0.5 + 0.06), 0.008, leaf.darkened(0.1),
					leaf.lightened(0.2))


static func _aloe(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#6a9a58")
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.3
		mb.blade(_up(0.01), _ring(a, 0.1 * k) + _up(0.12 * k), 0.055, leaf.darkened(0.15), leaf.lightened(0.12),
			_ring(a, 0.02) + _up(0.03))
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		mb.blade(_up(0.02), _ring(a, 0.03 * k) + _up(0.15 * k), 0.04, leaf, leaf.lightened(0.15))
	if ripe:
		mb.cone(Vector3.ZERO, 0.01, 0.005, 0.34 * k, STEM, 4)
		for j in 6:
			mb.ellipsoid(_ring(j * 2.2, 0.018) + _up(0.24 + 0.016 * j), Vector3(0.012, 0.022, 0.012),
				_p(0.95 - 0.05 * j), 5, 3)


static func _potato(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#3f8a32")
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.4
		var at := _ring(a, 0.055) + _up(0.12 * k)
		mb.blade(Vector3.ZERO, at, 0.01, STEM, STEM, _up(0.01))
		for j in 4:
			mb.ellipsoid(at + _ring(a + j * 1.6, 0.025) + _up(0.008 * j), Vector3(0.032, 0.01, 0.02),
				leaf.lerp(leaf.lightened(0.25), j / 4.0), 5, 3)
		if ripe and i % 2 == 0:
			mb.ellipsoid(at + _up(0.03), Vector3(0.015, 0.008, 0.015), WHITE, 5, 3)
			mb.ellipsoid(_ring(a, 0.05) + _up(0.008), Vector3(0.03, 0.018, 0.025), _p(0.8), 5, 3)


static func _carrot(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#4f9a36")
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.3
		mb.blade(_up(0.005), _ring(a, 0.045 * k) + _up(0.17 * k), 0.012, STEM, leaf, _ring(a, 0.012))
		for j in 3:
			var t := 0.4 + 0.2 * j
			var p0 := _ring(a, 0.045 * k * t) + _up(0.17 * k * t)
			mb.blade(p0, p0 + _ring(a + 1.5, 0.03) + _up(0.03), 0.012, leaf, leaf.lightened(0.2))
			mb.blade(p0, p0 + _ring(a - 1.5, 0.03) + _up(0.03), 0.012, leaf, leaf.lightened(0.2))
	if ripe:
		mb.ellipsoid(_up(0.008), Vector3(0.032, 0.02, 0.032), _p(0.9), 6, 3)


static func _onion(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#5a9a4a")
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.3
		mb.blade(_ring(a, 0.014), _ring(a, 0.04 * k) + _up(0.22 * k * rng.randf_range(0.8, 1.1)), 0.014,
			leaf.darkened(0.1), leaf.lightened(0.2), _ring(a, 0.015))
	if ripe:
		mb.ellipsoid(_up(0.02), Vector3(0.04, 0.03, 0.04), _p(0.85), 7, 4)
		mb.cone(_up(0.04), 0.01, 0.006, 0.03, STRAW, 5)
	else:
		mb.ellipsoid(_up(0.012), Vector3(0.02, 0.015, 0.02), leaf.lightened(0.35), 5, 3)


static func _ginger(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#4f9a36")
	for i in 8:
		var a := TAU * i / 8.0 + rng.randf() * 0.3
		var h := 0.2 * k * (0.7 + 0.3 * (i % 2))
		mb.blade(_ring(a, 0.012), _ring(a, 0.05 * k) + _up(h), 0.04, leaf.darkened(0.15), leaf.lightened(0.15),
			_ring(a, 0.012))
	if ripe:
		for i in 4:
			mb.ellipsoid(_ring(i * 1.6, 0.03) + _up(0.008), Vector3(0.03, 0.015, 0.02), _p(0.85), 5, 3)


# ---------------------------------------------------------------- vines, bushes, berries


## Peas and tomatoes climbing a stake, cucumbers sprawling on the ground.
static func _vine(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#3f8a32")
	var stake := float(s.get("stake", 0.0))
	var fruit := str(s.get("fruit", "round"))
	var fruits := int(s.get("fruits", 4))
	var h := (stake if stake > 0.0 else 0.14) * k
	if stake > 0.0:
		mb.cone(Vector3.ZERO, 0.005, 0.003, stake * k, STAKE, 4)
	mb.cone(Vector3.ZERO, 0.008, 0.004, h, STEM, 5)
	var n := 9
	for i in n:
		var a := i * 2.4 + rng.randf() * 0.3
		var y := h * (0.12 + 0.85 * i / n)
		var reach := (0.05 if stake > 0.0 else 0.06 + 0.07 * (1.0 - float(i) / n))
		mb.blade(_up(y), _ring(a, reach) + _up(y + 0.03), 0.05, leaf.darkened(0.25), leaf.lightened(0.12), _up(-0.025))
	if not ripe:
		return
	for j in fruits:
		var a := j * 2.0 + 0.5
		var y := h * (0.25 + 0.5 * j / fruits)
		var at := _ring(a, 0.05) + _up(y)
		match fruit:
			"round":
				mb.ellipsoid(at, Vector3(0.03, 0.03, 0.03), _p(0.9), 6, 4)
				mb.cone(at + _up(0.025), 0.016, 0.004, 0.012, leaf, 5)
			"pod":
				mb.ellipsoid(at - _up(0.03), Vector3(0.008, 0.035, 0.008), _p(0.9), 5, 3)
			_:
				mb.ellipsoid(_ring(a, 0.09) + _up(0.02), Vector3(0.045, 0.016, 0.016), _p(0.85), 6, 3)


## Eggplant (big glossy leaves, hanging teardrops) and peppers (small leaves, many pods).
static func _bush_fruit(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#3f7f32")
	var leaf_w := float(s.get("leaf_w", 0.05))
	mb.cone(Vector3.ZERO, 0.012, 0.006, 0.1 * k, STEM, 5)
	for i in 10:
		var a := i * 2.4 + rng.randf() * 0.3
		var y := (0.04 + 0.009 * i) * k
		mb.blade(_up(y), _ring(a, 0.1 * k) + _up(y + 0.05), leaf_w, leaf.darkened(0.25), leaf.lightened(0.1), _up(-0.03))
	var fruit := str(s.get("fruit", "cone"))
	for j in int(s.get("fruits", 3)):
		var at := _ring(j * 2.1 + 0.4, 0.06) + _up((0.1 if fruit == "teardrop" else 0.09 + 0.03 * (j % 3)) * k)
		if not ripe:
			mb.ellipsoid(at, Vector3(0.01, 0.012, 0.01), leaf.lightened(0.3), 4, 3)
		elif fruit == "teardrop":
			mb.ellipsoid(at - _up(0.03), Vector3(0.03, 0.05, 0.03), _p(0.9), 7, 4)
			mb.cone(at + _up(0.008), 0.022, 0.01, 0.015, leaf, 6)
		else:
			mb.cone(at - _up(0.05), 0.003, 0.016, 0.05, _p(0.9), 6)


static func _strawberry(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#4f9a36")
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.4
		var at := _ring(a, 0.055 * k) + _up(0.035 * k)
		mb.blade(_up(0.01), at, 0.008, STEM, STEM)
		for j in 3:
			mb.ellipsoid(at + _ring(a + (j - 1) * 0.7, 0.022) + _up(0.004 * j), Vector3(0.03, 0.007, 0.024),
				leaf.lerp(leaf.lightened(0.25), j / 3.0), 6, 3)
	for j in 6:
		var at := _ring(j * 1.05 + 0.2, 0.085) + _up(0.02)
		if ripe:
			mb.cone(at, 0.004, 0.018, 0.036, _p(0.95), 6)
			mb.ellipsoid(at + _up(0.036), Vector3(0.016, 0.005, 0.016), leaf, 5, 3)
		elif j < 3:
			mb.ellipsoid(at + _up(0.01), Vector3(0.014, 0.005, 0.014), WHITE, 5, 3)
			mb.ellipsoid(at + _up(0.015), Vector3(0.005, 0.004, 0.005), Color("#f2c230"), 4, 3)


## Raspberries and blackberries: arching canes with small leaves and clusters of bumpy berries at the tips.
static func _cane_berry(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#4f8a36")
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf() * 0.5
		var tip := _ring(a, 0.1 * k) + _up(0.22 * k)
		mb.blade(_ring(a, 0.01), tip, 0.012, BARK, BARK.lightened(0.1), _ring(a, 0.04))
		for j in 4:
			var t := 0.3 + 0.18 * j
			var p0 := _ring(a, 0.1 * k * t) + _up(0.22 * k * t)
			mb.blade(p0, p0 + _ring(a + 1.4 * (1 if j % 2 == 0 else -1), 0.05) + _up(0.015), 0.03, leaf.darkened(0.2),
				leaf.lightened(0.15))
		if ripe:
			for c in 3:
				var at := tip - _ring(a, 0.02 * c) - _up(0.04 * c)
				for b in 4:
					mb.ellipsoid(at + _ring(b * 1.6, 0.01) + _up(0.008 * (b % 2)), Vector3(0.012, 0.012, 0.012),
						_p(0.9), 5, 3)


## Blueberry, cranberry, elderberry: a woody shrub with small leaves and clusters of round berries.
static func _shrub_berry(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#3f7a32")
	for i in 5:
		var a := TAU * i / 5.0 + rng.randf() * 0.4
		mb.blade(_ring(a, 0.01), _ring(a, 0.06 * k) + _up(0.15 * k), 0.01, BARK, BARK, _ring(a, 0.01))
	for i in 14:
		var a := i * 2.4 + rng.randf() * 0.3
		var at := _ring(a, rng.randf_range(0.02, 0.09) * k) + _up(rng.randf_range(0.08, 0.19) * k)
		mb.ellipsoid(at, Vector3(0.03, 0.02, 0.03), leaf.lerp(leaf.lightened(0.3), rng.randf()), 5, 3)
	if ripe:
		for j in 5:
			var at := _ring(j * 1.3 + 0.3, 0.095 * k) + _up((0.09 + 0.02 * (j % 3)) * k)
			for b in 3:
				mb.ellipsoid(at + _ring(b * 2.1, 0.012) + _up(0.01 * (b % 2)), Vector3(0.013, 0.013, 0.013),
					_p(0.9), 5, 3)


static func _coffee(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#2f6b24")
	mb.cone(Vector3.ZERO, 0.015, 0.008, 0.25 * k, BARK, 6)
	for t in 4:
		var y := (0.09 + 0.045 * t) * k
		for j in 4:
			var a := j * TAU / 4.0 + t * 0.8
			mb.blade(_up(y), _ring(a, (0.12 - 0.015 * t) * k) + _up(y + 0.01), 0.045, leaf.darkened(0.2),
				leaf.lightened(0.1), _up(-0.015))
			if ripe:
				mb.ellipsoid(_ring(a, 0.05 * k) + _up(y - 0.006), Vector3(0.012, 0.012, 0.012), _p(0.9), 5, 3)
				mb.ellipsoid(_ring(a + 0.3, 0.056 * k) + _up(y - 0.012), Vector3(0.011, 0.011, 0.011), _p(0.8), 5, 3)


static func _grape(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#5f9a3a")
	mb.cone(Vector3.ZERO, 0.02, 0.012, 0.2 * k, BARK, 6)
	for i in 7:
		var a := i * 2.4 + rng.randf() * 0.3
		mb.blade(_up(0.2 * k), _ring(a, 0.11 * k) + _up(0.22 * k), 0.09, leaf.darkened(0.25), leaf, _up(-0.03))
	for c in 3:
		var at := _ring(c * 2.1 + 0.5, 0.055 * k) + _up(0.19 * k)
		for l in 4:
			var n := maxi(4 - l, 1)
			var r := 0.026 * (1.0 - l * 0.2)
			for m in n:
				var col := _p(0.9) if ripe else leaf.lightened(0.2)
				mb.ellipsoid(at - _up(0.022 * l) + _ring(m * TAU / n, r * 0.6), Vector3.ONE * (0.012 if ripe else 0.007),
					col, 5, 3)


# ---------------------------------------------------------------- blooms and gourds


## One builder for the flowers: how many stems, how tall, and how the head is made (radial petals round a disc,
## a trumpet, a cup, a star of curving petals, or a layered rose).
static func _bloom(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#4f9a36")
	var stems := int(s.get("stems", 3))
	var style := str(s.get("style", "radial"))
	for i in stems:
		var a := TAU * i / stems + rng.randf() * 0.6
		var off := _ring(a, 0.03 if stems > 1 else 0.0)
		var h := _span(s, rng, "height", k)
		mb.cone(off, 0.007, 0.004, h, STEM, 4)
		_bloom_leaves(mb, str(s.get("leaf_kind", "grass")), off, a, h, leaf)
		var top := off + _up(h)
		if not ripe:
			mb.ellipsoid(top, Vector3(0.015, 0.025, 0.015), leaf.lightened(0.1), 5, 3)
			continue
		match style:
			"radial":
				_radial_head(mb, s, top, a)
			"trumpet":
				_petals(mb, s, top, a, 0.0)
				mb.cone(top - _up(0.01), 0.01, 0.024, 0.05, _p(0.75), 7)
			"cup":
				for j in 3:
					mb.ellipsoid(top + _ring(TAU * j / 3.0, 0.012) + _up(0.02), Vector3(0.018, 0.035, 0.014),
						_p(0.95 - 0.05 * j), 6, 4)
			"star":
				_petals(mb, s, top, a, 0.02)
				for j in 3:
					mb.blade(top, top + _ring(TAU * j / 3.0, 0.02) + _up(0.05), 0.004, Color("#8a3a1a"), Color("#f2c230"))
			_:
				for l in 3:
					mb.ellipsoid(top + _up(0.01 * l), Vector3(0.03 - 0.008 * l, 0.02, 0.03 - 0.008 * l),
						_p(0.7 + 0.12 * l), 7, 4)
				for j in 5:
					mb.ellipsoid(top + _ring(TAU * j / 5.0, 0.025) + _up(0.004), Vector3(0.014, 0.012, 0.014),
						_p(0.8), 5, 3)


static func _bloom_leaves(mb: MeshBuilder, kind: String, off: Vector3, a: float, h: float, leaf: Color) -> void:
	match kind:
		"broad":
			for j in 2:
				var b := a + 1.0 + j * PI
				mb.blade(off + _up(h * 0.3), off + _ring(b, 0.09) + _up(h * 0.3 + 0.05), 0.06, leaf.darkened(0.25), leaf,
					_up(-0.02))
		"sword":
			for j in 2:
				mb.blade(off, off + _ring(a + 0.8 + j * PI, 0.04) + _up(h * 0.7), 0.025, leaf.darkened(0.2),
					leaf.lightened(0.15), _ring(a + 0.8 + j * PI, 0.015))
		_:
			for j in 3:
				mb.blade(off, off + _ring(a + j * 2.1, 0.06) + _up(h * 0.5), 0.012, leaf.darkened(0.2),
					leaf.lightened(0.15), _ring(a + j * 2.1, 0.012))


## Petals round a disc, the head tilted toward the camera by `tilt`.
static func _radial_head(mb: MeshBuilder, s: Dictionary, top: Vector3, a: float) -> void:
	var tilt := float(s.get("tilt", 0.0))
	var disc := float(s.get("disc", 0.03))
	var axis := Vector3(sin(tilt) * cos(a), cos(tilt), sin(tilt) * sin(a)).normalized()
	var u := axis.cross(Vector3.UP)
	u = u.normalized() if u.length() > 0.01 else Vector3.RIGHT
	var v := axis.cross(u)
	var n := int(s.get("petals", 12))
	for j in n:
		var b := TAU * j / n
		var dir := u * cos(b) + v * sin(b)
		mb.blade(top + dir * disc * 0.7, top + dir * (disc + float(s.get("petal_len", 0.03))) + axis * 0.008,
			float(s.get("petal_w", 0.01)), _p(0.95), _p(0.85))
	mb.ellipsoid(top + axis * disc * 0.3, Vector3.ONE * disc * 0.85, _col(s, "disc_col", "#4a3018"), 7, 4)


## A flat ring of petals (a daffodil's back petals, a lily's star).
static func _petals(mb: MeshBuilder, s: Dictionary, top: Vector3, a: float, curl: float) -> void:
	var n := int(s.get("petals", 6))
	for j in n:
		var b := TAU * j / n + a
		mb.blade(top, top + _ring(b, float(s.get("petal_len", 0.04))) + _up(curl), float(s.get("petal_w", 0.02)),
			_p(0.8), _p(0.98), _up(curl))


static func _gourd(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#3f7f32")
	for i in 5:
		var a := TAU * i / 5.0 + rng.randf() * 0.5
		mb.blade(_up(0.01), _ring(a, 0.16 * k) + _up(0.08), 0.09, leaf.darkened(0.25), leaf, _up(0.03))
	var c := Vector3(0.03, 0.06, 0.02)
	if not ripe:
		mb.ellipsoid(c - _up(0.02), Vector3(0.03, 0.025, 0.03), leaf.lightened(0.2), 6, 3)
		return
	match str(s.get("fruit", "ribbed")):
		"ribbed":
			for j in 6:
				mb.ellipsoid(c + _ring(TAU * j / 6.0, 0.03), Vector3(0.04, 0.065, 0.04), _p(0.9 - 0.04 * (j % 2)), 7, 4)
			mb.cone(c + _up(0.1), 0.012, 0.006, 0.04, BARK, 5)
		"oval":
			mb.ellipsoid(c, Vector3(0.11, 0.075, 0.075), _p(0.85), 10, 6)
			for j in 3:
				mb.ellipsoid(c + Vector3(0.0, 0.0, (j - 1) * 0.05), Vector3(0.113, 0.077, 0.012), _p(0.5), 8, 4)
		"crook":
			mb.ellipsoid(c + Vector3(0.03, 0.0, 0.0), Vector3(0.045, 0.04, 0.045), _p(0.9), 7, 4)
			for j in 4:
				mb.ellipsoid(c + Vector3(0.03 - 0.008 * j, 0.03 + 0.025 * j, -0.01 * j),
					Vector3(0.022 - 0.003 * j, 0.027, 0.022 - 0.003 * j), _p(0.9), 6, 3)
		"long":
			mb.ellipsoid(c - _up(0.02), Vector3(0.1, 0.035, 0.035), _p(0.7), 9, 4)
			mb.cone(c + Vector3(-0.1, 0.0, 0.0), 0.01, 0.006, 0.02, BARK, 5)
		_:
			mb.ellipsoid(c - _up(0.01), Vector3(0.07, 0.032, 0.07), _p(0.95), 9, 4)
			for j in 8:
				mb.ellipsoid(c - _up(0.01) + _ring(TAU * j / 8.0, 0.066), Vector3(0.018, 0.02, 0.018), _p(0.85), 5, 3)


static func _pineapple(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#6f9a3a")
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.3
		mb.blade(_up(0.01), _ring(a, 0.1 * k) + _up(0.17 * k), 0.03, leaf.darkened(0.25), leaf.lightened(0.15),
			_ring(a, 0.02))
	if ripe:
		mb.ellipsoid(_up(0.09), Vector3(0.04, 0.06, 0.04), _p(0.9), 8, 5)
		for j in 6:
			mb.blade(_up(0.145), _ring(TAU * j / 6.0, 0.02) + _up(0.21), 0.015, leaf, leaf.lightened(0.2))


# ---------------------------------------------------------------- leaf crops


## Spinach, basil, lemon balm: a tuft of small upright leaves, the produce when grown.
static func _leaves(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#4f9a36")
	for i in 12:
		var a := TAU * i / 12.0 + rng.randf() * 0.3
		var shade := 0.65 + 0.35 * (i % 3) / 2.0
		var col := _p(shade) if ripe else leaf.lerp(leaf.lightened(0.3), (i % 3) / 2.0)
		mb.blade(Vector3.ZERO, _ring(a, (0.04 + 0.03 * (i % 2)) * k) + _up((0.1 + 0.03 * (i % 3)) * k), 0.06, col, col,
			_up(0.02))


static func _cabbage(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#6fa856")
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.3
		mb.blade(_up(0.01), _ring(a, 0.1 * k) + _up(0.04), 0.09, leaf.darkened(0.15), leaf, _up(0.04))
	if ripe:
		mb.ellipsoid(_up(0.06), Vector3(0.065, 0.06, 0.065), _p(0.95), 9, 6)
	else:
		mb.ellipsoid(_up(0.025), Vector3(0.025, 0.025, 0.025) * (0.5 + k), leaf.lightened(0.25), 6, 4)


static func _broccoli(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#4f8a36")
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.3
		mb.blade(_up(0.01), _ring(a, 0.12 * k) + _up(0.09 * k), 0.07, leaf.darkened(0.2), leaf.lightened(0.1), _up(0.03))
	mb.cone(Vector3.ZERO, 0.014, 0.01, 0.1 * k, STEM, 5)
	if ripe:
		mb.ellipsoid(_up(0.14), Vector3(0.04, 0.03, 0.04), _p(0.85), 7, 4)
		for j in 7:
			var a := TAU * j / 7.0
			mb.ellipsoid(_up(0.135) + _ring(a, 0.04), Vector3(0.026, 0.024, 0.026), _p(0.78 + 0.14 * (j % 2)), 6, 4)
	else:
		mb.ellipsoid(_up(0.11 * k), Vector3(0.025, 0.02, 0.025), leaf.lightened(0.2), 5, 3)


static func _artichoke(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#7a9a6a")
	for i in 8:
		var a := TAU * i / 8.0 + rng.randf() * 0.3
		mb.blade(_up(0.01), _ring(a, 0.12 * k) + _up(0.14 * k), 0.04, leaf.darkened(0.2), leaf.lightened(0.15),
			_ring(a, 0.02))
	if ripe:
		mb.cone(Vector3.ZERO, 0.01, 0.006, 0.2, STEM, 5)
		mb.ellipsoid(_up(0.22), Vector3(0.035, 0.045, 0.035), _p(0.8), 7, 4)
		for j in 8:
			mb.ellipsoid(_up(0.215) + _ring(TAU * j / 8.0, 0.028), Vector3(0.016, 0.03, 0.016), _p(0.65), 5, 3)


static func _tea(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#3f7f32")
	for i in 12:
		var a := i * 2.4 + rng.randf() * 0.3
		var at := _ring(a, rng.randf_range(0.02, 0.09) * k) + _up(rng.randf_range(0.04, 0.15) * k)
		mb.ellipsoid(at, Vector3(0.035, 0.018, 0.03), leaf.lerp(leaf.lightened(0.25), rng.randf()), 5, 3)
	if ripe:
		for j in 8:
			mb.ellipsoid(_ring(j * 2.4, 0.07 * k) + _up((0.12 + 0.01 * (j % 3)) * k), Vector3(0.012, 0.02, 0.012),
				_p(0.95), 4, 3)


static func _clover(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#4f9a36")
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.4
		var at := _ring(a, (0.04 + 0.04 * (i % 2)) * k) + _up(0.03 * k)
		mb.blade(_up(0.005), at, 0.006, STEM, STEM)
		for j in 3:
			var b := a + TAU * j / 3.0
			mb.ellipsoid(at + _ring(b, 0.02), Vector3(0.022, 0.005, 0.022), leaf.lerp(leaf.lightened(0.2), j / 3.0), 5, 3)
			mb.ellipsoid(at + _ring(b, 0.02) + _up(0.004), Vector3(0.012, 0.003, 0.012), leaf.lightened(0.45), 4, 3)
	if ripe:
		for j in 4:
			var a := j * 1.6 + 0.4
			mb.cone(_ring(a, 0.06), 0.004, 0.002, 0.1, STEM, 4)
			mb.ellipsoid(_ring(a, 0.06) + _up(0.1), Vector3(0.022, 0.02, 0.022), _p(0.95), 6, 4)


static func _cotton(mb: MeshBuilder, rng: RandomNumberGenerator, s: Dictionary, k: float, ripe: bool) -> void:
	var leaf := _col(s, "leaf", "#4f8a36")
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.4
		var at := _ring(a, 0.06 * k) + _up(0.2 * k)
		mb.blade(_up(0.0), at, 0.012, STEM, STEM, _ring(a, 0.01))
		mb.blade(at * 0.6, at * 0.6 + _ring(a + 1.2, 0.07) + _up(0.03), 0.06, leaf.darkened(0.2), leaf.lightened(0.1),
			_up(-0.02))
		var boll := _ring(a, 0.06) + _up((0.12 + 0.03 * (i % 3)) * k)
		if ripe:
			for j in 3:
				mb.ellipsoid(boll + _ring(j * 2.1, 0.012) + _up(0.008 * (j % 2)), Vector3(0.016, 0.015, 0.016), _p(0.98), 5, 3)
			for j in 4:
				mb.blade(boll - _up(0.012), boll + _ring(TAU * j / 4.0, 0.03) - _up(0.005), 0.012, BARK, BARK.darkened(0.2))
		elif i % 2 == 0:
			mb.ellipsoid(boll, Vector3(0.014, 0.016, 0.014), leaf.lightened(0.3), 5, 3)
