# Catalog

Every item in the game, generated from `data/catalog/` by `tools/make_catalog.py`. Don't edit this file by hand.

**Layout:** category (one data file) → family (variants that share defaults) → variant (one item).
**Status:** ✅ in the game · 🕓 planned (catalogued from FarmVille, not built yet).

| Category | Families | In game | Planned |
|---|---|---|---|
| Crops | 10 | 29 | 38 |
| Materials | 2 | 10 | 0 |
| Trees | 32 | 28 | 18 |
| Animals | 14 | 33 | 4 |
| Buildings | 6 | 13 | 9 |
| Vehicles | 4 | 4 | 0 |
| Decorations | 7 | 37 | 0 |
| Collectibles | 11 sets | 55 | 0 |
| **All** | **86** | **209** | **69** |

## Adding an item

1. Find its category file in `data/catalog/` and the family it belongs to (or add a family).
2. Add a variant with `id` and `name`, plus only what differs from the family's and file's defaults.
3. Give it art: a `shape` for its placeholder drawing now, and an entry in `art/manifest.json` for final art.
4. Run the tests (Godot, F6 on `tests/run_tests.tscn`) and `python3 tools/make_catalog.py`. The catalog loader names any missing or mistyped field, and any reference to something that doesn't exist.

A new **kind** of thing needs a class: add it to `schema.json` (with `extends` and its fields) and a matching `scripts/catalog/<kind>_def.gd` that extends its parent and overrides only what's different.

## Classes

Each class inherits its parent's fields and rules. The code for each is in `scripts/catalog/`.

```
Item - Anything in the catalog.
  Crop - Planted in plowed plots, harvested when ripe.
  Material - Building materials that drop while farming.
  Placeable (abstract) - Anything placed on the farm.
    Producer (abstract) - Placeables that are collected every cycle.
      Tree - Fruit and nut trees.
      Animal - Animals, loose on the farm or inside their home.
    Building - Holds animals, trees or vehicles; may be built from a frame and expanded.
      Barn - The starter barn: broken until repaired, then storage.
    Vehicle - Works an area of plots per tap and burns fuel.
    Decoration - Scenery. 1 XP per 100 coins (at least 5).
```

### Item

Anything in the catalog.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `id` | string |  | yes | Unique snake_case id. Saves refer to it, so never rename one that has shipped. |
| `name` | string |  | yes | Shown to the player. |
| `kind` | enum of crop, tree, animal, bee, building, barn, vehicle, decor, material |  |  | Set by the class; only override for special cases (bee, barn). |
| `unlock_level` | int | 1 |  | Level that unlocks it. 99 = never in the Market (earned, traded or starter only). |
| `color` | color | "#999999" |  | Main colour of the code-drawn placeholder. |
| `accent` | color |  |  | Second colour of the placeholder. |
| `status` | enum of in_game, planned | "in_game" |  | planned = in the catalog for reference only; the game doesn't load it, and only id and name are required. |
| `note` | string |  |  | Anything a developer should know about this entry. |
| `family` | string |  |  | Set by the loader: the family it's listed under. |
| `category` | string |  |  | Set by the loader: the catalog file it's in. |

### Crop (extends Item)

Planted in plowed plots, harvested when ripe.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `seed_cost` | int |  | yes | Coins to plant one plot. |
| `grow_seconds` | int |  | yes | Time from planting to ripe. |
| `sell_price` | int |  | yes | Coins per harvest before bonuses. |
| `xp` | int | 1 |  | XP per harvest. |
| `shape` | enum of berry, grain, root, stalk, flower, fruit, gourd, spike, fluff, leafy |  | yes | Placeholder drawing. |
| `flower` | bool | false |  | Flower harvests can bring bees and Queen Bees. |

### Material (extends Item)

Building materials that drop while farming.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `basic` | bool | false |  | Basic materials always drop; others only once you own something that uses them. |

### Placeable (extends Item)

Anything placed on the farm.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `cost` | int | 0 |  | Coins in the Market. |
| `gem_cost` | int |  |  | Gems in the Market instead of coins. |
| `w` | int | 1 |  | Footprint width in tiles. |
| `h` | int | 1 |  | Footprint depth in tiles. |
| `roof` | color |  |  | Roof colour of the placeholder. |

### Producer (extends Placeable)

Placeables that are collected every cycle.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `cycle_seconds` | int |  | yes | Time between collections. |
| `payout` | int | 0 |  | Coins per collection. |
| `xp` | int | 1 |  | XP per collection. |
| `product` | string |  |  | What it gives, as shown to the player. |

### Tree (extends Producer)

Fruit and nut trees.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `rare_sapling` | string → Tree |  |  | The rare variety an Orchard can sprout from this tree. |
| `rare_of` | string → Tree |  |  | For a rare variety: the tree it sprouts from. |

### Animal (extends Producer)

Animals, loose on the farm or inside their home.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `breed` | string |  |  | Chicken breed for Mystery Eggs (white, brown, red, grey, black, golden). |
| `stray_only` | bool | false |  | Only wanders in as a stray; never bought. |
| `home` | string → Building |  |  | For strays: the building the player must own before it can appear. |
| `rare_pig` | bool | false |  | A rare breed traded for truffles at the Pig Pen. |

### Building (extends Placeable)

Holds animals, trees or vehicles; may be built from a frame and expanded.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `cycle_seconds` | int | 86400 |  | Time between collections. |
| `levels` | list<int> |  | yes | Capacity at each size, smallest first. |
| `level_names` | list<string> |  |  | Name at each size (e.g. Coop, Big Coop, Huge Coop). |
| `holds` | list<string> → Animal|Tree |  |  | Item ids that can move in. |
| `holds_kind` | enum of tree, vehicle |  |  | Any item of this kind can move in. |
| `one_each` | list<string> → Animal |  |  | Specials kept one at a time, taking no space (a bull, a ram). |
| `build_materials` | materials |  |  | If set, it arrives as a frame finished with these. |
| `expand_materials` | materials |  |  | Paid for each size up. |
| `uses_materials` | list<string> → Material |  |  | Materials that start dropping once you own it. |
| `special` | enum of mystery_eggs, calves, foals, lambs, truffles, nursery, beehive, saplings, garage |  |  | Its FarmVille extra on each collection. |
| `produces` | bool | true |  | false = never ready to collect (the Garage). |
| `grow_days` | int |  |  | Nursery: days for a baby to grow up. |
| `grows_into` | map → Animal |  |  | Nursery: baby id -> adult id. |

### Barn (extends Building)

The starter barn: broken until repaired, then storage.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `repair_parts` | materials |  | yes | Materials needed to repair it. |
| `repair_coins` | int | 0 |  | Coins to repair it. |
| `repair_xp` | int | 0 |  | XP for repairing it. |

### Vehicle (extends Placeable)

Works an area of plots per tap and burns fuel.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `job` | enum of plow, plant, harvest, all |  | yes | What it does to each plot. |
| `fuel_per_plot` | int | 1 |  | Fuel per plot worked. |
| `upgrade_parts` | list<int> |  | yes | Vehicle Parts for each Garage upgrade (2x2 to 3x2, 3x3, 4x3, 4x4). |
| `upgrade_levels` | list<int> |  | yes | Player level each upgrade needs; same length as upgrade_parts. |
| `build_materials` | materials |  |  | If set, it arrives as a chassis finished with these. |
| `build_xp` | int | 0 |  | XP when the chassis is finished. |

### Decoration (extends Placeable)

Scenery. 1 XP per 100 coins (at least 5).

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `shape` | string |  |  | Placeholder drawing (fence, hedge, haybale, ...). Starter scenery is drawn by id instead. |
| `variant` | string |  |  | Shape variant (pine, oak, willow for shade trees). |

## Crops

Crops planted in plowed plots. Ripe window = grow time, clamped to 4 hours to 2 days.

### Berries

Berries.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Strawberries | `strawberries` | 1 | 10 | 4 h | 35 | 1 |
| ✅ | Raspberries | `raspberries` | 8 | 20 | 2 h | 40 | 1 |
| ✅ | Blueberries | `blueberries` | 16 | 40 | 4 h | 75 | 1 |
| ✅ | Cranberries | `cranberries` | 10 | 45 | 10 h | 110 | 2 |
| 🕓 | Blackberries | `blackberries` | 29 |  | 4 h |  |  |
| 🕓 | Elderberries | `elderberries` | 39 |  | 12 h |  |  |

### Grains

Grains.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Wheat | `wheat` | 1 | 15 | 12 h | 60 | 1 |
| ✅ | Corn | `corn` | 20 | 110 | 3 days | 400 | 4 |
| ✅ | Rice | `rice` | 7 | 40 | 12 h | 105 | 2 |
| 🕓 | Rye | `rye` | 21 |  | 20 h |  |  |
| 🕓 | Red Wheat | `red_wheat` | 30 |  | 3 days |  |  |
| 🕓 | Oats | `oats` | 53 |  | 8 h |  |  |
| 🕓 | Posole Corn | `posole_corn` | 54 |  | 12 h |  |  |
| 🕓 | Amaranth | `amaranth` | 76 |  | 16 h |  |  |

### Beans and Nuts

Beans and Nuts.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Soybeans | `soybeans` | 2 | 20 | 1 day | 80 | 2 |
| ✅ | Peanuts | `peanuts` | 3 | 25 | 16 h | 80 | 2 |
| 🕓 | Peas | `peas` | 32 |  | 1 day |  |  |
| 🕓 | Purple Pod Peas | `purple_pod_peas` | 40 |  | 1 day |  |  |
| 🕓 | Coffee | `coffee` | 23 |  | 16 h |  |  |

### Flowers

Flowers.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Sunflowers | `sunflowers` | 12 | 50 | 1 day | 160 | 2 |
| ✅ | Lilac | `lilac` | 4 | 30 | 10 h | 75 | 1 |
| ✅ | Daffodils | `daffodils` | 8 | 50 | 2 days | 180 | 3 |
| ✅ | Morning Glory | `morning_glory` | 13 | 50 | 12 h | 125 | 2 |
| ✅ | Red Tulips | `red_tulips` | 15 | 60 | 1 day | 190 | 2 |
| ✅ | Lavender | `lavender` | 17 | 80 | 2 days | 300 | 3 |
| 🕓 | Gladiolus | `gladiolus` | 28 |  | 6 h |  |  |
| 🕓 | Lilies | `lilies` | 35 |  | 1 day |  |  |
| 🕓 | Purple Poppies | `purple_poppies` | 38 |  | 8 h |  |  |
| 🕓 | Columbine | `columbine` | 44 |  | 4 h |  |  |
| 🕓 | Iris | `iris` | 45 |  | 1 day |  |  |
| 🕓 | Orange Daisies | `orange_daisies` | 59 |  | 1 day |  |  |
| 🕓 | White Roses | `white_roses` | 80 |  | 1 day |  |  |
| 🕓 | Forget-me-nots | `forget_me_nots` | 90 |  | 18 h |  |  |

### Roots

Roots.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Potatoes | `potatoes` | 20 | 100 | 3 days | 380 | 4 |
| ✅ | Carrots | `carrots` | 9 | 40 | 12 h | 110 | 2 |
| 🕓 | Onions | `onions` | 34 |  | 12 h |  |  |
| 🕓 | Ginger | `ginger` | 42 |  | 18 h |  |  |
| 🕓 | Heirloom Carrots | `heirloom_carrots` | 57 |  | 12 h |  |  |

### Gourds and Melons

Gourds and Melons.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Pumpkins | `pumpkins` | 5 | 30 | 8 h | 70 | 1 |
| ✅ | Squash | `squash` | 4 | 35 | 2 days | 150 | 3 |
| ✅ | Watermelon | `watermelon` | 18 | 110 | 4 days | 460 | 5 |
| 🕓 | Zucchini | `zucchini` | 27 |  | 16 h |  |  |
| 🕓 | Yellow Melon | `yellow_melon` | 33 |  | 4 days |  |  |
| 🕓 | Acorn Squash | `acorn_squash` | 36 |  | 10 h |  |  |
| 🕓 | Square Melon | `square_melon` | 52 |  | 1 day |  |  |
| 🕓 | Carnival Squash | `carnival_squash` | 63 |  | 8 h |  |  |
| 🕓 | Cucumber | `cucumber` | 43 |  | 1 day |  |  |

### Vegetables

Vegetables.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Tomatoes | `tomatoes` | 14 | 50 | 8 h | 110 | 2 |
| ✅ | Eggplant | `eggplant` | 1 | 25 | 2 days | 110 | 2 |
| ✅ | Bell Peppers | `bell_peppers` | 11 | 60 | 2 days | 220 | 3 |
| ✅ | Spinach | `spinach` | 6 | 35 | 14 h | 100 | 2 |
| ✅ | Artichokes | `artichokes` | 6 | 60 | 4 days | 260 | 4 |
| 🕓 | Ghost Chili | `ghost_chili` | 26 |  | 6 h |  |  |
| 🕓 | Cabbage | `cabbage` | 27 |  | 2 days |  |  |
| 🕓 | Broccoli | `broccoli` | 35 |  | 2 days |  |  |
| 🕓 | Asparagus | `asparagus` | 37 |  | 16 h |  |  |

### Sweet Crops

Sweet Crops.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Sugarcane | `sugarcane` | 19 | 60 | 8 h | 125 | 2 |
| ✅ | Pineapples | `pineapples` | 15 | 75 | 2 days | 280 | 3 |
| ✅ | Grapes | `grapes` | 19 | 80 | 1 day | 230 | 3 |
| 🕓 | White Grapes | `white_grapes` | 29 |  | 12 h |  |  |

### Fibre

Fibre.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Cotton | `cotton` | 9 | 60 | 3 days | 240 | 3 |
| 🕓 | Bamboo | `bamboo` | 60 |  | 16 h |  |  |

### Herbs and Teas

Herbs and Teas.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| 🕓 | Green Tea | `green_tea` | 28 |  | 10 h |  |  |
| 🕓 | Basil | `basil` | 48 |  | 10 h |  |  |
| 🕓 | Lemon Balm | `lemon_balm` | 50 |  | 6 h |  |  |
| 🕓 | Saffron | `saffron` | 64 |  | 10 h |  |  |
| 🕓 | Clover | `clover` | 70 |  | 4 h |  |  |

## Materials

Building materials. basic ones always drop; the others drop once you own something that uses them.

### Basic Materials

Always drop: frames, expansions and the barn need them.

Shared: `basic` = true

| | Item | id | Basic |
|---|---|---|---|
| ✅ | Bricks | `bricks` | yes |
| ✅ | Nails | `nails` | yes |
| ✅ | Wooden Boards | `boards` | yes |

### Special Materials

Drop once you own something that uses them.

| | Item | id | Basic |
|---|---|---|---|
| ✅ | Harnesses | `harnesses` |  |
| ✅ | Horseshoes | `horseshoes` |  |
| ✅ | Baby Bottles | `bottles` |  |
| ✅ | Blankets | `blankets` |  |
| ✅ | Smokers | `smokers` |  |
| ✅ | Beeswax | `beeswax` |  |
| ✅ | Vehicle Parts | `vehicle_parts` |  |

## Trees

Fruit and nut trees: harvested every cycle; can live in an Orchard. Rare varieties link both ways with rare_sapling / rare_of.

### Apple Trees

Apple trees, and the rare variety an Orchard can sprout from them.

Shared: `cycle_seconds` = 172800

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Apple Tree | `apple_tree` | 2 | 150 | 2 days | 60 |  |
| ✅ | Honeycrisp Apple Tree | `honeycrisp_apple_tree` | never sold | free | 2 days | 90 | rare variety of apple tree |

### Lemon Trees

Lemon trees, and the rare variety an Orchard can sprout from them.

Shared: `cycle_seconds` = 172800

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Lemon Tree | `lemon_tree` | 4 | 250 | 2 days | 85 |  |
| ✅ | Meyer Lemon Tree | `meyer_lemon_tree` | never sold | free | 2 days | 128 | rare variety of lemon tree |

### Cherry Trees

Cherry trees, and the rare variety an Orchard can sprout from them.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Cherry Tree | `cherry_tree` | 6 | 400 | 3 days | 140 |  |
| ✅ | Rainier Cherry Tree | `rainier_cherry_tree` | never sold | free | 3 days | 210 | rare variety of cherry tree |

### Orange Trees

Orange trees, and the rare variety an Orchard can sprout from them.

Shared: `cycle_seconds` = 172800

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Orange Tree | `orange_tree` | 8 | 500 | 2 days | 120 |  |
| ✅ | Blood Orange Tree | `blood_orange_tree` | never sold | free | 2 days | 180 | rare variety of orange tree |

### Peach Trees

Peach trees, and the rare variety an Orchard can sprout from them.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Peach Tree | `peach_tree` | 10 | 800 | 3 days | 200 |  |
| ✅ | Elberta Peach Tree | `elberta_peach_tree` | never sold | free | 3 days | 300 | rare variety of peach tree |

### Mango Trees

Mango trees, and the rare variety an Orchard can sprout from them.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Mango Tree | `mango_tree` | 12 | 1,200 | 3 days | 280 |  |
| ✅ | Alphonso Mango Tree | `alphonso_mango_tree` | never sold | free | 3 days | 420 | rare variety of mango tree |

### Plum Trees

Plum trees, and the rare variety an Orchard can sprout from them.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Plum Tree | `plum_tree` | 3 | 200 | 3 days | 75 |  |
| ✅ | Golden Plum Tree | `golden_plum_tree` | never sold | free | 3 days | 112 | rare variety of plum tree |

### Fig Trees

Fig trees, and the rare variety an Orchard can sprout from them.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Fig Tree | `fig_tree` | 5 | 300 | 3 days | 105 |  |
| ✅ | Black Mission Fig Tree | `black_mission_fig_tree` | never sold | free | 3 days | 158 | rare variety of fig tree |

### Banana Trees

Banana trees, and the rare variety an Orchard can sprout from them.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Banana Tree | `banana_tree` | 7 | 450 | 3 days | 150 |  |
| ✅ | Red Banana Tree | `red_banana_tree` | never sold | free | 3 days | 225 | rare variety of banana tree |

### Avocado Trees

Avocado trees, and the rare variety an Orchard can sprout from them.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Avocado Tree | `avocado_tree` | 9 | 550 | 3 days | 180 |  |
| ✅ | Hass Avocado Tree | `hass_avocado_tree` | never sold | free | 3 days | 270 | rare variety of avocado tree |

### Apricot Trees

Apricot trees, and the rare variety an Orchard can sprout from them.

Shared: `cycle_seconds` = 345600

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Apricot Tree | `apricot_tree` | 11 | 700 | 4 days | 250 |  |
| ✅ | Golden Apricot Tree | `golden_apricot_tree` | never sold | free | 4 days | 375 | rare variety of apricot tree |

### Pomegranate Trees

Pomegranate trees, and the rare variety an Orchard can sprout from them.

Shared: `cycle_seconds` = 432000

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Pomegranate Tree | `pomegranate_tree` | 14 | 900 | 5 days | 340 |  |
| ✅ | Wonderful Pomegranate Tree | `wonderful_pomegranate_tree` | never sold | free | 5 days | 510 | rare variety of pomegranate tree |

### Olive Trees

Olive trees, and the rare variety an Orchard can sprout from them.

Shared: `cycle_seconds` = 345600

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Olive Tree | `olive_tree` | 16 | 1,100 | 4 days | 360 |  |
| ✅ | Mission Olive Tree | `mission_olive_tree` | never sold | free | 4 days | 540 | rare variety of olive tree |

### Coconut Trees

Coconut trees, and the rare variety an Orchard can sprout from them.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Coconut Tree | `coconut_tree` | 18 | 1,400 | 3 days | 380 |  |
| ✅ | King Coconut Tree | `king_coconut_tree` | never sold | free | 3 days | 570 | rare variety of coconut tree |

### Lime Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Lime Tree | `lime_tree` | 1 |  | 5 days |  |  |

### Grapefruit Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Grapefruit Tree | `grapefruit_tree` | 1 |  | 3 days |  |  |

### Mandarin Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Mandarin Tree | `mandarin_tree` | 1 |  | 4 days |  |  |

### Date Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Date Tree | `date_tree` | 1 |  | 3 days |  |  |

### Guava Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Guava Tree | `guava_tree` | 1 |  | 3 days |  |  |

### Persimmon Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Persimmon Tree | `persimmon_tree` | 1 |  | 4 days |  |  |

### Starfruit Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Starfruit Tree | `starfruit_tree` | 1 |  | 4 days |  |  |

### Passion Fruit Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Passion Fruit Tree | `passion_fruit_tree` | 1 |  | 5 days |  |  |

### Jackfruit Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Jackfruit Tree | `jackfruit_tree` | 1 |  | 3 days |  |  |

### Asian Pear Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Asian Pear Tree | `asian_pear_tree` | 1 |  | 2 days |  |  |

### Tamarind Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Tamarind Tree | `tamarind_tree` | 1 |  | 3 days |  |  |

### Almond Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Almond Tree | `almond_tree` | 1 |  | 3 days |  |  |

### Walnut Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Walnut Tree | `walnut_tree` | 1 |  | 3 days |  |  |

### Cashew Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Cashew Tree | `cashew_tree` | 1 |  | 3 days |  |  |

### Chestnut Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Chestnut Tree | `chestnut_tree` | 1 |  | 2 days |  |  |

### Hazelnut Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Hazelnut Tree | `hazelnut_tree` | 1 |  | 2 days |  |  |

### Pecan Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Pecan Tree | `pecan_tree` | 1 |  | 2 days |  |  |

### Pistachio Trees

From FarmVille's tree list; not built yet.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| 🕓 | Pistachio Tree | `pistachio_tree` | 1 |  | 2 days |  |  |

## Animals

Animals: collected every cycle; live in the building whose holds lists them. stray_only animals wander in and are adopted, never bought.

### Chickens

Live in the Chicken Coop; breeds decide which Mystery Eggs turn up.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | White Chicken | `chicken` | 1 | 120 | Eggs | 1 day | 40 | breed: white |
| ✅ | Brown Chicken | `brown_chicken` | 5 | 5 gems | Brown Eggs | 1 day | 45 | breed: brown |
| ✅ | Rhode Island Red | `red_chicken` | 9 | 8 gems | Eggs | 1 day | 50 | breed: red |
| ✅ | Scots Grey | `grey_chicken` | 12 | 12 gems | Eggs | 1 day | 55 | breed: grey |
| ✅ | Black Chicken | `black_chicken` | never sold | free | Eggs | 1 day | 60 | breed: black |
| ✅ | Golden Chicken | `golden_chicken` | never sold | free | Golden Eggs | 1 day | 90 | breed: golden |

### Turkeys

Share the Chicken Coop.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Turkey | `turkey` | 10 | 500 | Feathers | 1 day | 120 |  |

### Ducks

Live in the Duck Pond.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Duck | `duck` | 4 | 200 | Feathers | 1 day | 60 |  |

### Geese

Share the Duck Pond.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Goose | `goose` | 13 | 650 | Down | 1 day | 150 |  |

### Cows

Live in the Dairy Farm. A bull brings calves, raised in the Nursery.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Cow | `cow` | 3 | 300 | Milk | 1 day | 85 |  |
| ✅ | Bull | `bull` | never sold | free | Nothing | 1 day | 0 | stray, needs a cow shed |
| ✅ | Calf | `calf` | never sold | free | Milk | 1 day | 20 |  |
| 🕓 | Brown Cow (verify against FarmVille before building) | `brown_cow` | 1 |  |  | 1 day |  |  |
| 🕓 | Pink Cow (verify against FarmVille before building) | `pink_cow` | 1 |  |  | 1 day |  |  |
| 🕓 | Longhorn Cattle (verify against FarmVille before building) | `longhorn` | 1 |  |  | 1 day |  |  |

### Oxen

Share the Dairy Farm.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Ox | `ox` | 12 | 2,000 | Fertilizer | 2 days | 120 |  |

### Sheep

Live in the Sheep Pen. A ram brings lambs.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Sheep | `sheep` | 5 | 350 | Wool | 1 day | 95 |  |
| ✅ | Ram | `ram` | never sold | free | Nothing | 1 day | 0 | stray, needs a sheep pen |
| ✅ | Lamb | `lamb` | never sold | free | Wool | 1 day | 20 |  |
| 🕓 | Black Sheep (verify against FarmVille before building) | `black_sheep` | 1 |  |  | 1 day |  |  |

### Llamas and Alpacas

Share the Sheep Pen; give fleece.

Shared: `product` = "Fleece", `cycle_seconds` = 172800

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Llama | `llama` | 18 | 1,000 | Fleece | 2 days | 320 |  |
| ✅ | Alpaca | `alpaca` | 16 | 3,000 | Fleece | 2 days | 150 |  |

### Pigs

Live in the Pig Pen and forage for truffles. Rare breeds are traded for truffles; a boar brings piglets.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Pig | `pig` | 7 | 450 | Truffles | 1 day | 110 |  |
| ✅ | Berkshire Pig | `berkshire_pig` | never sold | free | Truffles | 1 day | 160 | traded for truffles |
| ✅ | Tamworth Pig | `tamworth_pig` | never sold | free | Truffles | 1 day | 170 | traded for truffles |
| ✅ | Spotted Pig | `spotted_pig` | never sold | free | Truffles | 1 day | 180 | traded for truffles |
| ✅ | Kunekune Pig | `kunekune_pig` | never sold | free | Truffles | 1 day | 200 | traded for truffles |
| ✅ | Boar | `boar` | never sold | free | Nothing | 1 day | 0 | stray, needs a pig pen |
| ✅ | Piglet | `piglet` | never sold | free | Truffles | 1 day | 20 |  |

### Goats

Live in the Goat Pen.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Goat | `goat` | 9 | 600 | Goat Milk | 2 days | 200 |  |

### Horses

Live in the Horse Stable. A stallion brings foals.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Horse | `horse` | 11 | 900 | Horse Hair | 3 days | 320 |  |
| ✅ | Pony | `pony` | 10 | 1,500 | Horse Hair | 2 days | 95 |  |
| ✅ | Stallion | `stallion` | never sold | free | Nothing | 1 day | 0 | stray, needs a horse stable |
| ✅ | Foal | `foal` | never sold | free | Horse Hair | 1 day | 20 |  |

### Donkeys

Share the Horse Stable.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Donkey | `donkey` | 15 | 800 | Donkey Milk | 2 days | 270 |  |

### Rabbits

Live in the Rabbit Hutch.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Rabbit | `rabbit` | 8 | 400 | Fur | 1 day | 100 |  |

### Bees

Join a Beehive that has a Queen Bee; make honey and pollinate crops.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Bee | `bee` | never sold | free | Honey | 1 day | 6 |  |

## Buildings

Buildings that hold animals, trees or vehicles. levels = capacity at each size; frames (build_materials) are finished with materials; expand_materials pay for each size up.

### Animal Homes

Hold animals; one tap collects everyone inside.

| | Item | id | Unlock | Cost | Size | Holds | Built from | Special |
|---|---|---|---|---|---|---|---|---|
| ✅ | Chicken Coop | `chicken_coop` | 4 | 5,000 | 3x3 | 20 / 40 / 60 |  | mystery_eggs |
| ✅ | Duck Pond | `duck_pond` | 5 | 4,000 | 3x3 | 20 / 30 / 40 |  |  |
| ✅ | Dairy Farm | `cow_shed` | 6 | 10,000 | 4x3 | 20 / 30 / 40 |  | calves |
| ✅ | Sheep Pen | `sheep_pen` | 7 | 6,000 | 3x3 | 20 / 30 / 40 |  | lambs |
| ✅ | Goat Pen | `goat_pen` | 9 | 6,000 | 3x3 | 20 / 30 / 40 |  |  |
| ✅ | Rabbit Hutch | `rabbit_hutch` | 8 | 4,000 | 2x2 | 20 / 30 / 40 |  |  |
| ✅ | Pig Pen | `pig_pen` | 16 | 5,000 | 3x3 | 30 | frame | truffles |
| ✅ | Horse Stable | `horse_stable` | 12 | 5,000 | 4x4 | 20 / 25 / 30 / 35 / 40 | frame | foals |

### Nursery

Raises baby animals into adults.

| | Item | id | Unlock | Cost | Size | Holds | Built from | Special |
|---|---|---|---|---|---|---|---|---|
| ✅ | Nursery Barn | `nursery_barn` | 8 | free | 4x3 | 20 / 30 / 40 | frame | nursery |

### Orchards

Hold trees.

| | Item | id | Unlock | Cost | Size | Holds | Built from | Special |
|---|---|---|---|---|---|---|---|---|
| ✅ | Orchard | `orchard` | 8 | 6,000 | 4x4 | 20 / 30 / 40 |  | saplings |

### Production

Make goods from what the farm grows.

| | Item | id | Unlock | Cost | Size | Holds | Built from | Special |
|---|---|---|---|---|---|---|---|---|
| ✅ | Beehive | `beehive` | 3 | 5,000 | 2x2 | 200 | frame | beehive |
| 🕓 | Greenhouse (breeds hybrid crop seeds) | `greenhouse` | 1 |  |  |  |  |  |
| 🕓 | Windmill (grinds grain into flour) | `windmill` | 1 |  |  |  |  |  |

### Crafting

FarmVille's crafting cottages: crops in, goods out.

| | Item | id | Unlock | Cost | Size | Holds | Built from | Special |
|---|---|---|---|---|---|---|---|---|
| 🕓 | Bakery | `bakery` | 1 |  |  |  |  |  |
| 🕓 | Winery | `winery` | 1 |  |  |  |  |  |
| 🕓 | Spa | `spa` | 1 |  |  |  |  |  |
| 🕓 | Juice Press | `juice_press` | 1 |  |  |  |  |  |
| 🕓 | Spinning Mill | `spinning_mill` | 1 |  |  |  |  |  |

### Storage

Keep things off the farm.

| | Item | id | Unlock | Cost | Size | Holds | Built from | Special |
|---|---|---|---|---|---|---|---|---|
| ✅ | Barn | `barn` | never sold | free | 3x3 | 30 |  |  |
| ✅ | Garage | `garage` | 22 | 50,000 | 3x3 | 20 | frame | garage |
| 🕓 | Storage Shed | `storage_shed` | 1 |  |  |  |  |  |
| 🕓 | Silo | `silo` | 1 |  |  |  |  |  |

## Vehicles

Vehicles work an area of plots per tap (2x2 up to 4x4) and burn fuel. Upgrades in the Garage cost Vehicle Parts.

### Tractors

Plow.

| | Item | id | Unlock | Cost | Job | Fuel a plot | Upgrade parts |
|---|---|---|---|---|---|---|---|
| ✅ | Tractor | `tractor` | 12 | 5,000 | plow | 1 | 2, 5, 10, 15 |

### Harvesters

Harvest.

| | Item | id | Unlock | Cost | Job | Fuel a plot | Upgrade parts |
|---|---|---|---|---|---|---|---|
| ✅ | Harvester | `harvester` | 13 | 30,000 | harvest | 1 | 2, 5, 10, 15 |

### Seeders

Plant.

| | Item | id | Unlock | Cost | Job | Fuel a plot | Upgrade parts |
|---|---|---|---|---|---|---|---|
| ✅ | Seeder | `seeder` | 14 | 30,000 | plant | 1 | 2, 5, 10, 15 |

### Combines

Harvest, plow and plant in one tap.

| | Item | id | Unlock | Cost | Job | Fuel a plot | Upgrade parts |
|---|---|---|---|---|---|---|---|
| ✅ | Combine | `combine` | 31 | 500,000 | all | 3 | 6, 15, 30, 45 |

## Decorations

Decorations: 1 XP per 100 coins (at least 5), sell for 5%. shape picks the drawing until final art exists.

### Starter Scenery

On every new farm.

| | Item | id | Unlock | Cost | Size | Shape |
|---|---|---|---|---|---|---|
| ✅ | Farmhouse | `farmhouse` | never sold | free | 3x3 |  |
| ✅ | Mailbox | `mailbox` | never sold | free | 1x1 |  |
| ✅ | Farm Stand | `farm_stand` | never sold | free | 1x1 |  |

### Paths

Ground tiles.

| | Item | id | Unlock | Cost | Size | Shape |
|---|---|---|---|---|---|---|
| ✅ | Dirt Path | `dirt_path` | 1 | 20 | 1x1 | path |
| ✅ | Brick Path | `brick_path` | 5 | 50 | 1x1 | path |
| ✅ | Stone Path | `stone_path` | 8 | 80 | 1x1 | path |

### Fences and Walls

Run along a tile; Rotate turns them.

| | Item | id | Unlock | Cost | Size | Shape |
|---|---|---|---|---|---|---|
| ✅ | Wooden Fence | `wooden_fence` | 1 | 50 | 1x1 | fence |
| ✅ | White Picket Fence | `white_picket_fence` | 3 | 300 | 1x1 | fence |
| ✅ | Hedge | `hedge` | 4 | 250 | 1x1 | hedge |
| ✅ | Stone Wall | `stone_wall` | 6 | 400 | 1x1 | wall |

### Farm Props

| | Item | id | Unlock | Cost | Size | Shape |
|---|---|---|---|---|---|---|
| ✅ | Hay Bale | `hay_bale` | 1 | 100 | 1x1 | haybale |
| ✅ | Haystack | `haystack` | 3 | 300 | 1x1 | haystack |
| ✅ | Scarecrow | `scarecrow` | 2 | 500 | 1x1 | scarecrow |
| ✅ | Water Trough | `water_trough` | 4 | 800 | 1x1 | trough |
| ✅ | Bonfire | `bonfire` | 4 | 400 | 1x1 | bonfire |
| ✅ | Wheelbarrow | `wheelbarrow` | 5 | 600 | 1x1 | wheelbarrow |
| ✅ | Water Well | `water_well` | 7 | 1,500 | 1x1 | well |

### Garden

| | Item | id | Unlock | Cost | Size | Shape |
|---|---|---|---|---|---|---|
| ✅ | Flower Bed | `flower_bed` | 2 | 300 | 1x1 | flowerbed |
| ✅ | Pink Flamingo | `pink_flamingo` | 3 | 200 | 1x1 | flamingo |
| ✅ | Bench | `bench` | 3 | 400 | 1x1 | bench |
| ✅ | Birdhouse | `birdhouse` | 5 | 600 | 1x1 | birdhouse |
| ✅ | Birdbath | `birdbath` | 6 | 700 | 1x1 | birdbath |
| ✅ | Picnic Table | `picnic_table` | 6 | 1,500 | 1x1 | picnic |
| ✅ | Garden Gnome | `garden_gnome` | 7 | 500 | 1x1 | gnome |
| ✅ | Lamp Post | `lamp_post` | 8 | 900 | 1x1 | lamp |
| ✅ | Sundial | `sundial` | 9 | 2,500 | 1x1 | sundial |
| ✅ | Small Pond | `small_pond` | 10 | 2,500 | 2x2 | pond |
| ✅ | Arbor | `arbor` | 10 | 5,000 | 1x1 | arbor |
| ✅ | Wooden Bridge | `wooden_bridge` | 11 | 3,000 | 1x1 | bridge |
| ✅ | Fountain | `fountain` | 14 | 15,000 | 2x2 | fountain |
| ✅ | Gazebo | `gazebo` | 15 | 25,000 | 2x2 | gazebo |
| ✅ | Log Cabin | `log_cabin` | 20 | 250,000 | 3x3 | cabin |

### Shade Trees

Trees for looks; they give no fruit.

| | Item | id | Unlock | Cost | Size | Shape |
|---|---|---|---|---|---|---|
| ✅ | Pine Tree | `pine_tree` | 4 | 800 | 1x1 | shadetree |
| ✅ | Oak Tree | `oak_tree` | 5 | 1,000 | 1x1 | shadetree |
| ✅ | Maple Tree | `maple_tree` | 9 | 1,200 | 1x1 | shadetree |
| ✅ | Willow Tree | `willow_tree` | 12 | 2,000 | 1x1 | shadetree |

### Earned

Given, never bought.

| | Item | id | Unlock | Cost | Size | Shape |
|---|---|---|---|---|---|---|
| ✅ | Mastery Sign | `mastery_sign` | never sold | free | 1x1 | mastery |

## Collectibles

Drops found while harvesting, gathered into sets and traded in for rewards (`data/collections.json`).

### Berry Patch

Found from strawberries, raspberries, blueberries, cranberries. Trade-in reward: 500 coins, 25 XP.

Ladybug Pin, Berry Basket, Garden Gloves, Straw Hat, Tin Watering Can

### Golden Fields

Found from wheat, corn, rice. Trade-in reward: 800 coins, 40 XP.

Scarecrow Button, Grain Sack, Old Sickle, Corn Doll, Harvest Charm

### Bean Counter

Found from soybeans, peanuts. Trade-in reward: 600 coins, 30 XP.

Seed Pouch, Pod Peeler, Peanut Jar, Bean Scoop, Shelling Bowl

### Flower Show

Found from sunflowers, lilac, daffodils. Trade-in reward: 1,000 coins, 50 XP.

Bee Badge, Seed Packet, Pressed Petal, Flower Press, Garden Trowel

### Bouquet

Found from morning glory, red tulips, lavender. Trade-in reward: 1,200 coins, 50 XP.

Ribbon Bow, Flower Snips, Tulip Bulb, Lavender Sachet, Glass Vase

### Root Cellar

Found from potatoes, carrots. Trade-in reward: 1,500 coins, 75 XP.

Oil Lantern, Pickle Jar, Rusty Key, Old Almanac, Spinning Top

### Gourd Gallery

Found from pumpkins, squash, watermelon. Trade-in reward: 1,000 coins, 45 XP.

Carving Knife, Vine Clip, Melon Baller, Gourd Rattle, Prize Ribbon

### Market Garden

Found from tomatoes, eggplant, bell peppers, spinach, artichokes. Trade-in reward: 1,000 coins, 45 XP.

Trowel, Garden Twine, Pepper Pot, Salad Spinner, Seed Packet

### Sweet Tooth

Found from sugarcane, pineapples, grapes. Trade-in reward: 1,500 coins, 60 XP.

Candy Cane, Pineapple Crown, Grape Press, Sugar Cube, Honey Dipper

### Cotton Mill

Found from cotton. Trade-in reward: 1,200 coins, 50 XP.

Spindle, Cotton Boll, Thimble, Bobbin, Quilt Square

### Farm Birds

Found spotted while farming. Trade-in reward: 1,200 coins, 60 XP.

Robin, Sparrow, Bluebird, Cardinal, Goldfinch
