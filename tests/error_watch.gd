class_name ErrorWatch
extends Logger
## Listens to the engine's error log while the tests run. A script error inside a test (a bad type, a call on
## null, a missing member) stops that test where it stands, and the runner would still count it as passed;
## this makes it a failure that names the error. Warnings and the engine's own errors are not counted.

var _mutex := Mutex.new()
var _errors: Array[String] = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	_mutex.lock()
	_errors.append("%s (%s:%d in %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
	_mutex.unlock()


## The script errors since the last call, which are cleared.
func take() -> Array[String]:
	_mutex.lock()
	var out := _errors.duplicate()
	_errors.clear()
	_mutex.unlock()
	return out
