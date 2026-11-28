extends TestSuite
## A player who only follows the arrow and taps Next (owner, 28 Nov: "check the game the way I play it"): real
## touches from a new farm to the end of the guided start; anything that leaves him with nothing to tap is a gap.

var gaps: Array[String] = []


func _tap(screen_canvas: Vector2, hold := 0.0, drag_to := Vector2.INF) -> void:
	var tf := get_viewport().get_final_transform()
	var e := InputEventScreenTouch.new()
	e.pressed = true
	e.position = tf * screen_canvas
	Input.parse_input_event(e)
	await get_tree().process_frame
	if hold > 0.0:
		await get_tree().create_timer(hold).timeout
	var end := screen_canvas
	if drag_to != Vector2.INF:
		for i in 8:
			var p := screen_canvas.lerp(drag_to, (i + 1) / 8.0)
			var d := InputEventScreenDrag.new()
			d.position = tf * p
			d.relative = tf.basis_xform((drag_to - screen_canvas) / 8.0)
			Input.parse_input_event(d)
			await get_tree().process_frame
		end = drag_to
	e = InputEventScreenTouch.new()
	e.pressed = false
	e.position = tf * end
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame


func _gap(s: String) -> void:
	if not gaps.has(s):
		gaps.append(s)
		print("GAP ", s)


func test_669_a_player_who_only_follows_the_arrow_finishes_the_guided_start() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	var hud: FarmHud = main.get("hud")
	var grid: FarmGrid = main.get("grid")
	var cam: FarmCamera = main.get("camera")
	var view := get_viewport().get_visible_rect()
	var last_step := -1
	var still := 0
	for it in 500:
		if not HudGuide.guiding():
			break
		var step := int(Game.goals.chain_step.get(HudGuide.CHAIN, -1))
		if step != last_step:
			print("STEP ", step + 1, " ", HudGoals.say_of(HudGuide.KEY), " at iteration ", it, " minute ", Game.skipped / 60)
			last_step = step
			still = 0
		still += 1
		if still > 60:
			_gap("stuck at step %d: %s (tasks %s %s)" % [step + 1, HudGoals.say_of(HudGuide.KEY),
				Game.goals.tasks_of(HudGuide.KEY), Game.goals.progress_of(HudGuide.KEY)])
			break
		var arrows := hud.find_children("*", "GuideArrow", true, false)
		if false:
			print("  dbg ", it, " title ", hud.book.get("_title").text, " next ", hud.book.find_child("GuideNext", true, false), " sheet ", hud.sheet != null and hud.sheet.is_open(), " shown_done ", hud.guide._shown_done, " done ", Game.goals.is_done(HudGuide.KEY), " busy ", hud.guide._busy(), " placing ", grid.placing.is_empty(), " resting ", hud.resting, " modal ", Game.modal_open, " arrows ", arrows.size(), " target ", (arrows[0] as GuideArrow).target.call() if not arrows.is_empty() else Vector2.INF, " plant btn ", hud.tools.buttons["plant"].get_global_rect().get_center(), " book ", hud.book.visible, " tool ", grid.tool, " crop ", grid.selected_crop, " seeds held ", Game.goals.seeds, " plowed ", grid.spots_of("plowed").size(), " task ", hud.guide.current_task(), " show ", HudGoals.show_of(hud.guide.current_task()))
		var target := Vector2.INF
		if not arrows.is_empty() and (arrows[0] as GuideArrow).target.is_valid():
			target = (arrows[0] as GuideArrow).target.call()
		var pops := get_tree().root.find_children("*", "LevelUpPopup", true, false)
		pops.append_array(get_tree().root.find_children("*", "RevealCard", true, false))
		pops = pops.filter(func(pp: Node) -> bool: return (pp as Control).is_visible_in_tree() and UiFx.is_open(pp))
		if not pops.is_empty() or (Game.modal_open and not hud.book.visible):   # (a level-up card or a reveal)
			var shut := false
			var btns := []
			for pp in pops:
				if (pp as Control).is_visible_in_tree():
					btns.append_array(pp.find_children("*", "Button", true, false))
			for c in btns:
				var bt := c as Button
				if bt.is_visible_in_tree():
					print("  closing popup via ", bt.text)
					await _tap(bt.get_global_rect().get_center())
					shut = true
					break
			if not shut:
				await _tap(view.get_center())
			await get_tree().create_timer(0.8).timeout
			continue
		if hud.book.visible:
			var next := hud.book.find_child("GuideNext", true, false) as Control
			if next != null:
				await _tap(next.get_global_rect().get_center())
				await get_tree().create_timer(0.5).timeout
				continue
			if target != Vector2.INF and view.has_point(target):
				await _tap(target + Vector2(0, 14))
				await get_tree().create_timer(0.5).timeout
				continue
			await get_tree().create_timer(HudGuide.POINT_EVERY + 0.3).timeout
			if not hud.find_children("*", "GuideArrow", true, false).is_empty():
				continue
			var ids := []
			for c in hud.find_children("*", "CardList", true, false):
				if (c as CardList).is_visible_in_tree():
					ids.append((c as CardList).ids.slice(0, 6))
			_gap("step %d: a panel (%s) is open and nothing points in it (task %s, lists %s)" % [step + 1,
				hud.book.get("_title").text, hud.guide.current_task(), ids])
			hud.book.close_panel()
			await get_tree().create_timer(0.5).timeout
			continue
		if hud.sheet != null and hud.sheet.is_open():
			if target != Vector2.INF and view.has_point(target):
				await _tap(target + Vector2(0, 14))
				await get_tree().create_timer(0.5).timeout
				continue
			_gap("step %d: a building's sheet is open and nothing points in it" % (step + 1))
			hud.sheet.call("close")
			await get_tree().create_timer(0.5).timeout
			continue
		if not grid.placing.is_empty():
			var id := str(grid.placing.get("item", ""))
			var placed := false
			for r in range(4, Game.farm_size - 4):
				for c in range(4, Game.farm_size - 4):
					if Game.can_place(id, r, c):
						var fp := Game.footprint(id)
						var cs := grid.corners_of(r, c, fp.x, fp.y)
						var mid: Vector2 = (cs[0] + cs[2]) / 2.0
						cam.snap(grid.to_global(mid), cam.target_zoom)
						await get_tree().process_frame
						await _tap(grid.to_screen(mid))
						placed = true
						break
				if placed:
					break
			await get_tree().create_timer(0.5).timeout
			continue
		if target == Vector2.INF:
			Game.debug_skip(60)   # (waiting: crops grow)
			await get_tree().create_timer(HudGuide.POINT_EVERY + 0.2).timeout
			continue
		if not view.grow(-20).has_point(target):
			var world := grid.get_canvas_transform().affine_inverse() * target
			cam.snap(world, cam.target_zoom)
			await get_tree().process_frame
			await get_tree().process_frame
			continue
		var task := hud.guide.current_task()
		if str(task.get("do", "")) == "move":
			await _tap(target + Vector2(0, 14), 0.7, target + Vector2(120, 74))
		else:
			await _tap(target + Vector2(0, 14))
		await get_tree().create_timer(0.4).timeout
	_check(not HudGuide.guiding(), "a player who only follows the arrow and taps Next finishes the guided start: %s" % [gaps])
	print("END guiding ", HudGuide.guiding(), " step ", int(Game.goals.chain_step.get(HudGuide.CHAIN, -1)) + 1,
		" minute ", Game.skipped / 60, " level ", Game.level(), " coins ", Game.coins)
	for g in gaps:
		print("GAPLIST ", g)
	main.queue_free()
	await get_tree().process_frame
