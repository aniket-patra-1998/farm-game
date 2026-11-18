class_name DataFile
extends RefCounted
## Every data file (data/*.json, a catalog file, a sprite sheet's list) is read through here: one rule for a file
## that is missing or broken. It says so in the log and hands back an empty Dictionary, so the caller's own
## defaults take over instead of each module deciding (or forgetting) on its own.


## The file's top-level object; {} (and an error in the log) when it is missing or not a JSON object.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error(path + " is missing")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error(path + " is not a valid JSON object")
		return {}
	return parsed


## The same for a file that may rightly be absent (an optional catalog or sprite list): {} with no error.
static func read_optional(path: String) -> Dictionary:
	return read(path) if FileAccess.file_exists(path) else {}
