# Limited animals

Unique coats of the animals the farm already has: new colours, patterns, and more or less fur, on the same
animal underneath (no wings, no new kinds). FarmVille had limited editions like these. The owner's rules
(19 Nov 2026) are the three below; the numbers are in `data/balance.json` (`limited.*`).

## The rules
1. **Marked limited.** Every such animal has `limited` in the catalog (`data/catalog/animals.json`), and its
   baby too. The Market shows them in a section of their own, each card saying "Limited".
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

## Not in the first release
`data/v1.json` has `"limited": false`: no find is rare and none is limited, and the animals are not on its
list, until the owner turns it on.

## Open
- Downloading a limited animal's file when it is first needed is built and off (docs/PACKS.md): it needs an
  address to fetch from. Until then every file ships in the app (about 90 MB for these).
- Limited dogs (five were drawn) wait for dogs to be animals you can buy and house.
- Baby forms for chickens, ducks, geese and rabbits do not exist yet, limited or plain.
