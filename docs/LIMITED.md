# Limited animals

Unique coats of the animals the farm already has: new colours, patterns, and more or less fur, on the same
animal underneath (no wings, no new kinds). FarmVille had limited editions like these. The owner's rules
(19 Nov 2026) are the three below; the numbers are in `data/balance.json` (`limited.*`).

## The rules
1. **Marked limited.** Every such animal has `limited` in the catalog (`data/catalog/animals.json`), and its
   baby too. The Market sells them on a tab of their own, Limited, next to Animals (`HudMarket.SHELVES`; the
   tab is not there in a release that has none), and search finds them by that word.
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

## Not in the first release
`data/v1.json` has `"limited": false`: no find is rare and none is limited, and the animals are not on its
list, until the owner turns it on.

## Open
- Downloading a limited animal's file when it is first needed is built and off (docs/PACKS.md): it needs an
  address to fetch from. Until then every file ships in the app (about 90 MB for these).
- Limited dogs (five were drawn) wait for dogs to be animals you can buy and house.
- Baby forms for chickens, ducks, geese and rabbits do not exist yet, limited or plain.
