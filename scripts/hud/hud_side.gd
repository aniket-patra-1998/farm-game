class_name HudSide
extends RefCounted
## The right side of the screen: the menu (Market, Collections, Ribbons, Neighbours, Settings) and, above the
## tools, Next ready and the whole-farm view. Nothing else: sound is in Settings, the interface rests by itself
## on an idle farm (Main's idle view), pinching zooms, and the neighbours wait in the inbox behind their button.

const SEEN := "seen"   # PlayerSettings section: what the player has already looked at (the menu's dots)
const READY_MOST := 99           # the Next ready count stops here ("99+")
const INBOX_CHECK := 300.0       # seconds between catching the neighbours' mail up (the inbox's count)

var hud: FarmHud
var menu: VBoxContainer
var zoom: HBoxContainer
var buttons := {}    # menu entry ("MARKET", "INBOX") -> its button (HudReveal shows them as goals need them)
var _ready: Button   # Next ready: goes to the nearest thing with something to take (hidden when nothing has)
var _ready_badge: Label   # how many there are
var _badge: Label   # the inbox's count on the Neighbours button
var _news := {}      # menu entry ("MARKET", "COLLECTIONS") -> its dot: something new inside


func _init(owner: FarmHud) -> void:
	hud = owner


func build(root: Control) -> void:
	var margin := UiTheme.size("hud_margin")
	var gap := UiTheme.size("hud_gap")
	var top := UiTheme.size("top_height") + margin

	menu = VBoxContainer.new()
	menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu.offset_right = -margin
	menu.offset_top = top + gap
	menu.add_theme_constant_override("separation", int(gap))
	root.add_child(menu)
	var w := UiTheme.size("side_width")
	var h := UiTheme.size("side_height")
	for entry: Array in [["market", "MARKET", hud.show_market], ["album", "COLLECTIONS", hud.show_collections],
			["ribbon", "RIBBONS", hud.show_ribbons], ["inbox", "INBOX", _show_neighbours],
			["gear", "SETTINGS", hud.show_settings]]:
		if (entry[1] == "COLLECTIONS" and not Release.on("collections")) or (entry[1] == "RIBBONS"
				and not Release.on("ribbons")):
			continue   # (not in this release: docs/V1.md)
		# Icon only (the name shows on a long press): the menu's pictures say what they are.
		var b := UiKit.tool_button(str(entry[0]), tr(str(entry[1])), w, h, 0.0, null, false)
		b.pressed.connect(entry[2])
		menu.add_child(b)
		buttons[str(entry[1])] = b
		if entry[1] in ["MARKET", "COLLECTIONS"]:
			var dot := UiKit.count_badge(b)
			dot.text = "!"   # not-ui (a sign, not a word)
			_news[entry[1]] = dot
			if entry[1] == "MARKET":
				b.pressed.connect(func() -> void:   # (opening the Market sees what is new in it)
					PlayerSettings.keep(SEEN, {"market_level": Game.level()})
					show_news())
		if entry[1] == "INBOX":
			_badge = UiKit.count_badge(b)   # how many things wait in the inbox
			Game.inbox_changed.connect(show_inbox_count)
			show_inbox_count()
			var mail := Timer.new()   # the neighbours' mail comes in through the day
			mail.wait_time = INBOX_CHECK
			mail.autostart = true
			mail.timeout.connect(func() -> void: Game.social.settle())
			b.add_child(mail)
			Game.social.settle.call_deferred()

	Game.leveled_up.connect(func(_l: int) -> void: show_news())
	Game.collections_changed.connect(show_news)
	show_news.call_deferred()

	zoom = HBoxContainer.new()
	zoom.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	zoom.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	zoom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	zoom.offset_right = -margin
	zoom.offset_bottom = -(UiTheme.size("bottom_height") + margin + gap)
	zoom.add_theme_constant_override("separation", int(gap))
	root.add_child(zoom)
	# Next ready (our own touch): one press goes to the nearest thing to collect or harvest, the next press to the
	# one after. It counts what is ready every couple of seconds, and is away when nothing is.
	_ready = UiKit.icon_button("ready", UiTheme.size("zoom_size"))
	_ready.pressed.connect(func() -> void:
		if hud.next_ready.is_valid():
			hud.next_ready.call()
		show_ready_count())
	zoom.add_child(_ready)
	_ready_badge = UiKit.count_badge(_ready)
	var count := Timer.new()
	count.wait_time = Balance.f("feel.ready_check_seconds")
	count.autostart = true
	count.timeout.connect(show_ready_count)
	_ready.add_child(count)
	show_ready_count.call_deferred()
	# The whole farm in one press (pinching zooms in and out; on a computer, the wheel).
	var fit := UiKit.icon_button("fit", UiTheme.size("zoom_size"))
	fit.pressed.connect(func() -> void: hud.zoom_view(0.0))
	zoom.add_child(fit)


## The dots on the menu: the Market has something new (unlocked since it was last opened), a collection can
## be traded in. Asked again when the level or the collections change.
func show_news() -> void:
	if not is_instance_valid(menu):   # (a HUD that has gone: the game's signals outlive it)
		return
	if _news.has("MARKET"):
		var seen := int(PlayerSettings.value(SEEN, "market_level", Game.level()))
		var fresh := false
		for id: String in Game.item_order:
			var at := int(Game.item_data(id).get("unlock_level", 0))
			if at > seen and at <= Game.level() and Release.has(id):
				fresh = true
				break
		(_news["MARKET"] as Label).get_parent().visible = fresh
		_glow(buttons.get("MARKET"), fresh)
	if _news.has("COLLECTIONS"):
		var full := false
		for coll in Game.collectibles.collections:
			full = full or Game.collectibles.can_trade_in(coll)
		(_news["COLLECTIONS"] as Label).get_parent().visible = full
		_glow(buttons.get("COLLECTIONS"), full)


## How many things are ready, on the Next ready button (the button is away when nothing is). Not counted while
## the interface is hidden: nobody is looking at the number.
func show_ready_count() -> void:
	if hud.grid == null or not zoom.is_visible_in_tree():
		return
	var n := hud.grid.ready_count()
	_ready.visible = n > 0 and Release.on("next_ready")   # (off in the first release: the owner's call)
	_ready_badge.text = str(mini(n, READY_MOST)) + ("+" if n > READY_MOST else "")   # not-ui


## The inbox's count on the Neighbours button (hidden when nothing waits).
func show_inbox_count() -> void:
	if not is_instance_valid(_badge):   # (a HUD that has gone: the game's signals outlive it)
		return
	var n := Game.social.inbox.size()
	_badge.text = str(n)
	_badge.get_parent().visible = n > 0
	_glow(buttons.get("INBOX"), n > 0)


## A menu button's picture glows blue-white while something new waits behind it (the owner's pick C).
static func _glow(button: Variant, waiting: bool) -> void:
	var icon := UiKit.icon_of(button as Control) if button is Control else null
	if icon != null:
		icon.fresh = waiting


## The neighbours' button and faces open the one inbox (their mail and your farm's gifts).
func _show_neighbours() -> void:
	hud.show_inbox()


## What hides with the rest of the interface.
func hideable() -> Array[Control]:
	var out: Array[Control] = [menu, zoom]
	return out
