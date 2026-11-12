extends TestSuite
## The game's numbers live in data/balance.json: every key the code asks for is there, every number there is
## used, and the weather's odds come out as written, in steady spells rather than coin flips.

const SOURCE_DIRS := ["res://autoload", "res://scripts", "res://tools"]
const CALL := "Balance\\.[fiad]\\(\"([a-z_0-9.]+)\"\\)"


func _sources(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_sources(dir.path_join(d), out)


func test_153_every_number_the_code_asks_for_is_in_the_data_and_every_number_is_used() -> void:
	var rx := RegEx.create_from_string(CALL)
	var used := {}
	var files: Array = []
	for d in SOURCE_DIRS:
		_sources(d, files)
	for path: String in files:
		for m in rx.search_all(FileAccess.get_file_as_string(path)):
			used[m.get_string(1)] = path
	for key: String in used:
		_check(Balance.has(key), "%s (asked for in %s) is in balance.json" % [key, used[key]])
	var idle: Array = []
	for key: String in Balance.keys():
		if not used.has(key):
			idle.append(key)
	_eq(idle, [], "every number in balance.json is used by something")
	for key: String in Balance.keys():
		_check(Balance.note(key) != "" or key.begins_with("weather."), "%s says what it is" % key)


func test_154_weather_comes_out_as_the_odds_and_lasts_in_spells() -> void:
	var t0 := 1_800_000_000 - 1_800_000_000 % Weather.block()
	var odds: Dictionary = Balance.d("weather.odds")["Summer"]
	var total := 0.0
	for s: String in odds:
		total += float(odds[s])
	var blocks := 20000
	var count := {}
	var runs := 0
	var last := ""
	for b in blocks:
		var hour := fposmod(12.0 + b * 3.0, 24.0)
		var s := Weather.state_at(t0 + b * Weather.block(), "Summer", hour)
		count[s] = int(count.get(s, 0)) + 1
		if s != last:
			runs += 1
		last = s
	for s: String in ["clear", "partly_cloudy", "cloudy", "rain", "storm"]:
		var want := float(odds[s]) / total
		var got := float(count.get(s, 0)) / blocks
		_check(
			absf(got - want) < 0.05 + want * 0.25,
			"%s is out %.1f%% of the time (odds say %.1f%%)" % [s, got * 100.0, want * 100.0]
		)
	var spell := float(blocks) / runs
	_check(spell > 2.0, "weather lasts in spells of %.1f blocks on average, not one at a time" % spell)
	# It drifts: from fair to foul through the grades, not straight from sun to storm.
	var jumps := 0
	var prev := Weather.state_at(t0, "Summer", 12.0)
	for b in range(1, 4000):
		var s := Weather.state_at(t0 + b * Weather.block(), "Summer", fposmod(12.0 + b * 3.0, 24.0))
		if (prev == "clear" and s == "storm") or (prev == "storm" and s == "clear"):
			jumps += 1
		prev = s
	_eq(jumps, 0, "it never goes straight from clear to storm or back")
