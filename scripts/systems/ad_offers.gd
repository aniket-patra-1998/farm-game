class_name AdOffers
extends GameSystem
## Rewarded ads the player chooses (docs/ADS.md; owner, 27 Nov). Two kinds:
## - the gift ladder: three ads each give a common reward, the fourth a guaranteed rare (the ad-chest pattern);
## - a rescue: crops have withered, and an ad revives exactly those plots (counts as a rare).
## At most Balance ads.rares_per_day rares a day from ads in all, ads.per_day ads, none before ads.min_level.
## Rewards are data/ads.json's prizes, given as the Mystery Box gives them. The ad itself is rewarded_ads.gd.
## Part of the game state: reached as `Game.offers`.

const CONFIG := "res://data/ads.json"
const PLAYER := "res://scripts/systems/rewarded_ads.gd"
const GIFT := "gift"       # not-ui (analytics names)
const RESCUE := "rescue"   # not-ui
const BOX := "mystery_box"   # not-ui (a prize kind this file adds: a Mystery Box opened)

static var ads_ready := Callable()   # tests: stands in for the player's loaded()
static var player: Node              # the ad player (rewarded_ads.gd), on Android only

var day := 0          # the day the counts below are for
var watched := 0      # ads watched today
var step := 0         # gift ads watched since the last rare (the ladder, 0 to ads.ladder - 1)
var rares := 0        # rare rewards given today (ladder and rescues)
var _common: Array = []
var _rare: Array = []


func _init(owner: GameState) -> void:
	super(owner)


## Made once by the game: the ad player, on Android only (elsewhere no offer shows).
static func begin_ads(game: GameState) -> void:
	if OS.get_name() != "Android" or player != null:   # not-ui
		return
	player = (load(PLAYER) as GDScript).new()
	player.name = "RewardedAds"   # not-ui (a node name)
	player.set("config", game.read_json(CONFIG))
	game.add_child(player)
	player.call("ask_consent")   # not-ui


func load_data() -> void:
	var d := game.read_json(CONFIG)
	_common = d.get("common", [])
	_rare = d.get("rare", [])


func reset() -> void:
	day = game.day_number()
	watched = 0
	step = 0
	rares = 0


func shift_clock(seconds: int) -> void:
	day = game.day_moved_back(day, seconds)


func save_to(data: Dictionary) -> void:
	data["ads"] = {"day": day, "watched": watched, "step": step, "rares": rares}


func load_from(data: Dictionary) -> void:
	var d := int_map(data.get("ads", {}))
	day = int(d.get("day", game.day_number()))
	watched = int(d.get("watched", 0))
	step = clampi(int(d.get("step", 0)), 0, maxi(Balance.i("ads.ladder") - 1, 0))
	rares = int(d.get("rares", 0))


## Whether the next gift ad gives a rare (the ladder's last step, and a rare left today).
func next_is_rare() -> bool:
	_roll_day()
	return step >= Balance.i("ads.ladder") - 1 and rares < Balance.i("ads.rares_per_day")


## Whether the gift ad is offered now.
func gift_shown() -> bool:
	return _can_watch()


## Whether a rescue is offered now: crops withered, and a rare left today.
func rescue_shown() -> bool:
	return _can_watch() and game.withered_count() > 0 and rares < Balance.i("ads.rares_per_day")


## The gift button's words: how far up the ladder, or that this one is rare.
func gift_words() -> String:
	if next_is_rare():
		return tr("AD_GIFT_RARE")
	return tr("AD_GIFT") % [step + 1, Balance.i("ads.ladder")]


func rescue_words() -> String:
	return tr("AD_RESCUE") % game.withered_count()


func watch_gift() -> void:
	_watch(GIFT, give_gift)


func watch_rescue() -> void:
	_watch(RESCUE, give_rescue)


## A watched gift ad: a common reward, or the ladder's rare.
func give_gift() -> void:
	_roll_day()
	if watched >= Balance.i("ads.per_day"):
		return
	watched += 1
	var rare := next_is_rare()
	step = 0 if step >= Balance.i("ads.ladder") - 1 else step + 1
	if rare:
		rares += 1
	var words := _give(_draw(_rare if rare else _common))
	_done(GIFT + ("_rare" if rare else ""), words)


## A watched rescue ad: every withered crop back to ripe.
func give_rescue() -> void:
	_roll_day()
	if watched >= Balance.i("ads.per_day") or rares >= Balance.i("ads.rares_per_day") or game.withered_count() == 0:
		return
	watched += 1
	rares += 1
	game.revive_withered()
	_done(RESCUE, "")


func _can_watch() -> bool:
	_roll_day()
	if game.level() < Balance.i("ads.min_level") or watched >= Balance.i("ads.per_day"):
		return false
	if ads_ready.is_valid():
		return bool(ads_ready.call())
	return player != null and bool(player.call("loaded"))   # not-ui


func _watch(kind: String, reward: Callable) -> void:
	if not _can_watch():
		return
	if Analytics.shared != null:
		Analytics.shared.design("ad:%s:shown" % kind)
	if player != null:
		player.call("play", reward)   # not-ui


## One prize from a weighted list ([kind, amount, weight]); one the farm can't use yet (fuel with no
## vehicle) is left out.
func _draw(prizes: Array) -> Array:
	var usable: Array = []
	for p: Array in prizes:
		if str(p[0]) != "fuel" or game.vehicles.fuel_unlocked:
			usable.append(p)
	var weights: Array = []
	for p: Array in usable:
		weights.append(p[2])
	var i := RollSystem.weighted_index(game.rng, weights)
	return usable[i] if i >= 0 else []


func _give(prize: Array) -> String:
	if prize.is_empty():
		return ""
	if str(prize[0]) == BOX:
		return game.mystery.gift_box()   # (it says what came out itself)
	var p := prize.duplicate()
	match str(p[0]):
		"coins":
			p[1] = int(p[1]) + Balance.i("ads.coins_per_level") * game.level()
		"xp":
			p[1] = int(p[1]) + Balance.i("ads.xp_per_level") * game.level()
	return game.mystery.give_prize(p)


func _done(kind: String, words: String) -> void:
	if Analytics.shared != null:
		Analytics.shared.design("ad:%s:taken" % kind)
	if words != "":
		game.message.emit(tr("AD_GOT") % words)
	game.inventory_changed.emit()
	game.queue_save()


func _roll_day() -> void:
	var today := game.day_number()
	if today != day:
		day = today
		watched = 0
		rares = 0   # (the ladder's step carries over: progress is never lost)
