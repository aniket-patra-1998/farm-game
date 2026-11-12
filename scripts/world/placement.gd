class_name Placement
extends RefCounted
## Putting things on the farm: a new purchase, something carried back out of the barn, or a thing lifted to be
## moved. Holds what is in hand (`state`: item, uid, row, col, the homes that would take it, the home under the
## finger) and turns presses and drags into "where it would go" and, on letting go, into the move itself.
## The FarmGrid owns one (`grid.placement`) and draws the ghost from `state`.

var grid: FarmGrid
var state := {}   # {"item": id, "uid": -1 (a purchase) or the uid being moved, "stored": barn index, "row", "col",
				  #  "homes": {home uid: fit}, "home": the home under the finger or -1}


func _init(owner: FarmGrid) -> void:
	grid = owner


func start(item_id: String, uid := -1) -> void:
	state = {"item": item_id, "uid": uid, "row": -1, "col": -1}
	if uid != -1:
		var o := Game.object_by_uid(uid)
		state["row"] = int(o["row"])
		state["col"] = int(o["col"])
	var hint := tr("DRAG_TO_MOVE_THE_THEN_LET") if uid != -1 else tr("DRAG_TO_PLACE_THE_THEN_LET")
	refresh_homes()
	grid.placing_changed.emit(hint % Game.item_data(item_id)["name"])
	grid.queue_redraw()




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


## Under the finger, a home that takes what's being placed? Remembers it and says what a drop would do.
func _hover_home(tile: Vector2i) -> void:
	var home := -1
	var homes: Dictionary = state.get("homes", {})
	if tile.x >= 0 and tile.x < Game.farm_size and tile.y >= 0 and tile.y < Game.farm_size:
		var b := Game.object_at(Game.index_of(tile.x, tile.y))
		if not b.is_empty() and homes.has(int(b["uid"])):
			home = int(b["uid"])
	if home == int(state.get("home", -1)):
		return
	state["home"] = home
	var thing := str(Game.item_data(state["item"])["name"])
	if home == -1:
		grid.placing_changed.emit((tr("DRAG_TO_MOVE_THE_THEN_LET") if int(state["uid"]) != -1
			else tr("DRAG_TO_PLACE_THE_THEN_LET")) % thing)
		return
	var b := Game.object_by_uid(home)
	var why: HousingSystem.Fit = homes[home]
	grid.placing_changed.emit(tr("DROP_TO_MOVE_INTO") % [thing, Game.item_data(b["id"])["name"]]
		if why == HousingSystem.Fit.FITS else Game.homes.refusal(b, state["item"], why))


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
	if int(state.get("home", -1)) != -1:
		# Dropped on a home: in it goes (or a message says why not, and it stays in hand).
		var home := Game.object_by_uid(int(state["home"]))
		var source := _source()
		if Game.homes.put_in_home(int(state["home"]), state["item"], source):
			grid._feel("place", FarmGrid.BUZZ_PLACE)
			if source.has("buy"):
				var hfp := Game.footprint(home["id"])
				grid._float(grid.corners_of(int(home["row"]), int(home["col"]), hfp.x, hfp.y)[2],
					"-%d" % int(Game.item_data(state["item"])["cost"]), FarmGrid.COLOR_COST)
			cancel()
		return
	var row := int(state["row"])
	var col := int(state["col"])
	var uid := int(state["uid"])
	if not Game.can_place(state["item"], row, col, uid):
		grid._feel("error", FarmGrid.BUZZ_ERROR)
		grid.info.emit(tr("IT_DOESN_T_FIT_THERE_TRY"))
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
			grid._feel("place", FarmGrid.BUZZ_PLACE)
		if uid == -1 and from_storage < 0:
			grid._float(
				grid.corners_of(row, col, fp.x, fp.y)[2],
				"-%d" % int(Game.item_data(state["item"])["cost"]),
				FarmGrid.COLOR_COST
			)
		cancel()
