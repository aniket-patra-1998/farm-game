class_name HudSeeds
extends RefCounted
## The seed list the Plant tool opens (FarmVille's Market seeds tab): every crop with its price, time and
## pollinated seeds; picking one puts it in hand to plant on plowed plots. Locked crops say their level.

const NEXT_LOCKED := 3   # locked seeds the shelf shows, the next to unlock

var hud: FarmHud
var _ids: Array[String] = []   # the crops in this release, in order, worked out once at load


func _init(owner: FarmHud) -> void:
	hud = owner
	for id: String in Game.crop_order:
		if Release.has(id) and not Game.crops[id].get("starter", false):
			_ids.append(id)


func build_seeds(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text(tr("PICK_A_SEED_THEN_TAP_PLOWED_PLOTS"), UiTheme.BODY, BookPanel.SOFT))
	if Season.enabled() and Game.level() >= Balance.i("seasons.from_level"):
		content.add_child(BookPanel.text(tr("SEASON_SHELF") % [tr("SEASON_" + Game.season().to_upper()),
			roundi((Balance.f("seasons.off_price_mult") - 1.0) * 100.0)], UiTheme.HEADING, BookPanel.SOFT))
	var list := CardList.make(gifts() + shelf(), seed_face, func(id: String) -> void:
		if Game.can_plant(id):
			hud.choose_seed(id), hud.get_viewport().get_visible_rect().size.x)
	list.search_menu = "seeds"
	content.add_child(list)
	var later := _ids.size() - shelf().size()
	if later > 0:   # (the rest, folded: a young farm's shelf is what it can plant, not a wall of locks)
		content.add_child(BookPanel.text(tr("SEEDS_LATER") % later, UiTheme.BODY, BookPanel.SOFT))
	BookPanel.set_live(content, list.refresh)


## What the shelf shows (owner, 19 Nov: 19 of 22 cards were locks on day one): every seed that can be planted,
## then the next NEXT_LOCKED to unlock, soonest first; the search still finds them all.
func shelf() -> Array[String]:
	var out: Array[String] = []
	var locked: Array[String] = []
	for id in _ids:
		(out if Game.can_plant(id) else locked).append(id)
	locked.sort_custom(func(a: String, b: String) -> bool:
		return int(Game.crops[a]["unlock_level"]) < int(Game.crops[b]["unlock_level"]))
	out.append_array(locked.slice(0, NEXT_LOCKED))
	return out


## One crop's card face, as FarmVille's seed shelf showed it: its picture, its mastery stars, its name, how long
## it grows and what it sells for, and its seed price (free while pollinated seeds last); tapping picks it.
## The crops in this release, in order (what the Seeds shelf shows; the Market's search looks among them too).
func ids() -> Array[String]:
	return _ids


## Seeds a goal gave (Starter Seeds), first on the shelf while any are held; never sold.
func gifts() -> Array[String]:
	var out: Array[String] = []
	for id: String in Game.crop_order:
		if Game.crops[id].get("starter", false) and Game.goals.seeds_of(id) > 0:
			out.append(id)
	return out


func seed_face(id: String) -> Dictionary:
	var crop: Dictionary = Game.crops[id]
	var locked := not Game.can_plant(id)
	var pol := Game.bees.pollinated_seeds(id) + Game.goals.seeds_of(id)
	var badge: Array
	if locked:
		badge = ["lock", tr("UNLOCKS_LEVEL") % int(crop["unlock_level"])]
	elif pol > 0:
		badge = ["", tr("FREE_SEEDS_LEFT") % pol]
	else:
		badge = ["coin", UiTheme.number(int(crop["seed_cost"])), Game.coins < int(crop["seed_cost"])]
	# The season's price board (our own touch): an off-season crop shows what it sells for now, and says why.
	var off := Game.off_season(id)
	var sells := Game.field.sells_for(id, off)   # (what a harvest pays now: mastery stars and the season counted)
	var line := tr("SEED_CARD_OFF" if off else "SEED_CARD") % [FarmGrid.format_duration(int(crop["grow_seconds"])), sells]
	return {
		"name": str(crop["name"]),
		"line": line,
		# Off-season, its line is green (the shelf's note says why): a narrow card may leave the words off.
		"line_colour": BookPanel.GOOD if off else "tool_label",
		"long": "%s: %s" % [crop["name"], line],
		"badge": badge,
		"locked": locked,
		"stars": MasteryStars.values(id),
		"buyable": not locked,
	}
