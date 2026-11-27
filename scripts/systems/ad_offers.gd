class_name AdOffers
extends GameSystem
## Rewarded ads the player chooses (docs/ADS.md; owner, 27 Nov: ads that feel like a choice, not a chore): each
## offer is a button beside the thing it helps (the Barn's boosts), says first what it gives, and may be taken a
## few times a day (Balance ads.daily_caps). Skipping one costs nothing: everything it gives is also found by
## playing. None before Balance ads.min_level. What each gives is data/ads.json; the ad itself is rewarded_ads.gd.
## Part of the game state: reached as `Game.offers`.

const CONFIG := "res://data/ads.json"
const PLAYER := "res://scripts/systems/rewarded_ads.gd"
const WORDS := {
	"unwithers": "AD_GIVES_UNWITHERS", "fuel_tanks": "AD_GIVES_FUEL_TANKS", "farmhands": "AD_GIVES_FARMHANDS",
}

static var ads_ready := Callable()   # tests: stands in for the player's loaded()
static var player: Node              # the ad player (rewarded_ads.gd), on Android only

var day := 0                 # the day `taken` counts
var taken := {}              # offer id -> ads watched for it today
var _gives := {}             # offer id -> {count name: amount} (data/ads.json)


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
	_gives = game.read_json(CONFIG).get("offers", {})


func reset() -> void:
	day = game.day_number()
	taken = {}


func shift_clock(seconds: int) -> void:
	day = game.day_moved_back(day, seconds)


func save_to(data: Dictionary) -> void:
	data["ads_day"] = day
	data["ads_taken"] = taken.duplicate()


func load_from(data: Dictionary) -> void:
	day = int(data.get("ads_day", game.day_number()))
	taken = int_map(data.get("ads_taken", {}))


## The offers there are (data/ads.json), in its order.
func ids() -> Array:
	return _gives.keys()


## Ads still to watch today for `id`.
func left(id: String) -> int:
	_roll_day()
	return maxi(0, int(Balance.d("ads.daily_caps").get(id, 0)) - int(taken.get(id, 0)))


## Whether `id` is offered now: the level reached, some left today and an ad ready to play.
func shown(id: String) -> bool:
	if game.level() < Balance.i("ads.min_level") or left(id) <= 0:
		return false
	if ads_ready.is_valid():
		return bool(ads_ready.call())
	return player != null and bool(player.call("loaded"))   # not-ui


## What `id` gives, as the button says it before the ad ("Watch an ad: 1 Farmhand").
func words(id: String) -> String:
	var parts := PackedStringArray()
	for k: String in (_gives.get(id, {}) as Dictionary):
		parts.append(tr(WORDS.get(k, "")) % int(_gives[id][k]))
	return tr("WATCH_AN_AD") % ", ".join(parts)


## Plays the ad for `id`; its reward comes only when Google says it was watched (give).
func watch(id: String) -> void:
	if not shown(id):
		return
	if Analytics.shared != null:
		Analytics.shared.design("ad:%s:shown" % id)
	if player != null:
		player.call("play", give.bind(id))   # not-ui


## The reward for a watched ad: the offer's counts added, one fewer left today.
func give(id: String) -> void:
	_roll_day()
	if left(id) <= 0 or not _gives.has(id):
		return
	taken[id] = int(taken.get(id, 0)) + 1
	for k: String in (_gives[id] as Dictionary):
		var n := int(_gives[id][k])
		match k:
			"unwithers":
				game.add_unwithers(n)
			"fuel_tanks":
				game.vehicles.fuel_tanks += n
			"farmhands":
				game.farmhands += n
	if Analytics.shared != null:
		Analytics.shared.design("ad:%s:taken" % id)
	game.message.emit(tr("AD_THANKS"))
	game.inventory_changed.emit()
	game.queue_save()


func _roll_day() -> void:
	var today := game.day_number()
	if today != day:
		day = today
		taken = {}
