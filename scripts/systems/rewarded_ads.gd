extends Node
## The rewarded ad itself (docs/ADS.md), through Poing Studios' AdMob plugin (addons/admob, MIT): on Android
## only. It asks Google's consent form first where the law wants one (UMP: the EU, the UK), then starts the
## SDK and keeps one ad loaded, so an offer shows only when it can play at once. Elsewhere (the desktop, tests)
## nothing is made and no offer shows. The unit and the content rating are data/ads.json. Loaded by path, on
## Android only (AdOffers.begin_ads): its plugin classes make stand-in nodes wherever they are first loaded.

const RETRY_SECONDS := 60.0

var config := {}
var _ad: RewardedAd
var _loading := false
var _on_reward := Callable()
var _retry: Timer


## Whether an ad is loaded and can play now.
func loaded() -> bool:
	return _ad != null


## Plays the loaded ad; `on_reward` runs only once it was watched to the end.
func play(on_reward: Callable) -> void:
	if _ad == null:
		return
	_on_reward = on_reward
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		if _on_reward.is_valid():
			_on_reward.call()
		_on_reward = Callable()
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
	MobileAds.initialize()
	_retry = Timer.new()
	_retry.wait_time = RETRY_SECONDS
	_retry.one_shot = true
	_retry.timeout.connect(_load)
	add_child(_retry)
	_load()


func _load() -> void:
	if _ad != null or _loading:
		return
	_loading = true
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading = false
		_ad = ad
		var screen := FullScreenContentCallback.new()
		screen.on_ad_dismissed_full_screen_content = _used
		screen.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: _used()
		ad.full_screen_content_callback = screen
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		_loading = false
		_retry.start()   # (no fill or offline: try again in a minute)
	RewardedAdLoader.new().load(str(config.get("android_unit", "")), AdRequest.new(), cb)


func _used() -> void:
	if _ad != null:
		_ad.destroy()
	_ad = null
	_load()
