extends TestSuite
## The seasons (scripts/season.gd, data/seasons.json): the real calendar by region, each crop's home seasons, what
## an off-season crop pays and how soon it withers, and the rain that waters the fields.


func _at(month: int, day: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": 2026, "month": month, "day": day, "hour": 12,
		"minute": 0, "second": 0}))


func test_361_the_season_follows_the_calendar_where_the_player_lives() -> void:
	Season.active = true
	_eq(Season.at(_at(7, 15), 0, "monsoon"), "Monsoon", "July in India is the monsoon")
	_eq(Season.at(_at(7, 15), 0, "north"), "Summer", "summer in the north")
	_eq(Season.at(_at(7, 15), 0, "south"), "Winter", "winter in the south")
	_eq(Season.at(_at(1, 15), 0, "monsoon"), "Winter", "January in India is winter")
	_eq(Season.at(_at(1, 15), 0, "south"), "Summer", "and summer in the south")
	_eq(Season.guess_region("en_IN", 0), "monsoon", "a phone in India is in the monsoon's region")
	_eq(Season.guess_region("en_US", 330), "monsoon", "so is one set to American English on India's clock")
	_eq(Season.guess_region("en_AU", 600), "south", "Australia is in the south")
	_eq(Season.guess_region("en_US", -300), "north", "and anywhere unknown has the north's four seasons")
	_eq(Season.odds_key("Winter", "monsoon"), "Winter_monsoon", "an Indian winter has its own weather (no snow)")
	_eq(Season.odds_key("Winter", "north"), "Winter", "a northern one has winter's")
	var odds: Dictionary = Balance.d("weather.odds")
	var known: Array = Season.data()["seasons"]
	for region: String in Season.regions():
		var months: Array = Season.data()["regions"][region]["months"]
		_eq(months.size(), 12, "%s has a season for every month" % region)
		for season: String in months:
			_check(known.has(season), "%s: %s is a season" % [region, season])
			_check(odds.has(Season.odds_key(season, region)), "%s in %s has weather odds" % [season, region])
			_check(not Season.lawn(season).is_empty(), "%s has a lawn" % season)
			_check(TranslationServer.translate("SEASON_" + season.to_upper()) != "SEASON_" + season.to_upper(),
				"%s has a name" % season)
	var g := _farm()
	for crop_id: String in g.crops:
		_check((Season.data()["crops"] as Dictionary).has(crop_id), "%s has its seasons listed" % crop_id)
		for season: String in Season.seasons_of(crop_id):
			_check(known.has(season), "%s: %s is a season" % [crop_id, season])
	_done(g)
	_check(Season.is_off("wheat", "Monsoon"), "wheat in the monsoon is off-season")
	_check(not Season.is_off("wheat", "Winter"), "in winter it is at home")
	_check(not Season.is_off("sunflowers", "Winter"), "a flower is at home all year")
	Season.active = false
	_check(not Season.is_off("wheat", "Monsoon"), "with seasons off nothing is off-season")
	_eq(Season.at(_at(1, 15), 0, "south"), Season.PLAIN, "and it is always the plain season")


func test_362_an_off_season_crop_pays_more_and_withers_sooner_and_rain_waters() -> void:
	Season.active = true
	Season.set_region("monsoon", false)
	var g := _farm()
	g.debug_time_offset = _at(7, 15) - int(Time.get_unix_time_from_system())
	g.clear_until = 0
	_eq(g.season(), "Monsoon", "it is the monsoon")
	_check(not g.off_season("wheat"), "on a young farm nothing is off-season")
	g.xp = g.xp_for_level(12)
	_check(g.off_season("wheat"), "later, wheat in the monsoon is")
	_check(not g.off_season("rice"), "and rice is at home")
	g.coins = 100000
	var a := g.index_of(11, 11)
	var b := g.index_of(11, 12)
	g.field.plow(a)
	g.field.plow(b)
	g.field.plant(a, "wheat")
	g.field.plant(b, "rice")
	_check(g.plots[a].get("off", false), "the wheat is marked off-season when planted")
	_check(not g.plots[b].get("off", false), "the rice is not")
	var wheat: Dictionary = g.crops["wheat"]
	_eq(g.field.window_of(g.plots[a], wheat),
		int(g.field.ripe_window(wheat) * Balance.f("seasons.off_window_mult")), "it withers sooner")
	var planted := int(g.plots[a]["planted_at"])
	var rained := g.rained_between(planted, planted + int(wheat["grow_seconds"]))
	_skip(g, int(wheat["grow_seconds"]) + 5)
	var got := g.field.harvest(a)
	var bonus := Balance.f("seasons.rain_bonus") if rained else 0.0
	_eq(int(got["coins"]), int(round(float(wheat["sell_price"]) * (1.0 + bonus) * Balance.f("seasons.off_price_mult"))),
		"and sells for more (rain %s)" % rained)
	_eq(bool(got["rain"]), rained, "the harvest says whether rain watered it")
	# Rain: the weather is a function of the date, so a stretch with rain in it can be found and asked about.
	var length := Weather.block()
	var start := g.now() - g.now() % length
	var wet := -1
	var dry := -1
	for k in 400:
		var t := start + k * length
		var state := g.weather_state_at(t)
		if wet < 0 and GameState.WET.has(state):
			wet = t
		if dry < 0 and not GameState.WET.has(state):
			dry = t
	_check(wet >= 0, "the monsoon has rain within fifty days")
	if wet >= 0:
		_check(g.rained_between(wet + 60, wet + 600), "a stretch inside a rain block was rained on")
		g.clear_until = wet + length
		_check(not g.rained_between(wet + 60, wet + 600), "but not under a new farm's clear sky")
		g.clear_until = 0
	if dry >= 0:
		_check(not g.rained_between(dry + 60, dry + 600), "and a stretch inside a dry block was not")
	var next := g.forecast()
	if not next.is_empty():
		_check(int(next["at"]) > g.now(), "the forecast is of what is to come")
		_eq(GameState.FALLING.has(g.weather_state_at(int(next["at"]))), bool(next["starts"]),
			"rain starts then, or the rain falling now ends")
	_done(g)
	Season.set_region("", false)
	Season.active = false
