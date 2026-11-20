class_name FrondMesh
extends RefCounted
## The leaves of palms and banana trees, as triangles added to a tree's own SurfaceTool: a feather frond (a rib
## arching out and down, leaflets in pairs along it) and a paddle (a banana's broad leaf, its midrib pale). Each
## is laid along `at`'s +x from its base at `at`'s origin, its colour in its vertices, and carries in UV how far
## along it each point is (x) and the leaf's own beat (y): what `frond3d.gdshader` bobs it by in the wind.

const ARCH_PULL := 0.18       # how much a leaf's droop also pulls its tip in toward the trunk
const LEAFLET_FALL := 0.42    # how far a leaflet's tip hangs below the rib, of its own length..
const LEAFLET_SWEEP := 0.12   # ..and leans toward the frond's tip
const LEAFLET_FOOT := 0.82    # how much of the rib between two leaflets one's foot takes
const LEAFLET_TIP := 0.6      # where along that foot its tip stands
const LEAFLET_ENDS := 0.1     # how short the first leaflets are (of the way round to the middle's full length)
const LEAFLET_ROUND := 0.6    # how evenly their lengths run from base to tip (1: a diamond; less: fuller)
const RIB_WIDE := 0.012       # the rib's half-width, of the frond's length
const RIB_LIGHT := 0.3        # how much paler the rib is than the leaf
const TIP_LIGHT := 0.18       # ..and a frond's tip than its base
const EDGE_DARK := 0.12       # how much darker a leaflet's foot is than its tip (a painted fold)
const BAND_DARK := 0.08       # every other leaflet or band, darker by this: the leaf reads as many parts
const PADDLE_ROWS := 10       # bands along a paddle
const PADDLE_KEEL := 0.3      # how far a paddle's edges fall below its midrib, of its half-width
const PADDLE_ROUND := 0.55    # how full a paddle's outline is (1: a pointed oval; less: broader ends)
const PADDLE_FOOT := 0.06     # how wide it already is where it leaves the stem (0: a point)
const PADDLE_RIB_LIGHT := 0.35


## A point `s` (0..1) along a leaf `length` long that climbs by `rise` and falls by `droop`.
static func along(length: float, rise: float, droop: float, s: float) -> Vector3:
	return Vector3(length * s * (1.0 - ARCH_PULL * s * droop), length * (rise * s - droop * s * s), 0)


## A feather frond `length` long with `pairs` of leaflets, the longest `leaflet` long, in `col`.
static func feather(st: SurfaceTool, at: Transform3D, length: float, rise: float, droop: float, leaflet: float,
		pairs: int, col: Color, beat: float) -> void:
	for i in pairs:
		var s0 := float(i) / pairs
		var s1 := float(i + 1) / pairs
		var mid := (s0 + s1) * 0.5
		var a := along(length, rise, droop, s0)
		var b := along(length, rise, droop, s1)
		var long := leaflet * pow(sin(PI * (LEAFLET_ENDS + (1.0 - LEAFLET_ENDS - 0.02) * mid)), LEAFLET_ROUND)
		var shade := col.lightened(TIP_LIGHT * mid).darkened(BAND_DARK if i % 2 == 0 else 0.0)
		for side: float in [-1.0, 1.0]:
			var tip := a.lerp(b, LEAFLET_TIP) + Vector3(LEAFLET_SWEEP * long, -LEAFLET_FALL * long, side * long)
			_point(st, at, a, shade.darkened(EDGE_DARK), s0, beat)
			_point(st, at, a.lerp(b, LEAFLET_FOOT), shade.darkened(EDGE_DARK), s1, beat)
			_point(st, at, tip, shade, mid, beat)
		var rib := col.lightened(RIB_LIGHT)
		_point(st, at, a + Vector3(0, RIB_WIDE * length * 0.6, RIB_WIDE * length), rib, s0, beat)
		_point(st, at, a + Vector3(0, RIB_WIDE * length * 0.6, -RIB_WIDE * length), rib, s0, beat)
		_point(st, at, b + Vector3(0, RIB_WIDE * length * 0.6, 0), rib, s1, beat)


## A paddle leaf `length` long and `wide` to each side at its broadest, in `col`.
static func paddle(st: SurfaceTool, at: Transform3D, length: float, rise: float, droop: float, wide: float,
		col: Color, beat: float) -> void:
	var rib := col.lightened(PADDLE_RIB_LIGHT)
	for i in PADDLE_ROWS:
		var s0 := float(i) / PADDLE_ROWS
		var s1 := float(i + 1) / PADDLE_ROWS
		var a := along(length, rise, droop, s0)
		var b := along(length, rise, droop, s1)
		var w0 := wide * pow(sin(PI * (PADDLE_FOOT + (1.0 - PADDLE_FOOT) * s0)), PADDLE_ROUND)
		var w1 := wide * pow(sin(PI * (PADDLE_FOOT + (1.0 - PADDLE_FOOT) * s1)), PADDLE_ROUND)
		var edge := col.darkened(BAND_DARK if i % 2 == 0 else 0.0)
		for side: float in [-1.0, 1.0]:
			var e0 := a + Vector3(0, -PADDLE_KEEL * w0, side * w0)
			var e1 := b + Vector3(0, -PADDLE_KEEL * w1, side * w1)
			_point(st, at, a, rib, s0, beat)
			_point(st, at, b, rib, s1, beat)
			_point(st, at, e1, edge, s1, beat)
			_point(st, at, a, rib, s0, beat)
			_point(st, at, e1, edge, s1, beat)
			_point(st, at, e0, edge, s0, beat)


static func _point(st: SurfaceTool, at: Transform3D, p: Vector3, col: Color, s: float, beat: float) -> void:
	st.set_color(col)
	st.set_uv(Vector2(s, beat))
	st.add_vertex(at * p)
