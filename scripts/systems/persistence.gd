class_name Persistence
extends GameSystem
## Saving and loading the farm: when a save is due, the snapshot, the safe write (temporary file, backup, then
## the real one, on a thread when queued), reading the newest good file, and putting a save back into the game.
## The fields it handles are the shared core's; each other system saves its own through save_to/load_from.

## Moments a placed object keeps besides its "t" (a pig pen's forage, a perfect bunch's end); crafting slots'
## "done" too. Each moves with the clock when a device clock was set back (see shift_all).
const OBJECT_MOMENTS: Array[String] = ["forage_until", "expires"]
const UNUSABLE_SUFFIX := ".unusable"   # a save this game could not load, kept beside the new farm's
const CLOCK_SLACK := 2       # seconds the device clock may step back (a network time correction) unnoticed

var due_msec := -1           # when a queued save is written (-1: nothing waiting)
var _seen := 0               # the latest moment the running game has seen (0: not yet), for watch_clock
var _thread: Thread           # a queued save being turned into text and written off the main thread


## A change to save soon: changes within SAVE_DELAY_MSEC of each other are written once (the whole farm is
## serialised each time, and a phone feels that). Pausing or closing the app saves at once.
func queue() -> void:
	if due_msec < 0:
		due_msec = Time.get_ticks_msec() + GameState.SAVE_DELAY_MSEC


## Writes a queued save that has come due (called every frame by the game).
func tick() -> void:
	watch_clock()
	if due_msec >= 0 and Time.get_ticks_msec() >= due_msec:
		save(true)


## `in_background`: the farm is copied (a few ms) and the copy is turned into text and written on a thread,
## so a queued save doesn't stall a frame. Anything else (pausing, closing, tests) writes before it returns.
func save(in_background := false) -> void:
	due_msec = -1
	if not game.saving_enabled:
		return
	finish()
	var data := snapshot()
	if not in_background:
		_write_safely(JSON.stringify(data), game.save_path)
		return
	var copy: Dictionary = data.duplicate(true)  # the game goes on changing `data`'s parts; the thread keeps this
	_thread = Thread.new()
	_thread.start(Persistence._write_snapshot.bind(copy, game.save_path))


## Everything a save holds, as it is now (its parts are the game's own, not copies).
func snapshot() -> Dictionary:
	var data := {
		"version": GameState.SAVE_VERSION,
		"saved_at": game.now(),
		"coins": game.coins,
		"gems": game.gems,
		"xp": game.xp,
		"plots": game.plots,
		"debug_time_offset": game.debug_time_offset,
		"skipped": game.skipped,
		"tutorial_step": game.tutorial_step,
		"objects": game.objects,
		"farm_size": game.farm_size,
		"clear_until": game.clear_until,
		"unwithers": game.unwithers,
		"rescued": game.rescued,
		"born_day": game.born_day,
		"helped_day": game.helped_day,
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
	return data


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


## Written so a crash or a full disk can't lose the farm: the new save goes to a temporary file first and is
## checked whole, the last good save is kept as a backup, and only then does the new one take its place. Every
## step's result is checked: whatever fails, the last good save stays where `read` finds it (the save, or
## else its backup), and the failure is reported. Returns OK or the first error.
static func _write_safely(text: String, path: String) -> Error:
	var tmp := path + GameState.TEMP_SUFFIX
	var backup := path + GameState.BACKUP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return FileAccess.get_open_error()
	f.store_string(text)
	var written := f.get_length()
	var err := f.get_error()
	f.close()
	if err != OK or written != text.to_utf8_buffer().size():   # a full disk writes part of it
		push_warning("Save file was not written whole; the last save is kept")
		DirAccess.remove_absolute(tmp)
		return err if err != OK else ERR_FILE_CANT_WRITE
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)   # (some systems will not rename onto a file)
		err = DirAccess.rename_absolute(path, backup)
		if err != OK:
			push_warning("Could not keep the last save as a backup; it stays as the save")
			DirAccess.remove_absolute(tmp)
			return err
	err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("Could not put the new save in place; the last save is kept as the backup")
		return err
	return OK


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
	var saved_version: Variant = SaveCheck.whole(data.get("version", 0))
	var version := 0 if saved_version == null else int(saved_version)
	data["version"] = version
	if version > GameState.SAVE_VERSION:
		# From a newer game (the app was rolled back): the new farm that follows must not overwrite it.
		DirAccess.copy_absolute(game.save_path, "%s.v%d" % [game.save_path, version])
		return false
	if not SaveMigrations.upgrade(data):
		_keep_aside()
		return false
	# A field of the wrong kind (a hand-edited or damaged save: a word or nothing where a number goes) would stop the
	# load halfway, and a new farm would start and be saved over this one: it takes its default instead.
	var mended := SaveCheck.match_shape(data, snapshot())
	mended += SaveCheck.clean(data, game.items, GameState.MAX_SIZE, {"state": "grass"})
	if mended > 0:
		push_warning("Save: %d damaged entries were dropped or mended" % mended)
	var saved_plots: Array = data.get("plots", [])
	if saved_plots.size() != GameState.MAX_SIZE * GameState.MAX_SIZE:
		_keep_aside()
		return false
	game.farm_size = clampi(int(data.get("farm_size", GameState.START_SIZE)), GameState.START_SIZE,
		GameState.MAX_SIZE)
	game.clear_until = int(data.get("clear_until", 0))
	game.unwithers = int(data.get("unwithers", Balance.i("economy.start_unwithers")))
	game.rescued = bool(data.get("rescued", false))
	# (a farm saved before 19 Nov is taken as grown: no young-farm help for it)
	game.born_day = int(data.get("born_day", game.day_number() - Balance.i("economy.young_farm_days")))
	game.helped_day = int(data.get("helped_day", -1))
	game.fertilize_alls = int(data.get("fertilize_alls", 0))
	var saved_parts := GameSystem.int_map(data.get("parts", {}))
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
	# Before 19 Nov the farm's whole clock moved with Skip 1 hour (the only thing a player could add to the offset):
	# an older save's offset is all skips, so its sky comes back to the real time at once.
	game.skipped = int(data.get("skipped", game.debug_time_offset)) if OS.is_debug_build() else 0
	# Saves from before the tutorial existed belong to players who already know the basics.
	game.tutorial_step = int(data.get("tutorial_step", GameState.Tutorial.DONE))
	# A device clock set back since the save would leave every timer in the future: all of them wait the
	# difference on top of their cycle. Shifting them back by it keeps each one's progress.
	var skew := maxi(0, int(data.get("saved_at", game.now())) - game.now())
	for system in game.systems:
		system.load_from(data)
	game.set_objects([])
	for o in data.get("objects", []):
		var obj: Dictionary = o
		if not game.items.has(obj.get("id", "")):
			continue # item removed from the data file
		game.add_object(obj)   # (SaveCheck has already made uid, row, col, t and level whole numbers.)
	game.next_uid = int(data.get("next_uid", 1))
	game.absence_note = game.bees.apply_absence(maxi(0, game.now() - int(data.get("saved_at", game.now()))))
	game.plots.clear()
	for p in saved_plots:
		var plot: Dictionary = p
		# Drop plots whose crop no longer exists in the data file.
		if plot.get("state") == "planted" and not game.crops.has(plot.get("crop", "")):
			plot = {"state": "plowed"}
		game.plots.append(plot)
	shift_all(skew)
	_seen = game.now()
	game.absence_items = AbsenceReport.items(game, int(data.get("saved_at", game.now())) - skew, game.now())
	var away := AbsenceReport.line(game.absence_items)
	game.absence_head = away
	if away != "":
		game.absence_note = away if game.absence_note == "" else away + "\n" + game.absence_note
	var extra_vehicles := game.buildings.trim_extra_vehicles()
	if extra_vehicles > 0:
		var vnote := game.tr("EXTRA_VEHICLES_SOLD_BACK") % extra_vehicles
		game.absence_note = vnote if game.absence_note == "" else game.absence_note + "\n" + vnote
	if not game.in_showcase() and game.restore_mailbox():
		var mnote := game.tr("MAILBOX_BACK")
		game.absence_note = mnote if game.absence_note == "" else game.absence_note + "\n" + mnote
	var spilled := game.storage.spill_over()
	if spilled > 0:
		var snote := game.tr("BARN_OVERFLOW_TO_INBOX") % spilled
		game.absence_note = snote if game.absence_note == "" else game.absence_note + "\n" + snote
	var moved := game.settle_objects()
	if moved > 0:
		var note := game.tr("SOME_BUILDINGS_CHANGED_SHAPE_AND") % moved
		game.absence_note = note if game.absence_note == "" else game.absence_note + "\n" + note
	return true


## A save this game cannot use (too old, or its grid is damaged): a copy is kept beside it, since the new farm that
## follows is saved over it.
func _keep_aside() -> void:
	push_warning("Save: unusable, kept as %s%s" % [game.save_path, UNUSABLE_SUFFIX])
	DirAccess.copy_absolute(game.save_path, game.save_path + UNUSABLE_SUFFIX)


## The device clock was set back `skew` seconds (since the save, or while the game ran or waited in the
## background): every timer would wait the difference on top of its cycle, so each moves back by it and keeps
## its progress: the systems' own, the weather's clear spell, every placed thing's moments and growing crops.
func shift_all(skew: int) -> void:
	if skew <= 0:
		return
	for system in game.systems:
		system.shift_clock(skew)
	if game.clear_until > 0:
		game.clear_until -= skew
	game.born_day = game.day_moved_back(game.born_day, skew)   # (a farm's age, for its first-week help and wear)
	game.helped_day = game.day_moved_back(game.helped_day, skew)
	for o: Dictionary in game.objects:
		for key: String in ["t"] + OBJECT_MOMENTS:
			if o.has(key):
				o[key] = int(o[key]) - skew
		for slot: Variant in o.get("slots", []):
			if typeof(slot) == TYPE_DICTIONARY and (slot as Dictionary).has("done"):
				slot["done"] = int(slot["done"]) - skew
	for plot: Dictionary in game.plots:
		if plot.get("state") == "planted":
			plot["planted_at"] = int(plot.get("planted_at", 0)) - skew


## Called every frame: a phone's clock set back while the game runs or waits in the background (it resumes
## without loading) shifts every timer as loading does, so nothing waits the difference on top. Returns the shift.
## Forgets the latest time seen, so the next watch_clock takes the clock as it is (a new farm made on another
## date: the play bot's runs).
func forget_clock() -> void:
	_seen = 0


func watch_clock() -> int:
	var t := game.now()
	var skew := _seen - t if _seen > 0 and t < _seen - CLOCK_SLACK else 0
	if skew > 0:
		shift_all(skew)
		game.objects_updated()
		game.queue_save()
	_seen = maxi(_seen, t) if skew == 0 else t
	return skew
