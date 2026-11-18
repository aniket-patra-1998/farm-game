extends TestSuite
## The goals on screen (HudGoals; docs/PLAYER_EXPERIENCE.md Part 1): every task in the data has its words and a
## Show me that goes somewhere real; at most three faces show the first open goals, a ring for how far, a dot when
## done; the sheet's tabs hold each kind; Collect gives the reward once; Show me picks the tool or opens the shelf.

const GOALS_FIXTURE := preload("res://tests/suites/goals_test.gd")
const STATE_VERBS := ["level", "own"]


func _tasks_in(d: Dictionary) -> Array:
	var out: Array = []
	for c: Dictionary in d.get("chains", []):
		for s: Dictionary in c.get("steps", []):
			out.append_array(s.get("tasks", []))
	for p: Dictionary in d.get("projects", []):
		for s: Dictionary in p.get("stages", []):
			out.append_array(s.get("tasks", []))
	for t: Dictionary in (d.get("daily", {}) as Dictionary).get("templates", []):
		out.append(t)
	return out


func test_465_every_task_has_its_words_and_a_real_show_me() -> void:
	var d := DataFile.read(GoalSystem.DATA_PATH)
	var verbs: Dictionary = Game.ribbons.event_verbs
	var tasks := _tasks_in(d)
	tasks.append_array(_tasks_in(GOALS_FIXTURE.FIXTURE))
	for t: Dictionary in tasks:
		for key in HudGoals.keys_of(t):
			_check(tr(key) != key, "%s has its words (%s)" % [t, key])
	for verb: String in d.get("show", {}):
		_check(verbs.has(verb) or verb in STATE_VERBS, "show's %s is a verb of data/events.json" % verb)
		var how := str(d["show"][verb])
		var part := how.split(":")
		_check(part[0] in ["tool", "seeds", "market", "farm"], "show's %s goes somewhere known (%s)" % [verb, how])
		if part[0] == "tool":
			var tools := HudTools.TOOLS.map(func(e: Array) -> String: return str(e[0]))
			_check(part.size() > 1 and part[1] in tools, "show's %s names a tool (%s)" % [verb, how])
	for k in ["GOALS", "GOAL_COLLECT", "GOAL_SHOW_ME", "GOAL_SWAP", "GOALS_NONE_INFO", "GOALS_TODAY_BONUS"]:
		_check(tr(k) != k, "%s has its words" % k)
	for t: Array in HudGoals.TABS:
		_check(tr(str(t[1])) != str(t[1]), "the %s tab has its words" % t[0])
		_check(tr("GOALS_NONE_" + str(t[0]).to_upper()) != "GOALS_NONE_" + str(t[0]).to_upper(),
			"the %s tab says when it is empty" % t[0])
	_check(HudGoals.reward_words({"coins": 60, "xp": 10, "box": "mystery_box"}).contains("60"), "a reward in words")


func test_466_faces_show_the_first_three_and_collect_once() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	Game.tutorial_step = GameState.Tutorial.DONE
	var fixture: Dictionary = GOALS_FIXTURE.FIXTURE.duplicate(true)
	fixture["show"] = DataFile.read(GoalSystem.DATA_PATH).get("show", {})
	Game.goals.use_data(fixture)
	Game.goals.reset()
	Game.goals.refresh()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var faces := hud.goals.column
	var open := Game.goals.open_keys()
	_check(open.size() > HudGoals.FACES, "more goals open than faces (%d)" % open.size())
	_check(faces.get_child_count() == HudGoals.FACES, "three faces (%d)" % faces.get_child_count())
	_check(faces.get_child(0).name == "Face_" + open[0].replace(":", "_"), "the first face is the first goal")
	_check(faces.get_global_rect().position.y > hud.top.coins.get_global_rect().end.y, "the faces sit under the coins")
	# Done: a dot on its face, Collect in the sheet; collected once.
	var key := open[0]
	Game.record("harvest", GOALS_FIXTURE.SHOP_ID, 3)
	await get_tree().process_frame
	var face: HudGoals.GoalFace = faces.get_child(0)
	_check(face.done and is_equal_approx(face.share, 1.0), "a done goal's face is full, with its dot")
	hud.show_goals(HudGoals.tab_of(key))
	await get_tree().process_frame
	var collect := hud.book.find_child("Collect", true, false) as Button
	_check(collect != null, "a done goal can be collected in the sheet")
	var coins := Game.coins
	if collect != null:
		collect.pressed.emit()
	var got := Game.coins - coins
	_check(got >= 50, "Collect gives the reward (%d)" % got)
	hud.goals.collect(key)
	_check(Game.coins == coins + got, "..once")
	# Show me: the plow task of the next step puts the hoe in hand.
	var tasks := Game.goals.tasks_of(key)
	_check(str(tasks[0]["do"]) == "plow", "the chain moved on to its next step")
	var picked := []
	hud.tool_selected.connect(func(t: String, _c: String) -> void: picked.append(t))
	hud.goals.show_me(tasks[0])
	_check(picked == ["plow"], "Show me on Plow picks the hoe (%s)" % [picked])
	_check(HudGoals.show_of({"do": "level", "n": 3}).is_empty(), "a level task has no Show me")
	hud.goals.show_me({"do": "buy", "what": "cow"})
	await get_tree().process_frame
	_check(hud.book.visible, "Show me on Buy opens the Market")
	hud.book.close_panel()
	Game.modal_open = false
	# Every tab builds, and an empty one says so.
	hud.show_goals(0)
	await get_tree().process_frame
	var tabs: Array = hud.book.get("_tabs")
	_check(tabs.size() == HudGoals.TABS.size(), "the sheet has Story, Today and Projects")
	hud.book.close_panel()
	Game.modal_open = false
	main.queue_free()
	await get_tree().process_frame
	Game.goals.load_data()
	Game.goals.reset()
