class_name FeedSystem
extends GameSystem
## Feeding animals (our own touch, not FarmVille 2009: Balance `feeds.enabled` 0 turns all of it off).
## Part of the game state: reached as `Game.feeds`; shared state is on `game`.
##
## The field makes five feeds (data/feeds.json): harvesting a crop drops its family's feed now and then, a tree
## gives Fruit. They are kept in the Barn up to a cap. Each animal family takes some feeds as favourite and
## some as accepted (half the effect). Feeding a loose animal, or a home (one unit feeds a few animals inside),
## gives it ONE effect for its current cycle: more coins from the next collect, a shorter cycle, or better odds
## of a rare find. An animal not fed that cycle gives fewer coins (never none). A farmhand feeds every hungry
## animal in one go (Game.use_helper). Rich feed comes from golden, super or pollinated harvests.
##
## A fed object carries `fed`: {"effect", "power", "t"} where `t` is its cycle's start, so the effect ends by
## itself when the animal is collected (its `t` moves on).

const DATA := "res://data/feeds.json"
## The field a fed object carries (young ones already use "fed" for the supplies they were given).
const FED := "feed_fx"
const RICH := "rich_"       # a stock key for the Rich kind of a feed: "rich_grain"

var stock := {}             # feed id (or RICH + feed id) -> units kept
## While an animal or home is being collected: the chance multiplier its feed gives to rare finds (1 when none).
var rare_boost := 1.0
## The farm's own switch for feeding, on top of Balance `feeds.enabled`: tests turn it off for exact payouts.
var active := true

var _feeds := {}            # feed id -> {"name", "color"}
var _crop_feed := {}        # crop family -> feed id
var _tree_feed := ""
var _tastes := {}           # animal family -> {"favourite": [...], "accepted": [...]}
var _effects: Array = []


func _init(owner: GameState) -> void:
	super(owner)


func load_data() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var d: Dictionary = parsed if parsed is Dictionary else {}
	_feeds = d.get("feeds", {})
	_crop_feed = d.get("crop_families", {})
	_tree_feed = str(d.get("tree_feed", ""))
	_tastes = d.get("tastes", {})
	_effects = d.get("effects", [])


func reset() -> void:
	stock = {}
	rare_boost = 1.0


func save_to(data: Dictionary) -> void:
	data["feed_stock"] = stock


func load_from(data: Dictionary) -> void:
	stock = GameSystem.int_map(data.get("feed_stock", {}))


# ---------------------------------------------------------------- what exists


func enabled() -> bool:
	return active and Balance.i("feeds.enabled") != 0


func feed_ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in _feeds:
		out.append(k)
	return out


func effects() -> Array:
	return _effects


func feed_name(feed: String, rich := false) -> String:
	var n := tr(str(_feeds.get(feed, {}).get("name", feed)))
	return tr("RICH_FEED") % n if rich else n


func feed_color(feed: String) -> Color:
	return Color.html(str(_feeds.get(feed, {}).get("color", "#ffffff")))


func crop_feed(crop_id: String) -> String:
	return str(_crop_feed.get(str(game.crops.get(crop_id, {}).get("family", "")), ""))


## Which animal families take which feed: 1 favourite, accepted_share an accepted one, 0 refused.
func taste(family: String, feed: String) -> float:
	var t: Dictionary = _tastes.get(family, {})
	if feed in (t.get("favourite", []) as Array):
		return 1.0
	if feed in (t.get("accepted", []) as Array):
		return Balance.f("feeds.accepted_share")
	return 0.0


# ---------------------------------------------------------------- the Barn's stock


func cap() -> int:
	var level := 1
	for o in game.objects:
		if str(o["id"]) == "barn":
			level = game.level_of(o)
	return Balance.i("feeds.stock_cap") + Balance.i("feeds.cap_per_barn_level") * (level - 1)


func count(feed: String, rich := false) -> int:
	return int(stock.get((RICH if rich else "") + feed, 0))


func total(feed: String) -> int:
	return count(feed) + count(feed, true)


## Puts one unit in the Barn; at the cap it is sold instead. Returns whether it was kept.
func add(feed: String, rich := false) -> bool:
	if total(feed) >= cap():
		game.add_coins(Balance.i("feeds.overflow_coins"))
		return false
	var key := (RICH if rich else "") + feed
	stock[key] = int(stock.get(key, 0)) + 1
	game.inventory_changed.emit()
	return true


func _take(feed: String, rich: bool, n: int) -> void:
	var key := (RICH if rich else "") + feed
	stock[key] = maxi(0, int(stock.get(key, 0)) - n)


## Is there an animal on the farm that would take this feed? (A farm with none sees no feed drop.)
func has_taker(feed: String) -> bool:
	for o in game.objects:
		for fam in families_in(o):
			if taste(fam, feed) > 0.0:
				return true
	return false


# ---------------------------------------------------------------- finding feed


## A crop was harvested: now and then one unit of its family's feed, Rich from a golden, super or pollinated one.
## Returns the feed's id, or "" for none.
func roll_harvest(crop_id: String, stars: int, rich: bool) -> String:
	var feed := crop_feed(crop_id)
	if feed == "" or not enabled() or not game.drops_enabled or not has_taker(feed):
		return ""
	var chance := Balance.f("feeds.chance_base") + Balance.f("feeds.chance_per_star") * stars \
		+ game.boosts.total("feed_chance")
	if game.rng.randf() >= chance:
		return ""
	add(feed, rich)
	return feed


## A tree was collected: now and then one Fruit.
func roll_tree() -> String:
	if _tree_feed == "" or not enabled() or not game.drops_enabled or not has_taker(_tree_feed):
		return ""
	if game.rng.randf() >= Balance.f("feeds.tree_chance"):
		return ""
	add(_tree_feed)
	return _tree_feed


# ---------------------------------------------------------------- who can be fed


## The animal families in an object: a loose animal's own, a home's animals (family -> how many).
func family_counts(obj: Dictionary) -> Dictionary:
	var out := {}
	if obj.is_empty():
		return out
	if game.is_home(obj):
		var inside: Dictionary = obj.get("inside", {})
		for id: String in inside:
			var fam := str(game.item_data(id).get("family", ""))
			if _tastes.has(fam) and int(inside[id]) > 0:
				out[fam] = int(out.get(fam, 0)) + int(inside[id])
	elif game.kind_of(obj) == "animal":
		var fam2 := str(game.item_data(obj["id"]).get("family", ""))
		if _tastes.has(fam2):
			out[fam2] = 1
	return out


func families_in(obj: Dictionary) -> Array:
	return family_counts(obj).keys()


## Does this object keep animals that eat (and so can be fed, and go hungry)?
func is_feedable(obj: Dictionary) -> bool:
	return enabled() and not game.under_construction(obj) and not family_counts(obj).is_empty()


## How well the feed suits what is in the object: the average taste over its animals (0: none of them takes it).
func grade(obj: Dictionary, feed: String) -> float:
	var counts := family_counts(obj)
	var all := 0
	var sum := 0.0
	for fam: String in counts:
		all += int(counts[fam])
		sum += taste(fam, feed) * int(counts[fam])
	return sum / all if all > 0 else 0.0


## Units of feed the object takes (one feeds animals_per_feed animals).
func units_needed(obj: Dictionary) -> int:
	var n := 0
	for fam: String in family_counts(obj):
		n += int(family_counts(obj)[fam])
	return maxi(ceili(float(n) / Balance.i("feeds.animals_per_feed")), 1) if n > 0 else 0


# ---------------------------------------------------------------- effects


## What the object's feed does now: {"effect", "power"} or {} (not fed this cycle).
func effect_of(obj: Dictionary) -> Dictionary:
	var fed: Dictionary = obj.get(FED, {})
	if fed.is_empty() or int(fed.get("t", -1)) != int(obj.get("t", 0)):
		return {}
	return fed


func is_hungry(obj: Dictionary) -> bool:
	return is_feedable(obj) and effect_of(obj).is_empty()


## What a feed would give an object for an effect: favourite = full, accepted = share of it; rich adds a share.
func power(effect: String, grade_of: float, rich: bool) -> float:
	var base := 0.0
	match effect:
		"produce":
			base = Balance.f("feeds.produce_bonus") * grade_of
		"speed":
			base = Balance.f("feeds.speed_bonus") * grade_of
		"rare":
			base = (Balance.f("feeds.rare_multiplier") - 1.0) * grade_of
	return base * (1.0 + (Balance.f("feeds.rich_bonus") if rich else 0.0))


## Why a feeding can't happen, or "" when it can (for the card and for the farmer's job).
func problem(obj: Dictionary, feed: String, effect: String, rich := false) -> String:
	if not is_feedable(obj):
		return "NOT_AN_ANIMAL_HOME"
	if not effect in _effects or not _feeds.has(feed):
		return "NOT_AN_ANIMAL_HOME"
	if game.is_ready(obj):
		return "COLLECT_IT_FIRST"   # a feed is for the cycle ahead, so being fed late can't undo a hungry one
	if grade(obj, feed) <= 0.0:
		return "IT_WON_T_EAT_THAT"
	if count(feed, rich) < units_needed(obj):
		return "NOT_ENOUGH_FEED"
	var now_fed := effect_of(obj)
	if not now_fed.is_empty() and float(now_fed["power"]) >= power(effect, grade(obj, feed), rich):
		return "ALREADY_WELL_FED"
	return ""


func can_feed(obj: Dictionary, feed: String, effect: String, rich := false) -> bool:
	return problem(obj, feed, effect, rich) == ""


## Feeds one object. Returns {"feed", "effect", "power", "units"} or {} when it couldn't.
func feed(uid: int, feed_id: String, effect: String, rich := false) -> Dictionary:
	var obj := game.object_by_uid(uid)
	if not can_feed(obj, feed_id, effect, rich):
		return {}
	var units := units_needed(obj)
	var p := power(effect, grade(obj, feed_id), rich)
	_take(feed_id, rich, units)
	obj[FED] = {"effect": effect, "power": p, "t": int(obj["t"])}
	game.ribbons.bump("fed", 1)
	game.inventory_changed.emit()
	game.objects_updated()
	return {"feed": feed_id, "effect": effect, "power": p, "units": units, "rich": rich}


## The best feed in stock for an object (highest grade, plain before Rich), or {"feed", "rich"} / {}.
func best_feed_for(obj: Dictionary) -> Dictionary:
	var best := {}
	var best_grade := 0.0
	for f in feed_ids():
		var g := grade(obj, f)
		for rich in [false, true]:
			if g > best_grade and count(f, rich) >= units_needed(obj):
				best_grade = g
				best = {"feed": f, "rich": rich}
				break
	return best


## What the farmhand does: feeds every hungry animal home with the best feed in stock, for more coins. Returns
## how many were fed.
func feed_all(helper_kind: String) -> int:
	var n := 0
	if helper_kind != "animal":
		return 0
	for o in game.objects.duplicate():
		if not is_hungry(o):
			continue
		var pick := best_feed_for(o)
		if pick.is_empty():
			continue
		if not feed(int(o["uid"]), str(pick["feed"]), "produce", bool(pick["rich"])).is_empty():
			n += 1
	return n


# ---------------------------------------------------------------- what it does at a collect


## The coins multiplier for collecting this object: more with a produce feed, less (never none) when unfed.
func coin_multiplier(obj: Dictionary) -> float:
	if not is_feedable(obj):
		return 1.0
	var fx := effect_of(obj)
	if fx.is_empty():
		return 1.0 - Balance.f("feeds.hunger_penalty")
	return 1.0 + float(fx["power"]) if str(fx["effect"]) == "produce" else 1.0


## The share of the cycle a speed feed cuts off (0 when none).
func speed_cut(obj: Dictionary) -> float:
	var fx := effect_of(obj)
	return float(fx["power"]) if not fx.is_empty() and str(fx["effect"]) == "speed" else 0.0


## The chance multiplier a rare feed gives (1 when none).
func rare_multiplier(obj: Dictionary) -> float:
	var fx := effect_of(obj)
	return 1.0 + float(fx["power"]) if not fx.is_empty() and str(fx["effect"]) == "rare" else 1.0
