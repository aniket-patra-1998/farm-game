class_name VehicleRoute
extends RefCounted
## The road a vehicle drives over the area it works: lanes down the area (rows), two tiles apart, one after
## the other, joined at the ends by half circles, coming in from one side of the area and leaving by the
## last lane's end. Points are (x = column, z = row) in tiles, like everything in the 3D farm. Pure data.

const LANE := 2.0         # tiles between lanes (the same as Trails.LANE: the tracks it leaves)
const MARGIN := 0.9       # how far past the area's ends a lane runs, so the turns happen outside the work
const APPROACH := 1.8     # how far outside the area it starts and ends
const ARC_STEPS := 8


## Lanes' x positions across an area `width` tiles wide that starts at column `col`.
static func lane_xs(col: int, width: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var lanes := maxi(ceili(width / LANE), 1)
	for k in lanes:
		out.append(col + minf(LANE * (k + 0.5), width - 0.5))
	return out


## The route over the area whose top-left plot is (row, col) and which is `area.x` columns by `area.y` rows.
## The lane index of each point comes back in `lane_of` (-1 for the approach, turns and the leaving stretch).
static func plan(row: int, col: int, area: Vector2i) -> Dictionary:
	var xs := lane_xs(col, area.x)
	var pts := PackedVector2Array()
	var lane_of := PackedInt32Array()
	var top := float(row) - MARGIN
	var bottom := float(row + area.y) + MARGIN
	var going_down := true
	pts.append(Vector2(xs[0], top - APPROACH))
	lane_of.append(-1)
	for k in xs.size():
		var from_z := top if going_down else bottom
		var to_z := bottom if going_down else top
		pts.append(Vector2(xs[k], from_z))
		lane_of.append(k)
		pts.append(Vector2(xs[k], to_z))
		lane_of.append(k)
		if k + 1 < xs.size():
			# A half circle to the next lane, bulging past the end it just reached.
			var mid_x := (xs[k] + xs[k + 1]) / 2.0
			var radius := (xs[k + 1] - xs[k]) / 2.0
			var out_dir := 1.0 if going_down else -1.0
			for s in range(1, ARC_STEPS):
				var a := PI * s / ARC_STEPS
				pts.append(Vector2(mid_x - cos(a) * radius, to_z + out_dir * sin(a) * radius))
				lane_of.append(-1)
		going_down = not going_down
	var end_dir := 1.0 if not going_down else -1.0   # the last lane ended going down if it started that way
	var last_z: float = pts[pts.size() - 1].y
	pts.append(Vector2(xs[xs.size() - 1], last_z + end_dir * APPROACH))
	lane_of.append(-1)
	return {"points": pts, "lane_of": lane_of}


## Total length of a route.
static func length_of(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	return total


## The point `d` tiles along the route and the direction there (clamped to the ends); also the index of the
## segment it is on.
static func at(pts: PackedVector2Array, d: float) -> Dictionary:
	var left := maxf(d, 0.0)
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		if left <= seg or i == pts.size() - 1:
			var t := clampf(left / maxf(seg, 0.0001), 0.0, 1.0)
			return {"pos": pts[i - 1].lerp(pts[i], t), "dir": (pts[i] - pts[i - 1]).normalized(), "seg": i - 1}
		left -= seg
	return {"pos": pts[0], "dir": Vector2.RIGHT, "seg": 0}
