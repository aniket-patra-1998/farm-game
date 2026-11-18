extends TestSuite
## The one event stream (Game.record, data/events.json; docs/PLAYER_EXPERIENCE.md Part 1): everything done on the
## farm is told as `did(verb, subject, n)` and keeps the ribbon counters; every verb the code records is in the
## data, every verb in the data is recorded somewhere, and every ribbon's counter is fed by a verb.

const CODE_DIRS := ["res://autoload", "res://scripts"]


func _code_files(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_code_files(dir.path_join(d), out)


## Every verb a `record("verb"` call names in the game's code.
func _recorded_verbs() -> Dictionary:
	var files: Array[String] = []
	for d: String in CODE_DIRS:
		_code_files(d, files)
	var re := RegEx.create_from_string("record\\(\"([a-z_]+)\"")
	var verbs := {}
	for f in files:
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			verbs[m.get_string(1)] = f
	return verbs


func test_454_every_recorded_verb_is_in_the_data_and_every_verb_is_recorded() -> void:
	var g := _farm()
	var data: Dictionary = g.ribbons.event_verbs
	var code := _recorded_verbs()
	_check(not data.is_empty(), "data/events.json has verbs")
	for v: String in code:
		_check(data.has(v), "the code records '%s' (%s), which data/events.json declares" % [v, code[v]])
	for v: String in data:
		_check(code.has(v), "data/events.json's '%s' is recorded somewhere in the code" % v)
	_done(g)


func test_455_every_ribbon_counter_is_fed_by_an_event_and_nothing_bumps_ribbons_directly() -> void:
	var g := _farm()
	var fed := {}
	for v: String in g.ribbons.event_verbs:
		for rule: Dictionary in g.ribbons.event_verbs[v]:
			fed[str(rule["stat"])] = true
	for r: Dictionary in g.ribbons.ribbon_data["ribbons"]:
		_check(fed.has(str(r["stat"])), "ribbon %s's counter '%s' is fed by an event" % [r["id"], r["stat"]])
	var files: Array[String] = []
	for d: String in CODE_DIRS:
		_code_files(d, files)
	for f in files:
		_check(not FileAccess.get_file_as_string(f).contains("ribbons.bump("),
			"%s records events (Game.record) instead of bumping ribbon counters" % f)
	_done(g)


func test_456_an_event_is_told_with_what_it_was_done_to_and_counts_for_its_ribbon() -> void:
	var g := _farm()
	var heard: Array = []
	g.did.connect(func(verb: String, subject: String, n: int) -> void: heard.append([verb, subject, n]))
	var i := _free(g)
	_grow_and_harvest(g, i, "strawberries")
	_check(heard.has(["plow", "", 1]), "plowing is told")
	_check(heard.has(["plant", "strawberries", 1]), "planting is told with the crop")
	_check(heard.has(["harvest", "strawberries", 1]), "the harvest is told with the crop")
	_eq(g.ribbons.stat("harvests"), 1, "the harvest still counts for its ribbon")
	_eq(g.ribbons.stat("plowed"), 1, "the plowing still counts for its ribbon")
	_check(g.ribbons.stat("coins_earned") > 0, "the harvest's coins count as earned")
	heard.clear()
	g.record("harvest", "strawberries", 0)
	_eq(heard.size(), 0, "nothing done is not an event")
	_done(g)


func test_457_one_verb_picks_its_ribbon_by_the_kind_of_thing() -> void:
	var g := _farm()
	var decor := ""
	for id: String in g.items:
		if str(g.items[id].get("kind", "")) == "decor":
			decor = id
			break
	_eq(g.ribbons.stat_of("buy", decor), "decor_bought", "buying a decoration counts for the Decorator")
	_eq(g.ribbons.stat_of("buy", "chicken_coop"), "", "buying a building counts for no ribbon")
	_eq(g.ribbons.stat_of("upgrade", "tractor"), "vehicle_upgrades", "a vehicle's upgrade counts as a vehicle's")
	_eq(g.ribbons.stat_of("upgrade", "chicken_coop"), "upgrades", "a building's upgrade counts as a building's")
	_eq(g.ribbons.stat_of("plant", "strawberries"), "", "planting is told but counts for no ribbon")
	_done(g)
