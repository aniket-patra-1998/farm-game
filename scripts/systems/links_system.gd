class_name LinksSystem
extends GameSystem
## What each fence, hedge, wall or path piece is joined to. Nothing here is saved: how a piece joins is worked
## out from where its neighbours stand (data/linking.json says what joins what), so it can never disagree with
## the farm, old saves join up on load, and nothing needs migrating. Views ask `mask`; LinkShape turns a mask
## into the piece's shape.

## The four sides as (row, col) steps, in LinkShape's bit order: north, east, south, west.
const SIDES: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1)]


## The joining group of an item ("" when it doesn't join).
func group_of(item_id: String) -> String:
	return Linking.group_of_shape(str(game.item_data(item_id).get("shape", "")))


## Which sides of tile (row, col) hold a piece that a piece of `group` joins. `ignore_uid` is a piece in
## hand: it's not standing there.
func mask_at(group: String, row: int, col: int, ignore_uid := -1) -> int:
	var out := 0
	for d in SIDES.size():
		var r := row + SIDES[d].x
		var c := col + SIDES[d].y
		if not game.in_farm(r, c):
			continue
		var n := game.object_at(game.index_of(r, c))
		if n.is_empty() or int(n.get("uid", -2)) == ignore_uid:
			continue
		if Linking.joins(group, group_of(str(n["id"]))):
			out |= 1 << d
	return out


## The sides a placed piece is joined on (0 for anything that doesn't join).
func mask(o: Dictionary) -> int:
	var group := group_of(str(o.get("id", "")))
	if group.is_empty() or not o.has("row"):
		return 0
	return mask_at(group, int(o["row"]), int(o["col"]), int(o.get("uid", -1)))
