# VIP and the Barn (our own addition, not FarmVille 2009)

VIP is a paid layer on top of the game as it stands: it makes what the farm already gives stronger and
changes nothing else. Only the farmer's level gates things. The Barn is the farm's centre and shows it.

## VIP level (kept for good)

- Levels 1 to 15, reached with VIP points; a level is never lost.
- Points come from the daily gift's login streak: 10 on the first day, 10 more each day up to 50 a day; a
  missed day starts again at 10. They can also be bought: 1 gem buys 10 points, with no limit.
- The points each level takes (Balance `vip.level_points`) put a free player who logs in every day at VIP 15
  in about twelve months (18,000 points).

## VIP time (the switch)

- VIP's bonuses work only while VIP is active.
- Reaching a new level gives 3 days, added to whatever time is left. After that, 7 days cost gems: 5, and 3
  more for each level (8 at VIP 1, 50 at VIP 15).
- When the time runs out every bonus stops; the level and the Barn's look stay.

## What active VIP does

Everything buildings give is multiplied, from 1 at no VIP to 2 at VIP 15, by the same step each level
(`VipSystem.boost`):

- the boosts stocked homes give the farm (`HomeBoostSystem.total`, and its caps with it);
- the layout bonus of pieces of one kind that touch (`AdjacencySystem.bonus_for`);
- the chances on a collection: babies, helpers, fertilizer, the stable's XP (`BuildingSpecials`), a rare
  sapling from the Orchard (`NurtureSystem`), a find (`FindsSystem`) and a Mystery Egg (`MysterySystem`)
  (`VipSystem.chance`, never over certain).

Still to build, on the same multiplier: rare-quality crafted goods and rare babies in the Nursery Barn.

## The Barn

- Its storage is as before: five sizes bought with materials, nothing to do with VIP.
- It is the biggest building of a farm: it stands on four tiles by four, where other buildings take three.
- Its yard shows the farm prospering (`fill.company` in data/building_models.json, `BuildingFill`): with each
  storage size one more stands by it, each at a spot of its own. A cow at the first size, two apple trees at
  the second, a tractor at the third, a pig at the fourth and a horse at the fifth. They are for show: they
  are not the player's, give nothing, and a broken Barn has none.
- Its look follows the VIP level: 15 looks (five shapes of three steps each), a glTF file for each
  (docs/ASSETS.md). On top stands the VIP badge, the thing a player's eye should go to: one big, round,
  simple shape in the farm's own chunky look, as farm games show a level. A fat coin with a thick rim, a domed
  enamel face, the level's number on it, and a crown. The number is in the game's own bold face (Poppins
  Bold), outlined dark, and sized by what it covers so one digit or two both fill the face without touching
  the rim. Only its colours change by tier,
  three levels each: bronze, silver, then gold on red, on green and on royal purple.
  - While VIP is active (`when_vip_true`) its metal glimmers: a band of light crosses it every few seconds and
    it glows a little by itself, day and night (`ModelKit.shine_material`, one draw); a few big glints twinkle
    at its rim (the `sparkle` effect, one draw); and it turns slowly about its upright, its number on both
    faces (a `spin_*` part).
  - Lapsed (`when_vip_false`) the same badge stands still in dull grey: the level is still there to read, and
    what was lost is plain to see.
  - Before the first VIP level the Barn wears the first look with no badge.
- Its sheet has a VIP page: the level, the points to the next, the time left, and the buttons to buy points
  and time.

## For the store

Gems can raise the chances above. Show those chances on the VIP page before selling gems for money (the
stores ask for the odds of paid random rewards to be shown).

Switch: `Release.on("vip")`. Numbers: Balance `vip.*`. Rules: `scripts/systems/vip_system.gd`, held by
`tests/suites/vip_test.gd`.
