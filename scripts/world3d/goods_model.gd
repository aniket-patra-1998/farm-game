class_name GoodsModel
extends RefCounted
## Crafted goods (data/catalog/recipes.json) and produce (ingredients.json) as small 3D things, for their
## pictures (ItemIcons), like the building parts (MaterialModel). A good is its recipe's `shape` (a loaf, a pie,
## a bottle, a candle...) in the colours of what goes into it, so Pumpkin Bread is an orange loaf and Iris
## Perfume a violet bottle with no art drawn for either; produce is its `shape` in its own colour (a pail of
## milk, a nest of eggs, three apples, a bunch of cut roses). Modelled about a tile across, centred on
## (0.5, 0, 0.5) like everything the pictures draw.

const C := Vector3(0.5, 0.0, 0.5)   # the middle of the tile everything stands on
const ASIDE := Vector3(0.7, 0.0, -0.7)   # across the pictures' view (ItemIcons looks from +x +z)
const BAKED := Color("#c98b4a")     # a baked crust..
const CRUST := Color("#dcae6c")     # ..and a paler one (pastry, a loaf's slashes)
const SPONGE := Color("#f0d79a")
const CREAM := Color("#f8eeda")     # icing, labels, milk glass
const PAPER := Color("#efe6d2")
const TIN := Color("#aeb6be")
const CORK := Color("#b98b5a")
const GOLD := Color("#d8ae48")
const CERAMIC := Color("#e7dcc6")
const CLOTH := Color("#ece2cc")
const BURLAP := Color("#c9ad78")
const STRAW := Color("#c9a45a")
const LEAF := Color("#4f9a3c")
const STALK := Color("#7a5a36")
const FLAME := Color("#ffb52e")
const DARK_GLASS := Color("#31452f") # a wine bottle
const PALE_GLASS := Color("#cfe3d6") # a bottle of something pale (saki)
const VIVID := 0.3                  # a colour at least this strong is a flavour (wheat and milk are not)
const GOLDEN := 2.39996             # the angle between one scattered bit and the next
const BOUQUET := 0.62               # a bunch of cut flowers, against a Full Bloom on its tile
## Every shape a recipe may name (data/catalog/recipes.json `shape`) and every shape produce may (ingredients).
const GOODS := ["loaf", "muffin", "cake", "pie", "cookies", "tart", "pizza", "bottle", "jug", "glass", "perfume",
	"lotion", "candle", "sachet", "soap", "cloth", "pillow", "sack"]
const PRODUCE := ["pail", "milk_bottle", "eggs", "wool", "feather", "truffle", "jar", "fruit", "nut", "berries",
	"banana", "flower"]


## The good or the produce `id` as a baked model, or null for an id that is neither.
static func build(id: String) -> Node3D:
	var d := Game.catalog.get_def(id)
	if not (d is RecipeDef or d is IngredientDef):
		return null
	var root := Node3D.new()
	if d is RecipeDef:
		var t := flavours(d as RecipeDef)
		_good(root, (d as RecipeDef).shape(), t[0], t[1], t[2])
	else:
		_produce(root, d as IngredientDef)
	return ModelKit.bake(root)


## The colours of what goes into recipe `r`, the strongest flavours first (the vivid ingredients, by how much
## of the recipe's worth they are), then the rest: always three.
static func flavours(r: RecipeDef) -> Array[Color]:
	var vivid: Array = []
	var plain: Array = []
	for c: String in r.inputs():
		var col := colour_of(c)
		var share := float(RecipeDef.worth_of(Game.catalog, c) * int(r.inputs()[c]))
		(vivid if col.s >= VIVID else plain).append([share, col])
	vivid.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	plain.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var out: Array[Color] = []
	for e: Array in vivid + plain:
		out.append(e[1])
	while out.size() < 3:
		out.append(out[out.size() - 1].lightened(0.25) if not out.is_empty() else CREAM)
	return out


## The colour of a crop or of produce.
static func colour_of(id: String) -> Color:
	var d := Game.catalog.get_def(id)
	return Color.html(str(d.data.get("color", "#c9a45a"))) if d != null else STRAW


static func _good(root: Node3D, shape: String, a: Color, b: Color, c: Color) -> void:
	match shape:
		"muffin":
			ModelKit.cylinder(root, C, 0.15, 0.18, ModelKit.paint(PAPER.lerp(a, 0.15)), 0.21, 10)
			ModelKit.ball(root, C + Vector3(0, 0.2, 0), 0.23, ModelKit.paint(BAKED.lerp(a, 0.35)), Vector3(1, 0.72,
				1), true)
			_bits(root, C + Vector3(0, 0.375, 0), 7, 0.04, a.darkened(0.15), 0.15, 0.07)
			for k in 10:   # (the paper cup's pleats)
				var at := Vector3(cos(TAU * k / 10.0), 0, sin(TAU * k / 10.0))
				ModelKit.box(root, C + at * 0.185 + Vector3(-0.012, 0.01, -0.012), C + at * 0.185 + Vector3(0.012,
					0.17, 0.012),
					ModelKit.paint(PAPER.darkened(0.12)))
		"cake":
			ModelKit.cylinder(root, C, 0.37, 0.02, ModelKit.paint(Color.WHITE, 0.4), 0.37, 16)
			ModelKit.cylinder(root, C + Vector3(0, 0.02, 0), 0.27, 0.09, ModelKit.paint(SPONGE), 0.27, 16)
			# (the filling)
			ModelKit.cylinder(root, C + Vector3(0, 0.11, 0), 0.275, 0.03, ModelKit.paint(a), 0.275, 16)
			ModelKit.cylinder(root, C + Vector3(0, 0.14, 0), 0.27, 0.08, ModelKit.paint(SPONGE), 0.27, 16)
			ModelKit.cylinder(root, C + Vector3(0, 0.22, 0), 0.285, 0.035, ModelKit.paint(CREAM.lerp(a, 0.3)), 0.275,
				16)
			for k in 7:
				var at := Vector3(cos(TAU * k / 7.0), 0, sin(TAU * k / 7.0)) * 0.19
				ModelKit.ball(root, C + at + Vector3(0, 0.275, 0), 0.042, ModelKit.paint(b if k % 2 == 1 else a, 0.3))
			ModelKit.ball(root, C + Vector3(0, 0.285, 0), 0.055, ModelKit.paint(a, 0.3))
		"pie":
			ModelKit.cylinder(root, C, 0.25, 0.1, ModelKit.paint(CRUST), 0.33, 14)
			ModelKit.cylinder(root, C + Vector3(0, 0.085, 0), 0.3, 0.025, ModelKit.paint(a.darkened(0.12), 0.3), 0.3,
				14)
			for k in 14:
				var at := Vector3(cos(TAU * k / 14.0), 0, sin(TAU * k / 14.0)) * 0.325
				ModelKit.ball(root, C + at + Vector3(0, 0.1, 0), 0.042, ModelKit.paint(BAKED.lightened(0.1)))
			for k in 3:   # (a lattice)
				var off := (k - 1) * 0.15
				var long := 0.27 if k == 1 else 0.22
				ModelKit.box(root, C + Vector3(-long, 0.105, off - 0.025), C + Vector3(long, 0.125, off + 0.025),
					ModelKit.paint(CRUST.lightened(0.08)))
				ModelKit.box(root, C + Vector3(off - 0.025, 0.118, -long), C + Vector3(off + 0.025, 0.138, long),
					ModelKit.paint(CRUST.lightened(0.08)))
		"cookies":
			for k in 3:
				var at := C + Vector3(0.03 * (k - 1), 0.045 * k, -0.02 * (k - 1))
				ModelKit.cylinder(root, at, 0.2, 0.04, ModelKit.paint(BAKED.lerp(a, 0.25).lightened(0.04 * k)), 0.19,
					12)
			_bits(root, C + Vector3(0.03, 0.135, -0.02), 7, 0.026, a.darkened(0.35), 0.14, 0.0)
			ModelKit.cylinder(root, C + Vector3(0.3, 0.0, 0.26), 0.15, 0.04, ModelKit.paint(BAKED.lerp(a,
				0.25).lightened(0.06)),
				0.14, 12)   # (one more beside the stack)
			_bits(root, C + Vector3(0.3, 0.045, 0.26), 5, 0.022, a.darkened(0.35), 0.1, 0.0)
		"tart":
			ModelKit.cylinder(root, C, 0.29, 0.08, ModelKit.paint(CRUST), 0.35, 14)
			ModelKit.cylinder(root, C + Vector3(0, 0.07, 0), 0.31, 0.02, ModelKit.paint(CREAM.lerp(a, 0.45), 0.3),
				0.31, 14)
			for k in 8:
				var at := Vector3(cos(TAU * k / 8.0), 0, sin(TAU * k / 8.0)) * 0.19
				ModelKit.ball(root, C + at + Vector3(0, 0.095, 0), 0.07, ModelKit.paint(a if k % 2 == 0 else b, 0.3),
					Vector3(1, 0.35, 1))
			ModelKit.ball(root, C + Vector3(0, 0.1, 0), 0.07, ModelKit.paint(c, 0.3), Vector3(1, 0.4, 1))
		"pizza":
			ModelKit.cylinder(root, C, 0.39, 0.04, ModelKit.paint(CRUST), 0.39, 16)
			ModelKit.cylinder(root, C + Vector3(0, 0.035, 0), 0.33, 0.015, ModelKit.paint(a.darkened(0.05), 0.2),
				0.33, 16)
			for k in 7:
				var at := Vector3(cos(k * GOLDEN), 0, sin(k * GOLDEN)) * (0.08 + 0.03 * k)
				ModelKit.ball(root, C + at + Vector3(0, 0.05, 0), 0.075, ModelKit.paint(CREAM.lerp(GOLD, 0.25)),
					Vector3(1, 0.22, 1))
			_bits(root, C + Vector3(0, 0.06, 0), 8, 0.035, b, 0.26, 0.0)
		"bottle":
			var glass := (DARK_GLASS.lerp(a, 0.35) if a.s >= VIVID else PALE_GLASS)
			ModelKit.cylinder(root, C, 0.13, 0.36, ModelKit.paint(glass, 0.8), 0.13, 12)
			ModelKit.ball(root, C + Vector3(0, 0.36, 0), 0.13, ModelKit.paint(glass, 0.8), Vector3(1, 0.75, 1), true)
			ModelKit.cylinder(root, C + Vector3(0, 0.4, 0), 0.045, 0.17, ModelKit.paint(glass, 0.8), 0.04, 10)
			ModelKit.cylinder(root, C + Vector3(0, 0.56, 0), 0.042, 0.05, ModelKit.paint(CORK), 0.04, 10)
			ModelKit.cylinder(root, C + Vector3(0, 0.1, 0), 0.134, 0.16, ModelKit.paint(CREAM), 0.134, 12)
			ModelKit.cylinder(root, C + Vector3(0, 0.15, 0), 0.137, 0.05, ModelKit.paint(a), 0.137, 12)
			_bits(root, C + Vector3(0.24, 0.05, 0.1), 3, 0.05, a, 0.06, 0.0)
		"jug":
			ModelKit.ball(root, C + Vector3(0, 0.2, 0), 0.24, ModelKit.paint(CERAMIC, 0.5), Vector3(1, 0.85, 1), true)
			ModelKit.cylinder(root, C + Vector3(0, 0.37, 0), 0.085, 0.1, ModelKit.paint(CERAMIC, 0.5), 0.1, 10)
			ModelKit.cylinder(root, C + Vector3(0, 0.46, 0), 0.07, 0.045, ModelKit.paint(CORK), 0.065, 10)
			ModelKit.cylinder(root, C + Vector3(0, 0.15, 0), 0.243, 0.09, ModelKit.paint(a), 0.243, 14)
			for k in 11:   # (its handle, to one side as the pictures look at it)
				var bow := 0.2 + 0.11 * sin(PI * k / 10.0)
				ModelKit.ball(root, C + ASIDE * bow + Vector3(0, 0.12 + 0.024 * k, 0), 0.028,
					ModelKit.paint(CERAMIC.darkened(0.1), 0.5))
		"glass":
			ModelKit.cylinder(root, C, 0.115, 0.3, ModelKit.paint(a, 0.6), 0.16, 12)
			ModelKit.cylinder(root, C + Vector3(0, 0.3, 0), 0.165, 0.014, ModelKit.paint(a.lightened(0.35), 0.6),
				0.165, 12)
			var straw := ModelKit.cylinder(root, C + Vector3(0.05, 0.18, 0.0), 0.014, 0.32,
				ModelKit.paint(Color.WHITE), 0.014, 6)
			straw.rotation.z = -0.3
			ModelKit.ball(root, C + Vector3(-0.1, 0.32, 0.1), 0.085, ModelKit.paint(b, 0.3), Vector3(1, 1, 0.3))
			_bits(root, C + Vector3(0.24, 0.06, 0.1), 3, 0.06, b, 0.07, 0.0)
		"perfume":
			ModelKit.facet_ball(root, C + Vector3(0, 0.17, 0), 0.18, ModelKit.paint(CREAM.lerp(a, 0.55), 0.8),
				Vector3(1, 0.92, 0.7))
			ModelKit.cylinder(root, C, 0.11, 0.03, ModelKit.paint(GOLD, 0.6), 0.11, 10)
			ModelKit.cylinder(root, C + Vector3(0, 0.32, 0), 0.04, 0.06, ModelKit.paint(GOLD, 0.6), 0.04, 8)
			ModelKit.ball(root, C + Vector3(0, 0.42, 0), 0.06, ModelKit.paint(GOLD, 0.6))
			_bits(root, C + Vector3(0.22, 0.04, 0.12), 4, 0.045, b, 0.07, 0.0)
		"lotion":
			ModelKit.cylinder(root, C, 0.15, 0.32, ModelKit.paint(CREAM.lerp(a, 0.12), 0.5), 0.12, 12)
			ModelKit.cylinder(root, C + Vector3(0, 0.08, 0), 0.152, 0.12, ModelKit.paint(a), 0.137, 12)
			ModelKit.cylinder(root, C + Vector3(0, 0.32, 0), 0.05, 0.06, ModelKit.paint(Color.WHITE, 0.5), 0.045, 8)
			ModelKit.cylinder(root, C + Vector3(0, 0.38, 0), 0.02, 0.07, ModelKit.paint(TIN, 0.6), 0.02, 6)
			ModelKit.box(root, C + Vector3(-0.03, 0.44, -0.03), C + Vector3(0.12, 0.475, 0.03),
				ModelKit.paint(Color.WHITE, 0.5))
			_bits(root, C + Vector3(0.24, 0.045, 0.1), 3, 0.05, b, 0.07, 0.0)
		"candle":
			ModelKit.cylinder(root, C, 0.27, 0.025, ModelKit.paint(CERAMIC, 0.5), 0.25, 14)
			ModelKit.cylinder(root, C + Vector3(0, 0.025, 0), 0.15, 0.3, ModelKit.paint(CREAM.lerp(a, 0.5)), 0.15, 14)
			ModelKit.ball(root, C + Vector3(0, 0.325, 0), 0.15, ModelKit.paint(CREAM.lerp(a, 0.35)), Vector3(1, 0.18,
				1))
			ModelKit.cylinder(root, C + Vector3(0, 0.33, 0), 0.01, 0.05, ModelKit.paint(Color("#3a2f28")), 0.01, 5)
			ModelKit.ball(root, C + Vector3(0, 0.42, 0), 0.045, ModelKit.paint(FLAME, 0.2), Vector3(0.8, 1.6, 0.8))
			ModelKit.ball(root, C + Vector3(0, 0.41, 0), 0.025, ModelKit.paint(Color("#fff3b0")), Vector3(0.8, 1.5,
				0.8))
			# (a ribbon)
			ModelKit.cylinder(root, C + Vector3(0, 0.07, 0), 0.153, 0.035, ModelKit.paint(b), 0.153, 14)
			_bits(root, C + Vector3(0.21, 0.05, 0.08), 3, 0.045, b, 0.04, 0.0)
		"sachet":
			var cloth := CLOTH.lerp(a, 0.45)
			ModelKit.ball(root, C + Vector3(0, 0.17, 0), 0.21, ModelKit.paint(cloth), Vector3(1, 0.95, 0.85), true)
			ModelKit.cylinder(root, C + Vector3(0, 0.31, 0), 0.07, 0.07, ModelKit.paint(cloth), 0.13, 10)
			ModelKit.cylinder(root, C + Vector3(0, 0.305, 0), 0.082, 0.025, ModelKit.paint(b, 0.3), 0.082, 10)
			for side: float in [-1.0, 1.0]:   # (its bow)
				ModelKit.ball(root, C + Vector3(0.07 * side, 0.32, 0.09), 0.045, ModelKit.paint(b, 0.3), Vector3(1.4,
					0.8, 0.5))
			_bits(root, C + Vector3(0, 0.39, 0), 5, 0.035, c, 0.07, 0.02)
		"soap":
			var bar := CREAM.lerp(a, 0.5)
			ModelKit.box(root, C + Vector3(-0.22, 0, -0.14), C + Vector3(0.22, 0.1, 0.14), ModelKit.paint(bar, 0.3))
			var top := ModelKit.box(root, Vector3(-0.2, 0, -0.13), Vector3(0.2, 0.09, 0.13),
				ModelKit.paint(bar.lightened(0.2), 0.3))
			top.position = C + Vector3(0, 0.1, 0)
			top.rotation.y = 0.35
			var band := ModelKit.box(root, Vector3(-0.035, 0, -0.135), Vector3(0.035, 0.095, 0.135),
				ModelKit.paint(GOLD, 0.5))
			band.position = C + Vector3(0, 0.1, 0)
			band.rotation.y = 0.35
			_bits(root, C + Vector3(0, 0.21, 0), 5, 0.04, b, 0.05, 0.015)
		"cloth":
			for k in 3:
				var w := 0.3 - 0.02 * k
				ModelKit.box(root, C + Vector3(-w, 0.085 * k, -0.2), C + Vector3(w, 0.085 * k + 0.075, 0.2),
					ModelKit.paint(CLOTH.lerp(a, 0.55) if k != 1 else CREAM))
				ModelKit.box(root, C + Vector3(w - 0.06, 0.085 * k - 0.002, -0.202), C + Vector3(w - 0.02,
					0.085 * k + 0.077, 0.202),
					ModelKit.paint(b if k != 1 else a))   # (a stripe at each one's end)
			ModelKit.box(root, C + Vector3(-0.03, 0, -0.205), C + Vector3(0.03, 0.262, 0.205), ModelKit.paint(GOLD,
				0.4))
		"pillow":
			ModelKit.ball(root, C + Vector3(0, 0.12, 0), 0.32, ModelKit.paint(CREAM.lerp(a, 0.35)), Vector3(1.1, 0.38,
				0.85), true)
			for k in 4:   # (its corners)
				var corner := Vector3(0.3 if k % 2 == 0 else -0.3, 0.12, 0.23 if k < 2 else -0.23)
				ModelKit.ball(root, C + corner, 0.06, ModelKit.paint(CREAM.lerp(a, 0.35)))
			ModelKit.box(root, C + Vector3(-0.36, 0.1, -0.04), C + Vector3(0.36, 0.14, 0.04),
				ModelKit.paint(b.lerp(CREAM, 0.3)))
			_bits(root, C + Vector3(0.28, 0.03, 0.3), 3, 0.05, Color.WHITE, 0.08, 0.0)   # (a few feathers got out)
		"sack":
			ModelKit.ball(root, C + Vector3(0, 0.2, 0), 0.25, ModelKit.paint(BURLAP), Vector3(0.95, 1.0, 0.75), true)
			ModelKit.cylinder(root, C + Vector3(0, 0.4, 0), 0.07, 0.07, ModelKit.paint(BURLAP.darkened(0.08)), 0.13,
				8)
			ModelKit.cylinder(root, C + Vector3(0, 0.395, 0), 0.08, 0.02, ModelKit.paint(STALK), 0.08, 8)
			# (its label)
			ModelKit.ball(root, C + Vector3(0.11, 0.2, 0.11), 0.11, ModelKit.paint(a), Vector3(1, 1, 1) * 0.9)
			_bits(root, C + Vector3(0.22, 0.02, 0.2), 9, 0.03, a.lightened(0.1), 0.13, 0.0)
		_:   # a loaf
			var crust := BAKED.lerp(a, 0.3)
			ModelKit.ball(root, C + Vector3(0, 0.12, 0), 0.21, ModelKit.paint(crust), Vector3(1.7, 0.9, 1.0), true)
			for k in 3:
				var slash := ModelKit.ball(root, C + Vector3(-0.17 + 0.17 * k, 0.29, 0), 0.05,
					ModelKit.paint(CRUST.lightened(0.1)),
					Vector3(0.45, 0.3, 2.4))
				slash.rotation.y = 0.5
			_bits(root, C + Vector3(0.1, 0.045, 0.3), 3, 0.055, a, 0.09, 0.0)


static func _produce(root: Node3D, d: IngredientDef) -> void:
	var col := Color.html(str(d.data.get("color", "#c9a45a")))
	match d.shape():
		"pail":
			ModelKit.cylinder(root, C, 0.17, 0.27, ModelKit.paint(TIN, 0.6), 0.23, 12)
			ModelKit.cylinder(root, C + Vector3(0, 0.25, 0), 0.215, 0.02, ModelKit.paint(col, 0.3), 0.215, 12)
			ModelKit.cylinder(root, C + Vector3(0, 0.265, 0), 0.235, 0.015, ModelKit.paint(TIN.lightened(0.15), 0.6),
				0.235, 12)
			for k in 15:   # (its handle, over the top, across the pictures' view)
				var a := PI * k / 14.0
				ModelKit.ball(root, C + ASIDE * cos(a) * 0.23 + Vector3(0, 0.27 + sin(a) * 0.17, 0), 0.016,
					ModelKit.paint(TIN.darkened(0.25), 0.6))
		"milk_bottle":
			ModelKit.cylinder(root, C, 0.13, 0.28, ModelKit.paint(col, 0.7), 0.13, 12)
			ModelKit.ball(root, C + Vector3(0, 0.28, 0), 0.13, ModelKit.paint(col, 0.7), Vector3(1, 0.7, 1), true)
			ModelKit.cylinder(root, C + Vector3(0, 0.32, 0), 0.07, 0.1, ModelKit.paint(col, 0.7), 0.065, 10)
			ModelKit.cylinder(root, C + Vector3(0, 0.42, 0), 0.075, 0.03, ModelKit.paint(GOLD, 0.5), 0.075, 10)
			# (its label)
			ModelKit.cylinder(root, C + Vector3(0, 0.1, 0), 0.133, 0.09, ModelKit.paint(Color("#7fb6d9")), 0.133, 12)
		"eggs":
			ModelKit.cylinder(root, C, 0.22, 0.11, ModelKit.paint(STRAW), 0.3, 12)
			ModelKit.cylinder(root, C + Vector3(0, 0.1, 0), 0.3, 0.02, ModelKit.paint(STRAW.darkened(0.12)), 0.3, 12)
			for k in 4:
				var at := Vector3(cos(TAU * k / 4.0 + 0.4), 0, sin(TAU * k / 4.0 + 0.4)) * 0.11
				ModelKit.ball(root, C + at + Vector3(0, 0.16, 0), 0.085,
					ModelKit.paint(col if k != 2 else Color("#c9905c"), 0.3),
					Vector3(0.85, 1.12, 0.85), true)
		"wool":
			for k in 10:
				var a := k * GOLDEN
				var out := 0.05 + 0.017 * k
				ModelKit.ball(root, C + Vector3(cos(a) * out, 0.11 + 0.16 * (1.0 - k / 10.0), sin(a) * out), 0.12,
					ModelKit.paint(col.darkened(0.03 * (k % 3))))
		"feather":
			# Three, fanned from where their quills meet, each a flat vane facing the pictures' view.
			for k in 3:
				var feather := Node3D.new()
				feather.position = C + Vector3(0, 0.03, 0)
				feather.rotation = Vector3(0, PI / 4.0, 0.55 * (1 - k))
				root.add_child(feather)
				ModelKit.ball(feather, Vector3(0, 0.36, -0.01 * k), 0.3, ModelKit.paint(col.darkened(0.07 * absi(k - 1))),
					Vector3(0.34, 1.0, 0.06), true)
				ModelKit.cylinder(feather, Vector3(0, 0, 0.012 - 0.01 * k), 0.011, 0.66, ModelKit.paint(CREAM), 0.005, 5)
		"truffle":
			for k in 3:
				var at := Vector3(cos(TAU * k / 3.0), 0, sin(TAU * k / 3.0)) * 0.14
				var r := 0.14 - 0.02 * k
				ModelKit.facet_ball(root, C + at + Vector3(0, r * 0.85, 0), r,
					ModelKit.paint(col.lightened(0.05 * k)),
					Vector3(1.0, 0.85, 1.1))
				_bits(root, C + at + Vector3(0, r * 1.55, 0), 4, 0.018, col.lightened(0.35), r * 0.6, 0.0)
		"jar":
			ModelKit.cylinder(root, C, 0.17, 0.25, ModelKit.paint(col, 0.8), 0.17, 12)
			ModelKit.ball(root, C + Vector3(0, 0.25, 0), 0.17, ModelKit.paint(col, 0.8), Vector3(1, 0.4, 1), true)
			ModelKit.cylinder(root, C + Vector3(0, 0.29, 0), 0.13, 0.06, ModelKit.paint(CLOTH.lerp(Color("#d94a3a"),
				0.6)), 0.15, 12)
			ModelKit.cylinder(root, C + Vector3(0, 0.285, 0), 0.135, 0.015, ModelKit.paint(STALK), 0.135, 12)
			ModelKit.cylinder(root, C + Vector3(0, 0.08, 0), 0.173, 0.1, ModelKit.paint(CREAM), 0.173, 12)
		"nut":
			for k in 7:
				var a := k * GOLDEN
				var out := 0.05 + 0.03 * k
				var nut := ModelKit.ball(root, C + Vector3(cos(a) * out, 0.05 + (0.06 if k == 0 else 0.0),
					sin(a) * out), 0.075,
					ModelKit.paint(col.darkened(0.06 * (k % 3)), 0.2), Vector3(0.8, 0.7, 1.25), true)
				nut.rotation.y = a
		"berries":
			for side: float in [-1.0, 1.0]:
				ModelKit.ball(root, C + Vector3(0.12 * side, 0.11, 0.03 * side), 0.11,
					ModelKit.paint(col.darkened(0.05 if side > 0 else 0.0), 0.6), Vector3.ONE, true)
				var stem := ModelKit.cylinder(root, C + Vector3(0.06 * side, 0.2, 0.015 * side), 0.01, 0.24,
					ModelKit.paint(LEAF.darkened(0.2)), 0.01, 5)
				stem.rotation.z = 0.5 * side
			ModelKit.ball(root, C + Vector3(0.08, 0.43, 0), 0.1, ModelKit.paint(LEAF), Vector3(1.3, 0.12, 0.6))
		"banana":
			# A hand of three: each a curve of rounds running out from the stalk they share, sagging in the middle.
			var stalk := C - ASIDE * 0.26 + Vector3(0, 0.2, 0)
			for k in 3:
				var along := ASIDE.rotated(Vector3.UP, 0.34 * (k - 1))
				for part in 14:   # (close together, so they run into one curve)
					var t := part / 13.0
					ModelKit.ball(root, stalk + along * 0.54 * t + Vector3(0, -0.15 * sin(PI * t) - 0.02 * k, 0.0),
						0.08 - 0.035 * pow(absf(t - 0.5) * 2.0, 2.0), ModelKit.paint(col.darkened(0.05 * k), 0.3))
				ModelKit.ball(root, stalk + along * 0.56 + Vector3(0, -0.02 * k, 0), 0.026, ModelKit.paint(STALK.darkened(0.3)))
			ModelKit.ball(root, stalk, 0.06, ModelKit.paint(STALK))
		"flower":
			# A bunch of the cut flower, wrapped: the bloom's own painted flowers, so a cut rose is the farm's rose.
			var family: String = (d.data.get("families", [""]) as Array)[0]
			ModelKit.cylinder(root, C, 0.05, 0.27, ModelKit.paint(PAPER), 0.19, 10)
			ModelKit.cylinder(root, C + Vector3(0, 0.1, 0), 0.105, 0.03, ModelKit.paint(col.lerp(GOLD, 0.5), 0.3),
				0.12, 10)
			var bloom := Game.item_data(family + "_full_bloom")
			if not bloom.is_empty():
				var flowers := PaintedBloom.picture_card(family + "_full_bloom", PaintedCrops.facing())
				flowers.position = C + Vector3(0, 0.14, 0)
				flowers.scale = Vector3.ONE * BOUQUET
				root.add_child(flowers)
		_:   # fruit: three of them, a stalk and a leaf on each
			for k in 3:
				var at := Vector3(cos(TAU * k / 3.0 + 0.5), 0, sin(TAU * k / 3.0 + 0.5)) * 0.15
				var long := Vector3(1.22, 0.92, 0.92) if d.id == "lemons" else (Vector3(0.9, 1.18,
					0.9) if d.id == "figs"
					else Vector3.ONE)
				var fruit := ModelKit.ball(root, C + at + Vector3(0, 0.13, 0), 0.14,
					ModelKit.paint(col.darkened(0.05 * k), 0.4), long, true)
				fruit.rotation.y = 1.1 * k
				ModelKit.cylinder(root, C + at + Vector3(0, 0.25, 0), 0.012, 0.05, ModelKit.paint(STALK), 0.012, 5)
				ModelKit.ball(root, C + at + Vector3(0.05, 0.29, 0), 0.06, ModelKit.paint(LEAF), Vector3(1.3, 0.14,
					0.6))


## `n` small round bits of colour `col` scattered about `at`, as far as `spread` (berries on a cake, grain
## spilled by a sack, the fruit beside a bottle), each `drop` lower the further out it lies.
static func _bits(root: Node3D, at: Vector3, n: int, r: float, col: Color, spread: float, drop: float) -> void:
	for k in n:
		var a := k * GOLDEN
		var out := spread * sqrt((k + 0.5) / n)
		ModelKit.ball(root, at + Vector3(cos(a) * out, -drop * out / maxf(spread, 0.001), sin(a) * out), r,
			ModelKit.paint(col.darkened(0.05 * (k % 3)), 0.3))
