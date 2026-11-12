extends TestSuite
## The game's polish is data (data/feedback.json): every moment the code asks for exists, plays a real sound and a
## sane vibration, and every floating-text style it uses has a colour.

const SCAN_DIRS := ["res://scripts", "res://autoload"]


func test_204_every_moment_and_float_style_the_game_asks_for_exists() -> void:
	var moments := RegEx.create_from_string("Feedback\\.moment\\(\"([a-z_]+)\"")
	var either := RegEx.create_from_string("Feedback\\.moment\\([^\\n]*?\"([a-z_]+)\" if [^\\n]*? else \"([a-z_]+)\"")
	var styles := RegEx.create_from_string("Feedback\\.color\\(\"([a-z_]+)\"")
	var floats := RegEx.create_from_string("_float\\([^\\n]*?, \"([a-z]+)\"[,)]")
	var asked := {}
	var styled := {}
	for dir in SCAN_DIRS:
		for path in _scripts_in(dir):
			var text := FileAccess.get_file_as_string(path)
			for m in moments.search_all(text):
				asked[m.get_string(1)] = path
			for m in either.search_all(text):
				asked[m.get_string(1)] = path
				asked[m.get_string(2)] = path
			for m in styles.search_all(text) + floats.search_all(text):
				styled[m.get_string(1)] = path
	_check(asked.size() >= 12, "the game asks for its moments by name (%d found)" % asked.size())
	for name: String in asked:
		_check(Feedback.has_moment(name), "%s (asked for in %s) is in feedback.json" % [name, asked[name]])
	_check(styled.size() >= 5, "the game asks for its float colours by name (%d found)" % styled.size())
	for style: String in styled:
		_check(Feedback.has_float(style), "float style %s (asked for in %s) is in feedback.json" % [style, styled[style]])


func test_205_every_moment_has_a_real_sound_and_a_gentle_buzz() -> void:
	var moments := Feedback.moments()
	_check(moments.size() >= 12, "there are moments (%d)" % moments.size())
	for name: String in moments:
		var m: Dictionary = moments[name]
		_check(m.has("sound") or m.has("buzz"), "%s does something" % name)
		if m.has("sound"):
			_check(Sound.has_sound(str(m["sound"])), "%s: its sound %s exists" % [name, m["sound"]])
		_check(int(m.get("buzz", 0)) <= 100, "%s: its buzz is brief (%d ms)" % [name, int(m.get("buzz", 0))])
		_check(float(m.get("gain_db", 0.0)) <= 6.0, "%s is not louder than the rest" % name)
	for style: String in Feedback.floats():
		_check(Feedback.color(style) != Color.WHITE, "float style %s has a colour of its own" % style)


func _scripts_in(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_in(dir + "/" + d))
	return out
