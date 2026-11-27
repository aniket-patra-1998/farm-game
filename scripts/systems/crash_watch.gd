class_name CrashWatch
extends RefCounted
## Knowing when the game died (docs/CRASHES.md), the usual way for a game without a crash service of its own: a
## flag file is written while the game is in front and removed whenever it goes away properly (paused, closed),
## so a flag found at start means the last session ended in a crash (or was killed while in front). Godot keeps
## its log on the phone too (project setting debug/file_logging, rotated: the last run's log is kept beside the
## new one), so the end of the crashed run's log is kept as last_crash.txt, counted, and sent as one error event
## (Analytics, when its keys are in). Settings > About copies it to paste to the developer (`report`). Play
## Console's Android vitals adds native crashes and freezes for installs from Play, with no code of ours.

const FLAG := "user://running.flag"
const LOGS := "user://logs"
const LIVE_LOG := "godot.log"
const KEPT := "user://logs/last_crash.txt"
const TAIL_LINES := 80        # the end of the crashed run's log that is kept
const SECTION := "crash"      # PlayerSettings: {count, last (unix time)}

static var crashed_last := false   # this start found the flag: the last session crashed


## At start: what the last session left, then the flag for this one.
static func begin() -> void:
	crashed_last = FileAccess.file_exists(FLAG)
	if crashed_last:
		var tail := last_log_tail()
		var f := FileAccess.open(KEPT, FileAccess.WRITE)
		if f != null:
			f.store_string(tail)
		var n := int(PlayerSettings.value(SECTION, "count", 0)) + 1
		PlayerSettings.keep(SECTION, {"count": n, "last": int(Time.get_unix_time_from_system())})
		push_warning("CrashWatch: the last session ended in a crash (%d so far)" % n)
		if Analytics.shared != null:
			Analytics.shared.crash(tail)
	in_front()


## The game is in front (started, or back from the background): the flag is up.
static func in_front() -> void:
	var f := FileAccess.open(FLAG, FileAccess.WRITE)
	if f != null:
		f.store_string(str(Time.get_unix_time_from_system()))


## The game went away properly (paused, closed): no crash if it is not back.
static func away() -> void:
	if FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(FLAG)


## The end of the last run's log (the newest kept log that is not this run's), "" when there is none.
static func last_log_tail() -> String:
	var dir := DirAccess.open(LOGS)
	if dir == null:
		return ""
	var newest := ""
	for name in dir.get_files():
		if name.ends_with(".log") and name != LIVE_LOG and name > newest:   # (names carry their date and time)
			newest = name
	return tail_of(LOGS.path_join(newest), TAIL_LINES) if newest != "" else ""


static func tail_of(path: String, lines: int) -> String:
	var text := FileAccess.get_file_as_string(path)
	var all := text.split("\n")
	return "\n".join(all.slice(maxi(0, all.size() - lines)))


## What Settings copies: how many crashes, the last crash's log, and the end of this run's log.
static func report() -> String:
	var parts: PackedStringArray = []
	parts.append("Barnlight %s, %s, crashes: %d" % [ProjectSettings.get_setting("application/config/version", ""),   # not-ui (a report)
		OS.get_model_name(), int(PlayerSettings.value(SECTION, "count", 0))])
	if FileAccess.file_exists(KEPT):
		parts.append("--- last crash ---\n" + FileAccess.get_file_as_string(KEPT))   # not-ui (a report)
	parts.append("--- this run ---\n" + tail_of(LOGS.path_join(LIVE_LOG), TAIL_LINES))   # not-ui (a report)
	return "\n".join(parts)
