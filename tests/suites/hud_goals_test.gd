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
	for k in ["GOALS", "GOAL_COLLECT", "GOAL_SWAP", "GOALS_NONE_INFO", "GOALS_TODAY_BONUS"]:
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
	_check(hud.book.is_open(), "Show me on Buy opens the Market")
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


func test_661_a_real_tap_on_each_goal_face_opens_its_card() -> void:
	# (28 Nov: a face opened its card on the press, and the rest of that tap shut it again: nothing seemed to happen.)
	Game.saving_enabled = false
	Game.reset_game()
	Game.xp = 5000
	Game.goals.refresh()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	for f: Control in hud.goals.column.get_children():
		var at: Vector2 = get_viewport().get_final_transform() * f.get_global_rect().get_center()
		for down: bool in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = down
			e.position = at
			Input.parse_input_event(e)
			await get_tree().process_frame
		await get_tree().create_timer(0.4).timeout
		_check(hud.book.visible, "a tap on %s opens its card and it stays open" % f.name)
		hud.book.close_panel()
		await get_tree().create_timer(0.4).timeout

func test_660_a_new_farm_is_named_once_by_its_first_screen() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	_check(not Game.player.introduced, "a brand-new farm has not had its first screen")
	var saved := {}
	Game.player.save_to(saved)
	saved.erase("introduced")
	Game.player.load_from(saved)
	_check(Game.player.introduced, "a farm saved before the first screen never gets it")
	Game.reset_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	await hud.intro.open_when_ready(main)
	_check(hud.book.visible, "it opens over the new farm")
	await get_tree().create_timer(HudGuide.WATCH_EVERY * 2.0).timeout
	_check(not hud.guide.strip.is_visible_in_tree() and hud.find_children("*", "GuideArrow", true, false).is_empty(),
		"Maple's strip and arrow wait behind it (owner, 28 Nov: the first second looked broken)")
	_check(Game.player.farm_name != "", "with a ready name (%s)" % Game.player.farm_name)
	var field := hud.book.find_child("FarmName", true, false) as LineEdit
	var go := hud.book.find_child("LetsGo", true, false) as Button
	_check(field != null and go != null, "a name to change and Let's go")
	var before := Game.player.farm_name
	_check(hud.intro.ready_name(before) != before, "Another gives another name")
	await get_tree().create_timer(0.4).timeout   # (open: then a real tap, press and release, on Let's go)
	var at: Vector2 = get_viewport().get_final_transform() * go.get_global_rect().get_center()
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		Input.parse_input_event(e)
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	_check(not hud.book.visible, "Let's go closes it")
	_check(Game.player.introduced, "Let's go: done for good")
	_check(hud.guide.strip.is_visible_in_tree(), "then the guide comes up")
	_check(Game.player.farm_name == before, "and the name kept")
	main.queue_free()
	await get_tree().process_frame


func test_664_a_find_with_no_home_yet_says_where_it_is_and_shows_in_collections() -> void:
	# (Owner, 28 Nov: a gopher found before the Gopher Garden was nowhere to be seen.)
	Game.saving_enabled = false
	Game.reset_game()
	var said := []
	var hear := func(m: String) -> void: said.append(m)
	Game.message.connect(hear)
	Game.finds.add("gopher", Game.finds.pick("gopher"))
	Game.message.disconnect(hear)
	_check(said.size() == 1 and str(said[0]).contains(str(Game.item_data("gopher_garden")["name"])),
		"the message names the home it waits for: %s" % [said])
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var face: Dictionary = hud.books.set_face(HudBooks.FINDS + "gopher")
	_eq(str(face["ring"][1]), "1/5", "Collections shows the gophers found, one kind of five")
	main.queue_free()
	await get_tree().process_frame


func test_666_show_me_always_shows_something() -> void:
	# (Owner, 28 Nov: the Tractor's "harvest" did nothing on a farm with nothing ripe.)
	Game.saving_enabled = false
	Game.reset_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	for i in 5:
		await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	for i in Game.farm_size * Game.farm_size:   # (nothing ripe or growing anywhere: a bare farm)
		if Game.on_farm(i) and Game.object_at(i).is_empty():
			Game.field.clear_plot(i) if Game.field.has_method("clear_plot") else null
	var data: Dictionary = DataFile.read(GoalSystem.DATA_PATH)
	for verb: String in data["show"]:
		if verb in ["buy", "build", "own", "collect", "feed", "upgrade", "start_craft", "craft", "repair", "move"]:
			continue   # (things named by id: shown in the Market or on the farm by HudGoals' own tests)
		hud.goals.show_me({"do": verb, "what": "", "n": 1})
		await get_tree().process_frame
		var arrows := hud.find_children("*", "GuideArrow", true, false).size()
		_check(arrows > 0 or hud.book.visible, "Show me for %s does something (an arrow or a panel)" % verb)
		hud.book.close_panel()
		for a in hud.find_children("*", "GuideArrow", true, false):
			a.queue_free()
		await get_tree().create_timer(0.3).timeout
	main.queue_free()
	await get_tree().process_frame
