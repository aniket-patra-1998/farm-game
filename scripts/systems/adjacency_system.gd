class_name AdjacencySystem
extends GameSystem
## Layout synergies (our own touch, not FarmVille 2009; Balance `synergy.enabled` 0 turns them off). Pieces of
## one kind that touch pay more: each neighbour adds a share to the coins of a collect, up to a cap
## (data/synergies.json says which families and how much). Nothing here is saved: like LinksSystem it works
## out from where pieces stand, so it can never disagree with the farm and old saves have it on load.

const DATA := "res://data/synergies.json"
const SIDES: Array[Vector2i] = LinksSystem.SIDES

var _groups := {}   # group id -> {"families", "per_neighbour", "max_neighbours", "boost"}


func load_data() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var d: Dictionary = parsed if parsed is Dictionary else {}
	_groups = d.get("groups", {})


func is_on() -> bool:
	return Balance.i("synergy.enabled") != 0


## The group an item belongs to ("" when none), by its catalog family.
func group_of(item_id: String) -> String:
	var fam := str(game.item_data(item_id).get("family", ""))
	for g: String in _groups:
		if fam in _groups[g].get("families", []):
			return g
	return ""


## The uids of the pieces of the same item that share an edge with an item of `item_id` standing at (row, col).
## `ignore_uid` is a piece in hand (it isn't standing anywhere).
func neighbours_at(item_id: String, row: int, col: int, ignore_uid := -1) -> Array[int]:
	var out: Array[int] = []
	if not is_on() or group_of(item_id).is_empty():
		return out
	var fp := game.footprint(item_id)
	for r in range(row, row + fp.y):
		for c in range(col, col + fp.x):
			for s in SIDES:
				var nr := r + s.x
				var nc := c + s.y
				# Cells of the piece itself are not neighbours.
				if nr >= row and nr < row + fp.y and nc >= col and nc < col + fp.x:
					continue
				if not game.in_farm(nr, nc):
					continue
				var n := game.object_at(game.index_of(nr, nc))
				var uid := int(n.get("uid", -1))
				if n.is_empty() or uid == ignore_uid or str(n["id"]) != item_id or uid in out:
					continue
				out.append(uid)
	return out


## How many neighbours count for a piece standing at (row, col): the touching ones, up to the group's cap.
func count_at(item_id: String, row: int, col: int, ignore_uid := -1) -> int:
	var g := group_of(item_id)
	if g.is_empty():
		return 0
	return mini(neighbours_at(item_id, row, col, ignore_uid).size(), int(_groups[g]["max_neighbours"]))


## Neighbours counting for a placed piece.
func count(o: Dictionary) -> int:
	if o.is_empty() or not o.has("row"):
		return 0
	return count_at(str(o["id"]), int(o["row"]), int(o["col"]), int(o.get("uid", -1)))


## The bonus share a count of neighbours gives an item (0.2 = +20%).
func bonus_for(item_id: String, neighbours: int) -> float:
	var g := group_of(item_id)
	return 0.0 if g.is_empty() else float(_groups[g]["per_neighbour"]) * neighbours


## The coins multiplier for collecting this piece (1 when it touches none of its kind).
func coin_multiplier(o: Dictionary) -> float:
	return 1.0 + bonus_for(str(o.get("id", "")), count(o))
