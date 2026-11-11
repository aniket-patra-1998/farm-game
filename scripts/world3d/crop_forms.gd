class_name CropForms
extends RefCounted
## What each crop looks like in 3D: a form per kind of plant (wheat, rice, corn, tomato on its stake, sunflower,
## pumpkin, cabbage...) drawn into a MeshBuilder at a growth stage. Which crop is which form, and each form's
## numbers, are in data/crop_forms.json; a crop without one falls back to its catalog shape (CropModels).
## Produce (a head, a fruit, a bloom) is marked with vertex alpha 0 and takes the crop's colour at draw time.

const PATH := "res://data/crop_forms.json"
const STEM := Color("#5c8a2e")
const BARK := Color("#6b4a26")
const STAKE := Color("#7a5a30")
const STRAW := Color("#d8b85a")
const WHITE := Color(0.95, 0.94, 0.88)

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
