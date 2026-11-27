# Balance: where the numbers are and what they do

All tuning numbers live in `data/balance.json` (chances, gaps, timers, payouts, caps, costs, weather odds) and
are read with `Balance.f/i/a/d("section.name")`. `tests/suites/balance_test.gd` fails if code asks for a key the file
lacks, or the file has a number nothing uses. FarmVille's real rates were never published, so most values are
our estimates; a `note` says what each is and where a claim about FarmVille was made.

## Try a change before shipping it
`godot --headless --path . res://tools/balance_sim.tscn -- --days=14 --visits=3 --seed=1 [--set=harvest.golden_chance=0.01]`
plays the real game with a tidy bot (visits a few times a day, harvests everything, replants the best crop that is
ripe and not yet withered at the next visit, plows as coins allow) and prints per-day level, coins and drops, the
drop rates the real rolls give over 100,000 harvests, and the weather's shares and spells per season.

## The audit of 27 Nov (owner: "not too easy"; helpers scarce, ads a capped second route)
Applied: levels 6 to 20 take 25% more XP; a new player keeps economy.keep_coins for fields until level 5 (a buy an
open goal asks for is never held back); today's deal (market.deal_off on one item a day); decorations give no XP
from level 15; upgrade and expansion steps grow by 1.85 (was 1.6); the Bakery unlocks at 15 for 60,000; a Stable
harvest gives a helper 6% of the time (was 15%) and the Mystery Box's helpers weigh half; start coins 300. Sim
(seed 1, 35 days): engaged (3 visits, builder) level 20 on day 18, casual (1 visit) on day 28; something to buy on
81 to 82% of days (casual was 36%); the Bakery pays back in 5.5 days. Still open: an engaged builder holds about
190,000 coins by day 30 (new sinks, or tuning from real players through data/remote/tuning.json).

## Pace (seed 1, 35 days; the bot also buys land, trees and animals, and has about 5 minutes of work per visit)
Target: the FarmVille pace, level 20 in about two weeks for someone who visits three times a day, and four to five
weeks for someone who visits once a day. The level table (`economy.level_xp`, 8290 XP for level 20, then 1000 a
level) was tuned to it.
| visits a day | level 10 | level 20 | level 30 |
|---|---|---|---|
| 1 | day 11 | day 28 | - |
| 3 | day 5 | day 14 | day 27 |
Findings:
- Before the retune (table of 2060 XP for level 20) the same bot reached level 20 on day 4 (three visits) and day 10
  (one visit): land expansion multiplies plots, and XP grows with plots, so the table had to grow a lot.
- Coins still pile up (100-300k) because the bot only buys land and a few animals: the real sinks (buildings,
  decorations, crafting) are not in the bot yet. Land costs and the buildings' prices are the next thing to tune.
- A crop withers as long after ripening as it took to grow, so a once-a-day player can only use crops that grow
  12-24 hours: the choice of crop is the whole game for them (they sit at level 1-2 for the first days).
- Drops per 1000 harvests at 0 stars: golden 6, collectible 62-80 (pity at 30 lifts it), bird 29, super 54, bonus 44.
- Weather (summer): clear 49%, partly cloudy 25%, cloudy 10%, rain 9%, storm 2%, fog 4%; spells average 2.9 blocks (about 9 hours).
