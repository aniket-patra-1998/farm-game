# Rewarded ads

Owner, 27 Nov: ads should feel like a choice, not a chore, and the helpers stay scarce so an ad is worth it.

- **Only rewarded, only chosen.** No banners, no interstitials, no forced ads. Each offer is a button beside the
  thing it helps (the Barn's boosts today) and says first what it gives ("Watch an ad: +1 Farmhand"). Skipping
  costs nothing: everything an ad gives is also found by playing (Google's rewarded-ad policy).
- **What and how often** (owner, 27 Nov: rare items stay rare). Rewards are labelled in data/ads.json:
  *common* (coins and XP scaled by level, a Fertilizer bag, 2 materials, 25 fuel) and *rare* (Farmhand,
  Arborist, Gardener, Unwither, Fertilize All, a full fuel tank, a Mystery Box). Never gems.
  - The gift ladder (the ad-chest pattern): ads 1 to 3 give a common, the 4th a guaranteed rare; the button
    says which ("free gift (2 of 4)", "a rare gift!"). The step carries over between days.
  - A rescue: crops withered, and an ad revives exactly those plots, from the Barn or the Unwither petal when
    no Unwither is left (before gems). It counts as a rare.
  - Balance `ads`: `rares_per_day` 2 (ladder and rescues together; past it the ladder's top gives a common),
    `per_day` 15, `ladder` 4, `min_level` 4 (never in the first session). Remote-tunable.
- **Code.** `AdOffers` (`Game.offers`): caps, the day's count (saved), the reward. `rewarded_ads.gd` (loaded by path on Android only): the ad,
  Android only, through Poing Studios' AdMob plugin v5.1.0 (addons/admob, MIT, core "ads" library only, no
  mediation). It asks Google's consent form (UMP) where the law wants it, then keeps one ad loaded; an offer
  shows only when an ad can play at once. The reward comes only from Google's "earned" callback.
- **Analytics.** `ad:gift:shown`, `ad:gift:taken`, `ad:gift_rare:taken`, `ad:rescue:shown`, `ad:rescue:taken`.
- **Ids.** Google's test app id (the plugin's default, project setting admob/general/android/app_id) and
  test rewarded unit until the AdMob account exists; then put the real ones in project settings and
  data/ads.json, and set up the consent message in AdMob (Privacy & messaging).
- **app-ads.txt.** Put the AdMob publisher id in data/ads.json `publisher_id`: CI then serves app-ads.txt at
  https://farm-game-packs.pages.dev/app-ads.txt; name that site as the developer website on the Play page.
- **Two formats (27 Nov).** A rescue plays the rewarded ad (`android_unit`); the gift ladder plays the shorter
  rewarded interstitial (`android_unit_short`; leave it "" to play the rewarded ad there too). Both are kept
  loaded; if the one asked for is not, the other plays. The gift is still chosen on a button that says what it
  gives, which is the opt-in Google asks of that format. Not yet tried on a phone.
- **Next.** Rescues for weather damage once weather withers crops.
