class_name HudInbox
extends RefCounted
## The one inbox (our own touch: FarmVille had a news feed and a separate Gift Box; here they are one place): what
## neighbours send (gifts, answers to your requests, shares) and what they ask for help with, and what your own
## farm sends (a baby grown up in the nursery). Each line shows who sent it (their portrait, or the barn for your
## farm), what it is (with its picture when it is a thing), and one button: Accept, Place (a thing goes straight
## into your hand to put down), or Help (a neighbour's ask, paid, as many a day as the day allows). "Accept all"
## does every free one and every help the day allows. Opening it (not each refresh: what Accept all took must not
## be refilled at once from mail held back while the inbox was full) catches the neighbours up (SocialSystem.settle).

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner


func build_inbox(content: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	var all := hud._panel_button(tr("INBOX_ACCEPT_ALL"))
	all.disabled = Game.social.inbox.is_empty()
	all.pressed.connect(func() -> void:
		Game.social.help_all()
		hud._book.refresh())
	all.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(all)
	var left := BookPanel.text(tr("INBOX_HELPS_LEFT") % Game.social.helps_left(), 18, BookPanel.CREAM)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # (a wrapping label in a row needs its width)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(left)
	content.add_child(head)
	if Game.social.inbox.is_empty():
		content.add_child(BookPanel.info(tr("INBOX_EMPTY"), tr("INBOX_EMPTY_INFO"), 20, BookPanel.CREAM))
		return
	var items := Game.social.inbox.duplicate()
	items.reverse()   # (newest first)
	for item: Dictionary in items:
		content.add_child(line_for(item))


## One inbox item as a card: who, what, and its button.
func line_for(item: Dictionary) -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var from := int(item.get("from", 0))
	var who: Control
	if from == InboxItem.FARM:
		who = UiIcon.make("barn", UiTheme.size("inbox_face"))
	else:
		who = PortraitIcon.of(Game.social.look_of(Game.social.sender(item)), UiTheme.size("inbox_face"))
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(who)
	var give: Dictionary = item["give"]
	var what := str(give.get("what", ""))
	if what in [InboxItem.ITEM, InboxItem.YOUNG, InboxItem.PART]:
		row.add_child(UiKit.count_row([[str(give["id"]), "×%d" % int(give.get("n", 1))]]))
	# Just who sent it (the picture, the count and the button say the rest); a thing from your own farm says
	# what waits for you instead ("A Cow is waiting", then Place).
	var label := _who(item)
	if from == InboxItem.FARM and what == InboxItem.ITEM:
		label = tr("INBOX_WAITING") % str(Game.item_data(str(give["id"])).get("name", ""))
	var words := BookPanel.text(label, 18)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(words)
	var id := int(item["id"])
	var button := hud._panel_button(tr(button_key(item)))
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = InboxItem.is_help(item) and Game.social.helps_left() <= 0
	button.pressed.connect(func() -> void: _take(id, what == InboxItem.ITEM))
	row.add_child(button)
	var card := BookPanel.card()
	card.add_child(row)
	return BookPanel.card_frame(card)


## Who sent it: a neighbour's name, or your farm.
func _who(item: Dictionary) -> String:
	return tr("INBOX_YOUR_FARM") if int(item.get("from", 0)) == InboxItem.FARM else Game.social.sender(item)


## What a line says: "Maple sent you 2 Bricks", "Your farm: a Cow, grown up in the nursery", "Barley asks for 3 Nails".
func sentence(item: Dictionary) -> String:
	var who := Game.social.sender(item)
	var thing := Game.social.words(item["give"])
	if int(item.get("from", 0)) == InboxItem.FARM:
		return tr("INBOX_LINE_FARM") % thing
	match str(item.get("kind", "")):
		InboxItem.REQUEST:
			return tr("INBOX_LINE_REQUEST") % [who, thing]
		InboxItem.ANSWER:
			return tr("INBOX_LINE_ANSWER") % [who, thing]
		InboxItem.SHARE:
			return tr("INBOX_LINE_COLLAB" if bool(item.get("collab", false)) else "INBOX_LINE_SHARE") % [who, thing]
	return tr("INBOX_LINE_GIFT") % [who, thing]


## The button's word: Help for a neighbour's ask, Place for a thing to put down, else Accept.
static func button_key(item: Dictionary) -> String:
	if InboxItem.is_help(item):
		return "INBOX_HELP"
	return "INBOX_PLACE" if str(item["give"].get("what", "")) == InboxItem.ITEM else "INBOX_ACCEPT"


## Claims item `id`; a thing to place goes from the Barn straight into the player's hand.
func _take(id: int, place: bool) -> void:
	if not Game.social.claim(id):
		hud._book.refresh()
		return
	if place:
		hud._book.close_panel()
		hud.place_stored_requested.emit(Game.storage.stored.size() - 1)
	else:
		hud._book.refresh()
