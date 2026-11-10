# Catalog

Every item in the game, generated from `data/catalog/` by `tools/make_catalog.py`. Don't edit this file by hand.

**Layout:** category (one data file) → family (variants that share defaults) → variant (one item).
**Status:** ✅ in the game · 🕓 planned (catalogued from FarmVille, not built yet).

| Category | Families | In game | Planned |
|---|---|---|---|
| Crops | 10 | 70 | 0 |
| Materials | 2 | 10 | 0 |
| Trees | 32 | 46 | 0 |
| Animals | 15 | 68 | 0 |
| Buildings | 6 | 17 | 6 |
| Vehicles | 4 | 4 | 0 |
| Decorations | 7 | 38 | 0 |
| recipes | 3 | 45 | 0 |
| Collectibles | 22 sets | 110 | 0 |
| **All** | **101** | **408** | **6** |

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
    Building - Holds animals, trees or vehicles; may be built from a frame and grown size by size.
      Barn - The starter barn: broken until repaired, then storage.
      Crafting - FarmVille's crafting cottages: bushels in, goods out. Sizes are star levels (capacity = crafting slots); each star up costs its size's coins and recipe stars, or its gems.
    Vehicle - Works an area of plots per tap and burns fuel.
    Decoration - Scenery. 1 XP per 100 coins (at least 5).
  Recipe - Something a crafting building makes from bushels.
```

### Item

Anything in the catalog.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `id` | string |  | yes | Unique snake_case id. Saves refer to it, so never rename one that has shipped. |
| `name` | string |  | yes | Shown to the player. |
| `kind` | enum of crop, tree, animal, bee, building, barn, vehicle, decor, material, crafting, recipe |  |  | Set by the class; only override for special cases (bee, barn). |
| `unlock_level` | int | 1 |  | Level that unlocks it. 99 = never in the Market (earned, traded or starter only). |
| `color` | color | "#999999" |  | Main colour of the code-drawn placeholder. |
| `accent` | color |  |  | Second colour of the placeholder. |
| `status` | enum of in_game, planned | "in_game" |  | planned = in the catalog for reference only; the game doesn't load it, and only id and name are required. |
| `note` | string |  |  | Anything a developer should know about this entry. |
| `family` | string |  |  | Set by the loader: the family it's listed under. |
| `category` | string |  |  | Set by the loader: the catalog file it's in. |
| `look` | string |  |  | How it looks, in a few words, for art generation (defaults to its name). |
| `art_fill` | number |  |  | Share of its footprint width its art should fill (overrides the class's). |

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
| `lost` | bool | false |  | A lost animal: only wanders onto the farm (FarmVille's lost animals) and is adopted for free; never in the Market. |
| `young` | bool | false |  | A baby: drawn small and painted as a young animal. |
| `baby` | string → Animal |  |  | The baby this breed has when its home brings one (a Hereford Cow has Hereford Calves). Empty: the plain calf or foal. |
| `grows_into` | string → Animal |  |  | Grows into this animal after its first collection (Baby Turkey into Turkey, Ugly Duckling into Swan). |

### Building (extends Placeable)

Holds animals, trees or vehicles; may be built from a frame and grown size by size.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `cycle_seconds` | int | 86400 |  | Time between collections. |
| `sizes` | list<size> |  | yes | One record per size, smallest first: capacity (what it holds), name (shown; defaults to the building's), and what reaching it from the size before takes: materials, or for a crafting building's stars, coins and recipe_stars (or gems instead). |
| `tab` | enum of animal, storage, crafting, decor | "animal" |  | Its Market tab, as FarmVille sorted buildings: Animal, Storage, Crafting, Decorative. |
| `limit` | int | 1 |  | How many one farm may have (FarmVille: 5 Dairy Farms, 1 of most). |
| `limit_group` | string |  |  | Buildings sharing a limit (FarmVille: 3 crafting buildings in all). |
| `group_limit` | int |  |  | How many of the group one farm may have. |
| `holds` | list<string> → Animal|Tree |  |  | Item ids that can move in. |
| `holds_kind` | enum of tree, vehicle |  |  | Any item of this kind can move in. |
| `one_each` | list<string> → Animal |  |  | Specials kept one at a time, taking no space (a bull, a ram). |
| `build_materials` | materials |  |  | If set, it arrives as a frame finished with these. |
| `uses_materials` | list<string> → Material |  |  | Materials that start dropping once you own it. |
| `special` | enum of mystery_eggs, calves, foals, lambs, truffles, nursery, beehive, saplings, garage, garden_shed |  |  | Its FarmVille extra on each collection. |
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

### Crafting (extends Building)

FarmVille's crafting cottages: bushels in, goods out. Sizes are star levels (capacity = crafting slots); each star up costs its size's coins and recipe stars, or its gems.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `craft_seconds` | int | 21600 |  | How long one craft takes (FarmVille: 6 hours). |
| `extra_gem_cost` | int |  |  | Price in gems once you already own a crafting building (FarmVille: the first was coins, the rest Farm Cash). |

### Recipe (extends Item)

Something a crafting building makes from bushels.

| Field | Type | Default | Required | Meaning |
|---|---|---|---|---|
| `building` | string → Crafting |  | yes | Where it's made. |
| `star` | int | 1 |  | The building's star level that unlocks it. |
| `inputs` | map<int> |  | yes | Bushels used: crop id -> how many. |
| `product` | string |  |  | What kind of good (bread, wine, perfume). |

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
| ✅ | Blackberries (values estimated in FarmVille's style) | `blackberries` | 29 | 15 | 4 h | 40 | 1 |
| ✅ | Elderberries (values estimated in FarmVille's style) | `elderberries` | 39 | 25 | 12 h | 100 | 1 |

### Grains

Grains.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Wheat | `wheat` | 1 | 15 | 12 h | 60 | 1 |
| ✅ | Corn | `corn` | 20 | 110 | 3 days | 400 | 4 |
| ✅ | Rice | `rice` | 7 | 40 | 12 h | 105 | 2 |
| ✅ | Rye (values estimated in FarmVille's style) | `rye` | 21 | 35 | 20 h | 125 | 2 |
| ✅ | Red Wheat (values estimated in FarmVille's style) | `red_wheat` | 30 | 135 | 3 days | 495 | 4 |
| ✅ | Oats (values estimated in FarmVille's style) | `oats` | 53 | 25 | 8 h | 90 | 1 |
| ✅ | Posole Corn (values estimated in FarmVille's style) | `posole_corn` | 54 | 30 | 12 h | 105 | 1 |
| ✅ | Amaranth (values estimated in FarmVille's style) | `amaranth` | 76 | 45 | 16 h | 160 | 2 |

### Beans and Nuts

Beans and Nuts.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Soybeans | `soybeans` | 2 | 20 | 1 day | 80 | 2 |
| ✅ | Peanuts | `peanuts` | 3 | 25 | 16 h | 80 | 2 |
| ✅ | Peas (values estimated in FarmVille's style) | `peas` | 32 | 45 | 1 day | 165 | 2 |
| ✅ | Purple Pod Peas (values estimated in FarmVille's style) | `purple_pod_peas` | 40 | 50 | 1 day | 180 | 2 |
| ✅ | Coffee (values estimated in FarmVille's style) | `coffee` | 23 | 30 | 16 h | 110 | 2 |

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
| ✅ | Gladiolus (values estimated in FarmVille's style) | `gladiolus` | 28 | 15 | 6 h | 55 | 1 |
| ✅ | Lilies (values estimated in FarmVille's style) | `lilies` | 35 | 45 | 1 day | 170 | 2 |
| ✅ | Purple Poppies (values estimated in FarmVille's style) | `purple_poppies` | 38 | 20 | 8 h | 75 | 1 |
| ✅ | Columbine (values estimated in FarmVille's style) | `columbine` | 44 | 15 | 4 h | 45 | 1 |
| ✅ | Iris (values estimated in FarmVille's style) | `iris` | 45 | 50 | 1 day | 190 | 2 |
| ✅ | Orange Daisies (values estimated in FarmVille's style) | `orange_daisies` | 59 | 55 | 1 day | 210 | 2 |
| ✅ | White Roses (values estimated in FarmVille's style) | `white_roses` | 80 | 65 | 1 day | 245 | 2 |
| ✅ | Forget-me-nots (values estimated in FarmVille's style) | `forget_me_nots` | 90 | 55 | 18 h | 200 | 2 |
| ✅ | Pink Roses (values estimated in FarmVille's style) | `pink_roses` | 26 | 85 | 2 days | 315 | 3 |

### Roots

Roots.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Potatoes | `potatoes` | 20 | 100 | 3 days | 380 | 4 |
| ✅ | Carrots | `carrots` | 9 | 40 | 12 h | 110 | 2 |
| ✅ | Onions (values estimated in FarmVille's style) | `onions` | 34 | 25 | 12 h | 100 | 1 |
| ✅ | Ginger (values estimated in FarmVille's style) | `ginger` | 42 | 35 | 18 h | 135 | 2 |
| ✅ | Heirloom Carrots (values estimated in FarmVille's style) | `heirloom_carrots` | 57 | 30 | 12 h | 105 | 1 |

### Gourds and Melons

Gourds and Melons.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Pumpkins | `pumpkins` | 5 | 30 | 8 h | 70 | 1 |
| ✅ | Squash | `squash` | 4 | 35 | 2 days | 150 | 3 |
| ✅ | Watermelon | `watermelon` | 18 | 110 | 4 days | 460 | 5 |
| ✅ | Zucchini (values estimated in FarmVille's style) | `zucchini` | 27 | 30 | 16 h | 110 | 2 |
| ✅ | Yellow Melon (values estimated in FarmVille's style) | `yellow_melon` | 33 | 185 | 4 days | 680 | 5 |
| ✅ | Acorn Squash (values estimated in FarmVille's style) | `acorn_squash` | 36 | 20 | 10 h | 90 | 1 |
| ✅ | Square Melon (values estimated in FarmVille's style) | `square_melon` | 52 | 55 | 1 day | 200 | 2 |
| ✅ | Carnival Squash (values estimated in FarmVille's style) | `carnival_squash` | 63 | 25 | 8 h | 95 | 1 |
| ✅ | Cucumber (values estimated in FarmVille's style) | `cucumber` | 43 | 50 | 1 day | 185 | 2 |
| ✅ | Pattypan Squash (values estimated in FarmVille's style) | `pattypan_squash` | 24 | 30 | 16 h | 110 | 2 |

### Vegetables

Vegetables.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Tomatoes | `tomatoes` | 14 | 50 | 8 h | 110 | 2 |
| ✅ | Eggplant | `eggplant` | 1 | 25 | 2 days | 110 | 2 |
| ✅ | Bell Peppers | `bell_peppers` | 11 | 60 | 2 days | 220 | 3 |
| ✅ | Spinach | `spinach` | 6 | 35 | 14 h | 100 | 2 |
| ✅ | Artichokes | `artichokes` | 6 | 60 | 4 days | 260 | 4 |
| ✅ | Ghost Chili (values estimated in FarmVille's style) | `ghost_chili` | 26 | 15 | 6 h | 55 | 1 |
| ✅ | Cabbage (values estimated in FarmVille's style) | `cabbage` | 27 | 85 | 2 days | 320 | 3 |
| ✅ | Broccoli (values estimated in FarmVille's style) | `broccoli` | 35 | 95 | 2 days | 345 | 3 |
| ✅ | Asparagus (values estimated in FarmVille's style) | `asparagus` | 37 | 30 | 16 h | 115 | 2 |

### Sweet Crops

Sweet Crops.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Sugarcane | `sugarcane` | 19 | 60 | 8 h | 125 | 2 |
| ✅ | Pineapples | `pineapples` | 15 | 75 | 2 days | 280 | 3 |
| ✅ | Grapes | `grapes` | 19 | 80 | 1 day | 230 | 3 |
| ✅ | White Grapes (values estimated in FarmVille's style) | `white_grapes` | 29 | 20 | 12 h | 95 | 1 |

### Fibre

Fibre.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Cotton | `cotton` | 9 | 60 | 3 days | 240 | 3 |
| ✅ | Bamboo (values estimated in FarmVille's style) | `bamboo` | 60 | 40 | 16 h | 145 | 2 |

### Herbs and Teas

Herbs and Teas.

| | Item | id | Unlock | Seed | Grows | Sells | XP |
|---|---|---|---|---|---|---|---|
| ✅ | Green Tea (values estimated in FarmVille's style) | `green_tea` | 28 | 20 | 10 h | 90 | 1 |
| ✅ | Basil (values estimated in FarmVille's style) | `basil` | 48 | 20 | 10 h | 90 | 1 |
| ✅ | Lemon Balm (values estimated in FarmVille's style) | `lemon_balm` | 50 | 15 | 6 h | 60 | 1 |
| ✅ | Saffron (values estimated in FarmVille's style) | `saffron` | 64 | 25 | 10 h | 100 | 1 |
| ✅ | Clover (values estimated in FarmVille's style) | `clover` | 70 | 15 | 4 h | 50 | 1 |
| ✅ | Aloe Vera (values estimated in FarmVille's style) | `aloe_vera` | 22 | 20 | 8 h | 70 | 1 |

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

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Lime Tree (values estimated in FarmVille's style) | `lime_tree` | 21 | 4,350 | 5 days | 1245 |  |

### Grapefruit Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Grapefruit Tree (values estimated in FarmVille's style) | `grapefruit_tree` | 22 | 2,700 | 3 days | 775 |  |

### Mandarin Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Mandarin Tree (values estimated in FarmVille's style) | `mandarin_tree` | 24 | 3,850 | 4 days | 1105 |  |

### Date Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Date Tree (values estimated in FarmVille's style) | `date_tree` | 26 | 3,100 | 3 days | 880 |  |

### Guava Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Guava Tree (values estimated in FarmVille's style) | `guava_tree` | 27 | 3,200 | 3 days | 910 |  |

### Persimmon Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Persimmon Tree (values estimated in FarmVille's style) | `persimmon_tree` | 29 | 4,500 | 4 days | 1285 |  |

### Starfruit Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Starfruit Tree (values estimated in FarmVille's style) | `starfruit_tree` | 31 | 4,750 | 4 days | 1355 |  |

### Passion Fruit Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Passion Fruit Tree (values estimated in FarmVille's style) | `passion_fruit_tree` | 33 | 6,250 | 5 days | 1785 |  |

### Jackfruit Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Jackfruit Tree (values estimated in FarmVille's style) | `jackfruit_tree` | 35 | 3,950 | 3 days | 1125 |  |

### Asian Pear Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Asian Pear Tree (values estimated in FarmVille's style) | `asian_pear_tree` | 37 | 2,750 | 2 days | 785 |  |

### Tamarind Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Tamarind Tree (values estimated in FarmVille's style) | `tamarind_tree` | 39 | 4,300 | 3 days | 1235 |  |

### Almond Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Almond Tree (values estimated in FarmVille's style; FarmVille sold nut trees for Farm Cash) | `almond_tree` | 5 | 3 gems | 3 days | 255 |  |

### Walnut Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Walnut Tree (values estimated in FarmVille's style; FarmVille sold nut trees for Farm Cash) | `walnut_tree` | 11 | 5 gems | 3 days | 405 |  |

### Cashew Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Cashew Tree (values estimated in FarmVille's style; FarmVille sold nut trees for Farm Cash) | `cashew_tree` | 17 | 6 gems | 3 days | 525 |  |

### Chestnut Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Chestnut Tree (values estimated in FarmVille's style; FarmVille sold nut trees for Farm Cash) | `chestnut_tree` | 8 | 6 gems | 2 days | 260 |  |

### Hazelnut Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Hazelnut Tree (values estimated in FarmVille's style; FarmVille sold nut trees for Farm Cash) | `hazelnut_tree` | 14 | 5 gems | 2 days | 300 |  |

### Pecan Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Pecan Tree (values estimated in FarmVille's style; FarmVille sold nut trees for Farm Cash) | `pecan_tree` | 20 | 7 gems | 2 days | 400 |  |

### Pistachio Trees

From FarmVille's tree list.

| | Item | id | Unlock | Cost | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|
| ✅ | Pistachio Tree (values estimated in FarmVille's style; FarmVille sold nut trees for Farm Cash) | `pistachio_tree` | 23 | 8 gems | 2 days | 450 |  |

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
| ✅ | Cornish Hen | `cornish_chicken` | never sold | free | Eggs | 1 day | 70 | breed: cornish |

### Turkeys

Share the Chicken Coop. A Baby Turkey grows up after its first collection.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Turkey | `turkey` | 10 | 500 | Feathers | 1 day | 120 |  |
| ✅ | Baby Turkey | `baby_turkey` | 10 | 7 gems | Feathers | 1 day | 40 |  |
| ✅ | Wild Turkey | `wild_turkey` | never sold | free | Feathers | 1 day | 160 |  |

### Ducks

Live in the Duck Pond. The Ugly Duckling grows into a Swan.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Duck | `duck` | 4 | 200 | Feathers | 1 day | 60 |  |
| ✅ | Ugly Duckling | `ugly_duckling` | never sold | free | Feathers | 1 day | 60 |  |
| ✅ | Swan | `swan` | never sold | free | Feathers | 1 day | 180 |  |
| ✅ | Belted Duck | `belted_duck` | never sold | free | Feathers | 1 day | 90 |  |

### Geese

Share the Duck Pond.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Goose | `goose` | 13 | 650 | Down | 1 day | 150 |  |

### Cows

Live in the Dairy Farm. A bull brings calves of the breeds inside, raised in the Nursery.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Cow | `cow` | 3 | 300 | Milk | 1 day | 85 |  |
| ✅ | Bull | `bull` | never sold | free | Nothing | 1 day | 0 | stray, needs a cow shed |
| ✅ | Calf | `calf` | never sold | free | Milk | 1 day | 20 |  |
| ✅ | Brown Cow | `brown_cow` | never sold | free | Chocolate Milk | 1 day | 110 |  |
| ✅ | Pink Cow | `pink_cow` | never sold | free | Strawberry Milk | 1 day | 140 |  |
| ✅ | Jersey Cow (values estimated in FarmVille's style) | `jersey_cow` | 8 | 18 gems | Milk | 1 day | 120 |  |
| ✅ | Longhorn Cattle | `longhorn` | 10 | 20 gems | Milk | 1 day | 130 |  |
| ✅ | Hereford Cow | `hereford_cow` | 12 | 22 gems | Milk | 1 day | 140 |  |
| ✅ | Gelbvieh Cow | `gelbvieh_cow` | 14 | 22 gems | Milk | 1 day | 140 |  |
| ✅ | Galician Blond Cow | `galician_blond_cow` | 16 | 24 gems | Milk | 1 day | 150 |  |
| ✅ | Red Cow (values estimated in FarmVille's style) | `red_cow` | 30 | 100,000 | Milk | 1 day | 600 |  |
| ✅ | Belted Cow (values estimated in FarmVille's style) | `belted_cow` | 40 | 25,000 | Milk | 1 day | 300 |  |
| ✅ | Brown Calf | `brown_calf` | never sold | free | Milk | 1 day | 20 |  |
| ✅ | Pink Calf | `pink_calf` | never sold | free | Milk | 1 day | 20 |  |
| ✅ | Jersey Calf | `jersey_calf` | never sold | free | Milk | 1 day | 20 |  |
| ✅ | Longhorn Calf | `longhorn_calf` | never sold | free | Milk | 1 day | 20 |  |
| ✅ | Hereford Calf | `hereford_calf` | never sold | free | Milk | 1 day | 20 |  |
| ✅ | Gelbvieh Calf | `gelbvieh_calf` | never sold | free | Milk | 1 day | 20 |  |
| ✅ | Galician Blond Calf | `galician_blond_calf` | never sold | free | Milk | 1 day | 20 |  |
| ✅ | Red Calf | `red_calf` | never sold | free | Milk | 1 day | 20 |  |
| ✅ | Belted Calf | `belted_calf` | never sold | free | Milk | 1 day | 20 |  |

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
| ✅ | Black Sheep | `black_sheep` | never sold | free | Black Wool | 1 day | 190 |  |
| ✅ | Mouflon Sheep | `mouflon_sheep` | never sold | free | Wool | 1 day | 210 |  |

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
| ✅ | Saddleback Pig (values estimated in FarmVille's style) | `saddleback_pig` | 35 | 5,000 | Truffles | 1 day | 260 |  |

### Goats

Live in the Goat Pen.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Goat | `goat` | 9 | 600 | Goat Milk | 2 days | 200 |  |
| ✅ | Boer Goat | `boer_goat` | never sold | free | Goat Milk | 2 days | 260 |  |
| ✅ | Arapawa Goat (values estimated in FarmVille's style) | `arapawa_goat` | 55 | 8,000 | Goat Milk | 2 days | 420 |  |

### Horses

Live in the Horse Stable. A stallion brings foals.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Horse | `horse` | 11 | 900 | Horse Hair | 3 days | 320 |  |
| ✅ | Pony | `pony` | 10 | 1,500 | Horse Hair | 2 days | 95 |  |
| ✅ | Stallion | `stallion` | never sold | free | Nothing | 1 day | 0 | stray, needs a horse stable |
| ✅ | Foal | `foal` | never sold | free | Horse Hair | 1 day | 20 |  |
| ✅ | Gray Horse | `gray_horse` | never sold | free | Horse Hair | 3 days | 340 |  |
| ✅ | Black Pony | `black_pony` | never sold | free | Horse Hair | 2 days | 110 |  |
| ✅ | Mustang | `mustang` | never sold | free | Horse Hair | 3 days | 360 |  |
| ✅ | Gray Foal | `gray_foal` | never sold | free | Horse Hair | 1 day | 20 |  |
| ✅ | Mustang Foal | `mustang_foal` | never sold | free | Horse Hair | 1 day | 20 |  |

### Donkeys

Share the Horse Stable.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Donkey (Mystery Box only, as in FarmVille) | `donkey` | never sold | 800 | Donkey Milk | 2 days | 270 |  |

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

### Turtles

A lost animal that lives in the Duck Pond.

| | Item | id | Unlock | Cost | Gives | Every | Pays | Notes |
|---|---|---|---|---|---|---|---|---|
| ✅ | Turtle | `turtle` | never sold | free | Shells | 2 days | 130 |  |

## Buildings

Buildings: animal homes, storage, crafting. sizes = one record per size, smallest first: what it holds (capacity), its name, and what it takes to reach it from the size before (materials; for a crafting building's stars, coins and recipe stars, or gems instead). Frames (build_materials) are finished with materials first. tab = its Market tab; limit = how many one farm may have (limit_group + group_limit: a shared limit, e.g. 3 crafting buildings in all).

### Animal Homes

Hold animals; one tap collects everyone inside.

Shared: `tab` = "animal"

| | Item | id | Unlock | Cost | Size | Holds | Tab | Limit | Built from | Special |
|---|---|---|---|---|---|---|---|---|---|---|
| ✅ | Chicken Coop | `chicken_coop` | 4 | 5,000 | 3x3 | 20 / 40 / 60 | animal | 1 |  | mystery_eggs |
| ✅ | Duck Pond | `duck_pond` | 5 | 4,000 | 3x3 | 20 / 30 / 40 | animal | 1 |  |  |
| ✅ | Dairy Farm | `cow_shed` | 6 | 10,000 | 4x3 | 20 / 30 / 40 | animal | 5 |  | calves |
| ✅ | Sheep Pen | `sheep_pen` | 7 | 6,000 | 3x3 | 20 / 30 / 40 | animal | 1 |  | lambs |
| ✅ | Goat Pen | `goat_pen` | 9 | 6,000 | 3x3 | 20 / 30 / 40 | animal | 1 |  |  |
| ✅ | Rabbit Hutch | `rabbit_hutch` | 8 | 4,000 | 2x2 | 20 / 30 / 40 | animal | 1 |  |  |
| ✅ | Pig Pen | `pig_pen` | 16 | 5,000 | 3x3 | 30 | animal | 1 | frame | truffles |
| ✅ | Horse Stable | `horse_stable` | 12 | 5,000 | 4x4 | 20 / 25 / 30 / 35 / 40 | animal | 1 | frame | foals |

### Nursery

Raises baby animals into adults.

Shared: `tab` = "animal"

| | Item | id | Unlock | Cost | Size | Holds | Tab | Limit | Built from | Special |
|---|---|---|---|---|---|---|---|---|---|---|
| ✅ | Nursery Barn | `nursery_barn` | 8 | free | 4x3 | 20 / 30 / 40 | animal | 1 | frame | nursery |

### Orchards

Hold trees.

Shared: `tab` = "animal"

| | Item | id | Unlock | Cost | Size | Holds | Tab | Limit | Built from | Special |
|---|---|---|---|---|---|---|---|---|---|---|
| ✅ | Orchard | `orchard` | 8 | 6,000 | 4x4 | 20 / 30 / 40 | animal | 1 |  | saplings |

### Production

Make goods from what the farm grows.

Shared: `tab` = "animal"

| | Item | id | Unlock | Cost | Size | Holds | Tab | Limit | Built from | Special |
|---|---|---|---|---|---|---|---|---|---|---|
| ✅ | Beehive | `beehive` | 3 | 5,000 | 2x2 | 200 | animal | 1 | frame | beehive |
| 🕓 | Greenhouse (breeds hybrid crop seeds) | `greenhouse` | 1 |  |  |  |  |  |  |  |
| 🕓 | Windmill (grinds grain into flour) | `windmill` | 1 |  |  |  |  |  |  |  |

### Crafting

FarmVille's crafting cottages (level 25): bushels from your harvests in, goods out. Sell goods for coins or turn them into fuel.

Shared: `tab` = "crafting", `limit_group` = "crafting", `group_limit` = 3

| | Item | id | Unlock | Cost | Size | Holds | Tab | Limit | Built from | Special |
|---|---|---|---|---|---|---|---|---|---|---|
| ✅ | Bakery | `bakery` | 25 | 100,000 | 4x4 | 1 / 2 / 3 / 4 / 5 | crafting | 3 crafting |  |  |
| ✅ | Winery | `winery` | 25 | 100,000 | 4x4 | 1 / 2 / 3 / 4 / 5 | crafting | 3 crafting |  |  |
| ✅ | Spa | `spa` | 25 | 100,000 | 4x4 | 1 / 2 / 3 / 4 / 5 | crafting | 3 crafting |  |  |
| 🕓 | Juice Press | `juice_press` | 1 |  |  |  |  |  |  |  |
| 🕓 | Spinning Mill | `spinning_mill` | 1 |  |  |  |  |  |  |  |

### Storage

Keep things off the farm.

Shared: `tab` = "storage"

| | Item | id | Unlock | Cost | Size | Holds | Tab | Limit | Built from | Special |
|---|---|---|---|---|---|---|---|---|---|---|
| ✅ | Barn | `barn` | never sold | free | 3x3 | 30 | storage | 1 |  |  |
| ✅ | Garage | `garage` | 22 | 50,000 | 3x3 | 20 | storage | 1 | frame | garage |
| ✅ | Garden Shed (FarmVille: 30,000 coins (or 30 Farm Cash), holds 100 Perfect Bunches, 10 free bunches when built) | `garden_shed` | 4 | 30,000 | 2x2 | 100 | storage | 1 |  | garden_shed |
| 🕓 | Storage Shed | `storage_shed` | 1 |  |  |  |  |  |  |  |
| 🕓 | Silo | `silo` | 1 |  |  |  |  |  |  |  |

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

Shared: `art_fill` = 1.0

| | Item | id | Unlock | Cost | Size | Shape |
|---|---|---|---|---|---|---|
| ✅ | Dirt Path | `dirt_path` | 1 | 20 | 1x1 | path |
| ✅ | Brick Path | `brick_path` | 5 | 50 | 1x1 | path |
| ✅ | Stone Path | `stone_path` | 8 | 80 | 1x1 | path |

### Fences and Walls

Run along a tile; Rotate turns them.

Shared: `art_fill` = 1.0

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
| ✅ | Perfect Bunch (Found while harvesting flowers (FarmVille's Perfect Bunches); lasts 14 days once placed) | `perfect_bunch` | never sold | free | 1x1 | flowerbed |

## recipes

FarmVille's 2010 crafting recipes, 3 per star level per building (from the SuperCheats crafting guide). Inputs are bushels.

### Bakery recipes

Made in the Bakery.

Shared: `building` = "bakery", `product` = "Baked goods"

| | Item | id |  |
|---|---|---|
| ✅ | Pumpkin Bread | `pumpkin_bread` |  |
| ✅ | Spicy Muffins | `spicy_muffins` |  |
| ✅ | Strawberry Shortcake | `strawberry_shortcake` |  |
| ✅ | Pattypan Tart | `pattypan_tart` |  |
| ✅ | Peanut Butter Cookies | `peanut_butter_cookies` |  |
| ✅ | Triple Berry Pie | `triple_berry_pie` |  |
| ✅ | Mocha Blackberry Cake | `mocha_blackberry_cake` |  |
| ✅ | Raspberry Blondie | `raspberry_blondie` |  |
| ✅ | Vegetable Tart | `vegetable_tart` |  |
| ✅ | Baked Cucumber | `baked_cucumber` |  |
| ✅ | Oatmeal Cookies | `oatmeal_cookies` |  |
| ✅ | Pizza Bread | `pizza_bread` |  |
| ✅ | Carrot Cake | `carrot_cake` |  |
| ✅ | Ginger Snaps | `ginger_snaps` |  |
| ✅ | Potato and Onion Bread | `potato_and_onion_bread` |  |

### Spa recipes

Made in the Spa.

Shared: `building` = "spa", `product` = "Spa goods"

| | Item | id |  |
|---|---|---|
| ✅ | Floral Perfume | `floral_perfume` |  |
| ✅ | Fresh Sachet | `fresh_sachet` |  |
| ✅ | Soothing Herbal Lotion | `soothing_herbal_lotion` |  |
| ✅ | Devotion Perfume | `devotion_perfume` |  |
| ✅ | Petal Sachet | `petal_sachet` |  |
| ✅ | Relaxation Oil | `relaxation_oil` |  |
| ✅ | Energizing Lotion | `energizing_lotion` |  |
| ✅ | Lily of the Valley Soap | `lily_of_the_valley_soap` |  |
| ✅ | Restoring Candle | `restoring_candle` |  |
| ✅ | Iris Soap | `iris_soap` |  |
| ✅ | Meditation Candle | `meditation_candle` |  |
| ✅ | Pick Me Up Sachet | `pick_me_up_sachet` |  |
| ✅ | Daffodil Lotion | `daffodil_lotion` |  |
| ✅ | Farmers Frenzy Perfume | `farmers_frenzy_perfume` |  |
| ✅ | Transcendent Candle | `transcendent_candle` |  |

### Winery recipes

Made in the Winery.

Shared: `building` = "winery", `product` = "Drinks"

| | Item | id |  |
|---|---|---|
| ✅ | Red Table Wine | `red_table_wine` |  |
| ✅ | Sweet Saki | `sweet_saki` |  |
| ✅ | White Sangria | `white_sangria` |  |
| ✅ | Dry Saki | `dry_saki` |  |
| ✅ | Fruit Wine | `fruit_wine` |  |
| ✅ | Spicy Tomato Juice | `spicy_tomato_juice` |  |
| ✅ | Blackberry Wine | `blackberry_wine` |  |
| ✅ | Raspberry Wine | `raspberry_wine` |  |
| ✅ | Strawberry Cranberry Juice | `strawberry_cranberry_juice` |  |
| ✅ | Blueberry Wine | `blueberry_wine` |  |
| ✅ | Herbal Elixir | `herbal_elixir` |  |
| ✅ | Pumpkin Vinegar | `pumpkin_vinegar` |  |
| ✅ | Cucumber Wine | `cucumber_wine` |  |
| ✅ | Melon Juice | `melon_juice` |  |
| ✅ | Rose Petal Water | `rose_petal_water` |  |

## Collectibles

Drops found while harvesting, gathered into sets and traded in for rewards (`data/collections.json`).

### Berry Patch

Found from strawberries, raspberries, blueberries, cranberries.

Ladybug Pin, Berry Basket, Garden Gloves, Straw Hat, Tin Watering Can

### Golden Fields

Found from wheat, corn, rice.

Scarecrow Button, Grain Sack, Old Sickle, Corn Doll, Harvest Charm

### Bean Counter

Found from soybeans, peanuts.

Seed Pouch, Pod Peeler, Peanut Jar, Bean Scoop, Shelling Bowl

### Flower Show

Found from sunflowers, lilac, daffodils.

Bee Badge, Seed Packet, Pressed Petal, Flower Press, Garden Trowel

### Bouquet

Found from morning glory, red tulips, lavender.

Ribbon Bow, Flower Snips, Tulip Bulb, Lavender Sachet, Glass Vase

### Root Cellar

Found from potatoes, carrots.

Oil Lantern, Pickle Jar, Rusty Key, Old Almanac, Spinning Top

### Gourd Gallery

Found from pumpkins, squash, watermelon.

Carving Knife, Vine Clip, Melon Baller, Gourd Rattle, Prize Ribbon

### Market Garden

Found from tomatoes, eggplant, bell peppers, spinach, artichokes.

Trowel, Garden Twine, Pepper Pot, Salad Spinner, Seed Packet

### Sweet Tooth

Found from sugarcane, pineapples, grapes.

Candy Cane, Pineapple Crown, Grape Press, Sugar Cube, Honey Dipper

### Cotton Mill

Found from cotton.

Spindle, Cotton Boll, Thimble, Bobbin, Quilt Square

### Bramble Patch

Found from blackberries, elderberries, white grapes, coffee.

Thorn Gloves, Jam Jar, Bramble Hook, Picking Pail, Berry Stain

### Grain Silo

Found from rye, red wheat, oats, posole corn, amaranth.

Flail, Seed Drill, Winnowing Basket, Grain Scoop, Silo Key

### Pea Pod

Found from peas, purple pod peas.

Pea Shooter, Pod Clip, Shelling Tray, Twine Ball, Pea Trellis Tag

### Wildflower Meadow

Found from gladiolus, lilies, purple poppies, columbine.

Meadow Map, Butterfly Net, Dried Poppy, Lily Pad, Field Guide

### Bridal Bouquet

Found from iris, orange daisies, white roses, forget me nots, pink roses.

Lace Ribbon, Silver Pin, Rose Thorn, Daisy Chain, Keepsake Box

### Kitchen Roots

Found from onions, ginger, heirloom carrots.

Braided Onions, Ginger Grater, Root Brush, Clay Crock, Recipe Card

### Vine Harvest

Found from zucchini, yellow melon, acorn squash, square melon, carnival squash, cucumber, pattypan squash.

Vine Snips, Melon Scale, Square Mould, Pickling Jar, Blue Ribbon

### Veg Patch

Found from ghost chili, cabbage, broccoli, asparagus.

Chili Ristra, Cabbage Crate, Asparagus Knife, Slug Trap, Garden Kneeler

### Herb Garden

Found from green tea, basil, lemon balm, saffron, clover, bamboo, aloe vera.

Tea Tin, Mortar and Pestle, Saffron Thread, Four-Leaf Clover, Bamboo Whisk

### Orchard Harvest

Found spotted while farming.

Fruit Picker, Apple Peeler, Cider Jug, Pruning Saw, Golden Apple

### Barnyard

Found spotted while farming.

Cow Bell, Milk Pail, Horseshoe, Feed Scoop, Blue Ribbon Rosette

### Farm Birds

Found spotted while farming.

Robin, Sparrow, Bluebird, Cardinal, Goldfinch
