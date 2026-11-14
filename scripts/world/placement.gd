class_name Placement
extends RefCounted
## Putting things on the farm: a new purchase, something carried back out of the barn, or a thing lifted to be
## moved. Holds what is in hand (`state`: item, uid, row, col, the homes that would take it, the home under the
## finger) and turns presses and drags into "where it would go" and, on letting go, into the move itself.
## Fences, hedges, walls and paths are laid as a line: press where it starts, drag along the ground, let go.
## The FarmGrid owns one (`grid.placement`) and draws the ghost from `state`.

const LINE_MAX := 40   # the longest line laid in one drag, in tiles

var grid: FarmGrid
## What is in hand: {"item": id, "uid": -1 (a purchase) or the uid being moved, "stored": barn index, "row", "col",
## "homes": {home uid: fit} (every home of the right kind, ready or not), "home": the home under the finger that
## would take it now or -1, "refused": the home of the right kind under the finger that can't take it yet or -1}.
var state := {}

func _init(owner: FarmGrid) -> void:
	grid = owner


func start(item_id: String, uid := -1) -> void:
	state = {"item": item_id, "uid": uid, "row": -1, "col": -1}
	if uid != -1:
		var o := Game.object_by_uid(uid)
		state["row"] = int(o["row"])
		state["col"] = int(o["col"])
	var hint := tr("DRAG_ALONG_THE_GROUND_TO_LAY")
	if not _lays_a_line():
		hint = (tr("DRAG_TO_MOVE_THE_THEN_LET") if uid != -1 else tr("DRAG_TO_PLACE_THE_THEN_LET")) \
			% Game.item_data(item_id)["name"]
	refresh_homes()
	grid.placing_changed.emit(hint)
	grid.queue_redraw()




## Whether what's in hand is bought piece by piece in a line (a purchase of something that joins its neighbours).
func _lays_a_line() -> bool:
	return int(state.get("uid", -1)) == -1 and int(state.get("stored", -1)) < 0 \
		and not Game.links.group_of(str(state.get("item", ""))).is_empty()


## The tiles from where the press began to `tile`, along whichever way the finger has gone further.
func _line_to(tile: Vector2i) -> Array:
	var a: Vector2i = state["anchor"]
	var d := tile - a
	var along_rows := absi(d.x) > absi(d.y)
	var steps := mini(maxi(absi(d.x), absi(d.y)), LINE_MAX - 1)
	var out: Array = []
	for k in steps + 1:
		var t := a + (Vector2i(signi(d.x) * k, 0) if along_rows else Vector2i(0, signi(d.y) * k))
		if Game.in_farm(t.x, t.y):
			out.append(t)
	return out


## Which tiles of a line will be laid: free and unplanted, and as many as the coins reach.
func _line_ok(line: Array) -> Array:
	var cost := int(Game.item_data(state["item"]).get("cost", 0))
	var afford := Game.coins / cost if cost > 0 else line.size()
	var out: Array = []
	var laid := 0
	for t: Vector2i in line:
		var good := laid < afford and Game.can_place(state["item"], t.x, t.y)
		out.append(good)
		if good:
			laid += 1
	return out


## A press or drag of a line: it follows the finger; letting go lays it.
func _line_input(event: InputEvent, tile: Vector2i, released: bool) -> void:
	if not state.has("anchor") or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		state["anchor"] = tile
	var line := _line_to(tile)
	var ok := _line_ok(line)
	if line != state.get("line", []) or ok != state.get("line_ok", []):
		state["line"] = line
		state["line_ok"] = ok
		var laid := ok.count(true)
		var cost := int(Game.item_data(state["item"]).get("cost", 0))
		var what := str(Game.item_data(state["item"])["name"])
		grid.placing_changed.emit(tr("LAY_PIECES_FOR_COINS") % [laid, what, laid * cost])
		grid.queue_redraw()
	state["row"] = tile.x
	state["col"] = tile.y
	if released:
		_lay(line, ok)


## Buys and places the pieces of a line, in order, stopping if the coins run out.
func _lay(line: Array, ok: Array) -> void:
	var item := str(state["item"])
	var cost := int(Game.item_data(item).get("cost", 0))
	var laid := 0
	var last := Vector2i(-1, -1)
	for i in line.size():
		if not ok[i]:
			continue
		var t: Vector2i = line[i]
		if not Game.buy_and_place(item, t.x, t.y):
			break
		laid += 1
		last = t
	state.erase("anchor")
	state.erase("line")
	state.erase("line_ok")
	if laid == 0:
		Feedback.moment("error")
		grid.info.emit(tr("IT_DOESN_T_FIT_THERE_TRY"))
		return
	if not grid.pieces.three_d:
		Feedback.moment("place")
	grid._float(grid.corners_of(last.x, last.y, 1, 1)[2], "-%d" % (laid * cost), "cost")
	if laid < line.size():
		grid.info.emit(tr("LAID_OF_THE_REST_WERE_BLOCKED") % [laid, line.size()])
	cancel()


## Where the thing being placed comes from, as HousingSystem expects it.
func _source() -> Dictionary:
	if int(state.get("uid", -1)) != -1:
		return {"uid": int(state["uid"])}
	if int(state.get("stored", -1)) >= 0:
		return {"stored": int(state["stored"])}
	return {"buy": true}


## The homes that take what's being placed, with how each fits: worked out when state starts and when
## the farm changes, so drawing them every frame costs nothing.
func refresh_homes() -> void:
	if state.is_empty():
		return
	var fits := {}
	for pair in Game.homes.homes_for(state["item"], _source()):
		fits[int(pair[0]["uid"])] = pair[1]
	state["homes"] = fits
	if not fits.has(int(state.get("home", -1))):
		state["home"] = -1
	if not fits.has(int(state.get("refused", -1))):
		state["refused"] = -1


## Under the finger, a home that takes what's being placed? Remembers it and says what a drop would do.
func _hover_home(tile: Vector2i) -> void:
	var home := -1     # a home that takes it now: lit, and a drop goes in
	var refused := -1  # a home of the right kind that can't yet (unbuilt, broken, full): not lit, a drop goes back
	var homes: Dictionary = state.get("homes", {})
	if tile.x >= 0 and tile.x < Game.farm_size and tile.y >= 0 and tile.y < Game.farm_size:
		var b := Game.object_at(Game.index_of(tile.x, tile.y))
		if not b.is_empty() and homes.has(int(b["uid"])):
			if homes[int(b["uid"])] == HousingSystem.Fit.FITS:
				home = int(b["uid"])
			else:
				refused = int(b["uid"])
	if home == int(state.get("home", -1)) and refused == int(state.get("refused", -1)):
		return
	state["home"] = home
	state["refused"] = refused
	var thing := str(Game.item_data(state["item"])["name"])
	if refused != -1:
		var rb := Game.object_by_uid(refused)
		grid.placing_changed.emit(Game.buildings.can_move_in(rb, state["item"], _source()).text)
	elif home == -1:
		grid.placing_changed.emit((tr("DRAG_TO_MOVE_THE_THEN_LET") if int(state["uid"]) != -1
			else tr("DRAG_TO_PLACE_THE_THEN_LET")) % thing)
	else:
		grid.placing_changed.emit(tr("DROP_TO_MOVE_INTO") % [thing, Game.item_data(Game.object_by_uid(home)["id"])["name"]])


## Placing something taken back out of the barn (free; it keeps its timers reset).
func start_stored(index: int) -> void:
	var o: Dictionary = Game.storage.stored[index]
	state = {"item": o["id"], "uid": -1, "stored": index, "row": -1, "col": -1}
	refresh_homes()
	grid.placing_changed.emit(tr("DRAG_TO_PLACE_THE_THEN_LET") % Game.item_data(o["id"])["name"])
	grid.queue_redraw()




func cancel() -> void:
	state = {}
	grid.placing_changed.emit("")
	grid.queue_redraw()




## Press or drag shows where the object will go; letting go places it if it fits.
func input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var released := false
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.index != 0:
			return
		pos = t.position
		released = not t.pressed
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index != 0:
			return
		pos = d.position
	else:
		return
	if not grid._on_farm_area(pos):
		return
	var fp := Game.footprint(state["item"])
	var tile := grid._tile_at_screen(pos)
	if _lays_a_line():
		_line_input(event, tile, released)
		return
	# Centre the footprint under the finger.
	var was_row: int = state.get("row", -1)
	var was_col: int = state.get("col", -1)
	state["row"] = tile.x - int(fp.y / 2.0)
	state["col"] = tile.y - int(fp.x / 2.0)
	_hover_home(tile)
	if state["row"] != was_row or state["col"] != was_col:
		grid.queue_redraw()  # only when it moved to another tile, not on every touch event
	if not released:
		return
	if int(state.get("refused", -1)) != -1:
		_refuse(Game.buildings.can_move_in(Game.object_by_uid(int(state["refused"])), state["item"], _source()).text)
		return
	if int(state.get("home", -1)) != -1:
		# Dropped on a home that takes it: in it goes.
		var home := Game.object_by_uid(int(state["home"]))
		var source := _source()
		if Game.homes.put_in_home(int(state["home"]), state["item"], source):
			Feedback.moment("place")
			if source.has("buy"):
				var hfp := Game.footprint(home["id"])
				grid._float(grid.corners_of(int(home["row"]), int(home["col"]), hfp.x, hfp.y)[2],
					"-%d" % int(Game.item_data(state["item"])["cost"]), "cost")
			cancel()
		else:
			_refuse("")
		return
	var row := int(state["row"])
	var col := int(state["col"])
	var uid := int(state["uid"])
	var spot := Game.buildings.can_place(state["item"], row, col, uid)
	if not spot.ok():
		# Why it doesn't fit, and (for something lifted or stored) that it went back.
		_refuse(spot.text + ("" if not _has_origin() else " " + tr("SO_IT_WENT_BACK")))
		return
	var from_storage := int(state.get("stored", -1))
	var ok: bool
	if from_storage >= 0:
		ok = Game.storage.place_from_storage(from_storage, row, col)
	elif uid != -1:
		ok = Game.move_object(uid, row, col)
	else:
		ok = Game.buy_and_place(state["item"], row, col)
	if ok:
		# Something new drops onto the 3D farm, and thuds when it lands (Farm3D); a move settles at once.
		if uid != -1 or not grid.pieces.three_d:
			Feedback.moment("place")
		if uid == -1 and from_storage < 0:
			grid._float(
				grid.corners_of(row, col, fp.x, fp.y)[2],
				"-%d" % int(Game.item_data(state["item"])["cost"]),
				"cost"
			)
		cancel()
	else:
		_refuse("")


## Something lifted off the farm, or taken out of the Barn, has somewhere to go back to; a purchase doesn't (it
## stays in hand to try again, or is cancelled).
func _has_origin() -> bool:
	return int(state.get("uid", -1)) != -1 or int(state.get("stored", -1)) >= 0


## A drop that can't happen. What was lifted goes back where it came from (it never left: the hand is just
## emptied); a purchase stays in hand. `message` says why (a refusal may already have said it).
func _refuse(message: String) -> void:
	Feedback.moment("error")
	if message != "":
		grid.info.emit(message)
	if _has_origin():
		cancel()
