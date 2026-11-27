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


## Progress and life shown on the farm itself: a mastered crop's plants carry its stars, the farmhouse grows with
## the farmer, animals sleep at night, and a hungry one looks about.
func test_363_progress_and_life_show_on_the_farm() -> void:
	Game.saving_enabled = false
	Game.reset_game()
	_eq(CropClock.mastered("strawberries"), 0.0, "an unmastered crop is plain")
	_eq(Game.farmhouse_stage(), 1, "a new farm's house is the first")
	var house := {"uid": 1, "id": "farmhouse", "row": 0, "col": 0}
	var first := Objects3D.shows_of(house)
	Game.xp = Game.xp_for_level(int(Balance.a("feel.farmhouse_levels")[0]))
	_eq(Game.farmhouse_stage(), 2, "at the first of its levels it gains a part")
	_check(Objects3D.shows_of(house) != first, "and its look is another (it is built again)")
	Game.xp = Game.xp_for_level(60)
	var stages := Balance.a("feel.farmhouse_levels").size() + 1
	_eq(Game.farmhouse_stage(), stages, "a long-lived farm has every part")
	for stage in range(1, stages + 1):
		var spec := BuildingModel.spec("farmhouse", stage)
		_check((spec["features"] as Array).size() >= stage, "stage %d has its parts" % stage)
		var built := BuildingModel.build(Game.item_data("farmhouse"), Game.footprint("farmhouse"), stage)
		_check(built.get_child_count() > 0, "and builds")
		built.free()
	_eq(Objects3D.shows_of({"uid": 2, "id": "mastery_sign", "crop": "wheat"}), "wheat", "a sign still shows its crop")
	var mind := AnimalBehaviour.new(AnimalRig.of(Game.item_data("cow")), 7, Vector2(14, 7))
	AnimalBehaviour.night = true
	var slept := 0
	for k in 40:
		mind.call("_choose_next")
		if mind.state == AnimalBehaviour.State.SLEEP:
			slept += 1
	_check(slept > 20, "at night an animal mostly sleeps (%d of 40)" % slept)
	mind.call("_enter", AnimalBehaviour.State.SLEEP)
	mind.call("_ease_body", 0.1)
	mind.call("_idle_motions", 0.1)
	_eq(mind.pose.blink, 1.0, "with its eyes shut")
	AnimalBehaviour.night = false
	mind.call("_ease_body", 0.1)
	_check(mind.time_left() <= 0.5, "and wakes with the light")
	mind.hungry = true
	var looked := 0
	for k in 40:
		mind.call("_choose_next")
		if mind.state == AnimalBehaviour.State.LOOK:
			looked += 1
	_check(looked > 16, "a hungry one mostly looks about for its feed (%d of 40)" % looked)
	_check(Feedback.has_moment("dawn") and Sound.has_sound("crow"), "and the dawn has its rooster")
	Game.reset_game()



func test_581_the_days_shorten_with_the_season() -> void:
	# Owner, 19 Nov: autumn kept summer's long days. Each season's sunrise and sunset (seasons.json daylight) are
	# stretched onto summer's colours: summer is unchanged, a winter 6 pm is past the summer sunset (dusk or dark).
	for h in [0.0, 5.5, 12.0, 18.75, 23.0]:
		_check(absf(DayCycle.summer_hour(h, "Summer") - h) < 0.001, "summer unchanged at %s" % h)
	var winter: Array = Season.data()["daylight"]["Winter"]
	_check(absf(DayCycle.summer_hour(float(winter[0]), "Winter") - DayCycle.SUNRISE) < 0.001, "winter sunrise")
	_check(absf(DayCycle.summer_hour(float(winter[1]), "Winter") - DayCycle.SUNSET) < 0.001, "winter sunset")
	_check(DayCycle.summer_hour(18.0, "Winter") > DayCycle.SUNSET, "a winter 6 pm looks like a summer evening")
	_check(DayCycle.summer_hour(18.0, "Autumn") > DayCycle.summer_hour(18.0, "Summer"), "autumn evenings come earlier")
	for season: String in Season.data()["seasons"]:
		_check(Season.data()["daylight"].has(season), "%s has its daylight" % season)
