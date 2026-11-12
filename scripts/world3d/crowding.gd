class_name Crowding
extends RefCounted
## How packed in a thing is among its own kind (0: stands alone, 1: every tile round it holds another). A shared
## visual rule: things that crowd together look grown together, as in FarmVille's orchards. A crowded tree stands
## a little taller on a longer trunk, its crown swells to meet its neighbours' and its undersides sit in deeper
## shade, so overlapping crowns read as one leafy mass over a shaded floor of trunks, not as separate balls.
## A kind opts in by listing itself in GROUPS and reading `of(o)` (or `level(o)`, in a view's key, so the view is
## rebuilt when a neighbour comes or goes) where it is built.

const GROUPS: Array[String] = ["tree", "bloom"]   # the kinds that crowd (decorations such as hedges can join)
const STEPS := 4                                   # `level`: crowd in this many steps (a view is rebuilt per step)
const SHADE := 0.3                                 # how much darker the lower parts of a fully crowded thing are
const SWELL := 0.1                                 # how much wider a fully crowded crown grows
const LIFT := 0.2                                  # how much taller its trunk stands


## The share of the ring of tiles round `o`'s footprint holding another thing of its kind.
static func of(o: Dictionary) -> float:
	var kind := Game.kind_of(o)
	if not kind in GROUPS:
		return 0.0
	var fp := Game.footprint(str(o["id"]))
	var row := int(o["row"])
	var col := int(o["col"])
	var ring := 0
	var same := 0
	for r in range(row - 1, row + fp.y + 1):
		for c in range(col - 1, col + fp.x + 1):
			if r >= row and r < row + fp.y and c >= col and c < col + fp.x:
				continue
			if r < 0 or c < 0 or r >= Game.farm_size or c >= Game.farm_size:
				continue
			ring += 1
			var n := Game.object_at(Game.index_of(r, c))
			if not n.is_empty() and Game.kind_of(n) == kind:
				same += 1
	return float(same) / float(ring) if ring > 0 else 0.0


## `of`, in whole steps (0..STEPS): what goes in a view's key.
static func level(o: Dictionary) -> int:
	return roundi(of(o) * STEPS)


## A step as a share again.
static func share(step: int) -> float:
	return float(step) / float(STEPS)
