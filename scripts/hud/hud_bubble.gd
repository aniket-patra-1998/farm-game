class_name HudBubble
extends PanelContainer
## What a tapped thing says, right above it (FarmVille's way, not a panel), as floating words with no box
## (FloatText): its name, one line (ready in 14 h, withered, needs feed), and small round icon buttons beside them
## for what can be done there (Feed, Expand) or more about it (its panel). It follows the thing as the view
## moves, rises in, and goes after a few seconds, when another thing is tapped, or when a panel opens.

const SHOW_FOR := 3.0         # seconds a bubble stays..
const SHOW_FOR_ACTION := 5.0  # ..and with a button to press
const GAP := 6.0              # px between the bubble's point and the thing
const EDGE := 8.0             # px the bubble keeps from the screen's edges (a thing tapped at an edge)
const WRAP_AFTER := 26        # characters past which a bubble's words wrap (at ui_theme's `bubble_width`)

var hud: FarmHud
var to_screen: Callable       # grid space -> screen, from the farm (FarmMain)
var _at := Vector2.ZERO
var _uid := -1
var _rusty := ""           # the vehicle whose repair this bubble offers (show_repair), or ""
var _left := 0.0
var _title: Label
var _line: Label
var _open: Button
var _act: Button          # the one thing to do right here (Feed), done from the bubble itself
var _rise := 0.0          # px still to rise as it comes in


func _init(owner: FarmHud) -> void:
	hud = owner
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())   # (no box: the words float)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)
	_title = FloatText.label("", 20)
	col.add_child(_title)
	_line = FloatText.label("", 16, UiTheme.color("float_line"))
	col.add_child(_line)
	_open = FloatText.action("info", tr("BUBBLE_OPEN"))
	_open.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_open.pressed.connect(func() -> void:
		var uid := _uid
		close()
		hud.show_building(uid))
	_act = FloatText.action("feed", "")
	_act.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_act.pressed.connect(func() -> void:
		var deed := repair_of(_rusty) if _rusty != "" else action_of(Game.object_by_uid(_uid))
		close()
		if not deed.is_empty():
			(deed["do"] as Callable).call())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", int(UiTheme.size("hud_gap")))
	buttons.add_child(_act)
	buttons.add_child(_open)
	col.add_child(buttons)
	visible = false


## Shows `title` and `line` over grid point `at`; `uid` the thing (-1: a plot), offering its panel when it has one.
func show_at(at: Vector2, title: String, line: String, uid: int) -> void:
	_uid = uid
	_rusty = ""
	var o := Game.object_by_uid(uid) if uid >= 0 else {}
	_present(at, title, line, has_panel(o), action_of(o))


## Offers the repair of rusty vehicle `id` over grid point `at` (its rust sign was tapped; docs/RUST.md): what it
## costs and how long it takes, and the one button that starts it. Nothing more: the vehicle's own bubble and
## sheet are a tap on the vehicle.
func show_repair(at: Vector2, id: String) -> void:
	var uid := WearSystem.uid_of(id)
	if uid >= 0:
		_show_wear_repair(at, uid, id)
		return
	var cost := Game.rust.repair_cost(id)
	if cost.is_empty():
		return
	_uid = -1
	_rusty = id
	_present(at, str(Game.item_data(id)["name"]), tr("RUST_REPAIR_BUTTON") % [int(cost["coins"]),
		FarmGrid.format_duration(int(cost["seconds"]))], false, repair_of(id))


## A worn building's repair (docs/WEAR.md): how worn, what it costs (coins and materials), how long, one button.
func _show_wear_repair(at: Vector2, uid: int, key: String) -> void:
	var cost := Game.wear.repair_cost(uid)
	var o := Game.object_by_uid(uid)
	if cost.is_empty() or o.is_empty():
		return
	var parts: String = BuildingSystem.describe(cost["materials"])
	_uid = -1
	_rusty = key
	_present(at, Game.name_of(str(o["id"])), (tr("WEAR_LEVEL") % [Game.wear.level_of(o), Game.wear.max_level()])
		+ "  " + tr("WEAR_REPAIR_BUTTON") % [UiTheme.number(int(cost["coins"])),
		tr("WEAR_REPAIR_PARTS") % parts if parts != "" else "", FarmGrid.format_duration(int(cost["seconds"]))],
		false, repair_of(key))


## The bubble itself: `title` and `line` over `at`, with the button to its panel (`open`) and the one for `deed`
## (see action_of; {} for none).
func _present(at: Vector2, title: String, line: String, open: bool, deed: Dictionary) -> void:
	_at = at
	_title.text = UiTheme.tidy(title)
	_line.text = UiTheme.tidy(line)
	# A long word (a reason something can't be done) wraps at a set width; a name stays on one line.
	var long := title.length() > WRAP_AFTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if long else TextServer.AUTOWRAP_OFF
	_title.custom_minimum_size.x = UiTheme.size("bubble_width") if long else 0.0
	_line.visible = line != ""
	_open.visible = open
	_act.visible = not deed.is_empty()
	if _act.visible:   # (its picture says what; its words are its long-press name)
		(_act.get_meta("icon") as UiIcon).kind = str(deed["icon"])
		_act.tooltip_text = str(deed["words"])   # (its long-press name: UiKit.long_press_name reads it)
	_left = SHOW_FOR_ACTION if _open.visible or _act.visible else SHOW_FOR
	# Comes in afresh for each thing tapped, in the interface's one motion, rising a little into place (its place
	# is kept by _follow; the rise is an offset that eases off).
	UiFx.open_with(self, _look, true)
	reset_size()
	_follow()


func close() -> void:
	UiFx.close(self)   # (it fades out, still following its thing)
	_uid = -1
	_rusty = ""


func _look(share: float) -> void:
	_rise = FloatText.RISE * (1.0 - share)
	modulate.a = share
	_follow()


## Whether a placed thing has a panel worth opening from its bubble: a building (its yard, its recipes, its
## level), a young one or a bloom (what it needs, buying more), a vehicle (its fuel). An animal or a tree has
## nothing more than its bubble says; feeding is the bubble's own button (`action_of`).
static func has_panel(o: Dictionary) -> bool:
	if o.is_empty() or Game.kind_of(o) in ["decor", "animal", "tree"]:
		return false
	return (Game.is_building_item(str(o["id"])) or Game.nurture.is_young(o) or Game.kind_of(o) in ["bloom", "vehicle"]
		or Game.nurture.supply_for(o) != "")


## The one thing to do for `o` right from its bubble, as {"words", "do"}, or {}: expand a building that can grow
## now, or feed a hungry animal or home with the best feed in the Barn, for more coins (the first effect),
## queued for the farmer as any farm work.
static func action_of(o: Dictionary) -> Dictionary:
	if o.is_empty():
		return {}
	var uid := int(o["uid"])
	if Game.is_building_item(str(o["id"])) and not Game.under_construction(o) and Game.buildings.can_expand(o).ok():
		# A building that can grow now (its parts in, the coins there): Expand, right from its bubble.
		return {"words": TranslationServer.translate("EXPAND"), "icon": "up",
			"do": func() -> void: Game.land.upgrade_building(uid)}
	if not Game.feeds.is_feedable(o) or not Game.feeds.effect_of(o).is_empty():
		return {}
	var best := Game.feeds.best_feed_for(o)
	if best.is_empty():
		return {}
	var effect := str(Game.feeds.effects()[0])
	return {"words": TranslationServer.translate("BUBBLE_FEED"), "icon": "feed", "do": func() -> void:
		Game.player.enqueue({"kind": "feed", "uid": uid, "feed": best["feed"], "effect": effect,
			"rich": best["rich"]})}


## The repair of rusty vehicle `id` as a bubble's one thing to do (as action_of): it starts now, for coins.
static func repair_of(id: String) -> Dictionary:
	var uid := WearSystem.uid_of(id)
	return {"words": TranslationServer.translate("RUST_REPAIR"), "icon": "repair", "do": func() -> void:
		if uid >= 0:
			if not Game.wear.repair(uid):
				Game.message.emit(Game.wear.repair_short(uid))
		elif not Game.rust.repair(id):
			Game.message.emit(TranslationServer.translate("RUST_REPAIR_NO_COINS"))}


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if (_left <= 0.0 or Game.modal_open) and UiFx.is_open(self):
		close()
	_follow()


func _follow() -> void:
	if not to_screen.is_valid():
		return
	var p: Vector2 = to_screen.call(_at)
	# (screen space: the HUD root may sit inside safe insets)
	var at := p - Vector2(size.x / 2.0, size.y + GAP - _rise)
	var view := get_viewport().get_visible_rect().grow(-EDGE)
	if at.y < view.position.y:   # (no room above a thing at the top: it shows below it)
		at.y = p.y + GAP + _rise
	at.x = clampf(at.x, view.position.x, maxf(view.position.x, view.end.x - size.x))
	at.y = clampf(at.y, view.position.y, maxf(view.position.y, view.end.y - size.y))
	global_position = at
