# Draft for approval: feeds and animal tastes (Farming core, step 1b)

Status: **draft, nothing built yet.** Every number below is an estimate to tune with `tools/balance_sim`
(FarmVille's real rates were never published). Everything here is **our own touch**, not original FarmVille 2009
(there the farmer did not feed animals); it will be marked as such in the game and can be switched off as a whole
by one flag (`feeds.enabled`) so a "pure FarmVille" mode stays possible.

## 1. Feed types (5)
| Feed | Comes from | Kept in |
|---|---|---|
| Grain | grains, beans | Barn (stock) |
| Greens | vegetables (leafy), herbs, clover | Barn |
| Roots | roots, gourds | Barn |
| Fruit | berries, sweets, tree fruit and nuts | Barn |
| Nectar | flowers (and blooms) | Beehives, Bloom Garden |

Rich variant of each (same type, bigger effect) when the harvest was golden, super, or from a pollinated plot.

## 2. Getting feed
- Harvesting a crop gives its family's feed with chance `base 0.35`, +0.05 per mastery star on that crop (so up to
  0.50), **only once the player owns a home that takes that feed** (so a farm with no animals sees no feed clutter).
- One feed is one unit; a harvest of a golden/super/pollinated crop gives a Rich unit.
- Trees: collecting a ripe tree gives 1 Fruit.
- Stock cap per type: 30 in the Barn, +10 per Barn upgrade (Barn already has upgrade levels). Extra is not lost:
  at the cap it is sold for 2 coins automatically, with a small float "+2".
- Everything above is `data/feeds.json` (family -> feed, chances, caps), read through `Balance` for the numbers.

## 3. Tastes (data/animal_tastes.json)
| Animal family | Favourite | Accepted |
|---|---|---|
| Chicken, Turkey, Duck, Goose | Grain | Greens |
| Cow, Ox | Greens | Grain |
| Sheep, Llama, Alpaca | Greens | Roots |
| Pig | Roots | Fruit, Grain |
| Horse, Pony, Donkey | Grain | Fruit, Roots |
| Goat | Roots, Greens, Fruit (anything) | Grain |
| Rabbit | Greens | Roots |
| Bee | Nectar | none |
| Turtle | Greens | Fruit |

A favourite gives the full effect, an accepted feed 50% of it, anything else is refused (it just does not take it,
nothing is wasted). Babies take the same feed as their parents.

## 4. Feeding and effects
Tap an animal or its home -> a small feed picker shows only what you hold and what each does for that animal.
One feed per animal, used up. **One effect per feed** (kept simple):
| Effect | Favourite | Accepted | Lasts |
|---|---|---|---|
| Produce boost (more coins from the next collect) | +20% | +10% | until that collect |
| Speed boost (the cycle finishes sooner) | -10% time | -5% | the current cycle |
| Rare chance (rare baby, golden egg, twin, rare mystery young) | x1.5 | x1.2 | the current cycle |

The picker offers the three effects as the choice (Grain for a hen can be "produce", "speed" or "rare"): a Rich
feed adds half again to the chosen effect. Effects of different animals do not stack on one animal: feeding again
replaces the effect only if it is bigger. No penalty for not feeding: an unfed animal produces as it does today,
so the system only ever gives a bonus (nobody comes back to a dead farm).

Happiness (visible only): a fed animal hops and shows a heart; one that has gone a whole cycle unfed shows a small
hungry thought bubble, with no gameplay penalty.

## 5. Where it plugs in (no game.gd growth)
- `FeedSystem` (a `GameSystem`): stocks, caps, rolls on harvest, the effect on a home; saves its own fields.
- Harvest hook in `FieldSystem` and collect hook on trees; `ProducerDef` gets `taste` from the family;
  `Producer payout/cycle/rare` read the effect, so the effect lives with the item's own class.
- HUD: Barn panel shows the feed stocks; the feed picker is a small panel on tapping a home (`HudFeed`).
- Tests: each family has a taste; the chances/caps are in data; effects change payout/cycle/rare as stated;
  nothing is lost at the cap; save and load; "pure FarmVille" flag turns it all off.

## Decided by you
- Hungry animals **produce less** (not bonus-only). Proposed numbers: unfed -30% coins per collect (never zero), fed
  normal, favourite/rich feed as the effects table. Needs the helpers below so it is not a chore.
- Five feed types.
- Helpers: feeding is also done by the farmhand (and any future helper that fits: arborist feeds nothing, trees
  have no feed). Rule for all future systems: each action is declared once with which helpers can do it, and a test
  fails if a new action has no declaration.
