class_name HudGuide
extends RefCounted
## The guided start (owner's pick A, 28 Nov; Hay Day's way): a new farm's Welcome chain (data/goals.json,
## `guided`) played one step at a time. A strip under the top bar says the step (Maple's picture, "5 / 13" and
## her line; a tap on it is Show me), the arrow points by itself at what to do and comes back while the step is
## open (HudGoals.point_only), only the step's own goal face shows (HudGoals.faces), and the buttons a step needs
## appear as it asks for them (HudReveal). A step done opens a "Well done" card with what it taught (`learn`) and
## its reward; Next collects it and the next step begins. The last one opens "Your farm is ready", and the rest
## of the game (the neighbours' goals, today's jobs, the ads) takes over. A farm from before never sees it.

const KEY := "chain:welcome"         # not-ui (the guided chain's goal key)
const CHAIN := "welcome"             # not-ui
const POINT_EVERY := 2.5             # seconds between looks for whether the arrow should point again
const DONE_PANEL := "GuideDone"      # not-ui (node names: tests find them)
const READY_PANEL := "GuideReady"    # not-ui

var hud: FarmHud
var strip: PanelContainer
var _face: Control
var _count: Label
var _say: Label
var _shown_done := -1    # the step whose Well done card is up (or was: it is not shown twice)
var _was_guiding := false


func _init(owner: FarmHud) -> void:
	hud = owner


## Whether the guided start is on: its chain open on this farm.
static func guiding() -> bool:
	return Game.goals.active() and Game.goals.chain_step.has(CHAIN) and \
		bool(Game.goals.chain_of(CHAIN).get("guided", false))


func build(root: Control, y: float) -> void:
	strip = PanelContainer.new()
	strip.name = "GuideStrip"   # not-ui (a node's name)
	var sb := UiKit.card_box("card_face")
	sb.set_content_margin_all(UiTheme.size("card_pad"))
	strip.add_theme_stylebox_override("panel", sb)
	strip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	strip.offset_top = y
	root.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiTheme.size("row_gap")))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(row)
	_face = HudGoals.picture_of(KEY, UiTheme.size("goal_task_icon"))
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_face)
	_count = BookPanel.text("", UiTheme.CAPTION, BookPanel.GOOD)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_count)
	_say = BookPanel.text("", UiTheme.BODY)
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say.custom_minimum_size.x = UiTheme.size("guide_strip_width")
	_say.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_say)
	strip.gui_input.connect(func(e: InputEvent) -> void:   # (a tap on the strip: Show me, on the release)
		if e is InputEventMouseButton and not e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			strip.accept_event()
			var task := current_task()
			if not task.is_empty():
				hud.goals.show_me(task))
	var look := Timer.new()
	look.wait_time = POINT_EVERY
	look.autostart = true
	look.timeout.connect(_point_again)
	strip.add_child(look)
	Game.goals_changed.connect(refresh)
	refresh.call_deferred()


## The strip shows the step now; a step done opens its card; the end opens the farm-ready card.
func refresh() -> void:
	if strip == null or not is_instance_valid(strip):
		return
	var on := guiding()
	strip.visible = on and not hud.interface_hidden
	if _was_guiding and not on and Game.goals.chains_done.has(CHAIN):
		_was_guiding = false
		_show_ready.call_deferred()
		return
	_was_guiding = on
	if not on:
		return
	var step := int(Game.goals.chain_step[CHAIN])
	var steps: Array = Game.goals.chain_of(CHAIN).get("steps", [])
	_count.text = tr("GUIDE_STEP") % [step + 1, steps.size()]
	_say.text = UiTheme.tidy(HudGoals.say_of(KEY))
	if Game.goals.is_done(KEY) and _shown_done != step:
		_shown_done = step
		_show_done.call_deferred(step)


## The first task of the step not done yet ({} when all are).
func current_task() -> Dictionary:
	if not guiding():
		return {}
	var tasks := Game.goals.tasks_of(KEY)
	var at := Game.goals.progress_of(KEY)
	for t in tasks.size():
		if t < at.size() and int(at[t][0]) < int(at[t][1]):
			return tasks[t]
	return {}


## The arrow comes back while the step is open and nothing else is up (a panel, a placing, an arrow already).
func _point_again() -> void:
	if guiding() and Game.goals.is_done(KEY) and _shown_done == -1:
		refresh()   # (a Well done that waited for a panel or a placing to finish)
		return
	var arrows := hud.find_children("*", "GuideArrow", true, false)   # not-ui (a class name)
	if not guiding() or not arrows.is_empty():
		return
	var sheet_up: bool = hud.sheet != null and hud.sheet.is_open()
	if Game.modal_open and not hud.book.is_open() and not sheet_up:   # (a level-up card or a reveal: it first)
		return
	if hud.book.is_open() or sheet_up:   # (a list or a building open for this step: the arrow at what to tap)
		var wanted := current_task()
		var id := str(wanted.get("what", ""))
		if str(wanted.get("do", "")) in ["plant", "buy", "build", "own", "take_out"]:
			hud.goals.point_at_card(id)
		elif str(wanted.get("do", "")) == "repair":
			var fix := hud.find_child("RepairBarn", true, false) as Control
			if fix != null and fix.is_visible_in_tree():
				GuideArrow.point(hud, GuideArrow.at_control(fix))
		elif str(wanted.get("do", "")) == "claim":   # (the mailbox open: its Place for the thing)
			var take := hud.book.find_child("Take_" + id, true, false) as Control
			if take != null and take.is_visible_in_tree():
				GuideArrow.point(hud, GuideArrow.at_control(take))
		return
	if hud.grid != null and not hud.grid.placing.is_empty():
		return
	var task := current_task()
	if not task.is_empty():
		hud.goals.point_only(task)


## A finger or the mouse down on the farm (a press, a drag or a hold under way): the card waits for it.
func _busy() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


## "Well done": what the step taught, its reward, and Next (which collects it).
func _show_done(step: int) -> void:
	if not guiding() or int(Game.goals.chain_step.get(CHAIN, -1)) != step:
		return
	if Game.modal_open or (hud.grid != null and not hud.grid.placing.is_empty()) or _busy():
		_shown_done = -1   # (not over a panel, a placing or a press under way: asked again in a moment)
		return
	var learn := str((Game.goals.chain_of(CHAIN)["steps"][step] as Dictionary).get("learn", ""))
	var reward := Game.goals.reward_of(KEY)
	hud.book.open_panel(tr("GUIDE_WELL_DONE"), func(content: VBoxContainer) -> void:
		content.name = DONE_PANEL
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", int(UiTheme.size("row_gap")))
		var pic := HudGoals.picture_of(KEY, UiTheme.size("inbox_face"))
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(pic)
		var words := BookPanel.text(UiTheme.tidy(tr(learn)) if learn != "" else "", UiTheme.BODY)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(words)
		content.add_child(head)
		var foot := HBoxContainer.new()
		var gets := HudGoals.reward_row(reward)
		gets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gets.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.add_child(gets)
		var next := hud.panel_button(tr("GUIDE_NEXT"))
		next.name = "GuideNext"   # not-ui (a node's name)
		next.pressed.connect(func() -> void:
			hud.book.close_panel()
			Game.goals.claim(KEY))
		foot.add_child(next)
		content.add_child(foot), BookPanel.Shape.LIST)


## "Your farm is ready": the guided start is over and everything is open.
func _show_ready() -> void:
	hud.book.open_panel(tr("GUIDE_READY_TITLE"), func(content: VBoxContainer) -> void:
		content.name = READY_PANEL
		content.add_child(BookPanel.text(tr("GUIDE_READY_SAYS"), UiTheme.BODY))
		var go := hud.panel_button(tr("GUIDE_READY_GO"))
		go.name = "GuideGo"   # not-ui (a node's name)
		go.size_flags_horizontal = Control.SIZE_SHRINK_END
		go.pressed.connect(func() -> void: hud.book.close_panel())
		content.add_child(go), BookPanel.Shape.LIST)
	hud.ads.refresh()
