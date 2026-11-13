class_name SpaceFit
extends RefCounted
## Fitting things into space, for the whole game (a pure rule module, nothing saved). Two jobs:
##
## 1. Every tile has a clear border: whatever stands on a footprint keeps TILE_MARGIN inside its edges, so
##    neighbours never touch or overlap (`tile_room`, `fit_model`, `reach`).
## 2. Putting things in a room: animals in a yard, trees in an orchard, anything with a size in a space with
##    some of it taken (`pack`). Each thing is given a place clear of the room's edges, of what is already
##    standing there (`blocked`) and of each other, with a gap; when there is not room at full size they are
##    drawn smaller (down to MIN_SIZE), and past that only as many are shown as fit, in the order given.
##    The size follows from the room and what is put in it, so nothing is tuned per building.
##
## Sizes are in tiles. Callers give each thing's radius on the ground (what it needs clear around it) at full size.

const TILE_MARGIN := 0.1      # clear space inside each side of a footprint; neighbours are twice this apart
const EDGE_CLEAR := 0.05      # the share of a room kept clear all round inside its edge (a yard inside its fence)
const MIN_SIZE := 0.4         # the smallest things are drawn in a crowded room, against full size
const STEP := 0.05            # how much smaller each try is
const GRID := 0.2             # tiles between the places a thing is tried
const WALL_CLEAR := 0.5       # the share of a thing's radius kept clear of what is already standing in the room (walls)
const APART := 1.15           # how far apart two things stand, against their two radii added: a gap between them
const _EPS := 0.002

static var _cache := {}       # pack results, by their question: a room does not change until its contents do


## The ground a footprint leaves for what stands on it: inside the clear border of its tile.
static func tile_room(fp: Vector2i) -> Rect2:
	var edge := Vector2.ONE * TILE_MARGIN
	return Rect2(edge, Vector2(fp) - edge * 2.0)


## A footprint's yard: its tile's room, less EDGE_CLEAR of its size all round (animals keep off the fence).
static func yard_room(fp: Vector2i) -> Rect2:
	var room := tile_room(fp)
	var inset := Vector2(room.size.x, room.size.y) * EDGE_CLEAR
	return Rect2(room.position + inset, room.size - inset * 2.0)


## Where things go in `room` and how big to draw them: {"size": 0..1, "spots": [Vector2, ...]}. `radii` are
## the things in the order that matters (the first are kept when not all fit); `blocked` are rectangles of the
## room already taken. A spot is given for each thing shown, which is all of them unless they do not fit even
## at MIN_SIZE. The same question always gets the same answer (`seed_value` shuffles where things start).
static func pack(room: Rect2, blocked: Array[Rect2], radii: Array[float], seed_value: int) -> Dictionary:
	var key := "%s|%s|%s|%s" % [room, blocked, radii, seed_value]
	if _cache.has(key):
		return _cache[key]
	var cells := _cells(room, seed_value)
	var size := 1.0
	var spots: Array[Vector2] = []
	var out := {}
	while size > MIN_SIZE - _EPS:
		spots = _place(cells, room, blocked, radii, size)
		if spots.size() == radii.size():
			break
		size -= STEP
	if spots.size() < radii.size():
		size = MIN_SIZE
		spots = _place(cells, room, blocked, radii, size)
	if spots.is_empty() and not radii.is_empty():  # a room too small for even one: it stands where there is most space
		spots.append(_roomiest(cells, room, blocked))
	out = {"size": maxf(size, MIN_SIZE), "spots": spots}
	if _cache.size() > 256:
		_cache.clear()
	_cache[key] = out
	return out


## The place with the most clear space round it (from the edges and what is taken), for when nothing fits.
static func _roomiest(cells: PackedVector2Array, room: Rect2, blocked: Array[Rect2]) -> Vector2:
	var best := room.get_center()
	var most := -1.0
	for c in cells:
		var clear := minf(minf(c.x - room.position.x, room.end.x - c.x), minf(c.y - room.position.y, room.end.y - c.y))
		for q in blocked:
			var dx := maxf(maxf(q.position.x - c.x, c.x - q.end.x), 0.0)
			var dy := maxf(maxf(q.position.y - c.y, c.y - q.end.y), 0.0)
			clear = minf(clear, sqrt(dx * dx + dy * dy))
		if clear > most:
			most = clear
			best = c
	return best


static func _cells(room: Rect2, seed_value: int) -> PackedVector2Array:
	var nx := maxi(1, int(room.size.x / GRID))
	var nz := maxi(1, int(room.size.y / GRID))
	var cells := PackedVector2Array()
	for i in nx + 1:
		for j in nz + 1:
			cells.append(room.position + Vector2(room.size.x * i / nx, room.size.y * j / nz))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k in range(cells.size() - 1, 0, -1):
		var swap := rng.randi_range(0, k)
		var t := cells[k]
		cells[k] = cells[swap]
		cells[swap] = t
	return cells


## Places for the things in turn at this size, as many as fit (it stops at the first that does not).
static func _place(cells: PackedVector2Array, room: Rect2, blocked: Array[Rect2], radii: Array[float],
		size: float) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var end := room.end
	for i in radii.size():
		var r := radii[i] * size
		var near := r * WALL_CLEAR
		var found := false
		for c in cells:
			if c.x - room.position.x < r or end.x - c.x < r or c.y - room.position.y < r or end.y - c.y < r:
				continue
			var ok := true
			for q in blocked:
				if c.x > q.position.x - near and c.x < q.end.x + near and c.y > q.position.y - near and c.y < q.end.y + near:
					ok = false
					break
			if ok:
				for j in spots.size():
					var gap := (r + radii[j] * size) * APART
					if c.distance_squared_to(spots[j]) < gap * gap:
						ok = false
						break
			if ok:
				spots.append(c)
				found = true
				break
		if not found:
			break
	return spots


## Brings a model (built in tiles from its footprint's corner) inside its tile's border: whatever reaches past
## is moved in, the whole thing, and shrunk a little only if it is wider than the room. Returns `root`.
static func fit_model(root: Node3D, fp: Vector2i) -> Node3D:
	var box := reach(root)
	var room := tile_room(fp)
	if box.size.x <= 0.0 or room.grow(_EPS).encloses(box):
		return root
	var shrink := minf(1.0, minf(room.size.x / box.size.x, room.size.y / box.size.y))
	var lo := box.position * shrink
	var hi := box.end * shrink
	var shift := Vector2.ZERO
	for axis in 2:
		if hi[axis] > room.end[axis]:
			shift[axis] = room.end[axis] - hi[axis]
		if lo[axis] + shift[axis] < room.position[axis]:
			shift[axis] = room.position[axis] - lo[axis]
	root.scale = Vector3.ONE * shrink
	root.position = Vector3(shift.x, 0.0, shift.y)
	return root


## The ground covered (x and z, in tiles) by every mesh under `node`, in the space of its parent when `xf` is the
## node's own transform (by default its own units, its transform left out).
static func reach(node: Node3D, xf := Transform3D.IDENTITY) -> Rect2:
	var box := Rect2()
	var first := true
	for child in node.get_children():
		if not child is Node3D:
			continue
		var here := xf * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var b: AABB = here * (child as MeshInstance3D).mesh.get_aabb()
			var r := Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z))
			box = r if first else box.merge(r)
			first = false
		if child is MultiMeshInstance3D and (child as MultiMeshInstance3D).multimesh != null:
			var m: AABB = here * (child as MultiMeshInstance3D).multimesh.get_aabb()
			var mr := Rect2(Vector2(m.position.x, m.position.z), Vector2(m.size.x, m.size.z))
			box = mr if first else box.merge(mr)
			first = false
		var inner := reach(child, here)
		if inner.size != Vector2.ZERO:
			box = inner if first else box.merge(inner)
			first = false
	return box
