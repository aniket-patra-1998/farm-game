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
