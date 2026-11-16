class_name HudSeeds
extends RefCounted
## The seed list the Plant tool opens (FarmVille's Market seeds tab): every crop with its price, time and
## pollinated seeds; picking one puts it in hand to plant on plowed plots. Locked crops say their level.

var hud: FarmHud
var _ids: Array[String] = []   # the crops in this release, in order, worked out once at load


func _init(owner: FarmHud) -> void:
	hud = owner
	for id: String in Game.crop_order:
		if Release.has(id):
			_ids.append(id)


func build_seeds(content: VBoxContainer) -> void:
	content.add_child(BookPanel.text(tr("PICK_A_SEED_THEN_TAP_PLOWED_PLOTS"), UiTheme.BODY, BookPanel.SOFT))
	if Season.enabled() and Game.level() >= Balance.i("seasons.from_level"):
		content.add_child(BookPanel.text(tr("SEASON_SHELF") % [tr("SEASON_" + Game.season().to_upper()),
			roundi((Balance.f("seasons.off_price_mult") - 1.0) * 100.0)], 18, BookPanel.SOFT))
	var list := CardList.make(_ids, seed_face, func(id: String) -> void:
		if Game.is_unlocked(id):
			hud.choose_seed(id), hud.get_viewport().get_visible_rect().size.x)
	list.search_menu = "seeds"
	content.add_child(list)
	BookPanel.set_live(content, list.refresh)


## One crop's card face, as FarmVille's seed shelf showed it: its picture, its mastery stars, its name, how long
## it grows and what it sells for, and its seed price (free while pollinated seeds last); tapping picks it.
func seed_face(id: String) -> Dictionary:
	var crop: Dictionary = Game.crops[id]
	var locked := not Game.is_unlocked(id)
	var pol := Game.bees.pollinated_seeds(id)
	var badge: Array
	if locked:
		badge = ["lock", tr("UNLOCKS_LEVEL") % int(crop["unlock_level"])]
	elif pol > 0:
		badge = ["", tr("FREE_SEEDS_LEFT") % pol]
	else:
		badge = ["coin", UiTheme.number(int(crop["seed_cost"])), Game.coins < int(crop["seed_cost"])]
	# The season's price board (our own touch): an off-season crop shows what it sells for now, and says why.
	var off := Game.off_season(id)
	var sells := roundi(int(crop["sell_price"]) * (Balance.f("seasons.off_price_mult") if off else 1.0))
	return {
		"name": str(crop["name"]),
		"line": tr("SEED_CARD_OFF" if off else "SEED_CARD") % [FarmGrid.format_duration(int(crop["grow_seconds"])), sells],
		"badge": badge,
		"locked": locked,
		"stars": MasteryStars.values(id),
		"buyable": not locked,
	}
