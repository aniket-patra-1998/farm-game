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


func test_512_every_weighted_pick_shares_one_rule() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 512
	_check(RollSystem.weighted_index(rng, []) == -1, "nothing to pick from: none")
	_check(RollSystem.weighted_index(rng, [0, 0.0, -3]) == -1, "only empty weights: none")
	var hits := [0, 0, 0, 0]
	for n in 4000:
		hits[RollSystem.weighted_index(rng, [0, 1, 3, -2])] += 1
	_check(hits[0] == 0 and hits[3] == 0, "a weight of 0 or less is never picked: %s" % [hits])
	_check(hits[2] > hits[1] * 2 and hits[2] < hits[1] * 4, "picks follow their weights (1:3): %s" % [hits])
	var own := RegEx.create_from_string("randi_range\\(1, |randf\\(\\) \\* ")
	for dir: String in [SYSTEMS, "res://scripts/social"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") and f != "roll_system.gd":
				_check(own.search(FileAccess.get_file_as_string(dir.path_join(f))) == null,
					"%s picks by weight through RollSystem.weighted_index" % f)


func test_580_rewards_that_could_run_away_are_capped() -> void:
	# Owner, 19 Nov ("caps in many aspects"): building parts at most 5 a day, young from a pen 1 a day of each kind,
	# mystery babies 2 a day, the stable's 100 XP and the hive's fertilize-all once a day, a vehicle's coins 10 a
	# day, the stable's farmhand and arborist one each a week. A sure roll stops at its cap, the next day (or week)
	# it comes up again, and the count is saved.
	var g := _farm()
	var want := {"daily_part": 5, "lamb": 1, "piglet": 1, "calf": 1, "foal": 1, "mystery_baby": 2, "stable_xp": 1,
		"fertilize_all": 1, "tractor_coins": 10, "stable_farmhand": 1, "stable_arborist": 1}
	for id: String in want:
		var came := 0
		for k in 30:
			if g.rolls.roll(id, 1.0):
				came += 1
		_eq(came, int(want[id]), "%s: at most %d" % [id, want[id]])
	var data := {}
	g.rolls.save_to(data)
	var h := _farm()
	h.rolls.load_from(JSON.parse_string(JSON.stringify(data)))
	_eq(h.rolls.taken("daily_part"), Vector2i(5, 5), "the day's count is saved")
	_skip(g, 86400)
	_check(g.rolls.roll("daily_part", 1.0), "a new day: parts again")
	_check(not g.rolls.roll("stable_farmhand", 1.0) or g.rolls.taken("stable_farmhand").x == 1,
		"the farmhand counts by the week")
	_skip(g, 7 * 86400)
	_check(g.rolls.roll("stable_farmhand", 1.0), "a new week: a farmhand again")
	_check(g.rolls.roll("golden_harvest", 1.0) if g.rolls.ids().has("golden_harvest") else true,
		"an uncapped roll is never stopped")
	_done(g)
	_done(h)
