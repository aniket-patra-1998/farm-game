class_name DecorModel
extends RefCounted
## Every decoration in 3D, by id: paths, fences, hedges and walls that join up with their neighbours'
## lines, hay, a scarecrow, a well, a fountain, a gazebo, gnomes, flamingos... The farmhouse and log cabin
## are buildings (BuildingModel); the countryside trees share TreeModel and the pine. The node's origin is
## the footprint's back corner; `o` is the placed object (a mastery sign's crop, a bunch's flower).

const WOOD := Color("#a8743f")
const DARK_WOOD := Color("#6e4a2a")
const STONE := Color("#9aa4ad")
const WHITE := Color("#f4efe4")
const HAY := Color("#e3c46a")
const LEAF := Color("#3c8a2e")
## Every decoration with a model here (tests check the catalog's decorations against it).
const IDS := ["farmhouse", "log_cabin", "dirt_path", "brick_path", "stone_path", "wooden_fence", "white_picket_fence",
	"tall_wooden_fence", "wooden_gate", "hedge", "stone_wall", "hay_bale", "haystack", "scarecrow", "water_trough",
	"bonfire", "wheelbarrow",
	"water_well", "flower_bed", "pink_flamingo", "bench", "birdhouse", "birdbath", "picnic_table", "garden_gnome",
	"lamp_post", "sundial", "small_pond", "fountain", "arbor", "wooden_bridge", "gazebo", "pine_tree", "oak_tree",
	"maple_tree", "willow_tree", "mastery_sign", "mailbox", "farm_stand", "perfect_bunch"]



const HOUSE_AT := 0.5       # how high a birdhouse's landing board stands on its post, in tiles
const BATH_STONE := Color("#bdb6a6")   # the warm stone a birdbath is turned from (mixed with its own colour)
const BATH_SIDES := 20      # sides of a birdbath's turned stone
const WATER_LIFT := 0.012   # water stands this far above the rim it fills, never level with it (flicker)
## Decorations that bend in the wind, and how much (paint3d sway, by height above their foot): only soft, loose
## things (flowers, a scarecrow's rags); anything solid or clipped (an arbor, a haystack, a hedge) stands still.
const SWAY_BY_ID := {"scarecrow": 0.08, "flower_bed": 0.6, "perfect_bunch": 0.5}
static var _glows := {}   # colour -> glowing material




static func build(it: Dictionary, fp: Vector2i, o: Dictionary) -> Node3D:
	var id := str(it.get("id", ""))
	if id in ["farmhouse", "log_cabin"]:
		# The farmhouse grows with the farmer (its stage is in its look: Objects3D.shows_of); a picture of it, and
		# the cabin, are the first.
		var shows := str(o.get("crop", ""))
		var stage := int(shows.trim_prefix(Objects3D.STAGE)) if shows.begins_with(Objects3D.STAGE) else 1
		return ModelKit.bake(BuildingSpec.model().build(it, fp, maxi(stage, 1)))
	if Game.links.group_of(id) != "":
		# Fences, hedges, walls and paths are drawn joined up by the LinkLayer; alone (a sheet, a size guide)
		# one is a straight piece.
		var piece := Node3D.new()
		piece.position = Vector3(0.5, 0, 0.5)
		piece.add_child(LinkModels.node(it, LinkShape.Kind.STRAIGHT, 0))
		var alone := Node3D.new()
		alone.add_child(piece)
		return ModelKit.bake(alone)
	var root := Node3D.new()
	var c := Vector3(fp.x / 2.0, 0, fp.y / 2.0)
	var col := Color.html(str(it.get("color", "#a8743f")))
	match id:
		"hay_bale":
			# A round bale lying on its side: its rolled-up layers showing as rings on the ends, two twine
			# bands, and loose straw sticking out and lying round its foot.
			var bale := ModelKit.cylinder(root, Vector3.ZERO, 0.2, 0.36, ModelKit.paint(HAY), -1.0, 16)
			bale.rotation.x = PI / 2.0
			bale.position = c + Vector3(0, 0.2, 0)
			for z: float in [-0.181, 0.181]:
				for k in 3:
					var ring := ModelKit.cylinder(root, Vector3.ZERO, 0.17 - 0.05 * k, 0.004,
						ModelKit.paint(HAY.darkened(0.08 + 0.05 * k)), -1.0, 14)
					ring.rotation.x = PI / 2.0
					ring.position = c + Vector3(0, 0.2, z + signf(z) * 0.002 * (k + 1))
			for z: float in [-0.08, 0.08]:
				var band := ModelKit.cylinder(root, Vector3.ZERO, 0.205, 0.02, ModelKit.paint(Color("#a8743f")), -1.0, 16)
				band.rotation.x = PI / 2.0
				band.position = c + Vector3(0, 0.2, z)
			_straw(root, c, 0.24, 0.32, 18, id)
		"haystack":
			# A stack built up round a pole in rounded layers, each a little narrower, thatched with strands that
			# hang down its sides, straw scattered at its foot and a pitchfork leaning on it.
			for k in 4:
				var r := 0.38 - 0.06 * k
				ModelKit.ball(root, c + Vector3(0, 0.1 + 0.13 * k, 0), r, ModelKit.paint(HAY.darkened(0.08 - 0.025 * k)),
					Vector3(1, 0.55, 1))
			ModelKit.ball(root, c + Vector3(0, 0.5, 0), 0.17, ModelKit.paint(HAY.lightened(0.05)), Vector3(1, 0.9, 1))
			var rng := _rng(id)
			for k in 40:   # strands hanging down the sides
				var ang := TAU * k / 40.0 + rng.randf_range(-0.05, 0.05)
				var lay := rng.randi_range(0, 3)
				var r := (0.38 - 0.06 * lay) * 0.97
				var strand := ModelKit.box(root, Vector3(-0.006, -0.09, -0.002), Vector3(0.006, 0.0, 0.002),
					ModelKit.paint(HAY.darkened(rng.randf_range(0.0, 0.2))), false)
				strand.position = c + Vector3(cos(ang) * r, 0.1 + 0.13 * lay, sin(ang) * r)
				strand.rotation = Vector3(sin(ang) * 0.5, -ang, -cos(ang) * 0.5)
			ModelKit.cylinder(root, c + Vector3(0, 0.56, 0), 0.015, 0.14, ModelKit.paint(DARK_WOOD))
			_straw(root, c, 0.42, 0.5, 22, id)
			# The pitchfork: a handle leaning on the stack, three tines at its top.
			var fork := Node3D.new()
			fork.position = c + Vector3(0.36, 0, 0.2)
			fork.rotation = Vector3(0, 0.6, 0.38)
			root.add_child(fork)
			ModelKit.cylinder(fork, Vector3.ZERO, 0.012, 0.62, ModelKit.paint(WOOD), -1.0, 6)
			for t in 3:
				ModelKit.cylinder(fork, Vector3(-0.035 + 0.035 * t, 0.62, 0), 0.005, 0.12, ModelKit.paint(Color("#9aa3aa"), 0.5),
					-1.0, 4)
			ModelKit.box(fork, Vector3(-0.045, 0.6, -0.006), Vector3(0.045, 0.63, 0.006), ModelKit.paint(Color("#9aa3aa"), 0.5))
		"scarecrow":
			_scarecrow(root, c, col, id)
		"water_trough":
			# A plank trough on two short trestles, bound with iron straps, brimming.
			for x: float in [-0.24, 0.24]:
				ModelKit.box(root, c + Vector3(x - 0.03, 0, -0.17), c + Vector3(x + 0.03, 0.06, 0.17),
					ModelKit.paint(DARK_WOOD))
			ModelKit.tub(root, c + Vector3(-0.32, 0.06, -0.14), c + Vector3(0.32, 0.24, 0.14), 0.03,
				ModelKit.surface(col, "boards", 0.2), ModelKit.water())
			for x: float in [-0.29, 0.29]:
				ModelKit.box(root, c + Vector3(x - 0.012, 0.06, -0.145), c + Vector3(x + 0.012, 0.245, 0.145),
					ModelKit.paint(Color("#5a6066"), 0.4))
			_straw(root, c, 0.3, 0.36, 8, id)
		"bonfire":
			# A ring of stones of different sizes and greys round a bed of ash.
			ModelKit.cylinder(root, c, 0.2, 0.012, ModelKit.paint(Color("#3a3532")), -1.0, 12)
			var ring := _rng(id)
			for k in 10:
				var a := TAU * k / 10.0 + ring.randf_range(-0.08, 0.08)
				ModelKit.facet_ball(root, c + Vector3(cos(a) * 0.23, 0.035, sin(a) * 0.23), ring.randf_range(0.05, 0.075),
					ModelKit.paint(STONE.lerp(Color("#a59a8a"), ring.randf() * 0.7).darkened(ring.randf() * 0.2)),
					Vector3(1.1, 0.75, 1.0))
			for k in 4:
				var log_piece := ModelKit.cylinder(root, Vector3.ZERO, 0.03, 0.34, ModelKit.paint(DARK_WOOD), -1.0, 6)
				log_piece.position = c + Vector3(0, 0.08, 0)
				log_piece.rotation = Vector3(0, TAU * k / 4.0, PI / 2.0 - 0.5)
			# Tongues of flame licking up from the logs, embers floating off them.
			ModelKit.ball(root, c + Vector3(0, 0.08, 0), 0.08, _glow(Color("#ff6a1f")), Vector3(1, 0.5, 1))
			DecorMotion.flame(root, c + Vector3(0, 0.06, 0), 0.08, 0.26, Color("#ff6a1f"), Color("#ffd35a"))
			for k in 3:
				var a := TAU * k / 3.0 + 0.4
				DecorMotion.flame(root, c + Vector3(cos(a) * 0.06, 0.05, sin(a) * 0.06), 0.045, 0.15,
					Color("#ff7a26"), Color("#ffe07a"))
			DecorMotion.spray(root, c + Vector3(0, 0.18, 0), DecorMotion.EMBERS)
		"wheelbarrow":
			_wheelbarrow(root, c, col)
		"water_well":
			_well(root, c, col, id)
		"flower_bed":
			# A raised bed edged with boards, its soil mounded, leafy plants with flowers of several heights and
			# kinds standing in rows (taller at the back), and a few fallen petals.
			ModelKit.box(root, c + Vector3(-0.4, 0, -0.4), c + Vector3(0.4, 0.07, 0.4),
				ModelKit.surface(DARK_WOOD, "boards", 0.2))
			ModelKit.ball(root, c + Vector3(0, 0.065, 0), 1.0, ModelKit.paint(Color("#5e4128")), Vector3(0.37, 0.035, 0.37))
			var rng := _rng(id)
			var petals := [col, Color("#ffd23f"), Color("#ffffff"), Color("#b388ff"), Color("#ff7a59")]
			for k in 16:
				var row := k / 4
				var p := c + Vector3(-0.27 + 0.18 * (k % 4) + rng.randf_range(-0.04, 0.04), 0.08,
					-0.27 + 0.18 * row + rng.randf_range(-0.04, 0.04))
				var h := 0.2 - 0.03 * row + rng.randf_range(-0.02, 0.02)   # the back rows (low z) taller
				for leaf in 3:
					var ang := TAU * leaf / 3.0 + rng.randf()
					ModelKit.ball(root, p + Vector3(cos(ang) * 0.03, 0.02, sin(ang) * 0.03), 0.03,
						ModelKit.paint(Color("#4f8a2f").lightened(rng.randf() * 0.15)), Vector3(1.2, 0.45, 0.7))
				ModelKit.cylinder(root, p, 0.006, h, ModelKit.paint(Color("#4f8a2f")), -1.0, 4)
				var bloom: Color = petals[(k * 3 + row) % petals.size()]
				for j in 5:
					var b := TAU * j / 5.0
					ModelKit.ball(root, p + Vector3(cos(b) * 0.03, h, sin(b) * 0.03), 0.033, ModelKit.paint(bloom),
						Vector3(1.0, 0.5, 1.0))
				ModelKit.ball(root, p + Vector3(0, h + 0.008, 0), 0.016, ModelKit.paint(Color("#f2c230")))
			for k in 5:
				ModelKit.ball(root, c + Vector3(rng.randf_range(-0.3, 0.3), 0.09, rng.randf_range(-0.3, 0.3)), 0.012,
					ModelKit.paint(petals[k % petals.size()]), Vector3(1.2, 0.3, 1.0))
		"pink_flamingo":
			_flamingo(root, c, col)
		"bench":
			_bench(root, c, col, id)
		"birdhouse":
			_birdhouse(root, c, col, Color.html(str(it.get("accent", "#f4e3c3"))), id)
		"birdbath":
			_birdbath(root, c, col, id)
		"picnic_table":
			_picnic_table(root, c, col, Color.html(str(it.get("accent", "#e2453c"))), id)
		"garden_gnome":
			_gnome(root, c, col, Color.html(str(it.get("accent", "#3f6fb5"))))
		"lamp_post":
			_lamp_post(root, c, col, Color.html(str(it.get("accent", "#ffe066"))))
		"sundial":
			_sundial(root, c, col)
		"small_pond", "fountain":
			_pond(root, fp, id == "fountain", col)
		"arbor":
			_arbor(root, col, Color.html(str(it.get("accent", "#ff6b8a"))), id)
		"wooden_bridge":
			_bridge(root, c, col, int(o.get("uid", 0)))
		"gazebo":
			_gazebo(root, c, col, Color("#4f7f8a"))
		"pine_tree":
			Objects3D.pine(root, c, 1.1)
		"oak_tree", "maple_tree", "willow_tree":
			TreeModel.build_at(root, c, {"id": id}, 1.25, false, int(o.get("uid", 0)), false)
		"mastery_sign", "mailbox", "farm_stand", "perfect_bunch":
			_small_sign(root, id, c, col, o)
		_:
			# A decoration added to the catalog without a model: make it visible (and the test fails).
			push_warning("no 3D model for decoration %s" % id)
			ModelKit.box(root, c + Vector3(-0.2, 0, -0.2), c + Vector3(0.2, 0.4, 0.2), ModelKit.surface(col, "boards"))
	if SWAY_BY_ID.has(id):
		ModelKit.sway_all(root, SWAY_BY_ID[id])
	# Chunkier than modelled, about the middle of its footprint (the ground stays where it is).
	var chunk := ScaleGuide.decor_scale(id)
	root.scale = Vector3.ONE * chunk
	root.position = c * (1.0 - chunk)
	return ModelKit.bake(root)


## A straight round bar from `a` to `b` (a leg, a neck, a brace): `r` thick at `a`, `top_r` at `b`.
static func rod(root: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, top_r := -1.0,
		sides := 6) -> MeshInstance3D:
	var mi := ModelKit.cylinder(root, Vector3.ZERO, r, a.distance_to(b), mat, top_r, sides)
	var up := (b - a).normalized()
	var across := (up.cross(Vector3.RIGHT) if absf(up.dot(Vector3.RIGHT)) < 0.9 else up.cross(Vector3.BACK)).normalized()
	mi.transform = Transform3D(Basis(across, up, across.cross(up)), (a + b) / 2.0)
	return mi


## A lawn flamingo: a round body with a darker wing and tail, a neck in an S, a head with an eye and a
## two-tone bill bent down, on thin pink legs, one of them tucked up.
static func _flamingo(root: Node3D, c: Vector3, col: Color) -> void:
	var pink := ModelKit.paint(col)
	var deep := ModelKit.paint(col.darkened(0.18))
	var leg := ModelKit.paint(col.lerp(Color("#f0b0a0"), 0.5))
	rod(root, c + Vector3(-0.02, 0, 0.02), c + Vector3(-0.02, 0.3, 0.02), 0.008, leg)
	ModelKit.ball(root, c + Vector3(-0.02, 0.15, 0.02), 0.013, leg)
	rod(root, c + Vector3(-0.02, 0.3, -0.02), c + Vector3(0.04, 0.2, -0.02), 0.008, leg)   # the other, tucked up
	rod(root, c + Vector3(0.04, 0.2, -0.02), c + Vector3(-0.03, 0.17, -0.02), 0.007, leg)
	for z: float in [0.02]:
		ModelKit.ball(root, c + Vector3(0.0, 0.006, z), 0.022, leg, Vector3(1.6, 0.3, 1.2))
	ModelKit.ball(root, c + Vector3(-0.03, 0.36, 0), 0.085, pink, Vector3(1.35, 0.95, 0.85), true)
	for side: float in [-1.0, 1.0]:
		ModelKit.ball(root, c + Vector3(-0.05, 0.37, side * 0.05), 0.06, deep, Vector3(1.4, 0.75, 0.4), true)
	for k in 3:   # tail feathers
		ModelKit.ball(root, c + Vector3(-0.15, 0.36 + (k - 1) * 0.022, (k - 1) * 0.018), 0.03, deep,
			Vector3(1.6, 0.4, 0.5), true)
	rod(root, c + Vector3(0.05, 0.4, 0), c + Vector3(0.12, 0.5, 0), 0.02, pink, 0.016, 8)
	rod(root, c + Vector3(0.12, 0.5, 0), c + Vector3(0.09, 0.6, 0), 0.016, pink, 0.014, 8)
	ModelKit.ball(root, c + Vector3(0.12, 0.5, 0), 0.018, pink, Vector3.ONE, true)
	ModelKit.ball(root, c + Vector3(0.1, 0.625, 0), 0.036, pink, Vector3(1.1, 1.0, 0.9), true)
	var pale := ModelKit.paint(Color("#f6efe6"))
	var tip := ModelKit.paint(Color("#231c1a"))
	rod(root, c + Vector3(0.125, 0.625, 0), c + Vector3(0.165, 0.6, 0), 0.016, pale, 0.013, 8)
	rod(root, c + Vector3(0.165, 0.6, 0), c + Vector3(0.175, 0.565, 0), 0.013, tip, 0.004, 8)
	for side: float in [-1.0, 1.0]:
		ModelKit.ball(root, c + Vector3(0.115, 0.635, side * 0.028), 0.006, ModelKit.paint(Color("#16130f")))


## A picnic table: a top and two benches of separate planks on A-frame legs with a brace, a checked cloth
## across the middle, a pie and a jug.
static func _picnic_table(root: Node3D, c: Vector3, col: Color, cloth: Color, id: String) -> void:
	var rng := _rng(id)
	var frame := ModelKit.paint(col.darkened(0.25))
	for k in 5:   # the top's planks
		var z := -0.17 + k * 0.085
		ModelKit.box(root, c + Vector3(-0.32, 0.3, z - 0.039), c + Vector3(0.32, 0.325, z + 0.039),
			ModelKit.surface(col.darkened(rng.randf() * 0.12), "boards", 0.0))
	for side: float in [-1.0, 1.0]:
		for k in 2:   # a bench's two planks
			var z := side * (0.275 + k * 0.065)
			ModelKit.box(root, c + Vector3(-0.32, 0.17, z - 0.03), c + Vector3(0.32, 0.19, z + 0.03),
				ModelKit.surface(col.darkened(rng.randf() * 0.12), "boards", 0.0))
	for x: float in [-0.24, 0.24]:
		for side: float in [-1.0, 1.0]:   # the A-frame: a leg leaning out each way
			rod(root, c + Vector3(x, 0.3, side * 0.09), c + Vector3(x, 0.0, side * 0.3), 0.022, frame, -1.0, 4)
		ModelKit.box(root, c + Vector3(x - 0.02, 0.145, -0.34), c + Vector3(x + 0.02, 0.17, 0.34), frame)
		ModelKit.box(root, c + Vector3(x - 0.02, 0.275, -0.19), c + Vector3(x + 0.02, 0.3, 0.19), frame)
	rod(root, c + Vector3(-0.24, 0.16, 0), c + Vector3(0.0, 0.29, 0), 0.016, frame, -1.0, 4)
	rod(root, c + Vector3(0.24, 0.16, 0), c + Vector3(0.0, 0.29, 0), 0.016, frame, -1.0, 4)
	# The cloth: checks of the cloth's colour and white, hanging a little over each side.
	for i in 4:
		for j in 7:
			var at := c + Vector3(-0.13 + i * 0.065, 0.326, -0.2275 + j * 0.065)
			ModelKit.box(root, at, at + Vector3(0.065, 0.005, 0.065),
				ModelKit.paint(cloth if (i + j) % 2 == 0 else WHITE), false)
	ModelKit.cylinder(root, c + Vector3(-0.03, 0.331, -0.05), 0.07, 0.022, ModelKit.paint(Color("#d9a35a")), 0.085, 12)
	ModelKit.cylinder(root, c + Vector3(-0.03, 0.353, -0.05), 0.07, 0.012, ModelKit.paint(Color("#b5442f")), 0.055, 12)
	ModelKit.cylinder(root, c + Vector3(0.07, 0.331, 0.09), 0.03, 0.075, ModelKit.paint(Color("#6fa8d6"), 0.5), 0.022, 10)
	ModelKit.cylinder(root, c + Vector3(0.07, 0.406, 0.09), 0.024, 0.008, ModelKit.paint(WHITE), -1.0, 10)


## A garden gnome facing +x: boots, a belted coat, arms and hands, a face with a round nose, cheeks and eyes
## over a long white beard, and a tall pointed hat that flops at its tip.
static func _gnome(root: Node3D, c: Vector3, hat: Color, coat: Color) -> void:
	var skin := Color("#f2c9a0")
	var white := ModelKit.paint(WHITE)
	for side: float in [-1.0, 1.0]:
		ModelKit.ball(root, c + Vector3(0.03, 0.022, side * 0.04), 0.036, ModelKit.paint(Color("#4a3322")),
			Vector3(1.5, 0.65, 1.0), true)
		ModelKit.ball(root, c + Vector3(0.02, 0.16, side * 0.085), 0.034, ModelKit.paint(coat.darkened(0.1)),
			Vector3(0.9, 1.5, 0.9), true)
		ModelKit.ball(root, c + Vector3(0.035, 0.115, side * 0.09), 0.022, ModelKit.paint(skin), Vector3.ONE, true)
		ModelKit.ball(root, c + Vector3(0.062, 0.262, side * 0.028), 0.0075, ModelKit.paint(Color("#16130f")))
		ModelKit.ball(root, c + Vector3(0.05, 0.238, side * 0.045), 0.016,
			ModelKit.paint(skin.lerp(Color("#f08a8a"), 0.5)), Vector3(0.5, 0.8, 1.0), true)
	ModelKit.ball(root, c + Vector3(0, 0.12, 0), 0.085, ModelKit.paint(coat), Vector3(1.0, 1.15, 1.05), true)
	ModelKit.cylinder(root, c + Vector3(0, 0.088, 0), 0.088, 0.022, ModelKit.paint(Color("#3a2a1c")), -1.0, 14)
	ModelKit.box(root, c + Vector3(0.078, 0.086, -0.016), c + Vector3(0.094, 0.112, 0.016),
		ModelKit.paint(Color("#e8c14a"), 0.5))
	ModelKit.ball(root, c + Vector3(0, 0.245, 0), 0.066, ModelKit.paint(skin), Vector3.ONE, true)
	ModelKit.ball(root, c + Vector3(0.045, 0.19, 0), 0.058, white, Vector3(0.75, 1.0, 1.05), true)   # the beard..
	ModelKit.cylinder(root, c + Vector3(0.06, 0.07, 0), 0.006, 0.1, white, 0.045, 8)               # ..to a point
	for side: float in [-1.0, 1.0]:
		ModelKit.ball(root, c + Vector3(0.062, 0.225, side * 0.022), 0.02, white, Vector3(0.7, 0.6, 1.3), true)
	ModelKit.ball(root, c + Vector3(0.07, 0.24, 0), 0.02, ModelKit.paint(skin.darkened(0.08)), Vector3.ONE, true)
	ModelKit.cylinder(root, c + Vector3(0, 0.275, 0), 0.075, 0.15, ModelKit.paint(hat), 0.022, 12)
	ModelKit.cylinder(root, c + Vector3(0, 0.27, 0), 0.079, 0.018, ModelKit.paint(hat.darkened(0.2)), -1.0, 12)
	rod(root, c + Vector3(0, 0.42, 0), c + Vector3(-0.035, 0.465, 0), 0.022, ModelKit.paint(hat), 0.008, 8)
	ModelKit.ball(root, c + Vector3(-0.04, 0.47, 0), 0.014, white)


## A street lamp: a stone foot, an iron post with a turned base and rings, a ladder bar, and a four-sided
## lantern with a warm light inside, under a pointed cap with a finial.
static func _lamp_post(root: Node3D, c: Vector3, col: Color, light: Color) -> void:
	var iron := ModelKit.paint(col, 0.5)
	ModelKit.box(root, c + Vector3(-0.08, 0, -0.08), c + Vector3(0.08, 0.045, 0.08), ModelKit.surface(STONE, "stone", 0.3))
	lathe(root, c, [Vector2(0.0, 0.045), Vector2(0.06, 0.045), Vector2(0.06, 0.07), Vector2(0.04, 0.1),
		Vector2(0.045, 0.13), Vector2(0.026, 0.17), Vector2(0.02, 0.4), Vector2(0.018, 0.66), Vector2(0.0, 0.66)], 10, iron)
	for y: float in [0.2, 0.42, 0.63]:
		ModelKit.cylinder(root, c + Vector3(0, y, 0), 0.031, 0.018, iron, -1.0, 10)
	ModelKit.box(root, c + Vector3(-0.085, 0.585, -0.006), c + Vector3(0.085, 0.597, 0.006), iron)
	for x: float in [-0.085, 0.085]:
		ModelKit.ball(root, c + Vector3(x, 0.591, 0), 0.011, iron)
	ModelKit.cylinder(root, c + Vector3(0, 0.66, 0), 0.03, 0.03, iron, 0.062, 4).rotation.y = PI / 4.0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			ModelKit.box(root, c + Vector3(sx * 0.043 - 0.005, 0.69, sz * 0.043 - 0.005),
				c + Vector3(sx * 0.043 + 0.005, 0.83, sz * 0.043 + 0.005), iron)
	ModelKit.box(root, c + Vector3(-0.04, 0.692, -0.04), c + Vector3(0.04, 0.828, 0.04), ModelKit.glass())
	ModelKit.ball(root, c + Vector3(0, 0.75, 0), 0.028, _glow(light), Vector3(1.0, 1.3, 1.0))
	ModelKit.cylinder(root, c + Vector3(0, 0.83, 0), 0.085, 0.065, iron, 0.012, 4).rotation.y = PI / 4.0
	ModelKit.ball(root, c + Vector3(0, 0.905, 0), 0.014, iron)


## A garden sundial: a square plinth, a turned stone pedestal, and a round dial with its hours marked and a
## brass gnomon standing on it.
static func _sundial(root: Node3D, c: Vector3, col: Color) -> void:
	var tone := col.lerp(BATH_STONE, 0.6)
	var stone := ModelKit.surface(tone, "stone", 0.3)
	var brass := ModelKit.paint(Color("#b8862f"), 0.7)
	ModelKit.box(root, c + Vector3(-0.14, 0, -0.14), c + Vector3(0.14, 0.04, 0.14), stone)
	lathe(root, c, [Vector2(0.0, 0.04), Vector2(0.1, 0.04), Vector2(0.1, 0.06), Vector2(0.065, 0.09), Vector2(0.055, 0.14),
		Vector2(0.075, 0.2), Vector2(0.06, 0.26), Vector2(0.07, 0.29), Vector2(0.15, 0.31), Vector2(0.16, 0.325),
		Vector2(0.16, 0.345), Vector2(0.0, 0.345)], 16, ModelKit.paint(tone.lightened(0.04)))
	ModelKit.cylinder(root, c + Vector3(0, 0.345, 0), 0.14, 0.006, ModelKit.paint(tone.lightened(0.14)), -1.0, 20)
	ModelKit.cylinder(root, c + Vector3(0, 0.351, 0), 0.05, 0.004, brass, -1.0, 14)
	for k in 12:   # the hours
		var ang := TAU * k / 12.0
		var mark := ModelKit.box(root, Vector3(-0.004, 0, -0.016), Vector3(0.004, 0.004, 0.016),
			ModelKit.paint(Color("#4a4238")), false)
		mark.position = c + Vector3(cos(ang) * 0.112, 0.353, sin(ang) * 0.112)
		mark.rotation.y = -ang + PI / 2.0
	# The gnomon: a thin brass wedge, low at one end and standing at the other.
	var low := c + Vector3(0.09, 0.351, 0)
	var foot := c + Vector3(-0.09, 0.351, 0)
	var tip := c + Vector3(-0.09, 0.44, 0)
	var thick := Vector3(0, 0, 0.004)
	ModelKit.faces(root, [[foot + thick, low + thick, tip + thick], [foot - thick, low - thick, tip - thick],
		[tip + thick, low + thick, low - thick, tip - thick], [foot + thick, tip + thick, tip - thick, foot - thick]],
		c + Vector3(-0.03, 0.38, 0), brass)
	for k in 5:   # moss at the foot
		var ang := k * 1.3 + 0.4
		ModelKit.ball(root, c + Vector3(cos(ang) * 0.13, 0.03, sin(ang) * 0.13), 0.03,
			ModelKit.paint(Color("#5f8a3a").darkened(0.1 * (k % 3))), Vector3(1.4, 0.6, 1.0))


## A country mailbox: a post with a bracket, an arched box with a door and its knob, the red flag up on its
## arm, a letter in the door, and flowers at the foot.
static func _mailbox(root: Node3D, c: Vector3, col: Color, id: String) -> void:
	var wood := ModelKit.paint(WOOD)
	var body := ModelKit.paint(col, 0.5)
	ModelKit.box(root, c + Vector3(-0.022, 0, -0.022), c + Vector3(0.022, 0.4, 0.022), wood)
	ModelKit.box(root, c + Vector3(-0.13, 0.385, -0.05), c + Vector3(0.13, 0.405, 0.05), ModelKit.paint(DARK_WOOD))
	rod(root, c + Vector3(0, 0.27, 0), c + Vector3(0.09, 0.385, 0), 0.012, ModelKit.paint(DARK_WOOD), -1.0, 4)
	ModelKit.box(root, c + Vector3(-0.125, 0.405, -0.065), c + Vector3(0.125, 0.47, 0.065), body)
	var arch := ModelKit.cylinder(root, Vector3.ZERO, 0.065, 0.25, body, -1.0, 14)
	arch.rotation.z = PI / 2.0
	arch.position = c + Vector3(0, 0.47, 0)
	_disc(root, c + Vector3(0.126, 0.47, 0), 0.058, 0.006, ModelKit.paint(col.darkened(0.22), 0.5))   # the door
	ModelKit.box(root, c + Vector3(0.126, 0.41, -0.058), c + Vector3(0.132, 0.47, 0.058),
		ModelKit.paint(col.darkened(0.22), 0.5))
	ModelKit.ball(root, c + Vector3(0.136, 0.5, 0), 0.01, ModelKit.paint(Color("#e8c14a"), 0.6))
	ModelKit.box(root, c + Vector3(0.1, 0.43, -0.035), c + Vector3(0.16, 0.436, 0.02), ModelKit.paint(WHITE))   # a letter
	var red := ModelKit.paint(Color("#d8382f"))
	ModelKit.box(root, c + Vector3(-0.03, 0.44, 0.066), c + Vector3(-0.018, 0.6, 0.072), red)   # the flag's arm, up
	ModelKit.box(root, c + Vector3(-0.03, 0.54, 0.066), c + Vector3(0.04, 0.6, 0.072), red)
	ModelKit.ball(root, c + Vector3(-0.024, 0.445, 0.07), 0.01, ModelKit.paint(Color("#3a3a3a")))
	var rng := _rng(id)
	for k in 5:   # grass and a few flowers at the foot
		var ang := rng.randf() * TAU
		var at := c + Vector3(cos(ang) * 0.06, 0, sin(ang) * 0.06)
		ModelKit.cylinder(root, at, 0.012, rng.randf_range(0.06, 0.11), ModelKit.paint(LEAF.lightened(rng.randf() * 0.2), 0.0,
			0.3), 0.0, 4)
		if k < 3:
			ModelKit.ball(root, at + Vector3(0.015, 0.07, 0.01), 0.016,
				ModelKit.paint([Color("#f2d24a"), Color("#f0f0e8"), Color("#e86a8a")][k]))


## A scarecrow facing +x on its post and crossbar: a stuffed burlap head with button eyes, a patch nose and a
## stitched smile under a straw hat, a patched shirt with straw at the cuffs, neck and waist, and a crow on
## its arm that it is not scaring.
static func _scarecrow(root: Node3D, c: Vector3, hat_col: Color, id: String) -> void:
	var rng := _rng(id)
	var wood := ModelKit.paint(DARK_WOOD)
	var shirt := Color("#4a6fa5")
	ModelKit.box(root, c + Vector3(-0.02, 0, -0.02), c + Vector3(0.02, 0.7, 0.02), wood)
	ModelKit.box(root, c + Vector3(-0.018, 0.455, -0.3), c + Vector3(0.018, 0.49, 0.3), wood)
	ModelKit.ball(root, c + Vector3(0, 0.4, 0), 0.1, ModelKit.paint(shirt), Vector3(0.72, 1.25, 1.1), true)
	for side: float in [-1.0, 1.0]:
		rod(root, c + Vector3(0, 0.475, side * 0.07), c + Vector3(0, 0.468, side * 0.25), 0.046, ModelKit.paint(shirt), 0.038,
			8)
		for k in 6:   # straw at the cuff
			var out := Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.05, 0.03), side * rng.randf_range(0.05, 0.09))
			rod(root, c + Vector3(0, 0.468, side * 0.245), c + Vector3(0, 0.468, side * 0.245) + out, 0.006,
				ModelKit.paint(HAY.darkened(rng.randf() * 0.15)), 0.002, 4)
	for patch: Array in [[Vector3(0.068, 0.42, 0.03), Color("#c9483b")], [Vector3(0.066, 0.36, -0.04), Color("#e3c46a")]]:
		var at: Vector3 = c + (patch[0] as Vector3)
		ModelKit.box(root, at - Vector3(0.004, 0.022, 0.022), at + Vector3(0.004, 0.022, 0.022), ModelKit.paint(patch[1]))
	ModelKit.cylinder(root, c + Vector3(0, 0.3, 0), 0.078, 0.016, ModelKit.paint(Color("#b89a6a")), -1.0, 12)
	for k in 12:   # a skirt of straw below the rope belt, and a ruff of it at the neck
		var ang := TAU * k / 12.0
		var foot := c + Vector3(cos(ang) * 0.085, 0.2 + rng.randf_range(-0.02, 0.02), sin(ang) * 0.1)
		rod(root, c + Vector3(cos(ang) * 0.06, 0.3, sin(ang) * 0.07), foot, 0.008,
			ModelKit.paint(HAY.darkened(rng.randf() * 0.15)), 0.003, 4)
		rod(root, c + Vector3(0, 0.52, 0), c + Vector3(cos(ang) * 0.07, 0.5, sin(ang) * 0.07), 0.007, ModelKit.paint(HAY),
			0.002, 4)
	ModelKit.ball(root, c + Vector3(0, 0.6, 0), 0.085, ModelKit.paint(Color("#dcc08a")), Vector3(1.0, 1.02, 1.0), true)
	for side: float in [-1.0, 1.0]:
		ModelKit.ball(root, c + Vector3(0.074, 0.618, side * 0.032), 0.013, ModelKit.paint(Color("#1c1815")))
	ModelKit.ball(root, c + Vector3(0.084, 0.598, 0), 0.013, ModelKit.paint(Color("#c9483b")))
	for k in 5:   # the stitched smile
		var z := lerpf(-0.036, 0.036, k / 4.0)
		ModelKit.ball(root, c + Vector3(0.076, 0.566 + 0.014 * pow(z / 0.036, 2.0), z), 0.006,
			ModelKit.paint(Color("#3a2a1c")))
	var hat := Node3D.new()
	hat.position = c + Vector3(-0.01, 0.665, 0)
	hat.rotation.z = 0.12
	root.add_child(hat)
	ModelKit.cylinder(hat, Vector3.ZERO, 0.16, 0.012, ModelKit.paint(hat_col), 0.15, 16)
	ModelKit.cylinder(hat, Vector3.ZERO, 0.085, 0.085, ModelKit.paint(hat_col), 0.07, 12)
	ModelKit.cylinder(hat, Vector3(0, 0.012, 0), 0.087, 0.02, ModelKit.paint(Color("#a8402f")), -1.0, 12)
	var crow := songbird(Color("#2b2b33"), Color("#3c3c46"))
	crow.position = c + Vector3(0, 0.49, -0.2)
	crow.rotation.y = -PI / 2.0 - 0.4
	crow.scale = Vector3.ONE * 1.15
	root.add_child(crow)


## A wheelbarrow, its wheel toward +x: a tray with a sloped nose full of soil and seedlings, a wheel with a
## tyre, rim and hub in a fork, two legs, and long handles with grips.
static func _wheelbarrow(root: Node3D, c: Vector3, col: Color) -> void:
	var paint := ModelKit.paint(col, 0.5)
	var metal := ModelKit.paint(Color("#5a6066"), 0.5)
	var wood := ModelKit.paint(WOOD)
	ModelKit.tub(root, c + Vector3(-0.17, 0.13, -0.12), c + Vector3(0.13, 0.25, 0.12), 0.014, paint,
		ModelKit.paint(Color("#5e3d24")), 0.85)
	var nose := [c + Vector3(0.13, 0.13, -0.12), c + Vector3(0.13, 0.13, 0.12), c + Vector3(0.13, 0.25, 0.12),
		c + Vector3(0.13, 0.25, -0.12), c + Vector3(0.22, 0.25, -0.1), c + Vector3(0.22, 0.25, 0.1)]
	ModelKit.faces(root, [[nose[0], nose[1], nose[5], nose[4]], [nose[0], nose[4], nose[3]], [nose[1], nose[2], nose[5]],
		[nose[3], nose[4], nose[5], nose[2]]], c + Vector3(0.16, 0.2, 0), paint)
	ModelKit.ball(root, c + Vector3(-0.02, 0.235, 0), 0.11, ModelKit.paint(Color("#6b4a2b")), Vector3(1.25, 0.32, 0.95))
	for k in 3:   # seedlings in the soil
		var at := c + Vector3(-0.1 + k * 0.08, 0.26, (k % 2) * 0.06 - 0.03)
		ModelKit.cylinder(root, at, 0.005, 0.05, ModelKit.paint(LEAF), -1.0, 4)
		for side: float in [-1.0, 1.0]:
			ModelKit.ball(root, at + Vector3(side * 0.018, 0.05, 0), 0.02, ModelKit.paint(LEAF.lightened(0.15)),
				Vector3(1.3, 0.35, 0.8))
	for part: Array in [[0.075, 0.036, Color("#26262a")], [0.05, 0.04, Color("#b9bec4")], [0.016, 0.06, col]]:
		var wheel := ModelKit.cylinder(root, Vector3.ZERO, float(part[0]), float(part[1]), ModelKit.paint(part[2], 0.3),
			-1.0, 14)
		wheel.rotation.x = PI / 2.0
		wheel.position = c + Vector3(0.23, 0.075, 0)
	for side: float in [-1.0, 1.0]:
		rod(root, c + Vector3(0.1, 0.14, side * 0.06), c + Vector3(0.23, 0.075, side * 0.035), 0.008, metal, -1.0, 4)
		rod(root, c + Vector3(-0.12, 0.14, side * 0.1), c + Vector3(-0.15, 0.0, side * 0.11), 0.009, metal, -1.0, 4)
		rod(root, c + Vector3(0.1, 0.15, side * 0.09), c + Vector3(-0.4, 0.27, side * 0.11), 0.011, wood, -1.0, 6)
		rod(root, c + Vector3(-0.34, 0.255, side * 0.107), c + Vector3(-0.42, 0.275, side * 0.111), 0.016,
			ModelKit.paint(Color("#2a2a2a")), -1.0, 6)
	ModelKit.box(root, c + Vector3(-0.157, 0.02, -0.11), c + Vector3(-0.143, 0.034, 0.11), metal)


## A park bench with its back toward -x: slats for the seat and the back, each its own shade, on iron sides
## with curved legs and armrests.
static func _bench(root: Node3D, c: Vector3, col: Color, id: String) -> void:
	var rng := _rng(id)
	var iron := ModelKit.paint(Color("#2f2f33"), 0.4)
	for k in 4:
		var x := -0.085 + k * 0.05
		ModelKit.box(root, c + Vector3(x, 0.17, -0.31), c + Vector3(x + 0.042, 0.187, 0.31),
			ModelKit.surface(col.darkened(rng.randf() * 0.12), "boards", 0.0))
	for k in 3:
		var y := 0.235 + k * 0.058
		var x := -0.105 - k * 0.012
		ModelKit.box(root, c + Vector3(x - 0.012, y, -0.31), c + Vector3(x, y + 0.046, 0.31),
			ModelKit.surface(col.darkened(rng.randf() * 0.12), "boards", 0.0))
	for z: float in [-0.27, 0.27]:
		rod(root, c + Vector3(0.11, 0, z), c + Vector3(0.09, 0.17, z), 0.012, iron, -1.0, 6)
		rod(root, c + Vector3(-0.07, 0, z), c + Vector3(-0.1, 0.17, z), 0.012, iron, -1.0, 6)
		rod(root, c + Vector3(-0.1, 0.17, z), c + Vector3(-0.145, 0.41, z), 0.011, iron, -1.0, 6)
		rod(root, c + Vector3(-0.1, 0.17, z), c + Vector3(0.09, 0.17, z), 0.011, iron, -1.0, 6)
		rod(root, c + Vector3(0.09, 0.17, z), c + Vector3(0.105, 0.275, z), 0.009, iron, -1.0, 6)
		rod(root, c + Vector3(0.115, 0.28, z), c + Vector3(-0.125, 0.3, z), 0.012, iron, -1.0, 6)
		ModelKit.ball(root, c + Vector3(0.118, 0.28, z), 0.016, iron)
		for x: float in [0.11, -0.07]:
			ModelKit.ball(root, c + Vector3(x, 0.008, z), 0.018, iron, Vector3(1.2, 0.5, 1.0))


## A stone well: a ring of stones round the water with capstones on its rim, on a step; two posts carrying a
## shingled roof; a windlass with its rope and a crank; the bucket hanging over the water; ivy at the foot.
static func _well(root: Node3D, c: Vector3, col: Color, id: String) -> void:
	var rng := _rng(id)
	var tone := col.lerp(BATH_STONE, 0.6)
	ModelKit.cylinder(root, c, 0.34, 0.03, ModelKit.surface(tone.darkened(0.12), "stone", 0.3), -1.0, 16)
	lathe(root, c, [Vector2(0.0, 0.03), Vector2(0.29, 0.03), Vector2(0.3, 0.06), Vector2(0.285, 0.28), Vector2(0.3, 0.3),
		Vector2(0.3, 0.32), Vector2(0.215, 0.32), Vector2(0.21, 0.2), Vector2(0.0, 0.2)], 18,
		ModelKit.surface(tone, "stone", 0.3))
	for k in 12:   # the rim's capstones, each its own shade
		var ang := TAU * k / 12.0
		var cap := ModelKit.box(root, Vector3(-0.045, 0, -0.062), Vector3(0.045, 0.028, 0.062),
			ModelKit.paint(tone.lightened(0.06).darkened(rng.randf() * 0.16)))
		cap.position = c + Vector3(cos(ang) * 0.258, 0.334, sin(ang) * 0.258)
		cap.rotation.y = -ang
	ModelKit.cylinder(root, c + Vector3(0, 0.2, 0), 0.21, 0.02 + WATER_LIFT, ModelKit.water(), -1.0, 16)
	var bucket := Node3D.new()
	ModelKit.cylinder(bucket, Vector3.ZERO, 0.06, 0.08, ModelKit.paint(WOOD), 0.07, 10)
	ModelKit.cylinder(bucket, Vector3(0, 0.06, 0), 0.072, 0.012, ModelKit.paint(Color("#5a6066"), 0.4), -1.0, 10)
	ModelKit.box(bucket, Vector3(-0.003, 0.08, -0.003), Vector3(0.003, 0.26, 0.003), ModelKit.paint(Color("#c9b38a")))
	DecorMotion.orbit(root, c + Vector3(0, 0.34, 0), bucket, DecorMotion.BOBBING)
	for z: float in [-0.265, 0.265]:
		ModelKit.box(root, c + Vector3(-0.025, 0.3, z - 0.025), c + Vector3(0.025, 0.78, z + 0.025), ModelKit.paint(WOOD))
		rod(root, c + Vector3(0, 0.66, z), c + Vector3(0.1, 0.78, z), 0.012, ModelKit.paint(DARK_WOOD), -1.0, 4)
		rod(root, c + Vector3(0, 0.66, z), c + Vector3(-0.1, 0.78, z), 0.012, ModelKit.paint(DARK_WOOD), -1.0, 4)
	var top := ModelKit.roof(root, "gable", c + Vector3(-0.2, 0.78, -0.33), c + Vector3(0.2, 0.78, 0.33), 0.17, 0.04,
		ModelKit.surface(Color("#8e3b2c"), "shingles", 0.0), ModelKit.paint(WOOD))
	ModelKit.box(root, Vector3(c.x - 0.014, top - 0.01, c.z - 0.38), Vector3(c.x + 0.014, top + 0.014, c.z + 0.38),
		ModelKit.paint(Color("#6e2c20")))
	rod(root, c + Vector3(0, 0.6, -0.29), c + Vector3(0, 0.6, 0.36), 0.018, ModelKit.paint(DARK_WOOD), -1.0, 6)
	rod(root, c + Vector3(0, 0.6, -0.07), c + Vector3(0, 0.6, 0.07), 0.04, ModelKit.paint(Color("#c9b38a")), -1.0, 10)
	rod(root, c + Vector3(0, 0.6, 0.36), c + Vector3(0, 0.52, 0.36), 0.01, ModelKit.paint(Color("#5a6066"), 0.4), -1.0, 4)
	rod(root, c + Vector3(0, 0.52, 0.36), c + Vector3(0, 0.52, 0.43), 0.012, ModelKit.paint(DARK_WOOD), -1.0, 6)
	for k in 9:   # ivy creeping up the stones
		var ang := rng.randf() * TAU
		var y := rng.randf_range(0.04, 0.22)
		ModelKit.ball(root, c + Vector3(cos(ang) * 0.3, y, sin(ang) * 0.3), rng.randf_range(0.025, 0.04),
			ModelKit.paint(LEAF.darkened(rng.randf() * 0.2)), Vector3(1.2, 0.8, 1.2))


## A garden arbor: four posts on blocks with caps, beams and rafters overhanging above, a ladder of slats up
## each side, and a climbing rose winding up the posts and over the top.
static func _arbor(root: Node3D, col: Color, bloom: Color, id: String) -> void:
	var rng := _rng(id)
	var paint := ModelKit.paint(col)
	var shade := ModelKit.paint(col.darkened(0.12))
	for x: float in [0.2, 0.8]:
		for z: float in [0.3, 0.7]:
			ModelKit.box(root, Vector3(x - 0.04, 0, z - 0.04), Vector3(x + 0.04, 0.05, z + 0.04), shade)
			ModelKit.box(root, Vector3(x - 0.026, 0.05, z - 0.026), Vector3(x + 0.026, 0.76, z + 0.026), paint)
		for k in 5:   # the side's slats
			var y := 0.14 + k * 0.125
			ModelKit.box(root, Vector3(x - 0.008, y, 0.3), Vector3(x + 0.008, y + 0.024, 0.7), shade)
	for z: float in [0.3, 0.7]:
		ModelKit.box(root, Vector3(0.08, 0.76, z - 0.02), Vector3(0.92, 0.81, z + 0.02), paint)
	for k in 7:
		var x := 0.14 + 0.12 * k
		ModelKit.box(root, Vector3(x - 0.012, 0.81, 0.2), Vector3(x + 0.012, 0.845, 0.8), shade)
	var leaf_at: Array[Vector3] = []
	for x: float in [0.2, 0.8]:
		for z: float in [0.3, 0.7]:
			for k in 7:   # up a post, winding round it
				var ang := k * 1.7 + x * 3.0 + z
				leaf_at.append(Vector3(x + cos(ang) * 0.04, 0.1 + k * 0.1, z + sin(ang) * 0.04))
	for k in 22:   # over the top
		leaf_at.append(Vector3(rng.randf_range(0.12, 0.88), rng.randf_range(0.83, 0.9), rng.randf_range(0.22, 0.78)))
	for k in leaf_at.size():
		ModelKit.facet_ball(root, leaf_at[k], rng.randf_range(0.04, 0.06),
			ModelKit.paint(LEAF.darkened(rng.randf() * 0.18).lightened(rng.randf() * 0.1)), Vector3(1.2, 0.7, 1.2))
		if k % 3 == 0:
			ModelKit.ball(root, leaf_at[k] + Vector3(0.025, 0.03, 0.02), 0.03,
				ModelKit.paint(bloom.lightened(rng.randf() * 0.2)), Vector3(1.0, 0.8, 1.0))


## A garden gazebo: a boarded deck on a base with a step, eight posts with a rail and balusters between them
## (one side open), a beam round the top, and a shingled roof in two tiers with a trimmed eave and a finial.
static func _gazebo(root: Node3D, c: Vector3, col: Color, roof_col: Color) -> void:
	var paint := ModelKit.paint(col)
	var shingles := ModelKit.surface(roof_col, "shingles", 0.0)
	var turn := PI / 8.0   # (an eight-sided piece turned so its corners meet the posts)
	ModelKit.cylinder(root, c, 0.88, 0.05, ModelKit.surface(STONE, "stone", 0.3), -1.0, 8).rotation.y = turn
	ModelKit.cylinder(root, c + Vector3(0, 0.05, 0), 0.82, 0.05, ModelKit.surface(Color("#c8a26a"), "boards", 0.2), -1.0,
		8).rotation.y = turn
	var posts: Array[Vector3] = []
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		posts.append(c + Vector3(cos(a) * 0.74, 0.1, sin(a) * 0.74))
		ModelKit.box(root, posts[k] - Vector3(0.028, 0, 0.028), posts[k] + Vector3(0.028, 0.8, 0.028), paint)
		ModelKit.box(root, posts[k] - Vector3(0.04, 0, 0.04), posts[k] + Vector3(0.04, 0.05, 0.04), paint)
	for k in 8:
		var a := posts[k]
		var b := posts[(k + 1) % 8]
		rod(root, a + Vector3(0, 0.74, 0), b + Vector3(0, 0.74, 0), 0.02, paint, -1.0, 4)   # the beam round the top
		if k == 0:
			continue   # the way in
		rod(root, a + Vector3(0, 0.3, 0), b + Vector3(0, 0.3, 0), 0.014, paint, -1.0, 4)
		rod(root, a + Vector3(0, 0.08, 0), b + Vector3(0, 0.08, 0), 0.012, paint, -1.0, 4)
		for j in range(1, 5):
			var at := a.lerp(b, j / 5.0)
			ModelKit.box(root, at + Vector3(-0.008, 0.08, -0.008), at + Vector3(0.008, 0.3, 0.008), paint)
	var way := (posts[0] + posts[1]) / 2.0
	var out := (way - c).normalized()
	out.y = 0.0
	var step := ModelKit.box(root, Vector3(-0.2, 0, -0.07), Vector3(0.2, 0.05, 0.07),
		ModelKit.surface(STONE, "stone", 0.3))
	step.position = Vector3(way.x, 0.025, way.z) + out * 0.2
	step.rotation.y = atan2(out.x, out.z)
	ModelKit.cylinder(root, c + Vector3(0, 0.88, 0), 0.97, 0.03, paint, -1.0, 8).rotation.y = turn
	ModelKit.cylinder(root, c + Vector3(0, 0.91, 0), 0.94, 0.34, shingles, 0.3, 8).rotation.y = turn
	ModelKit.cylinder(root, c + Vector3(0, 1.25, 0), 0.26, 0.09, paint, -1.0, 8).rotation.y = turn
	ModelKit.cylinder(root, c + Vector3(0, 1.34, 0), 0.36, 0.2, shingles, 0.03, 8).rotation.y = turn
	ModelKit.cylinder(root, c + Vector3(0, 1.54, 0), 0.012, 0.08, ModelKit.paint(Color("#d4b04a"), 0.7), -1.0, 6)
	ModelKit.ball(root, c + Vector3(0, 1.63, 0), 0.04, ModelKit.paint(Color("#d4b04a"), 0.7))


## A farm stand: a boarded counter with crates of produce tilted to the front, pumpkins beside it, a sign on
## its face, and a striped awning on four posts with a scalloped edge.
static func _farm_stand(root: Node3D, c: Vector3, col: Color, id: String) -> void:
	var rng := _rng(id)
	var wood := ModelKit.paint(WOOD)
	ModelKit.box(root, c + Vector3(-0.34, 0, -0.08), c + Vector3(0.34, 0.26, 0.2), ModelKit.surface(WOOD, "boards", 0.2))
	ModelKit.box(root, c + Vector3(-0.36, 0.26, -0.1), c + Vector3(0.36, 0.285, 0.22),
		ModelKit.paint(WOOD.lightened(0.12)))
	var produce := [[Color("#d83a2f"), Color("#e8563a")], [Color("#f2a33a"), Color("#f6c14a")],
		[Color("#6fae3a"), Color("#8fc24a")]]
	for k in 3:
		var crate := Node3D.new()
		crate.position = c + Vector3(-0.22 + k * 0.22, 0.285, 0.06)
		crate.rotation.x = 0.3
		root.add_child(crate)
		ModelKit.tub(crate, Vector3(-0.09, 0, -0.075), Vector3(0.09, 0.07, 0.075), 0.012,
			ModelKit.surface(WOOD.lightened(0.2), "boards", 0.0))
		for j in 6:
			ModelKit.ball(crate, Vector3(-0.05 + (j % 3) * 0.05 + rng.randf_range(-0.008, 0.008), 0.06 + (j / 3) * 0.012,
				-0.03 + (j / 3) * 0.06), 0.032, ModelKit.paint(produce[k][j % 2]), Vector3.ONE, true)
	for k in 2:   # pumpkins on the ground beside the counter
		var at := c + Vector3(0.4, 0.045 + k * 0.01, 0.1 - k * 0.14)
		ModelKit.ball(root, at, 0.06 - k * 0.01, ModelKit.paint(Color("#ee8a2a").darkened(k * 0.1)), Vector3(1.0, 0.78, 1.0),
			true)
		ModelKit.cylinder(root, at + Vector3(0, 0.04, 0), 0.008, 0.025, ModelKit.paint(Color("#5d7a2c")), -1.0, 5)
	ModelKit.box(root, c + Vector3(-0.14, 0.07, 0.2), c + Vector3(0.14, 0.2, 0.212), ModelKit.paint(Color("#f6ecd2")))
	ModelKit.box(root, c + Vector3(-0.15, 0.06, 0.198), c + Vector3(0.15, 0.21, 0.204), ModelKit.paint(DARK_WOOD))
	for k in 3:
		ModelKit.ball(root, c + Vector3(-0.07 + k * 0.07, 0.135, 0.214), 0.028, ModelKit.paint(produce[k][0]),
			Vector3(1.0, 1.0, 0.2))
	for x: float in [-0.37, 0.37]:
		ModelKit.box(root, c + Vector3(x - 0.02, 0, -0.26), c + Vector3(x + 0.02, 0.78, -0.22), wood)
		ModelKit.box(root, c + Vector3(x - 0.02, 0, 0.26), c + Vector3(x + 0.02, 0.66, 0.3), wood)
	var stripes := 8
	var slope := atan2(0.14, 0.66)
	for k in stripes:   # the awning, sloping down to the front, and its scalloped edge
		var x := -0.42 + 0.84 * (k + 0.5) / stripes
		var cloth := ModelKit.paint(col if k % 2 == 0 else WHITE)
		var stripe := ModelKit.box(root, Vector3(-0.42 / stripes, -0.006, -0.34), Vector3(0.42 / stripes, 0.006, 0.34), cloth)
		stripe.position = c + Vector3(x, 0.735, 0.01)
		stripe.rotation.x = slope
		ModelKit.cylinder(root, c + Vector3(x, 0.605, 0.343), 0.42 / stripes, 0.012, cloth, -1.0, 8).rotation.x = PI / 2.0


## A mastery sign facing +x: a framed board on a post, with the mastered thing's rosette on it (a gold ring
## round its colour, a gold middle, two ribbon tails) and a gold cap on top.
static func _mastery_sign(root: Node3D, c: Vector3, accent: Color) -> void:
	var gold := ModelKit.paint(Color("#e8c14a"), 0.6)
	ModelKit.box(root, c + Vector3(-0.018, 0, -0.018), c + Vector3(0.018, 0.34, 0.018), ModelKit.paint(WOOD))
	ModelKit.box(root, c + Vector3(-0.022, 0.3, -0.24), c + Vector3(0.022, 0.64, 0.24), ModelKit.paint(DARK_WOOD))
	ModelKit.box(root, c + Vector3(-0.026, 0.325, -0.215), c + Vector3(0.026, 0.615, 0.215),
		ModelKit.paint(Color("#f6ecd2")))
	for side: float in [-1.0, 1.0]:
		var tail := ModelKit.box(root, Vector3(-0.003, -0.11, -0.022), Vector3(0.003, 0.0, 0.022),
			ModelKit.paint(accent.darkened(0.2)))
		tail.position = c + Vector3(0.03, 0.45, side * 0.03)
		tail.rotation.x = side * 0.35
		for k in 3:   # laurel leaves each side
			ModelKit.ball(root, c + Vector3(0.03, 0.4 + k * 0.05, side * (0.15 - k * 0.012)), 0.022,
				ModelKit.paint(Color("#5f9a3a").darkened(0.08 * k)), Vector3(0.25, 1.3, 0.7))
	_disc(root, c + Vector3(0.03, 0.49, 0), 0.085, 0.008, gold)
	_disc(root, c + Vector3(0.034, 0.49, 0), 0.068, 0.008, ModelKit.paint(accent))
	_disc(root, c + Vector3(0.038, 0.49, 0), 0.03, 0.008, gold)
	ModelKit.cylinder(root, c + Vector3(0, 0.64, 0), 0.03, 0.03, gold, 0.006, 4).rotation.y = PI / 4.0


## A perfect bunch: a glazed pot with a ribbon, leafy stems of different heights leaning out of it, each with
## a flower of five petals round a golden middle.
static func _bunch(root: Node3D, c: Vector3, accent: Color, id: String) -> void:
	var rng := _rng(id)
	var pot := Color("#f29ab8")
	lathe(root, c, [Vector2(0.0, 0.0), Vector2(0.055, 0.0), Vector2(0.085, 0.07), Vector2(0.07, 0.12),
		Vector2(0.078, 0.135), Vector2(0.06, 0.135), Vector2(0.0, 0.12)], 12, ModelKit.paint(pot, 0.5))
	ModelKit.cylinder(root, c + Vector3(0, 0.085, 0), 0.08, 0.016, ModelKit.paint(accent.darkened(0.25)), 0.076, 12)
	for side: float in [-1.0, 1.0]:
		ModelKit.ball(root, c + Vector3(0.082, 0.093, side * 0.022), 0.02, ModelKit.paint(accent.darkened(0.25)),
			Vector3(0.5, 0.8, 1.2))
	for k in 8:
		var ang := TAU * k / 8.0 + rng.randf_range(-0.2, 0.2)
		var lean := 0.03 if k == 0 else rng.randf_range(0.07, 0.13)
		var top := c + Vector3(cos(ang) * lean, rng.randf_range(0.3, 0.42), sin(ang) * lean)
		rod(root, c + Vector3(cos(ang) * 0.02, 0.12, sin(ang) * 0.02), top, 0.007, ModelKit.paint(Color("#4f8a2f")), 0.005, 4)
		var mid := (c + Vector3(0, 0.12, 0)).lerp(top, 0.55)
		ModelKit.ball(root, mid + Vector3(cos(ang) * 0.02, 0, sin(ang) * 0.02), 0.028,
			ModelKit.paint(LEAF.lightened(rng.randf() * 0.15)), Vector3(1.3, 0.35, 0.8))
		var petal := ModelKit.paint(accent.lightened(rng.randf() * 0.18))
		for j in 5:
			var b := TAU * j / 5.0 + ang
			ModelKit.ball(root, top + Vector3(cos(b) * 0.03, 0.0, sin(b) * 0.03), 0.032, petal, Vector3(1.0, 0.5, 1.0), true)
		ModelKit.ball(root, top + Vector3(0, 0.01, 0), 0.017, ModelKit.paint(Color("#f2c230")))


## A birdhouse on its post: a stone footing, a braced landing board, a boarded house under an overhanging roof
## with a ridge cap, a round door with its ring and a perch below it, a bird on the perch, a vine up the post
## and another bird circling above.
static func _birdhouse(root: Node3D, c: Vector3, col: Color, wall: Color, id: String) -> void:
	var wood := ModelKit.paint(WOOD)
	var dark := ModelKit.paint(DARK_WOOD)
	var rng := _rng(id)
	ModelKit.cylinder(root, c, 0.07, 0.03, ModelKit.surface(STONE, "stone", 0.3), 0.05, 8)
	ModelKit.box(root, c + Vector3(-0.02, 0.02, -0.02), c + Vector3(0.02, HOUSE_AT, 0.02), wood)
	ModelKit.box(root, c + Vector3(-0.028, HOUSE_AT - 0.05, -0.028), c + Vector3(0.028, HOUSE_AT - 0.03, 0.028), dark)
	for side: float in [-1.0, 1.0]:   # a brace each way under the landing board
		var brace := ModelKit.box(root, c + Vector3(side * 0.05 - 0.01, HOUSE_AT - 0.12, -0.01),
			c + Vector3(side * 0.05 + 0.01, HOUSE_AT, 0.01), dark)
		brace.rotation.z = side * 0.75
	ModelKit.box(root, c + Vector3(-0.17, HOUSE_AT, -0.13), c + Vector3(0.17, HOUSE_AT + 0.02, 0.13), wood)
	var lo := c + Vector3(-0.115, HOUSE_AT + 0.02, -0.095)
	var hi := c + Vector3(0.115, HOUSE_AT + 0.2, 0.095)
	ModelKit.box(root, lo, hi, ModelKit.surface(wall, "boards", 0.0))
	for sx: float in [-1.0, 1.0]:   # corner boards
		for sz: float in [-1.0, 1.0]:
			var at := Vector3(sx * 0.115, 0, sz * 0.095)
			ModelKit.box(root, c + at + Vector3(-0.012, HOUSE_AT + 0.02, -0.012),
				c + at + Vector3(0.012, HOUSE_AT + 0.2, 0.012), ModelKit.paint(wall.darkened(0.18)))
	var top := ModelKit.roof(root, "gable", lo, hi, 0.1, 0.04, ModelKit.paint(col),
		ModelKit.surface(wall, "boards", 0.0))
	ModelKit.box(root, Vector3(lo.x - 0.05, top - 0.012, c.z - 0.014), Vector3(hi.x + 0.05, top + 0.012, c.z + 0.014),
		ModelKit.paint(col.darkened(0.25)))
	# The door: a dark round hole in a ring, on the gable end, and the perch below it.
	var door := c + Vector3(0.116, HOUSE_AT + 0.13, 0)
	_disc(root, door, 0.05, 0.008, ModelKit.paint(col))
	_disc(root, door + Vector3(0.004, 0, 0), 0.034, 0.008, ModelKit.paint(Color("#1d1712")))
	_disc(root, door + Vector3(0.03, -0.075, 0), 0.008, 0.07, dark)
	var sitter := songbird(Color("#d8553a"), Color("#f1dfc4"))
	sitter.position = door + Vector3(0.05, -0.066, 0)
	sitter.rotation.y = -PI / 2.0 + 0.5
	root.add_child(sitter)
	for k in 7:   # a vine winding up the post
		var ang := k * 1.9 + rng.randf() * 0.4
		var leaf_at := c + Vector3(cos(ang) * 0.03, 0.06 + k * 0.055, sin(ang) * 0.03)
		ModelKit.ball(root, leaf_at, 0.022, ModelKit.paint(LEAF.lightened(rng.randf() * 0.25), 0.0, 0.15),
			Vector3(1.3, 0.6, 1.0))
	ModelKit.ball(root, c + Vector3(0.035, 0.2, 0.01), 0.014, ModelKit.paint(Color("#f2d24a")))
	DecorMotion.orbit(root, c + Vector3(0, HOUSE_AT + 0.42, 0), DecorMotion.bird(Color("#6f8fc9")),
		DecorMotion.CIRCLING)


## A stone birdbath: a square plinth, a turned baluster, a wide basin with a rolled rim standing above the
## water it holds, moss and pebbles at the foot, a bird drinking on the rim and another bathing.
static func _birdbath(root: Node3D, c: Vector3, col: Color, id: String) -> void:
	var tone := col.lerp(BATH_STONE, 0.55)   # (warm stone: a blue-grey bowl reads as more water)
	var stone := ModelKit.surface(tone, "stone", 0.3)
	var smooth := ModelKit.paint(tone.lightened(0.04))
	ModelKit.box(root, c + Vector3(-0.15, 0, -0.15), c + Vector3(0.15, 0.04, 0.15), stone)
	ModelKit.box(root, c + Vector3(-0.115, 0.04, -0.115), c + Vector3(0.115, 0.075, 0.115), stone)
	lathe(root, c, [Vector2(0.0, 0.075), Vector2(0.09, 0.075), Vector2(0.095, 0.095), Vector2(0.06, 0.12),
		Vector2(0.048, 0.16), Vector2(0.074, 0.215), Vector2(0.066, 0.26), Vector2(0.044, 0.3), Vector2(0.07, 0.325),
		Vector2(0.07, 0.345), Vector2(0.05, 0.36), Vector2(0.14, 0.385), Vector2(0.225, 0.43), Vector2(0.245, 0.452),
		Vector2(0.24, 0.47), Vector2(0.21, 0.47), Vector2(0.196, 0.44), Vector2(0.0, 0.425)], BATH_SIDES, smooth)
	for y: float in [0.1, 0.33]:   # the baluster's collars, a shade darker
		ModelKit.cylinder(root, c + Vector3(0, y, 0), 0.078, 0.014, ModelKit.paint(tone.darkened(0.1)), -1.0, 14)
	ModelKit.cylinder(root, c + Vector3(0, 0.432, 0), 0.2, 0.014 + WATER_LIFT, ModelKit.water(), -1.0, BATH_SIDES)
	var rng := _rng(id)
	for k in 7:   # moss creeping over the plinth
		var ang := rng.randf() * TAU
		ModelKit.ball(root, c + Vector3(cos(ang) * 0.14, 0.035, sin(ang) * 0.14), rng.randf_range(0.022, 0.04),
			ModelKit.paint(Color("#5f8a3a").darkened(rng.randf() * 0.2)), Vector3(1.4, 0.6, 1.0))
	for k in 4:   # pebbles round the foot
		var ang := rng.randf() * TAU
		ModelKit.ball(root, c + Vector3(cos(ang) * 0.21, 0.012, sin(ang) * 0.21), rng.randf_range(0.015, 0.026),
			ModelKit.paint(STONE.darkened(rng.randf() * 0.25)), Vector3(1.2, 0.6, 1.0))
	ModelKit.ball(root, c + Vector3(-0.07, 0.447 + WATER_LIFT, 0.06), 0.03, ModelKit.paint(Color("#4f9a3c")),
		Vector3(1.0, 0.12, 1.0))   # a leaf afloat
	var drinker := songbird(Color("#7a5a3a"), Color("#e9d9bd"))
	drinker.position = c + Vector3(0.2, 0.47, 0.06)
	drinker.rotation.y = 1.9
	drinker.rotation.x = 0.35   # (head down, drinking)
	root.add_child(drinker)
	var bather := songbird(Color("#3f7fc4"), Color("#f2ead8"))
	bather.position = c + Vector3(-0.02, 0.447, -0.07)
	bather.rotation.y = -0.6
	root.add_child(bather)


## A small bird at rest, facing -z, its feet at the origin: a round body with a pale belly, a head with a beak
## and eyes, folded wings a shade darker and a tail cocked up.
static func songbird(col: Color, belly: Color) -> Node3D:
	var b := Node3D.new()
	var paint := ModelKit.paint(col)
	var wing := ModelKit.paint(col.darkened(0.22))
	ModelKit.ball(b, Vector3(0, 0.04, 0), 0.036, paint, Vector3(0.85, 0.9, 1.25), true)
	ModelKit.ball(b, Vector3(0, 0.03, -0.012), 0.03, ModelKit.paint(belly), Vector3(0.8, 0.8, 1.0), true)
	ModelKit.ball(b, Vector3(0, 0.074, -0.03), 0.025, paint, Vector3.ONE, true)
	ModelKit.cylinder(b, Vector3(0, 0.068, -0.062), 0.009, 0.026, ModelKit.paint(Color("#e8a23a")), 0.0, 6) \
		.rotation.x = -PI / 2.0
	for side: float in [-1.0, 1.0]:
		ModelKit.ball(b, Vector3(side * 0.027, 0.045, 0.008), 0.026, wing, Vector3(0.35, 0.7, 1.3), true)
		ModelKit.ball(b, Vector3(side * 0.018, 0.08, -0.044), 0.0045, ModelKit.paint(Color("#16130f")))
		ModelKit.box(b, Vector3(side * 0.012 - 0.003, 0, -0.003), Vector3(side * 0.012 + 0.003, 0.014, 0.003),
			ModelKit.paint(Color("#c98a3a")))
	var tail := ModelKit.box(b, Vector3(-0.014, 0.036, 0.03), Vector3(0.014, 0.046, 0.085), wing)
	tail.rotation.x = 0.45
	return b


## A flat round piece standing on edge, facing +x (a door hole, a ring, a dowel when `depth` is long).
static func _disc(root: Node3D, at: Vector3, r: float, depth: float, mat: Material) -> MeshInstance3D:
	var mi := ModelKit.cylinder(root, at, r, depth, mat, -1.0, 12)
	mi.position = at
	mi.rotation.z = -PI / 2.0
	return mi


## A shape turned on a lathe round the upright axis through `c`: `profile` is its outline from the axis at
## the bottom, out and up, and back to the axis at the top, as (radius, height) points. A stretch that turns
## back toward the axis and down is a hollow (a basin's inside). Lit flat along the outline, smooth round it.
static func lathe(root: Node3D, c: Vector3, profile: Array, sides: int, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := ModelKit.scaled(sides, 8)
	for k in profile.size() - 1:
		var a: Vector2 = profile[k]
		var b: Vector2 = profile[k + 1]
		var out := Vector2(b.y - a.y, a.x - b.x).normalized()   # the outline's outward side, as (radial, up)
		for i in n:
			var corners: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for pair: Array in [[a, i], [b, i], [b, i + 1], [a, i + 1]]:
				var ang := TAU * float(pair[1]) / n
				var point: Vector2 = pair[0]
				corners.append(c + Vector3(cos(ang) * point.x, point.y, sin(ang) * point.x))
				normals.append(Vector3(cos(ang) * out.x, out.y, sin(ang) * out.x))
			var facing := (normals[0] + normals[2]).normalized()
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				var order: Array = tri
				var across := (corners[tri[1]] - corners[tri[0]]).cross(corners[tri[2]] - corners[tri[0]])
				if across.length_squared() < 1e-12:
					continue   # (at the axis a quad is a triangle: its empty half is left out)
				if across.dot(facing) > 0.0:   # (front faces run clockwise seen from outside: ModelKit.faces)
					order = [tri[0], tri[2], tri[1]]
				for v: int in order:
					st.set_normal(normals[v])
					st.add_vertex(corners[v])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	root.add_child(mi)
	return mi


static func _rng(id: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	return rng




static func _glow(col: Color) -> StandardMaterial3D:
	# Shared per colour, so the bake merges every glowing part of that colour into one draw.
	var key := col.to_html()
	if not _glows.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 2.0
		_glows[key] = m
	return _glows[key]




## Path tiles: packed dirt, laid bricks, or flagstones, flush with the grass.
## A plank footbridge: separate planks with gaps, beams underneath, posts with caps and two rails.
static func _bridge(root: Node3D, c: Vector3, col: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 17
	ModelKit.box(root, c + Vector3(-0.3, 0, -0.32), c + Vector3(0.3, 0.012, 0.32), ModelKit.water(), false)
	var boards := ModelKit.surface(col, "boards", 0.0)
	var dark := ModelKit.paint(col.darkened(0.25))
	for x: float in [-0.3, 0.3]:  # the beams the planks rest on
		ModelKit.box(root, c + Vector3(x - 0.03, 0.08, -0.34), c + Vector3(x + 0.03, 0.13, 0.34), dark)
	var planks := 9
	for k in planks:
		var z := -0.3 + 0.6 * (k + 0.5) / planks
		var lift := rng.randf_range(-0.004, 0.006)
		ModelKit.box(root, c + Vector3(-0.42 + rng.randf_range(0, 0.02), 0.13 + lift, z - 0.026),
			c + Vector3(0.42 - rng.randf_range(0, 0.02), 0.16 + lift, z + 0.026), boards)
	for side: float in [-1.0, 1.0]:
		var x := 0.4 * side
		for z: float in [-0.3, 0.0, 0.3]:
			ModelKit.box(root, c + Vector3(x - 0.02, 0.1, z - 0.02), c + Vector3(x + 0.02, 0.4, z + 0.02), dark)
			ModelKit.cylinder(root, c + Vector3(x, 0.4, z), 0.032, 0.03, dark, 0.014, 4)
		for y: float in [0.22, 0.34]:
			ModelKit.box(root, c + Vector3(x - 0.012, y, -0.31), c + Vector3(x + 0.012, y + 0.028, 0.31), ModelKit.paint(col))


static func _pond(root: Node3D, fp: Vector2i, fountain: bool, col: Color) -> void:
	var c := Vector3(fp.x / 2.0, 0, fp.y / 2.0)
	var r := minf(fp.x, fp.y) * 0.42
	if fountain:
		ModelKit.cylinder(root, c, r, 0.18, ModelKit.surface(col, "stone", 0.2), -1.0, 24)
		ModelKit.cylinder(root, c + Vector3(0, 0.17, 0), r * 0.9, WATER_LIFT + 0.01, ModelKit.water(), -1.0, 24)
		ModelKit.cylinder(root, c, 0.08, 0.6, ModelKit.paint(col), 0.06, 10)
		ModelKit.cylinder(root, c + Vector3(0, 0.6, 0), 0.3, 0.06, ModelKit.paint(col), 0.25, 16)
		ModelKit.cylinder(root, c + Vector3(0, 0.65, 0), 0.26, WATER_LIFT + 0.01, ModelKit.water(), -1.0, 16)
		# The spout, its jet falling back into the upper bowl, and the bowl spilling over into the basin.
		ModelKit.cylinder(root, c + Vector3(0, 0.64, 0), 0.025, 0.07, ModelKit.paint(col), 0.018, 8)
		DecorMotion.spray(root, c + Vector3(0, 0.71, 0), DecorMotion.JET)
		var cascade: Dictionary = DecorMotion.CASCADE.duplicate()
		cascade["start_radius"] = 0.31  # just outside the upper bowl (0.3 at its widest), not inside its stone
		DecorMotion.spray(root, c + Vector3(0, 0.66, 0), cascade)
		_pond_bank(root, c, r + 0.12, r + 0.12, 3)
	else:
		PondModel.build(root, c, r, r * 0.85, 5, 3)
		_ducks(root, c + Vector3(0, PondModel.WATER_LEVEL + 0.01, 0), r * 0.55)


## What grows and lies at a water's edge: a ring of stones (with a gap or two), and reeds in clumps, so the
## water sits in the ground. `rx` and `rz` are the bank's half sizes; `seed_value` makes each water its own.
static func _pond_bank(root: Node3D, c: Vector3, rx: float, rz: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 131
	var stones := 16
	for i in stones:
		if i % 7 == 3:
			continue  # a gap in the stones: a place to drink
		var a := TAU * i / stones + rng.randf_range(-0.1, 0.1)
		var size := rng.randf_range(0.04, 0.085)
		var stone := ModelKit.facet_ball(root, c + Vector3(cos(a) * rx, 0.015, sin(a) * rz), size,
			ModelKit.paint(Color("#9a9588").darkened(rng.randf() * 0.25)), Vector3(1.2, 0.7, 1.0))
		stone.rotation.y = rng.randf() * TAU
	for k in 3:
		var a := rng.randf() * TAU
		var at := c + Vector3(cos(a) * (rx + 0.05), 0.0, sin(a) * (rz + 0.05))
		for j in 4:
			var reed_h := rng.randf_range(0.14, 0.26)
			var reed := ModelKit.cylinder(root,
				at + Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.04, 0.04)),
				0.006, reed_h, ModelKit.paint(Color("#6f9a3c")), 0.002, 4)
			reed.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))
			ModelKit.cylinder(root, at + Vector3(0.0, reed_h * 0.85, 0.0), 0.012, 0.04,
				ModelKit.paint(Color("#7a5a30")), 0.01, 5)


## Two ducks paddling round a pond, apart from each other.
static func _ducks(root: Node3D, centre: Vector3, reach: float) -> void:
	for k in 2:
		var paddle: Dictionary = DecorMotion.PADDLING.duplicate()
		paddle["radius"] = reach * (1.0 - 0.3 * k)
		paddle["phase"] = PI * k * 3.1
		DecorMotion.orbit(root, centre, DecorMotion.duck(Color("#f2efe6") if k == 0 else Color("#8a6a45")), paddle)


## Loose straw round a thing's foot: `n` short strands lying on the ground in a ring between `inner` and `outer`
## from its centre.
static func _straw(root: Node3D, c: Vector3, inner: float, outer: float, n: int, id: String) -> void:
	var rng := _rng(id + ":straw")
	for k in n:
		var ang := rng.randf() * TAU
		var d := rng.randf_range(inner, outer)
		var strand := ModelKit.box(root, Vector3(-0.04, 0, -0.003), Vector3(0.04, 0.004, 0.003),
			ModelKit.paint(HAY.darkened(rng.randf_range(0.0, 0.25))), false)
		strand.position = c + Vector3(cos(ang) * d, 0.002, sin(ang) * d)
		strand.rotation.y = rng.randf() * TAU


static func _small_sign(root: Node3D, id: String, c: Vector3, col: Color, o: Dictionary) -> void:
	match id:
		"mailbox":
			_mailbox(root, c, col, id)
		"farm_stand":
			_farm_stand(root, c, col, id)
		"mastery_sign", "perfect_bunch":
			# The mastered item's colour (a crop, tree or animal), or a bunch's flower's.
			var shown := Game.mastery.colour_of(str(o.get("crop", o.get("flower", ""))))
			var accent := Color.html(shown) if shown != "" else col
			if id == "perfect_bunch":
				_bunch(root, c, accent, id)
			else:
				_mastery_sign(root, c, accent)


## A mystery young on the farm: a seedling in a mound of soil (taller and leafier with each can), or a
## covered wicker basket (a baby, stirring under its blanket) with a tag showing how far it has grown.
static func build_young(it: Dictionary, o: Dictionary, growth: float) -> Node3D:
	var root := Node3D.new()
	var c := Vector3(0.5, 0, 0.5)
	if str(it.get("grows", "")) == "tree":
		ModelKit.ball(root, c, 0.2, ModelKit.paint(Color("#6b4a2b")), Vector3(1, 0.35, 1))
		var h := lerpf(0.12, 0.42, growth)
		ModelKit.cylinder(root, c + Vector3(0, 0.05, 0), 0.012, h, ModelKit.paint(Color("#5d7a2c")), 0.008, 6)
		var leaf := ModelKit.paint(Color.html(str(it.get("color", "#6aa84f"))))
		for k in 2 + int(growth * 4.0):
			var a := TAU * k / 5.0 + 0.4
			var y := 0.06 + h * (0.45 + 0.5 * float(k) / 6.0)
			ModelKit.ball(root, c + Vector3(cos(a) * 0.05, y, sin(a) * 0.05), 0.045, leaf, Vector3(1.4, 0.35, 0.8))
		ModelKit.ball(root, c + Vector3(0, 0.06 + h, 0), 0.04, leaf, Vector3(1, 1.2, 1))
	else:
		var wicker := ModelKit.surface(Color("#b8894f"), "boards", 0.2)
		ModelKit.tub(root, c + Vector3(-0.2, 0, -0.14), c + Vector3(0.2, 0.16, 0.14), 0.025, wicker)
		ModelKit.ball(root, c + Vector3(0, 0.15, 0), 1.0, ModelKit.paint(Color("#9fc5e8")), Vector3(0.18, 0.06, 0.12))
		ModelKit.box(root, c + Vector3(-0.01, 0.16, -0.16), c + Vector3(0.01, 0.3, -0.14), ModelKit.paint(WOOD))
		# A tag on a stick: a bar filling with the feed given.
		ModelKit.box(root, c + Vector3(-0.07, 0.26, -0.155), c + Vector3(0.07, 0.31, -0.145), ModelKit.paint(WHITE))
		ModelKit.box(root, c + Vector3(-0.065, 0.27, -0.16), c + Vector3(-0.065 + 0.13 * maxf(growth, 0.04), 0.3, -0.158),
			ModelKit.paint(Color("#e2a43a")))
	return ModelKit.bake(root)
