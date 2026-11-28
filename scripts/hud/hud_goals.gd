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
const PROJECT_ICON := "barn"     # a project with no thing for its reward
const VERB_ICONS := {"plow": "hoe", "plant": "seeds", "harvest": "basket", "fertilize": "fertilizer",
	"level": "star", "buy": "market", "build": "market", "own": "market"}   # a task with no thing's picture
const TOOL_SPOTS := {"plow": "grass", "fertilize": "growing"}   # Show me's arrow: where each tool is used

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


## A goal's face: its picture in a ring of how far it is, a dot when it is done; a tap opens its card.
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
		show_goal(key))
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
	hud.book.open_tabs(tr("GOALS"), tabs(), first, BookPanel.Shape.LIST)


## Opens one goal's card on its own (a face tapped), the panel no wider than a column, titled with its name.
func show_goal(key: String) -> void:
	Game.goals.refresh()
	hud.book.open_panel(UiTheme.tidy(title_of(key)), func(content: VBoxContainer) -> void:
		if Game.goals.open_keys().has(key):
			content.add_child(card(key, false))
		else:
			content.add_child(BookPanel.text(tr("GOALS_NONE_INFO"), UiTheme.BODY, BookPanel.SOFT)), BookPanel.Shape.LIST)


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
func card(key: String, titled := true) -> Control:
	# Compact, FarmVille's quest card (owner's pick 1, 27 Nov: "compact and to the point, super clean"): who asks
	# and one line of what they say, the tasks as picture tiles (a bar each; a tap shows the way), and a line with
	# the reward and Collect. `titled`: the goal's name over it (a sheet of several; alone, the panel says it).
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UiTheme.size("hud_gap") * 0.6))
	var say := say_of(key)
	if titled or say != "":
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", int(UiTheme.size("row_gap")))
		var pic := picture_of(key, UiTheme.size("inbox_face"))
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(pic)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		words.add_theme_constant_override("separation", 0)
		if titled:
			words.add_child(BookPanel.text(UiTheme.tidy(title_of(key)), UiTheme.HEADING))
		if say != "":
			var line := BookPanel.text(UiTheme.tidy(say), UiTheme.BODY, BookPanel.SOFT)
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			words.add_child(line)
		head.add_child(words)
		col.add_child(head)
	var tiles := HFlowContainer.new()
	tiles.add_theme_constant_override("h_separation", int(UiTheme.size("hud_gap") * 0.6))
	tiles.add_theme_constant_override("v_separation", int(UiTheme.size("hud_gap") * 0.6))
	var tasks := Game.goals.tasks_of(key)
	var at := Game.goals.progress_of(key)
	for t in tasks.size():
		tiles.add_child(task_tile(tasks[t], at[t] if t < at.size() else [0, 1]))
	col.add_child(tiles)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", int(UiTheme.size("row_gap")))
	var reward := reward_row(Game.goals.reward_of(key))
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(reward)
	for b in _buttons(key):
		foot.add_child(b)
	col.add_child(foot)
	return col


## A reward as small pictures with their numbers (coins, XP, gems, the thing that comes), the rest in words.
static func reward_row(reward: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiTheme.size("row_gap")))
	var px := UiTheme.size("goal_reward_icon")
	var rest := reward.duplicate()
	for f: Array in [["coins", "coin"], ["xp", "star"], ["gems", "gem"]]:
		if rest.has(f[0]):
			row.add_child(_reward_bit(UiIcon.make(str(f[1]), px), UiTheme.number(int(rest[f[0]]))))
			rest.erase(f[0])
	for f in ["place", "item"]:
		if rest.has(f) and ItemIcons.of(str(rest[f])) != null:
			var tex := TextureRect.new()
			tex.texture = ItemIcons.of(str(rest[f]))
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = Vector2(px, px)
			var bit := _reward_bit(tex, UiTheme.tidy(Game.name_of(str(rest[f]))))
			bit.tooltip_text = Game.name_of(str(rest[f]))
			row.add_child(bit)
			rest.erase(f)
	if not rest.is_empty():
		var more := BookPanel.text(reward_words(rest), UiTheme.CAPTION, BookPanel.SOFT)
		more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(more)
	return row


static func _reward_bit(picture: Control, words: String) -> HBoxContainer:
	var bit := HBoxContainer.new()
	bit.add_theme_constant_override("separation", int(UiTheme.size("row_gap") * 0.4))
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bit.add_child(picture)
	var label := BookPanel.text(words, UiTheme.BODY)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bit.add_child(label)
	return bit


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


## One task as a tile: the thing's picture, what to do in a few words, a bar with the count; the whole tile is
## Show me while it is not done (the arrow then points), still with a green edge when it is.
func task_tile(task: Dictionary, at: Array) -> Control:
	var have := mini(int(at[0]), int(at[1]))
	var need := int(at[1])
	var done := have >= need
	var w := UiTheme.size("goal_tile_width")
	var pad := UiTheme.size("card_pad")
	var tile := Button.new()
	tile.focus_mode = Control.FOCUS_NONE
	var sb := UiKit.card_box("card_face")
	if done:
		sb.border_color = UiTheme.color("accent")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		tile.add_theme_stylebox_override(state, sb)
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", int(UiTheme.size("hud_gap") * 0.3))
	inner.position = Vector2(pad, pad)
	var px := UiTheme.size("goal_task_icon")
	var picture := _task_picture(task, px)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(picture)
	var words := BookPanel.text(UiTheme.tidy(task_words(task)), UiTheme.CAPTION)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.clip_text = true
	words.custom_minimum_size.x = w - pad * 2.0
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(words)
	var bar := UiKit.word_bar()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.set_bar(bar, have, need, "%s / %s" % [UiTheme.number(have), UiTheme.number(need)])
	inner.add_child(bar)
	tile.add_child(inner)
	tile.custom_minimum_size = Vector2(w, UiTheme.size("panel_button_height"))
	var fit := func() -> void:   # (once in the tree, when its words know their font: as tall as what it holds)
		var high := inner.get_combined_minimum_size().y
		inner.size = Vector2(w - pad * 2.0, high)
		tile.custom_minimum_size.y = maxf(high + pad * 2.0, UiTheme.size("panel_button_height"))
	tile.ready.connect(fit)
	inner.minimum_size_changed.connect(fit)
	tile.tooltip_text = UiTheme.tidy(task_words(task))
	if not done and not show_of(task).is_empty():
		tile.name = "ShowMe"   # not-ui (a node's name)
		UiFx.press_bounce(tile)
		tile.pressed.connect(func() -> void: show_me(task))
	else:
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tile


## A task's picture: its thing's, else the tool the verb uses (Plow: the hoe), else the goal's calendar.
static func _task_picture(task: Dictionary, px: float) -> Control:
	var what := str(task.get("what", GoalSystem.ANY))
	if what != GoalSystem.ANY and ItemIcons.of(what) != null:
		var pic := TextureRect.new()
		pic.texture = ItemIcons.of(what)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(px, px)
		return pic
	return UiIcon.make(str(VERB_ICONS.get(str(task.get("do", "")), DAILY_ICON)), px)


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


## Show me: the tool in hand, the Seeds, the Market on the thing's shelf, or the view to its place, and then an
## arrow (GuideArrow, no words: owner, 27 Nov) at what to tap: a plot to work, the thing on the farm, its card in
## the Market, or the tool button when the farm has nothing to work yet.
func show_me(task: Dictionary) -> void:
	Feedback.moment("tap")
	var to := show_of(task)
	hud.book.close_panel()
	if to.has("tool"):
		var tool := str(to["tool"])
		hud.tool_selected.emit(tool, "")
		hud.tools.show_tool(tool)
		_point_farm(str(TOOL_SPOTS.get(tool, "")), tool)
	elif to.has("seeds"):
		var crop := str(to["seeds"])
		if Game.crops.has(crop) and Game.can_plant(crop):
			hud.choose_seed(crop)
			_point_farm("plowed", "plow")
		else:
			hud.show_seeds()
	elif to.has("market"):
		hud.show_market_for(str(to["market"]))
		_point_card(str(to["market"]))
	elif to.has("farm"):
		_point_farm(str(to["farm"]), "")


## The arrow at the nearest spot of `kind` (the view goes there), or at tool `fallback`'s button when there is none.
func _point_farm(kind: String, fallback: String) -> void:
	var spot: Dictionary = hud.go_to.call(kind) if kind != "" and hud.go_to.is_valid() else {}
	if not spot.is_empty() and hud.grid != null:
		var grid := hud.grid
		var at: Vector2 = spot["at"]
		GuideArrow.point(hud, func() -> Vector2:
			return grid.to_screen(at) if is_instance_valid(grid) else Vector2.INF)
	elif hud.tools.buttons.has(fallback):
		GuideArrow.point(hud, GuideArrow.at_control(hud.tools.buttons[fallback]))


## The arrow at `id`'s card in the open Market (its shelf scrolled to it), while that card shows it.
func _point_card(id: String) -> void:
	var list: CardList = null
	for c in hud.find_children("*", "CardList", true, false):   # not-ui (a class name)
		if (c as CardList).is_visible_in_tree() and (c as CardList).bring_into_view(id):
			list = c
			break
	if list == null:
		return
	await hud.get_tree().process_frame
	await hud.get_tree().process_frame   # (the list fills the cards it scrolled to)
	if is_instance_valid(list):
		GuideArrow.point(hud, func() -> Vector2:
			var card := list.card_of(id) if is_instance_valid(list) else null
			return card.get_global_rect().get_center() if card != null and card.is_visible_in_tree() else Vector2.INF)


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

	var _down := false

	# A tap is a press and its release on the face, as a Button's (the release, not the press, opens the goal:
	# opened on the press, the rest of that tap, and on a phone its mouse twin, landed on the new card and its
	# backdrop and shut it again, 28 Nov). Mouse events only: touches arrive as them (emulate_mouse_from_touch).
	func _gui_input(e: InputEvent) -> void:
		var b := e as InputEventMouseButton
		if b == null or b.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if b.pressed:
			_down = true
		elif _down:
			_down = false
			if Rect2(Vector2.ZERO, size).has_point(b.position):
				tapped.emit()

	func _draw() -> void:
		draw_circle(size / 2.0, minf(size.x, size.y) / 2.0, UiTheme.color("paper"))
		var edge := minf(size.x, size.y) * RING_INSET   # (the ring on the paper, not on the grass)
		ProgressRing.paint(self, Rect2(Vector2.ONE * edge, size - Vector2.ONE * edge * 2.0), share, "",
			get_theme_default_font())
