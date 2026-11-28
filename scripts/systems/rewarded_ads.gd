extends Node
## The rewarded ad itself (docs/ADS.md), through Poing Studios' AdMob plugin (addons/admob, MIT): on Android
## only. It asks Google's consent form first where the law wants one (UMP: the EU, the UK), then starts the
## SDK and keeps one ad of each format loaded (the rewarded ad, and the shorter rewarded interstitial for the
## gift ladder), so an offer shows only when it can play at once. Elsewhere (the desktop, tests)
## nothing is made and no offer shows. The unit and the content rating are data/ads.json. Loaded by path, on
## Android only (AdOffers.begin_ads): its plugin classes make stand-in nodes wherever they are first loaded.

const RETRY_SECONDS := 60.0

var config := {}
var _ad: RewardedAd
var _short: RewardedInterstitialAd   # the shorter format (a rewarded interstitial), for the gift ladder
var _loading := false
var _loading_short := false
var _on_reward := Callable()
var _ads_ready := false   # AdMob said it is ready (MobileAds.initialize's listener)
var _retry: Timer


## Whether an ad is loaded and can play now.
func loaded() -> bool:
	return _ad != null or _short != null


## Plays a loaded ad; `on_reward` runs only once it was watched to the end. `short` asks for the shorter format
## (the gift ladder's: the player has already chosen it on a button that says what it gives, which is the opt-in
## Google's policy asks of that format); whichever is loaded plays when the one asked for is not.
func play(on_reward: Callable, short := false) -> void:
	if not loaded():
		return
	_on_reward = on_reward
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		if _on_reward.is_valid():
			_on_reward.call()
		_on_reward = Callable()
	if _short != null and (short or _ad == null):
		_short.show(listener)
	else:
		_ad.show(listener)


func ask_consent() -> void:
	var info := UserMessagingPlatform.consent_information
	info.update(ConsentRequestParameters.new(), func() -> void:
		if info.get_is_consent_form_available() \
				and info.get_consent_status() == info.ConsentStatus.REQUIRED:
			UserMessagingPlatform.load_consent_form(
				func(form: ConsentForm) -> void: form.show(func(_e: FormError) -> void: _start()),
				func(_e: FormError) -> void: _start())
		else:
			_start(),
		func(_e: FormError) -> void: _start())


func _start() -> void:
	var rc := RequestConfiguration.new()
	rc.max_ad_content_rating = str(config.get("max_content_rating", "PG"))   # not-ui (an AdMob rating)
	MobileAds.set_request_configuration(rc)
	# Ads load only once AdMob says it is ready (Google's order: a load before it crashed the game on Android 16,
	# start check 28 Nov), and only from the level the offers start at (a new farm loads none: a lighter start).
	var ready_now := OnInitializationCompleteListener.new()
	ready_now.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_ads_ready = true
		_load()
	MobileAds.initialize(ready_now)
	_retry = Timer.new()
	_retry.wait_time = RETRY_SECONDS
	_retry.one_shot = true
	_retry.timeout.connect(func() -> void:
		_load()
		_load_short())
	add_child(_retry)


func _load() -> void:
	if not _ads_ready or _ad != null or _loading:
		return
	if Game.level() < Balance.i("ads.min_level"):
		_retry.start()   # (no offers yet: look again in a minute)
		return
	_loading = true
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading = false
		_ad = ad
		_load_short()   # (one load at a time: the shorter format after the rewarded one)
		var screen := FullScreenContentCallback.new()
		screen.on_ad_dismissed_full_screen_content = _used
		screen.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: _used()
		ad.full_screen_content_callback = screen
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		_loading = false
		_retry.start()   # (no fill or offline: try again in a minute)
	RewardedAdLoader.new().load(str(config.get("android_unit", "")), AdRequest.new(), cb)


func _load_short() -> void:
	if not _ads_ready or Game.level() < Balance.i("ads.min_level"):
		return
	var unit := str(config.get("android_unit_short", ""))
	if unit == "" or _short != null or _loading_short:
		return
	_loading_short = true
	var cb := RewardedInterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedInterstitialAd) -> void:
		_loading_short = false
		_short = ad
		var screen := FullScreenContentCallback.new()
		screen.on_ad_dismissed_full_screen_content = _used_short
		screen.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: _used_short()
		ad.full_screen_content_callback = screen
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		_loading_short = false
		_retry.start()
	RewardedInterstitialAdLoader.new().load(unit, AdRequest.new(), cb)


func _used_short() -> void:
	if _short != null:
		_short.destroy()
	_short = null
	_load_short()


func _used() -> void:
	if _ad != null:
		_ad.destroy()
	_ad = null
	_load()
