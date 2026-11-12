class_name HudFeed
extends RefCounted
## Feeding animals (FeedSystem): the feed card on an animal home or a loose animal, and the feed the Barn holds.
## Builds its content into the book panel; shared helpers (buttons, messages) are on `hud`.

const EFFECT_NAMES := {"produce": "EFFECT_PRODUCE", "speed": "EFFECT_SPEED", "rare": "EFFECT_RARE"}
const PROBLEM_TEXT := {
	"NOT_AN_ANIMAL_HOME": "NOT_AN_ANIMAL_HOME", "IT_WON_T_EAT_THAT": "IT_WON_T_EAT_THAT",
	"NOT_ENOUGH_FEED": "NOT_ENOUGH_FEED", "ALREADY_WELL_FED": "ALREADY_WELL_FED", "COLLECT_IT_FIRST": "COLLECT_IT_FIRST",
}

var hud: FarmHud


func _init(owner: FarmHud) -> void:
	hud = owner


## A loose animal that isn't ready: what it is, then its feed card.
func build_animal(content: VBoxContainer) -> void:
	var o := Game.object_by_uid(hud._building_uid)
	if o.is_empty():
		hud._book.close_panel()
		return
	var it := Game.item_data(o["id"])
	var card := BookPanel.card()
	card.add_child(BookPanel.text(it["name"], 22))
	card.add_child(BookPanel.text(tr("READY_IN_4") + FarmGrid.format_duration(Game.seconds_until_ready(o)), 18))
	content.add_child(BookPanel.card_frame(card))
	add_feed_card(content, o)


## How it is fed now, and what feeding it (with what, for which effect) would do.
func add_feed_card(content: VBoxContainer, o: Dictionary) -> void:
	if not Game.feeds.is_feedable(o):
		return
	var uid := int(o["uid"])
	var card := BookPanel.card()
	card.add_theme_constant_override("separation", 8)
	card.add_child(BookPanel.text(tr("FEEDING_OUR_OWN_TOUCH"), 22))
	card.add_child(BookPanel.text(_status(o), 18))
	var any := false
	for f in Game.feeds.feed_ids():
		if Game.feeds.grade(o, f) <= 0.0:
			continue
		for rich in [false, true]:
			if Game.feeds.count(f, rich) <= 0:
				continue
			any = true
			var liking := tr("FAVOURITE") if Game.feeds.grade(o, f) >= 1.0 else tr("ACCEPTED")
			card.add_child(BookPanel.text(tr("FEED_LINE") % [Game.feeds.feed_name(f, rich),
				Game.feeds.count(f, rich), liking, Game.feeds.units_needed(o)], 18))
			var row := HFlowContainer.new()
			row.add_theme_constant_override("h_separation", 10)
			row.add_theme_constant_override("v_separation", 10)
			for effect: String in Game.feeds.effects():
				row.add_child(_effect_button(o, uid, f, effect, rich))
			card.add_child(row)
	if not any:
		card.add_child(BookPanel.text(tr("NO_FEED_THIS_ONE_LIKES_FARM_CROPS"), 18))
	content.add_child(BookPanel.card_frame(card))


func _status(o: Dictionary) -> String:
	var fx := Game.feeds.effect_of(o)
	if fx.is_empty():
		return tr("HUNGRY_COLLECTS_LESS") % roundi(Balance.f("feeds.hunger_penalty") * 100.0)
	return tr("FED_FOR_THIS_ROUND") % [tr(EFFECT_NAMES[str(fx["effect"])]), roundi(float(fx["power"]) * 100.0)]


func _effect_button(o: Dictionary, uid: int, feed: String, effect: String, rich: bool) -> Button:
	var p := Game.feeds.power(effect, Game.feeds.grade(o, feed), rich)
	var b := hud._panel_button("%s +%d%%" % [tr(EFFECT_NAMES[effect]), roundi(p * 100.0)])
	var why := Game.feeds.problem(o, feed, effect, rich)
	if why != "":
		b.disabled = true
		b.tooltip_text = tr(PROBLEM_TEXT.get(why, why))
	b.pressed.connect(func() -> void:
		Game.player.enqueue({"kind": "feed", "uid": uid, "feed": feed, "effect": effect, "rich": rich})
		hud._book.close_panel())
	return b


## What the Barn holds of each feed, and what each is for.
func add_barn_stock(content: VBoxContainer) -> void:
	if not Game.feeds.enabled():
		return
	var card := BookPanel.card()
	card.add_child(BookPanel.text(tr("FEED_IN_THE_BARN") % Game.feeds.cap(), 20))
	for f in Game.feeds.feed_ids():
		var line := "%s %d" % [Game.feeds.feed_name(f), Game.feeds.count(f)]
		if Game.feeds.count(f, true) > 0:
			line += "  (+%d %s)" % [Game.feeds.count(f, true), tr("RICH")]
		card.add_child(BookPanel.text(line, 17))
	content.add_child(BookPanel.card_frame(card))


## The layout line of a building panel (our own touch): how many of its own kind touch it and what that pays.
## "" when its kind has no synergy or the feature is off.
func layout_line(o: Dictionary) -> String:
	if not Game.adjacency.is_on() or Game.adjacency.group_of(str(o["id"])).is_empty():
		return ""
	var n := Game.adjacency.count(o)
	return tr("SYNERGY_LINE") % [n, roundi(Game.adjacency.bonus_for(str(o["id"]), n) * 100.0)]


## The boost lines of a building panel (our own touch): what this home gives back to the farm once stocked.
func boost_line(o: Dictionary) -> String:
	if not Game.boosts.is_on():
		return ""
	var given := Game.boosts.given_by(o)
	if given.is_empty():
		return ""
	var parts: Array[String] = []
	for b: String in given:
		parts.append(tr("BOOST_" + b.to_upper()) % roundi(float(given[b]) * 100.0))
	return tr("BOOST_LINE") % ", ".join(parts)
