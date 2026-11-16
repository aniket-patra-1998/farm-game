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
	var head := VBoxContainer.new()
	content.add_child(head)
	var list := CardList.rows(_ids(), func() -> Control: return MarginContainer.new(),
		func(row: Control, id: String) -> void: CardList.refill(row, line_for(_item(int(id)))))
	list.search_menu = "inbox"
	list.search_words = func(id: String) -> Dictionary: return words_of(_item(int(id)))
	content.add_child(list)
	var update := func() -> void:
		CardList.refill(head, _head())
		list.set_ids(_ids())
		list.visible = not list.ids.is_empty()
		list.refresh()
	update.call()
	BookPanel.set_live(content, update)


## Accept all and the helps left today, or a word that there is nothing.
func _head() -> Control:
	var col := VBoxContainer.new()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	var all := hud.panel_button(tr("INBOX_ACCEPT_ALL"))
	all.disabled = Game.social.inbox.is_empty()
	all.pressed.connect(func() -> void:
		Game.social.help_all()
		hud.book.refresh())
	all.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(all)
	var left := BookPanel.text(tr("INBOX_HELPS_LEFT") % Game.social.helps_left(), 18, BookPanel.SOFT)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # (a wrapping label in a row needs its width)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(left)
	col.add_child(head)
	if Game.social.inbox.is_empty():
		col.add_child(BookPanel.info(tr("INBOX_EMPTY"), tr("INBOX_EMPTY_INFO"), 20, BookPanel.SOFT))
	return col


## The inbox item with `id` (a line on screen being filled).
func _item(id: int) -> Dictionary:
	for item: Dictionary in Game.social.inbox:
		if int(item["id"]) == id:
			return item
	return {}


## The inbox's item ids, newest first.
func _ids() -> Array[String]:
	var out: Array[String] = []
	for k in range(Game.social.inbox.size() - 1, -1, -1):
		out.append(str(Game.social.inbox[k]["id"]))
	return out


## One inbox item as a line (flat on the panel, a thin line between: CardList rows): who, what, and its button.
## How an inbox line is found: what it gives (its item's words) and who sent it.
func words_of(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	var give: Dictionary = item.get("give", {})
	var w := ItemSearch.words_of(str(give.get("id", "")))
	return {"name": str(w.get("name", "")), "more": "%s %s" % [w.get("more", ""), _who(item)]}   # not-ui


func line_for(item: Dictionary) -> Control:
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
		var thing := UiKit.count_row([[str(give["id"]), "×%d" % int(give.get("n", 1))]])
		thing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(thing)
	# Just who sent it (the picture, the count and the button say the rest); a thing from your own farm says
	# what waits for you instead ("A Cow is waiting", then Place).
	var label := _who(item)
	if from == InboxItem.FARM and what == InboxItem.ITEM:
		label = tr("INBOX_WAITING") % str(Game.item_data(str(give["id"])).get("name", ""))
	var words := BookPanel.text(label, 18)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.autowrap_mode = TextServer.AUTOWRAP_OFF   # (one line, trimmed: every line of the list is one height)
	words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.clip_text = true
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_color_override("font_color", BookPanel.SOFT)
	row.add_child(words)
	var id := int(item["id"])
	var button := hud.panel_button(tr(button_key(item)))
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = InboxItem.is_help(item) and Game.social.helps_left() <= 0
	button.pressed.connect(func() -> void: _take(id, what == InboxItem.ITEM))
	row.add_child(button)
	return row


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
		hud.book.refresh()
		return
	if place:
		hud.book.close_panel()
		hud.place_stored_requested.emit(Game.storage.stored.size() - 1)
	else:
		hud.book.refresh()
