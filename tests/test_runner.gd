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
	for path in suite_paths():
		var suite := (load(path) as GDScript).new() as TestSuite
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
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if failed > 0 else 0)


## Every suite file, in name order.
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
