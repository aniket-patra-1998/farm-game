class_name PrestigeModel
extends RefCounted
## The prestige decorations (owner, 27 Nov: big showpieces to save coins for; no power, only pride): a hot-air
## balloon, a clock tower and a stone castle, each built in code from ModelKit pieces like the other decorations
## (DecorModel hands them here by id). Sizes are their footprints in tiles; `c` is the middle.
##
## They are the dearest things in the Market, so they are built past a building's finish (owner, 27 Nov: "not up
## to the mark"): stonework in fine courses (a building's stones on a wall this big made a toy of it), real
## openings (a gate with its doors, lit windows, arrow slits), trim where one stone meets another, and one thing
## each that lives: the castle's banner streams, the clock's hands tell the farm's hour, the balloon rides the air.

const IDS := ["hot_air_balloon", "clock_tower", "stone_castle"]   # not-ui (catalog ids)
const STONE := Color("#cfc7b6")
const STONE_DARK := Color("#9a9283")
const TRIM := Color("#e6dfd0")
const GOLD := Color("#d6a531")
const WOOD := Color("#8a5a32")
const DOOR := Color("#5c3a1e")
const IRON := Color("#3b3a3f")
const HOLLOW := Color("#2a2420")      # the dark of a gateway or an arrow slit
const ROOF_RED := Color("#b4452f")
const SLATE := Color("#4f7186")
const FLAG := Color("#c9443a")
const BRONZE := Color("#b98a3a")
const WICKER := Color("#b78a4c")
const ROPE := Color("#6b5a3e")
const FINE := 0.5            # the stonework's pattern size (ModelKit.surface): half a building's
const BRICK := 0.4           # and the clock tower's bricks
const WEAVE := 0.45          # and the basket's wicker
const GORES := 16            # the balloon's panels round
const GORE_ROWS := 14
const BAND := Vector2(0.44, 0.56)   # where, crown to mouth, the balloon's panels swap colours: a belt round it
# The balloon's outline, crown to mouth: [how far down (0..1), radius (of its widest)].
const ENVELOPE := [[0.0, 0.0], [0.05, 0.42], [0.12, 0.7], [0.22, 0.9], [0.34, 1.0], [0.48, 0.96], [0.62, 0.8],
	[0.76, 0.56], [0.9, 0.3], [1.0, 0.19]]
const HOUR_MARKS := 12
const NAVY := Color("#27405c")       # the clock's panel, marks and hands
# The dial as a lamp's glass: cream by day (a lamp is dim unlit), alight at night.
const DIAL_LIT := Color(1.7, 1.65, 1.52)
const CASTLE_RISE := 1.24     # how much taller the castle stands than it is built
const ISLAND := 1.86         # the castle's island, out from its middle; the moat runs from here
const MOAT := 2.4            # to here, and a stone kerb to the edge of its land
const GATE_FACE := 1.58      # how far out the gatehouse's face stands: where the drawbridge is hinged
const TOWER_SCALE := 1.3     # how much bigger the clock tower stands than it is built
const BALLOON_SCALE := 1.2   # and the balloon and its basket
const SANDBAG := Color("#b3966a")
const PLASTER := Color("#ece5d6")


static func build(id: String, root: Node3D, c: Vector3, col: Color, accent: Color) -> void:
	match id:
		"hot_air_balloon":
			_balloon(root, c, col, accent)
		"clock_tower":
			var tower := Node3D.new()   # (built to a 2x2 foot, then grown to stand on its square)
			tower.scale = Vector3.ONE * TOWER_SCALE
			tower.position = c * (1.0 - TOWER_SCALE)
			root.add_child(tower)
			_clock_tower(tower, c, col)
			_square(root, c)
		"stone_castle":
			var body := Node3D.new()   # (built low and wide, then drawn up: a castle should tower)
			body.scale = Vector3(1.0, CASTLE_RISE, 1.0)
			root.add_child(body)
			_castle(body, c)
			_moat(root, c)


## A box on one of a square's four sides: `x0`..`x1` along the side, `z0`..`z1` out from the middle `c`, the
## whole turned a quarter turn `side` times (0 faces +z).
static func _side_box(root: Node3D, c: Vector3, side: int, x: Vector2, z: Vector2, y: Vector2,
		mat: Material) -> MeshInstance3D:
	var turn := Basis(Vector3.UP, PI / 2.0 * side)
	var a := turn * Vector3(x.x, 0, z.x)
	var b := turn * Vector3(x.y, 0, z.y)
	return ModelKit.box(root, c + Vector3(minf(a.x, b.x), y.x, minf(a.z, b.z)),
		c + Vector3(maxf(a.x, b.x), y.y, maxf(a.z, b.z)), mat)


## A disc standing on one of the four sides, facing out: its middle `at` (x along the side, y up, z out).
static func _side_disc(root: Node3D, c: Vector3, side: int, at: Vector3, r: float, deep: float, mat: Material,
		sides := 20) -> MeshInstance3D:
	var turn := Basis(Vector3.UP, PI / 2.0 * side)
	var disc := ModelKit.cylinder(root, Vector3.ZERO, r, deep, mat, -1.0, sides)
	disc.position = c + turn * Vector3(at.x, 0, at.z) + Vector3(0, at.y, 0)
	disc.basis = turn * Basis(Vector3.RIGHT, PI / 2.0)
	return disc


## An arched opening on a side: a surround of `frame`, its filling of `fill` (a door, the dark of a gateway,
## glass), `half` wide each way, from `y0` up to where the arch springs at `y1`, on the wall face at `z`.
static func _arch(root: Node3D, c: Vector3, side: int, x: float, half: float, y: Vector2, z: float, frame: Material,
		fill: Material) -> void:
	var edge := half * 0.28
	_side_box(root, c, side, Vector2(x - half - edge, x + half + edge), Vector2(z, z + 0.02), Vector2(y.x, y.y), frame)
	_side_disc(root, c, side, Vector3(x, y.y, z + 0.01), half + edge, 0.02, frame, 16)
	_side_box(root, c, side, Vector2(x - half, x + half), Vector2(z + 0.02, z + 0.032), Vector2(y.x, y.y), fill)
	_side_disc(root, c, side, Vector3(x, y.y, z + 0.026), half, 0.012, fill, 16)


## Merlons along the top of a square's four sides (`half` out from `c`, at height `y`), `n` to a side.
static func _battlements(root: Node3D, c: Vector3, half: float, y: float, n: int, mat: Material) -> void:
	var step := 2.0 * half / n
	for side in 4:
		for k in n:
			var x := -half + (k + 0.5) * step
			_side_box(root, c, side, Vector2(x - step * 0.3, x + step * 0.3), Vector2(half - 0.09, half + 0.025),
				Vector2(y, y + 0.13), mat)


## Blocks standing in a ring of radius `r` round `c` at height `y`: a round tower's merlons.
static func _ring(root: Node3D, c: Vector3, y: float, r: float, n: int, size: Vector3, mat: Material) -> void:
	for k in n:
		var a := TAU * k / n
		var block := ModelKit.box(root, -size / 2.0, size / 2.0, mat)
		block.position = c + Vector3(cos(a) * r, y + size.y / 2.0, sin(a) * r)
		block.rotation.y = PI / 2.0 - a


## A pole with a pennant at its top; `streams` lets the pennant move in the wind (one draw more).
static func _flag(root: Node3D, foot: Vector3, tall: float, size: Vector2, streams := false) -> void:
	ModelKit.cylinder(root, foot, 0.012, tall, ModelKit.paint(WOOD), -1.0, 5)
	ModelKit.ball(root, foot + Vector3(0, tall, 0), 0.025, ModelKit.paint(GOLD, 0.6))
	var top := foot + Vector3(0, tall - size.y - 0.02, 0)
	if not streams:
		ModelKit.box(root, top + Vector3(0.012, 0, -0.004), top + Vector3(size.x, size.y, 0.004), ModelKit.paint(FLAG))
		return
	var cloth := Node3D.new()
	ModelKit.box(cloth, Vector3(-0.004, 0, 0.0), Vector3(0.004, size.y, -size.x), ModelKit.paint(FLAG))
	ModelKit.box(cloth, Vector3(-0.005, size.y * 0.4, -size.x * 0.15), Vector3(0.005, size.y * 0.6, -size.x * 0.85),
		ModelKit.paint(GOLD))
	DecorMotion.orbit(root, top, cloth, DecorMotion.FLUTTER)


## A stone castle round a courtyard: a curtain wall with a wall-walk and merlons, four round corner towers under
## red cones, a gatehouse with its doors, iron bands and a ramp, banners on the walls, and a tall keep at the back
## with lit windows and a turret flying the castle's banner.
static func _castle(root: Node3D, c: Vector3) -> void:
	var stone := ModelKit.surface(STONE, "stone", 0.35, FINE)
	var dark := ModelKit.surface(STONE_DARK, "stone", 0.35, FINE)
	var trim := ModelKit.paint(TRIM)
	var roof := ModelKit.surface(ROOF_RED, "shingles", 0.1)
	var hollow := ModelKit.paint(HOLLOW)
	var wall := 1.38
	ModelKit.box(root, c + Vector3(-1.86, 0, -1.86), c + Vector3(1.86, 0.1, 1.86), dark)
	ModelKit.box(root, c + Vector3(-wall, 0.1, -wall), c + Vector3(wall, 0.14, wall), dark)   # the courtyard
	for side in 4:
		_side_box(root, c, side, Vector2(-wall, wall), Vector2(wall - 0.26, wall), Vector2(0.1, 1.0), stone)
		_side_box(root, c, side, Vector2(-wall, wall), Vector2(wall - 0.02, wall + 0.03), Vector2(0.1, 0.2), dark)
		_side_box(root, c, side, Vector2(-wall, wall), Vector2(wall - 0.29, wall + 0.03), Vector2(1.0, 1.05), trim)
		for x: float in [-0.85, 0.85]:   # a banner each side of the middle, and a slit beside it
			_side_box(root, c, side, Vector2(x - 0.11, x + 0.11), Vector2(wall, wall + 0.012), Vector2(0.42, 0.92),
				ModelKit.paint(FLAG))
			_side_box(root, c, side, Vector2(x - 0.11, x + 0.11), Vector2(wall, wall + 0.014), Vector2(0.42, 0.5),
				ModelKit.paint(GOLD))
			_side_box(root, c, side, Vector2(x * 0.45 - 0.02, x * 0.45 + 0.02), Vector2(wall, wall + 0.01),
				Vector2(0.5, 0.82), hollow)
	_battlements(root, c, wall, 1.05, 9, stone)
	for k in 4:
		var at := c + Vector3(wall if k % 2 == 0 else -wall, 0, wall if k < 2 else -wall)
		ModelKit.cylinder(root, at + Vector3(0, 0.1, 0), 0.44, 0.22, dark, 0.38, 16)
		ModelKit.cylinder(root, at + Vector3(0, 0.32, 0), 0.38, 1.2, stone, -1.0, 16)
		ModelKit.cylinder(root, at + Vector3(0, 1.52, 0), 0.38, 0.1, dark, 0.46, 16)
		ModelKit.cylinder(root, at + Vector3(0, 1.62, 0), 0.46, 0.1, stone, -1.0, 16)
		_ring(root, at, 1.72, 0.42, 8, Vector3(0.17, 0.12, 0.09), stone)
		ModelKit.cylinder(root, at + Vector3(0, 1.66, 0), 0.36, 0.78, roof, 0.0, 16)
		_flag(root, at + Vector3(0, 2.4, 0), 0.34, Vector2(0.2, 0.11))
		for out: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]:
			var slit := ModelKit.box(root, Vector3(-0.022, 0, -0.01), Vector3(0.022, 0.3, 0.01), hollow)
			slit.position = at + out * 0.375 + Vector3(0, 1.0, 0)
			slit.rotation.y = 0.0 if absf(out.z) > 0.5 else PI / 2.0
	_gatehouse(root, c, wall, stone, dark)
	_keep(root, c + Vector3(-0.42, 0, -0.42), stone, dark)


## The castle's gate, on its +z side: a tower over an open arched gateway, its portcullis drawn up, a crest over
## the arch and a torch each side (its light on the ground at night). The drawbridge is the moat's (`_moat`).
static func _gatehouse(root: Node3D, c: Vector3, wall: float, stone: Material, dark: Material) -> void:
	var trim := ModelKit.paint(TRIM)
	var iron := ModelKit.paint(IRON)
	_side_box(root, c, 0, Vector2(-0.46, 0.46), Vector2(wall - 0.34, GATE_FACE), Vector2(0.1, 1.42), stone)
	_side_box(root, c, 0, Vector2(-0.5, 0.5), Vector2(wall - 0.38, GATE_FACE + 0.04), Vector2(1.42, 1.48), trim)
	var top := c + Vector3(0, 0, wall - 0.07)
	_battlements(root, top, 0.46, 1.48, 3, stone)
	var face := GATE_FACE
	_arch(root, c, 0, 0.0, 0.24, Vector2(0.1, 0.66), face, dark, ModelKit.paint(HOLLOW))
	_side_box(root, c, 0, Vector2(-0.24, 0.24), Vector2(face + 0.03, face + 0.045), Vector2(0.6, 0.66), iron)
	for k in 6:   # the portcullis, drawn up: its teeth show under the arch
		var x := -0.2 + 0.08 * k
		_side_box(root, c, 0, Vector2(x - 0.012, x + 0.012), Vector2(face + 0.03, face + 0.045), Vector2(0.5, 0.74), iron)
	_side_disc(root, c, 0, Vector3(0, 1.16, face + 0.012), 0.12, 0.024, ModelKit.paint(GOLD, 0.6), 6)
	_side_disc(root, c, 0, Vector3(0, 1.16, face + 0.02), 0.075, 0.024, ModelKit.paint(FLAG), 6)
	var pools := []
	for x: float in [-0.36, 0.36]:
		var foot := c + Vector3(x, 0.62, face + 0.03)
		DecorModel.rod(root, foot, foot + Vector3(0, 0.16, 0.05), 0.014, iron, 0.022, 5)
		DecorMotion.flame(root, foot + Vector3(0, 0.16, 0.05), 0.03, 0.12, Color("#ff8a2a"), Color("#ffe08a"))
		pools.append([c + Vector3(x, 0, face + 0.45), Vector2(1.3, 1.3)])
	ModelKit.glow_pools(root, pools)


## The water round the castle's island, a stone kerb outside it, the drawbridge let down across it from the gate
## on its chains, and a duck paddling in it.
static func _moat(root: Node3D, c: Vector3) -> void:
	var dark := ModelKit.surface(STONE_DARK, "stone", 0.35, FINE)
	var iron := ModelKit.paint(IRON)
	for side in 4:
		var along := MOAT if side % 2 == 0 else ISLAND   # (two sides run the whole way, two fit between them)
		_side_box(root, c, side, Vector2(-along, along), Vector2(ISLAND, MOAT), Vector2(0.0, 0.04), ModelKit.water()) \
			.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_side_box(root, c, side, Vector2(-MOAT - 0.09, MOAT + 0.09), Vector2(MOAT, MOAT + 0.09), Vector2(0.0, 0.08), dark)
	var deck := 0.1 * CASTLE_RISE
	ModelKit.box(root, c + Vector3(-0.3, deck, GATE_FACE), c + Vector3(0.3, deck + 0.04, MOAT + 0.09),
		ModelKit.surface(WOOD, "planks", 0.2))
	for x: float in [-0.3, 0.3]:
		ModelKit.box(root, c + Vector3(x - 0.025, deck, GATE_FACE), c + Vector3(x + 0.025, deck + 0.075, MOAT + 0.09),
			ModelKit.paint(DOOR))
		DecorModel.rod(root, c + Vector3(x * 0.9, 1.3, GATE_FACE + 0.02), c + Vector3(x, deck + 0.07, MOAT - 0.05), 0.008,
			iron, -1.0, 4)
	DecorMotion.orbit(root, c + Vector3(-(ISLAND + MOAT) / 2.0, 0.045, 0.7), DecorMotion.duck(Color("#f4f1ea")),
		DecorMotion.PADDLING)


## The paved square the clock tower stands on: flagstones, a step up to the door, and a stone post with a gold
## ball at each corner.
static func _square(root: Node3D, c: Vector3) -> void:
	var half := 1.36
	ModelKit.box(root, c + Vector3(-half, 0, -half), c + Vector3(half, 0.05, half),
		ModelKit.surface(PLASTER, "stone", 0.2, FINE))
	for k in 4:
		var in_ := half - 0.12
		var at := c + Vector3(in_ if k % 2 == 0 else -in_, 0.05, in_ if k < 2 else -in_)
		ModelKit.cylinder(root, at, 0.07, 0.3, ModelKit.surface(STONE, "stone", 0.35, FINE), 0.055, 8)
		ModelKit.ball(root, at + Vector3(0, 0.34, 0), 0.055, ModelKit.paint(GOLD, 0.6))


## The castle's keep, its middle at `c`: a tall square tower with a string course, lit windows on every side, its
## own merlons, and a round turret under a slate cone that flies the banner.
static func _keep(root: Node3D, c: Vector3, stone: Material, dark: Material) -> void:
	var trim := ModelKit.paint(TRIM)
	var half := 0.64
	ModelKit.box(root, c + Vector3(-half - 0.05, 0.1, -half - 0.05), c + Vector3(half + 0.05, 0.3, half + 0.05), dark)
	ModelKit.box(root, c + Vector3(-half, 0.3, -half), c + Vector3(half, 2.0, half), stone)
	ModelKit.box(root, c + Vector3(-half - 0.03, 1.22, -half - 0.03), c + Vector3(half + 0.03, 1.28, half + 0.03), trim)
	ModelKit.box(root, c + Vector3(-half - 0.04, 2.0, -half - 0.04), c + Vector3(half + 0.04, 2.06, half + 0.04), trim)
	_battlements(root, c, half + 0.02, 2.06, 5, stone)
	for side in 4:
		for x: float in [-0.3, 0.3]:
			_arch(root, c, side, x, 0.09, Vector2(1.45, 1.7), half, trim, ModelKit.glass())
		_side_box(root, c, side, Vector2(-0.02, 0.02), Vector2(half, half + 0.01), Vector2(0.62, 0.98),
			ModelKit.paint(HOLLOW))
	_arch(root, c, 0, 0.0, 0.14, Vector2(0.14, 0.5), half, dark, ModelKit.surface(DOOR, "planks", 0.2))
	ModelKit.cylinder(root, c + Vector3(0, 2.06, 0), 0.34, 0.56, stone, -1.0, 16)
	ModelKit.cylinder(root, c + Vector3(0, 2.62, 0), 0.34, 0.08, dark, 0.41, 16)
	_ring(root, c, 2.7, 0.37, 8, Vector3(0.15, 0.1, 0.08), stone)
	ModelKit.cylinder(root, c + Vector3(0, 2.66, 0), 0.32, 0.74, ModelKit.surface(SLATE, "shingles", 0.1), 0.0, 16)
	_flag(root, c + Vector3(0, 3.36, 0), 0.62, Vector2(0.42, 0.22), true)


## A brick clock tower on a stepped stone foot: stone corners and bands, an arched door and a lit window to each
## side, a stone stage with four faces whose hands tell the farm's hour, an open belfry with its bronze bell, and
## a slate spire with a gold vane.
static func _clock_tower(root: Node3D, c: Vector3, col: Color) -> void:
	var stone := ModelKit.surface(STONE, "stone", 0.35, FINE)
	var dark := ModelKit.surface(STONE_DARK, "stone", 0.35, FINE)
	var brick := ModelKit.surface(col, "stone", 0.25, BRICK)
	var trim := ModelKit.paint(TRIM)
	var slate := ModelKit.surface(SLATE, "shingles", 0.1)
	var half := 0.5
	ModelKit.box(root, c + Vector3(-0.8, 0, -0.8), c + Vector3(0.8, 0.1, 0.8), dark)
	ModelKit.box(root, c + Vector3(-0.66, 0.1, -0.66), c + Vector3(0.66, 0.2, 0.66), stone)
	ModelKit.box(root, c + Vector3(-half, 0.2, -half), c + Vector3(half, 1.75, half), brick)
	for k in 4:   # stone corners the height of the shaft
		var corner := Vector3((half - 0.06) if k % 2 == 0 else -(half - 0.06), 0, (half - 0.06) if k < 2 else -(half - 0.06))
		ModelKit.box(root, c + corner + Vector3(-0.075, 0.2, -0.075), c + corner + Vector3(0.075, 1.75, 0.075), stone)
	for y: float in [0.92, 1.75]:
		ModelKit.box(root, c + Vector3(-half - 0.03, y, -half - 0.03), c + Vector3(half + 0.03, y + 0.06, half + 0.03), trim)
	for side in 4:   # brackets under the stage, and a pinnacle on each of its corners
		for k in 5:
			var x := -0.4 + 0.2 * k
			_side_box(root, c, side, Vector2(x - 0.03, x + 0.03), Vector2(half, half + 0.07), Vector2(1.66, 1.75), trim)
	_arch(root, c, 0, 0.0, 0.15, Vector2(0.2, 0.62), half, trim, ModelKit.surface(DOOR, "planks", 0.2))
	_side_box(root, c, 0, Vector2(-0.24, 0.24), Vector2(0.66, 0.78), Vector2(0.0, 0.1), stone)   # the door's step
	for side in 4:
		if side != 0:
			_arch(root, c, side, 0.0, 0.085, Vector2(0.4, 0.66), half, trim, ModelKit.glass())
		_arch(root, c, side, 0.0, 0.085, Vector2(1.2, 1.46), half, trim, ModelKit.glass())
	var stage := 0.58
	ModelKit.box(root, c + Vector3(-stage, 1.81, -stage), c + Vector3(stage, 2.62, stage),
		ModelKit.surface(PLASTER, "plaster", 0.1))
	ModelKit.box(root, c + Vector3(-stage - 0.05, 2.62, -stage - 0.05), c + Vector3(stage + 0.05, 2.69, stage + 0.05),
		trim)
	for side in 4:
		_clock_face(root, c, side, Vector3(0, 2.215, stage), 0.35)
	for k in 4:
		var top := c + Vector3(0.56 if k % 2 == 0 else -0.56, 2.69, 0.56 if k < 2 else -0.56)
		ModelKit.box(root, top + Vector3(-0.06, 0, -0.06), top + Vector3(0.06, 0.12, 0.06), trim)
		ModelKit.cylinder(root, top + Vector3(0, 0.12, 0), 0.075, 0.26, slate, 0.0, 4).rotation.y = PI / 4.0
		ModelKit.ball(root, top + Vector3(0, 0.4, 0), 0.028, ModelKit.paint(GOLD, 0.7))
	for k in 4:   # the belfry: corner piers, open between, under a lintel
		var corner := Vector3(0.45 if k % 2 == 0 else -0.45, 0, 0.45 if k < 2 else -0.45)
		ModelKit.box(root, c + corner + Vector3(-0.08, 2.69, -0.08), c + corner + Vector3(0.08, 3.12, 0.08), brick)
	for side in 4:
		_side_box(root, c, side, Vector2(-0.53, 0.53), Vector2(0.4, 0.53), Vector2(3.04, 3.12), stone)
		_side_box(root, c, side, Vector2(-0.37, 0.37), Vector2(0.47, 0.5), Vector2(2.69, 2.8), trim)
	var bronze := ModelKit.paint(BRONZE, 0.7)
	DecorModel.lathe(root, c + Vector3(0, 2.76, 0), [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.17, 0.05),
		Vector2(0.11, 0.2), Vector2(0.07, 0.26), Vector2(0.0, 0.27)], 12, bronze)
	ModelKit.box(root, c + Vector3(-0.45, 3.02, -0.025), c + Vector3(0.45, 3.06, 0.025), ModelKit.paint(WOOD))
	ModelKit.box(root, c + Vector3(-0.6, 3.12, -0.6), c + Vector3(0.6, 3.18, 0.6), trim)
	ModelKit.cylinder(root, c + Vector3(0, 3.18, 0), 0.82, 0.2, slate, 0.5, 4).rotation.y = PI / 4.0
	ModelKit.cylinder(root, c + Vector3(0, 3.38, 0), 0.5, 1.02, slate, 0.0, 4).rotation.y = PI / 4.0
	var gold := ModelKit.paint(GOLD, 0.7)
	ModelKit.cylinder(root, c + Vector3(0, 4.36, 0), 0.014, 0.2, gold, -1.0, 6)
	ModelKit.ball(root, c + Vector3(0, 4.44, 0), 0.045, gold)
	ModelKit.box(root, c + Vector3(-0.13, 4.53, -0.006), c + Vector3(0.13, 4.555, 0.006), gold)
	ModelKit.box(root, c + Vector3(0.07, 4.51, -0.006), c + Vector3(0.13, 4.575, 0.006), gold)


## One clock face on a side, its middle `at` (x along, y up, z the wall's face): a deep blue panel framed and
## studded in gold, a gold bezel, a pale dial that glows after dark (a lamp's glass), a gold ring inside twelve
## marks, and two hands with diamond tips that the farm's hour turns (a `clock_*` part: ClockHands, the hour the
## sky and the HUD's clock go by).
static func _clock_face(root: Node3D, c: Vector3, side: int, at: Vector3, r: float) -> void:
	var ink := ModelKit.paint(NAVY)
	var gold := ModelKit.paint(GOLD, 0.7)
	var panel := r * 1.1
	_side_box(root, c, side, Vector2(at.x - panel, at.x + panel), Vector2(at.z, at.z + 0.012),
		Vector2(at.y - panel, at.y + panel), ink)
	for e: float in [-1.0, 1.0]:   # the panel's gold frame, and a stud in each corner
		_side_box(root, c, side, Vector2(at.x - panel, at.x + panel), Vector2(at.z, at.z + 0.018),
			Vector2(at.y + e * panel - 0.012, at.y + e * panel + 0.012), gold)
		_side_box(root, c, side, Vector2(at.x + e * panel - 0.012, at.x + e * panel + 0.012), Vector2(at.z, at.z + 0.018),
			Vector2(at.y - panel, at.y + panel), gold)
		for f: float in [-1.0, 1.0]:
			_side_disc(root, c, side, at + Vector3(e * panel * 0.86, f * panel * 0.86, 0.016), 0.024, 0.012, gold, 8)
	_side_disc(root, c, side, at + Vector3(0, 0, 0.02), r, 0.02, gold, 28)
	_side_disc(root, c, side, at + Vector3(0, 0, 0.024), r * 0.93, 0.02, ink, 28)
	_side_disc(root, c, side, at + Vector3(0, 0, 0.028), r * 0.89, 0.02, DecorModel.lamp_glass(DIAL_LIT), 28)
	_side_disc(root, c, side, at + Vector3(0, 0, 0.031), r * 0.56, 0.018, gold, 24)
	_side_disc(root, c, side, at + Vector3(0, 0, 0.034), r * 0.53, 0.018, DecorModel.lamp_glass(DIAL_LIT), 24)
	var turn := Basis(Vector3.UP, PI / 2.0 * side)
	var middle := c + turn * Vector3(at.x, 0, at.z + 0.044) + Vector3(0, at.y, 0)
	for k in HOUR_MARKS:
		var big := k % 3 == 0
		var size := Vector3(0.03 if big else 0.016, r * (0.2 if big else 0.13), 0.004)
		var mark := ModelKit.box(root, -size / 2.0, size / 2.0, ink, false)
		mark.basis = turn * Basis(Vector3.BACK, -TAU * k / HOUR_MARKS)
		mark.position = middle + mark.basis * Vector3(0, r * (0.73 if big else 0.76), 0)
	var hands := Node3D.new()
	hands.name = "%s_%d" % [DecorMotion.CLOCK, side]
	hands.position = middle + turn * Vector3(0, 0, 0.004)
	hands.basis = turn
	for h: Array in [[r * 0.46, 0.02, 0.0], [r * 0.74, 0.013, 0.006]]:   # the hour hand, then the minute hand over it
		var hand := Node3D.new()
		var z := float(h[2])
		ModelKit.box(hand, Vector3(-float(h[1]), -r * 0.14, z), Vector3(float(h[1]), float(h[0]), z + 0.006), ink, false)
		var tip := ModelKit.box(hand, Vector3(-0.026, -0.026, z), Vector3(0.026, 0.026, z + 0.006), ink, false)
		tip.position = Vector3(0, float(h[0]) * 0.8, z + 0.003)
		tip.rotation.z = PI / 4.0
		hands.add_child(hand)
	hands.set_meta(ModelKit.KEEP, true)
	root.add_child(hands)
	DecorMotion.start(hands)
	_side_disc(root, c, side, at + Vector3(0, 0, 0.062), 0.032, 0.014, gold, 10)


## A hot-air balloon riding at its moorings: a tall envelope of sixteen panels in two colours with a belt where
## they swap, a gold crown, a burner alight under its mouth, and a wicker basket hung from a load ring with
## sandbags on its rim. All of that floats (a `sway_*` part: Swayer); the pegs and mooring lines stay put.
static func _balloon(root: Node3D, c: Vector3, col: Color, accent: Color) -> void:
	var rope := ModelKit.paint(ROPE)
	var craft := Node3D.new()
	var top := Vector3(0, 4.05, 0)
	var drop := 2.5
	var wide := 1.18
	for part: Array in [[0, col], [1, accent]]:
		var panels := _gores(top, wide, drop, int(part[0]))
		panels.material_override = ModelKit.paint(part[1])
		craft.add_child(panels)
	ModelKit.cylinder(craft, top + Vector3(0, -0.03, 0), 0.2, 0.06, ModelKit.paint(GOLD, 0.6), 0.1, 12)
	var mouth := top.y - drop
	ModelKit.cylinder(craft, Vector3(0, mouth - 0.1, 0), 0.2, 0.12, ModelKit.paint(accent.darkened(0.3)), 0.225, GORES)
	ModelKit.cylinder(craft, Vector3(0, 1.06, 0), 0.07, 0.1, ModelKit.paint(IRON, 0.5), 0.05, 8)
	DecorMotion.flame(craft, Vector3(0, 1.16, 0), 0.05, 0.24, Color("#ff8a2a"), Color("#ffe08a"))
	var basket := 0.27
	ModelKit.box(craft, Vector3(-basket, 0.3, -basket), Vector3(basket, 0.66, basket),
		ModelKit.surface(WICKER, "logs", 0.3, WEAVE))
	ModelKit.box(craft, Vector3(-basket - 0.025, 0.66, -basket - 0.025), Vector3(basket + 0.025, 0.71, basket + 0.025),
		ModelKit.paint(WOOD))
	ModelKit.box(craft, Vector3(-basket - 0.01, 0.28, -basket - 0.01), Vector3(basket + 0.01, 0.32, basket + 0.01),
		ModelKit.paint(DOOR))
	for k in 4:
		var corner := Vector3(basket if k % 2 == 0 else -basket, 0, basket if k < 2 else -basket)
		DecorModel.rod(craft, corner + Vector3(0, 0.71, 0), corner * 0.4 + Vector3(0, 1.08, 0), 0.01, ModelKit.paint(WOOD),
			-1.0, 4)
		ModelKit.ball(craft, corner * 1.1 + Vector3(0, 0.52, 0), 0.05, ModelKit.paint(SANDBAG), Vector3(1, 1.4, 1))
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		DecorModel.rod(craft, Vector3(cos(a) * 0.1, 1.1, sin(a) * 0.1), Vector3(cos(a) * 0.2, mouth - 0.1, sin(a) * 0.2),
			0.005, rope, -1.0, 4)
	var pegs: Array[Vector3] = [Vector3(-1.3, 0, 1.0), Vector3(1.3, 0, 1.0), Vector3(0, 0, -1.4)]
	for p in pegs:
		ModelKit.cylinder(root, c + p, 0.035, 0.13, ModelKit.paint(WOOD), 0.02, 6)
		DecorModel.rod(root, c + p + Vector3(0, 0.1, 0), c + p * 0.24 + Vector3(0, 0.3 * BALLOON_SCALE, 0), 0.006, rope,
			-1.0, 4)
	var floating := ModelKit.bake(craft)
	floating.name = "%s_%d" % [DecorMotion.SWAY, root.get_child_count()]
	floating.position = c
	floating.scale = Vector3.ONE * BALLOON_SCALE
	floating.set_meta(ModelKit.KEEP, true)
	root.add_child(floating)
	DecorMotion.start(floating)


## The balloon's panels of one colour (`which` 0 or 1) as one mesh: the envelope hangs `drop` below `top`, `wide`
## at its widest (ENVELOPE), each panel bulging a little between its seams, and the two colours swapping in a
## belt round the middle (BAND).
static func _gores(top: Vector3, wide: float, drop: float, which: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in GORES:
		for half in 2:
			var a0 := TAU * (k + half * 0.5) / GORES
			var a1 := TAU * (k + (half + 1) * 0.5) / GORES
			var swell0 := 1.0 if half == 0 else 1.035
			var swell1 := 1.035 if half == 0 else 1.0
			for i in GORE_ROWS:
				var t0 := float(i) / GORE_ROWS
				var t1 := float(i + 1) / GORE_ROWS
				var belt := (t0 + t1) / 2.0 > BAND.x and (t0 + t1) / 2.0 < BAND.y
				if (k + (1 if belt else 0)) % 2 != which:
					continue
				var r0 := _envelope(t0) * wide
				var r1 := _envelope(t1) * wide
				var quad := [Vector3(cos(a0) * r0 * swell0, -drop * t0, sin(a0) * r0 * swell0),
					Vector3(cos(a1) * r0 * swell1, -drop * t0, sin(a1) * r0 * swell1),
					Vector3(cos(a1) * r1 * swell1, -drop * t1, sin(a1) * r1 * swell1),
					Vector3(cos(a0) * r1 * swell0, -drop * t1, sin(a0) * r1 * swell0)]
				var lean := (r0 - r1) / (drop * (t1 - t0))   # how the skin leans: out and up above the widest
				for tri: Array in [[0, 2, 1], [0, 3, 2]]:
					var across: Vector3 = (quad[tri[1]] - quad[tri[0]]).cross(quad[tri[2]] - quad[tri[0]])
					if across.length_squared() < 1e-12:
						continue
					for v: int in tri:
						var q: Vector3 = quad[v]
						st.set_normal(Vector3(q.x, 0, q.z).normalized() + Vector3(0, -lean, 0))
						st.add_vertex(top + q)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	return mi


## The balloon's radius (of its widest) `t` of the way from crown to mouth.
static func _envelope(t: float) -> float:
	for k in ENVELOPE.size() - 1:
		var a: Array = ENVELOPE[k]
		var b: Array = ENVELOPE[k + 1]
		if t <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), smoothstep(float(a[0]), float(b[0]), t))
	return float((ENVELOPE[-1] as Array)[1])
