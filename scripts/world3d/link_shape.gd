class_name LinkShape
extends RefCounted
## The shape a joining piece takes from the sides it's joined on: a 4-bit mask (north, east, south, west) has
## sixteen cases, but only six shapes, each turned a number of quarter turns. Models are built and drawn
## for the six; a piece is one of them, turned. The table is worked out from the six canonical masks at load,
## not written by hand, and a test checks all sixteen.

enum Kind { POST, END, STRAIGHT, CORNER, TEE, CROSS }

const N := 1
const E := 2
const S := 4
const W := 8

## Each shape's mask when its arms are turned zero times (an end points north, a tee is open to the west).
const CANON := [0, N, N | S, N | E, N | E | S, N | E | S | W]

static var _table: Array[Vector2i] = []   # mask -> (kind, turns)


## `mask` turned `turns` quarter turns clockwise (north becomes east).
static func turn(mask: int, turns: int) -> int:
	var t := posmod(turns, 4)
	return ((mask << t) | (mask >> (4 - t))) & 15


## (kind, turns) of a mask: turning the canonical mask of `kind` by `turns` gives `mask`. (A straight turned
## twice is the same straight: the fewest turns win.)
static func of(mask: int) -> Vector2i:
	if _table.is_empty():
		_table.resize(16)
		_table.fill(Vector2i(-1, -1))
		for kind in CANON.size():
			for turns in 4:
				var m := turn(CANON[kind], turns)
				if _table[m].x == -1:
					_table[m] = Vector2i(kind, turns)
	return _table[mask & 15]


## The mask a shape's model is built for.
static func canon(kind: int) -> int:
	return CANON[kind]


## How far the piece is turned about its tile's centre, as a rotation about the vertical axis (clockwise from above).
static func yaw(turns: int) -> float:
	return -turns * PI / 2.0
