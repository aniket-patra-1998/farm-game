class_name WeatherEffects
extends GameSystem
## What the weather does to the harvest (docs/WEATHER.md "Weather and the harvest"; owner, 27 Nov; our own touch):
## a ripe crop left out in weather that spoils it (rain on berries, frost on melons) withers, and a crop or tree
## that grew through the weather it loves gives more. data/weather_effects.json says which, by family. The weather
## is a pure function of the date (Game.weather_state_at), so both are known for any stretch, the time away too.
## Off on a young farm (Balance seasons.from_level), during a new farm's clear spell, and with the seasons off.
## Part of the game state: reached as `Game.weather_fx`.

const CONFIG := "res://data/weather_effects.json"
const KEPT_MOST := 4096   # spoil times kept (by plot and planting) before the keep starts again
const LOVED := {
	"clear": "LOVED_SUN", "partly_cloudy": "LOVED_SUN", "rain": "LOVED_RAIN", "snow": "LOVED_FROST", "fog": "LOVED_MIST",
}

var tried := ""     # a weather tried on the showcase farm (its clock), "" none: it spoils what it would at once
var tried_at := 0
var _spoils := {}   # state -> {family: true}
var _bloom_spoils := {}   # state -> {bloom family: true}
var _loves := {}    # "crops" / "trees" -> state -> {family: true}
var _kept := {}     # "plot:planted_at" -> the time its crop spoils, or -1


func _init(owner: GameState) -> void:
	super(owner)


func load_data() -> void:
	var d := game.read_json(CONFIG)
	_spoils = _sets(d.get("spoils_ripe", {}))
	_bloom_spoils = _sets(d.get("blooms_spoil", {}))
	for kind: String in (d.get("loves", {}) as Dictionary):
		_loves[kind] = _sets(d["loves"][kind])


func reset() -> void:
	_kept.clear()
	tried = ""


## The showcase's clock tried weather `state` ("" back to the real one): ripe crops it spoils wither at once, so
## the farm shows it (owner, 27 Nov: "these should be withered"). The real weather is the date's, as always.
func try_weather(state: String) -> void:
	tried = state
	tried_at = game.now()
	_kept.clear()
	game.plot_changed.emit(-1)   # (every plot's look and wither time asked again)


## Whether the weather touches the harvest on this farm now.
func on() -> bool:
	return Season.enabled() and game.level() >= Balance.i("seasons.from_level")


## When plot `i`'s ripe crop spoils (weather its family can't take, while it waits to be picked), or -1.
func spoils_at(i: int, ripe_at: int, withers_at: int) -> int:
	if not on():
		return -1
	var p: Dictionary = game.plots[i]
	var key := "%d:%d" % [i, int(p.get("planted_at", 0))]
	if _kept.has(key):
		return int(_kept[key])
	if _kept.size() > KEPT_MOST:
		_kept.clear()
	var family := str(game.crops.get(str(p.get("crop", "")), {}).get("family", ""))
	if tried != "":   # (the showcase's tried weather: what it spoils, spoiled from the moment it was tried)
		var hurt_now := (_spoils.get(tried, {}) as Dictionary).has(family)
		var since := maxi(ripe_at, tried_at)
		return since if hurt_now and since < withers_at else -1
	var at := -1
	var length := Weather.block()
	var t := maxi(ripe_at, game.clear_until)
	t -= posmod(t, length)
	for k in GameState.RAIN_LOOK_MOST:
		if t >= withers_at:
			break
		var hurt: Dictionary = _spoils.get(game.weather_state_at(t), {})
		if hurt.has(family):
			at = maxi(t, ripe_at) + Balance.i("weather.spoil_grace_seconds")
			break
		t += length
	at = at if at >= 0 and at < withers_at else -1
	_kept[key] = at
	return at


## When an open Single Bloom (`family`, ready at `ready_at`) is spoiled by weather it can't take before
## `withers_at`, or -1: the same rule as a ripe crop's (spoils_at), with the blooms' own list.
func bloom_spoils_at(family: String, ready_at: int, withers_at: int) -> int:
	if not on():
		return -1
	if tried != "":
		var since := maxi(ready_at, tried_at)
		return since if (_bloom_spoils.get(tried, {}) as Dictionary).has(family) and since < withers_at else -1
	var length := Weather.block()
	var t := maxi(ready_at, game.clear_until)
	t -= posmod(t, length)
	for k in GameState.RAIN_LOOK_MOST:
		if t >= withers_at:
			break
		if (_bloom_spoils.get(game.weather_state_at(t), {}) as Dictionary).has(family):
			var at := maxi(t, ready_at) + Balance.i("weather.spoil_grace_seconds")
			return at if at < withers_at else -1
		t += length
	return -1


## The weather a crop (`kind` "crops"), tree ("trees") or bloom ("blooms") of `family` loved while it grew from
## `from_t` to `to_t`,
## when it had enough of it (Balance weather.love_share), or "".
func loved(kind: String, family: String, from_t: int, to_t: int) -> String:
	if not on() or to_t <= from_t:
		return ""
	var loves: Dictionary = _loves.get(kind, {})
	var length := Weather.block()
	var t := maxi(from_t, game.clear_until)
	t -= posmod(t, length)
	var blocks := 0
	var counts := {}
	while t < to_t and blocks < GameState.RAIN_LOOK_MOST:
		var state := game.weather_state_at(t)
		if (loves.get(state, {}) as Dictionary).has(family):
			counts[state] = int(counts.get(state, 0)) + 1
		blocks += 1
		t += length
	var best := ""
	for state: String in counts:
		if best == "" or int(counts[state]) > int(counts[best]):
			best = state
	if best == "" or float(counts[best]) / maxi(blocks, 1) < Balance.f("weather.love_share"):
		return ""
	return best


## What stood in a home of plants (an Orchard, a Bloom Garden) and loved the weather since it was last
## harvested: {"state": the weather most of them loved ("" for none), "share": how much of what is inside loved
## its weather, 0..1}. Each tree or bloom inside is asked as it would be standing alone.
func loved_inside(home: Dictionary) -> Dictionary:
	var counts := {}
	var all := 0
	var loving := 0
	var inside: Dictionary = home.get("inside", {})
	for id: String in inside:
		var n := int(inside[id])
		var it := game.item_data(id)
		all += n
		var state := loved(str(it.get("kind", "")) + "s", str(it.get("family", "")), int(home.get("t", game.now())),
			game.now())
		if state != "":
			loving += n
			counts[state] = int(counts.get(state, 0)) + n
	var best := ""
	for state: String in counts:
		if best == "" or int(counts[state]) > int(counts[best]):
			best = state
	return {"state": best, "share": float(loving) / maxi(all, 1)}


## The words for a loved weather ("Loved the sun +20%"), said on the harvest; `share` is how much of a home's
## plants loved it (the bonus is that much of the whole).
func loved_words(state: String, share := 1.0) -> String:
	return tr("LOVED_WEATHER") % [tr(LOVED.get(state, "LOVED_SUN")),
		maxi(1, roundi(Balance.f("weather.loved_bonus") * share * 100.0))]


static func _sets(d: Dictionary) -> Dictionary:
	var out := {}
	for state: String in d:
		var s := {}
		for family: String in d[state]:
			s[family] = true
		out[state] = s
	return out
