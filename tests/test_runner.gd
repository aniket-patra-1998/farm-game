extends Node
## Runs every rule test: each file in tests/suites/ is a TestSuite, and each of its test_ methods a test.
##
## In Godot: open tests/run_tests.tscn and press F6 (Run Current Scene). Results print in the Output panel.
## From a terminal or CI: godot --headless --path . res://tests/run_tests.tscn   (exit code 1 if anything fails)
##
## Every test builds its own throwaway farm with saving turned off, so your real save is never touched.
## A test that needs real frames (input, rendering) is a coroutine; the runner waits for it to finish.

const SUITES_DIR := "res://tests/suites"


func _ready() -> void:
	var tests := 0
	var checks := 0
	var failed := 0
	var failures: Array[String] = []
	var only := ""   # `-- --only=saving` runs just the suites whose file name contains it
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	for path in suite_paths():
		if only != "" and not _wanted(path, only):
			continue
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			failed += 1   # a suite that does not even parse is a failure, not a silent hang
			failures.append("%s: the suite could not be loaded" % path.get_file())
			print("FAIL  %s could not be loaded" % path.get_file())
			continue
		var suite := script.new() as TestSuite
		suite.name = path.get_file().get_basename()
		add_child(suite)
		for n in test_names(suite):
			suite.current = n
			var before := suite.failures.size()
			await suite.call(n)
			var ok := suite.failures.size() == before
			tests += 1
			if not ok:
				failed += 1
			print("%s  %s/%s" % ["PASS" if ok else "FAIL", suite.name, n])
		checks += suite.checks
		failures.append_array(suite.failures)
		suite.queue_free()
	print("")
	for f in failures:
		print("  - " + f)
	print("%d tests, %d checks, %d failed" % [tests, checks, failed])
	Instancer.clear()   # the shared looks are held in statics: let them go before the engine reports leaks
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if failed > 0 else 0)


## Every suite file, in name order.
## Whether a suite file is named by `--only` (a few names, separated by commas, each part of a file name).
static func _wanted(path: String, only: String) -> bool:
	for part in only.split(","):
		if part != "" and path.contains(part):
			return true
	return false


static func suite_paths() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(SUITES_DIR):
		if f.ends_with("_test.gd"):
			out.append(SUITES_DIR + "/" + f)
	out.sort()
	return out


static func test_names(suite: Object) -> Array[String]:
	var names: Array[String] = []
	for m in suite.get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_"):
			names.append(n)
	names.sort()
	return names
