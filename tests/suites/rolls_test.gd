extends TestSuite
## Every reward roll goes through one place (RollSystem, data/rolls.json): code and data name the same rolls, no
## rule rolls a chance of its own, and VIP raises exactly the rolls listed for it.

const SYSTEMS := "res://scripts/systems"
const ROLL_CALL := "rolls\\.roll\\(\"([a-z_]+)\""
const OWN_ROLL := "randf\\(\\) *[<>]"


func test_430_code_and_data_name_the_same_rolls() -> void:
	var g := _farm()
	var used := {}
	var call := RegEx.create_from_string(ROLL_CALL)
	var own := RegEx.create_from_string(OWN_ROLL)
	for f in DirAccess.get_files_at(SYSTEMS):
		if not f.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(SYSTEMS.path_join(f))
		for m in call.search_all(text):
			used[m.get_string(1)] = true
		_check(f == "roll_system.gd" or own.search(text) == null,
			"%s rolls no chance of its own: Game.rolls.roll(id, base)" % f)
	for id: String in used:
		_check(g.rolls.ids().has(id), "roll '%s' is listed in data/rolls.json" % id)
	for id: String in g.rolls.ids():
		_check(used.has(id), "listed roll '%s' is rolled somewhere" % id)
	_done(g)


func test_431_vip_raises_only_the_rolls_listed_for_it() -> void:
	var g := _farm()
	g.vip.reset()
	_check(is_equal_approx(g.rolls.odds("calf", 0.1), 0.1) and is_equal_approx(g.rolls.odds("golden", 0.1), 0.1),
		"without VIP every roll is as it is")
	g.vip.points = 18000   # (the top level)
	g.vip.until = g.now() + 86400
	_check(is_equal_approx(g.rolls.odds("calf", 0.1), 0.1 * Balance.f("vip.top_boost")),
		"a roll listed for VIP is multiplied by the top boost")
	_check(is_equal_approx(g.rolls.odds("golden", 0.1), 0.1), "one that isn't stays as it is")
	_check(is_equal_approx(g.rolls.odds("calf", 0.8), 1.0), "never more than certain")
	_done(g)
