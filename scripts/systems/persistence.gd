class_name Persistence
extends GameSystem
## Saving and loading the farm: when a save is due, the snapshot, the safe write (temporary file, backup, then
## the real one, on a thread when queued), reading the newest good file, and putting a save back into the game.
## The fields it handles are the shared core's; each other system saves its own through save_to/load_from.

var due_msec := -1            # when a queued save is written (-1: nothing waiting)
var _thread: Thread           # a queued save being turned into text and written off the main thread


## A change to save soon: changes within SAVE_DELAY_MSEC of each other are written once (the whole farm is
## serialised each time, and a phone feels that). Pausing or closing the app saves at once.
func queue() -> void:
	if due_msec < 0:
		due_msec = Time.get_ticks_msec() + GameState.SAVE_DELAY_MSEC


## Writes a queued save that has come due (called every frame by the game).
func tick() -> void:
	if due_msec >= 0 and Time.get_ticks_msec() >= due_msec:
		save(true)


## `in_background`: the farm is copied (a few ms) and the copy is turned into text and written on a thread,
## so a queued save doesn't stall a frame. Anything else (pausing, closing, tests) writes before it returns.
func save(in_background := false) -> void:
	due_msec = -1
	if not game.saving_enabled:
		return
	finish()
	var data := {
		"version": GameState.SAVE_VERSION,
		"saved_at": game.now(),
		"coins": game.coins,
		"gems": game.gems,
		"xp": game.xp,
		"plots": game.plots,
		"debug_time_offset": game.debug_time_offset,
		"tutorial_step": game.tutorial_step,
		"objects": game.objects,
		"farm_size": game.farm_size,
		"clear_until": game.clear_until,
		"unwithers": game.unwithers,
		"fertilize_alls": game.fertilize_alls,
		"parts": game.parts,
		"farmhands": game.farmhands,
		"arborists": game.arborists,
		"gardeners": game.gardeners,
		"fertilizer_bags": game.fertilizer_bags,
		"next_uid": game.next_uid,
	}
	for system in game.systems:
		system.save_to(data)
	if not in_background:
		_write_safely(JSON.stringify(data), game.save_path)
		return
	var copy: Dictionary = data.duplicate(true)  # the game goes on changing `data`'s parts; the thread keeps this
	_thread = Thread.new()
	_thread.start(Persistence._write_snapshot.bind(copy, game.save_path))


## (On the save thread.) The copy as text, then safely onto disk. Static, so the running thread holds nothing that the
## game could free from under it (a reset builds new systems while an old save may still be writing).
static func _write_snapshot(copy: Dictionary, path: String) -> void:
	_write_safely(JSON.stringify(copy), path)


## Waits for a save still being written on its thread (before anything reads or replaces the file).
func finish() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


## True while a background save has not been waited for.
func is_writing() -> bool:
	return _thread != null


## Written so a crash or a full disk can't lose the farm: the new save goes to a temporary file first, the
## last good save is kept as a backup, and only then does the new one take its place.
static func _write_safely(text: String, path: String) -> void:
	var tmp := path + GameState.TEMP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(path, path + GameState.BACKUP_SUFFIX)
	DirAccess.rename_absolute(tmp, path)


## The saved farm as a dictionary: the save, or its backup if the save is missing or unreadable.
func read() -> Dictionary:
	finish()
	for path in [game.save_path, game.save_path + GameState.BACKUP_SUFFIX]:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var json := JSON.new()  # (parse() reports a damaged file quietly; parse_string logs an engine error)
		if json.parse(f.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
			return json.data
		push_warning("Save %s is unreadable" % path)
	return {}


## Puts the saved farm into the game. False if there is no usable save (a new game starts instead).
func load_save() -> bool:
	var data := read()
	if data.is_empty():
		return false
	var version := int(data.get("version", 0))
	if version > GameState.SAVE_VERSION:
		# From a newer game (the app was rolled back): the new farm that follows must not overwrite it.
		DirAccess.copy_absolute(game.save_path, "%s.v%d" % [game.save_path, version])
		return false
	if not SaveMigrations.upgrade(data):
		return false
	var mended := SaveCheck.clean(data, game.items, GameState.MAX_SIZE, {"state": "grass"})
	if mended > 0:
		push_warning("Save: %d damaged entries were dropped or mended" % mended)
	var saved_plots: Array = data.get("plots", [])
	if saved_plots.size() != GameState.MAX_SIZE * GameState.MAX_SIZE:
		return false
	game.farm_size = clampi(int(data.get("farm_size", GameState.START_SIZE)), GameState.START_SIZE,
		GameState.MAX_SIZE)
	game.clear_until = int(data.get("clear_until", 0))
	game.unwithers = int(data.get("unwithers", Balance.i("economy.start_unwithers")))
	game.fertilize_alls = int(data.get("fertilize_alls", 0))
	var saved_parts: Dictionary = data.get("parts", {})
	game.parts = {}
	for p in game.part_ids:
		game.parts[p] = int(saved_parts.get(p, 0))
	game.farmhands = int(data.get("farmhands", 0))
	game.arborists = int(data.get("arborists", 0))
	game.gardeners = int(data.get("gardeners", 0))
	game.fertilizer_bags = int(data.get("fertilizer_bags", 0))
	game.coins = int(data.get("coins", Balance.i("economy.start_coins")))
	game.gems = int(data.get("gems", Balance.i("economy.start_gems")))
	game.xp = int(data.get("xp", 0))
	game.debug_time_offset = int(data.get("debug_time_offset", 0)) if OS.is_debug_build() else 0
	# Saves from before the tutorial existed belong to players who already know the basics.
	game.tutorial_step = int(data.get("tutorial_step", GameState.Tutorial.DONE))
	for system in game.systems:
		system.load_from(data)
	game.set_objects([])
	# A device clock set back since the save would leave every timer in the future: all of them wait the
	# difference on top of their cycle. Shifting them back by it keeps each one's progress.
	var skew := maxi(0, int(data.get("saved_at", game.now())) - game.now())
	for o in data.get("objects", []):
		var obj: Dictionary = o
		if not game.items.has(obj.get("id", "")):
			continue # item removed from the data file
		obj["t"] = int(obj["t"]) - skew
		# (SaveCheck has already made uid, row, col, t and level whole numbers.)
		if obj.has("forage_until"):
			obj["forage_until"] = int(obj["forage_until"])
		game.add_object(obj)
	game.next_uid = int(data.get("next_uid", 1))
	game.absence_note = game.bees.apply_absence(maxi(0, game.now() - int(data.get("saved_at", game.now()))))
	game.plots.clear()
	for p in saved_plots:
		var plot: Dictionary = p
		if plot.get("state") == "planted":
			plot["planted_at"] = int(plot.get("planted_at", 0)) - skew
		# Drop plots whose crop no longer exists in the data file.
		if plot.get("state") == "planted" and not game.crops.has(plot.get("crop", "")):
			plot = {"state": "plowed"}
		game.plots.append(plot)
	var away := AbsenceReport.build(game, int(data.get("saved_at", game.now())) - skew, game.now())
	if away != "":
		game.absence_note = away if game.absence_note == "" else away + "\n" + game.absence_note
	var mail := game.social.settle()
	if mail != "":
		game.absence_note = mail if game.absence_note == "" else game.absence_note + "\n" + mail
	var extra_vehicles := game.buildings.trim_extra_vehicles()
	if extra_vehicles > 0:
		var vnote := game.tr("EXTRA_VEHICLES_SOLD_BACK") % extra_vehicles
		game.absence_note = vnote if game.absence_note == "" else game.absence_note + "\n" + vnote
	var moved := game.settle_objects()
	if moved > 0:
		var note := game.tr("SOME_BUILDINGS_CHANGED_SHAPE_AND") % moved
		game.absence_note = note if game.absence_note == "" else game.absence_note + "\n" + note
	return true
