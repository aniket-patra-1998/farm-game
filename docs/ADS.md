# Rewarded ads

Owner, 27 Nov: ads should feel like a choice, not a chore, and the helpers stay scarce so an ad is worth it.

- **Only rewarded, only chosen.** No banners, no interstitials, no forced ads. Each offer is a button beside the
  thing it helps (the Barn's boosts today) and says first what it gives ("Watch an ad: +1 Farmhand"). Skipping
  costs nothing: everything an ad gives is also found by playing (Google's rewarded-ad policy).
- **What and how often.** data/ads.json says what each offer gives; Balance `ads.daily_caps` how many a day
  (unwither 3, fuel 2, farmhand 1) and `ads.min_level` (4) when they start: never in the first session.
  Both are remote-tunable (data/remote/tuning.json).
- **Code.** `AdOffers` (`Game.offers`): caps, the day's count (saved), the reward. `rewarded_ads.gd` (loaded by path on Android only): the ad,
  Android only, through Poing Studios' AdMob plugin v5.1.0 (addons/admob, MIT, core "ads" library only, no
  mediation). It asks Google's consent form (UMP) where the law wants it, then keeps one ad loaded; an offer
  shows only when an ad can play at once. The reward comes only from Google's "earned" callback.
- **Analytics.** `ad:<offer>:shown` and `ad:<offer>:taken`.
- **Ids.** Google's test app id (the plugin's default, project setting admob/general/android/app_id) and
  test rewarded unit until the AdMob account exists; then put the real ones in project settings and
  data/ads.json, and set up the consent message in AdMob (Privacy & messaging).
- **Next.** Double the daily bonus, one more mystery box, double a find; a weekly watch streak.
