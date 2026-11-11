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

## Build order
1. `FindsSystem` + data/finds.json + harvest hook; gophers as the first family (found, rarities, pop-up).
2. `Requirements` checker + market checklist; Gopher Garden (needs 1 gopher; auto-upgrades).
3. Move Queen Bees, birds, collectibles onto the same framework; beehive requires a queen found from flowers.
4. Quests from data; boosts per home; then Feed Mill (bushels), Nursery, dogs as finds/homes.
