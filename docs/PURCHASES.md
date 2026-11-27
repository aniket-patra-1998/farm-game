# In-app purchases

docs/V1.md: gem packs in three sizes and a one-time starter pack. Google Play Billing through the official
GodotGooglePlayBilling plugin 3.3.0 (addons/GodotGooglePlayBilling, MIT; Billing Library 9.1; Android, Gradle
builds only).

- **Products** (data/store.json; the ids must match Play Console's in-app products): `starter_pack` (one-time:
  60 gems, 10,000 coins, 2 Farmhands, 3 Unwithers, 2 Fertilize All), `gems_small` 40, `gems_medium` 240 (+20%),
  `gems_large` 520 (+30%). Prices are set in Play Console (suggested Rs 89 / Rs 449 / Rs 899, the $0.99 / $4.99 /
  $9.99 tiers; the starter pack at Rs 89); the game shows Play's own price text.
- **Where.** The Market's last tab, Gems; the gem meter's + opens it. Where Play can't sell (a test build, offline,
  Play not answered yet) the page says the shop isn't open.
- **Rules** (`PurchaseSystem`, `Game.purchases`): a purchase is given the moment Play says it is paid, its token
  kept so it is never given twice; then a pack is consumed and the starter pack acknowledged (unacknowledged
  purchases are refunded by Play after 3 days). On every start Play hands back what was paid but not consumed, so
  a crash mid-purchase still delivers once. Pending payments (cash, UPI collect) wait and arrive when paid.
- **No server.** Single-player: purchases are not checked by a server of our own (Play's signature could be, later).
- **Testing.** Needs a build uploaded to Play Console (internal testing) and license testers (Play Console →
  Setup → License testing): their purchases are free test purchases. Test 633 covers the rules.
