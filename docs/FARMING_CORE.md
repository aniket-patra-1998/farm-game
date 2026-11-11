# Farming is the core: how every system ties back to the field

Today the systems (bees, strays, mystery young, collections, crafting, vehicles) each work alone. In
FarmVille they were all fed by farming and fed it back. This is the design that makes it one loop.

## The loop
**Farm** (plant, harvest, collect) -> **Finds** (creatures, items, materials that turn up while you work)
-> **Homes** (places that need a find to exist, grow as you collect more) -> **Collections and goals**
(sets to complete, missions with rewards) -> **Boosts back to the farm** (pollination, fuel, faster
growth, bigger yields, new land and items) -> farm again.

## 1. Finds: one framework for everything that turns up while farming
Gophers, Queen Bees, birds, bushels, mystery seedlings/eggs/bulbs, strays and collectibles are all "a thing
found by doing farm work". One data file (data/finds.json) describes each family:
- **trigger**: what action rolls it (harvest a crop of a kind, harvest a flower, plant, plow, collect from an
  animal, shake a tree), with a chance, a pity counter and a mastery luck bonus.
- **rarities**: common/uncommon/rare/legendary with weights and names (Gophers: Plain, Brown, Spotted, Golden
  ... each a separate collectable); some are only found on certain crops or at certain times.
- **reward**: goes to a stock (finds owned), shown with a pop-up where it was found.
Code is one `FindsSystem` (rolls, owned counts, pity, saves); new creature = data, not code.

## 2. Homes with prerequisites
A home declares `requires` in the catalog: "own 1 gopher", "own 1 queen bee", "have 10 bushels", "mastery 2
stars on corn", "level N", "building X". The market shows the checklist with what's missing and where to
get it ("find gophers by harvesting crops"), and the item stays locked until met. One `Requirements` checker
serves buildings, upgrades, recipes, land and quests.

## 3. Homes that grow with what you put in
Gopher Garden: needs 1 gopher to build; upgrades by itself as you add more (levels at 3, 8, 15 gophers),
showing a mound and a popping gopher per few owned. Same rule for other homes: capacity/level follow the
count of finds kept (Beehive with queen and workers, Bird Table, Butterfly House).

## 4. Collections and missions
Every find family is a collection (rarities are the items); completing sets, or reaching counts, pays coins,
XP, gems, items. Missions ("find 3 spotted gophers", "harvest 50 wheat", "own a Gopher Garden") come from
data/quests.json and count the same stats ribbons use.

## 5. Boosts back to the farm (so the loop closes)
Bees pollinate plots (done); gophers' rare finds give fertilizer or seeds; Gopher Garden level gives a small
bonus to find chance; birds scare pests; dogs find things; vehicles and fuel speed fieldwork; crafted goods
feed fuel and bushels. Each home states its boost in data.

## 6. Inputs: the field feeds every home (the general rule behind bees and gophers)
Bees needing flowers is one case of a single rule: **every home has inputs, and the field makes them.**
- **Crop by-products.** Each crop family yields a *feed type* when harvested (a chance, more with mastery
  stars): grain (wheat, corn, oats) = Grain; hay/greens (alfalfa, clover, lettuce) = Greens; roots and
  gourds (carrot, beet, pumpkin, potato) = Roots; fruit (berries, apples from trees) = Fruit; flowers = Nectar
  (and the Queen Bee chance from a short list of 4-5 flowers); honey and eggs/milk from homes feed crafting.
  Stored as bushels/feed in the Barn; data/feeds.json maps crop family -> feed type.
- **Each animal family has tastes** (data/animal_tastes.json): hens like Grain, cows Greens, pigs Roots and
  Fruit, sheep Greens, horses Grain and Fruit, goats anything, bees Nectar. A *favourite* gives the biggest
  effect, an *accepted* one a smaller effect, others nothing.
- **Feeding is the action** (feed trough on the home, FarmVille's feed idea): tap the home, pick a feed, it
  is used up. Effects last a set time and stack up to a cap:
  - produce boost: more eggs/milk/wool/truffles per collect;
  - speed boost: the cycle finishes sooner;
  - rare chance: raises the odds of a rare baby, egg or find from that home (rare coat colours, golden
    eggs, twins, rare mystery young);
  - happiness: fed animals show it (they perk up, hop, and a heart rises), unfed ones look hungry.
- **Quality ladder.** Better crops (higher mastery stars, golden or super harvests, pollinated plots) make
  better feed, so the better you farm, the better your animals do. Pollinated crops give Rich feed.
- **Odds are data.** Every number (chance per harvest, boost size, duration, caps) is in data and tuned in
  one place; pity counters keep luck fair.
- **Trees and orchards join in:** fruit from trees is Fruit feed and also the input for crafting; flowers feed
  bees and the Bloom Garden; animals' produce (eggs, milk, wool) feeds crafting buildings and fuel, closing
  the loop: crop -> feed -> animal -> produce -> goods -> fuel/coins -> more land and crops.

One mechanism serves all of it: `Inputs` (feed types, stocks, tastes, effects, durations) as a system; a home
just names which feed it takes and what each does. Gophers, bees and the rest are special cases of "finds"
(section 1) that land in the same stocks.

## Build order
1. `FindsSystem` + data/finds.json + harvest hook; gophers as the first family (found, rarities, pop-up).
1b. `Inputs`: feed types from harvests (data/feeds.json), tastes (data/animal_tastes.json), feeding a home and its effects (produce, speed, rare chance).
2. `Requirements` checker + market checklist; Gopher Garden (needs 1 gopher; auto-upgrades).
3. Move Queen Bees, birds, collectibles onto the same framework; beehive requires a queen found from flowers.
4. Quests from data; boosts per home; then Feed Mill (bushels), Nursery, dogs as finds/homes.
