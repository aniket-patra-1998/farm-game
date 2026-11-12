class_name AnimalLoft
extends RefCounted
## Sculpted shapes for the animals: a body, head or limb made as one smooth mesh from a table of stations along
## its length (data/animal_builds.json), instead of balls stuck together. A station is [x, top, bottom, width]:
## how far along (-1 rear .. 1 front), how high its top and low its bottom stand, and how wide it is, each a
## share of the part's size. The cross-section between them is a rounded box (`box` 2 is an ellipse, higher is
## squarer), so a cow's barrel, a horse's deep chest and tucked waist, a pig's ham all come from their own
## outline. Limbs and necks are tubes with a radius profile.

const RING := 14            # points round a station
const TUBE_RING := 9


## A smooth body from `stations`, its half extents `size` (length, height, width).
static func body(outline: Array, size: Vector3, box := 2.4) -> ArrayMesh:
	var stations := _rounded(outline)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := stations.size()
	for i in n:
		var s: Array = stations[i]
		var mid := (float(s[1]) + float(s[2])) * 0.5
		var half := maxf((float(s[1]) - float(s[2])) * 0.5, 0.001)
		for j in RING:
			var a := TAU * j / RING
			var cy := sin(a)
			var cz := cos(a)
			var y := mid + signf(cy) * pow(absf(cy), 2.0 / box) * half
			var z := signf(cz) * pow(absf(cz), 2.0 / box) * float(s[3])
			st.add_vertex(Vector3(float(s[0]) * size.x, y * size.y, z * size.z))
	for i in n - 1:
		for j in RING:
			var a := i * RING + j
			var b := i * RING + (j + 1) % RING
			var c := (i + 1) * RING + j
			var d := (i + 1) * RING + (j + 1) % RING
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	_cap(st, stations[0], 0, size, -1.0, n * RING)
	_cap(st, stations[n - 1], (n - 1) * RING, size, 1.0, n * RING + 1)
	st.generate_normals()
	return st.commit()


## The outline with each end drawn in two more steps, shrinking toward a point, so the ends are rounded off
## rather than cut flat.
static func _rounded(outline: Array) -> Array:
	var out: Array = []
	var first: Array = outline[0]
	var last: Array = outline[outline.size() - 1]
	for k: float in [0.1, 0.05]:
		out.append(_shrunk(first, -k, 0.35 if k > 0.07 else 0.75))
	for s: Array in outline:
		out.append(s)
	for k: float in [0.05, 0.1]:
		out.append(_shrunk(last, k, 0.75 if k < 0.07 else 0.35))
	return out


## A station like `s`, moved `dx` along and drawn at `scale` of its height and width about its middle.
static func _shrunk(s: Array, dx: float, scale: float) -> Array:
	var mid := (float(s[1]) + float(s[2])) * 0.5
	return [float(s[0]) + dx, mid + (float(s[1]) - mid) * scale, mid + (float(s[2]) - mid) * scale,
		float(s[3]) * scale]


## Closes an end of a body: a point at the middle of the end station, fanned to its ring.
static func _cap(st: SurfaceTool, s: Array, first: int, size: Vector3, side: float, count: int) -> void:
	var mid := (float(s[1]) + float(s[2])) * 0.5
	var centre := count
	st.add_vertex(Vector3(float(s[0]) * size.x, mid * size.y, 0.0))
	for j in RING:
		st.add_index(centre)
		if side < 0.0:
			st.add_index(first + (j + 1) % RING)
			st.add_index(first + j)
		else:
			st.add_index(first + j)
			st.add_index(first + (j + 1) % RING)


## A tube along y from -0.5 to 0.5 (t 0 at the bottom): `profile` is [[t, radius]]; `depth` makes it deeper
## front to back (z) than wide (x). Radii are in units of `width` / 2.
static func tube(profile: Array, width: float, depth := 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Array in profile:
		var r := float(p[1]) * width * 0.5
		for j in TUBE_RING:
			var a := TAU * j / TUBE_RING
			st.add_vertex(Vector3(cos(a) * r, float(p[0]) - 0.5, sin(a) * r * depth))
	for i in profile.size() - 1:
		for j in TUBE_RING:
			var a := i * TUBE_RING + j
			var b := i * TUBE_RING + (j + 1) % TUBE_RING
			var c := (i + 1) * TUBE_RING + j
			var d := (i + 1) * TUBE_RING + (j + 1) % TUBE_RING
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	return st.commit()


## The (top, bottom, width) of `stations` at `x` (-1..1), between the two stations either side of it.
static func at(stations: Array, x: float) -> Vector3:
	var first: Array = stations[0]
	if x <= float(first[0]):
		return Vector3(first[1], first[2], first[3])
	for i in stations.size() - 1:
		var a: Array = stations[i]
		var b: Array = stations[i + 1]
		if x <= float(b[0]):
			var t := inverse_lerp(float(a[0]), float(b[0]), x)
			return Vector3(lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t),
				lerpf(float(a[3]), float(b[3]), t))
	var last: Array = stations[stations.size() - 1]
	return Vector3(last[1], last[2], last[3])


## How far out from the middle line the surface stands at height `y` (a share of the part's height) and `x`: the
## z to put a spot or an eye at so it sits on the skin.
static func surface_z(stations: Array, x: float, y: float, box := 2.4) -> float:
	var s := at(stations, x)
	var mid := (s.x + s.y) * 0.5
	var half := maxf((s.x - s.y) * 0.5, 0.001)
	var ny := clampf(absf(y - mid) / half, 0.0, 1.0)
	return s.z * pow(maxf(1.0 - pow(ny, box), 0.0), 1.0 / box)
