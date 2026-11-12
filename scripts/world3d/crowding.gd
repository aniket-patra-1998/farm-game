class_name Crowding
extends RefCounted
## A universal visual and rendering rule for things that stand packed together, as in FarmVille's orchards.
## Looks: a crowded thing grows as one with its neighbours (a tree stands taller, its crown swells to meet theirs
## and its underside sits in shade, so crowns read as one leafy mass over a floor of trunks). Cost: the parts of a
## thing that face a neighbour of its group are covered anyway, so they are left out (a packed orchard draws
## about three quarters of its trees' parts, a fence run shares its posts). Two trees side by side cost
## about one and a half.
## A group lives in data/crowding.json (matched by item id, then by kind). A model asks `mask(o)` of its placed
## object, reads the group's numbers with `setting`, uses `share_of` for how packed in it is and `covered` to
## know whether a part faces a neighbour. A view's key holds the mask, so it is rebuilt when a neighbour
## comes or goes.

const PATH := "res://data/crowding.json"
## The eight neighbours as (row, col) steps; a mask has one bit each, in this order.
const DIRS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -1), Vector2i(0, 1),
	Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)]

static var _groups: Dictionary = {}


static func _load() -> void:
	if not _groups.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_groups = (parsed as Dictionary).get("groups", {})


## The group an object belongs to ("" when it doesn't crowd).
static func group_of(o: Dictionary) -> String:
	_load()
	var id := str(o.get("id", ""))
	var kind := Game.kind_of(o)
	for g: String in _groups:
		var def: Dictionary = _groups[g]
		if id in def.get("ids", []) or (not def.has("ids") and kind in def.get("kinds", [])):
			return g
	return ""


## One number of a group's rules (0 for a group or key that isn't there).
static func setting(group: String, key: String) -> float:
	_load()
	return float((_groups.get(group, {}) as Dictionary).get(key, 0.0))


## Which of the eight tiles round `o`'s footprint hold another thing of its group (a bit each, see DIRS).
static func mask(o: Dictionary) -> int:
	var group := group_of(o)
	if group.is_empty() or not o.has("row"):   # previews and sheets show a thing on its own
		return 0
	var fp := Game.footprint(str(o["id"]))
	var row := int(o["row"])
	var col := int(o["col"])
	var out := 0
	for r in range(row - 1, row + fp.y + 1):
		for c in range(col - 1, col + fp.x + 1):
			if r >= row and r < row + fp.y and c >= col and c < col + fp.x:
				continue
			if r < 0 or c < 0 or r >= Game.farm_size or c >= Game.farm_size:
				continue
			var n := Game.object_at(Game.index_of(r, c))
			if n.is_empty() or group_of(n) != group:
				continue
			var step := Vector2i(signi(r - row) if r < row else (1 if r >= row + fp.y else 0),
				-1 if c < col else (1 if c >= col + fp.x else 0))
			out |= 1 << DIRS.find(step)
	return out


## How packed in a mask is: 0 alone, 1 with something on every side.
static func share_of(m: int) -> float:
	var n := 0
	for i in DIRS.size():
		n += (m >> i) & 1
	return float(n) / DIRS.size()


## Whether a neighbour of the group stands on the side a part faces; `angle` is its direction on the ground
## (0 along +col, a quarter turn towards +row), in the world, not turned by the model.
static func covered(m: int, angle: float) -> bool:
	var s := posmod(roundi(angle / (PI / 4.0)), 8)
	var step := Vector2i(roundi(sin(s * PI / 4.0)), roundi(cos(s * PI / 4.0)))
	return (m >> DIRS.find(step)) & 1 == 1


## Whether the next tile along a row (`dir` +1 south, -1 north) holds a thing of the group: where a run goes on.
static func joined(m: int, dir: int) -> bool:
	return (m >> DIRS.find(Vector2i(dir, 0))) & 1 == 1
