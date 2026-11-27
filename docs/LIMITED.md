# Limited animals and trees

Unique coats of the animals the farm already has: new colours, patterns, and more or less fur, on the same
animal underneath (no wings, no new kinds). FarmVille had limited editions like these. The owner's rules
(19 Nov 2026) are the three below; the numbers are in `data/balance.json` (`limited.*`).

## The rules
1. **Marked limited.** Every such animal has `limited` in the catalog (`data/catalog/animals.json`), and its
   baby too. The Market sells them on a tab of their own, Limited, next to Animals (`HudMarket.SHELVES`; the
   tab is not there in a release that has none), and search finds them by that word. The tab opens short (owner,
   27 Nov: every variety at once was "too clunky and messy"): the landmarks first (the prestige decorations:
   `DecorationDef.is_landmark`), then one card for each kind that has limited varieties, animals and then trees
   (`limited_kinds`, `kind_face`); a tap on a kind's card shows only its varieties, with a way back
   (`_build_limited`). Sent to a limited thing (search, a goal), the tab opens on its kind (`tab_for`).
2. **Bought with gems.** A limited animal is sold in the Market for gems only (`gem_cost`): about double an
   ordinary gem animal, by kind (birds and rabbits 20, pigs, sheep and goats 35, cows, horses, llamas and
   alpacas 50). It lives in its family's home and earns one and a half times the family's plain animal.
3. **Found only where one lives.** Once a limited animal lives in a home, that home's finds can turn out to
   be another of it:
   - a **Mystery Baby** from harvesting the home (`NurtureSystem.from_home`),
   - a **Mystery Egg** from the Chicken Coop (`MysterySystem.find_egg`; decided when found, shown when opened),
   - a **birth** (a calf, foal, lamb or piglet: `BuildingSpecials`; the limited animal's own baby, which the
     Nursery raises into it).
   An ordinary find is limited 0.5% of the time, a rare find 5%. Which one: the limited animals living there,
   likelier the more of one. Everything else a home gives is drawn from its other animals
   (`LimitedSystem.ordinary`), so a home full of limited animals does not hand them out.

## Rare finds
A **Rare Mystery Baby** and a **Rare Mystery Egg** are the same finds, rarer: 1 find in 10
(`limited.rare_share`). The rare egg has its own, better prizes (`data/mystery_eggs.json`, "rare").

## The animals
56 limited animals (five for each kind, six cows) and 21 babies (calves, foals, lambs, piglets: the homes
that have births). Goats, llamas, alpacas, birds and rabbits have no baby form in the game.
Their art is made as every animal's is (docs/ASSETS.md): rows in `tools/animal_art/animal_art/limited.py`,
each from one of its family's breeds, with patterns painted by `paint.py` (stripes, stars, dots, patches,
a run of colours, a dip, a belt, a half). A coat that turns colour does it in flat bands, so a file stays
about a megabyte.

## Their own touches
Each limited animal shows off when tapped: its usual start, then a toss of the head with the tail going, and
sparkles in its own colour (`AnimalBehaviour.showy`, `FarmGrid._poke`). Some coats also have a touch of
their own, named in the catalog (`touch`) and in the art tool (`limited.py` `TOUCH`):

| Touch | What happens | Who |
|---|---|---|
| stars | only the stars blink, each at its own pace | the Galaxy coats, the Midnight Turkey |
| rainbow | the colours turn round the colour wheel | the Rainbow coats |
| sunset | the colours sway a little, to and fro | the Sunset Goat and Rabbit |
| glint | a glint runs from nose to tail every few seconds | the Golden coats, the Royal Turkey, the Rubber Duck |
| embers | warm light climbs the coat | the Flame Chicken, the Autumn Turkey |
| shake | the coat shakes out now and then, the head still, and lets go a little fluff | the long and woolly coats |

How: the colour touches are worked out per point in the vertex stage of the shared material
(`shaders/coat_touch.gdshaderinc`; a material whose `touch` is 0 pays nothing), from what the file says of each
point (its two UV sets: `export.py` `_touch_points`). `CoatTouch.dress` turns a touch on: one material for every
animal of that touch and colour. A shake is two moves in the file (`shake_a`, `shake_b`) blended in turn
(`CoatTouch.shake_weights`); when it happens is the animal's mind's (`AnimalBehaviour.shakes`, every 14 to 30
seconds it stands awake). To give a coat another touch: change its row in `TOUCH`, export it, and set `touch`
in the catalog. Animals in a home shake and glint too; sparkles are for animals standing on the farm.

## Adding one
A fixed path, the same for every new limited animal (and for a new plain breed, less step 2's data):
1. **Draw it**: one row in its family's table in `tools/animal_art/animal_art/limited.py`, made from one of the
   family's breeds (its coat, its pattern), and its name under its touch in `TOUCH` if it has one. Its baby
   follows by the family's rule; its moves are the family's (walk, graze, look, blink, tail, breath).
2. **Make it**: `bash tools/remake_animals.sh path/to/godot`. That exports its file (and its baby's), writes
   its data from the row (`tools/make_limited.py`: the catalog entry with its gems, payout, baby and touch, its
   place in the family's home and the Nursery, its file's entry), and brings the game's lists in step. The
   price and payout it starts with are the family's rule; change them in the catalog afterwards if wanted.
3. **Check it**: `bash tools/precheck.sh path/to/godot`. `limited_test` runs it through the whole game and
   `make_limited.py --check` (here and in CI) fails if a drawn coat has no data or a limited entry no drawing.
Nothing else is written by hand: its Market picture is made by CI's phone build, its pack by
`tools/make_packs` (docs/PACKS.md), and its Market tab, home, finds and saving come from its data.

## Limited trees
Owner, 20 Nov: trees come in varieties as animals do, and everything is the same but that they are trees. A
variety is one thing over both: a row in `data/varieties.json` (`Varieties`), named by a limited item's `variety`.
An animal's look in a variety is drawn by the art tool; a tree's is drawn by the game from the row.
- **Which**: every tree the Market sells, in the five varieties `trees` lists: Galaxy (a deep night blue crown
  with stars that blink), Rainbow (each mass of leaves its own colour, the colours drifting), Golden (gold, with a
  glint), Sunset (peach to plum, warming and cooling) and Cotton Candy (pink, blue and white; it shivers and
  lets petals go). The touches are the animals' own names (`stars`, `rainbow`, `glint`, `sunset`, `shake`). A
  Plum and an Apricot have four: their Golden one is the Orchard's rare variety already.
- **Its data** is wholly its plain tree's and its variety's, written by `tools/make_limited.py`: id
  `<variety>_<plain id>`, `limited_of`, the plain tree's level, fruit colour, cycle and shape, gems by the level
  it unlocks at (`tree_gems`: 20, 35, 50, the animals' steps) and half as much again in coins (`tree_pay`). A
  change to a plain tree or a variety is followed by running the tool; `--check` fails until it is.
- **Its look** (`TreeModel`): the plain tree's own shape and fruit with the variety's `leaves` in turn over its
  masses and fronds, `darken` for Galaxy, `pale` for Cotton Candy's soft crown, the touch on its leaf
  materials (`leaf_touch.gdshaderinc`, `ModelKit.touch_all`) and Galaxy's stars (`star3d.gdshader`). **No file**: five of every tree would be some
  60 MB, so `tools/export_plants` leaves them out and each is built on the device when first shown and kept
  (ModelStore). Its Market picture is made from the same build.
- **Its rules** are the animals', through the same `LimitedSystem`: sold for gems on the Limited tab (animals,
  then trees, a card a kind), harvested alone or in an Orchard, kept in the Barn, sold for its gems'
  worth. An Orchard's Mystery Seedling is one of the limited trees standing in it 0.5% of the time, and 5% for a
  **Rare Mystery Seedling** (the Orchard's rare find, 1 in 10 seedlings, which is also likelier a rare variety:
  Balance `nurture.rare_seedling_chance`). Nothing else brings one.
- **A hummingbird** (`Hummingbird`, sent by `TreeLife`) calls at a limited tree standing on the farm now and
  then: it flies in, circles the crown, slips in among the leaves as if its nest were there, comes out and is
  off. One bird at a time, for show, with no sound.
- **Adding a variety for trees**: a row in `data/varieties.json` with `leaves` (and a `touch` if it has one), its
  name in `trees`, then `python3 tools/make_limited.py` and the precheck. `limited_test` 600 to 602 run every
  limited tree through the game and `trees_test` 603 to 605 check the look, the bird and the shiver.

## A new variety: the order of work
Owner, 20 Nov: a variety starts as a style, and the style is then put on animals and on trees, with their
pictures; every variety is sold on the Limited tab.
1. **The style**: a row in `data/varieties.json` (its name, its touch, and for trees its `leaves`), shown to the
   owner as a sheet first, like any new look.
2. **Trees**: its name in `trees`, then `python3 tools/make_limited.py`: every Market tree gets it.
3. **Animals**: a row for each animal that wears it in `tools/animal_art/animal_art/limited.py`, then
   `bash tools/remake_animals.sh` ("Adding one" above). Unlike trees, animals are drawn one by one.
4. **Pictures and the Limited tab** need nothing: both come from the data.
Flowers and crops have no varieties yet.

## In the rest of the game
A limited animal is an animal of its family in every other way, and nothing lists the limited ones by hand:
it moves, calls (the same sound, at the same pitch) and eats as its family does, gives the family's produce,
lives in the family's home, is kept in the Barn, sells for its gems' worth in coins, counts as an animal in
goals and jobs, and is saved wherever it is. A limited baby is raised in the Nursery into its own animal.
Nothing but the Market and a home's finds brings one: not a neighbour's mystery gift, a prize or a trade. A
home with only limited animals still makes ordinary finds, of their plain kind (`LimitedSystem.plain_of`).
`limited_test` runs every one of them through all of this, so a new limited animal added to the catalog is
checked with no test to write.

Their pictures are made like every item's (CI's `tools/bake_icons`, in the app). A picture never fetches a
file: where one has to be drawn on the device and the animal's file is not there yet, the stand-in's picture is
shown, not kept, and made again when the file arrives (docs/PACKS.md).

## In the first release
`data/v1.json` has `"limited": true` (owner, 20 Nov: "I don't see the limited banner and animals"): a limited
variety is in the release whenever the plain kind it is a variety of is (`Release.has`: a tree's `limited_of`,
an animal's family), so nothing needs listing one by one.

## Open
- Downloading a limited animal's file when it is first needed is built and off (docs/PACKS.md): it needs an
  address to fetch from. Until then every file ships in the app (about 90 MB for these).
- Limited dogs (five were drawn) wait for dogs to be animals you can buy and house.
- Baby forms for chickens, ducks, geese and rabbits do not exist yet, limited or plain.
