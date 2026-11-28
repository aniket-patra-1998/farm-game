class_name HudAds
extends RefCounted
## Where the rewarded ads are offered on the farm itself (owner's picks 1 and 2, 28 Nov: the Barn's Boosts tab
## hid them): a Free gift button at the top of the side menu, with how far up the ladder it is (3/4, or a star
## when the next is rare), and a Revive button over the toolbar while crops are withered. Both show only while
## an ad is ready to play (AdOffers: the day's cap, a loaded ad); asked again every CHECK seconds and whenever the
## farm changes. Watch-for-coins sits in the Market (HudMarket.show_about). The rules are AdOffers'.

const CHECK := 2.0   # seconds between looks (an ad loads in the background)

var hud: FarmHud
var gift: Button     # the Free gift button (side menu)
var rescue: Button   # Revive the withered crops (over the toolbar)
var _gift_badge: Label


func _init(owner: FarmHud) -> void:
	hud = owner


func build(root: Control, menu: VBoxContainer) -> void:
	gift = UiKit.tool_button("gift", tr("AD_GIFT_BUTTON"), UiTheme.size("side_width"), UiTheme.size("side_height"),
		0.0, null, false)
	gift.name = "FreeGift"   # not-ui (a node's name)
	gift.pressed.connect(func() -> void:
		Feedback.moment("tap")
		Game.offers.watch_gift())
	menu.add_child(gift)
	menu.move_child(gift, 0)   # (first: where the eye lands under the meters)
	_gift_badge = UiKit.count_badge(gift)
	rescue = hud.panel_button("")
	rescue.name = "ReviveCrops"   # not-ui (a node's name)
	rescue.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	rescue.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rescue.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rescue.offset_bottom = -(UiTheme.size("bottom_height") + UiTheme.size("hud_margin") + UiTheme.size("hud_gap"))
	rescue.pressed.connect(func() -> void:
		Feedback.moment("tap")
		Game.offers.watch_rescue())
	root.add_child(rescue)
	var look := Timer.new()
	look.wait_time = CHECK
	look.autostart = true
	look.timeout.connect(refresh)
	gift.add_child(look)
	Game.plot_changed.connect(func(_i: int) -> void: refresh())
	Game.inventory_changed.connect(refresh)
	refresh.call_deferred()


## Shows each offer while it can be watched, with its words now.
func refresh() -> void:
	if gift == null or not is_instance_valid(gift):
		return
	gift.visible = Game.offers.gift_shown()
	_gift_badge.text = "★" if Game.offers.next_is_rare() else "%d/%d" % [   # not-ui (a sign and a count)
		Game.offers.step + 1, Balance.i("ads.ladder")]
	_gift_badge.get_parent().visible = gift.visible
	gift.tooltip_text = Game.offers.gift_words()
	var show_rescue := Game.offers.rescue_shown()
	if show_rescue:
		rescue.text = Game.offers.rescue_words()
	rescue.visible = show_rescue


## What hides with the rest of the interface when the farm rests.
func hideable() -> Array[Control]:
	return [gift, rescue] if gift != null else []
