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
const BUBBLE_Z := 101                # above the spotlight (GuideArrow: z 100)
const WATCH_EVERY := 0.25            # seconds between looks for a panel or sheet opening or closing
const DONE_PANEL := "GuideDone"      # not-ui (node names: tests find them)
const READY_PANEL := "GuideReady"    # not-ui

var hud: FarmHud
var strip: PanelContainer
var _face: Control
var _count: Label
var _say: Label
var _shown_done := -1    # the step whose Well done card is up (or was: it is not shown twice)
var _was_guiding := false
var _scene := ""         # what was open at the last watch (the book, a sheet, a thing in hand)
var _pips: HBoxContainer # a pip a step: done, this one, to come
var _high := false       # the bubble moved up (the spotlight fell where it stands)


func _init(owner: FarmHud) -> void:
	hud = owner


## Whether the guided start is on: its chain open on this farm.
static func guiding() -> bool:
	return Game.goals.active() and Game.goals.chain_step.has(CHAIN) and \
		bool(Game.goals.chain_of(CHAIN).get("guided", false))


func build(root: Control, _y: float) -> void:
	# Maple's bubble (owner's pick A, 28 Nov): her face and one line at the bottom-left, clear of the top bar and of
	# what to tap (it moves up when the spotlight would fall under it), with the steps as pips under her words.
	strip = PanelContainer.new()
	strip.name = "GuideStrip"   # not-ui (a node's name)
	strip.add_theme_stylebox_override("panel", UiKit.paper_box(UiTheme.size("card_pad")))
	strip.z_index = BUBBLE_Z   # (over the spotlight's dark: Maple speaks in the light)
	root.add_child(strip)
	_place_strip(false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiTheme.size("row_gap")))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(row)
	_face = HudGoals.picture_of(KEY, UiTheme.size("guide_face"))
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_face)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", int(UiTheme.size("hud_gap") / 2.0))
	row.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var who := BookPanel.text(UiTheme.tidy(HudGoals.giver_of(CHAIN)), UiTheme.CAPTION, UiTheme.color("accent_text"))
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	_count = BookPanel.text("", UiTheme.CAPTION, BookPanel.SOFT)
	head.add_child(_count)
	_say = BookPanel.text("", UiTheme.HEADING)
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say.custom_minimum_size.x = UiTheme.size("guide_strip_width")
	col.add_child(_say)
	_pips = HBoxContainer.new()
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.add_theme_constant_override("separation", int(UiTheme.size("pip_gap")))
	col.add_child(_pips)
	GuideArrow.spot_allowed = _spot_allowed
	_hear_book.call_deferred()
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
	var watch := Timer.new()   # (a panel or sheet just opened or closed: the arrow moves at once, not up to 2.5 s on)
	watch.wait_time = WATCH_EVERY
	watch.autostart = true
	watch.timeout.connect(_watch)
	strip.add_child(watch)
	Game.goals_changed.connect(refresh)
	refresh.call_deferred()


## The strip shows the step now; a step done opens its card; the end opens the farm-ready card.
func refresh() -> void:
	if strip == null or not is_instance_valid(strip):
		return
	var on := guiding()
	strip.visible = on and not hud.interface_hidden and _after_intro() and not _covered()
	if _was_guiding and not on and Game.goals.chains_done.has(CHAIN):
		_was_guiding = false
		_show_ready.call_deferred()
		return
	_was_guiding = on
	if not on:
		return
	var step := int(Game.goals.chain_step[CHAIN])
	var steps: Array = Game.goals.chain_of(CHAIN).get("steps", [])
	_count.text = UiTheme.tidy(tr("GUIDE_STEP") % [step + 1, steps.size()])
	_say.text = UiTheme.tidy(HudGoals.say_of(KEY))
	_fill_pips(step, steps.size())
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
## Whether the first screen (HudIntro) is behind the player: until then the guide neither shows nor points.
static func _after_intro() -> bool:
	return Game.player.introduced or Game.in_showcase()


func _watch() -> void:
	if not guiding() or not _after_intro():
		return
	var now := "%s %s %s" % [hud.book.is_open(), hud.sheet != null and hud.sheet.is_open(),
		hud.grid != null and hud.grid.placing.is_empty()]
	if now != _scene:
		_scene = now
		_clear_arrows()   # (what it pointed at was in what just opened or closed)
		refresh()
		_point_again()
	_dodge()


func _point_again() -> void:
	if not _after_intro() or Time.get_ticks_msec() < GuideArrow.rest_until:
		return
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
			var fix := hud.find_child("RepairBarn", true, false) as Control   # not-ui (a node name)
			if fix != null and fix.is_visible_in_tree():
				GuideArrow.point(hud, GuideArrow.at_control(fix))
		elif str(wanted.get("do", "")) == "claim":   # (the mailbox open: its Place for the thing)
			var take := hud.book.find_child("Take_" + id, true, false) as Control   # not-ui (a node name)
			if take != null and take.is_visible_in_tree():
				GuideArrow.point(hud, GuideArrow.at_control(take))
		return
	if hud.grid != null and (not hud.grid.placing.is_empty() or hud.grid.carrying_soon != ""):
		return   # (a thing in hand, or about to be: the arrow would send the player off to the Barn meanwhile)
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
	_clear_arrows()   # (no spotlight left over the card)
	var learn := str((Game.goals.chain_of(CHAIN)["steps"][step] as Dictionary).get("learn", ""))
	var reward := Game.goals.reward_of(KEY)
	hud.book.open_panel(tr("GUIDE_WELL_DONE"), func(content: VBoxContainer) -> void:
		content.name = DONE_PANEL
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", int(UiTheme.size("row_gap")))
		var pic := HudGoals.picture_of(KEY, UiTheme.size("guide_face"))
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(pic)
		var words := BookPanel.text(UiTheme.tidy(tr(learn)) if learn != "" else "", UiTheme.HEADING)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(words)
		content.add_child(head)
		var foot := HBoxContainer.new()
		var gets := HudGoals.reward_row(reward)
		gets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gets.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.add_child(gets)
		var next := UiKit.primary(hud.panel_button(tr("GUIDE_NEXT")))
		next.name = "GuideNext"   # not-ui (a node's name)
		next.pressed.connect(func() -> void:
			hud.book.close_panel()
			Game.goals.claim(KEY))
		foot.add_child(next)
		content.add_child(foot), BookPanel.Shape.LIST, true)


## "Your farm is ready": the guided start is over and everything is open.
func _show_ready() -> void:
	hud.book.open_panel(tr("GUIDE_READY_TITLE"), func(content: VBoxContainer) -> void:
		content.name = READY_PANEL
		content.add_child(BookPanel.text(tr("GUIDE_READY_SAYS"), UiTheme.BODY))
		var go := hud.panel_button(tr("GUIDE_READY_GO"))
		go.name = "GuideGo"   # not-ui (a node's name)
		go.size_flags_horizontal = Control.SIZE_SHRINK_END
		go.pressed.connect(func() -> void: hud.book.close_panel())
		content.add_child(go), BookPanel.Shape.LIST, true)
	hud.ads.refresh()


## A panel up: the spotlight on the farm goes that moment, not a watch later (the book is made after the guide).
func _hear_book() -> void:
	if hud.book != null and not hud.book.opened.is_connected(_watch):
		hud.book.opened.connect(_watch)


## The bubble at the bottom-left over the tools, or (`high`) up at the left under the portrait.
func _place_strip(high: bool) -> void:
	_high = high
	var gap := UiTheme.size("hud_gap")
	if high:
		strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
		strip.grow_vertical = Control.GROW_DIRECTION_END
		strip.offset_top = FarmHud.top_h() + UiTheme.size("guide_high_drop")
		strip.offset_bottom = strip.offset_top
	else:
		strip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
		strip.offset_bottom = -FarmHud.bottom_h() - gap
		strip.offset_top = strip.offset_bottom
	strip.grow_horizontal = Control.GROW_DIRECTION_END
	strip.offset_left = gap
	strip.offset_right = gap


## Moves the bubble up when the spotlight falls under it, and back down when it doesn't.
func _dodge() -> void:
	var at := Vector2.INF
	for a in hud.find_children("*", "GuideArrow", true, false):   # not-ui (a class name)
		if (a as GuideArrow).target.is_valid():
			at = (a as GuideArrow).target.call()
	if at == Vector2.INF:
		return
	var reach := GuideArrow.hole_radius() * 2.0
	var under := strip.get_global_rect().grow(reach).has_point(at)
	if under:
		_place_strip(not _high)


## Whether a panel or a building's sheet is up (the bubble steps aside: the spotlight and hand show the way there).
func _covered() -> bool:
	return hud.book.is_open() or (hud.sheet != null and hud.sheet.is_open())


## Whether the arrow may be a spotlight now: guiding, nothing in hand, no other card (a level-up) over the farm.
func _spot_allowed() -> bool:
	if not guiding() or not _after_intro() or hud.interface_hidden:
		return false
	if hud.grid != null and (not hud.grid.placing.is_empty() or hud.grid.carrying_soon != ""):
		return false
	return not Game.modal_open or _covered()


func _clear_arrows() -> void:
	for a in hud.find_children("*", "GuideArrow", true, false):   # not-ui (a class name)
		a.queue_free()


## A pip a step: the done ones filled, this one in the accent, the rest empty.
func _fill_pips(step: int, steps: int) -> void:
	if _pips.get_child_count() != steps:
		for c in _pips.get_children():
			c.free()
		for k in steps:
			var pip := Panel.new()
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip.custom_minimum_size = Vector2(UiTheme.size("pip_w"), UiTheme.size("pip_h"))
			_pips.add_child(pip)
	for k in steps:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(UiTheme.size("pip_h") / 2.0))
		sb.bg_color = UiTheme.color("done" if k < step else ("accent" if k == step else "track"))
		(_pips.get_child(k) as Panel).add_theme_stylebox_override("panel", sb)
