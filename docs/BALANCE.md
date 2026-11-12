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

## Baseline (seed 1, 14 days, field loop only: no buildings, animals or purchases)
| visits a day | level 10 | level 20 | level 30 | level on day 14 | coins on day 14 |
|---|---|---|---|---|---|
| 1 | day 7 | day 10 | - | 27 | 217k |
| 2 | day 3 | day 6 | day 10 | 38 | 365k |
| 3 | day 2 | day 5 | day 8 | 43 | 407k |
| 6 | day 2 | day 4 | day 8 | 44 | 394k |
Findings:
- The XP table says "level 20 takes about two weeks of regular play"; a once-a-day visitor gets there in 10 days, a
  three-times-a-day visitor in 5. Past level 20 the climb is 250 XP a level and levels arrive faster, not slower.
- Coins pile up (200-400k) because the bot buys nothing: the sinks (land, buildings, animals) set the real pace.
- A crop withers as long after ripening as it took to grow, so a once-a-day player can only use crops that grow
  12-24 hours: the choice of crop is the whole game for them (they sit at level 1-2 for the first days).
- Drops per 1000 harvests at 0 stars: golden 6, collectible 62-80 (pity at 30 lifts it), bird 29, super 54, bonus 44.
- Weather (summer): clear 49%, partly cloudy 25%, cloudy 10%, rain 9%, storm 2%, fog 4%; spells average 2.9 blocks (about 9 hours).
