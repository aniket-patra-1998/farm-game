class_name HudGoals
extends RefCounted
## The goals on screen (docs/PLAYER_EXPERIENCE.md Part 1, our own shape of FarmVille's quest icons): a column of up
## to three round goal faces at the left edge under the coin meter (the giver's portrait, a calendar for today's
## jobs, the reward's picture for a project; a ring for how far it is, a dot when it waits to be collected), and
## the goal sheet a face opens: the one panel look, tabs Story, Today and Projects. Each task is a word bar
## ("Harvest Strawberry 6 / 10") with Show me (data/goals.json `show`: the tool, the Seeds, the Market shelf or
## the place on the farm); a finished goal is collected with one tap. The rules are GoalSystem's; this only asks.

const FACES := 3                 # at most this many faces (never in the way)
const FACE_INSET := 0.18         # the picture inside the ring, as a share of the face
const RING_INSET := 0.04         # the ring's way in from the face's edge, as a share of the face
## The sheet's tabs: which goals each shows (the key's part before ":") and its words.
const TABS := [["chain", "GOALS_STORY"], ["daily", "GOALS_TODAY"], ["project", "GOALS_PROJECTS"]]
const DAILY_ICON := "calendar"
const DAILY_PICTURE := 0.75   # a daily job's calendar, of a giver's picture (one line, not a card head)
const PROJECT_ICON := "barn"     # a project with no thing for its reward

var hud: FarmHud
var column: VBoxContainer
var _shown: Array[String] = []   # the keys the faces show, and how far each was (a change rebuilds them)
var _shown_at: Array = []


func _init(owner: FarmHud) -> void:
	hud = owner


func build(root: Control) -> void:
	var margin := UiTheme.size("hud_margin")
	column = VBoxContainer.new()
	column.name = "GoalFaces"   # not-ui (a node's name)
	column.position = Vector2(margin, UiTheme.size("top_height") + margin + UiTheme.size("hud_gap"))
	column.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
	root.add_child(column)
	Game.goals_changed.connect(update)
	column.tree_exited.connect(func() -> void:   # (the HUD gone: a goal change must not reach it)
		if Game.goals_changed.is_connected(update):
			Game.goals_changed.disconnect(update))
	Game.goals.refresh()
	update()


## Makes the faces again when what they show changed, and the open sheet with them.
func update() -> void:
	if not is_instance_valid(hud) or not is_instance_valid(column) or not column.is_inside_tree():
		return
	var keys := faces()
	var at := keys.map(func(k: String) -> Array: return [Game.goals.progress_of(k), Game.goals.is_done(k)])
	column.visible = Game.goals.active() and not hud.interface_hidden
	if keys != _shown or at != _shown_at:
		_shown = keys
		_shown_at = at
		for c in column.get_children():
			column.remove_child(c)
			c.queue_free()
		for key in keys:
			column.add_child(face(key))
	if hud.book.is_open():
		hud.book.refresh()


## The goals the faces show: the first three open ones (chains, then today's jobs, then projects).
static func faces() -> Array[String]:
	if not Game.goals.active():
		return []
	var keys := Game.goals.open_keys()
	return keys.slice(0, FACES)


## A goal's face: its picture in a ring of how far it is, a dot when it is done; a tap opens its tab.
func face(key: String) -> Control:
	var px := UiTheme.size("goal_face")
	var f := GoalFace.new()
	f.name = "Face_" + key.replace(":", "_")   # not-ui (a node's name)
	f.custom_minimum_size = Vector2(px, px)
	f.share = share_of(key)
	f.done = Game.goals.is_done(key)
	f.tooltip_text = UiTheme.tidy(title_of(key))
	var pic := picture_of(key, px * (1.0 - 2.0 * FACE_INSET))
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(pic)
	pic.position = Vector2.ONE * px * FACE_INSET
	f.tapped.connect(func() -> void:
		Feedback.moment("tap")
		show_goals(tab_of(key)))
	return f


## How far a goal is, 0 to 1, over all its tasks.
static func share_of(key: String) -> float:
	var have := 0
	var need := 0
	for p: Array in Game.goals.progress_of(key):
		have += mini(int(p[0]), int(p[1]))
		need += int(p[1])
	return 1.0 if need <= 0 else float(have) / float(need)


## The tab a goal is on.
static func tab_of(key: String) -> int:
	var kind := key.split(":")[0]
	for k in TABS.size():
		if TABS[k][0] == kind:
			return k
	return 0


## Opens the goal sheet on tab `first`.
func show_goals(first := 0) -> void:
	Game.goals.refresh()
	hud.book.open_tabs(tr("GOALS"), tabs(), first)


func tabs() -> Array:
	var out: Array = []
	for t: Array in TABS:
		var kind := str(t[0])
		out.append([tr(str(t[1])), func(content: VBoxContainer) -> void: build_tab(content, kind)])
	return out


## One tab: its open goals as cards, or a word that there are none yet.
func build_tab(content: VBoxContainer, kind: String) -> void:
	var keys: Array[String] = []
	for key in Game.goals.open_keys():
		if key.begins_with(kind + ":"):
			keys.append(key)
	if kind == "daily":
		content.add_child(BookPanel.text(tr("GOALS_TODAY_BONUS"), UiTheme.BODY, BookPanel.SOFT))
	if keys.is_empty():
		content.add_child(BookPanel.info(tr("GOALS_NONE_" + kind.to_upper()), tr("GOALS_NONE_INFO"),
			UiTheme.BODY, BookPanel.SOFT))
	for key in keys:
		content.add_child(BookPanel.card_frame(card(key)))


## A goal's card: who asks (their picture, name and words), each task as a word bar with Show me, and Collect
## when it is done (Swap on a daily job not started, once a day).
func card(key: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UiTheme.size("hud_gap") * 0.5))
	var daily := key.begins_with("daily:")
	var tasks := Game.goals.tasks_of(key)
	var at := Game.goals.progress_of(key)
	var buttons := _buttons(key)
	if daily and tasks.size() == 1:   # (a daily job is one line: its calendar, its bar, its buttons)
		var row := task_row(tasks[0], at[0] if not at.is_empty() else [0, 1])
		var pic := picture_of(key, UiTheme.size("inbox_face") * DAILY_PICTURE)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pic)
		row.move_child(pic, 0)
		for b in buttons:
			row.add_child(b)
		col.add_child(row)
		return col
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	var pic := picture_of(key, UiTheme.size("inbox_face"))
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pic)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_child(BookPanel.heading(UiTheme.tidy(title_of(key))))
	var say := say_of(key)
	if say != "":
		var line := BookPanel.text(UiTheme.tidy(say), UiTheme.BODY, BookPanel.SOFT)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(line)
	head.add_child(words)
	col.add_child(head)
	for t in tasks.size():
		col.add_child(task_row(tasks[t], at[t] if t < at.size() else [0, 1]))
	if not buttons.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation", 14)
		for b in buttons:
			row.add_child(b)
		col.add_child(row)
	return col


## A goal's buttons: Swap on a daily job not done (once a day), Collect on a done goal.
func _buttons(key: String) -> Array[Button]:
	var out: Array[Button] = []
	var done := Game.goals.is_done(key)
	if key.begins_with("daily:") and not done and Game.goals.daily_swaps < int(Game.goals.daily_data.get("swap", 0)):
		var swap := hud.panel_button(tr("GOAL_SWAP"))
		swap.pressed.connect(func() -> void:
			Feedback.moment("tap")
			Game.goals.swap_daily(int(key.split(":")[1])))
		out.append(swap)
	if done:
		var claim := hud.panel_button(tr("GOAL_COLLECT"))
		claim.name = "Collect"   # not-ui (a node's name)
		claim.pressed.connect(func() -> void: collect(key))
		out.append(claim)
	for b in out:
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return out


## One task: "Harvest Strawberry 6 / 10" on a word bar, and Show me while it is not done.
func task_row(task: Dictionary, at: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var have := mini(int(at[0]), int(at[1]))
	var need := int(at[1])
	var bar := UiKit.word_bar()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.set_bar(bar, have, need, "%s %s / %s" % [task_words(task), UiTheme.number(have), UiTheme.number(need)])
	row.add_child(bar)
	if have < need and not show_of(task).is_empty():
		var show := hud.panel_button(tr("GOAL_SHOW_ME"))
		show.name = "ShowMe"   # not-ui (a node's name)
		show.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		show.pressed.connect(func() -> void: show_me(task))
		row.add_child(show)
	return row


## A task in words, without its numbers: "Harvest Strawberry", "Plow plots", "Reach level 5".
static func task_words(task: Dictionary) -> String:
	var verb := str(task.get("do", "")).to_upper()
	var what := str(task.get("what", GoalSystem.ANY))
	if verb == "LEVEL":
		return TranslationServer.translate("GOAL_DO_LEVEL") % UiTheme.number(int(task.get("n", 1)))
	if what == GoalSystem.ANY:
		return TranslationServer.translate("GOAL_DO_%s_ANY" % verb)
	return TranslationServer.translate("GOAL_DO_" + verb) % thing_name(what)


## The name of a task's thing: an item or crop, or a kind ("animals").
static func thing_name(what: String) -> String:
	var name := Game.name_of(what)
	if name == "" and Game.crops.has(what):
		name = str(Game.crops[what].get("name", what))
	if name == "":
		name = TranslationServer.translate("GOAL_KIND_" + what.to_upper())
	return name


## The locale keys a task's words need (tests hold every goal in data to them).
static func keys_of(task: Dictionary) -> Array[String]:
	var verb := str(task.get("do", "")).to_upper()
	var what := str(task.get("what", GoalSystem.ANY))
	if verb == "LEVEL":
		return ["GOAL_DO_LEVEL"]
	if what == GoalSystem.ANY:
		return ["GOAL_DO_%s_ANY" % verb]
	var out: Array[String] = ["GOAL_DO_" + verb]   # not-ui (keys)
	if what.begins_with(GoalSystem.PICK):
		return out
	if Game.name_of(what) == "" and not Game.crops.has(what):
		out.append("GOAL_KIND_" + what.to_upper())   # not-ui (a key)
	return out


## Where a task's Show me goes (data/goals.json `show`, by verb): "tool:<id>", "seeds", "market" or a place
## on the farm ("farm:<kind>", "farm:item" for the task's own thing). {} when nothing fits.
static func show_of(task: Dictionary) -> Dictionary:
	var how := str((Game.goals.show_data as Dictionary).get(str(task.get("do", "")), ""))
	var what := str(task.get("what", GoalSystem.ANY))
	if how == "":
		return {}
	var part := how.split(":", true, 1)
	match part[0]:
		"farm":
			var kind := part[1] if part.size() > 1 else ""
			if kind == "item":
				if what == GoalSystem.ANY or Game.name_of(what) == "":
					return {}
				kind = FarmGrid.ITEM_SPOT + what
			return {"farm": kind}
		"tool":
			return {"tool": part[1] if part.size() > 1 else ""}
		"market":
			return {"market": what}
		"seeds":
			return {"seeds": what}
	return {}


## Show me: the tool in hand, the Seeds, the Market on the thing's shelf, or the view to its place.
func show_me(task: Dictionary) -> void:
	Feedback.moment("tap")
	var to := show_of(task)
	hud.book.close_panel()
	if to.has("tool"):
		hud.tool_selected.emit(str(to["tool"]), "")
		hud.tools.show_tool(str(to["tool"]))
	elif to.has("seeds"):
		var crop := str(to["seeds"])
		if Game.crops.has(crop) and Game.can_plant(crop):
			hud.choose_seed(crop)
		else:
			hud.show_seeds()
	elif to.has("market"):
		hud.show_market_for(str(to["market"]))
	elif to.has("farm"):
		if hud.go_to.is_valid():
			hud.go_to.call(str(to["farm"]))


## Collects a finished goal: the reward, its sound, and a word of what came.
func collect(key: String) -> void:
	var reward := Game.goals.claim(key)
	if reward.is_empty() and not Game.goals.open_keys().has(key):
		Feedback.moment("collect")
		return
	if reward.is_empty():
		return
	Feedback.moment("collect")
	hud.show_message(reward_words(reward))


## A reward in words: "+60 coins · +10 XP · a Mystery Box".
static func reward_words(reward: Dictionary) -> String:
	var parts: PackedStringArray = []
	for f: Array in [["coins", "GOAL_GOT_COINS"], ["xp", "GOAL_GOT_XP"], ["gems", "GOAL_GOT_GEMS"]]:
		if reward.has(f[0]):
			parts.append(TranslationServer.translate(str(f[1])) % UiTheme.number(int(reward[f[0]])))
	for f in ["item", "place"]:
		if reward.has(f):
			parts.append(TranslationServer.translate("GOAL_GOT_ITEM") % Game.name_of(str(reward[f])))
	if reward.has("seeds"):
		parts.append(TranslationServer.translate("GOAL_GOT_SEEDS") % Game.name_of(str(reward["seeds"])))
	var mats: Variant = reward.get("parts", {})
	if typeof(mats) == TYPE_DICTIONARY:
		for m: String in mats:
			parts.append(TranslationServer.translate("GOAL_GOT_PARTS") % [UiTheme.number(int(mats[m])), Game.name_of(m)])
	if reward.has("box"):
		parts.append(TranslationServer.translate("GOAL_GOT_BOX"))
	return UiTheme.tidy(" · ".join(parts))


## A goal's title: the giver's name, "Today's job" or the project's name.
static func title_of(key: String) -> String:
	var part := key.split(":", true, 1)
	match part[0]:
		"chain":
			return giver_of(part[1])
		"project":
			return TranslationServer.translate(str(Game.goals.project_of(part[1]).get("name", "")))
	return TranslationServer.translate("GOAL_TODAY_JOB")


## Who gives a chain, as the inbox names them (the data may write the name in any case).
static func giver_of(chain_id: String) -> String:
	var giver := str(Game.goals.chain_of(chain_id).get("giver", ""))
	for n in Game.social.roster():
		if n.to_lower() == giver.to_lower():
			return n
	return giver.capitalize()


## What the giver says on the step the chain is on (a locale key in the data); "" for others.
static func say_of(key: String) -> String:
	var part := key.split(":", true, 1)
	if part[0] != "chain":
		return ""
	var c := Game.goals.chain_of(part[1])
	var step := int(Game.goals.chain_step.get(part[1], 0))
	var steps: Array = c.get("steps", [])
	if step >= steps.size():
		return ""
	var say := str((steps[step] as Dictionary).get("say", ""))
	return TranslationServer.translate(say) if say != "" else ""


## A goal's picture: the giver's portrait, a calendar for today's jobs, the project's reward.
static func picture_of(key: String, px: float) -> Control:
	var part := key.split(":", true, 1)
	match part[0]:
		"chain":
			return PortraitIcon.of(Game.social.look_of(giver_of(part[1])), px)
		"project":
			var reward: Dictionary = Game.goals.project_of(part[1]).get("reward", {})
			for f in ["place", "item"]:
				if reward.has(f) and ItemIcons.of(str(reward[f])) != null:
					var tex := TextureRect.new()
					tex.texture = ItemIcons.of(str(reward[f]))
					tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					tex.custom_minimum_size = Vector2(px, px)
					tex.size = Vector2(px, px)
					return tex
			return UiIcon.make(PROJECT_ICON, px)
	return UiIcon.make(DAILY_ICON, px)


## A face: a paper disc, the ring of how far the goal is round its picture, and the done dot on top.
class GoalFace:
	extends Control

	signal tapped

	var share := 0.0
	var done := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		if done:   # (the menu's own dot: something here to take)
			var dot := UiKit.count_badge(self)
			dot.text = "!"   # not-ui (a sign, not a word)
			dot.get_parent().name = "Done"   # not-ui (a node's name)

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed
				and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
				or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			accept_event()
			tapped.emit()

	func _draw() -> void:
		draw_circle(size / 2.0, minf(size.x, size.y) / 2.0, UiTheme.color("paper"))
		var edge := minf(size.x, size.y) * RING_INSET   # (the ring on the paper, not on the grass)
		ProgressRing.paint(self, Rect2(Vector2.ONE * edge, size - Vector2.ONE * edge * 2.0), share, "",
			get_theme_default_font())
