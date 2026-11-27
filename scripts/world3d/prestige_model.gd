class_name PrestigeModel
extends RefCounted
## The prestige decorations (owner, 27 Nov: big showpieces to save coins for; no power, only pride): a hot-air
## balloon, a clock tower and a stone castle, each built in code from ModelKit pieces like
## the other decorations (DecorModel hands them here by id). Sizes are their footprints in tiles; `c` is the middle.

const IDS := ["hot_air_balloon", "clock_tower", "stone_castle"]   # not-ui (catalog ids)
const STONE := Color("#b9b2a4")
const STONE_DARK := Color("#8f887b")
const GOLD := Color("#c9962e")
const WOOD := Color("#8a5a32")
const ROOF_RED := Color("#a8432f")
const FLAG := Color("#c9443a")


static func build(id: String, root: Node3D, c: Vector3, col: Color, accent: Color) -> void:
	match id:
		"hot_air_balloon":
			_balloon(root, c, col, accent)
		"clock_tower":
			_clock_tower(root, c, col)
		"stone_castle":
			_castle(root, c)


## A striped balloon moored over a wicker basket by four ropes, a sandbag hanging from the basket's rim and two
## pegs holding it down.
static func _balloon(root: Node3D, c: Vector3, col: Color, accent: Color) -> void:
	var wicker := ModelKit.surface(Color("#b08850"), "planks", 0.3)
	ModelKit.box(root, c + Vector3(-0.32, 0, -0.32), c + Vector3(0.32, 0.42, 0.32), wicker)
	ModelKit.box(root, c + Vector3(-0.35, 0.4, -0.35), c + Vector3(0.35, 0.46, 0.35), ModelKit.paint(WOOD))
	var gores := 12
	var top := c + Vector3(0, 2.9, 0)
	for k in gores:
		var stripe := ModelKit.paint(col if k % 2 == 0 else accent)
		var a0 := TAU * k / gores
		var a1 := TAU * (k + 1) / gores
		var wedge := _gore(top, 1.2, 1.75, a0, a1)
		wedge.material_override = stripe
		root.add_child(wedge)
	ModelKit.cylinder(root, c + Vector3(0, 1.0, 0), 0.2, 0.18, ModelKit.paint(accent.darkened(0.25)), 0.3, 12)
	var rope := ModelKit.paint(Color("#6b5a3e"))
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		DecorModel.rod(root, c + Vector3(cos(a) * 0.32, 0.46, sin(a) * 0.32),
			c + Vector3(cos(a) * 0.24, 1.08, sin(a) * 0.24), 0.008, rope, -1.0, 4)
	ModelKit.ball(root, c + Vector3(0.36, 0.3, 0.0), 0.07, ModelKit.paint(Color("#c9b48a")), Vector3(1, 1.3, 1))
	for p: Vector3 in [Vector3(-0.9, 0, -0.9), Vector3(0.9, 0, 0.9)]:
		ModelKit.cylinder(root, c + p, 0.03, 0.12, ModelKit.paint(WOOD), 0.02, 6)
		DecorModel.rod(root, c + p + Vector3(0, 0.1, 0), c + p * 0.35 + Vector3(0, 0.44, 0), 0.006, rope, -1.0, 4)


## One gore of the balloon's envelope: a teardrop of radius `r` round `top` going down by `drop`, between two
## angles (a lathe slice, so the stripes are real panels).
static func _gore(top: Vector3, r: float, drop: float, a0: float, a1: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 10
	var profile: Array[Vector2] = []
	for i in rows + 1:
		var t := float(i) / rows   # 0 at the crown, 1 at the mouth
		var rad := r * sin(PI * minf(t * 1.15, 1.0)) * (1.0 - 0.55 * t * t) + 0.0001
		profile.append(Vector2(rad, -drop * t))
	for i in rows:
		var p0 := profile[i]
		var p1 := profile[i + 1]
		var quad := [Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x), Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x),
			Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x), Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)]
		var mid: Vector3 = (quad[0] + quad[2]) / 2.0
		var facing := Vector3(mid.x, 0.0, mid.z).normalized()
		for tri: Array in [[0, 1, 2], [0, 2, 3]]:
			var order: Array = tri
			var a: Vector3 = quad[tri[0]]
			var across: Vector3 = (quad[tri[1]] - a).cross(quad[tri[2]] - a)
			if across.length_squared() < 1e-12:
				continue
			if across.dot(facing) > 0.0:   # (front faces run clockwise seen from outside, as DecorModel.lathe)
				order = [tri[0], tri[2], tri[1]]
			for v: int in order:
				var q: Vector3 = quad[v]
				st.set_normal(Vector3(q.x, -q.y * 0.15 + 0.2, q.z).normalized())
				st.add_vertex(top + q)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	return mi


## A square brick-and-stone tower: a clock face on each side, a belfry with open arches and a bell, a pointed
## roof with a gold finial.
static func _clock_tower(root: Node3D, c: Vector3, col: Color) -> void:
	var stone := ModelKit.surface(STONE, "stone", 0.35)
	var brick := ModelKit.surface(col, "stone", 0.25)
	ModelKit.box(root, c + Vector3(-0.62, 0, -0.62), c + Vector3(0.62, 0.15, 0.62), stone)
	ModelKit.box(root, c + Vector3(-0.48, 0.15, -0.48), c + Vector3(0.48, 1.9, 0.48), brick)
	ModelKit.box(root, c + Vector3(-0.52, 1.9, -0.52), c + Vector3(0.52, 2.0, 0.52), stone)
	ModelKit.box(root, c + Vector3(-0.12, 0.15, 0.47), c + Vector3(0.12, 0.6, 0.5), ModelKit.paint(Color("#5c3a1e")))
	var face := ModelKit.paint(Color("#f4efe4"))
	var hands := ModelKit.paint(Color("#2b2b2b"))
	for k in 4:
		var turn := Basis(Vector3.UP, PI / 2.0 * k)
		var out := turn * Vector3(0, 0, 1)
		var at := c + Vector3(0, 1.55, 0) + out * 0.49
		var disc := ModelKit.cylinder(root, Vector3.ZERO, 0.26, 0.03, face, -1.0, 20)
		disc.position = at
		disc.basis = turn * Basis(Vector3.RIGHT, PI / 2.0)
		var rim := ModelKit.cylinder(root, Vector3.ZERO, 0.29, 0.02, ModelKit.paint(GOLD, 0.6), -1.0, 20)
		rim.position = at - out * 0.01
		rim.basis = disc.basis
		for h: Array in [[0.0, 0.17], [PI / 2.6, 0.12]]:
			var hand := ModelKit.box(root, Vector3(-0.012, 0, -0.005), Vector3(0.012, float(h[1]), 0.005), hands)
			hand.position = at + out * 0.025
			hand.basis = turn * Basis(Vector3.FORWARD, float(h[0]))
	for k in 4:   # the belfry's corner piers, open between
		var corner := Vector3(0.38 if k % 2 == 0 else -0.38, 0, 0.38 if k < 2 else -0.38)
		ModelKit.box(root, c + corner + Vector3(-0.08, 2.0, -0.08), c + corner + Vector3(0.08, 2.55, 0.08), brick)
	ModelKit.box(root, c + Vector3(-0.5, 2.55, -0.5), c + Vector3(0.5, 2.63, 0.5), stone)
	ModelKit.cylinder(root, c + Vector3(0, 2.12, 0), 0.13, 0.22, ModelKit.paint(GOLD, 0.7), 0.06, 12)
	ModelKit.cylinder(root, c + Vector3(0, 2.63, 0), 0.6, 0.85, ModelKit.surface(Color("#4f6f7a"), "shingles", 0.1),
		0.0, 4).rotation.y = PI / 4.0
	ModelKit.cylinder(root, c + Vector3(0, 3.45, 0), 0.015, 0.18, ModelKit.paint(GOLD, 0.7), -1.0, 6)
	ModelKit.ball(root, c + Vector3(0, 3.66, 0), 0.05, ModelKit.paint(GOLD, 0.7))


## A small stone castle: a keep with battlements, four round corner towers with red cone roofs and flags, a
## gatehouse with a wooden door, all on a grassy mound's stone footing.
static func _castle(root: Node3D, c: Vector3) -> void:
	var stone := ModelKit.surface(STONE, "stone", 0.35)
	var dark := ModelKit.surface(STONE_DARK, "stone", 0.35)
	var roof := ModelKit.surface(ROOF_RED, "shingles", 0.1)
	var flag := ModelKit.paint(FLAG)
	ModelKit.box(root, c + Vector3(-1.6, 0, -1.6), c + Vector3(1.6, 0.12, 1.6), dark)
	ModelKit.box(root, c + Vector3(-1.25, 0.12, -1.25), c + Vector3(1.25, 0.95, 1.25), stone)   # the curtain wall
	_battlements(root, c, 1.25, 0.95, stone)
	ModelKit.box(root, c + Vector3(-0.6, 0.12, -0.6), c + Vector3(0.6, 1.9, 0.6), stone)   # the keep
	_battlements(root, c, 0.6, 1.9, stone)
	for k in 4:
		var corner := Vector3(1.25 if k % 2 == 0 else -1.25, 0, 1.25 if k < 2 else -1.25)
		ModelKit.cylinder(root, c + corner + Vector3(0, 0.12, 0), 0.34, 1.35, stone, -1.0, 14)
		ModelKit.cylinder(root, c + corner + Vector3(0, 1.47, 0), 0.4, 0.06, dark, -1.0, 14)
		ModelKit.cylinder(root, c + corner + Vector3(0, 1.53, 0), 0.4, 0.7, roof, 0.0, 14)
		ModelKit.cylinder(root, c + corner + Vector3(0, 2.2, 0), 0.01, 0.3, ModelKit.paint(WOOD), -1.0, 4)
		ModelKit.box(root, c + corner + Vector3(0.01, 2.36, -0.005), c + corner + Vector3(0.2, 2.48, 0.005), flag)
	ModelKit.box(root, c + Vector3(-0.32, 0.12, 1.2), c + Vector3(0.32, 1.15, 1.42), dark)   # the gatehouse
	ModelKit.box(root, c + Vector3(-0.18, 0.12, 1.41), c + Vector3(0.18, 0.62, 1.44), ModelKit.paint(Color("#5c3a1e")))
	ModelKit.cylinder(root, c + Vector3(0, 1.9, 0), 0.012, 0.5, ModelKit.paint(WOOD), -1.0, 4)
	ModelKit.box(root, c + Vector3(0.01, 2.22, -0.005), c + Vector3(0.32, 2.4, 0.005), flag)


static func _battlements(root: Node3D, c: Vector3, half: float, y: float, mat: Material) -> void:
	var n := maxi(3, roundi(half * 5.0))
	for side in 4:
		var turn := Basis(Vector3.UP, PI / 2.0 * side)
		for k in n:
			var x := -half + (k + 0.5) * (2.0 * half / n)
			var lo := turn * Vector3(x - half / n * 0.45, 0, half - 0.07)
			var hi := turn * Vector3(x + half / n * 0.45, 0.14, half + 0.02)
			ModelKit.box(root, c + Vector3(minf(lo.x, hi.x), y, minf(lo.z, hi.z)),
				c + Vector3(maxf(lo.x, hi.x), y + 0.14, maxf(lo.z, hi.z)), mat)
